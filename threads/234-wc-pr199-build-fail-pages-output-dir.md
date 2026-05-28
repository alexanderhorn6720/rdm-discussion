---
thread: 234
author: wc
date: 2026-05-28
topic: pr199-build-fail-pages-output-dir-diagnostico
mode: incident-report
status: open-for-next-session
references:
  - PR #199 (feat/inquiry-bot-infra)
  - threads/232 (DoIt PR1 inquiry-bot)
  - threads/233 (CC reporte PR1 complete)
---

# thread/234 — Incidente: PR #199 build de Pages falla (output dir mismatch)

> **Para la sesión de mañana.** El código del PR #199 está LIMPIO. El bloqueo NO es código — es config de Cloudflare Pages. Diagnóstico cerrado, falta aplicar fix.

## TL;DR

- PR #199 (inquiry-bot PR1) NO mergeable: `mergeable_state: unstable`.
- Único check rojo: **Cloudflare Pages build failed** (3 intentos: `eb1a14c`, `69db2f0`, `60b012f`).
- **Causa raíz identificada (NO es código):** el build de `apps/web` compila perfecto, pero al final Pages busca el output en `dist/` (raíz del repo) y Astro lo escribe en `apps/web/dist/`. Mismatch de config.
- **Error literal del log de Pages:**
  ```
  Error: Output directory "dist" not found.
  Failed: build output directory not found
  ```
- El build local (`cd apps/web && pnpm build`) PASA idéntico → confirma que el código está bien.

## Qué se descartó (no era esto)

CC pusheó 3 fixes pensando que era código. Los 3 eran correctos pero NO eran la causa:

| Commit | Fix aplicado | ¿Era la causa? |
|---|---|---|
| `eb1a14c` | (PR original) | — |
| `69db2f0` | fragments `<>` → `<span>` en inquiry-replies.astro | No (real, pero no causa) |
| `60b012f` | biome format + import order + noImplicitAnyLet + CRLF→LF | No (real, pero no causa) |

CC reportó "TypeScript limpio, 29 tests pasando" — cierto, pero `tsc` ≠ `astro build` ≠ upload de Pages. El error ocurre DESPUÉS del build, en el paso de upload, que no se reproduce en local.

## Causa raíz (detalle técnico)

El log de Pages muestra:
```
Using v2 root directory strategy          ← NUEVO. CF migró el proyecto a v2.
No Wrangler configuration file found.      ← corre desde raíz /opt/buildhome/repo, no ve apps/web/wrangler.toml
Executing: pnpm install --frozen-lockfile && pnpm --filter web build
...
[build] Complete!                          ← build OK
directory: /opt/buildhome/repo/apps/web/dist/   ← Astro escribe AQUÍ
...
Error: Output directory "dist" not found.  ← Pages busca en /opt/buildhome/repo/dist/
```

**El mismatch:**
- Build corre desde la RAÍZ del monorepo.
- Output dir configurado en dashboard de Pages = `dist` (relativo a raíz → `/opt/buildhome/repo/dist/`).
- Astro escribe en `apps/web/dist/`.
- Pages no encuentra `dist/` → falla.

**Por qué empezó ahora:** sospecha fuerte = CF migró el proyecto a "v2 root directory strategy" (aparece explícito en el log, es nuevo). Eso reinterpretó las rutas. NO fue un cambio del PR ni de Alex. Implicación: TODOS los deploys de Pages futuros fallarían igual hasta arreglar esto — el PR #199 solo fue el primero en toparse.

**Dato clave:** existe `apps/web/wrangler.toml` con `pages_build_output_dir = "dist"`, pero Pages NO lo lee porque corre desde la raíz (el log dice "No Wrangler configuration file found"). El root directory en el dashboard está vacío/raíz, no `apps/web`.

## Opciones de fix (decisión de Alex mañana)

### Opción A — Dashboard (RECOMENDADA por WC) ✅
Dashboard → `rincondelmar-bot` → Settings → Build → **Build output directory** = `apps/web/dist` → Save → Retry deployment en `60b012f`.
- 30 seg, cero riesgo, no toca código.
- Desbloquea este PR Y todos los deploys futuros.
- Alex declinó esta opción en sesión de hoy (no quiere tocar dashboard).

### Opción B — wrangler.toml en raíz (por código, RIESGOSA)
Crear `wrangler.toml` en la raíz del repo con `pages_build_output_dir = "apps/web/dist"` + replicar TODA la config de Pages.
- ⚠️ Riesgo alto: la doc de CF dice que el wrangler.toml se vuelve "source of truth" y DESACTIVA la edición de esos campos en dashboard. Hay que replicar exacto ~15 vars + 3 bindings (D1 `d81622d7-...`, KV `033ee15...`, R2 `rdm-knowledge`) sin equivocar un ID, o se rompe producción (admin emails, roles staff, magic-link).
- Además, riesgo de que un `wrangler.toml` en raíz confunda los deploys manuales de worker-bot/worker-pago (aunque esos corren desde sus subdirs, deberían leer su propio toml).
- Solo hacer si Alex acepta el riesgo conscientemente.

### Opción C — Ajustar root directory en dashboard a `apps/web`
Dashboard → Root directory = `apps/web`, build command = `pnpm install --frozen-lockfile && pnpm build`, output = `dist`.
- Entonces Pages SÍ leería `apps/web/wrangler.toml` (que ya tiene `pages_build_output_dir = "dist"` correcto relativo a apps/web).
- También dashboard, mismo "no quiero tocarlo" de hoy.

### Opción NO probada — Retry simple
Si el fallo es 100% por la migración v2 de CF y no por config previa, puede que un **Retry deployment** del último build verde anterior, o re-trigger, ya funcione. Descartar lo trivial primero (gratis).

## Estado del PR #199 (lo que SÍ está bien)

Verificado vía GitHub MCP + CF MCP contra prod real:

| Item | Estado |
|---|---|
| Migration 0052 | ✅ Correcta. Prod tiene 0051 como última aplicada, 0052 libre |
| Tabla `pending_inquiry_replies` en prod | ✅ NO existe aún (correcto, Alex aplica post-merge) |
| Deps runtime (`bot_config`, `bot_messages_inbox`, `beds24_events`) | ✅ Existen en prod |
| Anti-loop (3 capas: echo, terminal status, reset cap 5) | ✅ Sólido |
| Integración runBeds24Normalize (best-effort) | ✅ No rompe batch |
| Casa Chamán filtrada (679176) | ✅ |
| Build local `pnpm build` | ✅ PASA |
| Build Pages (upload) | 🔴 Falla por output dir |

## 2 issues abiertos (no bloquean, para antes de PR2 canary)

Alex ya los abrió en rdm-bot:
1. `beds24_event_id` guarda booking ID, no event ID — UNIQUE semánticamente incorrecto, bomba de tiempo antes de canary auto-send.
2. Doble parse en enqueueInquiryReply — perf menor.
Ambos se cierran con el mismo cambio de firma: `enqueueInquiryReply(env, parsed, ev)`.

## Orden de acciones mañana

1. **Descartar lo trivial:** Retry deployment del PR #199 sin tocar nada. Si pasa → era glitch v2 transitorio.
2. Si no: aplicar Opción A (dashboard, output dir = `apps/web/dist`) o decidir B/C.
3. Build verde → merge PR #199 (squash).
4. **Post-merge manual (memoria #5 — worker-bot NO auto-deploy):**
   - `cd apps/worker-bot && npx wrangler deploy`
   - `wrangler d1 migrations apply rincon --remote` (migration 0052)
5. Smoke test (checklist del PR #199): inquiry → PIR awaiting_processing → 5min → approval_pending; pause; backup sweep.
6. Issues 1+2 → antes de PR2 canary.

## Lección para el sistema

`tsc` limpio + tests verdes ≠ build de Pages verde. Son 3 pipelines:
1. `tsc --noEmit` (typecheck)
2. `astro build` (compila, genera dist)
3. Pages upload (busca dist en el lugar configurado)

Un fallo en (3) NO se reproduce con (1) ni (2) en local. Para diagnosticar fallos de Pages: SIEMPRE leer el log real del dashboard, no inferir desde tsc/tests. CC pusheó 2 veces a ciegas antes de que el log revelara que no era código.

---

*FIN thread/234. Diagnóstico cerrado, fix pendiente decisión Alex. — WC, 2026-05-28*
