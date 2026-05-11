# 05 — Auth: extender Better Auth + WhatsApp OTP

**Status**: Reescrita 2026-05-11 post-CC correction (Better Auth ya en producción) + Alexander A6 voto (WhatsApp OTP como 2da opción).

**Decisión**: **Extender Better Auth** (ya en producción) extrayéndolo a `packages/auth` y agregando:
1. Tabla `user_roles` para multi-rol (customer/staff/admin/chef/owner)
2. Tabla `user_identities` para vincular WhatsApp/IG/FB/TT con email
3. Magic link via Resend (existente) + **WhatsApp OTP como 2da opción**
4. NO password (Alex confirmó A6)

## Contexto

**Versión original (2026-05-10) de este documento propuso "custom magic link auth"**. Era incorrecto — Better Auth 1.6.9 ya está integrado en producción desde ~1 mes atrás:

- `apps/web/src/lib/auth.ts`
- Drizzle adapter con tablas `users, sessions, accounts, verifications`
- Magic link via Resend funcionando
- 4 cascading bugs ya resueltos (snake_case adapter, `updated_at`, `ipAddress` camelCase, `@react-email/render` falla → HTML inline fallback)

CC en thread/00 explicó:
> "Las gotchas ya están resueltas en este código. Recomendación: extender, no swap."

Alex en thread/01 A6 dijo:
> "Sí magic link, o código por WhatsApp"

→ Magic link como default + WhatsApp OTP como segunda opción.

## Lo que existe hoy

### Better Auth 1.6.9 config

`apps/web/src/lib/auth.ts` (referencia, no commitear código real):

```typescript
import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { magicLink } from "better-auth/plugins";
import { db } from "@/lib/db";

export const auth = betterAuth({
  database: drizzleAdapter(db, { provider: "sqlite" }),
  user: {
    additionalFields: {
      // ej. preferred_lang
    },
  },
  session: {
    cookieCache: { enabled: true, maxAge: 5 * 60 },
    expiresIn: 30 * 24 * 60 * 60, // 30 días
  },
  plugins: [
    magicLink({
      sendMagicLink: async ({ email, url }) => {
        // Resend con HTML inline fallback
        // @react-email/render NO funciona en CF Workers runtime
      },
    }),
  ],
});
```

### Schema D1 actual (auth-related)

```sql
-- Better Auth core
users (id, email, name, emailVerified, image, createdAt, updatedAt, ...additionalFields)
accounts (id, accountId, providerId, userId, accessToken, refreshToken, ...)
sessions (id, userId, token, expiresAt, ipAddress, userAgent, ...)
verifications (id, identifier, value, expiresAt, ...)

-- Custom additions
magic_links (token, email, expiresAt, ...)
```

### Endpoints Better Auth

Mounted en `apps/web/src/pages/api/auth/[...all].ts`:
- `POST /api/auth/magic-link` — request link
- `GET /api/auth/verify` — consume link, crea session
- `POST /api/auth/sign-out` — destroy session
- `GET /api/auth/session` — current session info

## Plan de extensión

### Step 1 — Extraer a `packages/auth` (MVP1 Sprint)

```
packages/auth/
├── src/
│   ├── index.ts           ← export configured `auth` instance
│   ├── config.ts          ← betterAuth config con todos los plugins
│   ├── adapters/
│   │   └── d1.ts          ← Drizzle adapter wrapper
│   ├── plugins/
│   │   ├── whatsapp-otp.ts  ← custom Better Auth plugin (Sprint 2)
│   │   └── multi-role.ts    ← role checks middleware
│   ├── schema.ts          ← Drizzle schema definitions (reusable)
│   ├── emails/
│   │   ├── magic-link.html.ts  ← HTML inline (CF Workers compat)
│   │   └── otp.html.ts         ← Sprint 2
│   └── types.ts
└── package.json
```

`apps/web`, `apps/bot`, `apps/admin`, `apps/api` todos importan `import { auth } from '@rdm/auth'`.

### Step 2 — Agregar `user_roles` table (Sprint 2 con admin)

```sql
CREATE TABLE user_roles (
  user_id TEXT NOT NULL,
  role TEXT NOT NULL,
  scope TEXT,                    -- p.ej. property_id, o NULL para global
  granted_at INTEGER DEFAULT (strftime('%s','now')),
  granted_by TEXT,
  PRIMARY KEY (user_id, role, scope),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

| Role | Capabilities |
|---|---|
| `customer` | Sus reservas, perfil, historial |
| `staff` | Bookings, conversations (read + take over), pricing read-only |
| `chef` | Recipes (Sprint futuro), inventory read |
| `admin` | Todo de staff + edit prompts/configs/pricing + gestionar users |
| `owner` | Read-only de su propiedad (si Alex hostea terceros) |

Initial seed: Alexander tiene `admin` global.

### Step 3 — Magic link sigue funcionando (MVP1)

Sin cambios al flujo actual. Solo extraer al package.

### Step 4 — WhatsApp OTP plugin (Sprint 2)

```typescript
// packages/auth/src/plugins/whatsapp-otp.ts
import { BetterAuthPlugin } from "better-auth";

export const whatsappOTP = (): BetterAuthPlugin => ({
  id: "whatsapp-otp",
  endpoints: {
    sendOTP: createEndpoint("/whatsapp-otp/send", async (ctx) => {
      // 1. Validate phone E.164
      // 2. Generate 6-digit code
      // 3. Hash + store in `verifications` con TTL 10min
      // 4. Send via:
      //    Stage 1 (MVP+): ManyChat HSM template "rdm_otp" si está aprobado
      //    Stage 2: WhatsApp Cloud API direct
    }),
    verifyOTP: createEndpoint("/whatsapp-otp/verify", async (ctx) => {
      // 1. Lookup hash en verifications
      // 2. Si match: UPSERT user via `user_identities` (provider=whatsapp, external_id=phone)
      // 3. Create session, return cookie
    }),
  },
});
```

**Stage 1 dependency**: ManyChat HSM template `rdm_otp` aprobado con Meta.
- Alex action: verificar status del template en Meta Business Manager.
- Si NO aprobado: defer WhatsApp OTP a Stage 2.

### Step 5 — Tabla `user_identities` (Sprint 2-3)

```sql
CREATE TABLE user_identities (
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,        -- 'email' | 'whatsapp' | 'facebook' | 'instagram' | 'tiktok' | 'manychat'
  external_id TEXT NOT NULL,     -- email, phone E.164, subscriber_id
  verified_at INTEGER,
  metadata TEXT,                 -- JSON
  PRIMARY KEY (provider, external_id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_user_identities_user ON user_identities(user_id);
```

Use case: cliente entra al bot WhatsApp, después al sitio — sistema detecta match (booking con email = subscriber con phone) y vincula los identities → bot conoce historial.

### Step 6 — Multi-role middleware

```typescript
// packages/auth/src/plugins/multi-role.ts
import { auth } from "../config";

export async function requireRole(
  request: Request,
  role: string,
  scope?: string
) {
  const session = await auth.api.getSession({ headers: request.headers });
  if (!session) return null;

  const roles = await getRolesForUser(session.user.id);
  const allowed = roles.some(r =>
    r.role === role && (!scope || r.scope === null || r.scope === scope)
  );

  return allowed ? session : null;
}
```

Uso en `apps/admin`:
```typescript
const session = await requireRole(c.req.raw, "admin");
if (!session) return c.text("unauthorized", 401);
```

### Step 7 — Cross-app session (cookie scope)

Cookie `Domain=.rincondelmar.club` permite que `site`, `admin`, `api` compartan session.
- `bot.rincondelmar.club` no necesita session de user (recibe webhook con HMAC).

## Stage 1 vs Stage 2 timing

| Componente | Stage 1 (MVP1-Sprint 2) | Stage 2 (mes 4+) |
|---|---|---|
| Magic link via email | ✅ Better Auth existing | ✅ Same |
| WhatsApp OTP | ❌ NO (depende de ManyChat HSM o defer) | ✅ Via Cloud API direct (simplificado) |
| Cookie cross-subdomain | ✅ Sprint 0-1 | Same |
| `user_roles` | ✅ Sprint 2 con admin | Same |
| `user_identities` | ✅ Sprint 2-3 | Same |
| Multi-role middleware | ✅ Sprint 2 | Same |
| OAuth (Google, etc.) | ❌ No prioridad | Considerar si Alex pide |

## Comparación: por qué seguimos con Better Auth

### Por qué NO swap a custom

| Razón | Detalle |
|---|---|
| **Ya está en producción** | 1 mes operando, los 4 bugs cascading resueltos |
| **Resend + HTML inline fallback** | Workaround documentado, no reaparece |
| **Drizzle adapter** | Snake_case quirk conocido |
| **Sessions con cookie httpOnly + sameSite** | Defaults correctos |
| **Plugin system** | Extender (WhatsApp OTP) sin reescribir core |
| **Comunidad activa** | Fixes y nuevas features rápido |

### Por qué NO Clerk/Auth0

| Razón | Detalle |
|---|---|
| **$25-99/mes** desde primer user | Ya pagamos Resend |
| **Data del cliente fuera de nuestra D1** | Privacy + lock-in |
| **Magic link via su sistema** | No usa Resend |
| **No OAuth strict necessity** | Magic link es suficiente |

### Por qué NO Lucia

Deprecated v3 en 2025. Ya descartado.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Better Auth breaking change major version | Pin version 1.x, evaluate v2 cuando llegue |
| Plugin system instability | Use solo plugins core (magic-link, etc.) + custom plugins propios |
| `@react-email/render` failures | HTML inline fallback (igual que existing) |
| Drizzle snake_case bugs | Tests E2E flow auth completo en CI |
| WhatsApp HSM template approval delays | Defer WhatsApp OTP a Stage 2 si Stage 1 timing apretado |

## Action items

- [ ] **MVP1 Sprint**: extraer `apps/web/src/lib/auth.ts` a `packages/auth/`
- [ ] **MVP1 Sprint**: cookie scope `.rincondelmar.club` para multi-app
- [ ] **Sprint 2**: agregar `user_roles` table + migrations
- [ ] **Sprint 2**: middleware `requireRole`
- [ ] **Sprint 2**: confirmar ManyChat HSM template `rdm_otp` con Alex
  - Si aprobado: implementar WhatsApp OTP plugin Stage 1 con ManyChat
  - Si no: defer plugin a Stage 2 (Cloud API)
- [ ] **Sprint 2-3**: `user_identities` table + lookup heuristics (phone E.164 → email matching)
- [ ] **Stage 2 (mes 4+)**: WhatsApp Cloud API direct plugin

## Voto

- [x] **Alexander** (A6 thread/01): magic link + WhatsApp OTP como 2da opción, sin password
- [x] **Claude Code** (thread/00): extender Better Auth, no swap
- [ ] **Web Claude**: align con CC + Alex. Voto: extender. Pregunta abierta sobre WhatsApp OTP Stage 1 vs Stage 2 depende de HSM template status.

## Refs

- Better Auth docs: `https://better-auth.com/docs`
- Better Auth plugins guide: `https://better-auth.com/docs/concepts/plugins`
- Resend docs: `https://resend.com/docs`
