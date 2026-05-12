# Thread 15 — WC análisis + propuesta cutover AirBnB

**Date**: 2026-05-12
**Author**: Web Claude (claude.ai con MCPs)
**To**: Claude Code `[@cc]`, Alexander `[@alex]`
**Re**: Paso 3 del handoff `airbnb-cutover-handoff-cc.md`. Análisis findings thread/14 + propuesta settings concretos para Alex aprobar.

---

## 0. TL;DR

- ✅ Cutover viable, **sin blockers hard**
- ⚠️ 4 warnings menores a resolver pre-Connect (dependency cleanup, permit verify, listings inactivas safety)
- 🎯 Decisión Alex: **Channel Multiplier 1.183 uniforme** + **Min Stay Calc = Arrival** + sync `Prices & Availability` per listing
- 📋 6 settings críticos pre-Connect documentados con valor exacto propuesto
- 🚀 Listo para Paso 4 (CC execution) tras aprobación Alex

---

## 1. Comparativa costos actuales vs AirBnB expose post-cutover

### 1.1 Precios actuales en Beds24 (próximos 30 días, data de CC)

| roomId | maxPeople | Min stay | Rack Rate | Daily Price range observado | Capacidad base (handoff)* | Extra/pax/noche (handoff)* |
|---|---|---|---|---|---|---|
| 78695 RdM | 30 | 2 | $5,500 | $8,500 - $13,500 | 15 | $300 |
| 74322 Morenas | 30 | 2 | $3,500 | $3,500 - $8,500 | 15 | $300 |
| 74316 Combinada | 60 | 2 | $10,000 | $13,500 - $22,000 | 30 | $300 |
| 637063 Huerta | 12 | 2 | $1,500 | $1,500 - $2,000 | 4 | $200 |

*De CONTEXT.md y handoff. CC no pudo verificar via API (endpoint Daily Price Rules devuelve 500). **Confirmar con Alex en panel** Beds24 → SETTINGS → PROPERTIES → ROOMS → cada room → DAILY PRICES → "Up to N people" + "Extra Person Price".

### 1.2 Lo que verá el cliente en AirBnB post-cutover

**Con Channel Multiplier 1.183** (propuesta):

| roomId | Daily Beds24 mín | Daily Beds24 máx | AirBnB cliente ve (× 1.183) | Tu neto (× 0.82 post-fee) |
|---|---|---|---|---|
| 78695 | $8,500 | $13,500 | $10,056 - $15,971 | $8,246 - $13,096 |
| 74322 | $3,500 | $8,500 | $4,141 - $10,056 | $3,395 - $8,246 |
| 74316 | $13,500 | $22,000 | $15,971 - $26,026 | $13,096 - $21,341 |
| 637063 | $1,500 | $2,000 | $1,775 - $2,366 | $1,455 - $1,940 |

**Validación**: tu neto post-cutover (columna 4) ≈ Daily Price Beds24 × 0.97 = ingreso neto pre-cambio. ✅ Multiplier 1.183 mantiene el modelo económico.

### 1.3 Trade-off cliente

Cliente AirBnB pagará +3.7% en promedio vs split-fee pre-cambio (porque antes pagaba precio + 14% comisión guest = $1,140 sobre tu $1,000; ahora paga $1,183 all-in sobre tu $1,000). Diferencia imperceptible para guests.

---

## 2. Min Stay strategy

### 2.1 Hoy vs post-cutover

| Aspecto | Hoy (iCal) | Post-cutover (Prices & Availability) |
|---|---|---|
| Min stay AirBnB | Lo que Alex puso en AirBnB extranet (estático) | Beds24 envía per día |
| Modo evaluación AirBnB | Nativo "as arrival" | Recibe min_stay per día del check-in |
| Beds24 modo evaluación | Verificar — CC no lo extrajo | **Propuesta**: Arrival (per decisión Alex) |
| Reglas anti-orphan Alex | NO visibles en AirBnB | ✅ Sí visibles |

### 2.2 Decisión Alex confirmada

**Min Stay Calculation = Arrival** (per chat con WC). Razones:
- Más simple de entender
- Match con modo nativo AirBnB
- Permite Alex jugar dinámicamente con reglas anti-orphan
- Reglas sábado=4, martes=3 funcionan correctamente

### 2.3 Acción técnica

CC verifica en thread/16 setting actual via:
```bash
curl -sX GET "https://api.beds24.com/v2/properties?id=31862" -H "token: $TOKEN"
```

Busca campo `minStayCalculation` o equivalente. Si valor NO es `arrival`:
```bash
curl -sX POST "https://api.beds24.com/v2/properties" -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{"id": 31862, "minStayCalculation": "arrival"}]'
```

Si ya está en `arrival`, no requiere acción.

Si endpoint Beds24 no soporta el field por API, Alex lo cambia en panel:
**SETTINGS → PROPERTIES → 31862 → SETUP → Minimum Stay Calculation**

### 2.4 Verificación post-cutover

Alex verifica reglas activas pre-Connect:
- Sábado próximos 90 días: ¿min_stay=4 visible?
- Martes próximos 90 días: ¿min_stay=3 visible?
- Default otros días: ¿min_stay=2?

Si gaps (ej. solo configurado próximas 4 semanas), Alex extiende vía Daily Price Rules o Calendar bulk edit antes de Connect.

---

## 3. Riesgos identificados

### 🔴 BLOCKERS

**Ninguno**. Hardware ready.

### 🟡 WARNINGS

#### W1 — Dependency 74316 contiene 374482 obsoleto

CC encontró que Combinada (74316) tiene 3 dependencies:
- `dependentRoomId1: 78695` ✓
- `dependentRoomId2: 374482` ⚠️ obsoleto (archivado, 0 future bookings)
- `dependentRoomId3: 74322` ✓

**Comportamiento actual**: funcionalmente OK porque 374482 siempre está "disponible" (sin bookings). NO genera doble booking.

**Riesgo futuro**: si alguien revive 374482 o mueve bookings ahí, Combinada se desincroniza.

**Propuesta**: limpiar pre-Connect.

CC ejecuta vía API en Paso 4:
```bash
curl -sX POST "https://api.beds24.com/v2/properties" -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{
    "id": 31862,
    "rooms": [{
      "id": 74316,
      "dependentRoomId2": null
    }]
  }]'
```

Si API no acepta null, Alex lo limpia en panel: SETTINGS → PROPERTIES → ROOMS → 74316 → DEPENDENCIES → quitar 374482 de la lista.

**Verificación post-cleanup**:
```bash
curl -sX GET "https://api.beds24.com/v2/properties?id=31862&includeAllRooms=true" \
  -H "token: $TOKEN"
# Buscar room 74316.dependencies.dependentRoomId2 → debe ser null
```

#### W2 — PermitId vacío en propiedad

Acapulco / Coyuca de Benitez no requiere permit municipal a 2026 según mi última búsqueda en mayo. PERO AirBnB API puede exigir el campo aunque municipalidad no lo requiera (algunos checks de policy interna).

**Mitigación**: proceder con Connect. Si AirBnB rechaza con "Fix Content Errors → Missing license/permit", Alex deja `permitId: ""` o usa string "N/A". AirBnB typicamente acepta. Si rechaza, contactar AirBnB support.

**No bloquea**. Solo es trabajo de respaldo si surge.

#### W3 — Listing 872479727584938056 no aparece en API

CC reportó que la listing desactivada de Sophia (Morenas s/ser) NO aparece en `/v2/channels/airbnb/listings`. Hipótesis:
- AirBnB la eliminó completamente (no solo deactivated)
- O hay propagación lenta API tras deactivation
- O el ID del handoff es typo

**Mitigación**: 
- Alex confirma en AirBnB extranet → Listings → ver si listing existe (debería verse si fue solo "paused", no eliminada)
- Si existe pero no aparece API: documentar pero proceder con Connect (las 4 activas son las que importan)
- Si fue eliminada: 0 trabajo, ya pasó

**No bloquea**.

#### W4 — 6 listings inactivas en API (legacy/wedding/room-split antiguo)

CC encontró 6 listings inactivas adicionales:
- 19837998 VillaMorenas alterno
- 31173575 RinconMar_5Habitaciones
- 31173658/670/674 Cuartos individuales
- 31174165 Bodas
- 1656138511899435479 sin nombre

**Riesgo**: durante Connect, posible que AirBnB intente "reactivarlas" si tienen disponibilidad o si Alex accidentalmente las mapea.

**Mitigación**: 
- Mantener `has_availability: false` (CC confirma están así actualmente)
- Alex NO las mapea en panel (Phase 1 mapping solo las 4 activas)
- Si AirBnB las activa unilateralmente, Alex las re-pausa manualmente

**No bloquea**, requiere vigilancia.

### 🟢 OBSERVATIONS

- 29 bookings AirBnB confirmados próximos 90 días — Beds24 debería deduplicar en "Import existing bookings" durante Connect (sin acción extra)
- 4 listings activas matchean handoff ✅
- 74322 calendar populated ✅ (no era blocker)
- Currency MXN, coords precisas ✅
- Min stay 2-4 noches verificado en RdM ✅

---

## 4. Propuesta settings cutover — tabla decisión

| # | Setting | Valor actual | Valor propuesto | Where | Razón | Owner ejecución |
|---|---|---|---|---|---|---|
| 1 | Min Stay Calculation | (verificar) | `arrival` | Beds24 property 31862 SETUP | Decisión Alex, simple y match AirBnB nativo | CC (API) o Alex (panel) |
| 2 | Dependency 74316.dep2 | 374482 (obsoleto) | null | Beds24 room 74316 DEPENDENCIES | Cleanup pre-cutover, evita confusión futura | CC (API) o Alex (panel) |
| 3 | Channel Multiplier per listing | 1.0 (default) | **1.183** | Beds24 CHANNEL MANAGER → AIRBNB → MAPPING per listing | Compensa 18% host-only fee, mantiene neto pre-cambio | CC (API) |
| 4 | Sync Type per listing | `none` | `pricesAndAvailability` | Mismo lugar | Activa 2-way, NO "Everything" (sobreescribe fotos) | Alex (Connect button panel) |
| 5 | Room mapping per listing | (sin mapear) | Per tabla §7 | Mismo lugar | 4 listings activas → 4 roomIds | CC (API setup pre-Connect) |
| 6 | Listings inactivas | has_availability: false | mantener false | Mismo lugar | NO mapear las 6 legacy | Alex (vigilar en Connect panel) |

---

## 5. Channel Multiplier — análisis numérico final

Sobre tu volumen 2025-2026: $4.4M MXN AirBnB.

### Comparativa scenarios

| Multiplier | Tu neto vs pre-cambio | Cliente paga vs pre-cambio | Recomendación |
|---|---|---|---|
| 1.10 | -7.8% (-$343K/año) | -3.5% más barato | Demasiado conservador, pierdes |
| 1.18 | -0.3% (-$13K/año) | +3.5% más caro | Conservador |
| **1.183** | **=100%** ($0 diff) | **+3.7% más caro** | **Recomendado WC** |
| 1.20 | +1.4% (+$62K/año) | +5.3% más caro | Levemente agresivo |
| 1.25 | +5.6% (+$246K/año) | +9.6% más caro | Riesgo conversión baja |

**WC voto: 1.183 uniforme los 4 listings**. Razones:
- Mantén exacto el ingreso neto que tenías pre-cambio
- Cliente nota cambio ínfimo
- Simple administrar (mismo número los 4)
- Si después de 2 sem ves alguna listing con caída de conversión, ajustas individual a 1.18

---

## 6. Plan execution Paso 4 (CC)

### 6.1 Pre-Connect changes (writes via API)

CC ejecuta 3 cambios + verifica:

```bash
# 1. Min Stay Calculation
curl -X POST "https://api.beds24.com/v2/properties" -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{"id": 31862, "minStayCalculation": "arrival"}]'

# 2. Cleanup dependency 74316
curl -X POST "https://api.beds24.com/v2/properties" -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{"id": 31862, "rooms": [{"id": 74316, "dependentRoomId2": null}]}]'

# 3. Per listing: mapping + multiplier + sync (sin Connect)
# Endpoint exacto verificar en Beds24 docs:
# POST /v2/channels/airbnb/listings con body por listing
# Listing 18780853 → roomId 78695, multiplier 1.183, syncCategory "pricesAndAvailability"
# Listing 733868075691217916 → roomId 74322, multiplier 1.183, syncCategory "pricesAndAvailability"
# Listing 18009632 → roomId 74316, multiplier 1.183, syncCategory "pricesAndAvailability"
# Listing 1577678927412395161 → roomId 637063, multiplier 1.183, syncCategory "pricesAndAvailability"
```

### 6.2 Verification post-changes

```bash
# Verifica property
curl -sX GET "https://api.beds24.com/v2/properties?id=31862&includeAllRooms=true" \
  -H "token: $TOKEN" | jq '.data[0].minStayCalculation, .data[0].rooms[] | select(.id == 74316).dependencies'

# Verifica listings
curl -sX GET "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" | jq '.data[] | {airbnbListingId, propertyRoomId, channelMultiplier, syncCategory}'
```

### 6.3 Output thread/16

CC commitea `threads/16-cc-cutover-execution-log.md` con:
- Response API per cambio (success/error)
- Estado verificado de los 6 settings
- Bookings AirBnB confirmados pre-Connect (snapshot 29 bookings, para comparar post-Connect)
- Ready signal para Alex

---

## 7. Mapping final aprobado

| Listing AirBnB | Listing nombre | Map a roomId | Multiplier | Sync type | Connect en panel |
|---|---|---|---|---|---|
| 18780853 | RinconMar_6Habitaciones | 78695 (RdM) | 1.183 | Prices & Availability | Alex paso 5 |
| 733868075691217916 | VillaMorenas · 30 ppl CHEF | 74322 (Morenas) | 1.183 | Prices & Availability | Alex paso 5 |
| 18009632 | Dos villas 58 ppl | 74316 (Combinada) | 1.183 | Prices & Availability | Alex paso 5 |
| 1577678927412395161 | Huerta pie de playa | 637063 (Huerta) | 1.183 | Prices & Availability | Alex paso 5 |

**Orden Connect (Alex panel, paso 5)**: Huerta → Dos Villas → Morenas → RdM (de menor a mayor volumen, para detectar errores tempranos sin impacto).

---

## 8. Validación Alex en panel (cosas que CC no puede ver)

Antes de paso 5 (Connect), Alex verifica visualmente:

### Beds24 panel (5 min)

1. **PRICES → DAILY PRICE RULES → cada room**: verificar `Up to N people` y `Extra Person Price` matchean handoff:
   - 78695: Up to 15, $300/extra
   - 74322: Up to 15, $300/extra
   - 74316: Up to 30, $300/extra
   - 637063: Up to 4, $200/extra
2. **Calendar próximos 90 días por room**: confirmar reglas anti-orphan visibles (sábado=4, martes=3)
3. **CHANNEL MANAGER → AIRBNB → MAPPING**: confirmar las 4 listings con mapping + multiplier que CC seteó vía API

### AirBnB extranet (5 min)

4. **Per listing → Pricing & Availability → Discounts**: verificar Weekly/Monthly discounts (desactivar si están ON, Beds24 NO los sobrescribe)
5. **Per listing → Smart Pricing**: confirmar OFF (incompatible con sync)
6. **Per listing → Reservation type**: confirmar Instant Book ON (API requiere)
7. **Per listing → Cancellation policy**: confirmar es la que quieres (no se cambia con sync, queda como esté)

---

## 9. Comparativa pre-cutover vs post-cutover (resumen ejecutivo)

| Aspecto | Pre-cutover (iCal) | Post-cutover (2-way API + multiplier 1.183) |
|---|---|---|
| Precio cliente AirBnB ve | Tu precio + 14% commission (split) | Tu precio × 1.183 (all-in) |
| Comisión AirBnB cobra | 3% al host + 14% al guest | 16% + IVA = ~18% al host |
| Tu neto en banco | Precio × 0.97 | Precio × 0.97 (mantén igual) |
| Deducción comisión anual | $132K (3% sobre $4.4M) | $792K (18% sobre $4.4M) |
| IVA acreditable | $21K/año | $127K/año |
| Min stay sync | NO (AirBnB usa lo que Alex puso) | SÍ per día (Beds24 envía) |
| Calendar sync | iCal 2h delay, posible doble booking | Real-time (≤2 min) |
| Risk doble booking | Medio-alto | Bajo (con Dependencies OK) |
| Reglas anti-orphan visibles AirBnB | NO | SÍ |

🟢 **Cutover es ganancia neta** en operación + visibility, con ingreso neto preservado y deducciones aumentadas.

---

## 10. Next steps

1. **Alex review thread/15** + aprobar:
   - Channel Multiplier 1.183 ✅/⚠️ ajustar
   - Min Stay Calculation = arrival ✅/⚠️
   - Cleanup 374482 dependency ✅/⚠️
2. **CC procede paso 4** una vez Alex confirme — execution writes via API → thread/16
3. **Alex paso 5** Connect en panel orden Huerta → Dos Villas → Morenas → RdM (~15 min)
4. **WC verify final** vía Make MCP + lectura via CC → thread/17

ETA restante: ~45 min con Alex disponible.

---

## 11. Decisión pendiente para Alex (responder en chat o thread/15b)

Pegar respuesta del estilo:

```
@wc — apruebo thread/15.
Multiplier: 1.183 uniforme ✅
Min Stay Calc: arrival ✅
Cleanup dep 374482: GO ✅
Otros: ningún ajuste

CC procede paso 4.
```

O si quieres ajustes:

```
@wc — ajustes:
Multiplier: 1.20 en Huerta, 1.183 los otros 3 (motivo: ...)
Min Stay Calc: ya confirmé está en arrival panel
Cleanup: hago en panel directamente
Resto OK.
```

---

*FIN thread/15. Standby por aprobación Alex. CC pausado hasta señal.*

— Web Claude, 2026-05-12
