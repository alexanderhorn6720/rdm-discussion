# CC Instructions — Review Content Architecture Proposal

**Date**: 2026-05-13
**From**: Alex (via WC)
**To**: Claude Code (CC)
**Priority**: P2 (análisis, no ejecución)
**ETA**: 2-3 horas trabajo CC

---

## ⚠️ NO EJECUTAR NADA

Esta tarea es **análisis y review puro**. NO construir, NO refactorizar templates, NO crear páginas. Solo investigar, opinar, y producir thread/37 con recomendaciones.

Cualquier ejecución requiere aprobación explícita de Alex después de revisar thread/37.

---

## Contexto

WC (Web Claude) trabajó con Alex el 2026-05-13 analizando el ecosistema completo de contenido del negocio:

- 34 templates AirBnB existentes (extraídos del DOM de la página de Respuestas Rápidas)
- 3 kits WhatsApp manuales que Alex envía a clientes que reservan por ese canal
- 1 doc paquete eventos detallado ($1,400/pax)

Alex confirmó que los kits WhatsApp también viven en el campo `Directions` ("Cómo llegar") de AirBnB. Por eso clientes AirBnB ya los tienen, los de WhatsApp NO.

WC propuso una arquitectura unificada centrada en un Welcome Guide en `rincondelmar.club/welcome/{property}` como single source of truth.

Antes de ejecutar nada, Alex quiere que CC revise el análisis, baje la información que falta, valide el stack, y opine.

---

## Inputs (leer antes de empezar)

1. **`threads/36-wc-templates-content-architecture-analysis.md`** — análisis completo WC (~15K palabras, 11 secciones)
2. **`knowledge/airbnb-templates-current-2026-05-13.md`** — 34 templates AirBnB en formato legible
3. **`knowledge/airbnb-templates-current-2026-05-13.json`** — los mismos en JSON programático
4. **`knowledge/whatsapp-kits-current-2026-05-13.md`** — 3 kits WhatsApp + paquete eventos

Referencia previa:
- **`threads/33-cc-guest360-phaseb-plan.md`** — plan Phase B Guest 360 (4 tablas D1 + UI admin)
- **`threads/35-cc-templates-system-for-wc.md`** — templates system already built (PR #5-#7)

---

## Tareas

### Tarea 1 — Revisar análisis WC

Lee thread/36 completo. Opina sobre:

1. ¿La categorización de los 34 templates es correcta? ¿Falta alguna?
2. ¿Las inconsistencias detectadas (servicio Morenas, precio bodas $1K vs $1.4K, conteo reseñas, tienda local) son reales o WC malinterpretó?
3. ¿La propuesta de 4 capas (Marketing/Decision/Stay/Retention) tiene sentido para tu modelo mental?
4. ¿La matriz "Qué va dónde" (sección 5.3) está bien repartida o sugieres ajustes?
5. ¿Hay duplicaciones que WC no detectó?
6. ¿El plan de fases (sección 8) es viable o cambia algo?

**Output**: sección 1 del thread/37 con tu review.

### Tarea 2 — Bajar contenido actual de campos AirBnB

WC solo conoce el contenido del campo `Directions` (los kits WhatsApp). Faltan **~10 campos** por listing × 4 listings = 40 campos a inventariar.

**Listings activos (post-cutover 2026-05-12)**:
| Listing AirBnB ID | Beds24 Room ID | Propiedad |
|---|---|---|
| 18780853 | 78695 | Rincón del Mar |
| 733868075691217916 | 74322 | Las Morenas |
| 18009632 | 74316 | Combinada (Dos Villas) |
| 1577678927412395161 | 637063 | Huerta Cocotera |

**Campos a bajar** (URL pattern: `airbnb.mx/hosting/listings/editor/{listingId}/{section}`):

```
/details/title
/details/description
/details/the-space
/details/guest-access
/details/other
/house-rules
/amenities
/arrival/directions
/arrival/house-manual
/arrival/check-in-method
```

**Approach sugerido**:
- CC tiene Chrome MCP tools disponibles (ver tool_search). Puede automatizar el scraping si Alex está logged in en su browser.
- Alternativa: pedir a Alex que haga Ctrl+S de cada página del editor y suba HTML a `/mnt/user-data/uploads/`. WC ya tiene parser que extrae con regex sobre divs específicos.
- Otra alternativa: usar AirBnB Listings API si CC tiene acceso (Alex ya usa Beds24 channel manager pero AirBnB tiene API directo via OAuth).

**Output**: `knowledge/airbnb-listing-fields-current-2026-05-13.md` con el contenido completo de los 40 campos, organizados por propiedad.

**Stats esperadas**: ~30-50K chars total (Description es 500 chars, The Space ~1000, Directions hasta 5000 según vimos en kits).

### Tarea 3 — Inventario `apps/web` actual

Revisar el repo `rincondelmar-bot-discussion` o `rincondelmar-bot` (sea donde viva apps/web):

1. ¿Qué páginas existen hoy en `apps/web/src/pages/`?
2. ¿Existe `/guia-llegada` (mencionada en template `PROG: 30 - Dos semanas antes Rdm`)? ¿Qué contiene?
3. ¿Existen páginas por propiedad? `/rincon-del-mar`, `/las-morenas`, `/huerta-cocotera`, `/combinada`?
4. ¿Existe `/eventos`?
5. ¿Existen `/blog/*` para SEO?
6. ¿Estructura mobile-first responsive?
7. ¿i18n setup existe (ES/EN)?
8. ¿Framework Astro + React islands está usando MDX, JSON, o D1 para contenido?
9. ¿Sitemap y SEO básico configurados?

**Output**: `knowledge/apps-web-inventory-2026-05-13.md`.

### Tarea 4 — Validar stack para Welcome Guide

WC propone 3 opciones (thread/36 sección 6.2):

**A. Build propio en `apps/web`** con Astro pages + React islands + content en R2/JSON
**B. SaaS** (Touch Stay $20-100/mes, Hostfully, Folio)
**C. Híbrido** con MDX hardcoded en repo

WC vota A. Pero falta CC valide:

1. ¿La integración con bot existente es factible? (Bot vive en `rincon-bot` Worker, llama a KB en R2 via Files API.)
2. ¿Cómo se inyectan datos dinámicos (clave caja, WiFi password) si la URL es pública? ¿Magic link? ¿Booking code in URL?
3. ¿Performance impact en apps/web actual? Welcome Guide podría agregar 100+ páginas estáticas (9 secciones × 5 propiedades × 2 idiomas).
4. ¿Cómo se sincronizan con Beds24 booking data? (e.g., WiFi password único por estancia.)
5. ¿Sistema de templates ya construido (thread/35) se reusa o es paralelo? ¿Conflicto con el patrón de placeholders existente?
6. ¿i18n en Astro 5: built-in `astro:i18n` o algo custom?
7. ¿PDF generation: server-side (Puppeteer en Worker), client-side (jsPDF), o pre-generado en build?
8. ¿Analytics: Cloudflare Web Analytics, Plausible, custom?

**Output**: sección 4 del thread/37 con tu recomendación argumentada.

### Tarea 5 — Identificar gotchas técnicos

Cosas que WC no consideró o ignora:

1. **AirBnB anti-off-platform policies**: Host-Only Fee 17.98% es nuevo. ¿AirBnB tiene reglas sobre linkear a sitios externos en mensajes? ¿Templates AirBnB pueden incluir `rincondelmar.club/welcome/...` URLs sin riesgo de suspensión?
2. **Casa Chamán Q3 2026**: el plan menciona Chamán como futuro. ¿Welcome Guide debe estar listo antes del launch o se construye on-demand?
3. **Multi-booking de Combinada**: cuando un guest reserva "Combinada" (Dos Villas), efectivamente toma RdM + Morenas. ¿Welcome Guide para Combinada existe como entidad propia o linkea a las dos individuales?
4. **WhatsApp Business API rate limits**: si bot manda welcome con link al guide, ¿impacto en quotas de ManyChat / WhatsApp?
5. **GDPR/LFPDPPP datos terceros**: WC detectó que templates archivan datos personales de Celene, Michel, AcaScuba, etc. ¿Migrar al guide reduce el riesgo o lo perpetúa?
6. **SEO Welcome Guide**: ¿debe ser indexable Google (URLs públicas) o no (behind auth)? Pro indexable: SEO bonus. Contra: info sensible si no auth.
7. **Beds24 booking webhook ya implementado** (memoria 2026-05-12): se puede usar para trigger welcome auto-send con link al guide.
8. **Cache strategy**: si Welcome Guide se carga muchas veces (guest comparte con familia), CF cache strategy.

**Output**: sección 5 del thread/37 con lista de gotchas y propuestas de mitigation.

### Tarea 6 — Output thread/37

Crear `threads/37-cc-content-architecture-review.md` con:

```
# Thread 37 — CC review of content architecture proposal

## 0. TL;DR
[Resumen 5 líneas: coincides con WC, diferencias clave, recomendación stack]

## 1. Review análisis WC (Tarea 1)
[Tu opinión sobre las 6 sub-preguntas]

## 2. Estado actual campos AirBnB (Tarea 2)
[Link a knowledge/airbnb-listing-fields-current-2026-05-13.md]
[Highlights de lo que encontraste: qué está bien, qué falta, qué duplica con templates/kits]

## 3. Estado actual apps/web (Tarea 3)
[Link a knowledge/apps-web-inventory-2026-05-13.md]
[Highlights de lo que existe y qué falta para Welcome Guide]

## 4. Recomendación stack (Tarea 4)
[Opción recomendada A/B/C con justificación técnica]
[Costos estimados (CC time, monthly recurring, hosting)]
[Migration path si después queremos cambiar]

## 5. Gotchas técnicos (Tarea 5)
[Lista con mitigation propuesta]

## 6. Plan de fases ajustado
[Si difiere de WC, propón cambios]
[Tiempos realistas por fase: CC time + Alex time]

## 7. Preguntas abiertas
[Qué necesitas que Alex responda antes de poder ejecutar]
[Qué necesitas que WC clarifique]

## 8. Sí/No proceder
[Tu recomendación final: vamos adelante, paramos, o pivotamos]
```

---

## Constraints

1. **NO EJECUTAR**: no construir Welcome Guide, no refactorizar templates, no tocar Make scenarios, no push a producción.
2. **Sí leer/inventariar**: bajar contenido AirBnB (read-only), inspeccionar repo (read-only).
3. **Sí crear archivos en el repo en formato MD/JSON**: knowledge files + thread/37.
4. **NO modificar templates en R2** (`templates/` prefix) — aunque encuentres algo a fixar, documenta en thread/37.
5. **Output Spanish técnico, conciso, sin elogios** (preferencia Alex).

---

## Lo que Alex va a hacer en paralelo

Mientras CC trabaja, Alex responde las 18 preguntas críticas de thread/36 sección 10:

- Operación: footer interno, clave caja, datos terceros, servicio Morenas, precio bodas, chef nombrada, Karina rol, reservación instantánea
- Estrategia: stack vote, auth público vs privado, EN priority, AirBnB scraping approach, Chamán content, kits Huerta/Combinada
- Contenido: direcciones físicas, tienda local, OXXO distancia, reseñas count

Estas respuestas + tu thread/37 = inputs completos para Fase 1 decisiones.

---

## Timeline

| Step | Owner | ETA |
|---|---|---|
| Crear thread/36 + knowledge files | WC | ✅ Hoy 2026-05-13 |
| CC tarea 1-6 → thread/37 | CC | 1-2 días |
| Alex responde 18 preguntas | Alex | 1-2 días |
| Decisión final go/no-go + approach | Alex + WC + CC | Joint review |
| Fase 1 (limpieza inconsistencias) | TBD según decisión | 1 semana |
| Fase 2 (build Welcome Guide) | TBD según decisión | 2-3 semanas |

Sin fechas duras. Análisis primero, ejecución después de validar.

---

## Notas finales

- Si encuentras algo que cambie radicalmente la propuesta WC (e.g., AirBnB ya tiene un Welcome Guide nativo que WC no conocía, o apps/web tiene una página `/welcome` ya construida), **detente y notifica antes de seguir**.
- Si tarea 2 (bajar campos AirBnB) requiere Alex login interactivo, marca esa parte como blocked y procede con tareas 1, 3, 4, 5 sin ese input.
- Recordatorio scope discipline: este task NO toca el bot, NO toca Make scenarios, NO toca Beds24 sync, NO toca el plan Guest 360 Phase B. Es puramente sobre content architecture.

— Alex (vía WC), 2026-05-13
