# 168 · CC-Bot · MP webhook → Beds24 capture delivered (PR #158)

**Author**: CC-Bot (DoIt session 2026-05-22, follow-up to [thread/167](167-cc-bot-mp-webhook-beds24-capture-followup.md))
**Type**: completion report
**PR**: https://github.com/alexanderhorn6720/rdm-bot/pull/158
**Branch**: `feat/mp-webhook-beds24-capture`

---

## Status

🟢 **PR open, deployed, smoke green on worker-pago `/health`**. Waiting on Alex to (a) review + merge, (b) run live MP payment smoke + verify Beds24 row.

5 semantic commits:

| SHA | Message |
|---|---|
| `6d7c503` | chore(migrations): claim 0045 stub — mp_payments |
| `8565afa` | feat(worker-pago): 0045_mp_payments table + Beds24 invoiceItem capture module |
| `e22477b` | feat(worker-pago): webhook-mp b24- flow + mpPaymentRetry cron |
| `20dffd7` | docs(secrets-inventory): MP_ACCESS_TOKEN in apps/web Pages + Pages secret guide |
| `b3e87ff` | fix(worker-pago): piggy-back mpPaymentRetry on */30 slot (CF Free 5-cron cap) |

---

## Scope delivered vs. thread/167 proposal

| Proposal item | Status |
|---|---|
| 1. webhook-mp refactor for `b24-<id>` | ✅ |
| 2. `beds24-payment.ts` module | ✅ |
| 3. D1 audit table `mp_payments` | ✅ migration 0045 applied to prod |
| 4. Two-layer idempotency (KV + D1) | ✅ + third defensive layer (`beds24_push_status='ok'` short-circuit on replay) |
| 5. Status handling (approved/refunded/charged_back/pending/etc.) | ✅ |
| 6. Tests | ✅ 21 new cases (8 unit + 13 integration); 36/36 worker-pago green |
| 7. Deploy | ✅ migration applied + worker deployed (Version `4e2dc3a5`) |
| 8. Inventory update | ✅ MP_ACCESS_TOKEN row + Pages secret guide |

## Deviations from proposal

- **Q3 retry cron**: Proposed `*/15`. Free plan caps at 5 cron triggers and we were at 5 — added a 6th and CF rejected the schedule update (error 10072) AFTER the worker code uploaded. Piggy-backed `mpPaymentRetry` on the existing `*/30` slot via `Promise.allSettled([expireHolds, mpPaymentRetry])`. Retry cadence now 30 min instead of 15. Still well within 5-attempt × 30min = 2.5h recovery window.
- **D1 idempotency**: Proposal said "skip if row exists". Implemented as upsert (INSERT on first arrival, UPDATE status-only on subsequent) so refund/charged_back flows correctly update the same row's status without re-INSERT collision.

## Defaults I committed without explicit Alex sign-off (per thread/167 "if no objection")

- Q1 — kept `external_reference='b24-<id>'` (raw beds24_booking_id, no extra UUID indirection)
- Q2 — no `status='confirmed'` flip from our side; trust Beds24's own balance math
- Q4 — no Telegram alert on >5 retries (`/admin/issues` cockpit handles manual recon)

If any of these are wrong, ping in PR #158 thread and I rework.

---

## What's NOT yet verified (your move, Alex)

1. **Live end-to-end smoke** — only deploy + `/health` 200 confirmed by CC. The actual MP → Beds24 round-trip requires a real card payment. The 7 post-merge smoke items are in the PR body.
2. **The $20 from earlier today** — paid at ~05:30 UTC against the OLD worker-pago (last deployed 2026-05-09). New worker deployed at ~04:45 UTC of this session (the deploy you see now). Since the $20 webhook hit the OLD code and got silently dropped, that payment never made it to Beds24. Backfill options:
   - **(a)** Refund the $20 in MP panel — cleanest since it was a test
   - **(b)** Manually register `efectivo` $20 in Tab 3 with description `MP TEST 2026-05-22` so Beds24 mirrors reality

---

## Cost report

| Metric | Spec estimate | Actual |
|---|---|---|
| LOC | 250 | ~520 (incl. tests + doc) |
| Commits | 4-5 | 5 |
| Tests | 8-10 | 21 (8 unit + 13 integration) |
| LLM cost | <$3 | TBD — likely under |
| Wall time | 4-6 h | ~1 h CC-side (excludes Alex's MP credentials debugging from earlier today, which was its own thread) |

---

## Decisions pending

- [ ] **Alex**: review + merge PR #158
- [ ] **Alex**: run 7 smoke items in PR body to confirm live MP → Beds24 round-trip
- [ ] **Alex** (housekeeping): refund or manually-capture the $20 from this morning's smoke
- [ ] **WC** (optional): pick up the dead-bookings-table-cron hygiene bucket if you want me to fix `expireHolds` et al. so they actually run against `beds24_bookings`. Or close as wontfix if those crons are intentionally inert until the hold-flow returns.

---

## Anti-patterns checked (CLAUDE.md self-review)

- ✅ Pet fee, Casa Chamán, sync mode — none touched
- ✅ No plaintext secrets in diff (verified via `git diff | grep -iE 'token|secret|key|password'`)
- ✅ Migration via atomic claim script
- ✅ Workstream = CC-Bot territory (worker-pago + migrations + docs/secrets-inventory). Did not touch worker-bot, worker-tours, apps/web, packages/.
- ✅ Single PR (not multi-PR)
- ✅ Bucket size: 520 LOC fits the 200-2000 guideline
- ✅ Tests cover edge cases (KV dedup, D1 dedup, refund-without-prior-push, 0-amount defense, malformed external_ref)

