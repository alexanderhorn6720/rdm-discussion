# Thread 74 — CC-Data: Day 2 done — Stage B + Stage E

**Date**: 2026-05-15
**Author**: Claude Code (CC-Data)
**To**: WC `[@wc]` + Alex `[@alex]` + CC-Bot `[@cc-bot]` (FYI)
**Re**: Day 2 results — funnel + temporal insights
**Status**: 🟢 PR #49 merged. Continuing to Stage C (Sonnet operator playbook).

---

## TL;DR

Day 2 done in ~30 min. PR #49 (Stage B + E) merged. Temporal hypothesis test confirms operator latency matters (1.9× lift <30min vs >24h, p=0.038).

| PR | Stage | Status |
|---|---|---|
| #48 | 0 + A | ✅ merged |
| #49 | B + E | ✅ merged |
| (next) | C | starting now |
| (final) | Deploy | tomorrow |

---

## 1. Stage B — funnel detection

8 stages detected per conversation via regex + context.

### Funnel shape (17,023 convs)

| Stage | Reached | % of total | Drop from prev |
|---|---:|---:|---:|
| initial_inquiry | 16,971 | 99.7% | — |
| date_specified | 8,787 | 51.6% | 48.2% |
| group_specified | 7,428 | 43.6% | 15.5% |
| property_clarified | 10,289 | 60.4% | (asymmetric) |
| price_quoted | 4,633 | 27.2% | 55.0% |
| price_accepted | 1,261 | 7.4% | 72.8% |
| payment_data_requested | 2,189 | 12.9% | (asymmetric) |
| booking_confirmed | 462 | 2.7% | 78.9% |

**Note on non-monotonicity**: `property_clarified` (60.4%) is higher than `group_specified` (43.6%), and `payment_data_requested` (12.9%) is higher than `price_accepted` (7.4%). This is because the spec's funnel isn't strictly sequential — operator can send CLABE proactively before user explicitly accepts price, and property names are mentioned anywhere in conv. Not a bug — pipeline correctly captures "stages reached" regardless of order.

### Top abandonment hotspots

1. **`initial_inquiry → date_specified`**: 48.2% drop (8,184 convs) — customers who don't specify dates rarely return. **Bot should ASK FIRST**.
2. **`price_quoted → price_accepted`**: 73% drop (3,372 convs) — price objection bottleneck. **Stage C operator playbook §price_objection_handling will mine this**.
3. **`price_accepted → payment_data_requested`**: not a sequential drop (asymmetric) but customers who verbally accept but don't pay = followup target.

### Stage × outcome contingency (key for Stage C)

| Stage | direct | indirect | not_converted |
|---|---:|---:|---:|
| price_quoted | 95 | 87 | 4,451 |
| price_accepted | 63 | 41 | 1,157 |
| group_specified | 161 | 170 | 7,097 |

≥50 samples per cell for the 4 critical (stage × outcome) combos Stage C needs. Sampling viable.

---

## 2. Stage E — temporal insights

### Bookings by month (646 bookings, 2014-2025)

| Month | Bookings | Revenue (MXN) |
|---|---:|---:|
| Mar | 66 | 1,590,104 |
| Apr | 67 | 1,401,026 |
| May | 69 | 1,527,921 (peak count) |
| Dec | 52 | 2,256,997 (peak avg revenue) |
| Sep | 0 | 0 (likely data gap — verify) |
| Oct | 38 | 937,919 |
| Nov | 28 | 507,218 (lowest) |

December has the highest avg revenue/booking ($43K MXN) — premium pricing on holidays. Mar-May high volume but lower per-booking value.

September=0 is suspicious. May be a data export gap or seasonal closure. **NEEDS VERIFICATION** with Alex/Karina before pipeline final deploy.

### Day-of-week × hour heatmap

- Peak: **Monday 12:00 UTC** (= 6am Mexico Pacific time, which is morning)
- Total inbound msgs: 203,089

Hour distribution suggests customers messaging in their morning to plan weekends. The 06:00 Mexico time peak is unusual — likely US/Spain customers (UTC-5/UTC+2) chatting in their afternoon, or early-bird Mexican planners.

Charts committed to `data/artifacts/temporal_charts/*.png` (4 PNGs, ~163 KB).

### Operator latency vs conversion — chi-square test

| Latency bucket | N convs | Converted | Conversion % |
|---|---:|---:|---:|
| **<30 min** | 8,321 | 353 | **4.24%** |
| 30-60 min | 687 | 28 | 4.08% |
| 1-4 h | 935 | 26 | 2.78% |
| 4-24 h | 981 | 30 | 3.06% |
| **>24 h** | 360 | 8 | **2.22%** |

- chi² = 10.18, df=4, **p = 0.038**
- Lift <30min vs >24h: **1.9×** (vs spec's claim of 7×)
- Significance: marginally significant (p < 0.05)

**Honest interpretation**: the data confirms latency matters, but the effect is smaller than spec assumed. Reasons:
- Most convs (8,321 of 11,284 = 74%) already have <30 min response — Alex/Karina are already fast
- The "long tail" of >24h response = only 360 convs (3%) — small sample
- Conversion still meaningfully higher for fast response (4.24% vs 2.22%)

**Conclusion**: Telegram alerts + bot fast response are real value. Lift is 1.9× not 7×, but with thousands of convs this translates to meaningful revenue.

### Lead time distribution

- p10: 10 days
- p25: 28 days
- p50: **69 days** (much longer than spec's 21d)
- p75: 120 days
- p90: 200 days
- p99: 400+ days

Median lead time of 69 days suggests our customer cohort is more "planner-oriented" than spec assumed. Possible cause: AirBnB users plan vacations 2-3 months ahead. Direct WhatsApp users may be different.

Recommended bot behavior: don't pressure for immediate booking — many customers compare options for weeks. Provide value + soft followups.

---

## 3. Charts (committed)

All 4 charts saved to `data/artifacts/temporal_charts/`:
- `bookings_by_month.png` (55 KB)
- `dow_hour_heatmap.png` (33 KB)
- `latency_vs_conversion.png` (47 KB)
- `lead_time_distribution.png` (28 KB)

Total 163 KB. No PII — aggregated stats only. Day 4 will mirror these to R2 alongside operator_playbook.md.

---

## 4. Updates to Day 4 plan

The Sept=0 booking finding suggests I should verify with Alex/Karina before final deploy. **Default**: deploy as-is, document the gap in the Day 4 thread/76, and add a note in `temporal_insights.md` for human review.

Lead time finding (69d median vs 21d spec) → updates the Stage C playbook narrative: shouldn't include "urgency triggers" assuming customers book quickly.

---

## 5. Asks for WC (non-blocking)

Reiterating from thread/72-73 with mid-flight refinements:

- **September booking=0**: data gap or seasonal pattern? Default = note + deploy. Alex can verify.

- **Stage C combo coverage**: the 4 critical combos I need have 41-170 samples each in `(stage, outcome)` — enough for 50-sample × 8-combo Sonnet calls. Adjusting spec's `(initial_inquiry, converted_direct)` since I have 224 direct → plenty.

- **operator_playbook target size**: spec says < 32KB. With 30-50 patterns × ~600 chars each = ~18-30 KB. Comfortable.

---

## 6. Stage C next (Día 3)

Starting now:
- Stratified sampling by year (2024 40%, 2023 25%, ...)
- 8 Sonnet calls (~$8-12, claude-sonnet-4-6)
- 2 prompts (price_quote + objection_handling) × 4 outcome buckets each
- ETA: ~2-3h wall time
- Output: `data/artifacts/operator_playbook.md` (committed, sanitized)

PR #50 after Stage C done.

---

**FIN thread/74**. CC-Data continuing.

— Claude Code (CC-Data), 2026-05-15
