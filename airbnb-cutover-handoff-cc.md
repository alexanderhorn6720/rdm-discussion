# Beds24 AirBnB 2-way API Cutover — handoff para CC

**Date**: 2026-05-12
**Author**: Web Claude
**Para**: Claude Code (sesión nueva o existente)
**Modo**: Híbrido — CC investiga vía Beds24 API, commitea findings a discussion repo, Web Claude interpreta + propone, Alex decide + activa Connect final en panel
**ETA total**: ~90 min (45 min CC investigación + 30 min WC análisis + 15 min Alex Connect)

---

## 0. Contexto

Alex tiene 5 listings AirBnB históricamente, conectadas a Beds24 vía iCal feeds. Ayer (2026-05-11) Alex hizo "Connect with Airbnb Account" en Beds24 panel — eso disparó switch automático AirBnB de split-fee (3%) → host-only fee (16% + IVA ≈ 18%). No hay rollback de fee.

**Listings reales**:

| Listing AirBnB ID | Nombre | Status | Mapeo objetivo Beds24 roomId |
|---|---|---|---|
| 18780853 | Rincón del Mar | activa | 78695 |
| 872479727584938056 | Morenas s/ser (Sophia) | **DESACTIVADA** — ignorar | (374482 archivado) |
| 733868075691217916 | Morenas c/ser | activa | 74322 |
| 18009632 | Dos Villas | activa | 74316 |
| 1577678927412395161 | Huerta | activa | 637063 |

**Objetivo del cutover**:
- Activar sync `Prices & Availability` en los 4 listings
- Channel Multiplier para compensar 18% fee → mantener ingreso neto pre-cambio
- 0 doble booking durante transición iCal→API
- Cliente AirBnB ve pricing consistente con direct WhatsApp/web (compensado por fee)

**Scope estricto**:
- ✅ Channel Manager AirBnB de Beds24
- ✅ AirBnB extranet settings
- ❌ NO rdmbot
- ❌ NO worker-bot canary
- ❌ NO Make scenarios
- ❌ NO Booking.com (existe paralela, no tocar)

---

## 1. Pre-requisitos CC

### 1.1 Tokens Beds24
CC ya tiene access token con scopes: `bookings`, `bookings-personal`, `channels-airbnb`, `inventory`, `properties` (del invite code stored en Make datastore 85643 key `beds24_invite_code`, usado en migración 374482→74322).

Verifica con:
```bash
curl -sX GET "https://api.beds24.com/v2/authentication/details" \
  -H "token: $TOKEN"
```

Confirma scopes incluyen `channels-airbnb` (read + write).

### 1.2 Discussion repo
Trabajo se commitea como threads en `https://github.com/alexanderhorn6720/rincondelmar-bot-discussion`. Naming:
- `threads/14-cc-beds24-current-state-investigation.md` (CC paso 1)
- `threads/15-wc-cutover-proposal-analyzed.md` (WC paso 2)
- `threads/16-cc-cutover-execution-log.md` (CC paso 3)
- `threads/17-wc-final-verification.md` (WC paso 4)

---

## 2. Paso 1 — CC investigación (45 min)

CC ejecuta las siguientes queries y commitea findings en `threads/14`.

### 2.1 — Investigar AirBnB Channel Manager status

**Endpoint 1**: Channel users (cuenta AirBnB conectada)
```bash
curl -sX GET "https://api.beds24.com/v2/channels/airbnb/users" \
  -H "token: $TOKEN"
```

Documenta:
- AirBnB user IDs conectados
- Email de la cuenta AirBnB
- Permissions otorgados (read listings, manage calendar, etc.)
- Fecha de conexión

**Endpoint 2**: Listings detectadas
```bash
curl -sX GET "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN"
```

Per listing devuelta, extraer:
- Listing AirBnB ID
- Listing name actual en AirBnB
- Current sync status (probablemente `disconnected`, `undecided`, o vacío)
- Current room mapping (debe estar vacío o `null`)
- Current channel multiplier (debe ser 1.0 o vacío)
- Cleaning fee actual
- Cancellation policy currently set

🔴 **Si alguna listing NO aparece** en API response pero existe en AirBnB extranet:
- Problema potencial de permissions
- Posible que CC necesite re-invite a la app Beds24 en AirBnB
- Reportar en thread/14 sin proceder

### 2.2 — Investigar configuración rooms Beds24

**Endpoint**: Propiedad detallada
```bash
curl -sX GET "https://api.beds24.com/v2/properties?id=31862&includeAllRooms=true&includeTexts=es" \
  -H "token: $TOKEN"
```

Per room (78695, 74322, 74316, 637063), documentar:

#### Configuration general
- `name` (verificar matchea lo esperado)
- `quantity` (≥ 1 para activo)
- `roomTypeId` / `roomType` (Property = SINGLE / Multi-Unit)
- `maxPeople` (capacidad máxima incluyendo extras)
- `maxAdult`, `maxChildren`
- `minStay`, `maxStay` (a nivel room)
- `bookable` flag

#### Channel Manager
- `channelManager.enabled` (debe ser true)
- Otros channel settings

#### Dependencies (CRÍTICO para Combinada 74316)
- Para 74316: ¿qué rooms aparecen en `requiresAvailability` o equivalente?
- Para 78695 y 74322: ¿están listados en algún room's `blockRooms`?

#### Daily Prices availability
Ejecutar también:
```bash
curl -sX GET "https://api.beds24.com/v2/inventory/rooms/calendar?roomId=78695,74322,74316,637063&startDate=2026-05-12&endDate=2026-06-12&includePrices=true&includeMinStay=true&includeMaxStay=true&includeNumAvail=true&includeOverride=true" \
  -H "token: $TOKEN"
```

Per room, documenta:
- ¿Cuántos días en los próximos 30 tienen precios configurados? (cero = problema)
- Rango de precios mín/máx
- Rango de min_stay (debe ser 2-4)
- Días bloqueados (numAvail=0)
- Días con `override="blackout"` 

#### Price For (capacidad base) y Extra Person
**Endpoint Daily Price Rules**:
```bash
curl -sX GET "https://api.beds24.com/v2/properties/rates?propertyId=31862" \
  -H "token: $TOKEN"
```

Per room, extrae:
- `roomPrice` (precio base)
- `roomPriceUpTo` (capacidad base, e.g. "Up to 15 people")
- `roomPriceExtraPerson` (e.g. $300/persona/noche extra)
- Cualquier seasonal pricing rule

🔴 **Si algún room tiene `roomPriceExtraPerson` negativo**: setup raro (algunos channel managers usan negative extras). Reportar.

### 2.3 — Cross-check con calendar lookup conocido

Compara contra estos valores esperados (de mi cache de hoy 2026-05-12T06:13Z):

| roomId | base capacity | Extra/pax/noche | Min stay observado | Range precios |
|---|---|---|---|---|
| 78695 RdM | 15 | $300 | 2-4 | $6,750-$32,000 |
| 74322 Morenas | 15 | $300 | 2-4 | ? (estaba vacío pre-cutover, debe poblar post-374482 archive) |
| 74316 Combinada | 30 | $300 | 2-4 | $13,500-$52,000 |
| 637063 Huerta | 4 | $200 | 2-4 | $1,500-$5,000 |

⚠️ **Para 74322**: si el calendar API no devuelve precios para 74322 ahora, **es blocker hard** para el cutover. AirBnB necesita ver pricing antes de Connect. Reportar inmediatamente, no proceder sin esto.

### 2.4 — Investigar Property-level settings

```bash
curl -sX GET "https://api.beds24.com/v2/properties?id=31862&includeTexts=es&includeAllRooms=false" \
  -H "token: $TOKEN"
```

Documenta:
- `permits` / `permitId` / `licenseNumber` (Acapulco normalmente no requiere, verificar)
- `currency` (debe ser MXN)
- `propertyType` (e.g. Hotel, Apartment, House)
- Address completa (calle, ciudad, código postal)
- `latitude`, `longitude` (AirBnB requiere coords precisas)
- `cancelPolicy` global

### 2.5 — Análisis de bookings futuros AirBnB existentes (iCal)

```bash
curl -sX GET "https://api.beds24.com/v2/bookings?roomId=78695,74322,74316,637063&arrivalFrom=2026-05-12&arrivalTo=2026-08-12&status=confirmed&referer=Airbnb" \
  -H "token: $TOKEN"
```

Documenta:
- Total bookings AirBnB próximos 90 días por room
- ¿Algún booking sin guest email/phone? (iCal viejos pueden ser anónimos)
- Patrones: weekday vs weekend, longest stay

Esto es para entender qué bookings se MANTIENEN durante transición.

### 2.6 — Output esperado en threads/14

Crear `threads/14-cc-beds24-current-state-investigation.md` con:

```markdown
# Thread 14 — CC investigación pre-cutover AirBnB

## 1. Channel Manager Status
[summary from 2.1]

## 2. Rooms config (4 active)
### 2.1 78695 RdM
[config details, Daily Prices summary, Dependencies]
### 2.2 74322 Morenas
[idem]
### 2.3 74316 Combinada (Dos Villas)
[idem + dependency to 78695 + 74322 verified?]
### 2.4 637063 Huerta
[idem]

## 3. Calendar state (30 días)
[table per room: days configured, min/max price, min_stay range]

## 4. Bookings AirBnB futuros (90 días)
[count per room]

## 5. Property-level settings
[permit, currency, address]

## 6. Issues found
[lista de blockers, warnings, raras]

## 7. Listings AirBnB detectadas vs esperadas
- 18780853 RdM: detected? sync status? mapping?
- 733868075691217916 Morenas: detected? sync? mapping?
- 18009632 Dos Villas: detected? sync? mapping?
- 1577678927412395161 Huerta: detected? sync? mapping?
- 872479727584938056 Morenas s/ser: should be ABSENT (deactivated)
```

Commit message: `threads/14 — CC Beds24 pre-cutover investigation`

Ping a WC al terminar.

---

## 3. Paso 2 — WC análisis + propuesta (30 min)

WC lee thread/14, analiza, commitea `threads/15` con:

### 3.1 — Costos actuales vs AirBnB expose

Per room, comparativa:

| roomId | Daily Price Beds24 (rango) | Multiplier propuesto | Daily Price expuesto AirBnB (post-multiplier) | Cliente paga pre-cambio | Cliente paga post-cambio | Diff |
|---|---|---|---|---|---|---|
| 78695 | $6,750-$32,000 | 1.183 | $7,985-$37,856 | $7,695-$36,480 (×1.14) | $7,985-$37,856 | +3.7% |

(WC fills exact numbers con data real de CC)

### 3.2 — Análisis Min Stay

Comparar:
- **Hoy iCal**: AirBnB y Beds24 cada uno tienen min_stay propio. AirBnB respeta lo que Alex configuró en extranet. Beds24 respeta Daily Price Rules. No hay sync.
- **Post-cutover Prices & Availability**: Beds24 envía min_stay per day a AirBnB. AirBnB aplica al check-in night.

WC verifica:
- ¿AirBnB extranet tiene min_stay configurado a nivel listing? (cambio default 1-7 noches)
- ¿Hay conflicto cuando Beds24 envía min_stay=3 pero AirBnB listing tiene "Min nights = 5"?

Spoiler answer: post-sync, **Beds24 sobrescribe**. Si AirBnB listing tenía Min=5 pre-cutover, after sync=Beds24's value per día (típicamente 2-4 según fecha). **Esto es upgrade — más flexibility para guests**. Pero algunas reservas que antes hubieran sido min=5 noches ahora pueden ser min=2 → revenue change.

WC computes: con tu data histórica, ¿qué % de bookings AirBnB son 2-3 noches vs 5+? Si la mayoría es 2-3, el Min Stay cutover NO te afecta.

### 3.3 — Riesgos identificados

WC enumera con priority:

#### 🔴 BLOCKERS (no proceder hasta resolver)
- Daily Prices vacío en algún room
- Dependencies Combinada (74316) ausente o mal configurada
- Permit ID requerido por AirBnB pero no configurado
- Sync status anormal (e.g. "error" no "disconnected")

#### 🟡 WARNINGS (proceder con cuidado)
- Bookings iCal próximos 90 días que potencialmente se duplicarán al "Import existing"
- Smart Pricing AirBnB extranet activo (Beds24 lo override pero genera confusión)
- Weekly/Monthly discounts AirBnB extranet activos (Beds24 NO los sobrescribe)
- Cancellation policy actual de Alex en AirBnB vs lo que envía Beds24

#### 🟢 OBSERVATIONS (info-only)
- Min Stay cambios por nuevo sync
- Cleaning fee setup
- Currency consistency MXN

### 3.4 — Proposal table

Per setting:

| Setting | Current value | Proposed value | Where to change | Why |
|---|---|---|---|---|
| Channel Multiplier per listing | 1.0 (default) | 1.183 | Beds24 mapping per listing | Compensate 18% host-only fee |
| Sync type per listing | undecided/disconnected | Prices & Availability | Beds24 mapping | Activate 2-way |
| AirBnB Weekly discount | (CC reporta) | OFF | AirBnB extranet | Beds24 NO sobrescribe; estrategia limpia |
| AirBnB Smart Pricing | (CC reporta) | OFF | AirBnB extranet | Incompatible con Beds24 sync |
| AirBnB Min Stay listing-level | (CC reporta) | "Per-night" mode | AirBnB extranet | Permite Beds24 controlar per-day |
| Beds24 Rack Rate per room | (CC reporta) | Verify ≥ Daily Price mean | Beds24 SETUP | Fallback safe for days 366+ |
| Dependencies 74316 | (CC reporta) | Must include 78695 + 74322 | Beds24 DEPENDENCIES | Block doble booking |

### 3.5 — Multiplier decision

WC propone 1.183 uniforme por simplicidad. Pero presenta análisis alternativo:

| Option | Multiplier | RdM neto | Trade-off |
|---|---|---|---|
| Conservador | 1.18 | -0.3% vs pre-cambio | Cliente nota menos cambio |
| Exacto | 1.183 | =100% pre-cambio | Mantén neto perfecto |
| Agresivo | 1.20 | +1.4% vs pre-cambio | Cliente paga más, gano extra |
| Diferenciado | 1.18 RdM, 1.20 Huerta, 1.183 otros | ~Mixed | Por listing strategy |

Alex elige. WC commitea decision a thread/15.

---

## 4. Paso 3 — CC ejecución (15 min)

Con `threads/15` aprobado por Alex, CC ejecuta cambios via API.

### 4.1 — Cambios Beds24 vía API

Per listing, actualizar mapping:

```bash
# Endpoint TBD según docs Beds24 v2 — verificar
curl -sX POST "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "listingId": "<airbnb_listing_id>",
    "roomId": <beds24_roomid>,
    "channelMultiplier": 1.183,
    "syncType": "pricesAndAvailability",
    "cleaningFee": <amount>
  }'
```

Hacer per 4 listings. Capturar response per call.

### 4.2 — Resolver blockers identificados

Si thread/15 listó blockers (e.g. Dependencies 74316 mal configuradas, Rack Rate vacío), CC ajusta antes de Connect.

```bash
# Ejemplo: setear Dependencies de 74316
curl -sX POST "https://api.beds24.com/v2/properties" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 31862,
    "rooms": [
      {
        "id": 74316,
        "dependencies": {
          "blockRooms": [78695, 74322]
        }
      }
    ]
  }'
```

### 4.3 — Output

Commit `threads/16-cc-cutover-execution-log.md`:

- Per listing, response from API (success/error)
- Cambios aplicados (mapping, multiplier, sync type)
- Cleaning fees set
- Dependencies verified

**NO hacer Connect final por API**. Eso es para Alex en panel (ver Paso 4).

---

## 5. Paso 4 — Alex Connect + WC verifica (10-15 min)

### 5.1 Alex en panel Beds24

**SETTINGS → CHANNEL MANAGER → AIRBNB → MAPPING**

Per listing, en orden Huerta → Dos Villas → Morenas → RdM:
1. Ver que mapping muestra los valores que CC seteó (room + multiplier + sync type)
2. Click "Connect" 
3. Wait 1-2 min hasta status "Connected"
4. Si error "Fix Content Errors": ping a WC, paramos

### 5.2 WC verificación final via Make MCP

WC verifica via Make MCP + Beds24 (CC ejecuta si CC todavía está online):

- Channel Manager INBOX en Beds24 limpio (sin errores)
- Calendar Beds24 muestra precios visibles próximos 30 días por room
- Bookings iCal pre-existentes no duplicados (importar bookings deduplica por reference)

### 5.3 Alex en AirBnB extranet

Per listing:
- Calendar próximos 7 días: precios visibles ≈ Daily Price × multiplier
- Min stay próximos 7 días matchea Beds24

### 5.4 Commit final

WC commitea `threads/17-wc-final-verification.md` con:
- ✅ 4 listings connected
- ✅ Multiplier aplicado correctamente
- ✅ Bookings importados sin duplicados
- ✅ Cross-check Beds24 vs AirBnB consistent

---

## 6. Rollback plan (si algo sale mal)

**Si durante Phase 4.1 (Connect) algún listing falla**:
- Beds24 panel → MAPPING per listing → click "Disconnect"
- Listing vuelve a estado pre-Connect (iCal sigue funcionando)
- Investigar root cause antes de reintentar

**Si después de Connect aparecen problemas (duplicate bookings, precios mal expuestos)**:
- Disconnect listing problemático
- AirBnB sigue con iCal sync hasta nuevo intento
- 374482 archivado (no toca)

**Lo que NO se puede rollback**:
- Switch split-fee → host-only fee (irreversible, ya pasó ayer)
- Connection AirBnB account a Beds24 (puedes Disconnect pero AirBnB tracking persiste)

---

## 7. Out of scope (NO tocar)

- 🚫 rdmbot Make scenarios (router, greeter, booker)
- 🚫 worker-bot canary deploy
- 🚫 Make `wh:knowledge-refresh-core` (ya quedó en 74322, no tocar)
- 🚫 GitHub `rdm-greeter-kb` (gate del thread/13 sigue activo)
- 🚫 Booking.com channel manager (paralelo, no afecta)
- 🚫 Pricing agent (sigue como está, recalibrar Sprint 3)
- 🚫 Listing 872479727584938056 (desactivada)
- 🚫 Room 374482 (archive vivo, no tocar)

---

## 8. Timing total

| Phase | Owner | Duración |
|---|---|---|
| 1 — Pre-requisitos verify | CC | 2 min |
| 2 — CC investigación | CC | 45 min |
| 3 — WC análisis + proposal | WC | 30 min |
| 4 — CC ejecución cambios | CC | 15 min |
| 5 — Alex Connect + WC verify | Alex + WC | 10-15 min |
| **TOTAL** | | **~105 min** |

---

## 9. Para CC: prompt inicial recomendado

Si arrancas sesión nueva CC:

```
Hay un cutover AirBnB→Beds24 2-way API pendiente. Lee threads/00-13 del repo público 
discussion (https://github.com/alexanderhorn6720/rincondelmar-bot-discussion) para 
contexto, después thread/14-spec del cutover plan (file: airbnb-cutover-handoff-cc.md 
en discussion repo o que Alex te lo pega).

Token Beds24 que usaste para la migración de bookings 374482→74322 tiene los scopes 
necesarios (channels-airbnb incluido). Si expiró, lee invite code de Make datastore 
85643 key beds24_invite_code y regenera.

Empieza con Paso 2 — CC investigación. Outputs van a threads/14-cc-beds24-current-state-investigation.md
en el discussion repo. Ping en este chat cuando termines.

NO hagas cambios escritura todavía. Solo lectura/investigación.

Alex.
```

---

*Web Claude, 2026-05-12*
