# rdm-platform · STATE (draft)

> Conceptual repo. Architecture, vision, ADRs, foundations, module specs. **NO code.**
> Generado por CC vía DoIt thread/143 (2026-05-19). Actualizado por WC-Platform 2026-05-20.

---

## A. ESTADO ACTUAL

- **Estructura presente:**
  - `vision/` — `01-philosophy.md` (spirit + Alex mental model, ex thread/91), `02-wishlist.md` (5 módulos + 19 ideas, ex thread/89).
  - `decisions/` — `ADR-001-platform-shift.md` (Accepted 2026-05-17), **`ADR-002-foundations-seal.md` (Accepted 2026-05-20)** + `README.md` (índice).
  - `foundations/` — **`README.md` refactored as index** + `F1-events-bus.md` + `F2-observability.md` + `F3-staff-pwa.md`. **Specs sealed by ADR-002, pending CC implementation.**
  - `modules/` — 9 subfolders (`admin-tools`, `bot`, `content`, `data-pipeline`, `inventory`, `menu`, `pricing`, `staff-scheduling`, `tasks`). **Cada uno solo README.md placeholder.**
  - `coordination/` — `doit-template.md`, `roles-and-permissions.md`, `README.md` (vive aquí, NO en rdm-discussion).
  - `ideas/` — `README.md` (I1-I19 referenciados). **I20 Telegram contact discovery pendiente de crear (post-F2 pre-flight).**
  - **`reports/audit-2026-Q2/` NEW 2026-05-20** — `README.md` con spec de audit completo. Audit ejecuta Days 0-11 post-F2 pre-flight, paralelo a F2 ship.
- **Lo que falta** (per thread/89 wishlist + thread/91 vision):
  - ~~ADR-002~~ ✅ done 2026-05-20
  - ~~F1 spec final~~ ✅ done 2026-05-20 (12-16h CC effort, content-addressed event_uuid + state_diff)
  - ~~F2 spec final~~ ✅ done 2026-05-20 (6-9h CC effort, WAE + cron_heartbeats + 2-channel Telegram)
  - ~~F3 spec final~~ ✅ done 2026-05-20 (22-30h CC effort, email-only, phone path → F3.1)
  - F1, F2, F3 implementación — pending CC, gated by Alex F2 pre-flight (in progress 2026-05-20)
  - Per-module specs detallados (M1 Pricing tiene §1 en wishlist, los demás solo título). M1 spec next brain session post-F2.
  - Charter document (foundations/00-charter.md) — decoupled per ADR-002 §3, no longer blocking M1
  - Casa Chamán launch coordinator spec (mentioned thread/89 §0, no doc).
  - **Audit 2026-Q2 execution** — spec'd, parallel to F2 (Days 0-11). May produce ADR-003+ if findings warrant.
- **Estado foundations F1/F2/F3:** **Accepted via ADR-002.** Status moved from *conceptual* → *spec'd, pending implementation*.
- **Estado audit 2026-Q2:** **Spec'd 2026-05-20.** Pending Alex F2 pre-flight completion + F2 Day 0 start as Day 0 of audit timeline.

## B. RELACIÓN CON OTROS REPOS

- **`rdm-bot`** (code repo): platform define las decisiones arquitectónicas + module specs; rdm-bot las implementa. F1/F2/F3 cuando se shippen vivirán en rdm-bot (apps/packages), no aquí.
- **`rdm-discussion`** (comms layer): threads, specs operativos (`cc-instructions-*/`), ADRs operativas (decisions/ con 9 ADRs de implementación). Threads de origen para platform docs (89 → wishlist, 91 → philosophy) viven allá; aquí están las versiones canónicas migradas. **Foundations review cycle:** threads 145 (WC-Platform announce) → 146 (CC pre-flight) → 147 (WC-Impl review) → 148 (Alex go decision). **Audit cycle:** thread 149 (WC-Platform audit kickoff) → 151-153 (audits committed) → 154 (synthesis) → 155 (Alex decision).
- **Permisos** (per `coordination/roles-and-permissions.md`):
  - Alex: RW everything
  - WC-Platform: RW primary (brain mode, foundations + conceptual specs)
  - WC-Implementation: RW threads + operational specs en rdm-discussion
  - **CC: RO** + feedback/ subfolder cuando se le pida. CC NO escribe aquí sin invitación explícita. **Exception 2026-05-20: CC writes to `reports/audit-2026-Q2/` authorized for audit cycle only.**
- **Excepción DoIt thread/143:** STATE-drafts vive en rdm-discussion (CC RW allowed allá) para respetar boundary CC=RO en rdm-platform. Este patrón continúa.

## C. PENDING EVOLUTION (priorizado per ADR-002 + post-review)

### Done 2026-05-20
1. ✅ **ADR-002** foundations seal — F1/F2/F3 as M1 pre-req, Charter decoupled. Accepted.
2. ✅ **F1 events bus** spec final — 12-16h CC effort.
3. ✅ **F2 observability lite** — 6-9h CC effort.
4. ✅ **F3 staff PWA shell** — 22-30h CC effort (email-only).
5. ✅ **Audit 2026-Q2 spec** — `reports/audit-2026-Q2/README.md` published. 3-auditor parallel model, Days 0-11.

### Active blocking M1 (in dependency order)
6. **Alex F2 pre-flight checklist** (≤ 20 min CF dashboard, in progress 2026-05-20): R2 bucket `rdm-logs` ✅ + lifecycle rule ✅ + Logpush job (pending) + 2 Telegram channels + bot tokens + CF API token Analytics:Read. Posts confirmation in thread/148 follow-up.
7. **PR queue clear** (WC-Impl signals): PR #130 + PR #114 merge/close.
8. **CC ships F2** (6-9h, 3-4 days calendar). Day 0 blocked on Alex pre-flight (6) + PR queue (7). **Same Day 0 = audit Day 0.**
9. **Audit 2026-Q2 execution** (parallel to F2): WC-Platform + WC-Impl write Days 0-3, CC writes Days 5-8 post-F2 PR, synthesis Days 9-10, Alex decision Day 11.
10. **CC ships F1** (12-16h). Day 0 after F2 soaks 24h + audit synthesis informs F1 spec if needed.
11. **Alex F3 pre-flight** (≤ 15 min CF dashboard): CF Pages project `rdm-staff` + DNS + custom domain + BETTER_AUTH_SECRET mirror + VAPID keys + cookieDomain rotation on apps/web.
12. **CC ships F3** (22-30h, 5 days). Day 0 after F1 soaks + Alex F3 pre-flight.
13. **M1 Pricing Agent** spec deep — anti-orphan + last-minute discount + minStay matrix (5×5×4). WC-Platform brain session in parallel during F1/F3 dev. Impl starts day F3 merges. **Audit findings may shape M1 spec authoring.**

### Follow-up specs (triggered, not in foundations cycle)
14. **F1.1** Pre-stay migration to lifecycle bus — triggered when F1 soaks 1 week. 6-8h CC.
15. **F1.2** `/admin/lifecycle` UI panel — triggered post-F1. 3-5h CC.
16. **F2.1** Daily WhatsApp/Telegram summary — triggered when F2 live + Alex format confirmed. 3-4h CC.
17. **F3.1** ManyChat phone magic-link — triggered when first non-email empleado hire request lands. 5-7h CC.
18. **F3.2** `/admin/staff-onboarding` UI — triggered when hiring cadence > 1/month. 6-8h CC.
19. **ADR-003+** (potential) — authored AFTER audit synthesis if findings warrant. Scope TBD.

### Deferred / not yet specced
20. **M2 Menu** — referenciado pero sin spec detallado.
21. **M3 Inventory** — placeholder.
22. **M4 Staff scheduling** — depende F3.
23. **M5 Tasks module** — placeholder. Notification path depends F1 + F3.
24. **Casa Chamán launch coordinator** — Q3 2026 trigger, sin spec. Anti-pattern enforced across F1/F2/F3 (no roomId 679176 baked).
25. **I20 Telegram contact discovery** — new idea 2026-05-20 (see §F.2 decision). Spec authoring deferred to post-F2 pre-flight conclusion.
26. **19 ideas I1-I19** — referenciadas en `ideas/README.md` pero no expandidas.

## D. PERMISOS Y BOUNDARIES

- **Repo es brainstorm conceptual** (per README.md línea 4). No deploys, no apps/, no packages/, no tests.
- **Alex**: decisions, priorities, anti-patterns, final authority.
- **WC-Platform** (Claude.ai brain mode): RW primary, arquitectura + foundations + conceptual specs.
- **WC-Implementation** (misma sesión, modo distinto): RW threads + specs operativos en rdm-discussion.
- **CC** (Claude Code): RO default. Escribe sólo `feedback/` subfolder cuando Alex/WC lo pide explícito. No PRs autónomos a este repo desde DoIt mode. **Exception 2026-05-20**: CC writes to `reports/audit-2026-Q2/03-technical-audit-cc.md` authorized.
- **No commits con secrets, PII, tokens** (igual que los otros 2 repos).

## E. LAST UPDATED + UPDATE PROTOCOL

- Fecha generación inicial: 2026-05-19 por CC vía DoIt thread/143
- Última actualización: **2026-05-20** por WC-Platform (ADR-002 Accepted + F1/F2/F3 specs + Audit 2026-Q2 spec + §F.4 addition)
- Próxima refresh: cuando se complete audit synthesis (Day 11) o se mergee primer F-foundation a rdm-bot.
- **Update protocol:** WC-Platform actualiza este archivo cuando agrega ADR, foundation seal, audit cycle, o module spec deep. Alex actualiza §C priorización.
- Promote-to-root: Alex copia → `rdm-platform/STATE.md` post-PR aprobación. Si Alex prefiere mantener CC out-of-write para platform, este archivo puede vivir como referencia READ-ONLY desde rdm-discussion sin promote.

## F. EXTERNAL TOOLING DECISIONS (2026-05-20)

### F.1 Telegram as management override channel

**Decision** (Alex 2026-05-20): Telegram = management tier. If counterparts want to work with Alex, they use Telegram. WhatsApp stays for operational staff (housekeepers, gardeners, grocery buyers) and guests.

**Rationale**:
- Filtro natural de profesionalismo
- Separa Alex personal (WhatsApp familia/amigos) de Alex management (Telegram)
- Bots gratis sin Meta Business approval
- Native audit trail + multi-device serio
- Aligns with F2 observability (alerts via Telegram already in plan)

**Boundary**: 
- ✅ Telegram for: alerts (F2), management 1:1, vendors técnicos, contratistas digitales, Alex↔Karina ops, future M5 reminders to Alex/Karina
- ❌ NOT for: housekeepers, gardeners, grocery buyers, field staff (stay WhatsApp + F3 PWA)
- ❌ NOT for: guests (WhatsApp coexistence via ManyChat continues)

**Implementation**: ad-hoc. No spec needed for the decision itself. F2 alerts already wire Telegram. M5 may add Telegram as channel option in its spec.

### F.2 I20 Telegram contact discovery (idea, not spec yet)

**Triggered**: 2026-05-20 by Alex manual observation that many guests/leads have Telegram accounts.

**Hypothesis**: cross-reference Beds24 booking phones + ManyChat lead phones against Telegram via MTProto `contacts.importContacts`. Identify which contacts are already on Telegram, enable opt-in migration.

**Effort estimate**: 4-6h CC (Python script with telethon, D1 storage, dashboard for review).

**Technical constraints**:
- MTProto User API required (NOT Bot API — bots can't lookup phones for security)
- Rate limited ~250-500 contacts/day to avoid Telegram account suspension
- Requires Alex's personal Telegram session (api_id + api_hash from my.telegram.org)
- Privacy respect: users with "find me by phone" = "Nobody" won't appear (legitimate filter)

**Legal/ethical (MX LFPDPPP)**:
- ✅ Lookup of phones Alex already has in CRM/Beds24/Airbnb = OK (existing relationship)
- ❌ Sharing results with third parties = NO
- ⚠️ Cold spam to discovered contacts = risk; recommended pattern is silent contact-add + opt-in when contact reaches out next

**Volume estimate**: 1,200-1,600 contacts identified Telegram-positive (~25-40% rate across bookings + leads + vendors)

**Output schema** (proposed for D1 table `telegram_contacts_discovered`):
- phone (FK to beds24_bookings.mobile)
- telegram_user_id
- first_name
- username (nullable)
- found_at
- privacy_restricted (boolean)
- opt_in_status: not_attempted | reached_out | opted_in | opted_out

**Status**: Idea logged. Spec authoring deferred to post-F2 pre-flight conclusion. Not in foundations critical path.

**Next step**: WC-Platform creates `ideas/I20-telegram-contact-discovery.md` next time it has a slot. Implementation scheduled by Alex post-foundations.

### F.3 F2 pre-flight delegation pattern (2026-05-20)

**Context**: Alex faced 7-step pre-flight checklist for F2 (R2 + Logpush + Telegram + CF API token). Steps 1-2 done. Steps 3-7 mix of UI + CLI + cross-app coordination.

**Decision pattern adopted**:
- **Alex-only** (inherently): Telegram bot creation via BotFather, CF API personal token, anything in personal account settings
- **CC-can-do** (with prepared commands): `wrangler secret put`, Logpush via REST API curl, anything with Cloudflare API token scope

**Implication**: future foundation pre-flights split into "Alex-only ≤10 min" vs "CC-executable with token grant ≤10 min". Documented as practice.

**Concrete for F2**: Alex completes Telegram setup (paso 4) + CF API Token (paso 6) himself. CC executes Logpush job + 4 worker secrets when starting F2 Day 0. WC-Platform writes a thread/150 cc-handoff with exact commands when Alex provides the 5 secret values.

**Status**: 2026-05-20 Alex pre-flight in progress. Pasos 1-2 done. Resto pending.

### F.4 Audit 2026-Q2 — architecture + UX coherence review

**Triggered**: 2026-05-20 by Alex request: "tengo la preocupación si lo que hemos hecho es igual de bueno. La verdad fue hecho poco a poco, cuando yo aún no tenía experiencia — y ahora veo las fallas y que no cuadra."

**Decision**: Run a 3-auditor fresh-eyes review of `rdm-bot` current state, parallel to F2 implementation (Days 0-11). NOT a fix cycle — outputs are recommendations.

**Spec location**: `rdm-platform/reports/audit-2026-Q2/README.md`

**Auditors** (mirrors foundations review pattern):
- **WC-Platform**: architectural + conceptual audit (6h, `01-architectural-audit-wc-platform.md`)
- **WC-Implementation**: operational + UX audit (4h, `02-operational-audit-wc-impl.md`)
- **CC**: code + technical debt audit (4h, `03-technical-audit-cc.md`)
- **Alex**: synthesis review + ADR decision (2h)

**Three questions answered**:
1. Greenfield with current vision → arrive at this architecture?
2. ADR-001 anti-patterns actually absent in code?
3. Admin UI flows / mobile UX / dead buttons / functional gaps?

**Timeline**: Days 0-11 parallel to F2 ship (Day 0 = F2 Day 1). Audit Day 0 starts when Alex F2 pre-flight completes + CC begins F2 build.

**Output**: `04-synthesis-and-recommendations.md` (WC-Platform writes Days 9-10). Alex reads, decides ADR-003+ if warranted.

**Constraints**:
- Audit does NOT block F2, F1, F3, or M1
- No in-audit refactors; findings only
- No big-bang rewrites; prefer incremental migration
- Audit against `vision/01-philosophy.md`, NOT generic startup best practices
- Assume good faith on past PRs

**Threads tracking**:
- 149 (kickoff, WC-Platform) ← published 2026-05-20
- 151 (architectural audit committed)
- 152 (operational audit committed)
- 153 (technical audit committed)
- 154 (synthesis ready)
- 155 (Alex decision)

**Why now**: F1/F3 not yet started (audit findings can shape F1 spec adjustments before implementation). M1-M5 still conceptual (audit informs M1 authoring). Last quiet window before module-building phase. Wait 6 more months → too painful.

**Status**: 2026-05-20 spec published, awaiting Day 0 trigger (Alex F2 pre-flight completion).
