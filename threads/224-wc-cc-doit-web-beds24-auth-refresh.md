# Thread/224 — Fix BEDS24 auth en apps/web (refresh logic)

**Type**: DoIt (autonomous)
**Estimated**: 1-1.5h CC Sonnet
**Cost**: $2-4
**Prerequisite**: Alex ya subió `BEDS24_TOKEN` + `BEDS24_REFRESH_TOKEN` a Pages secrets de `rincondelmar-bot` (canjeados de invite code vía `/v2/authentication/setup` 2026-05-27).

---

## §1 Contexto

PR #194 (thread/222) introdujo `createBeds24Request` síncrono en `apps/web/src/pages/api/hold.ts`, pero `apps/web/src/lib/beds24-direct.ts` lee `env.BEDS24_TOKEN` directo sin refresh logic. Beds24 access tokens caducan en 24h → producción rompió el flujo hold con 401 "Token not valid" (verificado en logs 2026-05-27 17:31 — bookings `2b287bb7-...` y `e6bea424-...` cancelladas con `cancellation_reason='beds24_create_failed'`).

Worker-bot YA tiene refresh logic completa en `apps/worker-bot/src/beds24-auth.ts`. KV namespace `KV_KNOWLEDGE` es **compartido** entre worker-bot y apps/web (`wrangler.toml` línea 65: `id = "033ee15acf3744c096e83342d2e81dd4"` en ambos).

Smoke test del thread/222 validó por accidente:
- ✅ createBeds24Request maneja error sin crashear
- ✅ Rollback D1 funciona en falla (status='cancelled', cancellation_reason populated)
- ✅ Frontend muestra mensaje user-friendly con WhatsApp
- ✅ No se cobra nada al cliente

Lo único que falta es que Beds24 acepte la request — y eso depende de tener un token válido refrescable.

---

## §2 Scope

### IN
1. Copy `apps/worker-bot/src/beds24-auth.ts` → `apps/web/src/lib/beds24-auth.ts` (idéntico)
2. Modify `apps/web/src/lib/beds24-direct.ts`:
   - Cambiar `interface Beds24Env` para incluir `KV_KNOWLEDGE` + `BEDS24_REFRESH_TOKEN`
   - Las 3 funciones (`createBeds24Request`, `confirmBeds24Booking`, `cancelBeds24Booking`): reemplazar el uso directo de `env.BEDS24_TOKEN` por `await getBeds24AccessToken(env)`
3. Update `apps/web/src/env.d.ts` para tipar `BEDS24_REFRESH_TOKEN`
4. Update tests `apps/web/tests/beds24-direct.test.ts` para mockear `KV_KNOWLEDGE.get/put`
5. Build + typecheck + lint + test all pass
6. PR + reporte en thread/225

### OUT
- NO modificar `webhook-mp.ts` (sigue usando `pushMpPayment` que ya tiene su propio flujo via worker-pago)
- NO modificar `hold.ts` (solo cambia internamente el call a beds24-direct.ts)
- NO mover `beds24-auth.ts` a `packages/shared/` (futuro refactor, no hoy)
- NO deploy (Alex lo hace post-merge)
- NO smoke test (Alex lo ejecuta post-deploy)
- NO add unit tests adicionales para refresh logic (ya están en worker-bot side, copy mantiene cobertura conceptual)
- NO cleanup de los docstrings incorrectos sobre "tabla bookings does NOT exist" (anotados como deuda en thread/223; pueden quedar para próximo PR)

---

## §3 Decisiones cerradas

| # | Decisión | Razón |
|---|---|---|
| D1 | Copy file, no symlink ni shared package | Pages Functions tienen restricciones de bundling. Copy es lo más simple y reduce riesgo |
| D2 | KV_KNOWLEDGE compartido | Ya configurado en `apps/web/wrangler.toml`. Access token cacheado por worker-bot se reutiliza por apps/web — mismo `beds24:access_token` key |
| D3 | `BEDS24_TOKEN` queda opcional (fallback path 3) | Backward compat: si falla refresh y el access token static aún sirve, no rompe |
| D4 | Tests existentes pasan con fallback a Path 3 | Mock `KV_KNOWLEDGE.get` returns null → cae a `BEDS24_TOKEN` env. Patrón sencillo |
| D5 | No deploy en este DoIt | Alex deploya vía wrangler manual post-merge — política de safety |

---

## §4 Implementación

### 4.1 Crear `apps/web/src/lib/beds24-auth.ts`

Contenido idéntico a `apps/worker-bot/src/beds24-auth.ts` (copy literal). Cambio único en comentario docstring inicial: reemplazar "Sprint 1 día 5" por "Copy desde worker-bot 2026-05-27 (thread/224) — refresh logic compartida vía KV_KNOWLEDGE namespace".

### 4.2 Modificar `apps/web/src/lib/beds24-direct.ts`

**Antes** (líneas 1-5):
```typescript
const BEDS24_BASE = 'https://api.beds24.com/v2';

interface Beds24Env {
  BEDS24_TOKEN?: string;
}
```

**Después**:
```typescript
import { getBeds24AccessToken } from './beds24-auth';

const BEDS24_BASE = 'https://api.beds24.com/v2';

interface Beds24Env {
  KV_KNOWLEDGE: KVNamespace;
  BEDS24_TOKEN?: string;
  BEDS24_REFRESH_TOKEN?: string;
}
```

En las 3 funciones (`createBeds24Request`, `confirmBeds24Booking`, `cancelBeds24Booking`), reemplazar:

**Antes**:
```typescript
if (!env.BEDS24_TOKEN) return { ok: false, error: 'BEDS24_TOKEN not configured' };
// ...
headers: {
  token: env.BEDS24_TOKEN,
  ...
}
```

**Después**:
```typescript
let token: string;
try {
  token = await getBeds24AccessToken(env);
} catch (err) {
  return { ok: false, error: err instanceof Error ? err.message : String(err) };
}
// ...
headers: {
  token,
  ...
}
```

### 4.3 Update `apps/web/src/env.d.ts`

Añadir `BEDS24_REFRESH_TOKEN?: string;` a la interface `Env` (si existe; si no, crear interface o agregar a la existente).

### 4.4 Update tests `apps/web/tests/beds24-direct.test.ts`

Cada test que usa `env` debe incluir un mock `KV_KNOWLEDGE` con `get/put`. Default: `get` returns `null` (no cache) → forzar fallback a `BEDS24_TOKEN`. Pattern:

```typescript
const mockEnv = {
  BEDS24_TOKEN: 'test-token',
  KV_KNOWLEDGE: {
    get: vi.fn().mockResolvedValue(null),
    put: vi.fn().mockResolvedValue(undefined),
  } as unknown as KVNamespace,
};
```

Si algún test necesita simular refresh, añadir mock con BEDS24_REFRESH_TOKEN + fetch mock para `/v2/authentication/token` (opcional, no requerido por DoD).

Tests existentes pasan token static → siguen pasando con fallback a Path 3 (BEDS24_TOKEN).

---

## §5 Definición de Done

- [ ] `apps/web/src/lib/beds24-auth.ts` existe y es copy de worker-bot
- [ ] `apps/web/src/lib/beds24-direct.ts` usa `getBeds24AccessToken(env)` en las 3 funciones
- [ ] `apps/web/src/env.d.ts` incluye `BEDS24_REFRESH_TOKEN`
- [ ] `apps/web/tests/beds24-direct.test.ts` mockea KV_KNOWLEDGE
- [ ] `pnpm -w typecheck` pass
- [ ] `pnpm -w lint` pass
- [ ] `pnpm -w test` pass (incluye los 158 tests existentes de beds24-direct)
- [ ] `pnpm -w build` pass
- [ ] PR creado con descripción mobile-friendly + checklist deploy para Alex
- [ ] Self-review pre-merge: diff es lo esperado, no scope creep, los 7 archivos protegidos por payment-flow no se tocan (solo beds24-direct.ts y archivos nuevos)
- [ ] Reporte final en thread/225

---

## §6 Riesgos

| # | Riesgo | Mitigación |
|---|---|---|
| R1 | beds24-auth.ts referencia `KVNamespace` type que Pages Functions puede no tener en scope | Pages Functions soportan KVNamespace nativo via `@cloudflare/workers-types`. Si typecheck falla, importar explícitamente |
| R2 | Tests existentes de beds24-direct rompen por interface change | Aceptado — fix trivial (añadir mock KV_KNOWLEDGE). Cubierto en §4.4 |
| R3 | apps/web no tiene `BEDS24_REFRESH_TOKEN` en local .dev.vars (solo prod) | CC verifica que Pages secrets tienen ambos. Local dev sin refresh token usa fallback Path 3 |
| R4 | Pages Functions cold-start lento con KV read agregada | Aceptable. KV read es ~5-10ms. Solo importa primera invocación post-cache-miss |
| R5 | Worker-bot refresh logic asume KV_KNOWLEDGE writable; si apps/web Pages binding fuera read-only, el `put` falla | Verificado: wrangler.toml de apps/web tiene `KV_KNOWLEDGE` con `id` igual a worker-bot, sin readonly flag |

---

## §7 Post-merge (Alex)

1. Merge PR vía squash
2. CF Pages auto-deploya (GitHub integration, ~3 min)
3. Verificar BEDS24_REFRESH_TOKEN en Pages secrets:
   ```powershell
   cd C:\dev\rdm\dev\bot\apps\web
   npx wrangler pages secret list --project-name=rincondelmar-bot
   ```
   Esperado: ambos `BEDS24_TOKEN` y `BEDS24_REFRESH_TOKEN`.
4. Tail logs en paralelo:
   ```powershell
   npx wrangler pages deployment tail --project-name=rincondelmar-bot
   ```
5. Smoke en navegador: `https://rincondelmar.club/reservar/huerta-cocotera` → fechas 2026-07-15 a 17, 1 huésped → "Calcular precio" → "Reservar"
6. Hold debe avanzar al paso pago (NO pagar — solo validar Beds24 acepta)
7. WC verifica via MCP: D1 booking con `status='hold'` + `beds24_booking_id` poblado + Beds24 reserva `status='request'`
8. Cancelar hold en Beds24 dashboard (o dejar expire 24h)

---

## §8 Pre-flight CC

```bash
cd /c/dev/rdm/dev/bot
git checkout main
git pull --rebase origin main
git log --oneline -1
# Esperado: e7874ac (PR #194 merge) o posterior

# Branch
git checkout -b fix/web-beds24-auth-refresh

# Verifica archivos críticos
test -f apps/worker-bot/src/beds24-auth.ts
test -f apps/web/src/lib/beds24-direct.ts
test -f apps/web/tests/beds24-direct.test.ts
test -f apps/web/src/env.d.ts
test -f apps/web/wrangler.toml

# Verifica KV_KNOWLEDGE binding existe en apps/web wrangler.toml
grep "KV_KNOWLEDGE" apps/web/wrangler.toml
# Esperado: id = "033ee15acf3744c096e83342d2e81dd4" (mismo que worker-bot)
```

Si cualquier check falla → HALT, reportar en thread.

---

## §9 Reporte final (thread/225)

Template:
```markdown
# Thread/225 — DoIt 224 completion report

**Spec**: thread/224
**Branch**: fix/web-beds24-auth-refresh
**PR**: #XXX

## Files changed
- apps/web/src/lib/beds24-auth.ts (NEW, copy from worker-bot)
- apps/web/src/lib/beds24-direct.ts (modified — import + interface + 3 fn replace)
- apps/web/src/env.d.ts (modified — add BEDS24_REFRESH_TOKEN)
- apps/web/tests/beds24-direct.test.ts (modified — mock KV_KNOWLEDGE)

## Gates
- typecheck: PASS
- lint: PASS
- build: PASS
- test: 648 web + 40 worker-pago = 688 PASS

## Cost LLM
$X.XX (~XXX min Sonnet)

## Alex next
1. Merge PR
2. Aguardar CF Pages auto-deploy ~3 min
3. Smoke §7 thread/224
4. Si verde → bug fix payment flow completo
```

---

## §10 Notas

- Este DoIt es **bug fix sobre PR #194** — el flujo C1 está implementado, solo le faltaba el token refresh.
- El smoke test del thread/222 ya validó la mayor parte del cambio (rollback, frontend, no-cobro). Solo falta confirmar que Beds24 acepta la request con token válido.
- Hay 2 nits pendientes del PR #194 review (docstrings sobre tabla bookings) que NO se incluyen aquí — quedan para PR cleanup futuro o thread/224 followup si CC tiene capacidad sobrante.
- Post-merge: producción de checkout queda funcional con auto-refresh permanente.
