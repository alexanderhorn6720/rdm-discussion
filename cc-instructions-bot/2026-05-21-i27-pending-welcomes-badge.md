# I27 · Pending welcomes prominent badge · CC DoIt spec

**Status**: PENDING ALEX APPROVAL (Day 3 ranking). Pre-staged.
**Workstream**: CC-Bot (territory: `apps/web/src/pages/admin/pre-stay.astro`)
**Effort estimate**: 1h CC (conservative budget 1.5h)
**Source**: §F idea I27 + cross-ref `reports/audit-2026-Q2/02-operational-audit-wc-impl.md` follow-up F-6

---

## §1 · Context

### Problem

D1 evidence (audit-2026-Q2 follow-up F-6): **12 of 37 bookings (~32%) pending welcome**, oldest = 8 days. The Catch-up button exists in `/admin/pre-stay` but Karina doesn't notice because:
- No prominent badge "12 pending"
- Lede is ~110 words long; she skips it
- Pendings interleaved with completed in the same table

Pre-stay catch-up could close the loop today if Karina realized the urgency.

### Current state

`/admin/pre-stay.astro` renders:
- Lede ~110 words
- Per-row state with touchpoint columns (welcome, eta, instrucciones, parking)
- "Catch-up" bulk button

No prominent count display. No filter for "pending only".

### Desired behavior

Top of `/admin/pre-stay` page (and `/admin` landing if simple): a badge showing `{N} bookings pending welcome (oldest: {N} days)`. Tap the badge → URL state `?filter=pending` → table re-rendered showing only pendings.

If `N == 0` or `oldest < 2 days` → badge hidden (no alarm).

---

## §2 · Explicit scope

### YES

- Compute `pending_welcomes_count` + `oldest_pending_days` in `/admin/pre-stay.astro` server-side
- Render prominent badge at top of page (above lede) if `count >= 1 AND oldest >= 2`
- Badge styling: red bg if `oldest >= 7`, yellow bg if `oldest >= 2 AND oldest < 7`
- Badge tappable → adds `?filter=pending` to URL → re-renders table with only pending rows
- Add `?filter=pending|all` query param support (default `all`)
- Filter chips visible: `[Todos]` `[Pending: 12]` (highlight current)
- Update lede to be SHORTER (~50 words max) — extract the long version to a collapsible `<details>` "Cómo funciona pre-stay"

### NO

- DO NOT change Catch-up button logic
- DO NOT change `pre_stay_touchpoints` schema
- DO NOT auto-fire catch-up (Karina must explicitly tap)
- DO NOT change which bookings are eligible (room_id != 679176 filter remains)
- DO NOT add badge to landing `/admin` (separate spec for morning briefing I3)

---

## §3 · Closed decisions

- **Badge threshold**: hide if `count == 0` OR `oldest < 2 days` (avoid alarm for normal pipeline)
- **Severity color**: yellow `2-6 days oldest`, red `7+ days oldest`
- **Filter param**: `?filter=pending|all` (default `all`)
- **Lede shortening**: extract long version to `<details>` collapsible "¿Cómo funciona pre-stay?"
- **Pending definition**: row where `welcome_sent_at IS NULL AND arrival > today AND arrival < today + 60 days AND room_id != 679176`

---

## §4 · Implementation

### Files to modify

| File | Change |
|---|---|
| `apps/web/src/pages/admin/pre-stay.astro` | Add badge + filter + short lede |

### Server-side query addition

```typescript
// In /admin/pre-stay.astro before render:

const url = new URL(Astro.request.url);
const filter = (url.searchParams.get('filter') ?? 'all') as 'pending' | 'all';

// Count pending welcomes (independent of view filter — always show truth)
const { results: pendingStats } = await env.DB.prepare(
  `SELECT
     COUNT(*) AS count,
     MIN(arrival) AS oldest_arrival
   FROM beds24_bookings bb
   LEFT JOIN pre_stay_touchpoints p
     ON p.beds24_booking_id = bb.beds24_booking_id
   WHERE bb.room_id != 679176
     AND bb.arrival >= date('now')
     AND bb.arrival < date('now', '+60 days')
     AND (p.welcome_sent_at IS NULL OR p.id IS NULL)
     AND bb.status NOT IN ('cancelled','archived')`
).all<{ count: number; oldest_arrival: string | null }>();

const pendingCount = pendingStats[0]?.count ?? 0;
const oldestArrival = pendingStats[0]?.oldest_arrival;
const oldestPendingDays = oldestArrival
  ? Math.floor((Date.now() - new Date(oldestArrival).getTime()) / (24 * 3600 * 1000))
  : 0;
// NOTE: oldest is FUTURE arrival, so days are negative. Adjust:
// We want "how many days BEFORE arrival" = NEGATIVE means we still have time
// Use abs(days) where the URGENCY is "how soon arrival" not "how old".
// Actually re-frame: "oldest" = earliest arrival = most urgent. Compute days until arrival:
const daysUntilOldest = oldestArrival
  ? Math.floor((new Date(oldestArrival).getTime() - Date.now()) / (24 * 3600 * 1000))
  : 999;

// Badge visibility logic:
// SHOW if pendingCount >= 1 AND (arrival in <=7 days = critical, OR <=14 days = warning)
const showBadge = pendingCount >= 1 && daysUntilOldest <= 14;
const badgeSeverity = daysUntilOldest <= 7 ? 'red' : 'yellow';
```

**WAIT — re-reading**: §1 says "oldest = 8 days" pendings. That's 8 days SINCE arrival or 8 days WAITING? Looking at audit-2026-Q2 follow-up F-6: "12/37 bookings (32%) pending welcome". Welcome is sent BEFORE arrival typically. So "8 days oldest" likely means "8 days since the booking entered the welcome-pending state" OR "arrival is 8 days away and welcome still not sent".

Per the pre-stay touchpoint logic: welcome should fire X days BEFORE arrival. If `arrival - today = 8 days` and welcome not sent → that's late vs target window.

**Recommend**: CC must verify by reading `pre-stay.astro` source + `lib/pre-stay-orchestrator` config. If welcome target window is "send 14 days pre-arrival" → "oldest pending" with arrival in 2 days = critical. If target is "send 7 days pre-arrival" → arrival in 1 day = critical.

For v1 spec: use `daysUntilOldest` logic above. CC adjusts thresholds based on actual target window.

### Badge rendering

```html
{showBadge && (
  <div class={`pending-badge pending-badge-${badgeSeverity}`}>
    <strong>⚠ {pendingCount} reservas sin welcome</strong>
    {daysUntilOldest <= 0 ? (
      <span>· Llegada HOY o pasada</span>
    ) : (
      <span>· Próxima llegada en {daysUntilOldest} día{daysUntilOldest === 1 ? '' : 's'}</span>
    )}
    <a href="?filter=pending" class="badge-action">Ver solo pending →</a>
  </div>
)}

<nav class="filter-chips">
  <a
    href="/admin/pre-stay"
    class={`chip ${filter === 'all' ? 'active' : ''}`}
  >Todos</a>
  <a
    href="?filter=pending"
    class={`chip ${filter === 'pending' ? 'active' : ''}`}
  >Pending: {pendingCount}</a>
</nav>
```

### CSS additions

```css
.pending-badge {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4);
  border-radius: var(--radius-md);
  margin-bottom: var(--sp-4);
  font-size: var(--fs-sm);
}
.pending-badge-yellow {
  background: #fef3c7;
  color: #92400e;
  border-left: 4px solid #f59e0b;
}
.pending-badge-red {
  background: #fee2e2;
  color: #991b1b;
  border-left: 4px solid #dc2626;
}
.pending-badge .badge-action {
  margin-left: auto;
  color: inherit;
  font-weight: 600;
  text-decoration: underline;
}
.filter-chips {
  display: flex;
  gap: var(--sp-2);
  margin: var(--sp-3) 0 var(--sp-4);
}
.chip {
  padding: var(--sp-1) var(--sp-3);
  background: var(--color-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  color: var(--color-text);
  text-decoration: none;
  font-size: var(--fs-sm);
}
.chip.active {
  background: var(--color-primary);
  color: white;
  border-color: var(--color-primary);
}

/* Mobile: pending-badge wraps gracefully */
@media (max-width: 480px) {
  .pending-badge .badge-action {
    margin-left: 0;
    width: 100%;
  }
}
```

### Lede shortening

Current lede ~110 words → trim to ~40 words:

```html
<p class="lede">
  Estado del pre-stay automation: welcome, ETA, instrucciones, parking.
  Si ves pendings &gt; 7 días, usa el botón Catch-up.
</p>

<details class="how-it-works">
  <summary>¿Cómo funciona pre-stay?</summary>
  <p>
    [Move the existing long explanation here — keep verbatim, just relocate.]
  </p>
</details>
```

### Filter logic on table rows

```typescript
// After main query (existing logic):
const rowsToRender = filter === 'pending'
  ? rows.filter(r => !r.welcome_sent_at)
  : rows;

// Then existing render code uses `rowsToRender` instead of `rows`.
```

---

## §5 · Tests

### Unit tests (helper extraction)

If you extract `computePendingStats(env.DB)` to `lib/admin-pre-stay.ts`:

```typescript
describe('computePendingStats', () => {
  test('returns 0 count when no pending welcomes', async () => {
    // Seed DB with all welcomes sent
    const stats = await computePendingStats(testDb);
    expect(stats.count).toBe(0);
    expect(stats.oldestArrival).toBeNull();
  });

  test('returns count + oldest arrival when pendings exist', async () => {
    // Seed DB with 3 pending, oldest arrival 2026-05-23
    const stats = await computePendingStats(testDb);
    expect(stats.count).toBe(3);
    expect(stats.oldestArrival).toBe('2026-05-23');
  });

  test('excludes Casa Chamán (679176)', async () => {
    // Seed: 2 pending in room 78695 + 1 pending in 679176
    const stats = await computePendingStats(testDb);
    expect(stats.count).toBe(2);
  });

  test('excludes cancelled / archived', async () => {
    // Seed: 2 pending + 1 cancelled
    const stats = await computePendingStats(testDb);
    expect(stats.count).toBe(2);
  });
});
```

### Smoke test (manual)

1. Visit `/admin/pre-stay` with no pending → badge HIDDEN ✓
2. Seed 1 pending with arrival = today + 10 days → badge HIDDEN ✓ (>14 days threshold)
3. Seed 1 pending with arrival = today + 5 days → badge VISIBLE, yellow ✓
4. Seed 1 pending with arrival = today + 1 day → badge VISIBLE, red ✓
5. Tap badge "Ver solo pending →" → URL gains `?filter=pending` ✓
6. Filter chips show `Pending: N` highlighted ✓
7. Table renders ONLY pending rows ✓
8. Tap "Todos" chip → returns to full view ✓
9. Mobile 320px: badge wraps to multi-line, action button full-width ✓
10. Mobile 720px: badge inline single-line ✓

---

## §6 · Definition of done

- [ ] `/admin/pre-stay.astro` computes pending stats server-side
- [ ] Badge renders conditionally with correct severity color
- [ ] Filter chips work via `?filter=pending|all`
- [ ] Lede shortened, long version in `<details>` collapsible
- [ ] All unit tests pass
- [ ] Smoke test 10 steps pass locally
- [ ] No console errors at 320px/720px/1024px
- [ ] PR opened with: link to spec + screenshot before/after

---

## §7 · Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| `oldest_arrival` interpretation wrong (since arrival? since booking?) | medium | CC verifies by reading existing `lib/pre-stay-orchestrator` for target window logic. Adjust badge threshold accordingly. |
| Query slow if many rows (60d × 4 properties) | low | Add index on `pre_stay_touchpoints(beds24_booking_id, welcome_sent_at)` if not present. Verify with EXPLAIN QUERY PLAN. |
| Karina misses change because lede ALSO trimmed | low | Badge is visual-priority MUCH higher than lede. Trim is fine. |
| Filter chip `Pending: N` shows count from BEFORE catch-up bulk action | medium | After Catch-up button fires, page reloads → count refreshes naturally. Acceptable for v1. |
| Casa Chamán pending leaks if `room_id` check missing | low | Test #3 covers explicitly. |

---

## §8 · Sequencing

1. CC: branch `feat/i27-pending-welcomes-badge` (~5min)
2. CC: read existing `/admin/pre-stay.astro` + verify schema (~10min)
3. CC: add `computePendingStats` query + extract helper (~15min)
4. CC: render badge + filter chips + CSS (~20min)
5. CC: shorten lede + relocate to `<details>` (~5min)
6. CC: tests + smoke (~15min)
7. CC: open PR (~5min)

Total CC: ~1h. Total Alex: ~10min review/merge.

---

## §9 · Out of scope (future iteration)

- Badge on `/admin` landing (separate spec for morning briefing I3)
- Per-property breakdown ("4 pending Las Morenas · 3 pending Combinada")
- Notification when N pendings exceed threshold (e.g., Telegram alert if N >= 10)
- Auto-catch-up if pending > 7 days (no human gate)

---

**Spec sealed** by WC-Implementation 2026-05-21 ~05:45 MX. Pending Alex Day 3 approval.
