---
thread: 199
author: wc
topic: inbox-bugs-1-3-display-fields-and-booking-link
status: ready-for-execution
mode: DoIt
created: 2026-05-24
related_threads: [196, 197, 198]
related_prs: [167, 169]
estimated_effort: 30-45min CC (1 session, frontend-only)
pipeline: single-CC
out_of_scope_for_now: bug-2-conversation-lookup (separate thread/200)
---

# Thread 199 — Inbox bugs 1 + 3: display fields + booking deep-link

## §0. TL;DR

Post-deploy thread/198 reveló 3 bugs visuales. Este PR resuelve 2 de los 3 (easy fixes frontend-only):

**Bug 1 — Filas incompletas:** rows muestran solo `name + relative_time + channel + readiness + property`. Faltan `pax`, `days_to_checkin`, badge `🐶 has_pet`. Backend YA devuelve estos datos en `InboxRow` contract, solo el componente no los renderiza.

**Bug 3 — Falta link a /admin/bookings/[id]:** cuando ConversationView falla con error (bug 2 separado), no hay forma de saltar a la booking detail page existente. Solución: parsear `beds24_booking_id` del row.id prefix `b_xxx` y mostrar link en el error UI.

**Bug 2 (conversation lookup polimórfico) = thread/200 separado** — requiere análisis backend más profundo, se trabaja después.

---

## §1. Context (why)

### 1.1 Lo que mostró la verificación post-deploy thread/198

Inbox en `https://rincondelmar.club/admin/inbox` muestra:
- Counter 79 ✅ (data real backend)
- 5 sections lifecycle ✅
- Filter dropdowns ✅
- **PERO** las filas solo dicen `Claudia Becerra | 7s | Airbnb 2/6 Huerta Cocotera`. Falta pax, fechas, mascota.
- Click row → modal "not_found" SIN link a booking detail page.

### 1.2 Backend SÍ devuelve esos campos

Confirmed en `apps/worker-bot/src/inbox/aggregate.ts` líneas 220-260:
```ts
rows.push({
  id: `b_${br.beds24_booking_id}`,
  ...
  pax: br.num_adults,           // ← devuelto
  has_pet: br.num_pets > 0,     // ← devuelto
  days_to_checkin: daysToCheckin, // ← devuelto
  ...
});
```

Tipo `InboxRow` en `apps/web/src/lib/inbox-client.ts` los declara. Solo `InboxRow.tsx` no los renderiza.

### 1.3 Booking detail page existe

Verificado: `apps/web/src/pages/admin/bookings/[id].astro` está deployed (PR #155 area). URL pattern: `/admin/bookings/{beds24_booking_id}`. Lista, ready para reusar.

### 1.4 row.id contiene el booking_id

El aggregate genera `id: \`b_${beds24_booking_id}\`` para bookings. Parsing `id.slice(2)` da el booking_id sin necesidad de cambio de contract.

---

## §2. Explicit scope

### 2.1 IN scope

| Archivo | Cambio |
|---|---|
| `apps/web/src/components/inbox/InboxRow.tsx` | Render `pax`, `has_pet` badge, `days_to_checkin` chip |
| `apps/web/src/components/conversation/ConversationView.tsx` | En el error UI, parsear convId prefix `b_` y mostrar link a `/admin/bookings/{id}` |
| `apps/web/src/lib/inbox-client.ts` | Add pure helper `extractBookingIdFromRowId(id: string): number \| null` (also exported for tests) |
| `apps/web/tests/inbox/InboxRow.test.ts` | Add tests para nuevos display fields |
| `apps/web/tests/inbox/inbox-client.test.ts` | Add test para `extractBookingIdFromRowId` helper |

### 2.2 OUT of scope (NO tocar)

- ❌ **Bug 2 (conversation lookup polimórfico)** — separado en thread/200
- ❌ `MOCK_RESPONSE` removal en InboxApp.tsx — G2 handshake followup
- ❌ Backend changes a `aggregate.ts`, `conversation.ts`, `inbox.ts`
- ❌ Database migrations
- ❌ CSS rework amplio (solo agregar 2-3 classes nuevas si necesarias)
- ❌ Casa Chamán mentions
- ❌ Click row UX change (handleRowClick queda como está, bug 2 lo refactoriza)
- ❌ Deep-link button en la row (Alex pidió link en MODAL, no en row — leer §3 D3)

---

## §3. Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Bug 3 link va en error UI de ConversationView, NO en cada InboxRow | Pedido por Alex literal: "modal = not_found / missing link to /booking?id=X". Less visual noise en lista. |
| D2 | Parsear `b_xxx` prefix con helper pure, NO agregar `beds24_booking_id` field al contract | Backend contract sin cambio = bug 2 spec independiente. Menos blast radius. |
| D3 | Formato días to check-in: "T-3d" / "hoy" / "mañana" / "ayer salió" / "día N estadía" | Mobile-friendly, espacio compacto. Karina-friendly ES strings inline. |
| D4 | Render pax como `👥 N` con pet 🐶 sufijo cuando aplica | Iconos universales, sin labels redundantes |
| D5 | days_to_checkin chip va antes del relative timestamp en el row | Más importante operacionalmente que "hace 7s" |
| D6 | Si row.pax === null (lead), NO renderizar el bloque pax | Leads no tienen pax porque no hay booking. Sección stay-info se oculta. |
| D7 | Si row.days_to_checkin === null (lead), NO renderizar chip | Idem. |
| D8 | ConversationView error fallback: parse `b_xxx` → link to `/admin/bookings/{id}`. Texto botón: "Ver detalle de la reserva" | Karina-friendly ES. |
| D9 | helper `extractBookingIdFromRowId` retorna `null` si formato no es `b_<number>` (incluye `conv_xxx` o strings raros) | Defensive, no throw. |
| D10 | NO modificar handleRowClick en InboxApp.tsx (sigue pasando rawId) | Bug 2 hará ese refactor. Scope estricto. |

---

## §4. Implementation

### 4.1 Helper en `inbox-client.ts`

Agregar al final del archivo (junto a los otros helpers `fmtRelative`, `fmtDate`, etc):

```ts
/** Extract beds24_booking_id from row.id prefix "b_". Pure, testable. */
export function extractBookingIdFromRowId(id: string): number | null {
  if (!id.startsWith('b_')) return null;
  const n = Number(id.slice(2));
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** Format days to check-in for inbox row display. Pure, testable. */
export function formatDaysToCheckin(days: number): string {
  if (days === 0) return 'hoy';
  if (days === 1) return 'mañana';
  if (days > 0) return `T-${days}d`;
  if (days === -1) return 'ayer salió';
  return `día ${-days} estadía`;
}
```

### 4.2 InboxRow.tsx — Render display fields

Modificar `apps/web/src/components/inbox/InboxRow.tsx`:

**Import el helper nuevo:**
```diff
 import type { InboxRow as Row } from '@/lib/inbox-client';
-import { fmtRelative } from '@/lib/inbox-client';
+import { fmtRelative, formatDaysToCheckin } from '@/lib/inbox-client';
 import ReadinessScore from './ReadinessScore';
```

**Agregar bloque stay-info DESPUÉS del `inbox-row-name` div y ANTES del `inbox-row-time`:**

```tsx
{/* Stay info: pax + pet + days_to_checkin — only for bookings */}
{(row.pax !== null || row.days_to_checkin !== null) && (
  <div className="inbox-row-stay-info">
    {row.pax !== null && (
      <span className="inbox-row-pax">
        👥 {row.pax}
        {row.has_pet && <span aria-label="con mascota"> 🐶</span>}
      </span>
    )}
    {row.days_to_checkin !== null && (
      <span className="inbox-row-days">
        {formatDaysToCheckin(row.days_to_checkin)}
      </span>
    )}
  </div>
)}
```

El layout final del row queda:
```
[name + badges]
[stay-info: 👥 4 🐶  T-3d]   ← NEW
[time relative]
[preview]
[meta: channels + lang + readiness + property]
```

### 4.3 ConversationView.tsx — Booking deep-link en error UI

Modificar el error fallback (líneas ~135-145 aprox):

```diff
-  if (error || !data) {
-    return (
-      <div className={`conv-page${embedded ? ' conv-page-embedded' : ''}`}>
-        <div className="conv-main">
-          <div style={{ padding: 'var(--sp-4)', color: 'var(--color-error)' }}>
-            {error ?? 'Sin datos'}
-          </div>
-        </div>
-      </div>
-    );
-  }
+  if (error || !data) {
+    const bookingId = extractBookingIdFromRowId(convId);
+    return (
+      <div className={`conv-page${embedded ? ' conv-page-embedded' : ''}`}>
+        <div className="conv-main">
+          <div style={{ padding: 'var(--sp-4)', textAlign: 'center' }}>
+            <p style={{ color: 'var(--color-error)', marginBottom: 'var(--sp-3)' }}>
+              {error === 'not_found'
+                ? 'No encontramos conversación de WhatsApp para esta reserva.'
+                : (error ?? 'Sin datos')}
+            </p>
+            {bookingId !== null && (
+              <a
+                href={`/admin/bookings/${bookingId}`}
+                className="conv-action-btn"
+                style={{ display: 'inline-block', textDecoration: 'none' }}
+              >
+                Ver detalle de la reserva →
+              </a>
+            )}
+            {onBack && (
+              <button
+                type="button"
+                className="conv-action-btn"
+                onClick={onBack}
+                style={{ marginLeft: 'var(--sp-2)' }}
+              >
+                ← Volver al inbox
+              </button>
+            )}
+          </div>
+        </div>
+      </div>
+    );
+  }
```

**Y agregar al import:**
```diff
-import { fmtDate } from '@/lib/inbox-client';
+import { extractBookingIdFromRowId, fmtDate } from '@/lib/inbox-client';
```

### 4.4 CSS — Agregar 2 classes nuevas

En `apps/web/src/styles/inbox.css` agregar al final:

```css
/* thread/199 — stay info inline */
.inbox-row-stay-info {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
  margin-top: var(--sp-1);
}

.inbox-row-pax,
.inbox-row-days {
  display: inline-flex;
  align-items: center;
  white-space: nowrap;
}

.inbox-row-days {
  font-weight: 500;
  color: var(--color-accent);
}
```

(Si las variables CSS no existen exactas, usar las que defina el design system existente. Ver archivos `*.css` cercanos para conventions actuales.)

---

## §5. Tests

### 5.1 Test nuevo helper

En `apps/web/tests/inbox/inbox-client.test.ts` agregar:

```ts
import { extractBookingIdFromRowId, formatDaysToCheckin } from '@/lib/inbox-client';

describe('extractBookingIdFromRowId', () => {
  it('parses valid b_<number> format', () => {
    expect(extractBookingIdFromRowId('b_86656366')).toBe(86656366);
    expect(extractBookingIdFromRowId('b_12345')).toBe(12345);
  });
  it('returns null for non-booking IDs', () => {
    expect(extractBookingIdFromRowId('conv_5214424441234')).toBeNull();
    expect(extractBookingIdFromRowId('5214424441234')).toBeNull();
    expect(extractBookingIdFromRowId('')).toBeNull();
  });
  it('returns null for invalid b_ formats', () => {
    expect(extractBookingIdFromRowId('b_abc')).toBeNull();
    expect(extractBookingIdFromRowId('b_-5')).toBeNull();
    expect(extractBookingIdFromRowId('b_0')).toBeNull();
  });
});

describe('formatDaysToCheckin', () => {
  it('formats future dates', () => {
    expect(formatDaysToCheckin(0)).toBe('hoy');
    expect(formatDaysToCheckin(1)).toBe('mañana');
    expect(formatDaysToCheckin(3)).toBe('T-3d');
    expect(formatDaysToCheckin(15)).toBe('T-15d');
  });
  it('formats past dates (in-stay or post-stay)', () => {
    expect(formatDaysToCheckin(-1)).toBe('ayer salió');
    expect(formatDaysToCheckin(-2)).toBe('día 2 estadía');
    expect(formatDaysToCheckin(-5)).toBe('día 5 estadía');
  });
});
```

### 5.2 Test render InboxRow

En `apps/web/tests/inbox/InboxRow.test.ts` agregar:

```ts
describe('InboxRow display fields (thread/199)', () => {
  it('renders pax when available', () => {
    const row = makeRow({ pax: 4, has_pet: false, days_to_checkin: 3 });
    // assertion shape according to test helpers used (renderRow/screen).
    // verify that row has '👥 4' in rendered text and 'T-3d' in rendered text
    // and does NOT contain 🐶
  });
  it('renders pet badge when has_pet=true', () => {
    const row = makeRow({ pax: 6, has_pet: true });
    // verify 🐶 in rendered text
  });
  it('does not render stay-info block for leads (pax=null)', () => {
    const row = makeRow({ pax: null, days_to_checkin: null });
    // verify .inbox-row-stay-info NOT present
  });
});
```

(Adapt assertion style al framework de testing existente — vitest + happy-dom. Si los tests usan `render()` de `@testing-library/react`, usar `screen.getByText` etc. Si los tests son data fixture invariants, adapt accordingly.)

---

## §6. Definition of Done

- [ ] Branch `fix/inbox-display-fields-and-booking-link` creada
- [ ] 3 archivos modificados:
  - `apps/web/src/lib/inbox-client.ts` (+10 LoC helpers)
  - `apps/web/src/components/inbox/InboxRow.tsx` (+15 LoC)
  - `apps/web/src/components/conversation/ConversationView.tsx` (+15 LoC error fallback)
- [ ] 1 archivo CSS:
  - `apps/web/src/styles/inbox.css` (+10 LoC)
- [ ] 2 archivos tests:
  - `apps/web/tests/inbox/inbox-client.test.ts` (+30 LoC)
  - `apps/web/tests/inbox/InboxRow.test.ts` (+25 LoC)
- [ ] `pnpm --filter web typecheck` PASS 0 errors
- [ ] `pnpm --filter web test` PASS (al menos los tests nuevos verdes)
- [ ] `git diff main --stat` muestra solo los archivos esperados (5-6 archivos, ~100 LoC total)
- [ ] PR creada con título: `fix(inbox): display fields + booking deep-link (thread/199)`
- [ ] PR description menciona Bug 1 + Bug 3 con referencia thread/199 y nota que Bug 2 va en thread/200 separado
- [ ] Reporte al final con:
  - 4 cambios aplicados (resumen 1 línea cada uno)
  - Tests pass count
  - PR URL
  - Recordatorio que NO requiere worker-bot redeploy (frontend-only)

---

## §7. Risks + Mitigations

| Risk | Mitigation |
|---|---|
| CSS variables (`--sp-4`, `--color-accent`, etc) no existen | Verificar `apps/web/src/styles/inbox.css` antes — usar las variables que ya existen. Si no existen, hardcode reasonable values (8px, var(--color-text-base), etc) |
| Helper `formatDaysToCheckin` colisiona con función existente | Grep antes de definir: `grep -rn "formatDays" apps/web/src/` |
| Test helpers (`makeRow`) ya tienen shape diferente | Leer InboxRow.test.ts existente primero, adapt fixture style |
| ConversationView error fallback rompe layout drawer en desktop | Verificar visual post-deploy, padding/centering. NO bloqueador, ajuste cosmético si necesario |
| `extractBookingIdFromRowId('b_0')` debería ser null o 0? | Decisión: null. Booking ID 0 no es válido en beds24. Test cubre. |

---

## §8. Out-of-scope findings → issues

Si CC encuentra algo durante ejecución NO listado en §2.1:
- Abrir GitHub issue con prefix `[thread/199 OOS]`
- NO fixear inline
- Reportar en thread response

Ejemplos previsibles:
- TypeScript errors pre-existentes en otros archivos → IGNORE, no son scope
- Tests rotos en otros componentes → IGNORE
- Wave 1.5 followups (deploy-worker-bot.yml, MOCK_RESPONSE removal, subscribers table) → DEFER
- Bug 2 conversation lookup → DEFER a thread/200

---

## §9. Kickoff command (Alex pegará a CC)

```
DoIt thread/199: inbox display fields + booking deep-link, 1 PR frontend-only.

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/199-wc-cc-inbox-display-and-booking-link.md
o https://github.com/alexanderhorn6720/rdm-discussion/blob/main/threads/199-wc-cc-inbox-display-and-booking-link.md

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
1. git checkout -b fix/inbox-display-fields-and-booking-link
2. Edit apps/web/src/lib/inbox-client.ts según §4.1 (2 helpers nuevos: extractBookingIdFromRowId + formatDaysToCheckin)
3. Edit apps/web/src/components/inbox/InboxRow.tsx según §4.2 (bloque stay-info)
4. Edit apps/web/src/components/conversation/ConversationView.tsx según §4.3 (error fallback con booking link)
5. Edit apps/web/src/styles/inbox.css según §4.4 (3 CSS classes nuevas)
6. Add tests inbox-client.test.ts según §5.1
7. Add tests InboxRow.test.ts según §5.2
8. pnpm --filter web typecheck — must PASS 0 errors
9. pnpm --filter web test — tests pass (al menos los nuevos)
10. git diff main --stat — verifica 6 archivos modificados
11. git add (solo esos archivos)
12. git commit -m "fix(inbox): display fields + booking deep-link (thread/199)"
13. git push -u origin fix/inbox-display-fields-and-booking-link
14. gh pr create con título "fix(inbox): display fields + booking deep-link (thread/199)" y body con referencia thread/199, 2 bugs resueltos (1 + 3), nota que bug 2 va en thread/200 separado y que NO requiere worker-bot redeploy.

Scope ESTRICTO: frontend-only.
- apps/web/src/lib/inbox-client.ts (2 helpers nuevos)
- apps/web/src/components/inbox/InboxRow.tsx
- apps/web/src/components/conversation/ConversationView.tsx
- apps/web/src/styles/inbox.css
- apps/web/tests/inbox/inbox-client.test.ts
- apps/web/tests/inbox/InboxRow.test.ts

NO ejecutes:
- pnpm test completo (rompen pre-existentes)
- npx wrangler deploy (no worker-bot changes)
- Backend changes (aggregate.ts, conversation.ts, inbox.ts)
- Force-push, branch delete

Si encuentras algo fuera de scope → issue GitHub con prefix [thread/199 OOS].

Bloqueado >30 min en sub-tarea = STOP y reporta.

Reportar al final con:
- 4 cambios aplicados (resumen 1 línea cada uno)
- Typecheck PASS
- Tests pass count
- PR URL
- Confirmar que NO requiere worker-bot deploy

GO.
```

---

## §10. References

- thread/196: Inbox redesign megaspec
- thread/197: AirBnB flows backlog
- thread/198: Hotfix cross-origin (PR #169 merged)
- thread/200: Bug 2 conversation lookup (a redactar después)
- PR #167: FE inbox scaffold (merged)
- PR #169: Hotfix CORS + roomIds (merged)
- Backend contract: `apps/worker-bot/src/inbox/aggregate.ts` (read-only reference)
- BookingDetailView page: `apps/web/src/pages/admin/bookings/[id].astro` (deep-link target)
