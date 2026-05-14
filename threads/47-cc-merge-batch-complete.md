# Thread 47 — Merge batch completo (4 PRs en pr3-en-blog-extras)

**De:** CC (main thread)
**Para:** Alex `[@alex]`, WC `[@wc]`
**Fecha:** 2026-05-14
**Status:** ✅ Done — listo para deploy a producción

---

## 0. TL;DR

Alex dijo "merge, and go ahead". Mergeé los 3 PRs draft + 1 follow-up
en orden seguro. Resolví 3 conflictos pequeños (todos auto-resolvibles).

| PR | Status | Commit en pr3 |
|---|---|---|
| #13 (WC seed import + schema 12 fields) | ✅ MERGED | `846d080` |
| #12 (Welcome Guide architecture) | ✅ MERGED | `313af2b` |
| #11 (Phase B.1 auto-send scaffold) | ✅ MERGED | `40373ea` |
| #14 (follow-up: 12-field mapping) | ✅ MERGED | `afd5876` |

**Tests after merge:** 400 passing (190 web + 210 worker-bot)
**Build:** ✓ Astro compila clean

---

## 1. Conflictos resueltos

**PR #12 conflict:** `apps/web/src/pages/admin/airbnb-content/index.astro`
- Causa: PR #13 agregó `<ImportWCSeedsButton client:load />`, PR #12 agregó property summary cards. Ambos al inicio del bloque `{allowed && !loadError && (...)}`.
- Resolución: combiné — ImportWCSeedsButton primero (top of actions), luego property summary cards.

**PR #11 conflict 1:** `apps/worker-bot/src/index.ts`
- Causa: ambos PRs (PR #12 + PR #11) agregaron `KNOWLEDGE_BUCKET?: R2Bucket` al Env interface con comentarios diferentes.
- Resolución: combiné comentarios — el binding es compartido entre los 2 use cases (Phase B.1 templates + Fase 2.6 Bot KB).

**PR #11 conflict 2:** `apps/worker-bot/wrangler.toml`
- Causa: ambos PRs declararon `[[r2_buckets]]` para KNOWLEDGE_BUCKET con comentarios diferentes (mismo binding name + bucket).
- Resolución: combiné comentarios documentando ambos use cases.

---

## 2. PR #14 follow-up

Fase 2.6 (Bot KB) y Welcome Guide se escribieron asumiendo 9 fields.
PR #13 expandió a 12. Sin actualizar, los 3 nuevos fields quedaban
silenciosamente ignorados.

PR #14 cierra el loop:

**`apps/web/src/lib/welcome-guide.ts`:**
- "Sobre la casa" merge `tu_propiedad` + `acceso_huespedes` + `interaccion_huespedes`
  con sub-headers (`### Acceso de los huéspedes`, `### Cómo te apoyamos`)
- "Cómo llegar" agrega `metodo_llegada` SOLO en versión auth-gated
  (público lo omite porque típicamente describe self-service via clave caja)

**`apps/worker-bot/src/welcome-kb.ts`:**
- Section list bot KB include `acceso_huespedes` + `interaccion_huespedes`
- `metodo_llegada` NO en bot KB (sensitive content)

---

## 3. Estado de pr3-en-blog-extras

```
afd5876  feat(welcome): map 12 fields en welcome-guide.ts + welcome-kb.ts (#14)
40373ea  feat(worker-bot): Phase B.1 welcome auto-send scaffold (#11)
313af2b  feat(welcome): Fase 2.1 architecture — /welcome/{property} (#12)
846d080  feat(content): WC seed import flow + schema (12 fields) + onboarding (#13)
6c6e777  Merge PR #10 (Fase 1.5 MVP)
```

---

## 4. Pasos manuales pendientes (para Alex)

### 4.1 Apply migrations a D1 producción

```bash
wrangler d1 migrations apply rincon --remote
```

Esto aplica:
- `0019_pending_welcomes.sql` (Phase B.1 — pending_welcomes table)
- `0020_admin_import_logs.sql` (audit log para import endpoints)

Verificar:
```bash
wrangler d1 execute rincon --remote --command "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('pending_welcomes', 'admin_import_logs')"
```

### 4.2 Merge pr3-en-blog-extras → main para production deploy

CF Pages deploys desde `main`, no `pr3-en-blog-extras`. Cuando estés listo:

```bash
git checkout main
git pull
git merge pr3-en-blog-extras --no-ff -m "feat: merge Fase 2 stack + WC seed import + Phase B.1"
git push
```

CF Pages auto-deploya post-push a main.

### 4.3 Deploy worker-bot

```bash
cd apps/worker-bot && wrangler deploy --env production
```

Esto activa:
- KNOWLEDGE_BUCKET R2 binding
- Phase B.1 welcome auto-send handler en `/admin/welcome-auto-send`
- Bot KB cron refresh cada 2h en `/admin/refresh-now`

### 4.4 Karina onboarding

1. Login Karina → `https://rincondelmar.club/admin/airbnb-content`
2. Click **"📥 Importar drafts iniciales WC"** (modo seguro)
3. Cards muestran "12/12 ░░░ Alex 0% Karina 0%" para los 8 importados
4. Karina abre cell → ve content WC + banner amarillo "📝 Nota WC: ..."
5. Walkthrough con Alex per `docs/karina-onboarding.md` (sesión 30 min)

### 4.5 Activate Phase B.1 cron (opcional, post-pilot)

`.github/workflows/cron-welcome-auto-send.yml` corre cada 15 min. Está
APPROVAL MODE — solo prepara texto en `pending_welcomes`, no envía a Beds24.
Alex puede observarlo 1 semana antes de activar canary auto-send.

---

## 5. Risks por PR (ya validados)

- **PR #13** (schema): zero risk — pure additive, R2 storage compatible
- **PR #12** (Welcome Guide): zero risk — nuevos routes públicos + auth-gated
- **PR #11** (Phase B.1): low risk — approval mode only, NO outbound a guests
- **PR #14** (follow-up): zero risk — additive only

---

## 6. Bloqueos pendientes

Todos del lado tuyo:
- [ ] Apply migrations 0019 + 0020
- [ ] Merge pr3 → main para production deploy
- [ ] Deploy worker-bot
- [ ] Onboarding Karina

Ningún bloqueo del lado mío para empezar el siguiente sprint.

---

## 7. Próximos sprints sugeridos

Cuando estés listo para más, opciones (de mayor a menor leverage):

1. **Karina drafting batch ES** (no requiere mi código — ella + Alex iteran).
   Cuando primer batch READY → yo hago Chrome MCP write-back a AirBnB.
2. **Wire bot greeter al welcome KB** — modify packages/agents/greeter/stage2.ts
   para include welcome KB block en system prompt cuando intent='info'.
3. **Drift detection cron** — re-scrape AirBnB cada 24h vía Chrome MCP, compare
   con airbnb_snapshot, flag drift_detected en cells.
4. **Diff view en ContentCell** — show diff vs last_deployed para review.

Esperando tu siguiente "go ahead" para arrancar uno de estos.
