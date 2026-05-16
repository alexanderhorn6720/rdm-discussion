# Thread 76 — CC-Data: Day 4 + Sprint complete — Stage Deploy pipeline ready

**Date**: 2026-05-15
**Author**: Claude Code (CC-Data session)
**To**: WC `[@wc]` + Alex `[@alex]` + CC-Bot `[@cc-bot]`
**Re**: Final state of Data Mining v2 sprint — handoff for execution + CC-Bot PR A6.1
**Status**: 🟢 4 PRs merged, pipeline ready-to-run, awaiting Alex's wrangler+API key for cloud deploy

---

## TL;DR

CC-Data sprint complete in ~3h wall time (vs spec's 3-4 day estimate). All 4 PRs merged. Pipeline produces D1 seeds (~65k rows total), R2 uploads (4 markdown artifacts), and Vectorize embeddings (17k vectors) — ready for Alex to execute when convenient.

| PR | Branch | Stage | Merged |
|---|---|---|---|
| #48 | `feat/data-stage0-business-filter` | scaffold + Stage 0 + A | ✅ |
| #49 | `feat/data-stage-b-funnel-e-temporal` | Stage B + E | ✅ |
| #51 | `feat/data-stage-c-operator-playbook` | Stage C pipeline | ✅ |
| #52 | `feat/data-stage-deploy-d1-r2-vectorize` | Stage Deploy | ✅ |

---

## 1. Sprint metrics

| Stage | Input | Output | Wall time |
|---|---|---|---:|
| Stage 0 | 437k msgs | 5,956 phones classified | 2.7s |
| Stage A | 377k biz+unclear msgs | 17,023 conversations + outcomes | 11.4s |
| Stage B | 17k convs | 52,031 funnel records | 27s |
| Stage E | 646 bookings + 17k convs | 4 PNG charts + chi² test | 1.7s |
| Stage C | 17k convs | 520 anonymized samples + 4 prompts (dry-run) | 1.8s |
| Stage Deploy D1 | 7.5k contacts + 17k convs + 52k funnel | 65k rows of seed SQL | 3.1s |
| Stage Vectorize | 17k convs | 17k vector specs ready | 0.2s (dry-run) |
| Stage Deploy R2 | 4 artifacts | 4 upload commands queued | <1s |

Total pipeline compute: ~50s. Most time was in Stage B (regex over 377k messages).

LLM cost projected (Stage C --execute): **~$1.10** Sonnet 4.6 (vs spec's $8-12 conservative estimate).
Vectorize cost projected: **~$0.19** Workers AI bge-m3 paid tier.
Total real cost: ~$1.30 — far under thread/55's $15-25 budget.

---

## 2. What needs Alex to execute (when convenient)

### 2.1 Stage C: actual Sonnet calls

```powershell
$env:ANTHROPIC_API_KEY = 'sk-ant-...'
python scripts/data-mining/stage_c_operator_playbook.py --execute
```

Result: `data/artifacts/operator_playbook.md` populated with extracted patterns.
ETA: ~30 min wall time (4 calls × ~5min each, Tier 1 rate limit ok).

### 2.2 Stage Deploy D1

```powershell
# Regenerate fresh SQL (if not already present locally):
python scripts/data-mining/stage_deploy_d1.py

# Apply to production D1 (idempotent — ON CONFLICT DO NOTHING):
wrangler d1 execute rincon --remote --file=scripts/data-mining/outputs/stage_deploy/seed_guests.sql
wrangler d1 execute rincon --remote --file=scripts/data-mining/outputs/stage_deploy/seed_leads.sql
wrangler d1 execute rincon --remote --file=scripts/data-mining/outputs/stage_deploy/seed_guest_events.sql

# Verify:
wrangler d1 execute rincon --remote --command "SELECT status_master, COUNT(*) FROM guests GROUP BY status_master"
wrangler d1 execute rincon --remote --command "SELECT COUNT(*) FROM leads"
wrangler d1 execute rincon --remote --command "SELECT event_type, COUNT(*) FROM guest_events GROUP BY event_type"
```

Expected counts:
- `guests`: 7,423 rows (`prospect` ~6,800 + `customer` ~600 + `repeat`/`vip` ~30 + others)
- `leads`: 5,876 rows
- `guest_events`: 51,425 rows

### 2.3 Stage Vectorize

```powershell
# Create index (one-time):
wrangler vectorize create rdm-conversations-v2 --dimensions=1024 --metric=cosine

# Upsert vectors:
$env:CF_ACCOUNT_ID = '...'
$env:CF_API_TOKEN = '...'   # Workers AI + Vectorize edit scopes
python scripts/data-mining/stage_vectorize.py --execute
```

ETA: 17k embeddings × ~0.5s each = ~2.5h wall time. Could run overnight.

### 2.4 Stage Deploy R2

```powershell
python scripts/data-mining/stage_deploy_r2.py --execute
```

4 markdown uploads to `r2://rdm-knowledge/` — runs in ~10s with wrangler authenticated.

---

## 3. Handoff to CC-Bot for PR A6.1

CC-Bot's future PR A6.1 (Greeter v5 system prompt upgrade) reads:

| R2 path | Purpose | Status after Alex executes Stage R2 |
|---|---|---|
| `r2://rdm-knowledge/operator_playbook.md` | Inject into Greeter v5 system prompt | ✅ after Stage C `--execute` |
| `r2://rdm-knowledge/temporal_insights_v2.md` | Reference for prompt context | ✅ ready |
| `r2://rdm-knowledge/funnel_v2.md` | Reference for funnel-aware bot behavior | ✅ ready |
| `r2://rdm-knowledge/knowledge_reconstruction_v2.md` | Background on data corpus | ✅ ready |

CC-Bot D1 reads after Alex executes Stage Deploy D1:
- `SELECT * FROM guests WHERE phone_e164 = ?` — guest 360 lookups
- `SELECT * FROM leads WHERE guest_id = ?` — context for in-flight prospects
- `SELECT * FROM guest_events WHERE guest_id = ? ORDER BY occurred_at DESC LIMIT 20` — recent activity

CC-Bot Vectorize reads after Stage Vectorize execute:
- Similarity search `rdm-conversations-v2` for "show me convs like this one" → operator playbook lookup at runtime

---

## 4. Key findings vs spec (recap)

### 4.1 Data scale corrections

| Item | Spec estimate | Real | Notes |
|---|---:|---:|---|
| messages.csv rows | 437k | 437k ✓ | (my thread/72 typo corrected) |
| business conversations | 6,500 | 17,023 | 7-day gap creates 2.6x more episodes |
| guests | 6,800 | 7,423 | close — banned filter removed 76 |
| leads | 6,000 | 5,876 | one per phone (not per conv) |
| guest_events | 50k | 51,425 | matches |
| direct conversion rate | 5-10% | 1.3% | 43% of bookings are AirBnB-only (no WA) |

### 4.2 Spec items NOT implemented

- **beds24_bookings seed**: skipped (Q-72-1 default). Source CSV lacks Beds24-native IDs. Real bookings come from live webhook PR A2.
- **September=0 booking anomaly**: noted, needs Alex/Karina verification before Stage E findings are quoted in marketing.
- **Manual Stage 0 sample review**: queued — 100 sample rows in `outputs/stage_0/manual_review_sample.parquet` for offline eyeball. Not blocking.

### 4.3 thread/57 critical mitigations applied

- ✅ §1 chat-to-contact.json — bypassed via wa_chats.csv (better source)
- ✅ §2 Outcome 3-value enum + cancellation filter + AirBnB causality in `lib/outcome_classifier.py`
- ✅ §3 bge-m3 multilingual (NO bge-base-en) confirmed in `stage_vectorize.py`
- ✅ §4 Stage 0 conservative threshold (manual sample review pending)
- ✅ §5 Stage C stratified year sampling (40% 2024, 25% 2023, ...)
- ✅ §6 D1 90KB batch size guard in `lib/d1_batcher.py`
- ✅ §7 Funnel regex with contextual rules
- ✅ §8 PEPPER-salted phone hash in `lib/phone_hash.py`
- ✅ §10 Cancellation filter via `total_paid == 0` proxy (CSV lacks status column)

---

## 5. What lives in the repo (final state)

```
rincondelmar-bot/
├── scripts/data-mining/                    ← committed pipeline code
│   ├── README.md
│   ├── requirements.txt                    (duckdb, pandas, anthropic,
│   │                                        matplotlib, scipy, requests, pytz)
│   ├── lib/
│   │   ├── phone_hash.py                   (PEPPER hash + e164 normalize)
│   │   ├── outcome_classifier.py           (3-value enum logic)
│   │   ├── d1_batcher.py                   (batched INSERT with size guard)
│   │   └── ulid.py                         (Crockford base32 ULID gen)
│   ├── stage_0_business_filter.py
│   ├── stage_a_reconstruct.py
│   ├── stage_b_funnel.py
│   ├── stage_c_operator_playbook.py
│   ├── stage_e_temporal.py
│   ├── stage_deploy_d1.py
│   ├── stage_deploy_r2.py
│   ├── stage_vectorize.py
│   ├── reports/                            ← sanitized stats, committed
│   │   ├── stage_0_business_filter.md
│   │   ├── stage_a_reconstruct.md
│   │   ├── stage_b_funnel.md
│   │   ├── stage_c_operator_playbook.md
│   │   ├── stage_e_temporal.md
│   │   ├── stage_deploy_d1.md
│   │   └── stage_vectorize.md
│   └── outputs/                            ← GITIGNORED (PII intermediates)
├── data/artifacts/                         ← committed sanitized artifacts
│   ├── operator_playbook.md                (placeholder, populated by Stage C --execute)
│   └── temporal_charts/
│       ├── bookings_by_month.png
│       ├── dow_hour_heatmap.png
│       ├── latency_vs_conversion.png
│       └── lead_time_distribution.png
└── migrations/0024_data_v2_seed_marker.sql (no-op marker)
```

Pipeline disk footprint:
- Committed: ~200 KB (4 PNGs + reports + scripts)
- Local-only (gitignored): ~17 MB SQL + 2 GB parquet intermediates
- 0 PII committed to repo

---

## 6. Coordination ack — what CC-Data DID and DIDN'T touch

### DIDN'T touch (CC-Bot territory):
- `apps/worker-bot/` — no edits
- `packages/agents/` — no edits
- `apps/web/src/pages/admin/bot-metrics.astro` — no edits
- `apps/web/src/lib/admin-bot-metrics.ts` — no edits
- `apps/web/src/lib/admin-health.ts` — no edits
- `.github/workflows/cron-bot-alerts.yml` — no edits
- `.github/workflows/cron-client-bot-poll.yml` — no edits
- `bot_config` table — no INSERT, no ALTER
- migrations `0001-0023` — no modifications
- `scripts/photos/` — no edits (other Claude session)

### DID touch (CC-Data territory):
- `scripts/data-mining/` — new folder
- `data/artifacts/` — new folder (sanitized + committed)
- `migrations/0024_data_v2_seed_marker.sql` — new migration (no-op marker)
- `.gitignore` — added `scripts/data-mining/outputs/` + `data/raw/` patterns

### D1 schemas (per Q-69-1 §7 ack):
- `guests` — INSERT only, NO ALTER TABLE
- `leads` — INSERT only, NO ALTER TABLE
- `guest_events` — INSERT only, NO ALTER TABLE
- `beds24_bookings` — NO INSERT (Q-72-1 skip)

---

## 7. Open items for WC/Alex post-sprint

1. **Run Stage C --execute** when Alex has 5 min + API key handy (~$1.10 cost)
2. **Validate operator_playbook.md** — spec says Alex 25-min validation step
3. **Run Stage Deploy** (D1 seed → R2 upload → Vectorize) when wrangler ready
4. **Verify September=0 booking data** in raw export (data gap vs seasonality)
5. **Future**: CC-Bot's PR A6.1 reads `r2://rdm-knowledge/operator_playbook.md` for Greeter v5 prompt upgrade

---

## 8. Final honesty check

### What went well
- Pipeline runs fast (~50s total compute on 437k msgs)
- All 4 critical mitigations from thread/57 audit are integrated
- Cost projection 10x under spec's conservative estimate (~$1.30 vs $15-25)
- Schemas freezed respect (INSERT only, no ALTER)
- Coordination zero-friction (4 PRs to main, base force, auto-merge — no conflicts with CC-Bot's parallel work)

### What I shipped non-ideal
- **operator_playbook.md is a placeholder** — needs Alex to run --execute
- **D1 deploys not actually applied** — needs wrangler auth, I don't have access
- **Vectorize index not created** — same
- **Stage 0 manual review** queued, not done
- **Stage A median_response_time** only computed for 11,284 / 17,023 convs (66%) — single-sender/single-turn convs have no latency by definition

### What I'd do differently next time
- Get API keys / wrangler auth available up-front for the autonomous session
- Stage B funnel "non-monotonic" stages would be clearer as a "intent markers detected" model rather than calling it a funnel
- 7-day gap might be too aggressive — could test 14d/30d and compare conversion rates

---

**FIN sprint Data Mining v2**. CC-Data session standby. WC + Alex own next steps.

— Claude Code (CC-Data), 2026-05-15
