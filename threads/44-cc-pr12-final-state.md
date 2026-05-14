# Thread 44 — PR #12 final state + audit

**De:** CC (main thread)
**Para:** Alex
**Fecha:** 2026-05-13
**Status:** PR #12 listo para review final

## Update sobre thread/43

Thread/43 listó PR #12 con 5 commits. Después de tu "continúa" agregué más
trabajo. **PR #12 ahora tiene 15 commits.**

## Commits PR #12 (orden cronológico)

| # | SHA | Scope |
|---|---|---|
| 1 | `6772329` | Fase 2.1 architecture — /welcome/{property} ES + EN |
| 2 | `b15f4fa` | Fase 2.5 — /mi-estancia/welcome auth-gated con WiFi + clave caja |
| 3 | `7023e78` | Fase 2.6 — Bot KB integration con airbnb-content R2 |
| 4 | `04a0069` | UX: preview link a /welcome desde ContentCell editor |
| 5 | `1b9b3c1` | UX: property summary cards en /admin overview |
| 6 | `302922d` | Fix: align preview_bucket_name (no merge conflict con PR #11) |
| 7 | `0aca270` | SEO: include /welcome routes en sitemap, exclude admin/auth-gated |
| 8 | `5e216b3` | Fix: /welcome (no slug) redirects a /guia-llegada |
| 9 | `8b73327` | Test: e2e smoke (welcome routes) + schema-org unit tests |
| 10 | `e35c561` | Test: 21 unit tests para airbnb-content-storage |
| 11 | `46f1abb` | Docs: content-drafting-guide.md para Karina |
| 12 | `f5ba5ee` | Docs: CLAUDE.md aclara boundary deploy rdmbot vs baby-bebe |
| 13 | `2859165` | UX: placeholder mode pulls real property content |
| 14 | `9c9141d` | UX: READY badge + open questions count en property cards |
| 15 | `27eda7b` | Lint: remove unused AIRBNB_FIELDS import |

## Test + build state

### Tests
| Package | Test files | Tests | Status |
|---|---|---|---|
| apps/web | 14 | **162** | ✓ all passing |
| apps/worker-bot | 9 | **196** | ✓ all passing |
| **Total** | **23** | **358** | ✓ |

### Build
- `pnpm --filter web build` → ✓ Astro compila clean
- `pnpm --filter worker-bot build` → ✓ wrangler dry-run, KNOWLEDGE_BUCKET binding visible
- `pnpm --filter web typecheck` → 10 errors, **0 from my code** (pre-existing)
- `pnpm --filter worker-bot typecheck` → ✓ clean

## Pre-existing typecheck errors (NO bloquean PR #12)

Encontrados en typecheck completo, **NO son del trabajo Welcome Guide**:

| File | Issue | Owner |
|---|---|---|
| `apps/web/src/middleware.ts` | RESEND_API_KEY no en AuthEnvBindings | packages/auth |
| `apps/web/src/pages/logout.astro` | Mismo issue auth | packages/auth |
| `apps/web/src/pages/api/auth/[...all].ts` | Mismo issue auth | packages/auth |
| `apps/web/src/pages/proxReservas.astro` | 2× 'possibly undefined' | preexisting |
| `apps/web/src/pages/tour-virtual/las-morenas.astro` | PannellumConfig type | preexisting |
| `apps/web/tests/reviews-api.test.ts` | 4× 'possibly undefined' | preexisting |
| `apps/worker-tours/src/index.ts` | R2 range type | preexisting |
| `packages/llm-client` | typecheck fail | preexisting |
| `packages/mp` | Cannot find name 'fetch' | preexisting (no @cloudflare/workers-types) |
| `packages/shared` | Cannot find name 'D1Database' | preexisting |

Recomendación: filar follow-up issues por estos. NO bloquean ni PR #11 ni PR #12.

## Funcionalidad nueva agregada después de thread/43

### Placeholder mode mejorado (commits 13-14)

**Antes:** /welcome/{property} sin draft mostraba "🚧 Información en construcción"
genérica.

**Ahora:** placeholder pull desde el property collection:
- "🏖️ Sobre la casa" — del long_description (ya existe en /content/properties/{slug}.json)
- "✨ ¿Qué incluye?" — bullets de amenities labels
- "🗺️ Cómo llegar" — address + neighborhood + link a /como-llegar
- "📅 Antes de tu llegada" — siempre presente: dirección + WiFi + staff llegan día antes
- "🚧 Más información" — note honesto

**Resultado:** Karina/Alex pueden visitar /welcome/rincon-del-mar HOY (post-merge)
y ver contenido real. Cuando draftean los fields equivalentes, automáticamente
se reemplazan con sus drafts.

### READY badge (commit 14)

En /admin/airbnb-content overview, cards muestran:
- ✅ READY (verde) cuando: filledFields=9 ∧ alex_ok=9 ∧ openQuestions=0
- ⚠ N open (rojo) cuando: hay {open: ...} pendientes que bloquean deploy

Señal clara "OK Alex, ya puedes decirle a CC que haga write-back AirBnB".

### Tests adicionales (commits 9, 10)

- E2E smoke playwright: 4 props × 2 langs + redirect handling + Schema.org
- Unit tests airbnb-content-storage: 21 tests cubriendo R2 reads/writes,
  approval auto-reset, drift detection
- Schema-org welcomeGuideLd: 12 tests (lang, FAQ append, @id pattern)

## Cambio en mi ContentCell preview link

Karina/Alex ahora ven en footer de cada cell:

```
👁 Preview público — /welcome/rincon-del-mar (es)    Cambios aparecen tras guardar
```

Click → nueva tab con la página real. Cierra el ciclo "edita → guarda → ve resultado".

## Estado de Aggressive Partial mode

**Day 0-1 sprint completado:**
- ✅ Fase 2.1 architecture (estimado 4-6h)
- ✅ Fase 2.5 auth-gated (estimado 2-3h)
- ✅ Fase 2.6 Bot KB integration (estimado 2-3h)
- ✅ UX polish: preview links, property cards, placeholder, READY badge (~1h)
- ✅ Tests: 358 total, +57 nuevos (~1h)
- ✅ Docs: thread/43 + thread/44 + content-drafting-guide.md (~30 min)
- ✅ Phase B.1 agent in parallel (background worktree, PR #11)

**Wall-clock real:** ~14-16h hechos en una vuelta CC + 1 agente.

## Bloqueos pendientes (todos del lado tuyo)

1. Review + merge PR #11 (Phase B.1) — base `pr3-en-blog-extras`
2. Review + merge PR #12 (Welcome Guide) — base `pr3-en-blog-extras`
3. Decidir merge order (recomiendo PR #12 primero per thread/43)
4. Karina drafting el primer batch en /admin/airbnb-content
5. Cuando primer batch listo (✅ READY badge): tú me avisas → write-back AirBnB

## Sin más trabajo independiente productivo

Llegado al punto de diminishing returns en este branch. Más commits añaden
ruido sin valor proporcionado. Stoppeo aquí.

Si quieres que abra otra branch con scope diferente, dime qué priorizar:
- (a) Fix pre-existing typecheck errors (auth + preexisting)
- (b) Wire welcome KB into greeter system prompt (packages/agents/greeter)
- (c) Build /api/admin/welcome-kb-preview endpoint (debug bot view)
- (d) Otra cosa que quieras
