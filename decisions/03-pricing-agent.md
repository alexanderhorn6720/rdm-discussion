# 03 — Pricing agent: simplified port to admin

**Status**: DEFERRED — spec aprobada (v3 2026-05-11), implementación pendiente post-foundations (M1 item en thread/179b §2 master backlog). No ha iniciado implementación en `rdm-bot`. Revisitar post-F2 observability + post-F1 events bus según thread/178 Wave plan. Última revisión: 2026-05-23 (thread/182 WV-C).

**Decisión**: Pricing pipeline migra a `apps/admin` (no app separada) como **tab "Pricing"** con UX simplificada:

1. **On-demand**: tú das click "Run pricing now" en admin → pipeline ejecuta → propuestas en pantalla
2. **Apply all batch**: si te late el resultado, botón "Apply all" → push a Beds24 → done. Si no, ajustas prompt y re-corres
3. **Prompt editable inline** desde admin (Q3=B) con history defensivo invisible (D1 tabla `pricing_prompt_history`, no UI rollback)
4. **Notification daily WhatsApp** con count de proposals pending (sin botón, solo recordatorio)
5. **Cron en background** ejecuta pipeline diario para que la notification tenga proposals listas — pero NO aplica auto. Tú aplicas siempre desde admin.
6. **Make scenarios eliminados al final de Sprint 3**, post-cutover verificado.

## Iteraciones del documento

- **v1 (2026-05-10)**: Buy PriceLabs $100/mes + override layer custom. Wrong assumption — pricing agent ya existía.
- **v2 (2026-05-11)**: Port intacto del Make scenario sofisticado. Better, but mantenía email approval + token + 24h expiry workflow innecesario.
- **v3 (2026-05-11 PM)** este doc: simplified — on-demand desde admin, apply all batch, sin email approval. Alex decisiones C1+C2+C3 + Q1=B + Q2=apply all + Q3=B.

## Lo que existe hoy en Make (referencia)

Ver decisions/03 v2 commit anterior + thread/02 sección 5 para audit completo.

Resumen para esta v3: 
- `cron:pricing-daily` (4718358): cron diario Sonnet 4.5 + hard validator + email HTML approval
- `wh:pricing-approve` (4719127): consume token, aplica a Beds24
- `wh:pricing-reject` (4719128): marca rechazado
- Datastore `pricing_proposals` (85677): token + 24h expiry + deltas_json
- Email a alexander@rincondelmar.club con HTML rich

## Qué simplificamos vs Make actual

| Componente Make | v3 admin port | Razón |
|---|---|---|
| Cron `*/15` filtrado a 6 AM | Cron diario background (mantenido) | Sigue necesario para que daily WhatsApp notification tenga proposals listas |
| Email HTML rich con APPROVE/REJECT buttons | UI tab en `apps/admin/pricing` | Email approval workflow es overhead. UI directa más simple |
| Token único + 24h expiry | Eliminado | No hay deadline para aplicar; admin siempre puede correr nuevo |
| Datastore `pricing_proposals` con status flow | D1 tabla `pricing_proposals` (current state) + `pricing_prompt_history` | Simplificado: last_run, deltas, status. No token workflow |
| `wh:pricing-approve` separado | `POST /pricing/apply` endpoint | Mismo endpoint dentro de admin |
| `wh:pricing-reject` | Eliminado | Si no aplicas, simplemente ignoras o re-corres con prompt distinto |

## Lo que se mantiene intacto

- **System prompt 100+ líneas** con reglas operativas Sonnet 4.5 calibradas
- **Pre-LLM JS** (~50 líneas): limpia calendar, calcula financial_summary by_month
- **Hard validator post-LLM** (~80 líneas): valida ranges, auto-corrige multiples de 250, valida floor/ceiling/±20%
- **Min-stay matrix** 5 propiedades × 5 seasons × 4 horizons
- **Anti-orphan logic** (gap 1N/2-3N/4N+)
- **Last-minute discount schedule** (-5% a -25%)
- **Reglas operativas**: prices múltiplos de 250, NEVER Christmas/HolyWeek/Easter/Sept15, etc.

## UX en `apps/admin/pricing`

### Tab principal

```
┌──────────────────────────────────────────────────────────────┐
│  PRICING                                                     │
│  Última corrida: hoy 06:00 · 12 proposals pending           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ [🔄 Run pricing now]  [✏️ Edit prompt]                 │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Financial Summary (próximos 360 días)                      │
│  ┌──────┬─────────┬─────────┬──────────┬──────────────────┐ │
│  │ Mes  │ Avail   │ Occup % │ Confirm  │ Probable revenue │ │
│  ├──────┼─────────┼─────────┼──────────┼──────────────────┤ │
│  │ May  │   45    │  22%    │ $180,000 │ $250,000         │ │
│  │ Jun  │   62    │  18%    │ $145,000 │ $310,000         │ │
│  │ ...                                                     │ │
│  └──────┴─────────┴─────────┴──────────┴──────────────────┘ │
│                                                              │
│  Proposed changes (12)              [🟢 Apply all]          │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ RdM       2026-05-15  minStay=3, price=$8,500 ↓ -5%  │    │
│  │ Morenas   2026-05-16  override=noCheckIn (orphan)    │    │
│  │ Huerta    2026-05-17  minStay=2, price=$1,750 ↓ -10% │    │
│  │ ...                                                  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Warnings (2)                                                │
│  ⚠️ Combinada has discount proposed but rules forbid         │
│  ⚠️ Auto-corrected 8 prices to multiples of 250              │
│                                                              │
│  Reasoning (LLM analysis)                                    │
│  Executive summary: ...                                      │
│  Minstay analysis: ...                                       │
│  Discount analysis: ...                                      │
└──────────────────────────────────────────────────────────────┘
```

### Flujo del usuario (loop)

1. Alex llega al tab, ve "12 proposals pending" (del cron daily background)
2. Revisa Financial Summary + proposed changes + warnings
3. **Si le late**: click "Apply all" → POST `/pricing/apply` → Beds24 batch update → success toast → tab refresca con "0 pending"
4. **Si no le late**: click "Edit prompt" → ajusta system prompt en Monaco editor → save → click "Run pricing now" → 30-60s wait → re-renders con nuevos proposals → revisa → loop hasta "Apply all"
5. **Si quiere descartar**: simplemente cierra el tab. No se aplica nada. Al día siguiente nuevo cron, nuevos proposals.

### Edit prompt screen

Monaco editor con sintaxis markdown:
- Read-only view del current prompt
- Click "Edit" → editable
- "Save" → updates D1 + KV cache → next run usa nuevo prompt
- **History defensivo invisible**: cada save inserta row en `pricing_prompt_history` (timestamp + author user_id + prompt_text). NO UI rollback en MVP1. Si Alex rompe el prompt, restore es manual SQL: `SELECT prompt_text FROM pricing_prompt_history ORDER BY created_at DESC LIMIT 5`.

### Notification daily WhatsApp

Cron diario (`apps/admin` o `apps/api` cron) ~6:30 AM:
- Lee count de proposals pending
- Si > 0: envía WhatsApp HSM template:
  ```
  Pricing pending review.
  Tap to open: https://admin.rincondelmar.club/pricing
  
  {{count}} changes proposed including {{last_minute_count}} last-minute.
  ```
- Si == 0: no envía nada (no spam)

**Stage 1**: WhatsApp HSM template approval pendiente. Hasta que esté aprobado, fallback email. CC verifica.
**Stage 2** (Cloud API direct): trivial.

## Architecture: `apps/admin` no `apps/pricing`

Decision Alex 2026-05-11: pricing vive en `apps/admin`, no app separada.

Reasons:
- Pricing es 100% admin-driven (on-demand)
- No hay public endpoint exposed
- Una app menos = menos overhead deploy/CI/monitoring
- D1 + KV bindings compartidos con resto de admin
- Notification cron puede vivir aquí o en `apps/api` — CC decide

### Endpoints en `apps/admin/worker`

```
GET  /pricing                  → admin UI tab
POST /pricing/run              → trigger pipeline, await completion (30-60s timeout)
POST /pricing/apply            → batch apply current pending proposals a Beds24
GET  /pricing/prompt           → current system prompt
PUT  /pricing/prompt           → update + insert history row
GET  /pricing/history          → list past runs (last 30) (no rollback UI)
```

Cron triggers en `apps/admin/wrangler.toml`:
```toml
[triggers]
crons = [
  "0 11 * * *",  # 6 AM CDMX (UTC-5) = 11 UTC. Cron daily pipeline run.
  "30 11 * * *", # 6:30 AM CDMX. WhatsApp notification si proposals > 0
]
```

### D1 tablas nuevas

```sql
-- Current state de pending proposals (NO token, NO expiry)
CREATE TABLE pricing_proposals (
  id TEXT PRIMARY KEY,           -- ULID
  created_at INTEGER NOT NULL,
  source TEXT NOT NULL,          -- 'cron-daily' | 'manual'
  status TEXT NOT NULL DEFAULT 'pending', -- pending | applied | superseded
  summary TEXT,
  deltas_json TEXT NOT NULL,     -- changes[] + beds24_payload
  monthly_analysis_json TEXT,
  reasoning_json TEXT,
  warnings_json TEXT,
  applied_at INTEGER,
  applied_by_user_id TEXT,
  apply_response TEXT
);

CREATE INDEX idx_pricing_proposals_status ON pricing_proposals(status, created_at DESC);

-- History de prompts (defensivo invisible)
CREATE TABLE pricing_prompt_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  prompt_text TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
  author_user_id TEXT,
  note TEXT                       -- optional comment al editar
);

-- Lookup hot path: current active prompt
-- Use KV `KV_KNOWLEDGE` key `pricing:system_prompt` para hot reads
```

### Pipeline execution

```typescript
// apps/admin/src/pricing/pipeline.ts
export async function runPricingPipeline(env, opts: { source: 'cron-daily' | 'manual' }) {
  // 1. supersede any prior pending
  await env.DB.prepare(
    "UPDATE pricing_proposals SET status='superseded' WHERE status='pending'"
  ).run();
  
  // 2. fetch Beds24 calendar + bookings
  const [calendar, bookings] = await Promise.all([
    beds24.getCalendar({ daysAhead: 360 }),
    beds24.getBookings({ status: 'confirmed' }),
  ]);
  
  // 3. pre-LLM cleanup (port from Make code module)
  const payload = preLlmCleanup({ calendar, bookings });
  
  // 4. Anthropic Sonnet 4.5
  const systemPrompt = await env.KV_KNOWLEDGE.get('pricing:system_prompt');
  const llmResponse = await anthropic.messages.create({
    model: 'claude-sonnet-4-5',
    max_tokens: 12000,
    temperature: 0.3,
    system: [{ type: 'text', text: systemPrompt, cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: JSON.stringify(payload) }],
  });
  
  // 5. hard validator post-LLM (port from Make code module)
  const validated = hardValidator({ llmResponse, calendar });
  
  // 6. INSERT pricing_proposal row
  const id = ulid();
  await env.DB.prepare(`
    INSERT INTO pricing_proposals (id, created_at, source, status, summary, deltas_json, monthly_analysis_json, reasoning_json, warnings_json)
    VALUES (?, ?, ?, 'pending', ?, ?, ?, ?, ?)
  `).bind(id, Date.now(), opts.source, validated.summary, JSON.stringify(validated.deltas), JSON.stringify(validated.monthlyAnalysis), JSON.stringify(validated.reasoning), JSON.stringify(validated.warnings)).run();
  
  return { id, validated };
}

export async function applyPendingProposals(env, userId: string) {
  const pending = await env.DB.prepare(
    "SELECT * FROM pricing_proposals WHERE status='pending' ORDER BY created_at DESC LIMIT 1"
  ).first();
  if (!pending) return { applied: 0, message: 'no pending' };
  
  const deltas = JSON.parse(pending.deltas_json);
  const result = await beds24.applyCalendarChanges(deltas.beds24_payload);
  
  await env.DB.prepare(`
    UPDATE pricing_proposals
    SET status='applied', applied_at=?, applied_by_user_id=?, apply_response=?
    WHERE id=?
  `).bind(Date.now(), userId, JSON.stringify(result), pending.id).run();
  
  return { applied: deltas.changes.length, result };
}
```

## Migración path (Sprint 3)

### Pre-migration (Sprint 0-2)

- Make scenarios `cron:pricing-daily`, `wh:pricing-approve`, `wh:pricing-reject` **keep activos**
- Admin board Sprint 2 incluye view-only del pricing actual (lee D1 + Make logs) para auditar

### Sprint 3 — port

1. `apps/admin/src/pricing/` — UI tab + endpoints
2. `packages/pricing-agent/` — system prompt + pre/post llm logic + types
3. D1 migrations: `pricing_proposals` + `pricing_prompt_history`
4. KV `KV_KNOWLEDGE` seed con `pricing:system_prompt` (copy del Make scenario)
5. WhatsApp HSM template (or Stage 1 fallback email via Resend)
6. Beds24 client `packages/beds24` ya existe — reusar
7. Cron `0 11 * * *` + `30 11 * * *` en `apps/admin/wrangler.toml`

### Sprint 3 cutover

1. Deploy `apps/admin` con pricing tab + cron daily
2. **Run paralelo 5-7 días** vs Make:
   - Make cron sigue corriendo, manda email
   - Admin tab muestra proposals nuevos
   - Compare deltas — alertar si difieren > 10%
3. Switch authoritative: aplicar SIEMPRE desde admin (no responder al email de Make)
4. **Sprint 3 final** — eliminar Make scenarios:
   - `wrangler` no se puede usar para Make. Delete via Make API o UI.
   - Web Claude vía Make MCP: `Make:scenarios_delete` para 4718358, 4719127, 4719128
   - Datastore `pricing_proposals` (85677) export backup → delete
5. Done

### Riesgos cutover

- **WhatsApp HSM template approval delays**: si template `pricing_notification` no aprobado, fallback email Resend Sprint 3, swap a WhatsApp después
- **D1 schema migration error**: testear migrations en staging D1 antes
- **Sonnet 4.5 quota**: trivial, 1 run/día + manual ~5/día max = $5/mes
- **Beds24 API rate limits**: batch apply tiene N pricing changes en 1 call con `beds24_payload` formato

## Lo que NO entra en este port

- **Multi-prompt experimentation** (Sprint 4+ feature, p.ej. A/B test 2 prompts)
- **Pricing override layer** con señales del bot (intent demand) — Stage 2 future
- **Rollback UI** del prompt history — SQL manual por ahora
- **Approval workflow multi-user** (cuando llegue `staff` rol con permiso pricing read-only)

## Confirmaciones Alex

| Q | Voto | Razón |
|---|---|---|
| Q1 (cuándo correr) | B + cron background | On-demand desde admin + cron background diario para que notification tenga data |
| Q2 (granularidad apply) | Apply all batch | Si no le late, ajusta prompt y re-corre — no inline edit |
| Q3 (prompt editable) | B editable inline | Sin versioning UI, history defensivo invisible (C2) |
| HTTP endpoints | Sí completos | `/run`, `/apply`, `/prompt` GET/PUT |
| Make pricing | Eliminar al final Sprint 3 | Mantener fallback hasta cutover verificado |
| Notification | WhatsApp por defecto | Email Stage 1 fallback hasta HSM template aprobado |
| App | `apps/admin` no `apps/pricing` | Una app menos, pricing 100% admin-driven |

## Acción items

### Web Claude
- [x] Reescribir decisions/03 v3 con simplificación
- [x] Update thread/02 con decisiones C1+C2+C3

### Claude Code (lunes)
- [ ] Voto sobre `apps/admin` vs `apps/pricing` app separada
- [ ] Voto sobre notification cron en `apps/admin` vs `apps/api`
- [ ] Voto sobre orden de tabs en Sprint 2 (¿pricing antes o después de conversations?)
- [ ] Sprint 3 sizing: ¿2 sem realista para port + WhatsApp HSM + cutover paralelo?

### Alex
- [ ] WhatsApp HSM template `pricing_notification` — solicitar approval con Meta cuando llegue Sprint 3
- [ ] Stage 1 fallback: ¿OK email Resend si template no aprobado?
