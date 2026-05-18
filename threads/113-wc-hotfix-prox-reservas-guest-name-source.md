# 113 — WC: hotfix — /proxReservas guest name source

**Date**: 2026-05-19
**Author**: WC
**To**: CC-Bot
**Re**: Alex feedback — many "(sin nombre)" rows in production /proxReservas
**Mode**: hotfix (single commit, follow-on to thread/109 Part I)
**Status**: 🟡 Spec defect — WC origin, not CC. Apologies.
**Estimated effort**: ~30 min CC

---

## TL;DR

`/proxReservas.php?pass=vivamexico` shows guest as "(sin nombre)" for many bookings. WC verified via D1 MCP: bookings ARE in `beds24_bookings` with status=booked, but **subquery for first_name/last_name reads `beds24_events`** which is empty for ~62 backfilled-pre-webhook bookings (thread/103).

The names DO exist in the `guests` table (`guests.name`), correctly linked via `beds24_bookings.guest_id`. My spec thread/109 §3 missed this — apologies.

## D1 verification

```sql
-- 10 booked future bookings WITH event_count=0 (the "sin nombre" set)
SELECT bb.beds24_booking_id, bb.channel, g.name as guest_name_from_guests
FROM beds24_bookings bb
LEFT JOIN guests g ON g.id = bb.guest_id
WHERE bb.status = 'booked' AND bb.arrival >= date('now')
  AND (SELECT COUNT(*) FROM beds24_events e 
       WHERE CAST(json_extract(e.payload_json,'$.booking.id') AS INTEGER) = bb.beds24_booking_id) = 0;
```

Returns rows like:
- 79421553 → Alan Granados (the famous Jovany recovered backfill)
- 86656062 → Claudia Becerra Alcantara
- 86656367 → Leticia Ramírez (AirBnB)
- 86655648 → Araceli Garcia (AirBnB)

All have proper `guests.name` populated. Just not in `beds24_events`.

## Fix

In `apps/web/src/pages/proxReservas.php.astro` SQL query, change name source from events-subquery to `guests` JOIN primary + events fallback.

### Current (broken for backfill)

```sql
(SELECT json_extract(payload_json,'$.booking.firstName') 
 FROM beds24_events e 
 WHERE CAST(json_extract(e.payload_json,'$.booking.id') AS INTEGER) = bb.beds24_booking_id
 ORDER BY received_at DESC LIMIT 1) as first_name,
(SELECT json_extract(payload_json,'$.booking.lastName') 
 FROM beds24_events e 
 WHERE CAST(json_extract(e.payload_json,'$.booking.id') AS INTEGER) = bb.beds24_booking_id
 ORDER BY received_at DESC LIMIT 1) as last_name,
```

### Fixed (primary guests, fallback events)

```sql
-- Primary: guests table
g.name AS guest_name,

-- Fallback (only if guest_id is null — rare edge case):
COALESCE(
  g.name,
  (SELECT 
     TRIM(
       COALESCE(json_extract(payload_json,'$.booking.firstName'), '') || ' ' ||
       COALESCE(json_extract(payload_json,'$.booking.lastName'), '')
     )
   FROM beds24_events e 
   WHERE CAST(json_extract(e.payload_json,'$.booking.id') AS INTEGER) = bb.beds24_booking_id
   ORDER BY received_at DESC LIMIT 1)
) AS guest_name
```

Add LEFT JOIN:

```sql
FROM beds24_bookings bb
LEFT JOIN guests g ON g.id = bb.guest_id
WHERE bb.status = 'booked'
  AND bb.arrival >= date('now')
ORDER BY bb.arrival ASC
LIMIT 200
```

### Drop separate first/last fields

Simplify TypeScript types — collapse `first_name + last_name` into single `guest_name`. Component renders `{guest_name ?? '(sin nombre)'}` instead of `{first_name} {last_name}`.

### Phone fallback while at it

Same defect potential — phone also comes from events subquery. Apply same pattern:

```sql
COALESCE(
  g.phone_e164,                                    -- primary: guests E.164 (with +)
  (SELECT COALESCE(
     json_extract(payload_json,'$.booking.phone'),
     json_extract(payload_json,'$.booking.mobile')
   ) FROM beds24_events e 
   WHERE CAST(json_extract(e.payload_json,'$.booking.id') AS INTEGER) = bb.beds24_booking_id
   ORDER BY received_at DESC LIMIT 1)
) AS phone
```

`guests.phone_e164` is already `+E.164` format (e.g. `+525582528741`). The Part G `normalizePhoneForWhatsApp()` helper strips `+` automatically. No additional change.

### Comments handling

`guestComments` exists only in `beds24_events`. Keep events subquery for that one column. NULL is fine if backfill has no event.

## Acceptance criteria

- Backfilled bookings (Alan Granados, Claudia Becerra, etc.) show real names instead of "(sin nombre)"
- Webhook-arrived bookings still show names (no regression)
- Phone field uses E.164 from guests, falls back to events if NULL
- "(sin nombre)" only appears when truly NO name anywhere (guests.name NULL AND no events)
- Test fixture for backfilled booking added: `apps/web/tests/staff-prox-reservas.test.ts`

## Commit

```
git checkout -b hotfix/prox-reservas-guest-name-source

# Edit apps/web/src/pages/proxReservas.php.astro + StaffReservasList.tsx

git commit -m "fix(staff/prox-reservas): pull guest name from guests table

Original query (thread/109 §3) read firstName/lastName from
beds24_events subquery. But ~62 backfilled-pre-webhook bookings
(thread/103) have no events — only entries in beds24_bookings +
guests. Resulted in many '(sin nombre)' for real bookings.

Fix: LEFT JOIN guests via beds24_bookings.guest_id (primary source),
fallback to beds24_events subquery only if guest_id NULL.

Same pattern for phone: g.phone_e164 primary, events fallback.

Verified via D1 MCP — Alan Granados (79421553), Claudia Becerra
(86656062), Leticia Ramírez (86656367) all have guests.name set.

Spec defect from WC, not CC. Apologies on the slip.

Refs: thread/113"

gh pr create --title "fix(staff/prox-reservas): guest name source" ...
gh pr merge <N> --squash --delete-branch
```

## Out of scope

- ❌ Backfill `beds24_events` from `beds24_bookings` (separate concern, NOT needed)
- ❌ Touch /admin/bookings drawer (separate query, may have same defect — flag for later check)
- ❌ Touch C+E+D+P2 sprint scope
- ❌ Add migrations

## Priority

Low-medium urgent. /proxReservas is staff-only, but staff actively uses it. Recommendation: ship as small hotfix before C+E+D+P2 sprint kicks off (single commit, <30 min CC). Or bundle in C+E+D+P2 final commits if scope allows.

WC voto: hotfix first. Staff page is daily-use, fix is obvious + isolated.

— WC, 2026-05-19
