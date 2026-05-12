# Thread 15c — Plan final aprobado por Alex

**Date**: 2026-05-12
**Author**: Web Claude
**To**: Claude Code `[@cc]`, Alex `[@alex]`
**Re**: Settings finales confirmados. CC procede Paso 4.

---

## ✅ Decisiones finales Alex (cierra el plan)

| # | Setting | Valor final | Lugar configuración | Owner |
|---|---|---|---|---|
| 1 | Sync Type per listing | **Prices & Availability** | Beds24 mapping | CC via API |
| 2 | Channel Multiplier | **1.20 uniforme** los 4 listings | Beds24 mapping | CC via API |
| 3 | Min Stay Calculation | **Arrival** | Beds24 property 31862 | CC via API |
| 4 | Cleanup dependency 74316.dep2 | **null** (quitar 374482) | Beds24 room 74316 | CC via API |
| 5 | Advance Notice | **12 horas** | Beds24 SPECIFIC CONTENT → BOOKING RULES | Alex panel |
| 6 | Early Bird Discount | **0%** (no configurar) | n/a | n/a |
| 7 | Last Minute Discount | **14 días / 15%** | **AirBnB extranet** per listing | Alex panel post-Connect |
| 8 | Weekly/Monthly Discount | **0%** | n/a | n/a |
| 9 | Pre-Booking Message | Texto abajo §3 | **AirBnB extranet** per listing | Alex panel post-Connect |
| 10 | Cancellation Policy | **Super Strict 30** | AirBnB extranet (ya activa) | Alex (sin cambios) |
| 11 | Smart Pricing | OFF | AirBnB extranet | Alex panel verifica |
| 12 | House Rules | Existentes | AirBnB extranet | Alex (sin cambios) |
| 13 | Daily Price Rules (POSITIVE/NEGATIVE) | Por verificar | Beds24 panel | Alex (post-cutover, no bloquea) |

---

## 1. Justificación de elecciones

### Sync Type: Prices & Availability

Comparativa lo que envía:

| Setting | Prices & Avail | Limited | Everything |
|---|---|---|---|
| Daily prices, min/max stay, advance notice | ✅ | ✅ | ✅ |
| Channel multiplier | ✅ | ✅ | ✅ |
| Last Minute / Early Bird / Weekly / Monthly | ❌ | ✅ | ✅ |
| Pre-Booking Message | ❌ | ❌ | ✅ |
| House Rules | ❌ | ❌ | ✅ |
| Cancellation Policy | ❌ | ❌ | ✅ |
| Fotos/descripciones | ❌ | ❌ | ✅ |

**Razón Alex elige Prices & Availability**: 0 riesgo de override de contenido AirBnB ya optimizado. Super Strict 30 cancellation policy intocable.

**Trade-off aceptado**: Last Minute Discount + Pre-Booking Message se configuran manualmente en AirBnB extranet (4 listings × ~3 min cada = 12 min trabajo post-Connect).

### Channel Multiplier: 1.20 (no 1.183)

Sobre $4.4M MXN volumen anual AirBnB:
- 1.183 mantenía neto exacto pre-cambio
- 1.20 gana +1.4% margen extra (~$62K MXN/año)
- Cliente paga +5.3% vs split-fee pre-cambio (vs +3.7% con 1.183)

Alex elige el extra margen.

### Min Stay Calculation: Arrival

Razones Alex:
- Match modo nativo AirBnB
- Permite jugar dinámicamente con reglas anti-orphan
- Más simple de entender vs Stay Through

Funciona con reglas sábado=4 y martes=3 actuales.

### Super Strict 30 cancellation

Ya activa en AirBnB extranet (Alex tiene acceso premium/legacy). NO se cambia a Firm.

🟡 **Trade-off aceptado**: AirBnB penaliza visibility con Super Strict pero Alex prioriza protección contra cancelaciones. Decisión comercial Alex.

---

## 2. Last Minute 14 días / 15%

🟢 **Justificación numérica**:
- 20% de bookings AirBnB históricos entran en últimos 14 días
- 15% discount cubre threshold AirBnB para "Last Minute promotion" merchandising (>10%)
- Costo: ~3% revenue total
- Beneficio: mejor visibility + fill rate huecos cortos

**Path AirBnB extranet** (post-Connect):
- Listings → cada listing → Pricing & Availability → Discounts → Last-minute discount
- Set: 14 días + 15%
- Repetir 4 veces (1 por listing)

---

## 3. Pre-Booking Message (final)

Aplicar a los 4 listings (uniforme), via AirBnB extranet post-Connect:

```
¡Hola! Bienvenido a Rincón del Mar, Pie de la Cuesta, Acapulco.

Por favor confirma que LEÍSTE las reglas y descripción del anuncio
antes de proceder, en especial:

1. CAPACIDAD Y CARGO EXTRA
   Cada persona arriba de 16 cuesta $300 MXN/noche.
   AirBnB lo cobra automático según número de huéspedes en tu reserva.
   Si llegan más personas que las reservadas, debes solicitar
   modificación en AirBnB para pagar el extra.

2. HORARIOS SIN FLEXIBILIDAD
   Check-in: 3:00 PM (no antes)
   Check-out: 11:00 AM (no después)
   Necesitamos este window para limpieza profunda entre huéspedes.

3. REGLAS DEL ANUNCIO
   Sin fiestas. Mascotas según la propiedad. Otras reglas en
   "House Rules" — léelas con cuidado antes de confirmar.

Si algún punto NO te queda claro, escríbeme ANTES de reservar.
Después de confirmar no podemos hacer ajustes a horarios o reglas.

Gracias,
Alexander · Rincón del Mar
```

**Path AirBnB extranet** (post-Connect):
- Listings → cada listing → Booking settings → Instant Book → Pre-booking message
- Pegar texto arriba
- Repetir 4 veces

---

## 4. Tareas CC — Paso 4 ejecución

### 4.1 Cambios Beds24 vía API (writes)

CC ejecuta los 3 cambios en orden:

#### Cambio 1: Min Stay Calculation
```bash
curl -X POST "https://api.beds24.com/v2/properties" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{"id": 31862, "minStayCalculation": "arrival"}]'
```

#### Cambio 2: Cleanup dependency 74316
```bash
curl -X POST "https://api.beds24.com/v2/properties" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{"id": 31862, "rooms": [{"id": 74316, "dependentRoomId2": null}]}]'
```

Si API rechaza `null`, intentar:
- `"dependentRoomId2": 0`
- O omitir el field y enviar solo `dependentRoomId1` + `dependentRoomId3`

Si ninguno funciona, reportar y Alex limpia en panel.

#### Cambio 3: Mapping per listing (sin Connect)

```bash
# Listing 18780853 (RdM) → 78695
curl -X POST "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{
    "airbnbListingId": "18780853",
    "propertyRoomId": 78695,
    "channelMultiplier": 1.20,
    "syncCategory": "pricesAndAvailability"
  }]'

# Listing 733868075691217916 (Morenas) → 74322
curl -X POST "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{
    "airbnbListingId": "733868075691217916",
    "propertyRoomId": 74322,
    "channelMultiplier": 1.20,
    "syncCategory": "pricesAndAvailability"
  }]'

# Listing 18009632 (Dos Villas) → 74316
curl -X POST "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{
    "airbnbListingId": "18009632",
    "propertyRoomId": 74316,
    "channelMultiplier": 1.20,
    "syncCategory": "pricesAndAvailability"
  }]'

# Listing 1577678927412395161 (Huerta) → 637063
curl -X POST "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '[{
    "airbnbListingId": "1577678927412395161",
    "propertyRoomId": 637063,
    "channelMultiplier": 1.20,
    "syncCategory": "pricesAndAvailability"
  }]'
```

🔴 **CRÍTICO**: estos 4 calls configuran mapping + multiplier pero **NO activan el Connect**. El Connect lo hace Alex en panel (Paso 5).

Endpoint exacto a verificar en Beds24 docs si no es `POST /v2/channels/airbnb/listings`. Si no, usar GET first para ver schema, o reportar.

### 4.2 Verificación post-changes

```bash
# Verifica property
curl -sX GET "https://api.beds24.com/v2/properties?id=31862&includeAllRooms=true" \
  -H "token: $TOKEN" | jq '.data[0] | {minStayCalculation, rooms: [.rooms[] | select(.id == 74316) | {id, dependencies}]}'

# Esperado:
# {
#   "minStayCalculation": "arrival",
#   "rooms": [{"id": 74316, "dependencies": {"dependentRoomId1": 78695, "dependentRoomId2": null, "dependentRoomId3": 74322}}]
# }

# Verifica listings
curl -sX GET "https://api.beds24.com/v2/channels/airbnb/listings" \
  -H "token: $TOKEN" | jq '.data[] | select(.has_availability == true) | {airbnbListingId, propertyRoomId, channelMultiplier, syncCategory}'

# Esperado per listing:
# {"airbnbListingId": "18780853", "propertyRoomId": 78695, "channelMultiplier": 1.20, "syncCategory": "pricesAndAvailability"}
# (similar para los otros 3)
```

### 4.3 Output thread/16

CC commitea `threads/16-cc-cutover-execution-log.md` con:
- ✅/❌ per cambio (response API)
- Settings finales verificados
- Snapshot bookings AirBnB confirmed (~29 próximos 90d, para comparar post-Connect)
- Cualquier error o adjustment necesario
- READY signal para Alex Paso 5

---

## 5. Tareas Alex — Paso 5 (Connect en panel)

### 5.1 Pre-Connect (verificación final, ~3 min)

En **Beds24 panel**:
- SETTINGS → CHANNEL MANAGER → AIRBNB → MAPPING
- Confirmar visualmente las 4 listings tienen:
  - Room mapeado (78695, 74322, 74316, 637063)
  - Multiplier 1.20
  - Sync type "Prices & Availability"

Si algún listing muestra error o valores incorrectos: PARAR. Ping CC, ajustar antes de Connect.

### 5.2 Connect (~10 min)

Orden recomendado (low to high volume, atrapamos errores temprano):

1. **Huerta (637063)** — bajo volumen, prueba primera
   - Click "Connect"
   - Wait 1-2 min hasta status "Connected"
   - Click "Import existing bookings"
   - Verificar en Beds24 BOOKINGS que aparecen sin duplicados

2. **Dos Villas (74316)** — bajo volumen, prueba combinada
   - Mismo proceso
   - 🔴 Atención especial: si error en Combinada por Dependencies, ajustar primero

3. **Morenas (74322)** — volumen medio-alto
   - Mismo proceso

4. **RdM (78695)** — alto volumen, último
   - Mismo proceso

🔴 **Si error "Fix Content Errors"** en algún Connect:
- Click para ver detalles
- Comunes: permitId vacío, address mismatch, pricing too low
- Reportar y ajustar antes de continuar con siguientes listings

### 5.3 Post-Connect verificación AirBnB extranet (~10 min)

Per listing en AirBnB extranet:

1. **Calendar próximos 7 días**: ¿precio visible ≈ Daily Price × 1.20?
2. **Smart Pricing**: confirmar OFF
3. **Last Minute Discount**: configurar 14d / 15%
4. **Pre-Booking Message**: pegar texto §3
5. **Cancellation Policy**: confirmar Super Strict 30 sigue activa (no se sobreescribió)

### 5.4 Test booking dummy (opcional, ~5 min)

En AirBnB:
- Buscar tu propio listing
- Intentar reserva en fecha lejana (180+ días)
- Confirmar precio cliente AirBnB ve = Daily Price × 1.20
- Cancelar inmediatamente (24h grace period, 0 costo)
- Verificar booking aparece y luego cancela en Beds24

---

## 6. Post-cutover — WC verifica (Paso 6)

WC vía Make MCP + última lectura via CC:

- Beds24 INBOX: 0 errores activos
- Bookings AirBnB próximos 30 días: cuenta matchea pre-Connect (no duplicados)
- Calendar Beds24 + AirBnB cross-consistent

WC commitea `threads/17-wc-final-verification.md` con:
- ✅ 4 listings connected
- ✅ Multiplier 1.20 aplicado
- ✅ Sync activo
- ✅ Bookings importados sin duplicados
- ✅ Reglas anti-orphan visibles en AirBnB

---

## 7. Rollback si algo sale mal

### Per listing
Beds24 panel → MAPPING → Disconnect → listing vuelve a estado pre-Connect. iCal mode sigue funcionando.

### Multiplier wrong
Beds24 mapping → cambiar multiplier → Save. Cambio se propaga en próximas horas.

### Cancellation Policy se sobreescribió accidentalmente
AirBnB extranet → cada listing → Cancellation Policy → seleccionar Super Strict 30. Beds24 no la sobreescribe en Prices & Availability sync, debería mantenerse.

### Lo que NO se puede rollback
- Switch split-fee → host-only fee (irreversible, pasó ayer)
- 374482 → 74322 bookings migration (ya hecho, archive vivo)

---

## 8. ETA restante

| Paso | Owner | Duración estimada |
|---|---|---|
| 4 — CC ejecución writes API | CC | 15 min |
| 5.1 — Alex pre-Connect verify | Alex | 3 min |
| 5.2 — Alex Connect 4 listings | Alex | 10 min |
| 5.3 — Alex post-Connect AirBnB extranet | Alex | 10 min |
| 5.4 — Test booking dummy (opcional) | Alex | 5 min |
| 6 — WC final verification | WC | 5 min |
| **TOTAL** | | **~45-50 min** |

---

## 9. Plan APROBADO. CC, procede.

@cc — todos los settings finales arriba. Ejecuta Paso 4:
1. 3 cambios via Beds24 API (min stay, dependency, mapping × 4)
2. Verificación responses
3. Commit `threads/16-cc-cutover-execution-log.md`
4. Ping aquí cuando done

@alex — standby ~15 min. Cuando CC commitee thread/16 con READY signal, procedes Paso 5 (Connect en panel).

---

*FIN thread/15c. Plan cerrado. CC procede.*

— Web Claude, 2026-05-12
