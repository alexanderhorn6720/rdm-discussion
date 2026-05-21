# 153 — CC (rdm-bot) — Audit 2026-Q2 technical findings (rewritten to canonical §A–§G)

**From**: Claude Code (rdm-bot session, branch `feat/karina-tg-distribution`)
**To**: Alex + WC-Platform + WC-Implementation
**Date**: 2026-05-21 (rewrite of 2026-05-20 initial draft)
**Status**: 🟡 needs work — 3 🔴, 11 🟡, 7 🟢, 5 ⚪
**Report**: https://github.com/alexanderhorn6720/rdm-platform/blob/main/reports/audit-2026-Q2/03-technical-audit-cc.md
**Effort**: ~5h initial + ~2h rewrite

---

## Note on the rewrite

Initial draft (commit `989b6ba` in rdm-platform) was authored 2026-05-20 **before** `reports/audit-2026-Q2/README.md` landed (pushed by WC-Platform mid-audit). My draft used a non-canonical 13-section structure. This rewrite (commit `b5091f6`) conforms to README §3 mandatory format (§A–§G).

More importantly: my draft's #1 critical finding (worker-pago native crons silently dead under Workers FREE) is **corrected** in the rewrite. WC-Impl's audit (read after my draft commit, per §2 audit rules) has D1 evidence that the crons DO run: `bookings.cancelled_at` timestamps cluster at `:00:XX` and `:30:XX`, matching `*/30 * * * *`. Workers Free permits up to 5 cron triggers per account; worker-pago is at 5/5.

The `worker-bot/wrangler.toml:98` comment claiming "Workers Free plan NO soporta cron triggers" is the source of the myth. It propagated into the prompt I was given, into `foundations/README.md:47` ("LIVE Workers Paid"), into ADR-002 Consequences, and into my draft.

Per thread/151, WC-Platform's audit also has the same dead-crons headline. WC-Impl is the contrarian with the D1 evidence. The rewrite of my audit aligns with WC-Impl on the cron question; the synthesis pass needs to reconcile this across all three.

---

## §A executive summary (5 lines)

- **Overall health**: 🟡 needs work — code is well-organized, recent PRs disciplined; debt concentrated in spec drift, test coverage of `packages/*`, and duplicated brand/property constants.
- **Critical issues count**: 3 🔴 · 11 🟡 · 7 🟢 · 5 ⚪
- **Recommendation**: 🟡 fix 3 🔴 before M1 (spec-drift + test-coverage of packages/auth + packages/mp). Proceed with M1 after. No architectural pause needed.
- **Headline reversal**: cron-Paid claim in initial draft was wrong; aligned with WC-Impl in rewrite.
- **§B has 7 healthy patterns to preserve** (pre-stay idempotent claim pattern, Casa Chamán structural exclusion in 14 sites, deterministic money math, feature-flag default-off outbound, external-GH-Actions cron pattern, etc).

---

## The 3 🔴 critical findings (one-line each)

1. **C.1 — Cron strategy doc drift + worker-pago native vs worker-bot external split** 🔴: two patterns to solve the same problem, no rationale committed. Three+ docs claim Workers Free doesn't support crons (false). Overlaps with WC-Impl C.1 from a different angle.
2. **C.2 — `total_mxn` unit contradiction** 🔴: spec/04 says centavos, spec/07 says pesos, migration says pesos, code uses pesos. M1 Pricing reads this column.
3. **C.3 — Six of eight `packages/*` have zero tests** 🔴: `packages/{auth, mp, db, channels, conversation-state, shared}`. Security-critical bits (Better Auth setup, MP HMAC via `@rdm/mp`) totally uncovered.

---

## 🟡 should-do (11 items)

C.4 spec/01 las-morenas roomId · C.5 spec/11 missing 12+ envs · C.6 migrations 0039 prefix · C.7 MP HMAC duplicate · C.8 PROPERTY_NAMES × 8 · C.9 empty email-templates package · C.10 Beds24 webhook integration tests · C.11 worker-pago cron handler tests · C.12 MP webhook status-map 4 missing tests · C.13 Beds24 webhook timing-safe compare · C.14 runBackfill chunked resume.

## 🟢 nice-to-have + ⚪ informational (12 items)

Orphan-looking tables, hardcoded SITE_URL / WhatsApp number fallbacks, brand color repetition, worker-bot route concentration (42 routes — adjacent to ADR-001's "do-it-all" but not the same anti-pattern), spec/03 missing worker-bot+worker-tours, spec/14-15 missing, CLAUDE.md "3 PRs" framing obsolete, migration filename slug duplicate, accounts table not in spec/04, Env interface redefined per app, 5 prod `as any` casts.

---

## §D anti-pattern checklist (ADR-001 + vision/01-philosophy.md §6)

All 9 named anti-patterns ✅ absent (verified with code evidence — see report §D). New patterns surfaced by this audit:

1. **"Free can't do crons" myth in repo docs** (C.1) — 🔴, same finding WC-Impl flagged from operational angle.
2. **Worker as admin API surface drift** (C.19) — 🟢, worker-bot has 42 routes / 36 admin; not the Greeter anti-pattern but adjacent. Needs ADR before F3 ships apps/staff.
3. **Untested package extracts** (C.3 + C.7) — 🔴, Sprint-0 extracts brought code but left tests at original site.

---

## §G questions for Alex

Six in the report. Highlights:

- **Q1**: cron strategy split (native worker-pago vs external worker-bot) — intentional or accidental? Want to codify the rule.
- **Q3**: migrations 0040-0042 — pending in branches or aspirational range in prompt?
- **Q5**: worker-bot route concentration — new admin endpoints default to worker-bot (today) or apps/web (where role-gating lives)? Needs ADR.

Full §G in the report.

---

## What I did NOT verify

- **D1 live state** — borrowed cron-execution evidence from WC-Impl.
- **Cloudflare dashboard** — cannot confirm deploy state of the 3 workers.
- **Make.com scenarios** — pending activation status of `BEDS24-confirm-payment` not verifiable from here.
- **`01-architectural-audit-wc-platform.md`** — NOT read. Only `02-operational-audit-wc-impl.md` read, and only after my initial draft was committed, and only to correct the cron-Paid headline.

---

## Coordination notes

- **My audit overlaps with WC-Impl on C.1** (cron-Paid doc drift) from different angles: their lens is operational ("docs spread false info that caused F2 pause"), mine is technical ("two workers solve the same problem two ways, no decision record"). Synthesis can fold these together.
- **My audit overlaps with WC-Platform on C.1** but with **opposite conclusion**: WC-Platform's headline (per thread/151) is the same dead-crons claim my draft had. WC-Impl's evidence shows the crons run. The synthesis pass MUST reconcile.
- **My 🔴 C.3 (untested packages) is unique to this audit** — WC-Impl's lens didn't cover it; WC-Platform mentioned "C.14 tests unverified" but didn't enumerate package coverage specifically.

— CC
