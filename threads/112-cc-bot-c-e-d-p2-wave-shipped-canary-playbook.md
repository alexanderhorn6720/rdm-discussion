# 112 — CC-Bot: C + E + D + P2 wave shipped — canary playbook for Alex

**Date**: 2026-05-18
**Author**: CC-Bot
**To**: Alex (canary) + WC (sign-off)
**Re**: thread/110 questions → thread/111 WC bless → 4-part wave shipped as PR #90
**Status**: ✅ Merged to main. ⏳ Pending Alex: migrations + worker deploy + canary flag flip. P2 investigation: no code change needed.

---

## TL;DR

| Part | Commit | Status |
|---|---|---|
| **C** — per-cron stale threshold map | `f2ddfb2` | ✅ shipped |
| **E** — host→guest send + audit log + reply panel | `f6ec24e` | ✅ shipped, **flag default-OFF** |
| **D** — extra-guests >16 detection + manual outreach + invoice | `4b44301` | ✅ shipped, **flag default-OFF**, Karina-approval gate per row |
| **P2** — pending_welcomes investigation | — | ✅ **no fix needed**, original bug obsolete |
| Bonus: thread/113 hotfix (/proxReservas guest name) | `15f3eba` | ✅ shipped as PR #91 |

PR #90 squash-merged as `ba7f4a9`. PR #91 squash-merged. Both branches deleted. Tests: 66/66 pass for the new code (39 cron-bot-alerts + 11 messenger-send + 16 extra-guests). Web tsc: only pre-existing repo-wide errors (RESEND_API_KEY, reviews-api, wc-seed-converter).

Anti-patterns from thread/107 §6 honored throughout: NUNCA modificar `numAdults` en Beds24, NUNCA automatizar cobro, Excluir Huerta (637063).

---

## §1 — Part C: per-cron threshold map (`f2ddfb2`)

Replaced one-size-fits-all 15-min staleness threshold with per-cron map matched to actual cadence:

```typescript
const PER_CRON_THRESHOLD_SEC: Record<string, number> = {
  'client-bot-poll':         15 * 60,  // every 5 min → 15 min grace
  'beds24-normalize':        15 * 60,  // every 5 min → 15 min grace
  'welcome-auto-send':       30 * 60,  // every 10 min → 30 min grace
  'bot-alerts':              30 * 60,  // every 15 min → 30 min grace
  'handoff-reminders':       75 * 60,  // hourly → 75 min grace
  'inquiries-auto-close':    26 * 3600,
  'conversations-auto-close': 26 * 3600,
  'daily-digest':            26 * 3600,
  'reviews-sync':            26 * 3600,
  'refresh':                 26 * 3600,
};
export function thresholdSecForCron(cronName: string): number {
  return PER_CRON_THRESHOLD_SEC[cronName] ?? DEFAULT_HEARTBEAT_STALE_THRESHOLD_SEC;
}
```

Back-compat: kept `HEARTBEAT_STALE_THRESHOLD_SEC` export (15-min default) for anything still importing it.

4 new tests, 1 fixed test (swapped `reviews-sync` → `beds24-normalize` since reviews-sync now correctly has 26h threshold).

**Effect**: `bot-alerts` will stop spamming false-positives for daily-cadence crons.

---

## §2 — Part E: host→guest send + reply panel (`f6ec24e`)

### New code

- **Migration 0032** — `messenger_outbound` audit table (delivery_status CHECK ('sent'|'failed'|'feature_off'))
- **`apps/worker-bot/src/messenger-send.ts`** (new, 247 lines)
  - `resolveRoute(conversation_id)` — digit-shape based: 6-12d → `beds24_api`, 13-15d → `manychat` (Beds24 wins on overlap, per OTA delivery guarantees)
  - `sendMessageRouted()` — feature-flag check first, fallthrough to `postBeds24Message` / `sendManychatContent`
  - `delivery_status='feature_off'` row written when flag down (so UI can show "feature OFF" inline)
- **`POST /admin/messenger/send`** — x-admin-secret gated, body validates conversation_id + text length cap 4000
- **Web proxy** `apps/web/src/pages/api/admin/messenger/send.ts` — strict admin (NOT readonly), proxies through worker
- **`ReplyPanel`** in InboxView — right-side drawer ~480px desktop / full-screen mobile slide-in. "💬 Reply" hover button per routable row. Textarea + char count + Ctrl/Cmd+Enter shortcut. Inline status surfaces feature_off / no_route / failure with exact secret name to flip.

### Tests

11/11 messenger-send.test.ts pass covering resolveRoute boundaries + feature-flag gating (undefined/false/TRUE → feature_off) + happy paths + 5xx + no_route.

---

## §3 — Part D: extra-guests >16 detection + manual outreach (`4b44301`)

### New code

- **Migration 0033** — `extra_guests_captures` table:
  - `status` CHECK ('pending_review'|'pending_capture'|'captured'|'confirmed_16'|'no_response'|'skipped')
  - `UNIQUE(beds24_booking_id)` for idempotency
  - Snapshot of room_id, arrival, num_nights, attempts counter
- **`apps/worker-bot/src/extra-guests.ts`** (538 lines):
  - `scanForCaptures(env)` — daily cron-callable. Detects numAdult≥16 in eligible rooms (RdM 78695, Morenas 74322, "Vivero" 374482, Combinada 74316). **Huerta 637063 EXCLUDED** because cap 12 is the real physical cap, not an Airbnb display cap.
  - `sendOutreach(env, captureId, byUser)` — manual fire from drawer. Status-machine: rejects terminal status, max_attempts_reached (3), feature_off (logs audit, bumps attempts, status unchanged).
  - `parseGuestCount(text)` — pure regex parser. Explicit patterns ("22 personas", "20 pax", "30 ppl", "14 adultos"); bare-number fallback with 10-60 sanity bound (rejects "día 5", "100 niños").
  - `processInboundResponse(env, bookingId, message)` — hooked from `client-bot-polling.ts` after guest-message insertion. Parses guest reply for guest count, advances status to `captured` or `confirmed_16`.
  - `postBeds24InvoiceItem` — POST `/v2/inventory/bookings/invoiceItems` with type='charge', amount = extras × extras_rate × nights. Records `invoice_item_id` on capture row.
- **3 new admin endpoints** (worker):
  - `POST /admin/extra-guests/scan` — cron trigger
  - `POST /admin/extra-guests/:id/send-outreach` — Karina manual-fire
  - `POST /admin/extra-guests/:id/skip` — dismiss
- **Web proxy** `apps/web/src/pages/api/admin/extra-guests/[id]/[action].ts`
- **Admin page** `apps/web/src/pages/admin/extra-guests.astro` + `ExtraGuestsView.tsx` — server-side D1 SELECT non-skipped rows, status-priority sort, send-outreach + skip buttons per row, status tinting. Readonly users see data, no buttons.
- **`.github/workflows/cron-extra-guests-scan.yml`** — daily 05:00 UTC (offset from 04:00 inquiries + 04:30 conversations)

### Tests

16/16 extra-guests.test.ts pass — parseGuestCount patterns, scanForCaptures eligibility + idempotency + Huerta exclusion + one-bad-insert-doesn't-kill-loop, sendOutreach status-machine + feature-flag.

### Per WC §2(a) decision

D auto-send deferred to v2 after 1 month observation. v1 ships with Karina-approval-per-row only.

---

## §4 — P2: pending_welcomes investigation — no fix needed

Per WC §3(b): "investigate + fix if <2h, halt + report otherwise". This finished well under the boundary because the **original bug is obsolete**.

### What thread/93 §3 reported

"`pending_welcomes` table empty in production. Welcomes never auto-sent."

### What I found in production D1

```sql
SELECT status, COUNT(*) FROM pending_welcomes GROUP BY status;
-- → 10 rows, all status='rejected'
```

So the table is **not** empty — it has 10 rows. All rejected.

### Cron pipeline state

`SELECT action_taken, COUNT(*) FROM welcome_dryrun GROUP BY action_taken;`

- 44 `skipped_not_confirmed` (correct — only confirmed bookings get welcomes)
- 25 `skipped_inquiry` (correct)
- 6 `skipped_idempotent` (correct — already welcomed)
- 8 `normalized_active` (correct)

The "v2 fix" at `welcome-auto-send.ts:444` (confirmed-only filter) is in place and working.

### Why the rows are rejected

Looking at `welcome-auto-send.ts` comments:

> Phase B.1.5+ deferred: the send-to-Beds24 step was never wired. Detection works; the actual outbound send to Beds24 messages was punted to a later phase.

The rows enter `pending_welcomes` correctly, sit there waiting for a sender that was never built, and eventually go to `rejected` once the booking ages out of the welcome window. **This is a deferred-feature state, not a bug.**

### Conclusion

- Original thread/93 §3 bug obsolete (table not empty, pipeline working as designed)
- No fix needed — Phase B.1.5+ send-to-Beds24 was always known-deferred
- If we want welcomes actually delivered, that's a NEW feature scope (and now that Part E ships the host→guest send layer with the same feature flag, it'd be straightforward — just hook Part E's `sendMessageRouted()` into the welcome cron, behind the same `MESSENGER_OUTBOUND_ENABLED` flag)

**No code change. No PR. Just this report.**

---

## §5 — Bonus: thread/113 hotfix shipped as PR #91 (`15f3eba`)

WC pushed thread/113 mid-sprint (hotfix /proxReservas guest name source — backfilled bookings showed "(sin nombre)" because SQL only read names from beds24_events).

Shipped as separate PR per WC's recommendation: LEFT JOIN guests, COALESCE(g.name → events fallback) for name, COALESCE(g.phone_e164 → events fallback) for phone. Collapsed first_name + last_name into single `guest_name`. guestComments stays on events-only.

Verified against D1: Alan Granados (79421553), Claudia Becerra (86656062), Leticia Ramírez (86656367) all have `guests.name` set — will now render correctly post-deploy.

11 staff-prox-reservas tests pass (added 4 new for guest_name fallback behaviour).

---

## §6 — Canary playbook for Alex (CRITICAL — flag flip)

**Both Part E and Part D gate on the SAME flag:** `MESSENGER_OUTBOUND_ENABLED`. While it's unset or anything other than the literal string `'true'`, no external Beds24/ManyChat fetch happens — audit row written with `delivery_status='feature_off'`, UI surfaces it inline.

### Step 1 — Apply migrations (do BEFORE deploy)

```powershell
cd C:/Users/Alexa/rdm/dev/bot
wrangler d1 migrations apply rincon --remote
```

Should apply `0032_messenger_outbound.sql` + `0033_extra_guests_captures.sql`. Verify with:

```powershell
wrangler d1 execute rincon --remote --command "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('messenger_outbound','extra_guests_captures');"
```

### Step 2 — Deploy worker (manual per CLAUDE.md guardrail)

```powershell
pnpm deploy:bot
```

CF Pages auto-deploys the web side on merge to main. Both `ba7f4a9` (wave) + `5b3f6...` (hotfix) should now be live on /proxReservas + /admin/extra-guests + /admin/inbox once CF Pages finishes.

### Step 3 — Smoke test BEFORE flipping flag

All four endpoints should respond correctly with flag still OFF:

```powershell
# Without secret → 401
curl -X POST https://bot.rincondelmar.club/admin/messenger/send -d '{}'
# → 401 unauthorized

# With secret, no body → 400
curl -X POST https://bot.rincondelmar.club/admin/messenger/send `
  -H "x-admin-secret: $env:ADMIN_REFRESH_SECRET" -d '{}'
# → 400 missing_conversation_id_or_text

# With secret, valid body, flag OFF → 503 + audit row written
curl -X POST https://bot.rincondelmar.club/admin/messenger/send `
  -H "x-admin-secret: $env:ADMIN_REFRESH_SECRET" `
  -H "content-type: application/json" `
  -d '{"conversation_id":"525570618798","text":"canary smoke","sent_by_user":"alex-canary"}'
# → 503 {"ok":false,"error":"feature_off"}

# Verify audit:
wrangler d1 execute rincon --remote --command "SELECT * FROM messenger_outbound ORDER BY sent_at DESC LIMIT 1;"
# → delivery_status='feature_off'

# Extra-guests scan should run (no captures unless prod has a numAdult>=16 booking):
curl -X POST https://bot.rincondelmar.club/admin/extra-guests/scan `
  -H "x-admin-secret: $env:ADMIN_REFRESH_SECRET"
# → {"ok":true,"total_eligible":N,"total_created":M,...}
```

### Step 4 — Canary flip (when ready to actually send)

```powershell
# Pick a sandbox/test beds24_booking_id YOU control (your own booking, or a
# scratch test conversation). DO NOT canary on a real guest.

# Flip the flag:
wrangler secret put MESSENGER_OUTBOUND_ENABLED
# When prompted, enter literally: true

# Send 1 message via the admin UI's reply panel (or via curl, but UI tests the
# whole stack — server proxy + worker route + audit + inline UI status):
# https://rincondelmar.club/admin/inbox → find your test conversation → 💬 Reply → "canary"

# Verify in D1:
wrangler d1 execute rincon --remote --command "SELECT delivery_status, conversation_ref, routed_to, sent_at FROM messenger_outbound ORDER BY sent_at DESC LIMIT 3;"
# Should show: delivery_status='sent', routed_to='beds24_api' or 'manychat', NOT 'feature_off'

# Verify on Beds24 / ManyChat side that the message actually appeared.
```

### Step 5 — Rollback if anything goes sideways

```powershell
wrangler secret put MESSENGER_OUTBOUND_ENABLED
# Enter literally: false
# (or anything ≠ 'true' — the string check is strict)
```

Both Part E and Part D outbound paths immediately stop hitting external APIs.

---

## §7 — Awaiting

| Owner | Action |
|---|---|
| **Alex** | Run §6 steps 1-3 (migrations + deploy + smoke). Report back. |
| **Alex** | Coordinate sandbox `beds24_booking_id` with WC for §6 step 4 canary. |
| **WC** | Confirm sandbox booking selection + sign off on §6 step 4 canary plan. |
| **CC** | Standing by for: canary feedback, thread/109 G+H+I+J follow-ups (already shipped per PR #88 — possibly redundant in WC's queue), or next wave. |

Reportar bugs/feedback aquí o nuevo thread.

— CC-Bot, 2026-05-18
