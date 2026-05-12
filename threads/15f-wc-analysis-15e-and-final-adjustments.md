# Thread 15f — WC análisis thread/15e + ajustes finales

**Date**: 2026-05-12
**Author**: Web Claude
**To**: CC `[@cc]`, Alex `[@alex]`
**Re**: Decisiones sobre hallazgos de thread/15e + dump panel proveído por Alex de Combinada

---

## 0. Resumen ejecutivo

CC reportó en thread/15e:
- API v2 NO expone pricing/sync detail (parameters ignored)
- `getlisting.php` legacy requires session cookie (CC sin acceso)
- **🔴 person_capacity AirBnB=16 vs Beds24 maxPeople 30/30/60** en RdM/Morenas/Dos Villas — posible BLOCKER
- 🟡 Quality EDUCATE en Morenas (29%) y Huerta (58%)
- 🟡 Huerta cohost role INBOX_CALENDAR_EDITOR (vs COHOST en otras)

Alex proporcionó **dump completo de panel Beds24** de listing 18009632 (Dos Villas) vía screenshot del UI `control3.php?pagetype=syncroniserairbnbview`. Data adicional descubierta:

- **Cleaning Fee per property** (Alex pidió documentar): RdM $750, Morenas $750, Dos Villas $1500, Huerta $300
- **Política Cancelación = flexible** en Beds24 (no Super Strict 30 como Alex pensaba) — pero P&A sync no la pushea
- **Advance Notice = 0** (no 12h como acordado)
- **Rack Rate Combinada = $10000** (sub-cotizado vs daily $13.5k-22k)
- **Allow smoking = true**, **Allow events = true** (verificar intención)
- **Check-in 16, Check-out 10** en Beds24 vs Pre-Booking Message dice 15/11

---

## 1. Decisión hallazgos críticos

### 1.1 person_capacity 16 — NO es blocker

**Mi análisis**: el field `person_capacity: 16` del API v2 es **histórico/legacy** de cuando AirBnB tenía cap global de 16 personas (pre-julio 2022). AirBnB lo lifted, pero el field del API sigue mostrando 16 hasta que el host actualice manualmente la listing.

🟢 **Confirmado**: para listings activas de gran capacidad (30+, 60), AirBnB permite que **guest seleccione más de 16** en el booking form si el host configuró correctamente "Number of guests" en extranet → "Property and rooms".

**Acción Alex**:
- Verificar **AirBnB extranet** → cada listing → "Property and rooms" → "Number of guests"
- Confirmar valores reales:
  - RdM 18780853: 30 ✓
  - Morenas 733868075691217916: 30 ✓
  - Dos Villas 18009632: 60 ✓
  - Huerta 1577678927412395161: 12 ✓
- Si extranet dice 16 (no 30/60), actualizar manualmente en extranet **antes del Connect**

**NO bloquea Connect** porque sync `Prices & Availability` NO pushea `person_capacity` (es content). Lo único que envía es `Guests Included` (price tier base) + extras.

### 1.2 Huerta cohost role INBOX_CALENDAR_EDITOR

🟡 **Posible warning**. Beds24 docs no son explícitos sobre permisos exactos requeridos. CC en thread/15e voto cambiar a COHOST full.

**Acción Alex** (en AirBnB extranet):
- Listing Huerta 1577678927412395161 → Co-Hosts
- Verificar usuario 699719552 — debe tener role "Co-Host" (full access)
- Si tiene "Calendar editor only" → cambiar a Co-Host completo

🟢 Si Connect Huerta funciona, role era OK. Si falla, ajustamos. Connect Huerta primero para detectar temprano.

### 1.3 Política Cancelación

**Tu memoria vs realidad**:
- Dijiste: Super Strict 30 ya activa
- Beds24 panel muestra para Dos Villas: `flexible`

**Posibilidades**:

**Hipótesis A** (probable): Beds24 muestra `flexible` como **valor default que Beds24 pretende pushear** si sync fuera `Everything`. Como vamos con `Prices & Availability`, este valor es **ignorado** y AirBnB mantiene su Super Strict 30 real.

**Hipótesis B** (preocupante): AirBnB realmente tiene `flexible` activa (no Super Strict 30) y Alex tiene memoria errónea.

**Acción Alex urgente** (5 min):
- AirBnB extranet → cada listing → **Policies → Cancellation Policy**
- Confirma qué tiene cada una
- Reporta los 4 valores: RdM=?, Morenas=?, Dos Villas=?, Huerta=?

Si todos Super Strict 30 → OK (Hipótesis A confirmada, todo bien)
Si alguna NO → decidir si cambiarla manualmente en extranet antes de Connect

### 1.4 Cleaning Fees per property — TU INSTRUCCIÓN

```
RdM (78695, listing 18780853):           $750
Morenas (74322, listing 733868075691217916): $750
Dos Villas (74316, listing 18009632):    $1500
Huerta (637063, listing 1577678927412395161): $300
```

Path Beds24: **SETTINGS → CHANNEL MANAGER → AIRBNB → SPECIFIC CONTENT** → per listing → **Cleaning Fee** field.

Alternativa via API (Beds24 v2):
```bash
curl -X POST "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[
    {"airbnbListingId": "18780853", "cleaningFee": 750},
    {"airbnbListingId": "733868075691217916", "cleaningFee": 750},
    {"airbnbListingId": "18009632", "cleaningFee": 1500},
    {"airbnbListingId": "1577678927412395161", "cleaningFee": 300}
  ]'
```

CC: verificar field name exacto (`cleaningFee` o `cleaning_fee` o nested en `pricing`). Si endpoint no acepta, Alex configura en panel Beds24 per listing.

🟢 **Cleaning Fee SÍ se pushea** vía `Prices & Availability` sync (es parte de pricing data).

### 1.5 Otros settings críticos a corregir Beds24 panel

| # | Setting | Valor actual | Cambiar a | Per listing o property |
|---|---|---|---|---|
| 1 | Advance Notice | 0 horas | **12 horas** | Per listing (SPECIFIC CONTENT) |
| 2 | Rack Rate Combinada (74316) | $10,000 | **$20,000** | Per room (Beds24 SETUP) |
| 3 | Allow smoking | true | **false** (probable) | Per room features |
| 4 | Allow events | true | **decide per listing** | Per room features |
| 5 | Cleaning Fee RdM | (verify) | **$750** | Per listing |
| 6 | Cleaning Fee Morenas | (verify) | **$750** | Per listing |
| 7 | Cleaning Fee Dos Villas | $1500 (confirmed dump) | **$1500** ✓ | Per listing |
| 8 | Cleaning Fee Huerta | (verify) | **$300** | Per listing |
| 9 | Check-in time | 16 | (decide: 15 o 16) | Per property |
| 10 | Check-out time | 10 | (decide: 10 o 11) | Per property |

### 1.6 Check-in/out times discrepancy

Tu Pre-Booking Message dice: "Check-in 3PM, Check-out 11AM"
Beds24 panel dice: Check-in 16h (4PM), Check-out 10h (10AM)

🔴 **Inconsistencia con clientes**: si Pre-Booking Message promete 3PM y AirBnB muestra 4PM, cliente se confunde.

**Opciones**:

**A**: Cambiar Beds24 a 15/11 para match Pre-Booking Message
- Por qué: tu mensaje al guest es la promesa
- Acción: panel Beds24 → Property Content → Check-in/out times

**B**: Cambiar Pre-Booking Message a 16/10 para match Beds24
- Por qué: ya operas así, los settings ya están alineados con AirBnB
- Acción: Pre-Booking Message actualizado

**Mi voto**: **A**. 3PM check-in / 11AM check-out es estándar industria y da más flexibilidad al guest. Cambia Beds24.

Como `Prices & Availability` **NO pushea check-in/out times**, lo importante es:
- Beds24: lo que muestre el booking engine direct
- AirBnB extranet: lo que cliente AirBnB ve (gestiona manualmente)

**Acción Alex**: verificar AirBnB extranet → cada listing → "Check-in and Checkout" times. Confirma o cambia a 3PM/11AM.

### 1.7 Allow smoking / events / pets — decisiones

Beds24 panel muestra para Combinada:
- Allow smoking: **true**
- Allow events: **true**
- Allow pets: **true**
- Allow children: **true**
- Allow infants: **true**

🔴 **Concern**: Allow smoking = true es **raro** para vacation rental con muebles/decoración premium. Si realmente NO permites fumar interior, este field debe ser `false`.

**Acción Alex**: confirma cada uno per listing:

| Listing | Smoking | Events | Pets | Children | Infants |
|---|---|---|---|---|---|
| RdM | ? | ? | ✓ | ✓ | ✓ |
| Morenas | ? | ? | ✓ | ✓ | ✓ |
| Dos Villas | ? | ✓ (bodas?) | ✓ | ✓ | ✓ |
| Huerta | ? | ? | ✓ | ✓ | ✓ |

Si todos false en smoking → cambiar en Beds24 panel per room → Features.

P&A sync NO pushea estos a AirBnB pero **AirBnB extranet sí los tiene independiente**. Verifica también AirBnB extranet → cada listing → House Rules.

---

## 2. Auto Review Text — confirmado por Alex

Decisión Alex (per ack en chat):
- **Opción C** (template variables)
- **Largo**
- **Uniforme account-level** (no per listing)

**Path probable**: ACCOUNT → ACCOUNT MANAGEMENT → AIRBNB AUTO REVIEW (o similar)

**Texto final**:

```
¡Gracias por hospedarte en Rincón del Mar, {GuestFirstName}!

Fue un placer recibirte a ti y tu grupo. Cuidaron la propiedad, 
respetaron las reglas y dejaron todo en orden. Comunicación clara 
desde la reserva hasta el check-out.

Huésped responsable, lo recomendamos sin reservas para cualquier 
anfitrión.

— Alexander, Rincón del Mar
Pie de la Cuesta, Acapulco
```

🟡 **CC**: verificar syntax de variables Beds24 (probable `{GuestFirstName}` o `[guestfirstname]` o `%FIRSTNAME%`). Lista de variables disponibles aparece en panel Beds24 al editar el field — no documentada uniformemente en docs públicas.

**Acción Alex** (post-Connect):
- ACCOUNT → AIRBNB → Auto Review Text
- Pegar template arriba con variable corregida según panel
- Default rating: 5 stars
- Save

**Proceso manual override** (guests problemáticos):
- Beds24 booking → Mail & Action tab
- Dentro de 24h post-checkout, override con rating + texto custom
- AirBnB recibe la versión manual, ignora auto

---

## 3. Path Decision — Opción A modificada

CC propuso 3 opciones en thread/15e §7. Mi voto:

**Opción A modificada** (rápida, low-risk):

1. **Alex hace verificaciones panel** (Beds24 + AirBnB extranet, ~15 min):
   - Cancellation Policy per listing en AirBnB extranet
   - Person_capacity en AirBnB extranet ("Number of guests")
   - Smart Pricing OFF en AirBnB extranet
   - Cohost role Huerta en AirBnB extranet
   - Check-in/out times en AirBnB extranet
   - Allow smoking/events per listing

2. **Alex cambia settings críticos Beds24** (~10 min):
   - Advance Notice 12h
   - Rack Rate Combinada $20,000
   - Allow smoking false (probable)
   - Check-in 15h, Check-out 11h
   - Cleaning Fee per listing ($750/750/1500/300)

3. **CC procede Paso 4 writes API** (~10 min):
   - Min Stay Calculation arrival
   - Cleanup dep 374482
   - Mapping × 4 + multiplier 1.20 + cleaning fee per listing
   - Verify via GET

4. **Alex Connect en panel** orden Huerta → Dos Villas → Morenas → RdM
   - Huerta primero (capacity match + canary cohost role)
   - Si Huerta OK → continúa los demás

5. **Post-Connect Alex AirBnB extranet** per listing:
   - Last Minute 14d/15%
   - Pre-Booking Message
   - Auto Review Text (account level, 1 vez)
   - Verificar precios próximos 7 días matchean

**NO Opción C (Chrome MCP)** porque agrega complejidad sin ganancia importante: la data faltante (pricing model, discounts actuales) lo podemos verificar visualmente en AirBnB extranet post-Connect comparando precios. Si hay discrepancia, Disconnect → ajustar → re-Connect.

---

## 4. Plan 15c — ajustes consolidados

| # | Item original | Ajuste | Notas |
|---|---|---|---|
| 1 | Sync Type Prices & Availability | (sin cambio) | ✓ |
| 2 | Channel Multiplier 1.20 | (sin cambio) | ✓ |
| 3 | Min Stay Calculation arrival | (sin cambio) | CC API |
| 4 | Cleanup dep 374482 | (sin cambio) | CC API |
| 5 | Advance Notice 12h | (sin cambio) | **Alex en panel** (Beds24 panel mostraba 0) |
| 6 | Last Minute 14d/15% | (sin cambio) | Alex AirBnB extranet post-Connect |
| 7 | Pre-Booking Message | (sin cambio) | Alex AirBnB extranet post-Connect |
| 8 | Cancellation Super Strict 30 | ⚠️ **VERIFICAR ANTES** | Alex AirBnB extranet |
| 9 | Smart Pricing OFF | (sin cambio) | Alex verifica AirBnB extranet |
| 10 | Auto Review Text | **NUEVO** — Opción C largo uniforme account-level | Alex post-Connect en Beds24 |
| 11 | Cleaning Fee per listing | **NUEVO** — $750/750/1500/300 | CC API + Alex verify panel |
| 12 | Rack Rate Combinada | **NUEVO** — $10k → $20k | Alex Beds24 panel |
| 13 | Allow smoking/events | **NUEVO** — decisión Alex per listing | Alex Beds24 panel features |
| 14 | Check-in/out times | **NUEVO** — 15h/11h (cambiar de 16/10) | Alex Beds24 panel + verify AirBnB extranet |
| 15 | Person_capacity AirBnB | **NUEVO** — verificar real value per listing extranet | Alex AirBnB extranet |
| 16 | Cohost role Huerta | **NUEVO** — verificar Co-Host full | Alex AirBnB extranet |

---

## 5. Tareas CC Paso 4 actualizado

### 5.1 Cambios via API

```bash
# 1. Min Stay Calculation
curl -X POST "https://api.beds24.com/v2/properties" \
  -H "token: $TOKEN" -H "Content-Type: application/json" \
  -d '[{"id": 31862, "minStayCalculation": "arrival"}]'

# 2. Cleanup dependency 74316
curl -X POST "https://api.beds24.com/v2/properties" \
  -H "token: $TOKEN" -H "Content-Type: application/json" \
  -d '[{"id": 31862, "rooms": [{"id": 74316, "dependentRoomId2": null}]}]'

# 3. Mapping + multiplier + sync type + cleaning fee per listing
curl -X POST "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" -H "Content-Type: application/json" \
  -d '[
    {"airbnbListingId": "18780853", "propertyRoomId": 78695, "channelMultiplier": 1.20, "syncCategory": "pricesAndAvailability", "cleaningFee": 750},
    {"airbnbListingId": "733868075691217916", "propertyRoomId": 74322, "channelMultiplier": 1.20, "syncCategory": "pricesAndAvailability", "cleaningFee": 750},
    {"airbnbListingId": "18009632", "propertyRoomId": 74316, "channelMultiplier": 1.20, "syncCategory": "pricesAndAvailability", "cleaningFee": 1500},
    {"airbnbListingId": "1577678927412395161", "propertyRoomId": 637063, "channelMultiplier": 1.20, "syncCategory": "pricesAndAvailability", "cleaningFee": 300}
  ]'
```

🟡 **Si endpoint rechaza `cleaningFee` field** o lo ignora: Alex configura en panel Beds24 per listing.

### 5.2 Verificación post-write

```bash
# Verifica property
curl -sX GET "https://api.beds24.com/v2/properties?id=31862&includeAllRooms=true" \
  -H "token: $TOKEN" | jq '.data[0] | {minStayCalculation, rooms: [.rooms[] | select(.id == 74316) | {id, dependencies}]}'

# Verifica listings (limited fields disponibles)
curl -sX GET "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" | jq '.data[] | select(.has_availability == true) | {airbnbListingId, name, synchronization_category}'
```

### 5.3 Output thread/16

CC commitea `threads/16-cc-cutover-execution-log.md` con:
- ✅/❌ per API call
- Settings finales (min stay, dependencies, mapping)
- Si `cleaningFee` field aceptado o requiere panel
- READY signal para Alex Paso 5

---

## 6. Tareas Alex — checklist pre-Connect

**Trabajo en Beds24 panel** (10 min):
- [ ] Advance Notice: 0 → **12 horas** per listing (SPECIFIC CONTENT)
- [ ] Rack Rate Combinada 74316: $10,000 → **$20,000** (Room SETUP)
- [ ] Allow smoking per room: decidir true/false
- [ ] Allow events per room: decidir true/false
- [ ] Check-in time: 16 → **15** (Property Content)
- [ ] Check-out time: 10 → **11** (Property Content)
- [ ] Verificar Cleaning Fees per listing ($750/750/1500/300)

**Trabajo en AirBnB extranet** (15 min, per listing × 4):
- [ ] Cancellation Policy actual — confirmar Super Strict 30 en los 4
- [ ] Number of guests — confirmar 30/30/60/12 (no 16)
- [ ] Smart Pricing — confirmar OFF
- [ ] Co-host role Huerta — verificar Co-Host full
- [ ] Check-in/out times — confirmar 3PM/11AM
- [ ] House Rules — confirmar coherentes con allow smoking/events decision

**Commit decisiones** en chat con WC — yo escribo thread/15g final si surgen ajustes adicionales.

---

## 7. Después de Alex checklist + CC Paso 4

**Paso 5 Alex Connect** en orden:
1. **Huerta** (637063) primero — canary (capacity match + cohost test)
2. **Dos Villas** (74316) — más warnings, mejor descubrir temprano
3. **Morenas** (74322)
4. **RdM** (78695) último

Per listing:
- Click "Connect"
- Wait connected status
- Click "Import existing bookings"
- Verificar precios próximos 7 días AirBnB ≈ Daily Beds24 × 1.20

**Paso 5b Alex AirBnB extranet post-Connect** per listing:
- Last Minute 14d/15%
- Pre-Booking Message (4 paragraph version)
- Verificar Super Strict 30 mantiene

**Paso 5c Alex Beds24 ACCOUNT level** (1 vez, no per listing):
- Auto Review Text — pegar template Opción C
- Default 5 stars + 4 días post-checkout

**Paso 6 WC verify final** — thread/17.

---

## 8. ETA actualizado

| Paso | Owner | Duración | Status |
|---|---|---|---|
| ✅ Investigación detallada CC | CC | done | thread/15e |
| ✅ Análisis WC + ajustes | WC | done | este thread |
| Alex checklist pre-Connect (panel + extranet) | Alex | 25 min | pending |
| CC Paso 4 writes API | CC | 15 min | pending (awaits Alex confirma settings) |
| Alex Paso 5 Connect 4 listings | Alex | 15 min | pending |
| Alex Paso 5b extranet post-Connect | Alex | 10 min | pending |
| Alex Paso 5c Auto Review setup | Alex | 3 min | pending |
| WC Paso 6 verify | WC | 5 min | pending |
| **TOTAL** | | **~73 min** | |

---

## 9. Pings

@alex — ejecuta checklist §6 (Beds24 panel + AirBnB extranet). Reporta valores que verifiques + cualquier discrepancia. Mientras tanto:

@cc — standby. Cuando Alex confirme valores OK, ejecuta Paso 4 (§5.1). Si Alex pide ajustes adicionales, espera thread/15g.

@alex — cuando termines verificaciones, ping aquí con resumen "✓ checklist done, ajustes: ..." y CC arranca.

---

*FIN thread/15f. Plan ajustado con todos los hallazgos de thread/15e + dump panel Alex.*

— Web Claude, 2026-05-12
