# Contexto verificado — Rincón del Mar

**Última verificación**: 2026-05-11 (Web Claude via Cloudflare + Make MCPs, post-CC corrections).

## Negocio

Vacation rentals en Pie de la Cuesta, Acapulco (Barrio Mágico desde 2024). Operación familiar de Alexander Horn, 9 años en Airbnb Superhost.

**Propiedades activas (5 roomIds)**:
| Slug | Beds24 roomId | Capacidad base | Extra | Notas |
|---|---|---|---|---|
| `rincon-del-mar` | 78695 | 15 | $300/pax/noche | Premium, pie de playa, chef+cocinera+mozo incluidos |
| `las-morenas` (direct) | 374482 | 15 | $300/pax/noche | A 70m de playa, sin chef (opcional $1k-1.5k/día) |
| `las-morenas-airbnb` | 74322 | 15 | $300/pax/noche | Mismo property, diferente listing (Airbnb) |
| `huerta-cocotera` | 637063 | 4 | $200/pax/noche | Cabaña 1 hectárea, alberca infinity, animales |
| `combinada` | 74316 | 30 | $300/pax/noche | RdM + Morenas, linked availability, hasta 58-60 pax |

**Próxima (Q3 2026)**: `casa-chaman` (roomId 679176, base 15, $300/pax) en Punta Gorda. Renovación.

**Property ID 31862** en Beds24 agrupa todas.

**Canales**: WhatsApp (principal), Facebook, Instagram, TikTok, sitio web.

**Volumen estimado**: 30-100 turnos LLM/día, pico 500/día en temporada (puente del Grito, Navidad, Semana Santa).

## Stack actual (verificado via MCPs)

### Cloudflare Workers desplegados (5)

| Worker | Status | Función | Acción Fase 0 |
|---|---|---|---|
| `rincon-pago` | Activo (2026-05-09) | Hono + TS. MP webhook + auth magic link + Resend + 5 cron jobs | Mover a `apps/worker-pago` |
| `rincon-tours` | Activo (2026-05-10) | Vanilla TS. Panoramas 360° desde R2 `assetsrdm` | Mover a `apps/worker-tours` |
| `airdm` | Activo (2026-04-29) | Proxy OpenAI ↔ Anthropic con auto prompt caching. Status uso incierto | Verificar uso → decommission si no |
| `reservar` | Activo (2026-04-26) | Booking flow standalone con placeholders. Nunca terminado | **Decommission** |
| `beds24-calendar` | Activo (2026-04-26) | Sirve `disponibilidad.rincondelmar.club` (visor público). Usado por bot | **Keep**, mover a `apps/disponibilidad` Sprint 4 |

### Cloudflare Pages (1)

| Project | Stack | Dominio |
|---|---|---|
| `apps/web` | **Astro 5.18.1 + React 19.2.6 islands** + adapter cloudflare 12.6.7 | `rincondelmar.club` |

**Importante**: `apps/web` NO migra a Workers Static Assets. Stays en CF Pages para preservar SSR routes + content collections + sitemap auto-gen.

### `apps/web` (Astro) — detalle

- Astro 5.18.1 + adapter cloudflare 12.6.7 (static + SSR)
- React 19.2.6 (islands)
- Drizzle ORM 0.45.2 (schema en `apps/web/src/lib/db-schema.ts`)
- **Better Auth 1.6.9** ya integrado (`apps/web/src/lib/auth.ts`)
- Vitest 2.1.8 + happy-dom 15.11.7
- Wrangler 3.91.0 + compatibility_date `2026-04-15` + `nodejs_compat_v2`
- Biome 1.9.4 lint/format
- TypeScript 5.6.3 strict
- pnpm 9.12.3 workspaces

SSR routes en `apps/web/src/pages/api/*`: `/quote, /payment-link, /contact, /waitlist, /auth/*, /booking/hold, /r/click, /tour-tracking`.

### `apps/worker-pago` (Hono) — detalle

- Hono 4.12 + TS + Wrangler
- Bindings: `DB → rincon`, `KV_IDEMPOTENCY`
- Secrets: `MP_ACCESS_TOKEN, MP_WEBHOOK_SECRET, RESEND_API_KEY, RESEND_FROM_DOMAIN, MAKE_CONFIRM_WEBHOOK_URL, SITE_URL`

Routes: `GET /health`, `POST /webhook/mp` (HMAC SHA256 + idempotency KV TTL 24h), `GET /exitoso, /fallido, /pendiente`.

**Decisión `pago.*` migration**: Alexander confirmó migrar a `rincondelmar.club/pago/{exitoso,fallido,pendiente}` (Sprint 1).

Cron jobs (5):
- `*/30 * * * *` — `expireHolds()` libera holds caducados
- `0 15 * * *` — `preArrivalReminder()` email 1 día antes
- `0 17 * * *` — `reviewRequest()` email 3 días post
- `0 */6 * * *` — `authCleanup()` borra verifications/magic_links/sessions expiradas
- `0 21 * * *` — `autoCheckinAndComplete()` actualiza status

Status enum: `hold → pending_payment → paid → confirmed → checked_in → completed`. Más: `cancelled, expired, refunded, failed`.

Diseño tokens: `#0e6b7a` (teal), `#fdfaf5` (cream), `#c8a96e` (gold). Georgia + system-ui.

### D1 (1 database)

| Database | UUID | Tablas |
|---|---|---|
| `rincon` | `d81622d7-32e2-40a3-9609-80813c0e8a96` | 10 + `d1_migrations` |

Tablas (verificadas via MCP):
`accounts, bookings, linktree_clicks, magic_links, quote_requests, sessions, tour_views, users, verifications, waitlist`.

Migrations 0001-0008 documentadas en `migrations/`.

### KV namespaces

| Worker | KV |
|---|---|
| `worker-pago` | `KV_IDEMPOTENCY` (`b3035e701ce1492e829f1224d85bc545`) |

A futuro: `KV_KNOWLEDGE` (refresh 2h cron), `KV_SESSIONS_CACHE` (opcional).

### R2 buckets

| Bucket | Uso |
|---|---|
| `rdm-knowledge` | KB del bot (availability.json, prices.json, prompts) |
| `assetsrdm` | Panoramas 360° para `worker-tours` |

## Make.com (folder 316545 + otros)

**34 scenarios totales, 21 activos**.

### Bot pipeline (CRITICAL — migran a `apps/bot` en MVP1)

| ID | Name | Función | Stats |
|---|---|---|---|
| 4706679 | `wh:bot-router` | Entry ManyChat, debounce, routing | 2635 exec, 65 err |
| 4716928 | `wh:bot-greeter` | LLM 2-stage Greeter v5 + override_rule v5 + multi-room | 722 exec, 75 err |
| 4724250 | `wh:bot-booker` | LLM 2-stage Booker hot-fix C + create_booking + MP link | 63 exec, 30 err |
| 4704931 | `wh:tool-executor` | Wrapper Beds24+MP para bot | 50 exec, 2 err |

### Knowledge pipeline (cron)

| ID | Name |
|---|---|
| 4719360 | `cron:knowledge-refresh` cada 2h |
| 4719361 | `wh:knowledge-refresh` 15min |
| 4716901 | `sub:knowledge-refresh-core` (R2 SigV4 manual) |

### Beds24 auth

| ID | Name |
|---|---|
| 4704705 | `cron:beds24-token-refresh` cada 12h |

### MP webhooks (dual con Worker)

| ID | Name |
|---|---|
| 4709161 | `wh:mp-listener` (HMAC + idempotency) |
| 4723238 | `wh:mp-pages` (deprecará con `rincondelmar.club/pago/*`) |

### Pricing pipeline (PR3 — sofisticado)

| ID | Name | Detalle |
|---|---|---|
| 4718358 | `cron:pricing-daily` | Sonnet 4.5 + 100+ líneas reglas. Hard validator. Email approval rich HTML |
| 4719127 | `wh:pricing-approve` | Aplica changes a Beds24 |
| 4719128 | `wh:pricing-reject` | Marca rechazado |

**No es "simple"**: minStay matrix 5×5×4, anti-orphan, last-minute discounts -5% a -25%, floor/ceiling per roomId, prices múltiplos de 250. Port intacto a `apps/pricing` Sprint 3, **no rewrite, no buy PriceLabs**.

### Admin pipeline (PR3 — CC ya construyó)

| ID | Name | Función |
|---|---|---|
| 4721276 | `wh:admin-dashboard` | API dashboard |
| 4721587 | `wh:admin-assets` | Sirve assets admin |
| 4721249 | `wh:admin-action` | Pause bot, etc. |
| 4721731 | `wh:admin-send-msg` | Admin manual msg |

Sprint 2 migra a `apps/admin` PWA, NO greenfield.

### Test scenarios (preserve)

| ID | Name |
|---|---|
| 4723301 | `_e2e_test` (Greeter) |
| 4724261 | `_e2e_test_booker` |

### Inactivos / legacy (~18 scenarios)

Bot legacy (`_deprecated:bot-greeter-v1`, `wh:bot-booker-v2-OLD`, `_deprecated:beds24-*`), `sub:mp-confirm-payment` (invalidado), utilities, viejos 2022 (Bodas, Mercadolibre, Android social media). **Fase 5 cleanup**.

### Datastores Make

- 85638 `rdmbot_knowledge_v2` — prompts, calendar_lookup, calendar_text
- 85639 `rdmbot_conversations_v2` — conversation history
- 85643 `rdmbot_secrets` — anthropic_api_key, github_pat, mp tokens, r2 creds
- 85380 `beds24_auth` — access + refresh tokens
- 85677 `pricing_proposals` — changes pendientes de approve

## Otros sistemas

- **ManyChat** — BSP. Custom fields `MakeMsg` (14495426), `bot_paused_until` (14543062), `rdmbot_agent` (14538317). Connection 4268288.
- **Anthropic API** — Haiku 4.5 con prompt caching.
- **Beds24 API v2** — propertyId 31862.
- **MercadoPago** — 33% depósito, resto efectivo. HMAC rotado.
- **GitHub** — `alexanderhorn6720/rdm-greeter-kb` (KB) + `rincondelmar-bot` (código privado).
- **Resend** — emails desde `email.rincondelmar.club`.

## Conflicto actual: dos fuentes de verdad para bookings

- Booking web → INSERT D1 `bookings` → MP `external_reference = D1 id`.
- Booking bot WA → POST Beds24 directo → MP `external_reference = Beds24 id`.

Webhook MP:
- D1 id → handler actualiza D1 ✅
- Beds24 id → POST a Make `MAKE_CONFIRM_WEBHOOK_URL` para confirm Beds24

**Dualidad muere** en MVP1+ cuando `apps/bot` INSERT D1 first. D1 = single source of truth.

## Bugs y deuda actuales

1. `escapeJSON()` no funciona en Make `http:MakeRequest` → workaround Code module previo. Fixed.
2. Booker Make estado frágil tras iteraciones. Greeter v5 deployed 2026-05-11.
3. Property IDs duales (slugs vs numéricos) sin tabla mapping persistente.
4. **Dual MP handler activo**: Worker `rincon-pago` + Make `wh:mp-listener`. Cuál es autoritativo necesita verificación.
5. `reservar.rincondelmar.club` legacy worker activo pero incompleto. Decommission Sprint 0.
6. Sin observabilidad consolidada.
7. Sin tests automatizados (excepto los 100 ad-hoc local + e2e scenarios Make).
8. Pricing agent error rate 45% (22 exec, 10 err). Debug durante port.
9. `airdm` Worker uso incierto.

## KPIs (estimados)

- Greeter Make latency p50: ~10s
- Greeter error rate post-v5: ~10% (75/722)
- Booker error rate post-hot-fix C: ~47% (30/63) — alto, verificar
- Conversion bot WA → booking: desconocido
- Costo Make: ~$30-80/mes
- Costo Anthropic: ~$10-30/mes
- Costo Cloudflare: ~$5-10/mes
- Future Stage 2: Meta Cloud API $0.04-0.10/conv = $40-100/mes adicionales MX
