# rdm-platform · STATE (draft)

> Conceptual repo. Architecture, vision, ADRs, foundations, module specs. **NO code.**
> Generado por CC vía DoIt thread/143 (2026-05-19).

---

## A. ESTADO ACTUAL

- **Estructura presente:**
  - `vision/` — `01-philosophy.md` (spirit + Alex mental model, ex thread/91), `02-wishlist.md` (5 módulos + 19 ideas, ex thread/89).
  - `decisions/` — `ADR-001-platform-shift.md` (Accepted 2026-05-17) + `README.md` (índice).
  - `foundations/` — `README.md` (F1 events bus / F2 observability / F3 PWA shell + Charter). **Spec-only, no implementación.**
  - `modules/` — 9 subfolders (`admin-tools`, `bot`, `content`, `data-pipeline`, `inventory`, `menu`, `pricing`, `staff-scheduling`, `tasks`). **Cada uno solo README.md placeholder.**
  - `coordination/` — `doit-template.md`, `roles-and-permissions.md`, `README.md` (vive aquí, NO en rdm-discussion).
  - `ideas/` — `README.md` (I1-I19 referenciados).
- **Lo que falta** (per thread/89 wishlist + thread/91 vision):
  - F1, F2, F3 implementación (foundations no shipped).
  - Per-module specs detallados (M1 Pricing tiene §1 en wishlist, los demás solo título).
  - ADR-002+ (sólo existe ADR-001).
  - Charter document (referenciado en foundations/README como pendiente).
  - Casa Chamán launch coordinator spec (mentioned thread/89 §0, no doc).
- **Estado foundations F1/F2/F3:** todas en estado *conceptual, not implemented* per `foundations/README.md`.

## B. RELACIÓN CON OTROS REPOS

- **`rdm-bot`** (code repo): platform define las decisiones arquitectónicas + module specs; rdm-bot las implementa. F1/F2/F3 cuando se shippen vivirán en rdm-bot (apps/packages), no aquí.
- **`rdm-discussion`** (comms layer): threads, specs operativos (`cc-instructions-*/`), ADRs operativas (decisions/ con 9 ADRs de implementación). Threads de origen para platform docs (89 → wishlist, 91 → philosophy) viven allá; aquí están las versiones canónicas migradas.
- **Permisos** (per `coordination/roles-and-permissions.md`):
  - Alex: RW everything
  - WC: RW (primary writer, brain mode)
  - **CC: RO** + feedback/ subfolder cuando se le pida. CC NO escribe aquí sin invitación explícita.
- **DoIt thread/143 nota:** este STATE-draft toca rdm-discussion (no rdm-platform), respetando boundary CC=RO.

## C. PENDING EVOLUTION (priorizado per thread/89 §0)

1. **ADR-002** charter o foundations seal — formalizar F1/F2/F3 como pre-req de M1.
2. **F1 events bus** spec final (8-12h CC effort, unblocks M1+I3/I5/I7/I8+M5 notifications).
3. **F2 observability lite** (4-6h CC effort, Logpush + dashboard).
4. **F3 staff PWA shell** (16-24h CC effort, unblocks M5/M4/M3).
5. **M1 Pricing Agent** spec deep — anti-orphan + last-minute discount + minStay matrix (5×5×4).
6. **M2 Menu** — referenciado pero sin spec detallado.
7. **M3 Inventory** — placeholder.
8. **M4 Staff scheduling** — depende F3.
9. **M5 Tasks module** — placeholder.
10. **Casa Chamán launch coordinator** — Q3 2026 trigger, sin spec.
11. **19 ideas I1-I19** — referenciadas en `ideas/README.md` pero no expandidas.

## D. PERMISOS Y BOUNDARIES

- **Repo es brainstorm conceptual** (per README.md línea 4). No deploys, no apps/, no packages/, no tests.
- **Alex**: decisions, priorities, anti-patterns, final authority.
- **WC-Platform** (Claude.ai brain mode): RW primary, arquitectura + foundations + conceptual specs.
- **WC-Implementation** (misma sesión, modo distinto): RW threads + specs operativos en rdm-discussion.
- **CC** (Claude Code): RO default. Escribe sólo `feedback/` subfolder cuando Alex/WC lo pide explícito. No PRs autónomos a este repo desde DoIt mode.
- **No commits con secrets, PII, tokens** (igual que los otros 2 repos).

## F. RECENT DECISIONS

- **F.4** (2026-05-20): audit-2026-Q2 cycle triggered. Sealed in `reports/audit-2026-Q2/README.md`.
- **F.5** (2026-05-21): **audit-2026-Q2 closure**. Synthesis 04- + ADR-003 (Accepted by Alex thread/155) + Wave 1 spec authored by WC-Platform + Wave 1 PRs T1-T7 merged by CC. Net outcomes:
  - **Plan stance locked**: stay Workers Free until 2 of 3 trigger conditions hit (ADR-003 §2.3).
  - **Cron strategy codified**: ADR-003 §2.2 decision matrix (native ≤30s drift / GH Actions external ≥5min drift).
  - **F2 spec reduced scope**: 6-9h → 3-5h. Logpush dropped (Paid-gated), heartbeats reuse `bot_config` table (no migration 0042 needed).
  - **ADR-001 §6 amended** with 8 new anti-patterns (PR #2 in this repo).
  - **`foundations/00-platform-constraints.md`** created as single source of truth for platform capabilities (links to ADR-003 §2.1).
  - 5 doc-drift propagations corrected (foundations/README, ADR-002 §Consequences, audit-2026-Q2 §0.1, threads/146 §F1.Q1 amendment, threads/149-followup §A amendment).
- **Next**: F2 ship reduced scope (3-5h), then M1 brain session.

## E. LAST UPDATED + UPDATE PROTOCOL

- Fecha generación: 2026-05-19. Revised 2026-05-21 by CC to add §F.5 audit-2026-Q2 closure entry per Wave 1 T8.
- Por: CC vía DoIt thread/143 (excepción autorizada al boundary CC=RO: snapshot informativo, NO modifica contenido de rdm-platform)
- Próxima refresh: cuando se mergee ADR-002, F1/F2/F3 spec final, o se complete primer module spec deep.
- **Update protocol:** WC actualiza este archivo cuando agrega ADR, foundation seal, o module spec deep. Alex actualiza §C priorización.
- Promote-to-root: Alex copia → `rdm-platform/STATE.md` post-PR aprobación. Si Alex prefiere mantener CC out-of-write para platform, este archivo puede vivir como referencia READ-ONLY desde rdm-discussion sin promote.
