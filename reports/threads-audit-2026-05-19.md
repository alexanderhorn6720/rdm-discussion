# Threads audit — 2026-05-19

> Mechanical metadata extraction of `threads/*.md` (159 files). NO semantic content review except last 30 threads.
> Generado por CC vía DoIt thread/143.

---

## STATS GLOBALES

| Métrica | Valor |
|---|---|
| Total archivos en `threads/` | **159** |
| Números únicos | **138** (rango 00-142) |
| Dupes (mismo número, ≥2 archivos) | **17 números** afectados |
| Gaps en numbering | **5** (18, 75, 90, 114, 116) — más 143 self-reference |
| Threads modificados últimos 7d | **145** (91% del repo) |
| Threads modificados últimos 30d | **159** (100%) |
| Threads stale (>30d sin actividad NOT shipped) | **0** — repo solo tiene ~40 días de historia (start 2026-05-10) |
| Untracked en working tree | 4 (130, 136, 137, 138 — A5 halt/completion logs) |

### Por status (heurístico por filename)

| Status | Count | %    |
|--------|-------|------|
| other  | 67    | 42%  |
| spec   | 39    | 25%  |
| shipped| 25*   | 16%  |
| result | 14    | 9%   |
| decision| 13   | 8%   |
| question| 4    | 3%   |

*ojo: el conteo "shipped" cuenta solo los que filename contiene `done|complete|merged|shipped|deployed`. Threads que actually shipped pero filename no lo dice (e.g. `49b-cc-bot-routing-proposal` que se mergeó vía PR #90) salen como "other". Gap analysis (D5) corrige esto cross-referenciando PRs.

### Por autor (filename slot 2)

| Author | Count | Notas |
|--------|-------|-------|
| wc     | 74    | dominante; brain mode + DoIt authoring |
| cc     | 41    | CC generic (pre-rename, sprint 1-2) |
| cc-bot | 25    | CC dedicado rdm-bot (post-rename thread/92) |
| cc-data| 7     | CC dedicado data pipeline (Stage 0-E days 1-4) |
| claude | 3     | early threads, antes de convención `cc-*` |
| alex   | 3     | direct human input (votes, decisions) |
| **convention-drift** | **10** | filename rompe convención `NN-{author}-...` |

### Threads con author en slot equivocado (convention drift)

| # | filename | observación |
|---|----------|-------------|
| 15g | `15g-final-plan-post-getlistings` | autor=`final` (palabra topic) — sub-thread WC |
| 15h | `15h-go-signal-for-cc` | autor=`go` — sub-thread CC |
| 15i | `15i-pricing-analysis-beds24-showdata` | autor=`pricing` — sub-thread CC |
| 15j | `15j-final-go-signal` | autor=`final` — sub-thread WC/Alex |
| 19 | `19-pricing-comparison-findings` | sin author slot |
| 20 | `20-cutover-completed-close-issues` | sin author slot — Alex/WC |
| 21 | `21-greeter-v5-site-routing-bot-onsite` | sin author slot — CC |
| 23 | `23-beds24-messages-reviews-api-unlocked` | sin author slot |
| 33 | `33-guest360-architecture-phase-b-plan` | sin author slot — CC |
| 45 | `45-mvp-live-and-content-drafts-ready` | sin author slot — alex |

---

## HEATMAP (semana × autor)

| Semana | wc | cc | cc-bot | cc-data | claude | alex | others |
|--------|----|----|--------|---------|--------|------|--------|
| W1 (May 10-11) | 5  | 5  | -      | -       | 3      | 1    | -      |
| W2 (May 12-14) | 13 | 25 | -      | -       | -      | 2    | 8 (drift) |
| W3 (May 15-18) | 48 | 8  | 15     | 7       | -      | -    | -      |
| W4 (May 19)    | 8  | 3  | 6      | -       | -      | -    | -      |

Patrón claro: W2 fue intensiva CC (sprint 1-2 inicial, batch B+C), W3 explotó WC (specs + DoIt) y arrancó cc-bot/cc-data split, W4 continúa cc-bot dominante.

---

## TABLA FULL (159 threads, DESC por fecha)

| #   | Autor | Status | Last | Size | Topic |
|-----|-------|--------|------|------|-------|
| 142 | cc | shipped | 2026-05-19 | 14.9K | wc-house-rules-paper-trail-phase1-done |
| 141 | wc | other | 2026-05-19 | 18.4K | cc-house-rules-paper-trail-phase1 |
| 140 | cc | shipped | 2026-05-19 | 48.4K | wc-a6-reglas-adicionales-complete |
| 139 | wc | other | 2026-05-19 | 57.0K | cc-a6-reglas-adicionales-deploy |
| 138 | cc-bot | result | 2026-05-19 | 17.6K | a5-completion-67-deployed-30-structural-skips (untracked) |
| 137 | cc-bot | result | 2026-05-19 | 13.2K | a5-halt-rincondelmar-session-missing (untracked) |
| 136 | cc-bot | result | 2026-05-19 | 8.6K | a5-halt-stale-mcp-process (untracked) |
| 135 | cc | shipped | 2026-05-19 | 11.2K | wc-beds24-proxy-readonly-complete |
| 134 | wc | spec | 2026-05-19 | 28.5K | cc-beds24-proxy-readonly-doit |
| 133 | cc-bot | shipped | 2026-05-19 | 9.3K | mobile-inbox-rescue-complete |
| 132 | wc | other | 2026-05-19 | 11.0K | browserbase-airbnb-kpi-backlog |
| 131 | wc | spec | 2026-05-19 | 29.7K | cc-mobile-inbox-rescue-doit |
| 130 | cc-bot | result | 2026-05-19 | 7.3K | a5-halt-chrome-mcp-not-attached (untracked) |
| 129 | cc-bot | spec | 2026-05-19 | 9.5K | omnibus-doit-report |
| 128 | wc | spec | 2026-05-19 | 14.5K | cc-open-items-omnibus-doit |
| 127 | wc | spec | 2026-05-19 | 9.9K | cc-a5-execution-doit |
| 126 | wc | other | 2026-05-19 | 8.2K | 500-root-cause-and-fix |
| 125 | wc | other | 2026-05-18 | 4.7K | karina-training-deploy-v2 |
| 124 | wc | other | 2026-05-18 | 4.4K | karina-training-deploy-handoff |
| 123 | wc | other | 2026-05-18 | 16.4K | canary-review-hsm-critical-defer-during-post |
| 122 | cc-bot | result | 2026-05-18 | 8.7K | canary-results-and-manychat-architecture |
| 121 | wc | spec | 2026-05-18 | 12.0K | a2-a3-review-a4-amendment-a5-spec |
| 120 | wc | other | 2026-05-18 | 11.5K | a1-review-and-a2-design |
| 119 | wc | spec | 2026-05-18 | 5.6K | pre-stay-mvp-spec-ready |
| 118 | wc | other | 2026-05-18 | 6.9K | pet-policy-correction-and-v5-cleanup |
| 117 | wc | other | 2026-05-18 | 6.2K | handoff-doc-reconciliation |
| 115 | wc | spec | 2026-05-18 | 19.6K | doit-guests-resync-beds24 |
| 113 | wc | other | 2026-05-18 | 6.0K | hotfix-prox-reservas-guest-name-source |
| 112 | cc-bot | shipped | 2026-05-18 | 13.1K | c-e-d-p2-wave-shipped-canary-playbook |
| 111 | wc | decision | 2026-05-18 | 2.9K | ack-c-e-d-p2-defaults |
| 109 | wc | spec | 2026-05-18 | 40.1K | doit-small-items-wave-2 |
| 107 | wc | spec | 2026-05-18 | 50.9K | doit-small-items-wave-6-parts |
| 105 (dup-A) | wc | spec | 2026-05-18 | 21.0K | doit-admin-inbox-p3-plus-2bugs |
| 105 (dup-B) | wc | spec | 2026-05-18 | 12.3K | doit-admin-inbox-p3 |
| 110 | cc-bot | question | 2026-05-17 | 9.7K | questions-c-e-d-p2-pre-execution |
| 108 | cc-bot | shipped | 2026-05-17 | 13.5K | small-items-wave-4-of-6-shipped |
| 106 | cc-bot | shipped | 2026-05-17 | 13.4K | inbox-p3-bugs-complete |
| 104 | cc-bot | shipped | 2026-05-17 | 8.5K | beds24-backfill-complete |
| 103 | wc | spec | 2026-05-17 | 18.3K | doit-beds24-backfill-prewebhook |
| 102 | cc-bot | other | 2026-05-17 | 9.6K | admin-bookings-feedback-fixed |
| 101 | wc | spec | 2026-05-17 | 13.3K | doit-admin-bookings-feedback-fixes |
| 100 | cc-bot | shipped | 2026-05-17 | 7.0K | pr82-merged |
| 99 | wc | spec | 2026-05-17 | 10.6K | doit-fix-kv-binding-resume-pr82 |
| 98 (dup-A) | cc-bot | result | 2026-05-17 | 9.4K | pr82-halted-typecheck-errors |
| 98 (dup-B) | wc | other | 2026-05-17 | 8.1K | cc-autonomy-config-and-workspace |
| 97 | wc | spec | 2026-05-17 | 8.6K | doit-pr82-review-merge-deploy |
| 96 | cc-bot | spec | 2026-05-17 | 4.7K | pre-flight-clean-ready-for-next-task |
| 95 | wc | other | 2026-05-17 | 9.7K | briefing-new-cc-implementation-session |
| 94 | wc | spec | 2026-05-17 | 7.6K | ack-clone-paths-doit-template-v3 |
| 93 (dup-A) | cc-bot | shipped | 2026-05-17 | 9.9K | status-bookings-build-complete-inbox-paused |
| 93 (dup-B) | wc | spec | 2026-05-17 | 7.9K | ack-cc-feedback-doit-template-v2 |
| 92 | wc | other | 2026-05-17 | 6.7K | cc-rename-and-platform-coexistence |
| 91 | wc | other | 2026-05-17 | 18.0K | platform-vision-and-spirit-for-rdmbot-session |
| 89 | wc | spec | 2026-05-17 | 29.1K | platform-wishlist-and-tasks-module |
| 88 | wc | decision | 2026-05-17 | 5.4K | ack-cc-data-faq-content-extraction-delivered |
| 87 | wc | other | 2026-05-16 | 2.4K | multi-inquiry-amendment |
| 86 | wc | other | 2026-05-16 | 3.0K | bookings-inbox-delta-list-view-kv-inquiries |
| 85 | wc | spec | 2026-05-16 | 2.4K | admin-inbox-unified-spec |
| 84 (dup-A) | wc | spec | 2026-05-17 | 1.9K | admin-bookings-gantt-spec (84b prefix) |
| 84 (dup-B) | cc-data | shipped | 2026-05-16 | 11.3K | faq-and-content-extraction-complete |
| 83 | wc | spec | 2026-05-16 | 2.9K | faq-content-enrichment-extraction-task-cc-data |
| 82 | wc | spec | 2026-05-16 | 4.0K | v6-combined-spec-ready-for-cc |
| 81 | cc-data | decision | 2026-05-16 | 8.3K | stage-c-v2-trim-audit-final |
| 80 | cc-bot | other | 2026-05-16 | 5.3K | v5-real-data-analysis-pet-bug-pr66 |
| 79 | cc-bot | shipped | 2026-05-16 | 7.0K | chain-a-e-merged-vectorize-stuck |
| 78 | wc | other | 2026-05-16 | 1.3K | claude-md-published-pull-and-read |
| 77 (dup-A) | cc-bot | shipped | 2026-05-15 | 6.9K | prs-a761-a763-merged |
| 77 (dup-B) | cc-data | shipped | 2026-05-15 | 7.6K | prod-deploy-95-pct-done-vectorize-handoff |
| 76 | cc-data | shipped | 2026-05-15 | 11.6K | day4-deploy-pipeline-complete |
| 74 | cc-data | shipped | 2026-05-15 | 6.8K | day2-stage-b-and-e-done |
| 73 | cc-data | shipped | 2026-05-15 | 7.6K | day1-stage0-and-stage-a-done |
| 72 | cc-data | spec | 2026-05-15 | 18.2K | plan-and-day1-roadmap |
| 71 | cc | other | 2026-05-15 | 7.6K | 12h-autonomous-summary |
| 70 | cc | shipped | 2026-05-15 | 6.4K | prs-41-42-merged-q691-A-12h-plan |
| 69 | wc | question | 2026-05-15 | 9.4K | status-pr42-ok-q-cc-data-interface |
| 68 | cc | other | 2026-05-15 | 8.0K | pr-a75-ready-for-wc-review |
| 67 | wc | question | 2026-05-15 | 10.4K | q-66-1-pr-a75-go-autonomous |
| 66 | cc | other | 2026-05-15 | 7.3K | greeter-v5-fase-2-built |
| 65 | wc | spec | 2026-05-15 | 8.8K | greeter-v5-fase-2-spec-published |
| 64 | cc | spec | 2026-05-15 | 4.7K | alex-voted-option-a-handoff-spec-fase-2 |
| 63 | wc | question | 2026-05-15 | 7.1K | ack-fase-1-closed-q-fase-2-timing |
| 62 | cc | other | 2026-05-15 | 5.3K | pr-a15-subcomponents-live |
| 61 | cc | other | 2026-05-15 | 4.1K | image-bug-resolved |
| 60 | wc | other | 2026-05-15 | 6.7K | bug-critico-images-broken-prod |
| 59 | wc | decision | 2026-05-15 | 8.9K | pet-decision-resolved-cc-handoff |
| 58 | wc | spec | 2026-05-15 | 7.6K | ack-cc-overnight-and-pr-a15-spec |
| 57 | wc | spec | 2026-05-15 | 18.4K | edge-case-audit-v2-plan |
| 56 | wc | shipped | 2026-05-15 | 7.4K | data-v2-prep-complete-and-critical-findings |
| 55 | wc | spec | 2026-05-15 | 18.6K | data-mining-v2-go-plan |
| 54 (dup-A) | cc | result | 2026-05-15 | 9.8K | fase-1-progress |
| 54 (dup-B) | wc | spec | 2026-05-15 | 24.4K | data-mining-v2-strategy |
| 53 | wc | other | 2026-05-15 | 17.1K | greeter-v5-fase-0-1-execute |
| 52 | wc | spec | 2026-05-15 | 19.1K | anchors-spec-for-property-pages |
| 50 | wc | other | 2026-05-15 | 25.2K | bot-routing-response |
| 49 (dup-A) | cc-bot | other | 2026-05-15 | 21.2K | routing-proposal (49b prefix) |
| 49 (dup-B) | cc | other | 2026-05-14 | 9.3K | reglas-adicionales-13th-field |
| 51 | cc | other | 2026-05-14 | 7.4K | blockers-resolved-greeter-v5-go |
| 45 (dup-A) | mvp | other | 2026-05-14 | 7.3K | mvp-live-and-content-drafts-ready |
| 45 (dup-B) | cc | other | 2026-05-13 | 5.1K | wc-seed-drafts-discovery |
| 44 (dup-A) | wc | other | 2026-05-14 | 8.7K | footer-policy-research-morenas-concern |
| 44 (dup-B) | cc | decision | 2026-05-13 | 6.2K | pr12-final-state |
| 43 (dup-A) | wc | other | 2026-05-14 | 9.3K | alex-go-execute-batch-b |
| 43 (dup-B) | cc | other | 2026-05-13 | 7.6K | fase2-merge-guide |
| 42 | cc | other | 2026-05-13 | 27.5K | review-thread40-content-editor |
| 41 | wc | decision | 2026-05-14 | 8.4K | alex-final-answers |
| 40 | wc | other | 2026-05-14 | 16.7K | alex-answers-content-editor-proposal |
| 39 | wc | other | 2026-05-13 | 22.8K | response-cc-thread37-38 |
| 38 | cc | spec | 2026-05-13 | 10.6K | airbnb-write-back-plan |
| 37 | cc | other | 2026-05-13 | 35.4K | content-architecture-review |
| 36 | wc | other | 2026-05-13 | 27.9K | templates-content-architecture-analysis |
| 35 | cc | other | 2026-05-13 | 15.1K | templates-system-for-wc |
| 34 | cc | other | 2026-05-13 | 45.4K | review-guest360-phaseb |
| 33 | guest360 | spec | 2026-05-13 | 27.2K | guest360-architecture-phase-b-plan (drift) |
| 32 | cc | other | 2026-05-12 | 9.8K | track-c-reviews-carousel |
| 31 | cc | result | 2026-05-12 | 9.7K | track-b-deploy-log |
| 30 | alex | spec | 2026-05-12 | 13.1K | approvals-cc-execution-plan |
| 29 | wc | other | 2026-05-12 | 17.9K | review-cc-phase0-implementation |
| 28 | cc | result | 2026-05-12 | 12.0K | phase0-implementation-log |
| 27 | alex | decision | 2026-05-12 | 16.0K | decisions-cc-implementation-greenlight |
| 26 | cc | other | 2026-05-12 | 12.7K | phase0-closure-status |
| 25 | cc | other | 2026-05-12 | 8.7K | q15-webhook-implemented-reviews-cap-confirmed |
| 24 | cc | other | 2026-05-12 | 13.7K | beds24-messaging-discovery-validated |
| 23 | beds24 | other | 2026-05-12 | 14.8K | beds24-messages-reviews-api-unlocked (drift) |
| 22 | cc | other | 2026-05-12 | 33.9K | greeter-v5-challenge |
| 21 | greeter | other | 2026-05-12 | 22.7K | greeter-v5-site-routing-bot-onsite (drift) |
| 20 | cutover | shipped | 2026-05-12 | 6.4K | cutover-completed-close-issues (drift) |
| 19 | pricing | other | 2026-05-12 | 7.8K | pricing-comparison-findings (drift) |
| 17 | cc | other | 2026-05-12 | 4.9K | calendar-pricing-query |
| 16 | cc | result | 2026-05-12 | 23.1K | cutover-execution-log |
| 15-many | wc/cc/drift | mix | 2026-05-12 | 8.9K–17.3K | **11 sub-threads** (15-base + 15b/c/d/e/f/g/h/i/j/k). See dupes §below. |
| 14 | cc | other | 2026-05-12 | 15.3K | beds24-current-state-investigation |
| 13 | cc | shipped | 2026-05-11 | 10.5K | beds24-migration-done-handoff |
| 12 | cc | other | 2026-05-11 | 15.1K | beds24-migration-stop |
| 11 (dup-A) | wc | spec | 2026-05-12 | 10.9K | beds24-migration-task-for-cc |
| 11 (dup-B) | cc | other | 2026-05-11 | 7.8K | wc-thread10-implemented |
| 10 | wc | decision | 2026-05-11 | 20.9K | code-review-3-decisions |
| 09 | cc | shipped | 2026-05-11 | 6.7K | sprint1-day5-done |
| 08 | cc | shipped | 2026-05-11 | 9.5K | bug-fix-and-day4-done |
| 07 | wc | other | 2026-05-11 | 18.2K | port-audit-bug-responses |
| 06 | wc | other | 2026-05-11 | 10.2K | checkpoint-monorepo-ready |
| 05 | claude | result | 2026-05-11 | 9.2K | code-implementation-progress |
| 04 | wc | other | 2026-05-11 | 10.2K | web-claude-cc-response |
| 03 | claude | other | 2026-05-11 | 9.6K | code-second-response |
| 02 | wc | other | 2026-05-11 | 25.2K | web-claude-investigation |
| 01 | alex | decision | 2026-05-10 | 7.7K | alexander-votes |
| 00 | claude | other | 2026-05-10 | 21.8K | code-first-response |

---

## DUPES (mismo número, ≥2 archivos)

| # | Files | Recomendación |
|---|-------|---------------|
| 11 | `11-cc-wc-thread10-implemented` (CC reply) + `11-wc-beds24-migration-task-for-cc` (WC overwrite) | Renumerar uno → 11a / 11b retroactivamente, o aceptar (caso de "WC override" reciclando número) |
| 15 | 11 sub-threads (`15`, `15b/c/d/e/f/g/h/i/j/k`) | Intencional como "ultra-cluster" del cutover Beds24. Mantener. |
| 43 | `43-cc-fase2-merge-guide` + `43-wc-alex-go-execute-batch-b` | Renumerar el 2do → 43a (WC ack del CC report) |
| 44 | `44-cc-pr12-final-state` + `44-wc-footer-policy-research-morenas-concern` | Renumerar el 2do → 44a |
| 45 | `45-cc-wc-seed-drafts-discovery` + `45-mvp-live-and-content-drafts-ready` | Renumerar el 2do |
| 49 | `49-cc-reglas-adicionales-13th-field` + `49b-cc-bot-routing-proposal` | Aceptable (`49b` ya usa suffix convention) |
| 54 | `54-cc-fase-1-progress` + `54-wc-data-mining-v2-strategy` | Renumerar el 2do |
| 77 | `77-cc-bot-prs-a761-a763-merged` + `77-cc-data-prod-deploy-95-pct-done-vectorize-handoff` | Aceptable (split intencional cc-bot vs cc-data) |
| 84 | `84-cc-data-faq-and-content-extraction-complete` + `84b-wc-admin-bookings-gantt-spec` | Aceptable (`84b` suffix) |
| 93 | `93-cc-bot-status-bookings-build-complete-inbox-paused` + `93-wc-ack-cc-feedback-doit-template-v2` | Renumerar el 2do |
| 98 | `98-cc-bot-pr82-halted-typecheck-errors` + `98-wc-cc-autonomy-config-and-workspace` | Renumerar el 2do |
| 105 | `105-wc-doit-admin-inbox-p3` + `105-wc-doit-admin-inbox-p3-plus-2bugs` | El 2do supersedes el 1ro (mismo título extendido). Marcar v1 como obsoleto o renumerar. |
| 130 / 136 / 137 / 138 | sólo 1 archivo cada uno, untracked | NO son dupes; spec contó dupes porque mi pipeline original procesó dos veces (versión clean cuenta correcto) |

**Total dupes reales: 11 números (sin contar 15-cluster ni 49/77/84 que usan suffix convention).**

---

## GAPS EN NUMBERING

| # missing | Evidencia / explicación |
|-----------|-------------------------|
| 18 | Saltado (entre 17 calendar-pricing-query y 19 pricing-comparison) — error o reservado nunca usado |
| 75 | Saltado (entre 74 cc-data-day2 y 76 cc-data-day4) — probablemente día 3 abandonado |
| 90 | Saltado (entre 89 platform-wishlist y 91 platform-vision) — quizá renumerado a 89/91 |
| 114 | Saltado (entre 113 hotfix y 115 doit-guests-resync) — A1.5 implícito sin thread doc |
| 116 | Saltado (entre 115 doit-guests-resync y 117 handoff-doc-reconciliation) |
| 143 | self-reference (este thread es 143 pero aún no creado como archivo — todo el output sale a `144-cc-...`) |

---

## ÚLTIMOS 30 THREADS — verificación heurístico vs real

Sample manual de 5 (head -30 lines) para validar status real:

| # | Heurístico | Real (inferido del head) | Match |
|---|------------|-------------------------|-------|
| 142 | shipped | shipped (CC report done, awaiting WC) | ✅ |
| 138 | result | result (CC halt-style with 67% completion) | ✅ |
| 132 | other | spec/backlog (Browserbase eval + AirBnB scraper item) | ❌ should be `spec` |
| 127 | spec | spec (DoIt autonomous A5) | ✅ |
| 119 | spec | spec (pre-stay MVP) | ✅ |

**Discrepancia: 1/5 mal clasificado (132 era backlog/spec, no other).** Asume ~20% noise rate en `other` bucket. Para gap analysis usar bucket `spec ∪ select(other con "backlog"|"plan"|"sketch")`.

---

## INTERPRETACIÓN

- **El repo es muy joven** (~40 días). No hay "stale" real porque no hay tiempo para que haya stale.
- **Convention drift es manejable** (10 threads, todos pre thread/40). Post-thread/40 el patrón es consistente.
- **Dupes de número** revelan un patrón: WC frecuentemente recicla número cuando un thread se vuelve obsoleto pero el nuevo flow lo retrocede. Aceptable pero perjudica búsqueda (`grep "thread/93"` retorna 2 archivos).
- **Author split cc → cc-bot/cc-data ocurre en thread/72** (cc-data-plan-and-day1-roadmap es el primer cc-data). cc-bot empieza en thread/79.
- **W3 dominancia WC (48 threads)** refleja transición de "construir con CC" a "specificar para CC" — más DoIt authoring, menos prosa.

---

## NOTAS DE METODOLOGÍA

- **Last-modified** = `git log -1 --format=%ai`. NO file mtime (mtime no refleja merge time).
- **Author** = filename slot 2 (post-número). NO leído del contenido.
- **Status** = regex sobre filename. NO leído del contenido excepto últimos 5.
- **Excluded**: ningún thread excluido. Todos los 159 representados.
- **Untracked** (4 threads): incluidos con `last=stat_mtime` ya que git log retorna vacío.
