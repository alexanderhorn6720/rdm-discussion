# Thread 87 — WC: Amendment to bookings spec (multi-inquiry overlap)

**Date**: 2026-05-16
**Author**: WC (with Alex)
**To**: CC-Bot
**Re**: Amendment to bookings/inbox DELTA — multi-inquiry handling
**Status**: 🟢 Amendment ready

---

## TL;DR

Alex caught a real edge case: multiple Beds24 inquiries can target SAME villa + SAME dates simultaneously. Original DELTA didn't handle visual overlap.

**Decision**: Three-vista split with clear conceptual boundaries.

Amendment appended to: `cc-instructions-bot/2026-05-16-admin-bookings-and-inbox-DELTA.md`

---

## The three-vista split

| View | Shows | Hides |
|---|---|---|
| **Gantt** | `confirmed` + `request` ONLY (solid bars) + mini-badge `📩N` per villa row | Inquiries as bars, leads without locked dates |
| **List** | Everything + new column `Conflict?` indicating date overlaps | — |
| **Inbox** | Leads (no locked dates), conversations, escalations | Bookings with no recent activity |

### Why

- Inquiries are NOT occupancy — they're pipeline
- Operational planning needs only confirmed/request
- Commercial pipeline managed by urgency + conflict (List)
- Mixing inquiries in Gantt gives false "fully booked" sense

## Gantt amendment

Mini-badge `📩N` in row header indicating N active inquiries for that villa:

```
RdM 📩3    [══Pérez(16)══]
Morenas    [══González(8)══]
Huerta 📩1 [══Daniela(8)══]
```

Click badge → side drawer (right side, ~400px) with inquiry list + actions per inquiry. No page navigation.

Optional "Include inquiries" toggle in status filter → renders stripes overlay (debug only, off by default).

## List view amendment

New `Conflict?` column:
- Confirmed: `—`
- Inquiry vs confirmed: `⚠ {surname} confirmed`
- Inquiry vs N inquiries: `⚠ {N} others`
- No conflict: `—`

Sortable by Conflict (conflicts first).

## Queries added

- Inquiry count per room within range (for badge)
- Conflict detection (overlap query) for List Conflict? column

## Effort estimate

Total still in 33-45h ballpark. Amendment adds +3-5h within range:
- Gantt + List + KV + inquiry styling + multi-inquiry: 22-30h
- /admin/inbox unchanged: 13-17h

## Sequence (unchanged)

```
V6 100% ──► /admin/bookings (with all amendments) ──► /admin/inbox
```

---

**WC standing by. CC reads original + delta + amendment together.**
— WC, 2026-05-16
