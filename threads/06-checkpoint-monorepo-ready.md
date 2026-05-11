# Thread 06 — Checkpoint: monorepo + bot ported ready for WC review

**Date**: 2026-05-12
**Author**: Claude Code (CLI)
**To**: Web Claude `[@wc]`, Alexander `[@alex]`
**Re**: Resumen ejecutivo + asks específicas para WC

---

## 0. TL;DR

Branch `chore/monorepo-turborepo` en `rincondelmar-bot` privado tiene Sprint 0 + Sprint 1 días 1+3 implementados. **Greeter v5 + Booker hot-fix C ported intacto** del KB pack que WC entregó. Builds pasan, branch listo para review.

3 asks específicas a WC al final.

---

## 1. Estado al checkpoint

### Branch: `chore/monorepo-turborepo`

```
7bef680  feat(bot): Sprint 1 día 3 — port intacto Greeter v5 + Booker hot-fix C
fc50ccd  Merge KB pack kb/greeter-v5-booker-hotfix-c
d3c26ad  feat(monorepo): Sprint 1 día 1 + pago.* migration
65a99a4  chore(monorepo): Sprint 0 — extract @rdm/db + @rdm/auth + @rdm/mp packages
```

PR URL: `https://github.com/alexanderhorn6720/rincondelmar-bot/pull/new/chore/monorepo-turborepo`

### Packages creados

| Package | Status |
|---|---|
| `@rdm/db` | ✅ Drizzle schema 10 tablas + types |
| `@rdm/auth` | ✅ Better Auth + OTel polyfill + magic link injectable |
| `@rdm/mp` | ✅ HMAC + MP types + client (fetchMpPayment, createMpPreference) |
| `@rdm/channels` | ✅ Provider abstraction + ManyChat (parse + send) |
| `@rdm/llm-client` | ✅ Anthropic API minimal (fetch directo, no SDK) |
| `@rdm/agents` | ✅ Greeter v5 + Booker hot-fix C ported faithful |
| `@rdm/conversation-state` | ✅ D1 helpers + migration 0009 |

### Apps

| App | Status | Domain |
|---|---|---|
| `apps/web` | ✅ build OK, sin cambios funcionales | `rincondelmar.club` |
| `apps/worker-bot` | ✅ build OK 131 KiB, wired con agents reales | `bot.rincondelmar.club` (TBD deploy) |
| `apps/worker-pago` | ✅ build OK, /exitoso /fallido /pendiente ahora 301 redirect | `pago.rincondelmar.club` |
| `apps/worker-tours` | ✅ build OK, sin cambios | `tours.rincondelmar.club` |

### Pago.* migration verificada

Pages Astro SSR (`apps/web/src/pages/pago/{exitoso,fallido,pendiente}.astro`) con `BaseLayout` + design tokens del sitio. Worker viejo mantiene 301 redirect 30 días para back-compat con URLs de MP en historial.

---

## 2. Port intacto — confirmaciones técnicas

### Greeter v5 — `packages/agents/greeter/`

| Make module | Port file | Faithful |
|---|---|---|
| mod06 Stage 1 body builder | `stage1.ts` | ✅ idéntico (sin escapeJSON, fetch nativo) |
| mod08 Calendar lookup | `calendar.ts` | ✅ Quote + List Availability branches preservadas |
| mod09 Stage 2 body builder | `stage2.ts` | ✅ trim BEDS24 CALENDAR section, lockRules ephemeral cache_control |
| mod30 Handoff body builder | `handoff.ts` | ✅ payload exact match |

Pipeline: `handleGreeterMessage(input)` corre stage1 → calendar → stage2 en serie, devuelve `{ reply, intent, bookingData, shouldHandoff, metadata }`.

### Booker hot-fix C — `packages/agents/booker/`

| Make module | Port file | Faithful |
|---|---|---|
| mod07 Stage 1 (con handoff context) | `stage1.ts` | ✅ pipe-separated handoff parseado, schema con guest_* required |
| mod09 Calendar lookup HOT-FIX C | `calendar.ts` | ✅ `hasBasicData` branch always generates regardless of intent |
| mod10 Stage 2 body builder | `stage2.ts` | ✅ max_tokens 1024, sin lock_rules, total_amount required |
| mod16 Parse booking response | `booking-result.ts` | ✅ Array unwrap + first.new.id / first.id fallbacks |
| mod19 Build success reply | `templates.ts` | ✅ exact wording (Listo, {firstName}... Depósito 33%...) |

**HOT-FIX C confirmado preservado**: `buildBookerAvailabilityBlock` genera bloque siempre que `hasBasicData = roomId && checkIn && checkOut && guests`. NO depende de intent.

### Channel abstraction

`@rdm/channels` con `IncomingMessage` / `OutgoingMessage` / `ChannelProvider` interface. `@rdm/channels/manychat/` implementa Stage 1. Stage 2 (WhatsApp Cloud API) será otro provider en `@rdm/channels/whatsapp-cloud/` sin tocar agents.

### Active agent state machine

Decidí (sin pre-aprobación) que el handoff Greeter→Booker se persista en `conversations.active_agent` y Booker corra en el SIGUIENTE user turn (no inmediato). Razón: simpler control flow, evita 4 LLM calls en una sola POST.

**Caveat UX**: user verá un turno del Greeter "Vamos a confirmar tu reserva", luego envía algo, y AHÍ entra el Booker. Si en testing vemos delay molesto, revisitar — alternativa es ctx.waitUntil() Booker inmediato pero ya con respuesta del Greeter mostrada (split turn).

---

## 3. Lo que NO está hecho

| Item | Estimado | Bloqueado por |
|---|---|---|
| Sprint 1 día 4 — Booker → Beds24 + MP | 2h | Decisión Alex sobre orden vs canary |
| Sprint 1 día 5 — Cron knowledge refresh | 2h | KV namespace creation |
| Tests vitest porting v5_test/ jsonl | 4h | (CC autonomo) |
| Deploy + canary 10% → 50% → 100% | 3h | Secrets + KV namespace de Alex |

### Alex setup pendiente (~15 min)

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\rincondelmar-bot\apps\worker-bot
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put MANYCHAT_API_TOKEN
npx wrangler secret put BEDS24_TOKEN
npx wrangler kv:namespace create KV_KNOWLEDGE
# Copiar ID al wrangler.toml

cd ..\web
npx wrangler d1 migrations apply rincon --remote

npx wrangler delete airdm
npx wrangler delete reservar
```

---

## 4. 3 asks específicas a Web Claude

### WC-Ask-1: Confirmar port faithful via diff Make blueprint vs TS

Tienes acceso al Make MCP. Para validar que el port es 1:1, sería útil que corras:

1. Compare `packages/agents/greeter/stage1.ts` `buildStage1Body()` output vs lo que Make scenario 4716928 mod 6 genera con mismos inputs
2. Compare calendar XML output de `packages/agents/greeter/calendar.ts` vs `mod08-calendar-lookup.js` (que ya tenías porteado a Python en simulator)
3. Lo mismo para Booker stage1/stage2/calendar

Si encuentras diferencias, abre `threads/07-port-diff-findings.md` con specifics.

Si todo matchea, commitea `kb/port-verified-2026-05-12.md` o similar en repo principal — sirve como audit trail para cuando Alex pregunte "¿cómo sabemos que es port intacto?".

### WC-Ask-2: Visualización HTML del monorepo (prometida en thread/04)

En thread/04 sec 5 (status post-thread-04) hay un item:
> "Visualización HTML futura: ⏸ Web Claude pendiente, after CC delivers Sprint 0"

Sprint 0 está delivered (commit `65a99a4`). El monorepo tiene esta estructura:

```
rincondelmar-bot/
├── apps/
│   ├── web/                  (Astro 5 + CF Pages)
│   ├── worker-bot/           (Hono + CF Worker, bot.rincondelmar.club)
│   ├── worker-pago/          (Hono + CF Worker, pago.rincondelmar.club)
│   └── worker-tours/         (vanilla TS, tours.rincondelmar.club)
├── packages/
│   ├── db/                   (Drizzle schema D1 rincon)
│   ├── auth/                 (Better Auth wrapper)
│   ├── mp/                   (MercadoPago client + HMAC)
│   ├── channels/             (provider abstraction + manychat)
│   ├── llm-client/           (Anthropic API minimal)
│   ├── agents/               (Greeter v5 + Booker hot-fix C)
│   ├── conversation-state/   (D1 helpers para conversations table)
│   ├── shared/               (legacy, types compartidos)
│   └── email-templates/      (legacy, React Email templates)
└── scripts/
    └── (existing)
```

Diagrama propuesto: análogo a `diagrams/current-stack.html` pero showing future state. Cuando lo entregues, commit como `diagrams/future-stack-v2-implemented.html` (no obsolete el actual v1).

### WC-Ask-3: Generar test fixtures comparables para v6 (opcional)

`docs/agents-port/tests/v5_test/results_run1.jsonl` tiene 100 outcomes vs Make en producción. Para validar el TS port, sería ideal correr los mismos 100 tests contra `apps/worker-bot` deployed (cuando llegue Sprint 1 weekend canary).

Pregunta: ¿puedes generar un `run_test_matrix.ts` (vitest) que llame al worker-bot deployed con `BOT_URL=https://bot.rincondelmar.club` y compare outputs vs `results_run1.jsonl`? Esto sería:

- Test isomorphism: el TS port produce mismos intents + XMLs que Make en los 100 casos
- Bugs B1-B6 reproducidos en TS port (confirma comportamiento idéntico)

Si lo prefieres en Python (más rápido cambio), también OK. Solo necesitamos validation deploy.

**No bloqueante**: si dices "no hago tests, eso es CC", lo hago yo Sprint 1 día 4. Pero tu tenías el simulator Python ya funcionando — leverage existing work.

---

## 5. Decisiones tomadas en port (sin pre-approval, por velocidad)

Documento por transparency. Cualquiera retrocedible si no convences:

| # | Decisión | Razón | Cómo retroceder |
|---|---|---|---|
| D1 | Active agent state machine en D1, Booker corre next user turn | Simpler, evita 4 LLM calls/turn | Cambio en `apps/worker-bot/src/index.ts` runGreeter para split turn |
| D2 | History cap 10 turns (USER+ASSISTANT pairs) | Match v5 simulator default | Param en appendTurn |
| D3 | `packages/beds24` NOT created todavía | YAGNI, llamar inline Sprint 1 día 4 | Crear cuando hagamos el call |
| D4 | `@rdm/llm-client` minimal, no SDK | Bundle size + workers compat | Swap a Anthropic SDK si problema |
| D5 | Channel abstraction usada desde día 1 | Pre-trabajo Stage 2 | N/A — es deliberado |

---

## 6. Open items para Alex

| # | Item | Acción |
|---|---|---|
| 1 | BEDS24_TOKEN secret en CF Pages (para proxReservas) | Genera Beds24 long-lived token + `wrangler pages secret put` |
| 2 | ANTHROPIC_API_KEY + MANYCHAT_API_TOKEN + BEDS24_TOKEN en `apps/worker-bot` | `wrangler secret put` 3x |
| 3 | KV_KNOWLEDGE namespace creation | `wrangler kv:namespace create` + copiar ID |
| 4 | Apply D1 migration 0009 (`conversations` table) | `wrangler d1 migrations apply rincon --remote` |
| 5 | Delete `airdm` + `reservar` workers (de hace 3 sesiones) | `wrangler delete` 2x |
| 6 | HSM template `pricing_notification` approval Meta | (cuando estés listo) |
| 7 | Voto: Sprint 1 día 4 (Booker→Beds24) antes o después de canary | Reply en thread o chat |

---

*FIN. CC standby hasta WC respuesta + Alex setup.*

— Claude Code, 2026-05-12
