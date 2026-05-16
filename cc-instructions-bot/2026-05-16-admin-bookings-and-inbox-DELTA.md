# DELTA — /admin/bookings spec updates (Iteration 2)

**Date**: 2026-05-16
**Author**: WC (with Alex)
**Updates**: `cc-instructions-bot/2026-05-16-admin-bookings-gantt-build-spec.md`
**Reason**: Alex review introduced 3 refinements

---

## Change 1 — Add list view (toggle, same route)

**Decision**: NOT `/admin/bookings2`. ADD list view to same `/admin/bookings` page via toggle.

### Implementation

URL param:
```
/admin/bookings?view=gantt   (default — Gantt calendar, current spec)
/admin/bookings?view=list    (table view, this addition)
```

### List view layout

```
┌────────────────────────────────────────────────────────────────────────┐
│ /admin/bookings   View: [Gantt] [List✓]   Sort: [Arrival ▼]           │
│ Filter: Channel ▼  Property ▼  Status ▼  Time: [Next 30d ▼]  Search   │
├────────────────────────────────────────────────────────────────────────┤
│ Guest         │ Property │ Channel    │ Arrival │ Nights│ Group │ Flags│
├────────────────────────────────────────────────────────────────────────┤
│ Pérez Hndz    │ RdM      │ 🟠 Airbnb  │ May 16  │ 5    │ 16    │      │
│ García Soto   │ Morenas  │ 🔵 Booking │ May 18  │ 4    │ 25    │ 🐶   │
│ Wedding Soto  │ Combinada│ 🟢 Direct  │ May 20  │ 3    │ 40    │ ★ 💰 │
│ Cuauh. Ríos   │ Huerta   │ 🟠 Airbnb  │ May 16  │ 4    │ 6     │      │
│ ⚠ Luis Mendoza│ Huerta   │ 🟠 Airbnb  │ Mar 27  │ 6    │ 8     │ ⚠ 🐶 │
└────────────────────────────────────────────────────────────────────────┘
```

### Why list view is worth building

- Sortable columns (click header → sort by that field)
- Mobile-friendly (Gantt doesn't work on phone; list scrolls horizontally)
- Faster scan for "find me the Pérez booking"
- Higher density of info per screen
- Better for export/print thinking

### Implementation cost

~3-5h CC on top of Gantt. Same queries, same auth, same data — only presentation differs.

### Sortable columns

Default sort: `arrival` ASC. Click header to toggle:
- `guest_name` — alphabetical
- `property` — RdM > Morenas > Combinada > Huerta (fixed order)
- `channel` — alphabetical
- `arrival` — date asc/desc (default)
- `nights` — numeric
- `group_size` — numeric
- `flags` — flagged items first (issues, events, pending payments)

### Filters in list view

Same filters as Gantt:
- Channel, Property, Status, Time range
- Plus list-specific: Search by guest name or confirmation code

URL params consistent between views — toggle preserves filters.

### Mobile

List view works on mobile (responsive). Gantt does NOT work on mobile (set `view=list` automatically if viewport < 768px on initial load).

---

## Change 2 — Use KV calendar cache for blocked cells (no derivation)

**Original spec**: Derived "Combinada overlay" via TypeScript logic checking if Combinada had booking → shade RdM + Morenas.

**Updated spec**: USE existing KV cache `calendar:lookup` populated by `apps/worker-bot/src/cron.ts` (refreshes every ~2h from Beds24 `/inventory/rooms/calendar`).

### Why

The KV cache already has `numAvail` per `roomId × date`:

```typescript
// KV key 'calendar:lookup' shape:
{
  "78695": {     // RdM
    "2026-05-15": { price: 5500, min_stay: 2, num_avail: 1 },
    "2026-05-16": { price: 5500, min_stay: 2, num_avail: 0 },  // blocked
    ...
  },
  "74322": {     // Morenas
    "2026-05-16": { price: 6000, min_stay: 2, num_avail: 0 },  // ALSO blocked (linked by Combinada)
    ...
  },
  ...
}
```

When Combinada has a booking, Beds24 cascades `num_avail=0` to RdM AND Morenas automatically (linked rooms). The KV cache reflects this.

### Implementation

```typescript
// In the Astro page, server-side:
const calendarRaw = await env.KV_KNOWLEDGE.get('calendar:lookup');
const calendar = calendarRaw ? JSON.parse(calendarRaw) : {};

// For each cell (roomId, date):
function getCellState(roomId: number, date: string, ourBookings: Map<string, Booking>) {
  const bookingHere = ourBookings.get(`${roomId}-${date}`);
  if (bookingHere) return { type: 'booking', booking: bookingHere };
  
  const avail = calendar[roomId]?.[date]?.num_avail;
  if (avail === 0) return { type: 'blocked' };  // numAvail=0 but no our booking
  
  return { type: 'available' };
}
```

### Visual rendering

- `type: 'booking'` → render colored bar with surname (N)
- `type: 'blocked'` → gray cell, diagonal stripes pattern, tooltip "Blocked — no booking in this villa"
- `type: 'available'` → empty white cell

### Benefits

- ZERO custom logic for Combinada linkage
- Source of truth = Beds24 (single source)
- Works automatically if Beds24 changes linkage rules
- Handles other blocking reasons too (host manual block, maintenance, etc.)
- KV.get() is fast (<5ms)

### Tooltip on blocked cell

"Bloqueado · sin reserva en esta villa" — don't claim the reason. Reasons:
- Combinada booking (linked rooms)
- Host manually blocked in Beds24
- Maintenance/cleaning hold
- Beds24 data sync issue

We don't know which without extra query. Just show "blocked".

---

## Change 3 — Render inquiries (different from confirmed)

**Original spec**: only `status NOT IN ('cancelled', 'no_show', 'archived')` — but that includes `inquiry` and `request` as if they were confirmed.

**Updated**: differentiate visual rendering for tentative bookings.

### Beds24 status types affecting display

| Beds24 status | Description | Render style |
|---|---|---|
| `confirmed` | Booking confirmed, payment received | **Solid bar**, solid border, 100% opacity |
| `request` | Guest in active booking flow, near confirmation | **Solid bar**, solid border, 100% opacity (treat as confirmed visually) |
| `inquiry` | Pre-booking inquiry, may or may not convert | **Diagonal stripes pattern**, dashed border, 60% opacity |
| `black` | Beds24 internal block (host-set, no guest) | Gray pattern, no surname, tooltip "Bloqueado por host" |
| `cancelled` | Cancelled | Strikethrough text, faded gray, 30% opacity, **hidden by default filter** |
| `no_show` | Guest didn't arrive | Strikethrough text, faded gray, **hidden by default filter** |

### Channel colors don't change

A pending Airbnb inquiry is still orange — just patterned differently. This keeps channel identity consistent.

### Bar text

Same `Surname (N)` rule applies. For inquiry-state bookings:
- Append `(?)` to indicate tentative: `García? (25)` — only if useful
- Or rely solely on dashed-border + stripes pattern (cleaner)

Mi voto: **rely on visual styling, NOT add `?`**. Less clutter. Tooltip explains.

### Filter

Add filter option:
```
Status: ▼ All
        ▼ Confirmed only (default for Month/Quarter view)
        ▼ Confirmed + Requests
        ▼ Include inquiries
        ▼ Include cancelled (debug mode)
```

Default for Day/Week view: **Include inquiries** (operational planning needs them)
Default for Month/Quarter view: **Confirmed only** (clarity at zoom-out level)

### Mapping to D1 query

Modified query:

```sql
SELECT ...
FROM beds24_bookings bb
LEFT JOIN guests g ON g.id = bb.guest_id
LEFT JOIN leads l ON l.id = bb.lead_id
WHERE bb.arrival <= ?range_end
  AND bb.departure >= ?range_start
  AND bb.status NOT IN ('archived')                       -- always exclude archived
  AND (
    ?include_cancelled = 1 OR bb.status NOT IN ('cancelled', 'no_show')
  )
  AND (
    ?include_inquiries = 1 OR bb.status NOT IN ('inquiry', 'black')
  )
ORDER BY bb.room_id, bb.arrival;
```

---

## Change 4 — Leads (D1 `leads` table) belong in INBOX, NOT bookings

**Decision**: leads without dates+property locked DO NOT render in Gantt or list.

### Reasoning

- Leads in `leads` table may not have dates yet
- Even leads with dates may not have specific property
- Calendar/list views need a fixed cell (roomId × date)
- Leads belong to "conversation flow", not "calendar"

### Where leads go

In the `/admin/inbox` spec (`cc-instructions-bot/2026-05-16-admin-inbox-unified-build-spec.md`), add new state:

```
🟣 NEW LEAD · WhatsApp · 2h ago
Juan Pérez · +52 55 1234 5678 · "info para 16 personas, fin de semana julio"
Status: new · Property interest: undecided · Quote sent: NO
[Open conv] [Manual qualify]
```

### Inbox spec addendum (apply to inbox spec)

Add 1 more state to the inbox spec:

| State | Color | Source table | Trigger condition |
|---|---|---|---|
| 🟣 **New lead** | purple #A855F7 | `leads` | `status='new' OR status='engaged'` AND `last_active > now-24h` |

Update priority order:
```
1. Critical keyword
2. Escalated
3. Bot paused (about to expire)
4. Stalled
5. New lead (purple)   ← NEW
6. Active bot
7. Beds24 unread
8. Resolved
```

Action buttons for `🟣 New lead`:
- `Open conv` (jumps to /admin/conv)
- `Manual qualify` (NEW endpoint — sets `leads.status='engaged'` + appends note)

---

## Summary of changes to CC

### Spec `2026-05-16-admin-bookings-gantt-build-spec.md`

| Section | Change |
|---|---|
| Title | Add "+ list view" |
| Visual design | Add list view section |
| Data queries | Add status filter logic; use KV `calendar:lookup` for blocked cells |
| Acceptance criteria | Add list view items; KV cache integration; inquiry rendering |
| Out of scope | Mobile design moved from "out of scope" to "list view IS mobile-friendly" |
| Effort | Update from 16-24h to 20-28h (3-5h list view added) |

### Spec `2026-05-16-admin-inbox-unified-build-spec.md`

| Section | Change |
|---|---|
| States table | Add `🟣 New lead` (purple) row |
| Priority ordering | Insert "new lead" between stalled and active bot |
| Data queries | Add Query 4: leads (new/engaged from `leads` table) |
| New endpoints | Add `POST /api/admin/leads/{id}/qualify` |
| Acceptance criteria | Add lead rendering item |

---

## Worker endpoint additions

### For inbox spec

```
POST /api/admin/leads/{id}/qualify
  → Sets leads.status = 'engaged'
  → Appends admin note to leads.notes (or guest_events)
  → Returns 200 OK
```

---

## Open questions for CC (decisions delegated to implementation)

1. **Inquiry tooltip text**: "Inquiry pendiente · puede o no convertir" vs "Solicitud tentativa" vs other? Pick the clearest.
2. **List view density on tablet vs desktop**: how many rows fit comfortably? Test and adjust.
3. **Blocked cell tooltip on Combinada-blocked vs host-blocked**: can we tell them apart with extra D1 query? If yes, show; if no, generic "blocked".
4. **New lead default time filter**: last 24h or last 7d? Mi voto 24h.

If CC has no Alex available, proceed with WC suggestions above.

---

## Sequence reminder

```
V6 prompt cutover ──► 100%
  ▼
admin/bookings Gantt + List view (this updated spec)
  ▼
admin/inbox unified (with new lead state added)
```

No change to overall sequence. Just spec contents updated.

---

**End of delta. CC reads both specs together.**
