# Thread 86 — WC: Delta updates to /admin/bookings + /admin/inbox specs

**Date**: 2026-05-16
**Author**: WC (with Alex)
**To**: CC-Bot
**Re**: 4 refinements to bookings + inbox specs from Alex review
**Status**: 🟢 Delta ready

---

## TL;DR

Alex review introduced 4 refinements. Documented as delta, NOT rewrite. CC reads both specs together (original + delta).

Delta: `cc-instructions-bot/2026-05-16-admin-bookings-and-inbox-DELTA.md`

---

## The 4 refinements

### 1. List view (same route, toggle)

NOT `/admin/bookings2`. ADD `?view=list` toggle to `/admin/bookings`.

- Sortable table columns
- Mobile-friendly (Gantt doesn't work on phone)
- Same data, same queries, same auth
- +3-5h CC effort on top of Gantt
- Auto-default to list view on mobile

### 2. KV calendar cache for blocked cells

Skip "Combinada smart overlay" custom logic. Use existing KV `calendar:lookup` (refreshed every 2h from Beds24 `/inventory/rooms/calendar`).

- Beds24 already cascades `numAvail=0` to RdM + Morenas when Combinada booked (linked rooms)
- KV already has `num_avail` per `roomId × date`
- Frontend just reads the cache, no derivation needed
- Source of truth = Beds24
- Works for any block reason (Combinada, host manual, maintenance)
- Tooltip: "Bloqueado · sin reserva en esta villa" (don't claim reason)

### 3. Inquiries rendered differently from confirmed

Beds24 status types now distinguished visually:
- `confirmed`, `request` → solid bar, 100% opacity
- `inquiry` → diagonal stripes pattern, dashed border, 60% opacity (channel color unchanged)
- `black` (host-set hold) → gray pattern, no surname
- `cancelled`, `no_show` → strikethrough, hidden by default

Filter: "Confirmed only" default at month/quarter zoom; "Include inquiries" default at day/week zoom.

### 4. Leads belong in INBOX, NOT bookings

Leads without locked dates+property don't render in Gantt (no fixed cell to occupy).

Inbox spec gets new state:
- 🟣 **New lead** (purple) — `leads.status='new' OR 'engaged'`
- New worker endpoint: `POST /api/admin/leads/{id}/qualify`
- Inserted in priority order between "stalled" and "active bot"

---

## Effort impact

| Item | Original | Updated |
|---|---|---|
| `/admin/bookings` (Gantt + List + KV + inquiries) | 16-24h | 20-28h |
| `/admin/inbox` (+ lead state + 1 endpoint) | 12-16h | 13-17h |
| **Total** | 28-40h | 33-45h |

Bump is small — most additions are presentational, not data.

---

## Sequence (unchanged)

```
V6 100% cutover
  ▼
admin/bookings (Gantt + List + KV + inquiries) — PR A8.X
  ▼
admin/inbox (with 🟣 new lead) — PR A8.Y
```

---

## Files updated

- ✏️ `cc-instructions-bot/2026-05-16-admin-bookings-and-inbox-DELTA.md` (new, delta doc)
- Original specs untouched:
  - `cc-instructions-bot/2026-05-16-admin-bookings-gantt-build-spec.md`
  - `cc-instructions-bot/2026-05-16-admin-inbox-unified-build-spec.md`

CC reads original + delta together.

---

**WC standing by.**
— WC, 2026-05-16
