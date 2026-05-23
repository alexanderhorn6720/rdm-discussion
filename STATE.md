# rdm-discussion · STATE

> Coordination layer: threads, specs, decisions, CC/WC instructions. NO code.

---

## A. THREADS ACTIVOS ESTA SEMANA (modificados últimos 7d, top 15)

| #   | Título corto                                              | Esperando              | Desde       |
|-----|-----------------------------------------------------------|------------------------|-------------|
| 182 | megaspec Wave 1 cleanup + velocity stack (DoIt)           | CC ejecutando          | 2026-05-22  |
| 181 | budget tier fine-tune T5 hook (absorbed by 182 BT)        | CC absorbed ✅         | 2026-05-22  |
| 179b| master backlog priorizado con checkboxes (vivo)           | Alex actualización     | 2026-05-22  |
| 178 | WC brain ultra meta-synthesis + Wave 1 spec base          | WC done → 182          | 2026-05-22  |
| 177 | CC-Bot doit-176 meta-archaeology report                   | -                      | 2026-05-22  |
| 176 | meta-archaeology audit DoIt                               | CC shipped ✅          | 2026-05-22  |
| 175 | cost telemetry + budget alerts + hooks T1-T5              | CC shipped ✅          | 2026-05-22  |
| 143 | state-system + threads audit                              | CC shipped             | 2026-05-19  |
| 142 | house rules paper trail Phase 1 done (CC→WC)              | WC review              | 2026-05-19  |
| 140 | A6 reglas_adicionales complete 8/8 cells                  | Alex review PR #130    | 2026-05-19  |
| 138 | A5 completion 67% deployed, 30% structural skips          | Alex decisión next step| 2026-05-19  |
| 135 | Beds24 proxy phase 1 complete (PR #127)                   | Alex deploy + verify   | 2026-05-19  |
| 132 | Browserbase + AirBnB KPI scraper backlog item             | Alex decisión          | 2026-05-19  |
| 130 | A5 halt: chrome MCP not attached (untracked)              | resolved local         | 2026-05-19  |
| 129 | omnibus DoIt report                                       | -                      | 2026-05-19  |

> **Nota:** ver `reports/2026-05-22-META-A1-threads-inventory.md` para tabla completa de 182+ threads.

## A2. WAVE 1 STATUS (thread/182, en progreso)

| Sección | Estado | Notas |
|---|---|---|
| BT — budget tier warning-only | ✅ committed | DAILY_COST_BUDGET_USD 5→100, hook 2.0× warn-only |
| VL — velocity stack Sonnet | ✅ committed | bot settings.json OK, platform PR#3 draft |
| WV — Wave 1 cleanup | 🔄 in progress | STATE.md ✓, CLAUDE.md/decisions/specs/branches pendientes |
| MR — misc cleanup (179 superseded) | ✅ done | thread/179 frontmatter: superseded_by:180 |
| AU — audit-as-code convention | ⏳ pending | — |
| G6 — PDF removal | ⏳ pending | — |

## B. SPECS PENDING SHIP (type=spec sin result thread)

| #   | Spec título                                     | Days open | Quien implementa |
|-----|-------------------------------------------------|-----------|------------------|
| 132 | Browserbase eval + AirBnB KPI scraper backlog   | 0         | Alex decide      |
| 127 | A5 execution autonomous (paused ~67%)           | 0         | CC bot (blocked) |
| 123 | canary review HSM/defer/cancel-race             | 1         | Alex decisión    |

## C. ADRs VIGENTES (decisions/)

- `01-monorepo-structure.md`
- `02-channel-strategy.md`
- `03-pricing-agent.md`
- `04-admin-board.md`
- `05-auth-magic-link.md`
- `06-future-modules.md`
- `07-pwa-mobile.md`
- `08-orchestration.md`
- `09-bots-llm-architecture.md`

> 9 ADRs vigentes. ADR-001-platform-shift está en `rdm-platform/decisions/`, NO aquí.

## D. WORKING MODES / CONVENTIONS

- Working modes documentados en `CLAUDE.md` (brain / DoIt / verify).
- DoIt template versión actual: **v3** (thread/94 ack clone paths). Vive INLINE en CLAUDE.md + ejemplos en threads recientes (143 mismo es DoIt v3).
- NO existe `coordination/` folder (vive en CLAUDE.md). `coordination/` con `doit-template.md` + `roles-and-permissions.md` está en `rdm-platform`, NO aquí.
- Spec doc template: 7 secciones obligatorias (Context, Scope, Decisions, Implementation, Tests, DoD, Risks).
- Path convention specs: `cc-instructions-{workstream}/YYYY-MM-DD-{name}.md`.

## E. OUTSTANDING DECISIONS PARA ALEX

- **A5 Airbnb bulk-approve**: 67% completo, 30% skips estructurales (thread/138). Decidir: shipear lo deployable + ticket follow-up, o esperar hasta 100%.
- **Browserbase vs Chrome DevTools MCP** (thread/132): evaluar costo + ROI.
- **PR #130 A6 reglas_adicionales**: review + merge + deploy.
- **PR #114 journey templates editor**: review + merge.
- **Canary HSM critical path** (thread/123): aprobar defer estrategia durante/post + cancel-race fix.
- **STATE-drafts promotion** (este PR thread/143): copiar a root de cada repo post-aprobación.
- **Casa Chamán timeline**: cuándo Greeter prompt unhide (Q3 2026 placeholder).

## F. CONVENCIONES

- Threads naming: `XX-{author}-{topic}.md` sequential.
- Authors: `wc` (web claude — strategist), `cc` (claude code — generic), `cc-bot` (CC dedicado rdm-bot repo), `cc-data` (CC dedicado data pipeline), `alex` (humano).
- PR prefijos: A* = CC-Bot, D* = CC-Data (legacy; ahora sólo `feat/fix/chore/`).
- Branches: `feat/*`, `fix/*`, `chore/*`, `hotfix/*`, `debug/*`. No `claude/*` para ship-able (sólo CC sandbox).
- Commits: Conventional Commits (feat/fix/test/docs/chore + scope).
- Squash-merge PRs a main.
- `rdm-discussion` = comms layer + specs + threads, **NO código** (apps/packages no existen aquí).
- Idioma: español para threads/specs internos, mixto para anti-patterns enforced y referencias técnicas.
- Threads dupes (mismo número, dos archivos): aceptados cuando segundo deprecia primero (e.g. `105-...-p3.md` vs `105-...-p3-plus-2bugs.md`; `77-cc-bot-...` vs `77-cc-data-...`).

## G. LAST UPDATED + UPDATE PROTOCOL

- Last updated: 2026-05-23 (thread/182 WV-A: threads §A actualizados, Wave 1 status §A2 agregado).
- Por: CC-Bot vía DoIt thread/182 (branch `feat/megaspec-182-wave1-cleanup`).
- Próxima refresh: cuando se cierre/abra spec, o se agreguen ≥3 threads nuevos.
- **Update protocol:** todo PR a este repo toca §A si modifica threads/, toca §E si afecta decisión pendiente, toca §C si agrega ADR.
