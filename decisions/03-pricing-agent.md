# 03 — Pricing agent: Build vs Buy

**Status**: Propuesta. Esperando voto.

**Decisión propuesta**: **Buy** (PriceLabs) en Stage 1. **Build** complemento en Stage 2 (3-6 meses) solo si la heurística específica del negocio lo justifica.

## Contexto

Alexander pidió "pricing agent de Make, o solución similar para automatizar fijación de precios y minstays según necesidad del mercado y negocio".

Hoy en Make no hay un pricing agent activo verificado. Precios están **estáticos** en Beds24 (Alexander los edita manual). Min-stays están seteados pero no se ajustan dinámicamente.

Industria de vacation rentals tiene varios SaaS dedicados a esto con algoritmos calibrados por años y datos de millones de listings.

## Lo que necesitamos

1. **Dynamic pricing diario**: precio adjusta según demanda local, eventos (puentes, Semana Santa, Grito), competencia, occupancy histórica.
2. **Min-stay dynamic**: minstay sube en weekends de alta demanda, baja para orphan nights.
3. **Floor/ceiling rules**: precios nunca debajo de X (costo operativo + margen mínimo) ni arriba de Y (sanity check).
4. **Override manual**: Alexander puede setear precio fijo para fecha específica (boda corporativa, evento).
5. **Push automático a Beds24**: el sistema actualiza Beds24 vía API, sin intervención manual.
6. **Visibility**: Alexander ve qué cambió, por qué, y revenue proyectado.

## Opciones

### A — Buy: PriceLabs (recomendado Stage 1)

- $19.99/listing/mes (drop a $16.99 con 10+ listings).
- 5 listings × $19.99 = ~$100/mes total.
- **Algoritmo Hyper Local Pulse (HLP)** calibrado con datos de mercado local.
- Integra **directo con Beds24** (Beds24 está listado en integraciones oficiales de PriceLabs).
- 15+ settings para reglas: base prices, seasonality, weekly/weekend differentials, last-minute discounts, occupancy thresholds, etc.
- Comp set tools: mapeo de propiedades comparables nearby con ratings, amenities, size.
- Dashboard de KPIs: ADR, RevPAR, occupancy.

**Pros**:
- Live en 1-2 semanas (configuración + comp set + test).
- Algoritmo probado con miles de listings.
- Data de mercado local (Pie de la Cuesta / Acapulco) que NUNCA podríamos replicar from scratch.
- Mantenimiento $0 — PriceLabs mejora el algoritmo continuamente.
- Override manual fácil.
- Si no nos gusta, migrar a Beyond o Wheelhouse es cuestión de re-conectar a Beds24.

**Cons**:
- ~$100/mes recurrente.
- Algoritmo es black box. No podemos meter señales custom (p.ej. "Karina vio que el grupo de Whatsapp X reservó la villa de al lado").
- Dependencia externa para core del negocio.

### B — Buy: Beyond Pricing

- Pricing similar (~$15-20/listing/mes).
- "Search-powered pricing" — usa data de búsquedas guest para predecir demanda.
- Hand-launched markets — equipo Beyond cura cada mercado.

**Pros**:
- Mejor para luxury / unique properties (RdM cae aquí).
- Search-powered es ventaja real, datos que PriceLabs no tiene.

**Cons**:
- Hand-launched significa que **podrían no tener Pie de la Cuesta** cubierto bien todavía. Verificar.
- Menos customizable que PriceLabs.

### C — Buy: Wheelhouse

- $19.99/listing/mes Pro, o 1% revenue.
- 18-month forward calculator (único en industria).
- Dynamic Sets — comp set mapping detallado.

**Pros**:
- 1% revenue model es atractivo: paga proporcional a éxito.
- Forward calculator largo plazo útil para planning eventos grandes (bodas).

**Cons**:
- Menos data local que PriceLabs.

### D — Build: Pricing agent custom desde cero

```typescript
// apps/pricing/src/index.ts (sketch)
export default {
  async scheduled(event, env, ctx) {
    // 1. Pull occupancy histórica de D1
    // 2. Pull eventos calendar (Grito, S.Santa, etc.)
    // 3. Pull competitor prices (scrape Airbnb listings nearby — RIESGO TOS)
    // 4. Compute new prices per día per propiedad con heurística:
    //    - base × (1 + occupancyFactor) × (1 + eventFactor) × (1 + leadTimeFactor)
    //    - clamp a [floor, ceiling]
    // 5. Push a Beds24 via API
    // 6. INSERT en D1 pricing_log para audit
    // 7. Notify Alexander vía email si change > 15%
  }
};
```

**Pros**:
- $0 recurrente.
- Control total. Podemos meter señales custom (señal de Karina, eventos privados que conocemos).
- Data del bot (intent de cotización por fecha) es señal de demanda REAL — nadie más la tiene.

**Cons**:
- **3-6 meses** para tener algo bueno. Heurísticas simples sin ML primer trimestre. ML serio requiere meses + data.
- Scraping Airbnb es **violación de TOS** y frágil. AirDNA API existe pero cuesta $19-99/mes y aún hay que integrar.
- Riesgo de error: si el algoritmo baja precio 30% por bug, perdemos $$$.
- Mantenimiento continuo. Algoritmo debe ajustarse cada estación, evento nuevo, propiedad nueva.
- **Compite contra equipos full-time de PriceLabs/Beyond** que llevan años en esto.

### E — Híbrido: Buy PriceLabs + Build complemento (recomendado Stage 2)

- Stage 1: PriceLabs setea base prices y minstays.
- Stage 2: Worker custom override PriceLabs para casos específicos donde tenemos info propietaria:
  - Demand del bot (turnos LLM por fecha) — proxy de interés real.
  - Eventos corporativos confirmados que bloquean fechas.
  - Patterns de Karina (insights humanos).
  - Marketing campaigns activas (pricing ajustado para CTW ads).

**Pros**:
- Best of both: algoritmo industrial + señales propietarias.
- Si PriceLabs falla, base prices siguen siendo razonables sin override.
- Build minimal (override layer, no full algo).

**Cons**:
- Complejidad: dos sistemas que tocan Beds24 prices.
- Resolver conflictos: ¿quién gana cuando PriceLabs dice $12k y override dice $15k?

## Recomendación

**Stage 1: PriceLabs**. Live en 2 semanas, $100/mes para 5 listings, baseline excelente.

**Stage 2 (mes 4-6): Override layer custom** en `apps/pricing/` que escucha eventos del bot (cotización fallidas, conversion rate por fecha) y modifica precios sobre la baseline de PriceLabs solo en casos justificados.

**No build from scratch** — perderíamos meses replicando lo que PriceLabs hace gratis.

## Costos comparativos (3 propiedades activas + Combinada + Chamán futuro)

| Opción | Setup | $/mes | Tiempo a producción |
|---|---|---|---|
| A — PriceLabs | 1 sem | $80-100 | 2 sem |
| B — Beyond | 2 sem | $80-100 | 3 sem |
| C — Wheelhouse | 2 sem | $80-100 o 1% rev | 3 sem |
| D — Build | 12 sem | $0 (+ AirDNA $19-99 si data externa) | 3-6 meses |
| E — Híbrido | A + 4 sem extra | $80-100 + $0 | 2 sem + 1 mes |

ROI dynamic pricing en vacation rentals: industry data cita 5-15% ADR lift. Para RdM con ARPU promedio estimado de ~$15k/noche × 50-100 noches/mes per propiedad → revenue mensual $750k-1.5M MXN. 5% lift = $37k-75k MXN/mes. **PriceLabs paga su costo 400-1000x**.

## Decisión D (Build) — cuándo justificaría

- Si tenemos un edge claro vs algoritmos comerciales (no parece el caso hoy).
- Si volumen escala a 50+ propiedades y $100/mes/listing se vuelve material.
- Si encontramos señal propietaria que SaaS no captura.

**Hoy, no.**

## Voto

- [ ] **Claude Code**: ¿A, B, C, D, E? Otra herramienta?
- [ ] **Alexander**: ¿OK con buy PriceLabs Stage 1?

## Refs

- PriceLabs Beds24 integration: `https://hello.pricelabs.co/integrations/`
- Beyond Pricing: `https://www.beyondpricing.com`
- Wheelhouse: `https://www.usewheelhouse.com`
- Industry comparison 2026: `https://www.aeve.ai/best-dynamic-pricing-tools-vacation-rentals-2026`
