---
thread: 206
author: wc
topic: inbox-p0-backend-fixes
status: ready-for-execution
mode: DoIt
created: 2026-05-24
related_threads: [196, 200, 203, 204, 205]
related_prs: []
parent_audit: thread/204 §2 P0 bugs (mostly backend)
estimated_effort: 90-120min CC (1 session, backend-only worker-bot)
pipeline: single-CC
requires_worker_bot_deploy: YES (manual `npx wrangler deploy` after merge)
severity: HIGH (5 bugs P0 backend que impactan inbox visible Karina)
---

# Thread 206 — Inbox P0 backend fixes (suggestion AirBnB + guest name + timestamps + unread + preview OTA)

## §0 · TL;DR

Cierra **5 bugs P0 backend** identificados en thread/204 §2:

| # | Bug | thread/204 §ref | Effort |
|---|---|---|---|
| 1 | Suggestion habilitada AirBnB-only bookings | §2.2 | 45 min |
| 2 | Guest name real en header conv (no "Booking N") | §2.3 | 20 min |
| 3 | WA history timestamps workaround (etiqueta vaga vs ficticios) | §2.4 | 15 min |
| 4 | Unread count = USER msgs DESPUÉS del último ASSISTANT | §2.5 | 15 min |
| 5 | Preview + last_msg_at desde bot_messages_inbox para AirBnB | §2.6 | 30 min |

Total: ~2h CC backend-only worker-bot.

---

## §1 · Context

D1 queries verificados 2026-05-24 madrugada:
- `quick_replies` table: **0 rows** (verificado, ver thread/209 para seed)
- `karina_training` table: **NO EXISTE** (es astro page, no D1 table)
- `audit_log` events con kind='inbox_*': **0 rows** (LLM suggest nunca llamado, replies nunca enviados via nuevo endpoint)
- `bot_messages_inbox`: 476 mensajes en 66 bookings AirBnB activos
- Bookings activos: 75 (sin Casa Chamán)

Confirma:
- 90% bookings activos son AirBnB → necesitan suggestion sin WA conv (bug 1)
- Endpoint /suggest-reply NUNCA ha sido invocado en producción (bug separado pero relacionado, vive en thread/205)

---

## §2 · Explicit scope

### 2.1 IN scope

| Archivo | Cambio | LoC aprox |
|---|---|---|
| `apps/worker-bot/src/inbox/llm-suggestion.ts` | NEW función `suggestReplyFromBooking()` que usa `bot_messages_inbox` como history alternativa | +80 |
| `apps/worker-bot/src/api/admin/conversation.ts` | Modificar `handleSuggestReply` para routear booking sin WA → `suggestReplyFromBooking`; agregar `guest_name` a JOIN guests + return en subscriber.name; mejorar `parseHistoryToMessages` (timestamps workaround) | +60 modify |
| `apps/worker-bot/src/inbox/aggregate.ts` | Modificar Tab Reservas query: agregar `LEFT JOIN bot_messages_inbox` para preview/unread/last_msg fallback cuando convRow null. Fix unread count (DESPUÉS del último ASSISTANT) | +50 modify |
| `apps/worker-bot/tests/inbox/llm-suggestion.test.ts` (NEW si no existe) | Tests para suggestReplyFromBooking | +40 |
| `apps/worker-bot/tests/api/admin/conversation.test.ts` | Extend con tests guest_name + AirBnB-only suggestion | +30 |
| `apps/worker-bot/tests/inbox/aggregate.test.ts` (verify exists) | Tests para fallback OTA preview/unread | +30 |

### 2.2 OUT of scope

- ❌ Frontend (thread/205)
- ❌ Quick replies seed (thread/209)
- ❌ Structured summary (thread/207)
- ❌ Readiness in-stay override (thread/201)
- ❌ Database migrations (no new tables/cols this thread)
- ❌ ALTER TABLE (anti-pattern)
- ❌ R2 KB docs en LLM prompt (thread/210)
- ❌ Sentiment/intent classification

---

## §3 · Closed decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Suggestion AirBnB: nueva función `suggestReplyFromBooking(bookingId, env)` separada (no merge a `suggestReply()`) | Mantener separation of concerns: WA-based vs OTA-based loads distinct |
| D2 | OTA-based suggestion lee últimos 20 msgs de `bot_messages_inbox` ORDER BY message_time DESC | Mismo límite que WA history |
| D3 | Skip rules same: trivial, cron, cold_7d, rate_limit | No diferencia para AirBnB |
| D4 | `guest_name` en subscriber.name: prefer real name, fallback `Booking N` solo si null | Defensive |
| D5 | Timestamps workaround: NO mostrar timestamps individuales falsos. Mostrar relative al `last_active` solo en el último msg, resto vagos ("hace varios días") | Honesty: no inventes data |
| D6 | Unread = USER lines AFTER last ASSISTANT line (incluye history WA + bot_messages_inbox) | Real "no respondido por Kari/bot" |
| D7 | Preview/last_msg_at fallback orden: WA conv first, OTA bot_messages_inbox second, sino default values | Conservar precedencia WA cuando existe |
| D8 | NO usar embeddings/búsqueda semántica en R2 KB para suggestion AirBnB (deferred thread/210) | Keep this PR focused |
| D9 | Quick_replies vacía: NO seed en este PR (thread/209) | Out of scope |
| D10 | `inputs_used.history_msgs` count correcto cuando usa bot_messages_inbox | Logging accurate |
| D11 | LLM cost logging mismo formato a `audit_log kind='inbox_llm_suggestion'` con extra field `source: 'wa' | 'ota'` | Debug futuro |

---

## §4 · Implementation

### 4.1 NEW función `suggestReplyFromBooking()` en `llm-suggestion.ts`

Agregar al final del archivo (sin modificar `suggestReply` existente):

```typescript
/**
 * Suggest reply for AirBnB-only bookings (no WA conversation linked).
 * Reads history from `bot_messages_inbox` instead of `conversations.history`.
 * Same skip rules as suggestReply(): trivial, cron, cold_7d.
 *
 * Spec: thread/206 §4.1
 */
export async function suggestReplyFromBooking(
  bookingId: number,
  env: SuggestEnv,
): Promise<SuggestResponse> {
  if (!env.ANTHROPIC_API_KEY) return { ok: false, skip_reason: 'rate_limit' };

  // Load booking with captures
  const booking = await env.DB.prepare(
    `SELECT bb.beds24_booking_id, bb.room_id, bb.arrival, bb.departure,
            bb.num_adults, bb.num_pets, bb.total_amount_mxn, bb.deposit_paid,
            bb.balance_due_mxn, bb.channel,
            bc.mascotas_confirmed, bc.mascotas_count, bc.menu_status,
            bc.compras_confirmed, bc.morenas_svc_confirmed
     FROM beds24_bookings bb
     LEFT JOIN booking_captures bc ON bc.beds24_booking_id = bb.beds24_booking_id
     WHERE bb.beds24_booking_id = ?
       AND bb.room_id != 679176`,
  )
    .bind(bookingId)
    .first<{
      beds24_booking_id: number;
      room_id: number;
      arrival: string;
      departure: string;
      num_adults: number;
      num_pets: number;
      total_amount_mxn: number;
      deposit_paid: number;
      balance_due_mxn: number | null;
      channel: string;
      mascotas_confirmed: number | null;
      mascotas_count: number | null;
      menu_status: string | null;
      compras_confirmed: number | null;
      morenas_svc_confirmed: number | null;
    }>()
    .catch(() => null);

  if (!booking) return { ok: false, skip_reason: 'rate_limit' };

  // Load OTA messages (last 20, oldest first for prompt)
  const { results: otaMsgs } = await env.DB.prepare(
    `SELECT message_text, source, message_time
     FROM bot_messages_inbox
     WHERE booking_id = ?
     ORDER BY message_time DESC
     LIMIT 20`,
  )
    .bind(bookingId)
    .all<{ message_text: string; source: string; message_time: number }>();

  if (otaMsgs.length === 0) return { ok: false, skip_reason: 'rate_limit' };

  // Find last guest message
  const lastGuestMsg = otaMsgs.find((m) => m.source === 'guest');
  if (!lastGuestMsg) return { ok: false, skip_reason: 'rate_limit' };

  // Trivial / cold checks
  if (isTrivial(lastGuestMsg.message_text)) return { ok: false, skip_reason: 'trivial' };
  if (hoursSinceUnix(lastGuestMsg.message_time) > 7 * 24) return { ok: false, skip_reason: 'cold_7d' };

  // Build readiness from captures + no WA history (eta detection will be false here)
  const readiness = computeReadiness(
    {
      num_adults: booking.num_adults,
      num_pets: booking.num_pets,
      total_amount_mxn: booking.total_amount_mxn,
      deposit_paid: booking.deposit_paid,
      balance_due_mxn: booking.balance_due_mxn,
      arrival: booking.arrival,
      departure: booking.departure,
      room_id: booking.room_id,
    },
    {
      mascotas_confirmed: booking.mascotas_confirmed,
      mascotas_count: booking.mascotas_count,
      menu_status: booking.menu_status,
      compras_confirmed: booking.compras_confirmed,
      morenas_svc_confirmed: booking.morenas_svc_confirmed,
    },
    '', // no WA history; ETA detection via bot_messages_inbox could be added but defer §3.11 thread/204
  );

  // Training examples: top-3 quick_replies by usage_count
  const trainingRows = await env.DB.prepare(
    `SELECT text FROM quick_replies WHERE usage_count > 0 ORDER BY usage_count DESC LIMIT 3`,
  )
    .all<{ text: string }>()
    .catch(() => ({ results: [] as { text: string }[] }));
  const trainingExamples = trainingRows.results.map((r) => r.text);

  const systemPrompt = buildAdminSuggestPrompt({
    booking: {
      property_name: PROPERTY_NAMES[booking.room_id] ?? 'Propiedad RdM',
      arrival: booking.arrival,
      departure: booking.departure,
      num_adults: booking.num_adults,
      num_pets: booking.num_pets,
      channel: booking.channel,
      total_amount_mxn: booking.total_amount_mxn,
    },
    readiness,
    kbDocs: [],
    trainingExamples,
  });

  // Build messages array (chronological order: oldest first)
  const messages = otaMsgs
    .reverse()
    .map((m) => ({
      role: m.source === 'guest' ? ('user' as const) : ('assistant' as const),
      content: m.message_text,
    }));

  const t0 = Date.now();
  let response: Awaited<ReturnType<typeof callAnthropic>>;
  try {
    response = await callAnthropic(
      {
        model: HAIKU_MODEL,
        max_tokens: 512,
        system: [
          { type: 'text', text: systemPrompt, cache_control: { type: 'ephemeral' } },
        ],
        messages,
      },
      env.ANTHROPIC_API_KEY,
    );
  } catch {
    return { ok: false, skip_reason: 'rate_limit' };
  }

  const textBlock = response.content.find((b) => b.type === 'text');
  const suggestion = textBlock && 'text' in textBlock ? textBlock.text : '';

  const inputTokens = response.usage.input_tokens;
  const outputTokens = response.usage.output_tokens;
  const cacheRead = response.usage.cache_read_input_tokens ?? 0;
  const cost_usd = inputTokens * 0.0000008 + outputTokens * 0.000004 + cacheRead * 0.00000008;
  const cached = cacheRead > 0;

  await env.DB.prepare(
    `INSERT INTO audit_log (kind, payload_json, created_at) VALUES (?, ?, unixepoch())`,
  )
    .bind(
      'inbox_llm_suggestion',
      JSON.stringify({
        booking_id: bookingId,
        source: 'ota', // distinguish from WA-based
        model: HAIKU_MODEL,
        input_tokens: inputTokens,
        output_tokens: outputTokens,
        cache_read_tokens: cacheRead,
        cost_usd: Number(cost_usd.toFixed(6)),
        latency_ms: Date.now() - t0,
        booking_loaded: true,
        training_examples: trainingExamples.length,
      }),
    )
    .run()
    .catch(() => void 0);

  return {
    ok: true,
    suggestion,
    inputs_used: {
      history_msgs: otaMsgs.length,
      booking_loaded: true,
      readiness_loaded: true,
      kb_docs_loaded: 0,
      karina_training_examples: trainingExamples.length,
    },
    cost_usd: Number(cost_usd.toFixed(6)),
    cached,
  };
}
```

### 4.2 Modificar `handleSuggestReply` en `conversation.ts`

```diff
 export async function handleSuggestReply(c: Context<{ Bindings: Env }>): Promise<Response> {
   const rawId = c.req.param('id') ?? '';

   const ctx = await resolveConvContext(c.env, rawId);
   if (!ctx) return c.json({ ok: false, skip_reason: 'not_found' });

-  // Suggest requires WA history for LLM context — OTA messages alone don't have enough signal
-  if (!ctx.subscriberId || !ctx.hasWaConversation) {
-    return c.json({ ok: false, skip_reason: 'no_wa_history' });
+  // Route: WA-based for leads + bookings with WA conv; OTA-based for AirBnB-only bookings
+  if (ctx.subscriberId && ctx.hasWaConversation) {
+    // WA path (existing)
+    const conv = await c.env.DB.prepare(
+      `SELECT last_active FROM conversations WHERE subscriber_id = ?`,
+    )
+      .bind(ctx.subscriberId)
+      .first<{ last_active: number }>()
+      .catch(() => null);
+    if (!conv) return c.json({ ok: false, skip_reason: 'rate_limit' });
+    const result = await suggestReply(ctx.subscriberId, conv.last_active, {
+      DB: c.env.DB,
+      ANTHROPIC_API_KEY: c.env.ANTHROPIC_API_KEY,
+      KNOWLEDGE_BUCKET: c.env.KNOWLEDGE_BUCKET,
+    });
+    return c.json(result);
   }
-
-  const conv = await c.env.DB.prepare(
-    `SELECT last_active FROM conversations WHERE subscriber_id = ?`,
-  )
-    .bind(ctx.subscriberId)
-    .first<{ last_active: number }>()
-    .catch(() => null);
-
-  if (!conv) return c.json({ ok: false, skip_reason: 'rate_limit' });
-
-  const result = await suggestReply(ctx.subscriberId, conv.last_active, {
-    DB: c.env.DB,
-    ANTHROPIC_API_KEY: c.env.ANTHROPIC_API_KEY,
-    KNOWLEDGE_BUCKET: c.env.KNOWLEDGE_BUCKET,
-  });
-
-  return c.json(result);
+
+  if (ctx.bookingId) {
+    // OTA path (NEW thread/206)
+    const result = await suggestReplyFromBooking(ctx.bookingId, {
+      DB: c.env.DB,
+      ANTHROPIC_API_KEY: c.env.ANTHROPIC_API_KEY,
+      KNOWLEDGE_BUCKET: c.env.KNOWLEDGE_BUCKET,
+    });
+    return c.json(result);
+  }
+
+  return c.json({ ok: false, skip_reason: 'rate_limit' });
 }
```

Imports al top:
```diff
-import { suggestReply } from '../../inbox/llm-suggestion';
+import { suggestReply, suggestReplyFromBooking } from '../../inbox/llm-suggestion';
```

### 4.3 Modificar `resolveConvContext` para traer `guest_name` también

```diff
-LEFT JOIN guests g ON g.id = bb.guest_id
```

(Ya hace LEFT JOIN. Solo agregar `g.name` al SELECT.)

```diff
 const booking = await env.DB.prepare(
   `SELECT bb.beds24_booking_id, bb.room_id, bb.arrival, bb.departure,
           bb.num_adults, bb.num_pets, bb.total_amount_mxn, bb.deposit_paid,
           bb.balance_due_mxn, bb.channel,
-          g.phone_e164 as guest_phone,
+          g.phone_e164 as guest_phone,
+          g.name as guest_name,
           bc.mascotas_confirmed, bc.mascotas_count, bc.menu_status,
           bc.compras_confirmed, bc.morenas_svc_confirmed
    ...
```

Extender type:
```diff
 interface BookingRow {
   beds24_booking_id: number;
   ...
+  guest_name?: string | null;
 }
```

### 4.4 Modificar `handleConversationGet` subscriber.name

```diff
   conversation: {
     id: rawId,
     subscriber: {
       id: ctx.subscriberId ?? rawId,
       name: ctx.bookingRow
-        ? `Booking ${ctx.bookingId}`
+        ? (ctx.bookingRow.guest_name ?? `Booking ${ctx.bookingId}`)
         : (ctx.subscriberId ?? rawId),
```

Aplicar también garbage name normalization (importar de filters.ts):

```diff
+import { normalizeDisplayName } from '../../inbox/filters';
```

```diff
 subscriber: {
   id: ctx.subscriberId ?? rawId,
-  name: ctx.bookingRow
-    ? (ctx.bookingRow.guest_name ?? `Booking ${ctx.bookingId}`)
-    : (ctx.subscriberId ?? rawId),
+  name: (() => {
+    if (ctx.bookingRow?.guest_name) {
+      const { name } = normalizeDisplayName(ctx.bookingRow.guest_name, ctx.bookingRow.guest_phone);
+      return name;
+    }
+    return ctx.bookingRow ? `Booking ${ctx.bookingId}` : (ctx.subscriberId ?? rawId);
+  })(),
   ...
```

### 4.5 Modificar `parseHistoryToMessages` — timestamps workaround

Cambio mínimo: en lugar de distribuir ficticio, usar `last_active` solo para el último mensaje. Los demás se marcan como "hace varios días" (vagos).

```diff
 function parseHistoryToMessages(history: string, subscriberId: string) {
   type Msg = {
     id: string;
     channel: 'whatsapp';
     direction: 'inbound' | 'outbound';
     sent_by: 'guest' | 'bot' | 'karina' | 'alex';
     text: string;
     sent_at: string;
     external_id: string | null;
   };
   const msgs: Msg[] = [];
   const lines = history.split('\n').filter((l) => l.length > 0);
-  const baseMs = Date.now() - 24 * 3_600_000;
-  const step = lines.length > 0 ? (24 * 3_600_000) / lines.length : 60_000;
+  // thread/206: do NOT fabricate per-message timestamps. Use last_active for the LAST msg only.
+  // Older msgs get a stable "well in the past" timestamp so the UI clusters them but doesn't
+  // mislead with fake relative times.
+  // Caller injects lastActive (unix seconds) for accurate last-msg time.

   let idx = 0;
   for (const line of lines) {
     if (line.startsWith('USER:')) {
       msgs.push({
         id: `wa_user_${subscriberId}_${idx}`,
         channel: 'whatsapp',
         direction: 'inbound',
         sent_by: 'guest',
         text: line.slice(5).trim(),
-        sent_at: new Date(baseMs + idx * step).toISOString(),
+        sent_at: new Date(0).toISOString(), // sentinel; caller will replace last msg's timestamp
         external_id: null,
       });
     } else if (line.startsWith('ASSISTANT:')) {
       msgs.push({
         id: `wa_bot_${subscriberId}_${idx}`,
         channel: 'whatsapp',
         direction: 'outbound',
         sent_by: 'bot',
         text: line.slice(10).trim(),
-        sent_at: new Date(baseMs + idx * step + 1000).toISOString(),
+        sent_at: new Date(0).toISOString(),
         external_id: null,
       });
     }
     idx++;
   }
+
+  // Last message gets the real last_active timestamp (passed in by caller)
+  // Earlier messages keep sentinel 1970 → frontend renders "hace varios días"
   return msgs;
 }
```

Y en handler, después de parse:
```diff
-const historyMsgs = conv ? parseHistoryToMessages(conv.history, ctx.subscriberId!) : [];
+const historyMsgs = conv ? parseHistoryToMessages(conv.history, ctx.subscriberId!) : [];
+// Replace last msg's timestamp with conv.last_active (real)
+if (historyMsgs.length > 0 && conv) {
+  const lastIdx = historyMsgs.length - 1;
+  historyMsgs[lastIdx]!.sent_at = new Date(conv.last_active * 1000).toISOString();
+}
```

Frontend `fmtRelative()` debe distinguir sentinel epoch 0:
- En `inbox-client.ts fmtRelative()`: `if (diffMs > 365 * 86_400_000) return 'hace varios días'`

(Eso ya está hecho en frontend si default fallback es "—". Verificar; si no, agregar tweak en thread/205 follow-up.)

### 4.6 Modificar aggregate.ts Tab Reservas para preview/unread/last_msg fallback OTA

Después del bloque `const convRow = ...` y antes del `lastMsgText`:

```diff
 const convRow = br.conv_subscriber_id
   ? await env.DB.prepare(`SELECT * FROM conversations WHERE subscriber_id = ?`)
       .bind(br.conv_subscriber_id)
       .first<RawConvRow>()
       .catch(() => null)
   : null;

-const lastMsgText = convRow
-  ? convRow.history.split('\n').filter((l) => l.startsWith('USER:')).slice(-1)[0]?.slice(5).trim() ?? null
-  : null;
+// thread/206: prefer WA conv history, fallback to bot_messages_inbox for AirBnB-only bookings
+let lastMsgText: string | null = null;
+let lastMsgAtUnix: number | null = null;
+let unreadCount = 0;
+
+if (convRow) {
+  const lines = convRow.history.split('\n');
+  // Last user msg
+  const lastUserLine = lines.filter((l) => l.startsWith('USER:')).slice(-1)[0];
+  lastMsgText = lastUserLine?.slice(5).trim() ?? null;
+  lastMsgAtUnix = convRow.last_active;
+  // Unread count: USER lines AFTER last ASSISTANT line
+  for (let i = lines.length - 1; i >= 0; i--) {
+    const line = lines[i] ?? '';
+    if (line.startsWith('ASSISTANT:')) break;
+    if (line.startsWith('USER:')) unreadCount++;
+  }
+} else {
+  // Fallback: read OTA messages from bot_messages_inbox
+  const otaLast = await env.DB.prepare(
+    `SELECT message_text, message_time FROM bot_messages_inbox
+     WHERE booking_id = ? AND source = 'guest'
+     ORDER BY message_time DESC LIMIT 1`,
+  )
+    .bind(br.beds24_booking_id)
+    .first<{ message_text: string; message_time: number }>()
+    .catch(() => null);
+  if (otaLast) {
+    lastMsgText = otaLast.message_text;
+    lastMsgAtUnix = otaLast.message_time;
+  }
+  // Unread count: guest OTA msgs after last admin/bot OTA msg
+  const { results: recentOta } = await env.DB.prepare(
+    `SELECT source, message_time FROM bot_messages_inbox
+     WHERE booking_id = ?
+     ORDER BY message_time DESC LIMIT 50`,
+  )
+    .bind(br.beds24_booking_id)
+    .all<{ source: string; message_time: number }>();
+  for (const m of recentOta) {
+    if (m.source !== 'guest') break;
+    unreadCount++;
+  }
+}
```

Después remover el bloque viejo de unread:

```diff
-// Unread count: count recent messages from guest
-const unreadCount = convRow
-  ? convRow.history.split('\n').filter((l) => l.startsWith('USER:')).length
-  : 0;
```

Y reemplazar last_msg_at:

```diff
-const lastActive = convRow?.last_active ?? 0;
+const lastActive = lastMsgAtUnix ?? 0;
 const hoursSince = lastActive > 0 ? (nowMs / 1000 - lastActive) / 3600 : 0;
 if (filters.unanswered_h && hoursSince < filters.unanswered_h) continue;
```

Y ajustar el push final:
```diff
 preview: lastMsgText?.slice(0, 100) ?? '',
-last_msg_at: lastActive > 0 ? new Date(lastActive * 1000).toISOString() : new Date().toISOString(),
+last_msg_at: lastActive > 0 ? new Date(lastActive * 1000).toISOString() : new Date(0).toISOString(),
```

(sentinel epoch para casos sin data, frontend muestra "—" en lugar de timestamp falso)

---

## §5 · Tests

### 5.1 NEW `apps/worker-bot/tests/inbox/llm-suggestion-from-booking.test.ts`

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { suggestReplyFromBooking } from '../../src/inbox/llm-suggestion';

describe('suggestReplyFromBooking (thread/206)', () => {
  beforeEach(() => { vi.clearAllMocks(); });

  it('returns trivial skip if last guest OTA msg is trivial', async () => {
    const env = mockEnv({
      booking: { beds24_booking_id: 12345, /* ... */ },
      bot_messages_inbox: [
        { source: 'guest', message_text: 'gracias', message_time: nowSec() - 60 },
      ],
    });
    const result = await suggestReplyFromBooking(12345, env);
    expect(result).toEqual({ ok: false, skip_reason: 'trivial' });
  });

  it('returns cold_7d skip if last guest msg > 7 days', async () => {
    const env = mockEnv({
      booking: { beds24_booking_id: 12345 },
      bot_messages_inbox: [
        { source: 'guest', message_text: 'pregunta válida', message_time: nowSec() - 8 * 86400 },
      ],
    });
    const result = await suggestReplyFromBooking(12345, env);
    expect(result).toEqual({ ok: false, skip_reason: 'cold_7d' });
  });

  it('successfully suggests reply for AirBnB-only booking', async () => {
    const env = mockEnv({
      booking: { beds24_booking_id: 12345, room_id: 637063, arrival: '2026-06-01', /* ... */ },
      bot_messages_inbox: [
        { source: 'guest', message_text: 'a qué hora puedo hacer check-in?', message_time: nowSec() - 3600 },
      ],
      anthropic_response: { content: [{ type: 'text', text: 'Check-in es a las 3pm...' }] },
    });
    const result = await suggestReplyFromBooking(12345, env);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.suggestion).toContain('Check-in');
      expect(result.inputs_used.history_msgs).toBeGreaterThan(0);
    }
  });

  it('skips Casa Chamán bookings (room_id 679176)', async () => {
    const env = mockEnv({
      booking: { beds24_booking_id: 99999, room_id: 679176 },
      bot_messages_inbox: [
        { source: 'guest', message_text: 'pregunta', message_time: nowSec() - 60 },
      ],
    });
    const result = await suggestReplyFromBooking(99999, env);
    // Filtered out by WHERE bb.room_id != 679176
    expect(result).toEqual({ ok: false, skip_reason: 'rate_limit' });
  });
});
```

### 5.2 EXTEND `apps/worker-bot/tests/api/admin/conversation.test.ts`

Tests para guest_name + AirBnB-only suggestion routing:

```typescript
describe('handleConversationGet — guest name (thread/206)', () => {
  it('returns real guest name for booking (not "Booking N")', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 79421553, guest_name: 'Alan Granados', /* ... */ }],
    });
    const res = await handleConversationGet(mockCtx('b_79421553'));
    const data = await res.json();
    expect(data.conversation.subscriber.name).toBe('Alan Granados');
  });

  it('falls back to "Booking N" if guest_name null', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 12345, guest_name: null, /* ... */ }],
    });
    const res = await handleConversationGet(mockCtx('b_12345'));
    const data = await res.json();
    expect(data.conversation.subscriber.name).toBe('Booking 12345');
  });

  it('normalizes garbage guest name to phone parcial', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 12345, guest_name: '👍', guest_phone: '+525582528741' }],
    });
    const res = await handleConversationGet(mockCtx('b_12345'));
    const data = await res.json();
    expect(data.conversation.subscriber.name).toMatch(/\.\.\..*\d/);
  });
});

describe('handleSuggestReply — AirBnB routing (thread/206)', () => {
  it('routes to suggestReply (WA-based) when conv exists', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 1, guest_phone: '+525582528741' }],
      conversations: [{ subscriber_id: '5215582528741', history: 'USER: pregunta...', last_active: nowSec() - 60 }],
    });
    const res = await handleSuggestReply(mockCtx('b_1'));
    const data = await res.json();
    // Expect WA path called
    expect(data.ok).toBe(true);
  });

  it('routes to suggestReplyFromBooking (OTA-based) when no WA conv', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 2, guest_phone: '+525582528742' }],
      conversations: [], // no WA conv
      bot_messages_inbox: [{ booking_id: 2, source: 'guest', message_text: 'pregunta', message_time: nowSec() - 60 }],
    });
    const res = await handleSuggestReply(mockCtx('b_2'));
    const data = await res.json();
    // OTA path was called (returns suggestion)
    expect(data.ok).toBe(true);
  });

  it('returns skip if neither WA nor OTA available', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 3 }],
      conversations: [],
      bot_messages_inbox: [],
    });
    const res = await handleSuggestReply(mockCtx('b_3'));
    const data = await res.json();
    expect(data.ok).toBe(false);
    expect(data.skip_reason).toBe('rate_limit');
  });
});
```

### 5.3 EXTEND `apps/worker-bot/tests/inbox/aggregate.test.ts` (verify exists; else create)

Tests para fallback OTA en aggregate:

```typescript
describe('aggregateInbox preview/unread fallback OTA (thread/206)', () => {
  it('uses bot_messages_inbox for preview when no WA conv', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 100, channel: 'airbnb', /* ... */ }],
      conversations: [], // no WA
      bot_messages_inbox: [
        { booking_id: 100, source: 'guest', message_text: 'a qué hora check-in?', message_time: nowSec() - 3600 },
      ],
    });
    const res = await aggregateInbox(env, 'reservas', {});
    const row = res.sections[0]?.rows[0];
    expect(row?.preview).toContain('a qué hora check-in');
    expect(row?.last_msg_at).not.toBe(new Date(0).toISOString()); // real timestamp
  });

  it('unread count counts only USER msgs after last ASSISTANT', async () => {
    const env = mockEnv({
      bookings: [{ beds24_booking_id: 101 }],
      conversations: [{ 
        subscriber_id: '521xxx',
        history: 'USER: msg1\nASSISTANT: reply1\nUSER: msg2\nUSER: msg3', 
        last_active: nowSec()
      }],
    });
    const res = await aggregateInbox(env, 'reservas', {});
    const row = res.sections[0]?.rows[0];
    expect(row?.unread_count).toBe(2); // msg2, msg3 (NOT msg1, that's before reply)
  });
});
```

---

## §6 · Definition of Done

- [ ] Branch `fix/inbox-p0-backend-multi` creada
- [ ] 3 archivos modificados:
  - `apps/worker-bot/src/inbox/llm-suggestion.ts` (NEW function +80 LoC)
  - `apps/worker-bot/src/api/admin/conversation.ts` (modify ~60 LoC)
  - `apps/worker-bot/src/inbox/aggregate.ts` (modify ~50 LoC)
- [ ] 3 archivos tests (NEW/extend):
  - `apps/worker-bot/tests/inbox/llm-suggestion-from-booking.test.ts` (NEW ~40 LoC, 4-5 tests)
  - `apps/worker-bot/tests/api/admin/conversation.test.ts` (extend ~30 LoC, 6 tests nuevos)
  - `apps/worker-bot/tests/inbox/aggregate.test.ts` (extend ~30 LoC, 2-3 tests nuevos)
- [ ] `pnpm --filter worker-bot typecheck` PASS 0 nuevos errors
- [ ] `pnpm --filter worker-bot test` todos verdes (incluye thread/199, 200, 203 existentes)
- [ ] `git diff main --stat` muestra ~6 archivos
- [ ] Commit: `fix(inbox): P0 backend — AirBnB suggestion + guest name + timestamps + unread + preview OTA (thread/206)`
- [ ] PR body menciona los 5 bugs P0 cerrados con referencia thread/204
- [ ] ⚠️ MANUAL `npx wrangler deploy` REQUIRED post-merge

---

## §7 · Risks + Mitigations

| Risk | Mitigation |
|---|---|
| Conflicto con thread/205 frontend changes | Frontend solo modifica ConversationView + LLMSuggestion. Backend modifica conversation.ts + aggregate.ts. No overlap. |
| LLM cost overrun por Karina probando muchos AirBnB suggestions | Skip rules + Haiku ~$0.001/call. Asumido <$10/día |
| `quick_replies` vacía → trainingExamples = [] → prompt débil | Fix en thread/209 (seed). Mientras: prompt funciona aunque sin few-shot |
| Bot_messages_inbox query lento | Index `idx_messages_inbox_booking` existe (verificar). Worst case <50ms |
| Audit log payload bloated con `source: 'ota'` field | Marginal +20 bytes/event. OK |
| guest_name = null DB causes "Booking N" fallback OK pero inconsistente | normalizeDisplayName ya maneja null safely |
| WA history timestamps sentinel epoch 0 → frontend muestra "1969-12-31" | Frontend ya maneja con `fmtRelative()` falsy → "—". Verificar tests. Si rompe: thread/205 follow-up tweaks fmtRelative |
| Suggestion AirBnB-only sin readiness útil porque no WA history | OK: returns lo que tiene. Suggestion sigue siendo útil con booking context + OTA history |
| Cross-channel orden cronológico (WA history fake + OTA real) en conversation view | OTA timestamps reales, WA history timestamps ahora sentinel 0 → orden: WA history primero (1970), OTA mezclados según message_time. **Aceptable** workaround |

---

## §8 · Out-of-scope findings → issues

Si CC encuentra durante ejecución:
- Frontend changes → NO fix, defer thread/205
- ALTER TABLE necesaria → NO. Defer Wave 1.5
- Karina training table real → defer thread/210
- R2 KB docs integration → defer thread/210
- Sentiment classification → out of scope spec/196
- Issue [thread/206 OOS]

---

## §9 · Kickoff command (Alex pegará a CC)

```
DoIt thread/206: 5 bugs P0 backend inbox. Single PR worker-bot.

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/206-wc-cc-inbox-p0-backend-fixes.md

Sigue §4 implementation exacto. Self-review §6 DoD antes de commit.

Working directory: c:/dev/rdm/dev/bot

Pre-flight:
1. cd c:/dev/rdm/dev/bot
2. git checkout main
3. git pull origin main
4. git log --oneline -3 — confirma últimos PRs (170, 171, 172) ya merged

Execution:
1. git checkout -b fix/inbox-p0-backend-multi
2. Editar apps/worker-bot/src/inbox/llm-suggestion.ts: agregar suggestReplyFromBooking() según §4.1 (NEW function ~80 LoC). NO tocar suggestReply existente
3. Editar apps/worker-bot/src/api/admin/conversation.ts:
   - Import suggestReplyFromBooking + normalizeDisplayName
   - resolveConvContext: agregar g.name as guest_name a SELECT + extend BookingRow type
   - handleSuggestReply: dual path (WA → suggestReply, OTA-only → suggestReplyFromBooking) §4.2
   - handleConversationGet: usar guest_name real con normalizeDisplayName fallback §4.4
   - parseHistoryToMessages: sentinel epoch 0 timestamps, replace last msg con last_active real §4.5
4. Editar apps/worker-bot/src/inbox/aggregate.ts:
   - Tab Reservas query: agregar fallback OTA query a bot_messages_inbox §4.6
   - Unread count: USER msgs DESPUÉS del último ASSISTANT §4.6
   - last_msg_at: usar otaLast.message_time si convRow null §4.6
5. Crear apps/worker-bot/tests/inbox/llm-suggestion-from-booking.test.ts §5.1 (4-5 tests)
6. Extender apps/worker-bot/tests/api/admin/conversation.test.ts §5.2 (6 tests nuevos)
7. Extender apps/worker-bot/tests/inbox/aggregate.test.ts §5.3 (2-3 tests nuevos)
8. pnpm --filter worker-bot typecheck — PASS 0 errores nuevos
9. pnpm --filter worker-bot test — todos verdes
10. git diff main --stat
11. git add (archivos especificados §6)
12. git commit -m "fix(inbox): P0 backend — AirBnB suggestion + guest name + timestamps + unread + preview OTA (thread/206)"
13. git push -u origin fix/inbox-p0-backend-multi
14. gh pr create con title "fix(inbox): P0 backend — AirBnB suggestion + guest name + timestamps + unread + preview OTA (thread/206)" y body:
    - Closes thread/206, fixes P0 #2-#6 from thread/204 §2
    - 5 bugs P0 cerrados:
      1. Suggestion habilitada AirBnB-only bookings
      2. Guest name real (no "Booking N")
      3. WA timestamps workaround (sentinel + real last_msg)
      4. Unread count = USER msgs después del último ASSISTANT
      5. Preview + last_msg_at desde bot_messages_inbox
    - ⚠️ MANUAL `npx wrangler deploy` REQUIRED post-merge

Scope ESTRICTO: backend-only worker-bot.
- apps/worker-bot/src/inbox/llm-suggestion.ts (modify, NEW function)
- apps/worker-bot/src/api/admin/conversation.ts (modify)
- apps/worker-bot/src/inbox/aggregate.ts (modify)
- apps/worker-bot/tests/inbox/llm-suggestion-from-booking.test.ts (NEW)
- apps/worker-bot/tests/api/admin/conversation.test.ts (extend)
- apps/worker-bot/tests/inbox/aggregate.test.ts (extend)

NO ejecutes:
- pnpm test completo
- Frontend changes (apps/web/**) — thread/205 separado
- Database migrations
- ALTER TABLE
- npx wrangler deploy (Alex manual post-merge)
- Force-push, branch delete

Si encuentras algo fuera de scope → issue [thread/206 OOS].

Bloqueado >30 min sub-tarea = STOP y reporta.

Reportar al final con:
- suggestReplyFromBooking agregado (skip rules + booking context + OTA history)
- 4 archivos backend modificados
- handleSuggestReply dual path verificado
- guest_name extracción + normalizeDisplayName aplicado
- WA timestamps sentinel epoch 0 + real last_msg replacement
- Unread count post-ASSISTANT logic
- Aggregate Tab Reservas OTA fallback
- Tests pass count (mínimo 13 tests nuevos: 4-5 helper + 6 conversation + 2-3 aggregate)
- Typecheck PASS
- PR URL
- ⚠️ CRÍTICO: worker-bot deploy manual + smoke test:
  - Abrir conversation booking AirBnB (ej. Claudia Becerra #86656062) → debe mostrar sugerencia IA OTA-based
  - Header debe mostrar nombre real ("Claudia Becerra Alcantara") NO "Booking N"
  - Timestamps en msgs antiguos: "—" o vago, NO "23h, 17h"
  - Badge unread debe reflejar msgs REALES nuevos, no total histórico

GO.
```

---

## §10 · Post-merge smoke test (Alex)

Después de merge + `npx wrangler deploy`:

### Test 1 — Guest name real
- /admin/inbox → click row Alan Granados (#79421553)
- Header debe decir "Alan Granados" NO "Booking 79421553"
- ✓ esperado

### Test 2 — Suggestion AirBnB
- Click row Claudia Becerra Alcantara (booking AirBnB)
- Esperar ~2s
- ✨ "Sugerencia IA" aparece con texto coherente
- ✓ esperado (Bug P0 #2 fixed)

### Test 3 — Timestamps WA
- Abrir conv Alan Granados
- Msgs antiguos timestamps: "—" o "hace varios días" (no más "23h, 17h, 11h" ficticios)
- Solo el último msg timestamp = real (ej. "ayer" si last_active fue 1 día atrás)
- ✓ esperado

### Test 4 — Unread count real
- /admin/inbox tab Reservas
- Pequeños badges "N nuevos" en rows con WA history → reflejar solo msgs después del último ASSISTANT
- Si Karina ya respondió un cliente → unread_count debería ser 0 (no el total histórico)
- ✓ esperado

### Test 5 — Preview AirBnB
- /admin/inbox tab Reservas
- Rows AirBnB (Claudia, otros sin WA) ahora muestran preview del último mensaje OTA
- ✓ esperado

---

## §11 · References

- thread/204 §2 P0 bugs (root cause analysis 5/6 bugs P0)
- thread/196 §4.4.5 + §4.2.4 (spec original LLM suggestion)
- thread/200 (conversation polimórfico, contexto)
- thread/203 (phone normalize, contexto previo)
- thread/205 (P0 frontend complementario)
- D1 query investigation 2026-05-24 madrugada: quick_replies=0, audit_log inbox=0, bot_messages_inbox=476 en 66 bookings
