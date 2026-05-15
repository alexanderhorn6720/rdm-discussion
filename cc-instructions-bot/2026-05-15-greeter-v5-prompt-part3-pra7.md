# Execute Greeter v5 — Part 3: PR A7 Canary + Dashboard + Deliverables

**Continúa de**: `2026-05-15-greeter-v5-prompt-part2-pra6.md`

---

## 4. PR A7 — Canary rollout + admin metrics dashboard

### 4.1 Scope

PR A7 is mostly **autonomous CC** — WC doesn't need to spec the dashboard UI in detail. CC decides component design.

What WC specifies here:
1. Canary feature flag mechanics (deterministic hash)
2. Stage progression policy (10→25→50→100)
3. Metrics dashboard minimum data points
4. Telegram alert on stage transitions
5. Rollback procedure

### 4.2 Canary feature flag

**Hash-based deterministic assignment** (same user gets same version across turns):

```typescript
// apps/worker-bot/src/canary.ts

/**
 * Returns true if subscriber should be in v5 canary.
 * Deterministic: same subscriber_id → same assignment, always.
 */
export function isInCanaryV5(
  subscriberId: string,
  canaryPercent: number,
): boolean {
  if (canaryPercent <= 0) return false;
  if (canaryPercent >= 100) return true;

  // Hash subscriber_id to [0, 99]
  const hash = djb2Hash(subscriberId) % 100;
  return hash < canaryPercent;
}

function djb2Hash(str: string): number {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) + hash) + str.charCodeAt(i);
    hash = hash >>> 0; // force unsigned 32-bit
  }
  return hash;
}
```

**Stored in env var `CANARY_PERCENT`** (number 0-100). Updated via `wrangler` redeploy or D1 dynamic config:

```typescript
// Option A: env var (simple, requires redeploy)
const canary = parseInt(env.CANARY_PERCENT || '0', 10);

// Option B: D1 dynamic config (no redeploy needed)
const config = await env.DB.prepare(
  'SELECT value FROM bot_config WHERE key = ?',
).bind('canary_percent_v5').first<{ value: string }>();
const canary = parseInt(config?.value || '0', 10);
```

**WC recommendation**: Option B (D1) — Alex can scale canary without redeploy.

Migration for option B:
```sql
-- migrations/0023_bot_config.sql
CREATE TABLE IF NOT EXISTS bot_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_by TEXT
);

INSERT OR IGNORE INTO bot_config (key, value, updated_by)
VALUES
  ('canary_percent_v5', '0', 'pr-a7-initial'),
  ('greeter_version_force', '', 'pr-a7-initial');
```

### 4.3 Stage progression

CC: implement as series of D1 UPDATE statements + Telegram notif. NO automatic scaling — Alex decides each stage transition.

**Stages**:

| Stage | Percent | Duration | Success criteria | Telegram action |
|---|---|---|---|---|
| 0 | 0% | — | v5 ready in main, all tests pass | Notify Alex: "v5 ready for canary" |
| 1 | 10% | 24h | <5% error rate, no critical bugs reported | Alex approves → bump to 25 |
| 2 | 25% | 48h | CTR ≥80% of v4 baseline, no Alex interventions needed | Alex approves → 50 |
| 3 | 50% | 48h | Conversion rate ≥ v4 (measured by clicks → bookings tier) | Alex approves → 100 |
| 4 | 100% | — | v4 deprecated | Notify Alex: "v5 full rollout complete" |

**Each stage progression**:

```typescript
// apps/worker-bot/src/admin/canary.ts (admin endpoint)

export async function POST_canaryScale(request, env): Promise<Response> {
  const { newPercent, byUser } = await request.json();

  if (newPercent < 0 || newPercent > 100) {
    return new Response('Invalid percent', { status: 400 });
  }

  const oldConfig = await env.DB.prepare(
    'SELECT value FROM bot_config WHERE key = ?',
  ).bind('canary_percent_v5').first<{ value: string }>();
  const oldPercent = parseInt(oldConfig?.value || '0', 10);

  await env.DB.prepare(
    'UPDATE bot_config SET value = ?, updated_at = datetime(\'now\'), updated_by = ? WHERE key = ?',
  ).bind(String(newPercent), byUser, 'canary_percent_v5').run();

  // Telegram notif
  await notifyTelegram({
    text: `🚦 Greeter v5 canary scaled: ${oldPercent}% → ${newPercent}% (by ${byUser})`,
  });

  return new Response(JSON.stringify({ ok: true, oldPercent, newPercent }), {
    headers: { 'content-type': 'application/json' },
  });
}
```

Auth: this endpoint needs admin guard (`x-admin-secret` header).

### 4.4 Admin dashboard `/admin/bot-metrics`

**Page location**: `apps/web/src/pages/admin/bot-metrics.astro`

**Auth**: Better Auth gated, `role IN ('admin', 'super_admin')`.

**Minimum data points** to display (CC decides layout):

#### Section 1: Canary state

```
Current canary v5: 25% (since 2026-05-16 10:00 UTC, 18h ago)
Subscribers in v5: ~520 of ~2100 active (estimated)

[Buttons: 10%] [25%] [50%] [100%] [Force v4] (admin only)
```

#### Section 2: Tool usage (last 7 days, grouped by version)

```sql
SELECT
  bot_version,
  metadata_json->>'tool_used' AS tool,
  COUNT(*) AS calls,
  AVG(metadata_json->>'latency_ms') AS avg_latency
FROM greeter_logs
WHERE created_at > datetime('now', '-7 days')
GROUP BY bot_version, tool
ORDER BY calls DESC;
```

Render as table or stacked bar chart. **WC note**: greeter_logs table may not exist — CC decides whether to add it or use existing bot_link_clicks + human_handoff_log.

#### Section 3: Click-through rate by intent

```sql
SELECT
  intent_slug,
  COUNT(*) AS clicks,
  COUNT(DISTINCT conv_hash) AS unique_users
FROM bot_link_clicks
WHERE clicked_at > datetime('now', '-7 days')
GROUP BY intent_slug
ORDER BY clicks DESC
LIMIT 20;
```

Top 20 intents — useful to see if `precios`, `disponibilidad`, `fotos` dominate vs long-tail.

#### Section 4: Handoffs pending + resolved

```sql
SELECT
  reason,
  urgency,
  COUNT(*) AS total,
  SUM(CASE WHEN human_responded_at IS NOT NULL THEN 1 ELSE 0 END) AS responded,
  AVG(strftime('%s', human_responded_at) - strftime('%s', notified_at)) / 60.0 AS avg_response_minutes
FROM human_handoff_log
WHERE notified_at > datetime('now', '-7 days')
GROUP BY reason, urgency;
```

Useful for: are we escalating too much? Are humans responding?

#### Section 5: v4 vs v5 comparison

```sql
-- Conversion proxy: clicks per conversation
WITH conv_clicks AS (
  SELECT
    conv_hash,
    bot_version,
    COUNT(*) AS clicks_per_conv
  FROM bot_link_clicks
  WHERE clicked_at > datetime('now', '-7 days')
  GROUP BY conv_hash, bot_version
)
SELECT
  bot_version,
  COUNT(*) AS conversations_with_clicks,
  AVG(clicks_per_conv) AS avg_clicks_per_conv,
  SUM(CASE WHEN clicks_per_conv >= 2 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS multi_click_rate
FROM conv_clicks
GROUP BY bot_version;
```

If v5 has higher `multi_click_rate` (user clicks more than 1 link), it's a positive signal — engagement increased.

#### Section 6: Top opening_lines (sample)

```sql
SELECT
  metadata_json->>'tool_used' AS tool,
  reply,
  COUNT(*) AS frequency
FROM greeter_logs
WHERE bot_version = 'v5'
  AND created_at > datetime('now', '-24 hours')
GROUP BY reply
ORDER BY frequency DESC
LIMIT 20;
```

Spot-check what the LLM is generating — catch hallucinations / patterns.

### 4.5 Telegram alerts on key events

CC: add notification triggers for:

1. **Error rate spike** (>5% errors in last 100 calls): "⚠️ Greeter v5 error rate at X%"
2. **Latency degradation** (p95 >5s): "⏱️ v5 latency p95 = X.Xs"
3. **Escalate volume spike** (>20% of conversations escalating): "🚨 Escalation rate at X%"
4. **Stage transition** (admin scales canary): "🚦 Canary v5: X% → Y%"

Implementation:
```typescript
// apps/worker-bot/src/admin/metrics-watch.ts (cron job, every 5 min)

async function checkMetricsAndAlert(env: Env): Promise<void> {
  // Error rate check
  const errorRate = await env.DB.prepare(`
    SELECT
      SUM(CASE WHEN intent = 'error' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS rate
    FROM greeter_logs
    WHERE bot_version = 'v5' AND created_at > datetime('now', '-30 minutes')
  `).first<{ rate: number }>();

  if (errorRate && errorRate.rate > 0.05) {
    await notifyTelegram({
      text: `⚠️ Greeter v5 error rate at ${(errorRate.rate * 100).toFixed(1)}%`,
      urgency: 'high',
    });
  }

  // ... other checks
}
```

Add to `wrangler.toml`:
```toml
[[triggers.crons]]
cron = "*/5 * * * *"
```

### 4.6 Rollback procedure

If something goes wrong post-deploy:

```bash
# Option 1: Set canary back to 0%
curl -X POST https://bot.rincondelmar.club/admin/canary \
  -H "x-admin-secret: $ADMIN_REFRESH_SECRET" \
  -H "content-type: application/json" \
  -d '{"newPercent": 0, "byUser": "alex-rollback"}'

# Option 2: Force everyone to v4
wrangler d1 execute rincon --remote --command \
  "UPDATE bot_config SET value = 'v4_force' WHERE key = 'greeter_version_force'"

# Option 3: Nuclear — revert PR A4+A6 in code
git revert <PR-A6-merge-commit> <PR-A4-merge-commit>
git push origin main
# Auto-deploy triggers
```

Add to `docs/runbook.md` (or whatever exists).

### 4.7 PR A7 acceptance criteria

- [ ] D1 migration `bot_config` table applied
- [ ] `isInCanaryV5()` deterministic hash function with tests
- [ ] Admin endpoint POST `/admin/canary` with `x-admin-secret` auth
- [ ] Dashboard page `/admin/bot-metrics` Better Auth gated
- [ ] 6 metric sections rendered (canary state, tool usage, CTR, handoffs, comparison, sample openings)
- [ ] Telegram alerts cron job (error rate, latency, escalate spike, stage transitions)
- [ ] Rollback procedure documented in runbook
- [ ] Smoke test: scale to 10% → verify isInCanary returns ~10% of test subscribers

---

## 5. Implementation order (CC roadmap)

WC suggests sequential, NOT parallel:

```
Day 1 (CC ~5-6h):
  Morning:
    □ Read this 3-part spec end-to-end (~30min)
    □ Implement PR A4 (tool definitions, integration, anti-loop) (~3h)
    □ Vitest tests for A4 (~1h)
    □ Self-review + push PR #36 (~30min)
  
  Afternoon:
    □ WC review PR #36 (async)
    □ Address WC comments (if any)
    □ Merge #36

Day 2 (CC ~4-5h):
  Morning:
    □ Implement PR A6 (system prompt v5 verbatim from §3.2) (~1h paste)
    □ Few-shot examples integration (~30min)
    □ Migration shim runGreeterV4 / runGreeterV5 (~1h)
    □ Vitest tests from §3.5 (~2h — these are critical, do not skip)
  
  Afternoon:
    □ Run tests, iterate on prompt if any test fails
    □ Push PR #37
    □ WC review + merge

Day 3 (CC ~3-4h):
  Morning:
    □ Implement PR A7 (canary, dashboard, admin endpoint) (~3h)
    □ Tests for canary deterministic hash
  
  Afternoon:
    □ Deploy with CANARY_PERCENT=0 (no users affected yet)
    □ Smoke test: force v5 with env var, verify 1 conversation works end-to-end
    □ Telegram Alex: "v5 ready, scale to 10%?"

Day 4 (Alex action):
  □ Alex scales to 10% via admin endpoint
  □ Watch dashboard for 24h
  □ If green → scale to 25%
  □ Continue progression per §4.3
```

**Total ETA from spec → 100% canary: ~3-5 días elapsed.**

---

## 6. Coordination with WC

### 6.1 Async review points

WC reviews each PR before merge:
- PR #36 (A4) — focus on tool schema correctness + intent-resolver integration
- PR #37 (A6) — focus on prompt verbatim match to §3.2 + test coverage
- PR #38 (A7) — focus on canary determinism + dashboard data points

### 6.2 Open questions for CC (clarify before starting)

WC anticipates these may need clarification:

- **Q-A4-1**: ¿Existe `greeter_logs` table o solo `bot_link_clicks`/`human_handoff_log`?
  - If NO: CC decides whether to add `greeter_logs` table (recommended for dashboard) OR derive metrics from existing tables.
- **Q-A4-2**: ¿`/internal/notify-human` espera todos los fields del escalate_to_human tool, o solo subset?
  - CC verifies endpoint signature, adjust integration if needed.
- **Q-A6-1**: ¿Prompt caching v5 funcionará con tools? Confirm Anthropic API caching + tools interaction in current SDK version.
- **Q-A7-1**: ¿Better Auth ya tiene `role` field para gating `/admin/bot-metrics`? CC checks existing schema.

If ANY of these block progress, CC publishes `thread/65-cc-greeter-v5-questions.md` and waits for WC.

### 6.3 Reporting cadence

CC publishes:
- Per PR: brief summary in commit message + thread when merged
- End of Day 1: `thread/XX-cc-greeter-v5-day1.md` with progress
- End of Day 2: `thread/XX-cc-greeter-v5-day2.md`
- Day 3 deploy: `thread/XX-cc-greeter-v5-ready-canary.md` with Alex action items

WC responds to threads within 2h during work hours.

---

## 7. Out of scope (explicit)

NOT in this spec / NOT in this sprint:
1. ❌ PR A6.1 — system prompt upgrade post-Data-Mining-v2 (operator playbook). Separate spec, post-Data v2.
2. ❌ PR A8 — split AirBnB vs WhatsApp prompts (D8). Defer to post-baseline.
3. ❌ Booker v4 refactor. Booker keeps current implementation, just receives handoff via new tool schema.
4. ❌ Casa Chamán integration. Q3 2026 launch.
5. ❌ New intents beyond catalog in §3.2 §INTENT_CATALOG. If CC discovers need for new intent during impl, document in thread, do NOT add unilaterally.
6. ❌ Changes to `apps/web/src/pages/` (anchors etc — those are PR A1+A1.5, done).
7. ❌ Changes to MercadoPago integration.
8. ❌ Changes to Beds24 sync.
9. ❌ Changes to ManyChat configuration. Greeter v5 lives in worker-bot, ManyChat just relays messages as today.

---

## 8. Risk register

| Risk | Probability | Mitigation |
|---|---|---|
| LLM hallucinates URL despite tool_choice='any' | Low | Schema validation catches it, log + escalate |
| Tool calls have latency >3s, ManyChat timeout | Medium | Set 35s timeout on ManyChat webhook, monitor p95 |
| Anti-loop false positive (legit user iterates) | Medium | User can override by calling escalate explicitly |
| Canary 25% reveals critical bug | Medium | Rollback procedure documented (§4.6) |
| Prompt caching breaks with tools | Low | Test in PR A6 acceptance, monitor cache hit rate |
| Few-shot examples bias toward over-deflection | Medium | Watch dashboard §5 click-through rate |
| Booker still expects old `bookingData` schema | High | Compat shim in PR A4 §2.4 (verify on PR review) |

---

## 9. WC final notes

### 9.1 What this spec does NOT do

- Does NOT replace Booker. Booker handles transactional booking flow.
- Does NOT add new intents beyond catalog. If `/zonas-acapulco` doesn't exist yet, catalog still references it but resolver falls back.
- Does NOT change ManyChat flows. Webhook to worker-bot stays the same.
- Does NOT add Spanish/English content translation tooling. Lang is detected, content is already bilingual via separate `/en/` routes.

### 9.2 What success looks like

After 1 week at 100%:
- Greeter v5 handles 80%+ of conversations without human handoff
- Average response latency <2s
- CTR (clicks per conversation) ≥ 0.6 (most users click at least once)
- Escalate rate <15%
- Zero P0 hallucination incidents (no false prices, no fake amenities, no fake promises)

### 9.3 What success does NOT look like

- "Bot replaces humans entirely" — escalate path is critical, Karina/Alex still close deals
- "Bot generates better content than site" — bot deflects, doesn't generate
- "100% accuracy" — some friction is acceptable; goal is reducing repetitive load on humans

### 9.4 Personal note from WC

This spec stresses **strict constraints over flexibility**. The bigger risk with LLMs in customer-facing roles is hallucination, not stiffness. WhatsApp users tolerate brief, link-heavy replies if those replies actually help. They do not tolerate fake promises, invented prices, or fake "Karina te contesta en 5 min" lines that never resolve.

CC, when in doubt during implementation, err toward more guardrails / fewer permissions for the LLM. If a user wants more conversational depth, escalate path is one tool call away.

---

**END OF SPEC. CC: arranca cuando estés listo.**

— Web Claude, 2026-05-15 (autonomous mode, ~hour 1 of 3)
