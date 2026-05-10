# 08 — Orquestación: reemplazo nativo de Make.com

**Status**: Propuesta. Esperando voto.

**Decisión**: **Cloudflare Workflows** + **Queues** + **Durable Objects** + **Cron Triggers** reemplazan TODOS los usos de Make.com. Cero Make en arquitectura objetivo.

## Contexto

Alexander pidió explícitamente: "Make como solución temporal. Nueva versión ya no usa Make para Beds24 get/postings directo".

Y: "Best industry solutions, no island solutions, no workarounds".

Make.com hoy se usa para:
1. Bot LLM 2-stage flow (Greeter, Booker).
2. Calls a Beds24 (get availability, get prices, post booking).
3. MP webhook handling (en parte; el Worker hace HMAC + idempotency, llama Make para confirmar Beds24).
4. Knowledge refresh cron (GitHub raw + Beds24 calendar → datastores).
5. Otros utility scenarios.

Todo esto tiene equivalente nativo en Cloudflare stack.

## Mapping Make → Cloudflare

| Make pattern | Cloudflare nativo |
|---|---|
| Scenario con webhook trigger | Worker route `POST /webhook/...` |
| Scenario con scheduled trigger | Cron Triggers (`crons` en wrangler.toml) |
| Sub-scenario `CallSubscenario` | Function call dentro del mismo Worker / Workflow `step.do()` |
| Datastore record CRUD | D1 SQL / KV / Durable Object SQL |
| HTTP module a API externa | `fetch()` nativo |
| `Sleep` module | `step.sleep()` en Workflow / DO `alarm()` |
| `Repeater` / iterate array | Queue producer + consumer (fan-out) |
| `Router` con multiple paths | Switch/if en código |
| Error handler con retry | Workflow `step.do()` automatic retry |
| Sequential execution | `await` chain |
| Sequential con state persistence | Workflow `step.do()` |

## Cloudflare Workflows — el reemplazo grande

Workflows es **durable execution**: procesos multi-step que sobreviven crashes, retries automáticamente, persisten state. Equivalente a Make scenarios complejos pero en código TS, type-safe, versionable en git.

### Casos de uso para RdM

#### W1 — `booking-creation-workflow`

```typescript
export class BookingCreationWorkflow extends WorkflowEntrypoint<Env, BookingPayload> {
  async run(event, step) {
    const { subscriber_id, property_id, check_in, check_out, guests, guest_data } = event.payload;
    
    // Paso 1: D1 INSERT con status='hold', 30min hold
    const booking = await step.do('create-hold', () =>
      this.env.DB.prepare('INSERT INTO bookings ... RETURNING *').bind(...).first()
    );
    
    // Paso 2: Beds24 POST booking
    const beds24 = await step.do('create-beds24-booking', { retries: { limit: 3, backoff: 'exponential' } }, () =>
      createBeds24Booking({ booking, env: this.env })
    );
    
    // Paso 3: Update D1 con beds24_id
    await step.do('link-beds24', () =>
      this.env.DB.prepare('UPDATE bookings SET beds24_id=? WHERE id=?').bind(beds24.id, booking.id).run()
    );
    
    // Paso 4: MercadoPago preference
    const mp = await step.do('create-mp-preference', () => createMpPreference({ booking, env: this.env }));
    
    // Paso 5: ManyChat / WhatsApp send link
    await step.do('send-payment-link', () => sendPaymentLink({ subscriber_id, mp_url: mp.init_point, env: this.env }));
    
    // Paso 6: Esperar pago hasta 30min
    await step.sleep('wait-payment', '30m');
    
    // Paso 7: Check status, si no pagado → expire hold
    const current = await step.do('check-payment', () => getBooking(booking.id, this.env));
    if (current.status !== 'paid' && current.status !== 'confirmed') {
      await step.do('expire-hold', () => expireBookingHold(booking.id, this.env));
    }
  }
}
```

**Pros vs Make**:
- Type safety end-to-end.
- Step retries automáticas.
- State persistente (sobrevive worker restart).
- Versioned en git, code review possible.
- Sleep `30m` sin tener Worker corriendo (Cloudflare gestiona).

#### W2 — `mp-payment-workflow`

Trigger desde `POST /webhook/mp`:

```typescript
export class MpPaymentWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    const { payment_id, external_reference } = event.payload;
    
    // Paso 1: GET MP payment details
    const payment = await step.do('fetch-payment', () => fetchMpPayment(payment_id, this.env));
    
    if (payment.status !== 'approved') return;
    
    // Paso 2: Idempotency check
    const seen = await step.do('idempotency', () => checkProcessed(payment_id, this.env));
    if (seen) return;
    
    // Paso 3: Update booking
    await step.do('update-booking', () => updateBookingPaid(external_reference, payment, this.env));
    
    // Paso 4: Confirm Beds24
    await step.do('confirm-beds24', { retries: { limit: 5, backoff: 'exponential' } }, () =>
      confirmBeds24Booking(external_reference, payment, this.env)
    );
    
    // Paso 5: Email cliente
    await step.do('send-email', () => sendConfirmationEmail(external_reference, this.env));
    
    // Paso 6: Notify cliente vía channel (WhatsApp)
    await step.do('notify-channel', () => sendChannelMessage(external_reference, this.env));
  }
}
```

#### W3 — `pricing-update-workflow`

Cron-triggered diario:

```typescript
export class PricingUpdateWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    // Paso 1: Fetch PriceLabs computed prices
    const prices = await step.do('fetch-pricelabs', () => fetchPriceLabs(this.env));
    
    // Paso 2: Apply propio override layer (señales del bot)
    const adjusted = await step.do('apply-overrides', () => applyBotSignalOverrides(prices, this.env));
    
    // Paso 3: Push a Beds24 en batches
    await step.do('push-beds24', () => pushPricesBatch(adjusted, this.env));
    
    // Paso 4: Log en pricing_log
    await step.do('log', () => insertPricingLog(adjusted, this.env));
    
    // Paso 5: Notify Alexander si change > 15%
    const bigChanges = adjusted.filter(p => Math.abs(p.delta_pct) > 15);
    if (bigChanges.length > 0) {
      await step.do('notify', () => sendPricingChangeEmail(bigChanges, this.env));
    }
  }
}
```

### Workflows limits (verificado 2026)

Plan Workers Paid:
- Concurrent instances: limit raised April 2026.
- Steps per instance: 1024.
- Storage per instance: 1GB.
- Workflow duration: hours/days/weeks (free sleeps).

Para RdM volume actual + 5x growth: workflows scale más que suficiente.

## Cloudflare Queues — async messaging

Para fan-out, buffering, dead-letter queue.

### Casos de uso

#### Q1 — `outbound-messages-queue`

Cuando bot decide enviar mensaje, en lugar de fetch directo a ManyChat/WhatsApp (que puede fallar y bloquear el request):

```typescript
// apps/bot/src/agents/greeter.ts
await env.OUTBOUND_QUEUE.send({
  channel: 'whatsapp',
  subscriber_id,
  message: reply,
  attempt: 1
});

// apps/bot/src/queues/outbound-consumer.ts
export default {
  async queue(batch: MessageBatch, env) {
    for (const msg of batch.messages) {
      try {
        await sendViaChannel(msg.body, env);
        msg.ack();
      } catch (e) {
        if (msg.body.attempt >= 5) {
          msg.ack(); // give up, will go to DLQ via separate config
        } else {
          msg.retry({ delaySeconds: 2 ** msg.body.attempt });
        }
      }
    }
  }
};
```

Beneficios:
- Bot turn completa rápido, no espera ManyChat.
- Retry automático con backoff.
- DLQ para inspección de fallos.

#### Q2 — `image-processing-queue`

Staff sube fotos en task → queue → consumer redimensiona/optimiza → R2.

#### Q3 — `analytics-events-queue`

Cada turno LLM, cada booking, cada pago → emit evento → consumer agrega a `analytics_events` table o Logpush.

## Durable Objects — state coordinado

### Caso de uso 1: Debounce 8s per subscriber

```typescript
export class DebounceDurableObject extends DurableObject {
  async receiveMessage(subscriber_id: string, message: string) {
    await this.ctx.storage.setAlarm(Date.now() + 8000);
    const buffered = (await this.ctx.storage.get<string[]>('buffer')) || [];
    buffered.push(message);
    await this.ctx.storage.put('buffer', buffered);
  }
  
  async alarm() {
    const buffered = await this.ctx.storage.get<string[]>('buffer') || [];
    const combined = buffered.join('\n');
    await this.ctx.storage.delete('buffer');
    
    // Trigger bot processing
    await this.env.BOT_WORKFLOW.create({ subscriber_id: this.ctx.id.toString(), message: combined });
  }
}
```

Un DO por subscriber activo. Auto-cleanup cuando alarm fires.

### Caso de uso 2: Anti-double-booking lock

```typescript
export class PropertyLockDO extends DurableObject {
  async tryReserve(check_in: string, check_out: string, booking_id: string): Promise<boolean> {
    // Check existing overlaps in storage
    const overlaps = await this.findOverlaps(check_in, check_out);
    if (overlaps.length > 0 && overlaps.some(o => o.status !== 'hold' || isExpired(o))) return false;
    
    await this.ctx.storage.put(`reservation:${booking_id}`, { check_in, check_out, status: 'hold' });
    return true;
  }
}
```

Un DO por propiedad. Garantiza serialización de bookings concurrentes.

### Caso de uso 3: WebSocket para admin inbox

DO mantiene WebSocket connections de admin users. Cuando nuevo mensaje del bot → broadcast a admin conectados.

## Cron Triggers — schedules

Sin cambios respecto a hoy (`rincon-pago` ya tiene 5 crons). Solo agregar:
- `0 */2 * * *` — knowledge refresh.
- `0 7 * * *` — pricing workflow.
- `*/15 * * * *` — health check / metrics emit.

## Ejemplo end-to-end: cliente reserva por bot

```
1. Cliente: "Aparta para 25-27 sep, 20 pax"
   → ManyChat → POST /webhook/manychat

2. apps/bot/routes/manychat.ts:
   - Ack 200 inmediato
   - ctx.waitUntil( DEBOUNCE_DO.get(subscriber_id).receiveMessage(text) )

3. Debounce DO (8s alarm):
   - GREETER_WORKFLOW.create({ subscriber_id, message })

4. GreeterWorkflow run:
   - step.do('llm-stage1') → intent extraction
   - step.do('calendar-lookup') → D1 query
   - step.do('llm-stage2') → response generation
   - step.do('outbound-queue.send') → respond
   - if intent === 'handoff_booking':
     - BOOKER_WORKFLOW.create({ ...handoff_data })

5. BookerWorkflow run:
   - step.do('llm-stage1') → confirm intent
   - step.do('calendar-lookup')
   - step.do('llm-stage2') → reply
   - if intent === 'create_booking' && all data:
     - BOOKING_WORKFLOW.create(payload)
   - outbound-queue.send(reply)

6. BookingCreationWorkflow run (ver W1 arriba):
   - D1 INSERT hold
   - PROPERTY_LOCK_DO.tryReserve → fail if conflict
   - Beds24 POST
   - MP preference
   - outbound-queue.send(payment_link)
   - sleep('30m')
   - check + expire if not paid

7. Cliente paga → POST /webhook/mp:
   - HMAC verify
   - idempotency check
   - MP_PAYMENT_WORKFLOW.create(payload)

8. MpPaymentWorkflow run:
   - fetch MP details
   - update booking status='paid'
   - confirm Beds24 status='confirmed' (con retries)
   - email cliente
   - outbound-queue.send(confirmación)
```

Cada paso es:
- **Idempotent** (workflows step result cached).
- **Retried automáticamente** con backoff.
- **Trazado** (Workers Logs + Workflows UI).
- **Resumible** desde cualquier punto si crash.

## Pros vs Make

| Aspecto | Make.com | CF Workflows |
|---|---|---|
| Type safety | No | Sí (TS) |
| Version control | No (JSON blob en UI) | Sí (git) |
| Code review | No | Sí (PRs) |
| Tests | No | Sí (vitest) |
| Latency p50 | 9-13s | <2s esperado |
| Cold start | N/A (queue) | <100ms |
| Sleep largo (días) | Sí con caveats | Sí, nativo |
| Retry exponential | Sí (limit 3) | Sí, configurable |
| Step inspection | Sí (Make UI) | Sí (Workflows UI) |
| Costo concurrente | $0.0001/op | Workers Paid plan |
| DLQ | Manual | Sí (Queues) |

## Cons / consideraciones

- **Curva de aprendizaje**: Workflows API es nueva, equipo se familiariza.
- **Limits**: 1024 steps/instance, 1GB storage. Para nuestro volume no problema.
- **Vendor lock-in**: Workflows es CF-only. Mitigación: lógica de negocio en `packages/`, Workflows solo orquesta.
- **Local dev**: miniflare soporta Workflows desde 2025.

## Roadmap orquestación

| Fase | Migrar |
|---|---|
| 1 | Knowledge refresh (cron) — el más simple, baja blast radius |
| 2 | MP webhook → Workflow (en lugar de inline en `/webhook/mp`) |
| 3 | Greeter/Booker → Workflows + DO debounce |
| 4 | Booking creation → Workflow |
| 5 | Pricing → Workflow |
| 6 | Sunset Make scenarios |

## Voto

- [ ] **Claude Code**: ¿Workflows + Queues + DOs es la mezcla correcta? Otros patterns que prefieres?
- [ ] **Alexander**: ¿OK con Make sunset completo? (Sí pediste explícito, confirmo).

## Refs

- Cloudflare Workflows: `https://developers.cloudflare.com/workflows/`
- Cloudflare Queues: `https://developers.cloudflare.com/queues/`
- Durable Objects: `https://developers.cloudflare.com/durable-objects/`
- CF Best Practices 2026: `https://developers.cloudflare.com/changelog/post/2026-02-15-workers-best-practices/`
