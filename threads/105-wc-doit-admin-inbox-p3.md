# 105 — WC: DoIt — P3 /admin/inbox unified build

**Date**: 2026-05-19
**Author**: WC
**To**: CC-Bot
**Re**: P3 priority — build `/admin/inbox` per spec from thread/85 + cc-instructions
**Mode**: DoIt
**Status**: 🟢 Ready (after thread/104 backfill verified)
**Estimated effort**: 12-16h CC (single PR)

---

## TL;DR

P3 priority confirmed by Alex. Build `/admin/inbox` as unified operational view consolidating 3 signal sources. Read-only MVP. Spec self-contained — most detail lives in `cc-instructions-bot/2026-05-16-admin-inbox-unified-build-spec.md`.

Sequence prerequisites already met:
- ✅ V6 100% canary (telemetry green)
- ✅ /admin/bookings shipped (PR #82, #83, #84 all merged)
- ✅ Backfill complete (Jovany + others visible)

Now P3 starts.

---

## §1 — Why now

Alex + Karina currently track guest interactions across 3 separate panels:
- WhatsApp (ManyChat dashboard)
- Beds24 messages (Beds24 panel)
- Telegram notifications (escalation alerts)

No consolidated "what needs my attention NOW" view. D1 already has all 3 data sources — just needs UI.

---

## §2 — Spec reference

**Primary spec**: `cc-instructions-bot/2026-05-16-admin-inbox-unified-build-spec.md` (456 lines)

Read this FIRST and completely. Self-contained. Has:
- Visual design (layout + per-row formats)
- 7 state color-coded enum (Escalated/Paused/Stalled/Active/Beds24unread/Critical/Resolved)
- Priority sort order
- Filters (type, status, channel, time, search)
- Hover actions
- 3 new worker endpoints required
- D1 queries
- Test coverage requirements

**Supporting context**:
- thread/85-wc-admin-inbox-unified-spec.md (TL;DR + scope)
- thread/86-wc-bookings-inbox-delta-list-view-kv-inquiries.md (cross-cutting concerns with /admin/bookings)

---

## §3 — What's IN scope

| Item | Source |
|---|---|
| 7 states color-coded | thread/85 + build spec §Visual |
| Priority sort order | build spec |
| Filters: type, status, channel, time, search | build spec |
| Hover actions: open conv, mark responded, resolve, unpause, extend pause, open Beds24, trigger escalation | build spec |
| Top-of-page summary ("N need attention now") | thread/85 |
| 3 new worker endpoints | build spec |
| Readonly user support | per /admin/conv PR A7.7.4 precedent |
| Click row → jumps to /admin/conv | thread/85 |

---

## §4 — What's OUT of scope (Phase 2 later)

- ❌ Reply integration from inbox (WhatsApp send) — Phase 2 after 2 weeks usage
- ❌ Real-time updates — page refresh fine MVP
- ❌ Bulk actions
- ❌ Notifications (browser push)
- ❌ Mobile design (tablet+ only)
- ❌ Customizable views / SLA timers
- ❌ AI-assisted summary or routing

---

## §5 — TASK

```
TASK: Build /admin/inbox unified inbox per spec.
MODE: DoIt.
Branch: feat/admin-inbox-unified

CONTEXT:
P3 priority. Prerequisites met (V6 100%, /admin/bookings shipped, 
backfill done). Spec self-contained in cc-instructions-bot/.

============================================================
PRE-FLIGHT (auto-execute, halt only on actual failure)
============================================================

1. cd "$env:USERPROFILE\rdm\dev\bot"
2. git status --short → clean
3. git fetch origin
4. git checkout main && git pull origin main
5. gh auth status → logged in
6. Read cc-instructions-bot/2026-05-16-admin-inbox-unified-build-spec.md COMPLETO
7. Verify D1 tables exist:
   SELECT name FROM sqlite_master WHERE type='table' 
     AND name IN ('conversations', 'bot_messages_inbox', 'human_handoff_log');
   → Expect 3 rows
8. Check existing endpoints in apps/worker-bot/src/ for patterns to reuse
9. Check /admin/conv implementation as pattern reference (apps/web/src/pages/admin/conv*)
10. Test-Path "$env:USERPROFILE\rdm\dev\bot\apps\web\src\pages\admin\index.astro" → True

============================================================
DELIVERABLES (per spec — execute in order)
============================================================

PASO 1 — Create branch
   git checkout -b feat/admin-inbox-unified

PASO 2 — Worker endpoints (3 new)
Per spec §Worker endpoints, implement:
- POST /admin/inbox/mark-handoff-responded  (handoff → resolved)
- POST /admin/inbox/resolve-conv             (conv → resolved status)
- POST /admin/inbox/trigger-escalation       (conv → escalation alert)

All 3 require:
- Auth: isAdmin OR isAdminReadonly (read-only blocks destructive)
- Idempotent (mark twice = same result)
- Telemetry: counter event per call
- Test coverage per endpoint

Files:
- apps/worker-bot/src/admin-inbox.ts (new)
- apps/worker-bot/tests/admin-inbox.test.ts (new)
- Wire into apps/worker-bot/src/index.ts router

PASO 3 — D1 query layer
Per spec §Data sources, build unified query joining 3 sources:
- conversations (bot sessions, status, last_activity_at, paused_until)
- bot_messages_inbox (Beds24 unread guest msgs)
- human_handoff_log (open escalations)

Output: single sorted result by priority order. Server-side filter + pagination.

Files:
- apps/web/src/lib/inbox-query.ts (new)
- apps/web/src/lib/inbox-query.test.ts (new)

Pattern: reuse approach from apps/web/src/lib/bookings-query.ts (if exists from /admin/bookings).

PASO 4 — UI page
Per spec §Visual design, build /admin/inbox page:
- Route: apps/web/src/pages/admin/inbox.astro (server-rendered)
- React island for filters + interactivity: apps/web/src/components/admin/InboxView.tsx
- Auth gating: isAdmin OR isAdminReadonly

Components needed:
- InboxView.tsx (top-level, filters + list)
- InboxRow.tsx (single row, state color, hover actions)
- InboxFilters.tsx (filter bar)
- InboxSummary.tsx (top "N need attention now")

Files (estimated):
- apps/web/src/pages/admin/inbox.astro
- apps/web/src/components/admin/InboxView.tsx
- apps/web/src/components/admin/InboxRow.tsx
- apps/web/src/components/admin/InboxFilters.tsx
- apps/web/src/components/admin/InboxSummary.tsx
- apps/web/src/components/admin/InboxView.test.tsx

PASO 5 — Add to /admin/index
Update apps/web/src/pages/admin/index.astro cards.

Per spec §Route + access: place above bot-metrics, below airbnb-content.

PASO 6 — Verification chain
   pnpm typecheck   → 0 errors
   pnpm lint        → no new errors
   pnpm test        → all green (existing + new)
   pnpm build       → clean

PASO 7 — Commits (atomic per layer, ~3-4 commits)

Suggested split:
1. feat(worker): admin-inbox 3 endpoints + tests
2. feat(web): inbox-query unified D1 layer + tests
3. feat(admin): /admin/inbox UI (page + components + tests)
4. chore(admin): wire inbox card into /admin/index

PASO 8 — Push + PR + merge

   git push origin feat/admin-inbox-unified
   gh pr create --title "feat(admin): /admin/inbox unified inbox MVP" \
                --body "Per thread/105 + cc-instructions-bot/2026-05-16-admin-inbox-unified-build-spec.md
                
   Consolidates 3 signal sources (bot conv, Beds24 msgs, escalations) into 
   single operational view. Read-only MVP. Click row → /admin/conv for actions.
   
   ~12-16h effort. Refs: thread/85, thread/86."
   
   gh pr merge <NUMBER> --squash --delete-branch

PASO 9 — Deploy
- apps/web: CF Pages auto-deploys main push
- apps/worker-bot: wrangler deploy (Y/N expected per autonomy ask tier)

PASO 10 — Smoke test
- curl -s -o /dev/null -w "%{http_code}" https://rincondelmar.club/admin/inbox → 200/302
- Open browser, login as admin
- Verify:
  * Top summary count matches reality
  * Filters render
  * At least one row per source type if data exists
  * Click row → jumps to /admin/conv
  * Hover actions render (don't need to test destructive actions in smoke)

============================================================
DEFAULTS
============================================================

- Commit format: Conventional Commits (feat: prefix)
- Encoding: UTF-8 file contents
- 3-4 atomic commits (worker / data / UI / wiring)
- Squash merge with --delete-branch
- Branch: feat/admin-inbox-unified
- Tests required per layer
- Readonly user support inherited from /admin/conv pattern

============================================================
OUT OF SCOPE (NO HACER)
============================================================

- ❌ Don't build reply integration (Phase 2)
- ❌ Don't add real-time updates (page refresh OK)
- ❌ Don't add bulk actions
- ❌ Don't add browser notifications
- ❌ Don't optimize for mobile (tablet+ scope MVP)
- ❌ Don't add SLA timers or custom views
- ❌ Don't refactor /admin/conv (only link to it)
- ❌ Don't modify Beds24 polling logic
- ❌ Don't modify webhook handler
- ❌ Don't touch rdm-platform repo

============================================================
EXTERNAL STATE (informational only)
============================================================

- D1 tables conversations / bot_messages_inbox / human_handoff_log already populated
- /admin/conv pattern available as reference (auth, layout, components)
- isAdmin / isAdminReadonly helpers exist (from /admin/conv)
- React islands pattern established in /admin/bookings PR #82
- Beds24 polling cron runs every N min populating bot_messages_inbox

Verify (don't act):
- Existing CC sessions parallel
- Make scenarios with URLs (unlikely to reference /admin/inbox)
- CF Pages deploy pipeline auto

============================================================
CRITERIO DE ÉXITO
============================================================

- 3 worker endpoints functional with tests
- Unified query renders 3 source types with correct priority sort
- /admin/inbox page renders for admin user
- Readonly user sees same view, destructive actions disabled
- All filters work (type, status, channel, time, search)
- Top summary count accurate
- Click row jumps to /admin/conv with correct subscriber/booking ID
- Hover actions present (open conv, mark responded, resolve, etc.)
- pnpm test green
- 3-4 atomic commits squash-merged
- Worker deployed
- /admin/inbox smoke test 200/302
- Alex verifies in browser

============================================================
SI TE ATORAS
============================================================

- Spec ambiguous on a state color/icon: choose sensibly, note in PR description for review
- Performance issue with unified query: add indexes, document in PR
- Auth helper missing for readonly: STOP, report (may need refactor of existing)
- Tests fail unexpectedly: STOP, report stderr
- Type errors: STOP, report file:line
- Worker deploy fails: STOP, report
- Beds24 messages inbox empty (cron not running): note in report, don't block deploy
- Anything unexpected: STOP, report

============================================================
REPORTAR AL FINAL (thread/106-cc-bot-admin-inbox-complete.md)
============================================================

1. Pre-flight 10/10 pass
2. Files created (paths + line counts)
3. 3 worker endpoints (paths + test coverage %)
4. Unified query (lines, indexes used, performance notes)
5. UI components (4-5 components + line counts)
6. Test results (typecheck/lint/test/build)
7. 3-4 commits SHAs + PR # + merge SHA
8. Deploy: web (auto via CF Pages) + worker (wrangler deploy result)
9. Smoke test response code
10. Real data observed (rows per source: N conv, N Beds24, N escalations)
11. Any spec ambiguities resolved (with rationale)
12. Status: ready for P2 welcome bug or other priority?
```

---

## §6 — What Alex does after thread/106

1. Open /admin/inbox
2. Verify 3 source types render
3. Test filter combinations
4. Click a row, verify jump to /admin/conv works
5. Hover row, verify actions appear
6. Try as admin-readonly user (should see same view, destructive disabled)
7. Decide next priority

---

## §7 — After /admin/inbox lands

Pending priorities remaining:
- **P2 welcome auto-send bug** (shared root cause with beds24 normalize gap)
- **FAQ curation** 174 → 50-80 entries (Karina + Alex)
- **Old paths cleanup** C:\rincondelmar-*\ (after parallel sessions die)
- **Phase 2 inbox**: reply integration, bulk actions (2+ weeks usage data first)

WC voto post-inbox: **P2 welcome bug** (still warm context from backfill investigation).

---

**WC standing by. CC executes 12-16h, possibly split across sittings.**

— WC, 2026-05-19
