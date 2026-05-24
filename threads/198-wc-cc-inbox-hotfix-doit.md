---
thread: 198
author: wc
topic: inbox-hotfix-cross-origin-and-roomids
status: ready-for-execution
mode: DoIt
created: 2026-05-24
related_threads: [196, 197]
related_prs: [167, 168]
estimated_effort: 30-45min CC (1 session, sequential fixes)
pipeline: single-CC (no judges - hotfix scope)
---

# Thread 198 — Inbox redesign hotfix (3 fixes en 1 PR)

## §0. TL;DR

Post-ship verification de thread/196 reveló 3 bugs en el frontend deployado a producción:

1. **Frontend usa MOCK** porque `fetchInbox` falla. BASE URL en `inbox-client.ts` es `/api/admin` (relativo) → resuelve a `rincondelmar.club/api/admin/inbox` → CF Pages 404 → catch fallback al MOCK_RESPONSE. Backend real vive en `bot.rincondelmar.club/api/admin/*`.
2. **Filtro Propiedad tiene roomIds inventados** (`679175, 679177, 679178, 679179`). CC-A generó IDs cerca de Casa Chamán (`679176`) en lugar de usar los reales (`78695, 74322, 637063, 74316`).
3. **`/admin/conversation/[id]` → 404** (problema secundario, posiblemente causado por IDs mock con `:` que no rutean. Verificar tras fix 1 con IDs reales `b_xxxxx`).

Sistema actual: backend LIVE OK, frontend visible para staff pero sirviendo data MOCK. Riesgo: confusión Kari/staff si abren `/admin/inbox`.

**Fix scope:** 3 archivos modificados, 1 PR, ~30-45 min CC, manual deploy del worker post-merge.

---

## §1. Context (why)

### 1.1 Validación post-ship reveló bugs

Después de merger PR #167 (FE) + PR #168 (BE) y deployar worker-bot manualmente, Alex abrió `/admin/inbox` en producción y screenshots mostraron:

- Counter "Reservas 12 + Leads 5" (data del MOCK_RESPONSE en `InboxApp.tsx`)
- Andrea M., Carlos C., ...7441575, Sandy R. — todos sub-objetos del MOCK
- Filtro Propiedad con IDs 679175/177/178/179 (inventados)
- Click row → HTTP 404 page

Esto contradice el smoke test del endpoint backend que devolvió correctamente `{ ok: true, counters: { reservas: 79 } }` con data real de las 4 propiedades activas.

### 1.2 Root cause

**Issue 1 (mock fallback):** `apps/web/src/lib/inbox-client.ts`:
```typescript
const BASE = '/api/admin';
async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, ...);
}
```

Frontend en `rincondelmar.club` (CF Pages) hace fetch a `/api/admin/inbox` (same-origin) → CF Pages no tiene esa ruta (endpoint vive en `bot.rincondelmar.club` worker-bot subdomain) → 404 → catch fallback al MOCK.

**Issue 2 (wrong roomIds):** `apps/web/src/components/inbox/InboxFilters.tsx`:
```typescript
const PROPERTIES = [
  { value: '679175', label: 'Rincón del Mar' },   // ❌ real: 78695
  { value: '679177', label: 'Las Morenas' },       // ❌ real: 74322
  { value: '679178', label: 'Huerta Cocotera' },   // ❌ real: 637063
  { value: '679179', label: 'Combinada' },         // ❌ real: 74316
];
```

CC-A confundió Casa Chamán (679176) y generó random IDs alrededor. NINGUNO existe en `beds24_bookings.room_id`. Filtro nunca match nada.

**Issue 3 (conversation 404):** Pendiente verificar post-fix Issue 1. Hipótesis: IDs mock con `:` (ej. `conv:carlos-c`) rompen el routing dinámico `[id].astro`. Con IDs reales `b_86656062` debería funcionar.

---

## §2. Explicit scope

### 2.1 IN scope (3 archivos)

- **`apps/web/src/lib/inbox-client.ts`** — cambiar `BASE = '/api/admin'` a `BASE = 'https://bot.rincondelmar.club/api/admin'`
- **`apps/web/src/components/inbox/InboxFilters.tsx`** — corregir array `PROPERTIES` con roomIds reales
- **`apps/worker-bot/src/index.ts`** — agregar CORS middleware para `/api/admin/*` (`Access-Control-Allow-Origin: https://rincondelmar.club` + `Allow-Credentials: true`)

### 2.2 OUT of scope (NO tocar)

- ❌ MOCK_RESPONSE / MOCK_LEADS_RESPONSE en `InboxApp.tsx` (defer a G2 handshake, no parte de hotfix)
- ❌ Page `/admin/conversation/[id].astro` (verificar funciona tras fix 1, NO fixear preventivamente)
- ❌ Otros endpoints `/api/admin/*` no inbox (canary, heartbeats, etc) — solo CORS para los del inbox
- ❌ ANY backend logic en `apps/worker-bot/src/inbox/**` o `apps/worker-bot/src/api/admin/**`
- ❌ `packages/db/migrations/**` (DB ya OK)
- ❌ `packages/agents/**` (prompt OK)
- ❌ Tests refactor amplio — solo update tests que rompan por los 3 cambios
- ❌ Casa Chamán mentions (sigue excluida, no agregar)
- ❌ Deploy de worker-bot (Alex lo hace manual post-merge, NO ejecutar en sesión)
- ❌ Deploy de apps/web (auto-deploy via deploy.yml en merge a main)

---

## §3. Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | BASE URL absoluto cross-origin (NO proxy via apps/web) | Patrón ya existe con `/proxy/beds24/*`. Más rápido. Menos código. |
| D2 | CORS `Allow-Origin: https://rincondelmar.club` específico (NO `*`) | `credentials: include` requiere origin específico per spec CORS |
| D3 | `Allow-Credentials: true` | Better Auth session cookie cross-origin necesario |
| D4 | RoomIds correctos: 78695, 74322, 637063, 74316 (NO 374482) | Backend usa `74322` Las Morenas, mismo property dos listings. Filter por 74322 captura ambos rows airbnb+direct según aggregate.ts |
| D5 | Casa Chamán (679176) sigue excluida del filter | Anti-pattern memorial |
| D6 | Tests existentes que dependan de 679175/177/178/179 → update con IDs reales | Filter test debería match real backend behavior |
| D7 | NO crear deploy-worker-bot.yml en este PR | Wave 1.5 followup separado |
| D8 | Verificación post-deploy es responsibilidad de Alex, no CC | Smoke test browser manual |

---

## §4. Implementation

### 4.1 Fix 1 — inbox-client.ts BASE URL

**File:** `apps/web/src/lib/inbox-client.ts`

**Línea ~150 aprox** (busca `const BASE = '/api/admin';`):

```diff
-const BASE = '/api/admin';
+// thread/198 hotfix 2026-05-24: cross-origin fetch a worker-bot subdomain.
+// Frontend (apps/web) sirve desde rincondelmar.club CF Pages.
+// Backend endpoints viven en bot.rincondelmar.club worker-bot.
+// CORS handled en apps/worker-bot/src/index.ts (matching middleware).
+const BASE = 'https://bot.rincondelmar.club/api/admin';
```

### 4.2 Fix 2 — InboxFilters.tsx PROPERTIES array

**File:** `apps/web/src/components/inbox/InboxFilters.tsx`

**Líneas ~9-15 aprox** (busca el array `PROPERTIES`):

```diff
 const PROPERTIES = [
   { value: '', label: 'Todas las propiedades' },
-  { value: '679175', label: 'Rincón del Mar' },
-  { value: '679177', label: 'Las Morenas' },
-  { value: '679178', label: 'Huerta Cocotera' },
-  { value: '679179', label: 'Combinada' },
+  { value: '78695',  label: 'Rincón del Mar' },
+  { value: '74322',  label: 'Las Morenas' },
+  { value: '637063', label: 'Huerta Cocotera' },
+  { value: '74316',  label: 'Combinada' },
   // Casa Chamán (679176) excluded per anti-pattern rule
 ];
```

### 4.3 Fix 3 — worker-bot CORS middleware

**File:** `apps/worker-bot/src/index.ts`

**Insertar ANTES de la sección `// === Inbox redesign API (thread/196 CC-B) ===`** (busca esa línea exacta, debe estar cerca del final del archivo antes de los `app.get('/api/admin/inbox', handleInboxGet);` etc):

```typescript
// =====================================================================
// CORS para /api/admin/* — thread/198 hotfix 2026-05-24
// Frontend en rincondelmar.club (CF Pages) hace fetch cross-origin
// con credentials:include. Requiere Allow-Origin específico + Allow-Credentials.
// =====================================================================
const INBOX_API_ALLOWED_ORIGIN = 'https://rincondelmar.club';

app.options('/api/admin/*', (c) => {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': INBOX_API_ALLOWED_ORIGIN,
      'Access-Control-Allow-Credentials': 'true',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'content-type, authorization',
      'Access-Control-Max-Age': '86400',
    },
  });
});

app.use('/api/admin/*', async (c, next) => {
  await next();
  c.header('Access-Control-Allow-Origin', INBOX_API_ALLOWED_ORIGIN);
  c.header('Access-Control-Allow-Credentials', 'true');
});

// === Inbox redesign API (thread/196 CC-B) ===
import { handleInboxGet } from './api/admin/inbox';
// ... resto sin cambios
```

NOTA: la sección de imports inline (`import { handleInboxGet } ...`) y los `app.get/post/put/delete` queda EXACTAMENTE igual. Solo se agrega el bloque CORS arriba.

---

## §5. Tests

### 5.1 Tests a actualizar (si rompen)

Buscar referencias a los wrong roomIds:
```bash
grep -rn "679175\|679177\|679178\|679179" apps/web/src/ apps/web/tests/
```

Cualquier test que use esos IDs (probablemente en `apps/web/tests/inbox-filters.test.ts` o similar) → actualizar a los IDs reales.

### 5.2 Tests nuevos (NO requeridos, pero deseable)

- Si hay test que verifica `BASE` constant → asegurar que apunta a bot.rincondelmar.club. NO inventar test nuevo si no existe.

### 5.3 Typecheck obligatorio

```bash
pnpm --filter web typecheck
pnpm --filter worker-bot typecheck
```

Ambos deben pasar 0 errors antes del commit.

---

## §6. Definition of Done

- [ ] 3 archivos modificados commiteados en branch `fix/inbox-cross-origin-and-roomids` (o nombre similar)
- [ ] Typecheck web + worker-bot pasa 0 errors
- [ ] Tests que toquen roomIds antiguos actualizados (si existen)
- [ ] PR creada con título: `fix(inbox): cross-origin BASE + correct roomIds + CORS (thread/198)`
- [ ] PR description menciona los 3 issues con referencia thread/198
- [ ] Self-review: `git diff main..fix/inbox-cross-origin-and-roomids --stat` revisa solo los 3 archivos esperados
- [ ] Reporte al final con:
  - Confirmation 3 cambios aplicados según spec
  - Tests passing
  - PR URL
  - Instrucciones manual deploy worker para Alex (`cd apps/worker-bot && npx wrangler deploy`)

---

## §7. Risks + Mitigations

| Risk | Mitigation |
|---|---|
| CORS mal configurado bloquea fetch | Test post-deploy con browser DevTools Network tab + verifica response headers |
| BASE URL cambio rompe local dev | NO bloqueador — en local Alex ejecuta `wrangler pages dev` que también puede apuntar al worker remoto |
| Tests rompen por IDs cambiados | Update inline durante el run. Si más de 5 tests rompen, halt y reporta |
| Imports inline en index.ts conflictan con CORS middleware order | Mantener orden exacto: CORS arriba, imports + routes después. JS hoisting maneja imports |
| Casa Chamán colado accidental | NO posible — los 4 IDs nuevos NO incluyen 679176 |
| Cross-origin con cookies falla | `Allow-Credentials: true` + `Allow-Origin: specific` (NO `*`) según spec CORS |

---

## §8. Out-of-scope findings → issues

Si CC encuentra algo fuera de scope durante ejecución:
- Abrir GitHub issue con prefix `[thread/198 OOS]`
- NO fixear inline
- Reportar en el thread response al final

Ejemplos de things que pueden aparecer pero NO fixear:
- MOCK_RESPONSE fallback debería removerse (es G2 followup, NO ahora)
- 10 TS errors pre-existing en apps/web (no relacionados con inbox)
- Wave 1.5 followups del memory (subscribers table, bot_metrics table, etc)

---

## §9. Kickoff command (Alex copies to CC)

```
DoIt thread/198: inbox hotfix 3 fixes en 1 PR.

Spec: https://github.com/alexanderhorn6720/rdm-discussion/blob/main/threads/198-wc-cc-inbox-hotfix-doit.md

Lee la spec completa. Sigue §4 implementation exacto. Self-review §6 DoD antes de commit. Reporta al final con PR URL y comando wrangler deploy para Alex.

Scope estricto: 3 archivos (inbox-client.ts, InboxFilters.tsx, worker-bot/src/index.ts). Si encuentras algo fuera de scope → issue GitHub con prefix [thread/198 OOS], NO fix inline.

Bloqueado >30 min = STOP y reporta.

GO.
```

---

## §10. References

- thread/196: Inbox redesign megaspec (parent)
- PR #167: FE inbox scaffold (merged 2026-05-24)
- PR #168: BE inbox aggregate (merged 2026-05-24)
- Memory entries 25, 26, 27 (inbox shipped + worker deploy gotcha + Wave 1.5 followups)
- Anti-pattern memorial: roomIds reales 78695/74322/637063/74316, Casa Chamán 679176 excluida
