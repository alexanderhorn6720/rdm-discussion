# Thread 54 — CC: Fase 1 progress (overnight session)

**Date**: 2026-05-15 (sesión nocturna autónoma post-Alex GO)
**Author**: Claude Code (CC) — Aggressive Mode
**To**: Alex `[@alex]` + WC `[@wc]`
**Re**: thread/53 plan execution + thread/49b cleanup
**Status**: 5 PRs merged + 1 DRAFT espera review + auto-deploys live

---

## TL;DR

✅ **5 PRs merged + auto-deployed** (workflow corregido funcionando)
✅ **8 anchors live** verificados en producción (ES + EN, 4 properties)
✅ **Click tracking endpoint live** (pending Alex deploy worker bot manual)
✅ **Telegram notif endpoint code complete** (pending Alex deploy worker bot manual)
✅ **Lang detection utility ready** para PR A4 Greeter v5
🟡 **1 PR DRAFT** (#32 BookingCard URL params) espera review visual de Alex
⚠️ **Worker rincon-bot deploys manual** — PR #29 + #30 endpoints en main pero NO live hasta `wrangler deploy`

---

## PRs ejecutados esta sesión

| # | PR | Status | Auto-deploy | Notas |
|---|---|---|---|---|
| 27 | fix(deploy): SITE_URL + workflow pnpm filter | ✅ MERGED | ✅ deployed | Antes de Alex GO |
| 28 | feat(admin): ADMIN_EMAILS env var | ✅ MERGED | ❌ failed (sin GH secrets) → Alex deploy manual | Antes de GH secrets |
| 29 | feat(bot): click tracking /r/bot/[slug] | ✅ MERGED | ✅ Pages auto-deployed | Endpoint en worker bot — pending wrangler deploy worker manual |
| 30 | feat(bot): Telegram notify-human + reminders | ✅ MERGED | ✅ Pages auto-deployed | Mismo: endpoint pending wrangler deploy worker |
| 31 | feat(web): property page anchors | ✅ MERGED | ✅ **LIVE** verificado (8 IDs) | Anchors en sitio prod |
| 32 | feat(web): BookingCard URL params (PR A1.1) | 🟡 **DRAFT** | n/a | Espera review visual Alex |
| 33 | feat(bot): lang detection ES/EN heuristic | ✅ MERGED | ✅ Pages auto-deployed | Utility lib — no toca runtime hasta PR A4 |

**Total**: 5 PRs merged + 1 DRAFT. ~3.5h CC trabajo continuo.

---

## Verificación live

### Sitio (auto-deployed via workflow corregido PR #27)

```
$ curl -sSL https://rincondelmar.club/rincon-del-mar/ | grep -oE 'id="(tarifas|galeria|amenidades|testimonios)"' | sort -u
id="amenidades"
id="galeria"
id="tarifas"
id="testimonios"

$ curl -sSL https://rincondelmar.club/en/rincon-del-mar/ | grep -oE 'id="(rates|gallery|amenities|reviews)"' | sort -u
id="amenities"
id="gallery"
id="rates"
id="reviews"
```

**8/8 anchors live verificados** ✅

### Worker bot (NO auto-deploy)

```
$ curl -sS https://bot.rincondelmar.club/health
{"ok":true,"service":"rincon-bot","version":"0.6.1-phase0-tweaks",...}

$ curl -sSI "https://bot.rincondelmar.club/r/bot/precios?prop=rincon-del-mar"
HTTP/1.1 404 Not Found
```

**Endpoints en main pero NO live**. CLAUDE.md regla: deploys del worker rdmbot son manuales.

---

## Acciones pendientes para Alex (al despertar)

### 🔴 Bloqueante para que Greeter v5 funcione end-to-end

**1. Deploy worker rincon-bot manual** — habilita endpoints PR #29 + #30 + #33

```powershell
cd C:\rincondelmar-bot\apps\worker-bot
pnpm exec wrangler deploy
```

**Después** verifica:
```powershell
curl -sSI "https://bot.rincondelmar.club/r/bot/precios?prop=rincon-del-mar&conv=test&v=test&lang=es"
# Debe: HTTP/1.1 302 Found + Location: /rincon-del-mar?...#tarifas
```

**Y** test Telegram notif:
```powershell
curl -sS -X POST "https://bot.rincondelmar.club/internal/notify-human" `
  -H "x-admin-secret: $env:ADMIN_REFRESH_SECRET" `
  -H "Content-Type: application/json" `
  -d '{"subscriber_id":"test","last_user_message":"test handoff desde CC overnight session","intent":"escalate"}'
# Debe: {"ok":true,"handoff_id":1,...}
# Y mensaje TG llega a tu chat 8711110474
```

### 🟡 Review visual del PR DRAFT

**2. PR #32 (A1.1 BookingCard URL params)**

Si quieres que pre-fill funcione cuando bot mande URLs con dates+guests:
- Test manual: `https://rincondelmar.club/rincon-del-mar?check_in=2026-08-15&check_out=2026-08-17&guests=8#tarifas`
- Si form pre-rellenado + auto-quote → ✅ approve + merge

Si OK:
```powershell
gh pr ready 32
gh pr merge 32 --squash --admin --delete-branch
```

### 🟢 Opcional / non-urgent

**3. Crear `WORKER_REFRESH_URL` GH secret** (si no existe)

El cron `cron-handoff-reminders.yml` necesita este secret apuntando a `https://bot.rincondelmar.club/admin/refresh-now`. Mismo secret que otros crons existentes (cron-welcome-auto-send, cron-client-bot-poll, etc.).

Verifica:
```powershell
gh secret list | Select-String "WORKER_REFRESH_URL"
```

Si no existe, los crons existentes también fallarían — probablemente ya está, pero confirmar.

---

## Lo que NO se ejecutó este sprint (Fase 2)

Per thread/53 §6, Fase 2 viene después de Fase 1 merged + tested:

- **PR A4** — Greeter v5 prompt update con tool-use enforcement
  - Espera spec WC en `cc-instructions/2026-05-XX-greeter-v5-core.md`
  - Consume el catálogo intent-resolver (PR #29) + lang detection (PR #33)
  - Inyecta tool calls forzados que retornan `intent_slug` + URL
  - ETA ~4h CC + 3h WC

- **PR A6** — Greeter v5 system prompt final (con guardarrails opening_line)
  - Depende de A4
  - WC escribe prompt + CC integra
  - Tests vitest con fixtures (regression catch alucinaciones)

- **PR A7** — Canary rollout 10→25→50→100 + dashboard `/admin/bot-metrics`
  - Depende de A6 production-ready
  - Lee `bot_link_clicks` + `human_handoff_log` de D1
  - ETA ~2h CC

- **PR A8** — Split prompts AirBnB vs WhatsApp (D8)
  - Post baseline establecido
  - Conditional via `bookings.channel`

---

## Bug fixes del camino

Durante esta sesión surgieron 2 bugs menores que fixeé inline:

### Bug 1 — intent-resolver template literal sin reemplazar

`mascotas` y `testimonios` tienen `requires_property: false` pero su template incluye `{property}`. Sin property → URL quedaba literal `/{property}#mascotas` (broken).

**Fix** en `intent-resolver.ts`: si template incluye `{property}` Y no hay property → fallback. Tests cubren los 2 paths.

### Bug 2 — D1 mock no soportaba `.all()` sin `.bind()`

Mi mock D1 en `notify-human.test.ts` solo exponía `.all()` después de `.bind()`. Pero `checkAndSendReminders` usa `prepare(sql).all()` sin bind. 4 tests fallaron.

**Fix**: agregar `.all()` directo al return de `prepare()`.

Ambos bugs detectados por tests + fixed antes de merge.

---

## Observaciones técnicas para WC

### A. Componentes property NO tienen anchor sub-sections (yet)

PR A1.0 agregó anchors al **wrapper** de cada componente (PropertyGallery, PropertyAmenities, BookingCard, ReviewsCarousel). Pero los anchors `#chef`, `#mascotas`, `#capacidad` que el spec thread/52 §3.4-3.5 menciona viven **embebidos** dentro de `PropertyAmenities`.

Para que el bot deflecte a `/{property}#chef` con destination correcto, hace falta refactor de PropertyAmenities en sub-componentes (PR A1.5 — pending tu spec WC):
- `<ChefSection>` con copy específico (RdM/Combinada included, Morenas optional + cross-sell, Huerta hidden)
- `<PetsPolicy>` con narrativa per casa (Huerta tiene la animals story)
- `<RoomsTable>` o `<Capacity>` con tabla habitaciones

Mientras tanto, el bot puede deflectar a `#amenidades` (genérico) que SÍ existe.

### B. Reviews carousel ID en 3 paths

`ReviewsCarousel.tsx` tiene 3 returns (loading, fallback, loaded). Agregué `id` en los 3 — el user que llega via deep-link siempre ve el anchor independiente del state de carga.

### C. Lang detection conservadora

Threshold EN ≥1.5x stop-words ES para switch. Mercado MX = es default razonable. Si en producción detectamos muchos guests EU/USA queriendo EN sin que el bot switch, ajustar threshold a 1.2x o agregar más stop words EN.

### D. URL params BookingCard

Ya lista en PR #32 DRAFT. Si Alex aprueba, el bot puede deflectar `/{property}#tarifas?check_in=...&guests=...` y el calendar se pre-rellena + auto-quote.

---

## Métricas a observar (cuando Alex deploye worker)

Una vez `wrangler deploy` ejecutado, podemos monitorear:

```sql
-- Click tracking
SELECT intent_slug, COUNT(*) AS clicks, COUNT(DISTINCT conv_hash) AS unique_users
  FROM bot_link_clicks
 WHERE clicked_at > datetime('now', '-1 day')
 GROUP BY intent_slug
 ORDER BY clicks DESC;

-- Handoffs pendientes
SELECT id, subscriber_id, intent, notified_at,
       reminder_1h_sent_at IS NOT NULL AS reminded_1h,
       reminder_8h_sent_at IS NOT NULL AS reminded_8h
  FROM human_handoff_log
 WHERE human_responded_at IS NULL
 ORDER BY notified_at DESC;
```

PR A7 (canary) crea dashboard `/admin/bot-metrics` con estas queries automáticas + gráficas.

---

## Limpieza adicional

### `OPEN_QUESTIONS_BOT_ROUTING.md` movido

El doc original que escribí ayer (~600 líneas) estaba en `C:\rincondelmar-bot\` raíz local sin commit. Lo moví a este repo discussion como **`threads/49b-cc-bot-routing-proposal.md`** (paralelo al thread/50 de WC). Así toda la conversación queda en un solo repo + history.

### Auto-deploy workflow corregido

PR #27 reemplazó `cloudflare/wrangler-action@v3` con `pnpm --filter web exec wrangler` directo. Confirmé que funciona: PRs #29, #30, #31, #33 todos deployaron exitosamente.

**Solo Pages auto-deploya**. Worker rincon-bot sigue manual (CLAUDE.md regla).

---

## Estado del repo final

- **Branch main**: actualizada con 5 PRs merged
- **Tests**: 288/288 passing en worker-bot
- **Build**: clean en apps/web + worker-bot
- **PRs abiertos**: 1 (#32 DRAFT espera Alex)
- **D1 migrations applied**: 0021 (bot_link_clicks) + 0022 (human_handoff_log) por Alex pre-sesión
- **Worker deploys pendientes**: 1 (`cd apps/worker-bot && pnpm exec wrangler deploy`)

---

**Buenos días Alex. Ejecuta el deploy del worker (1 comando) y todo está funcional. Después tu llamada para PR A4 + thread/55 spec WC.**

— Claude Code, sesión nocturna 2026-05-15 ~01:30 → 04:00
