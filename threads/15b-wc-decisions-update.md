# Thread 15b — WC update post-Alex feedback

**Date**: 2026-05-12
**Author**: Web Claude
**To**: CC `[@cc]`, Alex `[@alex]`
**Re**: Updates a thread/15 con decisiones Alex

---

## Decisiones Alex confirmadas (2026-05-12)

| # | Setting | Valor final |
|---|---|---|
| 1 | Channel Multiplier | **1.20 uniforme** los 4 listings (no 1.183) |
| 2 | Min Stay Calculation | `arrival` |
| 3 | Cleanup dependency 374482 | GO |
| 4 | Weekly/Monthly Discounts | Pushear desde Beds24 (NO AirBnB extranet) |
| 5 | Smart Pricing | OFF (Alex verificará en AirBnB extranet) |
| 6 | Cancellation Policy | Sin cambios (Alex confirmó está bien) |

## Impacto Multiplier 1.20 vs 1.183

Sobre $4.4M volumen anual AirBnB:

| Métrica | 1.183 | **1.20** | Delta |
|---|---|---|---|
| Cliente paga vs pre-cambio | +3.7% | +5.3% | +$70/noche más en RdM ~$10k |
| Tu neto vs pre-cambio | =100% | +1.4% | +$62K MXN/año extra |
| Risk conversión | bajo | bajo-medio | marginal |

Alex elige +1.4% margen extra (~$62K/año). Justificable.

## Updates al execution plan CC (thread/16)

### Cambio en mapping API per listing

Reemplaza `channelMultiplier: 1.183` por `channelMultiplier: 1.20` en los 4 POST calls.

### Nuevo paso adicional pre-Connect — Weekly/Monthly Discounts vía Beds24

CC agrega configuración via API:

```bash
# Per listing, set Pricing Settings (Specific Content)
# Endpoint exacto a determinar — Beds24 docs sección:
# CHANNEL MANAGER → AIRBNB → SPECIFIC CONTENT → PRICING SETTINGS
#
# Settings recomendados WC (default, Alex puede ajustar):
# - weekly_discount: 0
# - monthly_discount: 0
# - early_bird_discount: 0
# - last_minute_discount: 0
#
# Si Alex pasa valores distintos, usar esos.
```

Si endpoint API no accesible, Alex configura en panel post-Connect (no bloquea cutover).

### Pre-Connect Alex verifications adicionales

Antes de Connect en panel, Alex verifica:

1. **SETTINGS → PROPERTIES → ROOMS → cada room → DAILY PRICES**:
   - Price For (capacidad base): 78695=15, 74322=15, 74316=30, 637063=4
   - Extra Person Price: 78695=$300, 74322=$300, 74316=$300, 637063=$200
   - Confirmar si signo POSITIVO o NEGATIVO (ver §3 abajo)

2. **SETTINGS → CHANNEL MANAGER → AIRBNB → SPECIFIC CONTENT → PRICING SETTINGS** per listing:
   - Si quiere descuentos Weekly/Monthly, configurar ahora
   - Mi voto: 0% para empezar, agregar después si necesario

3. **AirBnB extranet por listing → Smart Pricing**: confirmar OFF

## §3 — Extra Person Price: POSITIVE vs NEGATIVE setup

Beds24 docs documentan dos enfoques para enviar pricing a AirBnB:

### Setup A (POSITIVE, intuitivo)
- Price For: N personas (capacidad base)
- Extra Person: +$300/persona arriba de N
- AirBnB recibe: precio base para N + extras suma desde N+1

### Setup B (NEGATIVE, recomendado por Beds24 docs)
- Price For: capacidad MÁXIMA
- Daily Price: precio para máxima ocupación (base + max_extras × extra_rate)
- Extra Person: **-$300/persona faltante**
- AirBnB calcula: precio_max - (max_capacity - guests) × $300

**Implicación práctica**: para AirBnB recibir precios correctos diferenciados por # de guests, requiere Setup B.

Si Alex tiene Setup A actualmente, AirBnB cobra siempre precio para max occupancy independiente de # guests. **Confirmar en panel** — afecta margen real.

**Acción**: CC puede preguntar Beds24 docs si hay endpoint `/v2/properties/rates` confiable, o pedirle a Alex screenshot del panel para diagnosticar.

## Estado actual

- ✅ Alex confirmó multiplier 1.20
- ✅ Alex confirmó Min Stay arrival
- ✅ Alex confirmó cleanup 374482
- 🟡 Alex pending: verificar Daily Price Rules en panel (POSITIVE/NEGATIVE)
- 🟡 Alex pending: decidir Weekly/Monthly Discount % (default 0% si no decide)
- 🚀 CC ready para proceder Paso 4 con valores actualizados

## Aprobación Alex confirmada

Multiplier 1.20 + min stay arrival + cleanup 374482 = **APROBADO**.

CC procede Paso 4 con:
- `channelMultiplier: 1.20` (en lugar de 1.183 del thread/15)
- Cleanup dependency 74316
- Min stay calculation arrival
- Weekly/Monthly discounts: 0% si Alex no especifica

