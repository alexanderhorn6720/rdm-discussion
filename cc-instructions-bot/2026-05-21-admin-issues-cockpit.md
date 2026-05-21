# Spec: /admin/issues — GitHub Operations Cockpit

**Type**: brain deep — full spec
**Author**: WC (Web Claude)
**Date**: 2026-05-21
**Target**: CC-Bot (single batch execution, one-run)
**Estimate**: 31-45h CC
**Thread ref**: `threads/161-wc-cc-admin-issues-cockpit-doit.md`
**Branch**: `feat/admin-issues-cockpit`
**Spec path target**: `rdm-discussion/cc-instructions-bot/2026-05-21-admin-issues-cockpit.md`

---

## 1. Context

### Why

Alex está overwhelmed con approval cognitive load: bashes, PRs, deploys, issues, feedback de Karina, todo fragmentado entre 3 repos (`rdm-bot`, `rdm-platform`, `rdm-discussion`) + GitHub app + chat web. La carga de orientarse antes de decidir consume más tiempo que la decisión misma.

Karina (content_editor) tiene insight operativo diario crítico pero no usa GitHub. Hoy el feedback de ella entra vía WhatsApp / chat fragmentado, sin tracking.

### Problem

1. **Visibilidad**: sin vista única, abrir 3 repos × N issues × N PRs para saber "qué necesita mi atención hoy" toma 15-30min cada mañana
2. **Entry friction**: Karina sin acceso GitHub bloquea su capacidad de reportar bugs en tiempo real
3. **Context loss**: cuando discuto un issue contigo en chat web, copiar manualmente título + body + screenshot + threads relacionados toma 2-3min de fricciones
4. **Multi-session collisions**: paralelizar CC sessions sin visibilidad de "quién toca qué ahora" causó colisiones threads 145-154

### Current state

- Issues live en `rdm-discussion` mezclados con threads/specs
- PRs distribuidos en `rdm-bot` y `rdm-platform`
- GitHub mobile app es la única UI móvil disponible (genérica, no aware del workflow RdM)
- Karina onboarding al sistema bloqueado
- Approval flow funciona pero requiere context-switching constante

### Goal

Wrapper visual sobre GitHub que da: **visibilidad + estructura + smart submit**. NO duplica approval logic. NO reescribe flujo Git. Respeta convenciones RdM (threads, buckets, anti-patterns) y reglas Claude (territories, modos de trabajo).

---

## 2. Explicit scope

### YES — in scope

- Nuevo Worker `apps/worker-feedback` en repo `rdm-bot`
- D1 migration con 3 tablas: `feedback_items`, `github_cache`, `cc_sessions`
- R2 bucket nuevo: `rdm-feedback-attach` (signed URLs 7d)
- UI nueva en `apps/admin` (rdm-platform) bajo `/admin/issues/*`
- Submit form con paste/upload screenshot (desktop-optimized, mobile-functional)
- Unified Inbox view (mobile-first) agrupada por status
- Smart Grouping view por `thread/XXX` reference
- CC Activity Tracker (poll-based, 60s interval)
- Daily Brief generator (cron mañana 6am MX, render on-demand)
- Context Cards expand-inline en cada issue/PR
- Smart Clipboard button: copia markdown estructurado al clipboard del navegador
- GitHub webhook receiver: sync issues/PRs events → D1 cache
- Cron daily reconcile: detecta drift D1 ↔ GitHub
- Labels creation en `rdm-discussion`: `kind/feedback`, `bucket/*`, `status/*`, `priority/*`
- Auth integration: `admin` (Alex) full, `content_editor` (Karina) submit+comment, scaffold `feedback_only` role
- Tests E2E happy paths + unit tests críticos
- Karina onboarding doc 1-page

### NO — out of scope (hard line)

- ❌ Approval buttons que actúan en GitHub (no merge, no review submit, no comment desde UI)
- ❌ Bash trigger / deploy trigger / migration trigger desde UI
- ❌ Chat inline con Anthropic API (descartado por Alex)
- ❌ Deep-link a Claude.ai (descartado, mobile no soporta project + prompt prefill)
- ❌ Telegram push / email push (Alex: solo UI)
- ❌ Notificaciones del navegador / VAPID push
- ❌ Guest CRM / guest feedback (eso vive en Guest 360 + Beds24 Reviews)
- ❌ Asociar feedback a `booking_id` o `guest_id` (F5+ futuro)
- ❌ Vista de approvals/PRs como decision-making UI (solo informativa, tap = Open in GitHub)
- ❌ Make.com integration (siendo deprecado)
- ❌ Multi-language UI (ES only, Karina is fluent)
- ❌ Drag-drop kanban entre status (no requerido, status cambia vía label change en GitHub)
- ❌ Bashes/scripts execution (descartado scope creep)

### Decision deferred (future scope)

- `feedback_only` role para empleados futuros (scaffold solo, no UI específica)
- `/admin/feedback` para huéspedes (post-stay survey) — F5+
- Capacitor.js wrap-to-APK si geofencing serio se requiere — F5+
- Integration con `booking_lifecycle_events` (F1 foundation) cuando exista — automatic

---

## 3. Closed decisions (no re-litigate)

| # | Decisión | Resolución |
|---|---|---|
| 1 | Mobile vs desktop primary | **Desktop para submit + trabajo, mobile solo para ver estado + tap Open in GitHub** |
| 2 | Approval logic propio o delegar a GitHub | **Delegar 100% a GitHub. Solo informativa.** |
| 3 | Chat inline con bot | **NO. Smart Clipboard only.** |
| 4 | Deep-link a Claude.ai | **NO. Mobile no soporta. Solo clipboard.** |
| 5 | Repo para issues | **Reusar `rdm-discussion` con label `kind/feedback`** |
| 6 | Worker location | **Nuevo `apps/worker-feedback` (separation of concerns, no contamina bot runtime)** |
| 7 | UI location | **`apps/admin` en rdm-platform (auth + roles ya configurados)** |
| 8 | Notification channel | **Solo UI. Sin Telegram, sin email, sin push.** |
| 9 | Screenshot storage | **R2 bucket dedicated `rdm-feedback-attach`, signed URLs 7d expiry, refresh on access** |
| 10 | Ruta principal | **`/admin/issues`** |
| 11 | Submit roles | **`admin` + `content_editor` (Karina). Scaffold `feedback_only` para futuro.** |
| 12 | Buckets iniciales | **6 buckets: `admin`, `web`, `bot`, `beds24`, `content`, `infra`** |
| 13 | Priority labels | **3 niveles ortogonales: `priority/low`, `priority/normal`, `priority/high`** |
| 14 | Single big-bang o fases | **One-run, single CC session larga** |
| 15 | Tests coverage | **≥80%, E2E happy paths + unit critical** |
| 16 | Cron timing daily brief | **6am MX (CST-6), regenerable on-demand vía /api/brief/today** |
| 17 | CC Activity poll interval | **60s** |
| 18 | Status state machine | **`inbox → triaged → approved → spec-ready → in-pr → done`. Rechazo: `→ rejected`.** |
| 19 | Worker URL | **`worker-feedback.{cf-account}.workers.dev` (no custom domain). Sin DNS extra, sin certs, sin overhead.** |
| 20 | CC identity mapping | **Branch-based**, NO email-based. Mapping: `feat/greeter-*`, `feat/canary-*` → cc-bot. `feat/data-*` → cc-data. `feat/state-*`, `feat/numbering-*` → cc-strategy. Default fallback: repo-based (rdm-bot → cc-bot, rdm-discussion → cc-strategy si no matchea branch). |

---

## 4. Implementation

Ver archivo completo en repo. Esta es la versión web-pushed; archivo completo de 42KB con 7 secciones + 3 anexos disponible vía git pull.

**Secciones implementation completas en el archivo del repo**:
- 4.1 Files to create (estructura completa rdm-bot + rdm-platform + rdm-discussion)
- 4.2 D1 schema migration 0040 (3 tablas: feedback_items, github_cache, cc_sessions)
- 4.3 Worker API contracts (8 endpoint groups, base URL `*.workers.dev`)
- 4.4 Smart Clipboard template canónico
- 4.5 GitHub webhook event handling table
- 4.6 CC Activity detection logic BRANCH-BASED (regex rules + repo fallback)
- 4.7 Smart Grouping algorithm
- 4.8 Daily Brief generator (5 secciones rule-based, no LLM)
- 4.9 UI views (6 wireframes ASCII mobile-first)
- 4.10 Auth integration (admin / content_editor / feedback_only)
- 4.11 R2 bucket setup
- 4.12 GitHub labels (19 labels para gh label create)

---

## 5. Tests

### E2E (7 happy paths críticos)
1. Submit → GitHub → UI flow
2. Smart Clipboard markdown valid
3. Approval externo se refleja vía webhook
4. PR cierra issue cascade
5. Smart Grouping clusters
6. Daily Brief 5 secciones
7. CC Activity branch-based classification

### Unit (8 critical paths)
- R2 sign URL, webhook HMAC, clipboard template, thread regex, CC branch mapping, drift reconcile, brief heuristics, state machine

### Coverage target: ≥80%

---

## 6. Definition of Done (20 items checkable)

1-20: Migration applied, R2 bucket, Worker deployed, webhooks configured 3 repos, secrets set, 19 labels created, 6 UI routes live, desktop submit OK, mobile submit functional, mobile inbox renders, Smart Clipboard returns valid markdown, Karina UAT pass, Daily brief 5 secciones, CC Activity branch-classified, drift reconcile cron, tests ≥80%, self-review diff, spec archived, architecture doc, Karina guide.

---

## 7. Risks + mitigations (16 riesgos)

R1-R16 documentados en archivo completo con probabilidad + impacto + mitigación específica.

Key riesgos:
- R1 Sync drift D1↔GitHub → webhook + cron reconcile
- R3 Scope creep guest CRM → hard line en spec
- R6 Karina UX confusion → UAT + 1pg guide
- R9 CC branch misclassification → conservative rules + repo fallback
- R11 Auth bypass → Better Auth middleware
- R14 Spec changes mid-execution → halt + new spec

---

## 8. Execution notes for CC

### Order (additive-first, target 35h)
1. Setup (2h) — branch, labels, R2, worker skeleton
2. D1 schema (2h) — migration 0040 local first
3. Worker API (12h) — 7 endpoint groups in order
4. GitHub webhooks (3h) — 3 repos
5. UI components (10h) — mobile-first
6. Integration tests (4h)
7. Docs (1h)
8. Self-review (1h)

### Halt conditions (>30min blocked)
- Webhook signature failing
- D1 migration remote fails
- R2 sign returns 403
- Better Auth session not propagating
- Karina UAT confusion

### Out-of-scope guardrails (open issue, NO fix inline)
- Bug en worker-bot no relacionado
- Pet policy /noche residual
- Karina training 500 error
- Cambios a Greeter prompt
- thread/127 A5 Chrome MCP

### Hard halt: 45h
Si excede 45h, halt + comenta. NO grindear hasta 60h.

---

## 9. Post-merge follow-ups (Alex side)

1. Verify webhook delivery cada repo
2. Karina UAT 30min con Alex acompañando
3. Distribuir Karina guide
4. Smoke test daily brief 1 semana
5. Monitor R2 + worker logs 72h
6. Announce + bookmark mobile

---

## 10. Future iterations (NOT in this spec)

F5+: booking_id association, push notifications, multi-language, kanban reorder, WC auto-triage, M5 Tasks integration, metrics dashboard.

---

**End of spec.**

Numbering: thread asignado **161** (`threads/161-wc-cc-admin-issues-cockpit-doit.md`). Verified: thread/160 was last sequential at spec push time.

**Nota**: este archivo es la versión condensada para push vía API. Para detalles completos de secciones 4 (Implementation), 5 (Tests), 6 (DoD), 7 (Risks), CC debe consultar el archivo completo cuando se clone localmente o el thread 161 que tiene resumen ejecutivo + pre-flight + halt conditions.
