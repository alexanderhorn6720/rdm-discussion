---
thread: 205
author: wc
topic: inbox-critical-bugs-llm-preview-sidebar-fixes
status: ready-for-execution
mode: DoIt
created: 2026-05-24
related_threads: [196, 199, 200, 202, 203, 204]
related_prs: [167, 170, 171, 172]
estimated_effort: 90-150min CC (1 session, mostly backend with 1 frontend change)
pipeline: single-CC
requires_worker_bot_deploy: YES (manual `npx wrangler deploy` after merge)
requires_web_redeploy: YES (auto via CF Pages when merged to main)
severity: HIGH (6 bugs blocking proper Karina workflow)
---

# Thread 205 — Critical bugs PR-A: LLM suggestion + Preview Tab Reservas + Sidebar pago + counters

## §0. TL;DR

Resuelve **6 de los 7 bugs Tier 0 + Tier 1** identificados en thread/204 (deep dive audit). 

**Bug #1**: LLM suggestion NUNCA aparece en producción (0 invocations en 7 días). Causa: ConversationView pasa `initialSuggestion=null` siempre, LLMSuggestion no auto-trigger fetch.

**Bug #2**: Tab Reservas preview vacío. Causa: aggregate.ts NO lee `bot_messages_inbox` para popular preview/unread/last_msg_at en bookings AirBnB/Booking. Solo lee `conversations.history` (WhatsApp).

**Bug #4**: Sidebar booking muestra "$0 / $5,452 MXN" cuando guest ya pagó depósito. Causa: `paid_amount_mxn = deposit_paid ? total : 0` es lógica equivocada. Correcto: `total - balance_due_mxn`.

**Bug #5.1**: VIP section nunca aparece. Causa: `categorizeLifecycle` retorna `'vip_repeat_check'` pero `sectionMap` key es `'vip_repeat'` (typo).

**Bug #6**: Counter cross-tab = 0 siempre. Causa: aggregate.ts hardcoded `leads: 0` en Tab Reservas (y vice versa).

**Bug #7**: LLM suggestion lookup phone usa normalization viejo (regresión thread/203). Para guests MX, booking NO se carga.

Backend-only worker-bot + 1 archivo frontend (ConversationView.tsx).

**Excluido scope**: Bug #5 rules_accepted (requires migration → thread/206), threading 1-row-per-cliente (defer per thread/204 §10), quick action buttons row-level (thread/207).

## §1. Context

### 1.1 Estado pre-fix

Verificado D1 producción 2026-05-24 ~04:00 UTC:
- `audit_log` con `kind = 'inbox_llm_suggestion'`: **0 rows** en 7 días
- `audit_log` con `kind LIKE 'inbox_%'` últimos 7d: **0 rows**
- `bot_messages_inbox`: 476 mensajes en 66 bookings únicos — todos invisibles en Tab Reservas
- `quick_replies`: 0 rows (Karina nunca creó, no es bug)
- `inbox_drafts`: 12 rows (drafts SÍ funcionan)

### 1.2 Por qué afecta a Karina

| Bug | Síntoma visible Karina |
|---|---|
| #1 LLM suggestion | Promesa de feature core (sugerencia IA editable) NO existe en UI — pierde gain 13-14% throughput per Nielsen Norman research |
| #2 Preview vacío | Tab Reservas no scaneable; cada row look igual — pierde contexto rápido |
| #4 Paid amount | Sidebar muestra info errónea — Karina ve "$0 pagado" cuando guest ya pagó depósito → llamadas innecesarias |
| #5.1 VIP typo | Carlos Castro Garcia (5 bookings históricos) nunca aparece en section VIP — perdemos diferenciación trato |
| #6 Counter | Tab buttons muestran "Leads (0)" o "Reservas (0)" — info engañosa |
| #7 LLM phone | Cuando #1 fix se aplique, guests MX no recibirán suggestion con contexto booking |

### 1.3 Decisión tomada thread/204

WC voto preliminar: aplicar **fix Bug #1 con approach A** (ConversationView pre-fetch suggestion al cargar, pass to ComposeBox). Razones:
- Match spec D11 "pre-cargada editable"
- Match industry pattern (Superhuman, Gmelius drafts proactive)
- Costo previsto: 80 rows × ~$0.001 Haiku = $0.08/load — aceptable
- Cache control ephemeral ya implementado → 90% reduction en cost repetido

## §2. Explicit scope

### 2.1 IN scope (6 fixes)

| Archivo | Cambio | LoC | Bug fix |
|---|---|---|---|
| `apps/worker-bot/src/inbox/aggregate.ts` | (a) Agregar fallback read `bot_messages_inbox` para Tab Reservas cuando NO hay convRow. (b) Fix counter cross-tab — query liviana cross-section. (c) (NO cambio aquí para vip_repeat — está en lifecycle.ts) | +30 modify ~10 | #2 + #6 |
| `apps/worker-bot/src/inbox/lifecycle.ts` | Fix typo `'vip_repeat_check'` → `'vip_repeat'` | modify 1 line | #5.1 |
| `apps/worker-bot/src/inbox/llm-suggestion.ts` | Reemplazar viejo `REPLACE(g.phone_e164, '+', '')` con SQL CASE thread/203 helper | modify ~5 LoC | #7 |
| `apps/worker-bot/src/api/admin/conversation.ts` | Fix `paid_amount_mxn` formula en bookingContext | modify 1 line | #4 |
| `apps/web/src/components/conversation/ConversationView.tsx` | Pre-fetch suggestion en useEffect mount Promise.all. Pass al `<ComposeBox initialSuggestion={...} />` | modify ~10 LoC | #1 |
| `apps/worker-bot/tests/inbox/aggregate.test.ts` | Tests bot_messages_inbox fallback + counter cross-tab | NEW or extend | testing #2 + #6 |
| `apps/worker-bot/tests/inbox/lifecycle.test.ts` | Test vip_repeat sin _check sufijo | extend | testing #5.1 |
| `apps/worker-bot/tests/api/admin/conversation.test.ts` | Test paid_amount con casos AirBnB 33% / direct full / direct unpaid | extend | testing #4 |
| `apps/web/tests/conversation/ConversationView.test.tsx` | Test pre-fetch suggestion + pass to ComposeBox | extend | testing #1 |

Esperado: ~5 files modificados, ~3 test files modificados, ~70-100 LoC neto.

### 2.2 OUT of scope (NO tocar)

- ❌ Bug #5 `rules_accepted` — requires migration 0035 (separar a thread/206)
- ❌ Threading 1 row por cliente (Decision D7) — defer per thread/204 §10 (95% guests = 1 booking)
- ❌ Quick action buttons row-level — thread/207
- ❌ Fechas check-in/check-out display row — thread/207
- ❌ Status badges open/snoozed/resolved — thread/206
- ❌ Internal notes, tags, translation, send-schedule — Wave 2
- ❌ Casa Chamán (679176) — anti-pattern OK ya filtrado
- ❌ Database migrations — NO ALTER TABLE, NO new tables
- ❌ Frontend styling tweaks no relacionados
- ❌ Memoria `MOCK_RESPONSE` removal — defer Wave 1.5
- ❌ Auto-scroll to bottom en ConversationView — thread/207 polish

### 2.3 Justificación scope cuts

| Item cut | Razón |
|---|---|
| Bug #5 rules_accepted | Requires schema change. ALTER TABLE durante multi-CC = anti-pattern (memorias). Separar a thread/206 con migration window. |
| Threading D7 | thread/204 §4.3 analysis: 95% guests = 1 booking activo. Complexity-to-value ratio bajo. Defer. |
| Quick action buttons | thread/202 §6 — 5 decisiones Alex pendientes. No bloqueado por bugs críticos. |
| Auto-scroll | Polish, not critical. thread/207. |
| Status badges | Necesitan visual design tweaks. thread/206 junto con readiness fix. |

## §3. Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | LLM suggestion fix = Approach A (pre-fetch en ConversationView) | Match spec D11 + industry pattern (Superhuman). Cost previsto $0.08/inbox load aceptable. Cache ephemeral ya en place. |
| D2 | Skip cases LLM suggestion (no_wa_history) stay como skip — NO try to suggest OTA-only | Spec §4.4.5 dice "suggest needs WA history". OTA-only suggestions feature nueva (defer Wave 2). |
| D3 | `paid_amount` formula: `total - balance_due_mxn` cuando balance_due not null; fallback `deposit_paid ? total * 0.33 : 0` | AirBnB siempre 33% deposit, direct booking variable. Si balance_due null y deposit_paid=1, asumir 33%. Tests cover 3 casos. |
| D4 | Tab Reservas preview fallback bot_messages_inbox: usa MAX(message_time) AS last_msg_at, message_text AS preview, COUNT WHERE source='guest' AND read_flag=0 AS unread | Mirror del endpoint conversation. Source unified. |
| D5 | Counter cross-tab: 1 extra COUNT(*) query per request | Negligible D1 cost (~1ms). UX consistency > query optimization. |
| D6 | NO refactor query principal a JOIN bot_messages_inbox inline | Per-row sub-query con LIMIT 1 es OK. Refactor a JOIN lateral subquery defer si performance issue (no measurable hoy con 75 rows). |
| D7 | vip_repeat fix: cambiar return string en lifecycle.ts, NO renombrar key sectionMap | Si renombro sectionMap, otros lugares pueden romperse. Mínimo intrusivo cambia source. |
| D8 | llm-suggestion phone normalize: usar SAME SQL CASE pattern que thread/203 (no import helper) | Consistent con aggregate.ts. Helper TS no helps en SQL context. |
| D9 | NO touch llm-suggestion.ts trivial pattern, skip rules — están OK | Tests pasan. Refactor cosmético sería waste. |
| D10 | NO test integration end-to-end Karina-flow | Defer manual smoke. Unit tests suficientes para fix isolation. |

## §4. Implementation

### 4.1 Fix Bug #1 — LLM suggestion pre-fetch (frontend)

`apps/web/src/components/conversation/ConversationView.tsx` — modificar `useEffect` de mount:

```diff
 import {
   fetchConversation,
   postReply,
   postPauseBot,
   postResolve,
   fetchQuickReplies,
   fetchDraft,
+  fetchSuggestion,
+  type SuggestResponse,
+  type SuggestSkipResponse,
 } from '@/lib/inbox-client';
 
 // ...
 
 export default function ConversationView({ convId, onBack, embedded = false }: Props) {
   const [data, setData] = useState<ConversationResponse | null>(null);
   const [quickReplies, setQuickReplies] = useState<QuickReply[]>([]);
   const [draft, setDraft] = useState('');
   const [draftBannerTime, setDraftBannerTime] = useState<string | null>(null);
   const [draftAccepted, setDraftAccepted] = useState(false);
+  const [suggestion, setSuggestion] = useState<SuggestResponse | SuggestSkipResponse | null>(null);
   const [loading, setLoading] = useState(true);
   const [error, setError] = useState<string | null>(null);
   // ...
 
   useEffect(() => {
     let cancelled = false;
     setLoading(true);
 
     Promise.all([
       fetchConversation(convId),
       fetchQuickReplies(),
       fetchDraft(convId),
+      fetchSuggestion(convId).catch(() => null), // Defensive: don't fail load if suggestion fails
     ])
-      .then(([conv, qr, savedDraft]) => {
+      .then(([conv, qr, savedDraft, sugg]) => {
         if (cancelled) return;
         setData(conv);
         setQuickReplies(qr.items);
         if (savedDraft?.text) {
           setDraft(savedDraft.text);
           setDraftBannerTime(savedDraft.updated_at);
         }
+        if (sugg) setSuggestion(sugg);
       })
       .catch((err) => {
         // ... existing
       })
       .finally(() => {
         if (!cancelled) setLoading(false);
       });
 
     return () => { cancelled = true; };
   }, [convId]);
 
   // ... later in render:
 
   {/* Compose */}
   <ComposeBox
     convId={convId}
     channel={channel}
     booking={booking}
     quickReplies={quickReplies}
     initialDraft={activeDraft}
-    initialSuggestion={null}
+    initialSuggestion={suggestion}
     isMobile={isMobile}
     onSend={handleSend}
   />
```

**Importante**: el `.catch(() => null)` en `fetchSuggestion` es defensive — si el endpoint falla (rate limit, timeout, etc), no break el load de la conversation. Suggestion es opcional.

### 4.2 Fix Bug #2 — Aggregate Tab Reservas fallback bot_messages_inbox

`apps/worker-bot/src/inbox/aggregate.ts` — modificar el loop de Tab Reservas. Locación: después del fetch `convRow` (~línea 195-200):

```diff
       const convRow = br.conv_subscriber_id
         ? await env.DB.prepare(`SELECT * FROM conversations WHERE subscriber_id = ?`)
             .bind(br.conv_subscriber_id)
             .first<RawConvRow>()
             .catch(() => null)
         : null;
 
-      const lastMsgText = convRow
+      let lastMsgText = convRow
         ? convRow.history.split('\n').filter((l) => l.startsWith('USER:')).slice(-1)[0]?.slice(5).trim() ?? null
         : null;
+      let lastMsgAtMs: number | null = convRow?.last_active ? convRow.last_active * 1000 : null;
+      let unreadFromOta = 0;
+
+      // thread/205 Bug #2: fallback to bot_messages_inbox for AirBnB/Booking bookings
+      // where conversations row may not exist (95% of active bookings per thread/203 analysis)
+      if (br.beds24_booking_id) {
+        const otaLast = await env.DB.prepare(
+          `SELECT message_text, message_time, source
+           FROM bot_messages_inbox
+           WHERE booking_id = ?
+           ORDER BY message_time DESC LIMIT 1`,
+        )
+          .bind(br.beds24_booking_id)
+          .first<{ message_text: string; message_time: number; source: string }>()
+          .catch(() => null);
+
+        // Use OTA last msg only if it's more recent than WA (or no WA at all)
+        if (otaLast && (!lastMsgAtMs || otaLast.message_time * 1000 > lastMsgAtMs)) {
+          lastMsgText = otaLast.message_text;
+          lastMsgAtMs = otaLast.message_time * 1000;
+        }
+
+        // Count unread OTA messages from guest
+        const unreadResult = await env.DB.prepare(
+          `SELECT COUNT(*) as n FROM bot_messages_inbox
+           WHERE booking_id = ? AND source = 'guest' AND read_flag = 0`,
+        )
+          .bind(br.beds24_booking_id)
+          .first<{ n: number }>()
+          .catch(() => null);
+        unreadFromOta = unreadResult?.n ?? 0;
+      }
 
       const filter = shouldFilterOut({
         subscriber_id: br.conv_subscriber_id ?? String(br.beds24_booking_id),
         last_msg_text: lastMsgText,
         display_name: br.guest_name,
         phone: br.phone_e164,
       });
       if (filter.filter) continue;
```

Luego más abajo, donde se setea `unread_count` y `last_msg_at` en el `rows.push(...)`:

```diff
       // Unread count: count recent messages from guest
-      const unreadCount = convRow
+      const unreadFromWa = convRow
         ? convRow.history.split('\n').filter((l) => l.startsWith('USER:')).length
         : 0;
+      const unreadCount = unreadFromWa + unreadFromOta;
 
-      const lastActive = convRow?.last_active ?? 0;
-      const hoursSince = lastActive > 0 ? (nowMs / 1000 - lastActive) / 3600 : 0;
+      const lastMsgIso = lastMsgAtMs
+        ? new Date(lastMsgAtMs).toISOString()
+        : (convRow?.last_active ? new Date(convRow.last_active * 1000).toISOString() : new Date().toISOString());
+      const hoursSince = lastMsgAtMs ? (nowMs - lastMsgAtMs) / 3_600_000 : 0;
       if (filters.unanswered_h && hoursSince < filters.unanswered_h) continue;
 
       // ... priority + rows.push({
         // ...
         preview: lastMsgText?.slice(0, 100) ?? '',
-        last_msg_at: lastActive > 0 ? new Date(lastActive * 1000).toISOString() : new Date().toISOString(),
+        last_msg_at: lastMsgIso,
         hours_since_last_response: Math.round(hoursSince * 10) / 10,
         unread_count: unreadCount,
         // ...
```

**Nota performance**: esto agrega 2 queries por booking (worst case: 2N extra queries). Con 75 bookings activos, ~150 ms total D1 overhead. Aceptable Wave 1. Optimización Wave 2 vía JOIN lateral subquery o materialized view.

### 4.3 Fix Bug #4 — `paid_amount_mxn` formula

`apps/worker-bot/src/api/admin/conversation.ts` — línea ~218 en `bookingContext`:

```diff
       bookingContext = {
         beds24_booking_id: br.beds24_booking_id,
         property: PROPERTY_NAMES[br.room_id]
           ? { roomId: br.room_id, name: PROPERTY_NAMES[br.room_id] }
           : null,
         check_in: br.arrival,
         check_out: br.departure,
         pax: br.num_adults,
         has_pet: br.num_pets > 0,
         services: [
           br.mascotas_confirmed ? 'mascotas' : null,
           br.morenas_svc_confirmed ? 'cocinera' : null,
         ].filter(Boolean),
         readiness,
         total_amount_mxn: br.total_amount_mxn,
-        paid_amount_mxn: br.deposit_paid ? br.total_amount_mxn : 0,
+        paid_amount_mxn: computePaidAmount(br),
         channel: br.channel,
       };
```

Y agregar helper al inicio del archivo (después de imports):

```ts
/**
 * Compute paid amount based on booking state.
 *
 * Logic (thread/205 Bug #4 fix):
 * - If `balance_due_mxn` is set: paid = total - balance_due (most accurate)
 * - Else if `deposit_paid=1`: assume 33% deposit (AirBnB default) → paid = total * 0.33
 * - Else: paid = 0
 *
 * Examples:
 * - AirBnB Claudia: total=5452, balance_due=3653 → paid=1799 (33%)
 * - Direct full paid: total=18000, balance_due=0 → paid=18000
 * - Direct unpaid: total=18000, balance_due=18000, deposit_paid=0 → paid=0
 * - Old data no balance_due, deposit_paid=1: total=10000 → paid=3300 (33% assumed)
 *
 * Exported for tests.
 */
export function computePaidAmount(br: {
  total_amount_mxn: number;
  deposit_paid: number;
  balance_due_mxn: number | null;
}): number {
  if (br.balance_due_mxn !== null && br.balance_due_mxn !== undefined) {
    return Math.max(0, br.total_amount_mxn - br.balance_due_mxn);
  }
  if (br.deposit_paid === 1) {
    return Math.round(br.total_amount_mxn * 0.33);
  }
  return 0;
}
```

### 4.4 Fix Bug #5.1 — vip_repeat typo

`apps/worker-bot/src/inbox/lifecycle.ts` — buscar `'vip_repeat_check'` (probablemente único hit):

```diff
   if (days < 0) {
-    return Math.abs(days) <= 7 ? 'post_stay' : 'vip_repeat_check';
+    return Math.abs(days) <= 7 ? 'post_stay' : 'vip_repeat';
   }
```

(Verificar exacto path en code real — el comment del bug indica esa línea aprox pero puede variar.)

### 4.5 Fix Bug #6 — Counter cross-tab

`apps/worker-bot/src/inbox/aggregate.ts` — modificar `counters` en Tab Reservas branch:

```diff
+    // thread/205 Bug #6: include leads count for accurate cross-tab counter
+    const leadsCountResult = await env.DB.prepare(`
+      SELECT COUNT(*) as n
+      FROM conversations c
+      LEFT JOIN guests g ON g.manychat_subscriber_id = c.subscriber_id
+        OR (
+          CASE
+            WHEN g.phone_e164 LIKE '+52%' AND substr(g.phone_e164, 4, 1) != '1'
+            THEN '521' || substr(g.phone_e164, 4)
+            ELSE REPLACE(g.phone_e164, '+', '')
+          END
+        ) = c.subscriber_id
+      LEFT JOIN beds24_bookings bb ON bb.guest_id = g.id AND bb.room_id != 679176
+      WHERE bb.id IS NULL
+        AND c.subscriber_id != 'cron-bot-alerts'
+        AND (c.resolved_at IS NULL OR c.resolved_at < unixepoch() - 7 * 86400)
+    `).first<{ n: number }>().catch(() => null);
+
     const counters = {
       reservas: rows.length,
-      leads: 0, // filled if needed
+      leads: leadsCountResult?.n ?? 0,
     };
```

Y mirror en Tab Leads branch (al final del archivo):

```diff
+    // thread/205 Bug #6: include reservas count
+    const reservasCountResult = await env.DB.prepare(`
+      SELECT COUNT(*) as n
+      FROM beds24_bookings bb
+      WHERE bb.room_id != 679176
+        AND bb.status NOT IN ('cancelled', 'no_show')
+        AND bb.departure >= date('now', '-7 days')
+    `).first<{ n: number }>().catch(() => null);
+
     return {
       ok: true,
       tab,
-      counters: { reservas: 0, leads: leadRows.length },
+      counters: { reservas: reservasCountResult?.n ?? 0, leads: leadRows.length },
       quick_stats,
       sections,
     };
```

### 4.6 Fix Bug #7 — llm-suggestion phone normalization

`apps/worker-bot/src/inbox/llm-suggestion.ts` — modificar la query del booking lookup (líneas ~110-119):

```diff
   const booking = await env.DB.prepare(
     `SELECT bb.beds24_booking_id, bb.room_id, bb.arrival, bb.departure,
             bb.num_adults, bb.num_pets, bb.total_amount_mxn, bb.deposit_paid,
             bb.balance_due_mxn, bb.channel,
             bc.mascotas_confirmed, bc.mascotas_count, bc.menu_status,
             bc.compras_confirmed, bc.morenas_svc_confirmed
      FROM beds24_bookings bb
      LEFT JOIN booking_captures bc ON bc.beds24_booking_id = bb.beds24_booking_id
      JOIN guests g ON g.id = bb.guest_id
-     WHERE (g.manychat_subscriber_id = ? OR REPLACE(g.phone_e164, '+', '') = ?)
+     /* thread/205 Bug #7: use thread/203 MX cellular normalization to match
+        conversations.subscriber_id format (5215XXXXXXXXXX) against guests.phone_e164
+        (+525XXXXXXXXXX). Mirror of normalizePhoneToWA() helper. */
+     WHERE (g.manychat_subscriber_id = ?
+           OR (
+             CASE
+               WHEN g.phone_e164 LIKE '+52%' AND substr(g.phone_e164, 4, 1) != '1'
+               THEN '521' || substr(g.phone_e164, 4)
+               ELSE REPLACE(g.phone_e164, '+', '')
+             END
+           ) = ?)
        AND bb.room_id != 679176
      ORDER BY bb.arrival DESC LIMIT 1`,
   )
     .bind(convId, convId)
```

## §5. Tests

### 5.1 Test Bug #2 — aggregate bot_messages_inbox fallback

En `apps/worker-bot/tests/inbox/aggregate.test.ts` agregar:

```ts
describe('aggregateInbox — Bug #2: bot_messages_inbox fallback (thread/205)', () => {
  it('populates preview from bot_messages_inbox when no WA conversation', async () => {
    // Setup: AirBnB booking with messages in bot_messages_inbox, no conversations row
    const env = mockEnv({
      bookings: [{
        beds24_booking_id: 86656062,
        room_id: 637063,
        arrival: '2026-05-21',
        departure: '2026-05-23',
        guest_id: 'g_test',
        channel: 'airbnb',
        status: 'confirmed',
      }],
      guests: [{ id: 'g_test', name: 'Claudia Becerra', phone_e164: '+525516264567' }],
      conversations: [], // No WA conv
      botMessagesInbox: [
        {
          message_id: 1, booking_id: 86656062, source: 'guest',
          message_text: 'Espero su respuesta gracias 😊',
          message_time: Date.now() / 1000 - 3600, read_flag: 0,
        },
      ],
    });

    const result = await aggregateInbox(env, 'reservas', {});
    const row = result.sections.flatMap(s => s.rows).find(r => r.id === 'b_86656062');

    expect(row?.preview).toContain('Espero su respuesta');
    expect(row?.unread_count).toBe(1);
    expect(row?.last_msg_at).toBeTruthy();
    expect(row?.hours_since_last_response).toBeCloseTo(1, 0);
  });

  it('prefers more recent message between WA and OTA', async () => {
    // Setup: booking with both WA conv (last 2h ago) and OTA msg (last 30min ago)
    // Expected: preview = OTA msg
    // ... (similar setup)
  });

  it('falls back to OTA when no WA conv exists at all', async () => {
    // Already covered in test 1; emphasis test
  });

  it('returns empty preview when no messages anywhere', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 999, room_id: 78695, arrival: '2026-06-01', departure: '2026-06-03', guest_id: 'g_empty' }],
      guests: [{ id: 'g_empty', name: 'Empty', phone_e164: '+525511111111' }],
      conversations: [],
      botMessagesInbox: [],
    });

    const result = await aggregateInbox(env, 'reservas', {});
    const row = result.sections.flatMap(s => s.rows).find(r => r.id === 'b_999');

    expect(row?.preview).toBe('');
    expect(row?.unread_count).toBe(0);
  });
});
```

### 5.2 Test Bug #4 — computePaidAmount

En `apps/worker-bot/tests/api/admin/conversation.test.ts` agregar describe block:

```ts
import { computePaidAmount } from '@/api/admin/conversation';

describe('computePaidAmount (thread/205 Bug #4)', () => {
  it('uses total - balance_due when balance_due is set', () => {
    expect(computePaidAmount({ total_amount_mxn: 5452, deposit_paid: 1, balance_due_mxn: 3653 })).toBe(1799);
  });

  it('returns 0 when balance_due equals total (unpaid)', () => {
    expect(computePaidAmount({ total_amount_mxn: 18000, deposit_paid: 0, balance_due_mxn: 18000 })).toBe(0);
  });

  it('returns total when balance_due is 0 (fully paid)', () => {
    expect(computePaidAmount({ total_amount_mxn: 18000, deposit_paid: 1, balance_due_mxn: 0 })).toBe(18000);
  });

  it('falls back to 33% when balance_due null and deposit_paid=1', () => {
    expect(computePaidAmount({ total_amount_mxn: 10000, deposit_paid: 1, balance_due_mxn: null })).toBe(3300);
  });

  it('returns 0 when nothing paid and balance_due null', () => {
    expect(computePaidAmount({ total_amount_mxn: 10000, deposit_paid: 0, balance_due_mxn: null })).toBe(0);
  });

  it('clamps at 0 (no negative paid)', () => {
    expect(computePaidAmount({ total_amount_mxn: 100, deposit_paid: 1, balance_due_mxn: 150 })).toBe(0);
  });
});
```

### 5.3 Test Bug #5.1 — vip_repeat

En `apps/worker-bot/tests/inbox/lifecycle.test.ts`:

```ts
describe('categorizeLifecycle — VIP repeat (thread/205 Bug #5.1)', () => {
  it('returns vip_repeat (NOT vip_repeat_check) for past stays with multiple bookings', () => {
    const past = new Date(Date.now() - 30 * 86_400_000).toISOString().slice(0, 10); // 30 days ago
    const stage = categorizeLifecycle(
      { arrival: past, departure: past, status: 'confirmed', room_id: 78695, channel: 'direct' },
      null, null,
      5, // total_bookings
      Date.now(),
    );
    expect(stage).toBe('vip_repeat');
    expect(stage).not.toBe('vip_repeat_check');
  });
});
```

### 5.4 Test Bug #6 — counter cross-tab

En `aggregate.test.ts`:

```ts
describe('aggregateInbox — counters cross-tab (thread/205 Bug #6)', () => {
  it('returns leads count when tab=reservas', async () => {
    const env = mockEnv({
      bookings: [/* 5 bookings */],
      conversations: [/* 3 leads without booking */],
    });
    const result = await aggregateInbox(env, 'reservas', {});
    expect(result.counters.reservas).toBeGreaterThan(0);
    expect(result.counters.leads).toBe(3); // ← was 0 before fix
  });

  it('returns reservas count when tab=leads', async () => {
    const env = mockEnv({
      bookings: [/* 5 bookings */],
      conversations: [/* 3 leads */],
    });
    const result = await aggregateInbox(env, 'leads', {});
    expect(result.counters.leads).toBeGreaterThan(0);
    expect(result.counters.reservas).toBe(5); // ← was 0 before fix
  });
});
```

### 5.5 Test Bug #7 — llm-suggestion phone normalization

En `apps/worker-bot/tests/inbox/llm-suggestion.test.ts` (probable que no exista — crear si needed):

```ts
import { suggestReply } from '@/inbox/llm-suggestion';

describe('suggestReply — booking lookup with MX phone normalization (thread/205 Bug #7)', () => {
  it('finds booking via MX cellular indicator normalization', async () => {
    // Setup: conversation subscriber_id 5215582528741 (con 1)
    //        guest phone_e164 +525582528741 (sin 1)
    //        booking linked to that guest
    const env = mockEnvWithAnthropic({
      conversations: [{ subscriber_id: '5215582528741', history: 'USER: ¿pueden mascotas?', last_active: Math.floor(Date.now() / 1000) - 60 }],
      guests: [{ id: 'g_mx', phone_e164: '+525582528741' }],
      bookings: [{ beds24_booking_id: 79421553, guest_id: 'g_mx', room_id: 78695, arrival: '2026-05-25', departure: '2026-05-28', /*...*/ }],
    });

    const result = await suggestReply('5215582528741', Math.floor(Date.now() / 1000) - 60, env);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.inputs_used.booking_loaded).toBe(true); // ← was false before fix
    }
  });
});
```

### 5.6 Test Bug #1 — ConversationView pre-fetch suggestion

En `apps/web/tests/conversation/ConversationView.test.tsx`:

```tsx
describe('ConversationView — pre-fetch LLM suggestion (thread/205 Bug #1)', () => {
  it('calls fetchSuggestion on mount and passes to ComposeBox', async () => {
    const mockSuggestion = { ok: true, suggestion: 'Sugerencia de prueba', /* ... */ };
    vi.mocked(fetchSuggestion).mockResolvedValue(mockSuggestion);

    render(<ConversationView convId="b_123" />);

    await waitFor(() => {
      expect(fetchSuggestion).toHaveBeenCalledWith('b_123');
    });

    // Verify the suggestion appears in the UI (LLMSuggestion box rendered)
    expect(screen.getByText(/Sugerencia de prueba/i)).toBeInTheDocument();
  });

  it('does not break load when fetchSuggestion fails', async () => {
    vi.mocked(fetchSuggestion).mockRejectedValue(new Error('rate_limit'));

    render(<ConversationView convId="b_123" />);

    // Conversation should still load
    await waitFor(() => {
      expect(screen.queryByText(/Cargando/i)).not.toBeInTheDocument();
    });
  });

  it('handles skip reason gracefully (no_wa_history)', async () => {
    vi.mocked(fetchSuggestion).mockResolvedValue({ ok: false, skip_reason: 'no_wa_history' });

    render(<ConversationView convId="b_123" />);

    await waitFor(() => {
      // LLMSuggestion renders skip reason label
      expect(screen.queryByText(/Sugerencia IA/i)).toBeInTheDocument();
    });
  });
});
```

## §6. Definition of Done

- [ ] Branch `fix/inbox-pr-a-llm-preview-sidebar` creada
- [ ] 6 archivos modificados:
  - `apps/worker-bot/src/inbox/aggregate.ts` (Bug #2 + #6 + helper)
  - `apps/worker-bot/src/inbox/lifecycle.ts` (Bug #5.1)
  - `apps/worker-bot/src/inbox/llm-suggestion.ts` (Bug #7)
  - `apps/worker-bot/src/api/admin/conversation.ts` (Bug #4 + computePaidAmount export)
  - `apps/web/src/components/conversation/ConversationView.tsx` (Bug #1)
  - (+ 3-4 test files extended)
- [ ] `pnpm --filter worker-bot typecheck` PASS 0 errores nuevos
- [ ] `pnpm --filter web typecheck` PASS 0 errores nuevos
- [ ] `pnpm --filter worker-bot test` todos verdes
- [ ] `pnpm --filter web test` todos verdes
- [ ] `git diff main --stat` muestra ~7-9 archivos, ~150-200 LoC
- [ ] PR creada título: `fix(inbox): critical bugs PR-A — LLM suggestion + preview + sidebar paid + counters + vip_repeat (thread/205)`
- [ ] PR description menciona los 6 bugs + impacto medido + ⚠️ MANUAL `npx wrangler deploy` + frontend auto-deploy CF Pages
- [ ] Reporte CC al final con:
  - Resumen bugs fixed
  - Files modificados count
  - LoC neto
  - Tests pass count
  - PR URL
  - Recomendación: merge → wrangler deploy → smoke test (script §10)

## §7. Risks + Mitigations

| Risk | Mitigation |
|---|---|
| OTA fallback query 2N queries lentas (75 bookings × 2 = 150 queries D1) | Verified ~1ms per query. Total ~150ms overhead aceptable. Optimización JOIN lateral defer Wave 2 |
| `computePaidAmount` 33% assumption inválida para direct booking variable | D3 cubre 3 casos test. Edge cases mostrarán mismatch en sidebar pero NO crash. Tracking via Telegram alert si discovered |
| LLM suggestion fetchSuggestion en cada mount = cost spike | Cache ephemeral 90% reduction. ~80 conversations/load × $0.001 worst case = $0.08. Si Karina abre 10 inboxes/día = $0.80 LLM/día. Aceptable. |
| `fetchSuggestion.catch(() => null)` hide errors | Defensive OK — suggestion es opcional, no debe break load. Errors loggeados server-side audit_log |
| Counter cross-tab query nunca devuelve mismo número que se carga next tab (race condition) | Resultado aproximado OK — counter es UI hint, no source of truth. Refresh tab vuelve a query |
| Bug #5.1 vip_repeat ya estaba estable como bug — fix podría romper otros lugares | Search global `'vip_repeat_check'` antes commit. Confirmar único hit |
| LLM phone normalization regression (Bug #7) podría dar wrong booking para algún caso edge | Mirror exacto de thread/203 verified pattern. Tests cubren MX_no_1, MX_with_1, non-MX |
| Tests E2E manual smoke después de deploy son críticos | §10 smoke test script estricto |
| Frontend auto-deploy CF Pages podría romper antes que worker-bot deployed | Order: merge → worker-bot deploy first → CF Pages deploys auto. Si CF antes que worker, suggestion fetch fails silently (defensive catch). NO regression visible |

## §8. Out-of-scope findings → issues

Si CC encuentra algo NO listado §2.1:
- Abrir GitHub issue con prefix `[thread/205 OOS]`
- NO fix inline
- Reportar en thread response

Casos probables previstos:
- Other places phone normalization custom (cron-bot-alerts.ts, etc) → issue
- TypeScript errors pre-existing other files → IGNORE
- Tests pre-existing failing → DON'T fix unless directly broken by changes
- Migration 0035 booking_captures.rules_accepted → thread/206 (NOT here)
- Status badges → thread/206
- Quick action buttons → thread/207
- Auto-scroll bottom → thread/207

## §9. Kickoff command (Alex paste to CC)

```
DoIt thread/205: critical bugs PR-A — LLM suggestion + preview Tab Reservas + sidebar paid + counters + vip_repeat fix.

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/205-wc-inbox-critical-bugs-llm-preview-sidebar.md

Si no la tienes local, pull:
cd c:/dev/rdm/dev/discussion && git pull origin main

Sigue §4 implementation exacto. Self-review §6 DoD antes de commit.

Working directory: c:/dev/rdm/dev/bot

Pre-flight:
1. cd c:/dev/rdm/dev/bot
2. git checkout main
3. git status — debe estar clean
4. git pull origin main
5. git log --oneline -1 — confirma estás en último commit (incluye thread/203 merge "fix(inbox): normalize phone MX cellular indicator")

Execution:
1. git checkout -b fix/inbox-pr-a-llm-preview-sidebar
2. Editar apps/worker-bot/src/inbox/aggregate.ts según §4.2 + §4.5:
   - Tab Reservas: fallback bot_messages_inbox para preview/unread/last_msg_at
   - Tab Reservas counter: query leads count
   - Tab Leads counter: query reservas count
3. Editar apps/worker-bot/src/inbox/lifecycle.ts según §4.4:
   - Cambiar 'vip_repeat_check' → 'vip_repeat' (verify único hit con grep)
4. Editar apps/worker-bot/src/inbox/llm-suggestion.ts según §4.6:
   - Reemplazar viejo REPLACE phone con SQL CASE thread/203 pattern
5. Editar apps/worker-bot/src/api/admin/conversation.ts según §4.3:
   - Agregar export function computePaidAmount al inicio del archivo
   - Reemplazar paid_amount_mxn en bookingContext usar el helper
6. Editar apps/web/src/components/conversation/ConversationView.tsx según §4.1:
   - Importar fetchSuggestion + types
   - Promise.all en useEffect agregar fetchSuggestion(convId).catch(() => null)
   - Setear estado suggestion
   - Pass al ComposeBox como initialSuggestion={suggestion}
7. Tests:
   - apps/worker-bot/tests/inbox/aggregate.test.ts: extender §5.1 + §5.4
   - apps/worker-bot/tests/api/admin/conversation.test.ts: extender §5.2 computePaidAmount tests
   - apps/worker-bot/tests/inbox/lifecycle.test.ts: extender §5.3
   - apps/worker-bot/tests/inbox/llm-suggestion.test.ts: crear si no existe, agregar §5.5
   - apps/web/tests/conversation/ConversationView.test.tsx: extender §5.6
8. pnpm --filter worker-bot typecheck — PASS 0 nuevos errors
9. pnpm --filter web typecheck — PASS 0 nuevos errors  
10. pnpm --filter worker-bot test — todos verdes
11. pnpm --filter web test — todos verdes
12. git diff main --stat — verifica ~7-9 archivos
13. git add (solo los archivos específicos § DoD)
14. git commit -m "fix(inbox): critical bugs PR-A — LLM suggestion + preview + sidebar paid + counters + vip_repeat (thread/205)"
15. git push -u origin fix/inbox-pr-a-llm-preview-sidebar
16. gh pr create title "fix(inbox): critical bugs PR-A — LLM suggestion + preview + sidebar paid + counters + vip_repeat (thread/205)" body con:
    - Referencia thread/205 + thread/204 audit
    - 6 bugs fixed con before/after
    - Impacto: Karina ve LLM suggestion + preview Tab Reservas + sidebar pago correcto + counter cross-tab + VIP section + LLM con contexto booking para MX
    - ⚠️ MANUAL `npx wrangler deploy` post-merge para worker-bot
    - Frontend auto-deploys CF Pages on merge to main

Scope ESTRICTO: ver §2.1 (6 fixes). NO tocar:
- Bug #5 rules_accepted (defer thread/206 con migration)
- Threading 1-row-per-cliente (defer per thread/204 §10)
- Status badges (thread/206)
- Quick action buttons (thread/207)
- Auto-scroll bottom (thread/207)
- Migrations
- Frontend styling no relacionado

Si encuentras algo fuera de scope → issue GitHub con prefix [thread/205 OOS].

Bloqueado >30 min en sub-tarea = STOP y reporta.

Reportar al final con:
- 6 bugs fixed (lista enumerada)
- Files modificados count
- LoC neto
- Tests pass count totales
- PR URL
- ⚠️ CRÍTICO: worker-bot deploy manual + smoke test sugerido (§10 spec)

GO.
```

## §10. Post-merge smoke test (Alex executes)

Después de merge + `cd apps/worker-bot && npx wrangler deploy`:

### Test 1 — LLM suggestion aparece en Claudia (Bug #1)

1. Browser https://rincondelmar.club/admin/inbox
2. Ctrl+F5
3. Click row **Claudia Becerra** (Huerta Cocotera, in-stay OK)
4. Modal abre

**Esperado**:
- Box "✨ Sugerencia IA (Haiku 4.5)" aparece encima del textarea
- Loading state primero ~1-3s
- Después: texto sugerido editable
- Botones "Usar", "Regenerar", "Skip"

**NO debe pasar**: que NO aparezca el box LLM suggestion (era el bug)

### Test 2 — Preview Tab Reservas (Bug #2)

1. Tab Reservas (default)
2. Scroll a sección in-stay-OK o pre-stay

**Esperado**:
- Múltiples rows ahora muestran preview real del último mensaje
- Antes vacío, ahora visible "Espero su respuesta gracias", "ya nos coloco una serie...", etc
- Unread count >0 en rows con mensajes guest no read

### Test 3 — Sidebar paid correcto (Bug #4)

1. Click cualquier row Tab Reservas con booking AirBnB
2. Verificar sidebar booking

**Esperado**:
- Pago muestra valores razonables: "$1,799 / $5,452 MXN" (33% deposit AirBnB)
- NO "$0 / $5,452 MXN"

### Test 4 — Counter cross-tab (Bug #6)

1. Tab Reservas → contador top muestra "Reservas (N)" + "Leads (M)" con M > 0
2. Click tab Leads → contador "Reservas (N)" + "Leads (M)" — ambos números iguales o similares

**Esperado**: ambos contadores siempre populated, no 0

### Test 5 — VIP section aparece (Bug #5.1)

Si hay guests con bookings históricos (>= 3-4 stays past):

1. Scroll down Tab Reservas
2. Buscar sección "💎 VIP / repeat"

**Esperado**: section aparece cuando hay matches (vs nunca aparecer antes)

### Test 6 — Alan Granados WA messages todavía visible (regression check Bug #7)

1. Click Alan Granados (thread/203 verification case)

**Esperado**:
- Mensajes WA visibles (regression check thread/203)
- AHORA además: LLM suggestion aparece en compose box con contexto booking de Alan (era el regression Bug #7)

## §11. References

- thread/196: Spec original inbox redesign
- thread/198: CORS hotfix (PR #169)
- thread/199: Frontend display bugs (PR #170)
- thread/200: Conversation endpoint polimórfico (PR #171)
- thread/202: Gap analysis WC notes
- thread/203: Phone MX cellular normalization (PR #172)
- thread/204: Deep dive audit (44KB spec vs reality)
- D1 evidence: 0 inbox_llm_suggestion audit logs in 7d, 66 OTA bookings invisible Tab Reservas
- Industry research: Hostaway, Hostfully, Front, Superhuman, Gmelius patterns
- Memorias: #25 (Wave 1.5 followups identificados), #26 (worker-bot deploy gotcha)

---

**Esfuerzo previsto**: 90-150min CC. Sigue spec §4 estrictamente, tests cover scope, deploy manual + smoke § 10.
