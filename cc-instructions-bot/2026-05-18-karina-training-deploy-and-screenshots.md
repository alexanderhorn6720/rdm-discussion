# Karina Training — Fix Deploy + Screenshots + Ship

**Spec for:** CC-Bot
**Author:** WC
**Date:** 2026-05-18
**Branch existente:** `feat/karina-training-doc` (commit `2128b0f` pushed)
**Working mode:** DoIt autónomo

---

## 1 · Context

WC armó un manual operativo para Karina (~60 pp HTML) en `apps/web/src/pages/admin/karina-training/index.astro`. Branch `feat/karina-training-doc` pushed.

**CF Pages preview deploy FAILED** con error:

```
2026-05-18T21:52:07.902838Z	Validating asset output directory
2026-05-18T21:52:07.902838Z	Error: Output directory "dist" not found.
2026-05-18T21:52:08.763735Z	Failed: build output directory not found
```

El build de Astro **sí completó** (`Server built in 19.86s` con output en `/opt/buildhome/repo/apps/web/dist/`), pero CF Pages busca `dist/` en root del repo, no en `apps/web/`.

Esto es un problema de **configuración CF Pages**, no del código del PR. Mi PR no introduce nada que causa esto.

**Hipótesis:** la última deploy exitosa fue antes de un cambio en CF dashboard que rompió el `output directory` config, o un cambio en wrangler ubicación que CF no detecta.

Confirmación a verificar al inicio: si `https://rincondelmar.club/admin/pre-stay` **muestra** los touchpoints in-stay y post-stay (PR #113), entonces #113 sí deployó y mi PR es el primero que falla → algo nuevo en mi commit. Si NO se ven, entonces #113 también falló y es problema preexistente independiente.

---

## 2 · Explicit scope

### ✅ YES — en scope

1. **Diagnose** último deploy exitoso (cuál commit fue + cuándo)
2. **Fix CF Pages deploy** — crear wrangler.toml root o ajustar configs
3. **Capturar screenshots** de las páginas `/admin/*` para el doc training
4. **Verify** el doc se ve bien en preview
5. **Merge** PR a main (después de preview verde)
6. **Monitor** deploy a producción
7. **Smoke test** post-deploy: `/admin/karina-training` retorna 200 logged in
8. **Commits semánticos** apilados encima de `feat/karina-training-doc`

### ❌ NO — out of scope

- NO tocar contenido del doc (texto, estructura, prosa) — eso lo armó WC
- NO crear nuevas funciones del bot, nuevos admin endpoints
- NO cambiar AdminLayout `active` type union (usé `active="home"` deliberadamente)
- NO modificar otros wranglers (worker-bot, worker-pago, worker-tours)
- NO tocar otras Cloudflare resources (D1, R2, KV)
- NO subir secrets en commits
- Si encuentras algo fuera de scope (typo en otro page, bug en otra área): abre issue, NO fixees inline

---

## 3 · Closed decisions

| Decisión | Valor |
|---|---|
| Branch | Continuar `feat/karina-training-doc` (commits encima del `2128b0f`) |
| Auth screenshots | Magic-link de Karina (Alex te lo provee al arrancar) |
| Screenshots format | PNG, viewport 1400×900, comprimir < 500 KB cada uno via imagemagick si necesario |
| Screenshot storage | `apps/web/public/karina-training/admin-*.png` |
| Commits | Semantic conventional commits, prefix `feat(karina-training):` o `fix(cf-pages):` |
| Merge style | Squash merge cuando preview verde |
| Smoke test | Logged in as `karina@`, navegar a `/admin/karina-training`, verificar render |

---

## 4 · Implementation

### Phase A · Diagnose (10 min)

```bash
# A.1 — checkout branch existente
cd <rdm-bot>
git fetch origin
git checkout feat/karina-training-doc
git pull origin feat/karina-training-doc
git log --oneline -5

# A.2 — verifica si prod tiene PR #113 features (in-stay touchpoints)
curl -I https://rincondelmar.club/admin
# Si retorna 302 → login required → site OK respondiendo
# Pedir a Alex: ¿se ven 6 touchpoints en /admin/pre-stay? (welcome, T-14, T-7, T-1, T+1 in-stay, T+3 post-stay)
# Si SÍ ve los 6: #113 deployó OK → problema es mi PR
# Si NO ve los 6 (solo 4): #113 también falló → problema preexistente

# A.3 — verifica configuración CF Pages
# Esto requiere Alex en el dashboard:
#   Cloudflare Dashboard → Pages → rincondelmar-bot → Settings → Builds & deployments
#   Confirma estos valores:
#     - Production branch: main
#     - Build command: pnpm install --frozen-lockfile && pnpm --filter web build
#     - Build output directory: ⚠️ debe ser "apps/web/dist" o "/apps/web/dist"
#     - Root directory: vacío o "/"
#
# Si "Build output directory" dice "dist" o vacío → ese es el bug
# Si dice "apps/web/dist" → otra cosa está mal, investigar más
```

**Pide a Alex que verifique en el dashboard CF Pages el campo "Build output directory" y reporte.**

### Phase B · Fix CF Pages config

Hay 2 caminos según diagnose:

#### Camino 1 · Dashboard fix (preferido)

Si el campo "Build output directory" en CF está mal, **Alex** lo ajusta en dashboard a `apps/web/dist`. Después el siguiente push trigger redeploy.

CC: no hace cambios de código. Solo espera el dashboard fix de Alex.

#### Camino 2 · Code fix (fallback)

Si Alex no puede cambiar el dashboard o no quiere, agrega `wrangler.toml` en root del repo:

```toml
# wrangler.toml (root)
# Cloudflare Pages config para monorepo apps/web.
# Esto le dice a CF Pages dónde está el output después de build.
# Bindings de runtime quedan en apps/web/wrangler.toml.
name = "rincondelmar-bot"
compatibility_date = "2026-04-15"
compatibility_flags = ["nodejs_compat_v2"]
pages_build_output_dir = "apps/web/dist"
```

⚠️ **CRÍTICO**: solo agregar este archivo **si Camino 1 no es viable**. Hay riesgo de doble-config (root + apps/web/) que confunde a CF. Confirma con Alex antes de commitear esto.

```bash
git add wrangler.toml
git commit -m "fix(cf-pages): root wrangler.toml with apps/web/dist output dir"
git push origin feat/karina-training-doc
```

Espera 3-5 min y verifica el nuevo build log en CF Pages dashboard.

### Phase C · Capturar screenshots (~60 min)

Necesitas Chrome MCP autenticado. **Pídele a Alex**:

> "Alex, necesito magic-link a `karina@rincondelmar.club` para autenticar Chrome MCP. Genera uno en `/login` y mándamelo aquí. Tiene 15 min de TTL."

Una vez autenticado en Chrome MCP:

```bash
# Lista de screenshots a capturar
# Path: apps/web/public/karina-training/{filename}.png
```

| # | Filename | URL | Notas |
|---|---|---|---|
| 1 | `admin-nav.png` | https://rincondelmar.club/admin | Top navigation bar, crop arriba |
| 2 | `admin-inbox.png` | https://rincondelmar.club/admin/inbox | Lista de conversaciones con ejemplos visibles |
| 3 | `admin-bookings-list.png` | https://rincondelmar.club/admin/bookings?view=list | Vista lista, filtros visibles |
| 4 | `admin-pre-stay.png` | https://rincondelmar.club/admin/pre-stay | Grid de touchpoints status |
| 5 | `admin-extra-guests.png` | https://rincondelmar.club/admin/extra-guests | Lista de capturas (si vacía, anota "vacía" en commit) |
| 6 | `admin-airbnb-content.png` | https://rincondelmar.club/admin/airbnb-content | Overview de cards de las 4 propiedades |
| 7 | `admin-airbnb-content-editor.png` | https://rincondelmar.club/admin/airbnb-content (click una card → captura editor) | Editor de un listing específico |

**Procedure para cada screenshot:**

```python
# Pseudocode Chrome MCP
chrome_navigate(url)
wait_for_load(timeout=10s)  # esperar que React islands hidraten
chrome_screenshot(viewport=1400x900, fullpage=False)
save_to(f"apps/web/public/karina-training/{filename}.png")

# Si el PNG > 500 KB, comprimir
if file_size > 500_000:
    imagemagick_compress(file, quality=85)
```

Si una página tiene datos sensibles (números de teléfono reales, nombres de clientes reales en producción), **anonimiza con CSS injection antes del screenshot**:

```javascript
// Inyecta antes del screenshot
document.querySelectorAll('[data-pii]').forEach(el => {
  el.textContent = 'Cliente Ejemplo';
});
document.querySelectorAll('.phone-number').forEach(el => {
  el.textContent = '+52 55 1234 5678';
});
```

Si no hay clases `data-pii` o `.phone-number` específicas (probablemente no las hay), **revisa cada screenshot manualmente** antes de commitear. Si tiene datos reales de cliente:

| Opción | Detalle |
|---|---|
| A · Editar PNG | Usar imagemagick o similar para blur de las áreas con PII |
| B · Re-capturar en staging | Si existe staging con seed data |
| C · Re-capturar con datos de demo | Crear booking demo de "Cliente Ejemplo" en Beds24 |

**Pide a Alex**: "¿prefieres blur con imagemagick o data de demo en staging? Va a tardar X más con cada opción."

Después de capturar las 7, commit:

```bash
git add apps/web/public/karina-training/admin-*.png
git commit -m "feat(karina-training): screenshots batch · 7 admin pages

Captured via Chrome MCP authenticated as karina@.
PII reviewed manually (no real client data visible).
Compressed to < 500KB each.

Replaces placeholders in /admin/karina-training doc."
git push origin feat/karina-training-doc
```

### Phase D · Verify preview deploy

Después del push de Phase B (fix) + Phase C (screenshots), CF Pages debe trigger nuevo preview. Espera 3-5 min.

```bash
# Espera y verifica
sleep 300

# Check si build OK
# Pídele a Alex el preview URL del último deploy de CF Pages
# Ejemplo: https://feat-karina-training-doc.rdm-bot-xyz.pages.dev/admin/karina-training
```

**Smoke checks preview** (Alex te ayuda con browser auth):

| Check | Pass criteria |
|---|---|
| 1 · Auth | Logged out → 403 · Logged in karina@ → 200 |
| 2 · Page renders | Title "Manual operativo · Karina" visible |
| 3 · TOC visible | Sidebar con links a §1-§6 |
| 4 · Anchors funcionan | Click §5 admin training → scrollea |
| 5 · Tabla canónica §2.5 | 5 columnas visibles (Airbnb/Booking/WhatsApp/Web) |
| 6 · SVGs renderean | §2 mapa + §3 M1-M5 visibles |
| 7 · Screenshots | Imágenes admin-*.png cargan (no broken icons) |
| 8 · Mobile | Resize < 900px → single column |
| 9 · `/admin/` navbar | Nuevo card "📚 Training Karina" visible |
| 10 · No errores consola | Open DevTools → no red errors |

Si falla alguno, fix specific issue, push commit, repeat. Si no es trivial, **STOP, reporta a Alex con detalle del fallo**.

### Phase E · Merge a main

Cuando los 10 smoke checks pasan en preview:

```bash
# Opción 1 — gh CLI (si disponible)
gh pr merge feat/karina-training-doc --squash --delete-branch

# Opción 2 — manual desde GitHub UI
# https://github.com/alexanderhorn6720/rdm-bot/pulls
# Squash and merge → delete branch
```

### Phase F · Monitor deploy producción + smoke test

Después de merge, CF Pages debe deployar `main` a `rincondelmar.club` en 3-5 min.

```bash
sleep 300

# Smoke prod
curl -I https://rincondelmar.club/admin/karina-training
# Debe retornar 302 (redirect to login) o 200 si tienes session

# Visual smoke con Alex en browser
# 1. Login as karina@rincondelmar.club
# 2. Navegar a https://rincondelmar.club/admin/karina-training
# 3. Verificar 10 checks de Phase D pasan en prod también
```

Si prod falla pero preview pasó, hay diferencia de config entre preview y production en CF Pages. **Escala a Alex** con el log.

### Phase G · Notificar a Alex

Mensaje final a Alex en WhatsApp:

```
✅ Karina training doc live en prod.

URL: https://rincondelmar.club/admin/karina-training

Cambios shipped:
- Fix CF Pages output dir (root wrangler.toml o dashboard, según camino)
- 7 screenshots /admin/* capturados y embebidos
- Doc de 60pp HTML, tabla canónica 5 cols, M1-M5, glosario, checklist 30d

Para Karina:
- Magic-link a karina@rincondelmar.club, navegar al URL
- Walkthrough en vivo 30-45 min recomendado primer pass
```

---

## 5 · Tests

| Test | Cómo verificar | Pass criteria |
|---|---|---|
| Build pasa | CF Pages dashboard → último deploy | "Success" verde |
| Page accesible | `curl -I` o browser | 200 logged in, 403 logged out |
| Auth respeta rol | Login como user sin content_editor | 403 |
| Screenshots cargan | Network tab DevTools | `admin-*.png` retornan 200 |
| TOC sticky funciona | Scroll en preview | Sidebar sigue visible |
| Mobile responsive | Resize < 900px | Single column, TOC arriba |

---

## 6 · Definition of done

- [ ] CF Pages build pasa (no más "dist not found")
- [ ] `feat/karina-training-doc` branch contiene commit(s) de fix + screenshots
- [ ] Preview deploy verde y 10 smoke checks pasan
- [ ] PR mergeado a main vía squash
- [ ] Prod deploy automático activado y exitoso
- [ ] `https://rincondelmar.club/admin/karina-training` retorna 200 con login `karina@`
- [ ] 7 screenshots embebidos correctamente (no broken images)
- [ ] No PII visible en screenshots (verificación manual)
- [ ] Card "📚 Training Karina" visible en `/admin/` navbar
- [ ] Alex notificado con URL final + summary

---

## 7 · Risks + mitigations

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Dashboard CF Pages config tocado por Alex/auto-update | Alta | Confirmar con Alex antes de cambiar nada. Camino 1 (dashboard) es primero. |
| Doble wrangler.toml causa conflicto | Media | Solo crear root wrangler.toml si Camino 1 imposible. Si lo creas, mínimo (solo `pages_build_output_dir`). |
| Screenshots con PII real | Media | Review manual cada PNG antes commit. Blur con imagemagick si necesario. |
| Magic-link expira mid-session | Media | Si pasa, pedir nuevo a Alex, retomar. |
| Chrome MCP no autentica via magic-link | Media | Pedir a Alex setup alternativo: session cookie export, o cuenta dedicada `screenshots@`. |
| Build pasa pero `/admin/karina-training` falla en runtime | Baja | Smoke check post-deploy detecta. Si pasa, revisar logs CF Workers, posible problema con `isContentEditor` import. |
| Mi código (WC) tiene bug Astro que no detecté en sandbox | Baja-Media | Si build pasa pero render falla, ver Astro error en CF Pages logs. Posible: `{/* */}` JSX comments mal escritos. Si pasa, simplificar a remover comments. |
| Cambios concurrentes en main entre push y merge | Baja | Rebase si hay conflict. PR descripcion menciona base commit. |

---

## 8 · Acceptance criteria (Alex sign-off)

Para que Alex apruebe el work:

1. Ver `https://rincondelmar.club/admin/karina-training` cargando bien en su browser
2. Confirmar que Karina con magic-link a `karina@` puede acceder
3. Spot-check 3 secciones aleatorias del doc (§2.5 tabla, §4 URLs, §5.5 airbnb-content)
4. Verificar mobile en su teléfono (TOC arriba, single column)

---

## 9 · Working notes for CC-Bot

- **Time budget**: ~3h total. Si excedes 1.5x (4.5h), stop y reporta.
- **Stuck > 30 min**: para, reporta, espera input.
- **Out of scope finding**: abre issue, NO fixees inline.
- **Self-review pre-commit**: lee tu propio diff antes de cada push.
- **Pre-flight check antes de Phase B/C**: Alex confirmó plan? Magic-link recibido?
- **Friday > 5pm**: si pasaste 5pm hora Acapulco un viernes, pausa deploy a prod hasta lunes. Preview OK, merge no.

---

## 10 · Communication

Reporta a Alex en estos momentos:

| Trigger | Mensaje |
|---|---|
| Phase A done | "Diagnose: [Camino 1 viable / Camino 2 needed]. Necesito tu input en CF dashboard." |
| Pre-Phase C | "Listo para screenshots. Mándame magic-link `karina@`." |
| Pre-Phase E | "Preview deploy verde. 10/10 smoke checks pasan. ¿Mergeo?" |
| Phase F failed | "Prod deploy falló post-merge. Adjunto log. Necesito tu input." |
| Phase G done | "✅ Live in prod. URL: ..." (mensaje completo en §4 Phase G) |

No reportes en cada paso intermedio. Trabajo en batches.
