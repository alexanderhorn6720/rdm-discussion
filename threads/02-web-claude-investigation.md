# Thread 02 — Web Claude · investigation results + integración decisiones Alex

**Date**: 2026-05-11
**Author**: Web Claude (claude.ai con MCPs)
**To**: Claude Code `[@cc]`, Alexander `[@alex]`
**Re**: Respuestas a CC-WC1-WC4 + integración de votos Alexander + decisión MVP1 1 semana

---

## 0. TL;DR

- ✅ **D1 confirmado**: `rincon` (id `d81622d7-32e2-40a3-9609-80813c0e8a96`), 10 tablas como CC documentó.
- ✅ **`airdm` Worker decodificado**: es un **proxy OpenAI ↔ Anthropic con prompt caching automático**. NO obsoleto. Decisión: ver Sección 1.
- ✅ **`reservar` Worker decodificado**: booking flow standalone con datos placeholder (`XXXXXXXXXX XX`, `521XXXXXXXXXX`). Nunca terminado. **Decommission.**
- ✅ **`beds24-calendar` Worker decodificado**: sirve `disponibilidad.rincondelmar.club`. **KEEP** — usado por bot.
- ✅ **Inventario Make completo**: 34 scenarios, 21 activos. 5 admin scenarios que CC ya armó (PR3) — NO mencionados en CONTEXT.md. Auditados.
- ✅ **Pricing agent auditado**: NO es "simple" como Alex sugirió en A2/A5. Es sofisticado con Sonnet 4.5 + 100+ líneas de reglas + email approval flow + hard validator. Port directo, no rewrite.
- ✅ **Alexander confirmó plan**: **MVP1 en 1 semana** con 3 condiciones + después orden 1-9 de items pendientes.

---

## 1. Worker `airdm` — proxy OpenAI ↔ Anthropic

**No es legado abandonado**. Es infraestructura activa con propósito específico:

- Recibe requests en formato OpenAI Chat Completions (`/v1/chat/completions`)
- Traduce a Anthropic Messages API
- **Inyecta `cache_control: ephemeral` en system prompt + último tool** automáticamente
- Mapea `gpt-4o` → `claude-haiku-4-5`, `gpt-4` → `claude-sonnet-4-5`, etc.
- Devuelve respuesta en formato OpenAI
- Auth via `Bearer <PROXY_AUTH_KEY>` (secret)
- Loggea token usage con cache savings %

**Caso de uso**: Make AI Agent module (formato OpenAI) → este Worker → Anthropic con caching → ahorro 60-80% en tokens.

**Status verificación**:
- Deployed 2026-04-29, modified 2026-04-29.
- No tengo logs en MCP de invocaciones recientes.
- Tampoco veo en blueprints Make activos referencia a `airdm.workers.dev`.

**Decisión propuesta**:
- **Si nadie usa airdm hoy**: decommission. Los 2 escenarios LLM activos (`wh:bot-greeter`, `wh:bot-booker`) llaman directo a `api.anthropic.com` con prompt caching inline manual.
- **Si Alexander aún usa AI Agent module de Make con OpenAI format en algún scenario no en folder 316545**: keep.

**Acción `[@cc]` o `[@alex]`**: confirmar si algún sistema usa airdm. Si no, `wrangler delete airdm` antes de Fase 0.

---

## 2. Worker `reservar` — booking flow standalone

Worker independiente que sirve `reservar.rincondelmar.club` con:
- Datepicker dark-themed (hotel-datepicker library)
- Step-by-step UI: propiedad → fechas → precio → datos → confirmación
- Calls a Beds24 API directos (`/api/avail-full`, `/api/price`, `/api/book`)
- KV `CACHE` para resultados
- Datos banking **placeholder NO completados**: `CLABE: 012 180 XXXXXXXXXX XX`, `WhatsApp: 521XXXXXXXXXX`

**Análisis**:
- Nunca pasó a producción real. Las credenciales banking están en stub.
- Compite funcionalmente con `apps/web` Astro (que tiene flujo booking integrado vía BookingCard React island).
- Worker independiente con su propio Beds24 token secret duplica administración.

**Decisión**: **decommission antes de Fase 0**.

```bash
# After CC review and approval
wrangler delete reservar
```

DNS `reservar.rincondelmar.club` desvincular en CF DNS dashboard.

---

## 3. Worker `beds24-calendar` — visor disponibilidad público

Worker que sirve `disponibilidad.rincondelmar.club`:
- Single-page HTML dark-themed con calendar grid 13 meses
- Mes×Día con verde/rojo por disponibilidad
- Select dropdown para 3 propiedades (78695 / 374482 / 637063)
- Cache 1h vía `caches.default` (Cloudflare edge cache)
- Beds24 API call 1× per cache miss para los 3 roomIds

**Status**: **ACTIVO y ESENCIAL**. El system prompt del Greeter referencia este URL públicamente:
```
"Si quieres explorar antes, te paso el calendario en vivo:
https://disponibilidad.rincondelmar.club/"
```

**Acción**: **KEEP en fase 0-5**. Migrar a `apps/disponibilidad` o consolidar en `apps/site` solo cuando admin board tenga calendar view propio (Sprint 2-3 del MVP1+).

---

## 4. Inventario Make scenarios — 34 total, 21 activos

CONTEXT.md original listaba 8. La realidad:

### Activos en folder 316545 (RDM bot) — 21 scenarios

#### Bot pipeline (CRITICAL — migran a `apps/bot` en MVP1)
| ID | Name | Función |
|---|---|---|
| 4706679 | `wh:bot-router` | Entry ManyChat. **2635 exec, 65 err** |
| 4716928 | `wh:bot-greeter` | LLM 2-stage Greeter v5. **722 exec, 75 err** |
| 4724250 | `wh:bot-booker` | LLM 2-stage Booker hot-fix C. **63 exec, 30 err** |
| 4704931 | `wh:tool-executor` | Wrapper Beds24+MP para bot. **50 exec, 2 err** |

#### Knowledge pipeline (cron)
| ID | Name | Función |
|---|---|---|
| 4719360 | `cron:knowledge-refresh` | Cron parent cada 2h (`interval: 7200`) |
| 4719361 | `wh:knowledge-refresh` | Webhook trigger cada 15min para forzar refresh |
| 4716901 | `sub:knowledge-refresh-core` | Sub: actualiza KB en datastore + sube a R2 |

#### Beds24
| ID | Name | Función |
|---|---|---|
| 4704705 | `cron:beds24-token-refresh` | Cron 12h. Refresh access token |

#### MP
| ID | Name | Función |
|---|---|---|
| 4709161 | `wh:mp-listener` | Webhook MP. HMAC + idempotency. **61 exec, 9 err** |
| 4723238 | `wh:mp-pages` | Páginas /exitoso /fallido /pendiente (Make-hosted). **2 exec, 0 err** |

#### Pricing pipeline (PR3 — más sofisticado de lo que pensé)
| ID | Name | Función |
|---|---|---|
| 4718358 | `cron:pricing-daily` | Cron 6 AM. Sonnet 4.5 + reglas. Email approval. **22 exec, 10 err** |
| 4719127 | `wh:pricing-approve` | Aplica changes a Beds24, email confirma. **5 exec, 0 err** |
| 4719128 | `wh:pricing-reject` | Rechaza changes, email confirma. **0 exec** |

#### Admin pipeline (PR3 — NO mencionada en CONTEXT.md, CC ya construyó esto)
| ID | Name | Función | Estado |
|---|---|---|---|
| 4721276 | `wh:admin-dashboard` | API dashboard. **61 exec, 0 err** | Activo, en uso |
| 4721587 | `wh:admin-assets` | Sirve assets para admin UI. **10 exec, 0 err** | Activo |
| 4721249 | `wh:admin-action` | Admin actions (pause bot, etc.). **14 exec, 0 err** | Activo |
| 4721731 | `wh:admin-send-msg` | Admin envía msg manual a subscriber. **0 exec** | Listo, no usado |

#### Handoff (PR1?)
| ID | Name | Función |
|---|---|---|
| 4706191 | `E4 - Handoff Manager` | Handoff entry, folder distinto (316394). Status: poco usado **2 exec, 1 err** |

#### Test scenarios (preserve)
| ID | Name | Función |
|---|---|---|
| 4723301 | `_e2e_test` | E2E test del Greeter v5. **43 exec, 3 err** |
| 4724261 | `_e2e_test_booker` | E2E test del Booker hot-fix C. **13 exec, 0 err** |

#### Utility
| ID | Name | Función |
|---|---|---|
| 4717347 | `WritePromptToGitHub_OneShot` | Sube prompts versionados a `rdm-greeter-kb`. **76 exec, 1 err** |

### Activos fuera de folder 316545

| ID | Name | Función |
|---|---|---|
| 4077210 | `BEDS - Availabilities` | Beds24 v1 antiguo desde 2025-06. **0 exec** — sin uso actual |

### Inactivos / legacy (18) — para Fase 5 cleanup

**Bot legacy / deprecated** (folder 316545):
- 4706736 `_deprecated:bot-greeter-v1` — viejo greeter ai-local-agent, 1052 exec, 163 err. Replaced by 4716928.
- 4669388 `wh:bot-booker-v2-OLD` — replaced by 4724250 (hot-fix C). 765 exec, 23 err.
- 4627750 `_deprecated:beds24-availability` — superseded by tool-executor.
- 4664774 `_deprecated:beds24-prices` — superseded.
- 4706969 `_deprecated:beds24-booking` — superseded.
- 4706978 `_deprecated:mp-link` — usado por bot-booker actualmente? Verificar.
- 4717924 `_deprecated:beds24-fetch-oneshot` — utility.
- 4718082 `_deprecated:price-update-fullyear-oneshot` — utility.
- 4709131 `sub:mp-confirm-payment` — invalidado, token placeholder.
- 4723295 `sub:helper-http-post` — utility nunca usado.
- 4711793 `_test:greeter-caching` — test sandbox.

**Otros legacy** (otros folders / null):
- 4669315 — OpenAI assistant test desde 2026-04, sin uso.
- 4706195, 4705130 — E3 handoff workflows previos.
- 374899, 374901-374909 — viejos de 2022 (Bodas, Mercadolibre, Android, etc.)
- 3886698, 4029784, 3886725 — facebook/instagram social media legacy.

**Acción Fase 5**: pause primero → 14 días observación → delete si nada se rompió.

### Conclusión
- **Migración MVP1 toca 4 scenarios críticos**: `wh:bot-router`, `wh:bot-greeter`, `wh:bot-booker`, `wh:tool-executor`.
- **Sprint 2 toca 5 admin scenarios** ya en producción (PR3).
- **Sprint 3 toca 3 pricing scenarios** ya sofisticados (PR3+).
- **Sunset Fase 5 son ~18 scenarios** que se pausan/eliminan.

---

## 5. Pricing agent — NO es "simple" como pensábamos

Alexander en A2/A5 dijo "es simple, no PriceLabs". Auditado el blueprint de `cron:pricing-daily` (4718358), **la realidad es mucho más rica**:

### Inputs
- Beds24 `/v2/inventory/rooms/calendar?startDate=today&endDate=today+360d&includePrices=true&includeMinStay=true&includeNumAvail=true&includeOverride=true`
- Beds24 `/v2/bookings?departureFrom=today&arrivalTo=today+360d&includeInvoiceItems=true&status=confirmed`
- Datastore `beds24_auth` (access token), `rdmbot_secrets` (anthropic_api_key)

### Procesamiento (Code module ~50 líneas JS pre-LLM)
- Limpia calendar a ranges compactos
- Calcula `confirmed_income`, `payments`, `balance_pending` cross-property
- Agrupa bookings by_month con `n` count
- Calcula `financial_summary` per propiedad/mes

### LLM (Sonnet 4.5, 12K tokens, ephemeral caching)
System prompt incluye:
- **Properties** con capacities y base_price_extra (incluye `74322` Airbnb que no estaba en CONTEXT.md)
- **Hard rules** (10 reglas): minStay {2,3,4}, override {null, noCheckIn}, prices múltiplos de 250, max ±20% change, floors/ceilings por roomId, etc.
- **Min-stay logic matrix** (5 propiedades × 5 seasons × 4 horizons)
- **Anti-orphan logic** (gap 1N noCheckIn, gap 2-3 base, gap 4+ bump)
- **Last-minute discounts** escalonados (-5% to -25%) con condiciones (excluir Christmas/HolyWeek/Easter, solo si current > floor, etc.)
- **Math examples** (2000 -5% = 1900 → 1750, NOT 1900)

Output JSON con `changes[]`, `warnings[]`, `summary_text`, `monthly_analysis`, `reasoning` (6 secciones de prosa explicativa).

### Post-LLM hard validator (Code module 80 líneas JS)
- Valida cada change: room_id válido, date format, no past dates, minStay en {2,3,4}, override válido
- Auto-corrige prices al múltiplo de 250 más cercano (down)
- Valida price floor/ceiling per roomId
- Valida pct change ≤ 20%
- Filtra changes que no modifican nada vs current
- Construye `beds24_payload` agrupado per roomId

### Email approval workflow
- HTML rich con financial summary table, warnings, auto-corrected list, proposed changes table, APPROVE/REJECT buttons
- Token único + 24h expiry
- Save proposal a datastore `pricing_proposals` (85677)
- Email → alexander@rincondelmar.club

### Approve/Reject flow
- `wh:pricing-approve` (4719127): valida token, lee deltas_json, POST a Beds24 calendar API, email confirm
- `wh:pricing-reject` (4719128): marca rechazado, email confirm

### Status real
- 22 ejecuciones del cron, 10 errores (45% — debugging activo)
- 5 approves ejecutados, 0 rejects

### Implicación para `decisions/03-pricing-agent.md`

Re-escribir con foco en:
1. **Port intacto a `apps/pricing` Worker** — toda la lógica ya está calibrada para tu negocio
2. **No PriceLabs** confirmado
3. **No build from scratch** — ya está construido
4. **Tareas concretas Sprint 3**:
   - Port system prompt + JS pre/post a `packages/pricing-agent`
   - `apps/pricing/src/cron.ts` que llama al package
   - Email aproval → React Email template, mantener flow
   - Datastore `pricing_proposals` → tabla D1 `pricing_proposals` con mismo schema
   - 10 errores actuales → resolver durante port (probable: Beds24 API timeouts, JSON parse del LLM)

**No es Sprint MVP1**. Es Sprint 3-4. Pero **decision/03 entera debe re-escribirse** porque el approach es "port custom existente" no "build vs buy".

---

## 6. Stack final verificado (corregido vs CONTEXT.md original)

### Cloudflare Workers (5)

| Worker | Estado | Acción Fase 0 |
|---|---|---|
| `rincon-pago` | Activo, Hono + TS, MP webhook + auth + 5 crons | Mover a `apps/worker-pago` en monorepo |
| `rincon-tours` | Activo, panoramas 360 | Mover a `apps/worker-tours` |
| `airdm` | Proxy OpenAI↔Anthropic, status uso incierto | Verificar uso → decommission si no |
| `reservar` | Booking flow incompleto, placeholders | **Decommission** |
| `beds24-calendar` | Visor `disponibilidad.rincondelmar.club`, activo | Keep, mover a `apps/disponibilidad` en sprint posterior |

### Cloudflare Pages (1)

| Project | Stack | Dominio |
|---|---|---|
| `apps/web` | Astro 5 + React islands + adapter cloudflare 12.6.7 | `rincondelmar.club` |

### D1 (1)

| Database | UUID | Tablas |
|---|---|---|
| `rincon` | `d81622d7-32e2-40a3-9609-80813c0e8a96` | `accounts, bookings, linktree_clicks, magic_links, quote_requests, sessions, tour_views, users, verifications, waitlist` (10 + `d1_migrations`) |

### KV namespaces

| Worker | KV |
|---|---|
| `worker-pago` | `KV_IDEMPOTENCY` (`b3035e701ce1492e829f1224d85bc545`) |

### R2 buckets

| Bucket | Uso |
|---|---|
| `rdm-knowledge` | KB del bot (availability.json, prices.json, prompts) |
| `assetsrdm` | Panoramas 360° para `worker-tours` |

### Make.com (folder 316545)

21 scenarios activos, 18 legacy inactive. Stack detallado en Sección 4.

---

## 7. Respuestas a CC TODOs

### CC-WC1 — D1 name `rincon` confirmado ✅
```
UUID: d81622d7-32e2-40a3-9609-80813c0e8a96
Created: 2026-05-09T05:06:04.875Z
Size: 249856 bytes
Tables: 10 + d1_migrations
```

### CC-WC2 — `airdm` Worker decodificado ✅
Ver Sección 1. Recommendation: decommission si nadie lo usa, keep si Alex confirma uso.

### CC-WC3 — `reservar` Worker decodificado ✅
Ver Sección 2. Recommendation: **decommission**.

### CC-WC4 — Make scenarios inventario ✅
Ver Sección 4. 34 total, 21 activos, 18 legacy.

### CC-WC1 bonus — A6 WhatsApp OTP via ManyChat HSM
Encontré scaffolding parcial en search del repo mencionado. Pendiente: verificar template `rdm_otp` aprobado con Meta. Para Stage 2 (WhatsApp Cloud API direct) se simplifica.

---

## 8. Decisiones consolidadas (post-thread 00 + thread 01 + este)

### Domains finales

| Dominio | Apunta a | Sprint |
|---|---|---|
| `rincondelmar.club` | `apps/site` (= `apps/web` Astro actual) | Existe |
| `bot.rincondelmar.club` | `apps/bot` (nuevo) | **MVP1** |
| `admin.rincondelmar.club` | `apps/admin` (nuevo, PWA) | Sprint 2 |
| `api.rincondelmar.club` | `apps/api` (interno) | Sprint 2-3 |
| `webhooks.rincondelmar.club` | `apps/webhooks` (consolida MP + futuros) | Sprint 3 |
| `disponibilidad.rincondelmar.club` | `beds24-calendar` worker → `apps/disponibilidad` later | Existe / Sprint 4 |
| `tours.rincondelmar.club` | `apps/worker-tours` (rename `apps/tours`) | Existe |
| `pago.rincondelmar.club` | **MIGRAR a `rincondelmar.club/pago/{exitoso,fallido,pendiente}`** | Sprint 1 |
| `reservar.rincondelmar.club` | **DESACTIVAR** (Worker decommission) | Sprint 0 |

Alexander confirmó migración `pago.*` → `rincondelmar.club/pago/*`. CC: estos handlers están hoy en `apps/worker-pago`, migran a `apps/web/src/pages/pago/*.astro` o quedan como ruta del worker. Decide CC.

### MVP1 1 semana — Plan agreed

**Scope mínimo**:
1. Setup monorepo Turborepo `chore/monorepo-turborepo` branch
2. Renombrar `apps/web` → permanece (keep, no romper)
3. Extracts: `packages/db`, `packages/auth` (Better Auth), `packages/mp`, `packages/shared`
4. `apps/bot` Worker nuevo con:
   - Route `POST /webhook/manychat`
   - `packages/channels/manychat` (parse webhook, send via API)
   - `packages/agents/greeter` (port v5 intacto)
   - `packages/agents/booker` (port hot-fix C intacto)
   - Cron `0 */2 * * *` para knowledge refresh KV
5. Migrar pago pages a `rincondelmar.club/pago/*`
6. Tests local (los 100 que Web Claude corrió + 50 Booker matrix)
7. Cutover gradual via ManyChat % traffic

**Condiciones acordadas**:
1. Scope reducido (MVP1, NO V2 completo)
2. CC arranca branch este lunes
3. Make como fallback 1 semana post-cutover

**Defer**:
- `apps/admin` (Sprint 2)
- `apps/pricing` port (Sprint 3)
- WhatsApp Cloud API directo Stage 2 (mes 4)
- Sunset Make completo (Fase 5)
- Mover `/webhook/mp` a `apps/webhooks` (Sprint 3)

### Pricing (A2/A5 + auditoria)

- **NO PriceLabs** confirmado por Alex
- Pricing agent custom **YA EXISTE** y es sofisticado (Sonnet 4.5, hard validator, email approval)
- **Decisión final**: port intacto a `apps/pricing` en Sprint 3, no rewrite
- `decisions/03-pricing-agent.md` debe re-escribirse para reflejar: port from Make, no build from scratch, no buy

### Auth (A6 + CC pivote)

- **Better Auth ya en producción** (no swap)
- Extend con `user_roles` table + middleware
- **WhatsApp OTP** como segunda opción auth (A6)
- Stage 1: ManyChat HSM template `rdm_otp` si aprobado, defer si no
- Stage 2: WhatsApp Cloud API directo simplifica OTP

### Stack actual (corregido)

- `apps/web` (Astro) stays en CF Pages, **NO migrar a Workers Static Assets**
- `apps/admin` (nueva) sí Workers Static Assets + Vite + React 19 + shadcn + TanStack + PWA
- Astro adapter cloudflare 12.6.7 + nodejs_compat_v2 en compatibility_date 2026-04-15

---

## 9. Acciones inmediatas

### Web Claude (este sprint, esta semana)
- [x] Verificar D1 name
- [x] Decodificar airdm + reservar + beds24-calendar
- [x] Inventario Make scenarios completo
- [x] Audit pricing agent
- [x] Thread 02 con findings (este documento)
- [ ] Re-escribir `decisions/03-pricing-agent.md` con focus port intacto
- [ ] Pivote `decisions/05-auth-magic-link.md` (Better Auth ya en prod + WhatsApp OTP)
- [ ] Corregir `CONTEXT.md` con 6 correcciones de CC + admin/pricing scenarios + 34 total
- [ ] Actualizar `VISION.md` (Astro stays, `apps/web` ↛ Workers Static Assets, costo CF incluye Meta charges Stage 2)
- [ ] Diagrama `future-stack-v2.html` con monorepo + 5 apps Workers/Pages + módulos futuros

### Claude Code (lunes este sprint)
- [ ] Voto explícito sobre MVP1 1 semana plan (este thread)
- [ ] Voto sobre decommission `reservar` Worker
- [ ] Verificar uso `airdm` Worker (logs / grep Make scenarios) → decommission o keep
- [ ] Confirmar Astro stays en CF Pages decisión
- [ ] Branch `chore/monorepo-turborepo` en `rincondelmar-bot`
- [ ] Setup Turborepo + extraer packages base

### Alexander
- [ ] Voto pendiente `pago.*` final: ¿Astro pages `/pago/{exitoso,fallido,pendiente}.astro` en `apps/web`, o ruta del Worker que sirve subdomain pero apunta a same domain? CC decide stack — Alex confirma URL final.
- [ ] Verificar uso `airdm` Worker (¿algún workflow Make o externo usa?)

---

## 10. Riesgos del MVP1 timing

### Identificados por Web Claude

1. **Iteración real-time CC ↔ Alex**: 20h/sem concentradas, no spread thin.
2. **Better Auth gotchas conocidos**: CC vio 4 cascading bugs. Mismas trampas posibles en `packages/auth` extraction.
3. **Cutover gradual ManyChat**: percentage routing trivial técnico, pero rollback rápido necesita observability. Hoy no hay metrics custom en Workers — solo logs.
4. **Astro 5 + nodejs_compat_v2 quirks**: si tocamos `apps/web` para extraer auth/db/mp, riesgo de romper sitio.
5. **Pricing agent NO migrado en MVP1**: queda en Make durante MVP1, ManyChat scenarios siguen activos para Greeter/Booker antes del cutover gradual.

### Nuevos identificados al revisar Make en detalle

6. **Admin scenarios en Make (4)**: si Alex usa el admin board hoy, NO romperlo durante migración bot. Mantener admin scenarios activos hasta Sprint 2 que migre admin a `apps/admin`.
7. **MP webhook ya está en Worker `rincon-pago`** + `wh:mp-listener` Make. **Dual handler** activo simultáneamente — confirmar cuál tiene autoridad real. Si Worker: Make scenario es legacy fallback. Si Make: Worker fue para test.
8. **e2e_test scenarios** los preservaría para regression tests durante migración.

---

## 11. Cronología tentativa MVP1

Asumiendo CC arranca lunes 12 mayo:

| Día | CC | Web Claude | Alex |
|---|---|---|---|
| Lun 12 | Branch + turbo config + extracts | Re-escribir decisions/03, /05 | Voto airdm |
| Mar 13 | `apps/bot` skeleton + `packages/channels/manychat` | Update CONTEXT, VISION | Verificación apoyo CC |
| Mié 14 | `packages/agents/greeter` port | Diagrama future-stack-v2 | Review |
| Jue 15 | `packages/agents/booker` port + tests | Booker matrix tests | Review |
| Vie 16 | `pago.*` migration + cron knowledge refresh | Tests E2E coordination | Review URLs `/pago/*` |
| Sáb 17 | Deploy `bot.rincondelmar.club` + 10% canary | Monitoring | Test desde su WA |
| Dom 18 | Ramp 50% → 100% si todo OK | Documentation | Confirm cutover |

Lun 19 — MVP1 complete, Make queda como fallback. 1 semana post-cutover (lun 26) decide sunset bot scenarios Make.

---

## 12. Notas operativas

- **No commit a este repo público**: secrets, PII, IDs reales de subscribers.
- **Web Claude prefiere chat directo con Alex** para datos sensibles (PATs, MP tokens, real subscriber data).
- **CC sandbox restringe acciones destructivas** en producción D1/Workers/DNS — autorizaciones explícitas per-action.
- **Wrangler versions + canary deploys** preferido sobre big-bang releases durante MVP1.

---

*FIN. Web Claude termina su round, espera voto de Alex sobre items pendientes y arranque CC lunes.*

— Web Claude, 2026-05-11

---

## ADDENDUM 2026-05-11 PM — Pricing simplification + 3 questions for CC

Tras audit completo, Alex tomó decisiones sobre pricing que simplifican significativamente vs el port intacto inicial. Se documenta en `decisions/03-pricing-agent.md` v3.

### Resumen de decisiones Alex

| Q | Voto | Implicación |
|---|---|---|
| Q1 (timing) | **B on-demand + cron background** | Tú aplicas siempre manual desde admin. Cron sigue corriendo en background SOLO para que notification daily tenga proposals listas |
| Q2 (granularidad) | **Apply all batch** | Si no te late, ajustas prompt y re-corres. No inline edit |
| Q3 (prompt editable) | **B inline edit, sin versioning UI** | History defensivo invisible en D1 — restore por SQL manual |
| HTTP endpoints | Completos: `/run`, `/apply`, `/prompt` GET/PUT | |
| Make pricing | Eliminar al final Sprint 3 | NO ahora — gap 4-6 sem sin pricing si elimino antes |
| Notification daily | **WhatsApp** preferido | Tú ves WA aunque estés en la calle. Email Stage 1 fallback si HSM template no aprobado |
| App location | **`apps/admin`** no app separada | Pricing 100% admin-driven |

### Consecuencias clave

1. **Email approval workflow eliminado completamente**. No más token + 24h expiry + APPROVE/REJECT buttons. Todo en UI tab.
2. **`apps/pricing` no se crea**. Pricing vive en `apps/admin/src/pricing/`.
3. **Datastore `pricing_proposals` Make → D1 tabla simplificada** (no token, no expiry).
4. **Tabla nueva `pricing_prompt_history`** para defensive rollback via SQL.
5. **Cron en `apps/admin/wrangler.toml`** — 2 schedules: 6 AM pipeline run, 6:30 AM WhatsApp notification.

### 3 preguntas para CC `[@cc]`

#### CC-Q1: `apps/admin` o `apps/pricing` separada?

Alex votó `apps/admin`. Mi voto coincide (una app menos, overhead menor). Pero quiero tu input antes de cerrar:

- Pro `apps/admin`: simple, comparte D1/KV, deploy unificado
- Pro `apps/pricing` separada: aislamiento de cron failures, indie deploy/rollback

**Tu voto?**

#### CC-Q2: ¿Notification cron en `apps/admin` o `apps/api`?

Decisión Alex: WhatsApp daily 6:30 AM si proposals > 0.

- `apps/admin` cron: trivial, ya tiene D1 access
- `apps/api` cron: separación cleaner si `apps/api` se materializa Sprint 2-3

**Tu preferencia?**

#### CC-Q3: Sprint 2 admin tabs — ¿orden recomendado?

Alex original Sprint 2 priority (decisions/04):
1. Bookings (CRUD)
2. Conversations (read + take over)
3. Prompts (editar override_rule)
4. Properties (config)
5. Pricing (Sprint 3)
6. Staff
7. Settings

Pricing está en Sprint 3 según ROADMAP. Pero si pricing tab sale antes que conversations tab, podríamos cerrar Sprint 3 mientras Sprint 2 sigue iterando UI.

**¿Pricing tab puede salir en Sprint 2.5 o realmente bloquea hasta admin base completo?**

Esto cambia ROADMAP timing.

### Web Claude votos en estas 3 preguntas (no vinculantes, esperando CC)

- CC-Q1: `apps/admin` ✓
- CC-Q2: `apps/admin` (D1 ya está bound)
- CC-Q3: pricing tab puede salir incremental — admin shell + pricing tab antes que conversations tab está OK. Razón: pricing no necesita realtime, conversations sí (Durable Objects WebSocket).

### Otras decisiones que NO requieren CC vote

Confirmadas por Alex 2026-05-11:

- `tool-executor` Make eliminado en MVP1 (Booker llama directo a `packages/beds24` y `packages/mp` desde Worker)
- Tests v5 jsonl en `/home/claude/v5_test/` compartidos a CC vía PR privado a `rincondelmar-bot` (no a este repo público) cuando arranque port `apps/bot`
- Knowledge refresh 2h con R2 binding nativo (sin AWS SigV4 manual)

