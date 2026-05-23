---
thread: 188
author: CC
date: 2026-05-23
topic: apps-admin-pwa-decision
mode: brain
status: open-for-alex-vote
related: [148, 178, 184]
deliverable: Decision draft for apps/admin "5-doc fiction" — rewrite docs OR build separate PWA app
---

# Thread/188 — apps/admin PWA Decision: Rewrite Docs OR Build Separate App

**From**: worktree B (CC-Discussion specs drafter, Opus 4.7)
**Spec parent**: thread/184 §3 task B3
**Authority**: WC preliminary recommendation. Alex final vote required.

---

## §1. Problema (1 frase)

5 docs claim un `apps/admin` PWA app separada en `admin.rincondelmar.club`; reality es admin que vive dentro de `apps/web/src/pages/admin/` y comparte manifest + service worker con el site público.

---

## §2. Reality check (filesystem 2026-05-23)

### Lo que dicen los docs

| Doc | Línea | Claim |
|---|---|---|
| `rdm-discussion/VISION.md` §"Apps" | 40 | `apps/admin` Worker Static, `admin.rincondelmar.club` |
| `rdm-discussion/VISION.md` §"Pilar 2" | 122 | `apps/admin` PWA, Bookings/Conv/Prompts/Configs/Pricing/Staff |
| `rdm-discussion/VISION.md` §"Tres pilares" | 220 | Sprint 2 — `apps/admin` + auth roles |
| `rdm-discussion/decisions/04-admin-board.md` | — | React + shadcn + TanStack + PWA |
| `rdm-discussion/decisions/07-pwa-mobile.md` | — | PWA día 1 |
| `rdm-bot/OPEN_QUESTIONS.md` PR3 §24 | — | manifest.json + service worker basic |

### Lo que existe en filesystem

| Path | Estado |
|---|---|
| `apps/admin/` | **NO EXISTE** |
| `apps/web/src/pages/admin/` | LIVE: airbnb-content, audit-logs.astro, bookings/, bot-metrics.astro, conv.astro, extra-guests.astro, health.astro, inbox.astro, karina-training/, pre-stay.astro, templates/ |
| `apps/web/public/manifest.webmanifest` | LIVE (start_url=`/`, scope=`/`, name "Rincón del Mar") |
| `apps/web/public/sw.js` | LIVE |
| Subdomain `admin.rincondelmar.club` | Sin verificación en este audit (Cloudflare dashboard). Asunción: no provisioned. |
| Better Auth gating `/admin/*` | LIVE per F2 §1 boundary table |

### Conclusión de reality check

PWA basics SÍ existen (manifest + sw.js) en `apps/web/public/`. El manifest tiene `scope: "/"` — cubre admin pages también, pero **start_url=`/`** lleva al site público no al admin. No hay manifest dedicado a admin con `scope: "/admin"` ni icon set específico ni subdomain split.

Lo que NO existe del claim original:
- App separada en `apps/admin/`
- Subdomain `admin.rincondelmar.club`
- Manifest dedicado a admin con scope `/admin`
- Build pipeline separado

Lo que SÍ existe que el META audit (A6) no detectó:
- `manifest.webmanifest` (extensión moderna; A6 buscó `manifest.json`)
- `sw.js` activo
- Admin pages funcionales y auth-gated

**El gap real es más pequeño que "5-doc fiction completa"**: hay infraestructura PWA, pero no segregada/named para admin.

---

## §3. Opciones

### Opción A — Rewrite docs para reflejar la realidad ("admin = subpages de apps/web con PWA compartido")

Actualizar los 5 docs para decir: "admin vive en `apps/web/src/pages/admin/`, comparte el PWA del site público, Better Auth gates el acceso. NO existe `apps/admin/` como app separada y NO está planeado a corto plazo."

**Pros**:
- Cero código nuevo. Effort doc-only ~2h.
- Refleja decisión de facto que ya se tomó hace meses.
- Elimina el "5-doc fiction" sin re-litigar arquitectura.
- VISION.md ya está fechado 2026-05-11 stale — actualización natural.
- Si futuro require subdomain admin separado, se redacta nuevo ADR específico.

**Cons**:
- "Pierdes" la visión PWA mobile-first admin que el ADR-07 + decisions/04 prometían.
- Bookings/Conv/Prompts/Configs/Pricing/Staff admin viven en apps/web junto a páginas guest-facing — mezcla de bundle (aunque code-split puede mitigar).
- Auth boundary depende de Better Auth gating server-side; un bug expone admin pages en bundle público.
- No hay icon set, splash screen ni install prompt dedicado a uso operacional (Karina + Alex en phone).

### Opción B — Commit to build separate `apps/admin/` PWA app

Crear `apps/admin/` como Worker Static Assets app. Migrar pages de `apps/web/src/pages/admin/*` a `apps/admin/src/pages/*`. Manifest dedicado con scope `/`. Subdomain `admin.rincondelmar.club` provisioned. Better Auth shared package. Build pipeline separado vía Turborepo.

**Pros**:
- Boundary físico: admin code, assets, deploys aislados de site público.
- Bundle separado: admin assets no servidos a guests (privacy + perf).
- PWA install prompt dedicado: Karina puede "Add to home screen" la admin app, separado del site público.
- Iconography y theming admin-specific.
- Reduce blast radius: bug en admin no impacta site público (workers separados).

**Cons**:
- Effort alto: ~3-5 días CC (mover ~12 pages + auth shared package + manifest dedicado + DNS + CF setup).
- Migration de imports cross-package; potencial breakage en routes existentes.
- Better Auth requires careful shared-state setup entre workers.
- Subdomain provisioning Alex (DNS + CF dashboard + worker route).
- Mantiene 2 PWAs en lugar de 1 (más superficie de mantenimiento).
- Beneficio operativo marginal hoy: Karina + Alex ya usan admin desde phone vía rincondelmar.club/admin con auth, funciona.

---

## §4. Voto WC preliminar

**Recomendación: Opción A** (rewrite docs).

*WC preliminary, Alex final.*

Razón:
- Coste/beneficio: A es ~2h doc-update; B es ~3-5 días CC + subdomain provisioning + ongoing 2-PWA maintenance. Beneficio operativo de B vs estado actual = marginal (Karina ya opera desde phone).
- "Boundary físico" como justificación de B se debilita: Better Auth ya gates admin desde 2026-Q1. El bundle leak hipotético es un bug, no una decisión arquitectural — se mitiga con code-split en Astro sin requerir app separada.
- Existing `manifest.webmanifest` + `sw.js` cubren el "PWA día 1" del ADR-07 — sólo no están customizados para admin. Si en futuro se quiere install prompt admin-dedicated, se añade un segundo manifest con scope `/admin` sin separar la app (incremental).
- La fiction nace de no haber actualizado VISION desde 2026-05-11. Es maintenance de docs, no decisión arquitectural pendiente.

Si Alex prefiere B: spec separado WC-Platform brain (1 día), ADR formal en rdm-platform/decisions/ADR-005 candidate, plan de migración con tests de regresión auth.

---

## §5. Implementación si Alex confirma Opción A

Una sola PR rdm-discussion + una PR rdm-bot, ~2h CC total:

### En rdm-discussion

1. `VISION.md`:
   - Reescribir §"Apps" tabla: eliminar fila `apps/admin`, añadir nota explicativa: "admin = subpaths under apps/web, auth-gated via Better Auth"
   - Reescribir §"Pilar 2 — Admin board": "admin existe LIVE en `apps/web/src/pages/admin/*`. PWA compartido con site público (manifest.webmanifest + sw.js). Subdomain admin separado NO planeado actualmente."
   - Reescribir §"Tres pilares" tabla: Sprint 2 ya completado (admin LIVE).
2. `decisions/04-admin-board.md`:
   - Status update: "Decidido — implementado parcialmente. Admin vive en apps/web subpages, no en apps/admin app separada. Stack: Astro 5 + React 19 islands (no shadcn/TanStack puros)."
3. `decisions/07-pwa-mobile.md`:
   - Status update: "Decidido — PWA día 1 LIVE en apps/web (manifest.webmanifest + sw.js compartidos). NO separate admin PWA."

### En rdm-bot

4. `OPEN_QUESTIONS.md` PR3 §24:
   - Update entry: "manifest.json + sw resolved 2026-05-NN — manifest.webmanifest + sw.js LIVE en apps/web/public/."

### Optional follow-up (out of scope this decision)

Si Alex quiere install prompt admin-specific (sin separar app): añadir secundario `apps/web/public/admin.webmanifest` con scope `/admin`, icon set distintivo. ~1h CC. Decisión separada.

---

## §6. Implementación si Alex confirma Opción B

ADR formal requerido en `rdm-platform/decisions/ADR-005-apps-admin-split.md` (CC read-only en platform, lo redacta WC-Platform). Spec downstream:

1. **WC-Platform spec** (1 día brain): boundary, build pipeline, auth shared package, subdomain plan, migration order, rollback.
2. **Alex pre-flight** (~30 min): DNS subdomain, CF worker route, secrets duplicados si aplica.
3. **CC implementation** (~3-5 días):
   - Crear `apps/admin/` skeleton (Astro 5 + React 19, matching apps/web tooling)
   - Mover ~12 pages
   - Shared auth package `packages/auth/` o adapter
   - Manifest dedicado, icon set, theme
   - Subdomain wrangler.toml route
   - Regression tests auth + smoke per page
4. **Soak + cutover** (~2 días): admin.rincondelmar.club green, old `/admin/*` redirect, rollback path.

Bloqueador: Q3.1 (G7 Alex vote thread/148) sigue siendo independiente. Esto no destrabaría M1.

---

## §7. Bloqueador downstream

Cualquier path se puede ejecutar después de Alex vote — ni A ni B son hardcoded blockers de otros items en el pipeline (M1, F1/F2/F3, Karina-fication). Pero mientras no se cierre:

- "5-doc fiction" persiste en VISION + decisions/04 + decisions/07 + OPEN_QUESTIONS.
- Cualquier nuevo CC session que lea VISION puede asumir que `apps/admin/` existe (riesgo de planificación errónea).
- ADR-005 candidate en rdm-platform/README "Future ADRs" sigue siendo placeholder.

---

## §8. Definition of done — B3

- [x] Reality check filesystem documentado (existe manifest.webmanifest + sw.js, NO existe apps/admin/)
- [x] Hallazgo bonus: META audit A6 missed manifest.webmanifest (buscó `.json`)
- [x] Dos opciones A/B con pros/cons + implementación plan
- [x] Voto WC preliminar registrado (Opción A)
- [x] Status `open-for-alex-vote` (no se cierra sin voto Alex)

**Next action**: Alex vota A/B. Si A: CC follow-up session (~2h) edita los 5 docs. Si B: WC-Platform brain spec + ADR-005.

---

**END THREAD/188**
