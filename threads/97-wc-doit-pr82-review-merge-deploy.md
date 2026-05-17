# 97 — WC: DoIt task — review + merge + deploy PR #82 (bookings UI)

**Date**: 2026-05-19
**Author**: WC
**To**: CC-Bot
**Re**: P1 priority — close PR #82 (already MERGEABLE)
**Mode**: DoIt (autonomous, halt on actual failure only)
**Status**: 🟢 Ready to execute

---

## TL;DR

PR #82 (`feat/admin-bookings-ui`) is OPEN + MERGEABLE per CC's pre-flight in thread/96. Spec compliant (threads 84b/86/87). 2860 lines. CC built it, tested locally before stop. Now: final walkthrough + tests + merge + verify deploy.

DoIt task structured per template v3.

---

## TASK

```
TASK: Review, merge, and verify deploy of PR #82 (admin-bookings-ui).
MODE: DoIt.

CONTEXT:
PR #82 status (per CC thread/96):
  Branch: feat/admin-bookings-ui
  Status: OPEN + MERGEABLE
  Scope: List view + Gantt + KPIs + inquiry drawer + Conflict column
  Lines: 2860 (10 files)
  Spec refs: threads 84b/86/87 in rdm-discussion

Repo: rdm-bot
Working dir: <USER_HOME>\rdm\dev\bot   (where <USER_HOME>=$env:USERPROFILE)

============================================================
PRE-FLIGHT (auto-execute, halt only on actual failure)
============================================================

1. Set-Location "$env:USERPROFILE\rdm\dev\bot"
   - Verify: $PWD path contains "Alexa\rdm\dev\bot"

2. git remote -v
   - origin must contain "rdm-bot.git" (not rincondelmar-bot)

3. git fetch origin
   - Should complete clean

4. gh pr view 82 --repo alexanderhorn6720/rdm-bot --json state,mergeable,headRefName,baseRefName
   - state: OPEN
   - mergeable: MERGEABLE
   - headRefName: feat/admin-bookings-ui
   - baseRefName: main

5. gh auth status
   - Logged in

6. (Informational) Check CF Pages auto-deploy setup:
   gh repo view alexanderhorn6720/rdm-bot --json defaultBranchRef
   - Just to confirm main is default branch (deploy trigger source)

============================================================
DELIVERABLES (in order — additive checks first, mutating last)
============================================================

PASO 1 — Code walkthrough (read-only, ~5 min)

Use absolute paths to inspect files in branch:
   git -C "$env:USERPROFILE\rdm\dev\bot" fetch origin feat/admin-bookings-ui
   git -C "$env:USERPROFILE\rdm\dev\bot" diff origin/main..origin/feat/admin-bookings-ui --stat

Read for sanity (NOT modify):
   - apps/web/src/pages/admin/bookings.astro
   - apps/web/src/components/admin/GanttView.tsx
   - apps/web/src/components/admin/BookingsView.tsx
   - apps/web/src/components/admin/bookings-kpis.ts
   - apps/web/src/pages/api/admin/bookings/inquiries.ts

Verify:
   - No leftover console.logs in production paths
   - No hardcoded secrets
   - No commented-out blocks
   - Tests included (apps/web/tests/bookings-kpis.test.ts)

If any RED FLAG: stop, report in this thread, do NOT merge.

PASO 2 — Local test run (additive, doesn't change repo state)

   git -C "$env:USERPROFILE\rdm\dev\bot" checkout feat/admin-bookings-ui
   cd "$env:USERPROFILE\rdm\dev\bot"
   pnpm install --frozen-lockfile
   pnpm test

Expected: tests pass for bookings-kpis at minimum.
If tests fail: stop, report, do NOT merge.

PASO 3 — Type check / lint (additive)

   pnpm typecheck 2>&1 | tail -30
   pnpm lint 2>&1 | tail -30

Allowed: lint warnings.
NOT allowed: type errors or lint errors.

PASO 4 — Build verification (additive)

   pnpm build
   
Expected: clean build, no errors.

PASO 5 — Merge PR #82 (MUTATING — point of no return)

If all 1-4 pass:
   git -C "$env:USERPROFILE\rdm\dev\bot" checkout main
   git -C "$env:USERPROFILE\rdm\dev\bot" pull origin main

   gh pr merge 82 --repo alexanderhorn6720/rdm-bot --squash --delete-branch

Use squash merge (not regular) — cleaner history for 2860-line PR.
Delete branch after merge.

PASO 6 — Verify deploy (informational, may be auto)

   gh repo view alexanderhorn6720/rdm-bot/deployments --json status,environment 2>&1 | head -30
   
   Or via CF dashboard URL (info only, not action):
   https://dash.cloudflare.com/?to=/:account/pages

Note: CF Pages auto-deploys main pushes. Should take 2-5 min to live.

PASO 7 — Smoke test live deploy

After ~5 min:
   curl -s -o /dev/null -w "%{http_code}" https://rincondelmar.club/admin/bookings
   
Expected: redirect to auth (200 → 302) or admin login page (200).
If 500/404: deploy issue, report.

============================================================
DEFAULTS (apply unless overridden)
============================================================

- Commit message format on merge: GitHub auto-generates from PR title + squash bodies
- File encoding: not applicable (no files generated)
- Git attribution: not applicable (merge commit attributed to Alex via gh)
- Squash merge over regular merge: use squash (cleaner history)
- Delete branch after merge: yes
- Force push: NEVER
- Skip CI: NEVER

============================================================
OUT OF SCOPE (NO HACER)
============================================================

- ❌ Don't modify any file in PR #82 (this is review + merge, NOT edit)
- ❌ Don't merge if any test fails
- ❌ Don't merge if type errors found
- ❌ Don't start /admin/inbox build after merge — P3, not now
- ❌ Don't touch welcome bug — P2, not now
- ❌ Don't update CC instructions docs
- ❌ Don't push from old paths C:\rincondelmar-*\
- ❌ Don't change branch protection rules
- ❌ Don't deploy worker-bot directly (CF Pages auto-handles)
- ❌ Don't touch rdm-platform repo

============================================================
EXTERNAL STATE check (informational only — DON'T act)
============================================================

Verify and report (no action):

- CF Pages connected to rdm-bot repo (deploys main automatically)
- Make scenarios that may reference admin/bookings endpoint (unlikely)
- Webhooks pointing to admin/bookings (none expected)
- IDE workspaces in old paths (may still be open, no action needed)
- Other CC sessions active in old paths C:\rincondelmar-* (informational)

============================================================
CRITERIO DE ÉXITO
============================================================

- All pre-flight checks pass
- Code walkthrough: no red flags
- pnpm test: green
- pnpm typecheck + lint: clean (warnings OK, errors NO)
- pnpm build: clean
- PR #82 merged via squash, branch deleted
- CF Pages deploy triggered automatically
- https://rincondelmar.club/admin/bookings responds (redirect to auth = OK)

============================================================
SI TE ATORAS
============================================================

- Tests fail: stop, report in this thread with stderr
- Type errors: stop, report with file:line of error
- Build fails: stop, report
- Merge conflicts (unexpected since MERGEABLE): stop, report
- CF deploy stalls >10 min: report, suggest manual trigger
- Pre-flight check 4 fails (PR no longer MERGEABLE): stop, report
- Anything else unexpected: stop, report

DO NOT attempt to fix code issues yourself in this task. Just report.

============================================================
REPORTAR AL FINAL (thread/98-cc-bot-pr82-merged.md)
============================================================

1. Pre-flight results (6/6 pass or which failed)
2. Walkthrough findings (red flags or clean)
3. Test results (pass/fail per suite)
4. Typecheck/lint results
5. Build result
6. Merge commit SHA + URL
7. Branch deletion confirmation
8. CF Pages deploy status + URL
9. Smoke test live response code
10. Any blocker for next task (P2 welcome bug or P3 inbox)
```

---

## Why this task is structured this way

- **Pre-flight = auto-verifiable**: 6 commands, halts on real failure (v3)
- **Order**: walkthrough → tests → typecheck → build → merge → deploy → smoke (all additive before merge, mutating last)
- **Absolute paths**: `$env:USERPROFILE\rdm\dev\bot` everywhere (v3 lesson)
- **No cwd checks**: rely on absolute paths instead (v3 lesson)
- **Defaults explicit**: squash merge, delete branch, no force push (v3)
- **External state check informational**: don't fix CF/Make/etc, just observe (v2)
- **Single concern**: review + merge + deploy + smoke. NOT bundled with P2/P3.

---

## What Alex/WC will do after CC reports thread/98

1. Verify deploy live in browser (Alex, 1 min)
2. Verify Gantt + List + KPIs render correctly with real data
3. Decision on P2 (welcome bug) or P3 (inbox build)
4. WC writes next DoIt task for chosen priority

---

**WC standing by. CC executes. Halt on actual failure only.**

— WC, 2026-05-19
