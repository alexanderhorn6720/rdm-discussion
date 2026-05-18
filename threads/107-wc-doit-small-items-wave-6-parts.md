# 107 — WC: DoIt — small items wave (6 parts bundled)

**Date**: 2026-05-19
**Author**: WC
**To**: CC-Bot
**Re**: Alex feedback wave consolidado en single sprint
**Mode**: DoIt
**Status**: 🟢 Ready after thread/106 completes (thread/105 inbox + 2 bugs)
**Estimated effort**: ~20-25h CC single sprint

---

## TL;DR — Table of Contents

6 parts bundled. Single PR, atomic commits per part. Order = quick wins first, complejidad después.

| Part | Item | Effort | Section |
|---|---|---|---|
| **F** | Fix /admin/conv 3 bugs | 1-2h | §1 |
| **C** | Channel native buttons (logos oficiales) | 1-2h | §2 |
| **A** | Inquiries auto-close cron | 2-3h | §3 |
| **B** | Conversations auto-close cron | 2-3h | §4 |
| **E** | Inbox WhatsApp-style mobile UX | 5-6h | §5 |
| **D** | Extra guests >16 detection + capture + invoice | 8-10h | §6 |

Total: ~20-25h CC. Single PR `feat/small-items-wave`. 6+ atomic commits.

---

## §0 — Common pre-flight (run before any part)

```powershell
PRE-FLIGHT (auto-execute, halt only on real failure):

1. Set-Location "$env:USERPROFILE\rdm\dev\bot"
2. git status --short  → clean (or stashed)
3. git fetch origin
4. git checkout main && git pull origin main
5. gh auth status → logged in
6. wrangler whoami → authenticated
7. Verify migration sequence: ls migrations/ | tail -1 should show 0029
   New migrations start at 0030
8. Verify thread/106 reported merged successfully (PR from thread/105):
   gh pr list --repo alexanderhorn6720/rdm-bot --state merged --limit 3
   Should include "feat(admin/inbox)" or similar
```

============================================================
DELIVERABLES
============================================================

PASO 1 — Branch
```
git checkout -b feat/small-items-wave
```

PASO 2 — Execute parts F → C → A → B → E → D in order
PASO 3 — Atomic commit per part (6 commits minimum)
PASO 4 — Push + PR + squash merge
PASO 5 — Apply migrations (ask tier)
PASO 6 — Deploy worker (ask tier)
PASO 7 — Smoke tests
PASO 8 — Report thread/108

---

## §1 — Part F: Fix /admin/conv 3 bugs (1-2h)

### Bug 1.1 — `conv-search` crash with phone-style numbers

**Evidence**: Alex tested with `5570658798` → Network error: `Cannot read properties of undefined (reading 'length')`.

**Root cause** (verified via code review):
- Worker endpoint `/admin/conv/search` (`apps/worker-bot/src/index.ts:1064`) returns `{ ok: true, results: [...] }` OR `{ ok: false, error: '...' }`
- Client (`apps/web/src/pages/admin/conv.astro:168`) does `rows.length === 0` without verifying `data.results` exists
- When worker returns error response (e.g. auth fail), `data.results` is `undefined` → crash

**Fix** (`apps/web/src/pages/admin/conv.astro` line ~168):
```typescript
const rows = (data.results ?? []) as Array<{
  subscriber_id: string;
  turn_count: number;
  // ... rest of type
}>;
if (rows.length === 0) {
  // ...existing logic
}
```

### Bug 1.2 — Subscriber ID input action button broken

**Symptom (Alex feedback)**: when entering subscriber ID directly in field 2, clicking action buttons doesn't work.

**Investigation needed**:
- Trace JavaScript flow when subscriber ID typed directly (no search)
- Likely event listener not firing without prior search
- Check `apps/web/src/pages/admin/conv.astro` lines 200-300 for action handlers

**Fix**: ensure action handlers bind to subscriber ID input change event, not just to `searchResults` selection.

### Bug 1.3 — History action button broken

**Symptom (Alex feedback)**: "Acción 3 → history" doesn't work.

**Investigation**:
- History button calls some `/api/admin/conv/{subscriber}/history` endpoint
- Check if endpoint exists at `apps/web/src/pages/api/admin/conv/[subscriberId]/[action].ts`
- Verify worker has `/admin/conv/{id}/history` handler

**Fix**: based on what investigation reveals. Likely endpoint missing handler for `history` action.

### Acceptance criteria Part F

- Search with phone numbers (8-12 digits) works without crash
- Subscriber ID typed directly + action button click works
- History button shows greeter_turns timeline
- Tests added for 3 bug scenarios

**Commit message**:
```
fix(admin/conv): 3 bugs in legacy admin page

1. conv-search.ts client crashes when worker returns error
   (results undefined) — guard with ?? []
2. Subscriber ID direct input + action button not firing — bind handlers
3. History action endpoint/handler — investigate + fix

Refs: thread/107 §1
```

---

## §2 — Part C: Channel native buttons with logos oficiales (1-2h)

### Scope

Add deep-link buttons to admin/bookings drawer + list view per channel.

### Logos download instructions

**Airbnb logo**:
- Source: https://www.airbnb.com/help/article/904 (host brand guidelines page)
- Format: SVG preferred, PNG fallback
- Save to: `apps/web/public/logos/airbnb.svg`
- Brand color: #FF5A5F (Airbnb pink)
- Usage: deep-link to AirBnB host reservation page

**Booking.com logo**:
- Source: https://partner.booking.com (developer/partner resources)
- Format: SVG preferred, PNG fallback
- Save to: `apps/web/public/logos/booking-com.svg`
- Brand color: #003580 (Booking.com blue)
- Usage: deep-link to Booking.com extranet booking page

**Beds24 logo**:
- Source: https://beds24.com (use site favicon or screenshot crop)
- Save to: `apps/web/public/logos/beds24.svg`
- Brand color: #00A19A (Beds24 teal-ish)

**Note for CC**: if downloading official logos requires browser auth, use placeholders (Lucide ExternalLink colored) and document in commit for Alex to swap manually. Don't block on logo acquisition.

### URL helpers (extend `apps/web/src/lib/beds24-links.ts`)

```typescript
// File: apps/web/src/lib/beds24-links.ts

export function beds24BookingUrl(beds24BookingId: number | string): string {
  return `https://beds24.com/control2.php?ajax=bookedit&id=${beds24BookingId}&tab=1`;
}

export function airbnbHostReservationUrl(confirmationCode: string): string {
  // Pattern: airbnb.com/hosting/reservations/details/{code}
  return `https://www.airbnb.com/hosting/reservations/details/${confirmationCode}`;
}

export function bookingComExtranetUrl(reservationCode: string): string {
  // Pattern: admin.booking.com/hotel/hoteladmin/extranet_ng/manage/booking.html?res_id={code}
  return `https://admin.booking.com/hotel/hoteladmin/extranet_ng/manage/booking.html?res_id=${reservationCode}`;
}

export type ChannelButtonInfo = {
  label: string;
  url: string;
  logoSrc: string;
  brandColor: string;
};

export function getChannelButtons(
  channel: string,
  beds24BookingId: number,
  channelReservationCode: string | null,
): ChannelButtonInfo[] {
  const buttons: ChannelButtonInfo[] = [
    {
      label: 'Open in Beds24',
      url: beds24BookingUrl(beds24BookingId),
      logoSrc: '/logos/beds24.svg',
      brandColor: '#00A19A',
    },
  ];

  if (channel === 'airbnb' && channelReservationCode) {
    buttons.unshift({
      label: 'Open in Airbnb',
      url: airbnbHostReservationUrl(channelReservationCode),
      logoSrc: '/logos/airbnb.svg',
      brandColor: '#FF5A5F',
    });
  }

  if (channel === 'booking_com' && channelReservationCode) {
    buttons.unshift({
      label: 'Open in Booking.com',
      url: bookingComExtranetUrl(channelReservationCode),
      logoSrc: '/logos/booking-com.svg',
      brandColor: '#003580',
    });
  }

  return buttons;
}
```

### Drawer rendering

In `apps/web/src/components/admin/BookingsDrawer.tsx` (or wherever drawer lives):

```tsx
const channelButtons = getChannelButtons(
  booking.channel,
  booking.beds24_booking_id,
  booking.channel_reservation_code,
);

// In JSX bottom of drawer:
<div className="drawer-actions">
  {channelButtons.map(btn => (
    <a
      key={btn.url}
      href={btn.url}
      target="_blank"
      rel="noopener noreferrer"
      className="channel-button"
      style={{ borderColor: btn.brandColor }}
    >
      <img src={btn.logoSrc} alt={btn.label} className="channel-logo" />
      {btn.label}
    </a>
  ))}
  <button onClick={onClose}>Close</button>
</div>
```

### List view rendering (compact icons)

In BookingsView.tsx, add Actions column:

```tsx
<td className="actions-cell">
  {channelButtons.map(btn => (
    <a
      key={btn.url}
      href={btn.url}
      target="_blank"
      rel="noopener noreferrer"
      title={btn.label}
      className="action-icon"
    >
      <img src={btn.logoSrc} alt="" width="16" height="16" />
    </a>
  ))}
</td>
```

### CSS

```css
.channel-button {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border: 1.5px solid;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
}

.channel-logo { width: 16px; height: 16px; }

.action-icon { 
  opacity: 0.7;
  transition: opacity 0.15s;
}
.action-icon:hover { opacity: 1.0; }
```

### Acceptance criteria Part C

- `getChannelButtons()` helper returns correct URL per channel
- Drawer shows channel button(s) + Beds24 + Close
- List view shows compact icons
- Logos load (or placeholder graceful fallback)
- Click button → opens in new tab

**Commit message**:
```
feat(admin/bookings): channel native deep-link buttons

- Airbnb: hosting reservations URL by confirmation_code
- Booking.com: extranet URL by res_id
- Beds24: existing helper extended
- Drawer + list view both updated
- Logos oficiales (or placeholder if download blocked)

Refs: thread/107 §2
```

---

## §3 — Part A: Inquiries auto-close cron (2-3h)

### Migration 0030 — inquiries closure tracking

```sql
-- migrations/0030_inquiries_closure.sql

-- Track inquiry closure for audit + UI filtering
CREATE TABLE inquiries_closed (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  beds24_booking_id INTEGER NOT NULL UNIQUE,
  closed_at TEXT NOT NULL,
  closed_reason TEXT NOT NULL,  -- 'past_arrival' | 'calendar_conflict' | 'stale_7d'
  closed_by TEXT NOT NULL,       -- 'cron_inquiries' | 'admin_manual'
  original_arrival TEXT,
  original_room_id INTEGER,
  notes TEXT
);

CREATE INDEX idx_inquiries_closed_at ON inquiries_closed(closed_at);
```

### Cron worker handler

Create `apps/worker-bot/src/inquiries-auto-close.ts`:

```typescript
/**
 * Daily cron — auto-close stale Airbnb inquiries.
 * 
 * Rules:
 * 1. Past arrival → close (arrival < today)
 * 2. Calendar conflict → close (different booking confirmed same room+overlapping dates)
 * 3. Stale 7d → close (no new event in 7 days)
 * 
 * Runs at 04:00 UTC daily.
 * Idempotent — already-closed inquiries skip.
 */

import { logHeartbeat } from './cron-heartbeat';

interface InquiryRow {
  beds24_booking_id: number;
  arrival: string;
  departure: string;
  room_id: number;
  last_received: number;
}

interface CloseResult {
  total_scanned: number;
  closed_past_arrival: number;
  closed_calendar_conflict: number;
  closed_stale_7d: number;
  errors: number;
  duration_ms: number;
}

export async function runInquiriesAutoClose(env: Env): Promise<CloseResult> {
  const start = Date.now();
  const result: CloseResult = {
    total_scanned: 0,
    closed_past_arrival: 0,
    closed_calendar_conflict: 0,
    closed_stale_7d: 0,
    errors: 0,
    duration_ms: 0,
  };

  try {
    // Get all open inquiries (not already closed)
    const openInquiries = await env.DB.prepare(`
      SELECT
        CAST(json_extract(payload_json,'$.booking.id') AS INTEGER) AS beds24_booking_id,
        json_extract(payload_json,'$.booking.arrival') AS arrival,
        json_extract(payload_json,'$.booking.departure') AS departure,
        CAST(json_extract(payload_json,'$.booking.roomId') AS INTEGER) AS room_id,
        MAX(received_at) AS last_received
      FROM beds24_events e
      WHERE json_extract(payload_json,'$.booking.status') = 'inquiry'
        AND NOT EXISTS (
          SELECT 1 FROM inquiries_closed c
          WHERE c.beds24_booking_id = CAST(json_extract(e.payload_json,'$.booking.id') AS INTEGER)
        )
      GROUP BY beds24_booking_id
    `).all<InquiryRow>();

    result.total_scanned = openInquiries.results?.length ?? 0;
    const today = new Date().toISOString().slice(0, 10);
    const sevenDaysAgo = Math.floor(Date.now() / 1000) - 7 * 86400;

    for (const inq of openInquiries.results ?? []) {
      try {
        // Rule 1: past arrival
        if (inq.arrival && inq.arrival < today) {
          await closeInquiry(env, inq, 'past_arrival');
          result.closed_past_arrival++;
          continue;
        }

        // Rule 2: calendar conflict
        const conflict = await env.DB.prepare(`
          SELECT 1 FROM beds24_bookings
          WHERE room_id = ?
            AND status = 'booked'
            AND beds24_booking_id != ?
            AND arrival < ?
            AND departure > ?
          LIMIT 1
        `).bind(inq.room_id, inq.beds24_booking_id, inq.departure, inq.arrival).first();

        if (conflict) {
          await closeInquiry(env, inq, 'calendar_conflict');
          result.closed_calendar_conflict++;
          continue;
        }

        // Rule 3: stale 7d
        if (inq.last_received < sevenDaysAgo) {
          await closeInquiry(env, inq, 'stale_7d');
          result.closed_stale_7d++;
          continue;
        }
      } catch (err) {
        result.errors++;
        console.error(`[inquiries-close] error inquiry ${inq.beds24_booking_id}:`, err);
      }
    }

    await logHeartbeat(env, 'inquiries-auto-close');
  } catch (err) {
    console.error('[inquiries-close] fatal:', err);
    result.errors++;
  }

  result.duration_ms = Date.now() - start;
  return result;
}

async function closeInquiry(env: Env, inq: InquiryRow, reason: string): Promise<void> {
  await env.DB.prepare(`
    INSERT INTO inquiries_closed (
      beds24_booking_id, closed_at, closed_reason, closed_by,
      original_arrival, original_room_id
    ) VALUES (?, ?, ?, 'cron_inquiries', ?, ?)
  `).bind(
    inq.beds24_booking_id,
    new Date().toISOString(),
    reason,
    inq.arrival,
    inq.room_id,
  ).run();
}
```

### Update inquiries.ts endpoint

In `apps/web/src/pages/api/admin/bookings/inquiries.ts` line 70, add filter:

```sql
SELECT ... FROM beds24_events e
WHERE json_extract(payload_json,'$.booking.status') = 'inquiry'
  AND CAST(json_extract(payload_json,'$.booking.roomId') AS INTEGER) = ?
  AND received_at > unixepoch() - 90 * 86400
  AND NOT EXISTS (
    SELECT 1 FROM inquiries_closed c
    WHERE c.beds24_booking_id = CAST(json_extract(e.payload_json,'$.booking.id') AS INTEGER)
  )
GROUP BY ...
```

### Cron config

Add to `apps/worker-bot/src/index.ts` scheduled handler:

```typescript
case '0 4 * * *':  // 04:00 UTC daily
  await runInquiriesAutoClose(env);
  break;
```

OR if using GitHub Actions, add new workflow file:
```yaml
# .github/workflows/cron-inquiries-auto-close.yml
name: cron-inquiries-auto-close
on:
  schedule:
    - cron: '0 4 * * *'
  workflow_dispatch:
jobs:
  trigger:
    runs-on: ubuntu-latest
    steps:
      - run: |
          curl -X POST -H "Authorization: Bearer ${{ secrets.ADMIN_REFRESH_SECRET }}" \
            https://rincondelmar.club/admin/inquiries-auto-close
```

### Admin endpoint (manual trigger)

In worker `index.ts`:

```typescript
app.post('/admin/inquiries-auto-close', adminAuth, async (c) => {
  const result = await runInquiriesAutoClose(c.env);
  return c.json(result);
});
```

### Tests

`apps/worker-bot/tests/inquiries-auto-close.test.ts`:
- Past arrival inquiry → closes with `past_arrival`
- Calendar conflict → closes with `calendar_conflict`
- Stale 7d → closes with `stale_7d`
- Recent inquiry within range → NOT closed
- Already-closed inquiry → skipped on rerun (idempotency)

### Acceptance criteria Part A

- Migration 0030 applied
- Cron runs daily 04:00 UTC
- Existing 14 stale inquiries closed on first run
- /admin/bookings inquiries dropdown no longer shows closed ones
- Heartbeat logged for monitoring

**Commit**:
```
feat(inquiries): auto-close stale Airbnb inquiries via daily cron

3 rules: past arrival, calendar conflict, stale 7d.
Migration 0030 adds inquiries_closed table.
Worker endpoint /admin/inquiries-auto-close for manual trigger.
Inquiries.ts endpoint filters out closed via NOT EXISTS join.

Resolves 14 currently-stale inquiries in production.
Refs: thread/107 §3
```

---

## §4 — Part B: Conversations auto-close cron (2-3h)

### Migration 0031 — conversations closure metadata

```sql
-- migrations/0031_conversations_closed_reason.sql

-- resolved_at already exists (migration 0029)
-- Add closure metadata
ALTER TABLE conversations ADD COLUMN closed_reason TEXT;
ALTER TABLE conversations ADD COLUMN closed_by TEXT;
```

### Closure rules (matizado)

```typescript
// apps/worker-bot/src/conversations-auto-close.ts

interface ClosureRule {
  name: string;
  description: string;
  match: (conv: Conversation, now: number) => boolean;
}

const RULES: ClosureRule[] = [
  {
    name: 'lead_cold_7d',
    description: 'Lead frío sin booking match, sin actividad 7+ días',
    match: (conv, now) => {
      const lastActiveSec = conv.last_active ?? 0;
      const daysSince = (now - lastActiveSec) / 86400;
      return daysSince >= 7
        && !conv.booking_match  // computed: no beds24_booking match
        && !conv.pending_handoff_data
        && conv.active_agent !== 'booker';
    },
  },
  {
    name: 'lead_hot_arrival_passed',
    description: 'Lead con booking match cuyo arrival ya pasó (3+ días post)',
    match: (conv, now) => {
      if (!conv.booking_arrival) return false;
      const arrivalDate = new Date(conv.booking_arrival);
      const daysPostArrival = (now - arrivalDate.getTime() / 1000) / 86400;
      return daysPostArrival >= 3
        && !conv.pending_handoff_data
        && conv.active_agent !== 'booker';
    },
  },
  {
    name: 'pause_expired',
    description: 'Bot paused_until expired, sin retomada 1+ día',
    match: (conv, now) => {
      if (!conv.bot_paused_until) return false;
      const pauseEnd = new Date(conv.bot_paused_until).getTime() / 1000;
      const daysSincePauseEnd = (now - pauseEnd) / 86400;
      return daysSincePauseEnd >= 1
        && conv.last_active < pauseEnd;  // no activity since pause expired
    },
  },
];
```

### NEVER close (anti-patterns)

```typescript
function shouldNeverClose(conv: Conversation): boolean {
  // Pending handoff data
  if (conv.pending_handoff_data) return true;
  
  // Booker agent active (booking in progress)
  if (conv.active_agent === 'booker') return true;
  
  // In-stay booking (arrival <= today < departure)
  if (conv.booking_in_stay) return true;
  
  return false;
}
```

### Run function

```typescript
export async function runConversationsAutoClose(env: Env): Promise<CloseResult> {
  const now = Math.floor(Date.now() / 1000);
  const result = { total_scanned: 0, closed_per_rule: {} as Record<string, number>, errors: 0 };

  // Get open conversations with booking context
  const convs = await env.DB.prepare(`
    SELECT 
      c.*,
      bb.arrival as booking_arrival,
      bb.departure as booking_departure,
      (CASE WHEN bb.arrival <= date('now') AND bb.departure > date('now') 
            THEN 1 ELSE 0 END) as booking_in_stay,
      (CASE WHEN bb.beds24_booking_id IS NOT NULL THEN 1 ELSE 0 END) as booking_match
    FROM conversations c
    LEFT JOIN beds24_bookings bb 
      ON bb.guest_phone = c.subscriber_id  -- or similar match logic
      AND bb.status = 'booked'
    WHERE c.resolved_at IS NULL
      AND c.closed_reason IS NULL
  `).all();

  result.total_scanned = convs.results?.length ?? 0;

  for (const conv of convs.results ?? []) {
    if (shouldNeverClose(conv)) continue;
    
    for (const rule of RULES) {
      if (rule.match(conv, now)) {
        await env.DB.prepare(`
          UPDATE conversations
          SET resolved_at = ?, closed_reason = ?, closed_by = 'cron_conv_close'
          WHERE subscriber_id = ?
        `).bind(new Date().toISOString(), rule.name, conv.subscriber_id).run();
        
        result.closed_per_rule[rule.name] = (result.closed_per_rule[rule.name] ?? 0) + 1;
        break;
      }
    }
  }

  await logHeartbeat(env, 'conversations-auto-close');
  return result;
}
```

### Admin endpoint + cron

Similar pattern to Part A:
- POST `/admin/conversations-auto-close` (manual trigger)
- Same daily 04:00 UTC cron (consolidate with §3)

### Tests

- Lead frío 7d → closed with `lead_cold_7d`
- Lead with booking arrival 4d passed → closed `lead_hot_arrival_passed`
- Pause expired 2d ago + no activity → closed `pause_expired`
- Lead frío 2d → NOT closed
- pending_handoff_data → NEVER closed
- active_agent='booker' → NEVER closed
- In-stay booking → NEVER closed

### Acceptance criteria Part B

- Migration 0031 applied
- 80 currently-open conversations evaluated on first run
- Expected: ~50-60 auto-closed (lead frío category dominante)
- 2 conversations stuck open via NEVER rule = safe
- /admin/inbox shows accurate "open" count after run

**Commit**:
```
feat(conversations): auto-close cron with matizado rules

3 closure rules:
- lead_cold_7d: lead frío sin booking 7+ días
- lead_hot_arrival_passed: arrival pasó hace 3+ días
- pause_expired: bot pause expired sin retomada 1+ día

NEVER close: pending_handoff_data, active_agent=booker, in-stay.

Migration 0031 adds closed_reason + closed_by columns.
Consolidated with §3 cron (same 04:00 UTC slot).

Refs: thread/107 §4
```

---

## §5 — Part E: Inbox WhatsApp-style mobile UX (5-6h)

**Note**: thread/106 from CC should have basic `/admin/inbox` desktop done (list + 7 states + filters + hover actions). Part E adds mobile-first WhatsApp UX on top.

### UX pattern

```
DESKTOP (>1024px):
  /admin/inbox shows split-view: list left + conv right (existing behavior from thread/105)

MOBILE (<1024px):
  /admin/inbox shows list view ONLY by default
  Tap card → hide list, show conv full-screen
  Back arrow → show list, hide conv
  Same URL — no page navigation, just CSS/JS state toggle
```

### Implementation approach

Use a single Astro page `/admin/inbox.astro` with React island for state management:

```tsx
// apps/web/src/components/admin/InboxView.tsx

import { useState, useEffect } from 'react';

interface InboxViewProps {
  conversations: ConversationListItem[];
  initialFilter?: FilterState;
}

export function InboxView({ conversations, initialFilter }: InboxViewProps) {
  const [selectedConv, setSelectedConv] = useState<string | null>(null);
  const [isMobile, setIsMobile] = useState(false);
  
  useEffect(() => {
    const mq = window.matchMedia('(max-width: 1024px)');
    setIsMobile(mq.matches);
    const handler = (e: MediaQueryListEvent) => setIsMobile(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  // Mobile: list OR conv (full screen)
  // Desktop: list AND conv (split)
  const showList = !isMobile || !selectedConv;
  const showConv = !isMobile || !!selectedConv;

  return (
    <div className="inbox-container">
      {showList && (
        <InboxList
          conversations={conversations}
          selected={selectedConv}
          onSelect={setSelectedConv}
        />
      )}
      {showConv && selectedConv && (
        <ConversationView
          conversationId={selectedConv}
          onBack={isMobile ? () => setSelectedConv(null) : undefined}
        />
      )}
    </div>
  );
}
```

### Card-style list

```tsx
// InboxListCard.tsx

function InboxListCard({ conv, selected, onClick }: Props) {
  const channelIcon = getChannelIcon(conv.channel);
  const stateBadge = getStateBadge(conv.state);
  
  return (
    <div 
      className={`inbox-card ${selected ? 'selected' : ''}`}
      onClick={onClick}
    >
      <div className="card-header">
        <span className="channel-icon">{channelIcon}</span>
        <span className="subscriber-name">{conv.subscriber_name ?? 'sin nombre'}</span>
        <span className="time">{formatRelativeTime(conv.last_active)}</span>
      </div>
      <div className="card-body">
        <p className="last-message-preview">{conv.last_message_snippet}</p>
      </div>
      <div className="card-footer">
        <span className="context">
          {conv.property_name} · {conv.booking_date ?? '—'}
        </span>
        {stateBadge}
      </div>
    </div>
  );
}
```

### Conversation view (full screen mobile)

```tsx
// ConversationView.tsx

function ConversationView({ conversationId, onBack }: Props) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);

  useEffect(() => {
    fetchMessages(conversationId).then(setMessages);
  }, [conversationId]);

  async function handleSend() {
    if (!input.trim() || sending) return;
    setSending(true);
    try {
      const res = await fetch(`/api/admin/messenger/send`, {
        method: 'POST',
        body: JSON.stringify({
          conversation_id: conversationId,
          text: input.trim(),
        }),
      });
      const data = await res.json();
      if (data.ok) {
        // Optimistic add
        setMessages(prev => [...prev, { 
          id: data.id, 
          text: input.trim(), 
          direction: 'outbound',
          timestamp: new Date().toISOString(),
          sent_by_user: 'alex',  // from auth context
        }]);
        setInput('');
      } else {
        alert(`Send failed: ${data.error}`);
      }
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="conv-view">
      <header className="conv-header">
        {onBack && <button onClick={onBack} className="back-btn">←</button>}
        <div className="conv-meta">
          <h2>{conversation.subscriber_name}</h2>
          <p>{conversation.channel} · {conversation.context}</p>
        </div>
        <button className="kebab-menu">⋮</button>
      </header>

      <div className="messages-thread">
        {messages.map(msg => (
          <MessageBubble key={msg.id} message={msg} />
        ))}
      </div>

      <div className="option-buttons">
        <button onClick={pauseBot}>⏸ Pause</button>
        <button onClick={markResolved}>✅ Resolve</button>
        <button onClick={triggerEscalation}>⚠ Escalate</button>
      </div>

      <div className="input-bar">
        <input
          type="text"
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyPress={e => e.key === 'Enter' && handleSend()}
          placeholder="Type a message..."
          disabled={sending}
        />
        <button onClick={handleSend} disabled={!input.trim() || sending}>
          📤
        </button>
      </div>
    </div>
  );
}
```

### Send-message endpoint

Create `apps/web/src/pages/api/admin/messenger/send.ts`:

```typescript
import { isAdmin } from '@/lib/admin';
import type { APIRoute } from 'astro';

export const prerender = false;

export const POST: APIRoute = async ({ request, locals }) => {
  const env = locals.runtime?.env as Env;
  const user = locals.user;

  if (!isAdmin(env, user?.email)) {
    return new Response(JSON.stringify({ ok: false, error: 'forbidden' }), { status: 403 });
  }

  const body = await request.json() as {
    conversation_id: string;
    text: string;
  };

  // Proxy to worker
  const res = await fetch(`https://bot.rincondelmar.club/admin/messenger/send`, {
    method: 'POST',
    headers: {
      'x-admin-secret': env.ADMIN_REFRESH_SECRET,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      ...body,
      sent_by_user: user?.email ?? 'unknown',
    }),
  });

  return new Response(await res.text(), {
    status: res.status,
    headers: { 'content-type': 'application/json' },
  });
};
```

### Worker endpoint with routing

In `apps/worker-bot/src/index.ts`:

```typescript
app.post('/admin/messenger/send', adminAuth, async (c) => {
  const body = await c.req.json();
  const { conversation_id, text, sent_by_user } = body;

  // Determine source + route
  const conv = await c.env.DB.prepare(`
    SELECT 
      c.subscriber_id,
      c.last_intent,
      bmi.booking_id as beds24_booking_id,
      bmi.source as inbox_source
    FROM conversations c
    LEFT JOIN bot_messages_inbox bmi ON bmi.booking_id::text = c.subscriber_id
    WHERE c.subscriber_id = ?
    LIMIT 1
  `).bind(conversation_id).first();

  let routedTo: string;
  let externalId: string | null = null;

  try {
    if (conv?.beds24_booking_id) {
      // Beds24 messages API (routes to AirBnB / Booking.com automatically)
      const res = await postBeds24Message(c.env, conv.beds24_booking_id, text);
      routedTo = 'beds24_api';
      externalId = res.messageId;
    } else if (conversation_id.startsWith('521') || conversation_id.match(/^\d{10,12}$/)) {
      // WhatsApp via ManyChat
      const res = await sendManychatMessage(c.env, conversation_id, text);
      routedTo = 'manychat';
      externalId = res.id;
    } else {
      return c.json({ ok: false, error: 'no_route_resolved' }, 400);
    }

    // Log outbound
    await c.env.DB.prepare(`
      INSERT INTO messenger_outbound (
        conversation_source, conversation_ref, message_text,
        routed_to, sent_at, sent_by_user, delivery_status, external_message_id
      ) VALUES (?, ?, ?, ?, ?, ?, 'sent', ?)
    `).bind(
      conv?.beds24_booking_id ? 'beds24_inbox' : 'whatsapp',
      conversation_id,
      text,
      routedTo,
      new Date().toISOString(),
      sent_by_user,
      externalId,
    ).run();

    return c.json({ ok: true, id: externalId, routed_to: routedTo });
  } catch (err) {
    return c.json({ ok: false, error: 'send_failed', detail: String(err) }, 500);
  }
});

async function postBeds24Message(env: Env, bookingId: number, text: string) {
  const token = await getBeds24AccessToken(env);
  const res = await fetch('https://api.beds24.com/v2/bookings/messages', {
    method: 'POST',
    headers: { token, 'content-type': 'application/json' },
    body: JSON.stringify({
      data: [{ bookingId, message: text, source: 'host' }],
    }),
  });
  if (!res.ok) throw new Error(`Beds24 send failed: ${res.status}`);
  const json = await res.json() as any;
  return { messageId: json.data?.[0]?.messageId };
}

async function sendManychatMessage(env: Env, subscriberId: string, text: string) {
  const res = await fetch(`https://api.manychat.com/fb/sending/sendContent`, {
    method: 'POST',
    headers: {
      'authorization': `Bearer ${env.MANYCHAT_API_TOKEN}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      subscriber_id: subscriberId,
      data: {
        version: 'v2',
        content: { messages: [{ type: 'text', text }] },
      },
    }),
  });
  if (!res.ok) throw new Error(`ManyChat send failed: ${res.status}`);
  const json = await res.json() as any;
  return { id: json.message_id };
}
```

### Migration 0032 — messenger_outbound table

```sql
-- migrations/0032_messenger_outbound.sql

CREATE TABLE messenger_outbound (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_source TEXT NOT NULL,
  conversation_ref TEXT NOT NULL,
  message_text TEXT NOT NULL,
  routed_to TEXT NOT NULL,
  sent_at TEXT NOT NULL,
  sent_by_user TEXT NOT NULL,
  delivery_status TEXT NOT NULL DEFAULT 'sent',
  failure_reason TEXT,
  external_message_id TEXT
);

CREATE INDEX idx_outbound_conv ON messenger_outbound(conversation_ref, sent_at);
CREATE INDEX idx_outbound_user ON messenger_outbound(sent_by_user, sent_at);
```

### CSS for WhatsApp UX

```css
/* Mobile-first */
.inbox-container {
  display: grid;
  grid-template-columns: 1fr;
  height: 100vh;
}

@media (min-width: 1024px) {
  .inbox-container {
    grid-template-columns: 360px 1fr;
  }
}

.inbox-card {
  padding: 12px 16px;
  border-bottom: 1px solid #eee;
  cursor: pointer;
}
.inbox-card.selected { background: #f0f7ff; }
.inbox-card:hover { background: #f9f9f9; }

.conv-view {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.messages-thread {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  background: #efeae2; /* WhatsApp-style */
}

.message-bubble {
  max-width: 75%;
  padding: 8px 12px;
  border-radius: 8px;
  margin-bottom: 8px;
}
.message-bubble.inbound {
  background: white;
  align-self: flex-start;
}
.message-bubble.outbound {
  background: #d9fdd3;
  align-self: flex-end;
}

.input-bar {
  display: flex;
  padding: 12px;
  border-top: 1px solid #eee;
  gap: 8px;
}
.input-bar input { flex: 1; }
```

### Acceptance criteria Part E

- Mobile <1024px: list view only, tap card → full-screen conv
- Mobile: back arrow returns to list
- Desktop ≥1024px: split view (existing behavior preserved)
- Input box bottom + send button
- Option buttons row (Pause/Resolve/Escalate) above input
- Send routes correctly:
  - Beds24 booking → Beds24 messages API
  - WhatsApp subscriber → ManyChat send
- Optimistic UI update on send
- Failure handling: alert + don't clear input
- All Telegram-noise sources unified in single inbox

**Commit**:
```
feat(admin/inbox): WhatsApp-style mobile UX + reply integration

- Mobile: list ↔ conv full-screen toggle (no page nav)
- Desktop: split view preserved
- Card-style list (WhatsApp visual pattern)
- Conversation view: header + thread + option buttons + input
- Send-message endpoint with routing:
  - Beds24 booking → Beds24 messages API
  - WhatsApp subscriber → ManyChat send
- Migration 0032 adds messenger_outbound table
- Optimistic UI + failure handling

Refs: thread/107 §5
```

---

## §6 — Part D: Extra guests >16 detection + capture + invoice (8-10h)

### Scope

Detect AirBnB inquiries/bookings where guest count is suspicious (>= 16 = AirBnB UI cap), proactively capture real count via Beds24 messages API, calculate extra revenue, post Beds24 invoice item.

### Trigger conditions

```typescript
function shouldTriggerExtraGuestsCapture(event: Beds24Event): boolean {
  const booking = event.payload?.booking;
  if (!booking) return false;

  // Channel: AirBnB only
  if (booking.referer?.toLowerCase() !== 'airbnb') return false;

  // Room: RdM, Morenas, Combinada (NOT Huerta — cap 12 already real)
  const eligibleRooms = [78695, 374482, 74316];
  if (!eligibleRooms.includes(booking.roomId)) return false;

  // Guest count threshold
  if ((booking.numAdult ?? 0) < 16) return false;

  // Skip if already captured
  if (event.extra_guests_captured) return false;

  // Skip if VIP repeat guest (Phase 2)
  // if (isVipRepeatGuest(booking.guestPhone)) return false;

  return true;
}
```

### Migration 0033 — extra guests capture

```sql
-- migrations/0033_extra_guests_capture.sql

CREATE TABLE extra_guests_captures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  beds24_booking_id INTEGER NOT NULL UNIQUE,
  detected_at TEXT NOT NULL,
  booking_status_at_detection TEXT NOT NULL,  -- 'inquiry' | 'confirmed'
  initial_guest_count INTEGER NOT NULL,
  room_id INTEGER NOT NULL,
  num_nights INTEGER NOT NULL,
  expected_guests INTEGER,
  extra_guests_count INTEGER,
  extra_per_person_per_night_mxn INTEGER,
  expected_extra_revenue_mxn INTEGER,
  captured_at TEXT,
  captured_via TEXT,  -- 'beds24_messages' | 'whatsapp' | 'manual'
  beds24_invoice_item_id INTEGER,
  status TEXT NOT NULL DEFAULT 'pending_capture',  -- pending_capture | captured | no_response | confirmed_16 | inquiry_cancelled
  attempts INTEGER NOT NULL DEFAULT 0,
  last_attempt_at TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_extra_guests_status ON extra_guests_captures(status, detected_at);
CREATE INDEX idx_extra_guests_pending ON extra_guests_captures(status) WHERE status = 'pending_capture';
```

### Extra-person price per room

```typescript
const EXTRA_PERSON_RATES: Record<number, number> = {
  78695: 300,    // RdM
  374482: 300,   // Morenas
  74316: 300,    // Combinada
  637063: 200,   // Huerta (excluded but mapped for completeness)
};
```

### Detection trigger (webhook + cron)

In `apps/worker-bot/src/beds24-webhook.ts` after normalize logic:

```typescript
// After event saved to beds24_events
if (shouldTriggerExtraGuestsCapture(event)) {
  await createPendingCapture(env, event.payload.booking);
}
```

In daily cron, scan inquiries that became eligible since last run:

```typescript
async function scanForExtraGuestsCapture(env: Env) {
  const eligible = await env.DB.prepare(`
    SELECT 
      CAST(json_extract(payload_json,'$.booking.id') AS INTEGER) AS beds24_booking_id,
      CAST(json_extract(payload_json,'$.booking.numAdult') AS INTEGER) AS num_adults,
      CAST(json_extract(payload_json,'$.booking.roomId') AS INTEGER) AS room_id,
      json_extract(payload_json,'$.booking.arrival') AS arrival,
      json_extract(payload_json,'$.booking.departure') AS departure,
      json_extract(payload_json,'$.booking.status') AS status
    FROM beds24_events e
    WHERE json_extract(payload_json,'$.booking.referer') = 'Airbnb'
      AND CAST(json_extract(payload_json,'$.booking.numAdult') AS INTEGER) >= 16
      AND CAST(json_extract(payload_json,'$.booking.roomId') AS INTEGER) IN (78695, 374482, 74316)
      AND NOT EXISTS (
        SELECT 1 FROM extra_guests_captures egc
        WHERE egc.beds24_booking_id = CAST(json_extract(e.payload_json,'$.booking.id') AS INTEGER)
      )
    GROUP BY beds24_booking_id
  `).all();

  for (const row of eligible.results ?? []) {
    await createPendingCapture(env, row);
  }
}
```

### Proactive outreach via Beds24 messages

```typescript
async function sendCaptureMessage(env: Env, capture: ExtraGuestsCapture) {
  const room = ROOM_NAMES[capture.room_id] ?? 'la propiedad';
  const arrival = formatDate(capture.arrival);
  const nights = capture.num_nights;

  const messageText = `
Hola! Gracias por reservar ${room} para ${arrival} (${nights} ${nights === 1 ? 'noche' : 'noches'}).

Tu reserva muestra 16 personas, pero Airbnb solo permite mostrar hasta 16. Si esperan más, tenemos un cargo extra de $${capture.extra_per_person_per_night_mxn} MXN por persona adicional por noche.

¿Cuántas personas vendrán en total? (Aproximado está bien)
`.trim();

  const result = await postBeds24Message(env, capture.beds24_booking_id, messageText);
  
  await env.DB.prepare(`
    UPDATE extra_guests_captures
    SET attempts = attempts + 1,
        last_attempt_at = ?,
        captured_via = 'beds24_messages'
    WHERE beds24_booking_id = ?
  `).bind(new Date().toISOString(), capture.beds24_booking_id).run();
}
```

### Parsing guest response

```typescript
function parseGuestCountFromMessage(text: string): number | null {
  // Patterns to detect:
  // "22 personas", "como 25", "vamos a ser 18", "around 20", etc.
  
  const numberMatch = text.match(/\b(\d{1,2})\s*(personas|gente|pax|adultos|ppl|people)\b/i);
  if (numberMatch) return parseInt(numberMatch[1], 10);
  
  const vagueMatch = text.match(/\b(\d{1,2})\b/);
  if (vagueMatch) {
    const num = parseInt(vagueMatch[1], 10);
    if (num >= 10 && num <= 60) return num;  // sanity bounds
  }
  
  return null;
}
```

### Process capture + post Beds24 invoice

```typescript
async function processCaptureResponse(env: Env, bookingId: number, guestCount: number) {
  const capture = await env.DB.prepare(`
    SELECT * FROM extra_guests_captures WHERE beds24_booking_id = ?
  `).bind(bookingId).first<ExtraGuestsCapture>();

  if (!capture) throw new Error('Capture not found');

  if (guestCount <= 16) {
    // Confirmed they fit in cap, no extra
    await env.DB.prepare(`
      UPDATE extra_guests_captures
      SET expected_guests = ?, status = 'confirmed_16', captured_at = ?
      WHERE beds24_booking_id = ?
    `).bind(guestCount, new Date().toISOString(), bookingId).run();
    
    await postBeds24Message(env, bookingId, `Perfecto, gracias. Te esperamos para ${guestCount} personas.`);
    return;
  }

  const extraGuests = guestCount - 16;
  const extraRevenue = extraGuests * capture.num_nights * capture.extra_per_person_per_night_mxn;

  // Post Beds24 invoice item
  const invoiceItemId = await postBeds24InvoiceItem(env, bookingId, {
    type: 'charge',
    description: `${extraGuests} huéspedes extra × ${capture.num_nights}N (capturado pre-arrival)`,
    amount: extraRevenue,
    qty: 1,
  });

  // Update D1
  await env.DB.prepare(`
    UPDATE extra_guests_captures
    SET expected_guests = ?, 
        extra_guests_count = ?, 
        expected_extra_revenue_mxn = ?,
        captured_at = ?,
        status = 'captured',
        beds24_invoice_item_id = ?
    WHERE beds24_booking_id = ?
  `).bind(
    guestCount, extraGuests, extraRevenue,
    new Date().toISOString(), invoiceItemId, bookingId,
  ).run();

  // Confirm message to guest
  await postBeds24Message(env, bookingId, `
Confirmado, ${guestCount} personas en total.

Cargo extra:
${extraGuests} personas × ${capture.num_nights} noches × $${capture.extra_per_person_per_night_mxn} = $${extraRevenue} MXN

Este cargo se cobra a la llegada (efectivo o transferencia).
`.trim());
}
```

### Beds24 messages inbound handler

The bot already polls Beds24 messages via existing infrastructure. Add hook to detect responses to capture messages:

In message processing (`apps/worker-bot/src/client-bot-polling.ts` or similar):

```typescript
// When new inbound Beds24 message detected
async function handleInboundBeds24Message(env: Env, message: Beds24Message) {
  // Check if this booking has pending extra_guests_capture
  const capture = await env.DB.prepare(`
    SELECT * FROM extra_guests_captures
    WHERE beds24_booking_id = ?
      AND status = 'pending_capture'
  `).bind(message.bookingId).first<ExtraGuestsCapture>();

  if (capture && message.source === 'guest') {
    const guestCount = parseGuestCountFromMessage(message.text);
    if (guestCount !== null) {
      await processCaptureResponse(env, message.bookingId, guestCount);
      return; // intercepted
    }
    // If not parseable, mark attempt but keep pending
  }
}
```

### Retry strategy

Daily cron also handles retries:

```typescript
// Retry pending captures with attempts < 3
const retries = await env.DB.prepare(`
  SELECT * FROM extra_guests_captures
  WHERE status = 'pending_capture'
    AND attempts < 3
    AND (last_attempt_at IS NULL OR last_attempt_at < datetime('now', '-2 days'))
`).all<ExtraGuestsCapture>();

for (const capture of retries.results ?? []) {
  await sendCaptureMessage(env, capture);
}

// Mark as no_response if 3+ attempts without success
await env.DB.prepare(`
  UPDATE extra_guests_captures
  SET status = 'no_response'
  WHERE status = 'pending_capture' AND attempts >= 3
`).run();
```

### UI integration `/admin/bookings`

Drawer: add field after Status:

```tsx
{booking.extra_guests_capture && (
  <div className="extra-guests-info">
    <strong>Expected guests:</strong> {booking.extra_guests_capture.expected_guests ?? '?'} 
    {booking.extra_guests_capture.extra_guests_count > 0 && (
      <span className="extra-revenue">
        (+{booking.extra_guests_capture.extra_guests_count} extra · ${booking.extra_guests_capture.expected_extra_revenue_mxn} MXN)
      </span>
    )}
    <small className="capture-status">{booking.extra_guests_capture.status}</small>
  </div>
)}
```

List view: badge in guest count column:

```tsx
<td>
  {booking.num_adults}
  {booking.extra_guests_capture?.extra_guests_count > 0 && (
    <span className="extra-badge">+{booking.extra_guests_capture.extra_guests_count}</span>
  )}
</td>
```

### Anti-patterns (NO HACER)

- ❌ NUNCA modificar `numAdults` en Beds24 booking (afecta AirBnB sync, viola memorias)
- ❌ NUNCA automatizar el cobro (sin MP auto-charge, Karina cobra manual)
- ❌ Excluir Huerta (637063) — cap 12 ya es real
- ❌ NO insistir más de 3 attempts sin respuesta
- ❌ NO capture post-arrival via bot (regla: post-arrival = Karina manual)
- ❌ NO trigger en VIP repeat guests (Phase 2)
- ❌ NO bypass cuando inquiry status changed to cancelled

### Acceptance criteria Part D

- Migration 0033 applied
- Daily cron + webhook handler both detect new triggers
- Pending captures send proactive Beds24 message
- Inbound message parser detects guest count response
- Beds24 invoice item posted on capture
- Status tracking: pending_capture → captured | no_response | confirmed_16
- /admin/bookings drawer + list show expected guests + extra revenue
- 3 attempt limit before marking no_response
- Retry after 2 days between attempts
- Tests cover all status transitions

**Commit**:
```
feat(extra-guests): capture >16 AirBnB guests + Beds24 invoice integration

Detection: AirBnB inquiries/bookings with numAdult>=16 in RdM/Morenas/Combinada.
Outreach: Beds24 messages API (works pre + post booking).
Parsing: regex + sanity bounds on guest count response.
Invoice: Beds24 invoice item posted (charge) — NO modify numAdults.
Retry: max 3 attempts, 2d between, marks no_response after.
UI: /admin/bookings drawer + list show expected + extra revenue.

Migration 0033 adds extra_guests_captures table.

Anti-patterns documented (no auto-charge MP, no Huerta, no post-arrival).

Refs: thread/107 §6
```

---

## §7 — Push + PR + Merge

After all 6 parts complete:

```bash
git push origin feat/small-items-wave

gh pr create \
  --title "feat(wave): small items bundle — F+C+A+B+E+D (6 parts)" \
  --body "Per thread/107 in rdm-discussion.

6 atomic commits, each addressing one feedback item from Alex:
- F: /admin/conv 3 bugs fix
- C: Channel native buttons with logos
- A: Inquiries auto-close cron
- B: Conversations auto-close cron
- E: Inbox WhatsApp-style mobile UX
- D: Extra guests >16 capture + Beds24 invoice

Migrations 0030, 0031, 0032, 0033.
4 new worker endpoints + 1 web API endpoint.
Total ~20-25h CC sprint.

Refs: thread/107"

gh pr merge <N> --squash --delete-branch
```

## §8 — Apply migrations + Deploy

```bash
wrangler d1 migrations apply rincon --remote
# Y/N prompts expected per autonomy config

wrangler deploy
# Y/N prompt expected
```

## §9 — Smoke tests after deploy

```bash
# /admin/conv works without crash
curl -I https://rincondelmar.club/admin/conv  # 200/302

# Channel buttons render
# (browser visual verification by Alex)

# Inquiries close endpoint
curl -X POST -H "Authorization: Bearer $ADMIN_REFRESH_SECRET" \
  https://rincondelmar.club/admin/inquiries-auto-close
# Should return {ok: true, closed_*: N}

# Conversations close endpoint
curl -X POST -H "Authorization: Bearer $ADMIN_REFRESH_SECRET" \
  https://rincondelmar.club/admin/conversations-auto-close
# Should return {ok: true, closed_per_rule: {...}}

# Inbox mobile
# (browser test by Alex on phone)

# Extra guests scan
curl -X POST -H "Authorization: Bearer $ADMIN_REFRESH_SECRET" \
  https://rincondelmar.club/admin/extra-guests-scan
# Should return {ok: true, eligible: N, pending_created: M}
```

============================================================
DEFAULTS
============================================================

- Commit format: Conventional Commits, atomic per part (6 commits min)
- Encoding: UTF-8 file contents, ASCII shell args
- Branch: feat/small-items-wave
- Squash merge with --delete-branch
- Migration sequence: 0030, 0031, 0032, 0033
- Cron consolidated: parts A+B+D in single daily 04:00 UTC run
- Deploy worker via wrangler deploy (ask tier)
- Migrations apply via wrangler d1 migrations apply (ask tier)

============================================================
OUT OF SCOPE (NO HACER)
============================================================

- ❌ Welcome auto-send bug (separate P2 task)
- ❌ Cron stale fix path (Alex decides after thread/106 Part C diagnosis)
- ❌ M1 Pricing (post-foundations)
- ❌ V7 lifecycle bot
- ❌ rdm-platform touches
- ❌ Refactor existing tested code
- ❌ Auto-charge MP for extra guests (manual collection at arrival)
- ❌ Modify Beds24 booking `numAdults` (viola memorias)
- ❌ Include Huerta in extra guests detection (cap 12 already real)
- ❌ Capture VIP repeat guests (Phase 2)
- ❌ Real-time updates (refresh-based MVP OK)
- ❌ Mobile push notifications (Phase 2)

============================================================
EXTERNAL STATE (informational only)
============================================================

- 14 stale inquiries in production (will close on first run Part A)
- 82 open conversations (50-60 expected to auto-close Part B)
- Latest migration: 0029 (next 0030+)
- Worker bot URL: https://bot.rincondelmar.club
- Web URL: https://rincondelmar.club
- D1 database id: d81622d7-32e2-40a3-9609-80813c0e8a96
- Beds24 propertyId: 31862
- Roomids: 78695 (RdM), 374482 (Morenas), 74316 (Combinada), 637063 (Huerta)
- Extra-person rates: 78695/374482/74316 = $300, 637063 = $200

============================================================
SI TE ATORAS
============================================================

- Logos oficiales download blocked: use Lucide ExternalLink with brand colors (#FF5A5F, #003580, #00A19A), document in commit for Alex to swap manually later
- Beds24 messages API auth issues: check getBeds24AccessToken, may need refresh
- ManyChat send fails: verify MANYCHAT_API_TOKEN secret
- Migration conflict (number already used): use next available, document
- Tests fail in unrelated code: investigate, may need fixture update
- Beds24 invoice POST schema issues: check Beds24 wiki at https://wiki.beds24.com
- Webhook handler integration breaks tests: revert touches there, integrate via separate cron instead
- Anything unexpected after 30 min: STOP, report

============================================================
REPORTAR AL FINAL (thread/108-cc-bot-small-items-wave-complete.md)
============================================================

Por cada part F-D:
1. Files changed (path + line count)
2. Commit SHA
3. Tests added (count + scenarios)
4. Acceptance criteria check (pass/fail per criterion)

Overall:
5. PR # + merge SHA + URL
6. Migrations applied (4 migrations)
7. Worker deploy result
8. Smoke test results (each endpoint)
9. D1 verification queries:
   - Inquiries closed count
   - Conversations closed count per rule
   - Extra guests captures created
10. Browser verification by Alex pending
11. Any blockers or partial implementations
12. Status for next priority signal

---

**WC standing by. CC executes after thread/106 ack. Single sprint, single PR, atomic commits.**

— WC, 2026-05-19
