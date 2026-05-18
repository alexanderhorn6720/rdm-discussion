# 119 — WC: Pre-stay notifications MVP spec ready

**Date**: 2026-05-18
**Author**: WC (brain deep)
**To**: CC-Bot (executor when ready) + Alex (approver/canary)
**Re**: Alex objective "todos los huéspedes que arriven en próximas 4 semanas reciben pre-arrival info" + ↓ workload Alex + handoff a Karina
**Mode**: brain deep → spec doc complete
**Status**: 🟢 Spec ready. Awaiting CC-Bot capacity (after thread/115 guests resync + any current queue).

---

## TL;DR

Spec doc shipped: `cc-instructions-bot/2026-05-18-pre-stay-notifications-mvp.md` (7 secciones + 3 appendices).

| Metric | Value |
|---|---|
| Estimated effort | 35-50h CC across 4 atomic PRs (A1-A4) |
| Universe (verified D1) | **19 active bookings** in next 4 weeks |
| Touchpoints v1 | welcome + T-7 + T-1 (drop T-3 chef + T-0 day-of) |
| Channels | Beds24 messages (OTA) + ManyChat (direct). NO email |
| New infra cost | 1 migration (0034), 1 module + templates, 3 crons, 4 admin endpoints |
| Reuse infra | Part E `sendMessageRouted` + `MESSENGER_OUTBOUND_ENABLED` flag + `messenger_outbound` audit + welcome-auto-send detection pipeline (drains 10 existing pending_welcomes rows) |
| Canary path | 0% → Alex sandbox (3 sends) → catch-up 6 real (Karina supervising) → autonomous crons rolling |

---

## Why now

Sprint C+E+D+P2 canary closed 2026-05-18 (Beds24 msg ID 148091343, audit `delivery_status='sent'`). Outbound infra **validated end-to-end in prod**. Pre-stay piggybacks the same plumbing — no new flag, no new sender, no new audit table.

Welcome auto-send detection pipeline has been running for months and queueing rows in `pending_welcomes` (10 rows status='rejected'). It's NOT a bug — the outbound wire was always deferred. Part E shipped that wire. Wire-up is the cheapest first PR (A2).

---

## PR sequencing (CC-Bot autonomous)

| PR | Scope | Effort | Independent shippable? |
|---|---|---|---|
| **A1** | Migration 0034 + `pre-stay.ts` skeleton + 24 templates + template unit tests | 8-12h | ✅ Yes (templates lint clean, no runtime) |
| **A2** | scanForWelcome + wire welcome-auto-send → sendMessageRouted + drains 10 pending rows + tests | 8-12h | ✅ Yes (welcome only, T-7/T-1 still inactive) |
| **A3** | scanForT7 + scanForT1 + cron dispatchers + wrangler.toml + GHA workflows + tests | 8-12h | ✅ Yes (all 3 touchpoints live, no admin UI) |
| **A4** | Admin endpoints + web proxy + drawer buttons + `/admin/pre-stay` page + catch-up + tests | 10-14h | ✅ Yes (closes Karina workflow) |

Total: **35-50h CC**.

CC-Bot picks up when current queue (thread/115 guests resync + any wave items) clears. **Not urgent first** — spec is durable + dated.

---

## Alex actions required

Before A4 lands:

| # | Action | When |
|---|---|---|
| 1 | Apply migration 0034 to prod D1 | After A1 merge |
| 2 | Deploy worker post-A2 merge | After A2 |
| 3 | Verify GitHub Actions cron workflows scheduled | After A3 |
| 4 | Smoke test admin endpoints (curl + flag OFF) | After A4 |
| 5 | Canary: flip `MESSENGER_OUTBOUND_ENABLED=true`, send 3 to Alex sandbox bookings | Post A4 smoke |
| 6 | Catch-up dry-run, then real run with Karina supervising | Post canary |
| 7 | 30-min walkthrough with Karina on drawer + skip button | Post catch-up |

---

## Closed decisions (won't re-litigate)

16 decisions listed in spec §3. Highlights:

| # | Decision |
|---|---|
| C1 | Multi-channel WA + Beds24, NO email (Alex 2026-05-18) |
| C5 | Templates hardcoded TS module v1 (no R2/KV indirection) — velocity over flexibility |
| C6 | 3 touchpoints v1 only (welcome, T-7, T-1). T-3 chef + T-0 day-of deferred v2 |
| C7 | Catch-up manual via admin endpoint, not auto on deploy — safety |
| C11 | NO LLM personalization v1 — determinism + cost |
| C12 | Karina can skip per booking without escalating Alex — handoff objective |

---

## Out of scope flagged

15 items in spec §2.2. Most important deferred:

| # | Item | Reason |
|---|---|---|
| N1 | T-3 chef menu request | Property-specific complexity; v2 |
| N3 | In-stay touchpoints | Client Bot Phase A separate scope |
| N4 | Reply handling | Humans via `/admin/inbox` (existing) |
| N7 | LLM personalization | After templates validated |
| N12 | Vectorize index runtime query | CC-Data scope (Appendix A) — parallel |
| N13 | OTA-specific templates | Generic OK v1 |

---

## Risks tracked (15 in spec §7)

Top 3 by impact × probability:

| # | Risk | Mitigation |
|---|---|---|
| R4 | Wrong template per property | Slug derived from `ROOM_INFO[room_id]`; renderTemplate throws on missing |
| R9 | Casa Chamán surfaces accidentally | Explicit `room_id != 679176` SQL filter + template lookup throws |
| R13 | Template typo/dead link at scale | All templates reviewed Alex+Karina pre-launch; flag flip rollback |

---

## Vectorize tail (Appendix A spec doc, paralelo)

Not pre-stay dependency. Status: 17k embeddings pending upsert, index not created, bot doesn't consume yet.

Effort total: 5 min Alex (scoped CF API token creation) + 2-3h wall CC-Data background. Handoff doc already exists at `cc-instructions-data/2026-05-16-vectorize-handoff.md`.

If Alex wants closed: create token, hand off to CC-Data session, ~30 min total Alex involvement.

---

## What I'll do next

- Stand by for Alex pick on next move
- Available for spec tweaks if Alex/CC-Bot find gaps during A1-A4 execution
- Watch CC threads for updates and reconcile if drift

**Pre-stay spec ready for CC-Bot. Atomic PR sequence A1→A4. Canary playbook detailed. 4-week objective traceable to Definition of Done §6.**

— WC, 2026-05-18
