# Thread 161 · WC → CC-Bot · DoIt: /admin/issues GitHub Operations Cockpit

**From**: WC (Web Claude)
**To**: CC-Bot
**Mode**: DoIt (autonomous, scope-strict)
**Date**: 2026-05-21
**Origin**: Alex brain session 2026-05-21 (web chat) → spec → push

---

## Summary

Construir `/admin/issues` como wrapper visual sobre GitHub: visibilidad + estructura + Smart Clipboard, sin duplicar approval logic. Karina entra al loop sin GitHub. Alex reduce overhead de orientación matutina y context-switch.

**Spec doc completo**: [`cc-instructions-bot/2026-05-21-admin-issues-cockpit.md`](../cc-instructions-bot/2026-05-21-admin-issues-cockpit.md)

⚠️ El spec inicialmente pushed es versión condensada (~10KB). Versión completa (~42KB) con todas las wireframes ASCII, SQL schemas literales, API contracts detallados, y templates canónicos disponible vía artifact en chat WC (Alex la sube si necesitas más detalle).

Lee ese archivo end-to-end antes de empezar. Este thread es solo el wrapper de coordinación.

---

## Alex's closed decisions (sealed in spec section 3, 20 items)

| # | Decisión | Resolución |
|---|---|---|
| 1 | Approval logic en UI | ❌ NO. Solo informativa. Tap → GitHub app |
| 2 | Chat inline con bot | ❌ NO. Smart Clipboard only |
| 3 | Deep-link Claude.ai | ❌ NO. Mobile no soporta |
| 4 | Notification channel | Solo UI. Sin Telegram/email/push |
| 5 | Repo issues | Reusar `rdm-discussion` con label `kind/feedback` |
| 6 | UI location | `apps/admin` en rdm-platform |
| 7 | Worker URL | `*.workers.dev` (no custom domain) |
| 8 | CC identity mapping | **Branch-based**, NO email-based (ver spec §4.6) |
| 9 | One-run vs fases | **One-run** big bang single CC session larga |
| 10 | Cron daily brief | 6am MX (CST-6) |
| 11 | Buckets | `admin`, `web`, `bot`, `beds24`, `content`, `infra` |
| 12 | Priority | `low`, `normal`, `high` |
| 13 | Tests coverage | ≥80% |
| 14 | Submit primary | Desktop. Mobile = view + tap Open in GitHub |

20 decisiones cerradas viven en spec section 3. No re-litigues.

---

## DoIt scope

### YES — in scope
6 ideas implementadas one-run:
1. Unified Inbox view (`/admin/issues`)
2. Smart Grouping by thread (`/admin/issues/grouped`)
3. CC Activity Tracker branch-based (`/admin/issues/cc-activity`)
4. Daily Brief generator (`/admin/issues/brief`)
5. Feedback Submission Form (`/admin/issues/new`)
6. Context Cards expand-inline en cada item
+ Smart Clipboard button (Copy WC context markdown)

### NO — out of scope (hard line)
- Approval buttons que actúan en GitHub
- Bash/deploy/merge trigger desde UI
- Chat inline o deep-link a Claude.ai
- Telegram/email/push
- Guest CRM / guest feedback
- Make.com integration

Full list en spec §2.

---

## Branch + numbering

| Item | Value |
|---|---|
| Branch | `feat/admin-issues-cockpit` (off rdm-bot main) |
| CC session | **cc-strategy** (matches `feat/admin-issues-*` rule en spec §4.6) |
| PR prefix | Standard `feat:` conventional |
| Migration | `0040_feedback_system.sql` |
| Worker name | `worker-feedback` |
| R2 bucket | `rdm-feedback-attach` |
| Worker URL | `worker-feedback.{cf-account}.workers.dev` |
| Estimate | 35h target, 45h hard halt |

---

## Pre-flight (auto-verify before starting)

```bash
# 1. Branch doesn't exist yet
git ls-remote --heads https://github.com/alexanderhorn6720/rdm-bot.git refs/heads/feat/admin-issues-cockpit
# expected: empty

# 2. Migration 0040 doesn't exist yet
ls rdm-bot/migrations/0040* 2>/dev/null
# expected: no such file

# 3. R2 bucket name available
wrangler r2 bucket list | grep -c "rdm-feedback-attach"
# expected: 0

# 4. Worker name available
wrangler deployments list --name worker-feedback 2>&1 | grep -c "not found"
# expected: 1

# 5. Verify D1 rincon accessible
wrangler d1 execute rincon --command "SELECT 1" 2>&1 | grep -c "results"
# expected: ≥1

# 6. Labels not yet in rdm-discussion
gh label list -R alexanderhorn6720/rdm-discussion | grep -c "kind/feedback"
# expected: 0
```

Si cualquier pre-flight falla con state distinto al esperado: STOP, comenta en thread 161 con detail, espera Alex.

---

## Execution order (additive-first, ver spec §8)

1. Setup phase (2h)
2. D1 schema + migration (2h)
3. Worker API endpoints (12h)
4. GitHub webhook wiring (3h)
5. UI components (10h)
6. Integration tests (4h)
7. Docs (1h)
8. Self-review + polish (1h)

---

## Halt conditions (>30min blocked → para y reporta en thread)

- Webhook signature validation failing repeatedly
- D1 migration fails on remote despite local success
- R2 signed URL generation returns 403
- Better Auth session not propagating to worker
- Karina UAT reveals UX confusion not solvable inline
- Estimate excede 45h

---

## Out-of-scope guardrails (open issue, NO fix inline)

- Bug en `apps/worker-bot` no relacionado
- Pet policy aún en `/noche` en algún sitio
- Karina training 500 error pendiente (PR `fix/karina-training-input-self-close` independent)
- Cualquier cambio a Greeter prompt
- thread/127 A5 Chrome MCP

---

## Criterio de éxito (DoD en spec §6, 20 items checkable)

Resumen DoD high-level:
- Migration 0040 applied to D1 rincon
- R2 bucket created
- Worker deployed to `*.workers.dev`
- GitHub webhooks configured en 3 repos
- 19 labels creados en rdm-discussion
- 6 UI routes live en `/admin/issues/*`
- Smart Clipboard endpoint funciona, R2 URLs accesibles 7d
- Daily brief renderiza 5 secciones
- CC Activity tracker clasifica por branch correctamente
- Karina UAT pasa
- Tests ≥80% coverage
- Self-review del diff completo
- Spec doc archivado + architecture doc + Karina guide

Detalles checkables en spec section 6.

---

## Reportar al final

PR description debe incluir (mobile-first, what + how to verify):

1. **What changed**: lista de archivos nuevos por categoría (worker, UI, migration, docs)
2. **How to verify**: comandos exactos para validar cada DoD item
3. **Estimate actual vs target** (target 35h)
4. **Halt incidents** si los hubo
5. **Out-of-scope findings** opened as issues (linked)
6. **Karina UAT readiness checklist**
7. **Self-review notes**: cosas que te llamaron la atención

Y crear thread de respuesta `162-cc-bot-admin-issues-cockpit-complete.md` con:
- Summary ejecutivo (3-5 líneas)
- Worker URL final (`worker-feedback.<subdomain>.workers.dev`)
- Lista de items DoD ✅ vs 🟡 vs ❌
- Riesgos detectados mid-execution no en spec
- Recomendaciones para Karina onboarding

---

## Context para CC

Alex pidió esto en chat web hoy. Le explica por qué:
- Karina (content_editor) no usa GitHub, necesita reportar bugs en UI propia
- Alex está overwhelmed con approvals fragmentados
- Va a estar usando este sistema **años**
- Quiere visibility + structure + smart submit, NO rehacer GitHub

Wrapper, no replacement. Respeta flujo Git y reglas Claude que ya tenemos.

---

## GO signal

✅ Spec en su lugar (condensed pushed; full available via WC chat artifact si necesitas)
✅ Decisiones cerradas (20 items)
✅ Pre-flight definido (6 checks)
✅ Halt conditions claros
✅ Out-of-scope guardrails explícitos
✅ Numbering thread/161 asignado
✅ Branch `feat/admin-issues-cockpit` reservado

**DoIt autorizado. Procede cuando estés listo.**

Si tienes preguntas pre-execution que afecten scope, comenta en este thread ANTES de arrancar.

— WC
