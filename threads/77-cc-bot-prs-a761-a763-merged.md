# Thread 77 — CC-Bot: 3 PRs autonomous (greeter_turns + WhatsApp hybrid + Airbnb link)

**Date**: 2026-05-16 ~03:10 UTC
**Author**: Claude Code (CC-Bot)
**To**: WC `[@wc]` + Alex `[@alex]`
**Re**: Alex authorization Camino A+B+C autonomous mode
**Status**: 🟢 3 PRs merged, esperando Alex deploy (1 migration + wrangler)

---

## TL;DR

Mientras canary v5 está a 50% LIVE (Alex jump 0→50 aggressive), CC entregó:

| PR | Scope | Status | Deploy needs |
|---|---|---|---|
| **#54 (A7.6.1)** | greeter_turns D1 table + log writes + dashboard sections | ✅ merged | migration 0025 + wrangler deploy |
| **#55 (A7.6.2)** | WhatsApp hybrid handoff (channel routing) | ✅ merged | wrangler deploy + opt-in env var |
| **#56 (A7.6.3)** | Airbnb booking link en Telegram (channel=airbnb) | ✅ merged | migration 0026 + wrangler deploy |

**Tests**: worker-bot **401/401** passing (+22 nuevos). Cero regresiones.

---

## 1. PR #54 A7.6.1 — greeter_turns logging (CRÍTICO para canary observability)

### Por qué urgente

Canary 50% LIVE = real users en v5 ahora. Sin este PR, no podés evaluar:
- Tool usage exact breakdown (route/clarification/handoff/escalate counts)
- v4 vs v5 latency p50/p95 comparison
- Anti-loop trigger frequency
- Sample opening_lines (QA: Felix consistency, ausencia precios)

### Cambios

- **Migration 0025**: nueva tabla `greeter_turns` (version, intent, tool_used,
  intent_slug, property, lang, recommended_url, tokens_*, latency_ms,
  turn_count, loop_detected, escalate_reason, opening_line_preview, user_msg_preview)
  + 4 índices (turn_at DESC, version+turn_at, intent+turn_at, subscriber+turn_at)

- **Worker**: `greeter-turns-log.ts` con `logGreeterTurn()` defensive INSERT
  (fire-and-forget, fail = log warn, NO bloquea respuesta al user)

- **Llamado desde** ambos paths v4 (`runGreeter`) y v5 (`runGreeterV5Path`)
  post-LLM call. Captura latencia end-to-end del greeter.

- **Dashboard `/admin/bot-metrics`** 4 secciones nuevas (reemplazan el TODO):
  - Tool usage breakdown v5 (counts + %)
  - v4 vs v5 latency comparison (avg + p50 + p95 + tokens + cache hits)
  - Anti-loop metrics (bot_loop count + fallback count + escalate by reason)
  - Sample openings v5 last 20 (QA)

---

## 2. PR #55 A7.6.2 — WhatsApp hybrid handoff (wishlist Alex #6)

### Diseño

Nueva env var `HANDOFF_NOTIFY_CHANNEL`:

| Value | Comportamiento |
|---|---|
| `'telegram'` | DEFAULT — solo TG (legacy preservado, sin opt-in nada cambia) |
| `'whatsapp'` | solo WA via ManyChat (donde Karina/Alex responden) |
| `'both'` | TG + WA paralelo (transición segura) |

Operational alerts (`intent='cron_alert:*'`) **siempre TG** (override del env).

### Implementación

- `notifyHumanHandoff` refactor: branch TG + branch WA pueden correr juntos
- `sendHandoffViaWhatsApp` helper reusa pattern de `alerts.ts sendAlertToAlex`
  (ManyChat setCustomField MakeMsg + sendFlow → Alex's subscriber)
- Defensive: si un branch falla, otro puede succeed → ok=true si AT LEAST ONE
- Legacy code path eliminado (era dead code post-refactor)

### Activar WhatsApp

Sin cambios = nada cambia. Para opt-in WA, en `wrangler.toml`:

```toml
[vars]
HANDOFF_NOTIFY_CHANNEL = "whatsapp"   # solo WA
# o "both" para TG + WA simultáneo (transición)
```

Después `wrangler deploy`. NO requiere migration, NO secrets nuevos.

---

## 3. PR #56 A7.6.3 — Airbnb booking link en Telegram (wishlist Alex #5)

### Lo que faltaba

Alex pidió en Telegram: phone, wa.me, **Airbnb booking link**. Los primeros 2
ya estaban (PR A7.5.1). Faltaba el Airbnb link directo a inbox del guest:

```
https://www.airbnb.com/hosting/reservations/details/{confirmation_code}
```

### Implementación

- **Migration 0026**: `bot_messages_inbox` + `airbnb_confirmation_code TEXT` nullable
- `client-bot-polling.getBookingMeta`: parsea `reference` field de Beds24
  response cuando `channel='airbnb'`, valida formato `[A-Z0-9]{8,16}` (e.g.
  HMRTNP6XQK estilo)
- INSERT en `bot_messages_inbox` guarda el code para reuso (alerts + reminders
  sin re-fetchear Beds24)
- `formatCriticalKeywordAlert` añade Airbnb link como última línea cuando
  `channel='airbnb'` + `airbnbCode` disponible
- `unread_long` alert (inline en polling) también incluye Airbnb link
- Graceful: si código missing o channel≠airbnb, sólo Beds24 link

### Backfill

Rows nuevas en `bot_messages_inbox` empiezan a tener `airbnb_confirmation_code`
desde el próximo cron poll. Rows viejas quedan NULL → alerts viejas no tienen
Airbnb link, pero las nuevas sí. No-op migration desde el perspective del bot.

---

## 4. Acciones Alex para activar todo

```powershell
cd C:\rincondelmar-bot\apps\worker-bot
git pull origin main

# 1. Aplicar las 2 migrations nuevas (0025 + 0026)
pnpm exec wrangler d1 migrations apply rincon --remote
# Confirmar 'y' cuando pida

# 2. Deploy worker
pnpm exec wrangler deploy

# 3. Verificar greeter_turns funciona (después de algunos mensajes nuevos)
# Visitá https://rincondelmar.club/admin/bot-metrics y mirá las 4 secciones nuevas

# 4. (Opcional) Activar WhatsApp handoff
# Editar wrangler.toml + agregar:
#   [vars]
#   HANDOFF_NOTIFY_CHANNEL = "both"   # transición segura: TG + WA
# Después: pnpm exec wrangler deploy
```

---

## 5. Estado canary actual (verificado en D1)

```
canary_percent_v5: 50  (alex-stage1, 2026-05-16 01:12:58)
greeter_version_force: ""  (no force, true canary)
```

Real users a v5 al 50%. Después de deploy de A7.6.1, tendrás métricas reales
en `/admin/bot-metrics` para decidir scale 50 → 100% (o rollback si data sale
mala).

---

## 6. CC-Data status (lado vecino)

Threads observados (no mis sesiones): 72, 73, 74, 76 — CC-Data ya completó
Day 1 (Stage 0+A), Day 2 (Stage B+E), Day 4 (deploy pipeline). Track paralelo
limpio, cero conflicts con CC-Bot territory.

PR #48, #49, #51, #52 mergeados sin colisión. Operator playbook está en
`r2://rdm-knowledge/operator_playbook.md` (ver thread/76 detalles).

Próximo paso CC-Data potential: PR A6.1 para que el Greeter v5 consume el
operator_playbook en su system prompt. Pero eso va después de canary 100%.

---

## 7. Métricas sesión

| Frente | Stats |
|---|---|
| PRs merged este block | **3** (#54, #55, #56) |
| LOC añadidas | ~870 |
| Tests añadidos | +22 (greeter-turns-log 11, notify-human WA 6, alerts-format 6) |
| Tests passing | worker-bot **401**, agents 127, web 229+ |
| Migrations nuevas | 2 (0025 + 0026) |
| Producción incidents | 0 |

---

## 8. Standby para

- Alex deploy + smoke test métricas v5 en `/admin/bot-metrics`
- Si quiere WhatsApp handoff opt-in → 1 linea en wrangler.toml + deploy
- Si canary 50% data es verde → scale 100%
- Si rollback necesario → `HANDOFF_NOTIFY_CHANNEL` o canary % via curl

**FIN thread/77**. CC standby.

— Claude Code, 2026-05-16 03:10 UTC
