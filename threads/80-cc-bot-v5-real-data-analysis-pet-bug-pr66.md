# Thread 80 — CC-Bot: real data v4 vs v5 + v4 bug (pet) + PR #66 + ops update

**Date**: 2026-05-16 ~16:30 UTC
**Author**: Claude Code (CC-Bot)
**To**: WC `[@wc]` + Alex `[@alex]`
**Re**: Production canary 50% data + autonomous work status
**Status**: 🟢 v5 strong production data + 1 PR more merged

---

## 1. 🎉 PRIMERA DATA REAL v4 vs v5 (n=19, 50% canary, 24h)

Después del deploy de PR A7.6.1 (greeter_turns logging) + canary 50%:

| Metric | v4 (n=14) | v5 (n=5) | Win |
|---|---|---|---|
| **Avg latency** | 3,200ms | **1,600ms** | **v5 2x más rápido** ✅ |
| **Escalate rate** | 14% (2/14) | **0%** | **v5** ✅ (target era <2%) |
| **Fallback path** | n/a | **0%** | v5 ✅ |
| **Avg tokens input** | 3,065 | **364** | v5 88% menos (cache hits) |
| **Avg cache hits** | 7,400 | 6,800 | similar |

### v5 tool distribution (real)

- `route_user_to_url`: 60% (3/5) — incluyendo nuevo smart greeting `casas`
- `request_clarification`: 40% (2/5) — incluyendo handling de URL TikTok ("¿Ese video es de una de nuestras villas?")
- `escalate_to_human`: 0% ✅
- `handoff_to_booker`: 0%
- `fallback`: 0% ✅

### Sample openings v5 (QA)

- "¡Buenos días! Soy Felix de Rincón del Mar 🌅. Tenemos 4 villas: Rincón del Mar (c..." (smart greeting working ✅)
- "Perfecto, acá tenés los precios y fotos de Rincón del Mar. ¡Mirá todos los detal..." (correct property routing ✅)
- "¿Qué información específica necesitás de Rincón del Mar? (precios, fotos, dispon..." (good clarification ✅)
- "¿Ese video es de una de nuestras villas o querés saber más sobre alguna propieda..." (smart handling of URL ✅)

---

## 2. 🚨 BUG observado en v4 production: "no son pet-friendly"

Turn `2026-05-16 05:10:47` (subscriber via canary v4 path):

```
USER:      Es petfriendly?
ASSISTANT: Las propiedades no son pet-friendly — no aceptamos mascotas en l...
                                                                      ↑
                          INCORRECTO — política real es $300/noche max 2
```

Política oficial v5 (Q-56-1 resolved): **$300 MXN/noche por mascota, máximo 2 por reserva**. v4 prompt está stale (no se updateó cuando se cambió la política).

**Impacto**: 50% de users con pregunta sobre mascotas reciben respuesta incorrecta. Probable lost lead (pet owner se fue).

**Mitigaciones posibles**:
- (a) **Recomendada**: scale canary a 75-100% v5 → menos users tocan v4
- (b) Fix v4 prompt (riesgo: v4 era supuesto deprecated, no tiene buen test coverage para prompt edits)
- (c) Force_v5 para todos los users que mencionen "pet|mascota" (complex, hard to detect cleanly)

**Sugiero (a)** — datos justifican scale agresivo.

---

## 3. Recomendación scale canary

Data al 50%:
- v5 0% escalate (vs 14% v4)
- v5 2x faster
- v5 0 fallbacks
- v5 tool distribution healthy

**Mi recomendación**: scale a **75% directo** (no necesario stage intermedio 60%). Justificación:
- Sample chico (n=5 v5) — pero TODOS los turns fueron quality OK
- v4 tiene bug activo (pet policy) — costo real per turn que sigue en v4
- Riesgo rollback bajo: 1 curl revierte a 50% si algo aparece raro

```powershell
# Scale 75%:
curl.exe -X POST "https://bot.rincondelmar.club/admin/canary" `
  -H "x-admin-secret: $env:ADMIN_REFRESH_SECRET" `
  -H "content-type: application/json" `
  -d '{\"newPercent\":75,\"byUser\":\"alex-stage75-data-driven\"}'
```

Si querés más conservador: 60% → observar 12h → 75% → observar 12h → 100%.

Si querés más aggressive: 100% directo.

Tu llamada.

---

## 4. PR A7.7.4 merged (#66) — Karina readonly role

Permite que staff (Karina) vea dashboards admin sin riesgo de tocar canary por accidente.

- Nueva env var `ADMIN_READONLY_EMAILS` en CF Pages
- Karina puede VER /admin/health, /admin/bot-metrics, /admin/conv (Inspect)
- NO puede Reset/Pause/Unpause conv ni modificar canary
- Defense en depth: UI hide + proxy server-side check + worker auth

**Para activar**: agregá `karina@rincondelmar.club` (o el email que use) a env var
`ADMIN_READONLY_EMAILS` en CF Pages settings. CF Pages auto-deploy ya pickeó
el código.

---

## 5. Vectorize status (CC-Data territory pero monitor)

Al last check (~16:30 UTC): **6,700 / 17,023 embedded (39%)**. ETA ~17:30 UTC para terminar todos los embeds, después ~30 seg upsert batch → total done ~17:35 UTC.

0 errors hasta ahora.

---

## 6. Acciones inmediatas Alex

| # | Acción | Por qué |
|---|---|---|
| 🔴 | Decidí scale canary (60/75/100%) | Data justifica acelerar — v4 bug activo |
| 🟡 | wrangler deploy (incluye PRs A #61 + B #62 + A7.7.4 #66 server-side) | Endpoints conv ops + alerts nuevos no activos hasta deploy |
| 🟢 | (Opcional) Agregar `ADMIN_READONLY_EMAILS` env CF Pages para Karina | UX-only, sin urgencia |
| 🟢 | Confirmá si querés que arregle v4 pet bug (opt B) o solo scale (opt A) | Decisión tuya |

---

## 7. Standby

CC-Bot continúa autónomo. Próximas tareas pendientes en mi backlog:
- PR A7.7.6: `/admin/conv` enhancements (search por phone partial, history view)
- Monitor Vectorize completion
- Si pedís: PR para fix v4 pet bug (small prompt edit)

Wake-ups programados cada ~45min para chequear Vectorize.

---

**FIN thread/80**.

— Claude Code (CC-Bot session), 2026-05-16 16:30 UTC
