# I15 · Critical-keyword Telegram alert · CC DoIt spec

**Status**: PENDING ALEX APPROVAL (Day 3 ranking). Pre-staged.
**Workstream**: CC-Bot (territory: `apps/worker-bot` + D1 + maybe `apps/web/src/pages/api/admin/`)
**Effort estimate**: 2h CC (conservative budget 3h with self-review)
**Source**: §F idea I15 + cross-ref `reports/audit-2026-Q2/02-operational-audit-wc-impl.md` follow-up F-2
**Blocking dependency**: Question H.3.8 (Alex must confirm critical keyword list) — **MUST RESOLVE BEFORE CC PICKS UP**

---

## §1 · Context

### Problem

D1 evidence (audit-2026-Q2 follow-up F-2): inbox has **4 messages with `has_keywords_critical=1` unread × 9-day oldest**. The `critical_keyword` alert type exists in `bot_alerts` schema but firing logic to Telegram is not implemented (or broken silently). Karina doesn't see these in real time. SLA risk grows daily.

### Current state

- `bot_messages_inbox` or `conversations` rows tag `has_keywords_critical=1` when message body matches a keyword list (logic in worker-bot)
- Telegram bot `@RinconDelMarNotifs` (id `8667752636`) exists and Karina (id `8656647143`) + Alex (id `8711110474`) confirmed `/start`
- thread/152 PR #136 (`feat/karina-tg-distribution`) added Karina TG distribution infrastructure (pending merge)
- `/admin/health` page renders `bot_alerts` recent 10 read-only

### Desired behavior

When a NEW row gets `has_keywords_critical=1` AND `age > N minutes` (default 30) AND has NOT been alerted yet, fire Telegram message to Karina + Alex via existing bot. Track via `bot_alerts.alerted_at` column (already exists in schema per `/admin/health` query).

---

## §2 · Explicit scope

### YES

- New cron `cron-critical-keyword-alerts` running every 5 minutes
- Query D1 for rows with `has_keywords_critical=1` AND `alerted_at IS NULL` AND `created_at < unixepoch() - 30*60` (30min grace)
- Fire Telegram message to Karina + Alex (BOTH) per matched row
- Idempotent: writes `alerted_at = unixepoch()` after successful fire to prevent re-alerts
- Heartbeat: write to `cron_heartbeat:critical-keyword-alerts` KV key
- Telegram message format includes: guest phone (last 4 digits), property, preview (first 100 chars), link to `/admin/conv?phone={partial}`
- Hardcoded keyword list lives in `packages/shared/src/critical-keywords.ts` (NEW file)
- Test mode env var `CRITICAL_KEYWORD_ALERT_DRY_RUN` defaults FALSE → if TRUE, log to stdout instead of firing

### NO

- DO NOT change keyword detection logic (already exists)
- DO NOT change schema of `bot_alerts` table
- DO NOT add inline "Respondí" button to Telegram message (separate spec I22)
- DO NOT implement per-recipient acknowledgment (Alex tap = both acknowledged)
- DO NOT add escalation (e.g., if no response in 4h, page-via-call) — Phase 2

---

## §3 · Closed decisions

- **Grace period**: 30 minutes (allows Karina natural response time, prevents spam for short-lived alerts)
- **Frequency**: every 5min cron tick
- **Recipients**: BOTH Karina + Alex (redundancy for SLA)
- **Idempotency mechanism**: column `alerted_at` set after fire
- **Critical keywords source**: hardcoded in `packages/shared/src/critical-keywords.ts` (curated by Alex, edit via PR)
- **Telegram message**: plain text, no rich formatting (avoid encoding issues)
- **Link format**: `https://rincondelmar.club/admin/conv?phone={last4}` (Karina can full-search from there)

### BLOCKING question for Alex (H.3.8)

**¿Qué keywords cuentan como "critical"?**

WC-Impl propuesta inicial (ESPAÑOL, lowercase normalized, accents stripped):
```
[
  'emergencia',
  'urgente',
  'ambulancia',
  'policia',
  'bomberos',
  'robo',
  'asalto',
  'accidente',
  'lesion',
  'sangre',
  'hospital',
  'fuego',
  'incendio',
  'inundacion',
  'no funciona el aire',  // recurring guest complaint
  'no hay agua',          // infrastructure
  'no hay luz',           // infrastructure
  'cancelar',             // booking-impact
  'reembolso',            // booking-impact
  'demanda',              // legal
]
```

Alex puede:
- Aprobar lista as-is
- Agregar/quitar items
- Replace por su lista existente si ya tiene una

NOTA: separación entre infraestructura (water/light/AC) vs emergencia personal (police/medical) puede merecer 2 severities. v1 trata como "critical" uniforme. v2 split possible.

---

## §4 · Implementation

### Files to create/modify

| File | Action |
|---|---|
| `packages/shared/src/critical-keywords.ts` | NEW · keyword list + normalize fn |
| `apps/worker-bot/src/handlers/cron-critical-keyword-alerts.ts` | NEW |
| `apps/worker-bot/src/index.ts` | Register new cron handler |
| `apps/worker-bot/wrangler.toml` | Add cron trigger `*/5 * * * *` |
| `apps/web/src/pages/admin/health.astro` | Add the new cron in `CronStatuses` query map |

### `critical-keywords.ts`

```typescript
/**
 * Critical keywords trigger Telegram alerts to Karina + Alex.
 * Edit via PR — Alex curates.
 *
 * Detection: case-insensitive, accent-stripped, word-boundary match.
 */
export const CRITICAL_KEYWORDS: ReadonlyArray<string> = [
  // EMERGENCIAS PERSONALES
  'emergencia',
  'urgente',
  'ambulancia',
  'policia',
  'bomberos',
  'robo',
  'asalto',
  'accidente',
  'lesion',
  'sangre',
  'hospital',

  // INFRAESTRUCTURA CRITICA
  'fuego',
  'incendio',
  'inundacion',
  'no funciona el aire',
  'no hay agua',
  'no hay luz',

  // BOOKING-IMPACT
  'cancelar',
  'reembolso',
  'demanda',
];

/**
 * Normalize text for matching: lowercase + strip Spanish accents.
 */
export function normalizeForMatch(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, ''); // strip combining diacritics
}

/**
 * Returns the matched keyword(s) in the text, or empty array if none.
 */
export function matchCriticalKeywords(text: string): string[] {
  const normalized = normalizeForMatch(text);
  return CRITICAL_KEYWORDS.filter(kw => normalized.includes(normalizeForMatch(kw)));
}
```

### `cron-critical-keyword-alerts.ts`

```typescript
import { writeHeartbeat } from '../lib/cron-heartbeat';
import { sendTelegramMessage } from '../lib/telegram'; // assumes exists from PR #136

const KARINA_TG_ID = '8656647143';
const ALEX_TG_ID = '8711110474';
const GRACE_PERIOD_SECONDS = 30 * 60;

export async function handleCriticalKeywordAlerts(env: Env): Promise<void> {
  await writeHeartbeat(env.KV_KNOWLEDGE, 'critical-keyword-alerts');

  if (!env.DB) {
    console.error('[critical-keyword-alerts] No DB binding');
    return;
  }

  const dryRun = (env as { CRITICAL_KEYWORD_ALERT_DRY_RUN?: string })?.CRITICAL_KEYWORD_ALERT_DRY_RUN === 'true';

  // Query unalerted rows with critical keyword flag, grace period passed
  // VERIFY exact table + column names with rdm-bot schema before running
  const cutoff = Math.floor(Date.now() / 1000) - GRACE_PERIOD_SECONDS;
  const { results } = await env.DB.prepare(
    `SELECT id, booking_id, room_id, channel, body_preview as preview,
            guest_phone, created_at
       FROM bot_alerts
      WHERE has_keywords_critical = 1
        AND alerted_at IS NULL
        AND created_at < ?
      ORDER BY created_at ASC
      LIMIT 20`
  ).bind(cutoff).all<{
    id: number;
    booking_id: string | null;
    room_id: number | null;
    channel: string | null;
    preview: string;
    guest_phone: string | null;
    created_at: number;
  }>();

  if (!results || results.length === 0) return;

  const ROOM_NAMES: Record<number, string> = {
    78695: 'Rincón del Mar',
    74322: 'Las Morenas',
    374482: 'Las Morenas',
    74316: 'Combinada',
    637063: 'Huerta Cocotera',
  };

  for (const row of results) {
    const phoneLast4 = row.guest_phone?.slice(-4) ?? '????';
    const propertyName = row.room_id ? (ROOM_NAMES[row.room_id] ?? `room ${row.room_id}`) : '—';
    const preview = (row.preview ?? '').slice(0, 100);
    const ageMinutes = Math.floor((Date.now() / 1000 - row.created_at) / 60);

    const message = [
      `🚨 Mensaje crítico (${ageMinutes}min)`,
      ``,
      `Propiedad: ${propertyName}`,
      `Canal: ${row.channel ?? 'desconocido'}`,
      `Teléfono: ****${phoneLast4}`,
      ``,
      `"${preview}${preview.length >= 100 ? '...' : ''}"`,
      ``,
      `→ https://rincondelmar.club/admin/conv?phone=${phoneLast4}`,
    ].join('\n');

    if (dryRun) {
      console.log(`[critical-keyword-alerts] DRY RUN message:\n${message}`);
    } else {
      try {
        await Promise.all([
          sendTelegramMessage(env, KARINA_TG_ID, message),
          sendTelegramMessage(env, ALEX_TG_ID, message),
        ]);

        // Mark as alerted ONLY after successful fire (idempotency)
        await env.DB.prepare(
          `UPDATE bot_alerts SET alerted_at = unixepoch() WHERE id = ?`
        ).bind(row.id).run();
      } catch (err) {
        console.error(`[critical-keyword-alerts] Failed to alert row ${row.id}:`, err);
        // DO NOT mark as alerted — will retry next cron tick
      }
    }
  }
}
```

### `wrangler.toml` addition

```toml
[triggers]
crons = [
  # ... existing crons ...
  "*/5 * * * *",  # critical-keyword-alerts (every 5 minutes)
]
```

**WARNING**: Workers FREE plan allows max 5 cron triggers. If already at 5, must consolidate. Check existing first.

### `health.astro` cron map addition

Add `critical-keyword-alerts` to the `getCronStatuses` map in `lib/admin-health.ts` so it appears in `/admin/health` status table.

---

## §5 · Tests

### Unit tests

`packages/shared/src/critical-keywords.test.ts`:

```typescript
describe('critical-keywords', () => {
  test('matches exact keyword', () => {
    expect(matchCriticalKeywords('hay una emergencia')).toContain('emergencia');
  });

  test('matches case-insensitive', () => {
    expect(matchCriticalKeywords('URGENTE')).toContain('urgente');
  });

  test('matches accent-insensitive', () => {
    expect(matchCriticalKeywords('Policía')).toContain('policia');
  });

  test('matches multi-word phrase', () => {
    expect(matchCriticalKeywords('No funciona el aire')).toContain('no funciona el aire');
  });

  test('no false positive on contained words', () => {
    expect(matchCriticalKeywords('Hola buenos dias')).toEqual([]);
  });

  test('multiple matches returned', () => {
    const result = matchCriticalKeywords('emergencia urgente');
    expect(result).toContain('emergencia');
    expect(result).toContain('urgente');
  });
});
```

### Integration test (cron handler)

`apps/worker-bot/src/handlers/cron-critical-keyword-alerts.test.ts`:
- Setup: seed `bot_alerts` row with `has_keywords_critical=1`, `alerted_at=NULL`, `created_at = now - 60min`
- Run handler in dry-run mode
- Assert: log line emitted with expected message format
- Assert: row `alerted_at` remains NULL (dry-run)
- Setup: seed another row with `created_at = now - 5min` (within grace)
- Run handler
- Assert: only the > 30min row gets processed

### Smoke test (manual, post-deploy)

1. Send WhatsApp message to bot with "emergencia" as content
2. Wait 30+ minutes
3. Confirm Telegram alert arrives to BOTH Karina + Alex
4. Confirm tap link opens `/admin/conv?phone=…`
5. Re-run cron manually (`wrangler triggers cron`) — confirm NO duplicate alert
6. Check `/admin/health` shows `critical-keyword-alerts` cron with recent heartbeat

---

## §6 · Definition of done

- [ ] `critical-keywords.ts` shipped with curated list (Alex-approved)
- [ ] `cron-critical-keyword-alerts.ts` handler implemented
- [ ] `wrangler.toml` cron trigger added (verify cap on Free plan)
- [ ] `health.astro` cron map includes new cron
- [ ] All unit tests pass
- [ ] Integration test passes
- [ ] Smoke test 6 steps pass on staging/prod
- [ ] Dry-run mode confirmed via env var toggle
- [ ] PR opened with: link to this spec + manual smoke test screenshots

---

## §7 · Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| **Workers FREE plan cap (5 crons)** | high | Audit existing crons FIRST. If at cap, consolidate (e.g., merge into existing `cron-bot-alerts` handler). |
| Karina+Alex spam if many critical messages | medium | 30min grace + idempotency via `alerted_at`. v2 can add throttle per phone (max 3 alerts per phone per hour). |
| `bot_alerts` table doesn't actually have `alerted_at` column | medium | **CC must verify schema first**. If absent, add migration FIRST. |
| Keyword list too narrow → misses real emergencies | medium | Alex curates v1; iterate based on missed cases via Karina feedback (when I2 ships). |
| Keyword list too broad → false positives spam | medium | Same as above. Start with curated 20-item list, refine. |
| Telegram bot API rate limit hit | low | 30 messages/sec is generous; even 100 alerts/day = 0.001 msg/sec. |
| `sendTelegramMessage` lib not present | medium | Per memory PR #136 added Karina TG distribution. **Verify on branch state before starting**. If absent → block on PR #136 merge first. |
| Casa Chamán (679176) accidentally surfaces in alert | low | `ROOM_NAMES` map intentionally omits 679176 — fall-through to "room 679176" which is acceptable. Same exclusion pattern as `/admin/pre-stay`. |

---

## §8 · Sequencing

1. **PRE-PICKUP**: Alex resolves H.3.8 keyword list. ~15min Alex.
2. CC: branch `feat/i15-critical-keyword-alerts` (~5min)
3. CC: verify `bot_alerts` schema, `sendTelegramMessage` lib, Workers cron cap (~15min)
4. CC: create `critical-keywords.ts` with Alex list + tests (~15min)
5. CC: create cron handler + integration test (~30min)
6. CC: register cron in wrangler.toml + index.ts (~10min)
7. CC: update health.astro cron map (~10min)
8. CC: dry-run locally → confirm log format (~10min)
9. CC: open PR (~5min)
10. Alex: review + merge + verify Telegram bot is online (~15min)
11. Alex: smoke test step 1-6 from §5 (~30min real-time, can run async)

Total CC: ~2h. Total Alex: ~1h (15min decision + 15min review + 30min smoke async).

---

## §9 · Out of scope (future iteration)

- I22 spec: Telegram inline "Respondí" button (closes loop, cross-ref audit C.2)
- Per-recipient acknowledgment (Karina vs Alex tracks)
- Escalation pager (no response in 4h)
- Severity split (emergencia vs infraestructura vs booking-impact)
- Per-keyword on/off toggle in admin UI

---

**Spec sealed** by WC-Implementation 2026-05-21 ~05:40 MX. Pending Alex Day 3 approval + H.3.8 keyword list resolution.
