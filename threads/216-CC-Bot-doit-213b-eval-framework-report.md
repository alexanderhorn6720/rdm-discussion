---
thread: 216
author: CC-Bot
date: 2026-05-26
topic: doit-213b-eval-framework-report
mode: result
status: done
refs:
  - thread/213b
  - pr/189
---

# CC-Bot DoIt 213b Report — Greeter Eval Framework v0.5

## Estado

✅ PR #189 abierto en `feat/greeter-eval-framework`. Tests pasan (1160/1160). Listo para review de Alex.

## Deliverables completados

| ID | Entregable | Estado |
|----|-----------|--------|
| E1 | Migration 0049 — `greeter_eval_cases` + `greeter_eval_runs` | ✅ |
| E2 | `eval-engine.ts` — `runEval`, `scoreEval`, `runReplay`, `runSynthetic` | ✅ |
| E3 | `admin-eval.ts` — 7 endpoints `/api/admin/eval/*` | ✅ |
| E4 | `eval.astro` + `EvalDashboard.tsx` | ✅ |
| E5 | `wrangler.toml [[triggers]]` + scheduled handler | ✅ |
| E6 | 30 synthetic seed cases en migration | ✅ |
| E7 | 8 anti-regression tests (14 tests total en el archivo) | ✅ |
| E8 | Telegram alert cuando score_pct < 85% + `bot_config eval_framework_enabled=false` | ✅ |

## Anti-patterns verificados

- ✅ NO LLM-as-judge — scoring 100% determinístico
- ✅ NO compares vs v6 — baseline es v7 (100% canary)
- ✅ 30 casos con `expected_opening_line_excludes` incluyendo "Iris", "/noche", "NUNCA"
- ✅ Cron 04:00 MX = UTC 10:00 (`"0 10 * * *"`)
- ✅ Default OFF (`eval_framework_enabled=false`)

## Nota sobre spec thread

Thread 213b no existía en `rdm-discussion/threads/` al inicio del DoIt. El spec estaba embebido en el mensaje del DoIt. Procedí con ese spec.

## Scoring logic (v0.5)

```
score per case = passing_checks / active_checks

Checks (cada uno vale 1 punto):
  1. intent_ok       — result.intent === expected_intent (skipped si NULL)
  2. intent_slug_ok  — URL slug === expected_intent_slug (skipped si NULL o intent≠route)
  3. includes_ok     — reply contiene todos los strings de includes (skipped si NULL)
  4. excludes_ok     — reply NO contiene ninguno de los strings de excludes
  5. validator_ok    — v7-validator pasa
```

## Decisión importante: cron slot conflict

⚠️ worker-pago ocupa 5/5 slots de cuenta (ADR-003 §2.2). Si `wrangler deploy` falla por conflict:
1. Comentar `[triggers]` en `apps/worker-bot/wrangler.toml`
2. Activar cron via GH Actions: POST `/api/admin/eval/run` con `x-admin-secret`

El handler `/api/admin/eval/run` funciona independientemente del cron nativo.

## Pasos post-merge (para Alex)

1. Aplicar migration: `cd apps/web && npx wrangler d1 migrations apply rincon --remote`
2. Verificar: `SELECT COUNT(*) FROM greeter_eval_cases;` → esperado 30
3. Deploy: `bash scripts/safe-deploy.sh rincon-bot`
4. Smoke test: `POST /api/admin/eval/replay/ec001` con header `x-admin-secret`
5. UI: `/admin/eval` → confirmar tabla de 30 casos carga
6. Para activar cron: `UPDATE bot_config SET value='true' WHERE key='eval_framework_enabled';`

## Métricas

- Tiempo: ~2h
- Test files: 59 → 1160 tests, 0 failures
- TypeScript: clean en worker-bot
- LLM cost estimado: <$1 (sin llamadas reales a Anthropic)
