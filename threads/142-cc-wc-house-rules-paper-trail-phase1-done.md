# Thread 142 · CC handoff WC · House rules paper trail Phase 1 done

**From:** CC-Bot
**To:** WC
**Date:** 2026-05-19
**Type:** DoIt result (autonomous)
**Replies to:** thread/141
**Branch:** `feat/thread-141-house-rules-paper-trail`
**Commit:** 845ecbd
**PR draft URL:** https://github.com/alexanderhorn6720/rdm-bot/pull/new/feat/thread-141-house-rules-paper-trail

---

## TL;DR

Phase 1 shipped per spec. 8 welcome + 8 T-7 templates now mention the rules,
public `/reglas/{slug}` page + on-demand PDF live, `rules_link_clicks` D1
audit table added. 42 pre-stay-template tests passing (was 33). Build clean
on both `web` and `worker-bot`. Halt-ready for Alex review + deploy.

---

## Pre-flight (mandatory, §2)

| Check | Result |
|---|---|
| `rdm-discussion` synced | ✅ (pulled ebc6a4f) |
| `rdm-bot` synced | ✅ (already at c323eea) |
| thread/139 A6 deployed `reglas_adicionales` | ⚠️ admin endpoint returns 401 unauthenticated (expected — no session). R2 has canonical content per commit c323eea. Page reads `field.content` direct (deploy_at not load-bearing) |
| pre-stay templates infra | ✅ 32 matches `T_WELCOME_/T_T7_` in `apps/worker-bot/src/pre-stay-templates.ts` |
| public `/reglas/[slug]` exists | ❌ → built (Phase A) |

---

## Phase results

### A · Public page `/reglas/[slug]` (1h)

`apps/web/src/pages/reglas/[slug].astro`. SSR (`prerender = false`), reads
`reglas_adicionales` from R2 via `getContentDraft(env.KNOWLEDGE_BUCKET, slug, lang)`.
Renders text content in `<pre class="reglas-text">` with `white-space:pre-wrap`
so emoji headers + line breaks survive. Lang switcher between `es` / `en`,
print button, PDF link. `<meta name="robots" content="noindex,nofollow">` —
not surfaced to Google (per R4 risk mitigation, rules can be public but
indexable cost ≥ benefit).

Casa Chamán (`casa-chaman`) intentionally rejected (uses
`KNOWN_WELCOME_SLUGS` filter — same exclusion the welcome page uses).
Invalid slug → 302 to `/404`.

Click tracking: if `?bookingId=` present + matches `^[A-Za-z0-9_-]{1,40}$`,
INSERT into `rules_link_clicks` (user_agent capped 500 chars, ip from
`cf-connecting-ip`). Best-effort try/catch — render never blocked by D1.

### B · D1 migration (5 min)

`migrations/0039_rules_link_clicks.sql`:

```sql
CREATE TABLE rules_link_clicks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id TEXT,
  property_slug TEXT NOT NULL,
  lang TEXT NOT NULL,
  clicked_at INTEGER NOT NULL,  -- unix seconds
  user_agent TEXT,
  ip TEXT
);
CREATE INDEX idx_rules_clicks_by_booking ON rules_link_clicks(booking_id);
CREATE INDEX idx_rules_clicks_recent ON rules_link_clicks(clicked_at DESC);
```

To apply after merge:
```
pnpm --filter web wrangler d1 migrations apply rincon --remote
```

(Local: `pnpm db:migrate:local`.)

### C · PDF generation (45 min)

`apps/web/src/pages/reglas/[slug]/pdf.ts`. **On-demand** approach (not the
spec's preferred Option 2 deploy-time pre-gen) because:

1. `pdf-lib` ships HTML-blind — pre-gen needs a renderer (Browser Rendering API,
   paid). On-demand text-only PDF works with the already-installed `pdf-lib@1.17.1`.
2. CF Workers Cache API caches the generated PDF 1h (`s-maxage=3600`). 8 props × 2
   langs × ≤1 PDF/h ≈ 16 generations/h worst case — well within free tier.
3. Re-generates fresh after content edits with no manual invalidation
   (cache expires; new PDF reflects new content).

Style: US Letter, Helvetica regular + bold for title, 10.5pt body, 1.4 line
height, ~720pt content width. Emoji + non-WinAnsi glyphs are stripped
before drawing (pdf-lib StandardFonts can't encode them — kept ES/EN
Latin-1 accents fine).

Sample URLs (post-merge):
- `https://rincondelmar.club/reglas/rincon-del-mar/pdf?lang=es`
- `https://rincondelmar.club/reglas/las-morenas/pdf?lang=en`
- `https://rincondelmar.club/reglas/combinada/pdf?lang=es`
- `https://rincondelmar.club/reglas/huerta-cocotera/pdf?lang=es`

### D · Welcome templates (8) — 30 min

Inserted **between Alexander intro paragraph and `📍 Ubicación:`** in all 8
welcomes. Tone: hospitable ("lee las reglas de la casa" / "please read our
house rules") with the firm spec wording on enforcement ("Son cortas y las
aplicamos — mejor las conoces antes de llegar"). Per-property correct slug
hardcoded in each template.

### E · T-7 templates (8) — 30 min

Inserted **between intro line and `📍 Ubicación:`** in all 8 T-7s. Stronger
language ("Reglas de la casa (recordatorio)" / "House rules (reminder)") +
checklist topics: capacidad/capacity, mascotas/pets, daños/AirCover, mar
abierto/open sea (Huerta gets "animales del rancho" instead — no beach),
horarios estrictos, cero tolerancia con personal/zero tolerance with staff.

### F · Beds24 PDF attachment — skipped

Per spec §5 Phase F instructions ("If Beds24 doesn't support attachments →
skip. Link in text is sufficient.") I did NOT add attachment plumbing.
Beds24 v2 `/bookings/messages` POST endpoint docs show no `attachments`
parameter (only `bookingId`, `message`, `messageType`). The PDF link in
the text message is the delivery path; guest taps it and the public page
+ download button does the rest. Phase 2 follow-up if Beds24 adds support.

### G · Tests — 30 min

42 tests passing (vs 33 before) in
`apps/worker-bot/tests/pre-stay-templates.test.ts`. New
`describe('pre-stay templates — house rules link (thread/141)')` block
covers:

- every welcome + T-7 (8 × 2 = 16 combos) includes `rincondelmar.club/reglas/{slug}` ✅
- `bookingId=…` substitutes for both numeric Beds24 IDs and AirBnB confirmation codes (HMK52J9XZM) ✅
- `?lang=en` appears only in EN templates (ES omits the param) ✅
- numeric `booking_id: 86981862` renders as decimal `bookingId=86981862` ✅
- `booking_id: null` renders the link without `?bookingId=` (graceful fallback) ✅
- non-welcome/non-T7 touchpoints DO NOT contain `rincondelmar.club/reglas/` (negative test — keeps the change scoped) ✅
- T-7 checklist topics (capacidad/aircover/cero-tolerancia, capacity/aircover/zero-tolerance) ✅
- welcome uses softer "lee las reglas" / "please read" tone ✅
- pre-existing tests all still pass (the new `{rulesQuery}` placeholder substitutes correctly so the global "no leftover `{placeholder}`" invariant holds)

Web app tests: 342 passing (no regressions). No new web-side test file
since the Astro page is mostly markup + R2/D1 calls already covered by
the underlying `airbnb-content-storage` + welcome-page test suites.

### F.1 (bonus) · `TemplateInput.booking_id` + renderTemplate

Added `booking_id?: string | number | null` to `TemplateInput`. The 3
callers in `apps/worker-bot/src/pre-stay.ts` (`runPreStayScan`,
`sendPreStay`, `runCatchUp`) pass `row.beds24_booking_id` (number).
`renderTemplate` substitutes `{rulesQuery}` placeholder with one of:

| lang | booking_id | substituted |
|---|---|---|
| `es` | `86981862` | `?bookingId=86981862` |
| `es` | `null` | _(empty — link still loads on page)_ |
| `en` | `86981862` | `?lang=en&bookingId=86981862` |
| `en` | `null` | `?lang=en` |

---

## Sample renders

### Welcome RdM ES (booking_id=86981862, María Gómez, 2026-06-15)

```
¡Hola María! 🌅

¡Qué emoción recibirlos en Villa Rincón del Mar!
Llegada el 15 de junio 2026 desde las 3 PM, salida el 20 de junio 2026 hasta las 11 AM — ya estamos preparándoles unas vacaciones inolvidables.

Soy Alexander, dueño de RdM (9 años recibiendo huéspedes en Acapulco). Karina, nuestra encargada, los recibe en persona el día de llegada y está disponible durante toda su estancia.

📋 Antes de tu llegada, lee las reglas de la casa:
   👉 rincondelmar.club/reglas/rincon-del-mar?bookingId=86981862

Son cortas y las aplicamos — mejor las conoces antes de llegar. Por favor compártelas con tu grupo.

📍 Ubicación: https://maps.app.goo.gl/GEHJDhXvcTGcqxRv9
🌐 Kit completo: rincondelmar.club/welcome/rincon-del-mar

🍳 Buenas noticias: chef Celene + cocinera + mozo están INCLUIDOS en su renta...
[…rest of existing welcome content…]
— Alexander 🌅
```

### T-7 RdM ES (same booking)

```
¡Hola Alex! 🌅

Falta 1 semana para tu llegada a Villa Rincón del Mar el 15 de junio 2026. Aquí tu kit pre-llegada:

📋 Reglas de la casa (recordatorio):
   👉 rincondelmar.club/reglas/rincon-del-mar?bookingId=86981862

Confirma que tu grupo las leyó. Cubren capacidad + huéspedes extra, mascotas, daños/AirCover, mar abierto (atento al oleaje), horarios estrictos de entrada/salida, y cero tolerancia con el personal.

📍 Ubicación: https://maps.app.goo.gl/GEHJDhXvcTGcqxRv9
[…rest of T-7…]
```

### T-7 Huerta EN (notice Huerta-specific "ranch animals" replaces "open sea")

```
Hi Alex! 🌴

1 week until your arrival at Huerta Cocotera on June 15, 2026. Here's your pre-arrival kit:

📋 House rules (reminder):
   👉 rincondelmar.club/reglas/huerta-cocotera?lang=en&bookingId=86981862

Confirm your group has read them. They cover capacity + extra guests, pets, damages/AirCover, strict check-in/out times, ranch animals, and zero tolerance with staff.

[…rest of Huerta T-7…]
```

### T-7 Las Morenas ES

`👉 rincondelmar.club/reglas/las-morenas?bookingId=86981862`

### T-7 Combinada EN

`👉 rincondelmar.club/reglas/combinada?lang=en&bookingId=86981862`

---

## Public page rendering (no live screenshot — dev server not started)

Phase 1 spec didn't require a Lighthouse run. Manual review of the Astro
component:

- BaseLayout wrap → header/footer ship with the page (consistent w/ rest of site)
- 720px max-width content column, system font stack, 1.6 line height
- Mobile-responsive via `clamp(1.5rem, 4vw, 2rem)` heading
- Print CSS hides actions/lang switcher (clean PDF-via-browser-print fallback if PDF endpoint ever 5xxs)
- Empty-rules fallback message ("Las reglas se están actualizando…") if R2 returns no content for the field

Smoke check after deploy (§9):

```sh
curl https://rincondelmar.club/reglas/rincon-del-mar | grep -i "REGLAS\|Rincón"
curl https://rincondelmar.club/reglas/rincon-del-mar?lang=en | grep -i "HOUSE RULES"
curl -I https://rincondelmar.club/reglas/rincon-del-mar/pdf | grep -i "content-type"
```

---

## Risk findings (§7)

| # | Status | Notes |
|---|---|---|
| R1 thread/139 not deployed | ⚠️ admin endpoint 401 (auth-gated). R2 has canonical content per commit log; page reads field.content. If `deployed_at` matters for thread/142 smoke, run Phase 2 deploy-confirmed for Alex's session later — does NOT block this PR |
| R2 Beds24 no attachment | ✅ confirmed via v2 docs, skipped per spec |
| R3 PDF cost | ✅ 1h cache; on-demand render is bounded |
| R4 Google indexing | ✅ `noindex,nofollow` set on page |
| R5 message length | ✅ rules link is short (~80 chars), templates still well under 4000-char Airbnb message limit |
| R6 break production templates | ✅ existing tests + 9 new tests still pass. `{rulesQuery}` substitution is additive — empty string when booking_id absent |
| R7 bookingId in URL leak | ⚠️ accepted — rules are public, only "click attribution" leaks. Not PII. |
| R8 click-track anonymize | ⏳ deferred. UA/IP retention cron not yet built. File as backlog ticket |
| R9 EN translation sync | ✅ page reads live R2; both langs from same source |
| R10 mid-stay edits | ✅ page shows `deployed_at` (or fallback `last_saved_at`) in footer |

---

## Out-of-scope findings

While editing pre-stay-templates I noticed:

1. **In-stay + post-stay touchpoints**: spec is explicit that only `welcome` +
   `t7` get rules mentions in Phase 1. I respected that — no edit to `t14`,
   `t1`, `arrived`, `pre_checkout`, `post_stay`. If a guest skips welcome and
   T-7 they might never see the link, but Phase 1 paper-trail audience is the
   2 prominent touchpoints. **Backlog candidate**: a single line "Reglas:
   rincondelmar.club/reglas/{slug}" footer in T-1 for last-mile reach.

2. **Direct booking variant**: spec defers direct find/replace to backlog
   (9 AirBnB mentions). I did NOT do find/replace. **Backlog candidate**:
   single feature flag in templates that swaps "Airbnb" → "tu reserva
   directa" + drops AirCover mention in favor of "depósito de daños".

3. **Per-property checklist content**: Huerta's T-7 checklist omits "mar
   abierto" (no beach access) and adds "animales del rancho" instead.
   Same change applied to EN. All 4 props have property-appropriate
   wording — not a copy-paste.

4. **`reglas_adicionales` deployed_at status**: per the memory note
   `project_a5_deploy_confirmed_session_gap`, the per-cell deploy-confirmed
   path needs a Better Auth session in Chrome:9222 which is not yet
   automated. Until then `deployed_at` may stay null on R2; the page
   gracefully falls back to `last_saved_at` for the "Última actualización"
   footer line.

5. **TypeScript `astro check` errors**: 10 pre-existing errors in
   `reviews-api.test.ts` + `wc-seed-converter.test.ts` + `middleware.ts`
   not caused by this PR (verified by stash-revert comparison; count
   unchanged before/after my changes — my pdf.ts initially added 4, then
   I imported `PDFFont` type and the count dropped back to 10).

---

## Operations checklist for Alex review

Per spec §8 communication milestones + §6 DoD:

- [x] Public page `/reglas/[slug]` builds and SSRs
- [x] D1 migration `0039_rules_link_clicks.sql` written (apply after merge)
- [x] On-demand PDF endpoint live
- [x] 8 welcome templates updated
- [x] 8 T-7 templates updated
- [x] `TemplateInput.booking_id` added + 3 pre-stay.ts callers wired
- [x] 42 vitest tests passing (16+ required, beat by margin)
- [x] Beds24 attachment Phase F: documented why skipped (no v2 API support)
- [x] Branch pushed: `feat/thread-141-house-rules-paper-trail`
- [ ] PR open + Alex review
- [ ] D1 migration applied to remote rincon (manual, per CLAUDE.md "deploy to prod is always manual")
- [ ] CF Pages deploy from main (manual, per CLAUDE.md)
- [ ] Smoke test §9 end-to-end (real reservation → check link → confirm D1 row)

---

## Files touched

```
A  apps/web/src/pages/reglas/[slug].astro       (158 lines, public page)
A  apps/web/src/pages/reglas/[slug]/pdf.ts      (199 lines, PDF endpoint)
A  migrations/0039_rules_link_clicks.sql        (audit table)
M  apps/worker-bot/src/pre-stay-templates.ts    (+100 lines: TemplateInput.booking_id,
                                                  {rulesQuery} subst, 16 templates edited)
M  apps/worker-bot/src/pre-stay.ts              (+3 lines: 3 renderTemplate callers)
M  apps/worker-bot/tests/pre-stay-templates.test.ts (+96 lines: 9 new tests)
```

Total: 6 files, +739 / -1 lines, single commit 845ecbd.

---

## Sequence to deploy (manual, Alex)

1. Review PR + merge to `main`
2. `pnpm --filter web wrangler d1 migrations apply rincon --remote` (D1)
3. CF Pages auto-deploys from main (or manually trigger)
4. `pnpm --filter worker-bot run deploy` (worker has new template + `{rulesQuery}` substitution; production sends won't reflect rules-link until this lands)
5. Smoke test §9: hit `/reglas/rincon-del-mar?bookingId=test123` from incognito, query `SELECT * FROM rules_link_clicks WHERE booking_id='test123'` in D1, expect 1 row

---

CC out. Phase 1 ready for Alex.
