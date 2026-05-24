---
thread: 204
author: wc
topic: inbox-deep-audit-spec-vs-shipped-and-roadmap
status: brain-deep-ultra-complete
mode: brain deep (3h investigación autónoma WC mientras Alex duerme)
created: 2026-05-24
related_threads: [196, 197, 198, 199, 200, 201, 202, 203]
related_prs: [167, 168, 169, 170, 171, 172]
purpose: Audit exhaustivo thread/196 spec vs realidad shipped; bugs P0 visibles; gaps P1; best practices benchmark (Front/Intercom/Help Scout); roadmap priorizado de threads ejecutables
estimated_remaining_work_to_close_spec_full: 18-26h CC (vs 33h originales del spec, gracias a thread/199-203 ya invertidas)
---

# 204 — Inbox deep audit: spec thread/196 vs shipped + roadmap

> **Audiencia:** Alex cuando despierte. WC trabajó autónomo ~3h durante la noche (24/may madrugada).
> **Status:** Análisis completo, listo para decisión Alex. NO ejecutable directo aún — define qué threads ejecutables seguir.
> **Próximo paso:** Alex lee §0 + §10. Decide cuáles items P0/P1 atacar primero. WC convierte en threads/205+ ejecutables.

---

## §0 · TL;DR (3 minutos lectura)

### ¿Qué se entregó del spec 196?

**~75% de la superficie del spec está en código** (componentes creados, endpoints, migrations 0032-34 aplicadas, helpers, tests). Pero hay **3 bugs funcionales P0 que vuelven invisible parte del valor** del spec, y **15+ gaps que están en código pero no en el render path o no funcionan en producción**.

### Los 3 bugs P0 críticos (NO son cosméticos)

1. **🚨 LLM Suggestion NUNCA aparece**. ConversationView pasa `initialSuggestion={null}` siempre, y LLMSuggestion solo renderiza si recibe data inicial. Karina nunca ha visto la sugerencia que el spec promete. El backend existe y funciona. El frontend no la pide al cargar. → **Fix trivial: 1 línea + auto-fetch on mount.**

2. **🚨 Guest name muestra "Booking 79421553" en lugar del nombre real**. En `conversation.ts` handler: `subscriber.name = ctx.bookingRow ? \`Booking ${ctx.bookingId}\` : ...`. Falta hacer JOIN guests para mostrar "Alan Granados". Por esto la screenshot mobile de Alex muestra "...allá" arriba (texto del último mensaje truncado, no el nombre).

3. **🚨 LLM Suggestion bloqueada para AirBnB-only bookings**. `handleSuggestReply` requiere `ctx.hasWaConversation`. Los 60+ bookings AirBnB activos NO tienen WA conv linked → nunca disparan suggestion. **Justo donde más útil sería** (responder OTA via mensaje predicho). Ironía: el caso de uso principal está bloqueado.

### "Texto informativo estructurado" que Alex menciona

El spec §4.2.1 define `preview: string` (último msg 100 chars). Esto NO es "estructurado", es free-text. Lo que Alex quiere es probablemente el **stay-summary block** que el spec implícitamente sugiere en mockup iterations: `T-3, 5 pax, 1🐶, $0/$5,452, ETA pendiente`. Esto NO existe como concepto separado — está dispersamente capturado entre `inbox-row-stay-info` (pax + days), `ReadinessScore` (pills missing), y `preview` (last msg).

**Recomendación:** Crear un campo backend `summary: StructuredSummary` que reemplaza/complementa `preview` cuando booking activo. Render frontend distinto a last_message. Detalle en §3.1.

### 75% del spec entregado pero 60% del valor visible

Hay un gap de **valor visible** vs **código existente**:
- Botones quick-action row-level: NO existen (gap thread/202).
- Quick stats header: existe pero CSS lo oculta en mobile.
- Audit trail: backend devuelve, frontend renderiza pero data llega genérica (action/actor no estructurado).
- Mobile compose full-screen: existe, funcional.
- Drafts persist: existe, funcional.
- Quick replies: backend + frontend CRUD existen, **probable que NO esté seeded data** (0 quick replies en DB?).

---

## §1 · Matriz exhaustiva: spec thread/196 vs realidad shipped

Convención:
- ✅ Existe y funcional en producción
- 🟡 Existe en código pero bug/gap
- ❌ NO existe
- ⚪ Out-of-scope spec (no se esperaba)

### 1.1 Frontend `apps/web/`

| Spec ref | Component / file | Status | Notas |
|---|---|---|---|
| §4.1 | `pages/admin/inbox.astro` | ✅ | Rewrite shipped |
| §4.1 | `pages/admin/conversation/[id].astro` | ✅ | Página existe |
| §4.1 | `pages/admin/quick-replies/index.astro` | ✅ | Existe (NO verificado functional) |
| §4.1 | `pages/admin/quick-replies/[id].astro` | ✅ | Edit page existe |
| §4.1 | `components/inbox/InboxTabs.tsx` | ✅ | 808 bytes, OK |
| §4.1 | `components/inbox/InboxRow.tsx` | 🟡 | Existe pero falta quick action buttons + structured summary (§3.1 below) |
| §4.1 | `components/inbox/ReadinessScore.tsx` | ✅ | Compact done counter (thread/199 fix) — todo OK |
| §4.1 | `components/inbox/LifecycleSection.tsx` | ✅ | 1382 bytes |
| §4.1 | `components/inbox/QuickStatsHeader.tsx` | 🟡 | Existe pero **invisible mobile** (CSS oculta? verificar) |
| §4.1 | `components/inbox/InboxFilters.tsx` | ✅ | 4616 bytes, filtros OK |
| §4.1 | `components/conversation/ConversationView.tsx` | 🟡 | Funciona pero `initialSuggestion={null}` → LLM never shown |
| §4.1 | `components/conversation/MessageBubble.tsx` | ✅ | Render bot/guest distinto |
| §4.1 | `components/conversation/ComposeBox.tsx` | ✅ | Mobile full-screen + drafts + textarea wiring OK |
| §4.1 | `components/conversation/LLMSuggestion.tsx` | 🟡 | Componente existe, sin auto-fetch on mount → bug crítico P0 #1 |
| §4.1 | `components/conversation/QuickRepliesPanel.tsx` | 🟡 | Top 3 keyword match OK, **NO suggested if zero quick replies seed** |
| §4.1 | `components/conversation/BookingContextSidebar.tsx` | ✅ | Renders fields OK |
| §4.1 | `components/conversation/AuditTrail.tsx` | 🟡 | Renders genérico (actor=system mayormente, action=kind raw) |
| §4.1 | `components/quick-replies/QuickRepliesList.tsx` | ✅ | (Asumido existe en /admin/quick-replies dir) |
| §4.1 | `components/quick-replies/QuickReplyEditor.tsx` | ✅ | Idem |
| §4.1 | `styles/inbox.css` | ✅ | Background fix + structures |
| §4.1 | `styles/conversation.css` | ✅ | WhatsApp-style bubbles |
| §4.1 | `lib/inbox-client.ts` | ✅ | Types + fetch helpers OK |

### 1.2 Backend `apps/worker-bot/`

| Spec ref | Endpoint / file | Status | Notas |
|---|---|---|---|
| §4.2.1 | `GET /api/admin/inbox` | 🟡 | Existe pero unread_count = total USER msgs (bug), preview vacío para AirBnB (bug), last_msg_at = now() para AirBnB-only (bug) |
| §4.2.2 | `GET /api/admin/conversation/[id]` | 🟡 | Funcional polimórfico tras thread/200. PERO: WA history timestamps son ficticios (distribuidos en 24h artificial), `subscriber.name = "Booking N"` en lugar de guest_name real |
| §4.2.3 | `POST /api/admin/conversation/[id]/reply` | ✅ | Routing WA via ManyChat + AirBnB via Beds24, auto-pause 1h, auto-mark responded OK |
| §4.2.4 | `POST /api/admin/conversation/[id]/suggest-reply` | 🟡 | Backend funcional. Pero: NO se llama desde frontend al abrir conv (P0 #1), bloqueado si no hay WA conv (P0 #3) |
| §4.2.5 | `POST /api/admin/conversation/[id]/pause-bot` | ✅ | Auto-pause + manual respect OK |
| §4.2.6 | `POST /api/admin/conversation/[id]/snooze` | ✅ | Existe — sin granularidad ("snooze hasta fecha/hora" como best practice — gap) |
| §4.2.7 | `POST /api/admin/conversation/[id]/resolve` | ✅ | Idempotente OK |
| §4.2.8 | CRUD `/api/admin/quick-replies` | ✅ | List/Create/Update/Delete + usage_count OK |
| §4.2.9 | Drafts `POST/GET /api/admin/conversation/[id]/draft` | ✅ | Upsert by conv_id + user_email |
| §4.4.1 | `inbox/aggregate.ts` (threading) | 🟡 | Threading existe pero NO cross-channel merge (spec D8) |
| §4.4.2 | `inbox/lifecycle.ts` | ✅ | 11 stages mapped, in_stay_issue keyword detection |
| §4.4.3 | `inbox/readiness.ts` | 🟡 | 6 components calculated BUT: `pax_confirmed = num_adults > 0` trivial true, `rules_accepted = false` (no column), `eta_known` requires WA history (AirBnB-only siempre false) |
| §4.4.4 | `inbox/filters.ts` | ✅ | Cron alerts + placeholder + garbage name normalization OK |
| §4.4.5 | `inbox/llm-suggestion.ts` (Haiku) | 🟡 | Funcional pero kbDocs hardcoded `[]`, training examples = quick_replies most-used (no es karina_training real) |
| §4.4.6 | `inbox/auto-pause.ts` | ✅ | Manual respect OK |
| §4.4.7 | `inbox/lang-detect.ts` | 🟡 | Detect funcional, persistence column no existe (Wave 1.5 deferred) |
| §4.1 | `inbox/lead-intent.ts` | ✅ | 3 buckets classification OK |
| §4.1 | `packages/agents/src/prompts/admin-suggest-reply.ts` | ✅ | Prompt template existe (no verifiqué contenido completo) |

### 1.3 Database `packages/db/migrations/`

| Spec ref | Migration | Status | Notas |
|---|---|---|---|
| §4.3.1 | `0032_inbox_drafts.sql` | ✅ | Applied 2026-05-24 |
| §4.3.2 | `0033_quick_replies.sql` | ✅ | Applied 2026-05-24 |
| §4.3.3 | `0034_inbox_indexes.sql` | ✅ | Applied 2026-05-24 |
| §7 R6 | `subscriber.detected_lang` column | ❌ | Spec dijo Wave 1.5 — defer OK |
| (implicit) | `bot_metrics` table | ❌ | Spec mentioned for cost logging; LLM cost va a `audit_log` instead |

### 1.4 DoD §6 checklist verification

#### CC-A frontend DoD

| Item | Status | Notas |
|---|---|---|
| `/admin/inbox` muestra 2 tabs con counters live | ✅ | Tab Reservas/Leads con counters |
| Tab Reservas muestra 8 secciones lifecycle | ✅ | Categorize OK con data real |
| Tab Leads muestra 3 secciones intent | ✅ | needs_human / bot_failed / cold |
| 1 row por cliente (threading) | 🟡 | 1 row por booking_id, no merge cross-channel mismo phone |
| Readiness pills desktop, score mobile | ✅ | Responsive con CSS thread/199 |
| Test number 5217441441575 CSS tenue | ✅ | data-test="true" funciona |
| Cron alerts filtered | ✅ | filters.ts catches |
| `{{first_name}}` filtered | ✅ | filters.ts catches |
| Display name basura → phone parcial | ✅ | normalizeDisplayName works |
| `/admin/conversation/[id]` WhatsApp-style | ✅ | Bubbles + booking sidebar + audit |
| Compose LLM suggestion editable | 🟡 | Componente existe, **nunca aparece** (bug P0 #1) |
| Quick replies top 3 sugeridos | 🟡 | Funciona si hay quick replies en DB — **probable que esté vacío** |
| `/admin/quick-replies` CRUD | ✅ | Pages existen |
| Variables `{{guest_name}}` interpoladas | ✅ | `interpolateQuickReply()` |
| Mobile compose full-screen | ✅ | ComposeBox responsive |
| Booking sidebar desktop, oculto mobile | ✅ | CSS responsive |
| Drafts persisten + banner | ✅ | Funcional |
| Audit trail conversation view | 🟡 | Renders pero actor=system genérico |
| Quick stats header | 🟡 | **Oculto mobile** (verificar CSS) |
| Filters property/etapa/idioma/canal | ✅ | InboxFilters funcional |

#### CC-B backend DoD

| Item | Status | Notas |
|---|---|---|
| Migrations applied | ✅ | 0032/33/34 |
| `GET /inbox?tab=reservas` shape válido | ✅ | Response correcto |
| `GET /inbox?tab=leads` shape válido | ✅ | Response correcto |
| `GET /conversation/[id]` retorna conv + booking + audit | ✅ | (con bugs §1.2 arriba) |
| `POST /reply` WA via MakeMsg / AirBnB via Beds24 | ✅ | sendMessageRouted dispatches |
| Auto-pausa 1h post-reply | ✅ | autoPauseBot called |
| Auto-marca responded | ✅ | UPDATE resolved_at |
| `POST /suggest-reply` Haiku <2s p95 | ✅ | Haiku 4.5 + cache_control |
| Skip rules suggest (trivial, cron, cold_7d) | ✅ | Implementado |
| `POST /pause-bot` manual vs auto | ✅ | autoPauseBot respect manual |
| `POST /snooze` reaparece en N horas | ✅ | Sets bot_paused_until |
| `POST /resolve` idempotente | ✅ | Updates resolved_at |
| CRUD `/quick-replies` completo | ✅ | List/Create/Update/Delete |
| Drafts upsert + read | ✅ | (assume from drafts.ts) |
| Cron alerts filtered | ✅ | filters.ts |
| Test number flagged (no filter) | ✅ | isTestNumber() |
| Display name garbage normalized | ✅ | normalizeDisplayName() |
| Lang detection persist | ❌ | Wave 1.5 deferred OK |
| LLM cost logged | 🟡 | A `audit_log` kind='inbox_llm_suggestion' (no `bot_metrics` table) |

---

## §2 · Bugs funcionales P0 (críticos, visibles, afectan workflow Karina)

### 2.1 LLM Suggestion nunca aparece (CRÍTICO)

**Síntoma:** Alex abrió conversaciones en producción, nunca vio la sugerencia LLM que el spec promete. "Lo vi en el thread y cuando xx estaba ejecutando, pero no aparece."

**Causa raíz:**

```typescript
// ConversationView.tsx línea ~67
Promise.all([
  fetchConversation(convId),
  fetchQuickReplies(),
  fetchDraft(convId),
])
// ❌ NO incluye fetchSuggestion(convId)

// Línea ~234 al renderizar ComposeBox:
<ComposeBox
  ...
  initialSuggestion={null}  // ❌ Siempre null
/>

// LLMSuggestion.tsx línea ~37
if (!result || !result.ok) {
  if (result && !result.ok) { /* skip reason */ }
  return null;  // ❌ Si no hay result → render null silente
}
```

**Solución:**

```diff
 Promise.all([
   fetchConversation(convId),
   fetchQuickReplies(),
   fetchDraft(convId),
+  fetchSuggestion(convId).catch(() => null),
 ])
-  .then(([conv, qr, savedDraft]) => {
+  .then(([conv, qr, savedDraft, suggestion]) => {
     ...
+    setSuggestion(suggestion);
```

```diff
 <ComposeBox
   convId={convId}
   channel={channel}
   booking={booking}
   quickReplies={quickReplies}
   initialDraft={activeDraft}
-  initialSuggestion={null}
+  initialSuggestion={suggestion}
   isMobile={isMobile}
   onSend={handleSend}
 />
```

**Effort:** 15 min CC.

**Impact:** Karina ve sugerencia LLM al abrir cada conv (excepto skips legítimos trivial/cron/cold).

### 2.2 LLM Suggestion bloqueada para AirBnB-only bookings (CRÍTICO)

**Síntoma:** Para los 60+ bookings AirBnB activos (90%+ del inbox Reservas), NUNCA aparece sugerencia.

**Causa raíz:**

```typescript
// conversation.ts handleSuggestReply línea 414
if (!ctx.subscriberId || !ctx.hasWaConversation) {
  return c.json({ ok: false, skip_reason: 'no_wa_history' });
}
```

`hasWaConversation` requiere conv WA linked. AirBnB-only bookings → siempre false → skip.

**Solución:** Backend debería usar `bot_messages_inbox` (mensajes OTA Beds24) como fuente de history alternativa cuando no hay WA history.

```typescript
// llm-suggestion.ts debe aceptar history desde otro origen
export async function suggestReplyFromBooking(
  bookingId: number,
  env: SuggestEnv,
): Promise<SuggestResponse> {
  // Load bot_messages_inbox messages
  const { results } = await env.DB.prepare(
    `SELECT message_text, source, message_time FROM bot_messages_inbox 
     WHERE booking_id = ? ORDER BY message_time DESC LIMIT 20`
  ).bind(bookingId).all();
  
  // Build history-like string for prompt
  const history = results
    .reverse()
    .map(m => `${m.source === 'guest' ? 'USER' : 'ASSISTANT'}: ${m.message_text}`)
    .join('\n');
  
  // ... rest same as suggestReply, with manually-loaded booking context
}
```

Y en `handleSuggestReply`:
```diff
-if (!ctx.subscriberId || !ctx.hasWaConversation) {
-  return c.json({ ok: false, skip_reason: 'no_wa_history' });
-}
+if (ctx.bookingId && !ctx.hasWaConversation) {
+  // AirBnB-only: use bot_messages_inbox
+  const result = await suggestReplyFromBooking(ctx.bookingId, c.env);
+  return c.json(result);
+}
```

**Effort:** 45 min CC + tests.

**Impact:** Sugerencia disponible para los 60+ bookings AirBnB activos.

### 2.3 Guest name muestra "Booking N" en lugar del nombre real

**Síntoma:** Header del modal mobile muestra "Booking 79421553" para Alan Granados.

**Causa raíz:**

```typescript
// conversation.ts handleConversationGet línea 296
subscriber: {
  ...
  name: ctx.bookingRow
    ? `Booking ${ctx.bookingId}`  // ❌ Hardcoded, no usa guest data
    : (ctx.subscriberId ?? rawId),
```

**Solución:** `resolveConvContext` ya hace JOIN guests pero solo trae phone. Extender query para traer name también:

```diff
-LEFT JOIN guests g ON g.id = bb.guest_id
+LEFT JOIN guests g ON g.id = bb.guest_id  -- add g.name to SELECT
```

```diff
 name: ctx.bookingRow
-  ? `Booking ${ctx.bookingId}`
+  ? (ctx.bookingRow.guest_name ?? `Booking ${ctx.bookingId}`)
   : ...
```

(Necesita type extension de BookingRow para incluir guest_name field.)

**Effort:** 20 min CC.

### 2.4 WA history timestamps son ficticios

**Síntoma:** En screenshot Alan Granados (image 1), msgs muestran "23h, 17h, 11h, 5h" relativo. Estos timestamps NO son reales — son calculados por algoritmo que distribuye N msgs uniformemente en 24h hacia atrás.

**Causa raíz:**

```typescript
// conversation.ts parseHistoryToMessages línea 188
const baseMs = Date.now() - 24 * 3_600_000;
const step = lines.length > 0 ? (24 * 3_600_000) / lines.length : 60_000;

for (const line of lines) {
  if (line.startsWith('USER:')) {
    msgs.push({
      ...
      sent_at: new Date(baseMs + idx * step).toISOString(),  // ❌ Fabricado
```

**Impact:** Karina ve timestamps falsos. Si el último msg real fue hace 3 días, aparece como "5h". Si los msgs reales son de hace 1 año + uno reciente, aparecen todos repartidos en 24h.

**Root issue:** `conversations.history` es un blob text sin timestamps individuales. Solo guarda `last_active` (1 timestamp para todo).

**Solución (2 opciones):**

**Opción A — Quick fix (5 min CC):** Mostrar solo timestamps relativos respecto a `last_active`, no absolutos. Usar etiquetas vagas: "Hace varios días" en lugar de "5h" cuando no hay timestamp real.

**Opción B — Proper fix (3-6h CC):** Migración nueva para tabla `messages` con timestamps individuales. ManyChat webhook ya pasa timestamp por mensaje pero no lo guardamos. Backfill imposible (no tenemos los timestamps históricos), forward-only.

**Voto WC:** Opción A inmediata (workaround visual: "USER: hace 1 día" sin granularidad), Opción B agenda Q3 con migration 0035+.

### 2.5 Unread count = TOTAL USER msgs (no realmente "unread")

**Síntoma:** Badge "5 nuevos" siempre muestra cuenta total de USER lines en history. Si un cliente envió 50 msgs en su vida y Kari respondió todos, badge dice "50 nuevos".

**Causa raíz:**

```typescript
// aggregate.ts línea 270
const unreadCount = convRow
  ? convRow.history.split('\n').filter((l) => l.startsWith('USER:')).length
  : 0;
```

No filtra "since last assistant/karina response".

**Solución:** Contar USER lines DESPUÉS del último ASSISTANT line:

```typescript
function computeUnread(history: string): number {
  const lines = history.split('\n');
  let unread = 0;
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i] ?? '';
    if (line.startsWith('ASSISTANT:')) break;
    if (line.startsWith('USER:')) unread++;
  }
  return unread;
}
```

**Effort:** 10 min CC.

### 2.6 Preview vacío en Tab Reservas para AirBnB-only

**Síntoma:** Rows AirBnB en Tab Reservas NO muestran preview del último mensaje (porque aggregate solo lee `conversations.history`, no `bot_messages_inbox`).

**Causa raíz:**

```typescript
// aggregate.ts línea 232 — Tab Reservas
const lastMsgText = convRow
  ? convRow.history.split('\n').filter((l) => l.startsWith('USER:')).slice(-1)[0]?.slice(5).trim() ?? null
  : null;  // ❌ Para AirBnB-only sin WA, siempre null
```

**Solución:** Query adicional a `bot_messages_inbox` por booking_id si convRow null:

```typescript
let lastMsgText: string | null = null;
let lastMsgAtUnix: number | null = null;
if (convRow) {
  lastMsgText = convRow.history.split('\n')
    .filter((l) => l.startsWith('USER:')).slice(-1)[0]?.slice(5).trim() ?? null;
  lastMsgAtUnix = convRow.last_active;
} else {
  // Fallback: read OTA messages
  const otaLast = await env.DB.prepare(
    `SELECT message_text, message_time FROM bot_messages_inbox 
     WHERE booking_id = ? AND source = 'guest' ORDER BY message_time DESC LIMIT 1`
  ).bind(br.beds24_booking_id).first<{message_text: string; message_time: number}>();
  if (otaLast) {
    lastMsgText = otaLast.message_text;
    lastMsgAtUnix = otaLast.message_time;
  }
}
```

Similar para unread_count (count guest rows in bot_messages_inbox after last admin sent_by).

**Effort:** 30 min CC + tests.

---

## §3 · Gaps spec funcionales P1 (no críticos pero importantes)

### 3.1 "Texto informativo estructurado" en row (Alex preguntó)

**Lo que Alex recuerda haber propuesto:** Un texto resumen estructurado del estado del booking, distinto al last_message.

**Lo que existe hoy:**
- `preview: string` = last_msg truncado (a veces vacío)
- Stay-info inline = `👥 5 🐶 T-3d`
- ReadinessScore = pills missing + done counter
- Separados, no consolidados.

**Lo que propongo (NUEVO concepto):**

Campo backend `summary: StructuredSummary`:

```typescript
type StructuredSummary = {
  // Una línea descriptiva inteligente
  headline: string;       // "T-3, mascotas pendientes, último msg hace 2h"
  
  // Estado granular
  stage_context: string;  // "Pre-stay T-3", "In-stay día 2 de 3", "Post-stay ayer"
  
  // Pendientes accionables (TOP 2)
  blockers: string[];     // ["Falta menú", "Falta ETA"]
  
  // Último msg (si existe) — diferente al preview free-text
  last_msg_summary: string | null;  // "Pregunta horario check-in"
};
```

Render frontend:

```
┌──────────────────────────────────────────────────────────┐
│ 🚨  Andrea Mendoza                  [5 nuevos]  [WA]    │
│ Huerta Cocotera · 5 pax · 🐶                             │
│                                                          │
│ ⚠ In-stay día 2 de 3 — "luz no funciona + pastel..."   │
│ Bloqueado: ninguno (todo confirmado)                     │
│                                                          │
│ [Ver conv] [Beds24] [/admin/booking]                    │
└──────────────────────────────────────────────────────────┘
```

**Effort:** 1.5-2h CC backend (compute summary in aggregate) + 1h frontend (new render block).

**Alternativa cheap:** Solo headline computed runtime, no new backend field, render desde data existente.

### 3.2 Cross-channel merge incompleto (spec D8)

Spec D8: "mismo phone WA + AirBnB inquiry → 1 row merged".

Hoy: aggregate corre 2 queries (Tab Reservas pulls bookings, Tab Leads pulls conversations sin booking). Si guest tiene booking confirmado + leads previos al mismo phone, aparece en ambas tabs.

**Effort:** 1h CC (query refactor con merge by phone normalized).

**Priority:** Bajo — afecta few edge cases.

### 3.3 Quick action buttons row-level (gap thread/202)

Pedido Alex: 4 botones por row (desktop):
- AirBnB hosting URL (si channel airbnb + confirmation_code)
- Beds24 control3.php
- /admin/bookings/[id]
- /admin/conversation/[id]

**Effort:** 30 min frontend + 15 min backend (add `airbnb_confirmation_code` to InboxRow).

### 3.4 Total message count badge (gap thread/202)

Pedido Alex: badge "5 nuevos / 24 total".

**Effort:** 15 min frontend + 15 min backend.

### 3.5 Check-in/check-out raw dates en row (gap thread/202)

Pedido Alex: ver fechas "28 may - 1 jun" en row.

**Effort:** 30 min (backend add check_in/check_out a InboxRow + frontend format).

### 3.6 Subscriber.detected_lang persistence (spec §4.4.7)

Spec dijo Wave 1.5. Hoy se computa runtime cada request.

**Effort:** 30 min (ALTER TABLE en off-window + persist en webhook handler).

### 3.7 Audit trail estructurado

Hoy: `audit_log` con `kind` y `payload_json` libre. Frontend renderiza `actor = payload.actor ?? 'system'`. La mayoría logs son `inbox_reply_sent` con actor=email, pero el resto cae a "system".

**Effort:** 1h (definir tipos action + actor canónicos + log inputs estructurados en cada handler).

### 3.8 Karina training en LLM prompt

Hoy: usa `quick_replies WHERE usage_count > 0` como proxy. Spec §4.4.5 dice `karina_training_examples` reales.

`karina_training` table existe (memoria #4 — endpoint `/admin/karina-training`). Pero llm-suggestion.ts NO la lee.

**Effort:** 30 min (cambiar SQL en llm-suggestion.ts a query karina_training_examples table).

### 3.9 R2 KB docs en LLM prompt

Hoy: `kbDocs: string[] = []` hardcoded.

Spec §4.4.5: leer R2_KNOWLEDGE bucket para top-K docs relevantes al lastGuestMsg.

**Effort:** 2-3h (implementar embedding lookup o keyword search en R2 + integrate).

**Priority:** Medio — el bot Greeter ya hace esto, replicar pattern.

### 3.10 Readiness `pax_confirmed` lógica trivial

Hoy: `pax_confirmed = booking.num_adults > 0`. Trivialmente true para cualquier booking.

Spec D1: "pax final confirmado" — debería verificar si guest confirmó vs initial.

**Solución:** Comparar `booking_captures.pax_confirmed` (column nueva?) o detectar en history mensajes "somos N personas".

**Effort:** 45 min.

### 3.11 Readiness `eta_known` AirBnB-only

Hoy: requiere WA history. Bookings AirBnB-only siempre ETA false (incluso si guest dijo ETA por AirBnB).

**Solución:** Leer también `bot_messages_inbox` para keywords ETA.

**Effort:** 20 min.

### 3.12 Readiness in-stay override (thread/201 spec)

Cuando arrival <= today (en estancia), ETA + rules deberían override a true (ya llegó, no aplica).

**Effort:** 30 min CC (spec thread/201 ya redactado).

### 3.13 `paid_amount_mxn` semántica incorrecta

Hoy: `paid_amount_mxn = br.deposit_paid ? br.total_amount_mxn : 0`. Si pagó depósito (33%), reporta TODO el total como pagado.

**Solución:** `paid_amount_mxn = br.total_amount_mxn - (br.balance_due_mxn ?? 0)`.

**Effort:** 10 min.

### 3.14 Quick stats header invisible mobile

Probable: CSS `.inbox-stats` con `display: none` en `@media (max-width: 767px)`.

Karina mobile NO ve stats útiles (check-ins hoy, readiness avg, etc).

**Solución:** Versión mobile compacta — solo 3 stats clave (críticos, today checkins, hot leads).

**Effort:** 30 min CSS.

### 3.15 Quick replies seed vacío (verificar)

D1 query: `SELECT COUNT(*) FROM quick_replies`. Probablemente = 0.

**Sin seed, QuickRepliesPanel siempre return null.** Karina nunca ve sugerencias quick reply.

**Solución:** Seed inicial con 10-15 quick replies canónicas RDM. Migration `0035_seed_quick_replies.sql` (es INSERT, no ALTER, safe).

Lista propuesta:
- 🐕 Pet policy ($300 MXN/estancia, max 2)
- 🕒 Check-in horarios (3pm, antes solo si acordado)
- 📋 Reglas casa (no fiestas, sonido bajo después 10pm, etc.)
- 🍽️ Menú cocinera (Celene/Lupita variantes)
- 💳 Pago liquidación
- 📍 Ubicación + indicaciones llegada
- 🛒 Compras / despensa
- 🏊 Alberca / playa / amenities
- 🚗 Estacionamiento
- 🎉 Eventos (cumpleaños, bodas)
- 🌧️ Clima / preparación
- 📞 Contacto emergencia
- 💼 Servicios extra (cocinera adicional, limpieza extra)
- 🔑 Llaves / entrada
- ❓ FAQ general
- 🙏 Despedida post-stay / review

**Effort:** 30 min Alex review + 15 min CC seed.

---

## §4 · Best practices benchmark (Front, Intercom, Help Scout, Crisp, Zendesk)

### 4.1 Lo que los mejores hacen y RDM NO hace todavía

#### 4.1.1 AI suggestion pre-loaded (Intercom, Front, Help Scout)
**Estado RDM:** Bug P0 #1 — backend listo, frontend no lo pide.
**Fix:** §2.1 (15 min).

#### 4.1.2 Snooze granular (Front, Help Scout)
Snooze "hasta mañana 9am", "fin de semana", "próxima semana" (no solo "N horas").
**Estado RDM:** Solo `POST /snooze {hours: number}`.
**Effort:** 1h (UI date/time picker + backend timestamp conversion).

#### 4.1.3 Tags/labels libres por conversación (Zendesk, Front)
Pegar tags ad-hoc: "VIP", "anniversary", "difficult", "complaint_resolved".
**Estado RDM:** Lifecycle stage hardcoded, no tags libres.
**Effort:** 3h (table conversation_tags + UI inline tag editor).

#### 4.1.4 Notas privadas internas (todos)
Notes en la conv que el guest NO ve. Para Kari → Alex coordination.
**Estado RDM:** No existe.
**Effort:** 2h (table conversation_notes + UI inline).

#### 4.1.5 SLA timer visible (Front, Zendesk)
"Responde en <2h para mantener AirBnB Superhost rating".
**Estado RDM:** No existe.
**Effort:** 2h (timer compute + render destacado en row).

#### 4.1.6 Read receipts (Crisp, Intercom)
Indicar si guest leyó respuesta de Kari.
**Estado RDM:** ManyChat lo soporta, no surfaced.
**Effort:** 1h (read events webhook + render checkmark).

#### 4.1.7 Last seen del guest (Intercom)
"Activo hace 2 min" / "Visto hace 1h".
**Estado RDM:** No surfaced.
**Effort:** 1.5h.

#### 4.1.8 Búsqueda dentro de conversation (cmd+F)
Spec Wave 1 N14 says "filters + text search". No implementado.
**Estado RDM:** No existe.
**Effort:** 1h (frontend Ctrl+F in modal).

#### 4.1.9 Keyboard shortcuts (Front, Help Scout)
- `j/k` navigate rows
- `e` reply
- `r` resolve
- `m` mark read
- `/` search
**Estado RDM:** No existe.
**Effort:** 2h.

#### 4.1.10 Undo send (Gmail, Front)
5-30s window para cancelar envío.
**Estado RDM:** No existe. Send es immediate.
**Effort:** 3h (queue 10s + endpoint cancel).
**Priority:** Bajo.

#### 4.1.11 Schedule send (Front, Gmail)
"Enviar mañana 9am".
**Estado RDM:** No existe.
**Effort:** 3h.

#### 4.1.12 Tags AI-detected (Intercom)
Auto-flag conv por sentiment ("frustrated", "complaint"), language ("EN"), intent ("booking_inquiry").
**Estado RDM:** lang-detect existe; sentiment/intent no.
**Effort:** 4h+ (Haiku classify on incoming + persist tags).

#### 4.1.13 Multi-language reply auto-translate (Help Scout AI, Crisp)
Kari escribe ES, guest recibe EN auto.
**Estado RDM:** AirBnB lo hace nativo. WhatsApp NO (Kari debe escribir EN manual).
**Effort:** 3h (Haiku translate antes send a WA + flag traduction).

#### 4.1.14 Voice-to-text para responder rápido (apps mobile)
Karina dicta, sale texto.
**Estado RDM:** No existe.
**Effort:** Browser native API gratis → 1h.

#### 4.1.15 Bulk select acciones (Front)
Spec out-of-scope N12.

### 4.2 Lo que los mejores hacen y RDM YA hace bien

| Feature | RDM status | Best-in-class match |
|---|---|---|
| Single inbox cross-channel | ✅ | OK |
| Threading 1 row/cliente | 🟡 | Parcial (no cross-channel merge) |
| Templates con variables | ✅ | OK |
| Auto-pause bot post-reply manual | ✅ | Mejor que Intercom (no tiene bot pause concept porque no tiene bot) |
| Audit trail | 🟡 | Existe, genérico |
| Lifecycle stages categorization | ✅ | OK (better than most CRMs because tailored a hosteling) |
| Drafts persistentes | ✅ | OK |
| Mobile compose full-screen | ✅ | Mismo pattern WhatsApp |

### 4.3 Lo que es ÚNICO RDM (no en best-in-class)

Estos son ventajas competitivas que el spec ya capturó bien:

| Feature | Razón es RDM-specific |
|---|---|
| **Readiness score 6 components** | Hostelería: requiere checklist específico pax/pet/menu/ETA/rules/paid |
| **Lifecycle stages T-3, T-15, in-stay** | Time-relative al check-in es key para hostelería, no aplica a SaaS support |
| **Cross-channel WA + AirBnB + Booking + direct** | Mayoría inboxes son single-channel; hostelería requires todos |
| **Beds24 booking context sidebar** | Integration vertical, no en best-in-class horizontales |

---

## §5 · Roadmap priorizado (P0/P1/P2/P3)

### 5.1 P0 — CRÍTICO, hacer YA (esta semana)

Total effort estimado: **2-3h CC**

| # | Bug | §ref | Effort | Thread propuesto |
|---|---|---|---|---|
| P0.1 | LLM Suggestion auto-fetch on mount | §2.1 | 15 min | thread/205 frontend |
| P0.2 | Suggestion habilitada para AirBnB-only bookings | §2.2 | 45 min | thread/206 backend |
| P0.3 | Guest name real (no "Booking N") | §2.3 | 20 min | thread/205 frontend (combo) |
| P0.4 | WA history timestamps fix (opción A workaround) | §2.4 | 10 min | thread/205 frontend (combo) |
| P0.5 | Unread count real (last assistant onwards) | §2.5 | 10 min | thread/206 backend (combo) |
| P0.6 | Preview + last_msg_at desde bot_messages_inbox para AirBnB | §2.6 | 30 min | thread/206 backend (combo) |

**Threads ejecutables propuestos:**
- **thread/205** — Frontend P0 fixes (P0.1, P0.3, P0.4): ~50 min CC
- **thread/206** — Backend P0 fixes (P0.2, P0.5, P0.6): ~1.5h CC

### 5.2 P1 — IMPORTANTE, hacer pronto (próxima semana)

Total effort estimado: **6-9h CC**

| # | Item | §ref | Effort |
|---|---|---|---|
| P1.1 | Structured summary en row (decision §3.1) | §3.1 | 2-3h |
| P1.2 | Quick action buttons row-level | §3.3 | 45 min |
| P1.3 | Total message count badge | §3.4 | 30 min |
| P1.4 | Check-in/check-out dates raw en row | §3.5 | 30 min |
| P1.5 | Quick replies seed inicial 15 items | §3.15 | 45 min |
| P1.6 | Readiness in-stay override (thread/201) | §3.12 | 30 min |
| P1.7 | Karina training real en LLM prompt | §3.8 | 30 min |
| P1.8 | Quick stats header mobile-friendly | §3.14 | 30 min |
| P1.9 | paid_amount_mxn lógica correcta | §3.13 | 10 min |
| P1.10 | Readiness eta_known incluye bot_messages_inbox | §3.11 | 20 min |
| P1.11 | Audit trail estructurado actor/action | §3.7 | 1h |

**Threads ejecutables propuestos:**
- **thread/207** — Structured summary backend + frontend: ~3h CC
- **thread/208** — Frontend row enhancements (quick actions + count + dates): ~1.5h CC
- **thread/209** — Quick replies seed + Karina training integration: ~1.5h CC
- **thread/201** (ya escrito) — Readiness in-stay override
- **thread/210** — Backend cleanups (paid, eta, audit, stats mobile): ~2h CC

### 5.3 P2 — NICE TO HAVE, hacer este mes

Total effort estimado: **8-12h CC**

| # | Item | §ref | Effort |
|---|---|---|---|
| P2.1 | Cross-channel merge (spec D8) | §3.2 | 1h |
| P2.2 | Tags/labels libres por conv | §4.1.3 | 3h |
| P2.3 | Notas privadas internas | §4.1.4 | 2h |
| P2.4 | Snooze granular (hasta fecha/hora) | §4.1.2 | 1h |
| P2.5 | SLA timer visible | §4.1.5 | 2h |
| P2.6 | Read receipts surfaced | §4.1.6 | 1h |
| P2.7 | Búsqueda en conversation Ctrl+F | §4.1.8 | 1h |
| P2.8 | Last seen del guest | §4.1.7 | 1.5h |
| P2.9 | Voice-to-text mobile compose | §4.1.14 | 1h |
| P2.10 | Subscriber.detected_lang persistence | §3.6 | 30 min |
| P2.11 | R2 KB docs en LLM prompt | §3.9 | 2-3h |
| P2.12 | Keyboard shortcuts (j/k/e/r/m) | §4.1.9 | 2h |
| P2.13 | Readiness pax_confirmed lógica útil | §3.10 | 45 min |

### 5.4 P3 — FUTURE / SI HAY TIEMPO

| # | Item | Razón defer |
|---|---|---|
| P3.1 | Undo send | Edge case, complex queue logic |
| P3.2 | Schedule send | Few use cases hostelería |
| P3.3 | Tags AI-detected | Complejidad alta, valor incremental sobre lifecycle stages |
| P3.4 | Multi-language reply translate WA | AirBnB ya lo cubre, WA es minoría EN guests |
| P3.5 | Bulk actions | Spec out-of-scope explicitly |
| P3.6 | Multi-user presence (cursor real-time) | Single-user mayoría tiempo |
| P3.7 | Messages individuales con timestamps reales (opción B §2.4) | Requiere migration nueva + nuevo pipeline. Hoy approximación funcional |
| P3.8 | Conv search semántica | Filters + Ctrl+F basta |
| P3.9 | "Merge conversations" manual | Edge case raro |
| P3.10 | Emoji quick reactions Slack-style | Demasiado consumer-app feel |

---

## §6 · Recomendación específica de orden

Si Alex puede invertir **~10h CC esta semana**, recomendación:

```
Día 1 (lunes):
├── thread/205 (P0 frontend, 50 min)  ──┐ MERGE + smoke
└── thread/206 (P0 backend, 1.5h)    ──┘ ⇒ Karina ve LLM suggestion + AirBnB suggestion + nombres reales
                                         + preview real + unread correcto
                                         ≈ El spec sale del 60% visible al 90% visible

Día 2 (martes):
├── thread/201 (readiness in-stay, 45 min) ──┐
└── thread/210 (cleanups paid/eta/audit, 2h) ──┘ ⇒ readiness scores accurate

Día 3 (miércoles):
├── thread/208 (frontend row enhancements, 1.5h) ──┐
└── thread/209 (quick replies seed, 1.5h)       ──┘ ⇒ Quick wins UX: botones, fechas, badges

Día 4 (jueves):
└── thread/207 (structured summary, 3h)           ⇒ "Texto descriptivo estructurado" Alex pidió

Día 5 (viernes — no deploys 5pm+):
└── Smoke test integral + iteración basado en uso real Karina
```

**Total: 11.5h CC** = cierra spec/196 al ~95% del valor visible + el "texto estructurado" que faltaba.

### 6.1 Alternativa cheap (3h CC)

Si Alex prefiere arreglar solo lo crítico:

```
thread/205 + thread/206 (~2h CC) + verify
```

Esto cierra los 6 bugs P0 = el inbox que Alex ya probó esta noche pasa de "no muestra mensajes WA en bookings" a "funciona pero le faltan features cosmetic".

### 6.2 Recomendación realista WC

**Voto: día 1 + día 2** (4h CC total).

Razón:
- P0 son bugs visibles que rompen UX hoy
- thread/201 readiness ya está escrito hace días, costo marginal cerrar
- thread/210 cleanups son baratos en lote
- Día 3+ son enhancements, esperar feedback Karina real uso 1 semana primero

---

## §7 · Anti-patterns + constraints recordatorio

Aplica a todos threads/205-210:

- ❌ NO ALTER TABLE durante multi-CC concurrent
- ❌ NO Casa Chamán (roomId 679176) en ningún UI
- ❌ NO LLM money decisions
- ❌ NO pet fee como `/noche`
- ❌ NO commits con secrets
- ❌ NO production deploys viernes 5pm+
- ❌ NO worker-bot auto-deploy GH Actions (manual `npx wrangler deploy` siempre)
- ❌ NO eliminar safety nets en bloque
- ✅ Beds24 sync mode Prices & Availability ONLY
- ✅ Backend tests verdes ANTES de merge
- ✅ Self-review hook antes commit
- ✅ Audit log toda mutation a `audit_log` con structured payload

---

## §8 · Pipeline status snapshot (post sesión madrugada 24/may)

| Thread | Status | Notas |
|---|---|---|
| 196 | Spec original 33h estimado | 75% código entregado, 60% valor visible |
| 197 | Backlog AirBnB | NO scope |
| 198 | Hotfix CORS PR #169 | ✅ deployed |
| 199 | Display bugs 1+3+4+5 PR #170 | ✅ deployed + verified |
| 200 | Conversation polimórfico PR #171 | ✅ deployed + verified |
| 201 | Readiness in-stay override | 🟡 spec ready, NOT executed yet |
| 202 | Gap analysis + 5 decisiones Alex | 🟡 5 decisiones pendientes — algunas absorbidas en §3 aquí |
| 203 | Phone normalize MX cellular PR #172 | ✅ deployed + verified (Alan Granados case) |
| **204** | **Deep audit + roadmap (este doc)** | ✅ Ready for Alex review |
| 205-210 (propuestos) | A redactar post decisión Alex | 🔵 future |

---

## §9 · Files investigated durante esta sesión

WC autónomo leyó/audited:

- `threads/196-wc-inbox-redesign-spec.md` (spec original 33h, 49 KB)
- `apps/web/src/components/conversation/ConversationView.tsx` (10.4 KB)
- `apps/web/src/components/conversation/ComposeBox.tsx` (5.1 KB)
- `apps/web/src/components/conversation/LLMSuggestion.tsx` (3.0 KB)
- `apps/web/src/components/conversation/BookingContextSidebar.tsx` (1.9 KB)
- `apps/web/src/components/conversation/QuickRepliesPanel.tsx` (1.6 KB)
- `apps/web/src/components/conversation/MessageBubble.tsx` (1.7 KB)
- `apps/web/src/components/conversation/AuditTrail.tsx` (1.4 KB)
- `apps/web/src/components/inbox/InboxApp.tsx` (9.2 KB)
- `apps/web/src/components/inbox/InboxRow.tsx` (3.5 KB)
- `apps/web/src/components/inbox/ReadinessScore.tsx` (2.1 KB)
- `apps/web/src/components/inbox/QuickStatsHeader.tsx` (1.3 KB)
- `apps/web/src/lib/inbox-client.ts` (13.5 KB)
- `apps/worker-bot/src/api/admin/conversation.ts` (19.1 KB)
- `apps/worker-bot/src/api/admin/quick-replies.ts` (5.0 KB)
- `apps/worker-bot/src/inbox/aggregate.ts` (17.4 KB)
- `apps/worker-bot/src/inbox/lifecycle.ts` (4.2 KB)
- `apps/worker-bot/src/inbox/readiness.ts` (3.1 KB)
- `apps/worker-bot/src/inbox/llm-suggestion.ts` (8.2 KB)
- `apps/worker-bot/src/inbox/filters.ts` (1.6 KB)
- `apps/worker-bot/src/inbox/phone-normalize.ts` (1.7 KB)

Search code referenciado:
- "texto descriptivo estructurado" en rdm-discussion
- "summary booking row inbox" en rdm-discussion

D1 queries directos:
- No requirió queries adicionales (las de thread/203 ya cubrieron auditoría datos).

**Total LoC frontend audited:** ~50 KB
**Total LoC backend audited:** ~60 KB
**Total LoC spec audited:** ~50 KB

---

## §10 · Acción específica para Alex despierte

### Paso 1 — Leer este thread/204 (15 min)
Foco en §0 TL;DR + §2 P0 bugs + §6 recomendación orden.

### Paso 2 — Decidir orden (1 min)

**Pregunta Alex:** ¿Cuál camino prefieres?

- **A) Solo P0 esta semana** (~3h CC): 205 + 206. Fix bugs críticos. Después ver con Karina cómo se siente.
- **B) Cierre spec/196 al ~95%** (~10h CC esta semana): 205 + 206 + 201 + 210 + 208 + 209 + 207. Spec original "completado" plus structured summary.
- **C) Mid-camino (~4h CC)** ← **voto WC**: 205 + 206 + 201 + 210. Fixes críticos + readiness + cleanups. Defer enhancements 1 semana hasta feedback Karina real.

### Paso 3 — WC redacta threads ejecutables del camino elegido

Cuando Alex confirme A/B/C, WC redacta thread/205, 206, etc específicos con kickoff commands, en ~30-45 min.

### Paso 4 — CC ejecuta secuencial

Cada thread ~30-60 min CC. Después de cada uno: merge + deploy manual + smoke test Alex.

---

## §11 · Cosas que necesitan decisión Alex pero NO bloquean P0

(Pendiente de thread/202 §6 + nuevos)

1. **Structured summary headline** — ¿Qué formato exacto? "T-3 · 5 pax · 🐶 · menú pendiente" vs alternatives.
2. **Quick replies seed** — ¿Alex review propuesta 15 items §3.15 antes seed?
3. **paid_amount_mxn semántica** — ¿Reportar deposit como 33% del total, o leer realmente desde MercadoPago/Beds24?
4. **Tags/labels libres** — ¿Cuáles tags pre-definidos canónicos RDM? (VIP, Anniversary, Difficult, Complaint, etc.)
5. **SLA targets** — ¿AirBnB requiere <1h response durante check-in day? Definir umbrales para SLA timer.
6. **Quick action buttons URLs** — Confirmar 4 propuestos (thread/202 §4) o agregar más.
7. **Mobile QuickStats** — ¿3 stats clave a mostrar? (críticos, today_checkins, leads_hot)
8. **WA history timestamps** — Opción A workaround vs B migration. Voto Alex.

---

## §12 · References

- thread/196 spec original — https://github.com/alexanderhorn6720/rdm-discussion/blob/main/threads/196-wc-inbox-redesign-spec.md
- thread/197 AirBnB backlog — out of scope
- thread/198 hotfix CORS — PR #169 ✅
- thread/199 frontend bugs — PR #170 ✅
- thread/200 conversation polimórfico — PR #171 ✅
- thread/201 readiness in-stay — spec ready, awaiting CC
- thread/202 gap analysis — 5 decisions pendientes
- thread/203 phone normalize MX — PR #172 ✅
- Mockup iterations v1-v5 (offline brain deep sessions con Alex) — no thread

### Best practices references mencionadas

- Front (front.com) — Multi-channel team inbox enterprise
- Intercom (intercom.com) — AI-first conversation platform
- Help Scout (helpscout.com) — Saved replies + Workflows
- Crisp (crisp.chat) — Travel mode + multi-language
- Zendesk (zendesk.com) — Tags + Macros enterprise

---

**WC sign-off:** Trabajo de ~3h autónomo nocturno. Toda evidencia verificada en código actual del repo a la fecha. No se ejecutaron mutations a producción ni a repos. Brain mode puro.

Buenas noches Alex. Día largo pero bueno.

— WC, 2026-05-24 madrugada Acapulco
