# Thread 14 — CC investigación pre-cutover AirBnB

**Date**: 2026-05-12
**Author**: Claude Code (CLI, sesión Sprint 1 + canary)
**To**: Web Claude `[@wc]`, Alexander `[@alex]`
**Re**: Paso 2 (read-only) del handoff `airbnb-cutover-handoff-cc.md`. NO se ejecutaron writes.

---

## 0. TL;DR

- **Token Beds24 vigente**: scopes `all:channels` (incluye airbnb), 12h+ vida restante
- **AirBnB Channel Manager**: 1 cuenta conectada (Alexander, airbnbUserId 95731371), 11 listings detectadas (4 activas, 7 inactivas)
- **Sync status**: TODAS las listings están en `synchronization_category: "none"` (pre-cutover, modo iCal)
- **Listing 872479727584938056** (Morenas s/ser, esperada como desactivada en handoff) **NO aparece en API** — ver §7
- **74322 (Morenas canónico)**: ✅ tiene calendar configurado próximos 30d (15 ranges, $3,500-$8,500) — **NO blocker** para cutover
- **74316 (Combinada) dependencies**: 🔴 incluye **374482 obsoleto** además de 78695+74322. Funcionalmente OK (374482 vacío) pero limpiar antes/post-cutover
- **45 confirmed bookings** próximos 90d en propiedad: 29 AirBnB (vía iCal actual) + 14 direct + 2 setBooking JSON
- **PermitId vacío** en propiedad — verificar si AirBnB requiere para Mexico/Acapulco

---

## 1. Channel Manager Status (§2.1 handoff)

### 1.1 AirBnB user conectado

```json
{
  "airbnbUserId": "95731371",
  "firstName": "Alexander",
  "picture": "https://a0.muscache.com/im/pictures/user/User/...jpeg"
}
```

- Conectado a Beds24 vía OAuth (no email visible en este endpoint)
- Permissions: implícitas por OAuth flow — endpoint `/v2/channels/airbnb/users` no devuelve scope detalle

### 1.2 Listings detectadas (11 total)

| AirBnB ID | Nombre (corto) | has_avail | sync_category | Esperada según handoff |
|---|---|---|---|---|
| **18780853** | RinconMar_6Habitaciones · Beachfront villa | ✅ true | `none` | ✅ → 78695 RdM |
| **733868075691217916** | VillaMorenas · 70m beach, 30 ppl, CHEF | ✅ true | `none` | ✅ → 74322 Morenas |
| **18009632** | Dos villas · 58 personas | ✅ true | `none` | ✅ → 74316 Combinada |
| **1577678927412395161** | Huerta · pie de playa | ✅ true | `none` | ✅ → 637063 Huerta |
| 19837998 | VillaMorenas · 28 ppl alterno | ❌ false | `none` | ⚠️ no en handoff (legacy?) |
| 31173575 | RinconMar_5Habitaciones | ❌ false | `none` | ⚠️ no en handoff (legacy?) |
| 31173658 | Cuarto 2 · 5 guests | ❌ false | `none` | ⚠️ no en handoff (room split?) |
| 31173670 | Cuarto 4 · 5 guests | ❌ false | `none` | ⚠️ no en handoff (room split?) |
| 31173674 | Cuarto 3 · 5 guests | ❌ false | `none` | ⚠️ no en handoff (room split?) |
| 31174165 | Bodas · WEDDING | ❌ false | `none` | ⚠️ no en handoff (eventos?) |
| 1656138511899435479 | (sin nombre) | ❌ false | `none` | ⚠️ listing nueva sin contenido? |

**Confirmado**: 4 listings activas matchean exactamente las 4 esperadas (RdM, Morenas, Dos Villas, Huerta).

**Listing 872479727584938056** (Morenas s/ser Sophia, "DESACTIVADA" según handoff): **NO aparece en API response**. Hipótesis:
- Borrada completamente (no solo deactivated)
- O AirBnB no la incluye porque lleva mucho tiempo suspendida
- O el ID del handoff es typo

Para WC: confirmar con Alex si la listing existe en AirBnB extranet o ya fue eliminada.

---

## 2. Rooms config (§2.2 handoff)

Property: **Rincón del Mar** (id=31862, owner 17972)

### 2.1 Room 78695 — Rincón del Mar

| Field | Value |
|---|---|
| name | Rincon Mar |
| maxPeople | 30 |
| minStay | 2 (room-level default) |
| maxStay | 365 |
| rackRate | $5,500 (fallback days 366+) |
| dependencies | (none) |
| ratePerExtraPerson | (no en includeRoomRates response) |

### 2.2 Room 74322 — Las Morenas (canónico post-cutover)

| Field | Value |
|---|---|
| name | Rincon Morenas |
| maxPeople | 30 |
| minStay | 2 |
| maxStay | 365 |
| rackRate | $3,500 |
| dependencies | (none) |

### 2.3 Room 74316 — Combinada (Dos Villas)

| Field | Value |
|---|---|
| name | Dos villas |
| maxPeople | 60 |
| minStay | 2 |
| maxStay | 365 |
| rackRate | $10,000 |
| **dependencies.combinationLogic** | `allRoomsAvailable` |
| **dependentRoomId1** | 78695 ✓ |
| **dependentRoomId2** | **374482** ⚠️ **obsoleto** |
| **dependentRoomId3** | 74322 ✓ |
| assignBookingsTo | thisRoom |

🟡 **Hallazgo importante**: dependency contiene `374482` (room renombrado a "!!! historico !!!" tras cutover bookings 374482→74322 del 2026-05-12). Funcionalmente NO bloquea (374482 está vacío de future bookings → siempre "disponible"), pero queda como dato obsoleto. **Recomendado limpiar** post-cutover (cambiar `dependentRoomId2: null` o reasignar). No es blocker para Connect AirBnB.

### 2.4 Room 637063 — Huerta Cocotera

| Field | Value |
|---|---|
| name | Huerta |
| maxPeople | 12 |
| minStay | 2 |
| maxStay | 365 |
| rackRate | $1,500 |
| dependencies | (none) |

### 2.5 Room 374482 — Las Morenas (ARCHIVE)

| Field | Value |
|---|---|
| name | `!!!   Rincon Morenas - historico!!!!` |
| maxPeople | 30 |
| rackRate | $3,500 |

NO debe ser tocado en cutover. Mantener como archive vivo (157 históricos).

### 2.6 Room 679176 — Casa Chamán

| Field | Value |
|---|---|
| name | Casa Chaman |
| maxPeople | 2 (placeholder) |
| minStay | 0 (no listo) |
| rackRate | $0 |

NO en scope de cutover (Q3 2026).

### 2.7 Daily Price Rules (extra person, capacity tiers)

❌ **No accesible vía endpoint `/v2/properties/rates`** — devuelve 500 Internal Server Error en todas las variantes probadas (`?id=`, `?propertyId=`, `?propertyIds=`, `/v2/properties/dailyRates`).

Tampoco en `?includeRoomRates=true` (los rooms no muestran `priceRules` ni `dailyPriceRules`).

**Workaround**: extra person & capacity tiers están embebidos en daily calendar response per día. Inferimos pricing real desde calendar §3.

Para WC: si necesita ratePerExtraPerson explícito, hay que pedirle a Alex que verifique en panel Beds24 → SETUP → ROOM RATES per room.

---

## 3. Calendar state — próximos 30 días (§2.2-2.3 handoff)

| roomId | Range | Days priced | Days disponibles | Price min | Price max | Min stay observado |
|---|---|---|---|---|---|---|
| **78695 RdM** | 22 ranges | 31 / 31 | 1 ⚠️ | $8,500 | $13,500 | 2-4 |
| **74322 Morenas** ✅ | 15 ranges | 30 / 30 (estimado) | 2 | $3,500 | $8,500 | (en file 05b) |
| **74316 Combinada** | 16 ranges | 30 / 30 | 0 ⚠️ | $13,500 | $22,000 | (en file 05c) |
| **637063 Huerta** | 15 ranges | 30 / 30 | 11 | $1,500 | $2,000 | (en file 05d) |

🟢 **74322 SÍ tiene calendar configurado** (handoff blocker hard descartado).

🟡 **74316 Combinada disponible 0 días** próximos 30: porque dependencies con 78695 y 74322 → cuando cualquiera está reservado, Combinada bloqueada. Esperado.

🟡 **78695 RdM disponible solo 1 día** próximos 30 (semana santa + alta demanda): operativo correcto, no problema.

### 3.1 Cross-check con handoff esperados

| roomId | base capacity | min stay obs | range precios |
|---|---|---|---|
| 78695 RdM | 30 (handoff dice 15) | 2-4 ✓ | $8,500-$13,500 (handoff dice $6,750-$32,000) |
| 74322 Morenas | 30 (handoff dice 15) | 2-? | $3,500-$8,500 (handoff "?") |
| 74316 Combinada | 60 (handoff dice 30) | 2-? | $13,500-$22,000 (handoff $13,500-$52,000) |
| 637063 Huerta | 12 (handoff dice 4) | 2-? | $1,500-$2,000 (handoff $1,500-$5,000) |

🟡 **Discrepancia capacity**: handoff documenta `base capacity` que asumo es "Up to N people sin extra" (precio base). Mi data es `maxPeople` (cap absoluta). Posible que room tenga `maxPeople: 30` con `roomPriceUpTo: 15` y `roomPriceExtraPerson: $300/persona` (handoff confirma). El daily calendar API sólo expone `price1` (precio base por noche), no extras — necesitaría endpoint Daily Price Rules para confirmar (ver §2.7, no accesible).

🟡 **Discrepancia rango precios**: mi rango es próximos 30d. Handoff probablemente ve rango de 360d. Mi rango es subset, no contradice.

🟢 **min_stay 2-4**: confirma rango. ✓

---

## 4. Bookings AirBnB futuros (§2.5 handoff)

⚠️ Endpoint `/v2/bookings?roomId=X,Y,Z&referer=Airbnb` retorna **400 Bad Request**. Workaround: query por `propertyId=31862` y filter en cliente.

**Total confirmed bookings próximos 90 días**: 45

Por referer:

| Referer | Count |
|---|---|
| Airbnb.com | 29 |
| AlexanderHorn (direct) | 14 |
| setBooking JSON (API) | 2 |

Por roomId:

| roomId | Count | Nombre |
|---|---|---|
| 78695 | 22 | RdM |
| 74322 | 19 | Morenas (post-cutover) |
| 74316 | 2 | Combinada |
| 637063 | 2 | Huerta |
| 374482 | 0 | Morenas (archive — ✅ confirma cutover OK) |

Estos 29 bookings AirBnB son los que se MANTIENEN durante transición iCal→2-way. Beds24 debería deduplicarlos automáticamente al "Import existing bookings" durante Connect (no debería duplicar).

---

## 5. Property-level settings (§2.4 handoff)

| Field | Value |
|---|---|
| id | 31862 |
| name | Rincón del Mar |
| currency | **MXN** ✓ |
| address | C. Puerto Huatulco 10, San Nicolas, de las Playas, Coyuca de Benitez |
| city | (parte de address) |
| country | MX |
| latitude | 16.916715 |
| longitude | -100.007395 |
| **permitId** | (vacío) |
| **licenseNumber** | (vacío) |
| propertyType | (no expuesto en este endpoint) |

🟡 **PermitId / LicenseNumber vacíos**: AirBnB para Mexico no obliga, pero algunas ciudades sí (Cancún, CDMX). Acapulco/Coyuca de Benitez típicamente no requiere license para vacation rentals (a 2026), pero **WC verificar últimos cambios regulatorios** antes de Connect — si AirBnB rechazó listing por falta de license, hay que generar una en Acapulco gov.

🟢 Coords precisas (lat/lng decimal con 6 dígitos, matchea Pie de la Cuesta).

🟢 Address completa.

---

## 6. Issues found — categorización

### 🔴 BLOCKERS (no proceder hasta resolver)

Ninguno hard-blocker confirmado.

### 🟡 WARNINGS (proceder con cuidado)

1. **Dependency 74316 → 374482 obsoleto** (§2.3). Limpiar pre o post-cutover.
2. **PermitId vacío en propiedad** (§5). Verificar si Acapulco requiere a 2026.
3. **Listing 872479727584938056 (Morenas s/ser) NO en API** (§1.2). Confirmar con Alex si fue eliminada o re-aparece.
4. **6 listings inactivas con nombres legacy** (Cuarto 2, Bodas, RinconMar_5Habitaciones, etc.). Revisar si hay riesgo que AirBnB las "active" durante Connect. Recomendado mantener `has_availability: false` y NO mapear.
5. **Daily Price Rules endpoint inaccesible** (§2.7). Workaround calendar OK pero validar `ratePerExtraPerson` per room manualmente en panel.
6. **74316 Combinada `maxPeople: 60`** (vs Greeter prompt que dice 30). Posible discrepancia entre Beds24 capacity vs lo que el bot anuncia. Validar en cutover schemas (separado).

### 🟢 OBSERVATIONS (info-only)

1. Token Beds24 vigente, scopes correctos (`all:channels` incluye airbnb).
2. 1 AirBnB user conectado (Alexander, OAuth).
3. 4 listings activas matchean handoff esperadas.
4. 74322 calendar populated (NO blocker).
5. 374482 0 future bookings (cutover bookings exitoso).
6. 29 bookings Airbnb próximos 90d que se mantienen (dedupe import esperado).
7. Currency MXN, coords precisas, address completa.
8. Min stay 2-4 noches en RdM (matchea handoff).

---

## 7. Listings detectadas vs esperadas

| Listing AirBnB ID | Esperada (handoff) | Detectada en API | sync | Match |
|---|---|---|---|---|
| 18780853 | RdM → 78695 | ✅ activa | none | ✓ proceder |
| 733868075691217916 | Morenas → 74322 | ✅ activa | none | ✓ proceder |
| 18009632 | Dos Villas → 74316 | ✅ activa | none | ✓ proceder |
| 1577678927412395161 | Huerta → 637063 | ✅ activa | none | ✓ proceder |
| 872479727584938056 | (DESACTIVADA, ignorar) | ❌ **NO aparece** | n/a | ⚠️ ver §1.2 |

Adicionalmente detectadas (no en handoff):

| Listing AirBnB ID | Nombre | has_availability | Acción sugerida |
|---|---|---|---|
| 19837998 | VillaMorenas alterno | false | NO mapear (legacy) |
| 31173575 | RinconMar_5Habitaciones | false | NO mapear (legacy) |
| 31173658 | Cuarto 2 | false | NO mapear (room split antiguo) |
| 31173670 | Cuarto 4 | false | NO mapear (room split antiguo) |
| 31173674 | Cuarto 3 | false | NO mapear (room split antiguo) |
| 31174165 | Bodas | false | NO mapear (eventos) |
| 1656138511899435479 | (sin nombre) | false | NO mapear (vacía) |

Recomendación: durante Paso 4 (Alex Connect), confirmar visualmente que las 7 inactivas siguen en `has_availability: false` y NO se accidentalmente mapean.

---

## 8. Recursos de esta sesión

| Recurso | Ubicación |
|---|---|
| Token Beds24 access (vigente ~2026-05-13T02:29Z) | `C:\rincondelmar-bot\scripts\setup\.beds24-access.tmp` (gitignored) |
| Token Beds24 refresh (long-lived) | `C:\rincondelmar-bot\scripts\setup\.beds24-refresh.tmp` (gitignored) |
| Raw responses API (snapshots) | `C:\rincondelmar-bot\.tmp\beds24-airbnb-investigation\` (gitignored) |

Files snapshots:
- `01-airbnb-users.json` — 1 user
- `02-airbnb-listings.json` — 11 listings full structure
- `03-property-rooms-rates.json` — propiedad + 6 rooms config
- `05-calendar-30d.json` — 78695 calendar (response inicial)
- `05b-calendar-74322.json` — Morenas próximos 30d ✓
- `05c-calendar-74316.json` — Combinada próximos 30d
- `05d-calendar-637063.json` — Huerta próximos 30d
- `06-bookings-property-90d.json` — 45 bookings full

Ningún archivo commiteado al repo principal.

---

## 9. Pasos siguientes (per handoff §3-5)

| Paso | Owner | Status |
|---|---|---|
| 2 — CC investigación | CC (yo) | ✅ done (this thread) |
| 3 — WC análisis + propuesta `threads/15` | WC | 🟡 unblocked |
| 4 — CC ejecución cambios via API | CC | ⏸️ awaiting WC + Alex sign-off |
| 5 — Alex Connect en panel + WC verifica | Alex + WC | ⏸️ |

---

## 10. Sobre el contexto colateral

Esta sesión CC tiene work no relacionado al cutover AirBnB que está pausado:

- 🟢 Sprint 1 worker-bot deployed + canary 10% LIVE
- 🟡 GUARD branch `fix/bot-las-morenas-74322-guard` con 2 commits (1d8ea99 + 485eb5b) listo para push/deploy. Previene booking-en-archive en room 374482 mientras cutover completo de schemas LLM coordina con WC. Tests verde 64+82=146.
- 🟡 E2E ManyChat WhatsApp validación pending (subscriber 573268715 sin canal, esperando que Alex se mande WhatsApp real)
- ⏸️ Cutover completo Beds24 ~22 archivos (branch separado, awaiting WC sync `rdm-greeter-kb`)
- ⏸️ Webhook MP en MP dashboard (Alex UI)

Ninguno de estos afecta el AirBnB cutover (scope distinto).

---

## 11. Ping para WC

@wc — listo `threads/14`. Proceeed con `threads/15` (Paso 3 — análisis + propuesta multiplier + risk register). Findings clave para tu decision:

1. **Daily Price Rules inaccesible vía API** — analysis de extras manual o pedirle a Alex panel screenshot
2. **Discrepancia maxPeople 60** vs Greeter doc 30 para Combinada
3. **PermitId vacío** — confirmar regulatorio Acapulco
4. **Dependency 74316 contiene 374482 obsoleto** — propose cleanup como paso pre-cutover (1 API call PUT)
5. **Confirmar con Alex** si listing 872479727584938056 fue eliminada permanentemente o aún existe en extranet

---

*FIN. Investigación read-only. Sin escrituras.*

— Claude Code (sesión Sprint 1+canary), 2026-05-12T~04:00Z
