# Thread 128 · WC handoff CC · Open items omnibus DoIt (pre-A5)

**From:** WC
**To:** CC-Bot
**Date:** 2026-05-19
**Type:** DoIt handoff autonomous
**Order:** EJECUTAR ANTES de thread/127 (A5)
**Mode:** Full autonomous · CC ejecuta sin permiso step-by-step

---

## TLDR

Alex confirmó 2026-05-19: "**A, and give me an instruction for cc to work on all other open items before, DOIT mode. Thread/127 thereafter, also doit.**"

**Order of execution:**

```
thread/128 (este, omnibus open items) → thread/127 (A5) → done
```

**Lo que CC hace en thread/128:**

1. Pre-flight verifications
2. Merge PR #118 (biome cleanup — trivial)
3. Merge PR #116 (bulk-approve endpoint — pre-req para A5)
4. Merge PR #123 (event-driven welcome — WC ya aprobó en thread/126/127 prep)
5. Review situación PR #114 (3042 líneas, journey templates) — **NO MERGE en este DoIt** sin WC formal review
6. Validate `/admin/karina-training` post-PR #124 (debe responder 200 autenticado)
7. Validate booking 86939592 welcome (ahora con PR #123 inline o cron previo)
8. CF Pages dashboard fix coordination con Alex
9. Post thread/129 con estado pre-A5

**Time budget:** 2-3h total. Excedo 1.5x = stop + reporta.

---

## 1 · Estado actual conocido (verified)

| Item | Status |
|---|---|
| PR #124 (500 fix void elements) | ✅ Mergeado por Alex, commit `ea69adb` en main |
| PR #123 (inline welcome) | 🟡 Open. WC aprobó technical review. Listo merge. |
| PR #118 (biome cleanup) | 🟡 Open. CI blocker. Trivial merge. |
| PR #116 (bulk-approve endpoint) | 🟡 Open. Pre-req para A5. Listo merge. |
| PR #114 (journey templates editor) | 🟡 Open. 3042 líneas, 15 files, 1128 líneas tests. ⚠️ NECESITA WC review formal — NO merge sin spec doc + sign-off. |

### Hallazgo crítico · PR #114 vs PR #116

Ambos PRs contienen `apps/web/src/pages/api/admin/airbnb-content/bulk-approve.ts` **idéntico** (+158/-0, MD5 match verified). CC armó #116 como standalone para desbloquear A5 sin bloquear en #114 review pesado.

**Decisión:** Merge #116 first. #114 después de PR #114 review (out of scope este DoIt).

Resolución del conflict: cuando #114 se mergee post-review, git auto-resuelve (mismo content). Si conflict: drop bulk-approve.ts de #114 branch antes de merge.

---

## 2 · Explicit scope

### ✅ YES — en scope

| # | Item | Action |
|---|---|---|
| 1 | Pre-flight verifications (git pull, env health) | Read-only |
| 2 | Merge PR #118 (biome) | Squash + delete branch |
| 3 | Merge PR #116 (bulk-approve) | Squash + delete branch |
| 4 | Merge PR #123 (inline welcome) | Squash + delete branch |
| 5 | Validate `/admin/karina-training` post-#124 | Curl + manual smoke |
| 6 | Validate booking 86939592 (HMK52J9XZM) welcome status | Query D1 |
| 7 | CF Pages dashboard fix coordination | Pídele a Alex 2 min |
| 8 | Post thread/129 con summary pre-A5 | Markdown |

### ❌ NO — out of scope

- NO mergees PR #114 (necesita WC review formal — abrir thread separado después)
- NO modifiques código de los PRs antes de merge (todos están listos as-is)
- NO arranques A5 (thread/127) hasta este DoIt esté completo
- NO toques otros items no listados arriba
- NO actualices specs ya aprobados

Si encuentras algo fuera de scope: log en thread/129 final, NO fixees inline.

---

## 3 · Closed decisions

| Decisión | Valor |
|---|---|
| PR #118 merge | ✅ Approved by WC (cosmetic CI fix, no risk) |
| PR #116 merge | ✅ Approved by WC (pre-req A5, 158 líneas isolated endpoint) |
| PR #123 merge | ✅ Approved by WC (review formal en thread/126 + thread/127 §6 R8) |
| PR #114 merge | ❌ HOLD — necesita WC review (3042 líneas, Karina-facing, no spec doc previo) |
| Merge style | Squash + delete branch (RdM convention) |
| Order of merges | #118 first (CI), #116 second (A5 pre-req), #123 third (independent) |
| If merge fails (conflict/CI) | Skip + log, don't block other merges |

---

## 4 · Pre-flight checklist

```bash
# Step 0 — verify clones up-to-date
cd <rdm-discussion>
git pull origin main
ls threads/127*.md threads/128*.md
# Both must exist

cd <rdm-bot>
git fetch origin
git log origin/main --oneline -5
# Top commit must be ea69adb (#124 500 fix) or newer

# Step 1 — verify prod health (no recent regressions)
curl -I https://rincondelmar.club/admin/karina-training
# Expected: 302 (redirect to login)

curl -I https://rincondelmar.club/admin
# Expected: 302

curl -I https://rincondelmar.club/
# Expected: 200

# Step 2 — verify GitHub API access
gh auth status || (echo "gh CLI not authenticated, use GitHub UI for merges" && exit 1)
```

If any pre-flight fails → halt + ping Alex via Telegram with detail.

---

## 5 · Execution

### Phase A · PR #118 merge (5 min)

```bash
# Verify PR is mergeable
gh pr view 118 --json mergeable,mergeStateStatus
# Expected: mergeable=MERGEABLE, mergeStateStatus=CLEAN (or BLOCKED if CI not run yet)

# Wait for CI if pending
gh pr checks 118
# Expected: all checks pass or pending (biome cleanup is fixing the CI)

# Merge
gh pr merge 118 --squash --delete-branch \
  --subject "chore(biome): ignore vendor CSS + utility scripts blocking CI (#118)" \
  --body "Squash merge approved by WC in thread/128 omnibus."
```

**If CI fails:** investigate. May need to adjust biome config. Defer to Alex.

**Smoke post-merge:** `gh run list --limit 1` should show green CI for main.

### Phase B · PR #116 merge (5 min)

```bash
# This is pre-req for A5 (thread/127)
gh pr view 116 --json mergeable,mergeStateStatus
gh pr checks 116
# Expected all green

gh pr merge 116 --squash --delete-branch \
  --subject "feat(airbnb-content): bulk-approve endpoint (A5 §1) (#116)" \
  --body "Squash merge approved by WC in thread/128 omnibus. Pre-requisite for A5 execution (thread/127)."
```

**Smoke:** verify endpoint exists post-deploy:

```bash
sleep 300  # wait deploy.yml
curl -X POST https://rincondelmar.club/api/admin/airbnb-content/bulk-approve \
  -H "Content-Type: application/json" \
  -H "x-admin-secret: ${ADMIN_REFRESH_SECRET}" \
  -d '{"who": "alex", "dry_run": true}'
# Expected: 200 with dry-run counts
# 404 = deploy not done yet, retry in 2 min
# 401 = auth issue, escalate
```

### Phase C · PR #123 merge (5 min)

```bash
gh pr view 123 --json mergeable,mergeStateStatus
gh pr checks 123

gh pr merge 123 --squash --delete-branch \
  --subject "feat(beds24-webhook): inline normalize + welcome (no more 1.5h cron lag) (#123)" \
  --body "Squash merge approved by WC in thread/126 + thread/127.

Architecture: inline normalize+welcome via c.executionCtx.waitUntil() with
cron backstop. Idempotency verified: scanForWelcome UPDATE..WHERE..IS NULL
atomic claim, runBeds24Normalize ON CONFLICT DO UPDATE on OTA cols only.

Booking 86939592 (HMK52J9XZM) is the canonical test case — welcome should
land within seconds of webhook 231 (booking_modified status=confirmed)."
```

**Smoke post-merge:** tail worker-bot logs:

```bash
wrangler tail rdm-bot --format pretty | grep "beds24_webhook_inline_processed"
# Wait for next webhook to fire (any booking event)
# Expected: log entry with bookingId, normalized count, welcomes_sent
```

### Phase D · Validate /admin/karina-training post-#124

```bash
# Public probe (logged out)
curl -I https://rincondelmar.club/admin/karina-training
# Expected: 302 (redirect to login)

# Logged-in test: pídele a Alex
# "Alex, abre /admin/karina-training logged in karina@ y reportame:
#  - ¿200 con contenido visible? → fix #124 funciona, cierra el loop.
#  - ¿500 todavía? → escalate WC con dev tools Network tab screenshot."
```

### Phase E · Validate booking 86939592 welcome status

```bash
# Query D1 (vía CC's wrangler-d1 access)
wrangler d1 execute rincon --remote --command "
SELECT
  booking_id,
  arrival,
  status,
  channel,
  welcome_sent_at,
  welcome_skipped,
  pre_stay_skip
FROM beds24_bookings
WHERE booking_id = 86939592
LIMIT 1;
"
```

**Casos:**

| welcome_sent_at | Acción |
|---|---|
| `NOT NULL` | ✅ Welcome enviado (vía cron pre-#123 o vía inline post-#123). Log en thread/129. |
| `NULL` (post-PR #123 merge) | Verify PR #123 inline triggered. If still null after 30 min, manual trigger: `POST /admin/pre-stay/send-now` with touchpoint=welcome. |
| Row doesn't exist | beds24_events 231 nunca se normalizó. Force `runBeds24Normalize` via admin endpoint. |

### Phase F · CF Pages dashboard fix (Alex collaborative)

CC pide a Alex via Telegram:

> "Alex, 2 min en CF Dashboard → Pages → rincondelmar-bot → Settings → Builds & deployments:
> - Cambia 'Build output directory' a: `apps/web/dist`
> - Confirma 'Build command': `pnpm install --frozen-lockfile && pnpm --filter web build`
> - 'Root directory' déjalo vacío o `/`
> - Save
>
> Después push trigger a cualquier branch — verifica que preview deploy ahora pasa (no más 'dist not found')."

CC espera confirmación. NO touchea código mientras.

**Si Alex confirma success:** log en thread/129 "CF Pages preview restored".

**Si Alex dice no puede o no tiene tiempo:** defer al próximo ciclo. Log "CF Pages preview pendiente, prod no afectado (deploy.yml único path)".

### Phase G · Decision PR #114

CC NO mergea #114. CC escribe en thread/129:

```
## PR #114 status
- 3042 líneas, 15 files (840 lines new admin page + 1128 lines tests + worker logic)
- Karina-facing feature (D1-backed override layer over journey templates)
- bulk-approve.ts is DUPLICATE of PR #116 (already merged in Phase B)
- Migration 0039 included

Necesita WC review formal antes de merge:
- Architecture review del override layer design
- Karina UX review (¿necesita Karina realmente editar 56 templates ahora?)
- Tests coverage assessment
- Rollback plan si feature causa issues post-deploy

Recomendación: WC abre spec doc retroactive review + thread/130 cuando
tenga ciclo. No bloquea operaciones actuales (override table empty = zero
behavior change per CC's PR body).

CC: tendrás conflict con bulk-approve.ts post-A5 cuando #114 mergee. Drop
bulk-approve.ts del branch #114 antes del merge final.
```

---

## 6 · Tests / verification

| Phase | Test | Pass criteria |
|---|---|---|
| A | PR #118 merged + CI green | `gh run list --limit 1` shows ✅ success |
| B | bulk-approve endpoint exists | `curl -X POST .../bulk-approve dry-run` returns 200 |
| C | Inline welcome logs visible | `wrangler tail` shows `beds24_webhook_inline_processed` |
| D | karina-training accessible | Alex logged-in as karina@ sees content (no 500) |
| E | 86939592 welcome status known | D1 query returns row with clear `welcome_sent_at` value |
| F | CF Pages preview works | Alex confirms or deferred status logged |

---

## 7 · Definition of done

- [ ] PR #118 merged + CI green on main
- [ ] PR #116 merged + bulk-approve endpoint deployed (200 on dry-run probe)
- [ ] PR #123 merged + inline welcome log observed in worker-bot
- [ ] `/admin/karina-training` smoke: Alex logged-in karina@ confirms 200
- [ ] Booking 86939592 welcome status documented in thread/129
- [ ] CF Pages dashboard fix: confirmed or deferred (logged)
- [ ] PR #114 status documented (no merge, defer to WC review)
- [ ] thread/129 posted with summary + handoff to thread/127 (A5)

---

## 8 · Risks + mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | PR #118 CI still failing post-merge | Investigate biome config. Defer A5 si bloquea otros pushes. |
| R2 | PR #116 bulk-approve endpoint deploy lag | Wait up to 10 min for deploy.yml. If 404 persists, escalate. |
| R3 | PR #123 inline welcome causes regression | Monitor logs 30 min post-merge. Cron backstop catches if inline fails. Revert if issues. |
| R4 | #124 500 fix doesn't resolve Karina's issue | Get Network tab screenshot, escalate WC. Don't block on this — A5 unaffected. |
| R5 | 86939592 still no welcome | Manual trigger via admin endpoint. Alternatively wait for next cron tick. |
| R6 | Alex not available for #114 decision | Defer #114 cleanly. Don't merge without his sign-off. |
| R7 | CF Pages dashboard fix breaks something else | Don't push code. Only ask Alex to change 1 dropdown. Reversible. |

---

## 9 · Communication

| Trigger | Mensaje |
|---|---|
| Pre-flight done, starting | "thread/128 starting. Will merge #118, #116, #123 sequential." |
| Each merge complete | "PR #N merged. Deploy in progress." |
| All 3 merges done + smokes pass | "All 3 PRs deployed. Validating 86939592 + karina-training." |
| Halt condition | "thread/128 halted at Phase X. Reason: Y. Need: Z." |
| Complete | Thread/129 posted + Telegram "Omnibus done. Starting thread/127 (A5)." |

---

## 10 · Comando para arrancar (copy a CC)

```
Pre-flight:
1. git pull origin main en rdm-discussion (verifica thread/128 + thread/127 existen)
2. git fetch origin && git log origin/main --oneline -5 en rdm-bot
   (top commit debe ser ea69adb #124 o más reciente)
3. curl -I https://rincondelmar.club/admin/karina-training → 302 expected
4. gh auth status

Lee:
- threads/128-wc-cc-open-items-omnibus-doit.md (este, EJECUTAR PRIMERO)
- threads/127-wc-cc-a5-execution-doit.md (DESPUÉS de completar 128)

Ejecuta thread/128 phases A-G sequential.

Time budget thread/128: 2-3h. Excedo 1.5x = stop + Telegram.
Output: thread/129 con summary + handoff a thread/127.

Después de thread/129 completo + Alex OK:
Ejecuta thread/127 (A5 execution).
Time budget thread/127: 8-12h.
Output: thread/130 con A5 report.
```

---

## 11 · Working notes

- **Sequential is required.** No paralelices merges (CI can race).
- **Wait deploy.yml between merges.** ~3-5 min per merge before smoke test.
- **Stuck > 30 min:** stop + Telegram with detail.
- **Out of scope finding:** log in thread/129, NO fixees inline.
- **Self-review pre-merge:** read PR diff one more time before squash.
- **If #114 looks tempting:** resist. WC needs spec review. No exception.

---

## 12 · After thread/128 complete

CC proceeds directly to thread/127 (A5 execution) without waiting for Alex sign-off, **unless any of these halt conditions:**

| Halt | Reason |
|---|---|
| PR #116 not deployed | A5 depends on bulk-approve endpoint |
| Karina-training 500 still occurring | Indica algún issue infra pendiente, espera Alex |
| Booking 86939592 weird state | Indica issue webhook/cron, espera review |
| CF Pages issues persist en prod (no preview) | Si afecta deploy.yml, halt. Si solo preview, OK proceder |

If all green → arranca A5 inmediatamente.

---

WC out.

🚀 Buena suerte CC. Después de thread/127 / A5, sleep good.
