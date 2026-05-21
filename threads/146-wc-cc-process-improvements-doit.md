# Thread 146 · Process improvements · smoke test + branch protection + PR template + auto-delete

**From:** WC
**To:** CC
**Mode:** DoIt (autónomo, scope estricto)
**Date:** 2026-05-19
**Depends on:** thread/145 promote-to-root completado (no estricto, pero recomendado)

---

## CONTEXT

Análisis del PR history rdm-bot (PRs #1-30+) reveló:

- 47% PRs mergeados en <1 min (no review real)
- PR #27 detectó deploy workflow roto durante 4 días sin que nadie notara
- 50% PRs sin referencia a thread
- 15+ branches sin podar acumuladas

El proceso optimiza para velocity de merge. Falla en confianza post-deploy. Este thread cierra esos gaps con 4 cambios en 1 PR único.

---

## PRE-FLIGHT (auto-verificable)

1. `Test-Path "<USER_HOME>\rdm\dev\rdm-bot"` → True
2. `cd rdm-bot; git status` → clean
3. `cd rdm-bot; git pull origin main` → up to date
4. `gh auth status` → logged in
5. `gh api /repos/alexanderhorn6720/rdm-bot --jq .default_branch` → `main`

---

## DELIVERABLES (4 cambios en 1 PR)

**Branch:** `chore/process-improvements-thread-146` (en rdm-bot)

### Cambio 1 · Smoke test post-deploy

**Archivo nuevo:** `.github/workflows/post-deploy-smoke.yml`

**Behavior:**
- Trigger: `workflow_run` después de `deploy.yml` exitoso
- O trigger directo: `*/10 * * * *` (cada 10 min como heartbeat)
- Steps:
  1. `curl -fsS --max-time 5 https://rincondelmar.club/` → HTTP 200
  2. `curl -fsS --max-time 5 https://bot.rincondelmar.club/health` → HTTP 200
  3. `curl -fsS --max-time 5 https://pago.rincondelmar.club/health` → HTTP 200 (verificar si endpoint existe; si no, crear endpoint mínimo en worker-pago como parte de este PR)
- Si falla cualquiera: enviar mensaje Telegram a chat `8711110474` via secret `TG_BOT_TOKEN`:
  ```
  🔴 SMOKE TEST FAILED · {worker_name} · {http_code} · {timestamp}
  ```

**Implementación:**
- Workflow file con jobs paralelos para los 3 endpoints
- Telegram alert via `curl https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage`
- Si `worker-pago` no tiene `/health`, agregar handler simple en `apps/worker-pago/src/index.ts`:
  ```ts
  if (url.pathname === '/health') return new Response('OK', { status: 200 });
  ```

**Tests:**
- Verificar workflow syntax con `gh workflow view post-deploy-smoke.yml`
- Manual smoke: trigger workflow manualmente post-merge, verificar Telegram recibe ping si forzamos URL inválida

---

### Cambio 2 · Branch protection rules en main

**NO archivo de código.** CC ejecuta via `gh` CLI:

```bash
gh api -X PUT /repos/alexanderhorn6720/rdm-bot/branches/main/protection \
  -f required_status_checks.strict=true \
  -f required_status_checks.contexts[]="Deploy" \
  -f required_status_checks.contexts[]="post-deploy-smoke" \
  -f enforce_admins=false \
  -f required_pull_request_reviews.required_approving_review_count=0 \
  -f restrictions=null \
  -f allow_force_pushes=false \
  -f allow_deletions=false
```

**Resultado esperado:**
- Merge bloqueado si `Deploy` workflow fails
- Merge bloqueado si `post-deploy-smoke` workflow fails
- Force push deshabilitado en main
- Delete branch main deshabilitado
- Alex sigue siendo admin (puede bypass si necesario)

**Aplicar igual a `rdm-discussion`:**
```bash
gh api -X PUT /repos/alexanderhorn6720/rdm-discussion/branches/main/protection ...
```
(con menos checks, solo `allow_force_pushes=false` y `allow_deletions=false`)

**NO aplicar a `rdm-platform`** (boundary CC=RO).

---

### Cambio 3 · PR template

**Archivo nuevo:** `.github/pull_request_template.md`

```markdown
## What changed
<!-- 1-3 líneas. Qué cambió, no por qué. -->

## What to verify
<!-- 1-3 bullets. Qué Alex debe smoke-checkear post-merge. -->
- [ ]
- [ ]

## Threads
Closes: thread/__
References: thread/__

## Notes
<!-- Opcional. Anti-patterns considerados, decisiones técnicas no obvias, follow-ups planeados. -->

---
🤖 Generated with Claude Code
```

**Aplicar también a `rdm-discussion`** (mismo template, sin sección "What to verify"):
```markdown
## What changed
## Threads
Closes: thread/__
References: thread/__
## Notes
```

---

### Cambio 4 · Auto-delete branch on merge

**NO archivo de código.** CC ejecuta via `gh` CLI:

```bash
gh api -X PATCH /repos/alexanderhorn6720/rdm-bot \
  -f delete_branch_on_merge=true

gh api -X PATCH /repos/alexanderhorn6720/rdm-discussion \
  -f delete_branch_on_merge=true
```

**NO aplicar a `rdm-platform`** (boundary CC=RO).

**Resultado:** branches feature mergeadas se auto-delete. STATE.md §C queda limpio sin trabajo manual.

---

## COMMIT STRATEGY

- 1 PR, 4 commits semánticos:
  - `feat(ci): add post-deploy smoke test workflow + worker-pago /health endpoint`
  - `chore(github): add PR template (bot + discussion)`
  - `chore(github): enable branch protection on main (bot + discussion)`
  - `chore(github): enable auto-delete branch on merge (bot + discussion)`
- PR title: `chore: process improvements (smoke test + protections + template + auto-delete)`
- PR body usa el template (dogfood):
  ```
  ## What changed
  4 process improvements: post-deploy smoke test, PR template, branch protection,
  auto-delete on merge. Closes thread/146.

  ## What to verify
  - [ ] Smoke test workflow visible en Actions tab
  - [ ] Force push a main bloqueado en bot + discussion
  - [ ] Nueva PR muestra template
  - [ ] Branch borrada automáticamente tras siguiente merge

  ## Threads
  Closes: thread/146
  References: thread/143, thread/145
  ```

---

## DEFAULTS

- Encoding: UTF-8 file contents, ASCII shell args
- Idioma: ES en docs, EN en código y workflows
- 0 secretos hardcoded (usar `${{ secrets.TG_BOT_TOKEN }}`)
- TG chat ID `8711110474` es público (ya en `wrangler.toml` per STATE.md), OK en workflow

---

## OUT OF SCOPE

- NO tocar `rdm-platform` (boundary CC=RO)
- NO modificar workflows existentes (solo agregar el nuevo)
- NO podar branches existentes (eso lo hace auto-delete a partir de ahora)
- NO requerir reviewer approval count >0 (rompería velocity actual)
- NO required coverage threshold
- NO modificar SKILL.md, CLAUDE.md
- NO crear thread/147 (este es self-contained)

---

## EXTERNAL STATE (informational only)

- Verify que `TG_BOT_TOKEN` secret ya existe en GH repo settings (per STATE.md ya está)
- Verify que ningún workflow existente sufre conflicto con el nuevo
- Verify que branch protection no bloquea PRs actualmente abiertos (#114, #130)
  → Si bloquea, documentar en PR body y dejar que Alex decida si reabrir tras adoption

---

## CRITERIO DE ÉXITO

- [ ] `.github/workflows/post-deploy-smoke.yml` creado en rdm-bot
- [ ] `apps/worker-pago/src/index.ts` con `/health` endpoint (si no existía)
- [ ] `.github/pull_request_template.md` creado en rdm-bot y rdm-discussion
- [ ] Branch protection aplicada en main de rdm-bot y rdm-discussion
- [ ] Auto-delete on merge habilitado en rdm-bot y rdm-discussion
- [ ] PR creado en rdm-bot usando el nuevo template (dogfood)
- [ ] Smoke test pasa en preview run (Telegram NO recibe alerta porque endpoints OK)
- [ ] Documentación inline en workflow explica cómo deshabilitar si Alex necesita

---

## SI TE ATORAS

- `gh api` falla por permisos → halt + reportar exact error
- `wrangler` no disponible → solo afecta verificación post-merge, no bloquea PR
- Workflow syntax error → debug local con `act` si instalado, sino simplificar workflow
- Branch protection rule rechaza por API version → usar formato alternativo `gh api graphql`

---

## REPORTAR AL FINAL

- PR # creado
- Confirmación cada uno de los 4 cambios aplicado
- Output de `gh api /repos/alexanderhorn6720/rdm-bot/branches/main/protection` (sanitized)
- Output de `gh api /repos/alexanderhorn6720/rdm-bot --jq .delete_branch_on_merge`
- Smoke test primer run resultado
- Tiempo invertido
- Cualquier sorpresa o gotcha encontrado

---

## COST BUDGET

- LLM esperado: <$3
- Tiempo: 1.5-2h CC
- Halt si excede $5 o 3h

---

## POST-MERGE EXPECTATIONS

Próximos PRs después de este:
1. Tendrán template auto-cargado
2. Branch source se auto-delete on merge
3. Si deploy falla, próximo merge bloqueado hasta resolver
4. Si smoke test falla, Alex recibe Telegram en <10 min

Esto cierra el gap "PR #27 deploy roto 4 días undetected" sin sacrificar velocity de merge actual.
