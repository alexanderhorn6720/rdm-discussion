# Visión — arquitectura objetivo

Resumen ejecutivo. Cada decisión técnica vive en `decisions/`.

## Principios

1. **Cloudflare-native**. Todo el cómputo, storage, queues, workflows, edge sobre CF. Cero island solutions, cero workarounds para suplir features faltantes.
2. **Modular**. Monorepo Turborepo + pnpm con apps independientes y packages compartidos. Cada nuevo módulo (inventario, staff, chef) se añade como `apps/X` sin tocar lo existente.
3. **Single source of truth**. Bookings, conversaciones, clientes, inventario — todo vive en D1. Beds24, ManyChat, MercadoPago, Resend son downstream/integrations.
4. **Two-stage channels**. Stage 1: ManyChat como BSP (evitar cutover masivo). Stage 2: WhatsApp Cloud API direct + IG/FB/TT directos (sunset ManyChat).
5. **Migración gradual sin downtime**. Make.com se mantiene activo hasta que cada módulo Worker esté probado. Cutover por módulo, no big bang.
6. **Magic link unificado**. Un solo sistema de auth para clientes, staff y admin. Multi-rol.
7. **Build vs Buy disciplinado**. Para problemas estándar de la industria (pricing dinámico, broadcast WhatsApp, analytics) considerar SaaS antes que construir. Solo construir lo que da ventaja competitiva.
8. **Best industry stack 2026**: Hono + TypeScript + Turborepo + pnpm + Cloudflare Workers + D1 + KV + R2 + Queues + Workflows. React 19 + shadcn/ui + Tailwind + Vite para fronts. Anthropic Haiku/Sonnet para LLM.

## Stack

```
┌────────────────────────────────────────────────────────────────────┐
│  USUARIOS                                                          │
│  Cliente WA/FB/IG/TT · Cliente web · Staff · Admin (Alexander)     │
└──────┬──────────────────────┬────────────────────┬─────────────────┘
       │                      │                    │
       ▼                      ▼                    ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ ManyChat (BSP)  │  │ rincondelmar.club│  │ admin.rdm.club   │
│ Stage 1 only    │  │ apps/site        │  │ apps/admin (PWA) │
└────┬────────────┘  └────┬─────────────┘  └────┬─────────────┘
     │ Stage 2:           │                     │
     │ Meta Cloud API     │                     │
     │ direct             │                     │
     ▼                    ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  CLOUDFLARE WORKERS — monorepo apps                             │
│                                                                 │
│  apps/site    (rincondelmar.club)      ← sitio público          │
│  apps/bot     (bot.rincondelmar.club)  ← WA/FB/IG/TT agents     │
│  apps/admin   (admin.rincondelmar.club) ← Pages, React PWA      │
│  apps/api     (api.rincondelmar.club)  ← API gateway interno    │
│  apps/pricing (cron-only)              ← pricing agent           │
│  apps/webhooks (webhooks.rdm.club)     ← MP, Meta, Beds24       │
│                                                                 │
│  packages/db      ← D1 schema + Drizzle ORM + migrations        │
│  packages/shared  ← types, constants, utils                     │
│  packages/agents  ← LLM patterns (Greeter, Booker, Customer)    │
│  packages/channels ← WhatsApp, IG, FB, TT abstraction           │
│  packages/beds24  ← typed client + sync                         │
│  packages/mp      ← MercadoPago client                          │
│  packages/auth    ← magic link, sessions, multi-role            │
│  packages/ui      ← React components (admin + emails)           │
│                                                                 │
└──────┬───────────────┬───────────────┬─────────────┬────────────┘
       │               │               │             │
       ▼               ▼               ▼             ▼
┌────────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────┐
│ D1         │  │ KV         │  │ R2           │  │ Queues + │
│ all data   │  │ cache +    │  │ assets +     │  │ Workflows│
│ + drizzle  │  │ sessions + │  │ knowledge +  │  │ orchestr.│
│            │  │ debounce   │  │ logs         │  │          │
└────────────┘  └────────────┘  └──────────────┘  └──────────┘

       ▼
┌──────────────────────────────────────────────────────────┐
│  INTEGRACIONES EXTERNAS                                  │
│  Beds24 · MercadoPago · Anthropic · Resend · GitHub      │
│  PriceLabs (build vs buy)                                │
└──────────────────────────────────────────────────────────┘
```

## Apps (Workers + Pages)

| App | Tipo | Dominio | Función |
|---|---|---|---|
| `site` | Worker | `rincondelmar.club` | Sitio público + flujo de booking (hereda de `rincon-pago` actual) |
| `bot` | Worker | `bot.rincondelmar.club` | Agentes LLM para canales de mensajería |
| `admin` | Pages | `admin.rincondelmar.club` | UI React (PWA) — staff, admin, prompts, configs, bookings |
| `api` | Worker | `api.rincondelmar.club` | Endpoints internos compartidos (auth, search, etc.) |
| `pricing` | Worker (cron-only) | (no domain) | Pricing agent cron, push prices a Beds24 |
| `webhooks` | Worker | `webhooks.rincondelmar.club` | MP webhook, Meta webhook, Beds24 webhook (cuando exista) |
| `tours` | Worker | `tours.rincondelmar.club` | Sin cambios (panoramas 360°) |

**Decisión**: separar `webhooks` de `site` para reducir blast radius. El webhook MP de `site` actual se mueve a `webhooks`.

## Módulos futuros (post-migración)

Cada módulo es un `apps/X` adicional en el monorepo:

- `apps/inventory` — admin de inventario y compras.
- `apps/staff-tasks` — tasks del equipo (limpieza, mantenimiento, llegadas).
- `apps/chef` — recetas, insumos, platillos, menús.
- `apps/marketing` — broadcasts, campañas, segmentación.
- `apps/owner-dashboard` — si en el futuro Alexander hostea propiedades de terceros.

No los construimos ahora pero el monorepo, schema D1, auth, y design system los anticipan.

## Tres pilares de la migración

### Pilar 1 — Migrar bots Make → `apps/bot`

Greeter + Booker + Router → módulos TypeScript con override_rule v4 + hot-fix C portados intactos. Knowledge refresh → cron del Worker.

**Tiempo estimado**: 2-3 semanas.

### Pilar 2 — Admin board

`apps/admin` (React PWA + shadcn/ui + Tailwind) con:
- Bookings (CRUD).
- Conversaciones (read + take over).
- Prompts (editar override_rule, base prompt, deploy en vivo).
- Configs (precios base, min stay, capacidad, mascotas, etc.).
- Pricing (rules manuales y override de pricing agent).
- Staff y clientes (multi-rol con magic link).

**Tiempo estimado**: 3-4 semanas en paralelo con Pilar 1.

### Pilar 3 — Pricing agent

Cron Worker que cada 24h:
1. Lee occupancy histórica de D1 + Beds24.
2. Lee competidores (PriceLabs API o scraping ligero AirDNA / Airbnb).
3. Computa nuevos prices + min-stays con heurística (luego ML).
4. Push a Beds24.

**Decisión Build vs Buy**: ver `decisions/03-pricing-agent.md`. Recomendación inicial: usar **PriceLabs** ($19/listing/mes) para empezar, integrar via webhook + API, y construir capa propia encima si justifica. **Razón**: best industry tool, calibrado por mercado, evita 3-6 meses de ML.

**Tiempo estimado**: 2 semanas con PriceLabs, 3-6 meses build from scratch.

## Two-stage channels

### Stage 1 (semanas 0-12) — ManyChat se queda

- Webhook ManyChat → `apps/bot/webhook/manychat`.
- Custom fields se mantienen (MakeMsg, bot_paused_until, rdmbot_agent).
- Mensajes salientes via ManyChat API (SetCustomField + SendFlow).
- **Razón**: ya está pagado, opt-in registrado, templates aprobados, multi-canal funciona. Cutover masivo a Cloud API es riesgo alto que NO necesitamos en stage 1.

### Stage 2 (mes 4+) — WhatsApp Cloud API directo

- WABA propia con Meta Cloud API.
- Templates HSM gestionados en Meta Business Suite.
- Webhook directo a `apps/webhooks/whatsapp`.
- IG / FB / TT directo via Meta Graph API.
- Sunset ManyChat solo cuando feature parity al 100%.
- **Razón**: 30-60% menor TCO (Meta charges per conversation, ManyChat agrega markup), control total de templates y flows, soporte para WhatsApp Flows (formularios nativos).

Ver `decisions/02-channel-strategy.md` para detalle.

## Auth — magic link unificado

Una tabla `users` con `roles[]`. Magic link via Resend para clientes, staff y admin. Middleware `requireRole('admin')` en endpoints sensibles. Ver `decisions/05-auth-magic-link.md`.

## PWA / APK

`apps/admin` se construye desde día 1 como PWA (manifest.json, service worker, offline-capable). Cuando Alexander quiera, **Capacitor** wrappea la PWA en APK para Play Store. No es prioridad. Ver `decisions/07-pwa-mobile.md`.

## Orquestación: Workflows + Queues en lugar de Make

Make.com se usa para:
1. Llamadas a Beds24 (refresh, get, post).
2. Conversaciones LLM 2-stage.
3. MP webhook handling.
4. Knowledge refresh cron.

**Reemplazo nativo CF**:
- **Cloudflare Workflows** — orquestación durable multi-step (replaza scenarios complejos Make). Ejemplos: pricing pipeline (fetch competitors → compute → push → notify), confirmar booking (D1 update → Beds24 PUT → email → ManyChat notify), retry con backoff exponencial.
- **Cloudflare Queues** — fan-out async, buffering, dead letter queue (replaza patterns de cola en Make). Ejemplos: outbound messages, image processing, analytics events.
- **Cron Triggers** — schedules (replaza Make cron). Ya en uso para `rincon-pago`.
- **Durable Objects** — state coordinado (debounce 8s per subscriber, locks anti-double-booking).

Ver `decisions/08-orchestration.md`.

## Lo que NO cambia

- Anthropic Haiku 4.5 + prompt caching.
- Override_rule v4 + hot-fix C (probados, portados intactos).
- HMAC SHA256 webhook MP (ya implementado bien).
- Resend para emails.
- Knowledge files en GitHub raw (sync cron a KV).
- Property slugs (`rincon-del-mar`, etc) como public identifiers.
- Mapping property slug → Beds24 roomId (pasa a tabla D1 `properties`).
- Diseño tokens del sitio (`#0e6b7a`, `#fdfaf5`, etc.).

## Métricas objetivo

| Métrica | Actual (estimado) | Objetivo |
|---|---|---|
| Latencia LLM p50 | ~10s | < 2s |
| Error rate Greeter | ~5% | < 1% |
| Bookings con full trazabilidad D1 | ~50% (solo web) | 100% |
| Costo plataforma mensual | ~$60 (Make+CF+Resend) | < $40 (sunset Make) |
| Time to deploy fix | 10-30 min | < 2 min |
| Test coverage paths críticos | 0% | > 60% |
| Conversion bot→booking | desconocido | medido + > 15% |
| Modules adicionales para añadir | 1 por mes en stack actual | 1 por semana en stack nuevo |

## Roadmap macro

| Fase | Duración | Output |
|---|---|---|
| 0 — Setup monorepo | 1 sem | Turborepo + packages + wrangler configs |
| 1 — Apps `bot` + `pricing` + `webhooks` | 4 sem | Bots migrados + pricing live + webhooks consolidados |
| 2 — App `admin` | 4 sem | PWA con prompt editor + bookings + roles |
| 3 — Stage 2: WhatsApp Cloud API directo | 3 sem | Sunset ManyChat |
| 4 — Hardening + observability | 2 sem | Logs, metrics, alerting |
| 5 — Futuros módulos | continuo | Inventory, staff, chef on demand |

Total fase 0-4: ~14 semanas de trabajo concentrado.

Detalle en `ROADMAP.md`.
