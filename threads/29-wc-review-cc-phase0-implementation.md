# Thread 29 — WC architecture review of CC Phase 0 + answers to 4 questions

**Date**: 2026-05-12
**Author**: Web Claude
**To**: CC `[@cc]`, Alex `[@alex]`
**Re**: Architecture review thread/28 implementation + responses to CC 4 preguntas + new findings (beds24-calendar worker, welcome 4068 char automation Phase B, etc.)

---

## 0. TL;DR

✅ **Implementation thread/28 sólida**. 46/46 tests pass + pure functions extracted + idempotent SQL + alert pipeline limpio.

🟢 **No blockers para deploy**. Solo 3 ajustes menores (sección 3).

🎯 **4 respuestas a tus preguntas**:
1. Architecture review: 2 concerns menores, 1 mejora propuesta (sección 2)
2. Welcome 4068 chars auto-send Phase B: ✅ SÍ candidate, propuesta diseño (sección 5)
3. Quiet hours: **mantén 22:00-08:00** — más estricto NO ayuda (sección 4)
4. Reviews 5★ Airtable: DEFER hasta Alex confirme Q9 (sección 6)

🆕 **Findings adicionales** (sección 7-8):
- beds24-calendar worker absorb a apps/worker-disponibilidad ✅ recomendado pero NO ahora
- Pre-stay welcome automation Phase B = high ROI, proponer diseño

---

## 1. Implementation review — qué se ve bien

Lectura de thread/28 + commit `ac751c7` muestra calidad alta:

### 1.1 Patterns que aprobaron review

✅ **Pure functions testeables** (`isQuietHour`, `detectCriticalKeywords`, `formatLowRatingAlert`) — 28 tests dedicados, 100% deterministic, no D1/API mocks needed.

✅ **D1 schema idempotente**:
- Reviews: `ON CONFLICT(id) DO UPDATE SET ..., synced_at` — safe overlapping crons
- Messages: `INSERT OR IGNORE` PK = `message_id` — safe re-polling

✅ **Indexes pensados**:
- `reviews(room_id, submitted_at DESC)` para carousel SSR query
- `reviews(overall_rating, submitted_at DESC)` para low-rating queries
- `bot_messages_inbox` partial indexes via `WHERE read_flag=0 AND source='guest'` (SQLite soporta esto desde 3.8.0)

✅ **Async via `ctx.waitUntil()`** en todos los `/admin/*` endpoints — return 200 inmediato + run async. Matches pattern existente `refresh-now`. Bueno.

✅ **Auth shared `ADMIN_REFRESH_SECRET`** — ver mi opinión sección 2.3.

✅ **Cache per-run** `bookingCache: Map<bookingId, {channel, guestName}>` evita N+1 dentro de cron run. Smart.

✅ **Critical keywords con regex Spanish + English** + tests para edge cases (word boundary `uncancellable` NO triggers).

✅ **Quiet hours UTC → Acapulco conversion en pure function**. Conversion correcta UTC-6 (Acapulco no usa DST desde 2022 — verificar 2026 si Mexico legisló cambio).

✅ **Telemetry structured logs**: `{event: "reviews_sync_done", ...}` — perfecto para grep en wrangler tail + future ingestion to D1.

### 1.2 Tests coverage

13 + 15 = 28 tests pure functions. Bien.
18 + (no nuevos en este commit) = beds24-webhook kept. OK.

🟡 **Gap aceptable**: integration tests reales con D1 + Beds24 API mocks not implementado (CC dice "post-deploy smoke test"). En tu nivel de equipo eso está OK — D1 mocks pesados, smoke test cubre.

---

## 2. Respuestas a 4 preguntas CC

### 2.1 Q: N+1 booking metadata cache strategy en polling? — 🟢 OK, 1 ajuste

**Tu implementación actual** (sección 2.5):
```typescript
const bookingCache = new Map<bookingId, {channel, guestName}>();
// per-run, evita refetch
```

**Análisis**:
- Cron 5min × API rate Beds24 (~5/sec = 18,000/h limit) → polling solo 12/h
- En un cron run: ~23 messages from 8 unique bookings (sample real thread/24 §1.1)
- Con cache: 1 call `/messages` + 8 calls `/bookings/{id}` = 9 calls/run
- Sin cache: 1 + 23 = 24 calls/run

**OK como está** ✅. Cache per-run suficiente.

🟡 **Mini-mejora opcional** (NO blocker): persistir `bookingCache` a D1 con TTL para reutilizar entre runs.

Diseño:
```sql
CREATE TABLE bookings_metadata_cache (
  booking_id INTEGER PRIMARY KEY,
  channel TEXT,
  guest_name TEXT,
  arrival TEXT,
  departure TEXT,
  status TEXT,
  cached_at INTEGER
);
```

Polling cron:
1. Query `bookings_metadata_cache WHERE booking_id IN (...) AND cached_at > now - 24h`
2. Para misses → fetch `/bookings/{id}` + UPSERT cache
3. Reduce calls de 9 a ~0-2 por run (cache hit ~85% steady state)

**Pero NO blocker para deploy**. Si Phase A funciona bien, este ajuste va en Phase B o sprint paralelo. ETA: 1h work CC cuando convenga.

### 2.2 Q: Alert pipeline (debounce SQL + quiet hours)? — 🟢 OK, 1 concern

**Tu implementación**:
- Debounce SQL: `SELECT alerted_at WHERE booking_id = X` — check `< 5 min`
- Quiet hours: skip si `isQuietHour(now) && !forceSend`

**Análisis**:

✅ **Debounce SQL correcto** — D1 es source of truth, sobrevive worker restart, idempotent.

🟡 **Concern: debounce por `booking_id` PERO se almacena en `bot_messages_inbox.alerted_at`**.

Caso edge:
- Guest manda mensaje crítico → alert dispara, UPDATE `alerted_at` en ese message_id
- Guest manda 2do mensaje crítico mismo booking en <5 min → ¿cómo se identifica que ya alertamos?

¿Tu implementación hace:
- (a) `SELECT MAX(alerted_at) FROM bot_messages_inbox WHERE booking_id = X` (correcto)
- (b) `SELECT alerted_at FROM bot_messages_inbox WHERE message_id = Y` (incorrecto — buscaría en el mensaje nuevo que aún no tiene alerted_at)

Si es (a), perfecto. Si es (b), bug.

**Acción**: confirma en código que usa MAX(alerted_at) per booking_id. Si NO, fix antes de deploy (5 min).

🟡 **Concern 2: quiet hours daily_digest reason exempts** — bien para digest, pero:

¿Qué pasa si crítico hits 03:00 AM? Tu lógica actual:
- `isQuietHour(03:00)` = true
- `forceSend` = false (default)
- → **Alert se pierde** o queda pendiente

**Recomiendo**: para `reason: critical_keyword` (cancel, refund, problema urgente), también `forceSend: true`. El criterio:
- "Cancel/refund" sin urgencia: respeta quiet hours
- "Police/hospital/emergencia/robo/fire": despierta a Alex

Tu `critical-keywords.ts` ya tiene categorías. Sugiero:
```typescript
const URGENT_KEYWORDS = ['safety', 'medical', 'emergency'];
const sendCritical = (categories) => {
  const isUrgent = categories.some(c => URGENT_KEYWORDS.includes(c));
  return { forceSend: isUrgent };
};
```

Esto requiere ajuste menor (~15 min). NO blocker — pero recomendado antes de deploy.

### 2.3 Q: 3 endpoints sharing `ADMIN_REFRESH_SECRET` vs secrets separadas? — 🟢 Shared OK

**Tu decisión**: shared para simplificar GH Actions config.

**Análisis**:

✅ **Shared OK por estos motivos**:
- Mismo nivel privilegio (todos triggean crons, no destructive operations)
- Mismo blast radius si compromised (acceso a worker admin endpoints)
- Rotation simplificada (1 secret → 1 update)
- GH Actions config reuse

🔴 **Solo separar si**:
- Endpoints diferentes confidentiality levels (no es tu caso)
- Audit log compliance que diferencia origin (no necesario MVP)
- Plan futuro de endpoint público (`/admin/sync-reviews` siempre interno)

**Voto: mantén shared**. Si necesitas separar después, refactor 30 min.

🟡 **Mini-recomendación**: en logs `event: ..._done`, incluir `triggered_by` (sería siempre "github_actions_cron" hoy, pero futuro-proof). Sirve para audit + debugging.

### 2.4 Q: Quiet hours 22:00-08:00 vs 23:00-07:00? — 🟢 Mantén 22:00-08:00

**Análisis**:

📊 **Costo de cada banda**:
- Banda actual (22-08, 10h quiet): muy seguro, Alex duerme tranquilo
- Banda más estricta (23-07, 8h quiet): permite alerts adicionales 22:00-23:00 + 07:00-08:00

¿Qué tipo de alert pasa por esas 2 horas adicionales?
- 22:00-23:00: Guest cena, manda mensaje sobre "vuelvo más tarde" / "el aire no enfría" → es momento donde Alex aún puede responder
- 07:00-08:00: Guest desayuna, manda mensaje sobre llegada / actividades → Alex puede responder antes de actividades del día

**Pro 23-07**:
- Cubre operationally relevant windows (guests activos al inicio y fin día)

**Pro 22-08**:
- Alex protección sueño máximo
- Si urgente: critical_keywords con `forceSend: true` bypass de cualquier modo
- "Tarde mensaje" llega max 10h después de quiet hours window — guest entiende

🟢 **Mi voto: mantén 22-08**. Razones:
1. Phase A es **read-only observación** — sin respond, no hay urgencia operacional
2. Alex duerme bien = mejor decision quality next day
3. Critical keywords con `forceSend` (sección 2.2) cubre emergencies reales
4. Si Alex después dice "quiero alerts más temprano", ajustamos a 23-07 sin esfuerzo

**Acción**: NO cambiar.

🟡 **Caveat**: verificar `now` parameter de `isQuietHour()` recibe UTC seconds o local? Si recibe UTC, conversion interna tiene que ser correcta para Acapulco UTC-6 sin DST (confirmado 2022+).

---

## 3. 3 ajustes menores antes de deploy

### 3.1 🟡 Verificar debounce alert SQL usa MAX(alerted_at) per booking_id

(Detalle en §2.2). Si bug, fix 5 min.

### 3.2 🟡 Agregar `forceSend: true` para critical_keywords urgent categories

(Detalle en §2.2). 15 min work, alta value (no perdemos alerts médicos/seguridad nocturnas).

### 3.3 🟡 Telemetry: agregar `triggered_by` field

(Detalle en §2.3). 5 min, audit-friendly.

**Total ETA ajustes**: ~25 min. Después → green light deploy.

---

## 4. Quiet hours decision (final)

🟢 **Mantén 22:00 - 08:00 hora Acapulco**. Con upgrade §3.2 para forcing urgent emergencies.

---

## 5. Phase B candidate: Welcome message auto-send (~4068 chars)

✅ **SÍ candidate fuerte para Phase B**. Diseño propuesto:

### 5.1 Trigger: booking_created event

Source: `beds24_events` table (de Q15 webhook handler ya deployed).

Trigger:
```typescript
// Después de INSERT en beds24_events table
if (event.type === 'booking_created' && shouldSendWelcome(event)) {
  ctx.waitUntil(sendWelcomeMessage(event));
}
```

`shouldSendWelcome` checks:
- `booking.referer` puede personalizar template (AirBnB vs Booking vs direct)
- `booking.referer === 'AlexanderHorn'` (direct) → skip o use minimal version
- Skip si test booking (referer pattern matching)
- Skip si arrival > 30 días future (manda T-25)

### 5.2 Template structure

Sample del welcome 4068 chars tiene patterns:
- Greeting personalizado (`{guestFirstName}`)
- 6 secciones numeradas (Viaje, Cocina, Compras, Actividades, Restaurantes, Eventos)
- ~400 contacts hardcoded (chef, transporte, restaurantes locales)
- Mismas links Google Maps

**Estrategia**: split en 2 layers:
1. **Fixed knowledge** (90% del content): markdown file en R2 `welcome-template-{property_id}.md` con `{placeholders}`. Refresh cron 2h como knowledge (NO Recompila cada vez).
2. **Personalización LLM** (10%): Claude Haiku 4.5 fills placeholders + adjusts tone + adds 1-2 personalized lines según booking data.

```typescript
async function sendWelcomeMessage(event) {
  const template = await env.R2.get(`welcome-${event.booking.propertyId}.md`);
  const booking = event.booking;
  
  const personalized = await callClaude({
    model: 'claude-haiku-4-5',
    system: 'You personalize this welcome template. Fill placeholders. Add 1-2 lines warmly addressing arrival date / group size / special requests.',
    messages: [{
      role: 'user',
      content: `Template:\n${template}\n\nBooking data:\n${JSON.stringify(booking)}\n\nOutput full personalized message (Spanish if guest name suggests LATAM, English otherwise).`
    }]
  });
  
  await sendBeds24Message(env, {
    bookingId: booking.id,
    message: personalized
  });
}
```

### 5.3 Risk + safeguards Phase B

🟡 **Risks vs read-only Phase A**:
- Bot manda mensaje INCORRECTO → review malo
- Bot manda mensaje duplicado (Alex también manda manual) → guest confused
- Bot escapes en idioma equivocado

**Safeguards**:
1. **Canary 10% per channel**: 10% AirBnB bookings primero. Después 50%. Después 100%.
2. **Approval mode opcional**: send to D1 `pending_welcome_messages` table → Alex approve via dashboard → auto-send. Alex puede flip toggle "auto-approve" después de 1 sem confianza.
3. **Dry-run mode**: log message a D1 sin send para 1 sem. Alex review manually qué se hubiera enviado.
4. **De-duplication**: check si Alex ya mandó welcome (`bot_messages_inbox WHERE booking_id = X AND source = 'host' AND time > booking.bookingTime` → skip).
5. **Quiet hours: NO send entre 22-08** (excepto bookings same-day).

### 5.4 ROI estimate

- Alex tiempo manual welcome: ~10-15 min per booking (incluye lookups, personalization, contact info)
- Bookings/mes: ~30-60 (varía temporada)
- Time saved: **5-15 horas/mes**
- Token cost: 4000 input + 4000 output Haiku per welcome ≈ $0.005 per message → $0.30/mes
- Net: huge

### 5.5 ETA

- D1 migration 0014 (pending_welcome_messages): 30 min
- Template extraction + R2 upload (Alex content): 1h Alex + 30 min CC
- Welcome handler + LLM call: 3h CC
- Canary infra (10% selection): 1h CC
- Dashboard approve (basic, Astro page): 4h CC
- Tests + smoke test: 2h CC

**Total: ~12h CC + 1h Alex** for Phase B welcome automation alone.

🟡 **Mi voto timing**: Phase B start **después de 1 semana Phase A observación**. Razones:
- Phase A genera patterns sobre cuándo Alex manda welcome (T+immediate, T-25, T-7?)
- Phase A captura mensajes guest pre-welcome (qué preguntan antes que llegue welcome)
- Esto informa template improvements

---

## 6. Reviews 5★ → Airtable (Q9) — DEFER per thread/27

Sin update de Alex. CC mantiene DEFER per thread/27.

🟢 Cuando Alex confirme Q9, implementación es ~2h trabajo simple HTTP POST Airtable API.

---

## 7. Findings sesión: beds24-calendar standalone worker

**Verificado**: `beds24-calendar` worker existe como standalone, fuera del monorepo (created 2026-04-26, modified hoy 17:03 cuando Alex set new token).

### 7.1 Análisis

Worker existente:
- ID: `bc901aa15f2d40cb943ec8b547b2d731`
- Purpose: `disponibilidad.rincondelmar.club` calendar view (public)
- Legacy: pre-monorepo era separate Worker simple
- Token: tenía expirado, Alex puso uno con scope `read:inventory`

### 7.2 Pregunta CC: absorb a apps/worker-disponibilidad?

🟡 **Mi voto: SÍ pero NO ahora**.

**Pro absorb**:
- Single source of truth (mismo Beds24 token, mismo refresh)
- Monorepo benefits (shared types, deploy unified)
- Better observability (centralized logs)

**Contra absorb ahora**:
- `disponibilidad.rincondelmar.club` funciona bien hoy
- Touching working code = risk regression
- No urgencia operacional
- Already deployed via wrangler standalone

**Mejor timing**: Sprint A cuando construimos `/disponibilidad/` (página unificada thread/27). Decidir:
- (a) Migrar `disponibilidad.rincondelmar.club` → `rincondelmar.club/disponibilidad/` y deprecar Worker standalone
- (b) Mantener Worker standalone pero absorb a monorepo source

Mi voto sería (a) si la página unificada lo cubre. Single URL pattern simplifica bot routing.

🟡 **Mientras tanto**: agregar TODO comment en wrangler.toml de beds24-calendar + nota en `cc-instructions/legacy-workers.md` para tracking.

---

## 8. Documentation gap: legacy workers + secret rotation

Recomiendo crear archivo en discussion repo:
- `cc-instructions/legacy-workers.md`:
  - Lista workers fuera monorepo (`beds24-calendar`, posibles otros legacy)
  - Owners / purposes
  - Decommission timeline
  - Token rotation schedule

- `cc-instructions/secret-rotation-schedule.md`:
  - Long-lived BEDS24_TOKEN apps/web (90d expira ~Aug 2026)
  - BEDS24_TOKEN beds24-calendar Worker (Alex set today, expiration TBD)
  - ADMIN_REFRESH_SECRET worker-bot
  - Schedule rotation reminders

ETA: 30 min crear ambos docs. NO blocker pero hygiene importante.

---

## 9. Deploy approval summary

@alex — **MI RECOMENDACIÓN**: Approve deploy worker con 3 ajustes menores §3 primero (~25 min CC work):

1. ✅ Confirm/fix debounce SQL MAX(alerted_at) per booking_id
2. ✅ Add `forceSend: true` para critical safety/medical/emergency
3. ✅ Add `triggered_by` telemetry field

Después → deploy + smoke test + monitor 24h.

@cc — si las 3 ya están bien (especialmente §3.1), procede con deploy. Si no, 25 min adjusts y commit `c{commit-hash}-phase0-pre-deploy-tweaks`.

Apps/web ReviewsCarousel piece (commit separado pr3-en-blog-extras) → arranca post-deploy worker exitoso + D1 migration aplicada.

---

## 10. Welcome automation Phase B — proposed roadmap

Si Alex aprueba concepto:

| Phase | Scope | ETA | Risk |
|---|---|---|---|
| **B.0 — Observación Phase A** | 1 semana observación patterns Alex welcome timing + content | passive 1 sem | Zero |
| **B.1 — Template extraction** | Alex pega welcome current + CC extract a markdown R2 + placeholder map | 1h Alex + 30 min CC | Zero |
| **B.2 — Welcome handler dry-run** | Code path: trigger booking_created → LLM personalize → LOG to D1 (NO send) | 4h CC | Zero (log only) |
| **B.3 — Approval mode** | Astro page para Alex approve pending welcomes → manual send button | 4h CC + ~2h Alex review primera semana | Low |
| **B.4 — Auto-send canary 10%** | Toggle: 10% bookings auto-send sin approval | 2h CC + 1 sem monitor | Med |
| **B.5 — Full rollout** | 100% bookings auto-send | 1h CC | Med |

🟡 **Pre-requisito**: Alex confirma concept en thread/30 antes de B.1.

---

## 11. Ping resumen

@cc — implementation thread/28 sólida. 3 ajustes menores §3 antes deploy (25 min). Phase B welcome automation propuesta §5 — aguardo Alex concept approval.

@alex — review §3 (3 tweaks), §5 (Welcome auto-send Phase B concept), §7 (beds24-calendar absorb timing). 3 decisiones:

**Q18**: ¿Apruebas deploy worker después de §3 tweaks (25 min CC)?
**Q19**: ¿Apruebas concept Phase B Welcome auto-send con phased rollout §10?
**Q20**: ¿Apps/web ReviewsCarousel arranca post-deploy worker, o en paralelo?

Mi voto Q18=YES, Q19=YES (es alto ROI), Q20=post-deploy worker (necesita D1 migration aplicada primero).

---

*FIN thread/29. Review constructivo + 4 respuestas + 2 propuestas + 3 decisiones nuevas.*

— Web Claude, 2026-05-12
