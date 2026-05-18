# Thread 125 · Karina training V2 — deploy fix only

**From:** WC
**To:** CC-Bot (segunda sesión)
**Date:** 2026-05-18
**Supersedes:** thread/124 (V1)

---

## TLDR

PR `feat/karina-training-doc` (rdm-bot) tiene un manual operativo de Karina de ~60pp listo para deploy. **CF Pages preview deploy falla** por "dist not found" — config monorepo wrong. **Screenshots ya están en repo** (Alex los subió, WC los renombró + integró). Solo necesitas:

1. Diagnose CF Pages config
2. Fix con Alex (dashboard) o root wrangler.toml fallback
3. Verify preview + merge + smoke prod

**Spec completo:** `cc-instructions-bot/2026-05-18-karina-training-deploy-and-screenshots.md` (V2 actualizado, supersede V1)

---

## Por qué V2 corrige V1

| Cambio | Detalle |
|---|---|
| Screenshots | Ya hechos por Alex, NO necesitas Chrome MCP |
| Phase A datos | Embebidos como conocidos (PR #113 ya deployó, 7 touchpoints en prod) |
| Scope | Reducido a solo deploy fix |
| Time budget | 2h → 45 min |

---

## Pre-flight obligatorio antes de DoIt

```bash
# 1. Pull rdm-discussion para tener este doc + V2 spec
cd <path>/rdm-discussion
git pull origin main
ls threads/12[3-5]*.md
# Debe mostrar: 123, 124, 125

ls cc-instructions-bot/2026-05-18-karina-training-deploy-and-screenshots.md
# Debe existir

# 2. Pull rdm-bot al branch correcto
cd <path>/rdm-bot
git fetch origin
git checkout feat/karina-training-doc
git pull origin feat/karina-training-doc
git log --oneline -5
# Debe mostrar commit 2128b0f + commits posteriores con screenshots

# 3. Verifica screenshots presentes
ls apps/web/public/karina-training/admin-*.png
# Debe mostrar 7 archivos PNG
```

Si pre-flight falla → reporta a Alex, NO procedas.

---

## Estado actual (5 puntos clave)

| Item | Estado |
|---|---|
| Branch | `feat/karina-training-doc` (rdm-bot) |
| Base commit | `2128b0f` (doc original) + commits posteriores con screenshots y revisiones de contenido |
| CF Pages preview | ❌ Falla "dist not found" |
| Prod | ❌ 404 en /admin/karina-training (no mergeado todavía) |
| PR #113 (in-stay touchpoints) | ✅ Sí deployó (en prod, 7 columnas visibles en /admin/pre-stay) |

---

## Por qué falla CF Pages

```
Build de Astro: OK (Server built in 19.86s)
Output generado en: /opt/buildhome/repo/apps/web/dist/
CF Pages busca en: /opt/buildhome/repo/dist/  ← wrong
```

Algún cambio reciente al dashboard CF Pages config (o nunca estuvo configurado correctamente para monorepo). **Causa probable**: campo "Build output directory" mal apuntado.

---

## Lo que NO sabemos (preguntar a Alex en Phase A)

| Pregunta | Crítica |
|---|---|
| ¿Qué dice "Build output directory" en CF Pages dashboard? | Sí — determina Camino 1 vs 2 |
| ¿Cuándo cambió (si cambió)? | No crítico — solo contextual |
| ¿Alex tiene permisos para editar el dashboard? | Sí — afecta si Camino 1 viable |

---

## Workflow

| Phase | Tiempo | Acción |
|---|---|---|
| **A · Diagnose** | 5-10 min | Preguntar Alex 4 campos dashboard |
| **B · Fix config** | 5-15 min | Alex dashboard fix O root wrangler.toml fallback |
| **C · Esperar redeploy** | 3-5 min | sleep + verificar |
| **D · Smoke preview** | 5 min | 10 checks autenticado |
| **E · Merge** | 2 min | gh CLI o GitHub UI squash |
| **F · Monitor prod** | 5-10 min | sleep + verificar |
| **G · Notify** | 2 min | Msg final a Alex |
| **Total** | **~45 min** | |

---

## Constraints / hard rules

- **NO toques contenido del `.astro`** (texto, prosa, estructura del doc). Es de WC.
- **NO captures más screenshots** (Alex ya los hizo, WC ya los renombró).
- **NO toques otros wranglers** (worker-bot/pago/tours).
- **NO crees nuevos endpoints, migrations, features.**
- **NO mergees** sin que 10 smoke checks pasen.
- **Friday > 5pm Acapulco**: preview OK, NO merge a main hasta lunes.
- **Stuck > 30 min**: stop, reporta a Alex.

---

## Entregables esperados

1. Commits en `feat/karina-training-doc` con fix CF Pages
2. PR mergeado a main vía squash
3. `https://rincondelmar.club/admin/karina-training` responde 200 logged in `karina@`
4. CF Pages deploy verde en prod
5. Mensaje a Alex con URL final + walkthrough recomendado para Karina

---

## Comando para arrancar (copy-paste a CC)

```
Pre-flight:
1. git pull origin main en rdm-discussion
2. git checkout feat/karina-training-doc && git pull en rdm-bot
3. Verifica 7 PNG en apps/web/public/karina-training/

Después lee:
- threads/125-wc-karina-training-deploy-v2.md
- cc-instructions-bot/2026-05-18-karina-training-deploy-and-screenshots.md

Ejecuta DoIt según las 7 phases (A-G).

Time budget: 45 min. Stuck > 30 min: stop + reporta.
```

WC out.
