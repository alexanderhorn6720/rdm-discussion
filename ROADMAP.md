# Roadmap

**Última actualización**: 2026-05-10
**Status**: Borrador. Esperando votos en `decisions/*.md` antes de commitments duros.

Estimaciones asumen Claude Code + Alexander part-time (~20h/sem) + Web Claude support continuo.

## Resumen visual

```
Mes 1            Mes 2            Mes 3            Mes 4            Mes 5            Mes 6
│                │                │                │                │                │
├─ Fase 0 ──────►│                │                │                │                │
│  monorepo      │                │                │                │                │
│                ├─ Fase 1 ──────►│                │                │                │
│                │  apps/bot      │                │                │                │
│                │  apps/webhooks │                │                │                │
│                │  apps/pricing  │                │                │                │
│                │                ├─ Fase 2 ──────►│                │                │
│                │                │  apps/admin    │                │                │
│                │                │                ├─ Fase 3 ──────►│                │
│                │                │                │  Stage 2 WA    │                │
│                │                │                │  Cloud API     │                │
│                │                │                │                ├─ Fase 4 ──────►│
│                │                │                │                │  hardening     │
│                │                │                │                │                ├─ módulos
│                │                │                │                │                │  futuros
```

## Fase 0 — Setup monorepo (semana 1-2)

**Owner**: Claude Code.
**Output**: Monorepo Turborepo + pnpm operativo con `apps/site` migrado del Worker actual.

### Entregables

- [ ] Branch `chore/monorepo` en `rincondelmar-bot`.
- [ ] Estructura `apps/`, `packages/`, `tooling/`.
- [ ] `pnpm-workspace.yaml`, `turbo.json`, root `package.json`.
- [ ] `packages/tsconfig`, `packages/eslint-config`.
- [ ] `packages/db` con Drizzle ORM + schema actual (`bookings, users, verifications, magic_links, sessions`).
- [ ] `packages/shared` con types comunes.
- [ ] `apps/site` = código actual de `rincon-pago` movido sin cambios funcionales.
- [ ] `apps/tours` = código actual de `rincon-tours`.
- [ ] CI básico con GitHub Actions: lint + typecheck + deploy filtered.
- [ ] Merge a main, deploy verifica que `rincondelmar.club` sigue funcionando.

**Riesgos**:
- Romper deploy actual al refactorear. Mitigación: blue-green deploy via Wrangler versions.

## Fase 1 — apps/bot + apps/webhooks + apps/pricing (semana 3-6)

**Owner**: Claude Code, soporte Web Claude.
**Output**: Bots migrados de Make a Worker, MP webhook consolidado, pricing live.

### Entregables

- [ ] `packages/agents/greeter` con port intacto del bot Greeter v4 (override rule v4 + multi-room + escapeJSON-free).
- [ ] `packages/agents/booker` con port intacto del Booker hot-fix C.
- [ ] `packages/channels/manychat` — provider Stage 1.
- [ ] `packages/beds24` — typed client.
- [ ] `packages/mp` — typed client (extraído de `apps/site`).
- [ ] `apps/bot` con routes `/webhook/manychat`, `/internal/booker`, `/health`.
- [ ] `apps/bot` con cron `0 */2 * * *` para knowledge refresh.
- [ ] `apps/webhooks` con `/webhook/mp` (extraído de `apps/site`), HMAC + idempotency.
- [ ] `apps/webhooks` con `/webhook/beds24` skeleton (cuando activemos).
- [ ] `apps/pricing` con cron diario + integración PriceLabs.
- [ ] D1 schema migrations: `conversations`, `bot_idempotency`, `user_roles`, `user_identities`.
- [ ] Tests: 7 QA cases Greeter, casos Booker, HMAC validation MP.
- [ ] Cutover gradual via ManyChat % traffic.

**Riesgos**:
- Regression vs Make. Mitigación: run paralelo 1 semana, comparar outputs.
- PriceLabs integration delays. Mitigación: empezar contacto comercial PriceLabs día 1.

## Fase 2 — apps/admin (semana 5-10, en paralelo con Fase 1)

**Owner**: Claude Code, soporte Web Claude para diseño UX.
**Output**: PWA admin board operativo.

### Entregables

- [ ] `packages/auth` extraído de `apps/site`, agregar `user_roles`.
- [ ] `packages/ui` con shadcn components base + design tokens.
- [ ] `apps/admin` con stack React 19 + Vite + TanStack + shadcn.
- [ ] PWA manifest + service worker via vite-plugin-pwa.
- [ ] Rutas: `/login`, `/`, `/bookings`, `/conversations`, `/prompts`, `/properties`, `/pricing`, `/staff`, `/settings`.
- [ ] Prompt editor con Monaco + diff + deploy a KV.
- [ ] Inbox de conversaciones (read-only Stage 1, take-over Stage 2).
- [ ] Pricing override calendar view.
- [ ] Roles + permisos en middleware.
- [ ] Cookie scope `.rincondelmar.club` para SSO entre site/admin.
- [ ] Deploy a `admin.rincondelmar.club`.

**Riesgos**:
- Scope creep en UI. Mitigación: MVP estricto, polish iterativo.

## Fase 3 — Stage 2: WhatsApp Cloud API directo (semana 11-13)

**Owner**: Claude Code + Alexander (verificación Meta Business).
**Output**: ManyChat sunset para WhatsApp. IG/FB/TT migrados eventualmente.

### Entregables

- [ ] WABA propia creada y verificada en Meta Business Manager.
- [ ] Templates HSM aprobados directamente con Meta (re-approve los actuales de ManyChat).
- [ ] `packages/channels/whatsapp-cloud` con typed client Cloud API.
- [ ] `apps/webhooks/whatsapp` con signature verification.
- [ ] Inbox UI completo en `apps/admin/conversations` (reemplaza ManyChat inbox).
- [ ] Opt-in migration: export ManyChat, validate consent records.
- [ ] Coexistence period 2-4 sem (WhatsApp en Cloud, IG/FB en ManyChat).
- [ ] Sunset ManyChat para WhatsApp.

**Decisiones pendientes**:
- IG/FB/TT migration timing (probablemente Fase 5).
- WhatsApp Flows adoption (formularios nativos booking).

**Riesgos**:
- Meta verification delays (1-2 semanas típico).
- Template re-approval delays.
- Opt-in compliance.

## Fase 4 — Hardening + observability (semana 14-15)

**Owner**: Claude Code.
**Output**: Production-ready con observability completa.

### Entregables

- [ ] Logpush a R2 para retención long-term.
- [ ] Workers Analytics Engine para metrics custom.
- [ ] Alerting via email (Resend) para: error rate > threshold, latency p95 > threshold, queue DLQ events.
- [ ] Audit log de admin actions en D1.
- [ ] Rate limiting en `/webhook/manychat`, `/webhook/whatsapp`, `/api/*`.
- [ ] Backup automatizado D1 (export periódico a R2).
- [ ] Disaster recovery runbook.
- [ ] Documentation en `docs/runbook.md`.

## Fase 5 — Sunset Make (semana 16-18)

**Owner**: Web Claude (con Make MCP).
**Output**: Make completamente desactivado.

### Entregables

- [ ] Pausa scenarios Make uno por uno con verification:
  - [ ] `cron:knowledge-refresh` (4719360) — reemplazado por CF cron.
  - [ ] `sub:knowledge-refresh-core` (4716901).
  - [ ] `wh:bot-router` (4706679).
  - [ ] `wh:bot-greeter` (4716928).
  - [ ] `wh:bot-booker` (4724250).
  - [ ] `wh:tool-executor` (4704931).
  - [ ] `wh:mp-listener` (4709161).
  - [ ] `sub:mp-confirm-payment` (4709131).
- [ ] Esperar 14 días con scenarios pausados (rollback window).
- [ ] Eliminar scenarios.
- [ ] Eliminar datastores Make (export backups primero).
- [ ] Eliminar connections.
- [ ] Cancelar subscription Make.

## Fase 6 — Módulos futuros (mes 4+)

On-demand:
- [ ] `apps/inventory` (2-3 sem).
- [ ] `apps/staff-tasks` (2 sem).
- [ ] `apps/chef` (3-4 sem).
- [ ] `apps/marketing` (2 sem).

## Hito crítico: bookings full trazabilidad D1

Hoy: bookings vía sitio web están en D1, bookings vía bot WhatsApp están solo en Beds24.

Fase 1 cierra este gap: cuando `apps/bot` crea booking, INSERT D1 first, luego Beds24, luego MP. Single source of truth en D1.

Migración retroactiva: opcional script para importar bookings históricos de Beds24 a D1 con `source='legacy-beds24'`. Decisión: hacer si Alexander quiere reporting histórico unificado.

## Timing total

| Fase | Duración | Acumulado |
|---|---|---|
| 0 — Monorepo | 2 sem | 2 sem |
| 1 — bot + webhooks + pricing | 4 sem | 6 sem |
| 2 — admin (paralelo) | 6 sem (sem 5-10) | 10 sem |
| 3 — Stage 2 WA | 3 sem | 13 sem |
| 4 — Hardening | 2 sem | 15 sem |
| 5 — Sunset Make | 3 sem | 18 sem |
| 6 — Módulos | continuo | — |

**Total fase 0-5**: ~18 semanas (~4.5 meses) con dedicación 20h/sem.

## KPIs por fase

| Fase | KPI |
|---|---|
| 0 | Monorepo deploys verifies, latency `apps/site` igual |
| 1 | Bot p50 latency < 2s, error rate < 1%, 100% bookings en D1 |
| 2 | Admin DAU = Alexander + 1+ staff member |
| 3 | ManyChat sunset, TCO -30% |
| 4 | Alert response time < 5min, audit log completo |
| 5 | $0 en Make.com bill |

## Voto

- [ ] **Claude Code**: ¿timing realista para tu disponibilidad?
- [ ] **Alexander**: ¿priorización correcta? ¿Algún hito que mover antes/después?
