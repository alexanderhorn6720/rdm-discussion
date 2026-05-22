---
thread: 182
author: WC
date: 2026-05-22
topic: doit-megaspec-wave1-cleanup-velocity
mode: DoIt
status: ready-for-cc-execution
target_session: sesión CC nueva en `c:/dev/rdm/dev/bot/` + `c:/dev/rdm/dev/discussion/`
inputs:
  - thread/178 (WC brain ultra meta-synthesis + Wave 1 spec base)
  - thread/179b (master backlog vivo con checkboxes)
  - thread/181 (budget tier T5 fine-tune — debería estar shipped antes de este)
alex_votes_constraints:
  scope: A (WV + BT + MR + AU + VL + G6)
  budget_tiers_post_max_plan:
    exploration_warning: 20
    doit_normal_warning: 100
    doit_multi_cc_warning: 200
    block_mode: warning-only (no hard halt en 1.5×)
  velocity_stack:
    sonnet_default_repos:
      - rdm-bot
      - rdm-data
      - rdm-platform
    opus_default_repos:
      - rdm-discussion
    multi_cc_target: 2
    self_review_hook: keep
    plan_mode: ON
deliverable: 6 PRs (1 por sección) o 1 PR omnibus si CC prefiere — Alex pref omnibus mobile review
estimated_cc_time: 4h wall-clock (Sonnet)
estimated_llm_budget_usd: 12
halt_global_budget_usd: 18
daily_cost_budget_usd: 100
---

# DoIt CC — Megaspec Wave 1 Cleanup + Velocity Stack

## §0 Pre-flight obligatorio

1. `cd c:/dev/rdm/dev/bot` && `git pull --rebase origin main`
2. `cd c:/dev/rdm/dev/discussion` && `git pull --rebase origin main`
3. `cd c:/dev/rdm/dev/platform` && `git pull --rebase origin main` (read-only, solo verificar)
4. Verify thread/181 shipped (T5 budget tier):
   - `grep "DAILY_COST_BUDGET_USD" c:/dev/rdm/dev/bot/apps/worker-bot/wrangler.toml` → value >= 50
   - `test -f c:/dev/rdm/dev/bot/.claude/hooks/PostToolUse-cost-check.sh`
5. Verify schema validator soft mode hasta 2026-05-29:
   - `cat c:/dev/rdm/dev/discussion/schemas/thread.schema.json` → confirm soft mode flag
6. Atomic claim para nuevo thread (T1 thread/175 shipped):
   - `bash c:/dev/rdm/dev/discussion/scripts/new-thread.sh CC-Bot doit-182-megaspec-report` — verificar funciona
7. Halt si pre-flight falla.

## §1 Contexto

Wave 1 cleanup + velocity stack post Max plan upgrade. Alex confirmó:

| Voto | Valor | Razón |
|---|---|---|
| Plan activo | Claude Max | Tokens incluidos, ccusage $3,263 = vanity, no deuda |
| Default modelo | Sonnet 4.6 (bot, data, platform) | 2× velocidad sobre Opus, calidad daily OK |
| Discussion repo | Opus 4.7 | Specs/threads valen razonamiento profundo |
| Budget tiers | Warning-only | Sin block hard, solo señal "sesión pesada" |
| Multi-CC target | 2 sesiones | Conservador, atomic claim ya soporta |
| Self-review hook | Mantener | T4 thread/175 — barato, alta señal |
| Plan mode CC | ON default | Safety net contra scope creep |

Spend hoy 2026-05-22 = $185 ccusage (multi-CC + WC pesado + Opus dominante). Post este DoIt, CC corre Sonnet → spend esperado / 2.

## §2 Scope

### SÍ (6 secciones, ver §4 implementación)

- **WV** — Wave 1 cleanup (STATE.md, CLAUDE.md anti-pattern, decisions/03, archive specs, archive OPEN_QUESTIONS, delete branches)
- **BT** — Budget tier rebalance warning-only (override del shipping en thread/181)
- **MR** — Misc cleanup (thread/179 mark superseded_by:180)
- **AU** — Audit-as-code (`.audit-scratch/*.py` reproducibles)
- **VL** — Velocity stack (Sonnet default per-repo via `.claude/settings.json`)
- **G6** — PDF removal (legacy docs cleanup)

### NO

- NO tocar producción (worker-bot, worker-pago, worker-tours, worker-feedback) lógica core
- NO tocar D1 schemas, migrations, KV bindings
- NO refactor de código no relacionado
- NO open issues fuera de scope (anotar en reporte final, NO crear inline)
- NO tocar Greeter/Booker prompts
- NO tocar Casa Chamán (sigue invisible hasta Q3 2026)
- NO merge a main sin Alex review (PRs draft o request review)
- NO force-push, NO delete branches con commits no merged
- NO touch `rdm-platform` (read-only para CC)

## §3 Decisiones cerradas

1. **Estrategia PR**: 1 PR omnibus a `rdm-bot` + 1 PR omnibus a `rdm-discussion`. Alex preferred mobile review.
2. **Branch naming**:
   - `feat/megaspec-182-wave1-cleanup` en rdm-discussion
   - `feat/megaspec-182-velocity-stack` en rdm-bot
3. **Commit format**: Conventional commits con sección prefix:
   - `chore(WV): archive specs/2026-05-15-foo.md`
   - `feat(VL): sonnet default .claude/settings.json`
   - etc
4. **Branches a delete (WV-F)**: solo branches con `git log main..BRANCH` vacío (ya merged) o explícitamente abandoned (>30 días sin commit + no PR open). Lista candidata pre-flight, halt si >50 → reporta para Alex review.
5. **Budget rebalance (BT)**: Override thread/181 deploy. Default warning-only, no halt en 1.5×. Alerta Telegram low priority en 1.0×, no critical.
6. **G6 PDF removal**: identificar archivos `.pdf` en rdm-discussion y rdm-bot tracked por git, mover a `archive/pdfs-2026-05-22/` (no delete absoluto). PDFs en R2 no se tocan.
7. **AU script naming**: `.audit-scratch/audit-NN-purpose.py`, cada uno con docstring + `if __name__ == "__main__"` + idempotente.

## §4 Implementación

### §4.WV — Wave 1 cleanup (1.5h, rdm-discussion + rdm-bot)

#### WV-A — STATE.md update (15 min)

`rdm-discussion/STATE.md`:
- Agregar worker-feedback como 5to app activo (memoria 2026-05-21)
- Actualizar pipeline status (threads 175/176/181 shipped, hooks deployed)
- Sección "Wave 1 status" → mark cleanup en progreso

#### WV-B — CLAUDE.md anti-pattern reinforcement (10 min)

`rdm-bot/CLAUDE.md` y `rdm-discussion/CLAUDE.md` (ambos):
- Re-enforce: NO LLM money decisions (ADR-001)
- NO Casa Chamán en Greeter prompt
- Pet fee `/estancia`, NEVER `/noche`
- Beds24 sync mode: Prices & Availability ONLY, NEVER Everything

#### WV-C — decisions/03 status update (5 min)

`rdm-discussion/decisions/03-*.md` (identificar archivo exacto pre-flight):
- Mark status field a current state (Alex review)
- Si decision ya superseded, link al thread/decision que lo reemplaza

#### WV-D — Archive specs antiguas (20 min)

`rdm-discussion/cc-instructions-bot/` y `cc-instructions-data/`:
- Identificar specs con fecha < 2026-05-01 + status `shipped` o `superseded`
- Mover a `cc-instructions-bot/archive/` y `cc-instructions-data/archive/`
- Mantener naming + fecha original
- Update cualquier referencia rota en STATE.md o threads recientes

#### WV-E — Archive OPEN_QUESTIONS (10 min)

`rdm-discussion/OPEN_QUESTIONS.md`:
- Items con resolución cerrada en thread/178+ → mover a `OPEN_QUESTIONS_ARCHIVE.md`
- Items sin resolución pero >30 días sin actividad → mover a `OPEN_QUESTIONS_STALE.md` (revisar luego)
- Mantener máximo 10 items vivos

#### WV-F — Delete branches obsoletas (30 min)

```bash
cd c:/dev/rdm/dev/bot
git fetch --prune

# List branches merged a main
git branch -r --merged origin/main | grep -v 'origin/main\|origin/HEAD' > /tmp/merged-branches.txt

# List branches > 30 días sin commit
git for-each-ref --sort=committerdate refs/remotes/origin/ --format='%(committerdate:short) %(refname:short)' \
  | awk -v cutoff=$(date -d '30 days ago' +%Y-%m-%d) '$1 < cutoff' > /tmp/stale-branches.txt

# Intersect merged + stale = safe delete
# Report list a Alex ANTES de delete

# Si Alex green-lights:
xargs -a /tmp/branches-to-delete.txt -I{} git push origin --delete {}
```

**Halt si total candidate > 50 branches → report list + ask Alex.**

Repetir en `rdm-discussion` y `rdm-platform` (este último read-only, solo report no delete).

### §4.BT — Budget tier rebalance warning-only (30 min, rdm-bot)

Override thread/181 shipping. Cambios:

#### BT-1 — Worker env bump

`apps/worker-bot/wrangler.toml`:
```toml
[vars]
DAILY_COST_BUDGET_USD = "100"  # was "50" (thread/181), bumped warning-only post Max plan
HALT_MULTIPLIER = "999"        # was "1.5", efectivamente disabled (warning only)
```

#### BT-2 — Hook actualizar lógica

`.claude/hooks/PostToolUse-cost-check.sh`:
- Cambiar lógica de halt 1.5× a warning Telegram low priority
- 1.0× = no-op (no alert)
- 2.0× = Telegram low priority warning ("sesión pesada, $X spent")
- NUNCA halt CC en este DoIt — solo warning

#### BT-3 — Schema field actualizar

`rdm-discussion/schemas/thread.schema.json`:
- `daily_cost_budget_usd` field range max → 500
- Añadir enum recomendaciones en description: `[20, 100, 200]` (exploration, doit_normal, doit_multi_cc)

#### BT-4 — Docs update

`rdm-bot/CLAUDE.md` sección "Cost budget tiers":
- Actualizar tier values: 20 / 100 / 200
- Aclarar: warning-only post Max plan upgrade. Hard halt obsoleto.
- ccusage ≠ factura. Max plan cubre tokens. Tiers son señal "esta sesión está pesada".

### §4.MR — Misc cleanup (10 min, rdm-discussion)

#### MR-1 — Mark thread/179 superseded

`rdm-discussion/threads/179-wc-master-backlog-prioritized-checklist.md`:
- Agregar al frontmatter: `superseded_by: 180`
- Agregar nota top del file: "**SUPERSEDED**: thread/180 contiene estado post-merge real."

(Verificar pre-flight si thread/179 es el master backlog o el CC completion report — hay 2 con prefijo 179.)

#### MR-2 — Re-link backlog vivo

Si master backlog vivo es 179b (sufijo b), confirmar que cualquier reference a "179" en STATE.md, CLAUDE.md, threads recientes apunta a `179-wc-master-backlog-prioritized-checklist.md` (no al 179 de CC).

### §4.AU — Audit-as-code (1h, rdm-discussion)

#### AU-1 — Setup directory

`rdm-discussion/.audit-scratch/`:
- Crear `README.md` explicando convención
- Cada script: `audit-NN-purpose.py`, idempotente, docstring claro, `python3 audit-XX-foo.py` reproducible standalone

#### AU-2 — Migrar audits actuales

Si ya existen scripts ad-hoc en `.audit-scratch/`:
- Refactor a convention (NN- prefix + docstring + main guard)
- Agregar tests dummies con assert básicos
- Pre-flight: `python3 -m py_compile .audit-scratch/audit-*.py` debe pasar todos

#### AU-3 — `.audit-scratch/README.md`

Contenido mínimo:
```markdown
# Audit-as-code

Scripts reproducibles para auditorías META del repo.

## Convención

`audit-NN-purpose.py` donde NN = orden cronológico (00, 01, ...).

Cada script:
- Docstring top con: propósito, fecha, autor, dependencias
- `if __name__ == "__main__"` guard
- Idempotente (correr 2x = mismo output)
- Standalone (`python3 audit-XX.py` sin args)
- Output a stdout o `./audit-scratch/results/audit-NN-YYYY-MM-DD.json`

## Audits actuales

| # | Script | Propósito | Última corrida |
|---|---|---|---|
| 00 | audit-00-thread-numbering.py | Detectar threads duplicados | 2026-05-22 |
| 01 | ... | ... | ... |
```

#### AU-4 — Validar reproducibilidad

Pre-merge: correr cada audit 2x, diff output debe ser vacío (idempotente).

### §4.VL — Velocity stack (30 min, 3 repos)

#### VL-1 — Sonnet default en `rdm-bot`

`c:/dev/rdm/dev/bot/.claude/settings.json`:
- Si existe, agregar field `"model": "sonnet"` (alias resolve a Sonnet 4.6)
- Si no existe, crear con:
```json
{
  "model": "sonnet"
}
```

Mantener hooks block si ya existe (thread/175 T4/T5).

#### VL-2 — Sonnet default en `rdm-data`

`c:/dev/rdm/dev/data/.claude/settings.json`: mismo patrón VL-1.

#### VL-3 — Sonnet default en `rdm-platform`

`c:/dev/rdm/dev/platform/.claude/settings.json`: mismo patrón VL-1.

(Nota: CC NO tiene write a rdm-platform según roles. Para este punto VL-3: CC crea PR draft con el cambio, Alex merge manual.)

#### VL-4 — Discussion queda Opus

`c:/dev/rdm/dev/discussion/.claude/settings.json`:
- Si tiene `"model": "sonnet"` o similar override, **remover** el field (deja default Opus)
- Si no tiene field, no tocar

#### VL-5 — CLAUDE.md update — velocity stack section

`rdm-bot/CLAUDE.md` añadir:
```markdown
## Velocity stack (post 2026-05-22, Max plan)

- Default modelo: **Sonnet 4.6** (alias `sonnet`).
- Override puntual: `/model opus` dentro de sesión, o `claude --model opus` al launch.
- Multi-CC paralelo target: 2 sesiones simultáneas (atomic claim ya soporta).
- Budget tiers: warning-only. ccusage = vanity metric (Max plan cubre).
- Self-review hook (T4) activo siempre — no skip aunque tarea sea trivial.
- Plan mode ON default — explícito `DoIt` te da plan-off puntual.

## ¿Cuándo Opus?

- Brain mode WC (Claude.ai, no CC) — siempre Opus
- Específicamente debugging tricky (race conditions, edge cases multi-sistema)
- Spec doc complejo donde Sonnet pierde nuance

Para todo lo demás: Sonnet.
```

#### VL-6 — Verificar post-merge

Cada repo, post merge VL:
- `claude --model sonnet -p "/status"` → confirma Sonnet activo
- Smoke 1 mensaje simple → respuesta funcional

### §4.G6 — PDF removal (30 min, rdm-discussion + rdm-bot)

#### G6-1 — Identificar PDFs tracked

```bash
cd c:/dev/rdm/dev/discussion && git ls-files '*.pdf'
cd c:/dev/rdm/dev/bot && git ls-files '*.pdf'
```

Report lista pre-flight. Halt si > 20 archivos → ask Alex.

#### G6-2 — Mover a archive

```bash
mkdir -p archive/pdfs-2026-05-22/
git mv path/to/foo.pdf archive/pdfs-2026-05-22/foo.pdf
```

NO delete absoluto. Move-only (recoverable).

#### G6-3 — Actualizar referencias

`grep -r "\.pdf" --include="*.md" .` → si algún markdown linkea PDF movido, actualizar path o anotar broken-link en commit.

#### G6-4 — `.gitignore` update

Añadir `*.pdf` excepto archive en `.gitignore`:
```
*.pdf
!archive/**/*.pdf
```

(R2 PDFs no afectados — esto es solo git-tracked.)

## §5 Tests

### Tests por sección

| Sección | Test mínimo |
|---|---|
| WV-A | `cat STATE.md \| grep worker-feedback` → match |
| WV-B | `grep "estancia" CLAUDE.md` match, `grep "noche" CLAUDE.md` no match |
| WV-D | `ls cc-instructions-bot/archive/ \| wc -l` > 0 |
| WV-F | `git branch -r \| wc -l` post < pre |
| BT-1 | `grep DAILY_COST_BUDGET_USD wrangler.toml` value=100 |
| BT-2 | Hook ejecutado en thread test, NO halt, sí Telegram low |
| MR-1 | `grep "superseded_by: 180" threads/179-wc-*.md` match |
| AU-1 | `ls .audit-scratch/README.md` exists |
| AU-2 | `python3 -m py_compile .audit-scratch/audit-*.py` OK todos |
| AU-4 | Correr cada audit 2x, diff vacío |
| VL-1 | `cat .claude/settings.json \| jq .model` = "sonnet" en bot+data+platform |
| VL-4 | `cat discussion/.claude/settings.json \| jq .model` ausente o "opus" |
| G6-1 | `git ls-files '*.pdf'` solo `archive/**` paths |

### Test E2E global

Post merge megaspec, lanzar CC fresh session en `rdm-bot`:
1. `/status` → Sonnet
2. Spec dummy de 10 min, verificar self-review hook dispara
3. Cost real reportado < $0.5 (Sonnet es barato)

## §6 Definition of Done

- [ ] PR rdm-discussion mergeable (WV + MR + AU + G6-disc)
- [ ] PR rdm-bot mergeable (BT + VL-1 + WV-B-bot + G6-bot)
- [ ] PR draft rdm-platform (VL-3 only, Alex merge manual)
- [ ] Branch delete report a Alex (pre-execute si > 10 branches)
- [ ] PDFs moved report a Alex (pre-execute si > 5 archivos)
- [ ] Tests por sección pasan local
- [ ] Smoke E2E post-deploy verde
- [ ] PR bodies referencian `Closes thread/182`
- [ ] Cost real declarado en cada PR
- [ ] Self-review (T4 hook activo)
- [ ] Reporte final pusheado como thread/183 o thread/182-cc-bot-doit-report

## §7 Halt

Halt CC + reporta si:

- Pre-flight §0 falla cualquier paso
- WV-F candidate branches > 50 → report list, ask Alex
- WV-D specs candidate > 30 archivos → report list, ask Alex
- G6 PDFs > 20 archivos → report list, ask Alex
- AU-2 refactor falla py_compile en > 2 scripts → ask Alex
- BT-2 hook test halt en falso positivo → ask Alex
- VL settings.json existente con structure no-JSON-válido → ask Alex
- Branch delete falla por commits unmerged → halt, NO force-delete
- Cost total LLM excede $18 (1.5× estimate) → halt
- > 30 min stuck cualquier sub-task → halt, reporta

## §8 Out of scope

- Tier alias names en código (solo en docs CLAUDE.md)
- L1 Telegram alert para 1.0× (sigue solo warning 2.0×)
- Admin API integration master backlog item 4.5 (defer Q3)
- Per-conversation budget tracking
- F2 observability ship (separate spec, post-G7)
- F1 events bus (post-F2)
- F3 PWA shell (post-F1)
- M1 Pricing (post foundations)
- A5 AirBnB sync (defer post-megaspec per Alex)
- Thread/160 retomar (defer)
- Manuales BEDS24+TG (spec separada post-WV)
- Decisions stores policy (Alex pending vote, separate)
- G7 thread/148 (Alex pending vote, separate)
- Casa Chamán anything (defer Q3 2026)
- Worker producción lógica core (Greeter/Booker prompts intactos)
- Make scenarios (fase-out separado)
- MercadoPago re-integration (futuro)

## §9 Reporting al final

Pushear thread via `bash c:/dev/rdm/dev/discussion/scripts/new-thread.sh CC-Bot doit-182-megaspec-report`:

Estructura reporte:

```markdown
---
thread: <next>
author: CC-Bot
date: <today>
topic: doit-182-megaspec-completion-report
parent: 182
status: complete
---

# Reporte DoIt CC — Megaspec 182

## §1 Resumen

- PRs: #X (discussion), #Y (bot), #Z draft (platform)
- LoC: +X / -Y
- Tiempo wall-clock real: Z min
- Cost LLM real: $X (estimate era $12)
- Self-review hook: triggered N veces, 0 reverts

## §2 Por sección

### WV
- WV-A STATE.md: lines diff X
- WV-B CLAUDE.md: lines diff X
- WV-C decisions/03: status updated a "current"
- WV-D specs archived: N archivos
- WV-E OPEN_QUESTIONS archived: N items
- WV-F branches deleted: N (pre Alex green-light)

### BT, MR, AU, VL, G6: same structure

## §3 Tests resultados

| Test | Result |
|---|---|
| WV-A grep | ✅ |
| ... | ... |

## §4 Issues abiertos (NOT FIXED inline)

- Issue: ...
- Issue: ...

## §5 Smoke E2E

- /status post-merge: Sonnet ✅
- Spec dummy 10 min ejecutado, hook trigger ✅
- Cost dummy session: $0.X

## §6 DoD checklist

(copy de §6, marcar)
```

---

— WC, 2026-05-22, megaspec post Alex votes (Bloques 1+3+4). Sucesor de thread/178 Wave 1 spec base.
