# 170 · CC-Bot · Telegram pago-recibido delivered (PR #159, stacked on PR #158)

**Author**: CC-Bot (DoIt session 2026-05-22, follow-up to [thread/169](169-cc-bot-telegram-pago-recibido-spec.md))
**Type**: completion report
**PR**: https://github.com/alexanderhorn6720/rdm-bot/pull/159
**Base**: `feat/mp-webhook-beds24-capture` (PR #158) — stacked
**Branch**: `feat/telegram-pago-notify`

---

## Status

🟢 **PR open, deployed, all tests green**. Stacked on PR #158. When that merges, PR #159's base auto-flips to `main` and is mergeable.

Single commit `b954820` on top of PR #158's 7 commits.

Worker-pago Version `3fad6c7d-3869-405c-933a-ace877c1a0db` deployed — runs in graceful no-op mode (no ping fires) until Alex sets both `TG_BOT_TOKEN` + `TG_CHAT_ID_PAGOS`.

---

## What landed vs thread/169 spec

| Spec item | Status |
|---|---|
| `telegram-notify.ts` module | ✅ |
| `booking-lookup.ts` for D1 enrichment | ✅ (reads `beds24_bookings JOIN guests`, never throws) |
| Wire into webhook-mp approved branch | ✅ fires after `pushMpPayment.ok` only |
| Wire into refund/charged_back (Q4) | ✅ same pattern, isRefund=true prefix |
| Env types | ✅ `TG_BOT_TOKEN?`, `TG_CHAT_ID_PAGOS?` |
| Inventory doc | ✅ Both secrets documented |
| Tests | ✅ 7 unit + 3 webhook integration |
| Deploy | ✅ Version `3fad6c7d`, graceful no-op until secrets set |

## Stat block

| Metric | Spec estimate | Actual |
|---|---|---|
| LOC | 140 | ~330 (incl. tests) |
| Commits | 3 | 1 squashed |
| Tests | 6 | 10 (7 + 3 integration) |
| LLM cost | <$2 | TBD — likely under |
| Wall time | 1-2h | ~30 min CC-side |

---

## What's NOT yet verified

1. **Live Telegram ping** — requires Alex to set the two secrets. Until then notify returns `{ ok: false, skipped: 'no_token' }` silently.
2. **Real-world message format** — only tested in unit tests; first real message may want tweaks (e.g. timezone for arrival, currency symbol position).

---

## Action items (Alex)

### To activate the notifications

1. **Get your Telegram chat_id**:
   - Easiest: send `/start` to `@userinfobot` on Telegram → it returns your numeric user_id directly (e.g. `123456789`)
   - Or: send any message to your existing RDM bot (the one whose `TG_BOT_TOKEN` worker-bot uses), then ping me — I'll fetch it via `getUpdates`

2. **Set both secrets on worker-pago**:
   ```powershell
   cd C:\dev\rdm\dev\bot\apps\worker-pago

   # Same token as worker-bot's TG_BOT_TOKEN (paste from BotFather or .dev.vars)
   npx wrangler secret put TG_BOT_TOKEN

   # Your chat_id from step 1 (stringified numeric)
   npx wrangler secret put TG_CHAT_ID_PAGOS
   ```

3. **No redeploy needed** — Cloudflare Workers secrets are read at runtime.

4. **Smoke**: next MP payment should trigger the ping within ~5s of MP webhook arrival.

### Carry-overs from prior threads still open

- [ ] **thread/168**: register the 2 backfilled $20 payments as manual Beds24 invoice items via `/admin/bookings/86981862` Tab 3 (`transferencia` × 2, notes `MP 159702561933` and `MP 159753179073`)
- [ ] **thread/168**: review + merge PR #158
- [ ] **thread/167** decision: dead-bookings-table-cron hygiene bucket → fix/wontfix/leave?

---

## Anti-patterns checked

- ✅ Workstream = CC-Bot territory (apps/worker-pago only — no apps/web, no worker-bot, no packages)
- ✅ No new D1 schema (reads existing tables)
- ✅ Graceful degrade without secrets — production safety
- ✅ No PII in logs (paymentId + bookingId only, no guest_name/email)
- ✅ Fire-and-forget via `c.executionCtx.waitUntil()` — never blocks webhook response
- ✅ Tests cover happy path, no-token, no-chat, network failure, 4xx, refund variant, integration with webhook flow
- ✅ No mixing buckets — stacked PR pattern, PR #159 doesn't depend on PR #158 features at runtime; they're separable
