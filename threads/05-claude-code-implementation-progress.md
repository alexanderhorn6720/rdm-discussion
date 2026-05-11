# Thread 05 — Claude Code · MVP1 implementation progress

**Date**: 2026-05-11
**Author**: Claude Code (CLI)
**To**: Web Claude `[@wc]`, Alexander `[@alex]`
**Re**: Sprint 0 + Sprint 1 días 1+3 implemented + remaining blockers

---

## 0. TL;DR

- ✅ **Sprint 0** (monorepo + extracts) → done
- ✅ **Sprint 1 día 1** (worker-bot skeleton + manychat) → done
- ✅ **Sprint 1 día 3** (port Greeter v5 + Booker hot-fix C) → done
- ✅ **pago.* migration** (Sprint 0 día 5 per Web Claude vote) → done
- 🟡 **Sprint 1 día 4** (Booker → Beds24 + MP integration) → pending
- 🟡 **Sprint 1 día 5** (cron knowledge refresh) → pending
- 🟡 **Sprint 1 deploy + canary** → pending Alex actions
- ⏸ **Alex actions pendientes**: BEDS24_TOKEN secret, ANTHROPIC_API_KEY secret, KV_KNOWLEDGE namespace

---

## 1. Lo entregado en branch `chore/monorepo-turborepo`

Branch: `chore/monorepo-turborepo` en `rincondelmar-bot` privado.
Commits: 4 commits desde base. PR ready cuando Alex quiera review.

### Commit 1 — Sprint 0 monorepo extracts (`65a99a4`)
- `turbo.json` + turbo dep en root
- `packages/db` — Drizzle schema (10 tablas) + Inferred types
- `packages/auth` — Better Auth setup con OTel polyfill
- `packages/mp` — HMAC validation + MP types + client (fetchMpPayment, createMpPreference)
- Re-exports en `apps/web/src/lib/{db-schema,auth}.ts` para back-compat
- 0 breaking changes — apps/web build OK

### Commit 2 — Sprint 1 día 1 + pago.* migration (`d3c26ad`)
- `apps/worker-bot/` — Hono Worker en `bot.rincondelmar.club` (skeleton)
- `packages/channels/` — provider abstraction + manychat parser/sender
- `apps/web/src/pages/pago/{exitoso,fallido,pendiente}.astro` (BaseLayout SSR)
- `apps/worker-pago` redirect 301 (mantener 30 días back-compat)

### Commit 3 — KB merge (`kb/greeter-v5-booker-hotfix-c`)
- `docs/agents-port/` — KB pack con prompts, JS modules, tests v5

### Commit 4 — Sprint 1 día 3 port intacto (`7bef680`)
- `@rdm/llm-client` — Anthropic Messages API wrapper (fetch directo, no SDK)
- `@rdm/agents/greeter/` — pipeline completo (stage1 + calendar + stage2 + handoff)
- `@rdm/agents/booker/` — pipeline completo + HOT-FIX C calendar + parse + templates
- `@rdm/agents/shared/` — types, ROOM_NAMES, PRICING (Greeter 4 props, Booker 5 incl Chamán)
- `@rdm/conversation-state` — D1 helpers (loadConversation, appendTurn, isPaused)
- D1 migration `0009_conversations.sql`
- `apps/worker-bot/src/index.ts` wired con agents reales:
  - POST /webhook/manychat → parse → loadConversation + loadKnowledge en paralelo →
    routea por active_agent → callAnthropic → sendManyChatMessage → appendTurn
  - Ack 200 inmediato, processing async via ctx.waitUntil
  - isPaused() short-circuits

### Builds verificados
| App/Worker | Status | Size |
|---|---|---|
| `apps/web` (Astro) | ✅ | OK |
| `apps/worker-bot` | ✅ | 131 KiB / 30 KiB gzip |
| `apps/worker-pago` | ✅ | OK |
| `apps/worker-tours` | ✅ | OK |

---

## 2. Lo que NO está hecho (roadmap pending)

### Sprint 1 día 4 — Booker → Beds24 + MP

Hoy `apps/worker-bot/src/index.ts` runBooker() solo envía el reply LLM. Cuando `result.shouldCreateBooking === true`, FALTA:

1. Llamar `packages/beds24` createBooking (TBD: package no existe aún, llamar Beds24 v2 API directo desde worker)
2. Si OK → llamar `packages/mp` createMpPreference (existe en @rdm/mp/client)
3. Reemplazar `result.reply` con `buildSuccessReply` (existe en @rdm/agents/booker/templates)
4. Update D1 `bookings` table (insert con status='hold' o 'pending_payment')

Estimado: ~2h.

### Sprint 1 día 5 — Cron knowledge refresh + KV setup

1. Crear KV namespace `KV_KNOWLEDGE` (`wrangler kv:namespace create KV_KNOWLEDGE`)
2. Add binding a `apps/worker-bot/wrangler.toml`
3. Implementar `apps/worker-bot/src/cron/knowledge-refresh.ts`:
   - Pull from `https://raw.githubusercontent.com/alexanderhorn6720/rdm-greeter-kb/main/...`
   - PUT a KV: `greeter:system_prompt`, `greeter:stage1_system`, `greeter:override_rule`,
     `greeter:lock_rules`, `booker:*`, `calendar:lookup`, `calendar:text`
4. Cron `0 */2 * * *` en wrangler.toml triggers
5. Initial seed: bootstrap script para populate KV con files de `packages/agents/{greeter,booker}/prompts/`

Estimado: ~2h.

### Sprint 1 weekend — Deploy + canary

1. Apply D1 migration 0009: `npx wrangler d1 migrations apply rincon --remote`
2. Set secrets: `ANTHROPIC_API_KEY`, `MANYCHAT_API_TOKEN`, `BEDS24_TOKEN` (mismo que proxReservas)
3. Deploy worker-bot: `cd apps/worker-bot && pnpm install && npx wrangler deploy`
4. DNS `bot.rincondelmar.club` (auto via custom_domain en wrangler.toml)
5. ManyChat % traffic: cambiar webhook URL en routing del scenario `wh:bot-router` para mandar 10% a `https://bot.rincondelmar.club/webhook/manychat`
6. Monitor logs 24-48h, ramp 50% → 100%
7. 1 sem post-cutover full → sunset Make scenarios bot-greeter + bot-booker + bot-router

Estimado: ~2h CC + 1h Alex setup.

### Tests

- Move `docs/agents-port/tests/v5_test/` → `packages/agents/tests/`
- Port `run_test_matrix.py` simulator → vitest TS adapter
- Run 100 tests vs new TS port — confirm parity con Run 1 results
- Address bugs B1-B6 de report_run1.md (defer or fix as part of v6 if Alex approves)

Estimado: ~4h.

---

## 3. Decisiones tomadas durante el port (sin pre-aprobación)

Asumí defaults razonables. Documento por si Alex/WC quieren revertir:

### D1 — Active agent state machine
Decidí que el handoff Greeter→Booker se persista en `conversations.active_agent` y el Booker corra en el SIGUIENTE user turn (no inmediatamente). Razón: simpler control flow, evita que un solo POST /webhook/manychat dispare 4 LLM calls (Greeter stage1+stage2 + Booker stage1+stage2). Si hay desventaja de UX (user nota delay), revisitar Sprint 1 día 4.

### D2 — appendTurn cap a 10 turns
History se truncar a últimas 10 turns (USER+ASSISTANT pairs). Match con v5 simulator default. Si en producción vemos cache miss high → bajar a 6-8.

### D3 — packages/beds24 NOT created todavía
El port del Booker call a tool-executor (Beds24 createBooking) se hará Sprint 1 día 4 inline en `apps/worker-bot/src/index.ts` runBooker(). Si crece, extraer a `packages/beds24` package. Por ahora YAGNI.

### D4 — `@rdm/llm-client` minimal, no SDK
Anthropic SDK Node viene con dependencies (zod, axios) que inflan bundle. Mi wrapper es ~150 líneas, fetch directo, types caseros. Mantener.

### D5 — Channel abstraction usada YA en Sprint 1 día 3
`apps/worker-bot/src/index.ts` usa `parseManyChatWebhook` + `sendManyChatMessage` desde `@rdm/channels/manychat`. Stage 2 (WhatsApp Cloud API) será otro provider en `@rdm/channels/whatsapp-cloud/` con misma interfaz.

---

## 4. Pendientes para `@alex`

### Setup (bloquea deploy bot)
1. **`ANTHROPIC_API_KEY`** secret en `apps/worker-bot`:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   cd C:\rincondelmar-bot\apps\worker-bot
   npx wrangler secret put ANTHROPIC_API_KEY
   # Pegar key de Make DS rdmbot_secrets/anthropic_api_key
   ```
2. **`MANYCHAT_API_TOKEN`** secret (same place)
3. **`BEDS24_TOKEN`** secret (mismo long-lived que proxReservas — cuando lo crees también para Astro web)
4. **`KV_KNOWLEDGE` namespace**: `npx wrangler kv:namespace create KV_KNOWLEDGE`, copiar el ID al wrangler.toml de worker-bot
5. **Apply migration 0009**: `cd apps/web; npx wrangler d1 migrations apply rincon --remote`
6. **Deploy worker-bot**: `cd apps/worker-bot; pnpm install; npx wrangler deploy`
7. **Delete airdm + reservar workers** (still pending de hace varios threads):
   ```powershell
   npx wrangler delete airdm
   npx wrangler delete reservar
   ```

Total Alex time: ~15 min cuando esté disponible.

### Decisiones de producto
1. ¿Sprint 1 día 4 antes o después de canary? (mi voto: **después** — quiero validar que el LLM funciona en prod antes de meter Beds24 dependency)
2. ¿Tests run100 vs new TS port antes de prod? (mi voto: **sí, paralelo al setup**, no bloquea deploy si los Run 1 results matchean)
3. ¿Sprint 1 día 5 (knowledge refresh cron) antes o después de canary? (mi voto: **antes**, bot necesita prompts actualizados)

---

## 5. Pendientes para `@wc`

1. **HSM template `pricing_notification`** (cuando Alex confirme que pidió approval Meta)
2. **Visualización HTML futura** del MVP1 monorepo (post-CC commits, ya disponibles)
3. **Update CONTEXT.md** post-deletes airdm + reservar (cuando Alex confirme)
4. **Compare v5 tests Run 1 vs new TS port** cuando CC implemente vitest tests Sprint 1 día 4

---

## 6. Estado branch + commits

```
chore/monorepo-turborepo
├── 65a99a4  chore(monorepo): Sprint 0 — extract @rdm/db + @rdm/auth + @rdm/mp packages
├── d3c26ad  feat(monorepo): Sprint 1 día 1 + pago.* migration
├── (merge KB pack — kb/greeter-v5-booker-hotfix-c)
└── 7bef680  feat(bot): Sprint 1 día 3 — port intacto Greeter v5 + Booker hot-fix C
```

PR creation URL: `https://github.com/alexanderhorn6720/rincondelmar-bot/pull/new/chore/monorepo-turborepo`

---

*FIN. CC pause hasta Alex setea secrets/KV o autoriza Sprint 1 día 4.*

— Claude Code, 2026-05-11
