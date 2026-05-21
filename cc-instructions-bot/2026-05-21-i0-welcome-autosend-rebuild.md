# I0 · Welcome auto-send rebuild · CC DoIt spec (v2 post-synthesis)

**Status**: 🔴 P0 · path-forward selected (d) → (a) post-synthesis · ready para CC pickup
**Workstream**: CC-Bot (`apps/worker-bot` + D1 + `apps/web/src/pages/admin/pre-stay.astro`)
**Effort estimate**: 6-10h CC (path d investigación 2h + path a execution 4-8h)
**Source**: synthesis §C JF.1 + §10 of `reports/admin-audit-2026-Q2-v2/` + thread/157 P0 alert + audit-2026-Q2 follow-up F-1+F-6
**Discovery**: D1 evidence + cross-audit compound finding
**Updated**: 2026-05-21 ~08:00 UTC post-synthesis (was v1 with paths a/b/c only)

---

## §0 · CHANGELOG vs v1

| Change | Razón |
|---|---|
| ADD **path (d) NEW prerequisite**: investigate messenger_outbound bridge antes de I0 (a) | Synthesis §C JF.1: F-1 ManyChat 92% fail × §10 P0 × F-6 catch-up = compound. Sin (d), welcomes generados quedan en queue rebotando. |
| UPDATE voto WC: (a) → **(d) → (a)** | Post-synthesis recommendation |
| ADD §4.0 messenger_outbound investigation phase | Prerequisite tech work antes de welcome rebuild |
| UPDATE §8 sequencing: (d) frontload | Sequential dependency |
| NOTE: Sara/Claudia/Erik manual outreach ✅ done by Alex 2026-05-21 | Eliminates immediate-day urgency, sigue urgent para Alan (5/25) + Lucero (5/25) + Yosselin (5/28) + Marycarmen (5/29) + Leticia (6/1) + Araceli (6/1) |
| UPDATE risks: messenger_outbound 92% fail downgraded de "out of scope" a "prerequisite IN scope" | Synthesis recommendation |

---

## §1 · Context

### Problem (urgency real-time)

Sara Ramos llegó 2026-05-22 atendida manualmente ✅. Quedan 6 bookings sin contacto auto en próximos 14 días:

| Arrival | Property | Huésped | Phone |
|---|---|---|---|
| 2026-05-25 | RdM | Alan Granados (direct) | +52 5582528741 |
| 2026-05-25 | Las Morenas | Lucero Valadez | +1 7144126946 |
| 2026-05-28 | Las Morenas | Yosselin Sánchez Osorio | +52 5574468496 |
| 2026-05-29 | RdM | Marycarmen Cornejo Ortega | +52 15514935302 |
| 2026-06-01 | Las Morenas | Leticia Ramirez Lopez | +1 7792795326 |
| 2026-06-01 | RdM | Araceli Garcia | +1 2076046453 |

Sin I0 rebuild → más manual outreach acumulado para Alex/Karina.

### Compound issue (synthesis §C JF.1)

3 issues compound:
1. `pending_welcomes` table tiene 10 rows TODOS `status='rejected'` desde 2026-05-14 manual cleanup
2. Bookings nuevos NO entran a `pending_welcomes` (cron/flow broken silently)
3. `messenger_outbound` cumulative 1039 failed vs 88 sent = **92% failure rate**, top error "Subscriber does not exist" (ManyChat tracking broken)

I0 v1 fix solo (1) y (2). Pero sin reparar (3), welcomes generados quedan en outbound queue rebotando. **Path (d) ataca (3) primero como prerequisite**.

### D1 evidence base

```sql
-- Bookings sin welcome record (next 14d):
SELECT bb.beds24_booking_id, bb.arrival, g.name, pw.status
FROM beds24_bookings bb
LEFT JOIN guests g ON g.id = bb.guest_id
LEFT JOIN pending_welcomes pw ON pw.beds24_booking_id = bb.beds24_booking_id
WHERE bb.arrival >= date('now','+1 days') AND bb.arrival <= date('now','+14 days')
  AND bb.status NOT IN ('cancelled','archived')
  AND bb.room_id != 679176;
-- → 6 rows actualmente (Sara/Claudia/Erik atendidos manualmente)

-- messenger_outbound failure rate 7d:
SELECT failure_reason, COUNT(*) FROM messenger_outbound
WHERE delivery_status = 'failed' AND sent_at > datetime('now','-7 days')
GROUP BY failure_reason ORDER BY COUNT(*) DESC LIMIT 5;
-- → 992× "Subscriber does not exist", 37× rate limit, ...
```

---

## §2 · Explicit scope

### Path-forward decision (post-synthesis)

| Path | Effort | Status |
|---|---|---|
| ~~(a) Reactivate flow con template ACTUAL~~ | 4h | superseded — necesita (d) first |
| ~~(b) Manual backfill 10 SQL~~ | 1h | rejected — escala poorly |
| ~~(c) Accept gap hasta template nuevo~~ | 0h | rejected — 6 bookings sin contacto unacceptable |
| **(d) → (a) Investigate messenger_outbound + reactivate flow** | 6-10h | **RECOMMENDED per synthesis §C** |

**Voto WC**: (d) → (a). Sin fix de bridge no tiene sentido reactivar welcomes (van a quedar en queue rebotando).

### YES (path d → a)

**Phase 1 · Investigation messenger_outbound (~2h)**:
1. Diagnose root cause "Subscriber does not exist" en 992 cases
   - Hipótesis A: ManyChat subscriber IDs cambiaron y D1 está stale
   - Hipótesis B: Phone normalization mismatch entre Beds24 y ManyChat lookup
   - Hipótesis C: ManyChat WA template policy change (Meta) requires reauth
2. Test fix con 3-5 sample sends
3. Document findings + decision: fix in-place vs migrate path (WhatsApp Business Cloud direct - synthesis §H Q.7)

**Phase 2 · Welcome flow reactivation (~4-8h, contingent on Phase 1 success)**:
4. Investigate cron broken (¿por qué nuevos bookings no entran a pending_welcomes?)
5. Fix root cause (template R2 key missing, polling regression, cron disabled, etc)
6. Restore generation con current R2 template
7. Run catch-up para 6 backlogged bookings con `status='approval_pending'`
8. Karina aprueba via existing UI flow

**Phase 3 · Common visibility (~3h)**:
9. `/admin/pre-stay` "Sin record" section ABOVE existing pending_welcomes table
10. Backend endpoint `POST /api/admin/pre-stay/create-pending-welcome`
11. Telegram alert cada 6h: bookings <72h sin welcome record

### NO (path d → a)

- DO NOT modify template content (separate spec — Karina training v2 thread/151)
- DO NOT mass-deploy welcomes sin Karina approval (preserve `approval_pending` gating)
- DO NOT delete 10 `rejected` rows (history preservation)
- DO NOT switch a WhatsApp Business Cloud direct durante Phase 1 (separate ADR-006 candidate per synthesis §C consequences)

---

## §3 · Closed decisions

- **Telegram alert threshold**: 72h before arrival
- **/admin/pre-stay "Sin record" section**: above existing pending_welcomes table
- **Cron schedule**: keep existing
- **Approval flow**: preserve `approval_pending` → Karina aprueba
- **R2 template version**: current (last good before reject batch)
- **Investigation time-box**: 2h max. Si root cause no encontrado → escalate Alex decisión (continue investigation, switch path, o defer)

---

## §4 · Implementation

### §4.0 · Phase 1 · Messenger_outbound investigation (~2h)

NEW prerequisite phase. Sin esto, Phase 2 welcome rebuild es wasted effort.

#### §4.0.1 · Diagnose 992 "Subscriber does not exist" failures

```bash
# Sample 5 failures recientes para inspect
wrangler d1 query rincon --command "
SELECT id, conversation_source, conversation_ref, message_text, routed_to, failure_reason, sent_at
FROM messenger_outbound
WHERE delivery_status='failed' AND failure_reason LIKE '%Subscriber does not exist%'
ORDER BY sent_at DESC LIMIT 5;"

# Cross-reference con guests + conversations
# Verificar: ¿conversation_ref es subscriber_id o phone?
# Verificar: ¿guest's phone normalizado match con conversations.subscriber_id?
```

Decide root cause:
- Si `conversation_ref` es phone pero ManyChat espera subscriber_id → mapping broken
- Si subscriber_ids stale en D1 vs ManyChat actual → resync needed
- Si Meta WA policy change → migration required

#### §4.0.2 · Try fix in-place (60min budget)

Test fix con 3 sample sends:
1. Pick 3 conversations con bookings activos
2. Trigger manual `messenger_outbound` send vía wrangler
3. Observe delivery_status

Si 3/3 succeed → fix works, document + ship.
Si 0-2/3 succeed → escalate Alex decisión (continue vs migrate path).

#### §4.0.3 · Decision gate

- 🟢 Fix found + tested → proceed Phase 2
- 🟡 Partial fix (some categories work, others don't) → ship partial + document gap + proceed Phase 2 con caveats
- 🔴 No fix found → STOP. Open issue, report to Alex. NO proceed Phase 2 — sin bridge welcomes van a queue rebotando.

### §4.1 · Phase 2 · Welcome flow reactivation (~4-8h)

Solo si Phase 1 decision gate 🟢/🟡.

```bash
# 1. ¿Qué cron debería generar pending_welcomes rows?
grep -ri "pending_welcomes" apps/worker-bot/src/
grep -ri "INSERT INTO pending_welcomes" apps/worker-bot/

# 2. Último insert
wrangler d1 query rincon --command \
  "SELECT MAX(created_at), datetime(MAX(created_at),'unixepoch') FROM pending_welcomes"

# 3. Cron heartbeats
wrangler d1 query rincon --command \
  "SELECT DISTINCT cron_name, MAX(heartbeat_at)
   FROM cron_heartbeats
   WHERE cron_name LIKE '%welcome%' OR cron_name LIKE '%pre-stay%'
   GROUP BY cron_name;"

# 4. Bot config check
cat apps/worker-bot/wrangler.toml | grep -A3 "triggers\|cron"
```

Fix root cause encontrado. Run catch-up para 6 backlogged bookings con current template.

Smoke test: nuevo booking webhook → row aparece en pending_welcomes en <5min.

### §4.2 · Phase 3 · `/admin/pre-stay` visibility (~2h)

File: `apps/web/src/pages/admin/pre-stay.astro`

Add new "Sin record" section ABOVE existing pending_welcomes table:

```typescript
// New query (server-side)
const bookingsSinRecord = await env.DB.prepare(
  `SELECT bb.beds24_booking_id, bb.room_id, bb.channel, bb.arrival, bb.departure,
          bb.num_adults, bb.num_pets,
          g.name AS guest_name, g.phone_e164 AS guest_phone
     FROM beds24_bookings bb
     LEFT JOIN guests g ON g.id = bb.guest_id
     LEFT JOIN pending_welcomes pw ON pw.beds24_booking_id = bb.beds24_booking_id
    WHERE bb.arrival >= date('now')
      AND bb.arrival <= date('now', '+60 days')
      AND bb.status NOT IN ('cancelled','archived')
      AND bb.room_id != 679176
      AND pw.beds24_booking_id IS NULL
    ORDER BY bb.arrival ASC`
).all();
```

UI:

```astro
{bookingsSinRecord.results.length > 0 && (
  <section class="sin-record-alert">
    <h2>⚠️ Bookings sin welcome record ({bookingsSinRecord.results.length})</h2>
    <p>
      Estos bookings NO tienen entry en pending_welcomes. Sin atención manual
      o reactivación del flow, no recibirán welcome automatizado.
    </p>
    <table>
      <thead><tr>
        <th>Arrival</th><th>Property</th><th>Huésped</th><th>Phone</th><th>Acciones</th>
      </tr></thead>
      <tbody>
        {bookingsSinRecord.results.map(b => (
          <tr class={daysUntil(b.arrival) <= 3 ? 'urgent' : ''}>
            <td>{b.arrival} ({daysUntil(b.arrival)}d)</td>
            <td>{PROPERTY_NAMES[b.room_id]}</td>
            <td>{b.guest_name ?? '—'}</td>
            <td>{b.guest_phone ?? '—'}</td>
            <td>
              <button data-booking={b.beds24_booking_id} class="btn-create-pw">
                Crear pending welcome
              </button>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  </section>
)}
```

Backend endpoint `POST /api/admin/pre-stay/create-pending-welcome` toma `beds24_booking_id` + crea row con `status='approval_pending'`.

### §4.3 · Phase 3 · Telegram alert (~1h)

New cron (or reuse existing) cada 6h:

```sql
SELECT COUNT(*) FROM beds24_bookings bb
LEFT JOIN pending_welcomes pw ON pw.beds24_booking_id = bb.beds24_booking_id
WHERE bb.arrival >= datetime('now')
  AND bb.arrival <= datetime('now', '+72 hours')
  AND bb.status NOT IN ('cancelled','archived')
  AND bb.room_id != 679176
  AND (pw.beds24_booking_id IS NULL OR pw.status != 'sent');
```

Si count > 0: Telegram alert a Karina + Alex con lista phone numbers + arrivals.

---

## §5 · Tests

### Unit tests

- `messenger_outbound.test.ts`: mock send con 3 fixture failures + 3 success cases
- `pending_welcomes.test.ts`: insert row valido → status='approval_pending'
- `admin/pre-stay.test.ts`: query bookingsSinRecord retorna rows con LEFT JOIN NULL

### Smoke test (manual)

1. Phase 1: verify 3 sample messenger_outbound sends succeed post-fix
2. Phase 2: verify new booking webhook → row aparece en pending_welcomes <5min
3. Phase 3: verify `/admin/pre-stay` muestra "Sin record" section con 6 bookings actuales
4. Phase 3: Telegram alert dispara con count > 0
5. Mobile 320px: layout no rompe

---

## §6 · Definition of done

- [ ] Phase 1 investigation findings documented en PR description
- [ ] Phase 1 decision gate documented (🟢/🟡/🔴)
- [ ] (si 🟢/🟡) Phase 2 cron reactivated + heartbeat actualizando
- [ ] (si 🟢/🟡) 6 backlogged bookings con `status='approval_pending'` o `sent`
- [ ] (si 🟢) Karina recibió 6 welcomes para aprobar via UI
- [ ] Phase 3 `/admin/pre-stay` muestra "Sin record" section visible
- [ ] Telegram alert fires correctly with count > 0
- [ ] PR opened linking thread/157 + §10 + ADR-004
- [ ] Smoke test 5 steps pass locally
- [ ] No regressions en /admin/pre-stay existing functionality

---

## §7 · Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Phase 1 no encuentra fix in-place — ManyChat fundamentalmente broken | high (per Meta policy changes) | Phase 1 decision gate 🔴 → escalate Alex. ADR-006 candidate: WhatsApp Business Cloud direct migration. NO proceed Phase 2 hasta resolved. |
| Template R2 key missing → Phase 2 (a) sends mensaje incorrect | medium | Verify template key exists ANTES de catch-up. Use template original que funcionó pre-reject batch. |
| Karina overwhelmed con 6 aprovals simultáneos | medium | Sequence backfill por arrival proximity (Alan 5/25 primero, después Lucero etc) |
| Cron generation root cause harder than expected | medium | Time-box investigation Phase 2 a 60min. Si no resuelve, switch to manual SQL backfill (path b leftover). |
| Telegram alert noisy | low | Threshold count > 1 antes de fire alert (config). |
| messenger_outbound fix partial (some categories work, others don't) | medium | Phase 1 gate 🟡 → ship partial + document gap + proceed Phase 2 con caveats |

---

## §8 · Sequencing (path d → a)

```
1. CC: branch feat/i0-welcome-autosend-rebuild        ~5min
2. CC: Phase 1 messenger_outbound investigation        ~2h
   ├─ §4.0.1 diagnose                                  60min
   ├─ §4.0.2 try fix + 3 samples                       60min
   └─ §4.0.3 decision gate
3. CC: Phase 2 (si gate 🟢/🟡) welcome flow            ~3-4h
   ├─ §4.1 investigate cron + fix                      90min
   ├─ §4.1 catch-up 6 backlogged                       30min
   └─ §4.1 smoke test cron firing                      30min
4. CC: Phase 3 visibility                              ~3h
   ├─ §4.2 /admin/pre-stay "Sin record"                2h
   └─ §4.3 Telegram alert wiring                       1h
5. CC: tests + tsc + lint                              ~30min
6. CC: open PR + commit message detailed               ~10min
7. Alex: review + merge + deploy                       ~30min
8. Alex/Karina: verify catch-up sends                  ~15min

Total CC: ~9h (Phase 1 + Phase 2 + Phase 3)
Total Alex: ~45min

Si Phase 1 gate 🔴 → STOP after step 2. CC opens issue. Effort halted ~2h.
```

---

## §9 · Out of scope (still)

- Rebuild template content (separate spec — Karina training v2 thread/151)
- Auto-approval flow (preserve current `approval_pending` Karina gate)
- Multi-language welcome variants
- Per-property template customization beyond current state
- WhatsApp Business Cloud direct migration (if needed → ADR-006 candidate, separate workstream)

---

## §10 · Coordination con waves post-Day 3

Si I0 ships ✅ post-vote → Wave 0 complete.

Wave 1 puede arrancar inmediato después (no depende de I0):
- I21 kill nav placeholders (1h)
- F.7+F.5+F.2 tech debt sweep (~55min cluster)
- I27 pending welcomes badge (1h, sinergia con I0 visibility)
- I26 today/tomorrow filter bookings (1.5h)
- I13+I14 status badge + reset preview /admin/conv (4h)
- I28 bot-metrics karina summary card (2h)

Wave 0 + Wave 1 paralelo ≈ ~22h CC = ~3-4 días CC.

---

**Spec sealed v2** por WC-Implementation 2026-05-21 ~08:05 UTC post-synthesis. Pending Alex final vote SÍ (path d→a) → CC pickup inmediato. ADR-004 reference: G6 prevents AskClaude future de tocar este flow (read-only tools whitelist).
