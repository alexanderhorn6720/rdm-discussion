# 09 — Bots LLM architecture

**Status**: Propuesta. Esperando voto.

**Decisión**: Portar Greeter v4 + Booker hot-fix C intactos a `packages/agents/` con TypeScript. Patrón 2-stage tool-forcing con prompt caching mantenido. Anthropic Haiku 4.5 mantenido. Knowledge files siguen en GitHub, sync a KV cada 2h.

## Contexto

Bots actuales en Make (Greeter 4716928 + Booker 4724250) tienen lógica compleja iterada en producción:
- 2-stage tool-forcing (extract_intent → respond_to_user).
- Override rule v4 inline en system prompt.
- Multi-room support en Greeter (`room_ids` array).
- Hot-fix C en Booker (always-generate-block, stage1 PRIORIDAD ABSOLUTA, override regla 6/7/8/9).
- Calendar lookup determinístico antes de Stage 2.
- Knowledge files (system_prompt, system_prompt_booker, property JSONs) en GitHub raw.
- Calendar lookup desde KV (refresh 2h via cron).

NO REPLICAMOS desde cero. Portamos. Pero limpiamos los workarounds que solo existían por limitaciones de Make.

## Arquitectura

```
packages/agents/
├── greeter/
│   ├── index.ts              ← entry: handleMessage(input, ctx) → reply
│   ├── stage1-intent.ts      ← LLM call extract_intent
│   ├── stage2-respond.ts     ← LLM call respond_to_user
│   ├── prompts.ts            ← system_prompt + override_rule (loaded from KV)
│   ├── schemas.ts            ← Zod schemas para tool inputs/outputs
│   └── greeter.test.ts       ← 7 QA cases
├── booker/
│   ├── index.ts
│   ├── stage1-intent.ts
│   ├── stage2-respond.ts
│   ├── prompts.ts
│   ├── calendar-lookup.ts    ← reusable, also used by greeter
│   ├── schemas.ts
│   └── booker.test.ts
├── shared/
│   ├── anthropic-client.ts   ← wrapper con caching, retries, telemetry
│   ├── conversation-state.ts ← load/save from D1
│   └── types.ts
└── package.json
```

## API

```typescript
// packages/agents/greeter/index.ts
export async function handleGreeterMessage(input: {
  subscriberId: string;
  channel: ChannelKind;
  message: string;
  ctx: ExecutionContext;
  env: Env;
}): Promise<{
  reply: string;
  intent: GreeterIntent;
  shouldHandoff: boolean;
  handoffData?: BookingHandoffData;
}> {
  // 1. Load conversation state from D1
  const state = await loadConversation(input.subscriberId, input.env);
  
  // 2. Stage 1: extract intent
  const stage1 = await runStage1Intent({ message: input.message, state, env: input.env });
  
  // 3. Calendar lookup (deterministic, no LLM)
  const availabilityBlock = await buildAvailabilityBlock({
    roomIds: stage1.room_ids,
    checkIn: stage1.check_in,
    checkOut: stage1.check_out,
    guests: stage1.guests,
    intent: stage1.intent,
    env: input.env
  });
  
  // 4. Stage 2: respond
  const stage2 = await runStage2Respond({
    message: input.message,
    state,
    availabilityBlock,
    intent: stage1.intent,
    env: input.env
  });
  
  // 5. Save state to D1
  await saveConversation(input.subscriberId, {
    history: appendTurn(state.history, input.message, stage2.reply),
    last_intent: stage2.intent,
    turn_count: state.turn_count + 1
  }, input.env);
  
  // 6. Return result, caller decides routing
  return {
    reply: stage2.reply,
    intent: stage2.intent,
    shouldHandoff: stage2.intent === 'handoff_booking',
    handoffData: stage2.intent === 'handoff_booking' ? stage2.booking_data : undefined
  };
}
```

## Prompt caching estrategia

Anthropic prompt caching reduce 90% costo de tokens cacheados.

Patrón actual (Greeter Make):
```typescript
system: [
  { type: 'text', text: full_system_prompt },                          // ~10KB, frontier dinámico
  { type: 'text', text: lockRules, cache_control: { type: 'ephemeral' } }  // hot frontier
]
```

**Problema**: si `full_system_prompt` cambia entre turnos (p.ej. por incluir `last_intent`), cache miss. Hoy mitigamos meterlo en el user message, no en system.

**Diseño limpio**:
```typescript
system: [
  // Bloque 1: invariante por release (BASE_SYSTEM_PROMPT + OVERRIDE_RULE v4)
  { type: 'text', text: BASE_PROMPT + OVERRIDE_RULE, cache_control: { type: 'ephemeral' } },
  // Bloque 2: lock rules + property metadata (también invariante hasta deploy)
  { type: 'text', text: LOCK_RULES + PROPERTIES_JSON, cache_control: { type: 'ephemeral' } }
],
messages: [
  { role: 'user', content: USER_CONTEXT + USER_MESSAGE + AVAILABILITY_BLOCK }
  // último mensaje siempre dinámico, no cacheado
]
```

Cache HIT cuando subscriber X manda turno 2 dentro de 5min (TTL ephemeral). Para baseline ~85-95% cache hit rate.

## Knowledge en KV vs Files API

**Hoy**: knowledge_refresh Make sube archivos a Anthropic Files API + R2.

**Decisión**: usar **KV directo** (sin Files API).

Razón:
- Archivos son small (system prompt ~10KB, properties JSON ~5KB c/u, faq ~3KB). Total <50KB.
- Caben holgados en `system: [{ text: ... }]` cacheado.
- KV reads <10ms global.
- Files API agrega complejidad (file_id management, expiración).
- R2 sigue para `availability.json` y `prices.json` (que son más grandes y consumidos por otros lugares).

```typescript
// packages/agents/shared/load-prompts.ts
export async function loadGreeterSystemPrompt(env: Env): Promise<string> {
  const [base, override, lockRules, properties, faq] = await Promise.all([
    env.KNOWLEDGE.get('greeter:base_prompt'),
    env.KNOWLEDGE.get('greeter:override_rule_v4'),
    env.KNOWLEDGE.get('greeter:lock_rules'),
    env.KNOWLEDGE.get('properties:all'),
    env.KNOWLEDGE.get('faq')
  ]);
  return `${base}\n\n${override}\n\n${lockRules}\n\n${properties}\n\n${faq}`;
}
```

KV refresh via cron Workflow (ver `08-orchestration.md`):
- Cron pulls GitHub raw + Beds24 calendar
- PUT a KV
- Bot lee fresh en próxima invocación

## Multi-channel agent

Hoy el Greeter está acoplado a ManyChat (custom fields, flow names, subscriber_id format).

**Nuevo**: agent recibe `IncomingMessage` normalizado (via `packages/channels/`) y emite `OutgoingMessage`. Provider abstraído.

```typescript
// apps/bot/src/index.ts
app.post('/webhook/manychat', async (c) => {
  const incoming = await ManychatProvider.parseWebhook(await c.req.json());
  // Process in background
  c.executionCtx.waitUntil(processMessage(incoming, c.env));
  return c.json({ ok: true });
});

app.post('/webhook/whatsapp', async (c) => {
  // Stage 2 — WhatsApp Cloud API direct
  const incoming = await WhatsAppCloudProvider.parseWebhook(await c.req.json(), c.req.header('x-hub-signature-256'), c.env);
  c.executionCtx.waitUntil(processMessage(incoming, c.env));
  return c.json({ ok: true });
});

async function processMessage(msg: IncomingMessage, env: Env) {
  // Debounce via DO
  const debouncer = env.DEBOUNCE_DO.get(env.DEBOUNCE_DO.idFromName(msg.subscriberId));
  await debouncer.receiveMessage(msg);
  // (DO alarm triggers actual LLM processing 8s later)
}
```

Cuando debounce fires:
```typescript
// In DO alarm handler
const greeterResult = await handleGreeterMessage({ ... });

// Send response via correct provider
const provider = getProvider(msg.channel, env);
await provider.send({
  subscriberId: msg.subscriberId,
  text: greeterResult.reply
});

// If handoff:
if (greeterResult.shouldHandoff) {
  await env.BOOKER_WORKFLOW.create({ payload: greeterResult.handoffData });
}
```

## Tests

`packages/agents/greeter/greeter.test.ts` cubre los 7 QA cases existentes:

```typescript
import { describe, it, expect, vi } from 'vitest';
import { handleGreeterMessage } from './index';

describe('Greeter QA cases', () => {
  it('Case 1: midweek quote with breakdown', async () => {
    const result = await handleGreeterMessage({
      subscriberId: 'test-1',
      channel: 'whatsapp',
      message: '¿Cuánto cuesta Rincón del Mar 17 a 20 de junio para 20 pax?',
      ctx: mockCtx(),
      env: mockEnv({ /* fixtures de KV calendar */ })
    });
    expect(result.intent).toBe('quote');
    expect(result.reply).toMatch(/3 noches/);
    expect(result.reply).toMatch(/footnote.*3 PM.*11 AM/i);
  });
  
  it('Case 7: post-handoff status query', async () => {
    // Setup state with last_intent=handoff_booking
    await mockEnv.DB.prepare('INSERT INTO conversations (..., last_intent) VALUES (..., \'handoff_booking\')').run();
    
    const result = await handleGreeterMessage({
      subscriberId: 'test-7',
      channel: 'whatsapp',
      message: 'sigues ahí?',
      ctx: mockCtx(),
      env: mockEnv()
    });
    expect(result.intent).toBe('escalate');
    expect(result.reply).not.toMatch(/Alexander está procesando|en un momento/i);
  });
});
```

Mock env con `miniflare` + `@cloudflare/vitest-pool-workers`.

## Migration from Make blueprints

Para portar fielmente:
1. Extraer texto del `stage1_system` y `override_rule` actuales de Make scenarios 4716928 / 4724250.
2. Commitear a `packages/agents/{greeter,booker}/prompts/` como files versionados.
3. Setup KV con valores iniciales.
4. Refactor JavaScript Code modules de Make (`calendar_lookup.js`, `stage1-build.js`, etc.) a TypeScript modules con tipos.
5. Tests vs Make fixtures (capturar payloads reales para regression).

## LLM model decision

**Mantener Anthropic Haiku 4.5** para ambos agents.

Considerar Sonnet 4 solo si:
- Calidad reply queda corta en casos complejos.
- Budget acepta ~5x costo.

NO usar Workers AI / Llama / GPT-4. Razones:
- Haiku 4.5 ya está probado en producción.
- Override_rule v4 está calibrado para Haiku.
- Prompt caching de Anthropic es feature crítica.

## Voto

- [ ] **Claude Code**: ¿de acuerdo con port intacto + clean refactor? Otra arquitectura para 2-stage?
- [ ] **Alexander**: ¿OK con mantener Haiku 4.5 (no upgrade a Sonnet)?

## Refs

- Override rule v4 actual: ver bot Make scenario 4716928 mod 9 input `override_rule`.
- Hot-fix C Booker: ver bot Make scenario 4724250 mod 7/9/10.
- Anthropic prompt caching: `https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching`
