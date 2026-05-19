# Thread 127 · WC handoff CC · A5 execution DoIt autonomous

**From:** WC
**To:** CC-Bot
**Date:** 2026-05-19
**Type:** DoIt handoff · autonomous
**Spec base:** thread/121 §3 (already approved by Alex 2026-05-18 night)
**Mode:** Full autonomous · CC ejecuta sin permiso step-by-step

---

## TLDR

Alex confirmó hoy 2026-05-19: **"A5 execution → todo autonomous"**. Procede con A5 según spec en thread/121 §3.

**Lo que CC hace:**
1. Bulk approve cells con content sin `{open:}` comments
2. Chrome MCP write-back a 8 listings AirBnB live (4 props × 2 langs)
3. Verify all cells reach `deployed_at !== null`
4. Post thread/128 con report final

**Time budget:** 6-10h autonomous. Si excedes 1.5x (15h), stop + reporta.

---

## 1 · Estado actual de drafts (verified)

Alex screenshot 2026-05-18 night mostró:

| Métrica | Valor |
|---|---|
| Total cells | 104 (4 props × 2 langs × 13 fields) |
| Vacíos 🔴 | 7 |
| Approved 🟢 | 52 |
| Deployed 🚀 | 13 |
| Saved (no approved) | 32 (calculado: 104 - 7 - 52 - 13) |

### Per draft state (per Alex screenshot)

| Draft | Karina ES | Alex ES | Karina EN | Alex EN |
|---|---|---|---|---|
| RdM | 13/13 100% | 100% Alex | 12/13 | 23% Alex |
| Las Morenas | 12/13 | 92% Alex | 12/13 | 0% Alex |
| Combinada | 12/13 | 92% Alex | 12/13 | 0% Alex |
| Huerta | 12/13 | 92% Alex | 12/13 | 0% Alex |

**Implicación scope:** ~91 cells need deploy action (52 approved already ready + 32 saved need bulk-approve first + 7 vacíos skipped).

**Update vs thread/121 spec estimate:** original said "~55 cells". Real number is ~91. Time budget adjusts proportionally: 6-10h → 8-12h. Aún acceptable.

---

## 2 · Explicit scope

### ✅ YES — en scope

1. Bulk approve cells with `content !== ''` AND no `{open:}` comments (current "saved" → "approved")
2. Chrome MCP authenticated to Alex's AirBnB account (verify auth at start)
3. Sequential write-back per spec §3.3 order (RdM ES → RdM EN → Morenas ES → ... → Huerta EN)
4. Per-cell write-back: parse content via `stripComments()`, navigate to URL per field, save in AirBnB, verify "Saved" indicator, call `PUT /api/admin/airbnb-content/[property]/[lang]/[field]/deploy-confirmed`
5. Skip cells with `{open:}` syntax — log to report
6. Audit log entries `kind='airbnb_write_back'` per cell (existing infra)
7. Post thread/128 with full report

### ❌ NO — out of scope

- NO modificar contenido del draft (no editar texto). Solo approve + deploy lo que está
- NO tocar cells vacías (status `empty`)
- NO crear nuevos drafts ni fields
- NO desactivar / pausar otros features durante el run
- NO mergear PRs durante el run (A5 corre solo, sin code changes)
- NO ejecutar si Karina o Alex están activos en `/admin/airbnb-content` (race condition)

Si encuentras algo fuera de scope: log to report, NO fixees inline.

---

## 3 · Closed decisions (Alex)

| Decisión | Valor confirmed by Alex 2026-05-18 night + 2026-05-19 |
|---|---|
| EN drafts at Alex 0% review | "Todo ciego" — Alex acepta el riesgo. CC procede sin review previo. |
| `{open:}` comments | Skip cell. Report en thread/128. Alex resuelve post-A5. |
| Order | Sequential. RdM ES first (lowest risk, 100% Alex review). Huerta EN last. |
| Pause durante run | No. Solo coordinar con Karina (don't touch during A5). |
| Rate limit AirBnB | 2-3 seg delay entre saves. Total ~3-5 min extra. |
| Time budget | 8-12h. Excedo 1.5x (18h) = stop + report. |

---

## 4 · Pre-flight checklist

Antes de arrancar CC verifica:

- [ ] `git pull origin main` en rdm-bot — debe estar en HEAD post-PR #122 (commit `8f46b6a`) o más reciente
- [ ] Chrome MCP autenticado a AirBnB con cuenta Alex (verificar abriendo `https://www.airbnb.com/hosting/listings` — si redirige a login, halt + escalate)
- [ ] `/admin/airbnb-content` accesible logged in (verifica con un GET, NO modifiques nada)
- [ ] Alex disponible asynchronously para escalations (reporta a Telegram si halt)
- [ ] Karina no está activa en `/admin/airbnb-content` (Alex pregunta a Karina al inicio)
- [ ] No hay PRs in-flight tocando `apps/web/src/pages/admin/airbnb-content/` (verifica `git log --oneline -20`)

Si algún check falla → halt + ping Alex via Telegram.

---

## 5 · Execution per spec §3 (resumen)

Sigue thread/121 §3.2-§3.4 al pie de la letra. Resumen rápido:

### Step 1 — Bulk approve

```typescript
// Pseudocode
for each draft in [RdM-ES, RdM-EN, Morenas-ES, Morenas-EN, Combinada-ES, Combinada-EN, Huerta-ES, Huerta-EN]:
    for each cell in draft:
        if cell.content === '' or cell.status === 'empty':
            continue  // skip vacíos
        if cell.content.includes('{open:'):
            report.skipped.push({cell, reason: 'open_comment'})
            continue
        if cell.alex_ok && cell.karina_ok:
            continue  // already approved
        // Bulk approve: set both flags
        await putFieldApproval(cell, { alex: true, karina: true })
        report.approved++
```

### Step 2 — Chrome MCP write-back

```typescript
for each approved cell in deploy queue (sorted by spec order):
    content_clean = stripComments(cell.content)
    url = URL_PER_FIELD[cell.field]  // ver deploy-queue.astro
    await chromeMcp.navigate(`https://www.airbnb.com/hosting/listings/${listingId}${url}`)
    await chromeMcp.wait_for_load()
    await chromeMcp.fill_field(cell.field_selector, content_clean)
    await chromeMcp.click('button:has-text("Save")')
    await chromeMcp.wait_for_text('Saved')  // or AirBnB equivalent
    await sleep(2500)  // rate limit
    await fetch(`/api/admin/airbnb-content/${cell.property}/${cell.lang}/${cell.field}/deploy-confirmed`, { method: 'PUT' })
    report.deployed++
```

### Step 3 — Report

Post thread/128 con:
- Cells approved count
- Cells skipped (open comments) — lista
- Cells deployed count
- Cells failed deploy + error
- Time elapsed
- Audit log link
- Spot-check sugerencia: 1 random listing per property para Alex

---

## 6 · Risks + mitigations (per thread/121 §3.4)

| # | Risk | Mitigation |
|---|---|---|
| R1 | Chrome MCP session expires | Resume from last `deployed_at` cell. Idempotent. |
| R2 | AirBnB UI changes break URL_PER_FIELD | Test RdM EN first (lowest risk, already 23% Alex). If fails, halt. |
| R3 | EN content quality (Alex 0%) | Alex accepted ciego. CC reports cells with no prior review. |
| R4 | `{open:}` blocks deploy | Step 1 skips. Report lists. |
| R5 | AirBnB rate limit | 2-3s delay. |
| R6 | Snapshot mismatch post-deploy | Acceptable on first deploy (baseline). |
| R7 | Karina edits mid-run | Coordinate before start (Alex asks Karina). `resetApprovalsOnEdit` resets if happens. |
| **R8 NEW** | **Booking 86939592 inline welcome PR #123 not merged** | Independent. A5 affects content, not webhooks. No interaction. |
| **R9 NEW** | **karina-training 500 fix (4a311a2) not merged** | Independent. A5 affects content workflow, not auth/render. No interaction. |

---

## 7 · Definition of done (per spec)

- [ ] All 8 drafts reach `approved` status (excluding vacíos + open-comment skips)
- [ ] All approved cells reach `deployed_at !== null`
- [ ] All cells have `airbnb_snapshot` populated
- [ ] Audit log: `airbnb_write_back` entries per cell
- [ ] thread/128 posted with full report
- [ ] No Karina-mid-edit conflicts logged
- [ ] Spot-check sugerencia para Alex (1 listing per property)

---

## 8 · Communication protocol

Reporta a Alex (Telegram or thread comment) en estos momentos:

| Trigger | Mensaje |
|---|---|
| Pre-flight done, starting | "A5 starting. ~91 cells to action. ETA 8-12h." |
| RdM ES complete (first batch, validate URL_PER_FIELD works) | "RdM ES done. URL mapping validated. Continuing." |
| Halfway (50% cells deployed) | "A5 50% done. X errors so far. Continuing." |
| Halt condition triggered (timeout, AirBnB error, auth fail) | "A5 halted at cell {N}. Reason: {X}. Need: {Y}." |
| Complete | Thread/128 posted + Telegram "A5 done. Report in thread/128." |

**No reportes en cada cell.** Solo milestones above.

---

## 9 · Comando para arrancar

CC abre nueva sesión Claude Code CLI con Chrome MCP enabled, y ejecuta:

```
Pre-flight:
1. git pull origin main en rdm-discussion
2. git pull origin main en rdm-bot (verifica commit 8f46b6a o más reciente)
3. Verifica Chrome MCP autenticado a AirBnB (open hosting listings, no redirect to login)
4. Pregunta Alex via Telegram: "Karina activa en /admin/airbnb-content ahora?"

Lee:
- threads/121-wc-a2-a3-review-a4-amendment-a5-spec.md (spec completo, §3)
- threads/127-wc-cc-a5-execution-doit.md (este handoff)

Ejecuta A5 según spec §3.2-§3.5 sequential.

Time budget: 8-12h. Excedo 1.5x (18h) = stop + Telegram.
Comunicación: solo milestones del §8.
Output: thread/128 con report final.
```

---

## 10 · Working notes

- **Stuck > 30 min** en un cell específico: skip + log + continue. No bloquees todo el run por 1 cell.
- **AirBnB UI broken**: halt entire run. Re-test URL_PER_FIELD necesario antes de continuar.
- **Auth expira mid-run**: re-auth + resume. No restart from beginning (idempotent).
- **Self-review pre-deploy-confirmed**: lee el content que vas a pegar antes de pegar. Si tiene `[para Alex:` u `{open:`, skip.

---

## 11 · Post-A5 actions (no en este DoIt, mencionar en thread/128)

| Item | Quién |
|---|---|
| Spot check 4 listings (1 per property) live en AirBnB | Alex, 5 min |
| Review thread/128 report | Alex |
| Decidir si content_editor model needs cleanup (PR #121 bypass) | Alex + WC futuro |
| Resolver cells skipped por `{open:}` | Alex |

---

WC out.

🚀 Buena suerte CC. Sleep good post-A5.
