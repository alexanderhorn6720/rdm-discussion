# Rincón del Mar — Bot & Platform Discussion

Repo público para coordinar el diseño técnico de la migración y expansión del stack de Rincón del Mar entre Alexander Horn, Web Claude (claude.ai con MCPs) y Claude Code (CLI).

## Quién está aquí

- **Alexander Horn** — dueño del negocio. Decisión final.
- **Web Claude** — diseño y verificación con MCPs (Make.com, Cloudflare Developer Platform, MercadoPago). Lee y commitea directo via PAT.
- **Claude Code** — implementación. Lee del filesystem local, hace PRs.

## Cómo iteramos

1. Web Claude commitea documentos de diseño aquí.
2. Claude Code hace `git pull`, lee, responde en `threads/NN-tema.md` o haciendo cambios a `decisions/*.md`.
3. Alexander vota / corrige / amplia.
4. Web Claude refleja decisiones en docs maestros.
5. Cuando converja: implementación va a `rincondelmar-bot` (privado).

## Estructura

```
.
├── README.md                  ← este archivo, índice
├── CONTEXT.md                 ← estado actual verificado + contexto del negocio
├── VISION.md                  ← arquitectura objetivo (resumen ejecutivo)
├── ROADMAP.md                 ← fases con fechas
├── QUESTIONS.md               ← preguntas abiertas bidireccionales
├── decisions/                 ← una decisión por archivo, con pros/cons
│   ├── 01-monorepo-structure.md
│   ├── 02-channel-strategy.md      ← Stage 1 ManyChat → Stage 2 WhatsApp Cloud API
│   ├── 03-pricing-agent.md         ← Build vs Buy (PriceLabs/Beyond)
│   ├── 04-admin-board.md
│   ├── 05-auth-magic-link.md       ← unificado clientes/staff/admin
│   ├── 06-future-modules.md        ← inventario, staff tasks, chef
│   ├── 07-pwa-mobile.md            ← PWA primero, APK después
│   ├── 08-orchestration.md         ← Workflows + Queues reemplazan Make
│   └── 09-bots-llm-architecture.md ← LLM patterns, prompts, multi-channel
├── diagrams/
│   ├── current-stack.html          ← estado actual (Make + Worker rincon-pago)
│   └── future-stack-v2.html        ← arquitectura objetivo
└── threads/                        ← discusiones por tema
    └── NN-tema.md
```

## Estado actual de la discusión

- ✅ Repo público creado (este).
- ✅ Web Claude verificó estado real via MCPs:
  - 5 Workers desplegados (rincon-pago = sitio+pago+auth+cron, rincon-tours, reservar, beds24-calendar, airdm).
  - D1 schema deducido del bundle: bookings, users, verifications, magic_links, sessions.
  - 5 cron jobs activos en `rincon-pago`.
  - HMAC SHA256 MP webhook funcional con idempotency KV.
  - Make.com (folder 316545) sigue activo para bots WhatsApp/IG + un puente híbrido para confirmar Beds24.
- ✅ Web Claude armó plan v3 con 7 requerimientos nuevos de Alexander:
  1. Make como solución temporal — nueva versión no usa Make para Beds24 directo.
  2. Two-stage channel: Stage 1 ManyChat (evitar cutovers), Stage 2 WhatsApp Cloud API directo.
  3. Pricing agent automatizado.
  4. Admin board para prompts y configs.
  5. Infraestructura modular para futuros módulos (inventario, staff, chef).
  6. Magic link para clientes, admin, staff.
  7. PWA / APK a futuro.
  8. Best industry practices, sin workarounds.
- ⏳ Claude Code revisa y vota / corrige / agrega preguntas.
- ⏳ Alexander revisa decisiones, vota.

## Repos relacionados

- **`alexanderhorn6720/rincondelmar-bot`** (privado) — código de producción del sitio + bots.
- **`alexanderhorn6720/rdm-greeter-kb`** (privado) — knowledge base actual de bots (prompts, property JSONs). Será absorbido por el monorepo.
- **`alexanderhorn6720/rincondelmar-bot-discussion`** — este repo, público, solo diseño.

## Stack actual verificado

Lee `CONTEXT.md` y `diagrams/current-stack.html`.

## Stack propuesto

Lee `VISION.md`, `diagrams/future-stack-v2.html` y cada archivo en `decisions/`.

## Convención

- Decisión nueva: PR/commit a `decisions/NN-tema.md`.
- Pregunta nueva: añadir a `QUESTIONS.md` con responsable (`[@cc]`, `[@wc]`, `[@alex]`).
- Cambio de scope: actualizar `ROADMAP.md`.
- Discusión profunda: thread en `threads/`.

## Privacidad

Este repo es **público** durante el diseño. No commiteamos:
- Secrets (`*_TOKEN`, `*_KEY`, `*_SECRET`).
- IDs sensibles de cliente (subscriber_id particulares, emails, teléfonos).
- Booking IDs reales (usar `<EXAMPLE>` o `XXX`).

Para hablar de datos sensibles, comentar inline con `[REDACTED]` o usar el chat directo con Web Claude o Claude Code.
