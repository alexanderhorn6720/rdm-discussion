---
id: 220
author: wc
topic: airbnb-inquiry-bot-spec-and-customer-management-brain-ultra
status: ready-for-doit
mode: brain-ultra
created_at: 2026-05-27
updated_at: 2026-05-28
revision: 4
doit_task: thread/232 (renumbered from 222 post payment-flow merge)
references:
  - threads/33-guest360-architecture-phase-b-plan.md
  - threads/35-cc-templates-system-for-wc.md
  - threads/89-cc-event-bus-spec.md
  - threads/107-cc-inquiries-auto-close.md
  - threads/110-112-messenger-outbound-feature.md
  - threads/196-inbox-redesign.md
  - threads/217-greeter-v7.1-mega-spec.md
  - threads/232-wc-cc-bot-doit-pr1-inquiry-bot-infra.md
  - knowledge/airbnb-templates-current-2026-05-13.json
  - knowledge/airbnb-listing-fields-current-2026-05-13.md
  - knowledge/airbnb-emoji-blocklist-2026-05-14.md
  - knowledge/whatsapp-kits-current-2026-05-13.md
prs_proposed: PR1 (inquiry-bot infra), PR2 (template + canary), PR3 (lifecycle activation)
estimated_effort: 24-32h CC + 4-6h Alex/Karina (templates) + canary 2-3 semanas
---

# thread/220 — Brain ultra: Airbnb Inquiry Bot + Customer Management

> **Status:** REV 4 — Ready for DoIt CC (task = thread/232). Arquitectura cerrada + ajustes post payment-flow merge.
>
> **Changelog:** REV 1 = brain ultra inicial. REV 2 = corrección precio. REV 3 = arquitectura webhook+debounce+pause. **REV 4 = ajustes de integración tras merge payment-flow (migration 0052, integration point preciso, anti-loop guard).**

---

## §0 · TL;DR ejecutivo

**El estado actual:** Beds24 recibe inquiries Airbnb perfectamente (90 en últimas semanas). El sistema D1 las almacena en `beds24_events`. **El bot las ve y NO hace nada** — guest queda esperando respuesta de Alex/Karina manual.

**70% de la infraestructura ya existe.** El gap real son ~12-16h CC para el orchestrator.

**Arquitectura cerrada (REV 3):**

1. **Bot único** con context switch por canal
2. **Webhook push + 5min debounce window** (reset on update si guest manda más msgs)
3. **Cron `*/5min` existente reutilizado** (NO agregar 5to cron)
4. **Human pause time-based 1h:** si Karina/Alex respondió, bot pausa. Si no hay más mensajes humanos en 1h, bot retoma
5. **PR1 → PR2 → PR3** en 4-6 semanas, canary scaling

**Costo:** 24-32h CC, <$5/mes Anthropic, riesgo bajo.

---

## §0.1 · 🔴 CORRECCIÓN REV 2 — `payload.booking.price` NO es lo que ve el guest

El `price` en payload Beds24 es **meta revenue NET** (lo que cobra Alex después de commission Airbnb + taxes guest paga). **NO** es el "Total" del botón Airbnb.

**Verificado con D1:**

| Tipo evento | `price` | `commission` | Interpretación |
|---|---|---|---|
| Inquiry Ana Karen | $28,789.02 | 0 | NET sin desglose |
| Booking confirmado | $6,117.84 | $948.27 | NET + commission separado |
| Lo que ve el guest | **NO viene** | — | Service fee + taxes locales NO en payload |

**Implicación:** bot NUNCA muestra número MXN. Lenguaje canónico: "la tarifa que ya viste en Airbnb...".

---

## §0.2 · 🟢 ARQUITECTURA CERRADA REV 3 — webhook + debounce + 1h pause

**Decisiones de Alex (2026-05-27):**

| # | Decisión | Valor | Razón |
|---|---|---|---|
| 1 | Trigger | **Webhook push + 5min debounce** | Industry standard (Hostaway, Hospitable, Uplisting). Captura 70% bursts (data D1) |
| 2 | Skip si host respondió | **Sí + audit** | Industry standard, evita doble respuesta |
| 3 | Human pause logic | **Time-based 1h** | "Si Karina/Alex respondió, bot pausa 1h. Si no hay más mensajes humanos en 1h, bot retoma normal." Pragmatic, simple, sin LLM extra call |
| 4 | Cron strategy | **Reutilizar `*/5min` existente** | NO agregar 5to cron. Unified worker pattern |
| 5 | Backup sweep | **Cada 3ra ejecución (`*/15min`)** | Defense in depth si webhook se pierde |

**Reasoning H2 1h pause vs H3 LLM re-eval:**
- Alex constraint: "Realmente no quiero que Kari y yo intervengan, serían excepciones por mensajes críticos"
- H2 1h: simple, predecible, sin LLM extra call
- Si guest sigue conversación 1h+ después → bot retoma (asume host no estaba siguiendo)
- Si guest sigue conversación en <1h → respeta intervención activa de Karina

**Industry validation:** Uplisting/Hospitable docs textuales sobre delay configurable + skip si host respondió.

---

## §0.3 · 🟠 AJUSTES REV 4 — integración tras merge payment-flow (CRÍTICO para CC)

Mientras se escribía REV 1-3, una cadena P0 payment-flow (threads 222/224/226/228/230, PRs #194-#198) **mergeó a main** (2026-05-27 21:39 → 2026-05-28 03:25). Verificado contra repo real. 3 ajustes obligatorios:

### Ajuste 1 — Migration 0051 → **0052**

PR #194 creó `migrations/0051_bookings_beds24_booking_id.sql` (`ALTER TABLE bookings ADD beds24_booking_id`). El número 0051 **ya está tomado**.

→ La tabla `pending_inquiry_replies` usa **migration 0052** (CC debe audit `ls migrations/ | sort -V | tail` y confirmar siguiente libre). Todas las referencias "0051" en §3.1/§10/§13 abajo se leen como **0052**.

### Ajuste 2 — Integration point PRECISO = `runBeds24Normalize`

REV 3 decía genéricamente "webhook handler donde hace `action_taken='skipped_inquiry'`". Verificado: ese punto es la función **`runBeds24Normalize` en `apps/worker-bot/src/beds24-normalize.ts`**, no el webhook HTTP directo.

Flujo real:
```
Beds24 webhook → INSERT beds24_events (action_taken=NULL)
Cron → runBeds24Normalize() → SELECT events action_taken IS NULL
  → parseBeds24Booking(payload)   ← REUTILIZABLE, ya entrega ParsedBooking completo
  → shouldNormalize(status):
      'inquiry' → { normalize:false, reason:'skipped_inquiry' }
      → markEvent('skipped_inquiry')   ← INYECTAR enqueueInquiryReply ANTES de esto
```

Integration: en `runBeds24Normalize`, cuando `decision.reason === 'skipped_inquiry'` && `parsed.channel === 'airbnb'` && `ev.event_type === 'booking_created'` → llamar `enqueueInquiryReply(env, parsed, ev)` reutilizando el `parsed` existente (NO reparsear payload).

### Ajuste 3 — 🔴 ANTI-LOOP GUARD obligatorio (incident 2026-05-18)

Documentado en `beds24-normalize.ts`: **cada mensaje que el bot manda a Beds24 dispara un `booking_modified` webhook de vuelta (~3s después).** En mayo esto causó 17 welcomes duplicados antes de detectarse.

Mi inquiry bot MANDA mensajes → mismo riesgo. Guard obligatorio:

1. **Solo enqueue desde `event_type='booking_created'` + `status='inquiry'`.** NUNCA desde `booking_modified` (ese es el eco del propio bot).
2. **Dedup por `booking_id`:** si ya existe PIR para ese `beds24_booking_id` con status NOT IN ('expired','rejected') → NO crear nuevo PIR. Solo UPDATE debounce si sigue en `awaiting_processing`.
3. **Idempotencia `beds24_event_id` UNIQUE** ya cubre "mismo evento 2x", pero el dedup por booking_id cubre "evento distinto, mismo booking" (el eco).

Patrón de referencia: `upsertBooking` en el mismo archivo usa `ON CONFLICT DO UPDATE` preservando automation state justamente por este incident. Mismo principio.

### Ajuste 4 — NO tocar código payment-flow

PRs #194-#198 tocaron pesado: `webhook-mp.ts`, `beds24-direct.ts`, `beds24-release.ts`, `worker-pago/crons.ts`. **Todo eso es P0 recién mergeado — fuera de scope, NO tocar.** El inquiry bot vive en worker-bot, no en worker-pago.

**Nota patrón Beds24 (informativo):** PR #197 cambió modify de `PATCH /v2/bookings/{id}` (no existe) a `POST /v2/bookings [{id,status}]`. Para PR1 NO aplica (el inquiry bot solo manda messages vía `POST /v2/bookings/messages`, no modifica bookings). Pero si CC ve PATCH en código viejo, ignorar — el patrón vigente es POST.

---

## §1 · Hallazgo principal — el último mile de Phase B.2

### Plan original B.2 (thread/33, mayo 12) → estado actual

El thread/33 detalló Phase B.2 con 16h CC estimadas. Lo que se construyó vs lo que falta:

| Sub-task del plan B.2 | Status |
|---|---|
| Migrations 0014-0017 (guests + leads + bookings + guest_events) | ✅ aplicadas |
| Lead ingestion handler | ⚠️ parcial — `bot_messages_inbox` recibe pero no crea leads automáticos |
| Auto-respond inquiry handler | 🔴 NO existe |
| Template R2 `inquiry-welcome-<roomId>.md` | 🔴 NO existe en R2 |
| AI question detection | ⚠️ existe `admin-suggest-reply.ts` (manual) |
| Auto follow-ups cron (T+3, T+7, T+14) | 🔴 NO existe |
| Pre-approval detection | 🔴 NO existe |

**Diagnóstico:** B.2 quedó "pausado a 70% completion". Falta solo el orchestrator.

---

## §2 · Discovery summary — la inquiry de Ana Karen como caso real

Booking ID 87381196, RoomId 78695 (RdM), 16 adultos, arrival 2026-08-21. Guest: "Ana Karen". `lang: 'en'` pero escribió ES.

**Precio:** `price: 28789.02` (net Alex). Total que ve el guest NO viene.

Mensaje guest: "Hola Alexander, estoy interesada en la renta de este lugar vi que ofrecen servicio de chef ¿el costo total incluye los víveres para la comida?"

**Alex respondió 2h después.** Industry data: <1h response = +25% conversion. Target post-PR2: <5 min.

### Lo que detecta el sistema actual

| Campo | Sistema sabe | Comentario |
|---|---|---|
| Es inquiry, no booking | ✅ | `status='inquiry'` |
| Villa específica | ✅ | `roomId=78695` → RdM |
| Tamaño grupo (16) | ✅ | Trigger `extra-guests` capture |
| Pregunta concreta del huésped | ⚠️ texto presente | NO parseado |
| Idioma real del huésped | ❌ | `lang='en'` mintió |
| **Precio que ve el guest** | ❌ | **NO viene en payload** |

---

## §3 · Spec del bot — PR1, PR2, PR3 (REV 3, ajustes REV 4 en §0.3)

### §3.1 · PR1 — Infraestructura inquiry-response

**Branch:** `feat/inquiry-bot-infra`
**Effort:** 10-14h CC
**Risk:** muy bajo
**DoIt task:** thread/232
**⚠️ Migration:** **0052** (ver §0.3 Ajuste 1 — 0051 ya tomado por payment-flow)

#### Archivos a crear

```
apps/worker-bot/src/inquiry-response.ts            // Handler principal (processReadyInquiries)
apps/worker-bot/src/inquiry-enqueue.ts             // enqueueInquiryReply (desde runBeds24Normalize)
apps/worker-bot/src/inquiry-templates.ts           // Template loader + composer
apps/worker-bot/src/inquiry-parser.ts              // Haiku question extraction
apps/worker-bot/src/inquiry-pause-check.ts         // 1h pause logic
packages/agents/src/prompts/inquiry-question-parser.ts
migrations/0052_pending_inquiry_replies.sql        // ⚠️ 0052 NO 0051
apps/web/src/pages/admin/inquiry-replies.astro     // Approval UI
apps/web/src/pages/api/admin/inquiry-replies/[id].ts
apps/worker-bot/tests/inquiry-response.test.ts
apps/worker-bot/tests/inquiry-parser.test.ts
apps/worker-bot/tests/inquiry-pause.test.ts
```

#### Migration 0052 (schema)

```sql
CREATE TABLE pending_inquiry_replies (
  id TEXT PRIMARY KEY,                              -- ULID
  beds24_event_id INTEGER NOT NULL UNIQUE,          -- idempotency key
  beds24_booking_id INTEGER NOT NULL,               -- anti-loop dedup key (ver §0.3 Ajuste 3)
  room_id INTEGER NOT NULL,
  channel TEXT NOT NULL DEFAULT 'airbnb',

  -- Guest snapshot
  guest_first_name TEXT,
  guest_message_text TEXT NOT NULL,
  guest_message_lang_detected TEXT,
  arrival TEXT,
  departure TEXT,
  num_nights INTEGER,
  num_adults INTEGER,
  meta_revenue_net_mxn REAL,                        -- payload.booking.price (INTERNAL ONLY)

  -- Question extraction (Haiku)
  question_detected INTEGER NOT NULL DEFAULT 0,
  question_topic TEXT,
  question_topics_list TEXT,
  question_extracted TEXT,
  question_confidence REAL,
  question_tone TEXT,
  red_flag TEXT,

  -- Composition
  template_r2_key TEXT,
  template_content_snapshot TEXT,
  message_1_text TEXT,
  message_2_text TEXT,

  -- LLM cost
  llm_model TEXT,
  llm_tokens_in INTEGER,
  llm_tokens_out INTEGER,
  llm_cache_hit INTEGER DEFAULT 0,
  llm_cost_usd REAL,

  -- Debounce + pause
  process_at INTEGER NOT NULL,                      -- NOW + 5min on insert
  last_inbound_msg_at INTEGER NOT NULL,             -- resets process_at on each new guest msg
  debounce_reset_count INTEGER NOT NULL DEFAULT 0,  -- cap 5 (anti spam, ver §11)
  bot_pause_until INTEGER,
  pause_reason TEXT,                                -- 'host_intervened' | 'manual_pause' | 'red_flag'

  -- Status lifecycle
  status TEXT NOT NULL DEFAULT 'awaiting_processing' CHECK (status IN (
    'awaiting_processing', 'approval_pending', 'approved', 'sent',
    'rejected', 'expired', 'auto_send_eligible', 'superseded_by_human', 'paused'
  )),
  reviewed_by TEXT,
  reviewed_at INTEGER,
  rejection_reason TEXT,

  -- Send result
  sent_at INTEGER,
  send_attempts INTEGER NOT NULL DEFAULT 0,
  send_error_last TEXT,
  external_message_id_1 TEXT,
  external_message_id_2 TEXT,

  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_pir_status ON pending_inquiry_replies(status, process_at);
CREATE INDEX idx_pir_room ON pending_inquiry_replies(room_id, status);
CREATE INDEX idx_pir_ready ON pending_inquiry_replies(process_at)
  WHERE status IN ('awaiting_processing', 'paused');
CREATE INDEX idx_pir_booking ON pending_inquiry_replies(beds24_booking_id, created_at);
```

#### Handler architecture (3 funciones)

**`enqueueInquiryReply(env, parsed, ev)`** — llamada desde `runBeds24Normalize` (NO webhook HTTP)

```
1. Recibe `parsed` (ParsedBooking ya parseado) + `ev` (beds24_events row)
2. Filter: parsed.channel === 'airbnb' && roomId !== 679176 (Casa Chamán) && ev.event_type === 'booking_created'
3. Anti-loop dedup (§0.3 Ajuste 3):
   - Existe PIR con mismo beds24_booking_id Y status NOT IN ('expired','rejected')?
     - SÍ + status='awaiting_processing' → UPDATE process_at = NOW+5min, last_inbound_msg_at=NOW, debounce_reset_count++
     - SÍ + otro status → SKIP (ya en proceso o respondido)
     - NO → INSERT new PIR (process_at = NOW+5min, status='awaiting_processing')
4. NO procesar acá. Solo enqueue.
```

**`processReadyInquiries(env)`** — llamada por cron `*/5min` existente

```
1. SELECT PIR WHERE status='awaiting_processing' AND process_at <= NOW LIMIT 20
2. For each:
   a. checkHumanPause → si paused, status='paused', extend bot_pause_until, skip
   b. Si host respondió DESPUÉS de last_inbound_msg_at → status='superseded_by_human', audit, skip
   c. Haiku parse → load template R2 → compose 2 msgs
   d. status='approval_pending' (PR1) | canary % (PR2)
3. Backup sweep cada 3er tick: beds24_events status='inquiry' action_taken='skipped_inquiry' sin PIR → enqueue
```

**`checkHumanPause(env, pir)`** — 1h time-based

```
1. SELECT bot_messages_inbox WHERE booking_id=pir.beds24_booking_id AND source='host'
   AND message_time > pir.last_inbound_msg_at - 3600 ORDER BY message_time DESC LIMIT 1
2. NO host msg → {paused:false}
3. host msg + elapsed < 1h → {paused:true, pause_until: last_host+3600, reason:'host_intervened'}
4. host msg + elapsed >= 1h → {paused:false, audit:'human_intervention_expired'}
```

**Integration point (§0.3 Ajuste 2):** en `runBeds24Normalize`, branch `decision.reason==='skipped_inquiry'` + airbnb + booking_created → `enqueueInquiryReply` antes de `markEvent`.

#### Cron schedule (sin agregar nuevo)

| Cron actual | Frecuencia | Handler nuevo |
|---|---|---|
| `*/5 * * * *` (polling, llama runBeds24Normalize) | Cada 5 min | **+ processReadyInquiries + backup sweep cada 3er tick** |

#### Inquiry question parser prompt (Haiku 4.5)

Output JSON: `lang` (es|en|other), `lang_confidence`, `topic` (chef|veveres|precio|mascotas|amenidades|ubicacion|capacidad|evento|fechas|transporte|actividades|ninguna|multiple), `topics_list`, `question_extracted`, `question_confidence`, `tone` (casual|formal|urgent|vip), `red_flag` (null|off_platform_attempt|negotiation_aggressive|complaint).

#### Decisiones cerradas PR1

| Decisión | Valor |
|---|---|
| Idempotencia | `beds24_event_id` UNIQUE + dedup por `beds24_booking_id` (anti-loop) |
| Trigger | Inyectado en `runBeds24Normalize` branch skipped_inquiry, NO webhook HTTP |
| Solo booking_created | NUNCA enqueue desde booking_modified (anti-loop, §0.3) |
| Debounce reset | Cada guest msg → process_at = NOW+5min, cap 5 resets |
| Cron | Reutilizar `*/5min` existente |
| Backup sweep | Cada 3er tick |
| Human pause | Time-based 1h |
| Window | últimos 24h |
| Estado inicial PR1 | awaiting_processing → approval_pending (nunca auto-send) |
| Idioma respuesta | El del mensaje guest, NO payload.lang |
| Casa Chamán | Filtrar roomId 679176 |
| Precio en mensaje | NUNCA mostrar número |
| parseBeds24Booking | Reutilizar el existente, NO reparsear |

#### Tests PR1 (12 incluido anti-loop)

- drafts response for new inquiry with question
- skips inquiry without guest message
- detects language correctly when payload.lang != actual
- extracts topics correctly
- respects 24h window
- idempotente (mismo beds24_event_id → 1 PIR)
- **anti-loop: booking_modified posterior del mismo booking → NO crea segundo PIR**
- handles malformed payload gracefully
- skips Casa Chamán
- template renders NEVER contains explicit MXN number
- burst 3 msgs en 90 seg → 1 PIR, process_at se resetea (cap 5)
- host respondió 30min antes → PIR paused, bot_pause_until = host+1h
- host respondió hace 2h sin actividad → bot retoma approval_pending
- backup sweep detecta beds24_event sin PIR → enqueue

#### DoD PR1

- Migration 0052 applied local D1 (CC) → remote pendiente Alex
- Integration en runBeds24Normalize (branch skipped_inquiry + airbnb + booking_created)
- Anti-loop dedup funcional
- Cron processReadyInquiries + backup sweep
- Approval UI live con edit + approve + reject
- Smoke test debounce + pause + anti-loop
- Tests ≥85% coverage, greeter sin regresión
- Zero auto-sends

---

### §3.2 · PR2 — Templates Phase B.2 enriched + canary

**Branch:** `feat/inquiry-templates-canary`
**Effort:** 8-10h CC + 4-6h Alex/Karina
**Risk:** medio
**Dependency:** PR1 merged

#### Templates en R2 — 8 totales (4 villas × ES+EN)

`inquiry-rincon-del-mar-es.md`, `-en.md`, `inquiry-las-morenas-es.md` (chef OPCIONAL), `-en.md`, `inquiry-combinada-es.md` (58-60 pax), `-en.md`, `inquiry-huerta-cocotera-es.md` (sin chef default), `-en.md`.

#### Template RdM ES — enriched (sin cambios REV 4)

2 mensajes `{{MSG_2_BREAK}}`. Placeholders: `{guestFirstName}`, `{numAdults}`, `{nightsCount}`, `{questionAnswer}`.

**Mensaje 1 (<500 chars):**
```
¡Hola {guestFirstName}! 👋

{questionAnswer}

En un momento te mando la propuesta completa para los {numAdults} huéspedes que mencionaste. 🌊
```

**Mensaje 2 (<2000 chars):**
```
🏖 Rincón del Mar — para {numAdults} personas, {nightsCount} noches

Es la villa con chef incluido del grupo. Apapacha total desde que llegan.

✅ Lo que ya está incluido en la tarifa de Airbnb:
• Chef Celene + cocinera + mozo (3 personas a su servicio)
• Desayuno, comida y cena preparada
• Bebidas en palapa-bar frente al mar
• Limpieza diaria · WiFi · A/C todas las habs
• 6 habitaciones · 18 camas · 6.5 baños

📍 Pie de playa · zona tranquila
Pacífico al frente. Lejos del bullicio de la bahía pero cerca del malecón si quieren cenar fuera.

💰 Cómo funciona la cuenta
• La tarifa que ya viste en Airbnb cubre la villa completa con el equipo de chef
• Personas extras (hasta 30): $300/noche c/u, paga al llegar
• Víveres: cuenta aparte transparente. Promedio $250-280/persona/noche

🛎 Servicios opcionales con costo aparte
• Yates, snorkel, pesca — coordino yo todo
• Masajes en sitio con Michel
• Paquete bodas/eventos formales $1,400/persona

👉 Mirá las más de 168 reseñas ⭐ 4.84 en mi perfil:
airbnb.mx/users/95731371/listings

Confirmás {numAdults} huéspedes o vienen más? Cualquier duda más, escribíme.

— Alexander 🏖
```

#### Composer `{questionAnswer}` — determinista

```
chef     → "El servicio de chef SÍ está incluido en la tarifa que ya viste en Airbnb (Chef Celene + cocinera + mozo)."
veveres  → "Los víveres NO están incluidos en la tarifa de Airbnb — esos los compramos nosotros, costo transparente. Promedio $250-280/persona/noche."
precio   → "La tarifa que ya viste en Airbnb cubre la villa completa con el equipo de chef. Aparte: personas extras (>16) a $300/noche y los víveres."
mascotas → "Aceptamos hasta 2 mascotas por reservación, cargo único de $300 MXN por estancia (no por noche)."
evento   → "¡Felicidades por el evento! Para bodas/XV años manejamos paquete de $1,400/persona, mínimo 40 invitados."
default  → "Muchas gracias por tu pregunta. Te respondo a detalle en el siguiente mensaje."
```

#### Canary scaling plan

| Fase | % auto-send | Duración | Gate |
|---|---|---|---|
| 0% | 0% approval_pending | Indefinido | PR1 mergeado |
| Smoke | 1 manual | 24h | Alex aprueba |
| 10% | 1 de 10 | 7 días | <2 false positives |
| 25% | 1 de 4 | 7 días | <5% rejection |
| 50% | mitad | 14 días | <5% issues |
| 100% | todas | — | — |

High-stake (evento/complaint/off-platform) → siempre approval_pending + Telegram Karina. Confidence <0.5 → approval_pending.

#### Eval cases PR2 (12)

iq001 Ana Karen | iq002 EN mascotas | iq003 sin pregunta | iq004 wedding high-stake | iq005 off-platform | iq006 complaint | iq007 multiple | iq008 precio NO inventa número | iq009 negotiation | iq010 idioma payload incorrecto | iq011 host respondió → paused | iq012 host hace 2h → bot retoma.

#### DoD PR2

- 8 templates R2
- 12 eval ≥90% pass
- Canary logic + smoke 10%
- Telegram alert high-stake
- Worker deploy manual
- Karina training 15 min

---

### §3.3 · PR3 — Lifecycle post-booking activation

**Branch:** `feat/lifecycle-activation`
**Effort:** 6-10h CC
**Risk:** medio-alto
**Dependency:** PR2 canary 100% sustained 14 días

Handlers ya existen (`scanForWelcome`, `runPreArrivalScan`, `runPostStay`). Falta: 32 templates R2 + activar `MESSENGER_OUTBOUND_ENABLED='true'` + canary + pause logic 1h aplicada.

Templates: `welcome-`, `pre-arrival-t7-`, `pre-arrival-t1-`, `post-stay-review-` × 4 villas × 2 lang = 32. ~4-6h Alex/Karina.

Decisiones: activación manual `wrangler secret put`, canary 0→100% 4 semanas, welcome first post-stay last, daily digest 09:00, quiet hours 22:00-08:00, pause 1h.

---

## §4 · Attachments

| Channel | Tipos | Size |
|---|---|---|
| Airbnb | JPG, GIF, PNG | 2 MB |
| Vrbo | PDF, JPG, GIF, PNG | 2 MB |
| WhatsApp BSP | JPG, PNG, PDF, MP4, audio | 16 MB |

**NO PDFs en Airbnb.** Defer image attachments a post-PR3.

---

## §5 · Bot único vs separado

**Voto WC: Bot único con context switch.** KB 85% iguales, `sendMessageRouted` ya abstrae channel. Greeter + Inquiry + Lifecycle + Karina Suggest comparten infra.

---

## §6 · Best practices — industry validation

| Plataforma | Trigger | Delay | Human handoff |
|---|---|---|---|
| Uplisting | Webhook | 0-60 min config | Skip si host respondió |
| Hospitable | Webhook | 0-60 min config | Skip si host respondió |
| Hostaway | Webhook | Config | Cancel + reprocess si guest msg |
| RDM (spec) | Webhook + 5min debounce | 5min | 1h time-based unpause |

Métricas: <1h response = +25% conversion. Target RDM <10min = mejora 12x.

---

## §7 · Creatividad (sin cambios)

15 ideas. Top 3: upsells dinámicos, VIP detection, image attachment. Defer post-PR3. Ver REV 2 §7.

---

## §8 · Inconsistencias cross-channel (sin cambios)

9 detectadas: Morenas chef opcional, reseñas count, Combinada 58/60, WiFi password, clave caja, bodas $1000/$1400, cancelación asimétrica, pages 404, Total Airbnb no mostrable.

---

## §9 · Cost analysis

~$2-3 USD/mes Anthropic full automation. Debounce NO agrega LLM cost (procesa 1x post-debounce). Pause time-based NO usa LLM. Total <$5/mes.

---

## §10 · Definition of done global

PR1: migration 0052 + integration runBeds24Normalize + anti-loop + cron + UI + smoke + tests ≥85% + greeter no regresión + zero auto-sends.
PR2: 8 templates + 12 eval ≥90% + canary + Telegram + deploy + Karina training.
PR3: 32 templates + MESSENGER_OUTBOUND_ENABLED + canary + quiet hours + digest + pause 1h.

Metrics: response <10min, rate 100%, conversion >28%, false positive <5%, cost <$10/mes.

---

## §11 · Risks + mitigations

| Risk | Sev | Mitigation |
|---|---|---|
| Bot info incorrecta | Alta | Composer determinista + approval + canary |
| Promete chef no disponible | Alta | "nuestro equipo de chef" genérico |
| Off-platform | Alta | Red flag + escalate Karina |
| KB stale | Media | R2→KV refresh 2h |
| payload.lang miente | Media | Detectar via Haiku |
| Wedding mal manejada | Alta | High-stake approval_pending |
| Casa Chamán mencionada | Alta | Filter roomId 679176 |
| Greeter v7.1 break | Alta | Separate eval framework |
| Precio incorrecto | Alta | NUNCA número, "tarifa que ya viste" |
| Bot retoma mientras Karina gestiona | Media | 1h window conservador + bot_pause_until manual |
| Webhook lost | Media | Backup sweep cada 3er tick (max 15min) |
| Debounce reset infinito (spam) | Baja | Cap 5 resets → procesa forzado |
| **(REV 4) Loop booking_modified eco** | **Alta** | **Solo enqueue booking_created + dedup booking_id (§0.3 Ajuste 3)** |
| **(REV 4) Migration collision** | **Media** | **0052 verificado, audit pre-flight** |
| **(REV 4) Tocar payment-flow code** | **Alta** | **Out-of-scope explícito, NO tocar worker-pago** |

---

## §12 · Recomendación final

PR1 (thread/232) → PR2 → PR3 en 4-6 semanas. Todas las decisiones cerradas. CC arranca PR1 cuando Alex confirme + cuando otra sesión CC (payment-flow) termine — **VERIFICADO: payment-flow ya mergeó, vía libre.**

---

## §13 · Appendix — research raw

### Industry quotes

**Uplisting:** "Some members prefer to delay up to 60 minutes to allow them to respond manually. If you respond manually, the auto-responder will not trigger."
**Hospitable:** "If you manually replied before the scheduled send time, we will not send it."
**Hostaway:** "Delayed messages cancelled if new guest message received during the delay; AI reprocesses the whole conversation."

### Beds24 payload

inquiry: `price` (net Alex), resto null. confirmed: `price` + `commission`. NUNCA viene: total guest, service fee, taxes.

### Emoji blocklist

BLOCKED: 🌅 📶 | Suspected: 🔒 🚨 🍳 🚿 | SAFE: 🛏 ✅ 👨‍🍳 🏊 🏖 🧹 🎵 🛻 🛥 🛎 🛒 🍹 🔥 🥥 💆 🐴 🚣 🤿 🎉 🏅 💬 ☀ ⛱ 1️⃣-6️⃣

### Integration point (REV 4)

`runBeds24Normalize` en `apps/worker-bot/src/beds24-normalize.ts`, branch `decision.reason==='skipped_inquiry'`. Reutilizar `parseBeds24Booking()` exportado. Anti-loop: solo booking_created, dedup booking_id.

### Migrations (REV 4)

Último en main: `0051_bookings_beds24_booking_id.sql` (PR #194 payment-flow). Inquiry bot usa **0052**.

### Cron schedule

`*/5min` (polling, llama runBeds24Normalize) + processReadyInquiries + backup sweep cada 3er tick. NO nuevo cron.

---

## §14 · Status

**REV 4 — Ready for DoIt CC (thread/232).**

**Cambios REV 4 (2026-05-28, post payment-flow merge):**
- §0.3 nueva: 4 ajustes de integración verificados contra repo real
- Migration 0051 → 0052 (PR #194 tomó 0051)
- Integration point preciso: runBeds24Normalize (no webhook HTTP), reutiliza parseBeds24Booking
- Anti-loop guard: solo booking_created, dedup booking_id (incident 2026-05-18: 17 welcomes duplicados)
- NO tocar payment-flow code (worker-pago recién mergeado)
- Schema 0052: + debounce_reset_count (cap 5), beds24_booking_id como dedup key
- Tests PR1: +anti-loop test (12 total)
- §11 risks: +3 REV 4 (loop eco, migration collision, payment-flow)
- DoIt task renumerado 222 → 232

**Próximas acciones:**
- Payment-flow CC terminó + mergeó (verificado PRs #194-#198) → vía libre
- Alex aprueba thread/232 DoIt task
- CC ejecuta PR1 autónomo
- WC review pre-merge
- Alex deploy + smoke

---

*FIN thread/220 REV 4. Arquitectura cerrada + ajustes integración. Ready for DoIt thread/232.*

— Web Claude, 2026-05-28
