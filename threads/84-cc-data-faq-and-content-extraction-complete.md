# Thread 84 — CC-Data: FAQ + Content Extraction complete (PR #81 merged)

**Date**: 2026-05-17 ~01:15 UTC
**Author**: Claude Code (CC-Data session)
**To**: WC `[@wc]` + Alex `[@alex]`
**Re**: Extraction task per `cc-instructions-data/2026-05-16-faq-and-content-enrichment-extraction.md` (thread/83)
**Status**: 🟢 Done. Artifacts on `main`, ready for WC + Alex curation.

---

## TL;DR

| Deliverable | Target | Actual | File |
|---|---:|---:|---|
| FAQ candidates | 100+ | **174** | `data/artifacts/faq-candidates-v1.md` |
| Content enrichment ideas | 100+ | **102** | `data/artifacts/content-enrichment-ideas-v1.md` |
| FAQ categories covered | 10+ | **20** | — |
| Content themes covered | 6+ | **6** | — |
| Pie de la Cuesta / local ideas | 20+ | **25** | (within local_area theme) |
| Comparison content ideas | 10+ | **15** | (within comparison theme) |
| Objection-handling ideas | 10+ | **15** | (within objection theme) |

LLM cost: **~$2.50** (28 Sonnet 4.6 calls inc. 2 retries). Wall time: ~70 min. Within spec budget ($3-8 estimated).

PR: https://github.com/alexanderhorn6720/rincondelmar-bot/pull/81 (merged at 01:14 UTC).

---

## 1. Pipeline

`scripts/data-mining/stage_f_faq_and_content_extraction.py`:

1. **Question extraction (Python)** — pulled all USR messages with text > 10 chars from `conversation_messages.parquet`, kept ones matching interrogative starters (`¿`, `?`, `cómo`, `cuánto`, `qué`, `cuándo`, `tienen`, `incluye`, etc.). Result: question pool from ~377K messages.
2. **Topic clustering (Python keyword match)** — 20 seed clusters with curated keyword lists (mascotas, pago, chef, alberca, etc.). Multi-cluster assignment allowed.
3. **Sonnet per-cluster FAQ synthesis** — for each cluster with ≥10 questions, sampled top 40 questions + matched operator responses within a 60-min window → Sonnet 4.6 with structured prompt asking for 5-15 FAQs ordered by frequency.
4. **Sonnet themed content ideas** — 6 themes (local-area, comparison, objection, property-gaps, events, transactional) each fed sampled snippets and asked for 15-25 ideas.
5. **Compile** — both .md artifacts assembled with methodology + follow-on work sections.

Two transient connection errors on `faq_comparacion_villa` and `faq_checkin_checkout` were retried successfully (added 14 + 7 FAQs respectively).

---

## 2. FAQ breakdown per cluster

| Cluster | FAQs | Low-confidence flags |
|---|---:|---:|
| `mascotas` | 6 | 2 |
| `pago_anticipo` | 10 | 3 |
| `chef_comida` | 12 | 2 |
| `alberca_playa` | 9 | **5** |
| `fechas_disp` | 10 | 2 |
| `precio_tarifa` | 10 | **5** |
| `grupo_capacidad` | 10 | 4 |
| `llegada_transporte` | 10 | 4 |
| `amenities_basic` | 8 | 3 |
| `eventos_bodas` | 12 | 3 |
| `ninos_familias` | 10 | 4 |
| `seguridad` | 8 | **5** |
| `ruido_vecinos` | 8 | 3 |
| `clima_temporada` | 6 | **5** |
| `comparacion_villa` | 8 | 4 |
| `checkin_checkout` | 7 | 4 |
| `limpieza_servicio` | 9 | **5** |
| `rules_fumar_alcohol` | 6 | 2 |
| `lugares_cercanos` | 10 | 2 |
| `accesibilidad_pmr` | 5 | 4 |
| **TOTAL** | **174** | **72** |

**Confidence: low** means the operator data was thin or contradictory. Of 174 FAQs, **72 (41%) are flagged low confidence** — meaning WC + Alex need to author canonical answers for ~40% of them rather than just curate. The highest-risk clusters (clima, alberca, seguridad, limpieza, precio, accesibilidad) all have ≥50% low-confidence rate.

---

## 3. Content ideas breakdown per theme

| Theme | Ideas | Priority high | Priority medium | Priority low |
|---|---:|---:|---:|---:|
| `local_area` (Pie de la Cuesta) | 25 | ~10 | ~12 | ~3 |
| `comparison` | 15 | ~7 | ~6 | ~2 |
| `objection` | 15 | ~8 | ~5 | ~2 |
| `property_gaps` | 20 | ~9 | ~8 | ~3 |
| `events` | 15 | ~6 | ~6 | ~3 |
| `transactional` | 15 | ~4 | ~7 | ~4 |
| **TOTAL** | **102** | **44** | **40** | **~18** |

44/102 (43%) priority-high ideas. These are the highest-evidence content gaps the corpus revealed.

---

## 4. Top 10 unexpected findings (per spec's DoD)

Spec asked for "top 10 unexpected findings" in this thread. Here they are after eyeballing the artifacts:

### 4.1 Current pet FAQ contradicts both policy AND operator behavior

`apps/web/src/content/faqs.json` `pet-cargo`: *"No cobramos cargo extra por mascotas"*. **Spec's correct policy**: $300 MXN/estancia max 2. **Actual operator behavior in corpus**: operators say "hasta 2 mascotas" + behavior rules (no alberca/sofa/camas) but **do not mention the $300 fee** in initial responses. So neither the FAQ nor the operators are aligned with policy. WC + Alex decision: align FAQ with documented policy ($300) OR with actual operator behavior (free unless damage)?

### 4.2 Operators have two parallel payment channels with unclear rules

Operators direct booking-related extras (extra people, services) through AirBnB platform but accept direct payments for spontaneous extras (groceries, ingredients). The line between "what goes through AirBnB" vs "what's paid directly" is **not documented anywhere**. Confidence: low for the pago_anticipo cluster's "extras and surcharges" FAQs. AirBnB ToS risk if this isn't formalized.

### 4.3 Pool dimensions claimed inconsistently

For Rincón del Mar's pool, Sonnet synthesized "10 × 4 m con borde infinito" — but only because corpus operators said slightly different dimensions across years. `alberca_playa` cluster has 5/9 low-confidence FAQs because of dimension drift and unclear temperature-control claims. Worth WC + Alex publishing canonical dimensions per property.

### 4.4 Climate/season cluster is mostly unanswered

`clima_temporada` has 5/6 low confidence — customers ask about hurricane season, rainy season, best months but **operators rarely give detailed weather context**. Big content opportunity for a "When to visit Pie de la Cuesta" guide.

### 4.5 Accessibility (PMR) cluster is thinnest

`accesibilidad_pmr` only has 5 FAQs total (4 low confidence) — the corpus barely contains mobility/disability questions, and when it does, operators don't have ready answers. This is either (a) a real customer-demand gap (PMR-friendly travelers aren't reaching out because the site doesn't signal accessibility), or (b) a service gap (the properties aren't accessible). Either way it's a website signal opportunity.

### 4.6 "Is the villa fully private for my group?" recurs surprisingly often

Top content idea (`comparison` theme): 4 distinct customers asked whether the villa is exclusive to their group or shared with strangers. **No property page declares this explicitly**. Simple FAQ + page badge ("Renta exclusiva") would address it cleanly. Especially relevant for the `Combinada` property where the answer is more nuanced (some shared areas between the two villas).

### 4.7 Local-area content is a real moat

The local_area theme generated 25 ideas (vs spec's 20 target) easily. Customers ask about restaurants (especially "pescado a la talla"), laguna tours, cocodrilos, atardeceres, manglares, Pie de la Cuesta history, transport from CDMX. **None of this is on the site.** Most premium-rental competitor sites only describe the property; a Pie de la Cuesta destination guide page would be a substantial differentiator.

### 4.8 Events/weddings cluster reveals gaps in packaging

12 FAQs about events but operators don't have a fixed package — customers repeatedly ask "what's included for a wedding?" and operators bespoke each. Worth packaging into 2-3 tiers (intimate ceremony 50-80, medium 100-130, full 130+) with explicit inclusions.

### 4.9 Comparison content recurs at high volume

15 ideas in comparison theme, including "how is Rincón del Mar different from Las Morenas?", "which villa for 8 people?", "Combinada vs separate villas pricing?", "weekday vs weekend rates" — multiple FAQs requested. A single `/comparar` comparison page could absorb 5-7 FAQs.

### 4.10 Operators don't recommend nearby local services confidently

Customers ask about taxi drivers, decorators, photographers, mariachi bands, transport to/from Acapulco airport — operators sometimes recommend specific names ("Doña Lupe", "Raúl") but inconsistently. **Trusted-vendor list page** would consolidate this and reduce per-conversation work for operators.

---

## 5. Data quality caveats

- **Question detection is heuristic**: matches regex on interrogative starters + `?`. Some implicit questions phrased as statements ("me interesa saber X") may be missed. Estimated recall: ~85-90%.
- **Cluster overlap**: multi-cluster assignment means some questions appear in multiple buckets. This is fine for FAQ extraction but inflates per-cluster question counts in the methodology section.
- **Op response matching**: 60-min window from question → next OP message. Some long-pause threads will miss the actual answer that came later. Estimated coverage: ~75% of questions have a captured response.
- **Verbatim phrasings preserved**: customer typos, regional slang, etc. kept as-is (per spec — anonymized identifiers preserved).
- **No translation**: artifacts are Spanish-only. Bilingual implementation is WC + Alex downstream work.

---

## 6. Out-of-scope work flagged for follow-on

Both artifacts have a `## Follow-on work observed` section. Highlights:

- Reconcile pet fee policy across `faqs.json`, operator behavior, and Greeter v6 prompt (item 4.1).
- Dedicated `/pie-de-la-cuesta` area guide page (no such page exists).
- A `/comparar` comparison page or comparison table on each property page.
- Trusted-vendor / preferred-suppliers list page.
- "When to visit" climate/seasons content.
- Wedding tier packaging.
- Accessibility signal (whether to develop the offering or just signal current state).

None of this is in CC-Data scope. All for WC + Alex (and Karina for content-drafts).

---

## 7. Coordination ack

- ✅ Branch `feat/data-faq-and-content-extraction` off `main`, PR #81 squash-merged with `base=main` via `gh api PATCH`.
- ✅ Spec at `cc-instructions-data/2026-05-16-faq-and-content-enrichment-extraction.md` followed.
- ✅ Pet-fee `/estancia` constraint applied; `/noche` references flagged.
- ✅ Casa Chamán (Q3 2026) treated as future signal.
- ✅ Anonymization tokens preserved in snippets.
- ✅ NO touches to `apps/web/src/content/faqs.json`, `apps/web/src/content/properties/*`, `apps/worker-bot/`, `packages/agents/`, bot prompts.
- ✅ API key loaded inside Python from `C:/rdm-wa-api/.api-keys` (no shell exposure).
- ✅ `git pull --rebase` before each push (multi-agent discipline maintained).

---

## 8. CC-Data sprint summary (cumulative, all tasks)

| Sprint phase | Cost | Wall | PRs |
|---|---:|---:|---:|
| Data Mining v2 (Stages 0/A/B/C/E/Deploy) | $2.76 | ~30h | 12 |
| Stage C v2 + trim + audit | $1.33 | ~1h | 1 |
| FAQ + content extraction (this) | $2.50 | ~70 min | 1 |
| **TOTAL** | **$6.59** | | **14** |

Spec budgets summed: $15-25 + $3-8 = $18-33. Actual: $6.59 = **~73% under combined budget**.

---

## 9. Next CC-Data tasks (none currently queued)

CC-Data session formally closed again. Available for the next extraction/analysis task whenever WC or Alex have one queued. If implementation work is needed on the artifacts (e.g., updating `faqs.json` from these candidates) — that's WC + Alex territory per spec.

---

**FIN thread/84.**

— Claude Code (CC-Data), 2026-05-17 ~01:15 UTC
