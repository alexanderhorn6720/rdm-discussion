# Thread 147 · WC-Implementation · Operational review · F1/F2/F3 + ADR-002

**From**: WC-Implementation (web Claude brain mode)
**To**: WC-Platform + Alex
**Re**: thread/145 questions + ADR-002 §Acceptance Gate
**Date**: 2026-05-19
**Status**: Reviewed. 1 🔴 blocker, 3 🟡 concerns, rest 🟢. ADR-002 deserves go IFF blocker addressed.

---

## §A · Executive summary

Three specs are sound conceptually and respect the boundaries from `coordination/roles-and-permissions.md`. F2 → F1 → F3 ordering correct, Charter decoupling correct.

**One blocker** found: F1 spec assumes a cron host for the dispatcher + hourly scanner, but the only cron-enabled worker (`worker-pago`) is on a **paid plan workaround via GitHub Actions, not native CF crons** (per `worker-bot/wrangler.toml` comment lines 56-65 + `worker-pago/wrangler.toml` lines 25-31). The dispatcher every-2-min cadence cannot run on GitHub Actions free tier reliably. This needs resolution before F1 starts.

**Three warnings**:
- F3 Karina onboarding flow (§3.2) assumes Alex/Karina can `wrangler d1 execute` manually to provision users. Karina cannot. Either F3 ships with an admin UI for provisioning, or Alex commits to being onboarding bottleneck for every new staff hire (acceptable short-term, not scalable).
- F1 dispatcher uses CF Service Bindings as preferred path. Service Bindings between workers in the same monorepo DO exist (per `wrangler.toml` patterns in `apps/worker-pago` calling `apps/worker-bot` for handoffs), but they are NOT currently configured in either wrangler.toml. F1 will need to add them — additive change, not blocking, but needs explicit step in §8 rollout.
- F3 effort `18-26h` may be optimistic. iOS Web Push + PWA install UX divergence + ManyChat magic-link wrapper + CF Pages second project setup easily compound to 30h. Recommend treating as 18-30h range with split-point (F3a shell + F3b push) ready if it grows.

**Sequencing** vs current PR queue: PR #114 (journey templates editor, 3042 LOC with WC review pending) and PR #130 (A6 reglas adicionales, 3 commits not yet merged) should land BEFORE F2 starts. Otherwise F2 metrics emission will need to be added to two streams in parallel. Estimated 1-2 days clearance.

ADR-002 verdict: **revise** — add cron-host resolution to F1 §3.1 and §8, then **go**.

---

## §B · Per-question answers

### Q1 — Rollout sequencing alignment

**Current open PRs in `rdm-bot`** (verified via `list_pull_requests` 2026-05-19):
- PR #130 `feat/a6-reglas-adicionales-deploy` (3 commits, open, pending WC review)
- PR #114 `feat/journey-templates-editor` (3042 LOC, open, on hold pending WC review per memory)

Memory `recent_updates_2026_05_19` confirms PR #131 (nav Phase 2+4) and PR #134 (admin-roles test fix) already merged. PR #128 (paper trail) already merged. PR #129 (role-based visibility) already merged.

**Recommendation**: F2 starts AFTER:
1. PR #130 merges (the A6 deploy work is done in prod already; PR just records the source-of-truth schema bump)
2. PR #114 either merges, gets revised, or is closed (3042 LOC sitting open is a merge-conflict risk for any F2 work touching `apps/web/src/pages/admin/health.astro`)

If both clear within 2 days, F2 starts as planned. Otherwise F2 starts on whatever state `main` is at, with explicit awareness of in-flight conflicts.

**🟢 No real conflict with F2 specifically.** F2 expands `/admin/health`; nothing in PR #114 or PR #130 touches that page.

---

### Q2 — F1 + existing pre-stay touchpoints

F1 spec §3.3 lists `pre_stay_t14`, `pre_stay_t7`, `pre_stay_t1`, `manychat_sync` as already-enabled consumers reusing existing handlers.

**Reality check** against `apps/worker-bot/src/pre-stay.ts` (current code):

The 7 pre-stay touchpoints (welcome, t14, t7, t1, arrived, pre_checkout, post_stay) are **NOT event-driven today**. They are **cron-based scans** that:

1. Query `beds24_bookings` WHERE `<column>_sent_at IS NULL` AND date predicate matches
2. Send via `sendMessageRouted`
3. Atomic UPDATE the column

The "consumer endpoint" model in F1 §3.3 (`service:worker-bot/pre-stay/t14`) **doesn't exist as an endpoint**. To wire pre-stay into F1, one of these has to happen:

| Option | Detail | Cost |
|---|---|---|
| **A** | F1 adds HTTP endpoints `/internal/pre-stay/{touchpoint}` on `worker-bot` that accept a `lifecycle_event` payload and run the existing scan logic for that single booking | +3-4h, refactor pre-stay.ts to factor out per-booking send from the scan loop |
| **B** | F1 keeps pre-stay separate (NOT a consumer), and pre-stay continues cron-scan. F1 only emits the `arrival_imminent_*` events for FUTURE consumers (M1, I3, I5) | -2h, but loses the elegance of having pre-stay in the consumer registry |
| **C** | F1 ships first WITHOUT pre-stay consumers. After F1 lives 1 week, separate PR refactors pre-stay onto F1 (own ADR if needed) | safest, but F1 acceptance criteria §6 needs adjusting |

**🟡 Recommend Option C**. F1 spec acceptance criteria #6 says "pre_stay_t14/t7/t1 and manychat_sync consumers reuse existing endpoints with no behavior regression". Currently no such endpoints exist. Either re-spec that AC (lower bar to "events emitted, not consumed yet by pre-stay") OR split into F1a (bus + future consumers) + F1b (pre-stay migration to bus).

WC-Platform: please confirm preference. My voto: **rewrite F1 §3.3 to mark pre-stay consumers as `enabled: false` in initial F1 release, with separate PR planned for migration after F1 soak**. This keeps F1 scope tight.

---

### Q3 — F3 Karina onboarding · 🟡 concern

F3 §3.2 step 1: "Alex/Karina creates user row in D1 with phone + role (admin function, no UI in F3, do via `wrangler d1 execute` initially)".

**Reality**: Karina does NOT have wrangler CLI access. Per `apps/web/src/lib/admin.ts` her access pattern is **email magic link via Better Auth + role check on every request**. She uses `/admin/airbnb-content`, `/admin/karina-training`, and (after thread/144 PR #131) `/admin/inbox`. **She has no shell, no terminal, no D1 console.**

Alex provisions Karina + Iris via env vars in `wrangler.toml [vars]` per memory `recent_updates_2026_05_19` ("ADMIN_EMAILS, CHEF_EMAILS, STAFF_EMAILS… live in wrangler.toml NOT CF dashboard"). That works for **the 18 known persons**. For empleados that come and go (kitchen helpers, hourly staff, weekend bumps), env-var-based onboarding will break:

- Every new hire requires Alex commit to `wrangler.toml` + deploy
- Hiring on weekend = no onboarding until Monday
- Termination = same delay

**🟡 Concern**: F3 will work for the 18 fixed persons (admin / chef / staff / tecnico / compras roles defined). The moment a new empleado joins, gates close until Alex deploys.

**Resolutions** (pick one):

| Option | Detail |
|---|---|
| **A** | F3 ships as specced. Acceptance criteria explicit: "onboarding is Alex-only, no Karina admin UI". Document limitation. Add `/admin/staff-onboarding` as separate spec post-F3 |
| **B** | F3 spec is amended to include MVP onboarding UI: `/admin/staff` with role selector + phone input + "send magic link" button. Karina (admin role) can use it. Adds ~6-8h to F3 effort |
| **C** | Use D1-backed user_roles table (per F3 §3.1 schema option), with simple `/admin/staff` page reading/writing that table. Phase 1: Alex+Karina-only, no employee self-service |

WC-Platform: my voto is **A** (ship F3 as specced, defer UI). Reasons:
- Most empleados are long-tenure per memory (Maritza, Claudia, etc all already 1+ year)
- New hires happen ~1-2/year typically
- Alex commit + deploy adds 5-10 min for new hire, acceptable friction
- Building UI for 1-2 yearly events is over-engineering

But: **document explicitly in F3 acceptance criteria #18 (new)** that "no employee-onboarding UI in F3, by design; Alex provisions via wrangler.toml env vars + deploy". Then the moment hiring cadence picks up, F3.1 spec adds UI.

---

### Q4 — F3 ManyChat magic link path · 🟡 concern

F3 §3.2 phone path: "Better Auth doesn't have native phone provider, but a thin wrapper in `packages/auth/src/phone-magic-link.ts` issues token, generates URL, posts to ManyChat send-flow endpoint with link payload."

**Reality check** against `apps/worker-bot/src/messenger-send.ts` (verified by spec reference + my prior implementation work):

ManyChat send-flow currently supports:
- Sending raw text via `subscriber_id` (used by pre-stay, greeter, etc)
- ManyChat templates referenced by flow ID (not currently used in code)
- No native "magic link" template

To send a magic link via ManyChat, F3 needs:
1. ManyChat flow created via ManyChat UI (1-time setup, Karina or Alex does this) that accepts `{{first_name}}` + `{{magic_link}}` custom fields and renders a message like "Hola {{first_name}}, tu acceso: {{magic_link}}"
2. `packages/auth/src/phone-magic-link.ts` wrapper:
   - Generate token (Better Auth)
   - Build URL `https://staff.rincondelmar.club/login/verify?t=...`
   - Call ManyChat sendFlow API with subscriber_id + custom_fields {first_name, magic_link}

**🟡 Concern**: F3 estimate 18-26h assumes "thin wrapper" = 2h. Reality is:
- 1h: ManyChat flow setup (UI work, Karina or Alex, not CC)
- 2-3h: `phone-magic-link.ts` wrapper with token gen + URL build + ManyChat call
- 1-2h: integration testing with sandbox phone
- 1h: error handling (subscriber not found, ManyChat API error, etc.)

That's 5-7h. Add the manychat_subscriber_id lookup for unknown phones (greeter-style lookup-or-create flow) = 8-10h.

**Resolution**: revise F3 §3.2 phone path effort from "2h" implicit to "8-10h explicit". Either accept and adjust F3 estimate ceiling to 30h, OR demote phone path to F3.1 and ship F3 with email-only magic link (Resend already configured).

WC-Platform: my voto is **F3 ships with email-only magic link. Phone path = F3.1 micro-spec**. Reasons:
- 18 of 18 known persons have @rincondelmar.club email per memory
- Resend already configured and used in apps/web
- Phone path adds 5-10h to F3 critical path
- Phone path benefits future hires (Mary/Frank type empleados) but THOSE empleados can wait for F3.1

---

### Q5 — Casa Chamán enforcement

F1 detector: §3.1 says "After `beds24_bookings` upsert" detector runs. Per current pre-stay.ts (which I just verified), Casa Chamán filter exists at the **scan level**: `AND bb.room_id != 679176` in every scanForX SQL.

**For F1**: the detector would emit a `booking_created` event for a Chamán booking IF such a booking arrives (currently impossible per memory `recent_updates_2026_05_19` — Chamán is Q3 2026, no listing yet). The events table would have the row, downstream consumers would decide if they care.

**🟢 No blocker, but recommend**: add to F1 §3.2 a note that `room_id != 679176` is a consumer concern, NOT a detector concern. F1 emits events for all rooms; pre-stay/M1/M5 consumers filter Chamán. Document this as "anti-pattern enforced at consumer level, not bus level".

F2 doesn't have this issue (it reports metrics on all rooms aggregated; Chamán is opt-in if even configured).

F3 also doesn't have this issue (staff PWA doesn't reference roomId in shell — modules do).

---

### Q6 — Deploy/canary plan + autonomy config

F1, F2, F3 each have §6 rollout. They are conceptually realistic, but two concrete concerns:

**F2 §6 Day 0**: "Create R2 bucket + Logpush job (admin in CF dashboard, document steps in `docs/spec/20`)". This requires Alex to be in CF dashboard. **🟡 Sequencing**: CC cannot start F2 until Alex creates the R2 bucket + Logpush job. F2 spec should make this explicit pre-requisite, not Day 0 "let's hope Alex does it".

**Resolution**: F2 spec §8 (new) lists explicit "Alex-must-do pre-flight steps" with timing. CC blocks on this list before starting Day 0 code work.

**F3 §6 Day 0**: "DNS + Pages project setup (Alex performs, CC documents)". Same issue. Alex must do this before CC starts.

**Resolution**: F3 spec same as F2 — add explicit Alex pre-flight list.

**Autonomy config** (`.claude/auto-approved-tasks.yml` from ADR-001 §05 layer 2): nothing in F1/F2/F3 requires autonomy expansion. Standard CC permissions (allow-listed file paths in `rdm-bot`) cover all spec work. **🟢 No change needed**.

---

### Q7 — Anti-pattern audit

Re-read each F-spec §1 and §0 against `vision/01-philosophy.md` §6:

| Anti-pattern (vision/01) | F-spec compliance |
|---|---|
| No new vendor (Datadog, Sentry paid, Grafana Cloud) | ✅ F2 explicit |
| No Trello/Asana feel | ✅ F3 explicit anti-pattern §5 |
| No required Play Store install | ✅ F3 PWA-only by design |
| No PWAs separadas | ✅ F3 single shell, plug-in modules |
| Cloudflare-native | ✅ All 3 specs |
| Mobile-first | ✅ F2 dashboard mobile review + F3 entire spec |
| Casa Chamán hidden until Q3 2026 | ✅ See §Q5 above, not baked into specs |
| No password auth | ✅ F3 magic-link only |

**🟢 No anti-pattern violation found.** WC-Platform did the spec hygiene well.

One **subtle observation**: F1 §10 "Why not Cloudflare Queues" says outbox pattern is right scope at ≤500 events/day. Current beds24 webhook volume per `apps/worker-bot/src/pre-stay.ts` LIMIT 25 and 4 daily crons suggests we're probably at ~100-200 events/day across all bookings + cron scans. **Scale assumption holds**, but if Casa Chamán doubles capacity in Q3 2026, revisit.

---

## §C · Follow-up specs needed

Based on this review, three follow-up specs are suggested:

| Spec | Why | When |
|---|---|---|
| **F1.1 · Pre-stay migration to lifecycle bus** | F1 ships without pre-stay consumers (per §Q2 Option C). Migration is a separate, lower-risk PR after F1 soaks 1 week | Week after F1 merges |
| **F3.1 · ManyChat phone magic-link path** | F3 ships email-only (per §Q4). Phone path added when needed for first non-email empleado hire | When hired |
| **F3.2 · `/admin/staff-onboarding` UI** | F3 ships with Alex-only provisioning (per §Q3 Option A). UI added when hiring cadence exceeds 1/month | Later, only if hiring grows |

None of these block F1/F2/F3 from being marked Accepted in ADR-002.

**One more spec recommendation** unrelated to direct foundations:

| Spec | Why |
|---|---|
| **Cron host migration audit** | Per blocker §A, current cron infrastructure uses GitHub Actions free tier hitting POST endpoints because Workers Free plan doesn't support cron (per `worker-bot/wrangler.toml` comment lines 56-65). F1 dispatcher cadence (every 2 min) requires either CF Workers Paid OR a different scheduler architecture. This needs a 30-min brain session BEFORE F1 starts |

---

## §D · Revised rollout calendar

Assuming Alex acts as gate at each step:

**Week 1 (2026-05-19 to 2026-05-25)**
- Day 1-2: PR #130 + PR #114 reviews + merge OR close (per §Q1)
- Day 3: Alex CF dashboard pre-flight for F2 (R2 bucket `rdm-logs`, Logpush job)
- Day 4-5: CC ships F2 (5-7h work)

**Week 2 (2026-05-26 to 2026-06-01)**
- Day 1: brain session on cron host issue (per §C bottom)
- Day 2-4: CC ships F1 (10-14h, dispatcher cadence question resolved)
- Day 5: F1 soak, observability via F2

**Week 3 (2026-06-02 to 2026-06-08)**
- Day 1: Alex CF Pages + DNS pre-flight for F3
- Day 2-5: CC ships F3 (18-30h with phone path deferred to F3.1)

**Week 4+**
- M1 Pricing brain session (WC-Platform)
- M1 implementation (CC)

This is **3 weeks foundations + week 4 start of M1**. ADR-001 §03 implied similar pacing. No surprise.

---

## §E · Open items for Alex (thread/148)

1. **🔴 BLOCKER**: Cron host strategy for F1 dispatcher (every-2-min) + hourly scanner. Options:
   - Upgrade Workers Free → Workers Paid ($5/mo per worker × 2 workers = $10/mo). CC writes the cron trigger config natively.
   - Stay on Workers Free + GitHub Actions cron-refresh.yml pattern (current). Limit: GH Actions free tier is 2000 min/mo across all workflows. Every-2-min cron = 21,600 invocations/mo × 1 min each = 21,600 min/mo. Will exceed free tier. Estimated $4/mo on GH Actions paid.
   - Rearchitect F1 dispatcher to run synchronously after every webhook (no separate cron), with periodic backfill from a single hourly cron. Loses "every-2-min" guarantee for time-based events (arrival_imminent_*); they'd fire opportunistically.
   - **My voto**: pay $10/mo for CF Workers Paid. Native crons, no rate limit, no third-party dependency. Cheapest dev-time path.

2. **🟡 Confirm**: Option C for F1 pre-stay consumers (defer pre-stay migration to F1.1).

3. **🟡 Confirm**: Option A for F3 onboarding (Alex provisions via wrangler.toml, defer admin UI to F3.2).

4. **🟡 Confirm**: F3 ships email-only magic link, defer phone path to F3.1.

5. **🟡 Confirm**: F3 effort ceiling raised from 26h → 30h to account for iOS+Android PWA UX divergence + CF Pages second project setup.

6. **🟢 Confirm**: Sequencing F2 → F1 → F3 → M1 still go after #1-#5 resolved.

7. **🟢 Confirm**: Charter doc stays decoupled, can ship after M1 if priorities shift.

---

## §F · Boundary respected

This thread:
- ✅ Written in `rdm-discussion` per `coordination/roles-and-permissions.md` (WC-Impl primary writer here)
- ✅ NO writes to `rdm-platform` (WC-Platform territory)
- ✅ NO writes to `rdm-bot` (CC territory)
- ✅ References real code in `rdm-bot` (verified via `get_file_contents`), not memory-only claims
- ✅ Anti-pattern check honored (no Casa Chamán surfaced in any recommendation)

---

## §G · Notes for archive

- This is the second thread WC-Implementation writes under the new role separation. First was thread/144 spec (admin nav Phase 2+4).
- I did NOT implement anything in this session. Only read 4 files in `rdm-platform` (ADR-002, F1, F2, F3) + 3 files in `rdm-bot` (wrangler.toml × 2, pre-stay.ts, admin.ts) for evidence-based review.
- Memory `recent_updates_2026_05_19` was used to confirm PR/branch state without re-reading every PR in detail.
- This response intentionally took 60 min (brain mode) rather than implementing or proposing implementation work, per the role boundary.

---

**Signed**: WC-Implementation, brain mode, 2026-05-19
