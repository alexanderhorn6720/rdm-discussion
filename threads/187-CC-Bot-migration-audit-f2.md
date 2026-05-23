---
thread: 187
author: CC-Bot
date: 2026-05-23
topic: migration-audit-f2
mode: brain
status: closed
related: [175, 184]
---

# Thread/187 — Migration audit informacional + F2 slot recommendation

**Worktree**: A-tactical (thread/184 A2)
**Scope**: Read-only audit of `migrations/` in rdm-bot. NO schema modifications.

---

## §1 — Migration inventory (rdm-bot `migrations/`)

Snapshot: 2026-05-23. Total: **46 migrations**. Sequence: contiguous 0001–0046, **cero gaps**.

| Range | Migrations | Notes |
|---|---|---|
| 0001–0010 | users, magic_links, waitlist, bookings, quote_requests, linktree_clicks, sessions, tour_views, conversations, handoff_data | Core bootstrap |
| 0011–0020 | beds24_events, reviews, bot_messages_inbox, guests_master, leads, bookings(v2), guest_events, guests_fts, pending_welcomes, admin_import_logs | Guest/booking layer |
| 0021–0030 | bot_link_clicks, human_handoff_log, bot_config, data_v2_seed_marker, greeter_turns, airbnb_confirmation_code, greeter_turns_v6, handoff_subscriber_name, conversations_resolved_at, inquiries_closed | Bot operational |
| 0031–0040 | conversations_closed_reason, messenger_outbound, extra_guests_captures, guests_name_locked, pre_stay_columns, pre_arrival_t14, guests_manychat_id, in_stay_post_stay, audit_log, rules_link_clicks | Stay lifecycle + audit |
| 0041–0046 | bot_short_links, feedback_system, booking_captures, outreach_templates, mp_payments, cost_telemetry | Platform + monitoring |

### Detail — últimas 5 migraciones

| # | Filename | Purpose | Thread |
|---|---|---|---|
| 0042 | feedback_system | Admin issues cockpit (feedback_items, github_cache, cc_sessions) | thread/161 |
| 0043 | booking_captures | Booking capture events | — |
| 0044 | outreach_templates | Outreach template storage | — |
| 0045 | mp_payments | MercadoPago payments | — |
| 0046 | cost_telemetry | Daily cost telemetry (ccusage cron + API ingestion) | thread/175 T2 |

---

## §2 — F2 observability migration analysis

### Estado actual F2

- **Status**: ADR-002 "Accepted" (2026-05-20), pero implementación NO iniciada.
- **Blocker**: thread/148 vote Alex pendiente (7 items, incluyendo cron host decision).
- **F2 NO ships** hasta que Alex vote + operativo estabilice (per thread/175 Q4 constraint).

### Conflicto histórico (ya resuelto)

El META audit (thread/177 §3 finding #2) documentó que F2 spec originalmente
reclamó slot 0042, pero 0042 fue consumido por `feedback_system` (renombrado
de 0040 en thread/162 con aprobación Alex). Ese conflicto ya está en el registro
histórico; NO hay acción requerida ahora.

### Slot libre recomendado para F2

> **Recomendación: slot `0047`**

Razón: 0001–0046 están contiguos y occupados. 0047 es el siguiente libre,
sin reservas activas en ningún branch (`git branch -r | xargs grep 0047` → vacío).

### Tablas que F2 necesitará (per ADR-002 scope)

F2 observability ("metrics + alertas") probablemente requiere:
- `cron_heartbeats` — liveness de cron jobs
- `metrics_snapshots` — snapshots periódicos de KPIs
- `alert_rules` — reglas de alerta configurables

Estas 3 tablas → 1 migration (0047). Si el spec de F2 crece, puede necesitar 0048 también.
Reservar 0047–0048 es conservador pero reasonable.

---

## §3 — Conflict check: thread/175 T2 (0046)

| Chequeado | Resultado |
|---|---|
| 0046_cost_telemetry.sql exists en main | ✅ Merged (PR #163) |
| 0046 referenciado en wrangler.toml / migrations apply | N/A — migrations apply por orden, no por nombre en config |
| Conflict con F2 slot 0047 | ❌ None — 0047 libre |
| Collision con otro branch activo | ❌ None detectado |

---

## §4 — Recommendation

```
Next available migration slot: 0047
Safe to reserve for: F2 observability (cron_heartbeats + metrics + alerts)
Backup slot: 0048 (if F2 needs 2 migrations)
Action required NOW: none — F2 ships post Alex vote thread/148
```

Cuando F2 esté ready para ship, usar:
```bash
bash scripts/new-migration.sh observability-f2
```
El script garantizará número atómico (no hardcodear 0047 manualmente).

---

**END OF REPORT — Thread/187 closed (informational only)**
