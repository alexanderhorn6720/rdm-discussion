# 01 — Estructura monorepo

**Status**: Propuesta. Esperando voto de Claude Code + Alexander.

**Decisión**: Turborepo + pnpm workspaces, single repo `alexanderhorn6720/rincondelmar-bot` con apps independientes y packages compartidos.

## Contexto

Estado actual:
- Sitio + booking flow + auth + MP webhook + crons en single Worker `rincon-pago` (repo `rincondelmar-bot` privado).
- Bots WhatsApp/IG en Make.com.
- Knowledge files en repo separado `rdm-greeter-kb`.
- Worker `reservar` legacy desplegado pero status incierto.

Necesitamos:
- Migrar bots a Workers.
- Añadir admin board.
- Añadir pricing agent.
- Preparar para futuros módulos (inventario, staff, chef).

Sin estructura, terminaremos con N repos descoordinados, types duplicados, dependencies divergiendo.

## Opciones

### A — Monorepo Turborepo + pnpm

```
rincondelmar-bot/
├── apps/
│   ├── site/        ← rincon-pago actual, refactor
│   ├── bot/         ← migración Make
│   ├── admin/       ← nuevo, React PWA
│   ├── pricing/     ← cron-only Worker
│   ├── webhooks/    ← consolidación de webhooks
│   ├── api/         ← API gateway interno (opcional)
│   └── tours/       ← existente, mover aquí
├── packages/
│   ├── db/          ← Drizzle schema + migrations + queries
│   ├── shared/      ← types, constants, utils
│   ├── agents/      ← LLM patterns
│   ├── channels/    ← WhatsApp, IG, FB, TT abstractions
│   ├── beds24/      ← typed client
│   ├── mp/          ← MercadoPago client
│   ├── auth/        ← magic link + sessions
│   ├── ui/          ← React components
│   ├── tsconfig/    ← shared TS configs
│   └── eslint-config/
├── tooling/
│   └── wrangler-configs/  ← shared wrangler templates
├── package.json
├── pnpm-workspace.yaml
├── turbo.json
└── tsconfig.json
```

**Pros**:
- Estándar industria 2026 (referencias múltiples: Vercel, Cloudflare docs oficiales).
- Type safety end-to-end: cambio en `packages/db/schema.ts` rompe builds de quien lo use.
- Atomic commits: features cross-app (p.ej. nueva tabla `bookings` + UI admin + endpoint API) van en un PR.
- Turborepo remote cache via Cloudflare R2 — builds rapidísimos en CI.
- pnpm workspaces — disk efficient, deterministic, sin "phantom dependencies".
- Cada app deploya independiente (`turbo deploy --filter=apps/bot`).
- Dev local con `turbo dev` corre todas las apps en paralelo + hot reload.

**Cons**:
- Setup inicial ~1 día (Turborepo + pnpm + tsconfig hierarchy).
- Onboarding nuevos collaboradores requiere curva.
- CI más complicado de configurar (filtros, watch paths).

### B — Multi-repo (un repo por app)

Cada app es su propio repo (`rdm-bot`, `rdm-admin`, `rdm-pricing`, etc.).

**Pros**:
- Aislamiento total. Bug en uno no afecta otros.
- CI/CD per repo trivial.

**Cons**:
- Type sharing requiere publicar npm packages (latency de iteración).
- Cambio cross-app es N PRs sincronizados.
- Drift de dependencies casi garantizado.
- Schema D1 vive en algún repo "main", los demás copian.
- Imposible refactoring cross-repo limpio.
- **Anti-pattern moderno**. 2026 monorepo es default para multi-app.

### C — Mantener single Worker `rincon-pago` y meter bots dentro

```
rincondelmar-bot/  (single Worker)
├── src/
│   ├── routes/
│   │   ├── site/
│   │   ├── bot/
│   │   ├── admin/
│   │   └── api/
│   ├── lib/
│   ├── cron/
│   └── ...
```

**Pros**:
- Cero setup nuevo.
- Compartir D1, KV, secrets es trivial.
- Un solo deploy.

**Cons**:
- Bundle tamaño crece sin control. CF Workers tiene 1MB compressed limit.
- Cold start time degrada.
- Bug en bot afecta sitio.
- Imposible rollback granular.
- Tests lentos (cualquier cambio re-runs todo).
- React admin no encaja como ruta Worker (sirve mejor en Pages).
- **No escala**. Cuando lleguemos a 6+ módulos, el Worker es inmanejable.

## Recomendación

**Opción A — Monorepo Turborepo + pnpm**.

Justificación:
- Es el patrón que adoptaron empresas similares en 2026 (referencias: Outstand, Vercel templates, Cloudflare templates oficiales).
- Soporta crecimiento orgánico: añadir `apps/inventory` en 6 meses es trivial.
- Type safety es la única forma de mantener cordura cuando hay 5-10 apps tocando el mismo schema D1.
- Turborepo remote cache (gratis con CF R2) reduce CI time 60-80%.
- pnpm es más rápido y deterministic que npm/yarn.

## Setup propuesto

```json
// turbo.json
{
  "$schema": "https://turborepo.org/schema.json",
  "globalDependencies": ["tsconfig.json", "**/.env.*local"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["src/**", "tsconfig.json", "package.json"],
      "outputs": ["dist/**", ".wrangler/**"]
    },
    "dev": { "cache": false, "persistent": true },
    "lint": { "outputs": [] },
    "test": { "outputs": ["coverage/**"] },
    "deploy": { "dependsOn": ["build"], "cache": false }
  }
}
```

```yaml
# pnpm-workspace.yaml
packages:
  - "apps/*"
  - "packages/*"
  - "tooling/*"
```

```json
// package.json root
{
  "name": "rincondelmar-bot",
  "private": true,
  "scripts": {
    "build": "turbo build",
    "dev": "turbo dev",
    "lint": "turbo lint",
    "test": "turbo test",
    "deploy": "turbo deploy",
    "db:generate": "pnpm --filter @rdm/db generate",
    "db:migrate": "pnpm --filter @rdm/db migrate"
  },
  "devDependencies": {
    "turbo": "^2.0.0",
    "@rdm/tsconfig": "workspace:*"
  },
  "packageManager": "pnpm@9.0.0"
}
```

## Naming convention

Packages: `@rdm/db`, `@rdm/agents`, `@rdm/channels`, etc.
Apps: kebab-case (`bot`, `site`, `admin`, `pricing`, `webhooks`).

## Migración del repo actual

1. Estructura nueva en branch `chore/monorepo`.
2. Mover código actual de `rincon-pago` a `apps/site/`.
3. Mover Worker `tours` a `apps/tours/`.
4. Extraer types y utils a `packages/shared/` y `packages/db/`.
5. Extraer MP webhook a `apps/webhooks/`.
6. Refactor incremental, no big bang. Sites sigue funcionando en main mientras se hace el split en branch.

## Deploys CI/CD

GitHub Actions con turbo filters:

```yaml
- name: Deploy changed apps
  run: |
    turbo deploy --filter=...[origin/main] --concurrency=4
```

Cada app tiene su `wrangler.toml` y desploya cuando cambia su path. Branch protection: main → producción.

## Voto

- [ ] **Claude Code**: A / B / C ?
- [ ] **Alexander**: A / B / C ?
