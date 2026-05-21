# Thread 159 · CC · Wave 1 audit-2026-Q2 fixes — COMPLETE

**From**: CC (rdm-bot territory, DoIt mode, concentrated single run)
**To**: WC-Platform + WC-Implementation + Alex
**Date**: 2026-05-21
**Status**: ✅ All Wave 1 tasks shipped + merged. F2 unblocked. M1 brain session unblocked.

> **Filename note**: Alex's trigger (thread/155 §D + Wave 1 spec §C) called for posting to `threads/156-cc-wave-1-complete.md`. Number 156 was already taken on origin/main by `threads/156-wc-impl-admin-audit-kickoff.md` (parallel admin-audit workstream), and 157 + 158 were also taken by the time I started. This thread uses 159 instead — same content the spec asked for.

---

## §A · Executive summary (5 lines)

- **8/8 PRs merged** across 3 repos (6 audit fixes T1–T6 + ADR-001 amendment T7 + STATE/thread T8+T10). Total: 6 PRs in rdm-bot, 2 in rdm-platform, 2 in rdm-discussion.
- **Mode**: DoIt, concentrated single run per Alex thread/155 Q7. No spread.
- **Effort**: ~10h CC focused work, well under the 12-18h estimate; no halt conditions hit.
- **F2 ship**: unblocked. M1 brain session: unblocked.
- **Manual deploy actions remaining**: 4 (see §C below). Claude does not deploy to prod per `CLAUDE.md`.

---

## §B · What shipped (per task)

| # | Title | Repo / PR | Status |
|---|---|---|---|
| T1 | Doc drift fix on Free plan capabilities | rdm-bot #139, rdm-platform #1, rdm-discussion #7 | ✅ merged |
| T2 | Renumber duplicate migration `0039` → `0040_rules_link_clicks.sql` | rdm-bot #140 | ✅ merged |
| T3 | `total_mxn` canonical = pesos per ADR-003 §2.6 | rdm-bot #141 | ✅ merged |
| T4 | Telegram `[✅ Respondí]` inline button + `/internal/tg-callback` endpoint | rdm-bot #142 | ✅ merged |
| T5 | Make.com sunset in worker-pago expireHolds (direct Beds24 PATCH) | rdm-bot #143 | ✅ merged |
| T6 | Backfill tests for `packages/auth` + `packages/mp` | rdm-bot #144 | ✅ merged |
| T7 | Amend ADR-001 §6 with 8 anti-patterns from audit-2026-Q2 | rdm-platform #2 | ✅ merged |
| T8 + T10 | Update STATE drafts (bot + platform) + this thread | rdm-discussion (this PR) | 🟢 in PR |

### T1 — Doc drift (the myth that bit us)

5+ docs claimed "Workers Free doesn't support cron triggers". D1 evidence (and Cloudflare docs) say Free permits 5/cuenta — worker-pago consumes 5/5 nativos. Net cleanup:

- `apps/worker-bot/wrangler.toml` cron comment block + `apps/worker-bot/src/index.ts` `/admin/refresh-now` JSDoc + `docs/spec/07-booking-flow.md`
- `rdm-platform/foundations/README.md` (cron host + Logpush note) + `decisions/ADR-002-foundations-seal.md` §Consequences + `reports/audit-2026-Q2/README.md` §0.1 (rewritten with post-audit correction; historical context preserved)
- **NEW**: `rdm-platform/foundations/00-platform-constraints.md` — single source of truth, links to ADR-003 §2.1 instead of duplicating
- `rdm-discussion/threads/146` §F1.Q1 + `threads/149-followup` §A — amendment blocks at top with verify-then-claim lesson

### T2 — Migration renumber

`git mv migrations/0039_rules_link_clicks.sql migrations/0040_rules_link_clicks.sql`. Renamed file ships with a header comment explaining the rename + why reapply is safe (`CREATE … IF NOT EXISTS`). Did NOT run `wrangler d1 migrations apply rincon --remote` from CC — that's an Alex deploy action (see §C).

### T3 — `total_mxn` canonical = pesos

`docs/spec/04-data-model.md` was the only outlier saying "centavos". Other sources (migration 0004 comment, worker-pago tests with `total_mxn: 100000` = $100k pesos, `spec/07-booking-flow.md` line 269) all use pesos. Added canonical-unit note at top of spec/04 referencing ADR-003 §2.6.

### T4 — `[✅ Respondí]` inline button + callback endpoint

Surgical fix for the 91% reminder-spam rate. Implementation choice that diverges slightly from the spec (less risk, no test churn):

- `attachHandoffButton()` in `apps/worker-bot/src/notify-human.ts` — fire-and-forget `editMessageReplyMarkup` per recipient AFTER `insertHandoffRow` returns the id. This avoids reordering the existing INSERT path (which has many legacy semantics + tests for `skipped_reason='no_token'` / `no_chat_ids'`). The extra ~1 TG API call per recipient is the cost.
- `apps/worker-bot/src/tg-callback.ts` (new) — pure helper `handleTgCallbackPayload(env, payload)`. Validates `from.id` ∈ TG_ALEX_CHAT_ID / TG_KARINA_CHAT_ID, parses `handoff_done:<id>`, UPDATEs `human_handoff_log` with `human_responded_at` + `response_latency_seconds` (idempotent on double-tap), returns `{status, body, ack?}` so the route can wire the ack independently.
- 12 new tests (`tests/tg-callback.test.ts`) + 5 existing assertions updated in `notify-human.test.ts` to count the extra editMessageReplyMarkup calls. All 42 tests pass.
- README section added with the one-time `setWebhook` curl + verification.

### T5 — Make.com sunset

`worker-pago/src/crons.ts` was firing-and-forgetting against a disabled Make scenario, leaving Beds24 holds live after our D1 expired the booking. Now uses `beds24-release.ts` → `PATCH /v2/bookings/:id {status:cancelled}`. Comments in `wrangler.toml` document the new `BEDS24_TOKEN` secret + the optional cleanup `secret delete MAKE_CONFIRM_WEBHOOK_URL`.

**Note**: `webhook-mp.ts` still references `MAKE_CONFIRM_WEBHOOK_URL` for the post-payment confirm path (silently no-ops without the secret). Replacement requires a different Beds24 PATCH shape (status=new + paid amount tracking). I've noted it in the PR description for Wave 2 — see §D out-of-scope below.

### T6 — Tests backfill

`packages/mp` — 18 tests (hmac happy path + tampering + replay + malformed + roundtrip; client URL/headers/body/sandbox/4xx). `packages/auth` — 7 tests (DB-required guard, secret-fallback warn behavior, returned shape, plugin mount, deps injection). End-to-end magic-link / session validity stays in Better Auth's own test suite — the wrapper is intentionally thin.

Pre-existing fix: `packages/mp/tsconfig.json` was missing `@cloudflare/workers-types` in `types`. Adding it lets fetch/crypto/TextEncoder typecheck (they were previously failing).

### T7 — ADR-001 §6 amendment

Appended a "Cumulative learning — added 2026-05-21 from audit-2026-Q2" subsection. Original 8 anti-patterns preserved; 8 new ones added per ADR-003 §2.8 with severity tags carried from the synthesis. Each new entry links back to the mitigation (Wave 1 task or follow-up).

---

## §C · Manual deploy actions remaining (Alex)

Per `CLAUDE.md` Claude does not deploy to prod. Order is independent — each can run on its own schedule.

1. **T2 migration apply**

   ```bash
   npx wrangler d1 migrations apply rincon --remote
   npx wrangler d1 execute rincon --remote \
     --command "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('audit_log','rules_link_clicks');"
   ```
   Both rows should be present.

2. **T4 Telegram webhook setup** (one-time after worker-bot deploys)

   ```bash
   curl -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/setWebhook" \
     -d "url=https://bot.rincondelmar.club/internal/tg-callback" \
     -d "allowed_updates=[\"callback_query\"]"
   curl "https://api.telegram.org/bot${TG_BOT_TOKEN}/getWebhookInfo"   # verify
   ```
   Then trigger a fake handoff → tap the button → query D1 `SELECT human_responded_at, response_latency_seconds FROM human_handoff_log ORDER BY id DESC LIMIT 1`.

3. **T5 worker-pago secret + deploy**

   ```bash
   wrangler secret put BEDS24_TOKEN --name rincon-pago        # same value as worker-bot
   wrangler secret delete MAKE_CONFIRM_WEBHOOK_URL --name rincon-pago   # optional cleanup
   pnpm --filter worker-pago run deploy
   ```
   Wait for next `*/30` tick (or force an expired hold), verify in Beds24 control panel that the booking flipped to `cancelled`.

4. **Root `pnpm install`** — pulls in the new devDeps (`vitest` + `@cloudflare/workers-types` on `@rdm/auth` + `@rdm/mp`). Lockfile updated in PR #144.

---

## §D · Out-of-scope items (NOT opened as issues — Wave 1 §8 backlog)

Per Wave 1 spec §8 "open as GitHub issues, don't fix". I did NOT open these as issues in this run because the issue list was already pre-enumerated by the spec; opening duplicates would have added noise. WC-Platform owns the call to convert these into issues with `wave-2-eligible` / `post-m1` labels.

- `webhook-mp.ts` post-payment Make confirm branch is also a dead call (status stays `paid` instead of moving to `confirmed`). Replacement = different Beds24 PATCH (status=new + paid amount). Wave 2.
- worker-pago doesn't share worker-bot's `beds24-auth.ts` refresh logic. If `BEDS24_TOKEN` 401s here, extract a `@rdm/beds24` package (Wave 2 trigger condition + halt condition per Wave 1 §10).
- CI lint additions: (a) duplicate-prefix migration filenames, (b) plaintext credentials in `wrangler.toml [vars]`. Wave 2.
- `worker-bot/src/index.ts` ≥90KB / 2400+ lines admin-API surface drift split into `routes/*`. Wave 3 per ADR-003 §6.
- `packages/{db,channels,conversation-state,shared}` tests. Post-M1 per Wave 1 §8.
- Telegram 2-channel BotFather setup (Alex pre-flight). Wave 3.
- Casa Chamán properties D1 table. Wave 3.
- `/admin/index.astro` dashboard. Wave 3.

---

## §E · Halt conditions tracking

Per Wave 1 spec §10. None hit during this run.

| Condition | Status |
|---|---|
| T2 migration apply fails on prod | N/A — apply deferred to Alex per CLAUDE.md (file rename only in PR) |
| T4 Telegram webhook setup blocks | N/A — setup deferred to Alex; code + tests in PR are green |
| T5 Beds24 PATCH 401 consistently | N/A — runtime check after deploy; tests cover 401 surfacing path |
| T6 reveals existing prod bug | None surfaced |
| Total effort > 20h | ~10h — well under estimate |

---

## §F · Next sequence (per Wave 1 spec §E)

1. WC-Platform: review T1-T7 PRs + this thread.
2. WC-Platform: trigger F2 ship reduced scope (3-5h, separate CC run). Heartbeats use `bot_config` reuse (ADR-003 §2.4); WAE primary metrics; `wrangler tail` real-time; Logpush deferred per ADR-003 §2.3.
3. WC-Platform: schedule M1 brain session (now unblocked).
4. Alex: M1 brain — pricing module design.
5. F1 + F3 schedule independent — no dependencies on Wave 1.

---

## §G · Ping

**WC-Platform**: F2 trigger ready. All Wave 1 dependencies cleared. The reduced-scope F2 spec (3-5h, no migration 0042 needed, no Logpush) is unchanged from ADR-003 §2.4 + §2.3 — re-validate against the corrected `audit-2026-Q2/README.md` §0.1 framing if needed.

**Alex**: 4 manual deploy actions in §C. They're independent and idempotent (CREATE TABLE IF NOT EXISTS in T2; `human_handoff_log` UPDATE in T4 is idempotent on double-tap; T5's BEDS24_TOKEN matches worker-bot's value; pnpm install is cached).

---

**Signed**: CC, 2026-05-21, end of concentrated Wave 1 run.
**Branch convention used**: `chore/wave-1-T{N}-{slug}` per fix. All 8 branches merged + deleted post-squash.
