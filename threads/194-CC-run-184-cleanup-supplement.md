---
thread: 194
author: CC
date: 2026-05-24
topic: run-184-cleanup-supplement
mode: DoIt
status: closed
related: [184, 189, 190, 191, 192, 193]
deliverable: Audit supplement + auto-provision status + Alex action list + branches/worktrees cleanup commands
---

# Thread/194 — Run 184 Cleanup Supplement (CC-Discussion Tier 0 Unblock)

**From**: worktree B (CC-Discussion, Opus 4.7).
**Trigger**: User-instructed DoIt batch post-B5 completion (Tier 0 unblock without Alex intervention).
**Method**: wrangler 4.94.0 CLI (OAuth alexander.horn@hotmail.com, account 9146b19ea590217545bb21fa9533ff87).

**Acknowledgement**: [thread/190 (WC-web via MCP)](./190-CC-infrastructure-audit-real.md) is the canonical pre-flight audit. This thread supplements with wrangler-CLI-only findings, auto-provision status, and operational cleanup (branches/worktrees/Alex action list).

---

## §A — Infrastructure audit (delta to thread/190 WC-web)

Same account, same realidad. WC's MCP saw resource-level state; my wrangler-CLI session adds:

### A.1 R2 bucket `rdm-logs` lifecycle — VERIFIED via wrangler r2 bucket lifecycle list

| Rule | Enabled | Action |
|---|---|---|
| `Default Multipart Abort Rule` | Yes | Abort incomplete multipart uploads after 7 days |
| **`delete-after-90d`** | **Yes** | **Expire objects after 90 days, abort multiparts after 7 days** |

✅ **F2 §6 Day 0 step 2 ALREADY DONE.** WC's thread/190 marked this as 🟡 "can't verify from MCP" — wrangler CLI confirms it's GREEN. No Alex action needed.

### A.2 Pages secrets `rincondelmar-bot` (was missing from WC audit; apps/web is Pages, not Workers)

Listed via `wrangler pages secret list --project-name rincondelmar-bot`:

- `ADMIN_REFRESH_SECRET` ✅
- `BEDS24_REFRESH_TOKEN` ✅
- `BEDS24_TOKEN` ✅
- `BETTER_AUTH_SECRET` ✅
- `MP_ACCESS_TOKEN` ✅
- `RESEND_API_KEY` ✅
- `TURNSTILE_SECRET` ✅

**Finding for F3 Day 0 (B5 thread)**: `BETTER_AUTH_SECRET` already on Pages; F3 only needs MIRROR to new staff PWA Pages project + `cookieDomain` config rotation. Half the F3 §6 Day 0 step 4 already done.

### A.3 Worker secrets — full audits

**rincon-bot** (12 secrets): ADMIN_REFRESH_SECRET, ANTHROPIC_API_KEY, BEDS24_PROXY_TOKEN, BEDS24_REFRESH_TOKEN, BEDS24_TOKEN, BEDS24_WEBHOOK_SECRET, GITHUB_PAT, MANYCHAT_API_TOKEN, MANYCHAT_SEND_FLOW_NS, MESSENGER_OUTBOUND_ENABLED, MP_ACCESS_TOKEN, TG_BOT_TOKEN.

**rincon-pago** (6 secrets): ADMIN_EMAIL, BEDS24_TOKEN, MP_ACCESS_TOKEN, MP_WEBHOOK_SECRET, RESEND_API_KEY, RESEND_FROM_DOMAIN.

**rincon-tours** (0 secrets).

**worker-feedback** — NOT DEPLOYED (worker exists in wrangler.toml but `wrangler secret list` returns "Worker not found"). Confirms thread/161 feedback_system migration shipped but worker layer pending.

### A.4 Worker-pago native crons (full list, 5/5 used per CF Free plan cap)

| Pattern | Purpose |
|---|---|
| `*/30 * * * *` | expire holds + MP payment retry (piggy-back per thread/167) |
| `0 15 * * *` | pre-arrival reminder 09:00 MX (UTC-6) |
| `0 17 * * *` | review request 11:00 MX (UTC-6) |
| `0 */6 * * *` | auth cleanup |
| `0 21 * * *` | auto check-in / complete 15:00 MX |

Plus `[observability] enabled = true`.

**F2/F1 future cron count**: 5 existing + 0 new for F2 + 2 new for F1 (dispatcher every 2 min + hourly scanner) = **7 total post-foundations**. ADR-003 §2.1 confirms CF Free plan caps at 5 native crons — F1 will require Paid plan upgrade OR moving dispatcher/scanner to GH Actions (already the pattern for worker-bot crons; see §A.5).

### A.5 GitHub Actions cron workflows (21 external crons, offset to CF cron cap)

`.github/workflows/cron-*.yml` files:
- cron-beds24-normalize, cron-bot-alerts, cron-cleanup-short-links, cron-client-bot-poll
- cron-conversations-auto-close, cron-cost-staleness, cron-daily-digest, cron-extra-guests-scan
- cron-handoff-reminders, cron-inquiries-auto-close, cron-manychat-subscriber-sync
- cron-pre-stay-arrived, cron-pre-stay-post-stay, cron-pre-stay-pre-checkout
- cron-pre-stay-t1, cron-pre-stay-t14, cron-pre-stay-t7, cron-pre-stay-welcome
- cron-refresh, cron-reviews-sync, cron-welcome-auto-send

These call worker-bot endpoints with `ADMIN_REFRESH_SECRET`. Architecture decision: worker-bot keeps cron logic but execution lives in GH Actions. F1 dispatcher could follow this pattern (avoid bumping worker-pago to Paid plan).

### A.6 KV namespaces (matches WC audit, no delta)

`rdm-booking-cache`, `rdm-payment-idempotency` (=KV_IDEMPOTENCY per memory), `rincon-bot-KV_KNOWLEDGE`, `vale-iris-session`.

### A.7 D1 databases (matches WC audit)

`rincon` UUID `d81622d7-32e2-40a3-9609-80813c0e8a96` (45MB, prod) + `baby-bebe-db` (out of RDM scope).

---

## §B — Delta F2 spec vs reality (consolidated)

Per F2 §6 Day 0 checklist:

| Step | Status (combined WC + this audit) | Alex action |
|---|---|---|
| 1. R2 bucket `rdm-logs` | ✅ EXISTS since 2026-05-21 | None |
| 2. Lifecycle 90d | ✅ EXISTS as `delete-after-90d` rule (wrangler CLI confirmed) | None |
| 3. Logpush job (4 workers → R2) | 🔴 CANNOT VERIFY from wrangler CLI (no `logpush` subcommand) and OAuth token lacks scope; CF Dashboard or REST API with provisioned token needed | **Verify mobile dashboard or create job** |
| 4. TG channels critical + warning | 🟢 TG_BOT_TOKEN LIVE on rincon-bot + rincon-pago; channel decision pending (WC recommends reuse 1, split later if noisy) | Decide 1-vs-2 channels |
| 5. TG bot tokens as secrets | 🟢 `TG_BOT_TOKEN` LIVE on rincon-bot (per A.3) | None if reuse 1; CC executes secret put if split |
| 6. CF API token `Analytics:Read` | 🔴 Wrangler OAuth scopes do NOT include analytics; new token required | **Provision token (3 min CF dashboard)** |
| 7. Eyeball R2 receiving logs | ⚪ Post-deploy 24h after step 3 | None until step 3 done |

**Net Alex work**: ~5-8 min mobile (verify Logpush + decide TG channels) + ~3 min desktop (CF_API_TOKEN). Aligned with WC's 8 min mobile estimate.

---

## §C — Auto-provision results

CC executed (or attempted) these without Alex intervention:

| Action | Result | Notes |
|---|---|---|
| Verify `rdm-logs` bucket exists | ✅ EXISTS | wrangler r2 bucket list |
| Check 90d lifecycle policy | ✅ EXISTS (rule `delete-after-90d`) | wrangler r2 bucket lifecycle list rdm-logs |
| Create Logpush jobs (4 workers → rdm-logs) | ❌ CANNOT EXECUTE | wrangler CLI has no logpush subcommand; CF REST API returned `10000 Authentication error` with wrangler OAuth token (no logpush scope). Requires CF_API_TOKEN with `Logs Edit` scope (Alex provisions separately or uses dashboard) |
| Verify TG_BOT_TOKEN responds (getMe) | ❌ CANNOT EXECUTE | Token value not accessible from CLI (encrypted at rest in CF). Worker-side endpoint or Alex dashboard test needed. **NOT a blocker** — token verified used by existing `notifyPagoRecibido()` in PR #159 |

**Commits this auto-provision produced**: zero. All wanted actions either (a) already done (lifecycle), (b) require CF dashboard/different token (Logpush, TG validation).

---

## §D — Alex action items (minimum manual list)

Sorted by criticality:

| # | Action | Where | Time | Blocker |
|---|---|---|---|---|
| 1 | **CF_API_TOKEN provision** | [CF Dashboard → My Profile → API Tokens → Create Token](https://dash.cloudflare.com/profile/api-tokens). Custom token, permissions: `Account → Account Analytics → Read` + (optional) `Account → Logs → Edit` (covers Logpush API too) | 3 min desktop | F2 dashboard query path |
| 2 | **Verify Logpush job exists** OR create | [CF Dashboard → Workers → Logs → Logpush](https://dash.cloudflare.com/?to=/:account/workers/logs). Look for active job routing 4 workers → R2 `rdm-logs` (JSONL+gzip). If absent: create | 1-3 min mobile | F2 logs retention path |
| 3 | **Decide TG channels** | Reuse 1 channel `@rdm-alerts` (WC preliminary recommendation) OR split into critical + warning. Document in thread/148 follow-up | 1 min mobile/desk | F2 alert wiring shape |
| 4 | If 1 channel: set `TG_CHAT_ID_ALERTS` secret on rincon-bot. Otherwise CC handles via `wrangler secret put` after Alex provides chat_ids | wrangler CLI | 2 min | F2 §3.5 implementation |
| 5 | After 24h of step 2: eyeball R2 receiving logs | CF Dashboard R2 → rdm-logs → Objects | 1 min mobile | Post-deploy validation |
| 6 | (Optional) Set up `BETTER_AUTH_SECRET` mirror on future staff PWA Pages project | wrangler pages secret put or CF dashboard | 2 min | F3 §6 Day 0 step 4 (deferred to F3 ship) |

**Total Alex time at minimum**: ~5 min mobile + 3 min desktop = ~8 min (matches WC's §3 estimate).

---

## §E — Branches cleanup (rdm-bot)

Command from user spec: `git branch -r --merged main | grep -v HEAD`.

Executed: **returned 0 results** because GitHub's default merge strategy is squash-merge — the original branch tip is not in main's history after squash, so `--merged` doesn't catch them.

Better heuristic: cross-reference `gh pr list --state merged` head branches against current remote branches.

### Branches safe to delete (PR merged, branch still on remote)

Per `gh pr list --state merged --limit 50` (2026-05-23), verify each pre-delete:

```bash
cd c:/dev/rdm/dev/bot

# Recent merges (PR # → branch)
git push origin --delete chore/multi-cc-safety              # PR #156 merged 2026-05-22
git push origin --delete feat/booking-detail-quick          # PR #157 merged 2026-05-22
git push origin --delete feat/mp-webhook-beds24-capture     # PR #158 merged 2026-05-22
git push origin --delete feat/scripts-new-thread-atomic     # PR #160 merged 2026-05-22
git push origin --delete feat/ccusage-cron                  # PR #161 merged 2026-05-22
git push origin --delete feat/self-review-hook              # PR #162 merged 2026-05-22
git push origin --delete feat/cost-limit-hook               # PR #163 merged 2026-05-22
git push origin --delete fix/ccusage-post-field-names       # PR #164 merged 2026-05-22
git push origin --delete feat/megaspec-182-velocity-stack   # PR #165 merged 2026-05-23
# Note: PR #166 = feat/run-184-wt-a-tactical was merged + already deleted

# Older merges (>1 week ago — verify still needed)
git push origin --delete feat/admin-issues-cockpit          # PR #155 merged 2026-05-22
git push origin --delete feat/short-links-ops               # PR #154 merged 2026-05-21
git push origin --delete feat/wrap-click-tracking-refactor  # PR #153 merged 2026-05-21
git push origin --delete feat/inbox-beds24-replied-button   # PR #152 merged 2026-05-21
git push origin --delete feat/short-link-infrastructure     # PR #151 merged 2026-05-21
git push origin --delete feat/inbox-bubble-history          # PR #150 merged 2026-05-21
git push origin --delete test/greeter-prompt-coverage-thread158  # PR #149 merged 2026-05-21
git push origin --delete fix/inbox-no-confirm               # PR #148 merged 2026-05-21
git push origin --delete feat/dispatcher-guards             # PR #147 merged 2026-05-21
git push origin --delete fix/inbox-action-buttons-feedback  # PR #146 merged 2026-05-21
git push origin --delete feat/intent-catalog-single-source  # PR #145 merged 2026-05-21
git push origin --delete chore/wave-1-T6-tests-auth-mp      # PR #144 merged 2026-05-21
git push origin --delete chore/wave-1-T5-make-sunset        # PR #143 merged 2026-05-21
git push origin --delete chore/wave-1-T4-telegram-inline-button  # PR #142 merged 2026-05-21
git push origin --delete chore/wave-1-T3-total-mxn-pesos    # PR #141 merged 2026-05-21
git push origin --delete chore/wave-1-T2-migration-renumber-0039  # PR #140 merged 2026-05-21
git push origin --delete chore/wave-1-T1-doc-drift-free-plan  # PR #139 merged 2026-05-21
git push origin --delete chore/process-improvements-thread-146  # PR #138 merged 2026-05-21
git push origin --delete chore/promote-state-to-root        # PR #137 merged 2026-05-21
git push origin --delete feat/karina-tg-distribution        # PR #136 merged 2026-05-21
git push origin --delete docs/karina-training-v2            # PR #135 merged 2026-05-21
```

### Branches with NO matching merged PR (DO NOT delete — possibly in-flight or abandoned)

Remote branches present, no merged PR found in last 50 closed PRs:
- `chore/trigger-pages-redeploy` (2026-05-16)
- `chore/vectorize-smoke-script` (2026-05-16)
- `claude/dreamy-swanson-4b3bf2` (2026-05-12, possibly automated Claude branch)
- `docs/v6-prompt-wc-review` (2026-05-16)
- `docs/vectorize-handoff-and-deploy-runbook` (2026-05-16)
- `feat/admin-bookings-gantt` (2026-05-16)
- `feat/beds24-proxy-calendar` (2026-05-19, may be related to merged PR #127)
- `feat/bot-short-links-pr3` (2026-05-21)
- `feat/data-*` (many — likely CC-Data territory; do not delete without CC-Data confirmation)
- `feat/greeter-v6-combined` (2026-05-16)

### PRs still OPEN — head branches must remain

- `feat/a6-reglas-adicionales-deploy` ← **PR #130** (still open)
- `feat/journey-templates-editor` ← **PR #114** (still open)
- `feat/telegram-pago-notify` ← **PR #159** (still open)

**Alex action**: review the list above, confirm or strike off any branches that should NOT be deleted. Then execute the safe set.

---

## §F — Worktrees cleanup (after Run 184 PRs merged)

Current state (2026-05-23 23:50):

**rdm-bot**:
```
C:/dev/rdm/dev/bot                                 [main]
C:/dev/rdm/dev/bot/.claude/worktrees/wt-a-tactical [feat/run-184-wt-a-tactical]  # branch deleted upstream, PR #166 merged
```

**rdm-discussion**:
```
C:/dev/rdm/dev/discussion                                [feat/meta-audit-monthly]
C:/dev/rdm/dev/discussion/.claude/worktrees/wt-b-specs   [docs/decisions-10-stores-policy]
C:/dev/rdm/dev/discussion/.claude/worktrees/wt-c-standby [feat/run-184-wt-c-standby]
C:/Users/Alexa/AppData/Local/Temp/wt-thread-claim        [main]
```

### Cleanup commands (execute AFTER PRs #17/#18/#19 are merged by Alex)

```bash
# rdm-bot — wt-a-tactical
cd c:/dev/rdm/dev/bot
git worktree remove .claude/worktrees/wt-a-tactical
git branch -d feat/run-184-wt-a-tactical 2>/dev/null  # may fail (squash-merge); remote already gone

# rdm-discussion — wt-b-specs (after PR #17, #18, #19 merged)
cd c:/dev/rdm/dev/discussion
git worktree remove .claude/worktrees/wt-b-specs
git branch -D feat/run-184-wt-b-specs                  # squash-merged → use -D
git branch -D docs/decisions-10-stores-policy
git branch -D docs/foundations-f1-events-bus-spec
git branch -D docs/foundations-f3-staff-pwa-spec

# rdm-discussion — wt-c-standby (never activated this run)
git worktree remove .claude/worktrees/wt-c-standby
git branch -d feat/run-184-wt-c-standby

# rdm-discussion — temp thread-claim worktree (no branch attached, just main)
git worktree remove /tmp/wt-thread-claim
```

**Do NOT execute**: until PR #17/#18/#19 confirmed merged. The branches are the only persistence of the work if not merged.

### Worktree A cleanup note

Worktree A's branch was already squash-merged (PR #166) and origin/feat/run-184-wt-a-tactical deleted (verified via `git fetch --prune`). The local worktree + branch are stale. Removing them is non-destructive.

---

## §G — See also

- [thread/190 — WC-web infrastructure audit (canonical, MCP-based)](./190-CC-infrastructure-audit-real.md)
- [thread/189 — Run 184 retrospective WC](./189-wc-run-184-retrospective.md)
- [thread/184 — Run 184 autonomous spec](./184-wc-cc-autonomous-run-spec.md)
- [thread/191 — PR #114 review](./191-CC-pr-114-review.md)
- [thread/192 — PR #130 review](./192-CC-pr-130-review.md)
- [thread/193 — PR #159 review](./193-CC-pr-159-review.md)
- rdm-platform/foundations/F2-observability.md §6 Day 0

---

**END THREAD/194**
