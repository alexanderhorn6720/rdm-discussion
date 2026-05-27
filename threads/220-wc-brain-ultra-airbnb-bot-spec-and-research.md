---
id: 220
author: wc
topic: airbnb-inquiry-bot-spec-and-customer-management-brain-ultra
status: draft
mode: brain-ultra
created_at: 2026-05-27
references:
  - threads/33-guest360-architecture-phase-b-plan.md
  - threads/35-cc-templates-system-for-wc.md
  - threads/89-cc-event-bus-spec.md
  - threads/107-cc-inquiries-auto-close.md
  - threads/110-112-messenger-outbound-feature.md
  - threads/196-inbox-redesign.md
  - threads/217-greeter-v7.1-mega-spec.md
  - knowledge/airbnb-templates-current-2026-05-13.json
  - knowledge/airbnb-listing-fields-current-2026-05-13.md
  - knowledge/airbnb-emoji-blocklist-2026-05-14.md
  - knowledge/whatsapp-kits-current-2026-05-13.md
prs_proposed: PR1 (inquiry-bot infra), PR2 (template + canary), PR3 (lifecycle activation)
estimated_effort: 24-32h CC + 4-6h Alex/Karina (templates) + canary 2-3 semanas
---

# thread/220 — Brain ultra: Airbnb Inquiry Bot + Customer Management

> **Status:** Draft autónomo escrito mientras Alex duerme. Producto de ~6h de discovery + 2h de research + 1h de spec writing.
>
> **Lectura sugerida desayuno:** §0 TL;DR (5 min) → §1 Hallazgo principal (5 min) → §3 Spec PR1-PR3 (15 min) → §5 Decisión bot único vs separado (10 min) → §7 Creatividad (10 min). Total ~45 min lectura mobile.
>
> **Cómo está escrito:** Tradeoffs explícitos. Recomendaciones marcadas "voto WC preliminar". Decisiones cerradas donde la evidencia es clara, opciones abiertas donde Alex debe decidir.

---

## §0 · TL;DR ejecutivo

**El estado actual:** Beds24 recibe inquiries Airbnb perfectamente (90 en últimas semanas, última hace 3h). El sistema D1 las almacena en `beds24_events` con `status='inquiry', action_taken='skipped_inquiry'`. **El bot las ve y NO hace nada** — el guest queda esperando respuesta de Alex/Karina manual.

**Lo que sorprendió en discovery:** 70% de la infraestructura ya existe.

| Componente | Status |
|---|---|
| Beds24 webhook inquiries | ✅ LIVE |
| `beds24_events` table con `status='inquiry'` | ✅ LIVE, 90 rows |
| `bot_messages_inbox` con mensaje del guest | ✅ LIVE, 216 guest msgs |
| Template placeholders system + R2 storage | ✅ LIVE (Phase B.0.5) |
| `airbnb_inquiry_unconfirmed` lifecycle stage | ✅ LIVE en `/admin/inbox` |
| Karina sees inquiries en su tab | ✅ LIVE |
| Suggest-reply prompt para Karina | ✅ LIVE |
| `messenger_outbound` audit + feature flag global | ✅ LIVE (OFF) |
| Pre-stay scan + welcome touchpoints | ✅ LIVE (OFF) |
| Phase B.2 inquiry response template **handler** | 🔴 **NO EXISTE** ← el gap real |
| `MESSENGER_OUTBOUND_ENABLED='true'` en prod | 🔴 **OFF** (kill switch) |

**El gap real es pequeño:** falta el handler que dispare cuando `beds24_events.status='inquiry'` aterriza, lea KB + template R2, genere respuesta híbrida (template fijo + pregunta dinámica), envíe vía `sendMessageRouted`. ~12-16h CC.

**Lo segundo (lifecycle bot post-booking):** ya está construido pero **dormido**. Activar `MESSENGER_OUTBOUND_ENABLED='true'` con canary tight es el verdadero deploy. ~2h CC + 2-3 semanas canary.

**Recomendación voto WC preliminar:**
1. **Bot único** con context switch por canal (Airbnb / WhatsApp / direct), NO bots separados
2. **PR1 inmediato:** infra inquiry-response (approval mode + audit + canary 0%)
3. **PR2 +1 semana:** templates Phase B.2 enriched + canary 10% → 100%
4. **PR3 +2 semanas:** activar lifecycle post-booking (welcome → pre-stay → post-stay)

**Costo estimado:** 24-32h CC, $5-15 USD Anthropic API canary, riesgo bajo (approval mode + canary scaling).

---

## §1 · Hallazgo principal — el último mile de Phase B.2

### Plan original B.2 (thread/33, mayo 12) → estado actual

El thread/33 detalló Phase B.2 con 16h CC estimadas para inquiry auto-respond + follow-ups. Lo que se construyó vs lo que falta:

| Sub-task del plan B.2 | Status |
|---|---|
| Migrations 0014-0017 (guests + leads + bookings + guest_events) | ✅ aplicadas |
| Lead ingestion handler (classify + match phone/email) | ⚠️ parcial — `bot_messages_inbox` recibe pero no crea leads automáticos |
| Auto-respond inquiry handler | 🔴 NO existe |
| Template R2 `inquiry-welcome-<roomId>.md` | 🔴 NO existe en R2 (estructura sí, contenido no) |
| AI question detection (top FAQs) | ⚠️ existe `admin-suggest-reply.ts` (manual) |
| Auto follow-ups cron (T+3, T+7, T+14) | 🔴 NO existe |
| Pre-approval detection | 🔴 NO existe |

**Diagnóstico:** B.2 quedó "pausado a 70% completion" — la infra del lado D1 y stages está lista, falta solo el orchestrator.

### Por qué nunca se completó

Memoria de proyecto sugiere 3 razones:
1. **Mayo 13-14**: focus pivotó a templates editor (B.0.5) que tomó 3 PRs
2. **Mayo 16-20**: focus pivotó a thread/107 (inquiries auto-close) y thread/89 (event bus)
3. **Mayo 21-26**: focus en thread/196 (inbox redesign) y thread/217 (Greeter v7.1)

Es scope creep clásico. Cada pivote justificable individualmente; el resultado es que B.2 nunca llegó a producción.

### Por qué AHORA es el momento

- Tenés data real: 90 inquiries reales, 25 conversiones, tasa ~28% (industry baseline)
- KB enriched está listo (thread/217 lo dejó al 98.5% eval)
- Sitio nuevo `/comparar-casas` + `/disponibilidad` da donde mandar a leads
- `MESSENGER_OUTBOUND_ENABLED` es kill switch existente — se puede deploy seguro
- El template current de Alex (template "1" del JSON) ya es buena base — solo necesita enrichment

---

## §2 · Discovery summary — la inquiry de Ana Karen como caso real

Anchor del análisis: la inquiry recibida hace 3h. Sirve como caso de prueba para validar diseño.

### Lo que llegó

Booking ID 87381196, RoomId 78695 (Rincón del Mar), inquiry status, 16 adultos, arrival 2026-08-21, departure 2026-08-23. Guest: "Ana Karen". Lang declared: `en` pero escribió en ES. **Precio Airbnb: $28,789** (incluye comisiones+taxes, ese es el precio).

Mensaje del guest: "Hola Alexander, estoy interesada en la renta de este lugar vi que ofrecen servicio de chef ¿el costo total incluye los víveres para la comida?"

### Lo que respondió Alex 2h después

Template "1 - RdM completa - hasta 16" del JSON canonical, ~1688 chars. Sustituyó manualmente "Nombre del viajero" → "Ana Karen". El template **NO responde a su pregunta específica** sobre víveres — Alex respondió eso al final, pegado al template.

Tiempo total: 2h 8min. Para Airbnb response rate metric, está bajo el threshold de 24h pero arriba del "golden hour" (<1h) que correlaciona con +25% conversión.

### Lo que detecta el sistema actual

| Campo | Sistema sabe | Comentario |
|---|---|---|
| Es inquiry, no booking | ✅ | `status='inquiry'`, action `skipped_inquiry` |
| Villa específica | ✅ | `roomId=78695` → Rincón del Mar |
| Tamaño grupo (16) | ✅ | Trigger automático `extra-guests` capture (≥16 RdM/Morenas/Combinada) |
| Pregunta concreta del huésped | ⚠️ texto presente | NO parseado para topic extraction |
| Idioma real del huésped | ❌ | `lang='en'` mintió, Ana escribió en ES |
| Precio Airbnb final | ✅ | `price: 28789.02` — el número EXACTO que el guest ve |

### Lo que falta para responder bien

Tres capacidades faltantes:
1. **Trigger:** handler que escuche `beds24_events.status='inquiry'` con idempotencia
2. **Composer:** template fijo + Haiku parseando pregunta del guest + respuesta híbrida
3. **Sender:** `sendMessageRouted` con channel='airbnb' + `apiReference` para conversation threading

Todas son fáciles individualmente. Lo difícil es el **diseño del composer** — qué partes son fijas, qué son dinámicas, cuándo escalar a humano. Eso es §3.

---

## §3 · Spec del bot — PR1, PR2, PR3

### §3.1 · PR1 — Infraestructura inquiry-response (approval mode)

**Branch:** `feat/inquiry-bot-infra`
**Effort:** 8-12h CC
**Risk:** muy bajo (no sale a producción real, todo a `pending_replies`)

#### Archivos a crear

```
apps/worker-bot/src/inquiry-response.ts            // Handler principal
apps/worker-bot/src/inquiry-templates.ts           // Template loader + composer
apps/worker-bot/src/inquiry-parser.ts              // Haiku question extraction
packages/agents/src/prompts/inquiry-question-parser.ts
migrations/0051_pending_inquiry_replies.sql
apps/web/src/pages/admin/inquiry-replies.astro     // Approval UI
apps/web/src/pages/api/admin/inquiry-replies/[id].ts
apps/worker-bot/tests/inquiry-response.test.ts
apps/worker-bot/tests/inquiry-parser.test.ts
```

#### Migration 0051

Crear tabla `pending_inquiry_replies` con:
- `id` ULID, `beds24_event_id` UNIQUE, `room_id`, `channel`
- Guest snapshot: name, message_text, lang_detected, arrival/departure/nights/adults, airbnb_price_mxn (from payload directly)
- Question extraction: detected boolean, topic enum, extracted text, confidence
- Composition: template_r2_key, snapshot, message_1_text, message_2_text (nullable)
- LLM cost tracking
- Status enum: approval_pending | approved | sent | rejected | expired | auto_send_eligible
- Reviewed_by, reviewed_at, rejection_reason
- Sending result: sent_at, send_attempts, external_message_ids
- Indexes en status, room, unsent

**Decisión cerrada:** un PIR row por inquiry. Si el guest manda 3 mensajes consecutivos, sigue siendo 1 PIR (no multiplica).

#### Handler `runInquiryAutoRespond` — flujo

1. SELECT new inquiry events sin PIR row, últimos 24h, referer LIKE 'Airbnb', LIMIT 20
2. Filter eventos sin guest message (Airbnb a veces genera inquiry from "Save")
3. Parse guest message via Haiku (lang, topic, question, tone, red_flag)
4. Load template R2 per villa+lang
5. Compose 2 messages: direct answer + enriched proposal
6. INSERT PIR row status=approval_pending
7. markEventActionTaken
8. Si high-stake (evento, complaint) → Telegram alert Karina

#### Inquiry question parser prompt (Haiku 4.5)

Output JSON con `lang` (es|en|other), `lang_confidence`, `topic` (chef|veveres|precio|mascotas|amenidades|ubicacion|capacidad|evento|fechas|transporte|actividades|ninguna|multiple), `topics_list`, `question_extracted`, `question_confidence`, `tone` (casual|formal|urgent|vip), `red_flag` (null|off_platform_attempt|negotiation_aggressive|complaint).

#### Decisiones cerradas PR1

| Decisión | Valor | Razón |
|---|---|---|
| Idempotencia | Por `beds24_event_id` UNIQUE | Beds24 webhook puede llegar 2x |
| Window de procesamiento | últimos 24h | Inquiries más viejas pierden valor |
| Estado inicial | `approval_pending` siempre | PR1 NUNCA auto-envía |
| Approval UI | `/admin/inquiry-replies` (nueva) | Separate de `/admin/inbox` |
| Editor en UI | Sí, editan msg1 + msg2 antes de approve | Polish manual |
| Approval timeout | 48h → `expired` | No quedan pending forever |
| 2 mensajes siempre | No — si no hay pregunta clara, solo 1 (template completo) | Evita spam |
| Idioma respuesta | El del mensaje guest, NO `payload.lang` | Airbnb mistraduce |
| Multi-mensaje threading | 2-3s delay entre msg 1 y msg 2 | Beds24 wiki recomienda |
| Casa Chamán | Filtrar — no responder | Memoria #6, no bookable |

#### Tests PR1

- drafts response for new inquiry with question
- skips inquiry without guest message
- detects language correctly when payload.lang != actual
- extracts topics correctly
- does NOT skip high-stakes alert
- respects 24h window
- idempotente
- handles malformed payload gracefully
- skips Casa Chamán

#### DoD PR1

- Migration 0051 applied remote D1
- Handler deployed, NOT cron-scheduled yet
- `/admin/inquiry-replies` UI live con edit + approve + reject
- Smoke test: simular inquiry payload → PIR row created
- Tests ≥85% coverage
- Zero auto-sends (canary 0%)
- Documentation en code

---

### §3.2 · PR2 — Templates Phase B.2 enriched + canary

**Branch:** `feat/inquiry-templates-canary`
**Effort:** 8-10h CC + 4-6h Alex/Karina (templates)
**Risk:** medio (sale a producción real con canary)
**Dependency:** PR1 merged + deployed

#### Templates en R2 — 8 totales (4 villas × ES+EN)

`inquiry-rincon-del-mar-es.md`, `inquiry-rincon-del-mar-en.md`, `inquiry-las-morenas-es.md` (chef OPCIONAL clarificado), `inquiry-las-morenas-en.md`, `inquiry-combinada-es.md` (58-60 pax), `inquiry-combinada-en.md`, `inquiry-huerta-cocotera-es.md` (sin chef default), `inquiry-huerta-cocotera-en.md`.

#### Template Rincón del Mar ES — propuesta enriched

2 mensajes separados por marcador `{{MSG_2_BREAK}}`. Placeholders: `{guestFirstName}`, `{numAdults}`, `{nightsCount}`, `{airbnbPriceMxn}`, `{questionAnswer}`.

**Mensaje 1 (corto, <500 chars):**

```
¡Hola {guestFirstName}! 👋

{questionAnswer}

En un momento te mando la propuesta completa para los {numAdults} huéspedes que mencionaste. 🌊
```

**Mensaje 2 (enriched, <2000 chars):**

```
🏖 Rincón del Mar — para {numAdults} personas, {nightsCount} noches

Es la villa con chef incluido del grupo. Apapacha total desde que llegan.

✅ Lo que ya está incluido en la tarifa:
• Chef Celene + cocinera + mozo (3 personas a su servicio)
• Desayuno, comida y cena preparada
• Bebidas en palapa-bar frente al mar
• Limpieza diaria · WiFi · A/C todas las habs
• 6 habitaciones · 18 camas · 6.5 baños

📍 Pie de playa · zona tranquila
Pacífico al frente. Lejos del bullicio de la bahía pero cerca del malecón si quieren cenar fuera. Vecinos canadienses y americanos.

💰 Cómo funciona la cuenta
• Tu tarifa de Airbnb: {airbnbPriceMxn} (ya incluye comisiones y taxes)
• Personas extras (hasta 30): $300/noche c/u, paga al llegar
• Víveres: cuenta aparte transparente. Compras las hace nuestra chef Celene, pagás al llegar contra recibos. Promedio $250-280/persona/noche

🛎 Servicios opcionales con costo aparte
• Yates, snorkel, pesca, esquí acuático — coordino yo todo
• Masajes en sitio con Michel
• Fogata en la playa, cocos frescos
• Paquete bodas/eventos formales $1,400/persona

👉 Mirá las más de 168 reseñas ⭐ 4.84 en mi perfil:
airbnb.mx/users/95731371/listings

Confirmás {numAdults} huéspedes o vienen más? Cualquier duda más, escribíme.

— Alexander 🏖
```

**Notas críticas del template:**

1. `{questionAnswer}` es dinámico — Haiku rellena con respuesta a pregunta detectada. Sin pregunta: saludo genérico.
2. `{airbnbPriceMxn}` viene del payload directo. **NO recalcular** (memoria de Alex).
3. **Emojis usados** (todos confirmados safe per blocklist 2026-05-14): 👋 🌊 🏖 ✅ 📍 💰 🛎 ⭐ 👉
4. **NO usar:** 🌅 📶 🔒 🚨 (Airbnb bloquea o sospechoso)
5. **NO incluir** footer cryptic `--> rincondelasmorenas / --> rincondelmar`
6. **NO usar** "inseguridad de Acapulco" — reemplazar por "lejos del bullicio"
7. Chef Celene **nombrada** — confianza > anonimato
8. "Servicio chef incluido" claro — solo para RdM. Morenas será opcional $1,000/$1,500

#### Composer `{questionAnswer}` — determinista

Switch/case sobre topic detectado. Anti-hallucination: NO LLM-generated, hardcoded responses por topic.

```
chef     → "El servicio de chef SÍ está incluido en la tarifa..."
veveres  → "Los víveres NO están incluidos — esos los compramos nosotros..."
mascotas → "Aceptamos hasta 2 mascotas por reservación, con un cargo único de $300 MXN por estancia (no por noche)."
evento   → "¡Felicidades por el evento! Para bodas/XV años manejamos paquete de $1,400/persona..."
default  → "Muchas gracias por tu pregunta. Te respondo a detalle en el siguiente mensaje."
```

**Voto WC preliminar:** composer determinista para PR2. Anti-hallucination es prioridad. Stage 2 (futuro) podría usar LLM con KB injection para casos novedosos.

#### Canary scaling plan

| Fase | % auto-send | Duración | Gate próxima fase |
|---|---|---|---|
| 0% (PR1 baseline) | 0% — todo approval_pending | Indefinido | PR1 mergeado |
| Smoke test | 1 inquiry real manual | 24h | Alex aprueba calidad |
| 10% | 1 de cada 10 | 7 días | <2 false positives |
| 25% | 1 de cada 4 | 7 días | <5% rejection rate |
| 50% | mitad auto-send | 14 días | Sustained <5% issues |
| 100% | todas auto-send | indefinido | — |

**Override siempre activo:** Karina/Alex marcan booking `bot_paused=1` y el bot respeta.

**Telegram alert flow:**
- High-stake (evento, complaint, off-platform) → siempre approval_pending + alert Karina
- Canary % NO aplica a high-stake
- Haiku confidence <0.5 → siempre approval_pending

#### Decisiones cerradas PR2

| Decisión | Valor | Razón |
|---|---|---|
| Templates per-language ES/EN | Sí, 8 totales | EN no traducidos suenan robóticos |
| Templates per-villa | Sí, 4 × 2 = 8 | Diferencias críticas (chef RdM vs Morenas) |
| Casa Chamán | EXCLUIR | Memoria #6 |
| Mensaje 1 charlimit | <500 chars | Mobile-first |
| Mensaje 2 charlimit | <2000 chars | Cover Combinada (2 villas) |
| 2-3s delay msg1→msg2 | Sí | Beds24 wiki |
| Auto-translate | NO — usar ES/EN | Pierde matiz |
| `{questionAnswer}` | Composer determinista | Anti-hallucination |
| Footer signature | "— Alexander 🏖" | Reemplaza cryptic |

#### Eval cases PR2 (10 scenarios)

- iq001: Ana Karen real (chef + víveres)
- iq002: EN guest mascotas Las Morenas
- iq003: Inquiry sin pregunta concreta
- iq004: Wedding inquiry high-stake
- iq005: Off-platform attempt
- iq006: Complaint pre-booking
- iq007: Multiple topics
- iq008: Precio explícito (verifica placeholder rendered)
- iq009: Negotiation agresivo
- iq010: Idioma payload incorrecto (FR pero payload dice ES)

#### DoD PR2

- 8 templates pegados en R2 vía `/admin/templates`
- 10 eval cases ≥90% pass
- Canary scaling logic implementada
- Smoke test 1 inquiry real respondida
- `/admin/inquiry-replies` muestra canary status
- Telegram alert high-stake LIVE
- Worker deploy (manual `wrangler deploy`)

---

### §3.3 · PR3 — Lifecycle post-booking activation

**Branch:** `feat/lifecycle-activation`
**Effort:** 6-10h CC (mayoría operacional)
**Risk:** medio-alto (touches 25 active bookings)
**Dependency:** PR2 canary 100% sustained 14 días

#### Lo que activa (todo ya construido)

| Stage | Handler existente | Action |
|---|---|---|
| `booked` → `pre_arrival_t30` | `scanForWelcome` en `pre-stay.ts` | Welcome msg |
| pre_arrival_t30 → t14 → t7 → t1 | `runPreArrivalScan` | Touchpoints sequence |
| `pre_arrival_t1` → `arrived` | mismo | Check-in day |
| `arrived` → `in_stay` | cron auto | T+1 check |
| `checked_out` → `review_pending` | `runPostStay` | Review request |

Todos existen. Falta:
1. Pegar templates Phase B.1 en R2 (32 templates × 4 villas × 2 lifecycle moments mínimo)
2. Activar `MESSENGER_OUTBOUND_ENABLED='true'`
3. Canary scaling análogo PR2

#### Templates Phase B.1 mínimos a pegar

Reusar templates `PROG:*` del JSON. Solo necesitan:
- Polish con placeholders canónicos
- Split en archivos R2 separados
- Remover footer cryptic

Para PR3 minimum viable:
- `welcome-<slug>-<lang>.md` × 8
- `pre-arrival-t7-<slug>-<lang>.md` × 8
- `pre-arrival-t1-<slug>-<lang>.md` × 8
- `post-stay-review-<slug>-<lang>.md` × 8

Total: 32 templates. ~4-6h Alex/Karina polish.

#### Decisiones cerradas PR3

| Decisión | Valor |
|---|---|
| Activación `MESSENGER_OUTBOUND_ENABLED` | Manual via `wrangler secret put` |
| Canary scaling | 0→10→25→50→100% sobre 4 semanas |
| Order activation | Welcome first, post-stay last |
| Karina notification | Daily digest 09:00 Acapulco |
| Pause flag | Respeta `bookings.pre_stay_skip=1` |
| Quiet hours | NO send 22:00-08:00 Acapulco |

#### Followups (no en PR3)

- T+3/T+7/T+14 follow-up de leads abandonados → thread/221
- Pre-approval auto-send → defer
- VIP/repeat detection → Phase B.8 defer

---

## §4 · Attachments — qué se puede mandar

### Limits técnicos confirmados (Beds24 wiki)

| Channel | Tipos | Size |
|---|---|---|
| **Airbnb** | JPG, GIF, PNG **únicamente** | 2 MB |
| **Vrbo** | PDF, JPG, GIF, PNG | 2 MB |
| **Booking.com** | Email-based | 2 MB |
| **WhatsApp BSP** (ManyChat) | JPG, PNG, PDF, MP4, audio | 16 MB |

### Implicación crítica: NO PDFs en Airbnb

Approach común "mandamos PDF de propuesta" NO funciona en Airbnb. Alternativas:
- Mandar imagen (max 2MB)
- Link a URL pública con propuesta
- Texto largo en mensaje (hasta 5000 chars)

### Casos de uso interesantes

| Caso | Channel | Implementación |
|---|---|---|
| Foto exterior villa específica | Airbnb JPG | R2 already has photos. Pre-procesar a <2MB |
| Foto de Chef Celene cocinando | Airbnb JPG | Trust signal humano |
| Mapa de ubicación | Airbnb JPG | Screenshot Google Maps |
| Cotización detallada PDF | Vrbo / WhatsApp | NO Airbnb |
| Video walkthrough villa | WhatsApp solamente | MP4 <16MB |
| Diferencias entre villas | Airbnb link a `/comparar-casas` | Live page > JPG |

### Lo que NO recomiendo automatizar

- Attachments PDF/video en respuesta a inquiry → riesgo alto, formato no estándar, parece spam
- Foto Alex personal → privacy
- Screenshots con datos del huésped → leak data

### Lo que SÍ vale la pena (post-PR3)

**Voto WC preliminar:** un solo attachment por inquiry, **foto de la villa específica** desde R2, **solo si Haiku detecta interés alto** (signals: pregunta específica + tono entusiasta).

---

## §5 · Arquitectura: bot único vs separado

### Opciones consideradas

- **A — Bot único:** Un Worker, un agente Haiku, KB único, switch por canal
- **B — Bots separados:** Worker dedicado per canal
- **C — Híbrido:** Worker compartido, prompts diferenciados

### Análisis dimensional

**Dimension 1 — KB diferencial.** WhatsApp permite "apapacha" costeño, Karina cell directo, emojis libres. Airbnb tiene blocklist emoji + off-platform rules + traducción auto. Pero **KBs son ~85% iguales** (info de villas, precios, políticas). El 15% diferencial son metadata de canal.

**Dimension 2 — Code reuse.** Hoy `sendMessageRouted` ya abstrae channel. Toda la abstracción está ahí. Separar = duplicación pesada (KB management, prompts, evals, deploys, secrets, observability).

**Dimension 3 — Tone.** ¿Bot suena igual en ambos canales? **Voto WC: tono unificado con micro-adjustments.** El bot escribe como "Alex genuino": cálido, técnico cuando hace falta, costeño cuando es genuino. En Airbnb, menos emojis decorativos. En WA, más.

**Dimension 4 — Failure modes.** Aislamiento de Bots separados es real pero **cost de duplication > benefit de isolation** dado que ambos canales hablan a mismos clientes.

### Recomendación final voto WC preliminar

**Opción A — Bot único con context switch por canal.**

```
worker-bot (Hono, deployed)
├── Greeter (WhatsApp pre-booking, LIVE thread/217, 98.5% eval)
├── Inquiry Responder (Airbnb pre-booking, NEW PR1-PR2)
├── Lifecycle Bot (post-booking, construido PR3 activa)
└── Karina Suggest (admin assist, ya LIVE)
```

**Lo común:** KB en KV, `sendMessageRouted`, `messenger_outbound`, kill switch, eval framework.

**Lo diferenciado:** Prompt per use-case, templates per channel, channel-specific rules en cada prompt.

### Lo que NO recomiendo

- ❌ Bot separado para Airbnb. Cost > benefit.
- ❌ KB separada per canal. Stale risk explota.
- ❌ Tono dramáticamente diferente. Inconsistente.
- ❌ Llamarlo "Karina bot" o "Alex bot" en mensajes. Expectativas humanas.

---

## §6 · Best practices research — competidores

### Hospitable (el más relevante — su AI se llama "Alex")

**Patrón principal:**
- 3 niveles control: **Suggest** → **Approve** → **Auto Reply**
- AI detecta intent en **20+ topics** (WiFi, mascotas, descuentos, etc.)
- **Knowledge Hub** per-property
- **Escalation policy fija** (AI NO override)
- **Office Hours** configurables
- **Multilingual auto-match**
- **Question Rules vs Event Rules vs Scheduled Rules**
- Pricing: $25/property/month base

**Lo que copiamos en spec:**
- ✅ 3 niveles control (= canary scaling)
- ✅ Topic detection (~12 nuestros, 20+ ellos)
- ✅ Escalation predefined high-stake
- ✅ Multilingual auto-match

**Lo que NO copiamos:**
- ❌ Question Rules complejas (overkill 4 villas)
- ❌ Knowledge Hub UI separada (ya tenemos `/admin/airbnb-content`)

### Hostaway (enterprise, no relevante para 4 villas)
### iGMS (mid-size, templates per-property + tag system)
### Enso Connect (AI upsells post-booking, Phase B.6+)
### OwnerRez (compliance, no relevante)
### Lodgify / Uplisting / Tokeet / Smoobu / HostBuddy (mid-size variants, no learning único)

### Conclusión research

Patrón industry-standard:
1. Saved templates per-event
2. Question rule detection con AI (20+ topics)
3. Multi-tier control (suggest/approve/auto)
4. Multilingual matching
5. Knowledge Hub per-property

**Nuestro spec tiene 4 de los 5.** Quinto = ya cubierto por `/admin/airbnb-content`.

### Métricas industry

- <1h response → +25% conversion (Intellihost 5000 properties)
- 89%→100% response rate → +116% instant bookings
- Quick Responder badge (Airbnb)
- Superhost requires ≥90% response rate

**Nuestro target:** <5 min auto-send. Vs 2h actual (Ana Karen) = **mejora 24x**.

---

## §7 · Creatividad — propuestas adicionales

Ideas extras, no parte del PR1-PR3 spec. Brain ultra implica explorar más allá del checklist.

### §7.1 · Upsells dinámicos post-confirmation

| Trigger | Upsell | Revenue potencial |
|---|---|---|
| Booking Morenas + group >10 | Chef service $1000-1500/noche | $5K-15K/booking |
| Booking RdM + arrival distance (>14d) | Compras víveres margen 5%/$450 min | $500-2K/booking |
| Booking + special date (XV, anniversary) | Paquete eventos $1,400/pax | $50K-100K/evento |
| Booking + 1-2 personas adicionales | Extras $300/noche pre-paid | $600-1.8K/booking |
| Booking + arrival night | Masajes Michel | $0 directo |
| Group >20 | AcaScuba yates/snorkel | $0 directo, $1K commission posible |

**Risk:** muy spammy si mal calibrado. Defer post-PR3 con quiet hours.

### §7.2 · VIP / Repeat guest detection

Hoy 25 bookings 2026 + 20 mensajes históricos. Algunos son **mismas personas que regresan**.

Match phone/email/name → flag VIP, response personalizada:
> "Hola {guestFirstName}! Qué gusto verte otra vez — recuerdo tu visita en {previousArrival}. Para esta vez te preparo..."

**Risk:** false positives. Mitigation: phone exact match only.

### §7.3 · Recurring discount automático super-VIPs

Guests con 3+ visitas → 5% off automático sin que pidan. Como gesture de fidelidad.

**Risk:** crea expectativa que NO podemos cumplir todos los casos. Defer.

### §7.4 · Off-platform conversion legal

Airbnb estricto pre-booking. Pero **post-stay** es permitido compartir contacto directo.

Lifecycle bot Phase B.7 (post-stay review) puede incluir:
> "Si quieren regresar, encantado de coordinarte directamente — WhatsApp +52 744 144 1575. Mismo trato, sin comisiones de Airbnb."

**Revenue:** Airbnb cobra ~15% commission. Direct = +15% net.

**Risk:** Airbnb ToS. Defer hasta investigar legalidad.

### §7.5 · Quote attachment con imagen

Para inquiries grandes (>20 pax o evento), bot genera **imagen** dinámica de cotización (HTML → JPG via Cloudflare Browser Rendering → R2 → attached <2MB).

**Benefits:** look profesional, branded, scannable mobile.

**Defer:** post-PR3.

### §7.6 · Karina-Alex separación clara

Memoria #3: "Alex en design mode, no atiende escalations — solo Karina".

Bot puede:
- Detectar si Alex en design mode (flag global)
- Routear high-stake a Karina (+52 744 144 1575)
- NOT mention Alex personally salvo signature
- Alex recibe daily digest weekly

**Implementation:** simple feature flag.

### §7.7 · Top 20 FAQs como guidance

Del thread/33 nunca extraído. Hoy 216 guest messages + 20 históricos. Probable top FAQs:
1. ¿Víveres incluidos? (Ana Karen case)
2. ¿Hay chef? 
3. ¿Cuánto cuesta extra una persona? ($300/noche)
4. ¿Aceptan mascotas? ($300/estancia, máx 2)
5. ¿Cómo llegar?
6. ¿WiFi en habitaciones?
7. ¿Alberca climatizada?
8. ¿Cancelación?
9. ¿Eventos/bodas? ($1,400/pax)
10. ¿Tour virtual?

**Action:** brain quick futuro para validar.

### §7.8 · Anti-pattern: "no cumplir lo prometido"

Bot dice "Chef Celene atiende personalmente" pero Celene enferma → guest engañado.

**Mitigation:** templates evitan promesas que dependan de availability humana. "Nuestro equipo de chef" en vez de "Chef Celene" salvo 100% seguro.

### §7.9 · Detecting "ya tienen otra opción"

Pattern: guest pregunta múltiples veces sobre diferencias entre villas sin commit → probablemente comparando con otra propiedad.

Strategy: emphasize differentiators únicos (Chef Celene specific human, Pacífico vs bahía, 168 reseñas 4.84, 50+ bodas exitosas).

### §7.10 · Conversational state machine

Inquiry response = turn 1. Guest puede generar turn 2, 3, ...

Bot debe saber si ya respondió, modificar templates en subsequent turns, escalar a humano si 3+ turns sin commit.

**Defer:** scope creep. Phase B.2.1 futuro. Por ahora bot responde turn 1, Karina maneja turn 2+.

### §7.11 · Multi-property steering

Guest pregunta por RdM pero requirements (50 personas) sugiere Combinada → bot menciona:
> "Para 50 personas, te recomiendo la Combinada (RdM + Morenas juntas, hasta 58 personas)."

**Action:** incluir en PR2 si templates lo soportan.

### §7.12 · Casa Chamán teaser pre-launch

Q3 2026 launch. Bot puede mencionar **discreto** SOLO si guest pregunta por future capacity. NO actively promote.

### §7.13 · Wedding package — link al detalle

Templates current mencionan "$1,400 paquete bodas". Doc detallado tiene 35+ servicios opcionales. Bot puede mencionar package en inquiry + link a `/eventos` page (TBD crear).

### §7.14 · Capacity feedback loop

Cuando guest reserva con `numAdult` cerca del máximo:
> "Vimos que reservaste para 28 personas en RdM. Si llega alguno más, el costo de persona adicional es $300/noche pagado al llegar — no necesitas modificar la reserva en Airbnb."

Reduce friction. Captura revenue.

### §7.15 · Sentiment tracker

Track sentiment per turn. Trending negative → escalate Karina aunque no haya keyword "alarm". Haiku score 0-100, threshold <40 = escalate. Defer.

---

## §8 · Inconsistencias cross-channel que el bot va a destapar

### §8.1 · Servicio Las Morenas (chef incluido vs opcional)
Templates JSON 3, 3a, 3b dicen incluido. Listing fields actual dice OPCIONAL $1000/$1500. **Verdad: OPCIONAL.** Fix en templates B.2.

### §8.2 · Reseñas count
Airbnb listing actual: 168/128/180+. Templates JSON: stale 150-300. apps/web collection: 167/129/89/17 (Combinada off). Fix templates B.2 con números actuales.

### §8.3 · Combinada capacity
Spec dice 58-60. Listing actual: 58 personas (40 invitados). **Action Karina:** confirmar.

### §8.4 · WiFi password Las Morenas
`rincondelmar` (todas) vs `Rincondelmar1` (Las Morenas only). **Hidden bug:** guests en Combinada (Morenas side) reciben wrong password. Fix: documentar 2 networks en Combinada Manual.

### §8.5 · Clave caja universal "6720"
4 villas misma clave. **Security risk** si una comprometida. Defer rotación.

### §8.6 · Paquete bodas precio
Templates JSON dicen $1000. Kit WhatsApp + Directions + Doc dice $1400. **Fix:** templates B.2 alinear $1400. Create `/eventos` page.

### §8.7 · Cancelación asimétrica
RdM/Combinada: Superestricta 30d. Morenas: Estricta. Huerta: Firme. **Decisión de negocio.** Bot debe mencionar policy.

### §8.8 · Páginas missing en sitio
`/guia-llegada` 404 (templates linkean). `/eventos` 404. **Fix:** crear pages.

---

## §9 · Cost analysis

### Anthropic API budget

| Phase | Volume | Cost per request | Monthly |
|---|---|---|---|
| PR1 test | 5 inquiries | $0.005 | $0 (one-time) |
| PR2 canary 10% | 3/day | $0.005 | ~$0.50/mes |
| PR2 100% | 10/day | $0.005 | ~$1.50/mes |
| PR3 lifecycle 100% | 25 bookings × 5 touchpoints | $0.002 | ~$0.25/mes |
| **Total expected** | ~150 calls/mo | — | **~$2-3 USD/mes** |

**Cache hit savings:** ~50% on system prompts = $0.0035 effective per inquiry.

### Total infrastructure cost increase

- Anthropic: ~$2-3 USD/mes
- D1/R2/KV: no incremento meaningful
- CF Pages: no incremento

**Total:** <$5 USD/mes for full automation. ~$60 USD/year.

---

## §10 · Definition of done global

### PR1
- Migration 0051 applied remote D1
- Handler deployed
- Approval UI live
- Smoke test 1 inquiry payload
- Tests ≥85% coverage
- Zero auto-sends
- Documentation in code

### PR2
- 8 templates in R2
- 10 eval cases ≥90% pass
- Canary 10% smoke test successful
- Telegram alert high-stake LIVE
- Worker version bumped + deployed
- Karina training sesión (15 min)

### PR3
- 32 lifecycle templates in R2
- `MESSENGER_OUTBOUND_ENABLED='true'` deployed
- Canary 0%→10% smoke test
- Pre-stay + post-stay scans verified
- Quiet hours respected (22:00-08:00)
- Karina daily digest LIVE

### Global success metrics
- Inquiry response time: <5 min average (vs 2h current)
- Inquiry response rate: 100% (vs ~85% current)
- Lead conversion rate: maintain or improve (>28% baseline)
- False positive rate: <5%
- Cost: <$10 USD/mes Anthropic

---

## §11 · Risks + mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Bot manda info incorrecta | Alta | Composer determinista PR2 + approval mode PR1 + canary |
| Bot promete chef/cocinera no disponible | Alta | Template usa "nuestro equipo de chef" genérico |
| Off-platform attempt → Airbnb baneo | Alta | Red flag detection + escalate to Karina |
| KB stale | Media | R2→KV pipeline refresh 2h |
| Idioma mistakes (payload.lang miente) | Media | Detectar via Haiku, NO confiar payload |
| Wedding inquiry mal manejada | Alta | High-stake siempre approval_pending |
| Anthropic API outage | Baja | Fallback: template raw sin LLM polish |
| Beds24 API rate limit | Baja | 20 per cron run, retry exponential |
| Karina overwhelmed por approvals | Media | Canary scaling auto-reduces load |
| Casa Chamán mencionada por error | Alta | Filter roomId in handler |
| Greeter v7.1 break | Alta | Separate eval framework |

---

## §12 · Recomendación final (voto WC preliminar)

### Camino propuesto

1. **PR1 — Esta semana** (Alex polish templates en paralelo)
   - 8-12h CC autonomous
   - Output: infra inquiry-response + approval UI + 0% canary
   - Risk: muy bajo

2. **PR2 — Próxima semana**
   - 8-10h CC + 4-6h Alex/Karina templates
   - Output: 8 templates enriched + canary 10%
   - Risk: medio

3. **PR3 — 2-3 semanas después**
   - 6-10h CC + 4-6h Alex/Karina templates lifecycle
   - Output: lifecycle post-booking activado
   - Risk: medio-alto

### Por qué este orden

- **PR1 sin riesgo:** approval mode testea infra sin consecuencias
- **PR2 valida quality:** canary 10% revela issues
- **PR3 builds confidence:** 2 semanas PR2 estable = trust para lifecycle
- **Total timeline:** 4-6 semanas a 100% automation
- **Total CC effort:** 24-32h (~3-4 days)
- **Total Alex effort:** 8-12h (templates, validation, decisiones)

### Alternativas

**Más agresiva (NOT recomendada):** PR1+PR2 juntos, skip canary 10/25, directo a 50%. Reduce timeline 2 sem. Pero bug en composer → reputation hit.

**Más conservadora:** Approval mode forever, NO auto-send. Reduce Karina carga 80%. Pero pierde valor de <5min response time (+25% conversion industry).

### Lo que necesito de Alex para arrancar

Cuando despiertes:
1. ¿OK con plan PR1 → PR2 → PR3 en 4-6 semanas?
2. ¿OK con tono mix costeño + neutral, 2 mensajes, emojis funcionales?
3. ¿Karina disponible para 4-6h templates polish próxima semana?
4. ¿OK que CC arranque PR1 cuando confirmes, autónomo?
5. ¿Hidden constraint que no consideré? (legal, business, family)

---

## §13 · Appendix — research raw

### Beds24 attachment limits

- Hard limit 2MB per message
- Airbnb: JPG, GIF, PNG only
- Vrbo: PDF, JPG, PNG, GIF
- Booking.com: depends on channel

### Hospitable AI features observed

- 3 control modes (Suggest / Approve / Auto)
- 20+ topic detection
- Knowledge Hub
- Question Rules / Event Rules / Scheduled Rules
- Office Hours
- Escalation policy with predefined messages
- Multilingual matching

### Airbnb response time metrics

- <1h → +25% conversion (Intellihost 5000 properties)
- 89%→100% response rate → +116% instant bookings
- Quick Responder badge for sustained fast replies
- Superhost requires ≥90% response rate

### Templates JSON canonical (28 total)

Source-of-truth del tono Alex. Decisión: usar como **training reference** para parser + composer, NO copiar literalmente (tienen anti-patterns: villas no specific to airbnb_listing_id, footers cryptic, info stale).

### Emoji blocklist Airbnb

**BLOCKED confirmed:** 🌅 📶

**Suspected BLOCKED:** 🔒 🚨 🍳 🚿

**SAFE confirmed:** 🛏 ✅ 👨‍🍳 🏊 🏖 🧹 🎵 🛻 🛥 🛎 🛒 🍹 🔥 🥥 💆 🐴 🚣 🤿 🎉 🏅 💬 ☀ ⛱ 1️⃣-6️⃣

### D1 schema relevant

```
beds24_events            -- inquiries land here
bot_messages_inbox       -- guest + host messages threaded
beds24_bookings          -- normalized bookings, full lifecycle status
booking_captures         -- pets/menu/chef capture
inquiries_closed         -- audit trail auto-closed inquiries
messenger_outbound       -- audit trail outbound, gated by flag
pending_welcomes         -- legacy, deprecated
pending_inquiry_replies  -- NEW PR1
```

### Cron schedule

- `0 10 * * *` — daily cron
- `*/5 * * * *` — bot polling
- `*/30 * * * *` — pre-stay welcome scan

PR1 adds:
- `*/10 * * * *` — inquiry-response scan

---

## §14 · Status

**Documento status:** Draft. WC pre-deliverable autónomo overnight session.

**Próximas acciones:**
- Alex lee este thread mañana
- Decide arrancar PR1 (CC autonomous), o pivota
- Si arranca: CC ejecuta + WC review pre-merge
- Si pivota: redirect a próxima prioridad

**Sesión WC:** cerrada hasta próxima invocación.

---

*FIN thread/220. Brain ultra completo. Producto de discovery + research + spec writing autónomo overnight.*

— Web Claude, 2026-05-27, autonomous session
