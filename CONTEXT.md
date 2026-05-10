# Contexto verificado — Rincón del Mar

**Última verificación**: 2026-05-10 (Web Claude via Cloudflare + Make MCPs).

## Negocio

Vacation rentals en Pie de la Cuesta, Acapulco (Barrio Mágico desde 2024). Operación familiar de Alexander Horn, 9 años en Airbnb Superhost.

**Propiedades activas (4)**:
| Slug | Beds24 roomId | Capacidad base | Extra | Notas |
|---|---|---|---|---|
| `rincon-del-mar` | 78695 | 15 | $300/pax/noche | Premium, pie de playa, chef+cocinera+mozo incluidos |
| `las-morenas` | 374482 | 15 | $300/pax/noche | A 70m de playa, sin chef (opcional $1k-1.5k/día) |
| `huerta-cocotera` | 637063 | 4 | $200/pax/noche | Cabaña 1 hectárea, alberca infinity, animales |
| `combinada` | 74316 | 30 | $300/pax/noche | RdM + Morenas, linked availability, hasta 58-60 pax |

**Próxima (Q3 2026)**: `casa-chaman` (roomId 679176, base 15, $300/pax) en Punta Gorda. Renovación.

**Property ID 31862** en Beds24 agrupa todas.

**Canales**: WhatsApp (principal), Facebook, Instagram, TikTok, sitio web.

**Volumen estimado**: 30-100 turnos LLM/día, pico 500/día en temporada (puente del Grito, Navidad, Semana Santa).

## Stack actual (verificado MCPs)

### Cloudflare Workers desplegados

| Worker | Modified | Función |
|---|---|---|
| `rincon-pago` | 2026-05-09 | Sitio + flujo de booking web + MP webhook + auth magic link + Resend emails + 5 cron jobs |
| `rincon-tours` | 2026-05-10 | Sirve panoramas 360° (R2 ASSETS) |
| `reservar` | 2026-04-26 | Booking widget v1 (legacy) |
| `beds24-calendar` | 2026-04-26 | Lookup pre-existente |
| `airdm` | 2026-04-29 | Función desconocida |

### `rincon-pago` (lo más relevante)

Framework: Hono 4.12 + TypeScript + wrangler 3.91 + pnpm.

**Bindings deducidos del bundle**:
- `DB` — D1 database con tablas `bookings, users, verifications, magic_links, sessions` (y probablemente más).
- `KV_IDEMPOTENCY` — KV para idempotency del webhook MP.
- Secrets: `MP_ACCESS_TOKEN, MP_WEBHOOK_SECRET, RESEND_API_KEY, RESEND_FROM_DOMAIN, MAKE_CONFIRM_WEBHOOK_URL, SITE_URL`.

**Rutas activas**:
- `GET /health`
- `POST /webhook/mp` — HMAC SHA256, manifest `id:{paymentId};request-id:{x-request-id};ts:{ts};`, tolerance 300s, idempotency KV TTL 24h.
- `GET /exitoso`, `/fallido`, `/pendiente` — páginas post-pago renderizadas desde D1.

**Status de booking** (encontrados en SQL queries):
`hold` → `pending_payment` → `paid` → `confirmed` → `checked_in` → `completed`. Más: `cancelled, expired, refunded, failed`.

**Cron jobs** (5):
- `*/30 * * * *` — `expireHolds()` libera holds caducados, notifica Make para Beds24, manda email.
- `0 15 * * *` — `preArrivalReminder()` email 1 día antes del check-in.
- `0 17 * * *` — `reviewRequest()` email 3 días post check-out.
- `0 */6 * * *` — `authCleanup()` borra verifications/magic_links/sessions expiradas.
- `0 21 * * *` — `autoCheckinAndComplete()` actualiza status según fecha.

**Auth**: magic link via Resend. Tablas `verifications` (códigos), `magic_links` (tokens), `sessions` (cookies).

**Diseño tokens** (CSS inline emails y páginas):
- Primary `#0e6b7a` (teal)
- Bg `#fdfaf5` (cream)
- Gold `#c8a96e`
- Georgia serif para títulos, system-ui para body

**Puente híbrido actual**: el handler MP recibe pago → update D1 → POST a Make (`MAKE_CONFIRM_WEBHOOK_URL`) para que Make confirme en Beds24 (porque el booking de bot WhatsApp no existe en D1, solo en Beds24).

### Make.com (folder 316545)

Sigue activo para bots de mensajería:

| ID | Nombre | Función |
|---|---|---|
| 4706679 | `wh:bot-router` | Entry desde ManyChat, debounce, routing |
| 4716928 | `wh:bot-greeter` | LLM 2-stage (Haiku 4.5) + override_rule v4 + multi-room |
| 4724250 | `wh:bot-booker` | LLM 2-stage + hot-fix C + create_booking en Beds24 + MP link |
| 4704931 | `wh:tool-executor` | Wrapper Beds24 + MP |
| 4716901 | `sub:knowledge-refresh-core` | Refresh GitHub + Beds24 calendar cada 2h → DS + R2 |
| 4719360 | `cron:knowledge-refresh` | Trigger parent del refresh |
| 4709161 | `wh:mp-listener` | MP webhook legacy (compite con `/webhook/mp` del Worker) |
| 4709131 | `sub:mp-confirm-payment` | Confirma booking en Beds24 (llamado por Worker via MAKE_CONFIRM_WEBHOOK_URL) |

**Datastores Make**:
- 85638 `rdmbot_knowledge_v2` — prompts, calendar_lookup, calendar_text.
- 85639 `rdmbot_conversations_v2` — conversation history por subscriber.
- 85643 `rdmbot_secrets` — anthropic_api_key, github_pat, mp tokens, r2 credentials.
- 85380 `beds24_auth` — access + refresh tokens (auto-refresh cada 12h).

### Otros sistemas

- **ManyChat** — BSP para WhatsApp/FB/IG/TikTok. Custom fields `MakeMsg` (14495426), `bot_paused_until` (14543062), `rdmbot_agent` (14538317). Connection Make `__IMTCONN__` 4268288.
- **Anthropic API** — Haiku 4.5 con prompt caching. Key en DS 85643.
- **Beds24 API v2** — propertyId 31862. Token auto-refresh.
- **MercadoPago** — 33% depósito, resto en efectivo a la llegada. HMAC webhook secret rotado.
- **R2** — `rdm-knowledge` bucket (availability.json + prices.json refresh 2h).
- **GitHub** — `alexanderhorn6720/rdm-greeter-kb` privado (prompts + knowledge JSONs).
- **Resend** — emails transaccionales desde `email.rincondelmar.club`.

## Conflicto actual: dos fuentes de verdad para bookings

- **Booking via sitio web** → INSERT D1 `bookings` → MP preference con `external_reference = booking_id D1`.
- **Booking via bot WhatsApp** → POST Beds24 directo → MP preference con `external_reference = booking_id Beds24`.

Cuando entra webhook MP:
- Si `external_reference` es ID D1 → handler actualiza D1 inline ✅.
- Si `external_reference` es ID Beds24 → handler no lo encuentra en D1 → POST a Make para que Make confirme en Beds24 vía sub-scenario.

**Esta dualidad debe morir.** Toda la migración apunta a que bookings vivan en D1 como single source of truth, y Beds24 sea downstream (sync via webhooks o cron, no master).

## Bugs y deuda técnica actuales

1. `escapeJSON()` no funciona en Make `http:MakeRequest` → workaround Code module previo con `JSON.stringify()`. Fixed en Greeter v4 + Booker hot-fix C.
2. Booker Make en estado frágil tras varias iteraciones recientes (Greeter v4 + hot-fix C).
3. Property IDs duales (slugs en Worker, numéricos en Beds24/Make) sin tabla de mapping persistente.
4. Knowledge refresh duplicado: Make `sub:knowledge-refresh-core` corre paralelo a cualquier refresh nuevo del Worker (no existe aún).
5. `reservar.rincondelmar.club` legacy worker sigue desplegado, no claro si activo en producción.
6. Sin observabilidad consolidada: logs Worker en CF, logs Make en su UI, sin agregación.
7. Sin tests automatizados de bot.
8. Sin admin UI para editar prompts (todo via Make UI + GitHub).
9. Sin pricing dinámico (precios fijos manual en Beds24).

## KPIs actuales (estimados, no medidos)

- Latencia turno LLM p50 (Greeter Make): ~10s.
- Error rate Greeter post v4: ~2-5% (estimado).
- Error rate Booker post hot-fix C: a verificar con tests reales.
- Conversion bot WhatsApp → booking confirmado: desconocido (no instrumentado).
- Costo Make: $30-80/mes (varía).
- Costo Anthropic: ~$10-30/mes (con caching).
- Costo Cloudflare: ~$5-10/mes.
