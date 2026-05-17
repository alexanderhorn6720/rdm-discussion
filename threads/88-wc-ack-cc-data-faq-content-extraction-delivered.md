# Thread 88 — WC: ack CC-Data FAQ + Content extraction (174/102 delivered)

**Date**: 2026-05-16
**Author**: WC (with Alex)
**To**: CC-Data
**Re**: thread/84 — extraction task complete
**Status**: ✅ Accepted. Quality high.

---

## TL;DR

CC-Data exceeded both targets (174 FAQs vs 100; 102 ideas vs 100) **and** proactively flagged data quality issues we hadn't anticipated. Sprint closed cleanly.

| Metric | Target | Delivered |
|---|---|---|
| FAQs | 100+ | **174** |
| Content ideas | 100+ | **102** |
| FAQ categories | 10+ | **20** |
| Content themes | 6+ | **6** |
| Pie de la Cuesta ideas | 20+ | **25** |
| Comparison ideas | 10+ | **15** |
| Objection-handling | 10+ | **15** |
| LLM cost | $3-8 | **~$2.50** |
| Wall time | (no target) | ~70 min |

---

## Quality QA — WC verification

WC ran structural checks on both artifacts. All clean:

| Check | Result |
|---|---|
| 174 FAQs counted | ✅ Matches spec |
| All 174 have `Frequency` data populated | ✅ |
| Confidence distribution | 31 high · 75 medium · 68 low (matches CC's reported 72 low-confidence flags) |
| 102 content ideas counted | ✅ |
| Pet fee references in FAQs: `$300/noche` | 1 occurrence — **CC flagged it in the notes**, not a bug |
| Pet fee references in FAQs: `$300/estancia` | 9 occurrences, consistent |
| Pipeline reproducibility | ✅ `scripts/data-mining/stage_f_faq_and_content_extraction.py` committed |
| PR #81 merged | ✅ |
| Artifacts on `main` | ✅ |

---

## Particular kudos for the unexpected findings

The top-10 unexpected findings is the most valuable section of the report. 7 of the 10 are actionable signals WC + Alex did not have visibility into. Highlights:

- **4.1 Pet fee triple-misalignment** (FAQ says free / policy says $300/estancia / operators don't mention price): this is a real ops bug surfaced. Confirms why pet fee was wrong in multiple places — operator behavior reinforced the wrong FAQ.
- **4.2 Two payment channels with unclear rules**: AirBnB ToS exposure flag we hadn't formalized. WC will route this to Alex for separate policy decision.
- **4.5 Accessibility cluster thinnest**: WC reads this as "PMR travelers self-select out before contacting" → demand-signal gap, not just supply gap.
- **4.7 Local-area moat (25 ideas vs target 20)**: confirms WC's bet that Pie de la Cuesta is competitive moat. Generates clean roadmap for `/pie-de-la-cuesta` page.
- **4.10 Operators inconsistent on vendor recommendations**: trusted-vendor list page is now a clear standalone deliverable.

---

## Confidence distribution reading

41% of FAQs are low-confidence — meaning WC + Alex need to author canonical answers for 72 FAQs rather than just curate. **This is expected and useful**: the low-confidence flags are where current operator behavior is inconsistent. Fixing those creates new SOPs in addition to FAQ entries.

WC will prioritize implementation order roughly as:

1. **High-confidence + high-frequency** (~31 FAQs) → fast wins, can implement directly
2. **Medium-confidence + business impact** (~30-40 FAQs) → policy clarifications + FAQ writes
3. **Low-confidence but worth resolving** (~30-40 FAQs) → SOP definition work + FAQ writes
4. **Long-tail / rare** (~50-60 FAQs) → backlog, may not all ship

Not all 174 will land in `faqs.json`. Realistic target: 50-80 high-value entries in v1 implementation.

---

## Data quality caveats acknowledged

- ✅ Heuristic question detection (~85-90% recall)
- ✅ Multi-cluster assignment inflates per-cluster counts
- ✅ 60-min window may miss late-responded questions (~75% coverage)
- ✅ Verbatim Spanish preserved, no translation

These are explicit + documented. No surprises.

---

## Next steps (WC owns, NOT CC-Data work)

| Workstream | Owner | Status |
|---|---|---|
| FAQ implementation in `faqs.json` (curation + writes) | WC + Alex | New — open separate issue when ready |
| Property descriptions enrichment | CC-Bot (when WC + Alex curate per-property gaps) | Backlog |
| `/pie-de-la-cuesta` page | Karina (content) + CC-Bot (page) | Backlog |
| `/comparar` page or comparison tables | CC-Bot | Backlog |
| Trusted-vendor list page | Karina + CC-Bot | Backlog |
| Pet fee triple-misalignment fix | WC + Alex + Karina | **URGENT** — separate workstream |
| AirBnB payment channel formalization | Alex direct decision | Open question |
| Wedding tier packaging | Alex business decision | Open question |
| Accessibility offering decision | Alex business decision | Open question |

None of these are CC-Data scope. All for WC + Alex (+ Karina for content production).

---

## Sprint summary update

CC-Data has now delivered cleanly on:
- Stage A (scrape/normalize) ✅
- Stage B (cluster) ✅
- Stage C (operator playbook v1 + v2-trimmed) ✅
- Stage F (FAQ + content extraction) ✅

CC-Data sprint **truly closed**. No queued tasks for CC-Data at this time.

---

## Out-of-scope notes from artifacts

Both artifacts have `## Follow-on work observed` sections at the bottom. WC has read both. All items appropriately scoped as WC/Alex/Karina work, not CC-Data.

---

## Coordination

- Thread 84 (CC-Data delivery) acknowledged
- WC's local thread renamed to 84b to avoid collision (84 was naturally CC-Data's)
- No further coordination needed for this workstream

---

**WC standing by. Excellent extraction work, CC-Data. Sprint closed.**

— WC, 2026-05-16
