# Thread 28 — CC Phase 0 + Client Bot Phase A implementation log

**Date**: 2026-05-12
**Author**: Claude Code (CLI)
**To**: Alex `[@alex]` — review pre-deploy, Web Claude `[@wc]` — visibility
**Re**: Implementation autorizada por thread/27. Worker code DONE + tests pass + NOT deployed.

---

## 0. TL;DR

✅ **Worker-bot implementation complete** en branch `feat/phase0-reviews-client-bot-a` (commit `ac751c7` pushed).

✅ **46/46 vitest tests pass** (13 quiet-hours + 15 critical-keywords + 18 beds24-webhook).

✅ **TypeScript clean** (`tsc --noEmit` exit 0).

✅ **Wrangler build OK** (`--dry-run` exit 0).

🟡 **NO deployed yet** — awaiting Alex approval per thread/27 §8 protocol.

🟡 **Apps/web piece** (ReviewsCarousel + endpoint + Schema.org) queda para commit separado en `pr3-en-blog-extras` post-D1 migration aplicada.

---

## 1. Scope completed

| Item thread/27 | Status | File(s) |
|---|---|---|
| **§1.1.1 Reviews ingestion** D1 + cron daily 00:00 UTC + UPSERT | ✅ | `migrations/0012_reviews.sql`, `src/reviews-sync.ts`, `.github/workflows/cron-reviews-sync.yml` |
| **§1.1.2 Daily digest** cron 15:00 UTC (= 09:00 hora Acapulco) | ✅ | `src/daily-digest.ts`, `.github/workflows/cron-daily-digest.yml` |
| **§1.1.3 Low-rating alert hook** (rating ≤3 → WA inmediato) | ✅ | hook en `src/reviews-sync.ts` + `formatLowRatingAlert()` en `src/alerts.ts` |
| **§1.2 D1 0013_bot_messages_inbox** + polling cron 5min | ✅ | `migrations/0013_bot_messages_inbox.sql`, `src/client-bot-polling.ts`, `.github/workflows/cron-client-bot-poll.yml` |
| **§1.2 Critical keyword detection** + alerts | ✅ | `src/critical-keywords.ts` (9 categories regex), formato en `src/alerts.ts` |
| **§1.2 Quiet hours 22:00-08:00** + debounce 5min/booking | ✅ | `src/quiet-hours.ts` pure + integration en `src/client-bot-polling.ts` |
| **§1.1.4 Reviews 5★ → Airtable** | 🟡 DEFER per thread/27 (waiting Q9) | n/a |
| **§2.1 Greeter v5 prompt** | 🟡 WAIT WhatsApp histórico Q7 | n/a |

---

## 2. Architecture decisions implementadas

### 2.1 Endpoints worker-bot

3 nuevos POST endpoints en `apps/worker-bot/src/index.ts`:
- `POST /admin/sync-reviews` — disparado por cron 00:00 UTC
- `POST /admin/poll-messages` — disparado por cron */5 min
- `POST /admin/daily-digest` — disparado por cron 15:00 UTC

**Auth shared**: todos usan `x-admin-secret` header validado contra `env.ADMIN_REFRESH_SECRET` (reuse del secret existente — simplifica GH Actions config).

Pattern same que `/admin/refresh-now` (existing): validate auth, return 200 inmediato, run handler via `ctx.waitUntil()` async.

### 2.2 Pure functions extraídas (testable)

- `quiet-hours.ts::isQuietHour(unixSeconds)` — UTC → Acapulco hour conversion + window check
- `critical-keywords.ts::detectCriticalKeywords(text)` — regex multi-pattern detection
- `alerts.ts::formatLowRatingAlert()`, `formatCriticalKeywordAlert()`, `formatDailyDigest()` — message builders

### 2.3 D1 schema highlights

**`reviews` table**:
- PK: `id` (Beds24 review id, string)
- UPSERT pattern: `ON CONFLICT(id) DO UPDATE SET overall_rating, public_review, ..., synced_at`
- Idempotency safe para overlapping crons o retries
- 3 indexes: por room+date (carousel), por rating (alerts), por hidden filter (display)

**`bot_messages_inbox` table**:
- PK: `message_id` (Beds24 integer)
- `INSERT OR IGNORE` para idempotency (re-runs no duplican)
- `UPDATE` separado para read_flag changes
- 4 indexes incluyendo partial WHERE (PostgreSQL-style en SQLite) para unread guest + critical filters

### 2.4 Alert pipeline

Caller llama `sendAlertToAlex(env, { reason, message, forceSend?, now? })`:
1. Reason `daily_digest` → bypass quiet hours (cron scheduled fuera de quiet anyway)
2. Otros → skip si `isQuietHour(now) && !forceSend`
3. Skip si tokens missing
4. POST setCustomField MakeMsg
5. POST sendFlow → ManyChat dispatch al subscriber 573268715 (Alex)
6. Return `{ sent, skippedReason?, apiError? }` para caller telemetry

Debounce a nivel D1 (no in-memory): caller hace `SELECT alerted_at WHERE booking_id = X LIMIT 1`, check `< 5 min`. After successful send: `UPDATE bot_messages_inbox SET alerted_at = ? WHERE message_id = ?`.

### 2.5 Cross-ref booking metadata

`client-bot-polling.ts::getBookingChannel()` cache per-run (Map booking_id → channel + guestName). Evita N+1 calls dentro de 1 cron run.

`channel` derivado de `booking.referer` (lowercase substring match `airbnb` / `booking` / `direct`).

---

## 3. Tests vitest — coverage

```
Test Files  3 passed (3)
     Tests  46 passed (46)
  Duration  545ms

✓ tests/quiet-hours.test.ts (13 tests)
  - 22:00 / 23:00 / 00:00 / 03:00 / 07:59 boundary cases
  - 08:00 / 09:00 / 14:00 / 21:59 active cases
  - Real timestamps (15:00 UTC daily-digest cron time)
  - nextActiveWindowStart() same-day + next-day logic

✓ tests/critical-keywords.test.ts (15 tests)
  - Cancellation (es/en)
  - Refund/reembolso/devolución
  - Problem/no-funciona/broken/dañado
  - Urgent/emergencia
  - Safety: policía/police/robo/robbery/thief/ladrón
  - Medical: doctor/hospital/ambulancia
  - Multiple categories single message
  - Word boundary: "uncancellable" NO triggers cancellation
  - Long welcome message (4068 chars sample) → false-positive
  - Match strings captured exactos

✓ tests/beds24-webhook.test.ts (18 tests - kept from previous commit)
```

NOT tested directly (intentional — require D1 + Beds24 API mocks):
- `reviews-sync.ts::syncReviews()` — integration test post-deploy
- `client-bot-polling.ts::pollClientBotMessages()` — idem
- `daily-digest.ts::buildDailyDigest()` — idem
- `alerts.ts::sendAlertToAlex()` — integration con ManyChat sandbox

---

## 4. Pending Alex actions for deploy

Per thread/27 §8 protocol, CC NO deploya production sin Alex approval. Cuando autorices:

### 4.1 Apply D1 migrations

```powershell
cd C:\rincondelmar-bot\apps\web
npx wrangler d1 migrations apply rincon --remote
# Esperado: 0012_reviews + 0013_bot_messages_inbox aplicadas
```

### 4.2 Verify GH Actions secrets (probablemente ya configurados)

GitHub repo → Settings → Secrets and variables → Actions. Necesita:
- `WORKER_REFRESH_URL` = `https://bot.rincondelmar.club/admin/refresh-now` (existing per webhook setup)
- `ADMIN_REFRESH_SECRET` = (existing per webhook setup)

Los 3 nuevos workflows reusan los mismos secrets. NO requiere nuevos.

### 4.3 Merge or deploy from feature branch

**Opción A — Merge primero**:
```powershell
cd C:\rincondelmar-bot
git checkout chore/monorepo-turborepo
git merge feat/phase0-reviews-client-bot-a
git push
# Then deploy desde merged branch
```

**Opción B — Deploy directo desde feature branch**:
```powershell
cd C:\rincondelmar-bot
git checkout feat/phase0-reviews-client-bot-a
cd apps\worker-bot
npx wrangler deploy
```

Mi voto: **Opción A** (linear merge train) si Q15 webhook ya está merged a chore. Si no, deploy desde feature branch directo (more testing isolation).

### 4.4 Smoke test post-deploy

```powershell
# Health check version bumpea a 0.6.0-phase0-reviews-client-bot-a
Invoke-RestMethod https://bot.rincondelmar.club/health

# Trigger manual cada endpoint:
$secret = [System.IO.File]::ReadAllText("C:\rincondelmar-bot\scripts\setup\.admin-refresh-secret.tmp").Trim()
$headers = @{ "x-admin-secret" = $secret }

Invoke-WebRequest -Uri "https://bot.rincondelmar.club/admin/sync-reviews" -Method POST -Headers $headers
Invoke-WebRequest -Uri "https://bot.rincondelmar.club/admin/poll-messages" -Method POST -Headers $headers
Invoke-WebRequest -Uri "https://bot.rincondelmar.club/admin/daily-digest" -Method POST -Headers $headers
```

Tail worker para ver logs estructurados:
```
{"event":"reviews_sync_done", "totalFetched":167, "totalUpserted":167, "alertsSent":0, ...}
{"event":"client_bot_polling_done", "totalFetched":23, "newMessages":0, "alertsSent":0, ...}
{"event":"daily_digest_done", "sent":true, "metrics": {...}}
```

D1 verify:
```sql
SELECT COUNT(*), AVG(overall_rating) FROM reviews;
-- Expect ~167 rows post-first-sync (cap 50/room × 4 = 200 max, real ~167)

SELECT COUNT(*), source FROM bot_messages_inbox GROUP BY source;
-- Expect ~23 rows (12 host + 9 guest + ~2 indeterminate)
```

### 4.5 Verify GH Actions workflows show up + run

Después del push:
1. GitHub → Actions tab → ver 3 workflows nuevos en sidebar:
   - `cron-reviews-sync`
   - `cron-client-bot-poll`
   - `cron-daily-digest`
2. Trigger manual "Run workflow" en `cron-reviews-sync` → confirm 200 + log structurado en worker tail
3. Wait 5 min → primer auto-run de `cron-client-bot-poll` debería aparecer

---

## 5. Apps/web piece — PLAN (no implementado todavía)

Per thread/27 §1.1.1 Step 4, falta:

| Task | File | ETA |
|---|---|---|
| GET `/api/reviews/[roomId]` SSR | `apps/web/src/pages/api/reviews/[roomId].ts` | 30 min |
| ReviewsCarousel React island | `apps/web/src/components/property/ReviewsCarousel.tsx` | 1h |
| Insert carousel en `[propertyId].astro` con Schema.org `Review` + `AggregateRating` | edit `[propertyId].astro` | 30 min |
| CSS + responsive (mobile-first) | `ReviewsCarousel.css` | 30 min |

**Dependency**: requiere D1 migration 0012 aplicada (sino endpoint queries fall sobre tabla inexistente).

**Branch**: implementar en `pr3-en-blog-extras` (default branch CF Pages deploy). Separate commit del worker para clarity + permitir merge independiente.

Cuando autorices, arranco esto en una sesión separada o continuo aquí post-deploy worker.

---

## 6. Risks observed durante implementation

| Risk | Mitigación implementada |
|---|---|
| TypeScript block-comment `*/5 * * * *` cierra `/**...*/` prematuramente | Renombrado a "every 5 min" en doc comments |
| `@ts-expect-error` unused directive con D1Result types modernos | Removido (TSC ya conoce shape) |
| Polling N+1 calls /v2/bookings per message | Cache `bookingCache` Map per-run |
| Critical keyword false positives (e.g. "cancellation policy") | Tests cubren — sí matcha, but es semantically correct flag |
| Alert spam multiple messages same booking en 5 min | Debounce SQL `alerted_at < now - 5min` check |
| Quiet hours edge: cron 15:00 UTC drift to 04:00 hora Acapulco | `daily_digest` reason exempts quiet check |
| D1 INSERT OR IGNORE no returns changes count cleanly | Uso `result.meta?.changes ?? 0 > 0` para detectar inserted vs ignored |

---

## 7. Performance estimate

**Reviews sync** (daily 00:00 UTC):
- 4 rooms × 50 reviews each = 200 reviews max per run
- API calls: 4 (one per room) + 1 token check
- D1 writes: ~200 UPSERTs
- Alerts: 0-3 expected per day average
- Total runtime: ~5-10s

**Client Bot polling** (every 5 min):
- API calls: 1 (`/messages`) + 1 (`/bookings` cache fill on first message per booking)
- D1 writes: 0-23 INSERT OR IGNOREs (matching API page size)
- Alerts: 0-2 expected per run average
- Total runtime: ~2-5s

**Daily digest** (daily 15:00 UTC):
- D1 reads: 3 aggregate queries
- API calls: 0 (pure D1 aggregation)
- Alerts: 1 (digest message)
- Total runtime: ~1-2s

**Combined cron load**: ~432 calls/day a Beds24 API. Limit ~432,000/día → **0.1% utilization**.

---

## 8. Open questions remain (no bloqueantes)

Per thread/27 §3, sin update:
- Q7 WhatsApp histórico — Greeter v5 prompt sigue en hold
- Q8 Analytics access
- Q9 Airtable Content Queue
- Q10 Tour virtual completion
- Q11 Reservar pre-fill verification
- Q14 Mobile vs desktop traffic
- Q16 Reviews CSV bulk import timing

---

## 9. Ping

@alex — implementación completa pre-deploy. Review §4 para steps deploy (5-10 min trabajo Alex). Cuando autorices yo:
- Smoke test post-deploy
- Implemento apps/web piece (ReviewsCarousel)
- Commit thread/29 con deploy log + first-run metrics

@wc — visibility update. ¿Algo que ajustar en architecture antes del deploy? Concerns sobre N+1 cache strategy en polling? Alert spam threshold?

---

*FIN thread/28. Code ready. Awaiting Alex deploy approval.*

— Claude Code (CLI), 2026-05-12T~11:45Z
