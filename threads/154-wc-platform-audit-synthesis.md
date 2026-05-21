# Thread 154 · WC-Platform · Audit synthesis committed

**From**: WC-Platform
**To**: Alex (decision), WC-Impl + CC (post-audit context)
**Date**: 2026-05-21 ~04:45 MX (Day 2 of 5-day audit cycle)
**Status**: ✅ Synthesis committed. Awaiting Alex review + decision (thread/155).

---

## Doc

**Location**: `rdm-platform/reports/audit-2026-Q2/04-synthesis.md`
**Commit**: `f6e2f7d3b8c1c8b86f1bff0fc1855bde886374ae`
**Size**: 20.6 KB

---

## §A · Verdict en 5 líneas

- Greenfield delta: **~25% would change**, 75% survives. Architecture más coherente de lo esperado.
- Critical issues: **5 🔴**, 17 🟡, ~12 🟢, ~7 ⚪.
- Recommendation: **🟡 fix 5 críticos primero (~12-18h CC, 2 días), proceder M1 sin pause**.
- **F2 UNPAUSE**: el premise que lo pausó está falsificado por evidencia D1. F2 puede arrancar con scope reducido (drop Logpush, mantener WAE + TG + cost panel).
- **Auditor self-correction**: WC-Platform's §C.1 headline está incorrecto. WC-Impl + CC tienen evidencia D1 que crons sí corren. Synthesis reconcilia.

---

## §B · La reconciliación crítica

**Mi error en thread/151**: dije que worker-pago crons no corrían (Workers Free no soporta).

**WC-Impl en thread/152**: tiene **D1 evidence directa** — `bookings.cancelled_at` timestamps clusterean en `:00:13` / `:30:06` / `:30:44`, exactamente cuando `*/30` cron `expireHolds` debe correr. **Free SÍ soporta hasta 5 crons/cuenta**.

**CC en thread/153**: independiente, llegó a la misma conclusión post-read de WC-Impl. Confirma.

**Real finding**: doc drift. El comment en `apps/worker-bot/wrangler.toml:84` ("Workers Free plan NO soporta cron triggers") se propagó como mito a 5+ docs:
1. `worker-bot/wrangler.toml:84` (mito-source)
2. `foundations/README.md:47`
3. `thread/146-cc-foundations-preflight.md` §F1.Q1
4. `decisions/ADR-002-foundations-seal.md` §Consequences
5. `audit-2026-Q2/README.md` §0.1 (yo)
6. `thread/149-followup-day-0-trigger.md` (yo)
7. `01-architectural-audit-wc-platform.md` §C.1 (yo, climax del mito)

**Remediation revision**: de "3h refactor OR $5/mo upgrade" → **"1-2h doc edit"**.

**Auditor design validation**: la arquitectura de 3-auditor paralelo con D1 verification independiente atrapó mi error dentro de 1 día. Exactly what the design is for.

---

## §C · 5 críticos consensus (Wave 1)

| # | Finding | Origen | Effort | Why critical |
|---|---|---|---|---|
| 1 | **B.1 doc drift fix** | 3/3 | 1-2h | Unblocks F2. Foundation for ADR-003. |
| 2 | **C.2 migration 0039 renumber** | WC-Platform | 30min | Schema integrity, prod drift risk |
| 3 | **C.4 total_mxn unit decision** | CC | 1h | M1 will read this; centavos vs pesos drift = pricing bug |
| 4 | **C.6 Telegram inline [✅ Respondí]** | WC-Impl | 3-4h | 91% reminder spam → Karina onboard sane |
| 5 | **C.3 Make.com → Beds24 direct** | WC-Platform | 1-2h | Sunset closure (NOW relevant since crons DO run) |
| 6 | **C.5 tests auth + mp** | CC | 4-6h | Security critical, HMAC + magic links uncovered |

**Total**: 12-18h CC. Cabe en 2 días dedicados.

---

## §D · 8 preguntas para Alex en thread/155

Las 5 más críticas (rápidas):

1. **C.2 verification**: `wrangler d1 migrations list rincon --remote` → ¿cuál 0039 está applied?
2. **C.3 Make status**: ¿`MAKE_CONFIRM_WEBHOOK_URL` scenario online o disabled?
3. **C.4 total_mxn**: ¿Confirma "pesos" como canonical (matching código actual)?
4. **C.6 Telegram inline**: ¿OK con button [✅ Respondí] como canonical solution?
5. **F2 Logpush**: ¿Drop scope F2 (defer F2.2 contingent Paid) o forzar upgrade $5/mo ahora?

Las 3 más estratégicas:

6. **C.7 worker-bot/index.ts split timing**: ¿Antes de M1 (1d block) o después (más conflicts)?
7. **Wave 1 effort**: ¿12-18h CC concentrados 2 días, o spread 1 semana?
8. **ADR-003 author**: ¿Yo (WC-Platform) o CC?

---

## §E · Recomendación plan stance

**Stay Free** (§I synthesis).

Rationale:
- 5 cron triggers cap = 5/5 worker-pago. GH Actions pattern para más.
- 10ms CPU = current endpoints fit. M1 pricing recalc probablemente <10ms.
- WAE 10M datapoints = suficiente para F2.
- Logpush ($5/mo): wanted, NO needed. Defer F2.2 contingent.
- DO: not used, M1-M5 no requieren.

**Trigger condition para upgrade**: cuando 2/3 hit:
- M1 brain reveals pricing recalc needs >10ms CPU
- Logpush becomes high-value
- DO needed for I3 lifecycle/M4 staff scheduling

Hasta entonces: $5/mo es premature.

---

## §F · Nuevos anti-patterns para ADR-001 §6

Sintetizados del audit. Propose 8 additions, las 3 más importantes:

1. **"Cron in wrangler.toml without verifying plan supports it"** 🔴 — every `[triggers].crons` needs verification comment.
2. **"Duplicate-numbered migration files"** 🔴 — pre-commit hook needed.
3. **"Doc drift on platform constraints"** 🔴 (META) — "platform-feature requires X plan" claims need verification source BEFORE propagating.

Anti-pattern #3 es el que prevendría mi error. **Verify-then-claim, not claim-then-verify**.

(Otros 5 en synthesis §G.)

---

## §G · F2 status post-synthesis

**Antes**: F2 paused per thread/149-followup §B ("premise que pausó = Free no soporta crons").

**Ahora**: premise falsificado. F2 puede arrancar.

**Scope reducido** (3-5h CC vs 6-9h original):
- ✅ WAE primary metrics (no change)
- ✅ 2-channel Telegram routing (no change, needs Alex BotFather pre-flight)
- ✅ LLM cost panel (no change)
- ⏸️ Logpush → defer to F2.2 contingent Paid upgrade
- 🔄 cron_heartbeats table → reuse existing `bot_config` pattern (no new migration)
- ✅ /admin/health expansion → minimal (page already at 80% de scope)

Voto WC: ship F2 reduced post-Wave-1, antes de M1 brain session.

---

## §H · Self-correction explicit

In `04-synthesis.md` §J:

> **What I (WC-Platform) got wrong**
> 
> In `01-architectural-audit-wc-platform.md`:
> - §A "Headline finding" claimed worker-pago crons never run → **wrong, they do**.
> - §C.1 severity/risk/effort assumed 3h refactor or $5/mo upgrade → **wrong, 1-2h doc edit**.
> - §F.1 "do before M1" via Paid upgrade OR GH Actions migration → **wrong, just doc edit**.
> - thread/151 § "headline" propagated the same error.
> 
> **Root cause**: trusted the `wrangler.toml:84` comment as autoritative instead of verifying via D1 query.

thread/151 + audit-01 quedan as historical record. Authoritative reading: **04-synthesis.md**.

---

## §I · Next steps

| When | Who | What |
|---|---|---|
| **Day 3 (mañana)** | Alex | Read 04-synthesis (~30min), responder §H en thread/155 |
| Day 3-4 | WC-Platform | Author ADR-003 (cron strategy + plan stance) post-Alex |
| Day 4-5 | CC | Wave 1 execution (~12-18h) |
| Day 5+ | CC | F2 ship reduced (3-5h) |
| Post-Wave-1 | WC-Platform | M1 brain session schedule |

---

## §J · What I didn't audit (carry-forwards)

Synthesis surfaced 3 areas de menor prioridad que merecen brain sessions futuras pero NO bloquean M1:

1. **CC §D "Worker as admin API surface drift"** 🟢 — worker-bot tiene 42 rutas, 36 son `/admin/*`. Threshold para split a `worker-admin` cuando F3 lande?
2. **WC-Impl §C.5 `/admin/index.astro` landing dashboard** 🟡 — Karina onboard improvement, 2-3h, no blocking.
3. **WC-Platform §C.13 doc cleanup** 🟢 — mover OPEN_QUESTIONS / PROPUESTA-* a rdm-platform/proposals/.

Estos van a `wishlist` o tracking issues si Alex querés.

---

**Signed**: WC-Platform, brain mode, 2026-05-21 ~04:45 MX.

Audit cycle Day 2 ✅ complete.  
Day 3 transfers control to Alex.

🤝 Co-Authored-By: WC-Impl + CC (audits 02 + 03 informaron synthesis).
