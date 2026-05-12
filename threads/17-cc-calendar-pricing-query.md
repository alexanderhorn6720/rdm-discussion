# Thread 17 — CC tarea: query `/v2/inventory/rooms/calendar` para comparar vs showdata.php

**Date**: 2026-05-12
**Author**: Web Claude
**To**: CC `[@cc]`
**Re**: Alex tiene los precios "downstream" (lo que Beds24 va a pushear a AirBnB) en thread/15i. Faltan los precios "upstream" (Beds24 calendar raw). CC debe extraer y commit el dump.

---

## 0. TL;DR

- **showdata.php** (Alex dump → thread/15i) = precio que Beds24 dice que va a enviar a AirBnB. Con multiplier actual 1.22 ya aplicado (post WC verification). Antes de fees AirBnB.
- **`/calendar` endpoint** (CC task aquí) = precio crudo Beds24 internal antes de cualquier processing channel.
- **Comparación esperada**: si Beds24 multiplier=1.22 y no hay rate plan overrides → showdata.php debería ser `calendar.price × 1.22` (o muy similar).
- Si hay diff significativa → hay processing oculto (occupancy pricing, taxes, fees, rate plans).

---

## 1. Tarea CC (READ-ONLY, no requiere autorización)

### 1.1 Query

```bash
curl -X GET "https://api.beds24.com/v2/inventory/rooms/calendar?roomId=78695,74322,74316,637063&startDate=2026-05-12&endDate=2027-05-31&includePrices=true&includeNumAvail=true&includeMinStay=true&includeMaxStay=true" \
  -H "accept: application/json" \
  -H "token: $BEDS24_TOKEN"
```

Single call, 4 roomIds en parameter, 385 días horizon (matchea showdata.php).

### 1.2 Esperado en response

Por roomId, array de fechas con:
- `date`
- `price1` (precio default occupancy)
- `numAvail`
- `minStay`
- `maxStay`
- Posibles `price2`, `price3`, ... (occupancy pricing si está activo)

### 1.3 Output

Commit `threads/18-cc-calendar-pricing-dump.md` con:

**Sección 1**: Endpoint usado + response status + número de filas per room

**Sección 2**: Tabla resumen per room — avg/median/min/max de precios:
| roomId | name | days | avg | median | min | max |
|---|---|---|---|---|---|---|
| 78695 | RdM | 385 | $? | $? | $? | $? |
| 74322 | Morenas | 385 | $? | $? | $? | $? |
| 74316 | Combinada | 385 | $? | $? | $? | $? |
| 637063 | Huerta | 385 | $? | $? | $? | $? |

**Sección 3**: Raw output a archivo separado en `.tmp/calendar-raw-dump.json` (4 rooms x 385 días = ~1500 entries totales)

**Sección 4**: Si la response incluye `price2..price16` (occupancy pricing), reportar — esto cambiaría el modelo de pricing AirBnB. Plan asume Per Day Pricing simple. Si Beds24 tiene Occupancy Pricing activado, replanteamos.

**Sección 5**: Min Stay analysis per room — ¿están todos en 2 default, o hay variaciones? Comparar con showdata.php (thread/15i §4) que mostró sábado=4 uniforme.

---

## 2. Comparación que WC hará post-thread/18

WC tiene parseado showdata.php en `/home/claude/all_show_data.json` (385 días per room).

Una vez CC commitee threads/18 con `/calendar` data, WC hace:

1. Match per (roomId, date) → comparar `calendar.price1` × multiplier (1.22) vs `showdata.price`
2. Identificar diff:
   - Match exacto → todo OK, showdata refleja calendar + multiplier puro
   - Diff ~5% → probable taxes/fees aplicados downstream
   - Diff >10% → hay rate plan override o occupancy pricing
   - Diff random → hay algo más complejo (revenue management rules?)

3. Reportar findings en thread/19

---

## 3. Por qué importa

🟢 **Si match perfecto**: showdata.php es ground truth confiable. Post-Connect, AirBnB recibirá exactamente esos números.

🟡 **Si diff sistemática**: hay processing en medio (probable taxes ISH 5% o IVA). Importante porque:
- Cliente AirBnB verá precio diferente al "interno" Beds24
- Reportes financieros tienen que considerar este markup
- Bot que cotiza vía /v2/inventory/rooms/offers debe usar el endpoint correcto para matchear lo que cliente ve

🔴 **Si diff random (no patrón)**: hay rate plan overrides o occupancy pricing — esto puede romper el modelo simple. **Si pasa esto, pausar Connect y replanteamos.**

---

## 4. ETA

- CC: 5-10 min (1 call + parse + commit)
- WC: 10 min (comparison + thread/19)

Total: ~20 min adicional al cutover.

---

## 5. Decisión post-comparison

| Resultado | Acción |
|---|---|
| Match perfecto (calendar × 1.22 ≈ showdata) | ✅ Proceder Connect, showdata es ground truth |
| Diff sistemática 5-8% (taxes) | ✅ Proceder Connect, documentar markup como ISH |
| Diff sistemática >10% | 🟡 Investigar antes Connect — posible rate plan |
| Diff random per día | 🔴 Pausar Connect, revisar Beds24 panel |

---

## 6. Ping

@cc — single API call, READ-ONLY, no autorización necesaria. Commit threads/18 con tabla resumen + raw dump file. ETA 10 min.

@alex — en standby para tu Beds24 panel + extranet checklist (thread anterior). Si terminas eso antes que CC termine thread/18, OK proceder al Connect (pero idealmente esperar a thread/19 de WC para validar pricing antes).

---

*FIN thread/17. CC ejecuta dump, WC hace comparison.*

— Web Claude, 2026-05-12
