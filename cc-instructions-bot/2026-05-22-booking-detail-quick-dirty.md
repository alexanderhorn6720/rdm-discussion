# Booking Detail · Quick & Dirty · CC DoIt spec

**Status**: 🟢 ready para CC pickup · single PR · all-in-one
**Workstream**: CC-Bot (`apps/worker-bot` + `apps/web` + 1 helper extract en `apps/web/src/lib`)
**Effort estimate**: ~28h CC realistic (4-5 días sólidos)
**Source**: brain mode session 2026-05-22 + WhatsApp conversation con Alex (4 iteraciones v1→v4)
**Author**: WC-Implementation
**Date**: 2026-05-22
**Decision basis**: este NO es M-module completo. Es quick & dirty enhancement a lo que ya existe para que Karina opere mejor mientras se construyen M6/M7 reales en el futuro.

---

## §1 · Context

### Problem

Hoy Karina opera bookings con info dispersa:
- `/admin/bookings?view=list|gantt` muestra fechas + pax + $ básicos sin estado operacional
- `/admin/extra-guests` solo captura extras pax >16
- Mascotas, eventos, servicios Morenas, notas, menú, compras grocery = mental tracking ad-hoc que falla constantemente
- Welcome auto-send broken (post-audit P0)
- Pagos manejados en Beds24 panel directo, sin surface admin friendly
- MP link generation manual cada vez via `/api/payment-link.ts` (existing pero solo para direct bookings vía hold flow)
- Sin link directo de calendar → conversación inbox del huésped

### Lo que queremos

Quick & dirty surface por booking + pills "readiness" en calendar + extra-guests enhanced + MP link generator extending existing infra. NO es M6/M7 completo — eso queda documentado en `vision/02-wishlist.md` para futuro.

### Why now

Karina-fication phase (ADR-004 Wave 1-5) cubre polish + feedback infra. Este PR agrega capa **operacional capture** que Karina pidió explícito. Encaja entre Wave 1 polish y Wave 2 feedback como cluster operativo independiente.

---

## §2 · Explicit scope

### YES — 4 surfaces touched

#### Surface A · `/admin/bookings/{beds24_id}` NEW page (3 tabs)

Astro page nueva con 3 tabs React island.

**Tab 1 · General** (read-only desde D1 `beds24_bookings` + `guests`)
- Booking ID + Airbnb confirmation code (si channel='airbnb')
- Propiedad (PROPERTY_NAMES map)
- Llegada + Salida + Noches + Pax breakdown (adults/children/pets/total)
- Channel + Status + Beds24 status
- Totals MXN: total_amount, deposit_paid, balance_due
- Guest info: name, phone_e164, email
- Pre-stay timestamps: welcome_sent_at, pre_arrival_t7_sent_at, pre_arrival_t1_sent_at, arrived_sent_at
- Audit brief: "Last Beds24 sync XX · Karina last edit YY"

**Tab 2 · Capturas** (edit D1 + push Beds24 infoItems + comments)
- MASCOTAS: count + notes + confirmed checkbox + LLM badge si detected
- EVENTO: radio enum + custom text si 'other' + confirmed + LLM badge
- SERVICIOS MORENAS (solo room_id IN [374482, 74316]): chef Y/N + days, cocinera Y/N + days, confirmed
- MENÚ: radio enum (no_preguntado | pendiente | recibido | declined)
- COMPRAS GROCERY: monto MXN + notes + confirmed (= triggers invoice item draft en Tab 3)
- NOTAS KARINA: textarea 5000 chars max
- PEDIDOS ESPECIALES: textarea (LLM extracted o manual)
- Buttons: [Guardar local] [Guardar + Push a Beds24]

**Tab 3 · Cargos & Pagos** (mirror Beds24 invoiceItems + payments + MP link)
- CARGOS table (read Beds24 invoice items via worker proxy): label, qty, precio, total, [edit] [×]
- [+ Agregar cargo] form: label, texto, qty, precio → POST Beds24
- PAGOS table (read Beds24 invoice payments): tipo, fecha, monto, notas
- [+ Registrar pago manual] form: tipo enum (efectivo/transferencia/otro), monto MXN, fecha, notas → POST Beds24
- 💳 ENLACE MERCADOPAGO section:
  - Display "Total pendiente: $X" (= balance from Beds24)
  - Input "Efectivo a recibir: [_____]" (informativo, no se registra hasta que Karina recibe)
  - Auto-calc "MP link por: [total - cash]"
  - Input "Descripción" (editable, default "Saldo {property} {guest_name}")
  - Display "Expira en 5 días: {date}"
  - [Generar link] → POST `/api/admin/booking-payment-link`
  - Display link generado + [📋 Copiar] [Enviar por WhatsApp] (abre wa.me con texto pre-poblado)
- BILL plain-text preview (server-generated) + [📋 Copiar]
- [🔄 Recalcular en Beds24] [Abrir cargos en Beds24 →] (deep link)

**Top bar** (todos los tabs):
- Booking ID + guest name
- 3 external links: [💬 Inbox] [✈ Airbnb] [🏨 Beds24]
- Property · fechas · pax · days-to-arrival
- Readiness pill 🟢/🟡/🔴 + score %

#### Surface B · `/admin/extra-guests` ENHANCED

Mantiene queue functionality + agrega:
- Columnas nuevas inline-editable: Mascotas, Evento, Morenas svc, Menú, Compras, Notas (count chars)
- LLM badge "🤖 sugerido" cuando bot detectó algo en conversación (campo D1 `*_llm_detected`)
- Karina aprueba LLM suggestion con 1-click → copies value to confirmed field
- Pill "Listo" 🟢/🟡/🔴 + score per row
- Link "💬" per row → `/admin/inbox?conv={conversation_id}` (lookup via beds24_booking_id)
- Link booking_id → `/admin/bookings/{id}` full page
- **⚙️ Plantilla outreach UNIFICADA section** (collapsible):
  - **1 textarea + 1 botón** total (no 4)
  - Variables soportadas: `{{guest_name}}, {{property_name}}, {{arrival_date}}, {{pax}}`
  - Save → upsert en `outreach_templates` D1 row con `template_key='unified'`
  - Karina edita el texto. Cuando hace clic "Send outreach" en cualquier row → fires unified template

#### Surface C · `/admin/bookings?view=list` + `?view=gantt`

**List view**:
- Column NEW "Listo" con pill + score % + days-to-arrival
- Column NEW "💬" con link a inbox conversation
- Click row → navigate `/admin/bookings/{beds24_id}`

**Gantt view**:
- Stripe lateral colored sobre cada booking bar (color = readiness status)
- Popup expansion (existing) gana: link "Ver detalles →" + link "💬 Conversación →"
- Click bar → navigate `/admin/bookings/{beds24_id}`

#### Surface D · Conversation links cross-cutting

Helper `getConversationLinkForBooking(db, beds24_booking_id): Promise<string | null>` reusable across surfaces. Returns `/admin/inbox?conv={id}` o null si no hay conversación.

### NO — out of scope

- ❌ Guest-facing `/bill/{token}` page (Karina copia plain-text manual)
- ❌ PDF generation
- ❌ MP webhook → auto-update D1 captures con paid status (webhook existing solo updates Beds24)
- ❌ MP auto-send via ManyChat/WhatsApp (Karina copia link manual)
- ❌ LLM autonomous extraction loop (campos `*_llm_detected` existen pero NO populate loop en este PR)
- ❌ Beds24 sync queue con retry cron (push manual button only, fail-loud UI)
- ❌ Activity log table separada
- ❌ M5 Tasks integration
- ❌ Pre-arrival concierge workflow T-14d (separate I1 module)
- ❌ Beds24 conflict resolution UI (last-write-wins)
- ❌ Multi-currency display
- ❌ Casa Chamán surface (room_id != 679176 filter en queries)
- ❌ Email send
- ❌ Multiple outreach templates (UNIFIED single template per Alex decision)
- ❌ Refactor de `/api/payment-link.ts` flow para direct bookings (mantiene as-is)
- ❌ ManyChat integration para directos (workstream separado: F-1 fix)

---

## §3 · Closed decisions

| Decisión | Valor | Razón |
|---|---|---|
| Migration numbers | 0042 + 0043 | Last applied = 41 |
| Outreach templates | 1 unified textarea + 1 button | Alex decision iteration 4 |
| Outreach send channel: Airbnb | Beds24 messages API directo | Bypass ManyChat broken (92% fail) |
| Outreach send channel: directos | ManyChat (when fixed) | Workstream F-1 fix paralelo |
| Outreach send channel: Booking.com | Beds24 messages | Same as Airbnb |
| MP link TTL | 5 días | Alex: bill at arrival, paid before checkout |
| Cash split | Display informativo only | Karina anota manual al recibir en Beds24 |
| MP link short URL | `pago.rincondelmar.club/p/{slug}` | Reuse `bot_short_links` (thread/158 PR3) |
| MP create-preference | Extract helper from existing `payment-link.ts` | NO doble work |
| Payments registration | Beds24 source of truth, NO D1 payments table | Alex confirmed |
| LLM detection fields | Columns existen, NO populate loop v1 | Future M6 |
| Readiness formula | 30 mandatory + 50 captures + 20 welcome | v3 design |
| Conversation link | `/admin/inbox?conv={id}` query param | Verify support exists (§5.1 PRE-CHECK) |
| Casa Chamán | Filtered en TODAS queries (room_id != 679176) | Existing pattern |
| Mobile breakpoint | 320px stack vertical en tabs y forms | Audit-2026-Q2-v2 F.2 |
| Property names map | PROPERTY_NAMES from existing extra-guests.astro | Reuse |
| Beds24 messages format | Array body (not wrapped en `{data: ...}`) | Confirmed thread/158 PR2 |
| Outreach unified template variables | `{{guest_name}} {{property_name}} {{arrival_date}} {{pax}}` | 4 standard placeholders |

---

## §4 · Implementation

### §4.1 · Migration 0042: booking_captures

`apps/worker-bot/migrations/0042_booking_captures.sql`:

```sql
CREATE TABLE IF NOT EXISTS booking_captures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  beds24_booking_id INTEGER NOT NULL UNIQUE,
  
  -- Mascotas
  mascotas_count INTEGER,
  mascotas_notes TEXT,
  mascotas_confirmed INTEGER NOT NULL DEFAULT 0,
  mascotas_llm_detected INTEGER NOT NULL DEFAULT 0,
  mascotas_llm_evidence TEXT,
  
  -- Evento
  evento_type TEXT,
  evento_custom TEXT,
  evento_confirmed INTEGER NOT NULL DEFAULT 0,
  evento_llm_detected INTEGER NOT NULL DEFAULT 0,
  evento_llm_evidence TEXT,
  
  -- Servicios Morenas
  morenas_chef_enabled INTEGER NOT NULL DEFAULT 0,
  morenas_chef_days INTEGER,
  morenas_cocinera_enabled INTEGER NOT NULL DEFAULT 0,
  morenas_cocinera_days INTEGER,
  morenas_svc_confirmed INTEGER NOT NULL DEFAULT 0,
  
  -- Menu
  menu_status TEXT,
  
  -- Compras grocery
  compras_monto_mxn INTEGER,
  compras_notes TEXT,
  compras_confirmed INTEGER NOT NULL DEFAULT 0,
  
  -- Notes
  notes_karina TEXT,
  special_requests TEXT,
  
  -- Readiness (cached)
  readiness_score INTEGER,
  readiness_status TEXT,
  readiness_missing TEXT,
  
  -- Beds24 sync
  beds24_last_push_at INTEGER,
  beds24_push_status TEXT,
  beds24_push_error TEXT,
  
  -- Audit
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_by TEXT
);

CREATE INDEX IF NOT EXISTS idx_booking_captures_status
  ON booking_captures(readiness_status, beds24_booking_id);

CREATE INDEX IF NOT EXISTS idx_booking_captures_sync
  ON booking_captures(beds24_push_status)
  WHERE beds24_push_status != 'synced';

CREATE INDEX IF NOT EXISTS idx_booking_captures_llm
  ON booking_captures(mascotas_llm_detected, evento_llm_detected)
  WHERE mascotas_llm_detected = 1 OR evento_llm_detected = 1;
```

### §4.2 · Migration 0043: outreach_templates

`apps/worker-bot/migrations/0043_outreach_templates.sql`:

```sql
CREATE TABLE IF NOT EXISTS outreach_templates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  template_key TEXT NOT NULL UNIQUE,
  template_label TEXT NOT NULL,
  template_text_es TEXT NOT NULL,
  template_text_en TEXT,
  variables_json TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

INSERT OR IGNORE INTO outreach_templates (template_key, template_label, template_text_es, variables_json) VALUES
  ('unified',
   'Outreach unificado',
   'Hola {{guest_name}} 👋 vi tu reserva en {{property_name}} para el {{arrival_date}} ({{pax}} personas). Para preparar mejor tu estancia, necesito confirmar algunos detalles:

¿Vienen con mascotas? (cobramos $300 por mascota toda la estancia, máx 2)

¿Celebran algo especial? Cumpleaños, aniversario, despedida, evento corporativo, etc.

Servicios opcionales (solo Las Morenas):
- Chef ($1,000/día)
- Cocinera ($1,500/día)

¿Algún pedido o consideración especial?

Cualquier duda, aquí estoy. 🌅',
   '["guest_name","property_name","arrival_date","pax"]');
```

Karina puede editar `template_text_es` post-ship via UI en `/admin/extra-guests`.

### §4.3 · Helper extraction: `apps/web/src/lib/mp.ts` NEW

Extract de `apps/web/src/pages/api/payment-link.ts`:

```typescript
import type { D1Database } from '@cloudflare/workers-types';

interface CreateMpPreferenceParams {
  amount_mxn: number;
  description: string;
  external_reference: string;
  payer_email?: string;
  payer_name?: string;
  expires_days?: number;  // default 1 día
  back_urls_base?: string;  // default pago.rincondelmar.club
  metadata?: Record<string, unknown>;
}

interface MpPreferenceResult {
  preference_id: string;
  init_point: string;
  sandbox_init_point: string;
  use_sandbox: boolean;
  url: string;  // the one to send (init_point o sandbox_init_point based on env)
}

export async function createMpPreference(
  env: { MP_ACCESS_TOKEN?: string; SITE_URL?: string; MP_USE_SANDBOX?: string },
  params: CreateMpPreferenceParams,
): Promise<MpPreferenceResult | { error: string; details?: string; status: number }> {
  if (!env.MP_ACCESS_TOKEN) {
    return { error: 'mp_not_configured', status: 503 };
  }

  const SITE_URL = env.SITE_URL ?? 'https://rincondelmar.club';
  const PAGO_URL = params.back_urls_base ?? SITE_URL.replace(/^https?:\/\//, 'https://pago.');
  const expiresDays = params.expires_days ?? 1;
  const expiresAt = new Date(Date.now() + expiresDays * 24 * 60 * 60 * 1000).toISOString();

  try {
    const mpRes = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.MP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        items: [{
          title: params.description,
          quantity: 1,
          unit_price: params.amount_mxn,
          currency_id: 'MXN',
        }],
        payer: params.payer_email
          ? { email: params.payer_email, name: params.payer_name }
          : undefined,
        external_reference: params.external_reference,
        notification_url: `${PAGO_URL}/webhook/mp`,
        back_urls: {
          success: `${PAGO_URL}/exitoso?b=${params.external_reference}`,
          failure: `${PAGO_URL}/fallido?b=${params.external_reference}`,
          pending: `${PAGO_URL}/pendiente?b=${params.external_reference}`,
        },
        auto_return: 'approved',
        metadata: params.metadata,
        expires: true,
        expiration_date_to: expiresAt,
      }),
    });

    if (!mpRes.ok) {
      const text = await mpRes.text();
      console.error('[mp/create-preference] failed', mpRes.status, text);
      return { error: 'mp_error', details: text, status: 502 };
    }

    const pref = (await mpRes.json()) as {
      id: string;
      init_point: string;
      sandbox_init_point: string;
    };

    const useSandbox = env.MP_USE_SANDBOX === 'true';
    const url = useSandbox ? pref.sandbox_init_point : pref.init_point;

    return {
      preference_id: pref.id,
      init_point: pref.init_point,
      sandbox_init_point: pref.sandbox_init_point,
      use_sandbox: useSandbox,
      url,
    };
  } catch (err) {
    console.error('[mp/create-preference] exception', err);
    return { error: 'internal', status: 500 };
  }
}
```

**Refactor existing**: `apps/web/src/pages/api/payment-link.ts` → import + use this helper. Backward compatible — output shape sin cambios para callers actuales.

### §4.4 · NEW endpoint: `/api/admin/booking-payment-link`

`apps/web/src/pages/api/admin/booking-payment-link.ts`:

```typescript
import { createMpPreference } from '@/lib/mp';
import { isAdmin, isAdminReadonly } from '@/lib/admin';
import type { APIRoute } from 'astro';
import { z } from 'zod';

export const prerender = false;

const inputSchema = z.object({
  beds24_booking_id: z.number().int().positive(),
  amount_mxn: z.number().int().positive().max(1_000_000),
  description: z.string().min(1).max(200),
  expires_days: z.number().int().min(1).max(30).default(5),
});

export const POST: APIRoute = async ({ request, locals }) => {
  const env = locals.runtime?.env as Env | undefined;
  const user = locals.user;
  
  if (!user || !env) {
    return Response.json({ error: 'unauthorized' }, { status: 401 });
  }
  if (!isAdmin(env, user.email) && !isAdminReadonly(env, user.email)) {
    return Response.json({ error: 'forbidden' }, { status: 403 });
  }
  if (isAdminReadonly(env, user.email)) {
    return Response.json({ error: 'readonly_role' }, { status: 403 });
  }
  if (!env.DB) {
    return Response.json({ error: 'no_db' }, { status: 500 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return Response.json({ error: 'invalid_body' }, { status: 400 });
  }
  
  const parsed = inputSchema.safeParse(payload);
  if (!parsed.success) {
    return Response.json({ error: 'invalid_input', details: parsed.error.format() }, { status: 400 });
  }

  // Lookup booking + guest
  const row = await env.DB.prepare(
    `SELECT bb.beds24_booking_id, bb.channel, bb.arrival, bb.departure,
            g.name AS guest_name, g.email AS guest_email
       FROM beds24_bookings bb
       LEFT JOIN guests g ON g.id = bb.guest_id
      WHERE bb.beds24_booking_id = ?
      LIMIT 1`,
  ).bind(parsed.data.beds24_booking_id).first<{
    beds24_booking_id: number;
    channel: string;
    arrival: string;
    departure: string;
    guest_name: string | null;
    guest_email: string | null;
  }>();

  if (!row) {
    return Response.json({ error: 'booking_not_found' }, { status: 404 });
  }

  // Create preference via shared helper
  const result = await createMpPreference(env, {
    amount_mxn: parsed.data.amount_mxn,
    description: parsed.data.description,
    external_reference: `b24-${parsed.data.beds24_booking_id}`,
    payer_email: row.guest_email ?? undefined,
    payer_name: row.guest_name ?? undefined,
    expires_days: parsed.data.expires_days,
    metadata: {
      beds24_booking_id: parsed.data.beds24_booking_id,
      channel: row.channel,
      created_by: user.email,
      created_via: 'admin_booking_detail',
    },
  });

  if ('error' in result) {
    return Response.json({ error: result.error, details: result.details }, { status: result.status });
  }

  // Insert into bot_short_links (existing thread/158 PR3 table)
  // Slug format: pay-{guest_first}-{date}-{random3}
  const guestFirst = (row.guest_name ?? 'guest').split(' ')[0].toLowerCase().slice(0, 12);
  const dateStr = row.arrival.replace(/-/g, '').slice(2);  // YYMMDD
  const random3 = Math.random().toString(36).slice(2, 5);
  const slug = `pay-${guestFirst}-${dateStr}-${random3}`;
  
  try {
    await env.DB.prepare(
      `INSERT INTO bot_short_links
        (slug, target_url, intent_slug, lang, subscriber_name, created_at, created_via)
       VALUES (?, ?, 'payment', 'es', ?, unixepoch(), 'admin_booking_detail')`,
    ).bind(slug, result.url, row.guest_name ?? null).run();
  } catch (err) {
    // Insert fail = link still works directly, just no short URL
    console.error('[booking-payment-link] short_link insert failed', err);
  }

  const SITE_URL = env.SITE_URL ?? 'https://rincondelmar.club';
  const shortUrl = `${SITE_URL}/ir/${slug}`;

  return Response.json({
    preference_id: result.preference_id,
    mp_url: result.url,
    short_url: shortUrl,
    use_sandbox: result.use_sandbox,
    expires_at: new Date(Date.now() + (parsed.data.expires_days * 86400 * 1000)).toISOString(),
  });
};
```

### §4.5 · Worker-bot endpoints

Todos con auth `x-admin-secret` (existing pattern).

#### `GET /admin/booking-captures/:id`

`apps/worker-bot/src/index.ts`:

```typescript
app.get('/admin/booking-captures/:id', adminAuthMiddleware, async (c) => {
  const beds24Id = parseInt(c.req.param('id'), 10);
  if (isNaN(beds24Id)) return c.json({ error: 'invalid_id' }, 400);

  const captures = await c.env.DB.prepare(
    `SELECT * FROM booking_captures WHERE beds24_booking_id = ?`
  ).bind(beds24Id).first();

  // Si no existe row, return defaults
  if (!captures) {
    return c.json({
      beds24_booking_id: beds24Id,
      mascotas_count: null,
      mascotas_confirmed: 0,
      evento_type: null,
      evento_confirmed: 0,
      // ... (todos los fields con defaults)
      readiness_score: null,  // calc on save
      readiness_status: null,
    });
  }

  return c.json(captures);
});
```

#### `PUT /admin/booking-captures/:id`

Recibe TODO el body de captures. Validate. Calc readiness. UPSERT. Return.

```typescript
const updateSchema = z.object({
  mascotas_count: z.number().int().min(0).max(10).nullable().optional(),
  mascotas_notes: z.string().max(500).nullable().optional(),
  mascotas_confirmed: z.union([z.literal(0), z.literal(1)]).optional(),
  // ... (todos los fields)
  notes_karina: z.string().max(5000).nullable().optional(),
  special_requests: z.string().max(5000).nullable().optional(),
});

app.put('/admin/booking-captures/:id', adminAuthMiddleware, async (c) => {
  // Parse + validate
  // Read existing row (si existe)
  // Merge update on existing
  // Lookup beds24_bookings for room_id, arrival, welcome_sent_at, etc
  // Calc readiness via shared function
  // UPSERT INTO booking_captures
  // Return updated row
});
```

#### `POST /admin/booking-captures/:id/push-beds24`

Push infoItems + comments + (si confirmed) invoice item drafts a Beds24.

```typescript
app.post('/admin/booking-captures/:id/push-beds24', adminAuthMiddleware, async (c) => {
  // Read captures row
  // Build infoItems array:
  //   - mascotas: itemName='mascotas', itemText='{count} mascotas, {notes}'
  //   - evento: itemName='evento', itemText='{type} {custom}'
  //   - morenas-svc: itemName='morenas-servicios', itemText='Chef {days_chef}d, Cocinera {days_cocinera}d'
  //   - menu: itemName='menu', itemText=menu_status
  // Build comments append:
  //   - timestamp + [Karina] + notes_karina
  //   - timestamp + [LLM] + special_requests (si flag llm_detected)
  // POST Beds24 v2 /bookings con infoItems (replace) + comments append
  // Update D1 row: beds24_last_push_at, beds24_push_status='synced'
  // Si confirmed compras OR morenas svc → trigger invoice item creation (separate endpoint)
});
```

#### `POST /admin/bookings/:id/invoice-item`

Add custom invoice item a Beds24.

```typescript
const invoiceSchema = z.object({
  label: z.string().min(1).max(50),  // "Charge", "Rental", etc
  description: z.string().min(1).max(200),
  qty: z.number().positive().default(1),
  price_mxn: z.number().min(0),
});

app.post('/admin/bookings/:id/invoice-item', adminAuthMiddleware, async (c) => {
  // Replicar pattern de apps/worker-bot/src/extra-guests.ts postInvoiceItem
  // POST https://api.beds24.com/v2/bookings/invoiceItems con array body
});
```

#### `DELETE /admin/bookings/:id/invoice-item/:itemId`

DELETE Beds24 invoice item.

#### `POST /admin/bookings/:id/payment`

Add manual payment record a Beds24.

```typescript
const paymentSchema = z.object({
  payment_type: z.enum(['efectivo', 'transferencia', 'otro']),
  amount_mxn: z.number().positive(),
  payment_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  notes: z.string().max(200).optional(),
});

app.post('/admin/bookings/:id/payment', adminAuthMiddleware, async (c) => {
  // POST Beds24 v2 /bookings/payments (verify exact endpoint via Beds24 docs)
  // Format: array body, mismo pattern que invoiceItems
});
```

#### `GET /admin/bookings/:id/invoice-snapshot`

Fetch Beds24 booking's full invoice tab (read-only mirror para Tab 3).

```typescript
app.get('/admin/bookings/:id/invoice-snapshot', adminAuthMiddleware, async (c) => {
  // GET https://api.beds24.com/v2/bookings?id=X&includeInvoiceItems=true&includeInvoicePayments=true
  // Return { invoiceItems: [...], invoicePayments: [...], balance, total }
});
```

#### `GET /admin/bookings/:id/bill-text`

Generate plain-text bill server-side.

```typescript
app.get('/admin/bookings/:id/bill-text', adminAuthMiddleware, async (c) => {
  // Read beds24_bookings + booking_captures + invoice-snapshot
  // Build plain text with:
  //   Greeting (con guest first name)
  //   Property + dates
  //   Each invoice item line
  //   Totals (charges, paid, pending)
  //   If MP link in bot_short_links recent → include
  //   If split cash detected (Karina input via Tab 3) → include both options
  //   Closing
  // Return { bill_text: '...' }
});
```

#### `GET /admin/outreach-templates`

```typescript
app.get('/admin/outreach-templates', adminAuthMiddleware, async (c) => {
  const rows = await c.env.DB.prepare(
    `SELECT * FROM outreach_templates WHERE enabled = 1 ORDER BY template_key`
  ).all();
  return c.json({ templates: rows.results });
});
```

#### `PUT /admin/outreach-templates/:key`

```typescript
app.put('/admin/outreach-templates/:key', adminAuthMiddleware, async (c) => {
  const key = c.req.param('key');
  const body = await c.req.json();
  // Validate body.template_text_es
  await c.env.DB.prepare(
    `UPDATE outreach_templates
        SET template_text_es = ?, updated_at = unixepoch()
      WHERE template_key = ?`
  ).bind(body.template_text_es, key).run();
  return c.json({ ok: true });
});
```

#### `POST /admin/outreach-fire`

Send outreach template to guest via channel-appropriate path.

```typescript
const fireSchema = z.object({
  beds24_booking_id: z.number().int().positive(),
  template_key: z.string().default('unified'),
});

app.post('/admin/outreach-fire', adminAuthMiddleware, async (c) => {
  // Read template
  // Lookup booking + guest + channel
  // Substitute variables:
  //   {{guest_name}} → first name
  //   {{property_name}} → PROPERTY_NAMES[room_id]
  //   {{arrival_date}} → formatted date "15 ago"
  //   {{pax}} → num_adults + " huéspedes"
  
  // Route by channel:
  if (booking.channel === 'airbnb' || booking.channel === 'booking_com') {
    // Use Beds24 messages API (existing sendBeds24Message helper in messenger-send.ts)
    await sendBeds24Message(c.env, booking.beds24_booking_id, substitutedText);
  } else {
    // direct / web / whatsapp_direct → ManyChat
    // NOTA: ManyChat tiene 92% fail rate post-audit. UI debe warning.
    // Por ahora dispatch via existing messenger_outbound table como fallback
    // (separate workstream F-1 fix in flight)
    return c.json({ error: 'manychat_broken', warning: 'Directos via ManyChat tienen 92% fail. Workstream F-1 en progreso.' }, 503);
  }
  
  return c.json({ ok: true, channel: 'beds24', timestamp: new Date().toISOString() });
});
```

#### `GET /admin/conversation-link/:beds24_id`

```typescript
app.get('/admin/conversation-link/:beds24_id', adminAuthMiddleware, async (c) => {
  const beds24Id = parseInt(c.req.param('beds24_id'), 10);
  const conv = await c.env.DB.prepare(
    `SELECT id FROM conversations WHERE booking_id = ? ORDER BY last_message_at DESC LIMIT 1`
  ).bind(beds24Id).first<{ id: string }>();
  return c.json({ conversation_id: conv?.id ?? null });
});
```

### §4.6 · Astro page: `apps/web/src/pages/admin/bookings/[id].astro`

```astro
---
import AdminLayout from '@/layouts/AdminLayout.astro';
import BookingDetailView from '@/components/admin/BookingDetailView.tsx';
import { isAdmin, isAdminReadonly } from '@/lib/admin';

export const prerender = false;

const env = Astro.locals.runtime?.env as Env | undefined;
const user = Astro.locals.user;
const allowed = isAdmin(env, user?.email) || isAdminReadonly(env, user?.email);
const readonly = !isAdmin(env, user?.email) && isAdminReadonly(env, user?.email);

const beds24Id = parseInt(Astro.params.id as string, 10);

if (isNaN(beds24Id)) {
  return Astro.redirect('/admin/bookings');
}

const PROPERTY_NAMES: Record<number, string> = {
  78695: 'Rincón del Mar',
  74322: 'Las Morenas',
  374482: 'Las Morenas',
  74316: 'Combinada',
  637063: 'Huerta Cocotera',
  // 679176: 'Casa Chamán', — hidden v1
};

let booking: BookingDetail | null = null;
let captures: BookingCaptures | null = null;
let conversationId: string | null = null;
let loadError: string | null = null;

if (allowed && env?.DB && beds24Id !== 679176) {
  try {
    const bookingRow = await env.DB.prepare(
      `SELECT bb.*, g.name AS guest_name, g.phone_e164 AS guest_phone,
              g.email AS guest_email
         FROM beds24_bookings bb
         LEFT JOIN guests g ON g.id = bb.guest_id
        WHERE bb.beds24_booking_id = ?
        LIMIT 1`,
    ).bind(beds24Id).first();
    
    if (!bookingRow) {
      loadError = 'booking_not_found';
    } else {
      booking = bookingRow as BookingDetail;
      
      const capRow = await env.DB.prepare(
        `SELECT * FROM booking_captures WHERE beds24_booking_id = ? LIMIT 1`,
      ).bind(beds24Id).first();
      captures = capRow as BookingCaptures | null;
      
      const convRow = await env.DB.prepare(
        `SELECT id FROM conversations WHERE booking_id = ? ORDER BY last_message_at DESC LIMIT 1`,
      ).bind(beds24Id).first<{ id: string }>();
      conversationId = convRow?.id ?? null;
    }
  } catch (err) {
    console.error('[admin/bookings/[id]] load failed', err);
    loadError = err instanceof Error ? err.message : 'd1_error';
  }
}
---
<AdminLayout title={booking ? `Booking ${beds24Id}` : 'Booking'} active="bookings">
  <section>
    {!allowed && <p class="muted">Sin acceso.</p>}
    {loadError === 'booking_not_found' && (
      <div class="error-block">
        <strong>Booking no encontrado</strong>
        <p>Beds24 ID: {beds24Id}</p>
        <a href="/admin/bookings">← Volver a bookings</a>
      </div>
    )}
    {loadError && loadError !== 'booking_not_found' && (
      <div class="error-block">
        <strong>Error</strong>
        <p>{loadError}</p>
      </div>
    )}
    
    {allowed && booking && !loadError && (
      <BookingDetailView
        client:visible
        initialData={JSON.stringify({
          booking,
          captures,
          conversationId,
          propertyNames: PROPERTY_NAMES,
          readonly,
        })}
      />
    )}
  </section>
</AdminLayout>
```

### §4.7 · React island: `apps/web/src/components/admin/BookingDetailView.tsx`

Skeleton structure (full component ~800 lines, abbreviated):

```typescript
import { useState, useEffect } from 'react';

interface InitialData {
  booking: BookingDetail;
  captures: BookingCaptures | null;
  conversationId: string | null;
  propertyNames: Record<number, string>;
  readonly: boolean;
}

export default function BookingDetailView({ initialData }: { initialData: string }) {
  const data: InitialData = JSON.parse(initialData);
  const [tab, setTab] = useState<'general' | 'capturas' | 'cargos'>('general');
  const [captures, setCaptures] = useState(data.captures);
  const [readiness, setReadiness] = useState(calcReadiness(data.booking, data.captures));
  const [pushStatus, setPushStatus] = useState<'idle' | 'pushing' | 'ok' | 'error'>('idle');
  
  // ... handlers
  
  return (
    <div className="booking-detail">
      <header>
        <h1>{data.booking.beds24_booking_id} · {data.booking.guest_name}</h1>
        <div className="meta">
          {data.propertyNames[data.booking.room_id]} ·
          {data.booking.arrival} → {data.booking.departure} ·
          {data.booking.total_guests} pax ·
          {daysUntil(data.booking.arrival)}d a llegada
        </div>
        <div className="actions">
          {data.conversationId && (
            <a href={`/admin/inbox?conv=${data.conversationId}`}>💬 Inbox</a>
          )}
          {data.booking.channel === 'airbnb' && (
            <a href={`https://www.airbnb.mx/hosting/reservations/details/${data.booking.channel_reservation_code}`} 
               target="_blank" rel="noopener">✈ Airbnb</a>
          )}
          <a href={`https://beds24.com/control3.php?function=showBookings&bookId=${data.booking.beds24_booking_id}`}
             target="_blank" rel="noopener">🏨 Beds24</a>
        </div>
        <ReadinessPill {...readiness} />
      </header>
      
      <nav className="tabs">
        <button onClick={() => setTab('general')} className={tab === 'general' ? 'active' : ''}>General</button>
        <button onClick={() => setTab('capturas')} className={tab === 'capturas' ? 'active' : ''}>Capturas</button>
        <button onClick={() => setTab('cargos')} className={tab === 'cargos' ? 'active' : ''}>Cargos & Pagos</button>
      </nav>
      
      {tab === 'general' && <TabGeneral booking={data.booking} />}
      {tab === 'capturas' && <TabCapturas booking={data.booking} captures={captures} onSave={...} readonly={data.readonly} />}
      {tab === 'cargos' && <TabCargos booking={data.booking} readonly={data.readonly} />}
    </div>
  );
}
```

3 sub-components: `TabGeneral`, `TabCapturas`, `TabCargos`. Cada uno maneja su state + API calls. Mobile-first CSS.

### §4.8 · Readiness formula (shared)

`packages/shared/src/booking-readiness.ts` NEW:

```typescript
export interface ReadinessInput {
  arrival: string;
  room_id: number;
  guest_name: string | null;
  guest_phone: string | null;
  departure: string;
  welcome_sent_at: number | null;
  pre_arrival_t7_sent_at: number | null;
}

export interface CapturesInput {
  mascotas_confirmed?: number;
  evento_confirmed?: number;
  morenas_svc_confirmed?: number;
  menu_status?: string | null;
  compras_confirmed?: number;
  notes_karina?: string | null;
  special_requests?: string | null;
}

export interface ReadinessResult {
  score: number;
  status: 'green' | 'yellow' | 'red';
  missing: string[];
}

export function calcReadiness(booking: ReadinessInput, captures: CapturesInput | null): ReadinessResult {
  const today = new Date().toISOString().slice(0, 10);
  const daysToArrival = Math.floor((new Date(booking.arrival).getTime() - new Date(today).getTime()) / 86400000);
  const isMorenas = booking.room_id === 374482 || booking.room_id === 74316;
  
  let earned = 0;
  let max = 0;
  const missing: string[] = [];
  
  const cap = captures ?? {};
  
  // Mandatory 30
  max += 30;
  if (booking.guest_name && booking.guest_phone) earned += 15;
  else missing.push('guest_info');
  if (booking.arrival && booking.departure) earned += 15;
  
  // Captures 50
  max += 50;
  
  if (cap.mascotas_confirmed) earned += 10;
  else missing.push('mascotas');
  
  if (cap.evento_confirmed) earned += 10;
  else missing.push('evento');
  
  if (isMorenas) {
    if (cap.morenas_svc_confirmed) earned += 10;
    else missing.push('servicios_morenas');
  } else {
    earned += 10;
  }
  
  if (cap.menu_status && cap.menu_status !== 'no_preguntado') earned += 5;
  else missing.push('menu');
  
  if (cap.compras_confirmed || cap.menu_status === 'declined') earned += 5;
  else missing.push('compras');
  
  if (cap.notes_karina || cap.special_requests) earned += 10;
  else missing.push('notas');
  
  // Welcome/pre-arrival 20
  max += 20;
  if (booking.welcome_sent_at) earned += 10;
  else missing.push('welcome');
  if (booking.pre_arrival_t7_sent_at) earned += 10;
  
  const score = Math.round((earned / max) * 100);
  
  let status: 'green' | 'yellow' | 'red';
  if (daysToArrival <= 3 && missing.filter(m => m !== 'welcome' && m !== 'compras').length > 0) {
    status = 'red';
  } else if (daysToArrival <= 14 && score < 80) {
    status = 'yellow';
  } else if (score >= 80) {
    status = 'green';
  } else if (score >= 50) {
    status = 'yellow';
  } else {
    status = 'red';
  }
  
  return { score, status, missing };
}
```

Used en: server-side (booking-captures PUT endpoint para cache), client-side (real-time on form changes), calendar views (list + Gantt).

### §4.9 · `/admin/extra-guests` enhancement

`apps/web/src/components/admin/ExtraGuestsView.tsx` extended:

- New columns rendered in table
- Each cell tap → inline editor (popover o modal pequeño)
- Save → PUT `/api/admin/booking-captures/:beds24_id`
- LLM badges: si `mascotas_llm_detected=1` render small icon
- Pill column: render `<ReadinessPill />` con score+status calc client-side
- Conversation link column: render `<a href="/admin/inbox?conv={id}">💬</a>` o disabled
- Outreach unified template editor (collapsible section above table):
  - Single textarea + Save button
  - GET/PUT `/api/admin/outreach-templates/unified`

### §4.10 · `/admin/bookings?view=list` + `?view=gantt`

#### List view changes

Existing query LEFT JOIN booking_captures:

```sql
SELECT bb.*, bc.readiness_score, bc.readiness_status, bc.readiness_missing
  FROM beds24_bookings bb
  LEFT JOIN booking_captures bc ON bc.beds24_booking_id = bb.beds24_booking_id
 WHERE bb.arrival >= date('now', '-30 days')
   AND bb.arrival <= date('now', '+90 days')
   AND bb.status NOT IN ('cancelled', 'archived')
   AND bb.room_id != 679176
 ORDER BY bb.arrival ASC;
```

Add column "Listo" rendering `<ReadinessPill>` y "💬" rendering conversation link.

Click row → `window.location = /admin/bookings/{beds24_id}`.

#### Gantt view changes

Existing booking bars get colored stripe lateral (CSS `border-left: 4px solid {color}`).

Popup expansion (existing component) extends con:
```html
<a href="/admin/bookings/{id}">Ver detalles →</a>
<a href="/admin/inbox?conv={id}">💬 Conversación →</a>
```

### §4.11 · Bill plain-text generator

Server-side en `GET /admin/bookings/:id/bill-text`:

```typescript
function generateBillText(booking, captures, invoiceItems, payments, mpShortLink, cashAmount) {
  const guestFirst = booking.guest_name?.split(' ')[0] ?? '';
  const propertyName = PROPERTY_NAMES[booking.room_id];
  const checkInFmt = formatDate(booking.arrival);
  const checkOutFmt = formatDate(booking.departure);
  
  const lines = [
    `Hola ${guestFirst} 👋`,
    ``,
    `Tu cuenta para ${propertyName} (${checkInFmt} - ${checkOutFmt}):`,
    ``,
    ...invoiceItems.map(item => 
      `${item.description.padEnd(22)} $${item.amount.toLocaleString('es-MX')}`
    ),
    `${'─'.repeat(38)}`,
    `Total:               $${total.toLocaleString('es-MX')} MXN`,
    ``,
    `Pagado:              $${paid.toLocaleString('es-MX')}`,
    `Saldo pendiente:     $${balance.toLocaleString('es-MX')} MXN`,
  ];
  
  if (mpShortLink) {
    lines.push(``, `Opciones de pago:`);
    if (cashAmount > 0) {
      lines.push(
        `• $${cashAmount.toLocaleString('es-MX')} efectivo al llegar`,
        `• $${(balance - cashAmount).toLocaleString('es-MX')} MercadoPago:`,
        `  ${mpShortLink}`,
      );
    } else {
      lines.push(`• MercadoPago: ${mpShortLink}`);
      lines.push(`• O efectivo al llegar`);
    }
  }
  
  lines.push(``, `¡Te esperamos!`);
  
  return lines.join('\n');
}
```

---

## §5 · Tests

### §5.1 · PRE-CHECK obligatorio antes de PR open

CC verifica:

1. **`/admin/inbox?conv=X` query param support**:
   ```bash
   grep -rn "searchParams.get('conv')" apps/web/src/pages/admin/inbox.astro
   grep -rn "conv=" apps/web/src/components/admin/InboxView.tsx
   ```
   - Si NO support: agregar a InboxView para auto-select conversation by ID
   - Si NO se puede agregar en este PR: ship con links pero log warning + open issue separado

2. **Beds24 `/v2/bookings/payments` endpoint exists**:
   - Verify via Beds24 v2 API docs o test con `curl https://api.beds24.com/v2/bookings/payments -X POST -H 'token: ...'`
   - Si endpoint diferente: ajustar `POST /admin/bookings/:id/payment` para usar el correcto

3. **`bot_short_links` table exists en prod**:
   ```bash
   wrangler d1 query rincon --command "SELECT name FROM sqlite_master WHERE type='table' AND name='bot_short_links'"
   ```
   - Debe existir desde thread/158 PR3. Si NO: BLOCKER, apply 0041 migration first.

4. **`MP_ACCESS_TOKEN` configurado en `apps/web` Pages env**:
   ```bash
   wrangler pages secret list --project-name rincondelmar-club
   ```
   - Debe existir. Si NO: BLOCKER, Alex configura antes.

### §5.2 · Unit tests

| Test file | Cases |
|---|---|
| `packages/shared/src/booking-readiness.test.ts` | 12+ cases: mandatory only, all captures, Morenas vs non-Morenas, edge cases (T-2d, T-30d), missing fields combos |
| `apps/web/src/lib/mp.test.ts` | 6+ cases: success, MP_ACCESS_TOKEN missing, MP API 4xx, sandbox vs prod, expires_days override |
| `apps/worker-bot/src/booking-captures.test.ts` | 8+ cases: GET (existing + non-existing), PUT validation, PUT readiness recalc, push-beds24 happy path |
| `apps/worker-bot/src/booking-invoice.test.ts` | 6+ cases: invoice item POST, DELETE, payment POST, snapshot GET |
| `apps/worker-bot/src/outreach-templates.test.ts` | 4+ cases: GET, PUT, fire (airbnb → beds24), fire (direct → 503 manychat) |

### §5.3 · Smoke test (manual, post-deploy)

1. Visit `/admin/bookings/86850930` (use real booking ID Erika García o similar) → loads all 3 tabs
2. Tab General → all fields read-only correct
3. Tab Capturas → edit mascotas count, save local, refresh, persisted
4. Tab Capturas → confirm + push beds24 → verify infoItems aparecen en Beds24 panel
5. Tab Cargos → see existing invoice items + add new custom item → verify in Beds24
6. Tab Cargos → register manual payment (efectivo) → verify in Beds24
7. Tab Cargos → input cash $5,000, descripción default, generate MP link → link returned
8. Visit short URL → 302 redirect to MP checkout
9. Copy bill plain-text → paste in WhatsApp test conversation, verify format
10. Visit `/admin/extra-guests` → see new columns + LLM badges + readiness pills
11. Click "💬" link → navigates to inbox conversation
12. Visit `/admin/bookings?view=list` → see "Listo" column with pills
13. Visit `/admin/bookings?view=gantt` → see colored stripes + popup with links
14. Mobile 320px: verify no horizontal overflow en ningún surface
15. Update outreach template via UI → verify D1 row updated
16. Fire outreach a Airbnb booking → verify message en Beds24 conversation
17. Fire outreach a direct booking → verify 503 con warning (until F-1 fix)

---

## §6 · Definition of done

- [ ] Migrations 0042 + 0043 applied prod (verify via `wrangler d1 migrations list`)
- [ ] All worker-bot endpoints respond 200 to smoke tests
- [ ] `createMpPreference` helper extracted + existing `payment-link.ts` refactored using it
- [ ] `/api/admin/booking-payment-link` returns short URL + 302 chain works
- [ ] `/admin/bookings/{id}` page loads all 3 tabs without errors
- [ ] Tab 2 captures save + push beds24 verified end-to-end con real booking
- [ ] Tab 3 invoice add/delete + payment register + MP link generation verified
- [ ] Bill plain-text generates with proper formatting + copy button works
- [ ] `/admin/extra-guests` new columns editable + LLM badges visible + outreach template editable
- [ ] Calendar list view "Listo" pill column rendered + clickable rows
- [ ] Calendar Gantt view stripe overlay + popup links
- [ ] Conversation links cross-cutting (resolved via worker endpoint o D1 join)
- [ ] Readiness score calculated consistently server + client + cached in D1
- [ ] Casa Chamán (679176) filtered out de todas queries
- [ ] Mobile 320px verified en `/admin/bookings/{id}`, `/admin/extra-guests`, list, gantt
- [ ] Tests pass (worker + web + shared)
- [ ] tsc clean en apps/web + apps/worker-bot + packages/shared
- [ ] biome lint clean (sin nuevos warnings)
- [ ] PR opened linking ADR-004 + this spec + smoke screenshots

---

## §7 · Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Beds24 `/v2/bookings/payments` endpoint shape diferente al asumido | medium | PRE-CHECK §5.1.2. Si fallido, document gap + ship sin payment-register endpoint (Karina usa Beds24 panel for now) |
| `/admin/inbox?conv=X` no soporta query param | medium | PRE-CHECK §5.1.1. Si NO, ship con links pero open issue separado para inbox support |
| Single big PR difícil de review | high | Detailed PR description + commits semánticos per component. Sub-headings en PR. Pre-merge self-review |
| Beds24 push fail silently → drift | medium | UI muestra `beds24_push_status='failed'` pill + error text. NO auto-retry. Karina escala manual |
| MP create-preference fail por amount muy bajo (MP min $20 MXN) | low | Validate min en client antes de fire. Display error si MP returns 4xx |
| ManyChat 92% fail rate aplica al outreach directo | high | Endpoint return 503 con warning para directos. Karina copia mensaje manual + envía via WhatsApp directo |
| Readiness formula muy strict → siempre 🔴 | medium | Calibrable post-Karina baseline (2-3 weeks). Si > 50% rojo después de Wave 1 → relax thresholds |
| Casa Chamán bookings exposed | low | WHERE clause filter en 3+ queries. Verify en PR diff |
| Bot futuro escribe a `booking_captures` antes de Karina UI ready | low | Schema permite multi-source. Bot future puede update sin breakage. updated_by column distingue |
| Outreach template variable substitution falla | medium | Tests con missing variables (default values). Log errors |
| Mobile UX en 3 tabs en 320px | medium | Tabs horizontal scroll en <480px. Cards stack vertical |
| Inline edit en extra-guests collisions con outreach actions existing | medium | New columns en separate <td>. Outreach buttons mantienen su pattern. Tests verify ambos |
| MP short URL conflict con bot's Patrón B URLs en `bot_short_links` | low | Slug prefix `pay-` distintivo. Existing pattern usa `precio-`, `info-`, etc |
| Performance hit en /admin/bookings list query con JOIN booking_captures | low | Index `idx_booking_captures_status` covers. Limit query a 200 rows. |

---

## §8 · Sequencing CC pickup

Single PR, 5 días estimado:

```
Día 1 (CC) — Foundation
  - Branch: feat/booking-detail-quick
  - Migration 0042 + 0043
  - Worker-bot endpoints (booking-captures GET/PUT + push-beds24)
  - Worker-bot endpoints (invoice-item + payment + invoice-snapshot + bill-text)
  - Worker-bot endpoints (outreach-templates GET/PUT/fire + conversation-link)
  - createMpPreference helper extract + existing payment-link.ts refactor
  - /api/admin/booking-payment-link new endpoint
  - Astro proxies para todos los worker endpoints

Día 2 (CC) — Page foundation
  - Astro page /admin/bookings/[id].astro + skeleton
  - BookingDetailView.tsx React island + tab nav
  - TabGeneral component (read-only)
  - TabCapturas component (form + LLM badges + save)
  - Readiness pill component
  - readiness.ts shared package + tests

Día 3 (CC) — Cargos & Pagos
  - TabCargos component (invoice items list + add + delete)
  - Manual payment registration form
  - MP link generator UI (cash split display + generate button)
  - Bill plain-text preview + copy button
  - Tests: mp.test.ts + booking-invoice.test.ts

Día 4 (CC) — Cross-cutting surfaces
  - /admin/extra-guests columnas nuevas + inline edit + LLM badges
  - /admin/extra-guests outreach template editor section
  - /admin/bookings?view=list "Listo" + "💬" columns
  - /admin/bookings?view=gantt stripe overlay + popup links
  - Conversation link helper integration
  - Tests: booking-captures.test.ts + outreach-templates.test.ts

Día 5 (CC) — Polish + PR
  - Mobile 320px verification (all 4 surfaces)
  - biome lint clean
  - tsc clean
  - Smoke test (17 steps) en staging local con prod D1 binding
  - Self-review diff
  - PR open con description detallado + screenshots

Día 6 (Alex)
  - Review PR (mobile-friendly description)
  - Apply migrations 0042 + 0043 a prod
  - Deploy worker-bot + apps/web
  - Smoke test prod con booking real
  - Merge si verde
  - Optional: Karina onboarding 15min al new flow
```

---

## §9 · Coordination

### Cross-references

| Workstream | Relación |
|---|---|
| Audit-2026-Q2-v2 Wave 1 polish | Este PR es additive, no conflicta. Wave 1 polish (kill placeholders, fix soft-404) puede ship en paralelo. |
| Audit Wave 0 P0 (welcome rebuild) | NO bloqueante. Booking detail funciona aunque welcome no se haya enviado (campo welcome_sent_at solo afecta readiness score, no breaking) |
| F-1 ManyChat fix workstream | Outreach a directos returns 503 hasta F-1 ship. Documented en UI warning |
| Thread/158 short_links | Reuse `bot_short_links` table. Slug prefix `pay-` distintivo |
| ADR-004 Karina-fication | Este PR encaja entre Wave 1 (polish) y Wave 2 (feedback) — operational capture layer |
| `vision/02-wishlist.md` M6/M7 | Post-ship, append M6 v1 status + M7 conceptual placeholder |

### Post-ship actions

1. WC append `vision/02-wishlist.md` con M6/M7 sections (~30min WC)
2. Alex: Karina onboarding 15min showing new `/admin/bookings/{id}` page
3. Alex: ajustar outreach unified template texto si Karina sugiere
4. WC: monitor `beds24_push_status='failed'` count semanal. Si > 5 / week → escalate sync queue spec (M-module)
5. WC: monitor readiness 🔴 distribution. Si > 50% rojo después de 2 semanas → relax formula thresholds

---

## §10 · Out of scope future iteration (M6/M7 modules)

Documentado en `vision/02-wishlist.md` post-ship:

- LLM autonomous extraction loop (auto-populate sugerencias from convs)
- Beds24 sync queue + observability cron
- Guest-facing /bill/{token} page con MP link embedded
- PDF generation
- Email send
- Multi-currency display
- Pre-arrival concierge workflow T-14d (cross-ref I1)
- M5 Tasks integration (event_type=birthday → spawn decoración task T-3d)
- Activity log + audit trail table
- Beds24 conflict resolution UI
- Multi-language captures
- Casa Chamán support post-Q3 launch
- Per-property servicios catalog (not just Morenas)
- Recurring guest auto-fill from previous bookings
- Bill viewed = signal payment imminent tracking
- Multiple outreach templates by scenario

---

**Spec sealed** por WC-Implementation 2026-05-22 ~10:00 UTC. Ready para CC pickup inmediato. Single PR. Estimated 4-5 días CC sólidos. NO bloqueado por nada. Pre-checks §5.1 obligatorios antes de PR open.
