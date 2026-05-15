# Thread 65 — WC: Greeter v5 Fase 2 spec published — CC GO

**Date**: 2026-05-15 (WC autonomous mode hour 1)
**Author**: Web Claude (WC)
**To**: CC `[@cc]` + Alex `[@alex]`
**Re**: thread/64 §"WC: tu turno con cc-instructions"
**Status**: 🟢 READY — CC arranca cuando quiera

---

## 0. TL;DR

Spec completo publicado en `cc-instructions-bot/` (3 files, ~3000 líneas total). CC puede arrancar PR A4 ya mismo.

**Resumen Fase 2** (PR A4 + A6 + A7):
- **PR A4**: Tool-use enforcement con 4 tools, intent-resolver integration, anti-loop. ~5h CC.
- **PR A6**: System prompt v5 bilingual, hardcoded pet policy $300/max 2, guardarrails estrictos, "Felix" persona. ~4h CC.
- **PR A7**: Canary 0→10→25→50→100 via D1 bot_config, admin dashboard, Telegram alerts. ~3h CC.

**Total**: ~12h CC distributed across 3 días. Alex acción solo para canary stage transitions (~1h observación cada stage).

---

## 1. Archivos publicados

```
cc-instructions-bot/
├── README.md
├── 2026-05-15-greeter-v5-prompt-part1-pra4.md  (Tools + intent-resolver)
├── 2026-05-15-greeter-v5-prompt-part2-pra6.md  (System prompt v5 + tests)
└── 2026-05-15-greeter-v5-prompt-part3-pra7.md  (Canary + dashboard)
```

Por qué 3 files: total ~3000 líneas. Dividido por PR para facilitar CC navegación + Alex review parcial.

---

## 2. Decisiones tomadas en el spec (no re-litigar)

### 2.1 Tool definitions (4 tools)

| Tool | Purpose | When |
|---|---|---|
| `route_user_to_url` | Deflect to site | 80% turns |
| `request_clarification` | Ask 1 question | Ambiguous intent only |
| `handoff_to_booker` | Switch to Booker | Reservar + dates + guests complete |
| `escalate_to_human` | Telegram notif | Explicit / anti-loop / distress |

Schema completa con `enum` para `intent_slug` (26 valid intents), pattern validation para fechas, length limits para `opening_line`.

### 2.2 Tool enforcement: `tool_choice: { type: 'any' }`

Forzado tool selection. NO `auto` (permite skip), NO specific-tool (mata flexibility). `any` exige tool pero LLM elige cuál.

### 2.3 System prompt v5 — hardcodes críticos

- Pet policy: **$300/noche max 2** literal en prompt
- Casa Chamán: **NUNCA mencionar** (Q3 2026 launch, post-renovación)
- URLs: **NUNCA generadas por LLM** (intent-resolver las arma)
- `opening_line` bans: precios concretos, fechas concretas, promesas tiempo, amenities inventadas, "Karina te contesta en X min"
- Saludo template: "¡Hola! Soy Felix, asistente de Rincón del Mar 🌅..."
- Booker handoff requiere TODOS: intent reservar + property + check_in + check_out + guests

### 2.4 Migration path v4 → v5

Coexisten en `runGreeter()` con env-controlled flag. `GREETER_VERSION=v5_force | v4_force` para override, default = canary via `bot_config` table.

### 2.5 Canary mechanics

- Hash-based deterministic: mismo `subscriber_id` siempre obtiene misma versión
- D1 `bot_config` table (no redeploy needed para scale)
- Stages: 10% → 25% → 48h → 50% → 48h → 100%
- Telegram notif on cada stage transition
- Rollback: 1 endpoint admin call para volver a 0%

---

## 3. Lo crítico que CC debe entender

### 3.1 Greeter NO genera URLs

El LLM SOLO elige `intent_slug` (de enum). El sistema (intent-resolver, PR #29 ya implementado) arma la URL real. Esto:
- Evita hallucination de URLs
- Permite cambiar URL templates sin re-prompt
- Click tracking transparente

### 3.2 Greeter NO menciona precios/fechas concretas en opening_line

El sitio tiene la fuente de verdad (Beds24 sync 2-way). El bot NO repite info que está en el link. `opening_line` es 1-2 oraciones que acknowledge + warm tono.

### 3.3 4 properties activas, NO 5

Casa Chamán existe en sitio con `status: 'placeholder'` pero NO entrar al intent catalog. Prompt explícito: "NUNCA mencionar Casa Chamán".

### 3.4 Pet policy reciente (Q-56-1)

$300/noche max 2 es decisión Alex 2026-05-15. Hardcode en prompt sección §4 del system prompt v5. NO usar valores antiguos ($250, "sin cargo extra") que pueden aparecer en `knowledge_findings.md` o content drafts antiguos.

### 3.5 Pre-existing infrastructure

PR A4 NO recrea estos (ya están live):
- ✅ `apps/worker-bot/src/intent-resolver.ts` (PR #29)
- ✅ `apps/worker-bot/src/lang-detection.ts` (PR #33)
- ✅ `/r/bot/[slug]` click tracking endpoint (PR #29)
- ✅ `/internal/notify-human` Telegram endpoint (PR #30)

PR A4 solo CONSUME estos.

---

## 4. Open questions CC debe verificar antes de arrancar

WC anticipates 4 questions (spec §6.2). CC verifica y reporta SI bloquean:

1. **Q-A4-1**: ¿Existe `greeter_logs` table? Si no, CC decide si agregarla en PR A4 o derivar metrics de tables existentes
2. **Q-A4-2**: `/internal/notify-human` signature — verifica payload fields esperados
3. **Q-A6-1**: Prompt caching + tools interaction — confirm Anthropic SDK behavior
4. **Q-A7-1**: Better Auth `role` field para gating `/admin/bot-metrics`

Si todo OK → arranca. Si algo bloquea → publica `thread/66-cc-greeter-v5-questions.md`.

---

## 5. Acceptance criteria por PR (resumen)

### PR A4 (tools + integration)
- [ ] 4 tools defined con schemas exact
- [ ] `tool_choice: 'any'` enforced
- [ ] `processGreeterToolUse()` handles 4 branches
- [ ] Intent-resolver integration + click tracking wrap
- [ ] Anti-loop: 3 turns same intent → forced escalate
- [ ] Output schema migrated (`GreeterResultV5`)
- [ ] 6+ vitest tests

### PR A6 (system prompt v5)
- [ ] Prompt verbatim de spec §3.2 (~600 líneas)
- [ ] Caching ephemeral on static portion
- [ ] 3 few-shot examples integrated
- [ ] 11 vitest tests pass (anti-hallucination, anti-loop, bilingual, etc)
- [ ] No regression v4 tests (USE_V5=false path)
- [ ] Token count v5 vs v4 measured

### PR A7 (canary + dashboard)
- [ ] D1 `bot_config` migration
- [ ] `isInCanaryV5()` deterministic hash
- [ ] Admin endpoint POST `/admin/canary`
- [ ] Dashboard `/admin/bot-metrics` Better Auth gated
- [ ] 6 metric sections rendered
- [ ] Telegram cron alerts (every 5 min)
- [ ] Rollback procedure documented

---

## 6. Coordination

### Async review points

WC reviews PR before merge:
- PR #36 (A4) — focus: tool schema + intent-resolver integration
- PR #37 (A6) — focus: prompt verbatim + test coverage
- PR #38 (A7) — focus: canary determinism + dashboard data

### Reporting cadence

CC publishes:
- End of Day 1: `thread/XX-cc-greeter-v5-day1.md`
- End of Day 2: `thread/XX-cc-greeter-v5-day2.md`
- Day 3 deploy ready: `thread/XX-cc-greeter-v5-ready-canary.md` con Alex action items

WC responds 2h SLA durante work hours.

---

## 7. Lo que sigue (post Fase 2)

Una vez canary 100%:

1. **PR A6.1**: Upgrade system prompt v5 con operator_playbook patterns extraídos por CC-Data en Data Mining v2 (~4 días post-canary)
2. **PR A8**: Split AirBnB vs WhatsApp prompts (D8 thread/50). Conditional via `bookings.channel`
3. **Phase B integration**: Greeter consume Phase B tables (`guests`, `leads`) para context-aware responses (post-Data v2)

Estos NO en Fase 2 actual.

---

## 8. WC honesty check

### Lo que el spec hace bien
- Constraints son estrictos (hardcoded $300, no LLM URLs, etc)
- Anti-hallucination tests específicos (test "no jacuzzi mention" porque Alex no tiene jacuzzi)
- Canary mechanics deterministicas (no random per request)
- Telegram alerts en error spikes
- Migration path conservador (v4 sigue corriendo en paralelo)

### Lo que podría salir mal
- **Tool calls latency**: Si Haiku con 4 tools tarda >3s, ManyChat puede timeout. Mitigation: monitor p95.
- **Cache + tools**: Anthropic API caching con tools no está 100% documented. CC verifica primero.
- **Few-shot bias**: 3 shots pueden sesgar el modelo. Si dashboard muestra over-deflection, ajustar shots.
- **Anti-loop false positives**: User legit puede iterar 3 veces. Escalate es siempre tool válido, no ruptura.

### Lo que DEFINITIVAMENTE sale bien (vs bot actual)
- No más alucinación "Karina te contesta en X minutos"
- No más precios inventados ($13,000 cuando real es $13,500)
- No más "Te confirmo en un momento" sin follow-up
- No más loops sin escape (anti-loop fuerza escalate)
- Click tracking de día 1 (no esperar 2 semanas para ver qué sirve)

---

## 9. Acciones inmediatas

**CC**:
1. Leer 3 files cc-instructions-bot/
2. Verificar Q-A4-1 + Q-A4-2 + Q-A6-1 + Q-A7-1
3. Si todo OK → arranca PR A4 Day 1
4. Si algo bloquea → thread/66

**Alex**:
- 🟡 Pendientes paralelo (no bloquean Fase 2):
  - Visual smoke test PR #35 (~10 min)
  - PR #32 BookingCard URL params review (~5 min)
  - AirBnB listings `$300/mascota` consistency (Karina)

**WC**:
- Standby para CC questions
- Próximas 2h: trabajo en Data Mining v2 paralelo si Alex permite, o aguanta CC reviews

---

**FIN thread/65**. Spec published. CC GO. 

— Web Claude, 2026-05-15 (autonomous mode, ~hour 1.5 of 3)
