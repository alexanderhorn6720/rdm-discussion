# Execute: Import WC seed drafts + Karina onboarding

**Date**: 2026-05-14
**From**: WC + Alex
**To**: CC
**Re**: Thread/45-cc-wc-seed-drafts-discovery decisions + operational tasks
**ETA estimate**: ~3-4h CC (1h schema expansion + 1h import + 1h onboarding doc + smoke tests)
**Branch**: `feat/wc-seed-import`

---

## 0. Context summary

WC completó sprint content drafts 2026-05-14:
- 8 JSONs en `knowledge/content-drafts/` (4 props × ES+EN)
- 96/96 textboxes within AirBnB char limits
- 0 pending decisions
- 35+ third-party contacts preserved (legitimate vendor recommendations, NOT off-platform promotion)
- Alex confirmó 2026-05-14: EN listings Combinada + Huerta CREADOS en AirBnB (antes solo tenían ES)

Thread/45-mvp-live-and-content-drafts-ready.md = WC sprint closure thread.
Thread/45-cc-wc-seed-drafts-discovery.md = CC pidiendo decisión sobre schema gap.

---

## 1. DECISIÓN: expandir schema editor (no append strategy)

Tu thread/45 propuso 2 opciones para los 3 fields extras de WC drafts:
- **Opción A**: append strategy (mezclar con fields existentes)
- **Opción B**: expandir schema con 3 fields nuevos

**Decisión: Opción B (expandir schema).**

### Por qué

Los 3 fields que faltan en tu schema son **fields nativos AirBnB**, no inventados WC:

| Field WC | AirBnB UI field name |
|---|---|
| `acceso_huespedes` | "Acceso de los huéspedes" |
| `interaccion_huespedes` | "Interacción con los huéspedes" |
| `metodo_llegada` | "Método de llegada" |

Estos campos existen como textboxes separados en la UI de AirBnB. Si haces append:
1. **Push a AirBnB se complica**: cuando uses Chrome MCP para escribir back a AirBnB field por field, el contenido de `acceso_huespedes` está embedded en `tu_propiedad` — tienes que parsearlo back. Frágil.
2. **alex_ok/karina_ok per-field se pierde**: Alex aprueba "tu_propiedad" entero pero realmente son 3 contenidos distintos. Forzar a aprobar todo junto o nada.
3. **Re-edición se complica**: Karina edita "Acceso de los huéspedes" → tiene que encontrar la sección dentro de un blob.

Expandir schema es trivial (3 nuevos `airbnb_field` types) y matches 1:1 con AirBnB. Hazlo ahora, no en Fase 2.7.

### Schema expansion concreto

Agrega a tu schema:

```typescript
type AirbnbFieldKey =
  | 'title'
  | 'description'
  | 'tu_propiedad'
  | 'acceso_huespedes'           // NEW
  | 'interaccion_huespedes'      // NEW
  | 'otros_detalles'
  | 'como_llegar'
  | 'metodo_llegada'              // NEW
  | 'wifi_red'
  | 'wifi_password'
  | 'manual_casa'
  | 'instrucciones_salida';
```

Char limits (per WC drafts):
- `acceso_huespedes`: 1000 chars
- `interaccion_huespedes`: 1000 chars
- `metodo_llegada`: 200 chars

Update editor UI cards: ahora muestran "12/12" en vez de "9/9".

---

## 2. DECISIÓN: schema bridge entre WC JSON y tu editor

WC schema vs tu schema son distintos. Bridge concreto:

| WC field path | Tu schema equivalent |
|---|---|
| `airbnb_fields.{name}.content` | `fields.{name}.value` |
| `airbnb_fields.{name}.char_count` | computed runtime, no store |
| `airbnb_fields.{name}.max_chars` | constant per field type, no store |
| `airbnb_fields.{name}.format` | constant per field type |
| `airbnb_fields.{name}.wc_notes` | NEW: agregar `notes` field, mostrar amarillo en UI |
| `metadata.approvals.alex_ok` (single) | `fields.{name}.alex_ok` (per-field, ya decidido thread/42) |
| `metadata.approvals.karina_ok` (single) | `fields.{name}.karina_ok` (per-field) |
| `metadata.pending_decisions[]` | `fields.{name}.pending_decision` (move into field) |
| `metadata.changelog[]` | NEW: agrega `changelog` array a tu schema |
| `_signature_canonical` | Constant en código: `"— Alexander 🌅\n· rincondelmar\n· club"` |
| `_signature_note` | No persistir, es documentación |
| `property.slug` | match con tu slug |
| `property.airbnb_listing_id` | NEW si no tienes |
| `property.beds24_room_id` | NEW si no tienes |
| `property.display_name` | match |

### wc_notes UI rendering

Cada cell del editor que tenga `wc_notes` muestra:
- Banner amarillo arriba del textbox: `📝 Nota WC: {wc_notes}`
- Collapsible si > 200 chars
- No bloquea edición, solo guía

Esto es importante porque mis notas explican decisiones (e.g. "WiFi Morenas usa 'Rincondelmar1' con 1 final, distinto a otros" — si Karina lo cambia sin leer la nota, rompe el real WiFi).

---

## 3. TASK: build converter + import endpoint

Sigue tu propuesta de thread/45 con ajustes:

### 3.1 Files to create

```
apps/web/src/lib/wc-seed-converter.ts          # pure function
apps/web/tests/wc-seed-converter.test.ts       # 16 tests min (8 files × 2 sanity checks)
apps/web/src/pages/api/admin/airbnb-content/import-wc-seeds.ts  # POST endpoint
apps/web/src/components/admin/ImportWCSeedsButton.tsx  # UI button
```

### 3.2 Converter behavior

```typescript
interface WCSeedDraft { ... }  // matches knowledge/content-drafts/*.json
interface EditorDraft { ... }  // matches your R2 schema

function convertWCSeed(wcSeed: WCSeedDraft): EditorDraft {
  // 1. Map 12 airbnb_fields → 12 editor fields (1:1 now with schema expansion)
  // 2. For each field:
  //    - value = wc.content
  //    - alex_ok = false (esperando review)
  //    - karina_ok = false
  //    - notes = wc.wc_notes (display in UI)
  //    - pending_decision = (from metadata.pending_decisions if applicable)
  // 3. Copy changelog
  // 4. Copy property.{slug, airbnb_listing_id, beds24_room_id, display_name}
  // 5. Initialize deployed_to_airbnb = false
}
```

### 3.3 Safety constraints

- **NO sobrescribe drafts existentes** por default. Endpoint requiere `?force=true` para bulk overwrite. Si Karina ya empezó a editar algo, no se pierde.
- **Idempotency**: import endpoint debe ser safe re-runnable. Mismo input → mismo output.
- **Validation pre-import**: chequear char limits antes de write a R2. Si falla, abort + report.
- **Audit log**: cada import escribe entrada a tabla `import_logs` (D1) con `at`, `by`, `files_imported`, `force`, `result`.

### 3.4 UI button

En `/admin/airbnb-content` overview (top), botón:

```
[ Importar drafts iniciales WC ]
  └─ on click: confirm modal
     "Importar 8 drafts (4 propiedades × 2 idiomas) desde knowledge/content-drafts/?
      Esto NO sobrescribirá drafts existentes."
     [ Cancelar ] [ Importar ]
```

Post-import: refresh page, las 8 cards muestran "12/12 ░░░░░░░░░░ Alex 0% Karina 0%".

### 3.5 ETA

~1.5-2h CC para todo lo anterior (schema expansion + converter + endpoint + UI + tests).

---

## 4. TASK: Karina onboarding doc

Crear: `docs/karina-onboarding.md` (~1 página, mobile-friendly markdown).

### Estructura recomendada

```markdown
# Bienvenida Karina — Editor de Contenido AirBnB

## 1. Login (1 min)
- Abre rincondelmar.club/admin/airbnb-content en tu teléfono o laptop
- Selecciona "Email" → escribe karina@rincondelmar.club → "Enviar enlace"
- Revisa tu bandeja de entrada, abre el correo "Inicia sesión..." y haz click
- Estás dentro ✓

## 2. ¿Qué vas a ver? (30 seg)
[Screenshot del overview con las 4 propiedades]
- 4 propiedades × 2 idiomas (ES + EN) = 8 listings AirBnB
- Cada uno con 12 textboxes que se publican en AirBnB
- Estado actual: drafts iniciales escritos por Claude (WC)

## 3. Tu trabajo: revisar y aprobar (15-20 min por listing)
Por cada textbox:
1. Lee el draft
2. Si está bien → marca checkbox "Karina OK"
3. Si necesitas cambios → edita → guarda → marca "Karina OK"

Notas amarillas: si ves una nota 📝 en amarillo arriba del textbox, léela ANTES de editar — explica decisiones importantes.

## 4. Conventions útiles
- `[para Alex]` = nota directa para Alexander, déjalas
- `{open: ...}` = pregunta pendiente, NO toques sin discutir con Alexander
- Footer "— Alexander 🌅 · rincondelmar · club" = NO tocar, se aplica automático

## 5. ¿Qué NO toques?
- El footer canonical (al final de textos largos)
- Códigos de WiFi (red + contraseña) — Alexander confirma
- URLs Google Maps (Alexander verifica si hay errores)
- Números de teléfono de terceros (son recomendaciones confirmadas con esos contactos)

## 6. ¿Cuándo se publica a AirBnB?
Cuando un textbox tiene "Karina OK" + "Alex OK", entra en cola de publicación. Alexander corre el push final cada cierto tiempo. No te preocupes por esa parte.

## 7. Preguntas
Cualquier cosa: WhatsApp a Alexander +52 55 7061 8798
```

Idealmente con 2-3 screenshots del editor real (overview + edit cell + with note banner). Si no hay tiempo de screenshots, deja `[Screenshot: ...]` placeholders y Alex los toma después.

### ETA

~1h CC.

---

## 5. TASK: thread/46 reply post-import

Después de import + onboarding doc, escribe `threads/46-import-complete-onboarding-ready.md`:

- Confirmación import 8 JSONs success
- Link a `docs/karina-onboarding.md`
- Status: editor fully wired, Karina onboarding ready
- Pending Alex: agendar sesión 30 min con Karina + iniciar tap-by-cell review

---

## 6. Verificar EN listings AirBnB Combinada + Huerta (read-only)

Alex creó EN listings 2026-05-14 para `18009632` (Combinada) y `1577678927412395161` (Huerta). Verifica con Chrome MCP (read-only, NO editar nada):

```javascript
// Open AirBnB host dashboard, navigate to each listing
// Check that EN variant exists (language toggle shows "English")
// Report findings in thread/46
```

Si una falta, flaga a Alex. NO intentes crear EN listing tú mismo — eso lo hace Alex manualmente (UI flow estructural).

ETA: 5 min cada listing = 10 min total.

---

## 7. Out of scope para este sprint

NO hagas (déjalo para futuro):

1. **Push final a AirBnB**: requiere `alex_ok` + `karina_ok` en cada cell, todavía no aplica
2. **Schema migration para drafts existentes**: si Karina ya tenía algo drafted en el editor antes del import, NO lo migres al schema expandido — solo aplica schema nuevo a imports nuevos. Migration de existentes lo discutimos después
3. **EN listing creation**: Alex lo hace manual
4. **Bot training**: el sprint de Welcome Guide / Phase B viene después
5. **Sitio web `/en/` integration con drafts**: si quieres, en Fase 2.7

---

## 8. Acceptance criteria

Antes de cerrar branch + PR:

- [ ] Schema editor expandido con 3 fields nuevos (acceso_huespedes, interaccion_huespedes, metodo_llegada)
- [ ] Cards UI muestran "12/12" en vez de "9/9"
- [ ] Converter tests pass (≥16 tests, incluyendo edge cases char limit overflow)
- [ ] Import endpoint con `force=false` no sobrescribe drafts existentes
- [ ] Audit log entry creado por import
- [ ] 8 drafts visibles en `/admin/airbnb-content` overview con contenido WC
- [ ] wc_notes rendering en amarillo arriba de cada cell con nota
- [ ] `docs/karina-onboarding.md` creado y revisable
- [ ] EN listings AirBnB Combinada + Huerta verificados existen
- [ ] thread/46-import-complete-onboarding-ready.md publicado

---

## 9. Flag para WC

Si encuentras algo de los drafts WC que NO concuerda con la realidad operacional (e.g. precio chef desactualizado, teléfono de un proveedor que ya no opera, etc.), **NO lo corrijas silenciosamente**. Flag en thread/46 sección "WC drafts findings" y Alex/WC corrigen en repo.

Si encuentras conflicto entre `knowledge/airbnb-listing-fields-current-2026-05-13.md` (estado actual AirBnB) y los WC drafts (estado deseado), siempre gana el **WC draft** porque ya integra las decisiones Q-A14 de Alex.

---

End of instructions. ¿Preguntas? Pinguea WC en thread/46 antes de empezar branch si algo no queda claro.
