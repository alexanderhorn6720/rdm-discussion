# Thread 160 · Numbering protocol + branch protection rdm-bot (cierre thread/153)

**From:** WC (RDM Bot session)
**To:** CC
**Date:** 2026-05-21
**Mode:** DoIt (autónomo, scope ESTRICTO)
**Depends on:** PRs #137, #5, #138, #6 ya mergeados. PRs #139-#144 y #1, #2 ya mergeados (wave-1 RDM Strategy). GitHub Pro upgrade confirmado.

---

## CONTEXT

Thread/153 redirected hacia wave-1 audit (T1-T10) del workstream paralelo RDM Strategy. Mi spec original tenía 3 items, solo 1 fue ejecutado:

| Item original | Status |
|---|---|
| Numbering protocol scripts | ❌ NO ejecutado |
| 0039 rename | ✅ Shipped (PR #140) |
| Branch protection rdm-bot retry post-Pro | ❌ NO ejecutado |

Este thread cierra los 2 items pendientes. **Scope MINI.** ~20 min CC total.

NO ejecutes nada del workstream RDM Strategy aquí. Si ves trabajo "wave" o "audit" sin label de este thread, ignora.

---

## PRE-FLIGHT

1. `git -C rdm-discussion pull origin main` → up to date
2. `git -C rdm-bot pull origin main` → up to date
3. `gh auth status` → logged in
4. `gh api /user --jq .plan.name` → debería decir `pro`. Si dice `free` halt.
5. `Test-Path "<USER_HOME>\rdm\dev\rdm-discussion\threads\146-wc-cc-process-improvements-AMENDMENT.md"` → True (referenciado para CAMBIO 1)

---

## DELIVERABLES

### CAMBIO 1 · Numbering protocol scripts (rdm-discussion)

**Branch:** `chore/thread-160-numbering-protocol`

Lee `threads/146-wc-cc-process-improvements-AMENDMENT.md` §5to cambio. Ejecuta:

1. Crear `scripts/next-thread-number.sh`:
```bash
#!/usr/bin/env bash
# Returns next free thread number, atomic (no race).
# Usage: scripts/next-thread-number.sh
set -euo pipefail
cd "$(dirname "$0")/.."
git pull origin main --quiet
highest=$(ls threads/ 2>/dev/null \
  | grep -oE '^[0-9]+' \
  | sort -n \
  | tail -1 \
  || echo "0")
next=$((highest + 1))
echo "$next"
```

2. Crear `scripts/new-thread.sh`:
```bash
#!/usr/bin/env bash
# Atomically claim next thread number and create stub file.
# Usage: scripts/new-thread.sh <author> <topic-slug>
set -euo pipefail
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <author> <topic-slug>"
  exit 1
fi
cd "$(dirname "$0")/.."
author="$1"
topic="$2"
git pull origin main --quiet
n=$(scripts/next-thread-number.sh)
filename="threads/${n}-${author}-${topic}.md"
cat > "$filename" <<EOF
# Thread ${n} · ${topic} (stub)

**From:** TBD
**To:** TBD
**Date:** $(date -u +%Y-%m-%d)
**Status:** STUB — claim number, content pending

---

> This is an atomic claim. WC will replace this file with actual content
> within next 5 minutes. If you see this longer than 30 min, ping Alex.
EOF
git add "$filename"
git commit -m "chore(thread): claim ${n} stub — ${topic}" --quiet
git push origin main --quiet
echo "Claimed thread/${n}: ${filename}"
```

3. `chmod +x scripts/*.sh`

4. Crear `threads/README.md`:
```markdown
# Threads · Numbering Protocol

## Rules

1. **Claim before write.** Para evitar colisiones entre sesiones WC paralelas:
   - `bash scripts/new-thread.sh <author> <topic>` → reserva número atómicamente
   - Reemplaza el stub con contenido real
   - Re-commit + push

2. **No retroactive renumbering.** Si ocurre colisión histórica, NO renombrar —
   agregar sufijo `-b`, `-c` al más reciente.

3. **One topic per thread.** Si un topic crece, abrir nuevo thread con
   referencia "supersedes thread/NN" en el body.

4. **Naming:** `{NN}-{author}-{topic-slug}.md`
   - `NN` = sequential number (use script)
   - `author` = wc | cc | alex | wc-cc | cc-wc
   - `topic-slug` = kebab-case, descriptive

## Examples

| Filename | Meaning |
|---|---|
| `161-wc-cc-a5-path-forward-doit.md` | WC sends DoIt to CC about A5 |
| `162-cc-wc-a5-execution-report.md` | CC reports back to WC |

## Anti-patterns

- ❌ `vim threads/161-...md` without `new-thread.sh` first
- ❌ Renumbering existing threads to "fix" gaps
- ❌ Reusing numbers from deleted threads
```

5. **Smoke test obligatorio:**
```bash
bash scripts/new-thread.sh test-author smoke-test
ls threads/*-test-author-smoke-test.md  # debe existir
# Remover stub
git rm threads/*-test-author-smoke-test.md
git commit -m "chore(thread): remove smoke test stub"
git push origin main
```

**Commits del PR:**
- `chore(threads): add atomic numbering protocol scripts + README`

(El stub de smoke test queda en commits separados via el smoke mismo.)

**PR title:** `chore: thread numbering atomic protocol (closes thread/160 part 1)`

---

### CAMBIO 2 · Branch protection rdm-bot retry post-Pro

**NO archivo de código. NO branch. Solo `gh api` direct call.**

Primero verificar workflow names reales:
```bash
gh api /repos/alexanderhorn6720/rdm-bot/actions/workflows --jq '.workflows[] | .name'
```

Identifica el workflow CI (típicamente "CI" del archivo `ci.yml` que ya verifiqué existe). Usa ese nombre como context.

Ejecutar:
```bash
gh api -X PUT /repos/alexanderhorn6720/rdm-bot/branches/main/protection \
  -f required_status_checks.strict=true \
  -f required_status_checks.contexts[]="CI" \
  -f enforce_admins=false \
  -f required_pull_request_reviews.required_approving_review_count=0 \
  -f restrictions=null \
  -f allow_force_pushes=false \
  -f allow_deletions=false
```

Si el workflow name real difiere de "CI", usar el correcto. Si hay múltiples jobs en CI, agregar contexts[] adicionales según corresponda.

**Verificar:**
```bash
gh api /repos/alexanderhorn6720/rdm-bot/branches/main/protection
```

Esperar HTTP 200 con object describiendo protection rule.

Si vuelve 403 a pesar de Pro:
- Halt + reportar exact error
- Verificar `gh api /user --jq .plan.name` again

---

## COMMIT STRATEGY

- **CAMBIO 1:** 1 PR en rdm-discussion (branch `chore/thread-160-numbering-protocol`). NO auto-merge.
- **CAMBIO 2:** NO PR. Solo `gh api` ejecutado. Resultado se reporta en thread/161.

---

## DEFAULTS

- Encoding: UTF-8, ASCII shell args
- 0 secretos
- ES en docs, EN en scripts

---

## OUT OF SCOPE — ESTRICTO

- ❌ NO ejecutar trabajo de RDM Strategy waves (T1-T10 ya cerrados, no abras T11+)
- ❌ NO renombrar threads existentes
- ❌ NO modificar 0039 ni 0040 migrations (ya hecho en PR #140)
- ❌ NO crear thread/161, 162, etc.
- ❌ NO required_pull_request_reviews >0
- ❌ NO required_status_checks beyond CI workflow

---

## CRITERIO DE ÉXITO

- [ ] `scripts/next-thread-number.sh` + `new-thread.sh` executable en rdm-discussion
- [ ] `threads/README.md` creado
- [ ] Smoke test new-thread.sh ejecutado: stub creado, luego borrado
- [ ] Branch protection rdm-bot ACTIVA (verify con `gh api .../branches/main/protection` → HTTP 200)
- [ ] PR creado para CAMBIO 1 (NO mergeado)
- [ ] Thread/161 posted con resultado branch protection

---

## SI TE ATORAS

- Plan check returns `free` → halt + Alex re-check upgrade
- Smoke test script falla → debug, no halt (pero NO crear PR sin smoke OK)
- Branch protection 403 con Pro confirmed → halt + reportar exact error de la API

---

## REPORTAR (thread/161, usa scripts/new-thread.sh para crearlo)

- PR # rdm-discussion (numbering)
- Output `gh api .../branches/main/protection` (sanitized si necesario)
- Smoke test result
- Tiempo invertido
- Sorpresas

---

## COST BUDGET

- LLM esperado: <$1
- Tiempo: 15-25 min CC
- Halt si excede $3 o 45 min

---

## NOTA META

Este thread es **scope estricto** para evitar el scope-creep que ocurrió en thread/153. Si tu backlog tiene tareas RDM Strategy o cualquier otra cosa, esas NO van aquí. Solo los 2 cambios listed.

Si por alguna razón tienes dudas sobre si algo está en scope, **NO ejecutes** y halt con la duda. Es preferible halt que ejecutar trabajo de otra sesión.
