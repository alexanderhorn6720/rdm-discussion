---
thread: 208
author: wc
topic: inbox-mega-run-followups-bugfixes-polish
status: backlog (collection mode — items NOT yet specs)
mode: brain
created: 2026-05-24
related_threads: [196, 204, 205, 206, 207]
related_prs: [173, 174, TBD-PR-C]
purpose: Bug fixes + polish acumulados durante mega-run inbox (PR-A/B/C). Lista priorizada para Wave 1.5 work post-mega-run cierre.
---

# Thread 208 — Inbox mega-run followups + bugfixes

> **Purpose**: Inbox de bugs/improvements descubiertos durante mega-run thread/205+206+207. NO es spec ejecutable todavía — Alex decide qué items convertir a spec ejecutable post-cierre PR-C.

---

## §0. Estado mega-run al momento de crear este thread

| PR | Thread | Estado |
|---|---|---|
| PR-A #173 | thread/205 | ✅ MERGED + deployed |
| PR-B #174 | thread/206 | ⏳ awaiting Alex merge |
| PR-C TBD | thread/207 | ⏳ awaiting CC implementation |

---

## §1. Tier 0 — Funcional (LLM suggestion empty)

### 1.1 🔴 LLM suggestion box renders empty en /admin/inbox

**Evidencia Alex 2026-05-24**:
```
body > main > astro-island > div > aside > div > div > div.conv-compose > div.conv-suggestion
-> empty - no llm suggestion
```

PR-A frontend fix (Promise.all + fetchSuggestion + state pass to ComposeBox) sí desplegó vía GH Action `deploy.yml`. Lógica LLMSuggestion.tsx:
- `result === null` → return null (elemento NO existe)
- `result.ok === false` → render `conv-suggestion` div con `skipReasonLabel`
- `result.ok === true` → render full suggestion

Si Alex ve div EXISTE pero EMPTY = caso B con skip_reason label vacío, **O** caso C con suggestion string vacío.

**Hipótesis ordenadas**:
1. Endpoint `/api/admin/suggest/:convId` worker-bot devuelve `{ok: true, suggestion: ''}` (Haiku 4.5 generó string vacío)
2. Endpoint devuelve `{ok: false, skip_reason: <unmapped>}` (skip_reason no está en `skipReasonLabel` map)
3. ANTHROPIC_API_KEY secret missing → endpoint returns 500 → catch (() => null) → result null → element NO existe (contradice "empty")
4. Race condition: setSuggestion no triggea re-render

**Debug pasos**:
- F12 DevTools Network tab abre /admin/inbox autenticado
- Click una conversación con expected suggestion (Claudia, Alan Granados)
- Buscar request a `/api/admin/conversation/{id}/suggest` o similar
- Verificar response JSON: `{ok: true, suggestion: "..."}` vs vacío vs error

**Esfuerzo investigación**: 30 min Alex DevTools + paste response WC

**Esfuerzo fix**: TBD según hipótesis confirmada (10 min a 2h)

---

## §2. Tier 1 — Cosmético / UX (cubierto thread/207)

Items LISTED aquí solo para tracking — están dentro del scope thread/207 PR-C, NO requieren followup separado:

| Item | Status |
|---|---|
| Drawer width desktop angosto (~280px timeline) | ✅ thread/207 §4.4 |
| Auto-scroll initial view al último mensaje | ✅ thread/207 §4.3 |
| Action buttons row-level (AirBnB / Beds24 / detalle) | ✅ thread/207 §4.2 |
| Fechas display "21 may – 23 may" | ✅ thread/207 §4.2 |
| Total message count "5 nuevos / 24 total" | ✅ thread/207 §4.2 |

Si después PR-C merged y smoke detect algo NO funciona en estos → add al §3 con label "thread/207 regression".

---

## §3. Tier 2 — Bugs edge cases descubiertos durante mega-run

### 3.1 🟡 `is_snoozed` no detecta `bot_paused_until = 'indefinite'`

**Source**: WC review PR-B #174 (this thread post-creation)

**Bug**:
```ts
// apps/worker-bot/src/inbox/aggregate.ts
is_snoozed: !!convRow?.bot_paused_until 
  && new Date(convRow.bot_paused_until).getTime() > nowMs  // <-- NaN si 'indefinite'
  && !convRow.resolved_at
```

`new Date('indefinite').getTime()` → NaN. `NaN > nowMs` → false. Indefinite pauses NUNCA mostrarán 🌙 Snoozed badge.

**Fix** (~5 min):
```ts
const isPaused = convRow?.bot_paused_until === 'indefinite'
  || (!!convRow?.bot_paused_until && new Date(convRow.bot_paused_until).getTime() > nowMs);
is_snoozed: isPaused && !convRow?.resolved_at
```

Mirror para Tab Leads.

**Esfuerzo**: 10 min + 2 tests

---

### 3.2 🟡 `airbnb_confirmation_code` falta si CC verifica schema en thread/207 step 2

Cuando CC ejecuta thread/207 step 2 (verificar schema beds24_bookings):
- **Caso A**: column existe (per migration 0026) → continúa normal
- **Caso B**: column NO existe → log [thread/207 OOS], skip botón AirBnB Wave 1

Si Caso B detectado durante thread/207 implementation → spec migration nueva en thread/208:
- Migration 0048 (next number) add column + backfill via Beds24 API
- Endpoint `/admin/backfill-airbnb-codes` que itera bookings sin code y fetcha desde Beds24
- Esfuerzo: 2-3h

**Status**: TBD según resultado thread/207 step 2

---

### 3.3 🟢 Errores smoke test PR-A no detallados

**Source**: Alex 2026-05-24 dijo "unos errores" post-merge PR-A pero NO listó.

**Pendiente Alex**: cuando tengas tiempo, escribe bullet list de errores observados smoke PR-A:
- ¿LLM suggestion empty? (cubierto §1.1)
- ¿Preview Tab Reservas todavía vacío?
- ¿Sidebar paid mal?
- ¿Counters NO populados?
- ¿VIP section missing?
- ¿Algo más?

Sin lista detallada, NO sabemos qué más fix.

---

## §4. Tier 3 — Infrastructure / DevOps

### 4.1 🟢 CF Pages Git integration disable (legacy spam)

**Evidencia**: build log 2026-05-24 21:03 muestra "Failed: build output directory not found" porque CF Pages busca `dist/` en root pero monorepo genera `apps/web/dist/`.

**Realidad**: deploy real ocurre vía GH Action `.github/workflows/deploy.yml` usando `pnpm --filter web exec wrangler pages deploy dist --project-name=rincondelmar-bot`. CF Pages Git integration es path muerto pero todavía corre on push → mails "Failed build" spam.

**Fix**:
```
CF Pages dashboard 
→ project rincondelmar-bot 
→ Settings 
→ Builds & deployments 
→ Disable automatic deployments (Git integration)
```

**Esfuerzo**: 2 min Alex en dashboard, NO CC needed

---

### 4.2 🟢 deploy-worker-bot.yml GitHub Action (Wave 1.5 followup memoria #25)

**Bug**: worker-bot NO tiene auto-deploy en GH Actions. Cada PR que toca `apps/worker-bot/**` requiere manual `npx wrangler deploy` post-merge.

**Fix**: crear `.github/workflows/deploy-worker-bot.yml`:
```yaml
name: Deploy Worker Bot
on:
  push:
    branches: [main]
    paths: ['apps/worker-bot/**']
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 9.12.3 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm --filter worker-bot exec wrangler deploy
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

**Beneficio**: eliminar gotcha manual deploy. PR mergeable = auto-deployed = smoke listo.

**Riesgo**: si tests fallaron en CI worker-bot pero PR mergeó accidentalmente → auto-deploy versión rota. Mitigation: GH Action wait-for CI step.

**Esfuerzo**: 30 min CC

---

### 4.3 🟢 MOCK_RESPONSE/MOCK_LEADS_RESPONSE removal de InboxApp.tsx (Wave 1.5 followup memoria #25)

**Source**: thread/196 Wave 1.5 followups (G2 handshake)

Actualmente InboxApp.tsx tiene mock responses como fallback. Una vez backend estable → eliminar mock branch, simplificar code.

**Tarea**:
- Remove MOCK_RESPONSE constant
- Remove MOCK_LEADS_RESPONSE constant
- Remove conditional fallback en componente
- Add `normalizeDisplayName` fallback en ConversationView header (defensive si backend devuelve nombre garbage)

**Esfuerzo**: 10 min

---

### 4.4 🟢 subscribers metadata table (Wave 1.5 followup memoria #25)

**Source**: thread/196 CC-B usó `subscriber_id` como name fallback cuando guest.name null.

**Tarea**: crear `subscribers` table con metadata cached:
- subscriber_id (PK)
- name (cached del último seen)
- phone_e164
- first_seen, last_seen, total_inquiries

Permite display name decente sin re-fetch ManyChat cada inbox load.

**Esfuerzo**: 2-3h (migration + populate cron + use en aggregate.ts)

---

### 4.5 🟢 bot_metrics table (Wave 1.5 followup memoria #25)

**Source**: thread/196 — cost dashboard queryability.

**Tarea**: crear `bot_metrics` table separada de `audit_log`:
- date, metric_name, value, source
- Indexed para fast aggregation queries
- Populated por audit_log triggers o cron rollup

Permite `/admin/cost-dashboard` (Wave 2) sin queries pesadas sobre audit_log.

**Esfuerzo**: 4-6h (schema + populate + dashboard)

---

## §5. Tier 4 — Wave 2 priority list (NO mega-run scope)

Per thread/204 §10 ranking (industry research synthesized):

1. Internal notes — Karina + Alex pueden agregar notas privadas per conversation (não visibles guest). Industry: Front, HelpScout patterns.
2. Tags / labels — categorizar conversations (e.g. "VIP", "booking-issue", "complaint", "honeymoon"). Wave 2 filterable.
3. Translation — auto-translate guest messages (English → Spanish for Karina) y reverso. Wave 2 cost analysis required.
4. Send + schedule — agendar mensaje para envío futuro. Wave 2 cron infra.
5. Cross-channel guest profile — unified view across WA + AirBnB + Booking.com per huésped. Wave 2 ID matching.

NO crear specs hasta Wave 1 cierre completo (mega-run + this thread §1-§4 resolved).

---

## §6. Decision para Alex post mega-run cierre

Después de PR-C merge + smoke verde, Alex decide:

**Prioridad inmediata** (recomendación WC):
1. §1.1 LLM suggestion empty — debug con DevTools, fix según hipótesis (Tier 0, bloquea Karina valor real)
2. §3.1 is_snoozed indefinite — quick fix (10 min)
3. §3.3 lista de errores PR-A que faltó detalle de Alex

**Mediano plazo**:
4. §4.1 CF Pages disable legacy (2 min)
5. §4.2 deploy-worker-bot.yml workflow (30 min — elimina friction)
6. §4.3 MOCK removal (10 min)

**Largo plazo** (no antes de §1-§4 resueltos):
7. §3.2 airbnb_confirmation_code backfill si missing
8. §4.4 subscribers table
9. §4.5 bot_metrics table

**Wave 2 (post Wave 1.5)**:
10. §5 priorizado según uso real Karina + business needs

---

## §7. Tracking

| Item | Severity | Effort | Status |
|---|---|---|---|
| 1.1 LLM suggestion empty | 🔴 | TBD investigation | needs debug |
| 3.1 is_snoozed indefinite | 🟡 | 10 min | needs spec |
| 3.2 airbnb_confirmation_code backfill | 🟡 | 2-3h | conditional thread/207 result |
| 3.3 errores smoke PR-A detallar | 🟢 | 5 min Alex | needs Alex input |
| 4.1 CF Pages disable | 🟢 | 2 min Alex | needs Alex dashboard |
| 4.2 deploy-worker-bot.yml | 🟢 | 30 min | needs spec |
| 4.3 MOCK removal | 🟢 | 10 min | needs spec |
| 4.4 subscribers table | 🟢 | 2-3h | needs spec |
| 4.5 bot_metrics table | 🟢 | 4-6h | needs spec |
| 5.x Wave 2 items | — | varies | defer |

---

## §8. References

- thread/204 audit deep dive (origen mucho del backlog)
- thread/205 PR-A merged (LLM suggestion frontend fix landed pero runtime issue separado)
- thread/206 PR-B awaiting merge (readiness rules + status badges)
- thread/207 PR-C awaiting impl (action buttons + dates + counts + drawer + auto-scroll)
- Memoria #25 Wave 1.5 followups
- Screenshot Alex 2026-05-24 drawer width + suggestion empty
- CF Pages build log 2026-05-24 21:03 fail

---

## §9. Reanudación post-mega-run

Cuando PR-C merged + smoke verde:

1. Alex confirma "mega-run completo" a WC
2. WC actualiza este thread §0 con final state
3. Alex revisa §6 recomendaciones y vota prioridad
4. WC genera specs ejecutables para items priorizados
5. Pipeline normal: brain → spec → DoIt → verify por cada item
