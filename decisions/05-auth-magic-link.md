# 05 — Auth: magic link unificado multi-rol

**Status**: Propuesta. Esperando voto.

**Decisión**: Mantener magic link auth existente en `apps/site`, extraer a `packages/auth`, extender con tabla `user_roles` para soportar cliente / staff / admin con un solo flujo de login.

## Contexto

Estado actual (verificado): `rincon-pago` ya tiene `users, verifications, magic_links, sessions` en D1, manda magic link via Resend, mantiene sessions. Auth funciona para clientes web del flujo de booking.

Alexander pidió: "Admin board para clientes, administración y staff con magic link".

## Diseño

### Schema D1 extendido

```sql
-- Tabla existente, sin cambios mayores
CREATE TABLE users (
  id TEXT PRIMARY KEY,           -- ULID o UUID
  email TEXT NOT NULL UNIQUE,
  name TEXT,
  phone TEXT,                    -- E.164, opcional
  created_at INTEGER DEFAULT (strftime('%s','now')),
  updated_at INTEGER DEFAULT (strftime('%s','now')),
  last_login_at INTEGER,
  status TEXT DEFAULT 'active'   -- active | suspended | deleted
);

-- Nueva: roles multi-tenant
CREATE TABLE user_roles (
  user_id TEXT NOT NULL,
  role TEXT NOT NULL,            -- 'customer' | 'staff' | 'admin' | 'chef' | 'owner'
  scope TEXT,                    -- p.ej. property_id ('rincon-del-mar') o NULL para global
  granted_at INTEGER DEFAULT (strftime('%s','now')),
  granted_by TEXT,
  PRIMARY KEY (user_id, role, scope),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Nueva: vinculación con channels (WhatsApp, IG, FB, TT)
CREATE TABLE user_identities (
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,        -- 'email' | 'whatsapp' | 'facebook' | 'instagram' | 'tiktok' | 'manychat'
  external_id TEXT NOT NULL,     -- email, phone E.164, subscriber_id de provider
  verified_at INTEGER,
  metadata TEXT,                 -- JSON con datos del provider
  PRIMARY KEY (provider, external_id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_user_identities_user ON user_identities(user_id);

-- Existing magic_links, verifications, sessions sin cambios mayores
```

### Roles

| Role | Capabilities |
|---|---|
| `customer` | Ver sus propias reservas, modificar perfil, ver historial |
| `staff` | Acceso a bookings, conversations (read + take over), ver pricing (read-only) |
| `chef` | Acceso a admin/recipes, inventory para insumos (futuro módulo) |
| `admin` | Todo de staff + edit prompts, configs, pricing rules, gestionar usuarios |
| `owner` | Read-only de su propiedad (si Alexander hostea propiedades de terceros) |

Roles son aditivos (un user puede ser `staff` + `admin`). Scope opcional para limitar a propiedad específica.

### Flujo de login

```
1. User entra a admin.rincondelmar.club o /mi-cuenta del sitio
2. Submite email
3. Worker:
   - INSERT INTO magic_links (token, email, expires_at = now+15min, scope)
   - Resend email con link https://{host}/auth/verify?token=...
4. User click link
5. Worker:
   - SELECT magic_link, verify expires_at > now
   - UPSERT INTO users (email) si no existe (status='active' default)
   - INSERT INTO sessions (user_id, token, expires_at = now+30d)
   - Set-Cookie: session={token}; HttpOnly; Secure; SameSite=Lax; Max-Age=...
   - DELETE magic_link consumido
   - Redirect a host original
6. Cada request:
   - getSession(req.cookies.session) → user + roles[]
   - middleware requireRole('admin') etc.
```

### Cross-app session

Sessions deben funcionar en `site`, `admin`, `bot` (vía same-origin subdomain cookie).

Cookie scope: `Domain=.rincondelmar.club` para que `site`, `admin`, `api` compartan.

`bot.rincondelmar.club` no necesita session de usuario web (recibe webhook autenticado por HMAC).

### Vinculación WhatsApp ↔ Email

Cuando un cliente entra al bot WhatsApp y luego visita el sitio:

1. Bot crea `user_identities(provider='whatsapp', external_id=phone_e164)` SIN `user_id` (anonymous channel user).
2. Cliente entra al sitio, se loguea con email → tiene `user_id`.
3. Sistema detecta que el phone del subscriber WA matches algún booking con email del user → vincula: UPDATE user_identities SET user_id=? WHERE provider='whatsapp' AND external_id=?
4. Futuras conversaciones del bot conocen al user → contexto enriquecido (booking history, etc.).

Privacy: lo hacemos sólo cuando hay match explícito (no scraping).

### Magic link rate limiting

Para evitar abuse:
- 5 magic links por email por hora.
- 20 magic links por IP por hora.
- KV `auth:rl:email:{e}` y `auth:rl:ip:{ip}` con expirationTtl=3600.

### Magic link content

Email Resend template:
```
Hola {{name || 'Hola'}},

Para entrar a Rincón del Mar, haz click aquí:

{{magic_link_url}}

Este link expira en 15 minutos. Si no fuiste tú, ignora este email.

— Equipo Rincón del Mar
```

Subject: `Tu link de acceso a Rincón del Mar`.

### Multi-rol UI

Si user tiene roles `['customer', 'staff']`, después del login muestra selector "Modo cliente" / "Modo staff" (igual que Slack workspaces). Cookie de sesión guarda el `active_role`.

### Sessions storage

Hoy: D1 `sessions` table.

**Considerar Durable Object** para sessions activas (hot path). DO con SQLite es ~10x faster reads que D1 para single-row lookups.

Pros: latency.
Cons: complejidad, 1 DO per session crea N DOs.

**Recomendación**: empezar con D1 + KV cache (KV `session:{token}` con TTL 5min). DO solo si latency duele en producción.

## Comparación con Better Auth, Lucia, Clerk

### Clerk / Auth0 (managed)

**Pros**: Zero infra. Múltiples providers (OAuth Google, Apple).
**Cons**: $25-99/mes desde el primer user. Lock-in. Datos del cliente fuera de nuestra D1. Magic link tiene que ir via su sistema, no Resend ya pagado.
**Veredicto**: No. Tenemos la auth ya funcionando con Resend que ya pagamos.

### Better Auth (open source, framework-agnostic)

**Pros**: Library moderna 2025-2026. Magic link, OAuth, 2FA, MFA, organizations, multi-tenant built-in. Schema adapters para D1/Drizzle.
**Cons**: Library joven. Algunos quirks con Workers runtime.
**Veredicto**: **Evaluar**. Si CC lo conoce y le gusta, swap nuestro custom por Better Auth ahorra tiempo de mantenimiento. Si no, custom está bien y funciona.

### Lucia (deprecated)

Lucia v3 está deprecated en 2025. NO.

### Custom (lo que tenemos)

**Pros**: Funciona. Conocido. Cero deps externas.
**Cons**: Maintenance. Cualquier feature nueva (2FA, OAuth) la construimos.

## Recomendación

**Custom enhanced** — extraer `rincon-pago` auth a `packages/auth`, agregar `user_roles` table, soportar multi-rol. Si Claude Code tiene experiencia con Better Auth y prefiere, swappable.

## Voto

- [ ] **Claude Code**: ¿Custom o Better Auth? Otra preferencia?
- [ ] **Alexander**: ¿OK con magic link como único método de auth (sin password)? Mi voto: sí, password no aporta valor cuando ya hay email verificado.

## Notas de implementación

- 2FA por SMS/TOTP opcional para `admin` role en Stage 2.
- Audit log de admin actions en tabla `audit_log` para compliance.
- Session revocation: admin puede kick sessions de otros users (security).
