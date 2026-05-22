---
thread: 179
author: WC
date: 2026-05-22
topic: backlog-priorizado-master-checklist-alex
mode: brain (synthesis + actionable)
status: open-for-alex-prioritization
inputs:
  - reports/2026-05-22-META-A1..A9 (CC audit, PR rdm-discussion#12)
  - thread/178 (WC brain ultra synthesis)
  - threads 171-178 (synthesis chain)
deliverable: master backlog priorizado mobile-friendly con checkboxes para Alex marcar prioridades
nota_alex: "Marca con [x] los items que apruebas. Reordena por taps si quieres. Tachones = no hacer. Esto es backlog vivo — re-genera cuando agotes items."
---

# Master Backlog — RdM (priorizado por impacto×esfuerzo)

**Cómo usar este thread:** cada item tiene checkbox. Marca `[x]` los que aprueba ejecutar. Tacha con `~~strikethrough~~` los que decide NO hacer. Esfuerzo CC = horas reales (calibrado vs estimate WC original 10-15× over). Esfuerzo Alex = decisión + revisión.

---

## 🔴 TIER 0 — bloqueadores Alex (sin esto, mucho downstream se atasca)

### 0.1 G7 — Vote thread/148 sobre F1/F2/F3 + 7 items
- [ ] **APROBAR / VOTAR**
- **Impacto**: 🔴 critical-path. Sin esto: F2 ship → F1 ship → F3 ship → M1 Pricing → M5 Tasks → ideas I3/I5/I7/I8 todo bloqueado.
- **Esfuerzo Alex**: 30 min lectura del thread + voto sobre 7 sub-items
- **Esfuerzo CC post-voto**: ~10-15h CC para F2 ship (después F1, F3 secuencial)
- **Bloqueador upstream**: ninguno
- **Bloqueador downstream**: M1 Pricing entero, foundations completas
- **Notas**: thread/148 está abierto desde 2026-05-19 (3d). F2 spec necesita migration remap antes (ver 1.2 abajo)

### 0.2 G8 — Analytics activation (variant)
- [ ] **APROBAR / VOTAR**
- **Impacto**: 🟡 medio. Sin esto: tracker emit + GA4 events + GSC verify pendientes
- **Esfuerzo Alex**: 5 min — picks variant entre 3 opciones:
  - A) CF Web Analytics only (cookieless, simple, gratis)
  - B) CF + GA4 (más data, cookies, free tier GA4)
  - C) CF + GA4 + Google Search Console (full stack)
- **Esfuerzo CC post-voto**: 1h (env vars + tracker emit)
- **Bloqueador downstream**: A/B tests readout, conversion tracking

### 0.3 G6 — PDF endpoint removal
- [ ] **APROBAR**
- **Impacto**: 🟡 medio. Cleanup de `/reglas/{slug}/pdf` que está roto y no se usa
- **Esfuerzo Alex**: 5 min ack a WC para que escriba spec
- **Esfuerzo CC**: 1h (spec + ejecución)
- **Bloqueador downstream**: cleanup recursivo de PRs de fix relacionados

### 0.4 PR #114 — Journey templates editor (open 4d)
- [ ] **REVIEW + merge** ó [ ] **close con razón**
- **Impacto**: 🟡 medio. 3042 LoC, journey templates D1 override
- **Esfuerzo Alex**: 30 min review en GitHub
- **Notas**: contiene "duplicate bulk-approve logic" según memoria. WC había flagged HOLD pendiente review

### 0.5 PR #130 — A6 reglas adicionales deploy (open 3d)
- [ ] **REVIEW + merge** ó [ ] **close con razón**
- **Impacto**: 🟡 medio. 154 LoC, deploy de reglas adicionales
- **Esfuerzo Alex**: 20 min review
- **Notas**: pendiente desde 2026-05-19

### 0.6 PR #159 — Telegram pago-recibido notifications (open hoy)
- [ ] **REVIEW + merge** (probable auto-merge ya activo)
- **Impacto**: 🟢 bajo. 481 LoC, notification feature
- **Esfuerzo Alex**: 10 min review
- **Notas**: PR creado hoy 2026-05-22, posiblemente ya mergeado por auto-merge

### 0.7 rdm-discussion PR #8 — thread/158 CC tech validation (open)
- [ ] **REVIEW + merge** ó [ ] **close**
- **Impacto**: 🟢 bajo. 157 LoC docs only
- **Esfuerzo Alex**: 10 min review

### 0.8 rdm-discussion PR #10 — thread/163 DoIt final report (open)
- [ ] **REVIEW + merge**
- **Impacto**: 🟢 bajo. 178 LoC docs only
- **Esfuerzo Alex**: 10 min review

---

## 🟠 TIER 1 — Wave 1 cleanup (quick wins, ~2h CC total)

### 1.1 W1 — `scripts/new-thread.sh` real con flock + retry
- [ ] **APROBAR ejecución**
- **Impacto**: 🔴 estructural. Cierra futuras colisiones de threads (no las históricas)
- **Esfuerzo CC**: 20 min (~$0.50)
- **Solución**: ya cubierto por thread/175 T1. Mirror de `scripts/new-migration.sh` que sí existe y funciona
- **Verificación**: test atomic claim con 2 invocaciones concurrentes → exit 0 ambas, números distintos consecutivos
- **Nota**: el script vive en `rdm-discussion/scripts/` (porque threads viven ahí); wrapper delegador en `rdm-bot/scripts/`

### 1.2 W2 — STATE.md cleanup (rdm-bot)
- [ ] **APROBAR**
- **Impacto**: 🟡 medio. Stop misinforming new CC sessions
- **Esfuerzo CC**: 10 min (~$0.20)
- **Cambios**:
  - §A apps list: +`worker-feedback` (5to app shipped, nunca propagado)
  - §D: remove entry "0039 collision pending" (resuelto PR #140 hace 1d)
  - §G: remove G9 (duplicado de §D)
  - §A "Last deploys captured": refrescar fechas — todas tienen 10+d staleness vs realidad

### 1.3 W3 — CLAUDE.md anti-pattern "WC NO implementa"
- [ ] **APROBAR**
- **Impacto**: 🟡 medio. Propagation gap de STATE.md §E que no llegó a CLAUDE.md
- **Esfuerzo CC**: 5 min (~$0.10)
- **Cambio**: añadir línea en sección Anti-patterns: "WC NO implementa código en rdm-bot ni rdm-platform — solo specs + threads + brain mode (Alex correction 2026-05-19)"

### 1.4 W4 — decisions/03 PriceLabs status header
- [ ] **APROBAR**
- **Impacto**: 🟢 bajo. Stop stale guidance
- **Esfuerzo CC**: 2 min (~$0.05)
- **Cambio**: añadir frontmatter `status: REVISED 2026-05-XX` + nota: "Custom agent kept per VISION §Principios 7; PriceLabs NOT purchased"

### 1.5 W5 — Archive shipped cc-instructions/ specs
- [ ] **APROBAR**
- **Impacto**: 🟢 bajo. -90% noise en active dir, mejora signal/noise para nuevas sesiones
- **Esfuerzo CC**: 30 min (~$1)
- **Cambio**: move 22 specs shipped (per A6 §8) de `cc-instructions/`, `cc-instructions-bot/`, `cc-instructions-data/`, `wc-instructions/` a sus respectivos `archive/`
- **Notas**: A6 §8 ya identifica cuáles son shipped (Greeter v5/v6, batch B, Karina onboarding, vectorize, etc)

### 1.6 W6 — Archive OPEN_QUESTIONS.md PR1/2/3 era
- [ ] **APROBAR**
- **Impacto**: 🟢 bajo. 22KB → ~5KB activo. Alex queue becomes visible
- **Esfuerzo CC**: 20 min (~$0.50)
- **Cambio**: move 22KB histórico → `docs/archive/OPEN_QUESTIONS-2026-05-08-PR1-PR3.md`. Crear nuevo `OPEN_QUESTIONS.md` con solo net-pending de A7 §6 (Q4, Q6, Q7, Q8, Q10, Q17, Q19 — ~7 items)

### 1.7 W7 — Batch delete 41 merged branches
- [ ] **APROBAR**
- **Impacto**: 🟢 bajo. Limpieza repo
- **Esfuerzo CC**: 15 min (~$0.30)
- **Cambio**: `gh api /repos/.../branches` cross-ref con A8 §3 lista → `gh api -X DELETE` cada una. Skip si tiene PR open.

**TOTAL Tier 1**: ~2h CC, <$3 USD. Una sola PR con todo el cleanup. Spec separada en thread/180 si Alex aprueba el tier completo.

---

## 🟡 TIER 2 — Specs medias (1h cada, no ejecutables hasta aprobar)

### 2.1 F2 spec refactor — migration remap
- [ ] **APROBAR WC-Platform redacta**
- **Impacto**: 🟡 medio. Pre-req para F2 ship (que es pre-req para todo lo demás)
- **Esfuerzo WC-Platform**: 1h brain mode
- **Esfuerzo CC**: 0 — es solo spec update
- **Problema**: F2 reserva migration 0042 = `cron_heartbeats`. Reality 0042 = `feedback_system` (thread/161, ya en filesystem). F2 no puede shippearse sin remap.
- **Solución**: audit migrations 0042-0045, F2 reserva 0046+, ejecutar via `scripts/new-migration.sh` cuando ship
- **Bloqueador upstream**: ninguno
- **Bloqueador downstream**: F2 ship (depende también de G7)

### 2.2 Decisions stores policy doc
- [ ] **VOTO**: A / B / C / espero
- **Impacto**: 🟡 medio. Stop split-brain risk
- **Esfuerzo WC-Platform**: 30 min brain
- **3 opciones**:
  - **A) Freeze legacy** (voto WC): rdm-discussion/decisions/01-09 = v1 frozen, todo nuevo va a rdm-platform/decisions/. Simple, una source forward
  - **B) Migrar formato**: convertir 01-09 a YAML frontmatter, mantener split por scope. Preserva historia pero más mantenimiento
  - **C) Consolidar**: mover todo a rdm-platform/decisions/, legacy/ subdir. Single source pero migration cost

### 2.3 apps/admin PWA decision
- [ ] **VOTO**: rewrite VS commit
- **Impacto**: 🟡 medio. Stop 5-doc fiction (VISION + ADR-04 + ADR-07 + OPEN_QUESTIONS + roadmap)
- **Esfuerzo Alex + WC-Platform**: 1h discusión + 1h WC-Platform redact
- **2 opciones**:
  - **Rewrite**: VISION + ADRs reflejan realidad "admin = subpages de apps/web". Esfuerzo: 1h docs edit
  - **Build separate**: efectivamente migrar admin a `apps/admin/` PWA con manifest. Esfuerzo: 16-24h CC + planning

### 2.4 Thread metadata format universal
- [ ] **APROBAR ejecución**
- **Impacto**: 🟡 medio. Reliable cross-referencing
- **Esfuerzo CC**: 2h (~$3)
- **Problema**: 7/209 threads tienen YAML frontmatter, 202 usan legacy `**Date** / **Author**` bold-header. Parser dual-mode hoy
- **Solución**: one-shot migrator script + adopt YAML universal forward
- **Alternativa**: declarar legacy como "v1 frozen", solo nuevos requieren YAML. Mismo efecto sin migration burden

### 2.5 ADR-002 multi-WC formalization (POST test empírico)
- [ ] **ESPERAR test empírico primero** ó [ ] **redactar ya**
- **Impacto**: 🟢 bajo (mientras no se ejecute multi-WC físico). 🟡 medio si Alex decide ya
- **Bloqueador upstream**: test empírico 1-2 semanas Q1 voto Alex thread/174
- **Notas**: voto Alex Q1 fue "SÍ test empírico". Defer hasta tener data

---

## 🟢 TIER 3 — Estratégico foundations (post G7)

### 3.1 F2 observability ship
- [ ] **AUTORIZAR ejecución** (depende de G7 + 2.1 above)
- **Impacto**: 🔴 critical-path. Bloquea F1, F3, M1, M5
- **Esfuerzo CC**: 6-9h (per A7 §4 P3)
- **Bloqueador upstream**: G7 voto Alex + 2.1 spec refactor
- **Bloqueador downstream**: F1 events bus → F3 staff PWA → M1 Pricing
- **Notas**: ADR-002 Accepted 2026-05-20 pero NO shipped. Spec necesita migration remap antes (2.1)

### 3.2 F1 events bus ship
- [ ] **AUTORIZAR ejecución** (post F2)
- **Impacto**: 🔴 critical-path
- **Esfuerzo CC**: 12-16h (per A7 §4 P2)
- **Bloqueador upstream**: F2 ship
- **Bloqueador downstream**: M1, M5, ideas I3/I5/I7/I8

### 3.3 F3 staff PWA shell
- [ ] **AUTORIZAR ejecución** (post F1)
- **Impacto**: 🟡 medio
- **Esfuerzo CC**: 22-30h email-only (per A7 §4 P4); más con APK wrap
- **Bloqueador upstream**: F1 ship
- **Bloqueador downstream**: M3, M4, M5 modules

### 3.4 A5 Airbnb 67% completion
- [ ] **CONTINUAR** ó [ ] **ARCHIVAR**
- **Impacto**: 🟡 medio. Content sync to Airbnb listings stuck
- **Esfuerzo CC**: 5-10 días + Alex coord (Better Auth session en Chrome:9222)
- **Estado**: branch `feat/a5-airbnb-bulk-approve-writeback` existe, halt threads 130/136/137/138 untracked
- **Notas**: requiere Alex provisioning AirBnB login. Si no es prioritario, mejor archivar formal

### 3.5 Browserbase AirBnB KPI scraper
- [ ] **APROBAR** ó [ ] **DEFERIR**
- **Impacto**: 🟡 medio. KPIs no disponibles sin esto
- **Esfuerzo CC**: 8-12h + Browserbase $5-20/mo
- **Notas**: thread/132. Alternativa al A5 manual approach

### 3.6 Stage 2 ManyChat sunset → WABA propia
- [ ] **APROBAR planning** ó [ ] **DEFERIR Q3+**
- **Impacto**: 🔴 estratégico largo plazo. Ownership de canal WA
- **Esfuerzo**: 30+ días CC + Meta WABA approval (semanas)
- **Bloqueador**: necesita planning antes de exec. Decisión Alex business

---

## ⚪ TIER 4 — Estructural largo plazo (post Wave 1, post foundations)

### 4.1 "STATE como contrato" — status field + drift validator
- [ ] **APROBAR Q3+**
- **Impacto**: 🔴 estructural. Cura del patrón raíz identificado en thread/178 §2
- **Esfuerzo CC**: 5-10 días
- **Componentes**:
  - Status field machine-readable en docs canonical (Accepted/Implemented/Live/Superseded/Stale)
  - CI validator: claims en STATE.md vs filesystem reality
  - Self-review checklist: si tu PR cambia X, debes actualizar Y
  - ADR lifecycle explícito (Accepted ≠ Shipped)
- **Notas**: NO es Wave 1. Es work foundations sobre cómo el proyecto se documenta a sí mismo

### 4.2 META audit re-run mensual
- [ ] **APROBAR cron**
- **Impacto**: 🟢 bajo. Visibility recurrente del pipeline health
- **Esfuerzo CC**: <1h (scripts ya existen en `reports/.audit-scratch/`)
- **Notas**: pattern de CC thread/176 — Python reproducible. Cron mensual o on-demand

### 4.3 Casa Chamán Q3 2026 contingency
- [ ] **N/A hasta Q3**
- **Impacto**: 🟢 bajo (Alex Q3 vote = ignorar hasta renovation)
- **Esfuerzo**: TBD post-renovation
- **Notas**: roomId 679176, NO surfacar en Greeter prompt hasta Q3 2026

### 4.4 Cost analysis breve (post-ccusage)
- [ ] **EJECUTAR post ccusage 1 semana**
- **Impacto**: 🟢 bajo. Calibration vs assumed costs
- **Esfuerzo WC**: 1 página
- **Bloqueador upstream**: thread/175 T2 ccusage LIVE + 1 semana data
- **Notas**: Q5 voto Alex thread/174

---

## ⚫ TIER 5 — NO HACER (bajo impacto + alto esfuerzo)

### 5.1 ~~Fix retrospectivo 22 colisiones históricas threads~~
- [ ] **NO HACER**
- **Razón**: rompería links históricos sin beneficio. Forward-only fix con W1 es suficiente

### 5.2 ~~Cross-reference forzado 110 threads sin PR~~
- [ ] **NO HACER**
- **Razón**: mayoría son informacionales legítimas (reports, brain modes, syntheses). Forzar PR sería noise

### 5.3 ~~Migrar 202 threads legacy a YAML frontmatter manualmente~~
- [ ] **NO HACER manual** (opción 2.4 cubre con script automatizado)
- **Razón**: si decides ejecutar 2.4, hazlo via script. No manual.

### 5.4 PR #133 vs #132 — duplicate `fix(reglas-pdf)`
- [ ] **NO HACER nada**
- **Razón**: ambos ya merged. Cosmético; no impacto funcional

### 5.5 PR #45 vs #46 — duplicate `test(greeter-v5)`
- [ ] **NO HACER nada**
- **Razón**: #45 closed (era 13897 LoC), #46 merged limpio (136 LoC). Historia auto-resolvió

---

## 📊 Resumen estadístico para tu decisión

| Tier | Items | Esfuerzo Alex total | Esfuerzo CC total | Cost USD est |
|---|---|---|---|---|
| 🔴 Tier 0 bloqueadores | 8 | ~2h | 1-2h post-decisiones | <$5 |
| 🟠 Tier 1 Wave 1 cleanup | 7 | 10 min approve | ~2h | <$3 |
| 🟡 Tier 2 specs medias | 5 | 1-2h decisión | 0-2h | <$5 |
| 🟢 Tier 3 foundations ship | 6 | ~3h decisión + coord | 30-50 días | $30-50 |
| ⚪ Tier 4 estructural largo | 4 | TBD | 5-10 días Q3+ | TBD |
| ⚫ Tier 5 NO hacer | 5 | 0 (declarado) | 0 | 0 |

**Crítico-camino mínimo**: Tier 0 (G7 voto) + Tier 1 (Wave 1) desbloquea el 80% del valor posible en próximas 2 semanas.

---

## 🎯 Recomendación WC (1 línea por tier)

- **Tier 0**: empieza por **G7 thread/148 voto** — 30 min Alex, desbloquea ~10 días CC downstream
- **Tier 1**: aprueba todos los 7 cleanup en paquete (Wave 1 spec, ~2h CC en paralelo)
- **Tier 2**: vota 2.2 decisions stores (mi voto A), aprueba 2.1 F2 refactor (sin esto F2 no ship)
- **Tier 3**: NO arrancar hasta Tier 0 + Tier 1 listos. F2 → F1 → F3 secuencial
- **Tier 4**: parking lot — retomar Q3 cuando foundations LIVE
- **Tier 5**: confirmar NO hacer (1 tap)

---

## ✅ Tu decisión ahora

Tres opciones para procesar este backlog:

1. **Async batch**: marca checkboxes en GitHub directamente sobre este thread. Yo proceso cuando vuelves
2. **Síncrono ahora**: respóndeme con votos por tier (e.g. "Tier 0: 0.1 sí, 0.2 A, 0.3 sí, 0.4 review hoy, ...")
3. **Quick path**: aprueba Tier 1 entero (Wave 1) — pusheo thread/180 con spec ejecutable para CC, mientras tú decides Tier 0/2/3 con calma

---

**Fin master backlog.** Vivo: regenero cuando agotes items o cuando audit re-run produzca findings nuevos.

— WC, 2026-05-22.
