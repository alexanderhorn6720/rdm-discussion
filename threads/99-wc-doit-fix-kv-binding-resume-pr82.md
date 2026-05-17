# 99 — WC: DoIt — fix KV_KNOWLEDGE binding (Option B) + resume PR #82

**Date**: 2026-05-19
**Author**: WC
**To**: CC-Bot
**Re**: Decision on PR #82 halt — Option B selected
**Mode**: DoIt
**Status**: 🟢 Decision made. Execute.

---

## Decision

WC selected **Option B** from thread/98-cc-bot-pr82-halted.

Rationale (brain mode):

The Gantt spec (thread/86 DELTA, thread/87 amendment) explicitly uses KV `calendar:lookup` for blocked cells rendering. The whole purpose of using KV (vs derivation logic) is to leverage Beds24's linked-room cascade — when Combinada is booked, RdM and Morenas have `numAvail=0` automatically.

Option A would unblock typecheck but break the feature at runtime (graceful degrade = invisible blocked cells). That's worse than not shipping — UI looks fine but doesn't show the actual blocking state.

Option B is small (~10 min) and ships the feature as specified.

---

## TASK

```
TASK: Fix KV_KNOWLEDGE wiring in apps/web + resume PR #82 merge.
MODE: DoIt.

CONTEXT:
PR #82 halted at PASO 3 of thread/97 task due to typecheck errors:
  apps/web/src/pages/admin/bookings.astro:122,123 
  → 'KV_KNOWLEDGE' does not exist on type 'Env'

Root cause: PR #82 is first web-app reference to KV_KNOWLEDGE binding.
  - apps/web/src/env.d.ts doesn't declare it
  - apps/web/wrangler.toml doesn't bind it

The same KV namespace already exists and is bound to apps/worker-bot.
Need to:
  1. Add type declaration to apps/web/src/env.d.ts
  2. Add binding to apps/web/wrangler.toml (same namespace ID as worker-bot)

Branch: feat/admin-bookings-ui (already exists, the same branch from PR #82)
Repo: rdm-bot (located at $env:USERPROFILE\rdm\dev\bot)

============================================================
PRE-FLIGHT (auto-execute, halt only on real failure)
============================================================

1. Set-Location "$env:USERPROFILE\rdm\dev\bot"
   - Verify cwd contains "Alexa\rdm\dev\bot"

2. git status --short
   - Should be clean (CC reported workdir clean in thread/98-cc-bot)

3. git fetch origin
   - Should complete clean

4. git checkout feat/admin-bookings-ui
   - Switch to the PR branch
   - git pull origin feat/admin-bookings-ui (in case anything new)

5. Read apps/worker-bot/wrangler.toml
   - Find the [[kv_namespaces]] block with binding="KV_KNOWLEDGE"
   - Extract the id = "..." value
   - Capture this ID for step 2 of deliverables (we'll reuse same namespace)

6. Read apps/web/wrangler.toml current state
   - Verify [[kv_namespaces]] either doesn't exist or doesn't include KV_KNOWLEDGE

7. Read apps/web/src/env.d.ts current state
   - Verify KV_KNOWLEDGE is NOT in Env interface

============================================================
DELIVERABLES (additive first, mutating second per template v3)
============================================================

PASO 1 — ADD type declaration (additive, no runtime impact)

Edit apps/web/src/env.d.ts:
  In the Env interface, add:
    KV_KNOWLEDGE?: KVNamespace;
  
  Note the `?` — make it optional. Reasons:
  - Matches the existing `if (env.KV_KNOWLEDGE)` runtime guard in bookings.astro
  - Allows local dev without binding
  - Type-safe even if wrangler.toml change is reverted

Verify after edit:
  pnpm typecheck 2>&1 | Select-String "KV_KNOWLEDGE"
  - Should return nothing (error resolved)

PASO 2 — ADD wrangler.toml binding (mutating, enables runtime)

Edit apps/web/wrangler.toml:
  Add [[kv_namespaces]] block:
    [[kv_namespaces]]
    binding = "KV_KNOWLEDGE"
    id = "<NAMESPACE_ID from worker-bot wrangler.toml>"
  
  Use the SAME id as worker-bot (single source of truth).
  
  If apps/web/wrangler.toml has no [[kv_namespaces]] section yet, 
  this becomes the first one. If it has others, add as additional 
  block, don't replace.

Verify after edit:
  Get-Content apps/web/wrangler.toml | Select-String "KV_KNOWLEDGE"
  - Should return the new binding line

PASO 3 — Run full verification chain (same as thread/97)

  pnpm typecheck
  - Expect: 0 errors

  pnpm lint
  - Allowed: warnings (already noted as noisy)
  - NOT allowed: new errors introduced

  pnpm test
  - Should still pass 788/788 (no test changes)

  pnpm build
  - Should complete clean

If any of these fail: STOP, report in new thread, do NOT commit.

PASO 4 — Commit fix to feat/admin-bookings-ui

  git add apps/web/src/env.d.ts apps/web/wrangler.toml
  git commit -m "fix(admin/bookings): wire KV_KNOWLEDGE binding to apps/web

PR #82 was missing the binding. The Env interface didn't declare it
and apps/web/wrangler.toml didn't bind it, even though admin/bookings.astro
uses it (with graceful degrade guard) for the Gantt calendar:lookup
cache.

Same KV namespace as worker-bot — single source of truth, no duplication.

Resolves typecheck errors that halted PR #82 merge (thread/98-cc-bot)."

PASO 5 — Push fix to same branch

  git push origin feat/admin-bookings-ui
  
  Note: this is push to feature branch, NOT main. Should auto-approve
  per settings.json `ask` rule — Y/N prompt once per session.

PASO 6 — Re-run merge sequence (resume thread/97)

After push:
  - gh pr view 82 --repo alexanderhorn6720/rdm-bot --json state,mergeable
  - Expect: OPEN + MERGEABLE
  - Wait for GitHub CI if running (~30 sec to 2 min)

If mergeable confirmed:
  git -C "$env:USERPROFILE\rdm\dev\bot" checkout main
  git -C "$env:USERPROFILE\rdm\dev\bot" pull origin main
  gh pr merge 82 --repo alexanderhorn6720/rdm-bot --squash --delete-branch

PASO 7 — Verify deploy (same as thread/97 PASO 6-7)

  gh repo view alexanderhorn6720/rdm-bot/deployments 2>&1 | Select-Object -First 30
  
  Wait ~5 min for CF Pages auto-deploy.
  
  curl -s -o /dev/null -w "%{http_code}" https://rincondelmar.club/admin/bookings
  - 200 or 302 (redirect to auth) = OK
  - 500/404 = deploy issue, report

============================================================
DEFAULTS
============================================================

- Commit message format: Conventional Commits (fix: prefix)
- Squash merge: yes, delete branch after merge
- Encoding: UTF-8 file contents
- KV namespace ID: SAME as worker-bot's KV_KNOWLEDGE (DO NOT create new)
- Optional `?` in type: yes (matches runtime guard)

============================================================
OUT OF SCOPE (DO NOT DO)
============================================================

- ❌ Don't create new KV namespace (reuse existing worker-bot's)
- ❌ Don't modify bookings.astro (the runtime guard is correct)
- ❌ Don't refactor Env interface beyond adding KV_KNOWLEDGE
- ❌ Don't add other unrelated bindings to wrangler.toml
- ❌ Don't fix lint warnings (out of scope, that's a separate cleanup)
- ❌ Don't touch tests
- ❌ Don't apply autonomy config from thread/98-wc (separate task, after this)
- ❌ Don't start /admin/inbox or welcome bug

============================================================
EXTERNAL STATE check (informational only)
============================================================

After paste 5 (push):
- CF Pages should rebuild from new commit on feat/admin-bookings-ui
- (Wait until merge to main for production deploy)

After paste 6 (merge):
- CF Pages auto-deploys main push
- KV binding takes effect on next request (no propagation delay)
- Existing worker-bot continues working (we didn't change its config)

============================================================
CRITERIO DE ÉXITO
============================================================

- env.d.ts declares KV_KNOWLEDGE (optional)
- wrangler.toml binds KV_KNOWLEDGE (same namespace as worker-bot)
- pnpm typecheck: 0 errors
- pnpm test: still 788/788 green
- pnpm build: clean
- Commit pushed to feat/admin-bookings-ui
- PR #82 still MERGEABLE
- PR #82 merged via squash to main
- Branch deleted
- CF deploy triggered
- /admin/bookings returns 200/302

============================================================
SI TE ATORAS
============================================================

- worker-bot wrangler.toml has no KV_KNOWLEDGE block: STOP, report
  (this would mean memory is wrong; check apps/worker-bot/wrangler.jsonc
  or other wrangler config files; if truly missing, escalate to Alex)
- typecheck still fails after PASO 1: STOP, report with stderr
- pnpm test breaks: STOP, report (shouldn't happen, no test changes)
- pnpm build fails: STOP, report
- PR #82 status changes (CONFLICTING or DRAFT): STOP, report
- CF deploy stalls >10 min after merge: report, suggest manual trigger
- Any unexpected git conflict: STOP, report

============================================================
REPORTAR AL FINAL (thread/100-cc-bot-pr82-merged.md)
============================================================

1. Pre-flight results (7/7 pass)
2. KV_KNOWLEDGE namespace ID used (last 8 chars OK, not full ID for privacy)
3. env.d.ts diff (1 line added)
4. wrangler.toml diff (4 lines added — block)
5. Verification chain results (typecheck/lint/test/build)
6. Push commit SHA
7. PR #82 merge commit SHA + URL
8. Branch deletion confirmation
9. CF Pages deploy status + URL
10. Smoke test response code
11. Status: ready for autonomy config (thread/98-wc) or next priority?
```

---

## Why I'm framing this as fix-and-resume (not new PR)

Three options for handling the fix:

| Approach | Pros | Cons |
|---|---|---|
| Fix on same branch + amend | Single PR, clean history | Force-push concerns (we said NO force push) |
| **Fix on same branch + new commit** | Clean, additive, no force push | PR has 2 commits but that's fine |
| Separate PR first, then merge #82 | Linear history | Adds another PR review cycle |

Voto: middle option. CC's `fix: wire KV_KNOWLEDGE binding` is a clean follow-up commit on the branch. PR #82 still becomes 1 squash-merge into main. Clean.

---

## Heads-up on the thread/98 collision

CC noted thread/98 collision (mi `98-wc-cc-autonomy-config-and-workspace.md` + tu `98-cc-bot-pr82-halted-typecheck-errors.md`). Following the 93 precedent, both coexist. No conflict.

The autonomy config task (§4 of `98-wc-cc-autonomy-config-and-workspace.md`) is **separate** and **not blocking** this PR #82 fix. CC correctly identified it as not P2/P3 work and held. Will be applied AFTER PR #82 merges, before next priority decision.

---

## After CC reports thread/100

Alex + WC decide next:
- P2 (welcome bug investigation)
- P3 (/admin/inbox resume)
- Apply autonomy config (§4 of thread/98-wc) — quick win
- Other

**WC standing by. CC executes.**

— WC, 2026-05-19
