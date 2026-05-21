# thread/158 — WC → CC-Bot: `/ir/*` shortlink + resolver overhaul (DoIt)

**From:** WC (claude.ai, brain deep)
**To:** CC-Bot (new session, autonomous)
**Type:** DoIt · 5 atomic PRs sequential
**Source threads:** 21, 50, 51, 52, 53, 65, 67, 80, 82 + audit chat 2026-05-21
**Output thread:** thread/159 (CC reports back)
**Time budget:** 12-16h CC. Exceed 1.5× (24h) = stop + report.
**Cost cap:** $15 LLM combined. Exceed = stop + Telegram Alex.

---

## §1 · Context

Audit completo 2026-05-21 (Alex reportó 5 mensajes frescos de bot Greeter v5/v6 con URLs rotas). Causas-raíz desde el código (verificado en `intent-resolver.ts`, `tools-v5.ts`, `process-tool-use.ts`, `click-tracking.ts`, `system-prompt-v5.ts`, `system-prompt-v6.ts`, `greeter-v5-deps.ts`):

| Bug | Síntoma observado | Causa-raíz código |
|---|---|---|
| **A** | `/ir/huerta-cocotera` → `/contacto` | LLM emite property slug como `intent_slug`. Dispatcher `processRouteUserToUrl` NO valida runtime. Resolver retorna `unknown_intent` → fallback `/contacto`. No existe intent `propiedad` para "info general de villa X" — LLM improvisa. |
| **B.1** | `/ir/disponibilidad?check_in=...&guests=5` sin `prop=` → `/#casas` (params perdidos) | `intent-resolver.ts` línea 270: fallback retorna EARLY. Bloque `queryParts.push(...)` está DESPUÉS del return. Fallback URL nunca recibe dates/guests. |
| **B.2** | LLM emite `check_in=2025-05-29` con today=2026-05-21 | `buildSystemPromptBlocksV5/V6` NO inyecta `today=YYYY-MM-DD` en dynamic context. Tool schema valida `^\d{4}-\d{2}-\d{2}$` (cualquier año). No hay validator post-tool-call. |
| **C** | `/ir/precios?prop=...&guests=15` ignora `guests` | `precios` en catalog: solo `requires_property: true`. No tiene `accepts_dates` ni `accepts_guests`. Solo `cotizar` los tiene. LLM no distingue cuando user da guests sin dates. |
| **D** | `/ir/comparar-casas` → `/#casas` (sin tabla) | By design: `'comparar-casas': { url_template: '/#casas' }`. El bot promete "tabla comparativa" pero el target solo lista las 4 casas. Mismatch del opening_line vs landing. |

**Hallazgos adicionales:**

- **E** · No existe intent `propiedad` con `url_template: '/{property}/'`. Necesario para "info de Huerta".
- **F** · Drift de 4 sources: `CATALOG_ES/EN` (intent-resolver), `VALID_INTENT_SLUGS` (tools-v5), `§INTENT_CATALOG` markdown (system-prompt-v5 + v6). Cada cambio toca 4 lugares. PR #50 y #53 documentan desincronizaciones previas.
- **G** · `bot_link_clicks` D1 NO guarda `check_in/check_out/guests/used_fallback/fallback_reason`. Imposible auditar blast radius del bleeding.
- **H** · v5 + v6 comparten resolver + tools-v5. Fix una vez → aplica a ambos.
- **I** · URLs actuales son guest-facing-feas: `bot.rincondelmar.club/ir/disponibilidad?conv=20667327&v=v5&lang=es&check_in=2025-05-29&check_out=2025-06-03&guests=5`. Alex pide URLs human-friendly tipo `rincondelmar.club/ir/precio-erika-mayo29-x7q`.

---

## §2 · Scope

### YES (en este DoIt)

1. **Intent catalog single source of truth** (`packages/agents/greeter/intent-catalog.ts`)
2. **Nuevo intent `propiedad`** con `url_template: '/{property}/'`
3. **Defensive guard runtime**: property-slug-as-intent → auto-remap a `propiedad` + log
4. **`precios` + `disponibilidad`** aceptan `accepts_dates + accepts_guests`
5. **Resolver fallback enriquecido**: propaga `check_in/check_out/guests` al fallback URL si def tenía `accepts_*: true`
6. **`today=YYYY-MM-DD`** inyectado en dynamic context (v5 + v6) + validator post-tool-call que rechaza dates < today
7. **`comparar-casas`** opening_line guidance domado en system-prompt (no prometer "tabla")
8. **`bot_short_links` D1 table** + handler `/ir/:id` + Patrón B URL generator
9. **`wrapClickTracking` refactor**: ahora llama `createShortLink()` en vez de armar URL larga
10. **Domain switch**: `rincondelmar.club/ir/*` apunta al Worker (wrangler route). `bot.` mantiene beds24 proxy + admin endpoints.
11. **CI snapshot test** sincroniza catalog ↔ tool enum ↔ system-prompt markdown
12. **Cleanup cron mensual** para `bot_short_links` (60d buffer post-TTL 10d)
13. **v5 + v6** ambos reciben los cambios (resolver compartido)

### NO (out of scope — queue separados)

- Página `/comparar` real (4-6h frontend, queue separado)
- Canary v5/v6 audit (brain quick separado tras este spec — memoria dice v6 100% pero Alex reporta `v=v5` fresco)
- Beds24 proxy domain (sigue en `bot.beds24.rincondelmar.club`, sin cambio)
- Booker agent
- Lang detection
- Webhook flow / ManyChat integration
- Cleanup orphan `prompts/system-prompt.txt` (queue separado, thread/118)
- Pre-stay templates (separate spec)
- Out-of-scope findings durante exec → open issue, NO fix inline

---

## §3 · Closed decisions (Alex 2026-05-21)

| # | Tema | Decisión |
|---|---|---|
| 1 | Catalog sync | CI snapshot test (no codegen). 4 sources convergen vía import. |
| 2 | Bug A timing | Defensive guard dentro del spec, no PR hotfix paralelo. |
| 3 | Bug C `precios` guests | Schema: agregar `accepts_dates + accepts_guests` al intent. |
| 4 | Bug D `comparar` | Domar opening_line. Página `/comparar` real → queue separado. |
| 5 | Bug B.1 fallback | Propagar `check_in/check_out/guests` al fallback URL. |
| 6 | Bug B.2 año 2025 | `today=` en context + validator post-call (ambas defensas). |
| 7 | Intent `propiedad` | Nuevo intent dedicado con `url_template: '/{property}/'`. |
| 8 | v5 vs v6 scope | Ambos — resolver compartido. |
| 9 | Thread number | CC pre-flight `ls threads/15[7-9]-*.md` → primer slot libre ≥158. |
| 10 | Fix scope | Tactical + estructural en el spec (no minimal-viable). |
| 11 | Canary mismatch | Brain quick separado tras este DoIt. |
| 12 | URL format | Patrón B: `intent-nombre-contexto-xxx` human-readable. |
| 13 | Privacy nombre | Visible siempre en URL. |
| 14 | TTL + cleanup | 10d TTL efectivo + 50d buffer en tabla = 60d total. ~17K rows max. |
| 15 | Expired behavior | 302 graceful a `/{prop}/` (si row guardó property) sino `/`. |
| 16 | Domain | `rincondelmar.club/ir/*` guest-facing. `bot.` permanece para beds24 proxy + admin endpoints. |
| 17 | Hash collision | Retry 5× con nuevo `xxx` sufijo. Falla 5× → fallback formato viejo. |

---

## §4 · Implementation

### PR1 · `packages/agents/greeter/intent-catalog.ts` + propiedad intent + accepts updates + CI snapshot

**Branch:** `feat/intent-catalog-single-source`

**Files:**

```
NEW    packages/agents/greeter/intent-catalog.ts
EDIT   apps/worker-bot/src/intent-resolver.ts
EDIT   packages/agents/greeter/tools-v5.ts
EDIT   packages/agents/greeter/system-prompt-v5.ts
EDIT   packages/agents/greeter/system-prompt-v6.ts
NEW    apps/worker-bot/tests/intent-catalog-sync.test.ts
EDIT   apps/worker-bot/tests/intent-resolver.test.ts
```

**`intent-catalog.ts` shape:**

```ts
export interface IntentDef {
  url_template: string;
  requires_property?: boolean;
  only_for_properties?: string[];
  accepts_dates?: boolean;
  accepts_guests?: boolean;
  accepts_city?: boolean;
  accepts_category?: boolean;
  fallback: string;
  /** Human-friendly word for short-link URL (e.g. precios → precio). */
  human_label_es: string;
  human_label_en: string;
  /** Markdown row for §INTENT_CATALOG in system-prompt. */
  prompt_hint: string;
}

export const INTENT_CATALOG_ES: Record<string, IntentDef> = { ... };
export const INTENT_CATALOG_EN: Record<string, IntentDef> = { ... };

export const VALID_INTENT_SLUGS = Object.keys(INTENT_CATALOG_ES) as readonly string[];
export const VALID_PROPERTY_SLUGS = ['rincon-del-mar', 'las-morenas', 'huerta-cocotera', 'combinada'] as const;
export const VALID_CITY_SLUGS = [...] as const;

/** Render §INTENT_CATALOG markdown section for system-prompt embedding. */
export function renderIntentCatalogMarkdown(lang: 'es' | 'en'): string { ... }
```

**Cambios al catálogo:**

```ts
// NUEVO intent
propiedad: {
  url_template: '/{property}/',
  requires_property: true,
  accepts_dates: true,
  accepts_guests: true,
  fallback: '/#casas',
  human_label_es: 'info',
  human_label_en: 'info',
  prompt_hint: 'User pide info general de una villa específica',
},

// MODIFICADO: precios + disponibilidad ahora aceptan dates+guests
precios: {
  url_template: '/{property}#tarifas',
  requires_property: true,
  accepts_dates: true,      // NEW
  accepts_guests: true,     // NEW
  fallback: '/#casas',
  human_label_es: 'precio',
  ...
},
disponibilidad: {
  url_template: '/{property}#disponibilidad',
  requires_property: true,
  accepts_dates: true,
  accepts_guests: true,     // NEW
  fallback: '/#casas',
  ...
},
```

**`intent-resolver.ts`:** re-export desde `intent-catalog.ts`. `resolveIntent` ahora propaga `queryParts` al fallback path:

```ts
// Antes del return early para missing_property / invalid_property:
const queryParts = buildQueryParts(def, params);
const fallbackWithParams = appendQueryParts(def.fallback, queryParts);
return { url: fallbackWithParams, used_fallback: true, fallback_reason: 'missing_property' };
```

**`tools-v5.ts`:** `VALID_INTENT_SLUGS = Object.keys(INTENT_CATALOG_ES)`. Sin lista hardcoded.

**`system-prompt-v5.ts` + `system-prompt-v6.ts`:** § INTENT_CATALOG ahora se inyecta vía `renderIntentCatalogMarkdown('es')` en build de blocks (con cache_control ephemeral igual). El markdown se genera del catalog en runtime — drift impossible.

**CI snapshot test `intent-catalog-sync.test.ts`:**

```ts
it('VALID_INTENT_SLUGS matches CATALOG_ES keys', () => { ... });
it('CATALOG_EN has same keys as CATALOG_ES', () => { ... });
it('renderIntentCatalogMarkdown matches snapshot', () => {
  expect(renderIntentCatalogMarkdown('es')).toMatchSnapshot();
});
it('system-prompt v5 contains rendered catalog', () => { ... });
it('system-prompt v6 contains rendered catalog', () => { ... });
```

**Effort:** 4-5h CC

---

### PR2 · Defensive guard runtime + today injection + date validator

**Branch:** `feat/dispatcher-guards`

**Files:**

```
EDIT   packages/agents/greeter/process-tool-use.ts
EDIT   packages/agents/greeter/system-prompt-v5.ts
EDIT   packages/agents/greeter/system-prompt-v6.ts
EDIT   packages/agents/greeter/tools-v5.ts (description text only, schema sigue igual)
EDIT   packages/agents/greeter/tests/process-tool-use.test.ts
```

**`processRouteUserToUrl` cambios:**

```ts
function processRouteUserToUrl(args, ctx, deps, tokens): GreeterResultV5 {
  let effectiveIntent = args.intent_slug;
  let effectiveProperty = args.property;
  let remappedFrom: string | undefined;

  // GUARD 1: LLM emitió property slug como intent
  if (VALID_PROPERTY_SLUGS.includes(args.intent_slug as PropertySlug)) {
    remappedFrom = args.intent_slug;
    effectiveProperty = args.intent_slug as PropertySlug;
    effectiveIntent = 'propiedad';
  }

  // GUARD 2: dates en el pasado → silently drop
  const today = new Date().toISOString().slice(0, 10);
  let effectiveCheckIn = args.check_in;
  let effectiveCheckOut = args.check_out;
  if (args.check_in && args.check_in < today) effectiveCheckIn = undefined;
  if (args.check_out && args.check_out < today) effectiveCheckOut = undefined;

  const resolved = deps.resolveIntent({
    intent_slug: effectiveIntent,
    property: effectiveProperty,
    lang: ctx.lang,
    check_in: effectiveCheckIn,
    check_out: effectiveCheckOut,
    guests: args.guests,
    city: args.city,
  });

  const trackedUrl = deps.wrapClickTracking(resolved.url, {
    intent: effectiveIntent,
    property: effectiveProperty,
    conv: ctx.conv_hash,
    version: ctx.bot_version,
    lang: ctx.lang,
    check_in: effectiveCheckIn,
    check_out: effectiveCheckOut,
    guests: args.guests,
    city: args.city,
    subscriber_name: ctx.subscriber_name,   // NEW
    remapped_from: remappedFrom,            // NEW (for short-link insert log)
  });

  // ... rest
}
```

**`ClickTrackingParams` interface update:** agregar `subscriber_name?: string; remapped_from?: string;`

**`buildSystemPromptBlocksV5` + `V6`:** dynamic context block agrega:

```ts
- Today (YYYY-MM-DD): ${new Date().toISOString().slice(0,10)}
```

Y system-prompt body agrega regla §12 nueva:

```
### 12. Fechas siempre futuras

El context te dice "Today: YYYY-MM-DD". NUNCA emitas check_in o check_out
en pasado relativo a Today. Si el user dice "el 15 de marzo" sin año,
asume el próximo 15 de marzo (este año o el siguiente, lo que sea futuro).
```

**Tool schema** (descripcion solo, no cambia el shape): agregar texto:

> `check_in/check_out`: must be future-relative to the Today date in your context.

**`process-tool-use.test.ts`** new:

```ts
it('remaps property slug as intent_slug to intent=propiedad', () => { ... });
it('drops check_in in the past silently', () => { ... });
it('drops check_out in the past silently', () => { ... });
it('preserves valid future dates', () => { ... });
```

**Effort:** 2-3h CC

---

### PR3 · `bot_short_links` table + `short-link.ts` + handler `/ir/:id`

**Branch:** `feat/short-link-infrastructure`

**Files:**

```
NEW    migrations/0034_bot_short_links.sql
NEW    apps/worker-bot/src/short-link.ts
NEW    apps/worker-bot/tests/short-link.test.ts
EDIT   apps/worker-bot/src/index.ts
EDIT   apps/worker-bot/tests/click-tracking.test.ts (rename → short-link-handler.test.ts)
```

**Migration `0034_bot_short_links.sql`:**

```sql
CREATE TABLE bot_short_links (
  id TEXT PRIMARY KEY,                         -- Patrón B slug, 18-32 chars
  target_url TEXT NOT NULL,                    -- URL pre-resuelta completa (relativa al site)
  property TEXT,                               -- nullable, para fallback post-expiry
  intent_slug TEXT NOT NULL,                   -- intent emitido (después de defensive guard)
  conv_hash TEXT,                              -- tracking del bot turn
  bot_version TEXT,                            -- v5/v6
  lang TEXT NOT NULL DEFAULT 'es',
  remapped_from TEXT,                          -- defensive guard log (property slug que llegó como intent)
  used_fallback INTEGER NOT NULL DEFAULT 0,    -- 1 si resolver retornó fallback
  fallback_reason TEXT,                        -- unknown_intent / missing_property / etc
  click_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL                  -- unix epoch seconds
);

CREATE INDEX idx_short_links_created ON bot_short_links(created_at);
CREATE INDEX idx_short_links_conv ON bot_short_links(conv_hash, created_at);
```

**`short-link.ts` API:**

```ts
const ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789'; // 31 chars, sin confusos
const TTL_SECONDS = 10 * 86400; // 10 días efectivos

const INTENT_LABEL_ES: Record<string, string> = { /* del catalog */ };

export interface CreateShortLinkParams {
  intent_slug: string;
  property?: string;
  resolved_url: string;
  conv_hash?: string;
  bot_version: string;
  lang: 'es' | 'en';
  check_in?: string;
  check_out?: string;
  guests?: number;
  city?: string;
  subscriber_name?: string;
  remapped_from?: string;
  used_fallback: boolean;
  fallback_reason?: string;
}

export async function createShortLink(
  db: D1Database,
  params: CreateShortLinkParams
): Promise<string> {
  // Generate Patrón B slug
  for (let attempt = 0; attempt < 5; attempt++) {
    const slug = generateSlug(params);
    try {
      await db.prepare(`INSERT INTO bot_short_links (...) VALUES (...)`).bind(...).run();
      return slug;
    } catch (e) {
      if (isUniqueConstraintError(e)) continue;
      throw e;
    }
  }
  throw new Error('SHORT_LINK_COLLISION_RETRY_EXHAUSTED');
}

function generateSlug(params): string {
  const intent = slugifyIntent(params.intent_slug, params.lang); // 'precio' from 'precios'
  const name = slugifyName(params.subscriber_name);              // 'erika' or 'huesped'
  const context = slugifyContext(params);                        // 'mayo29' | '5pax' | '20261004'
  const suffix = randomShortString(3);                            // 'x7q'
  return `${intent}-${name}-${context}-${suffix}`;
}

function slugifyName(name?: string): string {
  if (!name) return 'huesped';
  const cleaned = name
    .normalize('NFD')                            // decompose accents
    .replace(/[\u0300-\u036f]/g, '')             // strip diacritics
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')                   // alphanum only
    .slice(0, 12);
  if (!cleaned || /^\d+$/.test(cleaned)) return 'huesped'; // phone numbers, empty
  return cleaned;
}

function slugifyContext(params): string {
  if (params.check_in) {
    // 'mayo29' format
    const d = new Date(params.check_in);
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return `${months[d.getUTCMonth()]}${d.getUTCDate()}`;
  }
  if (params.guests !== undefined) {
    return `${params.guests}pax`;
  }
  // fallback to current date YYYYMMDD
  const now = new Date();
  return `${now.getUTCFullYear()}${String(now.getUTCMonth() + 1).padStart(2, '0')}${String(now.getUTCDate()).padStart(2, '0')}`;
}

export interface ShortLinkLookupResult {
  found: boolean;
  expired: boolean;
  target_url?: string;
  property?: string;
}

export async function lookupShortLink(db: D1Database, id: string): Promise<ShortLinkLookupResult> {
  const row = await db.prepare(`SELECT * FROM bot_short_links WHERE id = ?`).bind(id).first();
  if (!row) return { found: false, expired: false };
  const ageSeconds = Math.floor(Date.now() / 1000) - (row.created_at as number);
  if (ageSeconds > TTL_SECONDS) {
    return { found: true, expired: true, property: row.property as string | undefined };
  }
  // Increment click count async — no bloquea
  await db.prepare(`UPDATE bot_short_links SET click_count = click_count + 1 WHERE id = ?`).bind(id).run();
  return { found: true, expired: false, target_url: row.target_url as string, property: row.property as string | undefined };
}
```

**Handler `GET /ir/:id` (`apps/worker-bot/src/index.ts`):**

```ts
app.get('/ir/:id', async (c) => {
  const id = c.req.param('id');
  const result = await lookupShortLink(c.env.DB, id);
  const siteUrl = c.env.SITE_URL ?? 'https://rincondelmar.club';

  // Casos:
  if (!result.found) {
    // Link inválido / typo / expired-cleaned. Landing genérico.
    return c.redirect(siteUrl, 302);
  }
  if (result.expired) {
    // Link real pero >10d. Graceful redirect a property page o root.
    const target = result.property
      ? `${siteUrl}/${result.property}/`
      : siteUrl;
    return c.redirect(target, 302);
  }
  // Happy path
  return c.redirect(
    result.target_url!.startsWith('http') ? result.target_url! : `${siteUrl}${result.target_url}`,
    302
  );
});
```

**Tests `short-link.test.ts`:**

- generateSlug shape: `precio-erika-mayo29-x7q`
- slugifyName edge cases (vacío, emoji, phone, acentos)
- slugifyContext con check_in, con guests, default fecha
- createShortLink retry on collision (mock D1)
- lookupShortLink: found+fresh, found+expired, not found

**Tests `short-link-handler.test.ts`:**

- `/ir/{valid}` → 302 target_url + click_count++
- `/ir/{expired}` con property → 302 `/{prop}/`
- `/ir/{expired}` sin property → 302 `/`
- `/ir/{invalid}` → 302 `/`

**Effort:** 4-5h CC

---

### PR4 · `wrapClickTracking` refactor + domain switch

**Branch:** `feat/wrap-click-tracking-refactor`

**Files:**

```
EDIT   apps/worker-bot/src/greeter-v5-deps.ts
EDIT   apps/worker-bot/wrangler.toml
EDIT   apps/worker-bot/tests/greeter-v5-deps.test.ts
```

**`greeter-v5-deps.ts` cambios:**

```ts
import { createShortLink } from './short-link';

export interface GreeterV5DepsEnv extends NotifyHumanEnv {
  SITE_URL?: string;       // rincondelmar.club — guest-facing
  BOT_PUBLIC_URL?: string; // bot.rincondelmar.club — DEPRECATED for /ir/, mantain for beds24
  DB: D1Database;
}

export function buildGreeterV5Deps(env: GreeterV5DepsEnv): ProcessToolUseDeps {
  const siteUrl = env.SITE_URL ?? 'https://rincondelmar.club';

  return {
    resolveIntent: resolveIntentImpl,

    wrapClickTracking: async (target: string, params: ClickTrackingParams) => {
      try {
        const slug = await createShortLink(env.DB, {
          intent_slug: params.intent,
          property: params.property,
          resolved_url: target,
          conv_hash: params.conv,
          bot_version: params.version,
          lang: params.lang,
          check_in: params.check_in,
          check_out: params.check_out,
          guests: params.guests,
          city: params.city,
          subscriber_name: params.subscriber_name,
          remapped_from: params.remapped_from,
          used_fallback: false,         // populated por dispatcher si aplica
          fallback_reason: undefined,
        });
        return `${siteUrl}/ir/${slug}`;
      } catch (err) {
        console.error('[wrapClickTracking] short-link creation failed, fallback to legacy', err);
        // Fallback: formato viejo bajo SITE_URL (no bot.)
        return buildLegacyTrackingUrl(siteUrl, params);
      }
    },

    notifyHumanHandoff: async (params) => { ... }, // sin cambios
  };
}

function buildLegacyTrackingUrl(siteUrl: string, params: ClickTrackingParams): string {
  const url = new URL(`${siteUrl.replace(/\/$/, '')}/ir/${params.intent}`);
  if (params.property) url.searchParams.set('prop', params.property);
  if (params.conv) url.searchParams.set('conv', params.conv);
  // ... idem que el viejo
  return url.toString();
}
```

**`wrapClickTracking` ahora es async** — el dispatcher debe `await` la llamada. Update interface en `process-tool-use.ts`:

```ts
export interface ProcessToolUseDeps {
  resolveIntent: ...;
  wrapClickTracking: (target: string, params: ClickTrackingParams) => Promise<string>; // ⚠ async ahora
  notifyHumanHandoff: ...;
}
```

Y `processRouteUserToUrl` ahora retorna `Promise<GreeterResultV5>`.

**`wrangler.toml` route:**

```toml
[[routes]]
pattern = "rincondelmar.club/ir/*"
zone_name = "rincondelmar.club"
```

`bot.rincondelmar.club` permanece (beds24 proxy intacto en `bot.beds24.rincondelmar.club` o `bot.rincondelmar.club/proxy/...` — verificar config actual sin tocar).

**Handler legacy** `GET /ir/{slug}` (path no-hash, e.g. `/ir/disponibilidad`): keep en `index.ts` para compat 60d. Logic: si `:id` no matchea Patrón B regex (`[a-z]+-[a-z0-9]+-[a-z0-9]+-[a-z0-9]{3}`), fallback al viejo `handleBotLinkClick` que llama `resolveIntent(slug, query)`. Misma URL ahora puede ser:
- Nuevo: `/ir/precio-erika-mayo29-x7q` → lookup tabla
- Viejo: `/ir/disponibilidad?prop=X&...` → resolveIntent

```ts
const PATRON_B_REGEX = /^[a-z]+-[a-z0-9]+-[a-z0-9]+-[a-z0-9]{3}$/;

app.get('/ir/:id', async (c) => {
  const id = c.req.param('id');
  if (PATRON_B_REGEX.test(id)) {
    // Nueva ruta short-link
    return handleShortLink(c, id);
  }
  // Legacy: viejo formato `/ir/disponibilidad?prop=...`
  return handleBotLinkClick(c, c.env);
});
```

**Effort:** 3-4h CC

---

### PR5 · CI snapshot test + cleanup cron + smoke

**Branch:** `feat/short-links-ops`

**Files:**

```
EDIT   apps/worker-bot/src/cron.ts
EDIT   apps/worker-bot/tests/cron.test.ts
EDIT   apps/worker-bot/wrangler.toml (verify cron triggers ya existe)
```

**`cron.ts` agrega handler mensual:**

```ts
async function cleanupShortLinks(env: { DB: D1Database }): Promise<{ deleted: number }> {
  const cutoffSeconds = Math.floor(Date.now() / 1000) - (60 * 86400); // 60 días total (10d TTL + 50d buffer)
  const result = await env.DB.prepare(
    `DELETE FROM bot_short_links WHERE created_at < ?`
  ).bind(cutoffSeconds).run();
  return { deleted: result.meta.changes ?? 0 };
}

// En el cron scheduled handler, agregar branch para el cron mensual:
if (event.cron === '0 3 1 * *') { // primer día del mes 03:00 UTC
  const r = await cleanupShortLinks(env);
  console.log(`[cron-cleanup] short-links: ${r.deleted} rows deleted`);
}
```

**`wrangler.toml`:** verificar que el cron de `0 3 1 * *` esté en `[triggers]` (agregar si no):

```toml
[triggers]
crons = [
  "0 */2 * * *",   # knowledge refresh cada 2h (existing)
  "0 3 1 * *",     # cleanup short-links primer día del mes
]
```

**Smoke post-deploy (Alex ejecuta manual):**

```bash
# 1. Verificar /ir/{patron-B} funciona
curl -I https://rincondelmar.club/ir/precio-erika-mayo29-x7q
# Expect: 302 Location

# 2. Verificar legacy /ir/{slug} sigue funcionando
curl -I "https://rincondelmar.club/ir/disponibilidad?prop=rincon-del-mar&conv=test&v=v5&lang=es"
# Expect: 302 Location

# 3. Verificar bot.rincondelmar.club beds24 proxy intacto
curl -H "Authorization: Bearer $BEDS24_PROXY_TOKEN" https://bot.rincondelmar.club/proxy/...

# 4. Generar un bot turn vía ManyChat test subscriber
# Inspect que URL emitida = rincondelmar.club/ir/{patron-B}
```

**Effort:** 1-2h CC

---

## §5 · Tests

| File | Cobertura |
|---|---|
| `intent-catalog-sync.test.ts` | NEW · 4 sources sync + snapshot markdown render |
| `intent-resolver.test.ts` | UPDATE · cubre fallback con params propagados + `propiedad` intent |
| `process-tool-use.test.ts` | UPDATE · defensive guard remap + date-past drop |
| `short-link.test.ts` | NEW · generateSlug + slugify edge cases + retry + lookup |
| `short-link-handler.test.ts` | NEW · /ir/:id flow (valid/expired/not-found) |
| `greeter-v5-deps.test.ts` | UPDATE · wrapClickTracking async + fallback legacy |
| `cron.test.ts` | UPDATE · cleanup short-links mensual |

**Target:** ≥85% coverage en archivos modificados. CI debe pasar verde.

---

## §6 · Definition of done

- [ ] `intent-catalog.ts` exporta CATALOG_ES, CATALOG_EN, VALID_INTENT_SLUGS, VALID_PROPERTY_SLUGS, VALID_CITY_SLUGS, renderIntentCatalogMarkdown
- [ ] `intent-resolver.ts` re-exporta desde catalog, fallback propaga queryParts
- [ ] `tools-v5.ts` deriva enum desde catalog
- [ ] System-prompt v5 + v6 inyectan §INTENT_CATALOG vía render runtime
- [ ] Intent `propiedad` con `url_template: '/{property}/'` funciona
- [ ] `precios` + `disponibilidad` aceptan `accepts_dates + accepts_guests`
- [ ] Resolver fallback URL recibe `check_in/check_out/guests` cuando aplica
- [ ] `processRouteUserToUrl` remap property-slug-as-intent → `propiedad`
- [ ] `today=YYYY-MM-DD` en dynamic context v5 + v6
- [ ] Dispatcher silently drops check_in/check_out < today
- [ ] System-prompt §12 nueva regla "Fechas siempre futuras"
- [ ] `comparar-casas` guidance updated (no prometer "tabla")
- [ ] Migration 0034 `bot_short_links` aplicada en producción
- [ ] `short-link.ts` API + tests
- [ ] Handler `/ir/:id` con Patrón B regex + legacy fallback
- [ ] `wrapClickTracking` async + llama createShortLink + fallback legacy on error
- [ ] Domain route `rincondelmar.club/ir/*` configurada en wrangler.toml
- [ ] Cleanup cron mensual configurado + test
- [ ] CI snapshot test green (catalog ↔ enum ↔ prompt markdown)
- [ ] Smoke test post-deploy: 4 bugs reportados ahora dan URL correcta
- [ ] thread/159 posted con report final + URL ejemplos generados

---

## §7 · Risks + mitigations

| R | Riesgo | Mitigación |
|---|---|---|
| R1 | Resolver fallback propagado a `/#casas` puede no funcionar si la booking card global no lee `check_in/check_out/guests` de query | Pre-flight: verificar que `apps/web/src/pages/index.astro` o componente home booking-card SÍ lee esos params. Si no funciona, este sub-PR queda con flag y se completa cuando frontend lo soporte. |
| R2 | `today=` inyectado rompe ephemeral cache porque cambia diariamente | El bloque dynamic-context NO está cacheado (verified en code). Solo el body del prompt está cacheado con `cache_control: ephemeral`. Sin riesgo. |
| R3 | Defensive guard remap pierde el opening_line del LLM (que mencionaba "Huerta" presumiendo intent específico) | El opening_line del LLM ya menciona la propiedad textualmente — independiente del intent slug. Remap silencioso es correcto. |
| R4 | Hash collision en INSERT después de 5 retries | Probability negligible. 5 retries × (1/31³ por retry) ≈ 1.7e-15 colisión final. Fallback legacy formato viejo si pasa. |
| R5 | Legacy `/ir/{slug}?prop=...` debe seguir funcionando 60d para historiales WhatsApp | PATRON_B_REGEX detecta y delega al handler viejo. Handler viejo intacto. Después de 60d, cleanup separado deprecia. |
| R6 | `wrapClickTracking` ahora async puede romper otros call sites no contemplados | Grep `wrapClickTracking` en codebase pre-PR4 — solo 1 call site (`processRouteUserToUrl`). |
| R7 | Cleanup cron borra rows que algún user todavía tiene en su WhatsApp scroll | 60d total + 10d TTL = ventana real 10d → user clic >10d siempre fue expired-graceful. Cleanup en 60d solo limpia rows ya expired. No-op para users. |
| R8 | D1 `bot_short_links` crece descontrolado si cron falla | Index en `created_at` + Telegram alert si row count >50K (futuro). En esta release: solo cron + log. |
| R9 | Patrón B slug puede generar URLs con palabras inesperadas (e.g., nombre + intent → palabra rara) | Slugify estricto a `[a-z0-9]`. Edge cases probados (acentos, emoji, phone, vacío). Si alguien reporta URL ofensivo: blocklist via mini-feature post-spec. |
| R10 | v6 canary % real desconocido (memoria dice 100%, Alex reporta v=v5 fresco) | Out of scope este DoIt. Brain quick separado tras este DoIt confirma canary status. |

---

## §8 · Execution order (secuencial, NO paralelo)

```
PR1 (intent-catalog single source + propiedad + accepts updates + CI snapshot)
  ↓ merge + green CI
PR2 (defensive guard + today injection + date validator)
  ↓ merge + green CI
PR3 (short-link table + short-link.ts + handler /ir/:id)
  ↓ merge + green CI + migration 0034 applied prod (Alex executes)
PR4 (wrapClickTracking refactor + domain switch wrangler.toml)
  ↓ merge + Alex deploy + DNS verify
PR5 (CI snapshot test final + cleanup cron)
  ↓ merge + smoke
thread/159 posted
```

**Por qué secuencial y no paralelo:** PR2 depende de PR1 (catalog import). PR4 depende de PR3 (createShortLink existe). PR5 limpia tabla creada por PR3. Solo PR1 puede correr aislado, los demás encadenan.

---

## §9 · Halt conditions

CC para inmediatamente y reporta a Alex via Telegram si:

| Condición | Acción |
|---|---|
| Pre-flight check falla (catalog import circular, migration sintáctica, etc.) | Halt + report exact failure |
| Tests rojos después de implementar PR | Halt + report failing test name + diff |
| Out-of-scope finding (e.g., booking card global NO lee query params) | Open issue + halt si bloquea PR1 fallback propagation |
| Tiempo total >24h CC (1.5× budget) | Halt + report progress hasta acá |
| LLM cost >$15 acumulado | Halt + report |
| Cualquier PR depende de Alex decision no contemplada en spec | Halt + Telegram con la pregunta exacta + opciones |

---

## §10 · Pre-flight (CC ejecuta ANTES de PR1)

```bash
# 1. Sync repos
cd <rdm-discussion> && git pull origin main
cd <rdm-bot> && git pull origin main

# 2. Verify thread/158 spec exists
ls <rdm-discussion>/threads/158-*.md
# o el slot real que CC use (≥158)

# 3. Verify D1 migration directory + numbering
ls <rdm-bot>/migrations/ | tail -5
# Confirma que 0034 está disponible (no taken)

# 4. Verify booking card global reads dates+guests params (R1)
grep -E "check_in|check_out|guests" apps/web/src/pages/index.astro apps/web/src/components/*BookingCard* 2>/dev/null

# 5. Verify wrapClickTracking call sites
grep -rn "wrapClickTracking" apps/ packages/ | grep -v node_modules
# Should show 1 call site only

# 6. Verify v5 + v6 prompts en main current
grep -c "INTENT_CATALOG" packages/agents/greeter/system-prompt-v5.ts
grep -c "INTENT_CATALOG" packages/agents/greeter/system-prompt-v6.ts

# 7. Verify ManyChat first_name field name (subscriber_name source)
grep -n "subscriber_name\|first_name" packages/agents/greeter/process-tool-use.ts apps/worker-bot/src/index.ts | head
```

Si pre-flight falla → halt + Telegram Alex.

---

## §11 · Final report (thread/159 template)

CC posts thread/159 con:

1. Resumen de los 5 PRs (números + branch + merged status)
2. Migration 0034 status (applied prod / pending)
3. Tests added (count + coverage delta)
4. CI snapshot diff (catalog markdown rendered)
5. Smoke test results: 4 bugs A-D ahora generan URL correcta — paste URLs ejemplo:
   - Bug A: user pregunta "info Huerta" → `rincondelmar.club/ir/info-huesped-20261004-xxx` → 302 → `/huerta-cocotera/`
   - Bug B.1: user "fechas 29 may - 3 jun 5 pax" sin property → fallback `/#casas?check_in=2026-05-29&check_out=2026-06-03&guests=5`
   - Bug B.2: si LLM emite `check_in=2025-05-29` → silently dropped, URL sin dates
   - Bug C: user "precio para 15" → `/ir/precio-erika-15pax-xxx` → 302 → `/rincon-del-mar#tarifas?guests=15`
   - Bug D: opening_line para `comparar-casas` no promete "tabla"
6. Out-of-scope findings + issues abiertos
7. Total tiempo CC + costo LLM
8. Cualquier desviación del spec + razón

---

**End of spec thread/158.**
