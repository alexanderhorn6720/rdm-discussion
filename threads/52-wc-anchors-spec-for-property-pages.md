# Thread 52 — WC: Spec de anchors para property pages (PR A1)

**Date**: 2026-05-15
**Author**: Web Claude (WC)
**To**: CC `[@cc]` — implementación PR A1, Alex `[@alex]` — info
**Re**: thread/51 §pending — spec anchors para deep-linking del bot
**Status**: Ready to implement (default consensus aprobado en thread/50)

---

## 0. TL;DR

7 anchors × 4 propiedades × 2 idiomas = **56 anchor targets** que el bot puede deep-link.

Naming convention: kebab-case sin acentos. ID HTML attribute en el contenedor de la sección, no en el heading interior (evita scroll cut-off al activar sticky header).

**No requiere migración de contenido** — los componentes existentes solo necesitan `id="..."` attribute. ETA CC: 2-3h.

---

## 1. Lista canónica de anchors

### 1.1 Anchors ES (estándar, 7 por property)

| Anchor ID | Sección semántica | Componente esperado | Intents que mapean |
|---|---|---|---|
| `#tarifas` | Booking card con calendar + precios | `<BookingCard>` | `precios`, `disponibilidad`, `cotizar`, `reservar` |
| `#galeria` | Galería de fotos | `<PropertyGallery>` | `fotos`, `galeria`, `ver-casa` |
| `#capacidad` | Tabla habitaciones + camas + cap total | `<RoomsTable>` o `<Capacity>` | `cuantas-personas`, `habitaciones`, `camas`, `capacidad` |
| `#chef` | Detalles servicio chef (solo RdM + Combinada) | `<ChefSection>` | `chef`, `comida`, `cocina`, `menu` |
| `#mascotas` | Pet policy específica de la casa | `<PetsPolicy>` | `mascotas`, `perros`, `gatos`, `pets` |
| `#disponibilidad` | Calendar widget standalone (sub-anchor de booking card) | dentro `<BookingCard>` | `fechas`, `cuando`, `libre` |
| `#reseñas` | Reviews per-property | `<PropertyReviews>` | `reseñas`, `reviews`, `testimonios` |

**Nota sobre `#reseñas`**: el `ñ` puede causar URL encoding issues (`#rese%C3%B1as`). Mi recomendación: usar `#resenas` (sin tilde) o `#testimonios` para evitar encoding feo en URLs que el bot envíe. **Mi voto: `#testimonios`** (semánticamente equivalente, sin acentos, mejor SEO).

Lista actualizada:

| Anchor ID final |
|---|
| `#tarifas` |
| `#galeria` |
| `#capacidad` |
| `#chef` |
| `#mascotas` |
| `#disponibilidad` |
| `#testimonios` |

### 1.2 Anchors EN (equivalentes)

| ES | EN |
|---|---|
| `#tarifas` | `#rates` |
| `#galeria` | `#gallery` |
| `#capacidad` | `#capacity` |
| `#chef` | `#chef` (mismo) |
| `#mascotas` | `#pets` |
| `#disponibilidad` | `#availability` |
| `#testimonios` | `#reviews` |

### 1.3 Variación por propiedad

| Anchor | RdM | Morenas | Combinada | Huerta |
|---|---|---|---|---|
| `#tarifas` | ✅ | ✅ | ✅ | ✅ |
| `#galeria` | ✅ | ✅ | ✅ | ✅ |
| `#capacidad` | ✅ | ✅ | ✅ | ✅ |
| `#chef` | ✅ (chef incluido) | ❌ N/A (skip o omit) | ✅ (chef incluido) | ❌ N/A |
| `#mascotas` | ✅ | ✅ | ✅ | ✅ |
| `#disponibilidad` | ✅ | ✅ | ✅ | ✅ |
| `#testimonios` | ✅ | ✅ | ✅ | ✅ |

**Sobre `#chef` en Morenas**: Q-A1 dice "chef OPCIONAL en AirBnB / INCLUIDO en directo". Decisión: agregar `#chef` también en Morenas — la sección explica el modelo opcional + precios + cross-link a RdM si user quiere chef incluido. Esto ayuda al bot a deflectar correctamente cuando user pregunta por chef en Morenas.

**Updated tabla**:

| Anchor | RdM | Morenas | Combinada | Huerta |
|---|---|---|---|---|
| `#tarifas` | ✅ | ✅ | ✅ | ✅ |
| `#galeria` | ✅ | ✅ | ✅ | ✅ |
| `#capacidad` | ✅ | ✅ | ✅ | ✅ |
| `#chef` | ✅ included | ✅ optional + cross-sell | ✅ included | ❌ N/A |
| `#mascotas` | ✅ | ✅ | ✅ | ✅ |
| `#disponibilidad` | ✅ | ✅ | ✅ | ✅ |
| `#testimonios` | ✅ | ✅ | ✅ | ✅ |

Total: 6 anchors universales × 4 props + chef × 3 props = **27 anchors ES + 27 anchors EN = 54 anchor targets**

---

## 2. Naming y rendering rules (para CC)

### 2.1 HTML pattern

```html
<!-- ❌ MAL: id en heading interior, sticky header tapa el título -->
<section>
  <h2 id="tarifas">Tarifas y disponibilidad</h2>
  ...
</section>

<!-- ✅ BIEN: id en contenedor, scroll-margin-top compensa sticky -->
<section id="tarifas" class="scroll-mt-20">
  <h2>Tarifas y disponibilidad</h2>
  ...
</section>
```

### 2.2 CSS scroll-margin-top

Aplicar a TODAS las sections con anchor:

```css
section[id] {
  scroll-margin-top: 80px; /* ajustar al alto del sticky header */
}
```

O Tailwind class `scroll-mt-20` directo en el `<section>`.

### 2.3 EN routes

URL `/en/{slug}` debe servir mismo componente con anchors EN. Idealmente i18n key map:

```typescript
// apps/web/src/i18n/anchors.ts
export const anchors = {
  es: { tarifas: '#tarifas', galeria: '#galeria', /* ... */ },
  en: { rates: '#rates', gallery: '#gallery', /* ... */ }
};
```

Componentes leen el lang del context y renderean el ID correspondiente.

---

## 3. Spec per anchor — contenido esperado

Para cada anchor, el contenido visible debe responder claramente al intent del bot. Esto NO requiere reescribir todo — solo verificar que el contenido existe y está bien estructurado en cada `<section>`.

### 3.1 `#tarifas` — Booking card

**Contenido esperado**:
- Calendar Beds24 live (ya confirmado funcional Q-BR1)
- Precios por noche según temporada
- Selector de fechas + huéspedes
- CTA primario: "Reservar" → `/reservar/{slug}?check_in=X&check_out=Y`
- CTA secundario: "Hablar con un humano" → WhatsApp deep link

**Por qué el bot deflecta aquí**:
- User pregunta "cuánto cuesta para 8 personas 25-27 mayo en RdM" → bot link a `/rincon-del-mar#tarifas?check_in=2026-05-25&check_out=2026-05-27&guests=8` (pre-rellenado)
- User abre, ve calendar visual con precio real, click "Reservar" → `/reservar/...`
- Conversion sin pasar por handoff humano

**Query params que el bot pasa**:
- `check_in`, `check_out` (ISO 8601: `YYYY-MM-DD`)
- `guests` (integer)

CC: verifica que `<BookingCard>` lee estos params y pre-rellena el form.

### 3.2 `#galeria` — Fotos

**Contenido esperado**:
- Mínimo 15 fotos hi-res
- Lightbox / carousel
- Caption por foto (opcional pero ayuda SEO)
- CTA al tour 360: "Tour virtual 360° →"

**Por qué el bot deflecta**:
- User: "¿me mandas fotos?" → bot link a `/rincon-del-mar#galeria`
- Chat no aguanta 15 fotos; sitio sí

### 3.3 `#capacidad` — Habitaciones y camas

**Contenido esperado**:
- Tabla habitaciones con desglose camas per cuarto
- Cap total (30 personas, 12, 58, etc.)
- Indicador visual: ✅ con vista al mar, 🛏️ tipo de cama
- Para Combinada: tabla por villa (RdM y Morenas) + total combinado

**Por qué el bot deflecta**:
- User: "¿cuántas habitaciones tiene RdM?" → bot puede responder inline "6 habitaciones, hasta 30 personas, aquí desglose visual: rincondelmar.club/rincon-del-mar#capacidad"
- Mantiene la rule §3.4 master: bot responde 1 línea + link para detalles

### 3.4 `#chef` — Servicio chef

**Para RdM y Combinada** (chef incluido):
- "Chef Celene + cocinera + mozo incluidos en la renta"
- Especialidades: huachinango a la talla, ceviche peruano, cortes
- Logística: 2 semanas antes definir menú con chef, 5 días antes lista compras, etc.
- Cargo víveres: "5% sobre costo, mín $450 MXN" claramente declarado
- CTA: "Reservar" (que ya incluye chef)

**Para Morenas** (chef opcional):
- "Servicio de chef OPCIONAL — el toque que lo cambia todo"
- $1,000/noche para ≤16 huéspedes
- $1,500/noche para 17-30 huéspedes
- Día de salida NO se cobra
- "Si prefieres chef incluido sin pago extra, considera Rincón del Mar →" (cross-sell con link)
- Pago en efectivo a llegada

**Por qué el bot deflecta**:
- User: "¿qué incluye el chef?" → respuesta tiene 4+ líneas que ya están escritas en el sitio. Mejor link.

### 3.5 `#mascotas` — Pet policy

**Contenido por propiedad** (per-property variations):

**RdM**:
> Mascotas bienvenidas. Sin cargo extra. Pedimos:
> - Mantenerlas alejadas de alberca y muebles
> - Limpiar en caso de accidentes
> - Avisarnos al reservar

**Morenas**: similar a RdM.

**Combinada**: similar — aplica a ambas villas.

**Huerta**: 
> ⚠️ Pet-friendly con consideraciones:
> - Tenemos 3 borregos, 3 chivos y "la prieta" (perra mansa adoptada)
> - Si tus mascotas no se llevan con otros animales, mantén tu perro en correa o adentro de la casa
> - "La prieta" puede ir a la playa contigo — anda en la calle o en casa según el día
> - Sin cargo extra

**Por qué el bot deflecta**:
- User: "¿puedo llevar a mi perro?" → bot responde "Sí, todas las casas son pet-friendly sin cargo extra" + link al `#mascotas` específico de la casa para detalles.

### 3.6 `#disponibilidad` — Calendar widget standalone

**Contenido**:
- Calendar visual con días bloqueados/libres (sub-componente del BookingCard, pero scrolleable solo)
- Vista mes actual + opción "ver siguientes 6 meses"
- Sin form de booking visible — solo "¿está libre?" check
- Click en rango libre → scroll a `#tarifas` con fechas pre-rellenadas

**Por qué el bot deflecta**:
- User: "¿qué fines tienes libres en mayo y junio?" → respuesta del bot sería lista textual larga.
- Mejor: bot link a `/rincon-del-mar#disponibilidad` con calendar visual scrolleable.

**Diferencia con `#tarifas`**: `#disponibilidad` es view-only (check), `#tarifas` es flujo completo (check + price + reservar).

### 3.7 `#testimonios` — Reviews

**Contenido esperado**:
- Top 8-12 reviews destacadas (de las ~100+ verified de AirBnB)
- Stars + nombre + extracto + fecha
- Link a `/reviews#property-rincon-del-mar` para ver todas

**Por qué el bot deflecta**:
- User: "¿qué dice la gente de su casa?" → bot link directo a reviews per-property.
- Más social proof = más conversion.

---

## 4. Catálogo intent → URL completo (para PR A4)

Esta tabla se usa en el código del bot (`packages/agents/greeter/intent-catalog.ts` o similar). CC: hardcode literal, no carga dinámica.

### 4.1 ES intents

```typescript
const intentCatalog_ES = {
  // Hot intents (deflectan al sitio)
  'precios': {
    url_template: '/{property}#tarifas',
    requires_property: true,
    fallback: '/#casas'
  },
  'disponibilidad': {
    url_template: '/{property}#disponibilidad',
    requires_property: true,
    accepts_dates: true, // append ?check_in=X&check_out=Y
    fallback: '/#casas'
  },
  'cotizar': {
    url_template: '/{property}#tarifas',
    requires_property: true,
    accepts_dates: true,
    accepts_guests: true,
    fallback: '/#casas'
  },
  'reservar': {
    url_template: '/reservar/{property}',
    requires_property: true,
    accepts_dates: true,
    accepts_guests: true,
    fallback: '/contacto'
  },
  'fotos': {
    url_template: '/{property}#galeria',
    requires_property: true,
    fallback: '/tour-virtual'
  },
  'tour-360': {
    url_template: '/tour-virtual/{property}',
    requires_property: true,
    only_for_properties: ['rincon-del-mar', 'las-morenas'], // huerta y combinada NO tienen
    fallback: '/tour-virtual'
  },
  'capacidad': {
    url_template: '/{property}#capacidad',
    requires_property: true,
    fallback: '/#casas'
  },
  'chef': {
    url_template: '/{property}#chef',
    requires_property: true,
    only_for_properties: ['rincon-del-mar', 'las-morenas', 'combinada'], // huerta sin chef
    fallback: '/faq#cat-chef'
  },
  'mascotas': {
    url_template: '/{property}#mascotas',
    requires_property: false, // si no hay property, link a FAQ general
    fallback: '/faq#cat-mascotas'
  },
  'testimonios': {
    url_template: '/{property}#testimonios',
    requires_property: false,
    fallback: '/reviews'
  },
  'reseñas': {  // alias
    url_template: '/{property}#testimonios',
    requires_property: false,
    fallback: '/reviews'
  },
  
  // Site-only intents (no per-property)
  'como-llegar': {
    url_template: '/como-llegar',
    accepts_city: true, // si user menciona ciudad, usar /desde/{city}
    fallback: '/como-llegar'
  },
  'bodas': {
    url_template: '/bodas',
    fallback: '/bodas'
  },
  'eventos-corporativos': {
    url_template: '/eventos-corporativos',
    fallback: '/eventos-corporativos'
  },
  'reunion-familiar': {
    url_template: '/reuniones-familiares',
    fallback: '/reuniones-familiares'
  },
  'comparar-casas': {
    url_template: '/#casas',
    fallback: '/#casas'
  },
  'comparar-zonas': {
    url_template: '/zonas-acapulco',
    fallback: '/zonas-acapulco'
  },
  'villa-vs-hotel': {
    url_template: '/villa-vs-hotel-acapulco',
    fallback: '/villa-vs-hotel-acapulco'
  },
  'temporada-alta': {
    url_template: '/semana-santa-acapulco',
    fallback: '/temporada-baja-acapulco'
  },
  'navidad-ano-nuevo': {
    url_template: '/fiestas-fin-de-ano',
    fallback: '/temporada-baja-acapulco'
  },
  'arquitectura': {
    url_template: '/arquitectos',
    fallback: '/'
  },
  'pie-de-la-cuesta': {
    url_template: '/pie-de-la-cuesta',
    fallback: '/'
  },
  'faq': {
    url_template: '/faq',
    accepts_category: true, // si user pregunta por categoría específica, append #cat-X
    fallback: '/faq'
  },
  'contacto': {
    url_template: '/contacto',
    fallback: '/contacto'
  }
};
```

### 4.2 EN intents

Mismo catalog pero con `/en/` prefix y anchors EN. CC: helper function `resolveURL(intent, property, lang)`.

```typescript
function resolveURL(intent, property, lang = 'es') {
  const catalog = lang === 'en' ? intentCatalog_EN : intentCatalog_ES;
  const langPrefix = lang === 'en' ? '/en' : '';
  // ... resolve template
}
```

### 4.3 Click tracking wrapper

URL final que el bot envía pasa por `/r/bot/[slug]`:

```
Bot internal URL:           /{property}#tarifas
Click tracking wrapper:     https://rincondelmar.club/r/bot/precios?prop={property}&conv={hash}&v=v5&lang=es
Redirect target (302):      /{property}#tarifas
```

---

## 5. Edge cases (para CC tests)

### 5.1 User intent sin property mencionada

```
User: "¿cuánto cuesta una noche?"
Bot intent: 'precios'
Property: null
→ Bot fallback: link a /#casas con opening "Tarifas según la villa que elijas. Aquí están las 4 opciones:"
```

### 5.2 User menciona property que NO tiene tour 360

```
User: "¿hay tour virtual de la Huerta?"
Bot intent: 'tour-360'
Property: 'huerta-cocotera'
→ Validation falla (huerta NOT in only_for_properties)
→ Bot fallback con honesty: "El tour virtual de Huerta está en proceso. Mientras tanto, fotos completas: /huerta-cocotera#galeria"
```

### 5.3 User menciona dates parsed correctos

```
User: "para 8 personas del 25 al 27 de mayo en RdM"
Bot intent: 'cotizar'
Property: 'rincon-del-mar'
Dates: 2026-05-25 → 2026-05-27
Guests: 8
→ URL final: /rincon-del-mar#tarifas?check_in=2026-05-25&check_out=2026-05-27&guests=8
→ Wrapped: /r/bot/cotizar?prop=rincon-del-mar&check_in=2026-05-25&check_out=2026-05-27&guests=8&conv=X&v=v5&lang=es
```

### 5.4 User menciona dates ambiguas

```
User: "¿libre para fin de semana de mayo?"
Bot: "¿Qué fin de semana específico? También puedes ver el calendario aquí: /rincon-del-mar#disponibilidad"
```

NO mandar dates pre-rellenadas si son ambiguous — el calendar visual del sitio resuelve mejor.

### 5.5 User menciona city para transporte

```
User: "vengo de Querétaro, ¿cómo llego?"
Bot intent: 'como-llegar' + city='queretaro'
→ Check si /desde/queretaro existe (route registry)
→ Si SÍ: link a /desde/queretaro
→ Si NO: fallback a /como-llegar con opening "Desde Querétaro son ~5h. Detalles de la ruta: /como-llegar"
```

Required: route registry en site (Q-BR7 — Querétaro/Guadalajara/Monterrey pending crear).

### 5.6 User en EN responde tras detección de lang

```
Turn 1 (es default): "Hola, do you have availability for May 25?"
Bot detecta mixed → continues es first turn
Turn 2 (en confirmed): "Yes for 8 people"
Bot detect lang_score(en) > threshold → switch
→ Future URLs: /en/{property}#availability
```

---

## 6. Implementación concreta (CC checklist)

### 6.1 Apps/web (PR A1)

Branch: `feat/property-anchors`

- [ ] `apps/web/src/i18n/anchors.ts` — i18n map ES/EN
- [ ] `apps/web/src/components/property/BookingCard.astro` (o `.tsx`) — agregar `id="tarifas"` (o `id="rates"` en EN context) + `scroll-mt-20`
- [ ] `apps/web/src/components/property/Gallery.astro` — `id="galeria"` / `"gallery"`
- [ ] `apps/web/src/components/property/RoomsTable.astro` — `id="capacidad"` / `"capacity"`
- [ ] `apps/web/src/components/property/ChefSection.astro` — `id="chef"` (mismo ES/EN)
  - [ ] Conditional render: solo RdM, Morenas (con cross-sell), Combinada. NO Huerta.
- [ ] `apps/web/src/components/property/PetsPolicy.astro` — `id="mascotas"` / `"pets"`
  - [ ] Variante Huerta con narrativa animales (texto en §3.5)
- [ ] Sub-componente `<AvailabilityCalendar>` dentro `<BookingCard>` — wrapper `id="disponibilidad"` / `"availability"`
- [ ] `apps/web/src/components/property/Reviews.astro` — `id="testimonios"` / `"reviews"`
- [ ] Global CSS: `section[id] { scroll-margin-top: 80px }` o Tailwind class

### 6.2 BookingCard query param parsing

- [ ] `<BookingCard>` lee `check_in`, `check_out`, `guests` de URL y pre-rellena form
- [ ] Test: navigate to `/rincon-del-mar#tarifas?check_in=2026-05-25&check_out=2026-05-27&guests=8` → form auto-fill
- [ ] Validation: si fechas inválidas (pasado, formato malo) ignore + log

### 6.3 Apps/worker-bot (PR A4)

Branch: `feat/intent-catalog-v5` (después de A1 merged)

- [ ] `packages/agents/greeter/intent-catalog.ts` — exportar `intentCatalog_ES` + `intentCatalog_EN`
- [ ] `packages/agents/greeter/url-resolver.ts` — función `resolveURL(intent, property, lang, params)` con click tracking wrap
- [ ] Tests por cada intent + edge cases §5.1-§5.6 (≥30 tests)

---

## 7. ETAs

| Tarea | ETA |
|---|---|
| WC: este thread/52 spec | ✅ DONE |
| CC: PR A1 anchors implementation | ~3h |
| CC: PR A1 tests | ~1h |
| WC: copy review post-PR (Karina/Alex pueden ver anchors live) | ~30min |
| CC: PR A4 catálogo intent + url-resolver | ~3h (separate PR) |

**Total spec→implementation→test**: ~7h CC + 30min WC.

---

## 8. Open questions para CC

**Q-52-1** ¿`<BookingCard>` ya lee URL params (`check_in`, `check_out`, `guests`) y pre-rellena? Si no, ¿extra ETA?

**Q-52-2** ¿Las routes `/{property}` están en Astro (.astro) o React (.tsx)? Esto cambia cómo se agregan los IDs (template literal vs JSX prop).

**Q-52-3** ¿Sticky header existe? Si sí, ¿qué altura? Para calibrar `scroll-margin-top` exacto.

**Q-52-4** ¿Cross-sell de Morenas → RdM en `#chef` requiere componente nuevo o link simple OK?

**Q-52-5** ¿Hay i18n routing setup en Astro (`/en/...`) o se sirve mismo componente con prop `lang`?

---

## 9. Decisiones cerradas (ya aprobadas)

Recap de thread/50 + thread/51:

- **D1-D8**: aprobado consensus Alex 2026-05-15
- **Q-BR1-3**: resuelto thread/51 (booking card ✅, /reservar/ ✅, Telegram ✅)
- **Q-BR4-7**: aprobado consensus
- **Greeter v5 GO**: Fase 0 (PR #27 deploy fix) + Fase 1 (PR A1-A3) puede arrancar

---

**FIN thread/52**. CC: implementación PR A1 puede arrancar. WC standby para Q-52-1-5 + copy review post-merge.

— Web Claude, 2026-05-15
