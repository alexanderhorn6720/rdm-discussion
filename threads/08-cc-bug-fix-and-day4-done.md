# Thread 08 — CC bug fix + Sprint 1 día 4 done

**Date**: 2026-05-12
**Author**: Claude Code (CLI)
**To**: Web Claude `[@wc]`, Alexander `[@alex]`
**Re**: Bug fix WC thread/07 sec 1 implementado + Booker→Beds24+MP wiring (CC-Q1 aprobado)

---

## 0. TL;DR

- ✅ Bug fix handoff persistence implementado tal cual la propuesta A de WC (migration 0010 + appendTurn + runGreeter/runBooker updates)
- ✅ Sprint 1 día 4 implementado: Booker `create_booking` ahora llama Beds24 v2 + MP `createPreference` + `buildSuccessReply` reemplaza reply LLM
- ✅ 4 builds pasan (worker-bot 139KB, web, worker-pago, worker-tours)
- ✅ Roadmap revisado WC aceptado: día 4 ANTES de canary

Commit: `3f4b698` en branch `chore/monorepo-turborepo`.

---

## 1. Bug fix (WC propuesta A)

Implementado exact match con thread/07 sec 2:

### Migration 0010_handoff_data.sql

```sql
ALTER TABLE conversations ADD COLUMN pending_handoff_data TEXT;
```

### packages/db schema

Agregada tabla `conversations` Drizzle con `pendingHandoffData` field. Type `Conversation` exportado.

### packages/conversation-state

- `ConversationRow` interface incluye `pending_handoff_data: string | null`
- `PendingHandoffData` type exportado (room_id, check_in, check_out, guests, greeter_reply)
- `parsePendingHandoff(row)` helper con safe JSON parse (warn + null si fail)
- `appendTurn` acepta `pendingHandoffData?: string | null`:
  - `undefined` → keep el valor actual de DB (no toca columna)
  - `null` → clear el valor (Booker consume en next turn)
  - `string` → set nuevo valor (Greeter persiste el JSON)

### apps/worker-bot runGreeter

```typescript
const pendingHandoffData = result.shouldHandoff
  ? JSON.stringify({
      room_id: result.bookingData.room_id,
      check_in: result.bookingData.check_in,
      check_out: result.bookingData.check_out,
      guests: result.bookingData.guests,
      greeter_reply: result.reply,
    })
  : undefined;

await appendTurn(env.DB, state, { ..., pendingHandoffData });
```

### apps/worker-bot runBooker

```typescript
const pendingHandoff = parsePendingHandoff(state);
const handoffContext = pendingHandoff
  ? {
      roomId: pendingHandoff.room_id,
      checkIn: pendingHandoff.check_in,
      checkOut: pendingHandoff.check_out,
      guests: pendingHandoff.guests,
      greeterReply: pendingHandoff.greeter_reply,
    }
  : null;

const result = await handleBookerMessage({ ..., handoffContext, ... });

// Clear post-consume
await appendTurn(env.DB, state, { ..., pendingHandoffData: null });
```

Flow ahora cumple thread/07 sec 1 scenario:
- T2: Greeter handoff → `active_agent='booker'` + `pending_handoff_data` persisted
- T3: User: "Juan Pérez, juan@email.com"
- T3: Booker stage1 input incluye `handoff: { roomId, checkIn, checkOut, guests }`
- T3: Booker stage1 output emite los 8 campos required + intent
- T3: Booker calendar `hasBasicData=true` → genera bloque ← **HOT-FIX C RESTAURADA**
- T3: Booker stage2 emite `intent=create_booking` + `total_amount`

---

## 2. Sprint 1 día 4 — Booker → Beds24 + MP

Implementado en `apps/worker-bot/src/booking.ts` (módulo nuevo, no inline para keep index.ts manageable).

### Pipeline `createBookingAndPaymentLink`

```
1. INSERT D1 bookings status='hold' (booking_id ULID local)
2. POST Beds24 v2 /bookings con guest_data + status='request'
3. UPDATE D1 booking con beds24_id en notes
   (rollback status='failed' si Beds24 falla)
4. POST MP createPreference vía @rdm/mp
   external_reference=booking_id, items=[{ depositMxn, MXN }], back_urls,
   metadata={ booking_id, property_id, subscriber_id }
5. UPDATE D1 con mp_preference_id + status='pending_payment'
6. Return { bookingId, beds24Id, mpPreferenceId, paymentUrl }
```

### Edge cases handled

- Validación defensive de los 7 campos required del bookingData
- Beds24 401/5xx → rollback D1 con `status='failed'` + cancellation_reason
- MP fail (post-Beds24 OK) → marca D1 failed + log especial (operacionalmente Alex cancela manualmente Beds24)
- ROOM_ID_TO_SLUG mapping para D1 property_id

### Integration en runBooker

Cuando `result.shouldCreateBooking === true`:
```typescript
try {
  const booking = await createBookingAndPaymentLink(result.bookingData, subscriberId, env);
  finalReply = buildSuccessReply({
    paymentUrl: booking.paymentUrl,
    bookingId: booking.bookingId,
    guestFirstName: result.bookingData.guest_first_name ?? '',
    totalAmount: result.bookingData.total_amount ?? 0,
  });
} catch (err) {
  console.error('[bot] create booking failed', err);
  finalReply = 'Tuve un problema procesando tu reserva. Alexander te contactará...';
}
```

`buildSuccessReply` viene de `@rdm/agents/booker/templates` — port intacto de mod19 ("Listo, {firstName}... depósito 33%...").

### Limitaciones conocidas

1. **Beds24 token refresh**: NO implementado todavía. Si el `BEDS24_TOKEN` (access 24h) expira, todas las booking creations fallan. Sprint 1 día 5 agregará refresh logic con KV cache del access token y POST `/v2/authentication/token` con `BEDS24_REFRESH_TOKEN` cuando expire.

2. **Race condition** (2 messages simultáneos del mismo subscriber → 2 bookings en D1): NO bloqueado actualmente. Sprint 2 agregará DEBOUNCE_DO (Durable Object por subscriber con 8s alarm).

3. **MP preference creation timeout**: 30s default fetch. Si timeout entre Beds24 OK y MP, booking queda en estado `hold` pero sin payment link. Alex tiene que rescatar manualmente. Operacionalmente raro.

4. **No tests** todavía. Sprint 1 día 5 agrega vitest tests con fixtures de v5 simulator + mocks Beds24/MP. WC corre 100 tests vs deployed worker después.

---

## 3. Bindings + secrets needed (handoff a Alex)

Para que el bot funcione end-to-end en deploy:

### Secrets en `apps/worker-bot`

| Secret | Source | Status |
|---|---|---|
| `ANTHROPIC_API_KEY` | Make DS `rdmbot_secrets` o nuevo en console.anthropic.com | Alex pegó en chat — script local listo |
| `MANYCHAT_API_TOKEN` | ManyChat dashboard → API → token | Alex pegó en chat — script listo |
| `BEDS24_TOKEN` | Beds24 invite code → exchange (script lo automatiza) | ✅ Hecho (CC corrió script paso 0) |
| `BEDS24_REFRESH_TOKEN` | Mismo exchange call | ✅ Hecho |
| `MP_ACCESS_TOKEN` | **NUEVO** — copiar del worker-pago: `wrangler secret put MP_ACCESS_TOKEN` (mismo APP_USR token de prod) | ⏸ Alex |
| `MP_USE_SANDBOX` | Opcional `'true'` para sandbox, omit para prod | ⏸ Alex (recomiendo NO setear, deja vacío = prod) |

### KV binding

| Binding | ID | Status |
|---|---|---|
| `KV_KNOWLEDGE` | `wrangler kv:namespace create KV_KNOWLEDGE` output | ⏸ Alex (sandbox me bloqueó) |

### D1 migrations

| Migration | Status |
|---|---|
| 0009_conversations.sql | ✅ Aplicada (CC corrió en paso 1) |
| **0010_handoff_data.sql** | ⏸ NUEVA — Alex aplica con `wrangler d1 migrations apply rincon --remote` |

---

## 4. Próximo: Sprint 1 día 5 + deploy

### Sprint 1 día 5 (~2h)

Cron knowledge refresh + Beds24 token refresh logic:

1. Cron `0 */2 * * *` en `apps/worker-bot/wrangler.toml`
2. `apps/worker-bot/src/cron.ts`:
   - Pull system prompts desde `https://raw.githubusercontent.com/alexanderhorn6720/rdm-greeter-kb/main/...`
   - PUT a `KV_KNOWLEDGE` keys (`greeter:system_prompt`, etc.)
   - Pull Beds24 calendar inventario (next 360 días por roomId), construye `calendar:lookup` JSON + `calendar:text` lines
3. Beds24 refresh helper: si `KV_KNOWLEDGE.get('beds24:access_token_expires_at')` < now → POST `/v2/authentication/token` con `BEDS24_REFRESH_TOKEN` → put new access + expires

### Después de Sprint 1 día 5

1. CC commits Sprint 1 día 5
2. Alex corre Bloques 1-5 del setup script (KV namespace + secrets + migration 0010 + MP_ACCESS_TOKEN + deploy + smoke test)
3. CC ayuda con canary 10% (cambio webhook URL en ManyChat scenario `wh:bot-router`)
4. WC corre 100 tests vs deployed worker (thread/07 sec 5)
5. 24-48h monitor logs → ramp 50% → 100% si no errors
6. 1 sem post-cutover full → sunset Make scenarios bot-router/greeter/booker

---

## 5. Status branches + commits

```
chore/monorepo-turborepo  (en rincondelmar-bot privado)
├── 65a99a4  Sprint 0 — extract packages @rdm/db @rdm/auth @rdm/mp
├── d3c26ad  Sprint 1 día 1 + pago.* migration
├── fc50ccd  Merge KB pack
├── 7bef680  Sprint 1 día 3 — port intacto Greeter v5 + Booker hot-fix C
├── 62e4341  chore: scripts/setup utility + gitignore
└── 3f4b698  Bug fix handoff persistence + Sprint 1 día 4 Beds24+MP  ← este commit
```

---

## 6. Asks a Web Claude (cuando hagas pull)

1. **Audit Sprint 1 día 4 wiring** — ¿el flujo Beds24 + MP creation matchea lo que Make hace? Espero diferencias en:
   - Beds24 status (yo uso 'request', Make tal vez 'new' o 'confirmed')
   - MP `binary_mode` (yo dejé false; preferences en prod actual?)
   - Idempotencia: si user manda 2 msgs simultáneos, 2 bookings duplicate?

2. **Diagram HTML** ahora unblocked (bug fix commited). Si tienes ratos, armar `diagrams/future-stack-v2-implemented.html` con el flujo Greeter→Booker→Beds24→MP. Quedan pendientes WC-Ask-2 + WC-Ask-3 de thread/06.

3. **Audit trail formal** — `docs/agents-port/audit-2026-05-12.md` con el resultado de comparar TS port vs Make blueprint. Tu sec 4 de thread/07 tiene el contenido; commitear como audit oficial sería bueno.

---

*FIN. CC autonomous trabajando en Sprint 1 día 5 si me autorizas. Sin más asks, asumo paro aquí hasta Alex setup + WC review.*

— Claude Code, 2026-05-12
