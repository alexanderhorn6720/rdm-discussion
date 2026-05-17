# 101 — WC: DoIt — /admin/bookings 3 fixes + apply autonomy config

**Date**: 2026-05-19
**Author**: WC
**To**: CC-Bot
**Re**: Alex feedback on `/admin/bookings` deploy live (post PR #82 merge)
**Mode**: DoIt
**Status**: 🟢 Ready to execute

---

## TL;DR

PR #82 merged + deployed. Alex tested in browser, gave 3 issues. Plus a bundled task: apply autonomy config (§4 of thread/98-wc) since CC is here anyway.

**Order**: autonomy config first (~5 min, quick win), then 3 bookings fixes (~30 min).

Total estimated: 40 min CC work, single sitting.

---

## §1 — Apply autonomy config (from thread/98-wc §4)

Per Alex confirmation: CC already created bot `.claude/settings.json` locally + workspace file. **This step verifies setup is complete + tests the 3 tiers.**

### Pre-flight

```powershell
Test-Path "$env:USERPROFILE\rdm\dev\bot\.claude\settings.json"  # → True
Test-Path "$env:USERPROFILE\rdm\rdm-workspace.code-workspace"   # → True
Test-Path "$env:USERPROFILE\rdm\dev\bot\.claude\settings.local.json"  # → False (no override)
```

If any False → CC re-runs §4 of thread/98-wc-cc-autonomy-config-and-workspace.

### Verify gitignore working

```powershell
cd "$env:USERPROFILE\rdm\dev\bot"
git status --short | Select-String "\.claude"
# Should return nothing (gitignored)
```

If `.claude/settings.json` appears in git status: STOP, report.

### Report

In thread/102 final report, confirm:
- bot/.claude/settings.json exists with N lines (paste first 10 lines for verification)
- workspace file exists
- git status clean re: .claude/

---

## §2 — Bookings fix #1: clarify channel breakdown in header

### Issue (Alex feedback)

"Faltan los bookings directos, nada mas veo los de airbnb."

### Root cause analysis (WC verified via D1 MCP)

```
Channel breakdown for rango 2026-04-17 → 2026-11-13:
- airbnb / booked:     16 bookings  ✅ visible in Gantt
- direct / booked:      1 booking   (arrival 2027-07-22, OUT OF RANGE)
- direct / cancelled:   7 bookings  (hidden by "Mostrar canceladas" OFF)
```

**NO es bug de pipeline**. Es percepción — Alex no ve breakdown.

### Fix

In the KPIs / header band, expand counter from:
```
23 bookings en rango  2026-04-17 → 2026-11-13
```

To something like:
```
23 bookings en rango  2026-04-17 → 2026-11-13
  16 Airbnb · 1 Direct · 7 Direct (canceladas, ocultas)
```

Or visually grouped per status:

```
23 bookings:  16 Airbnb activas  +  1 Direct activa  +  7 canceladas (ocultas)
```

WC voto: second format (mentions canceladas with hint). Reveals reality without forcing user to dig.

### Files affected

- `apps/web/src/components/admin/BookingsView.tsx` or similar (header rendering)
- Possibly `apps/web/src/components/admin/bookings-kpis.ts` (if breakdown logic lives there)
- Spec: thread/87 §amendment already mentioned multi-inquiry; this adds channel-aware

---

## §3 — Bookings fix #2: Gantt default view centers on TODAY

### Issue (Alex feedback)

"Al abrir, debe de estar en modo 'hoy', el dia de hoy, 17 de mayo deberia aparecer como primer dia del timeline (a la izquierda)"

### Current behavior

Vista actual: `start_date = 2026-04-17`, `end_date = 2026-06-15` (approx 60 days). Today is 2026-05-17 but Gantt opens 30 days before today.

### Fix

Default Gantt opening view:

```typescript
// Pseudocode
const today = new Date();  // ISO yyyy-mm-dd in local TZ
const startDate = today;   // exactly today, left edge
const endDate = addDays(today, 30);  // 30 day window default

// "Today" column visually highlighted
// Allow Prev/Next buttons to shift in 7-day or 30-day increments
```

Voto: `today = left edge` not `today = centered`. Reasons:
- Users care about future bookings (what's coming) not past (already happened)
- Past view always available via Prev button
- Left edge is "now" anchor — visual mental model "from now forward"

If `Week` view selected: 7 days starting today.
If `Month` view selected: 30 days starting today (or current calendar month? — needs decision).
If `Quarter` view selected: 90 days starting today.

**Alex confirms in feedback**: "today as left edge of timeline" — WC adopting this.

### "Today" column highlight

Even when scrolled to past dates via Prev button, the today column should be visually distinguished (e.g., subtle background tint, different border color).

### Files affected

- `apps/web/src/components/admin/GanttView.tsx` (date logic)
- `apps/web/src/components/admin/GanttView.css` (today column style)

---

## §4 — Bookings fix #3: Beds24 link format

### Issue (Alex feedback)

"El link a booking no funciona, debe ser asi por ejemplo:
https://beds24.com/control2.php?ajax=bookedit&id=85497876&tab=1"

### Current behavior

Whatever link the booking detail drawer / list view currently generates → doesn't open the Beds24 booking page.

### Fix

Use exact format:
```
https://beds24.com/control2.php?ajax=bookedit&id={beds24_booking_id}&tab=1
```

Where `{beds24_booking_id}` comes from D1 column `beds24_bookings.beds24_booking_id` (numeric, e.g., 86655644).

Apply in:
- Inquiry drawer "Open in Beds24" button
- List view per-booking action link
- Any other place a Beds24 deep-link is generated

### Files affected

- `apps/web/src/components/admin/BookingsView.tsx` (link rendering)
- Or wherever booking-detail-drawer is implemented
- Possibly a shared util: `apps/web/src/lib/beds24-links.ts` (create if doesn't exist for reusability)

### Testing

After fix, click any Beds24 link from `/admin/bookings`. Should open Beds24 admin panel directly on the booking. Test with `beds24_booking_id=86655644` (one of the AirBnB ones) and `86685323` (the direct booked one).

---

## §5 — Execution order

```
1. Verify autonomy config (~5 min)
2. Fix #3 (Beds24 link) — simplest, 5 min
3. Fix #2 (Gantt default today) — date logic, 10 min
4. Fix #1 (channel breakdown header) — UI design, 15 min
5. Local tests (pnpm test, typecheck, lint, build) — 5 min
6. Commit per fix (3 small commits, atomic)
7. Push to new branch fix/admin-bookings-feedback-3-issues
8. PR + merge via squash + delete branch
9. CF deploys auto
10. Smoke test
11. Report thread/102
```

============================================================
PRE-FLIGHT (auto-execute, halt only on actual failure)
============================================================

1. cd "$env:USERPROFILE\rdm\dev\bot"
2. git status --short  → clean
3. git fetch origin
4. git checkout main && git pull origin main
5. Test-Path "$env:USERPROFILE\rdm\dev\bot\.claude\settings.json"  → True
6. gh auth status  → logged in
7. Verify schema: column `beds24_booking_id` in D1 `beds24_bookings` table (already confirmed by WC via MCP)

============================================================
DELIVERABLES
============================================================

PASO 1 — Autonomy config verification (§1 above)

PASO 2 — Create branch
   git checkout -b fix/admin-bookings-feedback-3-issues

PASO 3 — Fix #3: Beds24 link helper
   Create `apps/web/src/lib/beds24-links.ts` if doesn't exist:
   ```typescript
   export function beds24BookingUrl(beds24BookingId: number | string): string {
     return `https://beds24.com/control2.php?ajax=bookedit&id=${beds24BookingId}&tab=1`;
   }
   ```
   
   Replace all current Beds24 link generation with calls to this helper.

PASO 4 — Fix #2: Gantt default today
   In GanttView.tsx: default `start_date = today` (local timezone Acapulco UTC-6).
   Add today column visual highlight.
   Test all 4 view modes (Day/Week/Month/Quarter) behave consistently with today as left edge.

PASO 5 — Fix #1: Channel breakdown header
   In bookings header / KPIs section, expand counter to show channel+status breakdown:
   "23 bookings:  16 Airbnb activas  +  1 Direct activa  +  7 canceladas (ocultas)"
   
   Where:
   - airbnb activa = channel=airbnb AND status=booked
   - direct activa = channel=direct AND status=booked
   - canceladas (ocultas) = status=cancelled AND show_cancelled=false
   
   Make "canceladas (ocultas)" text/badge clickable → toggles "Mostrar canceladas" checkbox.

PASO 6 — Verification chain
   pnpm typecheck   → 0 errors
   pnpm lint        → warnings OK, no new errors
   pnpm test        → still 788/788 green (no test changes expected)
   pnpm build       → clean

PASO 7 — Commits (atomic per fix)
   git add apps/web/src/lib/beds24-links.ts apps/web/src/components/admin/BookingsView.tsx (and other affected)
   git commit -m "fix(admin/bookings): Beds24 deep-link format correct
   
   Format: https://beds24.com/control2.php?ajax=bookedit&id=<id>&tab=1
   Helper: apps/web/src/lib/beds24-links.ts (reusable)
   
   Per Alex feedback after PR #82 deploy."
   
   git commit (Gantt today default)...
   git commit (channel breakdown)...

PASO 8 — Push + PR
   git push origin fix/admin-bookings-feedback-3-issues
   gh pr create --title "fix(admin/bookings): 3 issues from Alex feedback (Beds24 link, today default, channel breakdown)" \
                --body "Per thread/101 in rdm-discussion.
   
   3 fixes:
   1. Beds24 deep-link format corrected
   2. Gantt opens with today as left-edge column
   3. Header shows channel+status breakdown (reveals direct + cancelled distinction)
   
   Refs: thread/101"
   
   gh pr merge <NUMBER> --squash --delete-branch

PASO 9 — Deploy + smoke
   Wait ~5 min CF Pages.
   curl -s -o /dev/null -w "%{http_code}" https://rincondelmar.club/admin/bookings  → 200/302
   Browser test: login, see today as left edge, click Beds24 link, see breakdown header.

============================================================
DEFAULTS
============================================================

- Commit format: Conventional Commits (fix: prefix per atomic commit)
- Encoding: UTF-8 file contents
- Git attribution: inherit from local config
- Squash merge: yes, delete branch after merge
- Branch name: fix/admin-bookings-feedback-3-issues
- 3 atomic commits before merge (better history for future debugging)

============================================================
OUT OF SCOPE (NO HACER)
============================================================

- ❌ Don't expand Gantt features beyond these 3 fixes
- ❌ Don't refactor BookingsView.tsx beyond what's needed
- ❌ Don't add tests for these fixes (visual changes; existing test suite stays as-is)
- ❌ Don't touch /admin/inbox build (separate P3 work)
- ❌ Don't investigate welcome bug (separate P2 work)
- ❌ Don't fix lint warnings unrelated to these 3 changes
- ❌ Don't touch rdm-platform repo

============================================================
EXTERNAL STATE (informational only)
============================================================

- Direct booked bookings currently in DB: 1 (id 86685323, arrival 2027-07-22, room 637063 Huerta)
- Direct cancelled: 7 (Jun 2026 + Aug 2026)
- Airbnb booked: 16
- Check that fix #1 (channel breakdown) accurately reflects these numbers after deploy

============================================================
CRITERIO DE ÉXITO
============================================================

- Beds24 link format matches `https://beds24.com/control2.php?ajax=bookedit&id=<beds24_booking_id>&tab=1`
- Gantt opens with today as leftmost visible column (verified in browser by Alex)
- Header shows channel+status breakdown explaining the 23 bookings
- "Mostrar canceladas" toggle visible and clickable
- 3 atomic commits in branch
- PR created, reviewed, merged, branch deleted
- CF Pages auto-deploy succeeded
- /admin/bookings smoke test returns 200/302
- Alex confirms visual fixes in browser (after report)

============================================================
SI TE ATORAS
============================================================

- Autonomy config files missing: report, re-run thread/98-wc §4
- Typecheck breaks: STOP, report with stderr
- Tests fail: STOP, report (no test changes expected)
- Gantt logic conflict with existing date handling: STOP, report
- Beds24 link helper not reusable across components: ask WC
- Anything unexpected: STOP, report

============================================================
REPORTAR AL FINAL (thread/102-cc-bot-admin-bookings-feedback-fixed.md)
============================================================

1. Pre-flight 7/7 pass
2. Autonomy config verified (bot/.claude/settings.json contents head -10 lines, workspace file exists, gitignore working)
3. Fix #3 (Beds24 link) — files changed + helper code snippet
4. Fix #2 (Gantt today) — files changed + before/after pseudocode
5. Fix #1 (channel breakdown) — files changed + header text rendering snippet
6. Verification chain (typecheck/lint/test/build)
7. 3 commit SHAs
8. PR # + merge commit SHA + URL
9. Branch deleted confirmation
10. CF Pages deploy URL
11. Smoke test response code
12. Status for next task: ready for P2 (welcome bug) or P3 (inbox build) or other?

---

## What Alex does after thread/102

1. Open browser, test `/admin/bookings`:
   - Verify today as left edge
   - Click any Beds24 link, see Beds24 admin panel open
   - Verify header shows channel breakdown clearly
2. If all 3 visual fixes work: confirm in next message
3. Decide P2 or P3 next

---

**WC standing by. CC executes 40 min single sitting.**

— WC, 2026-05-19
