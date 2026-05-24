---
thread: 205
author: wc
topic: inbox-critical-bugs-llm-preview-sidebar-fixes
status: ready-for-execution
mode: DoIt
created: 2026-05-24
updated: 2026-05-24 (Alex votos confirmados: 1 CC serial mega-run; Bug #4 simplified `total - balance_due`; Bug #1 approach A)
related_threads: [196, 199, 200, 202, 203, 204, 206, 207]
related_prs: [167, 170, 171, 172]
estimated_effort: 90-150min CC (1 session, mostly backend with 1 frontend change)
pipeline: single-CC serial (PR-A → deploy → smoke → next PR-B thread/206)
requires_worker_bot_deploy: YES (manual `npx wrangler deploy` after merge)
requires_web_redeploy: YES (auto via CF Pages when merged to main)
severity: HIGH (6 bugs blocking proper Karina workflow)
---

# Thread 205 — Critical bugs PR-A: LLM suggestion + Preview Tab Reservas + Sidebar pago + counters

> **PR-A of 3 (mega-run)**. Después merge+deploy+smoke → thread/206 PR-B (readiness + status badges) → thread/207 PR-C (action buttons + dates + counts + drawer width).

## §0. TL;DR

Resuelve **6 bugs Tier 0 + Tier 1** identificados en thread/204 (deep dive audit).

| Bug | Fix |
|---|---|
| #1 LLM suggestion NUNCA aparece | ConversationView pre-fetch via Promise.all (approach A confirmado Alex) |
| #2 Tab Reservas preview vacío | aggregate.ts fallback `bot_messages_inbox` cuando NO hay convRow |
| #4 paid_amount erróneo | Formula simplificada: `total - balance_due_mxn` (Alex: balance_due ya incluye extras) |
| #5.1 vip_repeat typo | lifecycle.ts return `'vip_repeat'` (no `_check`) |
| #6 Counter cross-tab = 0 | Query liviana cross-section en aggregate.ts |
| #7 LLM phone normalize obsoleto | Mirror SQL CASE thread/203 en llm-suggestion.ts |

Backend-only worker-bot + 1 archivo frontend (ConversationView.tsx). ~5 archivos modificados, ~150 LoC.

## §1. Context

### 1.1 Estado pre-fix (verificado D1 prod 2026-05-24 ~04:00 UTC)

- `audit_log` con `kind = 'inbox_llm_suggestion'`: **0 rows** en 7 días
- `bot_messages_inbox`: 476 mensajes en 66 bookings únicos — todos invisibles en Tab Reservas
- `quick_replies`: 0 rows (Karina nunca creó, no es bug)
- `inbox_drafts`: 12 rows (drafts SÍ funcionan)

### 1.2 Por qué afecta a Karina (ver thread/204 §0 para tabla impacto detallada)

LLM suggestion (feature core anunciada) NO existe en UI. Preview Tab Reservas vacío. Sidebar paid info errónea ($0/$5,452 Claudia). VIP nunca aparece. Counter engañoso.

## §2. Explicit scope

### 2.1 IN scope (6 fixes)

| Archivo | Cambio | Bug fix |
|---|---|---|
| `apps/worker-bot/src/inbox/aggregate.ts` | (a) fallback `bot_messages_inbox` para Tab Reservas preview/unread/last_msg_at. (b) Counter cross-tab queries | #2 + #6 |
| `apps/worker-bot/src/inbox/lifecycle.ts` | Fix typo `'vip_repeat_check'` → `'vip_repeat'` | #5.1 |
| `apps/worker-bot/src/inbox/llm-suggestion.ts` | Mirror SQL CASE thread/203 para phone normalize | #7 |
| `apps/worker-bot/src/api/admin/conversation.ts` | Fix `paid_amount_mxn` simple: `total - balance_due` | #4 |
| `apps/web/src/components/conversation/ConversationView.tsx` | Pre-fetch suggestion en Promise.all mount | #1 |
| Tests: `aggregate.test.ts`, `lifecycle.test.ts`, `conversation.test.ts`, `llm-suggestion.test.ts`, `ConversationView.test.tsx` | Extender | testing |

Esperado: ~5-8 archivos modificados, ~150 LoC neto.

### 2.2 OUT of scope (NO tocar)

- ❌ Bug #5 `rules_accepted` → thread/206 (requires migration 0035)
- ❌ Threading 1-row-per-cliente → defer per thread/204 §10
- ❌ Status badges visual → thread/206
- ❌ Quick action buttons row-level → thread/207
- ❌ Fechas check-in/checkout display row → thread/207
- ❌ Auto-scroll bottom ConversationView → thread/207
- ❌ Drawer width CSS fix → thread/207
- ❌ Database migrations
- ❌ Frontend styling no relacionado
- ❌ Casa Chamán touches

## §3. Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | LLM suggestion fix = Approach A (pre-fetch en ConversationView) | Alex confirmado. Match spec D11 + Superhuman pattern. Cost ~$0.08/inbox load aceptable. Cache ephemeral activo |
| D2 | Skip cases LLM suggestion (no_wa_history) stay como skip | Spec §4.4.5. OTA-only suggestions defer Wave 2 |
| D3 | **`paid_amount` formula simplificada (Alex confirmó)**: `total - balance_due_mxn`. Si `balance_due_mxn` null → 0 | Alex: "balance_due ya incluye extras agregados durante stay (perros, comestibles, etc) — es source of truth desde Beds24" |
| D4 | Tab Reservas preview fallback bot_messages_inbox: pick MAX(message_time) entre WA y OTA, message_text AS preview, COUNT WHERE source='guest' AND read_flag=0 AS unread | Mirror del endpoint conversation. Source unified |
| D5 | Counter cross-tab: 1 extra COUNT(*) query per request | Negligible D1 cost (~1ms). UX consistency > optimization |
| D6 | NO refactor query principal a JOIN bot_messages_inbox inline | Per-row sub-query con LIMIT 1 es OK Wave 1. Refactor a JOIN lateral defer si performance issue |
| D7 | vip_repeat fix: cambiar return string en lifecycle.ts, NO renombrar key sectionMap | Mínimo intrusivo |
| D8 | llm-suggestion phone normalize: SAME SQL CASE pattern thread/203 | Consistent con aggregate.ts |

## §4. Implementation

### 4.1 Fix Bug #1 — LLM suggestion pre-fetch (frontend)

`apps/web/src/components/conversation/ConversationView.tsx`:

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
       // ...
   }, [convId]);

   // ... later in render:

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

### 4.2 Fix Bug #2 — Aggregate Tab Reservas fallback bot_messages_inbox

`apps/worker-bot/src/inbox/aggregate.ts` — modificar el loop de Tab Reservas. Locación: después del fetch `convRow`:

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
+      // thread/205 Bug #2: fallback bot_messages_inbox for AirBnB/Booking bookings
+      // 95% of active bookings have no conversations row (per thread/203 analysis)
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
+        // Use OTA only if more recent than WA (or no WA at all)
+        if (otaLast && (!lastMsgAtMs || otaLast.message_time * 1000 > lastMsgAtMs)) {
+          lastMsgText = otaLast.message_text;
+          lastMsgAtMs = otaLast.message_time * 1000;
+        }
+
+        const unreadResult = await env.DB.prepare(
+          `SELECT COUNT(*) as n FROM bot_messages_inbox
+           WHERE booking_id = ? AND source = 'guest' AND read_flag = 0`,
+        )
+          .bind(br.beds24_booking_id)
+          .first<{ n: number }>()
+          .catch(() => null);
+        unreadFromOta = unreadResult?.n ?? 0;
+      }

       const filter = shouldFilterOut({ ... });
```

Y donde se setea unread_count y last_msg_at:

```diff
-      const unreadCount = convRow
+      const unreadFromWa = convRow
         ? convRow.history.split('\n').filter((l) => l.startsWith('USER:')).length
         : 0;
+      const unreadCount = unreadFromWa + unreadFromOta;

-      const lastActive = convRow?.last_active ?? 0;
-      const hoursSince = lastActive > 0 ? (nowMs / 1000 - lastActive) / 3600 : 0;
+      const lastMsgIso = lastMsgAtMs
+        ? new Date(lastMsgAtMs).toISOString()
+        : new Date().toISOString();
+      const hoursSince = lastMsgAtMs ? (nowMs - lastMsgAtMs) / 3_600_000 : 0;

       // ... rows.push({
         preview: lastMsgText?.slice(0, 100) ?? '',
-        last_msg_at: lastActive > 0 ? new Date(lastActive * 1000).toISOString() : new Date().toISOString(),
+        last_msg_at: lastMsgIso,
         hours_since_last_response: Math.round(hoursSince * 10) / 10,
         unread_count: unreadCount,
```

### 4.3 Fix Bug #4 — `paid_amount_mxn` simplificado

`apps/worker-bot/src/api/admin/conversation.ts` — línea ~218:

```diff
       bookingContext = {
         // ...
         total_amount_mxn: br.total_amount_mxn,
-        paid_amount_mxn: br.deposit_paid ? br.total_amount_mxn : 0,
+        // thread/205 Bug #4 (Alex confirmó): balance_due_mxn es source of truth
+        // desde Beds24 — incluye extras agregados durante stay (perros, comestibles, etc).
+        // Si balance_due null → asumimos 0 paid (defensive). NO usar deposit_paid ya que
+        // es boolean (no monto) y no refleja extras.
+        paid_amount_mxn: br.balance_due_mxn !== null
+          ? Math.max(0, br.total_amount_mxn - br.balance_due_mxn)
+          : 0,
         channel: br.channel,
       };
```

No requiere export helper separado. Inline simple. Tests cubren 3 casos en §5.2.

### 4.4 Fix Bug #5.1 — vip_repeat typo

`apps/worker-bot/src/inbox/lifecycle.ts` — buscar `'vip_repeat_check'` (probablemente único hit):

```diff
   if (days < 0) {
-    return Math.abs(days) <= 7 ? 'post_stay' : 'vip_repeat_check';
+    return Math.abs(days) <= 7 ? 'post_stay' : 'vip_repeat';
   }
```

CC verificar con grep que es único hit antes commit.

### 4.5 Fix Bug #6 — Counter cross-tab

`apps/worker-bot/src/inbox/aggregate.ts` — modificar `counters` en Tab Reservas branch:

```diff
+    // thread/205 Bug #6: leads count cross-tab
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

Mirror en Tab Leads:

```diff
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

`apps/worker-bot/src/inbox/llm-suggestion.ts`:

```diff
   const booking = await env.DB.prepare(
     `SELECT ... FROM beds24_bookings bb
      LEFT JOIN booking_captures bc ON bc.beds24_booking_id = bb.beds24_booking_id
      JOIN guests g ON g.id = bb.guest_id
-     WHERE (g.manychat_subscriber_id = ? OR REPLACE(g.phone_e164, '+', '') = ?)
+     /* thread/205 Bug #7: mirror normalizePhoneToWA() helper. Conversations.subscriber_id
+        is 5215XXXXXXXXXX format (con 1), guests.phone_e164 is +525XXXXXXXXXX (sin 1) */
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

### 5.1 Test Bug #2 — aggregate fallback bot_messages_inbox

`apps/worker-bot/tests/inbox/aggregate.test.ts`:

```ts
describe('aggregateInbox — bot_messages_inbox fallback (thread/205 Bug #2)', () => {
  it('populates preview from OTA when no WA conversation', async () => {
    const env = mockEnv({
      bookings: [{
        beds24_booking_id: 86656062, room_id: 637063,
        arrival: '2026-05-21', departure: '2026-05-23',
        guest_id: 'g_test', channel: 'airbnb', status: 'confirmed',
      }],
      guests: [{ id: 'g_test', name: 'Claudia', phone_e164: '+525516264567' }],
      conversations: [],
      botMessagesInbox: [
        { message_id: 1, booking_id: 86656062, source: 'guest',
          message_text: 'Espero su respuesta gracias 😊',
          message_time: Date.now() / 1000 - 3600, read_flag: 0 },
      ],
    });
    const result = await aggregateInbox(env, 'reservas', {});
    const row = result.sections.flatMap(s => s.rows).find(r => r.id === 'b_86656062');
    expect(row?.preview).toContain('Espero su respuesta');
    expect(row?.unread_count).toBe(1);
  });

  it('prefers more recent message between WA and OTA', async () => {
    // ... test
  });

  it('returns empty preview when no messages anywhere', async () => {
    // ... test
  });
});
```

### 5.2 Test Bug #4 — `paid_amount_mxn` inline

`apps/worker-bot/tests/api/admin/conversation.test.ts`:

```ts
describe('handleConversationGet — paid_amount calc (thread/205 Bug #4)', () => {
  it('AirBnB Claudia: total=5452, balance_due=3653 → paid=1799 (33%)', async () => {
    const ctx = mockContext({
      booking: { total_amount_mxn: 5452, balance_due_mxn: 3653, deposit_paid: 1, ... },
    });
    const res = await handleConversationGet(ctx);
    expect(res.booking.paid_amount_mxn).toBe(1799);
  });

  it('Direct full paid: balance_due=0 → paid=total', async () => {
    // total=18000, balance=0 → paid=18000
  });

  it('Direct unpaid: balance_due=total → paid=0', async () => {
    // total=18000, balance=18000 → paid=0
  });

  it('balance_due null → paid=0 (defensive)', async () => {
    // total=10000, balance=null → paid=0
  });

  it('extras during stay: balance_due > 0 → paid reflects', async () => {
    // total=10000, balance=2000 (extras added 1000) → paid=8000
  });
});
```

### 5.3-5.6 Tests Bug #5.1, #6, #7, #1

Análogos. Spec original (versión previa thread/205 sin update) cubre el detalle de cada uno — sigue mismo pattern.

## §6. Definition of Done

- [ ] Branch `fix/inbox-pr-a-llm-preview-sidebar` creada
- [ ] 5 archivos modificados:
  - `apps/worker-bot/src/inbox/aggregate.ts` (Bug #2 + #6)
  - `apps/worker-bot/src/inbox/lifecycle.ts` (Bug #5.1)
  - `apps/worker-bot/src/inbox/llm-suggestion.ts` (Bug #7)
  - `apps/worker-bot/src/api/admin/conversation.ts` (Bug #4 inline)
  - `apps/web/src/components/conversation/ConversationView.tsx` (Bug #1)
- [ ] Tests extendidos (~3-5 test files)
- [ ] `pnpm --filter worker-bot typecheck` PASS
- [ ] `pnpm --filter web typecheck` PASS
- [ ] `pnpm --filter worker-bot test` todos verdes
- [ ] `pnpm --filter web test` todos verdes
- [ ] PR creada con título `fix(inbox): critical bugs PR-A (thread/205)`
- [ ] Reporte CC al final con files modificados + LoC + PR URL + nota "MANUAL `npx wrangler deploy` post-merge"

## §7. Risks + Mitigations

| Risk | Mitigation |
|---|---|
| OTA fallback 2N queries lentas (75 × 2 = 150) | ~150ms total D1 overhead, aceptable Wave 1 |
| `paid_amount` formula incorrecta para edge cases | Tests cubren 5 casos. balance_due null → 0 defensive |
| LLM suggestion cost spike | Cache ephemeral 90% reduction. $0.08/inbox load aceptable Max plan |
| `fetchSuggestion.catch(() => null)` hide errors | OK — suggestion opcional, no debe break load. Errors loggeados server-side |
| vip_repeat fix podría romper otros lugares | grep global `'vip_repeat_check'` antes commit |
| Frontend deploy before worker-bot deploy | Order: merge → worker-bot deploy first → CF Pages auto. Defensive catch protege regression |

## §8. Out-of-scope findings → issues

Si CC encuentra algo NO listado §2.1 → GitHub issue prefix `[thread/205 OOS]`. NO fix inline.

## §9. Kickoff command (Alex paste to CC)

```
DoIt thread/205 PR-A: critical bugs inbox.

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/205-wc-inbox-critical-bugs-llm-preview-sidebar.md

Si no la tienes local, pull:
cd c:/dev/rdm/dev/discussion && git pull origin main

Sigue §4 implementation exacto. Self-review §6 DoD antes commit.

Working directory: c:/dev/rdm/dev/bot

Pre-flight:
1. cd c:/dev/rdm/dev/bot && git checkout main && git pull origin main
2. git status clean
3. git log --oneline -1 — confirma post thread/203 merge

Execution:
1. git checkout -b fix/inbox-pr-a-llm-preview-sidebar
2. Editar §4.2 + §4.5 aggregate.ts (fallback OTA + counters cross-tab)
3. Editar §4.4 lifecycle.ts (vip_repeat typo)
4. Editar §4.6 llm-suggestion.ts (phone normalize)
5. Editar §4.3 conversation.ts (paid_amount simple)
6. Editar §4.1 ConversationView.tsx (Promise.all fetchSuggestion)
7. Tests §5.1-5.6 extendidos
8. pnpm typecheck + test ambos workspaces
9. Commit semántico, push branch
10. gh pr create con título + body referencia thread/205 + thread/204 + ⚠️ MANUAL wrangler deploy nota
11. Reporte final

Scope ESTRICTO §2.1. OOS → issue prefix [thread/205 OOS]. NO inline fix.

Bloqueado >30 min = STOP + reporta.

GO.
```

## §10. Post-merge smoke test (Alex)

Después de merge + `cd apps/worker-bot && npx wrangler deploy`:

1. **LLM suggestion aparece Claudia** (Bug #1) — Click Claudia row → box "✨ Sugerencia IA" visible con texto + botones
2. **Preview Tab Reservas** (Bug #2) — Múltiples rows muestran preview real (antes vacío)
3. **Sidebar paid Claudia** (Bug #4) — "$1,799 / $5,452 MXN" (no "$0 / $5,452")
4. **Counter cross-tab** (Bug #6) — Ambos contadores populated, no 0
5. **VIP section** (Bug #5.1) — Aparece cuando hay matches históricos
6. **Alan Granados regression** (thread/203 + Bug #7) — Mensajes WA visibles + LLM suggestion ahora con contexto booking

✅ Smoke completa → **thread/206 PR-B siguiente paso**.

## §11. References

- thread/204 (audit deep dive)
- thread/200, 203 (patrones polimorphic + phone normalize)
- D1 evidence (14 queries verified)
- Memorias #25, #26
