---
thread: 192
author: CC
date: 2026-05-24
topic: pr-130-review
mode: brain
status: open-for-alex-vote
related: [130, 138, 139, 184]
deliverable: PR #130 review with merge recommendation
---

# Thread/192 — PR #130 Review: A6 Reglas Adicionales Deploy

**Subject**: [PR #130 — Feat/a6 reglas adicionales deploy](https://github.com/alexanderhorn6720/rdm-bot/pull/130)
**Branch**: `feat/a6-reglas-adicionales-deploy`
**Stats**: +154 / −2 lines, 10 files changed, 3 commits
**Recommendation**: ✅ **GREEN to merge** with one operational sequence requirement (deploy worker BEFORE next R2 write).

---

## §0 — Summary

PR ships canonical `reglas_adicionales` content (Spanish + English idiomatic) for 8 cells (4 properties × 2 langs) authored by Alex 2026-05-19 in chat with WC. Also bumps `max_chars` schema constant 5000 → 12000 after live AirBnB UI verification accepts ≥12K chars. Fixes one downstream bug (putFieldContent 500 on missing field for pre-2026-05-14 drafts) + surgically removes "WhatsApp" brand mention (AirBnB house-rules content moderation blocks the literal word).

Content per cell (all <12000 chars):
- rincon-del-mar: 10066 ES / 9510 EN
- las-morenas: 10023 ES / 9495 EN
- combinada: 10680 ES / 10058 EN
- huerta-cocotera: 11103 ES / 10535 EN

---

## §1 — Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | Schema bump `max_chars` 5000→12000 — if any consumer cached the old constant, validation drift | 🟢 Low | Both producers (convertWCSeed, putFieldContent) validate against the bundled constant per PR description. No D1 row stores max_chars (it's a schema constant). |
| 2 | Branch open since 2026-05-19 (>4 days). May be behind main; possible merge conflicts | 🟡 Medium | Verify via `gh pr checks 130` or attempt rebase. Low diff scope (8 JSON + 2 TS) reduces collision risk. |
| 3 | "NEEDS wrangler deploy before Phase A.1.5" — if merged but not deployed, R2 writes for new content 500 (`write_failed`) | 🟡 Medium | Operational sequence: merge → Alex deploys worker → THEN Phase A.1.5 (PUT cells). Document in PR comment. |
| 4 | WhatsApp brand swap may need backporting if any OTHER content cells reference "WhatsApp" in `house-rules` field | 🟢 Low | Per commit message, swap was surgical for 6/8 cells. Verify no other house-rules content has WhatsApp post-merge via grep. |
| 5 | AirCover photo/timestamp + cuidador Huerta + animales La Prieta content all reference real-world facts — if any are outdated, content drift | 🟢 Low | Alex authored directly 2026-05-19. Reasonable freshness window. |
| 6 | Char limits ≥12K verified empirically (12000-char paste test) but AirBnB UI behavior may change | 🟢 Low | Acceptable risk; max_chars is enforced client-side, AirBnB-side enforcement is opaque. |

---

## §2 — Test coverage

Per PR description:
- 707 worker-bot tests + 342 web tests = **1049 passed, 0 failed**
- Includes regression coverage for putFieldContent fallback (the bug fix in commit 2)

**No new tests added** for this PR — appropriate since changes are content (JSON drafts) + 2 TS surgical edits (storage helper defensive guard + schema constant). Existing tests cover the surface.

---

## §3 — Migration impact

**No D1 migration**. Content lives in R2 + bundled JSON drafts. Schema change is TypeScript constant `max_chars: 12000` in `packages/shared/src/airbnb-content-schema.ts`.

**No collision risk** (unlike PR #114).

---

## §4 — Anti-pattern verification

| Check | Result |
|---|---|
| Pet fee `/estancia` NEVER `/noche` | ✅ "Mascotas strict ($300/estancia max 2)" per commit message — CORRECT |
| Casa Chamán surfacing | ✅ NONE — the 4 properties are RdM/Morenas/Combinada/Huerta. Casa Chamán roomId 679176 NOT in scope of this PR |
| Beds24 sync mode Everything | ✅ NOT TOUCHED |
| LLM money decision | ✅ Content human-authored by Alex 2026-05-19, not LLM-generated pricing/refund |
| Secrets plaintext | ✅ None in diff |
| ALTER TABLE during multi-agent run | ✅ No migration |

---

## §5 — Pre-merge requirements

| # | Requirement | Done? |
|---|---|---|
| 1 | Rebase against current `main` if behind | ⏳ check |
| 2 | All 1049 tests pass post-rebase | ✅ (per PR description, was clean at commit time) |
| 3 | `pnpm exec tsc --noEmit` clean | ⏳ verify post-rebase |
| 4 | Operational sequence noted: deploy worker BEFORE Phase A.1.5 (next R2 write) | ⏳ document in merge comment |

---

## §6 — Recommendation

**GREEN to merge** with these steps:

1. **CC** (~2 min): `git pull --rebase origin main` on branch. If conflicts → fix; if clean → push.
2. **Alex** (~30 sec): merge PR #130 to main.
3. **Alex** (~3 min): deploy worker-bot (`pnpm --filter worker-bot deploy` or via CI/CD).
4. **Alex/CC** (~2 min): Phase A.1.5 — PUT 8 cells to R2 via admin endpoint, verify 200 (no more 500 write_failed).
5. **Smoke test**: open AirBnB live listing one property → verify reglas_adicionales rendered.

**Total time**: ~10 min total. Low risk.

---

## §7 — Out-of-scope observations

- The defensive fallback fix (commit 2) addresses ONLY putFieldContent. Per commit message, same bug exists in:
  - `buildFieldResponse` (GET handler)
  - `/api/admin/airbnb-content` overview endpoint (thread/138 §4.1)
  - `putFieldApproval` (only safe because callers pre-filter empty)

  → Suggest follow-up issue/PR to harden the other 3 paths. NOT a blocker for this PR.

- WhatsApp swap: surgical 6/8 cells. Huerta uses Telmex copy unchanged. If new properties added later, content authoring must avoid "WhatsApp" in house-rules.

---

**END THREAD/192**
