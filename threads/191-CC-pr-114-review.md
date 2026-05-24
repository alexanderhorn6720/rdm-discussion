---
thread: 191
author: CC
date: 2026-05-24
topic: pr-114-review
mode: brain
status: open-for-alex-vote
related: [114, 184]
deliverable: PR #114 review with merge recommendation
---

# Thread/191 — PR #114 Review: Journey Templates D1-Override Editor

**Subject**: [PR #114 — feat(journey): D1-override editor for journey templates](https://github.com/alexanderhorn6720/rdm-bot/pull/114)
**Branch**: `feat/journey-templates-editor`
**Stats**: +3042 / −5 lines, 15 files changed
**Recommendation**: ⚠️ **HOLD — migration slot collision blocker**. Fix-and-merge: ~15 min CC + Alex deploy.

---

## §0 — Summary

PR adds a D1 override layer over the 56 hardcoded journey/pre-stay TS templates (7 touchpoints × 4 properties × 2 langs). Empty table = zero behavior change. One row overrides for that cell. Karina-editable via `/admin/journey/templates` UI without git push.

Architecture is sound: TS literals stay canonical (testable fallback), D1 layered on top with KV cache + 5-min TTL + invalidation on save, x-admin-secret gated. UI has line-by-line diff, reset-to-inline, char counts.

---

## §1 — Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | **Migration `0039_journey_template_overrides.sql` COLLIDES with existing `0039_audit_log.sql` on main** | 🔴 BLOCKER | Renumber to next free slot. Per [thread/186](./186-CC-f2-migration-remap.md): 0046 = cost_telemetry is latest applied. PR #114 should renumber to `0047` (if it merges before F2 ship) OR use `scripts/new-migration.sh` at re-target time. |
| 2 | KV cache 5-min TTL window: Karina saves → up to 5 min until cron-scan reads new value | 🟡 Medium | Spec says KV invalidated on every save/delete (per PR description). Verify in code: `journey-template-overrides.ts` invalidates `KV.delete(cacheKey)` on POST/DELETE |
| 3 | UNIQUE(touchpoint, property_slug, lang) — enforces single override per cell. Race condition: two admins editing same cell concurrently → last-write-wins, no merge UI | 🟢 Low | Acceptable; admin = Alex + Karina, low concurrency. |
| 4 | Inline template diff calc is "trivial line-by-line, not real LCS" per code comment — for short templates fine, but if Karina pastes a wholesale rewrite, diff looks chaotic | 🟢 Low | Documented in code. Acceptable for MVP. |
| 5 | `renderWithBody` uses caller-supplied body — must do identical placeholder substitution as `renderTemplate`. If they diverge → silent miscompute | 🟡 Medium | Tests cover: 23 unit + 5 scan/send/catch-up integration. Spot-check `renderWithBody` and `renderTemplate` share the same placeholder regex. |
| 6 | x-admin-secret bridge via web proxy (`/api/admin/journey/templates/`). Browser never sees secret — but if Alex/Karina session is hijacked, attacker can edit templates | 🟢 Low | Standard isAdmin guard; same risk surface as all admin endpoints. |

---

## §2 — Test coverage assessment

Per PR description:

| Layer | Coverage |
|---|---|
| `apps/worker-bot/` | 748 pass (706 baseline + 42 new): 23 override layer unit + 14 worker endpoint integration (auth + KV invalidation) + 5 scan/send/catch-up override-applied integration |
| `apps/web/` | 326 pass (no regressions; web layer is pure proxy) |
| typecheck | clean in worker-bot; web has 5 pre-existing errors UNRELATED to this PR (RESEND_API_KEY typing, reviews-api.test.ts) |
| build | both apps succeed |

**Verdict**: comprehensive. 42 new tests for the override layer is appropriate scope.

**Gap identified**: no E2E test for the UI flow (Karina opens editor → modifies → saves → next scan picks up new body). This is acceptable for MVP — manual smoke test post-merge is sufficient given the auth-gated, low-risk nature.

---

## §3 — Migration impact

PR ships `migrations/0039_journey_template_overrides.sql`:

```sql
CREATE TABLE journey_template_overrides (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  touchpoint TEXT NOT NULL,
  property_slug TEXT NOT NULL,
  lang TEXT NOT NULL,
  body TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  updated_by TEXT NOT NULL,
  UNIQUE(touchpoint, property_slug, lang)
);
CREATE INDEX idx_journey_overrides_key ON journey_template_overrides(touchpoint, property_slug, lang);
```

### Migration concerns

1. **🔴 Slot collision**: `0039_audit_log.sql` exists in main from 2026-Q1. wave-1-T2 (PR #140 merged 2026-05-21) renumbered migrations to fix earlier conflicts — PR #114 was branched 2026-05-18 (before #140) and never rebased. Migration MUST be renumbered before merge.
2. **Schema shape**: `id` is AUTOINCREMENT — fine. `UNIQUE(touchpoint, property_slug, lang)` provides upsert key. Index duplicates UNIQUE — Cloudflare D1 typically uses UNIQUE as the implicit index, so the explicit `CREATE INDEX` is redundant but not harmful. **WC preliminary recommend**: drop the explicit index (UNIQUE already covers).
3. **Migration is additive**, no destructive change to existing tables. Rollback = drop the new table (acceptable).

### Recommended fix

```bash
cd c:/dev/rdm/dev/bot
git checkout feat/journey-templates-editor
git pull --rebase origin main           # pulls 0040-0046 into branch
git mv migrations/0039_journey_template_overrides.sql migrations/0047_journey_template_overrides.sql
# Optionally: remove the redundant CREATE INDEX line
git add migrations/
git commit -m "fix(migration): renumber to 0047 to resolve collision with main"
git push origin feat/journey-templates-editor
```

Then re-test: `wrangler d1 migrations apply rincon --local`.

---

## §4 — Pre-merge requirements

| # | Requirement | Done? |
|---|---|---|
| 1 | Migration renumbered to next available slot | ❌ NO |
| 2 | Re-rebase against current `main` | ❌ NO (last commit on branch ~2026-05-18) |
| 3 | All tests still pass post-rebase | ⏳ pending step 1+2 |
| 4 | `pnpm exec tsc --noEmit` clean | ✅ (per PR description, baseline 5 errors UNRELATED) |
| 5 | Apply migration to remote D1 BEFORE merge | ⏳ Alex manual: `pnpm --filter worker-bot exec wrangler d1 migrations apply rincon --remote` |
| 6 | Deploy worker-bot after merge | ⏳ Alex manual per CLAUDE.md |
| 7 | Smoke test: Karina edits one template → cron-scan picks new body within 5 min | ⏳ post-deploy |

---

## §5 — Recommendation

**HOLD until migration renumber + rebase + apply.**

Path forward:
1. **CC** (separate session, ~10 min): rebase + renumber migration 0039 → 0047 (or current free slot) + push
2. **Alex** (~3 min): apply migration to remote D1
3. **Alex**: merge PR #114
4. **Alex**: deploy worker-bot
5. **CC or Karina**: smoke test override flow end-to-end

**Estimated total time**: 15 min CC + 5 min Alex.

After fix, this PR is **GREEN to merge** — architecture is solid, tests are comprehensive, risk surface is acceptable for admin-only feature.

---

## §6 — Out-of-scope observations

While reviewing, noticed:
- `apps/web/src/pages/api/admin/airbnb-content/bulk-approve.ts` modified — bulk approve A6 airbnb content. NOT in PR scope per title; verify this is intentional or stray from a parallel branch
- `AdminLayout.astro` adds "Journey · Plantillas" nav tab — appropriate for this PR
- Cross-link from `/admin/pre-stay` added — sensible UX

No anti-patterns detected: no Casa Chamán surfacing, no /noche pet fee, no LLM money decision, no secrets in plaintext, no ALTER TABLE.

---

**END THREAD/191**
