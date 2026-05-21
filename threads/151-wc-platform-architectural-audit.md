# Thread 151 · WC-Platform · Architectural audit committed

**From**: WC-Platform
**To**: Alex + WC-Implementation + CC
**Date**: 2026-05-21 (Day 0 complete)
**Status**: 🟡 needs work — 4 🔴 critical, 9 🟡, ~25% greenfield delta.

---

## Audit committed

**Document**: https://github.com/alexanderhorn6720/rdm-platform/blob/main/reports/audit-2026-Q2/01-architectural-audit-wc-platform.md

**Effort actual**: ~4h (matches spec §4 estimate).

---

## Executive summary (5 lines)

- **Overall health**: 🟡 — architecture is MORE coherent than expected from prior pessimism. 75% would survive greenfield.
- **Critical issues count**: 4 🔴 (1 production-breaking, 3 architectural inconsistencies)
- **Recommendation**: 🟡 fix N items first → ADR-003 needed re: "Free vs Paid plan + cron dispatch model". 3-5h cleanup unblocks M1.
- **Headline**: The system is `Workers Free + GH Actions cron externa` by Alex's prior decision documented in worker-bot/wrangler.toml. worker-bot embraces this with 19 GH Actions workflows. **worker-pago forgot**: it has 5 crons in wrangler.toml that have never run since deploy. This is the largest single coherence gap.
- **§B has 10 healthy patterns to preserve** — including `/admin/health` excellence, Beds24 3-layer integration, Greeter v4/v5 canary infrastructure, Better Auth role gating.

---

## The 4 critical findings (one-line each)

1. **C.1 — worker-pago dead crons** 🔴: 5 native crons configured but Free plan blocks them. Revenue + UX impact ongoing.
2. **C.2 — Duplicate migration 0039** 🔴: `0039_audit_log.sql` + `0039_rules_link_clicks.sql` collision. One likely orphan in prod D1.
3. **C.3 — Make.com residue** 🔴: `MAKE_CONFIRM_WEBHOOK_URL` still called in worker-pago/crons.ts despite Make sunset directive.
4. **C.4 — F2 spec heartbeat duplication** 🔴(spec only): F2 proposes `cron_heartbeats` table, but `apps/worker-bot/src/heartbeat.ts` already implements via `bot_config` (migration 0023). F2 would duplicate.

Severity 🟡 items (9 total): C.5 Casa Chamán scattered hardcode, C.6 worker-bot/index.ts 90KB, C.7 single Telegram channel, C.8 plaintext STAFF_PROX_RESERVAS_PASS, C.14 tests unverified.

Severity 🟢 (4 items): documentation file placement, data/ dir inspection, .mcp.json review, Service Binding optimization.

---

## What this means for foundations specs

### F2 must be revised

F2 spec was authored 2026-05-20 with two now-false assumptions:
- Logpush available (requires Paid plan)
- New `cron_heartbeats` table needed (already exists as `bot_config`)

**Revision needed (post-audit synthesis)**:
- §3.1 Logpush → defer to F2.2 micro-spec OR contingent on Paid upgrade
- §3.3 `cron_heartbeats` schema → drop migration 0042, use existing `bot_config`
- §3.2 WAE → keep, but verify Free plan quota
- §3.4 Telegram 2-channel routing → keep (still good)
- §3.5 LLM cost panel → keep
- Net effort F2 likely drops from 6-9h to 3-5h

### F1 partially affected

- F1 dispatcher cron `*/2 min` + hourly scanner — affected by C.1 plan finding
- If Paid: works as designed
- If Free: needs to convert to GH Actions cron pattern (3-4h additional effort)

### F3 unaffected

F3 (apps/staff PWA) doesn't depend on Cron Triggers or Logpush. Email-only magic link uses Resend (works on Free). VAPID push doesn't need Paid. F3 spec stands as-is.

### M1 informed but not blocked

- Audit recommendation: greeter v4/v5 canary infrastructure is exemplary, reuse pattern for M1 Pricing.
- audit_log table presence + F1 events bus design both validated against current state.

---

## 7 questions for Alex (in §G of audit)

Need answers to finalize recommendations. Critical:

1. **C.1 resolution**: Workers Paid upgrade ($5/mo) — yes/no/conditional?
2. **C.2 verification**: Run `wrangler d1 migrations list rincon --remote` and report which 0039 is applied.
3. **C.3 Make status**: Is the Make.com scenario for `MAKE_CONFIRM_WEBHOOK_URL` online or disabled?

Rest can wait for synthesis.

---

## Day 0 status

| Auditor | Status | Output |
|---|---|---|
| **WC-Platform** | ✅ Done | `01-architectural-audit-wc-platform.md` |
| **WC-Implementation** | ⏸️ Awaiting Alex trigger | `02-operational-audit-wc-impl.md` (pending) |
| **CC** | ⏸️ Awaiting Alex trigger | `03-technical-audit-cc.md` (pending) |

When Alex wakes up and pastes instructions in WC-Impl + CC sessions, they run their audits in parallel. Independence: neither reads `01-*` until they've committed their own. I'll write `04-synthesis.md` Day 2 after all 3 land.

---

## What I did NOT find

A few things I was prepared to flag that came back clean:

- **No Datadog / Sentry / Grafana paid tier imports**. Stack discipline holds.
- **No LLM in money decisions**. worker-pago/crons.ts is pure arithmetic + state machine. booking.ts uses template `buildSuccessReply` for confirmations.
- **No Casa Chamán pre-Q3 references** in active code (the `ACTIVE_ROOM_IDS` filter is correct, even if the pattern is fragile per C.5).
- **No "Greeter do-it-all"**. Clear Greeter → Booker handoff via `active_agent` state.
- **No PWAs separadas**. None exist yet — when F3 lands it'll be single `apps/staff`.

These are good news. Architecture has integrity in the places that matter most.

---

## My honest take

Going in I was expecting a lot worse. Alex's "fue hecho poco a poco, y ahora veo las fallas" framing primed me for a much deeper rebuild. The truth is more nuanced: the **mechanical layer** (D1 schema, worker boundaries, integration patterns) is solid. The **gaps are in coherence** — worker-pago not following worker-bot's plan pattern, F2 spec not noticing existing infrastructure, duplicate migration filenames.

These are all fixable in 3-5h of focused cleanup. The audit was worth doing, but the "let me rewrite half the system" reflex is not warranted.

That said: C.1 (worker-pago dead crons) has been silently costing revenue for weeks. That alone justifies the audit timing.

---

**Signed**: WC-Platform, 2026-05-21 04:00 MX

Next post: thread/154 (synthesis) after WC-Impl + CC commit theirs.
