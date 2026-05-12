# Thread 25 — Q15 webhook handler implemented + reviews cap re-verified

**Date**: 2026-05-12
**Author**: Claude Code (CLI)
**To**: Web Claude `[@wc]`, Alexander `[@alex]`
**Re**: Alex aceptó Q15 (Beds24 Booking Webhook). CC implementó Phase C passive logging. Plus re-verificación del reviews cap.

---

## 0. TL;DR

✅ **Q15 webhook handler implementado** en `feat/beds24-booking-webhook` branch. Phase C **passive logging** sin trigger actions. Ready para deploy + Alex configure panel Beds24.

🟡 **Reviews API cap re-verified = 50** (no 100 como Alex sugirió). API hard-cap independent de `limit/offset/page/pageLimit/maxResults/perPage`. Pero estrategia "**export histórico manual via panel + cron incremental via API**" sigue válida — explicación abajo.

---

## 1. Q15 webhook — implementación

Commit `aa23eaa` en branch `feat/beds24-booking-webhook`:

### 1.1 Files

| File | Purpose |
|---|---|
| `migrations/0011_beds24_events.sql` | D1 table `beds24_events` con payload_json + indices por bookingId/eventType/referer |
| `apps/worker-bot/src/beds24-webhook.ts` | Pure function `deriveBeds24EventType()` con 6 rules (cancelled/created/modified/unknown) |
| `apps/worker-bot/src/index.ts` | Nuevo endpoint `POST /webhook/beds24-booking` con header auth + D1 insert + 200 ack |
| `apps/worker-bot/tests/beds24-webhook.test.ts` | **12 vitest tests** del eventType derivation, todos pass |

### 1.2 Endpoint detail

```
POST https://bot.rincondelmar.club/webhook/beds24-booking
Headers:
  x-beds24-secret: <BEDS24_WEBHOOK_SECRET>
Body: JSON V2 with personal data (per Beds24 panel config)

Flow:
  1. Validate header → 401 si missing/wrong
  2. Parse JSON body
  3. deriveBeds24EventType(body) → 'booking_created' | 'booking_modified' | 'booking_cancelled' | 'unknown'
  4. INSERT to beds24_events table (best-effort, log on fail no propagate)
  5. Return 200 OK + { ok, received: true, type }

Telemetry log line:
  { event: "beds24_webhook_received", type, bookingId, referer, roomId, status, receivedAt }
```

### 1.3 eventType derivation rules (deriveBeds24EventType)

Beds24 V2 webhook payload NO incluye `event_type` field explícito. Inferencia:

| Rule | Condición | Output |
|---|---|---|
| 1 | `status === 'cancelled'` OR `cancelTime` presente | `booking_cancelled` |
| 2 | `bookingTime` y `modifiedTime` parseables, diff < 60s | `booking_created` |
| 3 | `bookingTime` y `modifiedTime` parseables, diff ≥ 60s | `booking_modified` |
| 4 | Solo `bookingTime` parseable (fallback) | `booking_created` |
| 5 | Solo `modifiedTime` parseable (fallback) | `booking_modified` |
| 6 | Nada match | `unknown` (log para análisis) |

Tests cubren cancellation override, identical timestamps, 60s boundary precisa (59s → created, 61s → modified), malformed timestamps → unknown.

### 1.4 Validations done

- ✅ `tsc --noEmit`: clean
- ✅ `vitest run`: 12/12 tests pass
- ✅ `wrangler deploy --dry-run`: 150.12 KiB / gzip 34.68 KiB
- ✅ Bumped `/health` version a `0.5.0-beds24-webhook`

### 1.5 Pending Alex actions

1. **Apply migration**:
   ```powershell
   cd C:\rincondelmar-bot\apps\web
   npx wrangler d1 migrations apply rincon --remote
   ```

2. **Set secret** (yo lo genero local, Alex setea via bulk JSON):
   ```powershell
   cd C:\rincondelmar-bot\apps\worker-bot
   $tok = [System.IO.File]::ReadAllText("C:\rincondelmar-bot\scripts\setup\.beds24-webhook-secret.tmp").Trim()
   # ...bulk JSON UTF-8 sin BOM, mismo pattern que setup A
   ```

3. **Merge feature branch** to default branch o usar como branch separado para deploy.

4. **Deploy worker-bot**:
   ```powershell
   cd C:\rincondelmar-bot\apps\worker-bot
   npx wrangler deploy
   ```

5. **Configure Beds24 panel** (UI Alex):
   - Webhook Version: **2 - with personal data**
   - URL: `https://bot.rincondelmar.club/webhook/beds24-booking`
   - Custom Header: `x-beds24-secret: <SECRET de .tmp file>`
   - Additional Data: **Ninguno**

6. **Smoke test**: crear/modificar booking dummy en Beds24 → verify `wrangler tail rincon-bot` captura webhook + `SELECT * FROM beds24_events ORDER BY received_at DESC LIMIT 5` muestra row.

---

## 2. Reviews API cap — re-verified = 50

### 2.1 Alex's hipótesis

> "Reviews API tiene cap 50 HARD per query: son 100! podemos exportar todos manualmente y nada mas agregar nuevos cada x dias."

### 2.2 CC re-verification

Probé 9 variantes con token actual:

| Query | count | first_id | nextPage |
|---|---|---|---|
| `?roomId=78695` | 50 | (X) | false |
| `?roomId=78695&limit=100` | 50 | same X | false |
| `?roomId=78695&pageLimit=100` | 50 | same X | false |
| `?roomId=78695&maxResults=100` | 50 | same X | false |
| `?roomId=78695&perPage=100` | 50 | same X | false |
| `?roomId=78695&limit=100&offset=100` | 50 | same X | false |
| `?roomId=78695&limit=100&page=2` | 50 | same X | false |
| `?roomId=78695&page=2` | 50 | same X | false |
| `?roomId=78695&since=2025-01-01` | 50 | same X | false |

🔴 **API cap = 50 confirmed**, hard, sin pagination.

🟡 **Posible discrepancia con Alex's 100**:
- Quizás Alex vio "100" en el **panel Beds24 UI** (web), donde Airbnb integration muestra más reviews
- O cap dependiente del scope/role del token (no tested con long-lived read-only de proxReservas)
- API endpoint cap = 50 con scope `all:channels` (que es lo que tiene mi token)

### 2.3 Tu estrategia sigue válida — y es muy buena 🎯

> "podemos exportar todos manualmente y nada mas agregar nuevos cada x dias"

**Refinada**:

**Fase 1 — Bulk import histórico** (una sola vez):
- Alex exporta CSV/JSON de TODOS los reviews desde panel Beds24 (donde sí hay pagination UI)
- CC import a D1 `reviews` table (DDL en thread/22 §6.1)
- ETA: ~30 min Alex export + 30 min CC import script

**Fase 2 — Cron incremental** (recurrente):
- Cron daily/weekly: `GET /v2/channels/airbnb/reviews?roomId=X` (cap 50)
- INSERT OR REPLACE: solo agregan reviews nuevos (cap 50 suficiente porque <50 reviews nuevos/semana per room)
- D1 mantiene histórico completo (Fase 1) + delta (Fase 2)

**Cobertura**:
- Histórico: completo (CSV manual)
- Nuevos: <24h lag (cron daily)
- API cap 50: NO bottleneck porque solo necesita los 50 más recientes para detectar new

🟢 **Estrategia óptima**. Sin overhead vs construir custom pagination (que API no soporta).

---

## 3. Updated Phase 0 quick wins

Updated del thread/22 §6 con estrategia híbrida reviews:

| # | Quick win | ETA | Risk |
|---|---|---|---|
| 0.1 | **Q15 webhook handler** ✅ implemented in `feat/beds24-booking-webhook` | done (4h) | Zero |
| 0.2 | Bulk import reviews CSV histórico (Alex export + CC import) | 1h Alex + 1h CC | Zero |
| 0.3 | Cron daily reviews incremental sync (API delta) | 2h | Zero |
| 0.4 | Daily digest unread WhatsApp → Alex via ManyChat | 1h | Zero |
| 0.5 | Low-rating alert (overall_rating ≤ 3 → WA Alex) | 30 min | Zero |
| 0.6 | Reviews 5★ → Airtable social queue (requires Airtable API token) | 2h | Zero |

**Total**: ~7h work spread (4h done con webhook). Cero risk en todos.

---

## 4. Open questions

### Q15 sub-decisions

**Q15.a**: Deploy webhook handler ahora o esperar Alex setup completo (secret + panel config + apply migration)?
- Voto: deploy en cuanto los 3 setup steps estén done (5 min total Alex)

**Q15.b**: Mantener `feat/beds24-booking-webhook` como branch separado, o merge a `chore/monorepo-turborepo` antes de deploy?
- Voto: merge a chore primero (linear history). PR review opcional.

### Reviews strategy

**Q16**: ¿Cuándo exportas el CSV histórico desde Beds24 panel? Y formato:
- ¿Por roomId individual o todo junto?
- ¿Columnas que necesitamos: id, listing_id, room_id, reservation_code, overall_rating, public_review, private_feedback, category_ratings, submitted_at, hidden?
- Si Beds24 panel no exporta esos exactos, CC adapta el import script.

**Q17**: ¿Cron sync incremental cada cuánto?
- Daily (00:00 UTC, junto con Reviews 5★ → social queue)
- Weekly (Sunday 02:00, menos load)
- Voto: **daily** porque reviews 5★ → social queue beneficia de frescura

---

## 5. Next steps

1. **Push branch + this thread** (en progreso al momento de escribir)
2. **Alex**:
   - Apply migration 0011 (`wrangler d1 migrations apply rincon --remote`)
   - Setear secret BEDS24_WEBHOOK_SECRET
   - Deploy worker-bot
   - Configure panel Beds24 settings
   - Export reviews CSV histórico
3. **CC after Alex done**: smoke test webhook + bulk import script reviews CSV
4. **WC**: comentar architecture/decisions adicionales si surge

---

*FIN thread/25. Webhook handler ready, reviews strategy clarified. Awaiting Alex setup steps + Q16/Q17 decisions.*

— Claude Code (CLI), 2026-05-12T~07:30Z
