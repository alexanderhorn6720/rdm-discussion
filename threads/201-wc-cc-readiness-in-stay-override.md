---
thread: 201
author: wc
topic: inbox-bug-6-readiness-in-stay-post-stay-eta-rules-override
status: ready-for-execution
mode: DoIt
created: 2026-05-24
related_threads: [196, 199, 200]
related_prs: [167, 169, 170]
estimated_effort: 30-45min CC (1 session, backend-only)
pipeline: single-CC
requires_worker_bot_deploy: YES (manual `npx wrangler deploy` after merge)
---

# Thread 201 — Inbox bug 6: readiness in-stay/post-stay override

## §0. TL;DR

**Bug 6:** Rows In-stay OK del inbox muestran `◯ETA ◯Reglas` como missing aunque los guests YA LLEGARON (están adentro). Visualmente confuso: Karina ve "falta info" cuando en realidad el guest está adentro y físicamente presente.

**Decisión Alex 2026-05-24:** 
- ETA + Reglas → marcar como `done` (✓) cuando booking está in-stay o post-stay (arrival ≤ today)
- **Pago → SIN CAMBIO**: permanece visible con current logic. Razón: clientes suelen pagar el balance DURANTE la estancia, Karina necesita ver claramente quién ya pagó completo.

**Fix:** modificar `computeReadiness()` en `apps/worker-bot/src/inbox/readiness.ts` para override `eta_known` + `rules_accepted` cuando `arrival ≤ today`. Backend-only.

---

## §1. Context

### 1.1 Current logic (readiness.ts líneas 53-67)

```ts
const pax_confirmed = booking.num_adults > 0;          // ✓ siempre OK
const pet_decided = cap.mascotas_confirmed === 1 || ... // ✓ data-driven
const menu_decided = cap.menu_status === 'recibido'...  // ✓ data-driven
const eta_known = detectEtaFromHistory(history);       // ❌ scan WA only
const rules_accepted = false;                          // ❌ HARDCODED false (no column)
const paid = booking.deposit_paid === 1 || ...         // ✓ data-driven
```

### 1.2 Problemas

| Field | Problema | Effect en in-stay rows |
|---|---|---|
| `eta_known` | Scan history WA. Si guest llegó por AirBnB (sin WA conv), scan vacío → false. Pero el guest YA ESTÁ AHÍ. | ◯ETA falso |
| `rules_accepted` | Hardcoded `false` porque no existe la columna en DB | ◯Reglas falso |
| `paid` | Data-driven (deposit_paid). Correct. | ✓Pago real |

### 1.3 Lifecycle context

```
arrival       ← guest llega físicamente
  │
  ├─ today < arrival  → pre-stay (T-N días)
  ├─ arrival ≤ today < departure → in-stay
  └─ today ≥ departure → post-stay
```

Si `arrival ≤ today` (in-stay o post-stay):
- El guest físicamente está/estuvo en la propiedad
- Necesariamente firmó reglas (entrar requiere check-in)
- Necesariamente comunicó ETA (Karina lo recibió)
- Conclusión: marcar ambos campos como `true`

### 1.4 Lo que NO cambia (Pago)

```ts
const paid = booking.deposit_paid === 1 || (booking.balance_due_mxn !== null && booking.balance_due_mxn <= 0);
```

Esta lógica sigue intacta. En in-stay row, Karina ve:
- `✓Pago` → guest pagó completo
- `◯Pago` → guest pendiente de pagar (alerta visible)

Visibility de `paid` es operacional crítica.

---

## §2. Explicit scope

### 2.1 IN scope

| Archivo | Cambio | LoC |
|---|---|---|
| `apps/worker-bot/src/inbox/readiness.ts` | Add `isInStayOrLater(arrival, departure)` helper. Override `eta_known` y `rules_accepted` cuando in-stay/post-stay. | +25 |
| `apps/worker-bot/tests/inbox/readiness.test.ts` | Tests nuevos: pre-stay (sin override), in-stay (override ETA+Reglas), post-stay (idem), edge cases | +60 |

### 2.2 OUT of scope (NO tocar)

- ❌ `paid` field logic — Alex confirmation explícita: queda igual
- ❌ Frontend (`ReadinessScore.tsx`) — thread/199 ya lo arregló (filter missing)
- ❌ `aggregate.ts` — `computeReadiness` es llamado desde aggregate, pero la firma no cambia
- ❌ `conversation.ts` — también llama computeReadiness, sin cambio de firma
- ❌ Database migrations
- ❌ Nueva columna `rules_form_submitted_at` — DEFER (Wave 1.5 followup)
- ❌ `detectEtaFromHistory()` — sin cambios, sigue como fallback para pre-stay
- ❌ Bug 2 conversation polimorfo → thread/200

---

## §3. Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | `eta_known` y `rules_accepted` → `true` si `arrival ≤ today (Acapulco TZ)` | Realidad operacional: guest físicamente presente desde arrival |
| D2 | `paid` → SIN CAMBIO | Alex confirmation 2026-05-24: pagos durante estancia common, Karina necesita visibility |
| D3 | Comparación de fechas usa día Acapulco (TZ America/Mexico_City) | Date strings en DB son YYYY-MM-DD locales (sin TZ). Comparar contra `now() Acapulco` |
| D4 | Para pre-stay (today < arrival): comportamiento sin cambios — `eta_known` via history scan, `rules_accepted = false` | Pre-stay logic ya funciona, no romper |
| D5 | Helper `isInStayOrLater` exportado para tests | Pure function, testable |
| D6 | `detectEtaFromHistory` sigue como fallback para pre-stay si no hay override | Backward compat |
| D7 | No filtra cancelled bookings — esos no llegan a `computeReadiness` desde aggregate (ya filtrados) | Defensiveness OK pero no necesario |
| D8 | Firma de `computeReadiness` NO cambia | Caller code en aggregate.ts y conversation.ts no necesita refactor |

---

## §4. Implementation

### 4.1 Helper `isInStayOrLater()` — nuevo

Agregar al top de `apps/worker-bot/src/inbox/readiness.ts`, antes de `detectEtaFromHistory`:

```ts
/**
 * Check if booking is currently in-stay or has already departed (arrival ≤ today).
 * Uses Acapulco timezone (America/Mexico_City) for `today` since arrival/departure
 * are stored as YYYY-MM-DD local dates.
 *
 * @param arrival - YYYY-MM-DD format
 * @returns true if guest has arrived or is already past departure
 */
export function isInStayOrLater(arrival: string): boolean {
  // Get today in Acapulco TZ as YYYY-MM-DD
  const todayAcapulco = new Date().toLocaleDateString('en-CA', {
    timeZone: 'America/Mexico_City',
  }); // returns YYYY-MM-DD format with en-CA locale

  // String comparison works for YYYY-MM-DD format
  return arrival <= todayAcapulco;
}
```

### 4.2 Override en `computeReadiness`

Modificar `apps/worker-bot/src/inbox/readiness.ts`:

```diff
 export function computeReadiness(
   booking: Beds24BookingRow,
   captures: BookingCapturesRow | null,
   history: string,
 ): ReadinessScore {
   const cap = captures ?? {} as BookingCapturesRow;
+
+  const inStayOrLater = isInStayOrLater(booking.arrival);

   const pax_confirmed = booking.num_adults > 0;

   // pet_decided: either explicitly confirmed via captures, OR booking says 0 pets (implicit no-pet)
   const pet_decided =
     cap.mascotas_confirmed === 1 ||
     // num_pets=0 (explicitly no pets) AND mascotas_confirmed was explicitly set (not null/undefined)
     (booking.num_pets === 0 && cap.mascotas_confirmed != null);

   const menu_decided =
     cap.menu_status === 'recibido' || cap.menu_status === 'declined';

-  const eta_known = detectEtaFromHistory(history);
+  // ETA: if guest already arrived (in-stay or post-stay), assume known.
+  // Otherwise scan WA history for arrival time keywords.
+  const eta_known = inStayOrLater || detectEtaFromHistory(history);

-  // rules_accepted: no column exists → false (Wave 1.5)
-  const rules_accepted = false;
+  // Rules: if guest already arrived, assume accepted (entering requires check-in).
+  // Otherwise hardcoded false until rules_form_submitted_at column exists (Wave 1.5).
+  const rules_accepted = inStayOrLater;

   const paid =
     booking.deposit_paid === 1 ||
     (booking.balance_due_mxn !== null && booking.balance_due_mxn <= 0);

   const booleans = [pax_confirmed, pet_decided, menu_decided, eta_known, rules_accepted, paid];
   const score = booleans.filter(Boolean).length;

   return { pax_confirmed, pet_decided, menu_decided, eta_known, rules_accepted, paid, score };
 }
```

### 4.3 Update doc comments

Actualizar header comment del archivo:

```diff
 // Readiness score — 6-component, computed runtime from beds24_bookings + booking_captures
 // Spec: thread/196 §4.4.3
+// Updated: thread/201 — eta_known + rules_accepted override when in-stay/post-stay (arrival ≤ today)
 //
 // Missing columns vs spec (no ALTER TABLE this run, per §7 R6 + G1 comment):
 //   - beds24_bookings.rules_form_submitted_at → NOT EXIST → rules_accepted = false
+//     EXCEPTION: arrival ≤ today → rules_accepted = true (physical check-in implies acceptance)
 //   - No readiness_cached on beds24_bookings → use booking_captures.readiness_score instead
```

---

## §5. Tests

### 5.1 Verificar si existe el test file

```bash
ls apps/worker-bot/tests/inbox/readiness.test.ts
```

Si NO existe → crear. Si existe → append nuevos tests.

### 5.2 Tests para `isInStayOrLater`

```ts
import { isInStayOrLater } from '../../src/inbox/readiness';

describe('isInStayOrLater', () => {
  // Mock Date.now or pass fixed dates
  it('returns false for arrival in future (pre-stay)', () => {
    const futureDate = new Date(Date.now() + 7 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    expect(isInStayOrLater(futureDate)).toBe(false);
  });

  it('returns true for arrival today', () => {
    const today = new Date().toLocaleDateString('en-CA', { 
      timeZone: 'America/Mexico_City' 
    });
    expect(isInStayOrLater(today)).toBe(true);
  });

  it('returns true for arrival in past (post-stay)', () => {
    const pastDate = new Date(Date.now() - 7 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    expect(isInStayOrLater(pastDate)).toBe(true);
  });
});
```

### 5.3 Tests para `computeReadiness` override behavior

```ts
import { computeReadiness } from '../../src/inbox/readiness';

const baseBooking = {
  num_adults: 4,
  num_pets: 0,
  total_amount_mxn: 50000,
  deposit_paid: 1,
  balance_due_mxn: null,
  arrival: '2026-05-22',  // adjust based on test scenario
  departure: '2026-05-28',
  room_id: 78695,
};

const baseCaptures = {
  mascotas_confirmed: 1,
  mascotas_count: null,
  menu_status: 'recibido',
  compras_confirmed: null,
  morenas_svc_confirmed: null,
};

describe('computeReadiness — in-stay override (thread/201)', () => {
  it('marks eta_known=true for in-stay booking even without history', () => {
    const arrivalPast = new Date(Date.now() - 2 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalPast },
      baseCaptures,
      '',  // empty history
    );
    expect(result.eta_known).toBe(true);
  });

  it('marks rules_accepted=true for in-stay booking', () => {
    const arrivalPast = new Date(Date.now() - 2 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalPast },
      baseCaptures,
      '',
    );
    expect(result.rules_accepted).toBe(true);
  });

  it('marks eta_known=true for post-stay (already departed)', () => {
    const arrivalLongPast = new Date(Date.now() - 30 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalLongPast },
      baseCaptures,
      '',
    );
    expect(result.eta_known).toBe(true);
    expect(result.rules_accepted).toBe(true);
  });

  it('keeps eta_known=false for pre-stay without history keywords', () => {
    const arrivalFuture = new Date(Date.now() + 7 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalFuture },
      baseCaptures,
      '',  // no ETA keywords
    );
    expect(result.eta_known).toBe(false);
    expect(result.rules_accepted).toBe(false);
  });

  it('detects eta_known via history scan for pre-stay', () => {
    const arrivalFuture = new Date(Date.now() + 7 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalFuture },
      baseCaptures,
      'USER: llegamos como a las 5pm',
    );
    expect(result.eta_known).toBe(true);
    expect(result.rules_accepted).toBe(false);  // pre-stay still hardcoded false
  });

  it('does NOT override paid for in-stay booking', () => {
    const arrivalPast = new Date(Date.now() - 2 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    // Unpaid in-stay booking
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalPast, deposit_paid: 0, balance_due_mxn: 20000 },
      baseCaptures,
      '',
    );
    expect(result.paid).toBe(false);  // CRITICAL: visibility for Karina
    expect(result.eta_known).toBe(true);
    expect(result.rules_accepted).toBe(true);
  });

  it('computes score correctly with overrides', () => {
    const arrivalPast = new Date(Date.now() - 2 * 24 * 3600 * 1000)
      .toISOString().split('T')[0];
    // Pre-thread/201 score: 4/6 (pax + pet + menu + paid). 
    // Post: 6/6 (+ eta + rules from override)
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalPast },
      baseCaptures,
      '',
    );
    expect(result.score).toBe(6);  // 6 of 6
  });
});
```

### 5.4 Tests para regresión (verificar que pre-stay sigue funcionando)

Si tests existen para `computeReadiness` pre-stay, verificar que siguen pasando. Si no, agregar:

```ts
describe('computeReadiness — pre-stay (existing behavior unchanged)', () => {
  const arrivalFuture = '2027-01-01';  // far future

  it('eta_known false when no history keywords', () => {
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalFuture },
      baseCaptures,
      'USER: hola\nASSISTANT: hola',
    );
    expect(result.eta_known).toBe(false);
  });

  it('paid driven by deposit_paid for pre-stay', () => {
    const result = computeReadiness(
      { ...baseBooking, arrival: arrivalFuture, deposit_paid: 1 },
      baseCaptures,
      '',
    );
    expect(result.paid).toBe(true);
  });
});
```

---

## §6. Definition of Done

- [ ] Branch `fix/inbox-readiness-in-stay-override` creada
- [ ] 2 archivos modificados:
  - `apps/worker-bot/src/inbox/readiness.ts` (+25 LoC: helper + override logic + doc updates)
  - `apps/worker-bot/tests/inbox/readiness.test.ts` (+60 LoC: ~10 tests nuevos, file created if missing)
- [ ] `pnpm --filter worker-bot typecheck` PASS 0 errors nuevos
- [ ] `pnpm --filter worker-bot test` los tests nuevos pasan
- [ ] `git diff main --stat` muestra ~2 archivos, ~85 LoC total
- [ ] PR creada con título: `fix(inbox): readiness override eta+reglas para in-stay/post-stay (thread/201)`
- [ ] PR description menciona bug 6 resuelto, Alex confirmation pago permanece visible, ⚠️ REQUIRES MANUAL `npx wrangler deploy` post-merge
- [ ] Reporte al final con:
  - Helper `isInStayOrLater` agregado
  - 2 fields override (eta_known, rules_accepted)
  - `paid` NO CAMBIA (confirmed)
  - Typecheck PASS
  - Tests pass count
  - PR URL
  - ⚠️ Worker-bot deploy manual requerido

---

## §7. Risks + Mitigations

| Risk | Mitigation |
|---|---|
| TZ comparison bug (UTC vs Acapulco) | Usar `toLocaleDateString('en-CA', { timeZone: 'America/Mexico_City' })` — formato YYYY-MM-DD garantizado |
| String comparison of dates rompe en formato inesperado | DB schema CHECK constraint garantiza `arrival GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'` — formato seguro |
| `detectEtaFromHistory` queda como dead code para post-stay | NO — sigue activo para pre-stay (cuando no hay override). Documentar comportamiento. |
| Cambia el `score` numérico de in-stay rows (era ~3/6, ahora ~5/6) | INTENCIONAL — es el bug que estamos arreglando. Karina verá rows in-stay más "completas" |
| Aggregate.ts pass diferente shape de booking → readiness | Firma de `computeReadiness` NO cambia. Caller code intacto. |
| Caso edge: arrival === departure (same-day check-in/checkout) | `isInStayOrLater(arrival)` retorna true en arrival day. `paid` etc no cambian. OK. |
| Caso edge: arrival sin formato válido | TypeScript signature `arrival: string`. CHECK constraint en DB. String comparison es defensive. |

---

## §8. Out-of-scope findings → issues

Si CC encuentra algo durante ejecución NO listado en §2.1:
- Abrir GitHub issue con prefix `[thread/201 OOS]`
- NO fixear inline
- Reportar en thread response

Ejemplos previsibles:
- `rules_form_submitted_at` column nueva → Wave 1.5 followup, DEFER
- Caller code en aggregate.ts/conversation.ts asume readiness shape específico → verificar y reportar si cambia
- TypeScript errors pre-existentes → IGNORE
- Bug 2 conversation polimorfo → thread/200

---

## §9. Kickoff command (Alex pegará a CC)

```
DoIt thread/201: readiness override in-stay/post-stay, 1 PR backend-only worker-bot.

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/201-wc-cc-readiness-in-stay-override.md

(Si no la tienes local, pull discussion repo:
cd c:/dev/rdm/dev/discussion && git pull origin main && cd c:/dev/rdm/dev/bot)

Sigue §4 implementation exacto. Self-review §6 DoD antes de commit.

Working directory: c:/dev/rdm/dev/bot

Pre-flight:
1. cd c:/dev/rdm/dev/bot
2. git status — debe estar clean en main
3. git pull origin main
4. git log --oneline -1 — confirma estás en último commit

Execution:
1. git checkout -b fix/inbox-readiness-in-stay-override
2. Leer apps/worker-bot/src/inbox/readiness.ts entero
3. Verificar si existe apps/worker-bot/tests/inbox/readiness.test.ts — si existe leerlo (no romper tests existing), si no crearlo
4. Edit readiness.ts según §4:
   - Add isInStayOrLater helper (exportado)
   - Modify computeReadiness: override eta_known + rules_accepted con inStayOrLater
   - paid SIN CAMBIO (confirmar)
   - Update doc comments
5. Add tests según §5 (~10 tests nuevos)
6. pnpm --filter worker-bot typecheck — must PASS 0 errors nuevos
7. pnpm --filter worker-bot test — tests nuevos pasan + tests existing readiness siguen verdes
8. git diff main --stat — verifica ~2 archivos
9. git add (solo readiness.ts + readiness.test.ts)
10. git commit -m "fix(inbox): readiness override eta+reglas para in-stay/post-stay (thread/201)"
11. git push -u origin fix/inbox-readiness-in-stay-override
12. gh pr create con title "fix(inbox): readiness override eta+reglas para in-stay/post-stay (thread/201)" y body con referencia thread/201, bug 6 resuelto, Alex confirmation explícita pago NO CAMBIA, ⚠️ MANUAL `npx wrangler deploy` REQUIRED post-merge

Scope ESTRICTO: backend-only worker-bot.
- apps/worker-bot/src/inbox/readiness.ts
- apps/worker-bot/tests/inbox/readiness.test.ts

NO ejecutes:
- pnpm test completo (rompen pre-existentes)
- npx wrangler deploy (Alex lo hace manual post-merge)
- Frontend changes (apps/web/**)
- Backend changes a otros archivos (conversation.ts, aggregate.ts, etc)
- Database migrations
- Cambios a la firma de computeReadiness
- Cambios a `paid` logic
- Force-push, branch delete

Si encuentras algo fuera de scope → issue GitHub con prefix [thread/201 OOS].

Bloqueado >30 min en sub-tarea = STOP y reporta.

Reportar al final con:
- isInStayOrLater helper agregado
- 2 fields override (eta_known, rules_accepted)
- paid NO CAMBIA (confirmar visible en diff)
- Typecheck PASS
- Tests pass count
- PR URL
- ⚠️ CRÍTICO: worker-bot deploy manual requerido

GO.
```

---

## §10. References

- thread/196: Inbox redesign megaspec §4.4.3 readiness
- thread/199: Display fields + readiness compact UI (PR #170 merged)
- thread/200: Conversation endpoint polimórfico (paralelo, redactado)
- D1 query investigation 2026-05-24: in-stay rows muestran ◯ETA ◯Reglas misleadingly
- Alex confirmation explícita 2026-05-24: `pago` debe quedar visible (memoria D11 de thread/199)
- Worker-bot deploy gotcha: memoria #27 — manual `npx wrangler deploy` requerido
- Future column `rules_form_submitted_at` → Wave 1.5 backlog
