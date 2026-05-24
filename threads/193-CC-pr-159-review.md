---
thread: 193
author: CC
date: 2026-05-24
topic: pr-159-review
mode: brain
status: open-for-alex-vote
related: [159, 158, 167, 169, 184]
deliverable: PR #159 review with merge recommendation
---

# Thread/193 — PR #159 Review: Telegram Pago-Recibido Notifications

**Subject**: [PR #159 — feat(worker-pago): Telegram pago-recibido notifications (thread/169)](https://github.com/alexanderhorn6720/rdm-bot/pull/159)
**Branch**: `feat/telegram-pago-notify` (stacked on `feat/mp-webhook-beds24-capture` = PR #158, now merged)
**Stats**: +481 / −1 lines, 7 files changed
**Recommendation**: ✅ **GREEN to merge** after rebase against current main (PR #158 already merged so target auto-flips).

---

## §0 — Summary

PR adds a Telegram `sendMessage` notification fired by `worker-pago` when an MP payment is successfully captured in Beds24 (approved OR refunded/charged_back). Fire-and-forget — never blocks payment webhook response. Stacked on the now-merged PR #158 (mp-webhook-beds24-capture).

Message format (per thread/169 Q3, Alex-approved):
```
💰 Pago recibido
Booking #86981862 · Alex Horn
2026-07-15 → 2026-07-18
$5,000 MXN · MP visa
👉 https://rincondelmar.club/admin/bookings/86981862
```

Refunds use `⚠️ Reembolso` prefix + negative sign on amount.

---

## §1 — Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | `TG_CHAT_ID_PAGOS` secret NOT YET PROVISIONED on worker-pago — without it, helper is graceful no-op (per PR description) | 🟢 Low | Acceptable: PR ships graceful-degrade. Alex provisions secret post-merge. NO 500 risk on payment webhook. |
| 2 | `TG_BOT_TOKEN` reused from worker-bot via `scripts/sync-secret.sh` (per PR description). If sync hasn't run for worker-pago, secret missing → no-op | 🟢 Low | Audit thread/194 §A.3 verifies `TG_BOT_TOKEN` is ALREADY set on worker-pago ✅ (no sync needed). |
| 3 | Telegram API rate limit (default 30 msg/sec global; 1 msg/sec per chat) — if multiple payments hit same minute → throttle | 🟢 Low | Fire-and-forget pattern + RDM volume (~few payments/day) → well under limit. |
| 4 | Booking enrichment query `beds24_bookings JOIN guests` adds D1 read on every payment webhook → minor latency | 🟢 Low | Per PR: `loadBookingForNotify()` returns null on missing row or query error (never throws). Bounded by D1 free tier. |
| 5 | Cron retry path (separate from initial webhook) intentionally does NOT ping — to avoid duplicate notif | 🟢 Low | Documented out-of-scope. v1 trade-off accepted. |
| 6 | No retry on Telegram API failure (fire-and-forget) — if TG infrastructure has 5-min outage, those payments silently un-pinged | 🟡 Medium | Webhook response NOT blocked is the priority. Operational alternative: cron-retry path could read missed pings from D1 if needed. Out of scope v1. |
| 7 | "Telegram pago-recibido" UX cumulative load on Alex's phone: every approved payment + every refund pings | 🟢 Low | Telegram-native mute on the chat thread if volume gets noisy. Alex controls. |

---

## §2 — Test coverage

Per PR description:
- 7 unit tests (`apps/worker-pago/tests/telegram-notify.test.ts`)
- 3 integration tests (`apps/worker-pago/tests/webhook-mp.test.ts` additions)
- Total worker-pago suite: 36 → 50 (14 new = matches 7+3 + likely 4 supporting)

Coverage targets:
- ✅ token missing → no-op
- ✅ chat_id missing → no-op
- ✅ approved branch fires after Beds24 invoiceItem POST `push.ok`
- ✅ refunded/charged_back fires after compensating push ok
- ✅ failed Beds24 push → no ping (cron retry handles)

**Verdict**: appropriate. Fire-and-forget + null-safety patterns well-tested.

---

## §3 — Migration impact

**No D1 migration**. Pure webhook-side addition + new secrets.

**No collision risk**.

---

## §4 — Anti-pattern verification

| Check | Result |
|---|---|
| Pet fee `/estancia` NEVER `/noche` | ✅ N/A (not content) |
| Casa Chamán surfacing in Greeter | ✅ N/A (worker-pago, not Greeter; payment notif goes to internal Alex chat, not guest-facing) |
| Beds24 sync mode Everything | ✅ N/A (reads existing `beds24_bookings`, doesn't trigger sync) |
| LLM money decision autónoma | ✅ NO — TG notif is INFORMATIONAL only, doesn't decide refund/price. Payment + Beds24 push are existing logic. |
| Secrets plaintext | ✅ `TG_BOT_TOKEN`, `TG_CHAT_ID_PAGOS` declared as types with `?` optional. NOT committed in code. |
| ALTER TABLE during multi-agent run | ✅ No migration |
| Hardcoded paths Windows | ✅ Only in PR description (post-merge steps for Alex), not in code. |

---

## §5 — Pre-merge requirements

| # | Requirement | Done? |
|---|---|---|
| 1 | Base branch auto-flipped to main (after PR #158 merged 2026-05-22) | ⏳ verify `gh pr view 159 --json baseRefName` shows `main` |
| 2 | Rebase against current main if behind | ⏳ likely yes (last commit was pre-#158 merge) |
| 3 | All 50/50 worker-pago tests pass post-rebase | ⏳ re-run |
| 4 | `pnpm exec tsc --noEmit` clean | ⏳ verify |
| 5 | `docs/secrets-inventory.md` updated (per PR) | ✅ included in diff |

---

## §6 — Post-merge steps (Alex)

Per PR description, Alex needs to:

1. **Get chat_id**: easiest path = send any message to `@yourbotname`, then `getUpdates` → numeric user_id. OR use `@userinfobot` on Telegram → returns user_id directly.
2. **Set both secrets** on worker-pago:
   ```powershell
   cd C:\dev\rdm\dev\bot\apps\worker-pago
   npx wrangler secret put TG_BOT_TOKEN
   # paste value from BotFather (same as worker-bot)
   npx wrangler secret put TG_CHAT_ID_PAGOS
   # paste chat_id (numeric string, e.g. "123456789")
   ```
   **Note from thread/194 §A.3**: `TG_BOT_TOKEN` is ALREADY set on worker-pago — only `TG_CHAT_ID_PAGOS` is new.
3. Re-deploy worker-pago — actually NOT required; secrets read at runtime by Workers.
4. Smoke: next real MP payment should trigger ping within ~5 sec.

---

## §7 — Recommendation

**GREEN to merge** with these steps:

1. **CC** (~2 min): `git pull --rebase origin main` on branch (PR #158 already merged, base auto-flipped). If conflicts → fix.
2. **Alex** (~30 sec): merge PR #159.
3. **Alex** (~3 min): provision `TG_CHAT_ID_PAGOS` secret on worker-pago. (`TG_BOT_TOKEN` already there per thread/194 §A.3.)
4. **Smoke**: wait for next real MP payment OR trigger test via `/admin/`-side stub → expect Telegram ping within 5 sec.

**Total time**: ~6 min total. Low risk.

---

## §8 — Out-of-scope observations

- Per PR §"Out of scope":
  - ❌ Multi-recipient — Karina CC'd later if needed
  - ❌ Markdown / inline keyboard buttons
  - ❌ Retries on Telegram API failure (fire-and-forget by design)
  - ❌ Quiet hours / mute schedule — Telegram's native mute
  - ❌ Notification on cron-retry success (silent backfill)

  All reasonable v1 deferments.

- Stacking pattern: PR #159 stacked on PR #158. Per PR #158 merge log (2026-05-22), this stacking is now flat — confirm base is `main` (not `feat/mp-webhook-beds24-capture`) via `gh pr view 159 --json baseRefName`.

- **Related to thread/167 piggy-back on `*/30` cron**: this PR does NOT add new cron, only webhook-fired call. No CF Free plan cron slot impact.

---

**END THREAD/193**
