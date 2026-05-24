---
thread: 200
author: wc
topic: inbox-bug-2-conversation-endpoint-polymorphic
status: ready-for-execution
mode: DoIt
created: 2026-05-24
related_threads: [196, 197, 198, 199]
related_prs: [167, 169, 170]
estimated_effort: 75-90min CC (1 session, backend-only)
pipeline: single-CC
requires_worker_bot_deploy: YES (manual `npx wrangler deploy` after merge)
---

# Thread 200 — Inbox bug 2: conversation endpoint polimórfico (booking + lead + legacy)

## §0. TL;DR

**Bug 2:** Click en cualquier row del inbox da modal "not_found". Root cause: `handleConversationGet` recibe rawId `b_86656062` (Claudia Becerra con 24 messages en `bot_messages_inbox`), hace `WHERE subscriber_id = ?` contra `conversations` table → 404 garantizado. **Nunca llega a consultar `bot_messages_inbox`** que ES donde están los mensajes AirBnB.

**Pero la query ya EXISTE** en `conversation.ts` líneas 200-218:
```ts
`SELECT message_id, booking_id, source, channel, message_text, message_time, read_flag
 FROM bot_messages_inbox WHERE booking_id = ?
 ORDER BY message_time ASC LIMIT 200`
```

Solo está después del 404. Fix = **refactor flow polimórfico**: detectar prefix `b_` / `conv_` / raw, ramificar al lookup correcto.

**Backend-only fix.** Frontend (`InboxApp.tsx` handleRowClick + `ConversationView.tsx` rawId passing) NO cambia.

---

## §1. Context — la arquitectura real de mensajes

### 1.1 Dos pipelines paralelos (descubierto vía D1 queries)

```
┌──────────────────────────────────────┬──────────────────────────────────────┐
│  WhatsApp directo                    │  AirBnB / Booking.com                │
├──────────────────────────────────────┼──────────────────────────────────────┤
│  Lead escribe WA al bot              │  Guest reserva AirBnB                │
│      ↓                               │  Beds24 pushea messages              │
│  Bot crea conversations row          │  client-bot-polling.ts cron          │
│  (subscriber_id = phone E.164)       │  GET /v2/bookings/messages           │
│      ↓                               │      ↓                                │
│  history text blob (USER:/ASSISTANT:)│  INSERT bot_messages_inbox           │
│                                      │  (booking_id, source, channel,       │
│                                      │   message_text, message_time)        │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

### 1.2 Stats reales en producción (queries D1 2026-05-24)

```
conversations:        205 total (todas phone E.164 sin "+")
bot_messages_inbox:   476 messages across 66 unique bookings
guests-conv match:    4 de 205 conv tienen guest record (1.9%)
bookings activos:     75 (sin Casa Chamán)
  with conv linked:   0   ← desacople estructural
  with OTA messages:  ~60 (todos AirBnB bookings)
```

### 1.3 Sample real

```
booking 86656062 (Claudia Becerra, AirBnB, room 637063 Huerta Cocotera):
  - bot_messages_inbox: 24 messages (guest + host alternados)
  - conversations:      NO MATCH (phone AirBnB ≠ phone WhatsApp guest)
  - Click row → ConversationView → backend 404 ❌
  - Karina pierde acceso visual a esos 24 messages
```

### 1.4 Lo que el código YA tiene

`apps/worker-bot/src/api/admin/conversation.ts` líneas 175-218:

```ts
// Step 1: Lookup conv (returns 404 si no existe)
const conv = await env.DB.prepare(
  `SELECT ... FROM conversations WHERE subscriber_id = ?`
).bind(convId).first();
if (!conv) return c.json({ ok: false, error: 'not_found' }, 404);  // ❌ EXITS HERE

// Step 2: Lookup booking via guest.phone_e164 (NEVER REACHED si conv no existe)
// Step 3: Lookup bot_messages_inbox (NEVER REACHED)
// Step 4: Merge messages (NEVER REACHED)
```

**El flow está construido para el caso "conv existe primero" — no para el caso "booking existe pero no conv".**

### 1.5 Aggregate IDs (de aggregate.ts confirmed)

```ts
// Bookings:
rows.push({ id: `b_${br.beds24_booking_id}`, ... });

// Leads:
leadRows.push({ id: `conv_${conv.subscriber_id}`, ... });
```

Frontend `InboxRow → InboxApp.handleRowClick → setOpenConvId(rawId)` pasa el ID con prefix al backend. Backend recibe `b_86656062` y rompe.

---

## §2. Explicit scope

### 2.1 IN scope (backend-only)

| Archivo | Cambio | LoC aprox |
|---|---|---|
| `apps/worker-bot/src/api/admin/conversation.ts` | Refactor: `resolveConvContext()` helper + split `handleConversationGet` into `handleBookingConversation` + `handleWhatsAppConversation`. Apply helper en TODOS los handlers (`Reply`, `SuggestReply`, `PauseBot`, `Snooze`, `Resolve`) | +180 |
| `apps/worker-bot/tests/api/admin/conversation.test.ts` | Tests nuevos: `b_XXX` path → bot_messages_inbox + booking context. `conv_XXX` path → strip + history. Raw subscriber → legacy. Edge cases. | +120 |

### 2.2 OUT of scope (NO tocar)

- ❌ **Frontend** — `InboxApp.tsx`, `ConversationView.tsx`, `inbox-client.ts` NO cambian. El rawId polimórfico llega al backend y backend lo resuelve.
- ❌ **`drafts.ts`** — `inbox_drafts.conv_id` es opaque storage (key = rawId concatenated). No requiere cambio.
- ❌ **`aggregate.ts`** — los IDs `b_XXX` / `conv_XXX` son por diseño, no cambian.
- ❌ **`bot_messages_inbox` schema** — read-only para este endpoint.
- ❌ **`conversations.beds24_booking_id` column** — propuesta data model future (thread separado post-foundations).
- ❌ **`computeReadiness` in-stay logic** — bug 6, separado thread/201.
- ❌ **Casa Chamán** — todos los lookups filtran `room_id != 679176`.
- ❌ **Database migrations** — no se requieren.

---

## §3. Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Refactor backend-only. Frontend rawId polimórfico se mantiene. | Single source of truth backend. Frontend no necesita conocer el data model. |
| D2 | 3 paths: `b_XXX` (booking) / `conv_XXX` (lead) / raw (legacy) | Match el universo real. Legacy support para `/admin/conv` (sistema viejo). |
| D3 | Path A (booking): query `bot_messages_inbox` PRIMARY source, `conversations` SECONDARY si hay phone match | OTA messages son la verdad para bookings AirBnB. WA history complementario si existe. |
| D4 | Path B (lead): strip `conv_` prefix, query `conversations` como hoy | Sin cambios al flow lead que sí funciona. |
| D5 | Path C (legacy raw): passthrough sin transform | Backward compat con `/admin/conv` sistema viejo |
| D6 | Merge OTA + WA messages ordenados por `sent_at` | Karina ve historia unificada cuando aplica |
| D7 | Booking sin OTA messages Y sin WA conv → response válida con `messages: []` + booking context | Mejor que 404. UX claro: "Sin mensajes aún" + booking sidebar |
| D8 | `handleConversationReply` para booking AirBnB → route via `beds24_booking_id` (Messenger Beds24) | Reply en AirBnB usa el endpoint Beds24, NO ManyChat |
| D9 | `handleConversationReply` para lead WA → route via `subscriber_id` (ManyChat) | Sin cambio |
| D10 | `handlePauseBot/Snooze/Resolve` para booking-only (sin WA conv) → no-op + return success | No hay row de conversations que pausar/resolver. UX no-error. |
| D11 | `handleSuggestReply` para booking-only sin WA → return skip_reason: 'no_history' | Sin history WA no hay context para LLM. AirBnB messages OTA solas no aplican (otro pipeline). |
| D12 | Filtrar `room_id != 679176` (Casa Chamán) en TODOS los lookups de bookings | Anti-pattern obligatorio. |
| D13 | `resolveConvContext` helper retorna estructura tipada, no booleanos sueltos | Defensiveness + testability |
| D14 | Tests deben cubrir 6 scenarios mínimo: booking con OTA+WA / booking con OTA solo / booking sin nada / lead con conv / lead sin conv (debería 404) / legacy raw | Coverage del polimorfismo |
| D15 | Reusar query existente `SELECT FROM bot_messages_inbox WHERE booking_id = ?` (líneas 200-218 actuales) | No reinventar |

---

## §4. Implementation

### 4.1 Helper `resolveConvContext()` — nuevo, top del archivo

```ts
interface ConvContext {
  type: 'booking' | 'lead' | 'legacy';
  bookingId: number | null;
  subscriberId: string | null;  // phone normalizado si hay WA conv linked, null si no
  bookingRow: BookingRow | null;
  hasWaConversation: boolean;
}

async function resolveConvContext(env: Env, rawId: string): Promise<ConvContext | null> {
  // ── Path A: booking (b_XXX) ──
  if (rawId.startsWith('b_')) {
    const bookingId = Number(rawId.slice(2));
    if (!Number.isFinite(bookingId) || bookingId <= 0) return null;

    const booking = await env.DB.prepare(
      `SELECT bb.beds24_booking_id, bb.room_id, bb.arrival, bb.departure,
              bb.num_adults, bb.num_pets, bb.total_amount_mxn, bb.deposit_paid,
              bb.balance_due_mxn, bb.channel,
              g.phone_e164 as guest_phone,
              bc.mascotas_confirmed, bc.mascotas_count, bc.menu_status,
              bc.compras_confirmed, bc.morenas_svc_confirmed
       FROM beds24_bookings bb
       LEFT JOIN guests g ON g.id = bb.guest_id
       LEFT JOIN booking_captures bc ON bc.beds24_booking_id = bb.beds24_booking_id
       WHERE bb.beds24_booking_id = ?
         AND bb.room_id != 679176`,
    )
      .bind(bookingId)
      .first<BookingRow & { guest_phone: string | null }>()
      .catch(() => null);

    if (!booking) return null;

    // Check if a conversation matches by phone (optional)
    let subscriberId: string | null = null;
    let hasWa = false;
    if (booking.guest_phone) {
      const phoneNormalized = booking.guest_phone.replace('+', '');
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
    }

    return {
      type: 'booking',
      bookingId,
      subscriberId,
      bookingRow: booking,
      hasWaConversation: hasWa,
    };
  }

  // ── Path B: lead (conv_XXX) ──
  if (rawId.startsWith('conv_')) {
    const subscriberId = rawId.slice(5);
    return {
      type: 'lead',
      bookingId: null,
      subscriberId,
      bookingRow: null,
      hasWaConversation: true,  // assumed; handler verifies
    };
  }

  // ── Path C: legacy raw subscriber_id ──
  return {
    type: 'legacy',
    bookingId: null,
    subscriberId: rawId,
    bookingRow: null,
    hasWaConversation: true,
  };
}
```

### 4.2 `handleConversationGet` — refactor

```ts
export async function handleConversationGet(c: Context<{ Bindings: Env }>): Promise<Response> {
  const rawId = c.req.param('id') ?? '';
  const env = c.env;

  const ctx = await resolveConvContext(env, rawId);
  if (!ctx) return c.json({ ok: false, error: 'not_found' }, 404);

  // ── Load WA history if applicable ──
  let conv: ConvRow | null = null;
  if (ctx.subscriberId) {
    conv = await env.DB.prepare(
      `SELECT subscriber_id, history, last_active, bot_paused_until, resolved_at
       FROM conversations WHERE subscriber_id = ?`,
    )
      .bind(ctx.subscriberId)
      .first<ConvRow>()
      .catch(() => null);
  }

  // ── Lead path: conv MUST exist ──
  if (ctx.type === 'lead' && !conv) {
    return c.json({ ok: false, error: 'not_found' }, 404);
  }

  // ── Assemble WA history messages ──
  const historyMsgs = conv ? parseHistoryToMessages(conv.history, ctx.subscriberId!) : [];

  // ── Assemble OTA messages (only for booking path with bookingId) ──
  let otaMsgs: Array<{...}> = [];
  if (ctx.bookingId) {
    const { results: beds24Msgs } = await env.DB.prepare(
      `SELECT message_id, booking_id, source, channel, message_text, message_time, read_flag
       FROM bot_messages_inbox WHERE booking_id = ?
       ORDER BY message_time ASC LIMIT 200`,
    )
      .bind(ctx.bookingId)
      .all<Beds24InboxRow>();

    otaMsgs = beds24Msgs.map((m) => ({
      id: `ota_${m.message_id}`,
      channel: (m.channel === 'airbnb' ? 'airbnb' : 'booking') as 'airbnb' | 'booking',
      direction: (m.source === 'guest' ? 'inbound' : 'outbound') as 'inbound' | 'outbound',
      sent_by: m.source === 'guest' ? ('guest' as const) : ('bot' as const),
      text: m.message_text,
      sent_at: new Date(m.message_time * 1000).toISOString(),
      external_id: String(m.message_id),
    }));
  }

  // ── Merge + sort ──
  const allMessages = [...historyMsgs, ...otaMsgs].sort(
    (a, b) => new Date(a.sent_at).getTime() - new Date(b.sent_at).getTime(),
  );

  // ── Build booking context (if bookingRow exists) ──
  let bookingContext = null;
  if (ctx.bookingRow) {
    const readiness = computeReadiness(
      {
        num_adults: ctx.bookingRow.num_adults,
        num_pets: ctx.bookingRow.num_pets,
        total_amount_mxn: ctx.bookingRow.total_amount_mxn,
        deposit_paid: ctx.bookingRow.deposit_paid,
        balance_due_mxn: ctx.bookingRow.balance_due_mxn,
        arrival: ctx.bookingRow.arrival,
        departure: ctx.bookingRow.departure,
        room_id: ctx.bookingRow.room_id,
      },
      {
        mascotas_confirmed: ctx.bookingRow.mascotas_confirmed,
        mascotas_count: ctx.bookingRow.mascotas_count,
        menu_status: ctx.bookingRow.menu_status,
        compras_confirmed: ctx.bookingRow.compras_confirmed,
        morenas_svc_confirmed: ctx.bookingRow.morenas_svc_confirmed,
      },
      conv?.history ?? '',
    );

    bookingContext = {
      beds24_booking_id: ctx.bookingRow.beds24_booking_id,
      property: PROPERTY_NAMES[ctx.bookingRow.room_id]
        ? { roomId: ctx.bookingRow.room_id, name: PROPERTY_NAMES[ctx.bookingRow.room_id] }
        : null,
      check_in: ctx.bookingRow.arrival,
      check_out: ctx.bookingRow.departure,
      pax: ctx.bookingRow.num_adults,
      has_pet: ctx.bookingRow.num_pets > 0,
      services: [
        ctx.bookingRow.mascotas_confirmed ? 'mascotas' : null,
        ctx.bookingRow.morenas_svc_confirmed ? 'cocinera' : null,
      ].filter(Boolean),
      readiness,
      total_amount_mxn: ctx.bookingRow.total_amount_mxn,
      paid_amount_mxn: ctx.bookingRow.deposit_paid ? ctx.bookingRow.total_amount_mxn : 0,
      channel: ctx.bookingRow.channel,
    };
  }

  // ── Load audit trail (keyed by rawId, opaque) ──
  const { results: auditRows } = await env.DB.prepare(
    `SELECT id, kind, payload_json, created_at FROM audit_log
     WHERE kind LIKE 'inbox_%' AND json_extract(payload_json, '$.conv_id') = ?
     ORDER BY created_at DESC LIMIT 50`,
  )
    .bind(rawId)
    .all<AuditRow>()
    .catch(() => ({ results: [] as AuditRow[] }));

  const auditTrail = auditRows.map((row) => {
    let payload: Record<string, unknown> = {};
    try { payload = JSON.parse(row.payload_json); } catch { void 0; }
    return {
      at: new Date(row.created_at * 1000).toISOString(),
      actor: (payload.actor as string) ?? 'system',
      action: row.kind.replace('inbox_', '') as string,
      detail: (payload.detail as string) ?? row.kind,
    };
  });

  const detectedLang = conv ? detectLangFromHistory(conv.history) : 'es';

  return c.json({
    ok: true,
    conversation: {
      id: rawId,
      subscriber: {
        id: ctx.subscriberId ?? rawId,
        name: ctx.bookingRow ? `Booking ${ctx.bookingId}` : (ctx.subscriberId ?? rawId),
        phone: ctx.subscriberId ?? '',
        detected_lang: detectedLang,
      },
      channels: ctx.bookingRow
        ? (['whatsapp', ctx.bookingRow.channel === 'airbnb' ? 'airbnb' : 'booking'] as string[])
        : ['whatsapp'],
      bot_paused_until: conv?.bot_paused_until ?? null,
      messages: allMessages,
    },
    booking: bookingContext,
    audit_trail: auditTrail,
  });
}
```

### 4.3 `handleConversationReply` — refactor

```ts
export async function handleConversationReply(c: Context<{ Bindings: Env }>): Promise<Response> {
  const rawId = c.req.param('id') ?? '';
  const userEmail = c.req.header('x-user-email') ?? 'unknown';
  const env = c.env;

  let body: { channel: string; text: string; ... };
  try { body = await c.req.json(); } catch { return c.json({ ok: false, error: 'invalid_json' }, 400); }

  if (!body.text || typeof body.text !== 'string') {
    return c.json({ ok: false, error: 'text_required' }, 400);
  }

  const ctx = await resolveConvContext(env, rawId);
  if (!ctx) return c.json({ ok: false, error: 'not_found' }, 404);

  // ── Determine routing target ──
  let routeConvId: string;
  if ((body.channel === 'airbnb' || body.channel === 'booking') && ctx.bookingId) {
    routeConvId = String(ctx.bookingId);  // Beds24 messenger
  } else if (ctx.subscriberId) {
    routeConvId = ctx.subscriberId;  // ManyChat WhatsApp
  } else {
    return c.json({ ok: false, error: 'no_route_available' }, 400);
  }

  const result = await sendMessageRouted(
    { DB: env.DB, ... },
    { conversation_id: routeConvId, text: body.text, sent_by_user: userEmail },
  );

  if (!result.ok) {
    return c.json({ ok: false, error: result.error ?? 'send_failed' }, 502);
  }

  // ── Auto-pause + auto-resolve only if WA conv exists ──
  let pauseUntil: string | null = null;
  if (ctx.subscriberId && ctx.hasWaConversation) {
    try {
      const pauseResult = await autoPauseBot({ DB: env.DB }, ctx.subscriberId, 'auto_post_reply');
      pauseUntil = pauseResult.bot_paused_until;
    } catch { void 0; }

    await env.DB.prepare(
      `UPDATE conversations SET resolved_at = unixepoch(), updated_at = unixepoch() WHERE subscriber_id = ?`,
    )
      .bind(ctx.subscriberId)
      .run()
      .catch(() => void 0);
  }

  if (body.used_quick_reply_id) {
    await handleQuickReplyUsed(env, body.used_quick_reply_id);
  }

  // ── Audit log keyed by rawId (opaque) ──
  await env.DB.prepare(
    `INSERT INTO audit_log (kind, payload_json, created_at) VALUES (?, ?, unixepoch())`,
  )
    .bind(
      'inbox_reply_sent',
      JSON.stringify({
        conv_id: rawId,
        actor: userEmail,
        detail: `Reply sent via ${result.routed_to}`,
        used_suggestion: body.used_suggestion ?? false,
        used_quick_reply_id: body.used_quick_reply_id ?? null,
      }),
    )
    .run()
    .catch(() => void 0);

  return c.json({
    ok: true,
    message_id: `msg_${Date.now()}`,
    external_id: result.external_message_id ?? null,
    bot_paused_until: pauseUntil ?? (ctx.hasWaConversation ? new Date(Date.now() + 3_600_000).toISOString() : null),
    auto_marked_responded: ctx.hasWaConversation,
  });
}
```

### 4.4 `handleSuggestReply` — guard

```ts
export async function handleSuggestReply(c: Context<{ Bindings: Env }>): Promise<Response> {
  const rawId = c.req.param('id') ?? '';
  const ctx = await resolveConvContext(c.env, rawId);
  if (!ctx) return c.json({ ok: false, skip_reason: 'not_found' });

  // Suggest requires WA history for LLM context
  if (!ctx.subscriberId || !ctx.hasWaConversation) {
    return c.json({ ok: false, skip_reason: 'no_wa_history' });
  }

  const conv = await c.env.DB.prepare(
    `SELECT last_active FROM conversations WHERE subscriber_id = ?`,
  )
    .bind(ctx.subscriberId)
    .first<{ last_active: number }>()
    .catch(() => null);

  if (!conv) return c.json({ ok: false, skip_reason: 'rate_limit' });

  const result = await suggestReply(ctx.subscriberId, conv.last_active, {
    DB: c.env.DB,
    ANTHROPIC_API_KEY: c.env.ANTHROPIC_API_KEY,
    KNOWLEDGE_BUCKET: c.env.KNOWLEDGE_BUCKET,
  });

  return c.json(result);
}
```

### 4.5 `handlePauseBot`, `handleSnooze`, `handleResolve` — guard

Pattern repetido para los 3:
```ts
const ctx = await resolveConvContext(c.env, rawId);
if (!ctx) return c.json({ ok: false, error: 'not_found' }, 404);

if (!ctx.subscriberId || !ctx.hasWaConversation) {
  // No-op + return success — no hay row de conversations que tocar
  return c.json({ ok: true, no_op: true, reason: 'no_wa_conversation' });
}

// Resto del flow existente, usando ctx.subscriberId en lugar de rawId
await c.env.DB.prepare(`UPDATE conversations SET ... WHERE subscriber_id = ?`)
  .bind(..., ctx.subscriberId).run();
```

---

## §5. Tests

Crear `apps/worker-bot/tests/api/admin/conversation.test.ts` (o append a existente):

### 5.1 resolveConvContext

```ts
describe('resolveConvContext', () => {
  it('resolves b_XXX prefix as booking type', async () => {
    const env = mockEnvWithBooking(86656062, { phone_e164: '+525516264567' });
    const ctx = await resolveConvContext(env, 'b_86656062');
    expect(ctx?.type).toBe('booking');
    expect(ctx?.bookingId).toBe(86656062);
    expect(ctx?.bookingRow).toBeTruthy();
  });

  it('detects matching WA conversation for booking', async () => {
    const env = mockEnvWithBookingAndConv(86656062, '+525516264567', '525516264567');
    const ctx = await resolveConvContext(env, 'b_86656062');
    expect(ctx?.subscriberId).toBe('525516264567');
    expect(ctx?.hasWaConversation).toBe(true);
  });

  it('returns null subscriberId for booking without matching WA conv', async () => {
    const env = mockEnvWithBookingNoConv(86656062);
    const ctx = await resolveConvContext(env, 'b_86656062');
    expect(ctx?.subscriberId).toBeNull();
    expect(ctx?.hasWaConversation).toBe(false);
  });

  it('strips conv_ prefix as lead type', async () => {
    const ctx = await resolveConvContext(mockEnv(), 'conv_525516264567');
    expect(ctx?.type).toBe('lead');
    expect(ctx?.subscriberId).toBe('525516264567');
  });

  it('passthrough raw subscriber as legacy', async () => {
    const ctx = await resolveConvContext(mockEnv(), '525516264567');
    expect(ctx?.type).toBe('legacy');
    expect(ctx?.subscriberId).toBe('525516264567');
  });

  it('returns null for invalid b_ format', async () => {
    expect(await resolveConvContext(mockEnv(), 'b_abc')).toBeNull();
    expect(await resolveConvContext(mockEnv(), 'b_0')).toBeNull();
  });

  it('filters out Casa Chamán bookings (room_id 679176)', async () => {
    const env = mockEnvWithBooking(86656062, { room_id: 679176 });
    const ctx = await resolveConvContext(env, 'b_86656062');
    expect(ctx).toBeNull();
  });
});
```

### 5.2 handleConversationGet — 6 scenarios

```ts
describe('handleConversationGet', () => {
  it('returns OTA messages for AirBnB booking with bot_messages_inbox rows', async () => {
    // Setup: booking 86656062 + 24 messages en bot_messages_inbox
    const res = await callGet('b_86656062');
    const data = await res.json();
    expect(res.status).toBe(200);
    expect(data.conversation.messages).toHaveLength(24);
    expect(data.conversation.messages[0].channel).toBe('airbnb');
    expect(data.booking.beds24_booking_id).toBe(86656062);
  });

  it('returns empty messages array for direct booking without OTA messages', async () => {
    const res = await callGet('b_86981862');  // Alex Horn direct booking, 0 messages
    const data = await res.json();
    expect(res.status).toBe(200);
    expect(data.conversation.messages).toHaveLength(0);
    expect(data.booking.channel).toBe('direct');
  });

  it('merges WA history + OTA messages sorted by sent_at when both exist', async () => {
    // Setup: booking 12345 + matching conversation (phone)
    const res = await callGet('b_12345');
    const data = await res.json();
    expect(data.conversation.messages.length).toBeGreaterThan(0);
    // Verify sort order
    const times = data.conversation.messages.map(m => new Date(m.sent_at).getTime());
    expect(times).toEqual([...times].sort((a, b) => a - b));
  });

  it('returns 404 for unknown booking_id', async () => {
    const res = await callGet('b_99999999');
    expect(res.status).toBe(404);
  });

  it('returns 404 for Casa Chamán booking', async () => {
    const res = await callGet('b_679176999');
    expect(res.status).toBe(404);
  });

  it('handles lead path (conv_XXX) with WA history', async () => {
    const res = await callGet('conv_525516264567');
    const data = await res.json();
    expect(res.status).toBe(200);
    expect(data.conversation.messages.length).toBeGreaterThan(0);
    expect(data.booking).toBeNull();
  });

  it('handles legacy raw subscriber_id', async () => {
    const res = await callGet('525516264567');
    const data = await res.json();
    expect(res.status).toBe(200);
  });
});
```

### 5.3 handleConversationReply

```ts
describe('handleConversationReply', () => {
  it('routes AirBnB reply via booking_id', async () => {
    const res = await callReply('b_86656062', { channel: 'airbnb', text: 'hola' });
    // Verify sendMessageRouted called with String(booking_id)
  });

  it('routes WA reply via subscriber_id (lead)', async () => {
    const res = await callReply('conv_525516264567', { channel: 'whatsapp', text: 'hola' });
    // Verify sendMessageRouted called with subscriber_id
  });

  it('returns error if booking-only and channel=whatsapp without subscriber', async () => {
    const res = await callReply('b_99999999', { channel: 'whatsapp', text: 'hola' });
    expect(res.status).toBe(400);
  });

  it('does NOT call autoPauseBot for booking without WA conv', async () => {
    // Verify no UPDATE conversations attempt
  });
});
```

### 5.4 handlePauseBot/Snooze/Resolve no-op

```ts
it('returns no_op for booking without WA conv', async () => {
  const res = await callPause('b_99999999', { until: 'indefinite', reason: 'manual_kari' });
  const data = await res.json();
  expect(data.ok).toBe(true);
  expect(data.no_op).toBe(true);
});
```

---

## §6. Definition of Done

- [ ] Branch `fix/inbox-conversation-endpoint-polymorphic` creada
- [ ] 2 archivos modificados:
  - `apps/worker-bot/src/api/admin/conversation.ts` (+180 LoC: resolveConvContext + refactor 6 handlers)
  - `apps/worker-bot/tests/api/admin/conversation.test.ts` (+120 LoC: new tests, file created if missing)
- [ ] `pnpm --filter worker-bot typecheck` PASS 0 errors nuevos
- [ ] `pnpm --filter worker-bot test` los tests nuevos pasan (mínimo 15 tests nuevos verdes)
- [ ] `git diff main --stat` muestra ~2 archivos, ~300 LoC total
- [ ] PR creada con título: `fix(inbox): conversation endpoint polimórfico — booking + lead + legacy (thread/200)`
- [ ] PR description menciona bug 2 resuelto, referencia thread/200, **explícitamente** indica REQUIRES MANUAL `npx wrangler deploy` post-merge para worker-bot
- [ ] Reporte al final con:
  - Resumen 6 handlers refactored
  - resolveConvContext helper agregado
  - Typecheck PASS
  - Tests pass count
  - PR URL
  - **⚠️ Recordatorio CRÍTICO: worker-bot deploy manual requerido**

---

## §7. Risks + Mitigations

| Risk | Mitigation |
|---|---|
| Tests existing en `conversation.test.ts` se rompen por refactor | Leer file primero. Si tests existen verifying old behavior (404 on `b_XXX`), reescribirlos al nuevo behavior. Si no existe el file, crearlo. |
| `sendMessageRouted` no acepta `String(booking_id)` para AirBnB | Verificar firma de `messenger-send.ts`. Si requiere transform, ajustar el llamado. Es código existente, no nuevo. |
| Audit log `conv_id` queries futuras con phone normalizado | Audit log se queda con rawId opaque. NO retroactive migration. Forward-only. |
| Performance: 4 queries en handleConversationGet vs 3 antes | Negligible — todas con indexes existentes. `idx_bot_messages_booking_time` ya creado migration 0034. |
| Edge case: booking sin guest record | `LEFT JOIN guests` retorna null phone. Handler skip WA conv check. OK. |
| Edge case: phone E.164 con formato inesperado | `replace('+', '')` es safe. Si null, skip lookup. |

---

## §8. Out-of-scope findings → issues

Si CC encuentra algo durante ejecución NO listado en §2.1:
- Abrir GitHub issue con prefix `[thread/200 OOS]`
- NO fixear inline
- Reportar en thread response

Ejemplos previsibles:
- `inbox_drafts.conv_id` query patterns que asumen format específico → DEFER thread/202 si aplica
- Front-end ConversationView render edge case con `messages: []` + booking context → DEFER
- TypeScript errors pre-existentes en otros archivos → IGNORE
- Bug 6 readiness in-stay → thread/201 (separado, en marcha)
- `conversations.beds24_booking_id` column propuesta → thread/202 post-foundations

---

## §9. Kickoff command (Alex pegará a CC)

```
DoIt thread/200: conversation endpoint polimórfico, 1 PR backend-only worker-bot.

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/200-wc-cc-conversation-endpoint-polymorphic.md

(Si no la tienes local, pull discussion repo:
cd c:/dev/rdm/dev/discussion && git pull origin main && cd c:/dev/rdm/dev/bot)

Sigue §4 implementation exacto. Self-review §6 DoD antes de commit.

Working directory: c:/dev/rdm/dev/bot

Pre-flight:
1. cd c:/dev/rdm/dev/bot
2. git status — debe estar clean en main
3. git pull origin main
4. git log --oneline -1 — confirma estás en último commit (incluye PR #170 merge)

Execution:
1. git checkout -b fix/inbox-conversation-endpoint-polymorphic
2. Leer apps/worker-bot/src/api/admin/conversation.ts entero (es el target del refactor)
3. Verificar si existe apps/worker-bot/tests/api/admin/conversation.test.ts — si existe leerlo, si no crearlo
4. Refactor conversation.ts según §4.1-4.5:
   - Add resolveConvContext helper (top del archivo)
   - Refactor handleConversationGet con polymorphic logic + bot_messages_inbox lookup
   - Refactor handleConversationReply con routing inteligente AirBnB/WA
   - Refactor handleSuggestReply con skip_reason: no_wa_history guard
   - Refactor handlePauseBot/Snooze/Resolve con no_op guard
5. Add tests según §5.1-5.4 (minimo 15 tests nuevos)
6. pnpm --filter worker-bot typecheck — must PASS 0 errors nuevos
7. pnpm --filter worker-bot test — tests nuevos pasan
8. git diff main --stat — verifica ~2 archivos
9. git add (solo conversation.ts + conversation.test.ts)
10. git commit -m "fix(inbox): conversation endpoint polimórfico — booking + lead + legacy (thread/200)"
11. git push -u origin fix/inbox-conversation-endpoint-polymorphic
12. gh pr create con title "fix(inbox): conversation endpoint polimórfico — booking + lead + legacy (thread/200)" y body con referencia thread/200, bug 2 resuelto, ⚠️ MANUAL `npx wrangler deploy` REQUIRED post-merge para worker-bot

Scope ESTRICTO: backend-only worker-bot.
- apps/worker-bot/src/api/admin/conversation.ts
- apps/worker-bot/tests/api/admin/conversation.test.ts

NO ejecutes:
- pnpm test completo (rompen pre-existentes)
- npx wrangler deploy (Alex lo hace manual post-merge)
- Frontend changes (apps/web/**)
- Backend changes a otros archivos (aggregate.ts, drafts.ts, readiness.ts, inbox/*.ts)
- Database migrations
- Force-push, branch delete

Si encuentras algo fuera de scope → issue GitHub con prefix [thread/200 OOS].

Bloqueado >30 min en sub-tarea = STOP y reporta.

Reportar al final con:
- 6 handlers refactored + resolveConvContext helper
- Typecheck PASS
- Tests pass count
- PR URL
- ⚠️ CRÍTICO: recordar a Alex que worker-bot deploy manual es necesario

GO.
```

---

## §10. References

- thread/196: Inbox redesign megaspec
- thread/198: Hotfix CORS + roomIds (PR #169 merged)
- thread/199: Display fields + CSS + readiness compact (PR #170 merged)
- thread/201: Bug 6 readiness in-stay (paralelo, redactando ahora)
- thread/202 (futuro): `conversations.beds24_booking_id` column + flow update post-foundations
- D1 query investigation 2026-05-24: 0/75 bookings activos linked a conversations; 476 OTA messages en bot_messages_inbox; pipeline AirBnB vs WhatsApp desacoplado
- `bot_messages_inbox`: migration 0013, populated by `client-bot-polling.ts` cron 5min
- Index: `idx_bot_messages_booking_time` migration 0034
- Worker-bot deploy gotcha: memoria #27 — manual `npx wrangler deploy` requerido
