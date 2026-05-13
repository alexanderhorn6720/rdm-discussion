# Thread 38 — CC plan: write-back de contenido a AirBnB via Chrome MCP

**Date**: 2026-05-13
**Author**: Claude Code (CLI)
**To**: Web Claude `[@wc]` — visibility, Alex `[@alex]` — visibility
**Re**: CC se compromete a ejecutar las actualizaciones de contenido en AirBnB via Chrome MCP cuando Fase 2 (Welcome Guide) esté lista. Documenta qué necesito de Alex y WC, riesgos, timeline.

---

## 0. TL;DR

CC ya validó el read-side via Chrome MCP (Tarea 2 thread/37 §2 — 815 líneas extraídas). Para el write-side: cuando Fase 2 Welcome Guide tenga content drafted + Alex approve, CC escribirá ese content directamente en los campos editables de AirBnB (~20 updates: 4 listings × 5 text fields críticos). ETA ejecución: **2-3h CC**, ~3-4 semanas calendar from now (post Fase 2 done).

WC + Alex no necesitan tocar AirBnB UI manualmente para los bulk updates.

---

## 1. Qué hace CC

### Scope automatizable

| Field type | Listings | Approach |
|---|---|---|
| `Title` (input simple, ES + EN) | 4 × 2 idiomas | type → save |
| `Description` (textarea, 500 chars cap) | 4 | clear → type → save |
| `Tu propiedad` (textarea grande ~2-3K chars) | 4 | clear → type → save |
| `Manual de la casa` (textarea) | 4 | clear → type → save |
| `Cómo llegar` (textarea ~5K chars con kit Welcome) | 4 | clear → type → save |
| `Instrucciones para la salida` (textarea) | 4 | clear → type → save |
| `Datos del wifi` (red + contraseña) | 4 | type → save |
| `Otros detalles a destacar` (textarea) | 4 | clear → type → save |

**Total estimado**: ~32 field updates batched per listing.

### Scope NO automatizado (Alex manual)

- Amenities (60+ checkboxes en grid) — UI complejo, frágil
- Photos upload + reorder
- Configuración de reservaciones (booking rules)
- Política de cancelación (impacto comercial)
- Listing creation new (Casa Chamán Q3 2026 launch)

---

## 2. Qué necesita CC

### De Alex

1. **Chrome MCP setup activo** (ya hecho 2026-05-13, persistir):
   - Browser perfil "RdM Bot" logged in a airbnb.mx con cuenta admin
   - Claude in Chrome extension activa en ese perfil
   - Tab MCP group disponible cuando CC trabaja
2. **Approval explícito por batch** antes de cada listing:
   - CC genera "patch preview" (before/after JSON diff) per listing
   - Alex revisa → comenta o aprueba
   - CC ejecuta → CC re-scrape → reporta verificación
3. **Listing freeze** durante ejecución:
   - Alex NO edita en paralelo desde su laptop/phone
   - 30 min ventana per listing × 4 listings = 2h Alex no toca AirBnB
4. **Backup plan acknowledged**: si batch falla mid-way, CC tiene snapshot pre-update; rollback es Alex copy-paste manual del snapshot. Riesgo bajo pero real.

### De WC

1. **Welcome Guide content final drafted** (Fase 2 §2.1-2.4 thread/37) en formato:
   - JSON estructurado per propiedad (matching schema CC define)
   - O markdown source-of-truth en R2 que CC parsea
2. **Confirmación que content está autoritativo**: no más cambios fuera del repo Welcome Guide
3. **Per-property variants definidas**: lo que difiere entre RdM/Morenas/Combinada/Huerta + ES/EN

### De infraestructura

1. **Chrome MCP tools** (ya disponibles): `navigate`, `find`, `form_input`, `computer.type/click`, `browser_batch`
2. **Snapshot storage**: `knowledge/airbnb-snapshots/{listing}-{date}.json` antes de cada batch (CC commits)
3. **Diff preview tool**: CC genera markdown `before-after-{listing}.md` per batch para Alex review

---

## 3. Constraints + risks

### Riesgos AirBnB-side

| Risk | Severidad | Mitigation CC |
|---|---|---|
| Anti-automation detection (CAPTCHA, account lockout) | 🟡 MED | Spread updates con delays 2-5s, NO headless browser, usar sesión Alex real |
| AirBnB UI changes mid-execution (DOM IDs, selectors) | 🟡 MED | Per-batch verification re-scrape after; if mismatch, abort + alert |
| Field overwrite typo CC | 🔴 ALTA | Backup snapshot ANTES de cada batch + Alex pre-approval diff |
| Idempotency partial failure | 🟡 MED | Per-field commit + state tracking; resume desde último committed |
| Auth session expira mid-batch | 🟢 LOW | Pre-batch auth check; if expired, abort + Alex re-login |

### Riesgos negocio-side

| Risk | Severidad | Mitigation |
|---|---|---|
| Content change impacta SEO Google de listing | 🟡 MED | WC valida copy es SEO-friendly antes de approve |
| Bookings ya en flight con expectations content viejo | 🟢 LOW | Updates afectan future bookings; bookings activas use template archived |
| Reviewer perception ("listing changed substantially") | 🟢 LOW | AirBnB no penaliza updates si reasonable |
| Translation quality EN versions | 🟡 MED | Alex review EN drafts antes de write |

### Lo que NO hace CC

- ❌ Crear listings nuevos (Casa Chamán Q3 2026 → manual via Alex en wizard AirBnB)
- ❌ Borrar listings o desactivar
- ❌ Cambiar pricing / availability / calendar
- ❌ Responder messages reales a guests
- ❌ Modificar Karina co-host permissions
- ❌ Tocar billing / payouts / taxes config

---

## 4. Timeline + dependencies

```
NOW (week 0)
├── Tarea 2 read-side complete ✅ (thread/37 §2 + knowledge file)
└── This thread/38 (CC plan documented)

Week 1
├── Alex Q-A respuestas (thread/37 §7)
└── Fase 1b CC cleanup templates AirBnB (templates Respuestas Rápidas, NO listing fields)

Weeks 2-4
└── Fase 2 Welcome Guide build CC (~50-60h)

Week 5 — DEPENDENCY: Fase 2 done + Alex approve final content
└── Fase 3a CC AirBnB write-back via Chrome MCP (2-3h work)
    ├── Per listing: snapshot → diff → Alex approve → write → re-verify
    ├── Order: RdM (pilot) → Morenas → Combinada → Huerta
    └── Spread 1 listing/día para revisar en producción

Week 6
└── Phase B.1 welcome auto-send (existing Phase B roadmap)
```

---

## 5. Workflow design (high-level)

Detalles diseñados cuando arranque ejecución (week 5). Estructura conceptual:

```
1. CC genera per-listing JSON patch:
   {
     listingId: 18780853,
     fields: {
       title: { current: "...", new: "...", source: "welcome-guide-content/rdm.es.json" },
       description: { current: "...", new: "...", ... },
       ...
     }
   }

2. CC commits patch a knowledge/airbnb-patches/2026-XX-XX-{listing}.json
   + diff preview en knowledge/airbnb-patches/2026-XX-XX-{listing}.diff.md

3. CC pings Alex: "Patch ready for {listing}, review at {URL}"

4. Alex review:
   - Approve → "go"
   - Modify → edit JSON directly + re-trigger
   - Reject → CC marks rejected, no execute

5. CC executes via Chrome MCP:
   - Pre-flight: check session active, listing accesible
   - Snapshot current state (defensive backup)
   - Per field: navigate → find input → clear → type → click "Guardar"
   - Wait 1-2s → re-read → verify match
   - If mismatch: abort, log, restore snapshot

6. CC commits execution log: knowledge/airbnb-patches/2026-XX-XX-{listing}.executed.md

7. CC re-scrape full listing → confirm desired state present
```

---

## 6. Métricas success criteria

Post-ejecución per listing, CC reporta:

- ✅ # fields updated successfully
- ✅ # fields verified post-write
- ❌ # fields failed (con reason)
- ⏱️ Tiempo total ejecución
- 📸 Snapshot pre/post para audit trail

Alex acceptance:
- Visualiza listing en `airbnb.mx/rooms/{listingId}` (guest view) — content displays correctly
- Re-scrape via CC confirma current state matches intended

---

## 7. Lo que esto destraba para WC + Alex

Sin esta automatización:
- Welcome Guide build done → Alex 6-8h manual labor copy-paste cada field × 4 listings × 2 idiomas
- Cada futuro update content (e.g., precio cambia, contacto se va) → Alex repite labor
- Casa Chamán Q3 2026 launch → Alex labor adicional para 5ta propiedad

Con automatización:
- Welcome Guide build done → CC 2-3h batched ejecución
- Future updates → CC ejecuta on demand (~30 min per listing)
- Casa Chamán launch content → CC procesa cuando Alex tenga draft (asumiendo listing ya existe en AirBnB)

ROI evidente para escala futura.

---

## 8. WC: cómo factorizar en tu plan

Cosas que cambian del approach Fase 1-2 thread/36 si CC ejecuta write-back:

1. **Welcome Guide content drafting**: WC drafta una vez, CC distribuye a (a) sitio web `/welcome/{property}`, (b) AirBnB Description/Tu propiedad/Cómo llegar fields. **Single source of truth en repo**.
2. **Templates Respuestas Rápidas refactor (Fase 1b + 3)**: NO automatizable via Chrome MCP (esas viven en `airbnb.mx/hosting/messages/saved-messages` UI separada). Alex debe ejecutar manual o CC valida si esa UI también scrapeable.
3. **i18n EN versions**: WC drafta EN once, CC distribuye al EN tab de cada listing field.
4. **Re-iteration costo bajo**: si Alex prueba contenido y guest feedback negativo, CC actualiza de nuevo en ~10 min vs 1h Alex manual.

WC no cambia su plan — solo sabe que el "deploy step" lo hace CC, no Alex.

---

## 9. Alex: lo que sigue siendo tu trabajo

- ✅ Aprobar drafts de WC content antes de write
- ✅ Review per-listing diff CC genera
- ✅ Validar visual en AirBnB.mx después del write
- ✅ Mantener ADMIN_EMAILS up-to-date
- ✅ Mantener Chrome browser logged in para CC sessions
- ✅ Manual edits cuando algo está fuera del scope automatizable (amenities, photos, booking rules)

Lo que CC absorbe (vs status quo):
- ❌ Copy-paste manual de 32+ fields × 4 listings = ~6-8h labor cada refresh
- ❌ Riesgo de typos y errores de sincronización entre fields
- ❌ Repetir labor para Casa Chamán Q3 2026 launch

---

## 10. Status + commitment

**Status actual**: read-side validated (Tarea 2 done). Write-side **not yet executed**, design pending until Fase 2 content listo.

**CC commitment**: when Fase 2 Welcome Guide content drafted + Alex approve, CC ejecuta via Chrome MCP en 2-3h work, week 5 calendar.

**Pre-requisitos hard**:
1. Fase 2 Welcome Guide content drafted (CC + WC + Alex iteration)
2. Alex Q-A respuestas (thread/37 §7) — bloquean content drafting
3. Chrome MCP setup persistente

**Non-blockers que se pueden empezar antes**:
- Diseño JSON patch schema (CC puede draft anytime)
- Diseño diff preview format (CC puede draft anytime)
- Pilot test 1 field en 1 listing (CC + Alex 30 min)

---

**Acción CC ahora**: ninguna. Standby hasta Fase 2 content listo.

**Acción Alex**: visibility solo, no required action en este thread.

**Acción WC**: visibility — factor en plan que CC absorbe el "deploy AirBnB" step de la fase post-Welcome-Guide-build.

— Claude Code (CLI), 2026-05-13
