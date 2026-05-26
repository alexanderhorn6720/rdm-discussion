---
id: 217
author: wc
topic: mega-spec-greeter-v7.1-kb-runtime-injection-plus-sitio-comparar-disponibilidad
status: draft
mode: DoIt
created_at: 2026-05-26
estimated_cc_hours: 12-18
prs_planned: 3
references:
  - threads/211-wc-greeter-v7-megarun-spec.md
  - threads/213b-wc-greeter-eval-framework-shadow-testing.md
  - threads/215-wc-session-log-2026-05-26.md
  - threads/216-CC-Bot-doit-213b-eval-framework-report.md
---

# thread/217 — Mega-spec: Greeter v7.1 KB runtime injection + sitio /comparar-casas + /disponibilidad

## §0 · TL;DR

3 bugs críticos detectados con eval framework (baseline 91.7%, lead_precios 47%) más 2 páginas nuevas del sitio que sustituyen el fallback genérico `/#casas`.

**Causa raíz del bug principal:** handler v7 no inyecta la KB (R2 → KV pipeline funciona, 8 keys cacheadas, pero `runGreeterV7` nunca llama `getAllWelcomeKBsFromKV`). En su lugar el prompt v7 §9 + Tier 2 tienen 4 villas inventadas hardcoded (Casa Olas, Casa Playa del Pacífico, Casa de la Bahía, La Huerta Cocotera). LLM obedece el prompt, mintiendo nombres en producción.

**Fix arquitectural:** quitar villas hardcoded del prompt, inyectar KB real desde KV en runtime. Además sitio gana 2 páginas (`/comparar-casas` y `/disponibilidad`) que el catalog puede apuntar en vez de caer a `/#casas` cuando no hay property declarada.

3 PRs async secuenciales. CC mega-run autónomo. Alex pausa solo entre PR1 (producción crítica) y PR2.

---

## §1 · CONTEXTO + DIAGNÓSTICO

### 1.1 · Estado al arranque de sesión 2026-05-26

- Greeter v7 LIVE 100% canary (PR #186 deployed 0bcb963d)
- Eradication 3 hallucinations shipped (PR #187)
- WA link hotfix shipped (PR #188)
- Eval framework shipped (PR #189, migration 0049 applied, 30 cases seeded)
- KB pipeline R2 → KV LIVE: 8 keys cacheadas correctamente

### 1.2 · Eval baseline corrido durante esta sesión

Run `er_01KSK33ZDW1002T3BHTQQXQR72` (manual-cc, 30 cases, 20s).

| Categoría | Score | Pass/Total |
|---|---|---|
| anti_regression | 100% | 2/2 |
| lead_disponibilidad | 75% | 3/4 |
| lead_grupos | 100% | 3/3 |
| lead_mascotas | 100% | 3/3 |
| **lead_precios** | **47%** | **1/5** |
| lead_reserva | 75% | 3/4 |
| lead_ubicacion | 67% | 2/3 |
| vip_in_stay | 100% | 4/4 |
| vip_repeat | 50% | 1/2 |
| **Global** | **91.7%** | **22/30** |

Score 91.7% pasa umbral 85% (no dispara Telegram alert) pero **oculta el problema de lead_precios al 47%**.

### 1.3 · Hallazgos críticos del baseline (WC manual review del details JSON)

#### Bug B1 — Villas inventadas en producción

Los 3 casos de `lead_grupos` (ec020, ec021, ec022) marcaron `passed: true` pero **el opening_line incluye nombres de villas inventadas**:

| Case | Opening line literal |
|---|---|
| ec020 (boda 50pax) | "Casa Playa del Pacífico es perfecta — es nuestra villa más grande..." |
| ec021 (corporativo) | "Casa Playa del Pacífico, que cabe hasta 30 personas..." |
| ec022 (reunión 20pax) | "Casa Playa del Pacífico (hasta 30)" + "Huerta Cocotera (hasta 20)" |

Eval scoring **ciego a nombres de villa** (solo valida trapwords Iris/noche/NUNCA). Por eso 91.7% global oculta esto.

**Realidad del catalog `VALID_PROPERTY_SLUGS`:**
```
rincon-del-mar, las-morenas, huerta-cocotera, combinada
```

Capacidad Huerta real: 12 pax (no 20).
"Casa Playa del Pacífico" no existe.

#### Bug B2 — Source del bug B1 = prompt hardcoded

`packages/agents/greeter/system-prompt-v7.ts`:
- **§9 (Tier 1, cached):** lista las 4 villas con nombres inventados
- **Tier 2 bucket context (cached):** repite los mismos nombres inventados con capacidades inventadas
- **§8 Ejemplo 6 (few-shot):** enseña "Casa Olas (16), La Huerta Cocotera (20), Casa Playa del Pacifico (30)"

Few-shot examples son el patrón más fuerte que sigue el LLM. Explica la reproducción exacta en ec020-022.

#### Bug B3 — Handler v7 NO consume la KB

`packages/agents/greeter/handler-v7.ts` + `apps/worker-bot/src/run-greeter-v5.ts::runGreeterV7`:
- Construyen `promptCtx` sin tocar `KV_KNOWLEDGE`
- La función `getAllWelcomeKBsFromKV` existe en `apps/worker-bot/src/welcome-kb.ts` pero **nadie la llama desde el path del Greeter**
- KB queda como dato muerto en KV: cacheado correctamente cada 2h, nunca consumido por el bot

#### Bug B4 — Escalation overshoot (lead_precios 47%)

5 de 8 fails son `wrong_intent: expected=route, actual=clarification`. Patrón: lead da info parcial → bot pide clarification en lugar de routear con URL útil.

Ejemplos:
- ec001 "precio fin de semana" → bot pidió "¿cuántas personas y qué fin de semana?"
- ec004 "precio familia con niños" → bot pidió "¿qué fechas?"
- ec005 "cotizar puente" → bot pidió "¿cuántas personas y noches?"

ec002 (mismo tipo: "price weekend EN") **pasó** con `route`. Demuestra inconsistencia del prompt, no falta de capacidad.

#### Bug B5 — VIP escalation overshoot

Caso ec024: lead pregunta "¿pueden traer toallas extra?" → bot respondió "Le aviso a Karina ahora mismo — te marca al +52 744 144 1575 en minutos. ¿Estás bien mientras? 🆘"

Tono SOS para query trivial. Eval marcó `passed: true` (expected_intent=null), pero comportamiento exagerado.

#### Bug C — Catalog estructural "casi todo a casas"

`intent-catalog.ts` mapea fallbacks cuando no hay property declarada:

| Slug | URL sin property | Implicación |
|---|---|---|
| `precios` | `/#casas` | Lista plana |
| `disponibilidad` | `/#casas` | Lista plana |
| `cotizar` | `/#casas` | Lista plana |
| `propiedad` | `/#casas` | Lista plana |
| `capacidad` | `/#casas` | Lista plana |
| `comparar-casas` | `/#casas` | NO es comparación, es la misma lista |

Observación de Alex durante la sesión: *"de nuevo casi todos a casas, no funciona así"*. Es structural del catalog + falta de página `/comparar-casas` real y `/disponibilidad` unificada.

### 1.4 · Mockups aprobados

- `/disponibilidad` = Mockup A (calendario mensual Airbnb-style) arriba + Mockup B (tabla con filtros) abajo
- `/comparar-casas` = Tabla 20 criterios × 4 villas (orden RdM, Las Morenas, Combinada, Huerta), sticky header, toggle "solo diferencias", botón "Ver disponibilidad de las 4"

### 1.5 · Decisiones acordadas durante la sesión

| Decisión | Valor |
|---|---|
| Tabla `/comparar-casas` | Hardcoded en página (Camino C). Migración a KB schema estructurado queda en backlog. |
| `/disponibilidad` data | Cache D1 (no Beds24 directo) |
| `/disponibilidad` selección | Airbnb-style (click start + click end) |
| KB inconsistencias | KB es source of truth, ignorar contradicciones del sitio público |
| 3 PRs async secuenciales | PR1 bot, PR2 comparar-casas, PR3 disponibilidad |
| Pausa CC | Entre PR1 y PR2 (Alex verifica prod). PR2 + PR3 async. |
| Heurística party-size | Suave: preferir route, clarification permitido si falta data crítica |
| Umbral done F1 | Eval ≥95% global + lead_precios ≥85% |
| Deploy | PR1 manual (Alex). PR2+PR3 CC autónomo. |
| Out-of-scope durante run | Abre issue, sigue. Excepción: si compromete safety, halt + report. |

---

## §2 · ALCANCE EXPLÍCITO

### 2.1 · YES — bugs en scope

- **B1+B2+B3** (single fix): borrar villas hardcoded del prompt + inyectar KB desde KV en runtime
- **B4** (escalation overshoot): regla anti-overshoot en §6 del prompt
- **B5** (VIP toallas SOS): antiejemplo en bucket VIP_in_stay coaching
- **Eval framework gap**: agregar `expected_villa_names_excludes` al schema + CC-triggerable run endpoint
- **C** (catalog estructural): página `/comparar-casas` real + página `/disponibilidad` real + update intent-catalog

### 2.2 · NO — explícitamente fuera de scope

- **Camino A** (KB schema con `comparison_data` estructurado). Diferido: tabla fija ahora, migrar cuando crezca negocio.
- **`/comparar-casas` bilingüe EN**. ES primero, EN follow-up.
- **`/comparar-casas` mobile cards layout**. Desktop-first.
- **Inconsistencia chef incluido/opcional en página `/las-morenas/`**. Bug de apps/web rendering, no del bot.
- **P2 contexto heredado entre conversaciones** ("Hola" → "¿sigues buscando para 29 personas en septiembre?"). Brain mode separado.
- **Karina training en `/comparar-casas`**. Future iteration con bot integration profunda.
- **Refactor karina-config.ts force-import-everywhere**. Memoria #27 patrón.
- **Recalibrar test cases ec013, ec015, ec028** (slug mismatches defendibles, test calibration issues). Out of scope, abrir issue.

---

## §3 · CLOSED DECISIONS

### 3.1 · KB runtime injection — diseño

Handler v7 carga KB desde KV antes de construir prompt blocks:

```typescript
// apps/worker-bot/src/run-greeter-v5.ts::runGreeterV7
// NEW: load KB from KV (cached, max 4 reads ES or EN)
const kbBlocks = await getAllWelcomeKBsFromKV(env.KV_KNOWLEDGE, input.lang);

const promptCtx = {
  // ... existing fields unchanged ...
  welcome_kb_blocks: kbBlocks,  // NEW
};
```

`ProcessToolUseDeps` necesita acceso a `env.KV_KNOWLEDGE`. CC decide el approach:

- **Camino preferido**: extender `GreeterV5DepsEnv` interface en `greeter-v5-deps.ts` para incluir `KV_KNOWLEDGE: KVNamespace`
- **Camino alternativo**: pasar `kbBlocks` como argument separado del input `RunGreeterV5Input`

CC elige basado en cleanliness, mantiene retrocompatibilidad con v5/v6 paths.

### 3.2 · Prompt v7.1 — qué se borra, qué se agrega

**Borrar:**
- §9 entero "PROPIEDADES ACTIVAS (4 villas, sin Casa Chamán)"
- Sección "### Propiedades activas — 4 villas" dentro de `buildBucketContextBlock` (Tier 2)
- Ejemplo 6 actual de §8 (que menciona Casa Olas + Casa Playa del Pacifico + La Huerta Cocotera con capacidades 16/20/30)
- Cualquier mención de "Casa Olas", "Casa Playa del Pacífico", "Casa de la Bahía" en cualquier parte del archivo

**Agregar:**

1. Nuevo sub-bloque dentro de Tier 2 que renderiza dinámicamente:

```
## KNOWLEDGE BASE — propiedades (single source of truth)

A continuación va el contenido aprobado por Karina y Alex para cada villa.
Es la ÚNICA fuente de verdad sobre nombres, capacidades, servicios, precios
y características. NO inventes datos. Si una pregunta no tiene respuesta en
este bloque, usa request_clarification o el catálogo de intents.

Slugs canónicos (USAR EXACTAMENTE así):
- rincon-del-mar
- las-morenas
- huerta-cocotera
- combinada

{welcome_kb_blocks_inyectados_desde_KV}
```

2. Ejemplo 6 reescrito en §8 — CC elige party_size de ejemplo entre 8 / 15 / 25 / 50. Debe usar UNA villa real del catalog + URL via intent_slug correcto + property correcto. Tono nivel 2 anfitrionero-funcional, sin inventar.

3. Nueva regla §6.X anti-overshoot (suave):

```
## §6.X — Cuándo preferir route sobre request_clarification

Si el lead declaró AL MENOS UNO de estos datos, preferí route con URL útil
antes que pedir más clarification:
- Party size (incluso aproximado: "como 20", "más o menos 30")
- Tipo de plan (boda, corporativo, familiar, cumple, vacación)
- Fechas aproximadas (julio, primera semana agosto, puente)

Una clarification SOLO si falta información crítica para elegir villa
(ej: "busco villa para vacaciones" sin party_size ni plan). Después
de UNA clarification, route incluso si falta algún dato menor.

El sitio captura especificidad faltante (fechas exactas, huéspedes finales,
extras) — no necesitás extraerla en chat.
```

4. Nuevo antiejemplo en bucket VIP_in_stay coaching (Tier 2):

```
### VIP_in_stay — qué NO es "problema operacional"

Amenities triviales se responden inline, NO se escalan:
- "¿Pueden traer toallas extra?" → respuesta inline cálida
- "¿Tienen almohadas extra?" → inline
- "¿Cómo enciendo el A/C?" → inline (info del manual)
- "¿Hora del check-out?" → inline

Problemas operacionales que SÍ escalan (urgency='high'):
- Falla servicio: no luz, no agua, no internet, no agua caliente
- Falla seguridad: alarma, intruso, robo, lesión
- Falla acceso: no puedo entrar, llaves perdidas, código no funciona
```

### 3.3 · Eval framework — CC-triggerable + villa names check

CC necesita poder correr eval sin pasar por endpoint HTTP auth (evita rotar secret). Opciones:

**Opción A** (preferida): script CLI en `apps/worker-bot/scripts/run-eval-local.ts` que:
- Importa `runEval` directo
- Usa `wrangler dev --remote` para bindings prod
- Outputs JSON del run + summary table a stdout
- CC ejecuta: `cd apps/worker-bot && npx tsx scripts/run-eval-local.ts`

**Opción B**: nuevo endpoint `/internal/eval/run-no-auth` activo solo cuando `ENV !== 'production'`. Más complejo, evitar.

CC elige A salvo bloqueo técnico.

**Schema extension:**

Agregar columna `expected_villa_names_excludes` (TEXT, JSON array) en `greeter_eval_cases`:
- Default value `'["Casa Olas","Casa Playa del Pacífico","Casa Playa del Pacifico","Casa de la Bahía","La Huerta Cocotera"]'` para todos los 30 casos existentes
- Scoring en `eval-engine.ts::scoreEval`: si `actual_opening_line` contiene alguno → violation `wrong_villa_name:found=X`
- Nueva migration `0050_eval_villa_names.sql`

### 3.4 · Páginas nuevas en apps/web

**`/comparar-casas`** (Astro page, hardcoded):
- 20 criterios × 4 villas (datos del KB extracted por CC)
- Orden columnas: Rincón del Mar, Las Morenas, Combinada, Huerta Cocotera
- Sticky header (CSS `position: sticky; top: 0`)
- Toggle JS "solo diferencias" (oculta rows donde 4 valores iguales)
- 4 botones "Ver [villa] →" linkean a `/{property}/`
- Botón "Ver disponibilidad de las 4" → `/disponibilidad`
- CTA WhatsApp como fallback inferior

**`/disponibilidad`** (Astro page con React island):
- Calendario mensual estilo Airbnb arriba (Mockup A)
- Tabla lista con filtros abajo (Mockup B)
- Data viene de cache D1 (`bot_short_links` no aplica; necesita schema nuevo o reuso de query Beds24 cached)
- Selección Airbnb-style: click día start, click día end, rango highlight
- Dropdown villa: Rincón del Mar (78695) / Las Morenas (74322) / Combinada (74316) / Huerta Cocotera (637063)
- Card cotización inline cuando hay rango seleccionado
- Idioma toggle ES/EN
- Botones "Ver detalle" y "Reservar →" en card cotización

### 3.5 · Intent catalog updates

`packages/agents/greeter/intent-catalog.ts`:

```typescript
// Cambio 1: comparar-casas URL
'comparar-casas': {
  url_template: '/comparar-casas',       // antes: '/#casas'
  fallback: '/comparar-casas',           // antes: '/#casas'
  // resto igual
},

// Cambio 2: disponibilidad fallback (NO la URL principal con property)
disponibilidad: {
  url_template: '/{property}#disponibilidad',  // unchanged
  fallback: '/disponibilidad',                  // antes: '/#casas'
  // resto igual
},

// Cambio 3 (opcional, CC decide): precios fallback
precios: {
  fallback: '/disponibilidad',  // antes: '/#casas' — alineado con disponibilidad
  // resto igual
},

// Cambio 4 (opcional, CC decide): cotizar fallback
cotizar: {
  fallback: '/disponibilidad',  // antes: '/#casas'
  // resto igual
},
```

EN catalog idem. CI snapshot test `intent-catalog-sync.test.ts` se actualiza con los nuevos URLs.

### 3.6 · Links cross-site

Cuando `/comparar-casas` y `/disponibilidad` existan, agregar links en:
- Footer global (apps/web layout)
- Header global (nav)
- Página de cada villa: link "Comparar con otras villas" + "Ver disponibilidad"
- Página `/` home: hero CTA o section con link a ambas

CC identifica los archivos exactos durante el run.

---

## §4 · IMPLEMENTATION — 3 PRs

### 4.1 · PR1 — Bot fix (Fase 1)

**Branch:** `feat/greeter-v7.1-kb-runtime-injection`
**Estimado CC:** 4-6h

#### Archivos a modificar

| Archivo | Cambio |
|---|---|
| `packages/agents/greeter/system-prompt-v7.ts` | Borrar §9 + Tier 2 villas hardcoded + Ejemplo 6 antiguo. Agregar bloque KB injection placeholder. Agregar §6.X anti-overshoot. Agregar antiejemplo VIP toallas. Agregar nuevo Ejemplo 6 con villa real. |
| `apps/worker-bot/src/run-greeter-v5.ts` | En `runGreeterV7`: cargar KB con `getAllWelcomeKBsFromKV(env.KV_KNOWLEDGE, input.lang)`. Pasar al promptCtx. |
| `apps/worker-bot/src/greeter-v5-deps.ts` | Extender `GreeterV5DepsEnv` con `KV_KNOWLEDGE: KVNamespace` si CC elige Camino preferido. |
| `apps/worker-bot/migrations/0050_eval_villa_names.sql` | NEW. Agrega columna `expected_villa_names_excludes` + UPDATE 30 cases con trapwords. |
| `apps/worker-bot/src/eval-engine.ts` | `scoreEval`: agregar check `villa_names_ok` que valida `actual_opening_line` contra `expected_villa_names_excludes`. |
| `apps/worker-bot/scripts/run-eval-local.ts` | NEW. CLI script para CC-triggerable eval run. |
| `packages/agents/greeter/system-prompt-v7.ts` tests | Update tests si rompen al borrar §9. |
| `apps/worker-bot/tests/eval-engine.test.ts` | Agregar test villa_names check. |

#### Pasos CC

1. Pre-flight: verify on main, clean tree, pull latest
2. Crear branch `feat/greeter-v7.1-kb-runtime-injection`
3. Implementar cambios en orden:
   a. Migration 0050 + apply local first
   b. Extender deps interface
   c. Modificar runGreeterV7 para cargar KB
   d. Editar system-prompt-v7.ts (borrar + agregar)
   e. Eval engine villa_names check
   f. Script run-eval-local.ts
4. Run tests locales: `pnpm test --filter @rdm/worker-bot`
5. Self-review diff completo
6. Push branch + crear PR via GitHub MCP
7. **HALT y reportar** a Alex con:
   - Diff summary
   - Tests passing count
   - Comando exacto para Alex: `wrangler d1 migrations apply rincon --remote && wrangler deploy`
   - Esperar GO de Alex antes de continuar a PR2

#### Post-merge + post-deploy verification

Alex despliega manualmente. CC corre:

```bash
cd apps/worker-bot
npx tsx scripts/run-eval-local.ts
```

CC valida:
- Score global ≥95%
- lead_precios ≥85%
- Ningún case viola villa_names_excludes
- lead_grupos sigue 100% (regresión check)

Si fallan umbrales: HALT, reportar a Alex, NO continuar.

#### Definition of done PR1

- [ ] Migration 0050 aplicada remote
- [ ] worker-bot deployado con código nuevo
- [ ] Eval re-corrido post-deploy
- [ ] Score ≥95% global, lead_precios ≥85%, 0 villa_name violations
- [ ] Alex confirma GO para PR2

---

### 4.2 · PR2 — Página /comparar-casas (Fase 2 parte 1)

**Branch:** `feat/comparar-casas-page`
**Estimado CC:** 4-6h
**Pre-req:** PR1 mergeado + deployado + verificado por Alex

#### Archivos a crear/modificar

| Archivo | Cambio |
|---|---|
| `apps/web/src/pages/comparar-casas.astro` | NEW. Página completa con tabla. |
| `apps/web/src/components/ComparisonTable.tsx` | NEW. React island con toggle "solo diferencias" + sticky header. |
| `apps/web/src/components/ComparisonTable.css` | NEW. Styles. |
| `packages/agents/greeter/intent-catalog.ts` | Update `comparar-casas` URL + fallback a `/comparar-casas`. |
| `apps/worker-bot/tests/intent-catalog-sync.test.ts` | Update snapshot. |
| `apps/web/src/layouts/BaseLayout.astro` o footer/nav components | Agregar links a `/comparar-casas` en footer global. |
| Páginas individuales de cada villa (`/{property}.astro`) | Agregar link contextual "Comparar con otras villas". |

#### Data hardcoded — los 20 criterios × 4 villas

CC extrae de los JSONs en R2 (`airbnb-content/{slug}.es.json`) y construye objeto:

```typescript
const villas = {
  'rincon-del-mar': {
    display: 'Rincón del Mar',
    rating_stars: 4.84,
    rating_count: 168,
    capacity: 30,
    bedrooms: 6,
    beds: 18,
    baths: 6.5,
    beach_distance: 'Pie de playa',
    pool: 'Infinita · palapa-bar',
    bbq: 'Sí',
    beach_palapa: 'Sí',
    beach_access: 'Directo',
    ocean_view_master: 'Sí',
    chef: 'Incluido',
    cocinera: 'Incluida',
    mozo: 'Incluido',
    daily_cleaning: 'Incluida',
    wifi_ac: 'Sí',
    pets: 'Sí · $300/estancia, máx 2',
    min_stay: '2 noches · 3 weekends',
    event_capacity: 'hasta 80',
    best_for: ['Bodas íntimas', 'Familias 3 gen'],
  },
  // 'las-morenas', 'combinada', 'huerta-cocotera' idem...
};
```

CC verifica cada valor contra JSON correspondiente antes de hardcodear. Si dato no aparece en KB, marca `'—'` o `'Próximamente'`. **No invents values.**

#### Features de la página

- Sticky header con 4 nombres de villa al scroll
- 4 secciones agrupadas: Capacidad / Espacios / Servicios / Reglas y mejor uso
- Toggle JS "Solo mostrar diferencias" (oculta rows donde 4 valores iguales)
- 4 botones "Ver [villa] →" footer linkean a `/{property}/`
- Botón "Ver disponibilidad de las 4" → `/disponibilidad`
- CTA WhatsApp inferior

#### Pasos CC

1. Pre-flight: branch from main, clean
2. Crear `feat/comparar-casas-page`
3. Implementar:
   a. Read los 4 JSONs de R2 (via `wrangler r2 object get --remote`)
   b. Construir data structure villas con 20 criterios extraídos
   c. Astro page + React island ComparisonTable
   d. CSS con sticky header + responsive básico
   e. Update intent-catalog.ts + snapshot test
   f. Agregar links en BaseLayout + páginas villa
4. Run tests locales
5. Self-review diff
6. Push + create PR
7. **CC continua a PR3 async** (no espera Alex)

#### Deploy + verification

CC despliega `apps/web` (CF Pages auto-deploys on push to main? verificar). Smoke check:

```bash
curl -I https://rincondelmar.club/comparar-casas
# Expect: 200
```

CC verifica que `/comparar-casas` carga en navegador, tabla renderiza, toggle funciona, links a villas individuales OK.

#### Definition of done PR2

- [ ] Page `/comparar-casas` LIVE
- [ ] 20 criterios × 4 villas con datos del KB
- [ ] Sticky header funciona
- [ ] Toggle "solo diferencias" funciona
- [ ] Links cross-site agregados
- [ ] Intent catalog actualizado
- [ ] Tests passing

---

### 4.3 · PR3 — Página /disponibilidad (Fase 2 parte 2)

**Branch:** `feat/disponibilidad-page`
**Estimado CC:** 6-8h
**Pre-req:** PR2 mergeado (orden lógico, no técnico — pueden ir paralelos si CC quiere)

#### Archivos a crear/modificar

| Archivo | Cambio |
|---|---|
| `apps/web/src/pages/disponibilidad.astro` | NEW. Página con calendario + tabla. |
| `apps/web/src/components/AvailabilityCalendar.tsx` | NEW. Mockup A — React island calendario mensual. |
| `apps/web/src/components/AvailabilityTable.tsx` | NEW. Mockup B — React island tabla con filtros. |
| `apps/web/src/components/AvailabilityCalendar.css` | NEW. |
| `apps/web/src/components/AvailabilityTable.css` | NEW. |
| `apps/web/src/pages/api/availability.ts` | NEW (o reuso existente). Endpoint API que lee cache D1. |
| `packages/agents/greeter/intent-catalog.ts` | Update `disponibilidad` fallback + opcional `precios` y `cotizar` fallback. |
| Tests + snapshot updates | |

#### Data source

CC investiga durante run:
- ¿Existe ya un cache D1 de Beds24 con tarifas + disponibilidad por día? Buscar tablas `beds24_*` en D1. Cron `refreshCalendar` ya popula `KV_KNOWLEDGE.calendar:lookup` y `calendar:text` — verificar si sirve.
- Si sí, query directa
- Si no, decidir: usar Beds24 token directo (no recomendado: rate limits) o crear caché D1 con cron refresh

Si requiere infra nueva (caché D1), CC abre issue separado y deja `/disponibilidad` con data mock + nota "TODO: integrar cache D1 cuando exista".

#### Features

**Mockup A (calendario):**
- 2 meses lado a lado
- Navegación prev/next mes
- Días disponibles clickeables, no disponibles tachados
- Selección rango Airbnb-style (click start → click end, hover highlight)
- Card cotización inline con total + por noche + botón Reservar
- Dropdown villa cambia data del calendario
- Dropdown huéspedes ajusta validación capacidad

**Mockup B (tabla):**
- Filtros: villa, huéspedes range, mes, noches
- Lista de rangos disponibles por villa
- Sort by: fecha / precio asc / precio desc / capacidad
- Click "Elegir" en row → llena el calendario arriba con ese rango

**Compartido:**
- Idioma toggle ES/EN
- Header con título + descripción

#### Definition of done PR3

- [ ] Page `/disponibilidad` LIVE
- [ ] Calendario funciona (al menos con mock data si cache no existe)
- [ ] Tabla funciona con filtros
- [ ] Selección rango Airbnb-style
- [ ] Intent catalog actualizado
- [ ] Links cross-site agregados
- [ ] Tests passing
- [ ] Eval framework re-corrido — sin regresiones vs PR1 baseline

---

## §5 · TESTS

### 5.1 · PR1 tests

- `apps/worker-bot/tests/eval-engine.test.ts` — nuevo test `villa_names_excludes_check`
- Snapshot test `intent-catalog-sync.test.ts` actualizado si tocaste catalog
- `runGreeterV7` integration test: mock KV con sample KB, verify pasa al prompt
- System prompt v7 test: verify §9 borrado, KB placeholder presente

### 5.2 · PR2 tests

- Component test `ComparisonTable.test.tsx`: render 4 columns, toggle hides identical rows
- Snapshot test catalog
- E2E mínimo: `curl /comparar-casas` returns 200 con HTML válido

### 5.3 · PR3 tests

- Component tests calendar + table
- Snapshot test catalog
- E2E `/disponibilidad` returns 200

### 5.4 · Eval framework re-runs

- Después de PR1 merge+deploy
- Después de PR3 merge+deploy (validar no regresión)
- Baseline objetivo: ≥95% global, lead_precios ≥85%, 0 villa_name violations

---

## §6 · DEFINITION OF DONE

### 6.1 · PR1 DOD

- [ ] Diff revisado por WC/Alex
- [ ] Tests passing local
- [ ] Migration 0050 aplicada remote
- [ ] Worker-bot deployado
- [ ] Eval re-corrido por CC: ≥95% global, lead_precios ≥85%
- [ ] 0 violaciones de villa_names en los 30 casos
- [ ] Smoke test WhatsApp con subscriber fresh — Alex confirma

### 6.2 · PR2 DOD

- [ ] `/comparar-casas` LIVE
- [ ] Datos verificados contra KB JSONs
- [ ] Toggle + sticky header funcionan
- [ ] Intent catalog actualizado, snapshot test pass
- [ ] Links cross-site en footer + páginas villa

### 6.3 · PR3 DOD

- [ ] `/disponibilidad` LIVE
- [ ] Calendario + tabla funcionan
- [ ] Eval framework re-corrido sin regresiones
- [ ] Si cache D1 no existe: issue separado abierto + página con mock data

### 6.4 · Mega-run DOD global

- [ ] 3 PRs mergeados
- [ ] Producción funcionando: bot no menciona villas inventadas, leads ven `/comparar-casas` y `/disponibilidad` cuando aplica
- [ ] Eval baseline post-run documentado en thread reporte CC
- [ ] Memorias WC actualizadas
- [ ] thread/218 (CC report) creado con summary

---

## §7 · RIESGOS + MITIGACIONES

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| KB inyectada al prompt rompe el cache de Haiku (Tier 2 cambia > 2048 tokens) | Media | Alto (costo) | Verify post-deploy en cost_telemetry. Si crash de cache: ajustar para mantener Tier 2 estable. |
| Prompt v7.1 cambia tanto que regresiona ec024 (VIP toallas que pasó) | Baja | Medio | Test ec024 explícito antes y después. |
| Cache D1 disponibilidad no existe → PR3 deja mock | Alta | Bajo | Aceptable. CC abre issue separado. Página LIVE con mock data + nota "datos en tiempo real próximamente". |
| Sticky header rompe en mobile | Media | Bajo | Desktop-first explícito. Mobile responsive es backlog. |
| CC mergea PR2 antes que Alex confirma PR1 OK | Baja | Alto | Spec explícito: HALT después de PR1 push. Esperar GO. |
| Eval framework run autónomo de CC consume API key cuota | Baja | Bajo | Cap manual: max 5 runs durante todo el mega-run. |
| Out-of-scope finding crítico durante run | Media | Variable | Open issue, NO fix inline. Si safety: HALT. |
| Link a `/disponibilidad` desde calendar mockup rompe porque catálogo aún apunta a `/#casas` | Baja | Bajo | Catalog update va en PR3 mismo, no separado. |
| Wrangler 4.14.1 crash en Windows entre comandos | Alta | Bajo | Ignorar assertion failures post-exec. Confirmado en sesión. |

---

## §8 · ORDEN DE EJECUCIÓN

```
1. CC pull branch main, verify clean
2. PR1: feat/greeter-v7.1-kb-runtime-injection
   - Implement bot fixes
   - Push branch + open PR
   - HALT — report a Alex
3. Alex review PR1, merge, deploy manual
4. CC: corre run-eval-local.ts post-deploy
5. CC reporta: scores
6. Alex confirma GO siguiente
7. PR2: feat/comparar-casas-page
   - Read 4 JSONs from R2
   - Build comparison page
   - Push branch + open PR
8. CC despliega apps/web (CF Pages auto)
9. CC smoke check /comparar-casas
10. CC continúa a PR3 sin pausar
11. PR3: feat/disponibilidad-page
    - Build calendar + table
    - Push branch + open PR
12. CC despliega
13. CC smoke check + re-run eval
14. CC reporta global summary en thread/218
```

---

## §9 · CRITERIO DE HALT

CC se detiene y reporta a Alex si:

- Tests fallan después de 2 intentos de fix
- Wall-clock >30 min en una sub-tarea sin progreso
- Migration fail
- Deploy fail
- Eval framework score < threshold después de PR1
- Found out-of-scope con potential safety impact
- KB JSONs en R2 inaccesibles
- 2+ commits sin diff útil (loop)

NO halt para:
- Out-of-scope findings menores → abrir issue
- Test flake → reintentar 1 vez
- Wrangler crash post-exec → ignorar (bug conocido)

---

## §10 · REPORTAR AL FINAL

CC crea `threads/218-CC-Bot-doit-217-megarun-report.md` con:

1. Resumen: 3 PRs status (merged/open/blocked)
2. PR1 metrics: eval scores pre vs post
3. PR2 deliverables + screenshots conceptuales (descripción visual)
4. PR3 deliverables + estado del cache D1
5. Out-of-scope findings list (issues abiertos)
6. Riesgos identificados durante el run
7. Memorias sugeridas para WC update
8. Total CC tokens consumidos (cost telemetry)
9. Wall-clock total
10. Next steps recomendados

---

EOF
