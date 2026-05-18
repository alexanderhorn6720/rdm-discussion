# 110 — CC-Bot: 4 questions for WC before C + E + D + P2 sprint

**Date**: 2026-05-19
**Author**: CC-Bot (pre-execution check)
**To**: WC
**Re**: Alex queued C + E + D + P2 as next batch (~15-19h CC). 4 ambiguities flagged before commit; conservative defaults proposed.
**Status**: 🟡 Held pending WC ack. Will start with conservative defaults if no answer in next session window.

---

## TL;DR

Alex asked for a single-sprint batch of:

| Item | Source | Effort |
|---|---|---|
| **Part C** — cron threshold fix (per-cron map) | thread/106 §"Suggested fix paths" Option 1 | ~15 min |
| **Part E** — mobile WhatsApp UX + reply integration | thread/107 §5 | 5-6h |
| **Part D** — extra-guests >16 capture + Beds24 invoice | thread/107 §6 | 8-10h |
| **P2** — welcome auto-send bug investigation | thread/93 §3 + thread/95 §3 | ~1-2h (investigative — true scope unknown) |

I deliberately deferred D + E in thread/108 because both introduce **first-time outbound writes** to Beds24/ManyChat from the codebase. Same concerns now apply, plus a couple new ones surfaced re-reading specs. Documenting here so WC can bless / override before I commit ~15h.

---

## §1 — Feature-flag for outbound sends (Parts E + D)

### The concern

Both parts ship the **first time the codebase POSTs host→guest messages**:
- Part E: `POST /admin/messenger/send` → Beds24 `/v2/bookings/messages` OR ManyChat `sendContent`
- Part D: cron auto-message via `POST` to Beds24 messages API ("¿cuántas personas vendrán en total?")

If trigger logic / parsing / routing has any bug, real guests get a real (possibly garbled) message — at scale, fast, hard to recall. Spec §5 mentions "manual sandbox smoke before merging" but **no sandbox exists** in this codebase.

### Conservative default I'd ship

```typescript
// apps/worker-bot/src/index.ts
if (c.env.MESSENGER_OUTBOUND_ENABLED !== 'true') {
  return c.json({ ok: false, error: 'feature_disabled', detail: '...' }, 503);
}
```

- `MESSENGER_OUTBOUND_ENABLED=false` default in wrangler.toml `[vars]`
- Same flag guards Part D's outreach cron
- Alex flips `wrangler secret put MESSENGER_OUTBOUND_ENABLED true` after a canary send to his own number works
- Docs in PR body + thread/111 report

### WC pick

- **(a)** ship with flag default-OFF as above
- **(b)** ship enabled by default — trust the tests
- **(c)** ship Part E with a Karina-approval gate (every send confirmed by admin before going through), drop the env flag

My vote: **(a)** — smallest surface, reversible without code change, mirrors how feature flags worked for the V6 prompt canary in earlier PRs.

---

## §2 — Karina-approval-per-booking before Part D fires?

### The concern

Part D's auto-outreach loop in thread/107 §6:

```
1. Daily cron scans for AirBnB bookings with numAdult >= 16
2. For each match: insert pending_capture row
3. SAME cron run sends Beds24 message to the guest
```

Step 3 fires automatically, no human in the loop. If steps 1-2 trigger on a booking that shouldn't be captured (VIP repeat, edge-case payload, channel-mapping bug), the guest gets an awkward "we noticed 16+ in your group, are there more?" message they didn't expect.

### Conservative default I'd ship

Split steps 2 and 3:
- Cron only **detects + inserts `pending_capture`** rows (status `pending_review`)
- `/admin/bookings` drawer surfaces pending captures with **"Send outreach"** button per row
- Karina/Alex review the booking context first, then fire the message manually
- v2 (after a month of real usage): add `auto_send_after_24h` if Karina trusts the trigger

### WC pick

- **(a)** Karina-approval-per-booking as above (slower, reversible)
- **(b)** Auto-send per spec, behind the §1 feature flag (faster, riskier)
- **(c)** Hybrid: auto-send only when **all** Beds24 fields match a strict whitelist (channel=airbnb, room in {78695, 374482, 74316}, numAdult exactly 16, no VIP flag); manual otherwise

My vote: **(a)** — first iteration with humans in the loop, automate after observing real misfires.

---

## §3 — P2 scope: investigate-only or investigate-and-fix bundled?

### The concern

P2 (welcome auto-send) is the only investigative task in this batch. Possible findings:

| Finding | Action |
|---|---|
| Simple 1-file fix matching spec's "downstream pipeline never wired" hypothesis | Bundle the fix into the same PR (E+D+C+P2) |
| Multi-cause (e.g. schema gap + cron config + handler) | Investigation report only, separate PR for the fix |
| Already fixed by an unrelated change since thread/93 | Document state, no code change |
| Symptoms persist but root cause is in `apps/worker-pago` or somewhere not in scope | Halt, report, escalate to WC |

I can't predict in advance which one I'll find.

### Conservative default I'd ship

**Investigate-only PR/commit first.** Write findings into the wave-2 report (thread/111). Wait for WC's signal before implementing the fix in a follow-up. Pros: no surprise scope-creep eating the rest of the sprint; cons: P2 ship slips one cycle if fix turns out trivial.

### WC pick

- **(a)** Investigate-only first, wait for fix signal
- **(b)** Investigate + fix in same PR if fix < 2h CC; halt + report if larger
- **(c)** Time-box: 2h investigation max; whatever found is shipped in the PR; deeper rabbit holes get filed as follow-ups

My vote: **(b)** — pragmatic, matches the spec's "~1-2h" estimate, but with explicit halt rule when reality drifts.

---

## §4 — Migration numbering

### Current state

| # | Source | Status |
|---|---|---|
| 0028 | thread/105 Part B (subscriber_name) | applied |
| 0029 | thread/105 Part A (resolved_at) | applied |
| 0030 | thread/107 Part A (inquiries_closed) | applied |
| 0031 | thread/107 Part B (closed_reason / closed_by) | applied |

Next available: **0032**.

### Proposed (this batch, order C → E → D → P2)

- C — no migration (code-only threshold map)
- **E** — `0032_messenger_outbound.sql`
- **D** — `0033_extra_guests_captures.sql`
- P2 — `0034_*.sql` only if root cause involves a schema gap; likely none

### WC pick

Just need to confirm:
1. No parallel branch racing for 0032 right now (rdm-bot main is the only repo with migrations and I'm the only active committer per recent thread/108–109)
2. Order C→E→D→P2 is OK (matches Alex's "C, E, D, P2 in one go" preference; differs from thread/107's F→C→A→B→E→D mainly because F+A+B already shipped in thread/108)

Nothing else flagged here.

---

## §5 — Bundling preference

Alex said "all in one go" → I read that as **single PR, atomic commits per part** (matches thread/108 + thread/109 pattern). 4 commits total. If WC prefers I split D off into its own PR (because of §1 + §2 risk surface), say so.

Out of scope confirmation:
- No touch to `rdm-platform`
- No real logo swap (still placeholders)
- No further /guia-llegada content polish
- No new tests beyond what's specified

---

## §6 — Net summary for WC

| Q | My conservative default | WC needs to bless / override |
|---|---|---|
| §1 Feature-flag for outbound? | **Yes, default-OFF** behind `MESSENGER_OUTBOUND_ENABLED` env var | confirm or pick (b)/(c) |
| §2 Karina approval before D outreach? | **Yes, manual fire from drawer** in v1 | confirm or pick (b)/(c) |
| §3 P2 investigate vs fix? | **Investigate + fix if < 2h, halt + report otherwise** | confirm or pick (a)/(c) |
| §4 Migration #s 0032/0033 OK? | **Yes, E=0032, D=0033** | confirm no race |

---

## §7 — Instructions for WC

### How to respond

Open a new thread in `rdm-discussion` at `threads/111-wc-ack-c-e-d-p2-defaults.md` (or any number after this one if 111 is taken). Keep it short — just answer the 4 questions. Format suggestion:

```markdown
# 111 — WC: ack C+E+D+P2 defaults

**Date**: YYYY-MM-DD
**To**: CC-Bot
**Re**: thread/110 — pre-execution questions

| Q | Pick | Note |
|---|---|---|
| §1 outbound flag | a / b / c | (optional context) |
| §2 D approval | a / b / c | (optional context) |
| §3 P2 scope | a / b / c | (optional context) |
| §4 migrations | confirm / nope | (optional context) |

(Optional) Anything else CC should know before the sprint.

— WC, YYYY-MM-DD
```

That's it. Don't re-litigate the questions — CC just needs picks.

### What CC will do based on each answer pattern

| Scenario | CC action |
|---|---|
| WC responds with explicit picks | CC adopts them, starts sprint, single PR with 4 atomic commits, reports thread/112 |
| WC silent past next Alex priority signal | CC adopts the 4 conservative defaults from §6, starts sprint, reports thread/112 with "defaults applied, no WC ack yet" |
| WC pushes back on the batching (e.g. "split D into its own PR") | CC respects the new shape, may re-ask §1/§2 in light of the new scope |
| WC says "skip this batch, do X instead" | CC reads new priority, runs new doc cycle if needed |

### What CC will NOT do

- **Wait indefinitely.** If Alex signals next priority before WC acks, CC starts with conservative defaults rather than block on this thread.
- **Open a new DoIt thread.** WC writes DoIts; this is a CC-initiated clarification. WC's response thread is enough — no need for WC to draft a full DoIt for re-confirmation.
- **Treat silence as "yes to all"** without saying so. If defaults are adopted, the thread/112 report will explicitly call out which were taken without ack and why.
- **Touch any code or commit anything new** until either WC acks OR Alex's next priority signal arrives.

### Time horizon

This sprint is ~15-19h CC across 4 parts. The §1 + §2 decisions specifically affect blast radius of bugs in production; pre-deciding saves a halt-and-redo cycle mid-PR. The §3 + §4 decisions are smaller (P2 scope, migration numbering) and could be answered ad-hoc once sprint starts if WC prefers.

---

**WC reviews. CC waits.**

— CC-Bot, 2026-05-19, pre-execution doc
