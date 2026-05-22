---
thread: 181
author: WC
date: 2026-05-22
topic: cc-doit-budget-tier-spec-t5-fine-tune
mode: DoIt
status: ready-for-cc-execution
target_session: sesión CC nueva en `c:/dev/rdm/dev/bot/`
inputs:
  - thread/175 (DoIt original — T1-T5 shipped)
  - thread/180 (CC post-merge report — bug fix + budget surprise $185)
  - thread/179b §2.6 (master backlog item)
alex_votes_constraints:
  budget_tiers:
    exploration: 5
    doit_normal: 50
    doit_multi_cc: 100
  default_tier: doit_normal
deliverable: 1 PR a rdm-bot con worker env bump + T5 hook reading frontmatter + T3 schema additive field
estimated_cc_time: 30-45 min
estimated_llm_budget_usd: 3
halt_global_budget_usd: 7.5
daily_cost_budget_usd: 50
---

# DoIt CC — Budget tier fine-tune T5 hook

## §0 Pre-flight obligatorio

1. `cd c:/dev/rdm/dev/bot` && `git pull --rebase origin main`
2. `cd c:/dev/rdm/dev/discussion` && `git pull --rebase origin main`
3. Verify shipped post thread/175:
   - `test -f apps/worker-bot/src/cron/ccusage-daily.ts` (or equivalent T2 path)
   - `test -f .claude/hooks/PostToolUse-cost-check.sh`
   - `wrangler.toml` worker-bot has `DAILY_COST_BUDGET_USD` var
4. Halt si pre-flight falla.

## §1 Contexto

Thread/175 T1-T5 shipped. ccusage LIVE. T5 cost-limit hook activo
pero default `DAILY_COST_BUDGET_USD=5` es demasiado bajo para
operación normal con Opus 4.7. Spend real día 2026-05-22 = $185
(multi-CC + WC pesado + Opus + 2 DoIts paralelos).

Sin esta spec, T5 halt CC en ~5 min de operación normal.

Alex votó tiers; este DoIt los implementa.

## §2 Scope

### SÍ

- B1: Bump worker env `DAILY_COST_BUDGET_USD` default 5 → 50 en `wrangler.toml`
- B2: T3 schema (`rdm-discussion/schemas/thread.schema.json`) añadir field opcional `daily_cost_budget_usd: integer | null` (no break legacy)
- B3: T5 hook (`.claude/hooks/PostToolUse-cost-check.sh`) leer frontmatter del thread current (parse YAML primera matter block), usar `daily_cost_budget_usd` si existe, fallback al env var
- B4: Test E2E: simula 3 thread frontmatters (exploration=5, doit_normal sin field, doit_multi_cc=100), verifica hook compara correcto
- B5: Actualizar `rdm-bot/CLAUDE.md` con explicación tier + cuándo declarar `daily_cost_budget_usd`

### NO

- NO tocar T1/T2/T3/T4 lógica core (solo additive)
- NO tocar apps/worker-bot/src/cron/* lógica
- NO añadir L1 alert para tiers (Telegram solo critical 1.5×, igual que hoy)
- NO tocar `KV_IDEMPOTENCY`, D1 schema, cron triggers
- NO touch otros workers (`worker-pago`, `worker-tours`, `worker-feedback`)
- NO open issues
- NO refactor

## §3 Decisiones cerradas

1. Tier values: `exploration=5`, `doit_normal=50`, `doit_multi_cc=100` (alias names solo documentación, hook lee número raw del frontmatter)
2. Frontmatter field: `daily_cost_budget_usd: number` (opcional). Si ausente, hook usa env `DAILY_COST_BUDGET_USD`. Si env también ausente, hook usa 50 hardcoded fallback.
3. Hook trigger 1.0× = warning Telegram (low priority); 1.5× = halt + critical Telegram. (Sin cambio, igual que thread/175 T5.)
4. Hook puede leer frontmatter del thread current cómo:
   - Si CC corre dentro de un thread (env `RDM_THREAD_CURRENT` o file `.claude/thread-current.txt`), parse ese frontmatter
   - Sino, env var fallback
5. Branch: `feat/budget-tier-finetune`
6. Conventional commit: `feat(hooks): budget tier — frontmatter override env + tier docs`

## §4 Implementación

### B1 — Worker env bump (5 min)

`apps/worker-bot/wrangler.toml`:
```toml
[vars]
DAILY_COST_BUDGET_USD = "50"  # was "5", bumped per Alex thread/179b §2.6
```

Deploy via `pnpm --filter worker-bot deploy` (smoke verde post).

### B2 — T3 schema additive (5 min)

`rdm-discussion/schemas/thread.schema.json` — añadir a properties:
```json
{
  "daily_cost_budget_usd": {
    "type": ["integer", "null"],
    "minimum": 1,
    "maximum": 1000,
    "description": "Per-thread budget override. If absent, env DAILY_COST_BUDGET_USD applies. Tiers: 5 (exploration), 50 (doit_normal), 100 (doit_multi_cc)."
  }
}
```

NO añadir a `required`. Es opcional.

### B3 — Hook frontmatter override (15 min)

`.claude/hooks/PostToolUse-cost-check.sh`:
```bash
#!/bin/bash
# Reads frontmatter daily_cost_budget_usd if available, else env

# Locate current thread (best effort)
THREAD_FILE=""
if [ -n "$RDM_THREAD_CURRENT" ]; then
  THREAD_FILE="$RDM_THREAD_CURRENT"
elif [ -f ".claude/thread-current.txt" ]; then
  THREAD_FILE=$(cat .claude/thread-current.txt)
fi

# Try to extract daily_cost_budget_usd from frontmatter
BUDGET_FROM_THREAD=""
if [ -f "$THREAD_FILE" ]; then
  BUDGET_FROM_THREAD=$(awk '/^---$/{f++} f==1{print} f==2{exit}' "$THREAD_FILE" \
    | grep -E '^daily_cost_budget_usd:' \
    | sed -E 's/^daily_cost_budget_usd:\s*([0-9]+).*$/\1/')
fi

# Fallback chain: frontmatter → env → hardcoded
BUDGET="${BUDGET_FROM_THREAD:-${DAILY_COST_BUDGET_USD:-50}}"

# Rest of original hook logic (call /api/cost, compare, alert/halt)
# ... (mantener lógica existente, solo cambiar referencia a $BUDGET)
```

### B4 — Test E2E (10 min)

`scripts/tests/test_budget_tier.sh`:
```bash
#!/bin/bash
# Test 1: exploration tier (5)
cat > /tmp/thread-exp.md <<EOF
---
thread: 999
author: WC
daily_cost_budget_usd: 5
---
EOF
RDM_THREAD_CURRENT=/tmp/thread-exp.md bash .claude/hooks/PostToolUse-cost-check.sh
# expect: budget=5 used

# Test 2: no frontmatter field, env fallback
cat > /tmp/thread-normal.md <<EOF
---
thread: 1000
author: WC
---
EOF
DAILY_COST_BUDGET_USD=50 RDM_THREAD_CURRENT=/tmp/thread-normal.md \
  bash .claude/hooks/PostToolUse-cost-check.sh
# expect: budget=50 used

# Test 3: explicit multi_cc tier
cat > /tmp/thread-multi.md <<EOF
---
thread: 1001
daily_cost_budget_usd: 100
---
EOF
RDM_THREAD_CURRENT=/tmp/thread-multi.md bash .claude/hooks/PostToolUse-cost-check.sh
# expect: budget=100 used
```

### B5 — Docs update (5 min)

`rdm-bot/CLAUDE.md` añadir sección "Cost budget tiers":

```markdown
## Cost budget tiers

T5 hook lee `daily_cost_budget_usd` del frontmatter del thread current.
Si ausente, usa env `DAILY_COST_BUDGET_USD` (default 50).

Tiers convencionales (declara explícitamente en frontmatter de cada DoIt):
- `exploration`: 5 — audit/read-only, no writes
- `doit_normal`: 50 — DoIt single session
- `doit_multi_cc`: 100 — DoIt paralelo a otro CC

Hook trigger: 1.0× = Telegram warning. 1.5× = halt CC + critical alert.

Spend real machine-wide día 2026-05-22 fue $185 con multi-CC + Opus.
Default $5 disparaba CRITICAL en 5 min — por eso default subido a $50.
```

## §5 Tests

- B4 test E2E (3 scenarios)
- Smoke post-merge: deploy worker, `curl /api/cost?days=1` 200
- Verify hook NO halt en operación normal post-bump (1 sesión nueva CC de 30 min)

## §6 Definition of Done

- [ ] 1 PR mergeable a main rdm-bot (B1, B3, B4, B5)
- [ ] 1 PR a rdm-discussion (B2 schema additive)
- [ ] Worker deployed con nuevo default
- [ ] Tests B4 pasan local
- [ ] Smoke post-deploy verde
- [ ] PR body referencia `Closes thread/181`
- [ ] Cost real declarado en PR body
- [ ] Self-review (T4 hook ya activo)

## §7 Halt

- Si B3 hook frontmatter parse falla en >1 de 3 test cases → halt + reporta
- Si deploy worker post B1 falla → halt + rollback
- Cost LLM excede $7.50 → halt
- >30 min stuck → halt + reporta

## §8 Out of scope

- L1 alert Telegram para 1.0× (sigue solo critical 1.5×)
- Tier alias names en código (solo documentación)
- Admin API integration (item 4.5 master backlog, defer Q3)
- Per-conversation budget tracking (overkill por ahora)
- Cost dashboard expansion en `/admin/health` (separate spec)

## §9 Reporting al final

Thread response via `bash scripts/new-thread.sh CC-Bot doit-181-budget-tier-report`:

Sections:
1. PR # + LoC
2. Worker deploy verify (curl output con nuevo budget)
3. B4 test results (3/3 pass esperado)
4. Cost total real
5. Tiempo wall-clock
6. DoD checklist

---

— WC, 2026-05-22, DoIt spec budget tier post thread/180 fix + Alex votes.
