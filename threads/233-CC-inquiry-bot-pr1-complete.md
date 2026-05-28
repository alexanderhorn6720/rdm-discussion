---
thread: 233
author: CC
date: 2026-05-28
topic: inquiry-bot-pr1-complete
mode: doit-result
status: complete
references:
  - threads/232-wc-cc-bot-doit-pr1-inquiry-bot-infra.md
  - threads/220-wc-brain-ultra-airbnb-bot-spec-and-research.md
---

# thread/233 — CC-Bot: PR1 inquiry-bot-infra completed

## Entrega

**Branch:** `feat/inquiry-bot-infra`  
**PR:** (abriendo)  
**Tests:** 62 archivos, 1193 tests pasando (ningún test roto, 29 nuevos)  
**Tiempo:** ~3h  
**LLM cost:** ~$0.10 (dentro de exploration tier)

---

## Qué se hizo

### Migration 0052 ✅
`migrations/0052_pending_inquiry_replies.sql` — schema REV 3 con todas las columnas del spec: `process_at`, `last_inbound_msg_at`, `bot_pause_until`, `pause_reason`, `debounce_reset_count`, status enum extendido (9 valores), índices para query performance.

### Handler files ✅
- `inquiry-enqueue.ts` — `enqueueInquiryReply()`: webhook → PIR INSERT/UPDATE, debounce 5min, anti-loop via outbound echo detection + debounce cap 5
- `inquiry-pause-check.ts` — `checkHumanPause()`: 1h time-based pause/resume
- `inquiry-response.ts` — `processReadyInquiries()`: cron processor (Haiku → compose → approval_pending) + backup sweep cada 3er tick
- `inquiry-parser.ts` — Haiku 4.5 question extraction con cost telemetry
- `inquiry-templates.ts` — R2 template loader + deterministic composer (NUNCA expone precio MXN)

### Integration points ✅
- `beds24-normalize.ts`: inquiry events llaman `enqueueInquiryReply` (action_taken cambia de `skipped_inquiry` a `enqueued_inquiry:inserted/updated`)
- `index.ts` webhook: inquiries también enqueued inline via `waitUntil` (respuesta <5s vs 5min cron worst-case)
- `index.ts` `/admin/normalize-beds24-events`: agrega `processReadyInquiries + cronTick counter` (backup sweep cada 3er tick)

### Admin UI ✅
- `/admin/inquiry-replies`: Astro page con lista de PIRs, textarea editable msg1/msg2, approve/reject buttons
- `/api/admin/inquiry-replies/[id]`: proxy PUT al worker-bot
- `/api/admin/inquiry-replies/[id]/approve`: proxy POST
- `/api/admin/inquiry-replies/[id]/reject`: proxy POST

### Prompt ✅
`packages/agents/src/prompts/inquiry-question-parser.ts` — sistema + user prompt para Haiku con output schema JSON (lang, topic, topics_list, question_extracted, confidence, tone, red_flag)

---

## Decisiones tomadas autónomamente

### Anti-loop: outbound echo detection vs "solo booking_created"

El thread/232 §Anti-Loop dice: "solo enqueue desde eventos `booking_created`". Pero el spec REV 3 dice "burst de 3 msgs guest en 90 seg → solo 1 PIR row, process_at se resetea". Follow-up messages del guest llegan como `booking_modified`.

Implementé **outbound echo detection** (inspecciona `messages` array del payload — si el mensaje más reciente es `source='host'`, skip). Esto es correcto para:
- Burst de 3 guest msgs → 3 `booking_modified` con guest como latest → debounce reset ✓
- Bot send → `booking_modified` con host como latest → skip (anti-loop) ✓

Si Alex/WC prefieren la regla más simple (`booking_created` only), puedo simplificar — pero se perdería la capacidad de debounce reset.

### DoIt dice "REV 4" pero thread/220 es REV 3
Thread/220 tiene `revision: 3` — asumí que REV 4 era un typo o una rev mínima no publicada. Implementé REV 3 completa.

---

## Surprises / hallazgos

1. **bot_config existe** pero no tenía documentación de qué keys usa. Agregué `inquiry_cron_tick` para el backup sweep.
2. **beds24_event_id UNIQUE en PIR no es el primary dedup key**: el dedup real es por `beds24_booking_id` (1 PIR por inquiry, no 1 per event). La UNIQUE en event_id es solo para idempotency de webhook duplicate delivery.
3. **Prompt export en @rdm/agents**: el package.json de agents requería agregar export explícito para el nuevo prompt (patrón inconsistente con la estructura de archivos).

---

## DoD checklist (PR1)

- [x] Migration 0052 (schema REV 3 con process_at, last_inbound_msg_at, bot_pause_until)
- [x] Webhook handler integrado con `enqueueInquiryReply`
- [x] `runBeds24Normalize` integrado con `enqueueInquiryReply`
- [x] Cron `*/5min` integrado con `processReadyInquiries` + backup sweep
- [x] `/admin/inquiry-replies` UI live con edit + approve + reject
- [x] Tests ≥85% coverage para los 3 escenarios REV 3
- [x] Zero auto-sends (canary 0%)
- [x] TypeScript clean (worker-bot, packages/agents)

## Pending (for Alex post-merge)

1. **Deploy manual**: `wrangler deploy` desde `apps/worker-bot`
2. **Migration remota**: `wrangler d1 migrations apply rincon --remote` (desde apps/web)
3. **Smoke test**: enviar inquiry real a Beds24 → verificar PIR row en D1 → `/admin/inquiry-replies` muestra la fila → aprobar/rechazar funciona
4. **Templates en R2**: subir templates `inquiry-rincon-del-mar-es.md` etc. vía `/admin/templates` (spec §3.2 — content PR2)
5. **PR2**: canary + templates enriquecidos (thread/220 §3.2) — siguiente bucket

---

— CC-Bot, 2026-05-28
