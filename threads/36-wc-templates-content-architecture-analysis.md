# Thread 36 — Templates content architecture analysis (WC)

**Date**: 2026-05-13
**Author**: Web Claude (WC) for Alex
**To**: Claude Code (CC), Alex
**Re**: Análisis completo del ecosistema de contenido — templates AirBnB, kits WhatsApp, campos AirBnB, sitio web. Propuesta de arquitectura unificada Welcome Guide.

⚠️ **NADIE EJECUTA NADA.** Este es análisis y propuesta. CC debe revisar, bajar info adicional y opinar antes de cualquier construcción.

---

## 0. TL;DR

Alex pidió analizar todos los templates AirBnB que usa hoy + los kits WhatsApp que envía manualmente. Análisis completo en 5 partes:

1. **Inventario actual**: 34 templates AirBnB extraídos + 3 kits WhatsApp + 1 doc paquete eventos
2. **Mapeo de campos AirBnB**: ~12 campos donde vive contenido (Description, The Space, Directions, House Manual, etc.) — pero solo conocemos contenido de algunos
3. **Análisis de duplicaciones e inconsistencias**: contenido está en 4-5 lugares, se desincroniza
4. **Propuesta arquitectónica**: Welcome Guide en `rincondelmar.club/welcome/{property}` como single source of truth, mensajes AirBnB linkean
5. **Plan de fases**: Fase 0 (decisiones) → Fase 1 (construir guide) → Fase 2 (refactor templates) → Fase 3 (in-property) → Fase 4 (bot integration)

**Lo que CC necesita hacer**: ver sección 9 "Tareas para CC". Resumen: revisar análisis, bajar campos AirBnB faltantes de los 4 listings, validar approach stack (build vs SaaS), opinar todo.

**Lo que Alex necesita decidir**: ver sección 10 "Preguntas críticas para Alex".

---

## 1. Inventario de contenido actual

### 1.1 AirBnB templates (Respuestas rápidas)

**34 templates extraídos** del HTML estático de la página `airbnb.mx/hosting/messages/saved-messages` (Alex Ctrl+S de la página, WC parseó con regex sobre `<div class="pim5ij3">`).

Archivos en `knowledge/`:
- `airbnb-templates-current-2026-05-13.md` — readable
- `airbnb-templates-current-2026-05-13.json` — programático

Categorización:

| Categoría | # | Propósito |
|---|---|---|
| Inquiry response (pre-booking) | 10 | Responder cuando preguntan disponibilidad |
| Post-booking welcome | 4 | Confirmar reserva + promesa T-14 |
| Pre-arrival T-14 | 2 | Definir menú chef |
| Pre-arrival T-7 | 2 | Checklist viaje |
| Pre-arrival T-1 | 3 | Dirección + clave caja |
| In-stay T+1 | 1 | Check-in cómo estuvo + upsells |
| Pre-checkout T-1 | 1 | Recordatorio salida 11am |
| Checkout day | 2 | Despedida + review CTAs |
| FAQ / handoff | 5 | Karina, signatures, servicio Morenas detalle |
| Sales follow-up | 2 | Lost dates, weekend push |
| Weddings | 2 | Catálogo paquete bodas ES + EN |

### 1.2 Kits WhatsApp manuales

**3 documentos** que Alex envía por WhatsApp a clientes que reservaron por ese canal.

Archivo en `knowledge/whatsapp-kits-current-2026-05-13.md`.

| Documento | Length | Propiedad |
|---|---|---|
| Kit RdM | ~5,400 chars | Rincón del Mar |
| Kit Morenas | ~5,800 chars | Las Morenas |
| Paquete Eventos | ~1,800 chars | Catálogo eventos $1,400/pax detallado |

Ambos kits siguen 6 secciones: viaje/llegada, servicio cocina, supermercados, actividades, restaurantes, eventos.

### 1.3 Campos AirBnB (no extraídos aún)

AirBnB ofrece ~12 campos donde vive contenido. Solo conocemos algunos:

| Campo | Sabemos su contenido? |
|---|---|
| Title | ❌ (parcialmente, memoria 2026-05-12 menciona drafts) |
| Description (500 chars) | 🟡 Alex tiene draft 3,890 chars en memoria (¿está aplicado o solo draft?) |
| The Space (~1,000 chars) | ❌ |
| Guest Access | ❌ |
| Other Things to Note | ❌ |
| House Rules | ❌ |
| Amenities (checkboxes) | 🟡 Parcialmente conocido |
| Photos | 🟡 Hay archivo `getlisting_*.htm` en uploads |
| **Directions ("Cómo llegar")** | ✅ Confirmado por Alex: contiene el "Kit WhatsApp completo" |
| **House Manual ("Manual de la casa")** | ❌ |
| Check-in Instructions | ❌ |
| Cancellation Policy | ❌ |

**🔴 Crítico**: CC debe bajar el contenido actual de todos estos campos para las 4 propiedades (Rincón del Mar, Las Morenas, Combinada Dos Villas, Huerta Cocotera). Ver tarea CC #2.

### 1.4 Sitio web actual

URL: `rincondelmar.club`
Stack: Astro 5 + React 19 + CF Pages + monorepo `apps/web`

Lo que se sabe que existe:
- Homepage
- Página `/guia-llegada` (mencionada en template `PROG: 30 - Dos semanas antes Rdm`)
- Linktree custom `/r`

Lo que NO sabemos:
- ¿Páginas individuales por propiedad? ¿Qué contenido?
- ¿Página `/eventos`?
- ¿Páginas SEO/blog?
- ¿Mobile-first o responsive?

CC tiene acceso al repo, puede inventariar.

---

## 2. Mapeo: ¿Qué hay vs. qué falta?

### 2.1 Cobertura por propiedad × momento del lifecycle

| | RdM | Morenas | Huerta | Combinada |
|---|---|---|---|---|
| Inquiry ES | ✅ (2 variantes) | ✅ (2 variantes) | ✅ | ✅ |
| Inquiry EN | ✅ | ✅ | ❌ | ✅ |
| Welcome ES | ✅ | ✅ | ✅ | ❌ |
| Welcome EN | ❌ | ❌ | ❌ | ❌ |
| T-14 | ✅ | ✅ | ❌ | ❌ |
| T-7 | ❌ | ❌ | ✅ | ✅ (ambas) |
| T-1 | ✅ | ✅ | ✅ | ❌ |
| T+1 in-stay | 🟡 genérico | 🟡 genérico | 🟡 genérico | 🟡 genérico |
| T-1 pre-checkout | 🟡 genérico | 🟡 genérico | 🟡 genérico | 🟡 genérico |
| Día salida | 🟡 genérico | 🟡 genérico | 🟡 genérico | 🟡 genérico |
| Kit WhatsApp | ✅ ($1,400 evt) | ✅ (sin $1,400) | ❌ | ❌ |

### 2.2 Gaps prioritarios

🔴 **Crítico**:
- Welcome post-booking EN: 0 propiedades cubiertas
- Welcome Combinada: 0 cobertura
- T-14/T-7 Combinada: 0 cobertura individual
- T-1 Combinada: 0 cobertura
- Kit WhatsApp Huerta: 0
- Kit WhatsApp Combinada: 0

🟡 **Importante**:
- T-14 Huerta
- T-7 RdM/Morenas individuales (solo existe ambas)
- T+1, T-1 pre-checkout, día salida con variantes por propiedad
- Casa Chamán (Q3 2026): 0 cobertura todo el lifecycle

---

## 3. Duplicaciones e inconsistencias detectadas

### 3.1 Duplicación 1: Transporte CDMX
**Mismo contenido en**:
- AirBnB `Directions` (asumido)
- Kit WhatsApp RdM sección 1
- Kit WhatsApp Morenas sección 1

**Impacto**: cambiar un teléfono = 3 lugares.

### 3.2 Duplicación 2: Masajista Michel + AcaScuba
**Mismo contenido en**:
- AirBnB template `PROG: 30` (T-14)
- AirBnB template `PROG: 40` (T-7)
- AirBnB template `PROG: 60` (T+1)
- AirBnB `Directions` (asumido)
- Kit WhatsApp RdM sección 4
- Kit WhatsApp Morenas sección 4

**Impacto**: si Michel cambia de número o se va, 6 lugares.

### 3.3 Duplicación 3: Restaurantes / supermercados
Aparecen en 3-4 lugares cada uno.

### 3.4 Inconsistencia: Servicio Morenas

| Source | Modelo |
|---|---|
| AirBnB template `3 - Morenas completa` ES | 🔴 NO menciona servicio (omisión) |
| AirBnB template `3a Morenas english` | "included" |
| AirBnB template `4 - Dos Villas` ES | "included" |
| AirBnB template `PROG: 1a Morena Servicio` | "OPCIONAL $1,000/noche" |
| Kit WhatsApp Morenas sección 2 | "OPCIONAL $1,000/noche ≤16, $1,500 >16" |

**¿Cuál es la verdad operacional?** Probablemente la última (opcional), pero los inquiry de venta sugieren incluido.

### 3.5 Inconsistencia: Precio paquete bodas

| Source | Precio |
|---|---|
| AirBnB `Paquete Bodas` ES | $1,000/pax |
| AirBnB `Wedding packages English` | $1,000/pax (~$50 USD) |
| Kit RdM sección 6 | $1,400/pax (avisar 1 mes) |
| Doc Paquete Eventos detallado | $1,400/pax |
| Kit Morenas | NO MENCIONADO |

**Disonancia**: AirBnB todavía vende a $1,000, los kits dicen $1,400. Riesgo legal/reputacional si guest reserva esperando $1,000.

### 3.6 Inconsistencia: Tienda local

| Template | Nombre | Distancia |
|---|---|---|
| Kit RdM | "El Güero" | 400m |
| Kit Morenas | "El Guero" (sin diéresis) | 400m |
| T-7 Huerta AirBnB | "La Azucena" | 100m |

¿Son la misma tienda? ¿Diferentes? Inconsistencia ortográfica.

### 3.7 Inconsistencia: Conteo de reseñas

| Template | Reseñas mencionadas |
|---|---|
| RdM ES | "150 reseñas" |
| RdM EN | "120 reviews" |
| Morenas ES | "150 reseñas" |
| Morenas EN | "190 reviews" |
| Huerta | "300 reseñas" (sospechoso) |
| Dos Villas | "190 reseñas" |
| Realidad (memoria 2026-05-12) | 4.83★ × 365+ reviews agregadas |

Todos los counts están desactualizados.

### 3.8 Problemas de seguridad

🔴 **Clave caja "6720"** hardcoded en templates T-1 de las 3 propiedades. Misma clave para todas. Archivada en mensajes AirBnB. Riesgo si el messaging es comprometido o si guest hostil comparte.

🔴 **Datos personales de terceros expuestos**: Celene (chef), Michel (masajista), AcaScuba (María José), Carlos Vinalay, Norma Rivera, Daribel, Markos, Memo, Sandra, etc. — todos con WhatsApp y teléfono en templates archivados por AirBnB. ¿Tienes consentimiento explícito de cada uno para tener sus datos en mensajes automatizados archivados?

### 3.9 Footers internos en mensajes públicos

Casi todos los inquiry templates terminan con:
```
--> rincondelasmorenas
--> rincondelmar
```

¿Estas notas internas SE MANDAN al guest tal cual? Si sí, se ven raros. Si no, ¿quién/qué las filtra?

### 3.10 Frase negativa

"La inseguridad de la bahía de Acapulco" aparece en templates `0 - RdM completa`, `1 - RdM hasta 16`, `3 - Morenas`, `3b Morenas más 16`, `3d Huerta`. Best practice: matizar a "alejado del bullicio de la bahía" sin la palabra "inseguridad".

---

## 4. Best practices industria (research 2026)

Búsquedas WC: vacation rental welcome guide, digital guidebook, AirBnB hosting fields.

### 4.1 Consenso 2026 industria

1. **Web-based digital guidebook > PDF**
   > "A web-based link — not a PDF attachment — is the most accessible format. It loads instantly on mobile, does not require downloading, and can be updated in real time without resending to past guests" — Jurny, 2026

2. **Single source of truth + linking**
   Cada pieza de info tiene UN owner canal. Todos los demás canales linkean. Cambias en uno → todos los demás ven la nueva versión.

3. **Mobile-first**
   Guests leen en cel. PDF rotos, fonts chicos, scroll horizontal = nadie lee. Web responsive es el estándar.

4. **Send 24-72 hours before check-in**
   > "Properties that implement comprehensive digital guidebooks report 40–70% reductions in repetitive pre-arrival and during-stay messages" — Jurny, 2026

5. **Analytics y feedback**
   Saber qué secciones leen, qué ignoran, optimizar.

6. **QR codes in-property**
   Guest scanea con cel, accede al guide siempre.

### 4.2 Alternativas

| Opción | Costo | Pros | Cons |
|---|---|---|---|
| **SaaS especializado** (Touch Stay, Hostfully, GoGuidebook, Folio) | $20-100/mes | Plug-and-play, multi-idioma built-in, analytics, AI chatbot | Vendor lock-in, branding limitado, datos en su DB |
| **Build propio** en Cloudflare apps/web | $0 marginal | Control total, integración nativa con bot+D1, branding completo, SEO bonus | Requiere desarrollo, ~2-3 semanas CC |
| **PDF only** | $0 | Simple | No actualizable, no analytics, no compartible, no SEO |
| **Combo** | $0-100/mes | Web + PDF auto-generado para offline | Complejidad mantenimiento |

**Mi voto**: Build propio. Alex YA tiene `apps/web` Astro+React+CF Pages en producción. Marginal cost es 0. Control y SEO son bonus.

---

## 5. Propuesta arquitectónica

### 5.1 Las 4 capas de contenido

```
CAPA 1 — Marketing/Discovery (atraer guests)
└─ Owner: AirBnB listing fields + rincondelmar.club homepage + redes sociales

CAPA 2 — Decision/Booking (info para decidir reservar)
└─ Owner: AirBnB listing + bot WhatsApp conversational

CAPA 3 — Operacional/Stay (info para la estancia)
└─ Owner: rincondelmar.club/welcome/{property} (Welcome Guide web)
   ↓ todos los canales linkean ↓
   AirBnB messages, WhatsApp bot, in-property QR

CAPA 4 — Retention/Loyalty (post-stay)
└─ Owner: AirBnB checkout template + sitio + email
```

### 5.2 Welcome Guide propuesto

URL: `rincondelmar.club/welcome/{property-slug}`

```
/welcome/rincon-del-mar/
├── #llegada           Cómo llegar (transporte, mapa, libramiento, emergencias)
├── #checkin           Horario, clave caja (auth), llaves
├── #servicios         Chef incluido (RdM)/opcional (Morenas), compras, deadlines
├── #casa              WiFi, manual electrodomésticos, normas
├── #actividades       Masajista, yates, tours (con teléfonos + WhatsApp)
├── #restaurantes      Locales + servicio a casa
├── #eventos           Cenas casuales, formales, paquete bodas $1,400
├── #emergencias       Médico, farmacia, contactos 24/7
└── #checkout          Horario, instrucciones salida, review CTAs

/welcome/las-morenas/
/welcome/huerta-cocotera/
/welcome/combinada/
/welcome/casa-chaman/    (futuro Q3 2026)
```

### 5.3 Matriz "Qué va dónde"

| Tipo de info | Source of truth | Mensaje AirBnB | WhatsApp bot | PDF |
|---|---|---|---|---|
| Hero pitch propiedad | AirBnB Description + sitio | — | — | — |
| Fotos galería | AirBnB Photos | — | bot linkea | — |
| Precios + cleaning | AirBnB Pricing | bot calcula | bot calcula | — |
| Política cancelación | AirBnB Policy | — | bot conoce | — |
| Servicio chef detalle | Guide `#servicios` | trigger T-14 + link | bot resume + link | sí, derivado |
| Costos servicios opcionales | Guide `#servicios` | trigger T-14 + link | bot resume | sí, derivado |
| Transporte CDMX | Guide `#llegada` | link en welcome | bot resume + link | sí, derivado |
| Supermercados | Guide `#llegada` | link en T-7 | bot resume + link | sí, derivado |
| Masajista + yates | Guide `#actividades` | teaser T+1 + link | bot recomienda + link | sí, derivado |
| Restaurantes | Guide `#restaurantes` | teaser T-7 + link | bot recomienda + link | sí, derivado |
| Eventos casuales | Guide `#eventos` | — | bot conoce + link | — |
| Paquete boda $1,400 | Guide `#eventos` + página /eventos | link a /eventos | bot conoce + link | sí, brochure |
| WiFi password | AirBnB Check-in field | — | bot da si in-stay | — |
| Clave caja | AirBnB Check-in field | — | bot da si T-1 | — |
| Hora check-in/out | AirBnB rules + guide | — | bot da | — |
| Emergencias | Guide `#emergencias` | mención T-14 + link | bot da | sí, card 1 pág |
| Review CTAs | template AirBnB `PROG: 80` | mantener template ⭐ | bot recuerda T+1 post | — |

### 5.4 Lo que SE MANTIENE en mensajes (no se va al guide)

- Saludo personal con nombre del guest
- Datos específicos de SU reserva (fechas, # personas, total)
- Triggers de acción específica (deadline menú, dirección hoy)
- CTAs que requieren respuesta inmediata
- Tone-of-voice cálido y personal
- Review CTAs día salida (template `PROG: 80` que está bien)

### 5.5 Lo que SE VA AL guide (no se duplica en mensajes)

- Transporte, supermercados, médicos, farmacias
- Lista completa actividades (masajista, yates, restaurantes, tours)
- Manual electrodomésticos
- Paquete eventos detallado
- WiFi credentials

### 5.6 Volumen estimado refactor

| Hoy | Futuro |
|---|---|
| 34 templates AirBnB largos (avg 1,023 chars) | ~16 templates centrales (4 props × 4 momentos) cortos (avg 400 chars) |
| 3 kits WhatsApp gigantes (5,400-5,800 chars) | Mensaje WhatsApp corto (~200 chars) + link al guide |
| Info duplicada en 4-5 lugares | Cada pieza en 1 lugar |

---

## 6. Análisis del stack propuesto

### 6.1 Stack actual conocido (memoria + thread/35)

```
apps/web (Astro 5.18.1 + React 19 islands)
  ↓
Cloudflare Pages (rincondelmar.club)
  ↓
Cloudflare D1 (rincon) — Phase B Guest 360 schema diseñado
Cloudflare R2 (rdm-knowledge, assetsrdm)
Cloudflare Workers (rincon-pago, rincon-bot, rincon-tours, beds24-calendar)
  ↓
Anthropic API (Files API) — KB en R2
ManyChat (WhatsApp/IG/FB)
Make.com (Greeter v5, Booker v3, sub-flows)
Beds24 (PMS, 2-way API activo)
AirBnB Host-Only Fee 17.98%, multiplier 1.25
```

Templates infrastructure ya construida (PR #5-#7 thread/35):
- `/admin/templates` editor LIVE
- R2 bucket con prefix `templates/`
- 26 placeholders canónicos
- Live preview + validation warnings

### 6.2 ¿Qué se agregaría para Welcome Guide?

**Opción A: Build propio en apps/web**

```
apps/web/src/pages/welcome/
├── [property].astro          (dinámico por propiedad slug)
├── _components/
│   ├── WelcomeHeader.tsx
│   ├── SectionLlegada.tsx
│   ├── SectionCheckin.tsx
│   ├── SectionServicios.tsx
│   ├── SectionCasa.tsx
│   ├── SectionActividades.tsx
│   ├── SectionRestaurantes.tsx
│   ├── SectionEventos.tsx
│   ├── SectionEmergencias.tsx
│   └── SectionCheckout.tsx
└── _content/                 (MDX o JSON por propiedad)
    ├── rincon-del-mar.json
    ├── las-morenas.json
    ├── huerta-cocotera.json
    ├── combinada.json
    └── casa-chaman.json

apps/web/src/pages/api/
└── welcome-pdf/[property].ts (PDF generator)
```

Storage opciones:
1. JSON estático en repo (más simple, deploy required para cambios)
2. D1 + admin UI (más flexible, requiere CRUD)
3. R2 + admin UI (similar a templates system existente)

Mi voto: **opción 3** — alinea con templates system ya existente, mismo patrón mental para Alex.

**Opción B: SaaS Touch Stay**

Pros: instant, mantenido por terceros, multi-idioma auto-translate, analytics built-in.
Cons: $20-100/mes, branding limitado, datos en SaaS (no en D1/R2), integración bot requiere effort.

**Opción C: Híbrido**

apps/web/welcome con datos hardcoded MDX. Sin admin UI fancy. Solo edita-y-deploy.
Pros: simple, $0, control total.
Cons: cada cambio requiere PR a Alex.

### 6.3 Bot integration

Phase B.4 (apps/admin/leads UI) ya en roadmap (thread/33).

Bot integration con Welcome Guide:
- Bot conoce las URLs `/welcome/{property}/#section`
- Cuando pregunta FAQ → responde corto + linkea sección específica
- Welcome auto-send (Phase B.1) incluye link al guide
- Pre-arrival auto-sends (T-14/T-7/T-1) incluyen link a secciones relevantes

Bot NO duplica contenido del guide en su KB. Solo conoce el INDEX (qué hay y dónde) + responde con extracts cortos + linkea.

### 6.4 i18n

Estructura propuesta:
```
_content/
├── rincon-del-mar.es.json
├── rincon-del-mar.en.json
├── las-morenas.es.json
├── las-morenas.en.json
└── ...
```

URLs: `/welcome/rincon-del-mar` (default ES) y `/welcome/rincon-del-mar?lang=en` (o `/en/welcome/...`).

Bot detecta idioma del guest (Beds24 booking data o ManyChat field) → linkea versión correcta.

---

## 7. Estado de los campos AirBnB (lo que NO sabemos)

Para diseñar bien el Welcome Guide y el refactor de templates, necesitamos saber qué hay HOY en cada campo de las 4 propiedades.

### 7.1 Campos a inventariar (CC tarea)

Para cada listing (RdM=18780853, Morenas=733868075691217916, DosVillas=18009632, Huerta=1577678927412395161):

| Campo URL | Editor URL pattern |
|---|---|
| Title | `/hosting/listings/editor/{listingId}/details/title` |
| Description | `/hosting/listings/editor/{listingId}/details/description` |
| The Space | `/hosting/listings/editor/{listingId}/details/the-space` |
| Guest Access | `/hosting/listings/editor/{listingId}/details/guest-access` |
| Other Things to Note | `/hosting/listings/editor/{listingId}/details/other` |
| House Rules | `/hosting/listings/editor/{listingId}/house-rules` |
| Amenities | `/hosting/listings/editor/{listingId}/amenities` |
| Directions | `/hosting/listings/editor/{listingId}/arrival/directions` |
| House Manual | `/hosting/listings/editor/{listingId}/arrival/house-manual` |
| Check-in Instructions | `/hosting/listings/editor/{listingId}/arrival/check-in-method` |

Confirmado por Alex: el "Kit WhatsApp" actual VIVE en el campo `Directions` de AirBnB. Por eso clientes AirBnB ya lo tienen, los de WhatsApp NO.

### 7.2 Hipótesis a verificar

Hipótesis 1: **Description** tiene el draft 3,890 chars propuesto en sesión 2026-05-12 (memoria). Verificar si aplicado.

Hipótesis 2: **House Manual** probablemente vacío o desactualizado. Es el campo correcto para WiFi, electrodomésticos, normas operativas.

Hipótesis 3: **Check-in Instructions** probablemente tiene dirección + clave caja (más seguro que en mensaje), pero Alex repite la info en template T-1. Verificar.

Hipótesis 4: **House Rules** probablemente tiene normas básicas (mascotas, ruido, fumar) pero falta granularidad sobre eventos, # personas extras, etc.

Hipótesis 5: **The Space** y **Guest Access** probablemente desactualizados, mencionan amenidades stale.

---

## 8. Plan de fases propuesto

### Fase 0 — Análisis y decisiones (esta semana)

- [x] WC: análisis de templates AirBnB + kits WhatsApp (este thread)
- [ ] **CC**: revisar este thread, opinar sobre stack, bajar campos AirBnB faltantes
- [ ] Alex: responder preguntas críticas (sección 10)
- [ ] Joint: decisión final approach (build propio vs SaaS)

### Fase 1 — Limpieza inconsistencias (1 semana, sin construir nada nuevo)

Solo actualizar templates AirBnB existentes:
- [ ] Quitar footer interno `--> rincondelasmorenas / --> rincondelmar`
- [ ] Suavizar "inseguridad de Acapulco" → "alejado del bullicio"
- [ ] Actualizar conteo reseñas a número actual (365+ agregado, o uno por listing)
- [ ] Fix template `3 - Morenas` agregando mención servicio
- [ ] Actualizar precio bodas en templates AirBnB `Paquete Bodas` $1,000 → $1,400 (o decidir mantener)
- [ ] Eliminar template `Instrucciones para la salida` (nativo sin customizar, casi inútil)

### Fase 2 — Welcome Guide (~2-3 semanas CC, si build propio)

- [ ] Diseño UX/UI Welcome Guide
- [ ] Páginas `/welcome/{property}` en apps/web
- [ ] 9 secciones × 4 propiedades + Chamán futuro
- [ ] i18n ES/EN
- [ ] PDF auto-generation
- [ ] QR codes generables
- [ ] Analytics básico (page views por sección)

### Fase 3 — Refactor templates AirBnB

- [ ] Reducir 34 → ~16 templates centrales
- [ ] Cada template termina con link al guide section
- [ ] Mover clave caja + WiFi a `Check-in Instructions` (campo dedicado)
- [ ] Crear variantes EN para todo el post-booking lifecycle
- [ ] Templates para Casa Chamán (Q3 2026)

### Fase 4 — In-property

- [ ] QR codes impresos físicos en cada propiedad
- [ ] WiFi cards físicos
- [ ] Emergency contact cards

### Fase 5 — Bot integration

- [ ] Bot conoce el Welcome Guide structure
- [ ] FAQs → bot responde corto + link
- [ ] Welcome auto-send vía Beds24 webhook (alinea con Phase B.1)

---

## 9. Tareas específicas para CC

### Tarea CC #1: Revisar este análisis

Lee `threads/36-wc-templates-content-architecture-analysis.md` (este doc) + los knowledge files:
- `knowledge/airbnb-templates-current-2026-05-13.md`
- `knowledge/airbnb-templates-current-2026-05-13.json`
- `knowledge/whatsapp-kits-current-2026-05-13.md`

Opina sobre:
- ¿Coincides con el análisis de duplicaciones?
- ¿La propuesta de 4 capas tiene sentido?
- ¿El Welcome Guide approach es la mejor solución o hay alternativas mejores?

### Tarea CC #2: Bajar contenido actual AirBnB

Para cada listing (18780853, 733868075691217916, 18009632, 1577678927412395161), bajar el contenido de TODOS los campos del editor:

- Title
- Description
- The Space
- Guest Access
- Other Things to Note
- House Rules
- Amenities (lista checkboxes activos)
- Directions
- House Manual
- Check-in Instructions

CC puede:
- Pedirle a Alex que haga Ctrl+S de cada página del editor y subirlo
- O CC mismo puede automatizar el scraping si tiene Chrome MCP/Playwright

Documentar en `knowledge/airbnb-listing-fields-current-2026-05-13.md`.

### Tarea CC #3: Inventario apps/web actual

Revisar el repo:
- ¿Qué páginas existen hoy en `apps/web/src/pages/`?
- ¿Hay `/guia-llegada`? ¿Qué contiene?
- ¿Hay `/rincon-del-mar`, `/las-morenas`, etc.?
- ¿Hay `/eventos`?
- ¿Estructura mobile-first?
- ¿i18n setup existe?

Documentar en `knowledge/apps-web-inventory-2026-05-13.md`.

### Tarea CC #4: Validar stack para Welcome Guide

Evaluar las 3 opciones (build propio, SaaS, híbrido) considerando:
- Costo (incluyendo costo CC time)
- Mantenimiento
- Integración con bot existente
- SEO
- i18n
- Analytics
- Migration path (qué pasa si después queremos cambiar)

Opinar cuál recomienda y por qué.

### Tarea CC #5: Identificar gotchas técnicos

Cosas que pueden salir mal o que estoy ignorando:
- ¿Cómo se sincroniza Welcome Guide con Beds24 booking data? (e.g., WiFi password único por estancia)
- ¿Qué auth para datos sensibles (clave caja, WiFi)? Magic link, booking code, etc.
- ¿Performance impact en apps/web actual?
- ¿Cómo afecta el plan Phase B Guest 360 (thread/33)?
- ¿AirBnB tiene restricciones sobre linkear a sitios externos en mensajes? (ahora que es Host-Only Fee, hay políticas anti-off-platform)

### Tarea CC #6: Output

Crear `threads/37-cc-content-architecture-review.md` con:
- Resumen de hallazgos CC
- Stack recomendado con justificación
- Lista de gotchas y riesgos
- Plan de fases ajustado (si difiere de WC)
- Tiempos estimados realistas por fase
- Preguntas que CC todavía necesita responder antes de poder ejecutar
- ETA si Alex aprueba: cuánto tiempo CC vs cuánto tiempo Alex needs

**ETA tarea CC: 2-3 horas trabajo CC, output thread 37 listo para Alex revisar.**

---

## 10. Preguntas críticas para Alex

Sin estas respuestas no podemos avanzar a Fase 1.

### Sobre operación

1. **Footer interno `--> rincondelasmorenas / --> rincondelmar`**: ¿se manda al guest o se borra antes?
2. **Clave caja "6720"**: ¿cambia por estancia? ¿es única por propiedad o universal?
3. **Datos terceros (Celene, Michel, etc.)**: ¿tienes consentimiento para tenerlos en mensajes archivados?
4. **Servicio Morenas**: ¿incluido o opcional? (Disonancia entre AirBnB EN y kits.)
5. **Precio paquete bodas**: ¿actual $1,400 o $1,000? ¿AirBnB Wedding templates necesitan update inmediato?
6. **Chef nombrada por propiedad**:
   - RdM: Celene ✅
   - Morenas: ¿quién? (kit dice "la encargada" sin nombre)
   - Huerta: ¿hay chef opcional? ¿quién?
   - Combinada: ¿el equipo combinado?
7. **Karina co-host**: ¿sigue activa? ¿qué rol?
8. **Reservación instantánea**: ¿sigues "te busco por teléfono"? ¿automatizable?

### Sobre estrategia

9. **Welcome Guide build propio vs SaaS**: ¿voto?
10. **Welcome Guide auth**: ¿público o behind booking code para info sensible?
11. **Versión inglés**: ¿prioridad ahora o después de tener ES estable?
12. **AirBnB campos**: ¿prefieres bajar tú el contenido (Ctrl+S de cada página del editor) o CC automatiza?
13. **Casa Chamán Q3 2026**: ¿plan ya tiene contenido para los campos AirBnB cuando lance?
14. **WhatsApp kit en Huerta/Combinada**: ¿no existen porque pocos clientes directos en esas propiedades, o porque falta crearlos?

### Sobre contenido

15. **Direcciones físicas T-1**: ¿confirmadas y vigentes? (C. Puerto Huatulco 10 RdM, C. Puerto Manzanillo 15 Morenas)
16. **Tienda local**: ¿"El Güero" vs "La Azucena" son la misma o diferentes?
17. **Distancia OXXO**: 100m (RdM/Morenas) vs 500m (Huerta) — ¿correcto?
18. **Conteo reseñas para templates**: ¿unificar a "más de 350 reseñas con 4.83★" o per-listing?

---

## 11. Referencias

- Thread/33: Guest 360 architecture (Phase B.1-B.8 plan)
- Thread/35: Templates system docs + content help request
- Memoria 2026-05-12: AirBnB cutover completado, multiplier 1.25, Beds24 IDs
- Best practices research:
  - <https://blog.jurny.com/digital-guidebook-for-vacation-rentals-everything-guests-actually-want-and-hosts-always-forget>
  - <https://touchstay.com/>
  - <https://www.hostfully.com/blog/what-is-a-digital-guidebook/>
  - <https://stayfi.com/vrm-insider/2025/07/28/digital-guidebook/>

---

**Estado**: análisis completo. Esperando review CC + responses Alex.

**Próximo paso**: CC ejecuta tareas #1-#6, output thread/37.

— Web Claude (WC), 2026-05-13
