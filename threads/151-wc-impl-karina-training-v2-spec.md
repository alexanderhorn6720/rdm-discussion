# Thread 151 · WC-Impl → CC-Bot · Spec · Karina Training doc bump v1 → v2 (SVG mockups, no screenshots)

**From**: WC-Implementation
**To**: CC-Bot (next session)
**Date**: 2026-05-20
**Type**: spec · brain deep with implementation directives
**Mode for CC**: DoIt with hard scope
**Estimated effort**: 4-5h CC

---

## §1 · Context

`apps/web/src/pages/admin/karina-training/index.astro` shipped v1 on 2026-05-18 (thread/124-127). Since then, 6 PRs changed the operational reality:

| PR | Thread | Impact on doc |
|---|---|---|
| #126 | thread/131 Part E | Mobile inbox WhatsApp-style UX |
| #127 | thread/134 | Beds24 read-only proxy `/calendar` (replaces R2 2h cache mention) |
| #128 | thread/141 Phase 1 | 4 public `/reglas/{slug}` URLs + D1 click tracking |
| #129 | thread/143 | 7 roles + 14 M1-M5 placeholders live |
| #131 | thread/144 | Nav reorg 5 dropdowns + landing dashboard 6 KPI + 4 widgets |
| (planning) | thread/147 | Foundations F2→F1→F3 calendar pushes M5 from "1-2 mo" to W8+ |

Goal: doc reflects prod state as of 2026-05-20. **Version bump v1 → v2.**

**No screenshots** — replace PNG captures with **inline SVG mockups** (same pattern as existing `§3 how-they-fit` SVG figure in v1). Reasons:

- Screenshots go stale fast (every PR touches UI)
- SVG mockups encode *intent* not *implementation detail*
- Karina learns the structure once, doesn't get confused by pixel-perfect drift
- CC can author inline, no Chrome MCP session needed
- Anti-pattern preserved: doc owns its visuals, not external files

---

## §2 · Scope

### YES files (modify)
- `apps/web/src/pages/admin/karina-training/index.astro` ← **only file**

### NO files (DO NOT touch)
- Test files (doc has no test coverage by design)
- `apps/web/public/karina-training/*.png` (orphan after this PR; cleanup in separate PR)
- Any other admin page or component
- Any worker-bot / packages / migration file

### Replace pattern
Every `<img src="/karina-training/foo.png" .../>` becomes inline `<svg viewBox="0 0 720 380" ...>` mockup. Caption stays. Container `.kt-figure` class stays.

---

## §3 · Closed decisions (do not re-evaluate)

1. Pet fee canonical: **"$300 MXN por mascota por estancia (NO por noche). Max 2 por reserva. Pago en efectivo al check-in."**
2. Casa Chamán: hidden until Q3 2026.
3. Version bump v1 → v2 (not v1.1).
4. Header date: `2026-05-20`.
5. Roles count: 7 effective (admin, content_editor, chef, staff, tecnico, compras, admin_readonly).
6. M1-M5 calendar align with thread/147 (W1-3 foundations, W4+ M1 brain, M5 Tasks W8+).
7. No new sections beyond §4. Stay in scope.
8. **No screenshots, only SVG mockups**.

---

## §4 · Edit list · summary

CC reads the full spec file from the rdm-discussion repo for the 21 detailed edits (FIND/REPLACE patterns + SVG source). The full content is ~100KB and contains complete inline SVG source for 7 mockups.

### Summary of 21 edits:

| # | Edit | Type |
|---|---|---|
| 4.1 | Doc header date v1 → v2 + 2026-05-20 (2 locations) | Text |
| 4.2 | §1 "Tu rol" expand for 7 roles + multi-role description | Content |
| 4.3 | §2.5 Fase 1 row 1.3 · update Beds24 proxy text | Text |
| 4.4 | §2.5 new row 2.4.5 · house rules public URLs | New row |
| 4.5 | §5.0 NEW "Cómo navegas" with SVG nav dropdown mockup | SVG mockup |
| 4.6 | §5.1 NEW "Landing dashboard" section (6 KPI + 4 widgets SVG) | New section + SVG |
| 4.7 | §5.1 inbox convert PNG → SVG (desktop table view) | SVG mockup |
| 4.8 | §5.1.5 NEW "Inbox móvil" section (2-phone SVG mockup) | New section + SVG |
| 4.9 | §5.2 bookings convert PNG → SVG (KPIs + table) | SVG mockup |
| 4.10 | §5.3 pre-stay convert PNG → SVG (table 7 touchpoints) | SVG mockup |
| 4.11 | §5.4 extra-guests convert PNG → SVG (3 scenarios) | SVG mockup |
| 4.12 | §5.5 airbnb-content convert 2 PNGs → 2 SVGs (matrix + editor) | 2 SVG mockups |
| 4.13 | §4 site URLs add `/reglas/{slug}` to Top 5 + EN section | Text |
| 4.14 | §3 M1-M5 ETAs realistic post-thread/147 | Text |
| 4.15 | §5.5 add note on reglas_adicionales 12K capacity | Text |
| 4.16 | §6 cheat + §2.5 align pet fee formulation | Text |
| 4.17 | §6 anti-pattern pet fee canonical | Text |
| 4.18 | §6 anti-pattern add WC role boundary | New item |
| 4.19 | §5.7 "7 herramientas" fix count → "técnicas" + mention 14 placeholders | Text |
| 4.20 | §6 glossary clarify Casa Chamán count | Text |
| 4.21 | ToC update for new sections (admin-landing + admin-inbox-mobile) | Text |

### Full FIND/REPLACE source for each edit + complete SVG source code

CC: read this file's full source via:

```bash
gh api repos/alexanderhorn6720/rdm-discussion/contents/threads/151-wc-impl-karina-training-v2-spec-detailed.md \
  --jq '.content' | base64 -d > /tmp/spec-151-detailed.md
```

OR via web UI: https://github.com/alexanderhorn6720/rdm-discussion/blob/main/threads/151-wc-impl-karina-training-v2-spec-detailed.md

The detailed file (separate commit, same thread number) contains every FIND/REPLACE block + every SVG source verbatim, ready to copy-paste.

---

## §5 · Tests

No automated tests required (content doc).

**Manual smoke-test** post-deploy:

```bash
pnpm --filter web build              # expect: clean
pnpm --filter web astro check        # expect: 0 errors
pnpm --filter web dev                # manual visual check
```

Visual verify:
- TOC sidebar + links work
- All 7 SVG mockups render (no broken `<img>` tags remain)
- Pet fee canonical formulation consistent
- "Versión 2 · 2026-05-20" in header + TOC
- §5.1 landing dashboard renders
- §5.1.5 mobile inbox renders
- No 404s

---

## §6 · Definition of Done

CC self-checks before opening PR:

- [ ] All 21 edits from §4 applied in document order
- [ ] All 7 PNG `<img>` replaced with inline SVG `<svg>`
- [ ] No reference to `/karina-training/*.png` remains
- [ ] Version banner shows `v2 · 2026-05-20` (header + TOC)
- [ ] Pet fee canonical in all 3 places (§2.5, §6 cheat, §6 anti-pattern)
- [ ] `pnpm --filter web build` clean
- [ ] `pnpm --filter web astro check` 0 errors
- [ ] No new test file (doc has no tests by design)
- [ ] PR body summarizes change in 3-5 bullets + thread/151 URL
- [ ] Single squash commit: `docs(karina-training): bump v1 → v2 (SVG mockups, navigation, foundations calendar)`

---

## §7 · Risks + mitigations

| Risk | Mitigation |
|---|---|
| Astro JSX SVG parsing with inline `<text>` content | Escape `<` with HTML entities if needed. Test build before push. |
| SVG attribute conflicts with Astro JSX-like syntax | Use SVG 2 syntax. Match existing §3 M5 diagram pattern. |
| File size growth (+30KB inline SVG) | Acceptable. Server-rendered, no client hydration. <500KB total. |
| Karina reads stale screenshots cached | CF Pages purge if reported. |
| CC scope-creep | This spec is ONLY scope. Out-of-scope → open issue. |

---

## §8 · Boundary respected

- ✅ Written in `rdm-discussion` (WC-Impl territory)
- ❌ NO code modifications proposed for `rdm-bot` directly · CC implements
- ❌ NO writes to `rdm-platform` (WC-Platform territory)
- ✅ Evidence-based: read full `karina-training/index.astro` from main via GitHub MCP
- ✅ Anti-pattern check honored (Casa Chamán hidden, pet fee canonical, no Friday post-5pm)
- ✅ Anti-screenshot decision (all visuals as inline SVG, matches §3 M5 diagram)

---

## §9 · Out of scope

For follow-up specs:

1. `/karina-training/*.png` cleanup (orphan files after this PR)
2. Verify §4 site URLs exist in prod (audit script)
3. Bot KB preview integration in §5.5
4. Karina feedback loop after reading v2 → thread/152+ for v3
5. EN translation (ES-only by design currently)

---

**Signed**: WC-Implementation, brain deep, 2026-05-20

**Next action**: CC reads thread/151 + the detailed companion file, opens branch `docs/karina-training-v2`, applies 21 edits with full SVG source, smoke-tests, opens PR.
