# Thread 124 · Karina training deploy + screenshots handoff

**From:** WC
**To:** CC-Bot
**Date:** 2026-05-18
**Type:** DoIt handoff

---

## TLDR

Hay un PR pushed (`feat/karina-training-doc` commit `2128b0f` en `rdm-bot`) con un doc de training de 60 páginas para Karina en `/admin/karina-training`. **CF Pages build está fallando** por config de output dir wrong (`dist` vs `apps/web/dist`). Necesitas:

1. Diagnose + fix el CF Pages config
2. Capturar 7 screenshots /admin/* con Chrome MCP autenticado
3. Verify preview + merge a main + smoke prod
4. Reportar live URL a Alex

**Spec completo:** `cc-instructions-bot/2026-05-18-karina-training-deploy-and-screenshots.md`

---

## Why this matters

Alex pidió manual operativo para Karina, su co-host. Vive en /admin/karina-training. Bloquea su onboarding hasta que esté live + screenshots reales.

---

## Estado actual

| Item | Status |
|---|---|
| Branch `feat/karina-training-doc` con doc HTML | ✅ Pushed |
| `apps/web/src/pages/admin/karina-training/index.astro` (2698 líneas) | ✅ Done |
| Card en `/admin/` navbar | ✅ Done |
| `apps/web/public/karina-training/README.md` con instrucciones screenshots | ✅ Done |
| CF Pages preview deploy | ❌ Failed "dist not found" |
| Screenshots reales | ❌ Pending Chrome MCP |
| Merge a main | ❌ Bloqueado por deploy |
| Prod live `/admin/karina-training` | ❌ 404 |

---

## Build log relevante

```
2026-05-18T21:52:05.962Z [build] Server built in 19.86s
2026-05-18T21:52:05.962Z [build] Complete!
2026-05-18T21:52:07.902Z Validating asset output directory
2026-05-18T21:52:07.902Z Error: Output directory "dist" not found.
2026-05-18T21:52:08.763Z Failed: build output directory not found
```

Build de Astro completa OK (genera output en `/opt/buildhome/repo/apps/web/dist/`). CF Pages busca `dist/` en root → no existe.

Causa probable: dashboard CF Pages "Build output directory" no apunta a `apps/web/dist`, o config del wrangler en root falta.

---

## Lo que NO sabemos todavía

| Pregunta | Quién responde | Cómo |
|---|---|---|
| ¿Último deploy exitoso fue cuál commit? | Alex | CF Pages dashboard → Deployments history |
| ¿"Build output directory" en CF dashboard es `apps/web/dist` o vacío/`dist`? | Alex | CF Pages → Settings → Builds & deployments |
| ¿PR #113 (in-stay/post-stay touchpoints) deployó OK? | Alex | Verificar si `/admin/pre-stay` muestra 6 touchpoints o solo 4 |

**CC: pídele esto a Alex como primer step de Phase A.**

---

## Camino sugerido

| Phase | Acción | Tiempo |
|---|---|---|
| A · Diagnose | Verificar config CF Pages + último deploy success | 10 min |
| B · Fix deploy | Dashboard fix (Alex) o root wrangler.toml (CC) | 5-15 min |
| C · Screenshots | 7 capturas autenticadas con Chrome MCP | 60 min |
| D · Verify preview | 10 smoke checks en preview URL | 10 min |
| E · Merge | Squash merge a main | 2 min |
| F · Monitor prod deploy | Esperar CF Pages, verify | 5 min |
| G · Smoke prod + notify | Confirm en prod, msg a Alex | 5 min |
| **Total** | | **~2h** |

---

## Constraints / hard rules

- **NO toques contenido del doc** (texto, prosa, estructura del `.astro`). Eso es de WC.
- **NO toques otros wranglers** (worker-bot, worker-pago, worker-tours).
- **NO crees nuevos endpoints, funciones, migrations.**
- **NO subas screenshots con PII real** sin review manual + sanitización.
- **NO mergees** sin que los 10 smoke checks de Phase D pasen.
- **Friday > 5pm** Acapulco: no deploy a prod, espera lunes.
- **Stuck > 30 min**: stop, reporta.

---

## Entregables esperados

Al final:

1. Branch `feat/karina-training-doc` con commits adicionales (fix + screenshots)
2. PR mergeado a main vía squash
3. `https://rincondelmar.club/admin/karina-training` retornando 200 logged in
4. 7 screenshots en `apps/web/public/karina-training/admin-*.png`
5. CF Pages deploy verde en prod
6. Mensaje resumen a Alex con URL final

---

## Comando para arrancar

```
Lee cc-instructions-bot/2026-05-18-karina-training-deploy-and-screenshots.md y ejecuta DoIt.
```

Pre-flight check antes de arrancar:
- ¿Tienes acceso write a `rdm-bot` y `rdm-discussion`?
- ¿Tienes Chrome MCP disponible?
- ¿Alex está disponible para responder preguntas críticas en Phase A y Phase C?

Si los 3 son sí → arranca con Phase A. Si alguno no, reporta a Alex.

---

WC out.
