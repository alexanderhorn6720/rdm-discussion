---
thread: 176
author: WC
date: 2026-05-22
topic: cc-doit-meta-archaeology-pipeline-audit
mode: DoIt
status: ready-for-cc-execution
target_session: nueva sesión CC paralela en `c:/dev/rdm/dev/` (NO la misma que ejecuta thread/175)
inputs:
  - thread/171/172/173/174 (synthesis context)
  - rdm-bot/CLAUDE.md (operating manual)
  - rdm-bot/.claude/settings.json (permissions — read-only operations OK)
  - rdm-bot/OPEN_QUESTIONS.md (22KB)
  - rdm-bot/STATE.md (11KB)
  - rdm-bot/PROPUESTA-*.md
  - rdm-discussion/CLAUDE.md, CONTEXT.md, STATE.md, VISION.md, ROADMAP.md, BACKLOG.md, QUESTIONS.md
  - rdm-platform/README.md, STATE.md, decisions/*, vision/*, foundations/*, modules/*, coordination/*
alex_explicit_flags:
  - "Hay PRs y threads multiplicados con la misma numeración" — DETECTAR Y REPORTAR colisiones explícitamente
  - "Considera también análisis de los Meta.md en bot/discussion/platform, info adicional" — los docs canonical de los 3 repos son input crítico
  - "Tenemos mucho en el pipe que se perdió, a causa mía" — identificar lost work / orphans
priority: P1 #1 según Alex (máxima prioridad)
estimated_cc_days: 2
estimated_llm_budget: $15-20 USD
halt_global_budget: $30 USD
mutation_scope: ZERO. Read-only audit. Solo CREATE en rdm-discussion/reports/.
---

# DoIt CC — META archaeology pipeline audit

## §1 Contexto

Alex flagged dos cosas críticas:

1. **"Tenemos mucho en el pipe que se perdió, a causa mía."** Necesitamos arqueología completa del pipeline: PRs, threads, branches, decisiones, lost work.

2. **"Hay PRs y threads multiplicados con la misma numeración."** CC en thread/172 ya cuantificó: 27/204 threads (13%) tienen colisiones. PR #140 fue "renumber duplicate migration 0039 → 0040". Hay más casos.

Salida esperada: información estructurada (MD + JSON) que WC y WC-Platform
puedan analizar después para priorizar próximas acciones. NO sugieras
fixes inline. NO consolides colisiones automáticamente. NO open issues.

**Este DoIt es READ-ONLY.** Solo escribe archivos a `rdm-discussion/reports/`.

## §2 Scope

### SÍ

- A1 — Inventario completo de threads (rdm-discussion/threads/)
- A2 — Inventario completo de PRs (3 repos, últimos 180 días)
- A3 — Inventario de migrations (rdm-bot/migrations/)
- A4 — Inventario branches activas / stale / muertas (3 repos)
- A5 — Cross-reference matrix threads ↔ PRs ↔ branches ↔ migrations
- A6 — Análisis docs META en 3 repos (drift, contradictions, fictions)
- A7 — OPEN_QUESTIONS + STATE §G + decisiones pendientes consolidado
- A8 — Lost work identification (huérfanos, abandonados, stale)
- A9 — Master synthesis report con top findings + recomendaciones (sin ejecutar)

Outputs:
- `rdm-discussion/reports/2026-05-22-META-A1-threads-inventory.{md,json}`
- `rdm-discussion/reports/2026-05-22-META-A2-prs-inventory.{md,json}`
- `rdm-discussion/reports/2026-05-22-META-A3-migrations-inventory.{md,json}`
- `rdm-discussion/reports/2026-05-22-META-A4-branches-inventory.{md,json}`
- `rdm-discussion/reports/2026-05-22-META-A5-cross-reference-matrix.{md,json}`
- `rdm-discussion/reports/2026-05-22-META-A6-docs-drift-analysis.{md,json}`
- `rdm-discussion/reports/2026-05-22-META-A7-pending-decisions.{md,json}`
- `rdm-discussion/reports/2026-05-22-META-A8-lost-work-orphans.{md,json}`
- `rdm-discussion/reports/2026-05-22-META-A9-master-synthesis.md` (top findings + recs)
- `rdm-discussion/reports/2026-05-22-META-collisions.md` ⚠️ (priority report explícito Alex flag)

### NO

- NO modificar threads existentes (incluso si tienen frontmatter malformado)
- NO renombrar archivos para resolver colisiones
- NO open issues automated
- NO sugerir fixes inline en el código del bot
- NO ejecutar refactor / cleanup automated
- NO consolidar threads colisionados
- NO touch git history (no rebase, no force push, no rewrite)
- NO ejecutar T1-T5 del thread/175 (otra sesión)
- NO tocar `apps/`, `packages/`, `data/` excepto LECTURA
- NO instalar deps nuevas en repos (excepto si requiere herramientas read-only en sandbox propio CC)
- NO ejecutar smoke tests / wrangler deploy
- NO acceder a secrets / .env / .dev.vars
- NO push de nada que no sea los reports a `rdm-discussion/reports/`

## §3 Decisiones cerradas (no re-litigar)

1. Output vive en `rdm-discussion/reports/` con prefix `2026-05-22-META-`.
2. Cada A1-A8 produce MD humano + JSON parseable (mismo data, dos formatos).
3. A9 master synthesis es solo MD (lectura humana).
4. Rango temporal default: últimos 180 días (en lugar de 90 — para capturar pre-CLAUDE.md establecimiento si aplica).
5. Cross-repo audit obligatorio: rdm-bot + rdm-discussion + rdm-platform.
6. PR único con TODOS los reports al final. Merge directo (read-only, no controvertido).
7. Branch: `feat/meta-archaeology-audit-2026-05-22`.
8. Conventional commits: `docs(reports): META A1-A9 pipeline audit`.
9. No bloqueo en threads con frontmatter inconsistente: best-effort parse, listar incompletos en su propio report.
10. Si CC encuentra colisión que ya fue resuelta (e.g. migration 0039 → 0040 via PR #140), reportar como `resolved` no `active`.

## §4 Implementación

### A1 — Inventario completo de threads

**Path**: `rdm-discussion/threads/`

**Para cada `.md`**:
- Parse filename: extraer prefix numérico, author slug, topic slug
- Parse frontmatter YAML (best-effort, manejar malformed)
- Extract: `thread`, `author`, `date`, `topic`, `mode`, `status`, `related`, `deliverable`, `inputs`
- File size (bytes)
- Last commit date (git log -1 --format=%ai <file>)
- First commit date (git log --reverse -1 --format=%ai <file>)

**Output `A1-threads-inventory.md`**:

```markdown
# A1 — Threads inventory

**Total threads**: <N>
**Date range**: <earliest> → <latest>
**Authors**: <breakdown by author>
**Status distribution**: <breakdown by status>

## Threads table

| # | Author | Date | Topic | Mode | Status | Size | Last commit |
|---|---|---|---|---|---|---|---|
| 001 | ... |
| ... |

## Frontmatter malformed (best-effort parsed)

- thread/N: missing field X
- thread/M: invalid date format
- ...
```

**Output `A1-threads-inventory.json`**: array de objetos con todos los campos.

### A2 — Inventario completo de PRs

**3 repos**: `rdm-bot`, `rdm-discussion`, `rdm-platform`

**Para cada PR (mergeed + open + closed-no-merge + draft)**:
- gh CLI: `gh pr list --repo <owner/repo> --state all --limit 500 --json number,title,author,createdAt,mergedAt,closedAt,state,isDraft,headRefName,baseRefName,additions,deletions,changedFiles,body,labels,reviewDecision`
- Para cada body: parse referencia a `thread/N` (regex `thread\s*/\s*(\d+)`)
- Detectar si PR tiene smoke test status en checks
- Identificar PRs sin thread referenced
- Identificar PRs duplicados (mismo title o overlapping diff)

**Output `A2-prs-inventory.md`**:

```markdown
# A2 — PRs inventory (3 repos)

**Total PRs**: <N>
- Merged: <X>
- Open: <Y>
- Closed (no merge): <Z>
- Draft: <W>

**Date range**: <earliest> → <latest>

## PRs by repo

### rdm-bot
| # | Title | Author | Created | Merged/Closed | State | LoC | Thread |
|---|---|---|---|---|---|---|---|

### rdm-discussion
| ... |

### rdm-platform
| ... |

## PRs sin thread reference

- PR #X: <title> (rdm-bot)
- ...

## PRs sospechosos (duplicate title o overlapping diff)

- PR #X vs PR #Y: <reason>
```

**Output `A2-prs-inventory.json`**: array de objetos.

### A3 — Inventario migrations

**Path**: `rdm-bot/migrations/*.sql`

**Para cada `.sql`**:
- Parse filename: número prefix (NNNN_topic.sql)
- Detectar duplicates por número
- Identificar applied vs not applied (best-effort: check `git log` + STATE.md sección de migrations si existe)
- Hash SHA1 del contenido

**Output `A3-migrations-inventory.md`**:

```markdown
# A3 — Migrations inventory

**Total migrations**: <N>
**Highest number**: <max>
**Duplicates detected**: <Y/N + list>

## Migrations table

| # | Filename | Topic | Last commit | Hash | Applied? |
|---|---|---|---|---|---|

## Colisiones de número

⚠️ Migration 0039 collision:
- 0039_audit_log.sql (resolved → renamed to 0040 in PR #140)
- 0039_rules_link_clicks.sql

(Cita PR/thread resolutor si aplica)
```

### A4 — Inventario branches

**3 repos**: gh api `/repos/{owner}/{repo}/branches --paginate`

**Para cada branch**:
- Name
- Last commit SHA + date
- Age in days
- Has open PR? (cross-reference A2)
- Has closed-no-merge PR? (cross-reference A2)
- Has merged PR? (cross-reference A2)
- Category:
  - `active`: last commit <= 14d
  - `stale`: 14d < last commit <= 60d
  - `dead`: last commit > 60d
  - `merged-stale`: tiene merged PR, no debería seguir existiendo
  - `orphan`: no tiene PR asociado nunca

**Output `A4-branches-inventory.md`**: tabla por repo + breakdown por category.

### A5 — Cross-reference matrix

**Cruces**:
1. Threads ↔ PRs (which threads have PR, which PRs reference thread, orphans en ambas direcciones)
2. Threads ↔ branches (which threads spawn branch still alive)
3. PRs ↔ migrations (which PR added which migration)
4. PRs ↔ smoke test status post-merge (best-effort vía gh checks)

**Output `A5-cross-reference-matrix.md`**:

```markdown
# A5 — Cross-reference matrix

## Threads → PRs mapping

| Thread | Related PRs | Status |
|---|---|---|
| 171 | (none — brain only) | closed |
| 172 | (none — challenge response) | closed |
| 175 | T1-T5 PRs pending | open-for-cc-execution |

## Orphan threads (no PR associated)

- thread/N: <topic>
- ...

## Orphan PRs (no thread referenced)

- PR #X (rdm-bot): <title>
- ...

## Threads ↔ branches

| Thread | Branch | Branch status |
|---|---|---|

## PRs ↔ migrations

| PR | Migration | Status |
|---|---|---|
```

### A6 — Análisis docs META en 3 repos

**Docs canonical a analizar**:

**rdm-bot**:
- CLAUDE.md (10KB)
- STATE.md (11KB)
- OPEN_QUESTIONS.md (22KB)
- README.md
- PROPUESTA-CLAUDE-CODE.md (18KB)
- PROPUESTA-TOUR-360.md (18KB)
- docs/ (listar contents)
- .mcp.json (config MCPs)
- .claude/settings.json (extract allowlist + deny list + scripts referenced)

**rdm-discussion**:
- CLAUDE.md
- CONTEXT.md
- STATE.md
- VISION.md
- ROADMAP.md
- BACKLOG.md
- QUESTIONS.md
- airbnb-cutover-handoff-cc.md
- decisions/ (listar ADRs)
- cc-instructions/, cc-instructions-bot/, cc-instructions-data/ (listar specs)
- wc-instructions/ (listar)
- templates/ (listar)

**rdm-platform**:
- README.md
- STATE.md
- decisions/ADR-001*, ADR-002*, README.md
- vision/01-philosophy.md, 02-wishlist.md
- foundations/ (F1, F2, F3, README, Charter si existe)
- modules/ (per-module READMEs)
- ideas/ (I1-I19)
- coordination/ (README, roles-and-permissions, doit-template)

**Para cada doc**:
- Last updated date
- File size
- Cross-references (links/menciones a otros docs)
- Decisions referenced (con/sin link a ADR)
- Open questions explícitos
- Anti-patterns mentioned

**Cross-check obligatorio**:

1. **Información contradictoria entre repos**:
   - Propiedades (roomIds, capacities) entre VISION.md y CLAUDE.md y STATE.md
   - Anti-patterns mencionados en varios sitios
   - Workstream territories
   - Stack components (Astro versions, Wrangler versions, packages list)

2. **Decisiones documentadas en uno y no en otros**:
   - ADR-001 en platform — ¿reflejado en STATE.md de discussion?
   - ADR-002 foundations seal — ¿reflejado en BOT/discussion?
   - Q4 voto Alex (operativo → foundations → M1-M5) — ¿documentado en algún doc o solo en threads?

3. **"Ficciones" tipo `new-thread.sh`**:
   - Scripts referenciados en CLAUDE.md que no existen
   - Endpoints en VISION.md / wrangler.toml que no están desplegados
   - Tablas D1 mencionadas en specs sin migration correspondiente
   - Skills/MCPs declarados en docs sin install

4. **Drift VISION vs realidad**:
   - VISION.md menciona `apps/admin` PWA — ¿existe? ¿LIVE?
   - VISION.md menciona Stage 2 WA Cloud API — ¿implementado?
   - foundations/F1 events bus — ¿LIVE? ¿partial?
   - foundations/F2 observability — ¿LIVE? ¿partial? (CC dice F2 sealed 2026-05-20)
   - foundations/F3 staff PWA — ¿LIVE? ¿partial?

**Output `A6-docs-drift-analysis.md`**:

```markdown
# A6 — Docs META drift analysis

## Inventario docs por repo

(table per repo)

## Cross-references graph

(adjacency table: which doc references which)

## Contradictions detected

| Topic | Doc A says | Doc B says | Reconciliation needed? |
|---|---|---|---|

## Decisions not propagated

| Decision (where stated) | Missing from | Impact |
|---|---|---|

## Ficciones detected (referenced but absent)

| Item | Referenced in | Actual status | Impact |
|---|---|---|---|
| scripts/new-thread.sh | bot/CLAUDE.md:65,70,119,127 + settings.json:77 | Does not exist | High — atomic claim broken |
| ... |

## VISION vs reality drift

| Component | VISION says | Realidad | Gap |
|---|---|---|---|
```

### A7 — Decisiones pendientes consolidado

**Inputs**:
- `rdm-bot/OPEN_QUESTIONS.md` (22 items según CC §3.1)
- `rdm-bot/STATE.md` §G (7 decisiones)
- `rdm-discussion/QUESTIONS.md`
- Threads con `status: open-for-alex-vote` o similar
- ADRs en `decisions/` con status no-Accepted

**Para cada pending decision**:
- ID (PR1, T1, P1, STATE.md§G.N, ADR-XXX, etc)
- Topic
- Where stated
- Date first raised (git log original commit que lo agrega)
- Days open
- Owner (Alex / WC / WC-Platform / CC)
- Blocking impact (qué se desbloquea cuando se decide)
- Category: provisioning humano / business decision / technical choice

**Output `A7-pending-decisions.md`**:

```markdown
# A7 — Pending decisions consolidated

## Total pendings: <N>

| ID | Topic | Source | Days open | Owner | Blocks |
|---|---|---|---|---|---|

## Stale items (>30 days open)

| ID | Days | Why stale? |
|---|---|---|

## Critical path items (blocking 3+ downstream)

| ID | Blocks |
|---|---|
```

### A8 — Lost work identification

**Categorías de lost work**:

1. **Threads con halt nunca retomado**: status `halt` en frontmatter pero ningún follow-up thread referenciado
2. **Branches stale >60d sin merge ni close**: candidatos a delete o resurrect
3. **PRs draft >7d**: estancados, requieren decision (continue / abandon)
4. **DoIt reports que reportan completion pero sin PR mergeed**: discrepancia spec vs ejecución
5. **Spec docs en cc-instructions sin thread de close**: trabajo planeado nunca ejecutado o reportado
6. **Decisiones tomadas conservadoras (OPEN_QUESTIONS) que pueden invalidarse**: tag para revisión

**Para cada item lost**:
- Type
- Reference (thread #, branch, PR, etc)
- Last touched date
- Days idle
- Context (qué se intentaba lograr)
- Recommended status (recuperar / archivar / cerrar formal)

**Output `A8-lost-work-orphans.md`**: listas priorizadas por tipo + recomendación NO ejecutiva.

### A9 — Master synthesis report

**No JSON, solo MD para lectura humana.**

**Output `A9-master-synthesis.md`**:

```markdown
# A9 — META archaeology master synthesis

**Generated**: 2026-05-22 por CC en thread/176

## TLDR

(3-5 bullets top findings)

## Pipeline health overview

| Métrica | Valor |
|---|---|
| Threads totales | <N> |
| Threads únicos por número | <M> |
| Colisiones de numeración threads | <X> (X%) |
| PRs últimos 180d | <N> |
| Merged | <X> |
| Open | <Y> |
| Closed-no-merge | <Z> |
| Branches activas | <N> |
| Branches stale | <X> |
| Branches dead | <Y> |
| Migrations | <N> |
| Migration collisions | <X> |
| Pending decisions | <N> |
| Stale pending decisions (>30d) | <X> |
| Lost work items | <N> |

## Top 10 findings

1. ...
2. ...

## Recommendations (NO ejecuto, solo declaro)

### Inmediato (quick wins)

- ...

### Estratégico

- ...

## Files generated

- A1: threads-inventory
- A2: prs-inventory
- A3: migrations-inventory
- A4: branches-inventory
- A5: cross-reference-matrix
- A6: docs-drift-analysis
- A7: pending-decisions
- A8: lost-work-orphans
- META-collisions.md ⚠️ (Alex flagged)
```

### Reporte explícito: colisiones (Alex flagged)

**Output adicional `2026-05-22-META-collisions.md`**:

Pull de A1, A2, A3, A4 para listar **todas las colisiones de numeración** con detalle:

```markdown
# ⚠️ META — Collisions detected

Alex flagged: "Hay PRs y threads multiplicados con la misma numeración."

## Threads collisions

| Number | Files | Authors | Topics | Resolved? |
|---|---|---|---|---|
| 162 | 162-cc-bot-doit.md, 162-amendment.md, 162-amendment-2.md | CC, CC, CC | DoIt + amendments | aceptable (same topic) |
| 160 | 160-A.md, 160-B.md | ... | distinct topics | unresolved race |
| 169 | 169-A.md, 169-B.md | ... | distinct topics | unresolved race |
| 170 | 170-A.md, 170-B.md | ... | distinct topics | unresolved race |
| 93 | ... | ... | ... | ? |
| 77 | ... | ... | ... | ? |
| 98 | ... | ... | ... | ? |

## PR collisions

(Si existen — GitHub no debería permitir pero verificar referencias en bodies, commits)

## Migration collisions

| Number | Files | Resolved? |
|---|---|---|
| 0039 | 0039_audit_log.sql, 0039_rules_link_clicks.sql | ✅ Resolved via PR #140 renumber |

## Branch name collisions

(Si existen — branches con names similares confundibles)
```

## §5 Tests

No aplica unit tests (read-only analysis). **Validaciones**:

- [ ] Cada A1-A8 produce 2 archivos (MD + JSON) consistentes
- [ ] Counts en A9 master == sum de A1-A8 individuales
- [ ] Ningún PR / thread / branch / migration en período listado missed (sample check con 5 random items)
- [ ] JSON parseable (jq válido)
- [ ] MD render-able (no broken markdown)
- [ ] META-collisions.md tiene MÍNIMO los casos que CC ya identificó en thread/172 (162-*, 160-*, 169-*, 170-*, migration 0039)

## §6 Definition of Done

- [ ] 10 archivos generados (A1-A8 × 2 + A9 + META-collisions)
- [ ] PR único con todos los reports + commit messages claros
- [ ] PR body con TLDR de top findings
- [ ] PR mergeable a main (no conflicts)
- [ ] CI verde (linting reports MD si existe)
- [ ] Smoke check post-merge: archivos accesibles vía GitHub raw URLs
- [ ] PR body referencia `Closes thread/176`
- [ ] Cost real reportado en PR body
- [ ] Self-review checklist (auto-verificables aplicables: secrets check, thread reference, no shared territory tocado)
- [ ] Thread response en `threads/{next}-cc-bot-doit-176-report.md` con findings summary

## §7 Risks + mitigations

| Risk | Mitigation |
|---|---|
| gh API rate limit (5000/hr) durante listing intenso | Paginate con sleep, log progress, resume desde checkpoint si quota exceeded |
| Frontmatter malformado en threads viejos (1-100) rompe parser | Best-effort parse, log entries malformed en su propio report sub-sección, no abortar |
| Análisis cross-repo requiere clone local de los 3 repos | Asume clones en `c:/dev/rdm/dev/{bot,discussion,platform}` — verificar al inicio, halt si missing |
| 180 días de data es mucho, análisis >2 días | Si A1-A6 completados en día 1, A7+A8+A9 en día 2. Si día 2 incompleto, partial report mejor que nada |
| Encontrar trabajo perdido sensible (e.g. spec con cliente data) | NO incluir contenido literal en reports — solo references + counts. Si hay PII en algo, redactar |
| CC encuentra colisiones que afectan producción durante audit | Flag immediato en thread/176 response, NO continúa solo, espera a Alex |
| Reportes muy grandes (>500KB) lentos para Alex review | Split en sub-reports si necesario, A9 master es summary corto (<2000 líneas) |

## §8 Halt conditions

Para esta sesión CC. Halt + reporta inmediato si:

- Encuentra colisión que **bloquea ejecución de algo en prod** (e.g. dos migrations con mismo número que no fueron renumbered)
- Encuentra secret / PII / credentials hardcodeado en algún thread o doc histórico — para + flag privado
- gh API quota permanentemente bloqueado >1h
- Cost LLM excede $30 (1.5× upper)
- Disk space full al generar reports
- Encuentra evidencia de drift CRÍTICO entre VISION y realidad (e.g. tabla D1 referenciada en spec NO existe, M1-M5 en producción cuando Alex dice no arrancados)

**NO halt por**:
- Frontmatter malformado en threads viejos (best-effort + log)
- Branches huérfanas sin claridad
- Decisiones pendientes "obvias" — listar, no fix
- gh API throttle temporal (sleep + retry)

## §9 Out of scope esta sesión CC

- Implementar new-thread.sh / ccusage / schema validator → thread/175
- F2 observability LIVE
- Fix de colisiones detectadas (eso es post-análisis con WC)
- Cleanup branches dead (eso es post-análisis)
- Consolidación de threads colisionados
- Migrations renumbering retroactivo
- Charter v0
- ADR-002 multi-WC
- M1-M5
- Cualquier modificación a producción

Si encuentras out-of-scope item urgente → declara en thread response, NO fix inline.

## §10 Reporting al final

Crea `threads/{next}-cc-bot-doit-176-report.md` con:

```yaml
---
thread: <N>
author: CC-Bot
date: <date>
topic: cc-bot-doit-176-meta-archaeology-report
mode: DoIt
status: closed
related:
  - thread/176 (spec)
  - PR #X (todos los reports)
deliverable: completion report del DoIt thread/176 META archaeology
---
```

Sections:
1. PR # (el único PR con todos los reports)
2. Files generated (list + sizes)
3. Top 10 findings (resumen, link a A9 master)
4. ⚠️ Colisiones críticas (link a META-collisions.md)
5. Lost work top items (link a A8)
6. Decisiones pendientes urgentes (link a A7)
7. Cost total real ($USD)
8. Tiempo total real (h)
9. Sorpresas / blockers encontrados (con resolución / escalation)
10. Recomendaciones para WC + WC-Platform analysis next session
11. DoD checklist verde/rojo

---

**Fin spec.** CC ejecuta. Read-only. Halt rules estrictas. Reporta al final.

— WC, 2026-05-22, DoIt spec producido para sesión CC nueva PARALELA a thread/175.
