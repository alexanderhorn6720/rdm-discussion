# 04 — Admin board

**Status**: Propuesta. Esperando voto.

**Decisión**: `apps/admin` como **React 19 + Vite + shadcn/ui + Tailwind**, deployada en **Cloudflare Workers (Static Assets)** sirviendo SPA + API calls al monorepo. **PWA-ready desde día 1.**

## Contexto

Alexander pidió admin board para:
- Administrar prompts y config de bots.
- Cliente, administración y staff (multi-rol con magic link).
- A futuro: inventario, staff tasks, chef admin.
- Best industry practices.

## Stack propuesto

| Layer | Choice | Razón |
|---|---|---|
| Framework | **React 19** | Hooks maduros, Suspense, Server Components opcional. Más demanda de devs que Svelte/Solid. |
| Build | **Vite 6+** | Fastest, mejor DX, mejor con Cloudflare. |
| UI library | **shadcn/ui** | Copy-paste, owned components, sin lock-in. Tailwind underneath. |
| Styling | **Tailwind 4** | Industry standard. Reuso de design tokens del sitio (`#0e6b7a` etc.). |
| Routing | **TanStack Router** | Type-safe routing, search-param validation. Mejor que React Router en TS. |
| Data fetching | **TanStack Query** | Cache, mutations, optimistic updates. Best industry standard. |
| Forms | **TanStack Form** + **Zod** | Type-safe forms con schema validation compartido con backend. |
| Auth | **packages/auth** (custom magic link) | Compartido con `apps/site`. |
| Hosting | **Cloudflare Workers Static Assets** | No Pages (Pages está siendo absorbido). Workers con `assets` binding. |
| PWA | **vite-plugin-pwa** | Manifest + service worker generation automatic. |

## Razón Workers vs Pages

Citado en CF best practices 2026:
> "Cloudflare is folding Pages into Workers. Pages isn't getting killed tomorrow, but all the new stuff goes to Workers first or only. Secrets Store, Workflows, Containers — Workers only."

Workers con Static Assets binding (`compatibility_date >= "2024-09-19"`):
- Sirve SPA igual que Pages.
- + Custom server logic en mismo deploy (auth middleware, API proxy).
- + Bindings (D1, KV, R2) directos.
- + Cron + Workflows + Queues si el admin board los necesita.

No Pages.

## Estructura

```
apps/admin/
├── wrangler.toml
├── vite.config.ts
├── package.json
├── public/
│   ├── manifest.webmanifest    ← PWA
│   ├── icons/
│   └── robots.txt              ← noindex
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── routes/
│   │   ├── _auth.tsx           ← layout para rutas autenticadas
│   │   ├── login.tsx
│   │   ├── bookings/
│   │   │   ├── index.tsx       ← lista
│   │   │   └── $id.tsx         ← detalle
│   │   ├── conversations/
│   │   │   ├── index.tsx
│   │   │   └── $id.tsx         ← inbox + take-over
│   │   ├── prompts/
│   │   │   ├── index.tsx
│   │   │   └── $name.tsx       ← editor (Monaco) + preview + deploy
│   │   ├── properties/
│   │   │   └── $id.tsx         ← config: capacidad, extras, min-stay, mascotas
│   │   ├── pricing/
│   │   │   └── index.tsx       ← rules + override + history
│   │   ├── staff/
│   │   │   └── index.tsx       ← gestión de roles
│   │   └── settings/
│   ├── components/
│   │   ├── ui/                 ← shadcn copy-paste
│   │   ├── data-table.tsx      ← TanStack Table
│   │   ├── prompt-editor.tsx
│   │   └── ...
│   ├── lib/
│   │   ├── auth.tsx            ← session context
│   │   ├── api.ts              ← TanStack Query setup
│   │   └── types.ts
│   └── worker/
│       └── index.ts            ← Worker handler (auth middleware + asset serving)
└── tsconfig.json
```

## Rutas y permisos

| Ruta | Rol mínimo | Función |
|---|---|---|
| `/login` | anon | magic link entry |
| `/` | client | dashboard de cliente (mis reservas, mi historial) |
| `/bookings` | staff | tabla de bookings con search/filter |
| `/bookings/$id` | staff | detalle, modificar, cancelar |
| `/conversations` | staff | inbox tipo Intercom (en Stage 2 reemplaza ManyChat inbox) |
| `/conversations/$id` | staff | chat + take over del bot |
| `/prompts` | admin | listar prompts versionados |
| `/prompts/$name` | admin | Monaco editor, preview con sandbox, "deploy now" |
| `/properties/$id` | admin | config por propiedad |
| `/pricing` | admin | reglas, override manual, history |
| `/staff` | admin | invitar staff, asignar roles |
| `/settings` | admin | secrets rotation (preview, no values), feature flags |

## Funcionalidades clave

### Prompt editor

Monaco editor con:
- Diff vs versión en producción.
- Test sandbox: corre LLM con prompt nuevo contra fixtures de los 7 QA cases.
- Deploy now: actualiza KV `KNOWLEDGE:system_prompt`, force refresh subscribers afectados.
- History: lista de versiones, rollback con 1 click.

### Inbox de conversaciones (Stage 2)

Cuando estamos en Cloud API direct, este se vuelve EL inbox del equipo (reemplaza el de ManyChat). Necesita:
- Real-time updates via Durable Objects WebSocket.
- Take over: pausar bot, asignar a staff, enviar manual.
- Internal notes.
- Tags (lead, hot, cold, problem, customer).

### Pricing override

Calendar view con precio por día por propiedad. Click → override manual con razón. Color-code: PriceLabs (gray), override manual (orange), confirmed booking (green).

## PWA

Desde día 1:
- `manifest.webmanifest` con icons, theme color (`#0e6b7a`), display=standalone.
- Service worker con vite-plugin-pwa (workbox).
- Offline page para conexión perdida (staff en propiedad sin WiFi).
- "Install app" prompt en Android/iOS Safari.

Beneficios:
- Alexander y Karina lo agregan a home screen → look-and-feel app nativa.
- Push notifications futuras (Web Push API).
- Offline reads (bookings cached, sync cuando recupera conexión).

Para APK ver `decisions/07-pwa-mobile.md`.

## Auth integration

Reusa `packages/auth/` (ver `decisions/05-auth-magic-link.md`).

Middleware en Worker:
```typescript
// apps/admin/src/worker/index.ts
import { authMiddleware } from '@rdm/auth';

export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url);
    
    // API calls: validate session, proxy to apps/api
    if (url.pathname.startsWith('/api/')) {
      const session = await authMiddleware(req, env);
      if (!session) return new Response('unauthorized', { status: 401 });
      return fetch(`https://api.rincondelmar.club${url.pathname}`, {
        ...req,
        headers: { ...req.headers, 'x-user-id': session.userId, 'x-roles': session.roles.join(',') }
      });
    }
    
    // Static assets
    return env.ASSETS.fetch(req);
  }
};
```

## Pros

- Cloudflare-native stack al 100%.
- Reusa design tokens y auth del sitio.
- PWA gratis con vite-plugin-pwa.
- Monorepo permite compartir types con bot/site.
- TanStack Query + Form + Router es 2026 industry standard.

## Cons

- React 19 + RSC support requiere compat date moderna (no problema).
- shadcn copy-paste requiere mantener componentes (pro: ownership, con: updates manuales).
- TanStack Router es menos popular que React Router — curva de aprendizaje.

## Alternativas consideradas

### Next.js en Cloudflare

**Pros**: App Router con RSC, full stack en mismo framework.
**Cons**: Next.js en Workers funciona pero con compromisos (no toda la feature set Next funciona). Overkill para SPA admin. Cold start mayor.
**Veredicto**: No.

### Remix / React Router 7

**Pros**: Excelente DX, loaders + actions pattern.
**Cons**: TanStack alternatives son más livianos y framework-agnostic. RR7 sigue maduro pero TanStack tiene momentum en 2026.
**Veredicto**: Considerar si CC prefiere RR7. Empate técnico.

### Svelte / SolidJS

**Pros**: Más rápido en runtime.
**Cons**: Comunidad smaller, menos tooling, menos React devs en mercado MX.
**Veredicto**: No para este proyecto.

### Refine (admin framework)

**Pros**: Pre-built admin patterns.
**Cons**: Lock-in, less customizable, opinionated.
**Veredicto**: No.

## Voto

- [ ] **Claude Code**: React 19 + shadcn + TanStack stack? Otra preferencia?
- [ ] **Alexander**: ¿confirmas que admin debe ser PWA installable?
