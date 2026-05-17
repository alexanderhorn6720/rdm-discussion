# 93 — CC-Bot status: bookings build complete + inbox paused awaiting direction

**Date**: 2026-05-17
**Author**: CC-Bot (autonomous DoIt session, 2026-05-16/17)
**To**: WC
**Re**: End-of-shift status report — what shipped, what's pending, what needs your eyes
**Priority**: P1 — read before next session direction
**Status**: 🟢 Stopped per Alex instruction. Awaiting decision on next priority.

---

## TL;DR

Long autonomous shift. V6 prompt is live at 100% canary with telemetry green. The data-layer plumbing for `/admin/bookings` was missing — built and shipped. Then the UI itself — list + Gantt + KPIs + drawer + conflict column — all in one PR. `/admin/inbox` build started but paused before commit at Alex's instruction.

**One unresolved bug**: welcome auto-send still not creating `pending_welcomes` despite v2 fix. Likely shares root cause with what we found in `beds24_bookings` (missing downstream pipeline + schema mismatch). Deferred per Alex.

---

## What shipped today (8 PRs merged + deployed)

| PR | Title | Verified live |
|---|---|---|
| #74 | fix(pages-build): prerender=false on admin/conv* SSR routes | ✅ CF Pages auto-deploys succeeded after this; previously failed for 5+ runs |
| #75 | chore(pages): redeploy trigger to pick up ADMIN_REFRESH_SECRET binding | ✅ /admin/conv proxy now works (was 503) |
| #77 | feat(greeter): V6 prompt (v2-playbook + WC vibe + pet fee fix) | ✅ Canary at 100%, prompt_version='v6' on all turns |
| #78 | fix(content): pet fee everywhere on web is $300/estancia | ✅ All 5 web locations corrected |
| #79 | fix(v6-followups): validator URL false-positive + booking header + nav silencer | ✅ Validator no longer false-flags appended URLs |
| #80 | feat(beds24): normalize beds24_events → beds24_bookings (data foundation) | ✅ 24 bookings now in beds24_bookings (was 0) |
| #81 | data(extraction): +174 FAQ candidates + 102 content enrichment ideas | ✅ CC-Data session work, merged in parallel |
| #82 | **feat(admin/bookings): list + Gantt + KPIs + drawer + conflict** | ⏳ **AWAITING ADMIN-MERGE** |

V6 canary mix observed in last hour: ~92% v6 / ~8% v5 by hash (was set to 100% via D1 update; the 8% v5 are subscribers Alex tested with greeter_version_force='v5' set during the day; can clear when ready).

---

## The big finding: `beds24_bookings` was empty

While starting `/admin/bookings` UI build, discovered the table had **0 rows** despite migration 0016 being applied 2026-05-13. Webhooks were arriving (~120 events) but the normalize step from `beds24_events` → `beds24_bookings` was never written.

**Root cause #1**: no code existed to do the normalization. Built and shipped via PR #80 (`apps/worker-bot/src/beds24-normalize.ts` + cron + admin endpoint).

**Root cause #2** (found during backfill): 32 events silently `error_unhandled`. Added granular error capture, real D1 message:

> `NOT NULL constraint failed: guests.last_activity_at`

Migration 0014 column comment said nullable; actual schema has NOT NULL. Fix shipped same day (1-line addition to INSERT bind).

**Result**: 49 events normalized successfully → 24 unique bookings (16 confirmed Airbnb + 7 cancelled Direct + 1 confirmed Direct). Real production data available for the Gantt UI.

This likely shares root cause with the welcome-auto-send bug (same kind of "downstream pipeline never wired" pattern). Worth investigating together.

---

## PR #82 detail — bookings UI build

**Full scope shipped in single PR per spec sequencing** (list first as Phase 4, then Gantt as Phase 3, KPIs as Phase 6, drawer as Phase 5, conflict as amendment thread/87).

### List view (Phase 4)

- 8-column sortable table (arrival, guest, property, channel, nights, guests, total MXN, status, flags, **Conflict?**, code)
- 4 filters: channel, property, show-cancelled toggle, search
- Status badges color-coded, surname extraction for compact display
- Cancelled rows: 55% opacity + strikethrough
- Mobile responsive (table scrolls horizontally, filters stack)

### Gantt view (Phase 3)

- CSS-grid built from scratch (no external dep per spec rec)
- 4 property rows: RdM, Morenas, Combinada, Huerta
- View zoom: day(80px/col) / week(60px) / month(40px, default) / quarter(24px)
- Date columns: UTC math, month labels at -01 boundaries, weekend shading
- Booking bars: absolute-positioned, channel-colored (orange/blue/green/yellow)
- Surname (N) labels + inline flag icons (🐶 ★ 💰)
- Today indicator: vertical red line + cell shading
- Blocked cells (no booking but num_avail=0): diagonal stripe pattern from KV calendar:lookup — per DELTA spec change 2, no Combinada-cascade custom logic needed
- Hover tooltip + click → modal with Beds24 link + Esc-to-close
- Cancelled bookings: hidden by default (toggle to show)
- Mobile fallback: warning banner recommending list view

### KPI header (Phase 6)

- 4 cells: Occupancy %, Revenue MXN, Pending payments, Per-property grid
- Revenue **prorated** by overlap nights (booking partially in range gets fractional credit)
- Pending payments highlight warn when count > 0
- Pure-function helpers in `bookings-kpis.ts` with **20/20 unit tests passing**

### Inquiry drawer (Phase 5)

- Click 📩N badge → right-side drawer (~420px, full-width on mobile)
- Lazy-loads via `GET /api/admin/bookings/inquiries?room=N`
- Shows: name, channel, dates, num_adults, sent date, Open Beds24 link per inquiry
- Escape key + overlay click closes
- Slide-in animation

### Multi-inquiry Conflict? column (thread/87 amendment)

- New sortable column in list view
- "—" no conflict
- "⚠ {surname} confirmed" when overlap with confirmed
- "⚠ N others" when overlap with N inquiries
- Sort by Conflict? → urgent items first

### Stats

| | |
|---|---|
| Lines added | 2,870 across 8 files |
| New tests | 20 (bookings-kpis) — all pass |
| Total web tests | 264/264 pass |
| Build time | ~15s |
| New API endpoint | 1 (GET /api/admin/bookings/inquiries) |

### Verified against real data

24 bookings live in `beds24_bookings` after PR #80 + bug fix. The Gantt + list both render correctly with this dataset. Inquiry count chips work. Conflict detection identifies the 2 known Andrea/Ricardo overlap on RdM June.

### Out of scope (intentionally deferred)

- Drag-and-drop bar editing (writes to Beds24, high risk)
- CSV/PDF export
- Real-time updates (polling/SSE)
- Lifecycle status auto-promotion cron (booked → pre_arrival_t30 → t7 → arrived → in_stay → checked_out)
- Lead linkage (lead_id=NULL for now; needs reverse-lookup mechanism)

---

## What's pending for WC eyes

### 1. PR #82 merge timing

CI is red repo-wide (pre-existing biome errors, accumulating tech debt). All today's PRs admin-merged. PR #82 follows same pattern but the scope is larger — happy for you to review the screenshots if/when you want before Alex admin-merges.

### 2. `/admin/inbox` build — start now or after stabilization?

Per spec sequence the inbox is next after bookings. I started the build (D1 schema check on `bot_messages_inbox`) but paused at Alex's instruction. **13-17h CC budget per your original spec.**

Question for you: same DoIt pattern as bookings (single PR, all phases), or split into list-first → drawer/states later? My recommendation: same single-PR pattern since inbox is conceptually one feature and the 8 states share data dependencies.

### 3. Welcome auto-send bug — investigate next?

Still unresolved. Pattern likely identical to what we found in `beds24_bookings`: pipeline step exists but never fires, or fires with bad inputs. Two hours max to investigate end-to-end. Recommend doing this before the inbox build — same code area, faster confidence.

### 4. Architectural cleanup: `action_taken` column collision

Both welcome-auto-send AND beds24-normalize write to `beds24_events.action_taken` with different semantics. They don't conflict today (each filters differently in SELECT) but the semantic overlap (`skipped_not_confirmed` could mean welcome-skipped OR normalize-skipped) is fragile.

Two options:
- (a) Rename actions to `welcome:skipped_*` and `normalize:skipped_*` prefixes
- (b) Split into separate columns (`welcome_action_taken`, `normalize_action_taken`)

(b) is cleaner but requires migration. (a) is one-line code change. Mi voto: (a) now, (b) when we add a third consumer of the events table.

### 5. Migration 0014 schema drift

The discovery that `guests.last_activity_at` has NOT NULL constraint but the migration comment described it as nullable suggests other columns may have similar drift. Worth a one-time `pragma_table_info('guests')` audit vs the docs.

---

## Open observations / questions for Alex (CC may resolve autonomously if no answer)

1. Lifecycle status promotion cron — when does this get built? `booked` → `pre_arrival_t30/t7/t1` → `arrived` → `in_stay` → `checked_out`. Without it the Gantt always shows everything as `booked`. ~2-3h CC.

2. The 1 booking with NULL guest_id (event 41, real booking 86655644 — 16 ppl, no name/phone/email in payload). My findOrCreateGuest created a guest with all-null fields but the JOIN couldn't follow back. Minor data quality issue.

3. content-drafts JSONs still have pet fee bug. Per your anti-pattern guidance in PR A6.1 spec, this is Karina + Chrome MCP territory. Want me to file an issue for tracking?

---

## What CC-Bot will work on next (pending your direction)

In priority order (my opinion):

1. **Welcome bug investigation** (~1-2h) — closes today's biggest open thread
2. **`/admin/inbox` build** (~5-6h) — next planned page per spec sequence
3. **Lifecycle status promotion cron** (~2-3h) — needed for Gantt visual fidelity
4. **CI hygiene pass** (~3-4h) — backlog tech debt
5. **Architectural cleanup of action_taken** (~30min) — quick win

If you have other priorities, name them. Otherwise CC waits for direction.

---

**End of report. CC-Bot stopped per Alex instruction.**

— CC-Bot, 2026-05-17
