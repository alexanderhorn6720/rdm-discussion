---
thread: 227
author: CC
date: 2026-05-28
topic: worker-pago-beds24-auth-refresh-report
mode: brain
status: done
refs:
  - thread/226
  - pr/196
---

# Thread 227 — Reporte: Beds24 auth refresh en worker-pago (thread/226)

## Resultado

PR #196 abierto: `fix(worker-pago): Beds24 token auto-refresh vía KV_KNOWLEDGE`

Branch: `fix/worker-pago-beds24-auth-refresh`  
Tests: 40/40 worker-pago + 649/649 web — verdes  
Typecheck: limpio

## Qué se hizo

Mismo patrón que thread/224 (apps/web) aplicado a worker-pago:

| Archivo | Cambio |
|---|---|
| `wrangler.toml` | Agrega `[[kv_namespaces]] KV_KNOWLEDGE` (id `033ee15acf3744c096e83342d2e81dd4`) |
| `src/beds24-auth.ts` | Nuevo — copia de worker-bot con docstring actualizado |
| `src/types.ts` | Agrega `KV_KNOWLEDGE: KVNamespace` y `BEDS24_REFRESH_TOKEN?: string` a WorkerEnv |
| `src/beds24-payment.ts` | `BedsPaymentEnv` + import + usa `getBeds24AccessToken` en lugar de `env.BEDS24_TOKEN` directo |
| `src/beds24-release.ts` | Mismo patrón |
| `src/webhook-mp.ts` | `confirmToken = await getBeds24AccessToken(env)` en PATCH confirm |
| `src/crons.ts` | Elimina guard `if (!env.BEDS24_TOKEN)` en `mpPaymentRetry` (innecesario — `pushMpPayment` ya maneja el error) |
| `tests/*.test.ts` | Agrega `KV_KNOWLEDGE: makeKv(null)` a todos los envs de tests |

## Backwards compatibility

Path 3 (fallback a `BEDS24_TOKEN` estático) se mantiene intacto — el worker funciona sin `BEDS24_REFRESH_TOKEN` ni KV poblado. La transición es transparente.

## Post-merge checklist

- [ ] Deploy: `bash scripts/safe-deploy.sh worker-pago` (o `npx wrangler deploy --name rincon-pago`)
- [ ] Opcional: `wrangler secret put BEDS24_REFRESH_TOKEN --name rincon-pago` si Alex quiere activar auto-refresh de largo plazo
- [ ] Procesar pago stuck `161308218526` ($1,000 anticipo) — puede hacerse via `/admin` o trigger manual del cron retry
- [ ] Verificar `mpPaymentRetry` cron procesa filas `beds24_push_status='error'` en el siguiente tick de 30 min

## Sorpresas / decisiones

- Ninguna. El patrón era idéntico a thread/224. La única diferencia es que worker-pago tiene 4 sitios que usaban `env.BEDS24_TOKEN` directamente (vs 1 en apps/web) — todos corregidos.
- El guard `if (!env.BEDS24_TOKEN)` en `mpPaymentRetry` fue eliminado porque `pushMpPayment` ahora maneja el error de token internamente y retorna `ok: false`.

## Tiempo / costo

~30 min. Costo LLM: dentro de doit_normal tier.
