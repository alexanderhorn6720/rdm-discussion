---
thread: 203
author: wc
topic: phone-normalize-mx-cellular-indicator-fix
status: ready-for-execution
mode: DoIt
created: 2026-05-24
related_threads: [196, 198, 199, 200, 201, 202]
related_prs: [167, 169, 170, 171]
estimated_effort: 30-45min CC (1 session, backend-only)
pipeline: single-CC
requires_worker_bot_deploy: YES (manual `npx wrangler deploy` after merge)
severity: CRITICAL (data loss visibility — Karina pierde mensajes WhatsApp de bookings)
---

# Thread 203 — Phone normalization MX cellular indicator fix

## §0. TL;DR

**Bug crítico:** Karina no ve mensajes WhatsApp de bookings (ej. Alan Granados #79421553 tiene 2 turns reales en `conversations` table pero el inbox muestra "Sin mensajes"). 

**Root cause:** Asimetría de formato phone entre 2 stores:

| Store | Formato MX | Ejemplo Alan Granados |
|---|---|---|
| `guests.phone_e164` (Beds24/AirBnB) | `+52XXXXXXXXXX` SIN "1" | `+525582528741` |
| `conversations.subscriber_id` (WhatsApp/ManyChat) | `521XXXXXXXXXX` CON "1" | `5215582528741` |

El JOIN actual `c.subscriber_id = REPLACE(g.phone_e164, '+', '')` falla porque uno tiene "1" cellular indicator y el otro no.

**Impacto medido D1:**
- OLD normalization: 4 / 205 conversations matchean a guest record (1.9%)
- NEW normalization: 32 / 205 (15.6%) — **8x mejora**

**Fix:** helper `normalizePhoneToWA()` que inserta "1" después de "52" para MX cellular. Apply en `conversation.ts` (resolveConvContext) Y `aggregate.ts` (Tab Reservas JOIN). Backend-only worker-bot.

**3 problemas que se arreglan con este 1 fix:**
1. ✅ Click row direct booking → muestra conv WA cuando existe (Alan Granados case)
2. ✅ Preview del último mensaje en Tab Reservas (gap thread/202)
3. ✅ Unread count badge en Tab Reservas (gap thread/202)

---

## §1. Context — diagnóstico D1

### 1.1 Query distribución formato `guests.phone_e164`

```
MX_no_1 (13 chars):       6,873 guests (92%)   ← +52XXXXXXXXXX
US_CA (12 chars):           281
DE (13-14 chars):           103
MX_cell_with_1 (14 chars):    5 guests         ← +521XXXXXXXXXX (raro)
```

### 1.2 Query distribución formato `conversations.subscriber_id`

```
MX_cell_with_1 (13 chars): 199 conversations (97%)  ← 521XXXXXXXXXX
US_CA (11 chars):            3
DE (13 chars):               1
MX_no_1:                     0 conversations  ← NUNCA aparece sin 1
```

### 1.3 Sample real verified (20 samples, todos OK con new normalization)

```
Alan Granados:
  phone_e164:       +525582528741
  old_norm:         525582528741          (NO match)
  new_norm:         5215582528741         (MATCH ✅ — 2 turns reales)

Sara Ramos:           +525584910041 → 5215584910041 ✅ (3 turns)
Claudia Becerra:      +525516264567 → 5215516264567 (verify match)
Mariana Alcázar:      +525540520465 → 5215540520465 ✅ (13 turns)
Pat Li (US):          +15126800858 → 15126800858 ✅ (sin cambio US)
Annegret Baass (DE):  +4916096267970 → 4916096267970 ✅ (sin cambio DE)
```

### 1.4 Conversación real Alan Granados (history actual D1)

```
USER: Que tal Alexander buena noche, el día lunes tengo una 
       reservación, liquidare llegando allá
ASSISTANT: Le paso esto a Karina o Alex — te van a escribir 
            en un rato.
USER: Que tal Alexander buena noche...

last_active: 2026-05-23 14:37:12 (ayer)
```

Esto **NO se muestra hoy** porque resolveConvContext no encuentra match con la normalization actual.

---

## §2. Explicit scope

### 2.1 IN scope

| Archivo | Cambio | LoC |
|---|---|---|
| `apps/worker-bot/src/inbox/phone-normalize.ts` | NEW helper `normalizePhoneToWA(phoneE164)` exportado | +30 |
| `apps/worker-bot/src/api/admin/conversation.ts` | `resolveConvContext` usa helper en lookup phone | +5 (modify 2 lines) |
| `apps/worker-bot/src/inbox/aggregate.ts` | Tab Reservas JOIN usa helper. Refactor inline JOIN clause para usar helper-produced value | +15 (modify ~20 LoC) |
| `apps/worker-bot/tests/inbox/phone-normalize.test.ts` | NEW tests: MX_no_1, MX_with_1, US, DE, edge cases, null | +60 |
| `apps/worker-bot/tests/api/admin/conversation.test.ts` | Tests adicionales: booking MX phone sin 1 → match con conv | +30 |

### 2.2 OUT of scope (NO tocar)

- ❌ Frontend (`InboxApp.tsx`, `ConversationView.tsx`) — bug es backend
- ❌ Database migrations — no schema change
- ❌ Backfill columna nueva — fix es runtime, no persistent
- ❌ `manychat_subscriber_id` column update — sigue inútil pero out-of-scope normalizar/poblar
- ❌ Inverse normalization (strip "1" cuando llega con 1) — los 5 guests con "1" son edge case minoritario, defer si needed
- ❌ Casa Chamán handling — anti-pattern OK ya filtrado upstream
- ❌ thread/201 readiness override — separado spec
- ❌ thread/202 gaps frontend (preview, dates, quick links) — separado spec post este fix

---

## §3. Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Opción A simple helper (NO multi-candidate lookup) | 99.97% de guests MX sin "1". Multi-candidate complicates, no extra value medido. |
| D2 | Helper exportado para tests + reutilización | Pure function, testable. Si después conversation.ts y aggregate.ts divergen, single source of truth |
| D3 | Solo MX +52 transform. US/CA/DE/etc strip "+" sin más | Otros países no tienen el problema MX cellular indicator. Verified D1. |
| D4 | Aplicar en conversation.ts Y aggregate.ts en MISMO PR | Mismo problema, mismo fix. Separar = doble deploy, doble review = waste |
| D5 | Backend-only. NO frontend changes | Bug es de matching D1, frontend solo renderiza lo que backend devuelve |
| D6 | NO touch `manychat_subscriber_id` field/lookups (sigue como código muerto) | Out of scope. Cleanup futuro thread separado |
| D7 | Tests primero phone-normalize.ts unit + después integration en conversation.test.ts | Pure helper test simple, integration valida wiring |
| D8 | Helper devuelve `string \| null` — null si input null | Defensive, consistent con resto del flow |
| D9 | NO ALTER TABLE — fix runtime puro | Anti-pattern. Schema intacto. |
| D10 | NO backfill columna nueva en guests — fix derivado runtime | Mantener stores como están. Sumar lookup variante a runtime |

---

## §4. Implementation

### 4.1 Nuevo archivo: `apps/worker-bot/src/inbox/phone-normalize.ts`

```ts
// Phone number normalization for matching guests.phone_e164 ↔ conversations.subscriber_id
// Spec: thread/203
//
// Problem:
//   - guests.phone_e164 stores MX phones WITHOUT cellular "1" indicator (Beds24/AirBnB format):
//     +525582528741
//   - conversations.subscriber_id stores MX phones WITH cellular "1" indicator (WhatsApp format):
//     5215582528741
//
// Solution: when looking up conversations from a guest phone, transform MX phones to add the "1"
// after the "52" country code. Non-MX phones are unchanged (only strip "+").

/**
 * Normalize a phone E.164 to match conversations.subscriber_id format.
 *
 * @param phoneE164 - Phone in E.164 format (with leading "+"), or null
 * @returns Normalized subscriber_id format (no "+", MX cellular "1" inserted), or null
 *
 * Examples:
 *   normalizePhoneToWA('+525582528741') === '5215582528741'  // MX add 1
 *   normalizePhoneToWA('+5215582528741') === '5215582528741' // MX already has 1, no change
 *   normalizePhoneToWA('+15126800858') === '15126800858'     // US/CA passthrough
 *   normalizePhoneToWA('+4916096267970') === '4916096267970' // DE passthrough
 *   normalizePhoneToWA(null) === null
 *   normalizePhoneToWA('') === null
 */
export function normalizePhoneToWA(phoneE164: string | null | undefined): string | null {
  if (!phoneE164 || phoneE164.length === 0) return null;

  // MX cellular: +52XXXXXXXXXX → 521XXXXXXXXXX (insert "1" after "52")
  // Only insert if char at position 3 (after "+52") is NOT already "1"
  if (phoneE164.startsWith('+52') && phoneE164.charAt(3) !== '1') {
    return '521' + phoneE164.slice(3);
  }

  // All other cases: strip "+" only
  return phoneE164.replace('+', '');
}
```

### 4.2 Modificar `apps/worker-bot/src/api/admin/conversation.ts`

En `resolveConvContext` (función nueva agregada por thread/200), modificar el lookup de phone para usar el helper:

```diff
+import { normalizePhoneToWA } from '../../inbox/phone-normalize';
 // ... otros imports
 
 async function resolveConvContext(env: Env, rawId: string): Promise<ConvContext | null> {
   if (rawId.startsWith('b_')) {
     // ... lookup booking ...
     
     // Check if a conversation matches by phone (optional)
     let subscriberId: string | null = null;
     let hasWa = false;
     if (booking.guest_phone) {
-      const phoneNormalized = booking.guest_phone.replace('+', '');
+      const phoneNormalized = normalizePhoneToWA(booking.guest_phone);
+      if (phoneNormalized) {
         const conv = await env.DB.prepare(
           `SELECT subscriber_id FROM conversations WHERE subscriber_id = ?`,
         )
           .bind(phoneNormalized)
           .first<{ subscriber_id: string }>()
           .catch(() => null);
 
         if (conv) {
           subscriberId = phoneNormalized;
           hasWa = true;
         }
+      }
     }
     // ... resto ...
   }
   // ... resto del helper sin cambios ...
 }
```

### 4.3 Modificar `apps/worker-bot/src/inbox/aggregate.ts`

En el SQL de Tab Reservas, el JOIN actual usa REPLACE inline:

```sql
LEFT JOIN conversations c ON c.subscriber_id = g.manychat_subscriber_id
    OR c.subscriber_id = REPLACE(g.phone_e164, '+', '')
```

Hay 2 approaches válidos:

#### Approach 1 — Inline SQL CASE (mantener single query)

```diff
 LEFT JOIN conversations c ON c.subscriber_id = g.manychat_subscriber_id
-    OR c.subscriber_id = REPLACE(g.phone_e164, '+', '')
+    OR c.subscriber_id = (
+      CASE
+        WHEN g.phone_e164 LIKE '+52%' AND substr(g.phone_e164, 4, 1) != '1'
+        THEN '521' || substr(g.phone_e164, 4)
+        ELSE REPLACE(g.phone_e164, '+', '')
+      END
+    )
```

**Pros:** zero extra queries, helper logic mirrored in SQL
**Cons:** logic duplicated TS + SQL, must keep in sync

#### Approach 2 — Post-query TypeScript join (use helper)

Remove the conversations JOIN from the SQL, post-process in TypeScript using normalizePhoneToWA. Requires a second batch query for conv lookup.

**Pros:** single source of truth (helper TS), no SQL duplication
**Cons:** extra DB roundtrip, more code

**Decisión: Approach 1** — pragmático, SQL único, ambos sources documented in code comments cross-referencing the helper.

#### Implementación Approach 1 detallada

En `aggregate.ts` Tab Reservas query block:

```diff
 let query = `
   SELECT
     bb.beds24_booking_id, bb.room_id, bb.arrival, bb.departure,
     bb.num_adults, bb.num_pets, bb.total_amount_mxn, bb.deposit_paid,
     bb.balance_due_mxn, bb.channel, bb.status, bb.guest_id,
     bc.mascotas_confirmed, bc.mascotas_count, bc.menu_status,
     bc.compras_confirmed, bc.morenas_svc_confirmed,
     g.name AS guest_name, g.phone_e164, g.total_bookings,
     c.subscriber_id AS conv_subscriber_id
   FROM beds24_bookings bb
   LEFT JOIN booking_captures bc ON bc.beds24_booking_id = bb.beds24_booking_id
   LEFT JOIN guests g ON g.id = bb.guest_id
+  /* thread/203: MX cellular indicator normalization.
+     guests.phone_e164 stores MX phones without "1" (Beds24/AirBnB format).
+     conversations.subscriber_id stores them with "1" (WhatsApp/ManyChat format).
+     Mirror of normalizePhoneToWA() in src/inbox/phone-normalize.ts. */
   LEFT JOIN conversations c ON c.subscriber_id = g.manychat_subscriber_id
-    OR c.subscriber_id = REPLACE(g.phone_e164, '+', '')
+    OR c.subscriber_id = (
+      CASE
+        WHEN g.phone_e164 LIKE '+52%' AND substr(g.phone_e164, 4, 1) != '1'
+        THEN '521' || substr(g.phone_e164, 4)
+        ELSE REPLACE(g.phone_e164, '+', '')
+      END
+    )
   WHERE bb.room_id != 679176
     AND bb.status NOT IN ('cancelled', 'no_show')
     AND bb.departure >= date('now', '-7 days')
 `;
```

También en el Tab Leads query (líneas ~390 aprox de aggregate.ts):

```diff
 const { results: convRows } = await env.DB.prepare(`
   SELECT c.subscriber_id, c.history, c.last_active, c.last_intent,
          c.active_agent, c.pending_handoff_data, c.bot_paused_until, c.resolved_at
   FROM conversations c
   LEFT JOIN guests g ON g.manychat_subscriber_id = c.subscriber_id
-    OR REPLACE(g.phone_e164, '+', '') = c.subscriber_id
+    OR (
+      CASE
+        WHEN g.phone_e164 LIKE '+52%' AND substr(g.phone_e164, 4, 1) != '1'
+        THEN '521' || substr(g.phone_e164, 4)
+        ELSE REPLACE(g.phone_e164, '+', '')
+      END
+    ) = c.subscriber_id
   LEFT JOIN beds24_bookings bb ON bb.guest_id = g.id AND bb.room_id != 679176
   WHERE bb.id IS NULL
     AND (c.resolved_at IS NULL OR c.resolved_at < unixepoch() - 7 * 86400)
   ORDER BY c.last_active DESC
   LIMIT 300
 `).all<RawConvRow>();
```

(El propósito en Tab Leads: filtrar conversations que YA están linked a un booking, para no mostrarlos como leads. Mismo bug si la normalization falla.)

---

## §5. Tests

### 5.1 NEW `apps/worker-bot/tests/inbox/phone-normalize.test.ts`

```ts
import { describe, it, expect } from 'vitest';
import { normalizePhoneToWA } from '../../src/inbox/phone-normalize';

describe('normalizePhoneToWA', () => {
  describe('MX cellular insertion (+52 → 521)', () => {
    it('inserts "1" after "52" for MX phones without it', () => {
      expect(normalizePhoneToWA('+525582528741')).toBe('5215582528741');
      expect(normalizePhoneToWA('+525584910041')).toBe('5215584910041');
      expect(normalizePhoneToWA('+525540520465')).toBe('5215540520465');
    });

    it('keeps MX phones that already have "1"', () => {
      expect(normalizePhoneToWA('+5215582528741')).toBe('5215582528741');
      expect(normalizePhoneToWA('+5215661027255')).toBe('5215661027255');
    });

    it('handles MX +52 with shorter numbers (edge case)', () => {
      expect(normalizePhoneToWA('+5212225982600')).toBe('5212225982600');
    });
  });

  describe('Non-MX passthrough (strip "+")', () => {
    it('US/CA: strip "+" only', () => {
      expect(normalizePhoneToWA('+15126800858')).toBe('15126800858');
      expect(normalizePhoneToWA('+17144126946')).toBe('17144126946');
    });

    it('DE: strip "+" only', () => {
      expect(normalizePhoneToWA('+4916096267970')).toBe('4916096267970');
    });

    it('CO: strip "+" only', () => {
      expect(normalizePhoneToWA('+57321234567')).toBe('57321234567');
    });
  });

  describe('Null/empty handling', () => {
    it('returns null for null input', () => {
      expect(normalizePhoneToWA(null)).toBeNull();
    });

    it('returns null for undefined input', () => {
      expect(normalizePhoneToWA(undefined)).toBeNull();
    });

    it('returns null for empty string', () => {
      expect(normalizePhoneToWA('')).toBeNull();
    });
  });

  describe('Edge cases', () => {
    it('does NOT add "1" if char at position 3 is already "1"', () => {
      // Already has 1 — must not become +5211XXX
      expect(normalizePhoneToWA('+5215582528741')).toBe('5215582528741');
    });

    it('handles +5 (Brazil-like) without changing — does not falsely match +52', () => {
      expect(normalizePhoneToWA('+5511999999999')).toBe('5511999999999');
    });

    it('handles +521XX (already cellular) without double-adding', () => {
      expect(normalizePhoneToWA('+52155')).toBe('52155'); // Not +52 cellular pattern, falls through
      // Note: this edge is rare; "+52155" is not realistic E.164 anyway
    });
  });
});
```

### 5.2 EXTEND `apps/worker-bot/tests/api/admin/conversation.test.ts`

Agregar tests para `resolveConvContext` que verifiquen el match con MX normalization:

```ts
describe('resolveConvContext — MX phone normalization (thread/203)', () => {
  it('finds WA conversation for MX booking guest with non-1 phone format', async () => {
    // Setup: booking 79421553, guest phone +525582528741 (sin "1"),
    // conversation subscriber_id 5215582528741 (con "1")
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 79421553, guest_phone: '+525582528741' }],
      conversations: [{ subscriber_id: '5215582528741', history: 'USER: hola' }],
    });

    const ctx = await resolveConvContext(env, 'b_79421553');
    expect(ctx?.type).toBe('booking');
    expect(ctx?.subscriberId).toBe('5215582528741');
    expect(ctx?.hasWaConversation).toBe(true);
  });

  it('finds WA conversation for US guest (no MX transform applies)', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 1234, guest_phone: '+15126800858' }],
      conversations: [{ subscriber_id: '15126800858', history: 'USER: hi' }],
    });

    const ctx = await resolveConvContext(env, 'b_1234');
    expect(ctx?.subscriberId).toBe('15126800858');
    expect(ctx?.hasWaConversation).toBe(true);
  });

  it('handles booking with MX guest that already has "1" in phone (no double-1)', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 5678, guest_phone: '+5215661027255' }],
      conversations: [{ subscriber_id: '5215661027255', history: 'USER: hola' }],
    });

    const ctx = await resolveConvContext(env, 'b_5678');
    expect(ctx?.subscriberId).toBe('5215661027255');
    expect(ctx?.hasWaConversation).toBe(true);
  });

  it('returns hasWaConversation=false for booking without matching conv (no WA history exists)', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 9999, guest_phone: '+525511111111' }],
      conversations: [], // no WA history
    });

    const ctx = await resolveConvContext(env, 'b_9999');
    expect(ctx?.subscriberId).toBeNull();
    expect(ctx?.hasWaConversation).toBe(false);
  });
});
```

### 5.3 Test smoke aggregate.ts (opcional, manual via wrangler dev)

Si CC tiene confianza de que JOIN funciona vía D1 query test sin levantar worker:

```sql
-- Verificar manualmente que JOIN encuentra 32 matches (no 4)
SELECT COUNT(DISTINCT g.id) FROM guests g
INNER JOIN conversations c ON c.subscriber_id = (
  CASE
    WHEN g.phone_e164 LIKE '+52%' AND substr(g.phone_e164, 4, 1) != '1'
    THEN '521' || substr(g.phone_e164, 4)
    ELSE REPLACE(g.phone_e164, '+', '')
  END
);
-- Expected: 32
```

(Esto es para Alex post-deploy smoke. NO test automatizado.)

---

## §6. Definition of Done

- [ ] Branch `fix/inbox-phone-normalize-mx-cellular` creada
- [ ] 3 archivos backend modificados/creados:
  - `apps/worker-bot/src/inbox/phone-normalize.ts` (NEW, ~30 LoC)
  - `apps/worker-bot/src/api/admin/conversation.ts` (modify ~5 LoC)
  - `apps/worker-bot/src/inbox/aggregate.ts` (modify ~20 LoC en 2 queries)
- [ ] 2 archivos tests:
  - `apps/worker-bot/tests/inbox/phone-normalize.test.ts` (NEW, ~60 LoC)
  - `apps/worker-bot/tests/api/admin/conversation.test.ts` (extend, ~30 LoC nuevos)
- [ ] `pnpm --filter worker-bot typecheck` PASS 0 errors nuevos
- [ ] `pnpm --filter worker-bot test` los tests nuevos pasan (mínimo 15 tests nuevos del helper + 4 de conversation extension)
- [ ] `git diff main --stat` muestra ~5 archivos, ~130 LoC total
- [ ] PR creada con título: `fix(inbox): normalize phone MX cellular indicator for WA matching (thread/203)`
- [ ] PR description menciona bug crítico, impacto medido (4→32 matches), ⚠️ REQUIRES MANUAL `npx wrangler deploy` post-merge
- [ ] Reporte al final con:
  - Helper agregado
  - 3 lugares modificados (conversation.ts, aggregate.ts × 2 queries)
  - Typecheck PASS
  - Tests pass count
  - PR URL
  - ⚠️ Worker-bot deploy manual + smoke test sugerido

---

## §7. Risks + Mitigations

| Risk | Mitigation |
|---|---|
| Edge case MX phone WITH "1" already → doble "1" → no match | Test explicito en §5.1 `keeps MX phones that already have "1"`. Helper hace check `charAt(3) !== '1'` |
| Non-MX phone con "+52..." prefix por error (Brazil +5511 ≠ +5215) | Helper checa `phoneE164.startsWith('+52')` que es 3 chars exactos. `+5511...` no matchea. Test explicito §5.1 |
| Performance del CASE en SQL aggregate.ts | Negligible. 75 bookings activos × 1 CASE = sub-ms |
| Test fixture mismatch en conversation.test.ts (thread/200 setup nuevo) | CC debe leer file existente primero, adaptar fixture builder |
| Helper se usa en otros lugares futuros pero olvidamos refactorizar | Documenta export claro, comment cross-ref en cada call site |
| SQL CASE duplica lógica del helper TS — pueden divergir | Comment explícito en aggregate.ts apuntando al helper como source of truth. Test mirror logic |
| Si Beds24 alguna vez cambia formato y empieza a enviar con "1", lógica sigue OK | Helper hace passthrough si ya tiene "1". Verified test |

---

## §8. Out-of-scope findings → issues

Si CC encuentra algo durante ejecución NO listado en §2.1:
- Abrir GitHub issue con prefix `[thread/203 OOS]`
- NO fixear inline
- Reportar en thread response

Ejemplos previsibles:
- `manychat_subscriber_id` column populated weirdly → DEFER (column es código muerto desde thread/202 audit)
- Other places en codebase con phone normalization custom (cron-bot-alerts.ts, etc) → reportar pero NO refactor aquí
- TypeScript errors pre-existentes en otros archivos → IGNORE
- thread/201 readiness backend → spec separado
- thread/202 frontend gaps (preview, dates, links) → spec separado post este fix

---

## §9. Kickoff command (Alex pegará a CC)

```
DoIt thread/203: phone normalize MX cellular indicator fix, 1 PR backend-only worker-bot.

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/203-wc-cc-phone-normalize-mx-cellular.md

(Si no la tienes local, pull discussion repo:
cd c:/dev/rdm/dev/discussion && git pull origin main && cd c:/dev/rdm/dev/bot)

Sigue §4 implementation exacto. Self-review §6 DoD antes de commit.

Working directory: c:/dev/rdm/dev/bot

Pre-flight:
1. cd c:/dev/rdm/dev/bot
2. git checkout main
3. git status — debe estar clean en main
4. git pull origin main
5. git log --oneline -1 — confirma estás en último commit (incluye PR #171 merge "fix(inbox): conversation endpoint polimórfico")

Execution:
1. git checkout -b fix/inbox-phone-normalize-mx-cellular
2. Crear apps/worker-bot/src/inbox/phone-normalize.ts según §4.1 (helper exportado normalizePhoneToWA)
3. Editar apps/worker-bot/src/api/admin/conversation.ts según §4.2:
   - Import normalizePhoneToWA
   - resolveConvContext: usar helper en booking.guest_phone lookup
4. Editar apps/worker-bot/src/inbox/aggregate.ts según §4.3:
   - Tab Reservas SQL JOIN: SQL CASE para normalizar phone (Approach 1)
   - Tab Leads SQL JOIN: mismo CASE para guest match
   - Agregar comment explícito apuntando a phone-normalize.ts como source of truth
5. Crear apps/worker-bot/tests/inbox/phone-normalize.test.ts según §5.1 (~15 tests)
6. Extender apps/worker-bot/tests/api/admin/conversation.test.ts según §5.2 (~4 tests nuevos para MX phone normalization)
7. pnpm --filter worker-bot typecheck — must PASS 0 errors nuevos
8. pnpm --filter worker-bot test — todos los tests verdes (incluye thread/200 existing + nuevos)
9. git diff main --stat — verifica ~5 archivos
10. git add (solo los archivos especificados §6)
11. git commit -m "fix(inbox): normalize phone MX cellular indicator for WA matching (thread/203)"
12. git push -u origin fix/inbox-phone-normalize-mx-cellular
13. gh pr create con title "fix(inbox): normalize phone MX cellular indicator for WA matching (thread/203)" y body con:
    - Referencia thread/203
    - Bug crítico: Karina pierde mensajes WA de bookings MX
    - Root cause: asimetría formato (+52XXX vs 521XXX)
    - Impacto medido: 4→32 matches (8x)
    - Helper normalizePhoneToWA aplicado en 2 archivos
    - ⚠️ MANUAL `npx wrangler deploy` REQUIRED post-merge

Scope ESTRICTO: backend-only worker-bot.
- apps/worker-bot/src/inbox/phone-normalize.ts (NEW)
- apps/worker-bot/src/api/admin/conversation.ts (modify)
- apps/worker-bot/src/inbox/aggregate.ts (modify, 2 queries)
- apps/worker-bot/tests/inbox/phone-normalize.test.ts (NEW)
- apps/worker-bot/tests/api/admin/conversation.test.ts (extend)

NO ejecutes:
- pnpm test completo (rompen pre-existentes)
- npx wrangler deploy (Alex lo hace manual post-merge)
- Frontend changes (apps/web/**)
- Backend changes a otros archivos (readiness.ts, lifecycle.ts, etc)
- Database migrations
- ALTER TABLE en ningún momento
- Force-push, branch delete

Si encuentras algo fuera de scope → issue GitHub con prefix [thread/203 OOS].

Bloqueado >30 min en sub-tarea = STOP y reporta.

Reportar al final con:
- Helper normalizePhoneToWA agregado (3 secciones cubiertas: MX, non-MX, null/empty)
- 3 lugares modificados (conversation.ts × 1, aggregate.ts × 2 queries)
- Typecheck PASS
- Tests pass count (mínimo 15 helper + 4 conversation = 19 nuevos)
- PR URL
- ⚠️ CRÍTICO: worker-bot deploy manual + smoke test sugerido (click row Alan Granados #79421553 → debe mostrar mensajes WA)

GO.
```

---

## §10. Post-merge smoke test (Alex executes)

Después de merge + `npx wrangler deploy`:

### Test 1 — Alan Granados (#79421553, MX direct booking con WA history)

1. Browser: https://rincondelmar.club/admin/inbox
2. `Ctrl+F5`
3. Click row **Alan Granados** (sección Llegada ≤48h)

**Esperado:**
- Modal abre con **2-3 mensajes** WA reales
- USER: "Que tal Alexander buena noche, el día lunes tengo una reservación..."
- ASSISTANT: "Le paso esto a Karina o Alex..."
- Booking sidebar con Rincón del Mar, fechas 24-27 may, channel direct

**NO debe pasar:** "Sin mensajes. Puedes iniciar la conversación abajo."

### Test 2 — Verificar preview en Tab Reservas

Una vez deployed, **algunos** rows del Tab Reservas (aquellos con guest match WA) deberían mostrar preview del último mensaje. Hoy todos vacíos. Después: ~4-10 con preview real.

Esperar: rows como Alan Granados, Mariana Alcázar (13 turns), Yosselin Sánchez (si phones match) muestren texto preview.

(Esto **no** arregla todos los gaps thread/202 — falta thread separado para frontend display changes — solo arregla los rows donde la conversation YA existe y nunca se mostraba.)

### Test 3 — Verificar Claudia Becerra (AirBnB, no debe romperse)

Booking 86656062, channel airbnb, OTA messages en bot_messages_inbox.

**Esperado (mismo que antes):**
- Modal muestra ~24 mensajes AirBnB
- Booking sidebar Huerta Cocotera

**NO debe pasar:** regression — los OTA messages siguen visibles.

### Test 4 — Verificar Tab Leads no se rompe

Cualquier lead WhatsApp.

**Esperado:**
- Modal abre con history WA
- Sin booking sidebar

---

## §11. References

- thread/196: Spec inbox redesign (original, no contempló este edge case)
- thread/198: Hotfix CORS (PR #169 merged)
- thread/199: Display fields + CSS + readiness compact (PR #170 merged)
- thread/200: Conversation endpoint polimórfico (PR #171 merged)
- thread/201: Readiness in-stay override (ready, awaiting CC)
- thread/202: Gap analysis + 5 decisiones pendientes (nota WC, not executable)
- D1 query investigation 2026-05-24 ~09:00 UTC: phone normalization asymmetry discovered via Alex visual verification of Alan Granados case
- Worker-bot deploy gotcha: memoria #27 — manual `npx wrangler deploy` requerido
- Sample data: 7,442 guests MX sin "1", 199/205 conversations MX con "1"
