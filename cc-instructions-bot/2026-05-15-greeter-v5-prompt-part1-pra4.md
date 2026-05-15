# Execute: Greeter v5 Fase 2 — PR A4 + A6 + A7

**Date**: 2026-05-15
**From**: WC (after Alex Q-63-1 → Opción A)
**To**: CC-Bot
**Re**: Greeter v5 system prompt + tool-use enforcement + canary rollout
**ETA**: ~9h CC distributed across 2-3 sessions
**Branch**: `feat/greeter-v5-core`

---

## 0. Context (read first)

This document is the Fase 2 execute spec, sequel to:
- `cc-instructions/2026-05-14-greeter-v5-fase-0-1-execute.md` (Fase 0+1 — done)
- `threads/50-wc-response-bot-routing.md` (D1-D8 + Q-BR1-7 decisions)
- `threads/52-wc-anchors-spec.md` (intent catalog + URL templates)
- `threads/58-wc-ack-cc-overnight-and-pr-a15-spec.md` (sub-components PR A1.5)
- `threads/59-wc-pet-decision-resolved-cc-handoff.md` (pet policy $300/max 2)
- `threads/64-cc-alex-voted-option-a-handoff-spec-fase-2.md` (handoff request)

**Fase 1 status**: ✅ CLOSED — 8 PRs merged + auto-deployed. Worker bot + Pages live.

**Fase 2 scope** (this doc):
- **PR A4** — Tool-use enforcement + intent-resolver integration in Greeter
- **PR A6** — System prompt v5 (bilingual + guardarrails + few-shot)
- **PR A7** — Canary rollout 10→25→50→100% + `/admin/bot-metrics` dashboard

**Out of scope** (post-Fase 2):
- PR A6.1 — system prompt upgrade post-Data-Mining-v2 (operator playbook patterns)
- PR A8 — split AirBnB vs WhatsApp prompts (per D8)
- Booker v4 refactor (separate sprint)

---

## 1. ⚠️ Critical reminders before starting

### 1.1 Existing infrastructure (DO NOT recreate)

CC already built:
- ✅ `apps/worker-bot/src/intent-resolver.ts` (PR #29) — 26 intents ES + EN
- ✅ `apps/worker-bot/src/lang-detection.ts` (PR #33) — heurística ES/EN
- ✅ `/r/bot/[slug]` click tracking endpoint (PR #29)
- ✅ `/internal/notify-human` Telegram endpoint (PR #30)
- ✅ D1 `bot_link_clicks` + `human_handoff_log` tables

PR A4 **consumes** these. Do NOT duplicate.

### 1.2 Greeter existing architecture (from thread/64 discovery)

```
packages/agents/greeter/
├── index.ts       orchestrator (loadKnowledge → Stage1 → calendar → Stage2 → output)
├── stage1.ts      extract_intent (Anthropic Haiku, max 400 tokens, temp 0.0)
├── stage2.ts      respond_to_user (Haiku, max 800, temp 0.3)
├── calendar.ts    deterministic availability check
└── handoff.ts     booker handoff logic
```

Output schema:
```typescript
interface GreeterResult {
  reply: string;
  intent: 'info'|'quote'|'videos'|'handoff_booking'|'escalate'|'bot_loop';
  shouldHandoff: boolean;
  bookingData: {...};
  metadata: { tokens..., cache... };
}
```

### 1.3 Hard constraints (NO negotiate)

| Constraint | Reason |
|---|---|
| Pet policy: `$300 MXN/noche, máximo 2` HARDCODED en prompt | Q-56-1 Alex decision, no LLM hallucination allowed |
| URL hardcoded via intent-resolver, NOT LLM-generated | D2 — tool-use híbrido |
| `opening_line` 1-2 sentences max | Threads 50 §2 P2 — guardarrails |
| Saludo template "Felix, asistente de Rincón del Mar 🌅" | Thread 50 §2 P3 |
| Greeter Haiku, not Sonnet | Cost — ~1ms/turn, $0.10/Mtok input |
| `last_intent` state persists in D1 conversations | Anti-loop logic |
| Casa Chamán NOT mentioned in prompt | Per memory — Q3 2026 launch, do not propose |

---

## 2. PR A4 — Tool-use enforcement + intent-resolver integration

### 2.1 Scope

Replace Stage 2 free-form generation with **tool-call enforcement**. Greeter must call exactly ONE tool per turn:

| Tool | Purpose | When |
|---|---|---|
| `route_user_to_url` | Deflect to site with URL + opening_line | 80% of turns (hot/site intents) |
| `request_clarification` | Ask user 1 specific question | When intent unclear OR missing data for URL |
| `handoff_to_booker` | Switch to Booker agent | Only when intent='reservar' + dates+guests detected |
| `escalate_to_human` | Trigger Telegram notif | Anti-loop, complex objection, explicit human request |

**No `respond_to_user` free-text tool.** All replies are templated from tool outputs.

### 2.2 Tool definitions (Anthropic schema)

CC: copy these to `packages/agents/greeter/tools.ts` or equivalent.

```typescript
import Anthropic from '@anthropic-ai/sdk';

export const GREETER_TOOLS_V5: Anthropic.Tool[] = [
  // -------------------------------------------------------------------------
  // TOOL 1: route_user_to_url (80% of turns)
  // -------------------------------------------------------------------------
  {
    name: 'route_user_to_url',
    description:
      'Deflect user to a specific URL on the Rincón del Mar website. ' +
      'Use this for ANY question that can be answered by content on the site: ' +
      'prices, availability, photos, amenities, location, weddings, FAQs, etc. ' +
      'You MUST select an intent_slug from the catalog. ' +
      'You write a 1-2 sentence opening_line that acknowledges the user warmly. ' +
      'The URL is resolved automatically — do NOT write URLs yourself.',
    input_schema: {
      type: 'object',
      properties: {
        intent_slug: {
          type: 'string',
          description:
            'Required. The intent identifier from the catalog. ' +
            'Examples: "precios", "disponibilidad", "fotos", "tour-360", ' +
            '"chef", "mascotas", "bodas", "como-llegar", "faq". ' +
            'See full catalog in system prompt §INTENT_CATALOG.',
          enum: [
            // Hot intents (require property)
            'precios', 'disponibilidad', 'cotizar', 'reservar',
            'fotos', 'tour-360', 'capacidad', 'chef',
            'mascotas', 'testimonios',
            // Site-only intents (no property required)
            'como-llegar', 'bodas', 'eventos-corporativos',
            'reunion-familiar', 'comparar-casas', 'comparar-zonas',
            'villa-vs-hotel', 'temporada-alta', 'navidad-ano-nuevo',
            'arquitectura', 'pie-de-la-cuesta', 'faq', 'contacto',
            'casas', 'reviews', 'home',
          ],
        },
        opening_line: {
          type: 'string',
          description:
            'Required. 1-2 sentences, WhatsApp-friendly tone, warm but concise. ' +
            'Acknowledge the user question in general terms. ' +
            'The link does the heavy lifting — do NOT repeat info that is on the linked page. ' +
            'STRICT BANS: see §OPENING_LINE_BANS in system prompt.',
          maxLength: 280,
        },
        property: {
          type: 'string',
          description:
            'Optional. Property slug if user mentioned a specific house. ' +
            'Required for intents marked requires_property=true. ' +
            'If user did not specify a property, omit this field — fallback URL will be used.',
          enum: ['rincon-del-mar', 'las-morenas', 'huerta-cocotera', 'combinada'],
        },
        check_in: {
          type: 'string',
          description:
            'Optional. ISO date YYYY-MM-DD if user mentioned check-in date. ' +
            'Used to pre-fill booking card for intents: disponibilidad, cotizar, reservar.',
          pattern: '^\\d{4}-\\d{2}-\\d{2}$',
        },
        check_out: {
          type: 'string',
          description: 'Optional. ISO date YYYY-MM-DD if user mentioned check-out date.',
          pattern: '^\\d{4}-\\d{2}-\\d{2}$',
        },
        guests: {
          type: 'integer',
          description: 'Optional. Number of guests if user mentioned. Used for cotizar/reservar.',
          minimum: 1,
          maximum: 60,
        },
        city: {
          type: 'string',
          description:
            'Optional. User origin city if mentioned (e.g. "cdmx", "monterrey"). ' +
            'Used for como-llegar intent to route to /desde/{city}.',
          enum: ['cdmx', 'edomex', 'puebla', 'cuernavaca', 'queretaro',
                 'guadalajara', 'monterrey', 'toluca'],
        },
      },
      required: ['intent_slug', 'opening_line'],
    },
  },

  // -------------------------------------------------------------------------
  // TOOL 2: request_clarification
  // -------------------------------------------------------------------------
  {
    name: 'request_clarification',
    description:
      'Ask the user ONE specific question to disambiguate. ' +
      'Use ONLY when intent is genuinely unclear AND you cannot pick a reasonable default. ' +
      'Prefer route_user_to_url with a fallback URL over asking — users hate question-asking bots. ' +
      'Maximum 2 turns of clarification before falling back to /casas or escalate.',
    input_schema: {
      type: 'object',
      properties: {
        question: {
          type: 'string',
          description:
            'Required. ONE question, 1 sentence, WhatsApp-friendly. ' +
            'Examples: "¿Para cuántas personas?" / "¿Qué fechas tienes en mente?" / ' +
            '"¿Te interesa alguna casa en particular?"',
          maxLength: 160,
        },
        clarification_type: {
          type: 'string',
          enum: ['property', 'dates', 'group_size', 'use_case', 'other'],
          description:
            'Type of info missing. Bot tracks this in conversation state to ' +
            'avoid asking same thing twice.',
        },
      },
      required: ['question', 'clarification_type'],
    },
  },

  // -------------------------------------------------------------------------
  // TOOL 3: handoff_to_booker
  // -------------------------------------------------------------------------
  {
    name: 'handoff_to_booker',
    description:
      'Switch to the Booker agent for transactional booking flow. ' +
      'Use ONLY when ALL of: (a) intent is clearly "reservar"/"book", ' +
      '(b) user has provided check-in date, check-out date, AND group size, ' +
      '(c) user expressed firm intent to book (not just asking prices). ' +
      'If ANY of (a)(b)(c) missing, use route_user_to_url with intent=cotizar instead.',
    input_schema: {
      type: 'object',
      properties: {
        property: {
          type: 'string',
          enum: ['rincon-del-mar', 'las-morenas', 'huerta-cocotera', 'combinada'],
        },
        check_in: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
        check_out: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
        guests: { type: 'integer', minimum: 1, maximum: 60 },
        pets: { type: 'integer', minimum: 0, maximum: 2 },
        notes: {
          type: 'string',
          description: 'Optional user-stated context (e.g. "bodas", "cumpleaños").',
          maxLength: 200,
        },
      },
      required: ['property', 'check_in', 'check_out', 'guests'],
    },
  },

  // -------------------------------------------------------------------------
  // TOOL 4: escalate_to_human
  // -------------------------------------------------------------------------
  {
    name: 'escalate_to_human',
    description:
      'Trigger Telegram notification to Alex/Karina and tell user a human will reply. ' +
      'Use for: (a) explicit user request ("quiero hablar con un humano"), ' +
      '(b) detected anti-loop (3+ user turns saying same thing without progress), ' +
      '(c) complex objection or complaint Greeter cannot resolve, ' +
      '(d) user shows mental health distress (suicide ideation, etc).',
    input_schema: {
      type: 'object',
      properties: {
        reason: {
          type: 'string',
          enum: ['user_request', 'anti_loop', 'objection', 'complaint',
                 'distress', 'special_request', 'other'],
        },
        summary: {
          type: 'string',
          description:
            'One-sentence summary of WHY escalating, for Alex to read in Telegram.',
          maxLength: 200,
        },
        urgency: {
          type: 'string',
          enum: ['low', 'medium', 'high'],
          description:
            'low=can wait 8h | medium=respond within 1h | high=respond ASAP. ' +
            'distress and complaint default to high.',
        },
      },
      required: ['reason', 'summary', 'urgency'],
    },
  },
];
```

### 2.3 Tool-use enforcement strategy

**Choice: `tool_choice = "any"` (forced tool call) — NOT auto/required-specific.**

Reasoning:
- `auto` allows LLM to skip tool → generates free text → high hallucination risk
- `any` forces tool selection but Greeter picks which one → still has flexibility
- A specific `{ type: 'tool', name: 'route_user_to_url' }` is too restrictive — kills the clarification/escalate paths

Call pattern:
```typescript
const response = await anthropic.messages.create({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 500,
  system: SYSTEM_PROMPT_V5, // see §3
  messages: conversationHistory,
  tools: GREETER_TOOLS_V5,
  tool_choice: { type: 'any' }, // forced tool selection
});

// Parse response.content — must contain exactly one tool_use block
const toolUseBlock = response.content.find(b => b.type === 'tool_use');
if (!toolUseBlock) {
  throw new Error('Greeter did not call a tool — forced tool_choice failed');
}
```

### 2.4 Intent-resolver integration

After Greeter selects `route_user_to_url`, CC code resolves the URL:

```typescript
import { resolveIntent } from '../intent-resolver';
import { wrapClickTracking } from '../click-tracking';

async function processGreeterToolUse(
  toolUse: ToolUseBlock,
  ctx: ConversationContext,
): Promise<GreeterReply> {
  if (toolUse.name === 'route_user_to_url') {
    const args = toolUse.input as RouteUserToUrlArgs;

    // 1. Resolve URL via intent-resolver
    const resolved = resolveIntent({
      intent: args.intent_slug,
      property: args.property,
      check_in: args.check_in,
      check_out: args.check_out,
      guests: args.guests,
      city: args.city,
      lang: ctx.lang, // from lang-detection
    });

    if (!resolved.ok) {
      // Intent-resolver said this intent has no URL — fallback
      return makeReply(
        args.opening_line,
        wrapClickTracking({
          target: '/casas',
          intent: 'casas',
          property: null,
          conv: ctx.conv_hash,
          version: 'v5',
          lang: ctx.lang,
        }),
      );
    }

    // 2. Wrap with click tracking
    const trackedUrl = wrapClickTracking({
      target: resolved.url,
      intent: args.intent_slug,
      property: args.property,
      conv: ctx.conv_hash,
      version: 'v5',
      lang: ctx.lang,
    });

    // 3. Format reply
    return makeReply(args.opening_line, trackedUrl);
  }

  if (toolUse.name === 'request_clarification') {
    const args = toolUse.input as RequestClarificationArgs;
    return {
      reply: args.question,
      intent: 'clarification',
      shouldHandoff: false,
      metadata: { tool_used: 'request_clarification', type: args.clarification_type },
    };
  }

  if (toolUse.name === 'handoff_to_booker') {
    const args = toolUse.input as HandoffToBookerArgs;
    return {
      reply: '', // booker will respond
      intent: 'handoff_booking',
      shouldHandoff: true,
      bookingData: { ...args },
      metadata: { tool_used: 'handoff_to_booker' },
    };
  }

  if (toolUse.name === 'escalate_to_human') {
    const args = toolUse.input as EscalateToHumanArgs;
    // Fire telegram notif (existing /internal/notify-human endpoint)
    await fetch(`${env.BOT_INTERNAL_URL}/internal/notify-human`, {
      method: 'POST',
      headers: { 'x-admin-secret': env.ADMIN_REFRESH_SECRET, 'content-type': 'application/json' },
      body: JSON.stringify({
        subscriber_id: ctx.subscriber_id,
        last_user_message: ctx.last_user_msg,
        intent: 'escalate',
        reason: args.reason,
        summary: args.summary,
        urgency: args.urgency,
      }),
    });
    return {
      reply: ctx.lang === 'en'
        ? "I'm passing this to Karina or Alex — they'll write back shortly."
        : 'Karina o Alex te van a escribir en un rato.',
      intent: 'escalate',
      shouldHandoff: false,
      metadata: { tool_used: 'escalate_to_human', reason: args.reason, urgency: args.urgency },
    };
  }

  throw new Error(`Unknown tool: ${toolUse.name}`);
}

function makeReply(opening: string, url: string): GreeterReply {
  return {
    reply: `${opening}\n\n→ ${url}`,
    intent: 'route',
    shouldHandoff: false,
    metadata: { tool_used: 'route_user_to_url' },
  };
}
```

### 2.5 Output schema update

```typescript
// packages/agents/greeter/types.ts

export type GreeterIntentV5 =
  | 'route'           // route_user_to_url succeeded
  | 'clarification'   // bot needs more info
  | 'handoff_booking' // handoff to Booker
  | 'escalate'        // Telegram notif fired
  | 'bot_loop'        // anti-loop triggered (still escalate but flagged)
  | 'error';          // tool call failed, fallback

export interface GreeterResultV5 {
  reply: string;
  intent: GreeterIntentV5;
  shouldHandoff: boolean;
  bookingData?: BookingHandoffData;
  recommendedUrl?: string;     // NEW: the URL emitted (for analytics)
  metadata: {
    tool_used: string;
    tokens_input: number;
    tokens_output: number;
    cache_hits: number;
    lang: 'es' | 'en';
    latency_ms: number;
  };
}
```

### 2.6 Anti-loop detection

Conversation table has `last_intent` and `turn_count`. Logic:

```typescript
function detectLoop(ctx: ConversationContext, newIntent: string): boolean {
  // Same intent 3 turns in a row, no progression
  if (ctx.history.slice(-3).every(turn => turn.intent === newIntent)) {
    return true;
  }
  // User has been asking same thing rephrased
  if (ctx.turn_count >= 10 && newIntent === ctx.last_intent) {
    return true;
  }
  return false;
}

// In orchestrator:
if (detectLoop(ctx, toolUse.input.intent_slug)) {
  // Override Greeter's tool call — force escalate
  return processGreeterToolUse({
    name: 'escalate_to_human',
    input: {
      reason: 'anti_loop',
      summary: `User stuck on intent ${toolUse.input.intent_slug} for ${ctx.turn_count} turns`,
      urgency: 'medium',
    },
  }, ctx);
}
```

### 2.7 PR A4 acceptance criteria

- [ ] `GREETER_TOOLS_V5` defined with 4 tools, exact schemas above
- [ ] `tool_choice: { type: 'any' }` enforced
- [ ] `processGreeterToolUse()` handles all 4 tool branches
- [ ] Intent-resolver integration: `resolveIntent()` called, fallback URLs respected
- [ ] Click tracking wrapper applied to ALL outgoing URLs
- [ ] Anti-loop detection: 3 turns same intent → forced escalate
- [ ] Lang detection consumed: ctx.lang passed to resolveIntent
- [ ] Output schema migrated: `GreeterResultV5` replaces `GreeterResult`
- [ ] Backward compat shim if Booker still expects old schema
- [ ] Vitest tests: 1 test per tool branch + 2 anti-loop cases (min 6 new tests)

---

## (continued in §3 — System prompt v5)
