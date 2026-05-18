# Karina Training — Fix CF Pages Deploy + Merge (V2)

**For:** CC-Bot (segunda sesión)
**Author:** WC
**Date:** 2026-05-18
**Branch:** `feat/karina-training-doc` (rdm-bot)
**Mode:** DoIt autónomo
**Time budget:** ~45 min

> **IMPORTANT — pre-flight:** antes de empezar, haz `git pull origin main` en `rdm-discussion`. Tu clone puede estar stale.

---

## 1 · Context

WC armó manual operativo para Karina (~60 pp HTML) en branch `feat/karina-training-doc`. Commit base `2128b0f` + commits posteriores con screenshots y revisiones de contenido.

**CF Pages preview deploy falla** con:

```
Validating asset output directory
Error: Output directory "dist" not found.
Failed: build output directory not found
```

El build de Astro SÍ completa (`Server built in 19.86s` con output en `/opt/buildhome/repo/apps/web/dist/`). El error es **post-build**: CF Pages busca `dist/` en root del repo, no en `apps/web/dist`.

**Causa probable:** config CF Pages monorepo no apunta al output directory correcto.

---

## 2 · Estado conocido (Alex confirmed)

| Item | Status |
|---|---|
| `/admin/pre-stay` en prod | ✅ Muestra 7 columnas (WELCOME, T-14, T-7, T-1, T+1, CO-1, CO+1) — PR #113 sí deployó |
| Último deploy success | PR #113 (commit `494addc`) — deploy posterior funcionó. Algo cambió después. |
| Screenshots en repo | ✅ Ya están en `apps/web/public/karina-training/admin-*.png` (commit posterior a `2128b0f`) |
| CF Pages dashboard "Build output directory" | **A verificar en Phase A** — Alex no lo confirmó explícitamente todavía |

---

## 3 · Explicit scope

### ✅ YES — en scope

1. Diagnose por qué cambia el behavior de CF Pages output dir (era OK con #113, falla con feat branch)
2. Fix CF Pages config para que reconozca `apps/web/dist`
3. Verificar preview deploy verde
4. Merge PR a main vía squash
5. Monitor deploy prod, smoke test
6. Notificar a Alex con URL final

### ❌ NO — out of scope

- NO toques el contenido del `.astro` (texto, prosa, estructura) — WC ya lo dejó final
- NO captures más screenshots (Alex ya los subió + WC los renombró)
- NO toques otros wranglers (worker-bot, worker-pago, worker-tours)
- NO cambies `AdminLayout.astro` (el `active="home"` es deliberado)
- NO crees nuevos endpoints, migrations, features

Si encuentras algo fuera de scope: abre issue, NO fixees inline.

---

## 4 · Closed decisions

| Decisión | Valor |
|---|---|
| Branch | Continuar `feat/karina-training-doc`, commits encima |
| Commit style | `fix(cf-pages): ...` o `chore(deploy): ...` |
| Merge style | Squash + delete branch |
| Smoke test | `curl -I https://rincondelmar.club/admin/karina-training` debe retornar 302 (redirect login) |
| Friday > 5pm Acapulco | Preview OK, NO merge a main (CF Pages auto-deploys a prod en merge) |

---

## 5 · Implementation

### Phase A · Diagnose root cause (5-10 min)

**Pregúntale a Alex (necesario, sin esto trabajas a ciegas):**

> "Alex, en Cloudflare Dashboard → Pages → rincondelmar-bot → Settings → Builds & deployments, ¿qué dice estos 4 campos?
> 1. Build command:
> 2. Build output directory:
> 3. Root directory:
> 4. Framework preset:
>
> Y en Deployments history, ¿el último deploy con status 'Success' fue qué commit + fecha?"

Mapea el problema:

| Si "Build output directory" dice... | Acción |
|---|---|
| `dist` o vacío | Camino 1 — pedir a Alex cambiarlo a `apps/web/dist` |
| `apps/web/dist` | Camino 2 — el config está bien pero algo más se rompió. Investigar más |
| Otra cosa | Reportar a Alex, pedir input |

### Phase B · Fix CF Pages config

#### Camino 1 (preferido) · Alex cambia dashboard

Pídele a Alex:

> "Necesito que ajustes en CF Dashboard → Pages → rincondelmar-bot → Settings → Builds & deployments:
> - **Build output directory:** `apps/web/dist`
> - Confirma que **Build command** sea: `pnpm install --frozen-lockfile && pnpm --filter web build`
> - **Root directory** déjalo vacío o `/`
>
> Después haz un push manual de test (o nuevo commit en el branch) para trigger redeploy."

CC: espera confirmación de Alex. NO hagas cambios de código hasta que confirme. Mientras esperas, prepara phase D smoke checks.

#### Camino 2 (fallback) · Root wrangler.toml

Solo si Camino 1 no es viable. Crear `wrangler.toml` en root del repo:

```toml
# wrangler.toml — root para CF Pages monorepo
# Bindings de runtime están en apps/web/wrangler.toml.
# Este archivo solo le dice a CF Pages dónde está el build output.
name = "rincondelmar-bot"
compatibility_date = "2026-04-15"
compatibility_flags = ["nodejs_compat_v2"]
pages_build_output_dir = "apps/web/dist"
```

⚠️ Cuidado: puede causar conflicto con `apps/web/wrangler.toml` (doble config). Solo después de Alex confirmar imposibilidad de Camino 1.

```bash
git add wrangler.toml
git commit -m "fix(cf-pages): root wrangler.toml with apps/web/dist output dir

CF Pages monorepo discovery v2 fallaba al buscar 'dist/' en root.
Apuntando explícitamente al output de Astro build en apps/web/dist.

apps/web/wrangler.toml sigue como source-of-truth para runtime bindings
(D1, R2, KV, env vars). Este root file solo informa a CF Pages."
git push origin feat/karina-training-doc
```

### Phase C · Esperar redeploy preview

```bash
# Espera 3-5 min después del push o del cambio dashboard
sleep 300

# Pídele a Alex el preview URL del último deploy attempt
# Si sigue fallando, examinar nuevo build log y reportar a Alex
```

### Phase D · Verify preview (5 min)

Pídele a Alex que abra el preview URL en su browser, autenticado como `karina@`:

```
https://<preview-hash>.rincondelmar-bot.pages.dev/admin/karina-training
```

**10 smoke checks:**

| # | Check | Pass criteria |
|---|---|---|
| 1 | Auth | Logged out → 403. Logged in karina@ → 200 |
| 2 | Page renders | Title "Manual operativo · Karina" visible |
| 3 | TOC sidebar | Links a §1-§6 visibles |
| 4 | Anchors funcionan | Click §5.5 airbnb-content → scrollea |
| 5 | §2.5 Tabla canónica | 5 columnas (Airbnb/Booking/WhatsApp/Web) visibles |
| 6 | SVGs render | §2 mapa + §3 M1-M5 visibles |
| 7 | Screenshots | 7 imágenes admin-*.png cargan sin "broken icon" |
| 8 | §5.3 pre-stay | Menciona 7 touchpoints (WELCOME, T-14, T-7, T-1, T+1, CO-1, CO+1) |
| 9 | Mobile | Resize < 900px → single column, TOC arriba |
| 10 | `/admin/` navbar | Card "📚 Training Karina" visible en home |

Si algún check falla pero es fixable (typo, link roto, CSS broken), push fix commit y re-test. Si falla algo del build mismo, reporta a Alex.

### Phase E · Merge (cuando 10 checks pasan)

```bash
# Si tienes gh CLI
gh pr merge feat/karina-training-doc --squash --delete-branch \
  --subject "feat(admin): Karina training doc at /admin/karina-training" \
  --body "Merged after preview deploy verified green. 10 smoke checks passed.

CF Pages config fix included (Phase B Camino 1 or 2)."

# Sin gh: pídele a Alex que mergee desde GitHub UI
# https://github.com/alexanderhorn6720/rdm-bot/pulls
# Squash merge → delete branch
```

### Phase F · Monitor prod deploy + smoke (5-10 min)

```bash
sleep 300

# Verifica prod
curl -I https://rincondelmar.club/admin/karina-training
# Espera 302 (redirect to login) — eso indica que la ruta existe
# Si 404 → deploy no terminó o falló. Esperar otros 3 min.
```

Pídele a Alex que abra logged in `karina@`:
- https://rincondelmar.club/admin/karina-training
- Repetir los 10 smoke checks de Phase D

### Phase G · Notificar a Alex (final)

```
✅ Karina training doc live en producción.

URL: https://rincondelmar.club/admin/karina-training
Card en /admin/ navbar: "📚 Training Karina"

Cambios shipped:
- Fix CF Pages output directory (Camino X)
- 7 screenshots /admin/* embebidos
- Doc de ~60pp HTML con tabla canónica 5 cols, M1-M5, glosario, checklist 30d

Para Karina:
1. Magic-link a karina@rincondelmar.club
2. Abrir /admin/karina-training
3. Walkthrough en vivo 30-45 min recomendado primer pass
```

---

## 6 · Tests

| Test | Cómo verificar | Pass criteria |
|---|---|---|
| Build CF Pages | Dashboard → último deploy | "Success" verde |
| Preview accesible | curl + browser | 200 con login |
| Auth respeta rol | Login sin content_editor | 403 |
| Screenshots cargan | DevTools Network | admin-*.png → 200 |
| Prod accesible post-merge | curl + browser | 200 con login |
| Mobile responsive | Resize < 900px | Single column |

---

## 7 · Definition of done

- [ ] CF Pages build pasa (no más "dist not found")
- [ ] PR mergeado a main vía squash
- [ ] Prod deploy automático activado y exitoso
- [ ] `https://rincondelmar.club/admin/karina-training` retorna 200 con login `karina@`
- [ ] 7 screenshots cargan sin broken icons
- [ ] Card "📚 Training Karina" visible en `/admin/` navbar
- [ ] Alex notificado con URL final

---

## 8 · Risks + mitigations

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Dashboard CF requiere permisos de owner | Media | Alex tiene permisos. Si por algo no, Camino 2 (root wrangler.toml) |
| Camino 2 causa conflicto con apps/web/wrangler.toml | Media | Mantener root config mínimo (solo `pages_build_output_dir`). Si CF queja, eliminar root y solo dashboard fix |
| Build pasa pero `/admin/karina-training` 500 en runtime | Baja | Smoke check post-deploy detecta. Si pasa, ver Astro Workers logs |
| Astro JSX comments `{/* */}` causan problema | Muy baja | WC convirtió 48 de `<!-- -->` a `{/* */}`. Si falla, simplificar |
| Cambios concurrentes en main | Baja | Rebase si hay conflict. WC base = `2128b0f` + commits posteriores |
| Friday > 5pm Acapulco al momento de mergear | Variable | Preview OK, defer merge a lunes |

---

## 9 · Working notes for CC

- **Stuck > 30 min**: para, reporta a Alex, espera input
- **Out of scope finding**: abre issue, NO fixees inline
- **Self-review pre-commit**: lee tu propio diff
- **Time budget total**: 45 min. Si excedes 1.5x (≈70 min), stop y reporta
- **Comunicación con Alex**: Phase A (diagnose), Phase D (preview verde), Phase G (live). NO ping en cada step intermedio.

---

## 10 · Pre-flight checklist antes de DoIt

- [ ] `git pull origin main` en `rdm-discussion` (para tener este doc V2)
- [ ] `git fetch origin && git checkout feat/karina-training-doc && git pull` en `rdm-bot`
- [ ] Verificar último commit incluye los screenshots PNG en `apps/web/public/karina-training/`
- [ ] Tienes acceso write a `rdm-bot`
- [ ] Alex disponible para responder Phase A (dashboard config) y Phase D (smoke checks browser)

Si los 5 son sí → arranca Phase A. Si algún no → reporta a Alex y espera.

---

## Comando para arrancar (copia esto al CC nuevo)

```
Lee threads/125-wc-karina-training-deploy-v2.md y
cc-instructions-bot/2026-05-18-karina-training-deploy-and-screenshots.md
en rdm-discussion.

Pre-flight: git pull en ambos repos (rdm-discussion + rdm-bot).
Después ejecuta DoIt según las 7 phases (A-G).
```
