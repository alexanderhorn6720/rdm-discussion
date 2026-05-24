---
thread: 206
author: wc
topic: inbox-readiness-rules-accepted-status-badges
status: ready-for-execution
mode: DoIt
created: 2026-05-24
related_threads: [196, 204, 205, 207]
estimated_effort: 2-3h CC (1 session)
pipeline: PR-B of mega-run (after PR-A thread/205 merged + deployed + smoke verified)
requires_d1_migration: YES (migration 0035, off-window since multi-CC NO concurrent durante migration)
requires_worker_bot_deploy: YES (manual)
requires_web_redeploy: YES (auto CF Pages)
severity: MEDIUM (readiness completion + visual state)
---

# Thread 206 — PR-B: Readiness rules_accepted + Status badges visual

> **PR-B of 3 (mega-run)**. Pre-req: PR-A (thread/205) merged + deployed + smoke OK.

## §0. TL;DR

Resuelve **Bug #5 (rules_accepted siempre false → max 5/6, nunca 6/6)** + agrega **status badges visuales** per row (Open / Snoozed / Resolved) que están en data pero no exposed visualmente.

| Fix | Impacto |
|---|---|
| Migration 0035 `booking_captures.rules_accepted` boolean + Karina toggle | Readiness completo 6/6 cuando aplica |
| Status badges Open/Snoozed/Resolved en InboxRow | Karina ve estado workflow per conversation |

~3 archivos backend + ~3 archivos frontend modificados. 1 migration (off-window).

## §1. Context

### 1.1 Estado pre-fix

`apps/worker-bot/src/inbox/readiness.ts` línea 64:
```ts
// rules_accepted: no column exists → false (Wave 1.5)
const rules_accepted = false;
```

Score máximo = 5/6 sistemicamente. Nunca 6/6.

Status workflow data existe en `conversations.bot_paused_until` + `conversations.resolved_at` pero NO se expone en `InboxRow` contract — Karina no ve visual state.

### 1.2 Por qué requiere thread separado

Migration 0035 requiere window OFF-multi-CC (anti-pattern memorias). 1 CC serial post-PR-A garantiza no concurrency. Alex aplica migration manualmente antes de o durante CC run.

## §2. Explicit scope

### 2.1 IN scope

| Archivo | Cambio |
|---|---|
| `packages/db/migrations/0035_booking_captures_rules_accepted.sql` | NEW migration |
| `apps/worker-bot/src/inbox/readiness.ts` | Use new column, score puede llegar 6/6 |
| `apps/worker-bot/src/inbox/aggregate.ts` | Expose `is_snoozed`, `is_resolved` al InboxRow |
| `apps/worker-bot/src/api/admin/booking-detail.ts` (o donde existe captures CRUD) | Endpoint para toggle `rules_accepted` |
| `apps/web/src/lib/inbox-client.ts` | Type `InboxRow` add `is_snoozed`, `is_resolved`. Type `ReadinessScore` ya tiene `rules_accepted` ✅ |
| `apps/web/src/components/inbox/InboxRow.tsx` | Render status badges visual |
| `apps/web/src/components/inbox/ReadinessScore.tsx` | (no cambios — ya soporta 6/6 visualmente) |
| `apps/web/src/pages/admin/bookings/[id].astro` (si existe) o nuevo component | Toggle UI para Karina marcar `rules_accepted` |
| Tests: readiness + aggregate + InboxRow | Extender |

Esperado: ~6-8 archivos modificados, ~150-200 LoC.

### 2.2 OUT of scope

- ❌ Bug #3 threading 1-row-per-cliente — defer
- ❌ Quick action buttons → thread/207
- ❌ Auto-scroll bottom → thread/207
- ❌ Drawer width fix → thread/207
- ❌ Fechas display row → thread/207
- ❌ Cualquier otro CSS unrelated
- ❌ Internal notes / tags / translation → Wave 2

## §3. Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | rules_accepted column en `booking_captures` (NOT en `beds24_bookings`) | Captures = mutable state, bookings = canonical Beds24 mirror. Aislamiento limpio |
| D2 | rules_accepted = boolean default 0, Karina marca manual desde `/admin/bookings/[id]` | Anti-pattern automation: forms detection no es reliable yet. Manual toggle simple |
| D3 | Migration 0035 apply post PR-A deploy, antes PR-B CC run | Off-multi-CC window. Alex aplica `wrangler d1 migrations apply rincon --remote` manual |
| D4 | Status badges visual: Open (default = no badge), Snoozed (🌙 amber), Resolved (✅ gray) | Industry pattern HelpScout/Front. Minimalist — no badge para default |
| D5 | `is_snoozed` = bot_paused_until > now AND resolved_at IS NULL. `is_resolved` = resolved_at IS NOT NULL AND resolved_at > unixepoch() - 7*86400 (last 7d) | Stale resolved no aparecen — aggregate ya filtra |
| D6 | NO agregar Status filter al `InboxFilters` Wave 1 | Visual primero, filter Wave 2 si Karina lo pide |
| D7 | Toggle UI rules_accepted en sidebar booking `/admin/bookings/[id]` (no en inbox compose box) | Inbox compose es operacional. Sidebar booking es config |

## §4. Implementation

### 4.1 Migration 0035

`packages/db/migrations/0035_booking_captures_rules_accepted.sql`:

```sql
-- thread/206: rules_accepted column for readiness 6/6 (Bug #5)
-- Anti-pattern: NEVER apply during multi-CC concurrent runs.
-- Apply manually: cd c:/dev/rdm/dev/bot && pnpm --filter @rdm/db migrate

ALTER TABLE booking_captures ADD COLUMN rules_accepted INTEGER NOT NULL DEFAULT 0;

-- Index NOT needed (low cardinality boolean, full scan OK for inbox aggregate)
```

**Alex apply command**:
```bash
cd c:/dev/rdm/dev/bot
npx wrangler d1 migrations apply rincon --remote
# Verify:
npx wrangler d1 execute rincon --remote --command="SELECT name FROM pragma_table_info('booking_captures') WHERE name='rules_accepted'"
```

### 4.2 readiness.ts use new column

`apps/worker-bot/src/inbox/readiness.ts`:

```diff
 export interface BookingCapturesRow {
   mascotas_confirmed: number | null;
   mascotas_count: number | null;
   menu_status: string | null;
   compras_confirmed: number | null;
   morenas_svc_confirmed: number | null;
+  rules_accepted: number | null;
 }

 // ...

 export function computeReadiness(
   booking: Beds24BookingRow,
   captures: BookingCapturesRow | null,
   history: string,
 ): ReadinessScore {
   const cap = captures ?? {} as BookingCapturesRow;

   const pax_confirmed = booking.num_adults > 0;
   const pet_decided = cap.mascotas_confirmed === 1 || (booking.num_pets === 0 && cap.mascotas_confirmed != null);
   const menu_decided = cap.menu_status === 'recibido' || cap.menu_status === 'declined';
   const eta_known = detectEtaFromHistory(history);

-  // rules_accepted: no column exists → false (Wave 1.5)
-  const rules_accepted = false;
+  // thread/206: read from booking_captures.rules_accepted (migration 0035)
+  const rules_accepted = cap.rules_accepted === 1;

   const paid = ...;
   const booleans = [pax_confirmed, pet_decided, menu_decided, eta_known, rules_accepted, paid];
   const score = booleans.filter(Boolean).length;
   return { pax_confirmed, pet_decided, menu_decided, eta_known, rules_accepted, paid, score };
 }
```

### 4.3 aggregate.ts SELECT capture rules + expose status fields

`apps/worker-bot/src/inbox/aggregate.ts`:

```diff
 type RawBookingRow = {
   // ... existing fields
   mascotas_confirmed: number | null;
   mascotas_count: number | null;
   menu_status: string | null;
   compras_confirmed: number | null;
   morenas_svc_confirmed: number | null;
+  rules_accepted: number | null;  // thread/206
   // ...
 };

 // ...

 // Tab Reservas query SELECT expand:
 let query = `
   SELECT
     bb.beds24_booking_id, bb.room_id, bb.arrival, bb.departure,
     bb.num_adults, bb.num_pets, bb.total_amount_mxn, bb.deposit_paid,
     bb.balance_due_mxn, bb.channel, bb.status, bb.guest_id,
     bc.mascotas_confirmed, bc.mascotas_count, bc.menu_status,
-    bc.compras_confirmed, bc.morenas_svc_confirmed,
+    bc.compras_confirmed, bc.morenas_svc_confirmed, bc.rules_accepted,
     g.name AS guest_name, g.phone_e164, g.total_bookings,
     c.subscriber_id AS conv_subscriber_id
   ...
 `;

 // computeReadiness call:
 const readiness = computeReadiness(
   { ... },
   {
     mascotas_confirmed: br.mascotas_confirmed,
     mascotas_count: br.mascotas_count,
     menu_status: br.menu_status,
     compras_confirmed: br.compras_confirmed,
     morenas_svc_confirmed: br.morenas_svc_confirmed,
+    rules_accepted: br.rules_accepted,
   },
   '',
 );
```

Y agregar `is_snoozed`, `is_resolved` al InboxRow contract + populate:

```diff
 export interface InboxRow {
   // ... existing fields
+  is_snoozed: boolean;  // thread/206: bot_paused_until > now
+  is_resolved: boolean; // thread/206: resolved_at within last 7d
 }
```

```diff
   rows.push({
     // ...
     bot_paused_until: convRow?.bot_paused_until ?? null,
+    is_snoozed: !!convRow?.bot_paused_until && new Date(convRow.bot_paused_until).getTime() > nowMs,
+    is_resolved: !!convRow?.resolved_at && convRow.resolved_at > Math.floor(nowMs / 1000) - 7 * 86400,
   });
```

Mirror en Tab Leads loop también.

### 4.4 conversation.ts también extender BookingCapturesRow

`apps/worker-bot/src/api/admin/conversation.ts` — el SELECT del booking en `resolveConvContext` debe incluir `bc.rules_accepted`. Idempotente con aggregate.ts.

### 4.5 Endpoint rules_accepted toggle

Verificar primero: existe `apps/worker-bot/src/api/admin/booking-detail.ts` o algo similar. Spec memoria sugiere `/admin/booking-captures/:id` endpoint existe (PUT).

Si existe — agregar `rules_accepted` al whitelist ALLOWED:

```diff
   const ALLOWED = new Set([
     'mascotas_count', 'mascotas_notes', 'mascotas_confirmed',
     'evento_type', 'evento_custom', 'evento_confirmed',
     'morenas_chef_enabled', 'morenas_chef_days',
     'morenas_cocinera_enabled', 'morenas_cocinera_days',
     'morenas_svc_confirmed',
     'menu_status',
     'compras_monto_mxn', 'compras_notes', 'compras_confirmed',
     'notes_karina', 'special_requests',
+    'rules_accepted',  // thread/206
   ]);
```

Si NO existe equivalente endpoint — crear `POST /api/admin/booking-captures/:id/rules-accepted` simple endpoint.

CC verificar primero qué existe.

### 4.6 InboxRow.tsx render status badges

`apps/web/src/components/inbox/InboxRow.tsx`:

```diff
 export default function InboxRow({ row, onClick }: Props) {
   const isTestNumber = row.is_test_number;

   return (
     <div className="inbox-row" ...>
       <div className="inbox-row-name">
         {row.guest_name}
         {row.display_name_was_garbage && (...)}
         {row.unread_count > 0 && (...)}
         {isTestNumber && (...)}
+        {/* thread/206: status badges */}
+        {row.is_snoozed && (
+          <span className="inbox-badge inbox-badge-snoozed" title="Bot pausado">
+            🌙 Snoozed
+          </span>
+        )}
+        {row.is_resolved && (
+          <span className="inbox-badge inbox-badge-resolved" title="Resuelto recientemente">
+            ✅ Resuelto
+          </span>
+        )}
         {/* stay-info ... */}
       </div>
       // ... rest
     </div>
   );
 }
```

CSS classes nuevas en `inbox.css`:

```css
.inbox-badge-snoozed {
  background: #fef3c7;
  color: #92400e;
  border: 1px solid #fcd34d;
}
.inbox-badge-resolved {
  background: #f3f4f6;
  color: #6b7280;
  border: 1px solid #d1d5db;
}
```

### 4.7 Toggle rules_accepted UI

Verificar primero: existe `/admin/bookings/[id]` con sidebar de captures editing?

Si SÍ: agregar 1 toggle row más:

```tsx
<div className="capture-row">
  <label>
    <input
      type="checkbox"
      checked={captures.rules_accepted === 1}
      onChange={(e) => updateCapture('rules_accepted', e.target.checked ? 1 : 0)}
    />
    Reglas de casa aceptadas por el huésped
  </label>
</div>
```

Si NO: defer this específico a thread/208 polish (que Karina marque desde inbox sidebar conversation context — feature nuevo).

Voto WC: si existe `/admin/bookings/[id]` page → agregar toggle ahí. Si no existe el page completo → toggle en `BookingContextSidebar.tsx` (conversation drawer sidebar derecha) es alternative simpler. CC decide después de verify.

## §5. Tests

### 5.1 readiness.ts con rules_accepted

```ts
describe('computeReadiness — rules_accepted (thread/206 Bug #5)', () => {
  it('returns rules_accepted=true when captures.rules_accepted=1', () => {
    const r = computeReadiness(booking, { ...captures, rules_accepted: 1 }, '');
    expect(r.rules_accepted).toBe(true);
  });

  it('returns rules_accepted=false when captures.rules_accepted=0 or null', () => {
    expect(computeReadiness(booking, { ...captures, rules_accepted: 0 }, '').rules_accepted).toBe(false);
    expect(computeReadiness(booking, { ...captures, rules_accepted: null }, '').rules_accepted).toBe(false);
  });

  it('score reaches 6/6 when all 6 components true', () => {
    const r = computeReadiness(
      { num_adults: 4, num_pets: 0, total_amount_mxn: 5000, deposit_paid: 1, balance_due_mxn: 0, arrival: '...', departure: '...', room_id: 78695 },
      { mascotas_confirmed: 1, mascotas_count: 0, menu_status: 'recibido', compras_confirmed: 1, morenas_svc_confirmed: 1, rules_accepted: 1 },
      'USER: llegamos 3pm',  // triggers eta_known
    );
    expect(r.score).toBe(6);
  });
});
```

### 5.2 aggregate exposes is_snoozed / is_resolved

```ts
describe('aggregateInbox — status flags (thread/206 D5)', () => {
  it('flags is_snoozed when bot_paused_until in future', async () => { ... });
  it('flags is_resolved when resolved_at within last 7d', async () => { ... });
  it('NO flag when paused expired or resolved >7d', async () => { ... });
});
```

### 5.3 InboxRow renders badges

```tsx
describe('InboxRow — status badges (thread/206)', () => {
  it('renders snoozed badge when is_snoozed', () => {
    render(<InboxRow row={{ ...mockRow, is_snoozed: true }} onClick={jest.fn()} />);
    expect(screen.getByText(/Snoozed/i)).toBeInTheDocument();
  });
  it('renders resolved badge when is_resolved', () => { ... });
  it('NO badge default (open)', () => { ... });
});
```

## §6. Definition of Done

- [ ] Migration 0035 creada + applied remote (Alex manual pre-CC run)
- [ ] readiness.ts uses new column
- [ ] aggregate.ts SELECT + populate is_snoozed/is_resolved (Tab Reservas + Leads)
- [ ] conversation.ts SELECT incluye bc.rules_accepted
- [ ] booking-detail endpoint o equivalente acepta rules_accepted en PUT/PATCH
- [ ] InboxRow renders badges
- [ ] inbox.css badges styling
- [ ] Toggle UI rules_accepted en /admin/bookings/[id] o BookingContextSidebar
- [ ] inbox-client.ts type extends
- [ ] Tests pasan
- [ ] PR título: `feat(inbox): readiness 6/6 + status badges PR-B (thread/206)`
- [ ] Reporte CC con files + LoC + PR URL + nota wrangler deploy

## §7. Risks + Mitigations

| Risk | Mitigation |
|---|---|
| Migration 0035 ALTER TABLE in multi-CC = anti-pattern | 1 CC serial post PR-A. Alex aplica manual antes CC start. No concurrent CC |
| rules_accepted Karina nunca marca → readiness 6/6 nunca | Comunicar a Kari post-deploy. UI prominent en sidebar booking |
| Status badges visual clutter | Minimalist — solo Snoozed y Resolved (open = no badge). Si Karina complain, ajustar CSS |
| /admin/bookings/[id] page may not exist | CC verifica. Si no existe, toggle en BookingContextSidebar alternative |
| `resolved_at` column may be int (unixepoch) or text (ISO) — inconsistent legacy | CC verifica schema actual y handles ambos: `typeof resolved_at === 'number' ? ... : new Date(resolved_at).getTime() / 1000` |

## §8. Out-of-scope findings → issues

Si CC encuentra:
- bot_metrics table needed → issue `[thread/206 OOS]` (memoria #25)
- subscribers table needed → issue
- Otros readiness components missing → defer thread/208+

## §9. Kickoff command (Alex paste to CC)

```
DoIt thread/206 PR-B: readiness rules_accepted + status badges.

⚠️ PRE-REQUISITE: PR-A (thread/205) MERGED + DEPLOYED + SMOKE OK. Verificar https://rincondelmar.club/admin/inbox muestra LLM suggestion + preview Tab Reservas + sidebar paid correcto antes de empezar.

⚠️ ALEX FIRST: aplicar migration 0035 antes que CC empiece:
  cd c:/dev/rdm/dev/bot
  # Verificar archivo exists primero: packages/db/migrations/0035_booking_captures_rules_accepted.sql
  # Si NO existe, CC lo crea como primer paso commit, después Alex apply:
  npx wrangler d1 migrations apply rincon --remote

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/206-wc-inbox-readiness-rules-status-badges.md

Working directory: c:/dev/rdm/dev/bot

Pre-flight:
1. cd c:/dev/rdm/dev/bot && git checkout main && git pull origin main
2. git status clean
3. git log --oneline -1 — confirma post PR-A merge

Execution:
1. git checkout -b feat/inbox-pr-b-readiness-status-badges
2. CREATE packages/db/migrations/0035_booking_captures_rules_accepted.sql (§4.1)
3. STOP — pedir a Alex aplicar migration manualmente y confirmar antes continuar
4. (resuming post-migration-applied) Editar readiness.ts (§4.2)
5. Editar aggregate.ts SELECT + is_snoozed/is_resolved population (§4.3)
6. Editar conversation.ts SELECT incluye bc.rules_accepted (§4.4)
7. Endpoint rules_accepted toggle (§4.5) — verify booking-detail.ts existe
8. InboxRow badges (§4.6) + inbox.css
9. Toggle UI rules_accepted (§4.7) — verify /admin/bookings/[id] existe
10. Type extends inbox-client.ts
11. Tests §5
12. typecheck + tests
13. Commit + push + PR
14. Reporte

Scope ESTRICTO §2.1. OOS → issue prefix [thread/206 OOS].

Bloqueado >30 min = STOP + reporta.

GO.
```

## §10. Post-merge smoke test (Alex)

Post merge + `cd apps/worker-bot && npx wrangler deploy`:

1. **Karina marca rules_accepted Claudia**: `/admin/bookings/86656062` → toggle "Reglas aceptadas" → verifica readiness changes
2. **Readiness puede llegar 6/6**: si todos los 6 ✓, ReadinessScore muestra "✓6" (no "✓5")
3. **Snoozed badge aparece**: pausar bot manualmente en una conv → inbox row muestra 🌙 Snoozed
4. **Resolved badge aparece**: resolver una conv → row muestra ✅ Resuelto (hasta 7d)

✅ Smoke OK → **thread/207 PR-C siguiente paso**.

## §11. References

- thread/204 audit Bug #5 + UX gap §6.6
- thread/205 PR-A pre-req
- Memorias #25 (Wave 1.5 followups)
- Industry pattern: HelpScout, Front status badges visual
