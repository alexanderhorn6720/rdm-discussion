---
thread: 236
author: CC-Bot
date: 2026-05-29
topic: doit-235-completion
type: result
status: done
ref_thread: 235
pr: 202
branch: feat/crons-nativos-cf
---

# CC-Bot — DoIt thread/235 completado

## PR

**PR #202** — `feat(worker-bot): crons nativos CF — migración GH Actions → scheduled() nativo`
Branch: `feat/crons-nativos-cf`

## Qué se hizo

| Item | Estado |
|---|---|
| `wrangler.toml` — 4 cron expressions | ✅ |
| `scheduled()` como dispatch table por `event.cron` | ✅ |
| `tickAndGet()` extraído a `cron.ts` | ✅ |
| `runCostStalenessCheck()` extraído a `cost-telemetry.ts` | ✅ |
| `/admin/normalize-beds24-events` usa `tickAndGet()` | ✅ |
| `/admin/cost-staleness` usa `runCostStalenessCheck()` | ✅ |
| `scheduled-dispatch.ts` — dispatcher + `runTaskSafe` | ✅ |
| 21 × `cron-*.yml` — `schedule:` removido, `workflow_dispatch:` intacto | ✅ |
| Tests 19 tests nuevos, todos verdes | ✅ |
| Typecheck limpio | ✅ |
| 1212 tests totales verdes (63 archivos) | ✅ |

## Estructura del dispatcher

```
*/15 * * * *  → pulse
  normalize (batchLimit 100)
  processReadyInquiries (cronTick)
  pollClientBotMessages
  runWelcomeAutoSend
  checkAndSendReminders
  cronTick % 8 == 0 → runScheduledRefresh   (÷8 ≈ 2h, respeta TTL KV)
  cronTick % 4 == 0 → runBotAlerts          (÷4 ≈ 1h)

0 15 * * *    → daily 09:00 MX
  inquiriesAutoClose · conversationsAutoClose · syncReviews ·
  scanForCaptures · runCostStalenessCheck · syncDirectSubscribers ·
  scanForWelcome/T14/T7/T1/Arrived/PreCheckout/PostStay ·
  buildDailyDigest

0 8 1 * *     → monthly
  cleanupShortLinks

0 10 * * *    → eval (sin cambios, gated por eval_framework_enabled)
```

## Post-merge (Alex hace)

1. `cd apps/worker-bot && npx wrangler deploy` — worker-bot NO tiene auto-deploy
2. CF Dashboard → rincon-bot → Settings → Triggers → verificar que aparecen 4 crons
3. Esperar 1 primer pulse (~15 min) → Cloudflare Logs → buscar `event: cron_task, ok: true`
4. `/admin/health` → heartbeats frescos (normalize, refresh, etc.)
5. Al día siguiente → confirmar que daily (`0 15 * * *`) corrió (~09:00 MX)
6. 1 semana en verde → PR separado para borrar archivos `cron-*.yml` completos

## Decisiones tomadas

- `scheduled-dispatch.ts` como archivo nuevo (no inline en index.ts) para mantener el dispatcher testeable via imports directos.
- `runTaskSafe()` exportado: isolation try/catch por tarea, log estructurado `{event, task, cron, ok}`.
- Gate ÷8 para refresh respeta TTL 2h del KV_KNOWLEDGE. Gate ÷4 para alerts = ~1h.
- `fetch-reviews.yml` NO tocado: escribe al repo directamente (no llama al worker vía ADMIN_REFRESH_SECRET).
- Doble ejecución durante transición no es riesgo: todas las tareas son idempotentes por diseño.

## Sorpresas / notas

Ninguna. El spec era preciso y el código ya estaba bien factorizado — la migración fue mover el punto de invocación, no la lógica.

## Tiempo y costo

Tiempo: ~1.5h sesión. LLM cost: <$1 (Sonnet 4.6, tarea de infra pura).
