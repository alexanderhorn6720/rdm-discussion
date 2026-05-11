# 03 — Pricing agent: port intacto del existente

**Status**: Reescrita 2026-05-11 post-decisión Alexander (A2/A5) + audit de Web Claude.

**Decisión**: **Port intacto** del pricing agent custom existente en Make (`cron:pricing-daily`, `wh:pricing-approve`, `wh:pricing-reject`) a `apps/pricing` Worker. **NO comprar PriceLabs/Beyond/Wheelhouse. NO build from scratch. NO heuristic simple.**

## Contexto

**Versión original (2026-05-10) de este documento sugirió "Buy PriceLabs Stage 1 + Build override Stage 2"**. Era una mala recomendación basada en suposición errónea de que no había pricing agent funcional.

Alexander corrigió en thread/01-alexander-votes.md (A2/A5):

> "Claude Web no analizó bien pricing agent actual en Make, es simple. No habrá PriceLabs."

Web Claude auditó el blueprint actual y encontró que el pricing agent **no es simple**: es sofisticado, calibrado para el negocio, y mejor que cualquier SaaS out-of-box para este caso de uso específico.

## Lo que existe hoy (auditado 2026-05-11)

### `cron:pricing-daily` (4718358)

**Schedule**: Lun-Dom 06:00-06:01 cada 15min (efectivamente diario 6 AM).

**Pipeline**:

1. **Get tokens** (datastores `beds24_auth` + `rdmbot_secrets`)
2. **Beds24 calendar** GET `/v2/inventory/rooms/calendar` con `startDate=today, endDate=today+360d, includePrices=true, includeMinStay=true, includeNumAvail=true, includeOverride=true`
3. **Beds24 bookings** GET `/v2/bookings` con `departureFrom=today, arrivalTo=today+360d, includeInvoiceItems=true, status=confirmed`
4. **Code module pre-LLM** (~50 líneas JS):
   - Limpia calendar a ranges compactos
   - Calcula `confirmed_income, payments, balance_pending` cross-property
   - Agrupa bookings by_month con count
   - Calcula `financial_summary` per propiedad/mes
5. **POST Anthropic** (Sonnet 4.5, 12K tokens, ephemeral caching) con:
   - System prompt 100+ líneas con reglas operativas detalladas
   - User content: JSON con `today, horizon_days, rooms, calendar, bookings, financial_summary`
6. **Code module post-LLM** (~80 líneas JS): hard validator
7. **Datastore add** `pricing_proposals` (85677) con token único + 24h expiry
8. **Email** con HTML rich a alexander@rincondelmar.club con tabla, warnings, auto-corrected list, APPROVE/REJECT buttons

### System prompt highlights

**Hard rules (10)**:
1. minStay only {2, 3, 4}
2. Override only `null` or `noCheckIn` (NEVER `blackout`)
3. Prices MUST be multiples of 250 (e.g. 1500, 1750, 2000 — NEVER 1900, 2850, 8075)
4. Max +/-20% price change vs current per run
5. NEVER touch dates with bookings (numAvail=0)
6. NEVER touch premium seasons: Christmas/NewYear (Dec23-Jan2), Holy Week, Easter, Sept 15
7. Floor by roomId: 78695=5000, 374482=3500, 74322=3500, 74316=11000, 637063=1500
8. Ceiling by roomId: 78695=40000, 374482=25000, 74322=25000, 74316=60000, 637063=6000
9. Saturday always minStay=4
10. Carnival is NOT premium

**Min-stay matrix** (5 propiedades × 5 seasons × 4 horizons):
- Christmas: 4 nights todos los horizonte
- Summer/HolyWeek/Easter/Sept15/May/Muertos: 3 nights typical, 2 if last-minute
- Low season: 3 → 2 según horizonte
- Combinada: similar pero excluye discounts
- Huerta: siempre 2 (más flexible)

**Anti-orphan logic** (gaps 1-4 nights between bookings):
- Gap 1N: override `noCheckIn`, minStay stays
- Gap 2-3N: respect base minStay
- Gap 4N+: bump first day to max(base, 3)

**Last-minute discount schedule** (% off current price):
- <45d, >=30d: -5%
- <30d, >=14d: -10%
- <14d, >=7d: -15%
- <7d, >=3d: -20%
- <3d: -25%

Conditions: solo RdM/Morenas/Huerta (NEVER Combinada), solo Low/Mid season (NEVER Christmas/HolyWeek/Easter), día disponible (numAvail=1), current > floor.

**Math**:
- `raw = current_price * (1 - discount_pct)`
- `new_price = Math.floor(raw / 250) * 250` (round DOWN to nearest 250)
- `new_price = max(floor, new_price)`
- If `new_price === current_price1`, SKIP

### Post-LLM hard validator (~80 líneas)

- Valida cada change: roomId, date format, no past dates, minStay {2,3,4}, override válido
- Auto-corrige prices al múltiplo de 250 más cercano (down)
- Valida price floor/ceiling per roomId
- Valida pct change ≤ 20%
- Filtra changes que no modifican nada
- Construye `beds24_payload` agrupado per roomId

### Email approval workflow

HTML rich:
- Financial summary table (avail nights, occupancy %, confirmed income, upside, probable revenue, notes per mes)
- Warnings section
- Auto-corrected prices list
- Proposed changes table (property, date, change, reason)
- 2 botones: APPROVE / REJECT con token único + 24h expiry
- Analysis sections del LLM: executive summary, minstay analysis, orphan analysis, discount analysis, season observations, operational alerts, recommendations

### Stats actuales

- 22 ejecuciones del cron
- 10 errores (45% — debugging activo, probable: Beds24 timeouts, JSON parse del LLM con `content[1].text` que puede fallar si LLM responde diferente)
- 5 approves ejecutados
- 0 rejects (los rechazos requieren que el approve no se haga, no se generan eventos)

## Por qué NO PriceLabs / Beyond / Wheelhouse

| Razón | Detalle |
|---|---|
| **Reglas propietarias** | Premium seasons MX, floors per propiedad, mascotas no, Combinada blocks 78695+374482 (linked) — SaaS no soporta |
| **Chef incluido en RdM** | Pricing más caro vs Morenas. SaaS no entiende |
| **5 roomIds incluyendo dual listing** | 374482 (direct) + 74322 (Airbnb) son mismo property. SaaS no maneja bien |
| **Email approval flow** | Alexander aprueba antes de aplicar. SaaS auto-apply o requieren UI propia para approval |
| **Costo SaaS recurrente** | ~$100/mes ($19.99 × 5 listings) PriceLabs vs $0/mes recurring marginal |
| **Vendor lock-in** | PriceLabs/Beyond migration sale es trabajo |
| **Modelo ya calibrado** | 100+ líneas de reglas Operacionales tomó tiempo afinar. Replicar en otro sistema es regresión |

## Por qué NO build from scratch

| Razón | Detalle |
|---|---|
| **Ya está construido** | El cron funciona, los emails llegan, las reglas están claras |
| **Time-to-port < time-to-rebuild** | 1-2 semanas port intacto vs 3-6 meses rewrite |
| **Riesgo de regresión** | Cualquier rewrite olvida casos edge ya cubiertos |
| **Sonnet 4.5 prompts ya tuneado** | Los ejemplos de math en el prompt están calibrados para Haiku/Sonnet behavior — replicar requiere re-tuning |

## Plan de port (Sprint 3, post-MVP1)

### `apps/pricing` Worker structure

```
apps/pricing/
├── wrangler.toml
├── src/
│   ├── index.ts              ← cron handler + manual trigger route
│   ├── cron.ts               ← orquestación del pipeline
│   ├── approve.ts            ← POST /approve?token=X endpoint
│   ├── reject.ts             ← POST /reject?token=X endpoint
│   ├── beds24-client.ts      ← typed client (delega a packages/beds24)
│   └── email-template.tsx    ← React Email para approval HTML
└── package.json

packages/pricing-agent/
├── src/
│   ├── index.ts              ← export pipeline orchestrator
│   ├── prompt.ts             ← system prompt (port intacto del JS string)
│   ├── pre-llm.ts            ← Code module pre-LLM logic
│   ├── post-llm.ts           ← hard validator
│   ├── types.ts              ← Zod schemas
│   └── pricing-agent.test.ts ← regression tests
└── package.json
```

### Cambios respecto a Make

1. **D1 reemplaza datastore `pricing_proposals`**:
   ```sql
   CREATE TABLE pricing_proposals (
     token TEXT PRIMARY KEY,
     status TEXT NOT NULL DEFAULT 'pending',  -- pending | approved | rejected | expired | applied | error
     summary TEXT,
     deltas_json TEXT NOT NULL,
     created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
     expires_at INTEGER NOT NULL,
     applied_at INTEGER,
     apply_response TEXT
   );
   ```

2. **React Email reemplaza HTML inline**:
   - Usa `packages/email-templates` (ya existe)
   - Mismo diseño, mejor maintainability
   - Cuidado: `@react-email/render` falla en CF Workers runtime (CC reportó). Usar HTML inline fallback igual que Better Auth.

3. **APPROVE/REJECT URLs apuntan a `apps/pricing`**:
   - `https://api.rincondelmar.club/pricing/approve?token=X` (Sprint 2-3 cuando `apps/api` exista)
   - O directo `https://pricing.rincondelmar.club/approve?token=X` (sin subdomain extra)
   - Decide CC

4. **Anthropic client desde `packages/llm-client`**:
   - Mismo wrapper que `apps/bot` para reutilizar prompt caching + telemetry

5. **Tests regresión**:
   - Capturar payloads reales actuales del cron Make (calendar+bookings)
   - Snapshot LLM output esperado
   - Replay contra `apps/pricing` y compare deltas

### Migración cutover

1. `apps/pricing` deployment con cron paralelo a Make (mismo schedule)
2. Compare outputs por 5-7 días — alertar si difieren > 10%
3. Switch authoritative source: Make → `apps/pricing`
4. Pause Make `cron:pricing-daily` (no delete, fallback 14 días)
5. Sunset Make scenario en Fase 5

## Errores actuales a resolver durante port

10 errores en 22 exec. Hipótesis:

1. **Beds24 API timeouts** (probable): rate limit o slowness. Fix: timeout 120s ya está, agregar retry exponential.
2. **JSON parse LLM**: `data.content[1].text` falla si LLM responde con un solo content block (sin tool use prefix). Fix: iterar content array buscando text type.
3. **Datastore `pricing_proposals` lookup**: si Make falla persisting, los approve URLs no funcionan.
4. **Email send failures**: Google Email connection puede tener rate limits.

Port a Worker resuelve 1, 3, 4 con D1 atomicity + Resend. (2) requiere fix en el code module.

## Riesgos del port

| Riesgo | Mitigación |
|---|---|
| `@react-email/render` falla en CF Workers | HTML inline fallback (igual que Better Auth) |
| Prompt Sonnet 4.5 cambia behavior en Haiku 4.5 | Mantener Sonnet 4.5 para pricing (no es hot path, $0.50/run es trivial) |
| D1 transaction fails atómica | Workers Workflows o try/catch con rollback explícito |
| Anthropic API quota | Single execution/día, no problema |
| Beds24 API rate limit | Espaciar fetchAll calls, ya hace 2 (no muchas) |

## Roadmap

| Sprint | Trabajo |
|---|---|
| MVP1 (Sprint 1) | NO tocar pricing. Sigue en Make |
| Sprint 2 (admin) | `apps/admin` tiene tab Pricing con view de pending proposals |
| Sprint 3 | Port `cron:pricing-daily` + approve/reject a `apps/pricing` |
| Sprint 4 | Cutover authoritative, paralelo deprecated |
| Sprint 5 | Sunset Make pricing scenarios |

## Voto

- [x] **Alexander** (A2/A5 thread/01): no PriceLabs, custom port
- [ ] **Claude Code**: ¿voto sobre port intacto vs incremental refactor con tests?
- [ ] **Web Claude**: voto port intacto manteniendo Sonnet 4.5, R2 para `pricing_proposals` archive, D1 para current state
- [ ] **Future**: stage 2 considera agregar señales propietarias (bot intent demand, eventos manuales) al LLM input — pero NO antes del cutover Make→Worker estable
