# 95 — WC: briefing for new CC implementation session

**Date**: 2026-05-19
**Author**: WC
**To**: CC-Bot (next implementation session, fresh start)
**Re**: Structural changes since last commit + next priorities + DoIt template v3
**Status**: 🟢 Read before any commit. Pre-flight checks required.

---

## TL;DR

Last CC implementation session reported stopped clean (thread/93-cc-bot). 8 PRs shipped, V6 100% canary, PR #82 awaiting merge, inbox build paused.

Since then, **structural changes happened**:
- 2 repos renamed
- Local paths consolidated to canonical structure
- New repo `rdm-platform` exists (conceptual only, CC doesn't touch)
- DoIt template iterated v1 → v2 → v3 based on CC feedback

This thread = comprehensive briefing for the next session. Read it, run pre-flight, then ask Alex which priority to tackle first.

---

## §1 — Structural changes you need to know

### GitHub renames

| Old name | New name |
|---|---|
| `rincondelmar-bot` | `rdm-bot` |
| `rincondelmar-bot-discussion` | `rdm-discussion` |

GitHub auto-redirects old URLs but **use new URLs in new commits** for cleanliness. PRs, issues, branches all preserved.

### New repo (NOT for CC)

`rdm-platform` (private) — conceptual brainstorm, ADRs, foundations. **CC does NOT touch this repo** unless explicit task. WC territory.

### Local paths consolidated

Canonical location going forward:
```
C:\Users\Alexa\rdm\dev\
├── platform\
├── bot\         ← work here (rdm-bot remote)
└── discussion\  ← thread responses here (rdm-discussion remote)
```

**Note path**: `C:\Users\Alexa\` (with "a") NOT `C:\Users\Alex\`.

### Old paths still alive (don't break)

```
C:\rincondelmar-bot\
C:\rincondelmar-bot-discussion\
```

These exist because parallel sessions may still be working there. **Don't push from old paths**. They will die naturally when Alex cleans up.

**Migration to new paths**: when you work, use `C:\Users\Alexa\rdm\dev\bot\` and `C:\Users\Alexa\rdm\dev\discussion\`. If you find yourself in old path, switch via `cd` to new path.

---

## §2 — Status of work from previous session

From thread/93-cc-bot-status (previous session):

### Shipped & verified (8 PRs)

- PR #74-75: admin/conv SSR fixes + redeploy trigger
- PR #77: V6 prompt (100% canary, green telemetry)
- PR #78: pet fee correction everywhere ($300/estancia)
- PR #79: V6 followups (validator + booking header + nav)
- PR #80: beds24_events → beds24_bookings normalize
- PR #81: data extraction (174 FAQs + 102 ideas)
- PR #82: **awaiting merge** (see below)

### Awaiting merge

**PR #82 — `feat/admin-bookings-ui`**: 2860 lines
- List view + Gantt view + KPIs + inquiry drawer + Conflict column
- Built per specs in threads 84b/86/87
- Tested locally
- Awaiting Alex review

### Paused (not committed)

- `/admin/inbox` build: started before commit, paused per Alex instruction

### Deferred (root cause unclear)

- Welcome auto-send bug: `pending_welcomes` not being created despite v2 fix. Likely shares root cause with beds24_bookings normalize gap (same "downstream pipeline never wired" pattern). Investigation deferred.

---

## §3 — Priority for next session (Alex decides)

WC recommended sequencing:

| Priority | Item | Rationale |
|---|---|---|
| **P1** | Review/merge PR #82 (bookings UI) | Spec compliant, code in branch, just needs final review. Clean close. |
| **P2** | Welcome auto-send investigation | Likely shared root cause with beds24_bookings (already resolved). Better to investigate together. |
| **P3** | `/admin/inbox` build resume | Patterns from bookings PR established. Build is mostly mechanical now. |

**Wait for Alex's explicit signal before arranging any of these.** Don't auto-start.

---

## §4 — DoIt template v3 conventions

Based on previous CC feedback iterations, template evolved. Apply these conventions to all future DoIt tasks:

### Pre-flight = auto-verifiable commands only

NOT human questions. Examples:
```bash
$userHome = $env:USERPROFILE         # not "where is your home?"
gh auth status                       # not "do you have PAT?"
Test-Path "$userHome\rdm\dev\bot"    # not "do you have clone?"
gh repo view OWNER/REPO --json name  # not "does repo exist?"
```

### Use placeholders, never hardcode paths

```
<USER_HOME>  = $env:USERPROFILE  (resolve to C:\Users\Alexa\)
<OWNER>      = alexanderhorn6720
<EMAIL>      = (inherit from git config unless specified)
<REPO>       = rdm-bot | rdm-discussion | rdm-platform
```

### Absolute paths in all mutations

When using mkdir, git clone, Test-Path on target, etc, use **absolute paths**. No relative paths, no implicit cwd dependence:

```bash
# ❌ DON'T (depends on cwd):
cd $userHome\rdm\dev
git clone URL bot

# ✅ DO (absolute, cwd-independent):
git clone URL "$userHome\rdm\dev\bot"
```

This eliminates the need for cwd-state checks (which had false-positives when CC runs inside `.claude\worktrees\`).

### Order: additive-first, mutating-second

When task involves both creating new + modifying existing:
1. Create new first (additive, recoverable)
2. Modify/rename existing second (mutating)

If creation fails after modification, you're in worse state than reverse.

### Defaults section explicit

Every DoIt task should specify:
- Commit message format (default: Conventional Commits)
- File encoding (default: UTF-8 file contents, ASCII shell args)
- Git attribution (default: inherit from parent unless override)
- Visibility on rename (default: preserve)
- Branch protection (default: not applied)
- CI/CD (default: not setup)

### External state check (informational only)

Before destructive ops, identify external state that may surprise-break:
- Make scenarios with hardcoded repo URLs
- CF Pages/Workers connected to repo
- CI/CD workflows referencing repo name
- Parallel CC sessions in same paths
- IDE workspaces
- Webhooks

Report findings, don't act on them unless explicitly instructed.

### Worktree safety

If task involves rename + you're inside `.claude\worktrees\` of repo-to-rename: that's harness state, not Alex state. OK to proceed if all mutation commands use absolute paths.

References: threads 93, 94 in rdm-discussion for full lessons history.

---

## §5 — Pre-flight checks for next session

Run these BEFORE next commit:

```bash
# 1. Verify canonical paths exist
Test-Path "C:\Users\Alexa\rdm\dev\platform"   # → True
Test-Path "C:\Users\Alexa\rdm\dev\bot"        # → True (cloned 2026-05-19)
Test-Path "C:\Users\Alexa\rdm\dev\discussion" # → True (cloned 2026-05-19)

# 2. Verify remotes point to rdm-* URLs
cd "C:\Users\Alexa\rdm\dev\bot"
git remote -v   # origin must point to github.com/alexanderhorn6720/rdm-bot.git

cd "C:\Users\Alexa\rdm\dev\discussion"
git remote -v   # origin must point to github.com/alexanderhorn6720/rdm-discussion.git

# 3. Verify clean state
cd "C:\Users\Alexa\rdm\dev\bot"
git status                # should be clean or have minimal local changes
git log @{u}..            # should be empty (no unpushed commits)

cd "C:\Users\Alexa\rdm\dev\discussion"
git status
git log @{u}..

# 4. Verify auth
gh auth status            # logged in

# 5. Pull latest
cd "C:\Users\Alexa\rdm\dev\bot"
git pull origin main

cd "C:\Users\Alexa\rdm\dev\discussion"
git pull origin main

# 6. Read this thread + thread/93-cc-bot-status (previous session) + thread/94 (template v3)
```

Halt only if any of these fail unexpectedly. Report findings before proceeding.

---

## §6 — Out of scope (NO HACER without explicit task)

- ❌ Don't touch `rdm-platform` repo
- ❌ Don't auto-start PR #82 merge — wait for Alex signal
- ❌ Don't auto-start `/admin/inbox` build — wait for signal
- ❌ Don't auto-investigate welcome bug — wait for signal
- ❌ Don't move/delete `C:\rincondelmar-*\` old paths
- ❌ Don't update IDE workspaces (Alex's job)
- ❌ Don't change Make scenarios, CF Workers, MP integration
- ❌ Don't push from old paths

---

## §7 — Reporting back

When you read this and complete pre-flight checks, respond with new thread:

```markdown
# 96-cc-bot-pre-flight-clean-ready-for-next-task

**Date**: YYYY-MM-DD

## Pre-flight status
- Canonical paths: ✓/✗
- Remotes: ✓/✗
- Working state: ✓/✗
- Auth: ✓/✗
- Latest pulled: ✓/✗

## Read confirmations
- [x] Thread 93 (previous session status)
- [x] Thread 94 (template v3 lessons)
- [x] Thread 95 (this briefing)

## Old paths observed (informational)
- C:\rincondelmar-bot\: <activity status>
- C:\rincondelmar-bot-discussion\: <activity status>

## Ready for next task
Awaiting Alex's signal on priority. Default sequencing per WC:
1. Review/merge PR #82
2. Welcome bug investigation
3. /admin/inbox resume

## Questions for Alex/WC
- <any blockers found>
```

After this response, **stop and wait**. Alex picks priority, then DoIt task arrives.

---

## §8 — Why we're doing this (context for understanding)

Previous session (thread/93-cc-bot) made significant progress but stopped clean before some structural decisions WC made later. Sequence:

```
Day 1: CC shipped 8 PRs, stopped clean
Day 1 (later): Alex + WC brain mode session (~10 hours)
  - Platform shift documented
  - Repo strategy decided
  - Local paths canonical structure
  - DoIt template iterated v2/v3
  - 30 memorias captured
Day 2: CC + WC executed:
  - Repo rename
  - Platform repo created  
  - Clone fresh to canonical paths
Day 2 (now): CC continues implementation
```

This thread closes the gap so CC understands current state without re-reading 10+ threads. Concise context > exhaustive context.

---

**WC standing by. Ready when CC pre-flight confirms.**

— WC, 2026-05-19, end of session
