# Visión — arquitectura objetivo (v2)

**Actualizada 2026-05-11** con correcciones CC + decisiones Alex (thread 01).

Resumen ejecutivo. Cada decisión técnica vive en `decisions/`.

## Principios

1. **Cloudflare-native** donde encaja, **CF Pages para Astro** donde aplica. Stack uniformemente CF, sin AWS/GCP.
2. **Modular**. Monorepo Turborepo + pnpm con apps independientes y packages compartidos.
3. **Single source of truth**. Bookings, conversaciones, clientes — todo D1. Beds24, ManyChat, MercadoPago, Resend son downstream/integrations.
4. **Two-stage channels**. Stage 1: ManyChat BSP. Stage 2: WhatsApp Cloud API direct + IG/FB/TT direct.
5. **Migración gradual sin downtime**. Make.com activo hasta cada módulo Worker probado. Cutover por módulo.
6. **Magic link + WhatsApp OTP unificado**. Better Auth extendido. Multi-rol.
7. **Build vs Buy disciplinado**. Para pricing, NO PriceLabs — agente custom existente ya superior.
8. **Best industry stack 2026**: Hono + TS + Turborepo + pnpm + Workers + D1 + KV + R2 + Queues + Workflows + Astro 5 (sitio) + React 19 + shadcn + TanStack (admin).

## Stack final

```
┌────────────────────────────────────────────────────────────────────┐
│  USUARIOS                                                          │
│  Cliente WA/FB/IG/TT · Cliente web · Staff · Admin (Alexander)     │
└──────┬──────────────────────┬────────────────────┬─────────────────┘
       │                      │                    │
       ▼                      ▼                    ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ ManyChat (BSP)  │  │ rincondelmar.club│  │ admin.rdm.club   │
│ Stage 1 only    │  │ apps/site (Astro)│  │ apps/admin (PWA) │
└────┬────────────┘  └────┬─────────────┘  └────┬─────────────┘
     │ Stage 2:           │                     │
     │ Meta Cloud API     │                     │
     │ direct             │                     │
     ▼                    ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  CLOUDFLARE — monorepo                                          │
│                                                                 │
│  apps/site       Astro 5 en Pages   rincondelmar.club           │
│  apps/bot        Worker             bot.rincondelmar.club       │
│  apps/admin      Worker Static      admin.rincondelmar.club     │
│  apps/api        Worker             api.rincondelmar.club       │
│  apps/pricing    Worker cron        (no public domain)          │
│  apps/webhooks   Worker             webhooks.rincondelmar.club  │
│  apps/tours      Worker             tours.rincondelmar.club     │
│  apps/disponibilidad Worker         disponibilidad.r.club       │
│  apps/worker-pago (legacy hasta migración páginas /pago)        │
│                                                                 │
│  packages/db          Drizzle schema + migrations               │
│  packages/auth        Better Auth + multi-role + WA OTP plugin  │
│  packages/agents      LLM patterns (Greeter, Booker, Pricing)   │
│  packages/channels    WA, IG, FB, TT abstraction                │
│  packages/beds24      typed client + sync                       │
│  packages/mp          MercadoPago client + HMAC                 │
│  packages/email-templates  React Email + HTML inline fallback   │
│  packages/llm-client  Anthropic wrapper con caching             │
│  packages/pricing-agent  port intacto del Make scenario         │
│  packages/shared      types, constants, utils                   │
│  packages/ui          React components (admin)                  │
│                                                                 │
└──────┬───────────────┬───────────────┬─────────────┬────────────┘
       │               │               │             │
       ▼               ▼               ▼             ▼
┌────────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────┐
│ D1 `rincon`│  │ KV         │  │ R2           │  │ Queues + │
│ all data   │  │ idempotency│  │ rdm-knowledge│  │ Workflows│
│ + drizzle  │  │ + cache    │  │ + assetsrdm  │  │ Sprint 3+│
│ 10 tablas+ │  │            │  │              │  │          │
└────────────┘  └────────────┘  └──────────────┘  └──────────┘

       ▼
┌──────────────────────────────────────────────────────────┐
│  INTEGRACIONES EXTERNAS                                  │
│  Beds24 · MercadoPago · Anthropic · Resend · GitHub      │
│  Meta Graph API (Stage 2)                                │
└──────────────────────────────────────────────────────────┘
```

## Apps (Workers + Pages)

| App | Tipo | Dominio | Función | Sprint |
|---|---|---|---|---|
| `site` | **CF Pages (Astro 5)** | `rincondelmar.club` | Sitio público + flujo booking + páginas /pago/* | Existe |
| `bot` | Worker | `bot.rincondelmar.club` | Agentes LLM (Greeter v5, Booker hot-fix C) | **MVP1** |
| `admin` | Worker Static Assets | `admin.rincondelmar.club` | UI React PWA — staff, admin, prompts, configs | Sprint 2 |
| `api` | Worker | `api.rincondelmar.club` | Endpoints internos compartidos | Sprint 2-3 |
| `pricing` | Worker (cron) | (no domain o `api.r.club/pricing/*`) | Port pricing agent + approve/reject | Sprint 3 |
| `webhooks` | Worker | `webhooks.rincondelmar.club` | MP webhook (extract de worker-pago), Meta webhook, Beds24 webhook | Sprint 3 |
| `tours` | Worker | `tours.rincondelmar.club` | Panoramas 360° (sin cambios) | Existe |
| `disponibilidad` | Worker | `disponibilidad.rincondelmar.club` | Visor calendar público (renombrado de `beds24-calendar`) | Sprint 4 |
| `worker-pago` | Worker | `pago.rincondelmar.club` (deprecará) | Legacy hasta `pago/*` migration | Sprint 1 cleanup |

**`apps/web` permanece en CF Pages, NO migra a Workers Static Assets.** Astro 5 + adapter cloudflare es excelente en Pages. Workers Static Assets es solo SPA + custom code — perderíamos SSR routes + content collections + sitemap auto-gen.

## Decisión clave: `apps/site` = `apps/web` actual

CC en thread/00 corrigió: **NO migrar Astro a Workers Static Assets**. Rename a `apps/site` opcional (semántica). Mantener stack Astro 5 + CF Pages.

Las SSR routes (`/api/quote`, `/api/payment-link`, `/api/contact`, etc.) quedan dentro de `apps/site`. `apps/api` solo cuando admin board lo requiera (Sprint 2-3).

## Módulos futuros (post-Sprint 4)

Cada uno `apps/X` adicional en monorepo:

- `apps/inventory` — admin inventario y compras
- `apps/staff-tasks` — tasks limpieza/mantenimiento/llegadas
- `apps/chef` — recetas, insumos, platillos, menús
- `apps/marketing` — broadcasts WhatsApp Stage 2
- `apps/owner-dashboard` — si Alex hostea propiedades terceros

NO se construyen ahora pero monorepo + schema D1 + auth + design system los anticipan.

## Tres pilares de la migración

### Pilar 1 — Migrar bots Make → `apps/bot` (MVP1, 1 semana)

Greeter v5 + Booker hot-fix C porteados intactos a TypeScript. Channel abstraction layer Stage 1 (ManyChat). Knowledge refresh cron 2h al KV.

**Sprint 1 (MVP1)**: bot.rincondelmar.club live, Make scenarios fallback 1 semana.

### Pilar 2 — Admin board (Sprint 2-3, ~4 semanas)

`apps/admin` PWA con:
- Bookings (CRUD)
- Conversaciones (read + take over)
- Prompts (editar override_rule, base prompt, deploy en vivo)
- Configs (precios base, min stay, capacidad, mascotas)
- Pricing (rules + override + history)
- Staff y clientes (multi-rol)

Reemplaza los admin scenarios de Make (`wh:admin-dashboard`, `wh:admin-action`, etc).

### Pilar 3 — Pricing agent port (Sprint 3-4, ~2 semanas)

Port intacto `cron:pricing-daily` Make → `apps/pricing` Worker.

**NO PriceLabs. NO build from scratch. Port custom sofisticado existente.** (Ver decisions/03.)

## Two-stage channels

### Stage 1 (mes 0-3) — ManyChat se queda

- ManyChat webhook → `apps/bot/webhook/manychat`
- Custom fields se mantienen (MakeMsg, bot_paused_until, rdmbot_agent)
- Templates HSM existentes
- WhatsApp OTP via HSM template `rdm_otp` si aprobado (decisión Alex pending)

### Stage 2 (mes 4+) — WhatsApp Cloud API direct

- WABA propia con Meta Cloud API
- Templates HSM gestionados en Meta Business Manager
- IG/FB/TT directo via Meta Graph API
- Sunset ManyChat post-coexistence 2-4 sem
- **Cost note**: Meta charges $0.04-0.10/conv en MX. Estimar $40-100/mes adicional según volumen.

Ver decisions/02-channel-strategy.md.

## Auth — Better Auth extendido (NO custom)

CC corrección: Better Auth 1.6.9 ya en producción.

`packages/auth`:
- Better Auth wrapper config con Drizzle adapter
- Plugin: WhatsApp OTP custom (Stage 1 via ManyChat HSM si template aprobado, Stage 2 via Cloud API)
- Tabla `user_roles` para multi-rol
- Tabla `user_identities` para vincular WA/IG/FB/TT con email
- Cookie `Domain=.rincondelmar.club` cross-app

Ver decisions/05-auth-magic-link.md.

## PWA / APK

`apps/admin` PWA día 1 (vite-plugin-pwa). APK via Capacitor 6-12 meses post-PWA si justifica.

Ver decisions/07-pwa-mobile.md.

## Orquestación: Workflows + Queues (Sprint 3+)

NO en MVP1. Reemplazo gradual de Make:
- Knowledge refresh → cron CF (Sprint MVP1)
- MP webhook → Worker `apps/webhooks` (Sprint 3, hoy es `worker-pago`)
- Greeter/Booker → Workers con DO debounce (Sprint MVP1)
- Booking creation → Workflow (Sprint 3)
- Pricing → Worker cron (Sprint 3-4)

Ver decisions/08-orchestration.md.

## Lo que NO cambia

- Anthropic Haiku 4.5 (Greeter, Booker) + Sonnet 4.5 (Pricing) + prompt caching
- Override_rule v5 + Booker hot-fix C (portados intactos)
- HMAC SHA256 webhook MP (ya implementado bien)
- Resend para emails
- Knowledge files en GitHub raw (sync cron a KV/R2)
- Property slugs (`rincon-del-mar`, etc) como public identifiers
- Mapping property slug → Beds24 roomId (pasa a tabla D1 `properties`)
- Diseño tokens del sitio (`#0e6b7a`, `#fdfaf5`, `#c8a96e`)
- **Astro 5 + CF Pages para `apps/site`** (no migrar a Workers Static Assets)

## Métricas objetivo

| Métrica | Actual (estimado) | Objetivo MVP1 | Objetivo Sprint 5 |
|---|---|---|---|
| Latencia LLM p50 | ~10s | < 3s | < 2s |
| Error rate Greeter | ~10% (75/722) | < 5% | < 1% |
| Error rate Booker | ~47% (30/63) | < 10% | < 1% |
| Bookings con full trazabilidad D1 | ~50% (solo web) | 100% (incluye WA) | 100% |
| Costo Make.com mensual | $30-80 | $30-80 (paralelo MVP1) | $0 (sunset Fase 5) |
| Costo Anthropic mensual | $10-30 | $10-30 | $10-30 |
| Costo Cloudflare Workers Paid | $0 (free tier) | $5/mes | $5-10/mes |
| Costo Stage 2 Meta Cloud API | N/A | N/A | $40-100/mes |
| **TOTAL** mensual | $40-110 | $45-115 | $55-150 |
| Time to deploy fix | 10-30 min | < 5 min | < 2 min |
| Test coverage paths críticos | 0% | 30% | > 60% |

## Roadmap macro

| Fase | Duración | Output |
|---|---|---|
| MVP1 — `apps/bot` + `pago/*` migration | 1 sem | Bots migrados, pago landing pages en site |
| Sprint 2 — `apps/admin` + auth roles | 4 sem | PWA admin, multi-rol |
| Sprint 3 — `apps/pricing` + `apps/webhooks` | 3-4 sem | Pricing port, MP consolidado |
| Sprint 4 — `apps/disponibilidad` + hardening | 2 sem | Visor consolidado, observability |
| Fase 5 — Sunset Make + Stage 2 WA Cloud | 4-6 sem | $0 Make bill, Cloud API direct |
| Módulos futuros | continuo | Inventory, staff, chef on demand |

Detalle en `ROADMAP.md`.
