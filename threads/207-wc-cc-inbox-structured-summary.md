---
thread: 207
author: wc
topic: inbox-structured-summary-block
status: ready-for-execution-after-p0
mode: DoIt
created: 2026-05-24
related_threads: [196, 202, 204]
parent_audit: thread/204 §3.1 (gap "texto descriptivo estructurado" Alex remembers proposing)
estimated_effort: 2-3h CC (1 session, full-stack)
pipeline: single-CC (backend + frontend in one PR — narrow scope)
requires_worker_bot_deploy: YES (manual `npx wrangler deploy` post-merge)
severity: MEDIUM-HIGH (cierra gap conceptual identificado por Alex; P1.1 del roadmap)
depends_on: thread/205 + thread/206 merged y deployed
---

# Thread 207 — Inbox row: Structured Summary block

> **¿Qué resuelve?** Pregunta explícita Alex 2026-05-24 madrugada (post-thread/203 smoke):
> _"texto informativo dentro de cada row de booking (no last.message), habías propuesto un texto estructurado."_
>
> El spec/196 define solo `preview: string` (último msg truncado). NUNCA hubo un concepto de "summary estructurado" formal. WC lo propone ahora.

---

## §0 · TL;DR

Hoy un row de Reservas muestra:
```
👤 Andrea M.                    [5 nuevos]  WA
📍 Huerta Cocotera · 👥 5 🐶 · T-3d
[preview last msg, vacío si AirBnB-only sin WA]
[readiness pills missing] [Property name badge]
```

Con thread/207 muestra adicionalmente un bloque resumen accionable:
```
👤 Andrea M.                    [5 nuevos]  WA
📍 Huerta Cocotera · 👥 5 🐶 · 28 may–1 jun
🔍 In-stay día 2 de 3 · Bloqueado: menú falta · 2h sin respuesta
[preview last msg, si existe]
[readiness pills missing]
```

**El "Resumen estructurado" es 1 línea SEMÁNTICA**, no last_msg free-text. Cubre:
- **Stage context** ("In-stay día 2 de 3", "Pre-stay T-3", "Post-stay ayer")
- **Top blocker** ("menú falta", "pago pendiente $5,452", "ETA desconocido")
- **Urgencia** ("2h sin respuesta", "🔥 in-stay activo")

---

## §1 · Context

### 1.1 Por qué un summary estructurado y no más data libre

Karina abre el inbox y necesita decidir **en <3 segundos** si abrir o pasar. Hoy:
- Preview es last_msg → vacío 40% del tiempo (AirBnB-only bookings)
- Readiness pills muestran lo que falta pero requiere parsing visual
- Days_to_checkin solo dice "T-3d" sin contexto

Un summary estructurado **una línea** combina: stage + blocker top + urgencia. Karina decide más rápido.

### 1.2 ¿Dónde encaja?

| Layer | Item | Status |
|---|---|---|
| spec/196 §4.2.1 InboxRow type | `preview: string` (last msg) | ✅ existe |
| spec/196 §4.4.1 aggregate | computes preview | ✅ existe |
| thread/206 § 4.6 | preview fallback OTA | 🟡 esta semana |
| **thread/207 (este)** | **`summary: StructuredSummary` NUEVO field** | **🔵 propuesto** |
| frontend InboxRow.tsx render | render structured | 🔵 cambio thread/207 |

`preview` se mantiene (último msg cuando existe). `summary` lo COMPLEMENTA, no lo reemplaza. En mobile portrait priorizamos summary; en desktop ambos visibles.

### 1.3 ¿Por qué backend computed y no frontend?

Computar el summary requiere:
- Acceso a booking_captures readiness raw data
- Lifecycle stage detection (lifecycle.ts)
- bot_messages_inbox + conversation history para "última respuesta"
- Lógica de "blocker más importante" según contexto

Todo eso ya vive en backend. Frontend solo necesita render. Mantenemos contrato API thin.

---

## §2 · Explicit scope

### 2.1 IN scope

**Backend (apps/worker-bot):**

| Archivo | Cambio | LoC |
|---|---|---|
| `apps/worker-bot/src/inbox/summary.ts` | NEW — `computeStructuredSummary(booking, readiness, lifecycleStage, ...)` | ~100 |
| `apps/worker-bot/src/inbox/aggregate.ts` | Llamar computeStructuredSummary + agregar `summary` a InboxRow output | +15 modify |
| `apps/worker-bot/tests/inbox/summary.test.ts` | NEW — tests para 8-10 casos canónicos | ~80 |

**Types contract (`apps/web/src/lib/inbox-client.ts`):**

| Cambio | LoC |
|---|---|
| Agregar `StructuredSummary` type | +10 |
| Extender `InboxRow.summary: StructuredSummary | null` | +1 |

**Frontend (apps/web):**

| Archivo | Cambio | LoC |
|---|---|---|
| `apps/web/src/components/inbox/InboxRow.tsx` | Renderizar bloque summary entre stay-info y preview | +25 |
| `apps/web/src/components/inbox/InboxRow.test.tsx` | Tests summary rendering | +30 |
| `apps/web/src/styles/inbox.css` | Estilo `.inbox-row-summary` | +20 |

### 2.2 OUT of scope (NO tocar)

- ❌ Cambios al `preview` existente (mantener fallback OTA thread/206)
- ❌ Database migrations
- ❌ Recomputar readiness (usar lo que aggregate ya computa)
- ❌ Casa Chamán logic
- ❌ Changes a ConversationView/BookingContextSidebar (ese sidebar ya cubre detail rich)
- ❌ Mobile-specific summary variants (1 summary, CSS handle responsive)
- ❌ Internationalization (ES only)

---

## §3 · Type contract `StructuredSummary`

```typescript
export interface StructuredSummary {
  // Una línea principal, 60-80 chars max
  headline: string;
  // Ejemplos:
  //   "Pre-stay T-3, falta menú y pago"
  //   "In-stay día 2 de 3, todo OK"
  //   "AirBnB inquiry sin confirmar, 4h"
  //   "Post-stay ayer, recordar review"

  // Subcomponentes structured (para render granular si hace falta)
  stage_label: string;     // "Pre-stay T-3" | "In-stay día 2 de 3" | "AirBnB inquiry" | etc.
  top_blocker: string | null;  // "Menú pendiente" | "Pago $5,452 MXN pendiente" | null
  urgency_label: string | null; // "🔥 In-stay activo" | "2h sin respuesta" | "Cold >24h" | null

  // Visual hint para frontend coloring
  severity: 'critical' | 'warn' | 'info' | 'muted';
}
```

### 3.1 Reglas de computación `headline`

```
case in_stay_issue:
  headline = `In-stay ${stayDay} de ${totalDays} · ${top_blocker ?? 'monitoring'}`
  severity = 'critical'

case in_stay_ok:
  headline = `In-stay ${stayDay} de ${totalDays} · todo OK`
  severity = 'info'

case pre_stay_imminent (T-2/T-1/T-0):
  headline = `Llega ${daysLabel} · ${top_blocker ?? 'todo listo'}`
  severity = top_blocker ? 'warn' : 'info'

case pre_stay_active (T-3 a T-14):
  headline = `Pre-stay T-${days} · ${top_blocker ?? 'sin bloqueos'}`
  severity = top_blocker ? 'warn' : 'info'

case airbnb_inquiry_unconfirmed:
  headline = `AirBnB inquiry · ${hoursSinceLast}h sin confirmar`
  severity = hoursSinceLast > 4 ? 'warn' : 'info'

case post_stay:
  headline = `Post-stay ${daysAgo === 0 ? 'hoy' : daysAgo + 'd'} · recordar review`
  severity = 'info'

case vip_repeat:
  headline = `VIP · ${totalBookings} estancias previas`
  severity = 'info'

case lead_*:
  headline = `${escalationReason ?? 'Sin contexto'} · ${hoursSinceLast}h`
  severity = bucket === 'lead_needs_human' ? 'critical' : 'muted'
```

### 3.2 Reglas para `top_blocker`

Prioridad ordenada (devuelve el primero que aplique):

1. **Pago** (si `!readiness.paid` y `pre_stay`): `"Pago $${balance} MXN pendiente"`
2. **Reglas** (si `!readiness.rules_accepted` y `pre_stay_imminent` T≤2): `"Falta aceptar reglas"`
3. **Menú** (si `!readiness.menu_decided` y `pre_stay` y la propiedad lo requiere): `"Menú pendiente"`
4. **Mascotas** (si `!readiness.pet_decided`): `"Mascotas sin confirmar"`
5. **Pax** (si `!readiness.pax_confirmed`): `"Pax sin confirmar final"`
6. **ETA** (si `!readiness.eta_known` y `pre_stay_imminent`): `"ETA desconocido"`
7. null si todo OK

**Nota:** in_stay y post_stay generalmente NO tienen blocker (override de §3.1 estado). Si hay critical keyword in-stay, el blocker = el síntoma detectado.

### 3.3 Reglas `urgency_label`

```
if in_stay && has_critical_keyword:
  urgency = "🔥 In-stay crítico"  (severity bumped to 'critical')

if hours_since_last_response > 24 && (lead_* || pre_stay):
  urgency = `${hoursSinceLast}h sin respuesta`

if unread_count >= 3:
  urgency = `${unread_count} msgs sin leer`

else: null
```

---

## §4 · Implementation

### 4.1 NEW `apps/worker-bot/src/inbox/summary.ts`

```typescript
// Structured summary block for inbox row — thread/207
// Provides a one-line accionable insight per row, NOT the last message preview.
// Spec: thread/207 §3

import type { ReadinessScore } from './readiness';
import type { LifecycleStage } from './lifecycle';
import { daysBetween, hoursSince, hasCriticalKeyword } from './lifecycle';

export interface StructuredSummary {
  headline: string;
  stage_label: string;
  top_blocker: string | null;
  urgency_label: string | null;
  severity: 'critical' | 'warn' | 'info' | 'muted';
}

export interface SummaryInput {
  lifecycle_stage: LifecycleStage;
  arrival: string | null;        // YYYY-MM-DD (booking) or null (lead)
  departure: string | null;
  total_bookings: number;
  unread_count: number;
  hours_since_last_response: number;
  last_msg_text: string | null;
  readiness: ReadinessScore | null;
  balance_due_mxn: number | null;
  channel: string | null;
  escalation_reason: string | null;
  room_id: number | null;
}

function computeStayDay(arrival: string, departure: string, today: string): { current: number; total: number } {
  const totalDays = Math.max(daysBetween(arrival, departure), 1);
  const elapsed = Math.max(daysBetween(arrival, today), 0) + 1; // day 1 is arrival day
  return { current: Math.min(elapsed, totalDays), total: totalDays };
}

function pickTopBlocker(input: SummaryInput): string | null {
  const r = input.readiness;
  if (!r) return null;
  const stage = input.lifecycle_stage;
  const isPreStay = stage === 'pre_stay_imminent' || stage === 'pre_stay_active' || stage === 'pre_stay_distant';

  if (!isPreStay) return null;

  if (!r.paid && input.balance_due_mxn != null && input.balance_due_mxn > 0) {
    return `Pago $${input.balance_due_mxn.toLocaleString('es-MX')} MXN pendiente`;
  }
  if (!r.rules_accepted && stage === 'pre_stay_imminent') {
    return 'Falta aceptar reglas';
  }
  if (!r.menu_decided) {
    return 'Menú pendiente';
  }
  if (!r.pet_decided) {
    return 'Mascotas sin confirmar';
  }
  if (!r.pax_confirmed) {
    return 'Pax sin confirmar final';
  }
  if (!r.eta_known && stage === 'pre_stay_imminent') {
    return 'ETA desconocido';
  }
  return null;
}

function pickUrgency(input: SummaryInput): { label: string | null; severityBump?: 'critical' | 'warn' } {
  // In-stay critical override
  if (
    (input.lifecycle_stage === 'in_stay_issue' || input.lifecycle_stage === 'in_stay_ok') &&
    input.last_msg_text &&
    hasCriticalKeyword(input.last_msg_text)
  ) {
    return { label: '🔥 In-stay crítico', severityBump: 'critical' };
  }
  if (input.hours_since_last_response > 24 && input.lifecycle_stage !== 'post_stay' && input.lifecycle_stage !== 'vip_repeat') {
    return { label: `${Math.round(input.hours_since_last_response)}h sin respuesta` };
  }
  if (input.unread_count >= 3) {
    return { label: `${input.unread_count} sin leer` };
  }
  return { label: null };
}

export function computeStructuredSummary(
  input: SummaryInput,
  todayIso = new Date().toISOString().slice(0, 10),
): StructuredSummary {
  const top_blocker = pickTopBlocker(input);
  const urgency = pickUrgency(input);

  let stage_label = '';
  let headline = '';
  let severity: StructuredSummary['severity'] = 'info';

  switch (input.lifecycle_stage) {
    case 'in_stay_issue':
    case 'in_stay_ok': {
      if (input.arrival && input.departure) {
        const { current, total } = computeStayDay(input.arrival, input.departure, todayIso);
        stage_label = `In-stay día ${current} de ${total}`;
        headline = input.lifecycle_stage === 'in_stay_issue'
          ? `${stage_label} · ${top_blocker ?? 'monitoring'}`
          : `${stage_label} · todo OK`;
        severity = input.lifecycle_stage === 'in_stay_issue' ? 'critical' : 'info';
      }
      break;
    }
    case 'pre_stay_imminent': {
      if (input.arrival) {
        const days = daysBetween(todayIso, input.arrival);
        const daysLabel = days === 0 ? 'hoy' : days === 1 ? 'mañana' : `en ${days} días`;
        stage_label = `Llega ${daysLabel}`;
        headline = `${stage_label} · ${top_blocker ?? 'todo listo'}`;
        severity = top_blocker ? 'warn' : 'info';
      }
      break;
    }
    case 'pre_stay_active': {
      if (input.arrival) {
        const days = daysBetween(todayIso, input.arrival);
        stage_label = `Pre-stay T-${days}`;
        headline = `${stage_label} · ${top_blocker ?? 'sin bloqueos'}`;
        severity = top_blocker ? 'warn' : 'info';
      }
      break;
    }
    case 'pre_stay_distant': {
      if (input.arrival) {
        const days = daysBetween(todayIso, input.arrival);
        stage_label = `Pre-stay T-${days}`;
        headline = `${stage_label} · sin urgencia`;
        severity = 'muted';
      }
      break;
    }
    case 'airbnb_inquiry_unconfirmed': {
      stage_label = 'AirBnB inquiry';
      const hours = Math.round(input.hours_since_last_response);
      headline = `${stage_label} · ${hours}h sin confirmar`;
      severity = hours > 4 ? 'warn' : 'info';
      break;
    }
    case 'post_stay': {
      if (input.departure) {
        const daysAgo = daysBetween(input.departure, todayIso);
        const label = daysAgo === 0 ? 'hoy' : daysAgo === 1 ? 'ayer' : `hace ${daysAgo}d`;
        stage_label = `Post-stay ${label}`;
        headline = `${stage_label} · recordar review`;
        severity = 'muted';
      }
      break;
    }
    case 'vip_repeat': {
      stage_label = 'VIP';
      headline = `${stage_label} · ${input.total_bookings} estancias previas`;
      severity = 'info';
      break;
    }
    case 'lead_needs_human': {
      stage_label = 'Necesita humano';
      const reason = input.escalation_reason ?? 'sin contexto';
      const hours = Math.round(input.hours_since_last_response);
      headline = `${stage_label} · ${reason} · ${hours}h`;
      severity = 'critical';
      break;
    }
    case 'lead_bot_failed': {
      stage_label = 'Bot falló';
      const reason = input.escalation_reason ?? 'sin contexto';
      headline = `${stage_label} · ${reason}`;
      severity = 'warn';
      break;
    }
    case 'lead_cold': {
      stage_label = 'Lead frío';
      const hours = Math.round(input.hours_since_last_response);
      headline = `${stage_label} · ${hours}h sin actividad`;
      severity = 'muted';
      break;
    }
  }

  // Apply urgency severity bump
  if (urgency.severityBump === 'critical') severity = 'critical';

  return {
    headline,
    stage_label,
    top_blocker,
    urgency_label: urgency.label,
    severity,
  };
}
```

### 4.2 Modify `apps/worker-bot/src/inbox/aggregate.ts`

```diff
 import { computeReadiness } from './readiness';
+import { computeStructuredSummary, type StructuredSummary } from './summary';
```

Extender `InboxRow` interface:
```diff
 export interface InboxRow {
   id: string;
   ...
   bot_paused_until: string | null;
+  summary: StructuredSummary | null;
 }
```

En el loop del Tab Reservas (después de calcular readiness, lifecycle, daysToCheckin, etc.):

```diff
       rows.push({
         id: `b_${br.beds24_booking_id}`,
         ...
         bot_paused_until: convRow?.bot_paused_until ?? null,
+        summary: computeStructuredSummary({
+          lifecycle_stage: stage,
+          arrival: br.arrival,
+          departure: br.departure,
+          total_bookings: br.total_bookings ?? 0,
+          unread_count: unreadCount,
+          hours_since_last_response: hoursSince,
+          last_msg_text: lastMsgText,
+          readiness,
+          balance_due_mxn: br.balance_due_mxn,
+          channel: br.channel,
+          escalation_reason: null,
+          room_id: br.room_id,
+        }, todayIso),
       });
```

Similar en Tab Leads loop:
```diff
       leadRows.push({
         id: `conv_${conv.subscriber_id}`,
         ...
         bot_paused_until: conv.bot_paused_until,
+        summary: computeStructuredSummary({
+          lifecycle_stage: stage,
+          arrival: null,
+          departure: null,
+          total_bookings: 0,
+          unread_count: 1, // computed elsewhere
+          hours_since_last_response: hoursSinceLast,
+          last_msg_text: lastMsgText,
+          readiness: null,
+          balance_due_mxn: null,
+          channel: 'whatsapp',
+          escalation_reason: escalationReason,
+          room_id: null,
+        }, todayIso),
       });
```

### 4.3 Frontend types `apps/web/src/lib/inbox-client.ts`

```diff
+export interface StructuredSummary {
+  headline: string;
+  stage_label: string;
+  top_blocker: string | null;
+  urgency_label: string | null;
+  severity: 'critical' | 'warn' | 'info' | 'muted';
+}

 export interface InboxRow {
   id: string;
   ...
   bot_paused_until: string | null;
+  summary: StructuredSummary | null;
 }
```

### 4.4 Frontend render `apps/web/src/components/inbox/InboxRow.tsx`

Agregar el bloque summary entre stay-info y preview:

```diff
   return (
     <div
       className="inbox-row"
       ...
     >
       {/* Name + unread + stay-info */}
       <div className="inbox-row-name">...</div>

       {/* Timestamp */}
       <div className="inbox-row-time">{fmtRelative(row.last_msg_at)}</div>

+      {/* NEW: Structured summary block */}
+      {row.summary && (
+        <div className={`inbox-row-summary inbox-row-summary-${row.summary.severity}`}>
+          <span className="inbox-row-summary-headline">{row.summary.headline}</span>
+          {row.summary.urgency_label && (
+            <span className="inbox-row-summary-urgency">{row.summary.urgency_label}</span>
+          )}
+        </div>
+      )}

       {/* Preview (existing, last msg) */}
       <div className="inbox-row-preview" title={row.preview}>
         {row.preview}
       </div>
       ...
     </div>
   );
```

### 4.5 CSS `apps/web/src/styles/inbox.css`

```css
.inbox-row-summary {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  font-size: var(--fs-sm);
  margin: var(--sp-1) 0;
}

.inbox-row-summary-headline {
  font-weight: 500;
}

.inbox-row-summary-urgency {
  font-size: var(--fs-xs);
  padding: 2px 6px;
  border-radius: 999px;
  background: var(--color-bg-subtle);
}

.inbox-row-summary-critical .inbox-row-summary-headline { color: #dc2626; }
.inbox-row-summary-warn     .inbox-row-summary-headline { color: #c47b00; }
.inbox-row-summary-info     .inbox-row-summary-headline { color: var(--color-text); }
.inbox-row-summary-muted    .inbox-row-summary-headline { color: var(--color-text-muted); }

.inbox-row-summary-critical .inbox-row-summary-urgency {
  background: #fee2e2;
  color: #b91c1c;
}
```

---

## §5 · Tests

### 5.1 NEW `apps/worker-bot/tests/inbox/summary.test.ts`

Casos canónicos a cubrir:

```typescript
import { describe, it, expect } from 'vitest';
import { computeStructuredSummary } from '../../src/inbox/summary';

describe('computeStructuredSummary (thread/207)', () => {
  // Helper: defaults
  const baseInput = {
    arrival: null,
    departure: null,
    total_bookings: 0,
    unread_count: 0,
    hours_since_last_response: 1,
    last_msg_text: null,
    readiness: null,
    balance_due_mxn: null,
    channel: 'airbnb',
    escalation_reason: null,
    room_id: 78695,
  };

  const fullReadiness = {
    pax_confirmed: true, pet_decided: true, menu_decided: true,
    eta_known: true, rules_accepted: true, paid: true, score: 6,
  };

  it('in_stay_ok: shows day X de Y · todo OK', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'in_stay_ok',
      arrival: '2026-05-22', departure: '2026-05-26',
      readiness: fullReadiness,
    }, '2026-05-24');
    expect(result.headline).toBe('In-stay día 3 de 4 · todo OK');
    expect(result.severity).toBe('info');
  });

  it('in_stay_issue with critical keyword bumps severity', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'in_stay_issue',
      arrival: '2026-05-23', departure: '2026-05-26',
      readiness: fullReadiness,
      last_msg_text: 'la luz no funciona, urgente',
    }, '2026-05-24');
    expect(result.headline).toContain('In-stay');
    expect(result.urgency_label).toBe('🔥 In-stay crítico');
    expect(result.severity).toBe('critical');
  });

  it('pre_stay_active: T-3 with menu pending', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'pre_stay_active',
      arrival: '2026-05-27',
      readiness: { ...fullReadiness, menu_decided: false, paid: false, balance_due_mxn: 5452 },
      balance_due_mxn: 5452,
    }, '2026-05-24');
    expect(result.headline).toBe('Pre-stay T-3 · Pago $5,452 MXN pendiente'); // pago wins over menu by §3.2 priority
    expect(result.severity).toBe('warn');
  });

  it('pre_stay_imminent: T-1 with all OK', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'pre_stay_imminent',
      arrival: '2026-05-25',
      readiness: fullReadiness,
    }, '2026-05-24');
    expect(result.headline).toBe('Llega mañana · todo listo');
    expect(result.severity).toBe('info');
  });

  it('pre_stay_imminent: T-0 hoy', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'pre_stay_imminent',
      arrival: '2026-05-24',
      readiness: fullReadiness,
    }, '2026-05-24');
    expect(result.headline).toContain('Llega hoy');
  });

  it('airbnb_inquiry_unconfirmed: 6h sin confirmar = warn', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'airbnb_inquiry_unconfirmed',
      hours_since_last_response: 6,
    }, '2026-05-24');
    expect(result.headline).toContain('AirBnB inquiry');
    expect(result.headline).toContain('6h sin confirmar');
    expect(result.severity).toBe('warn');
  });

  it('post_stay yesterday: recordar review', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'post_stay',
      departure: '2026-05-23',
    }, '2026-05-24');
    expect(result.headline).toBe('Post-stay ayer · recordar review');
    expect(result.severity).toBe('muted');
  });

  it('vip_repeat: shows total bookings', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'vip_repeat',
      total_bookings: 5,
    }, '2026-05-24');
    expect(result.headline).toContain('5 estancias previas');
  });

  it('lead_needs_human: critical severity', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'lead_needs_human',
      escalation_reason: 'pidió asesor',
      hours_since_last_response: 2,
    }, '2026-05-24');
    expect(result.headline).toContain('Necesita humano');
    expect(result.headline).toContain('pidió asesor');
    expect(result.severity).toBe('critical');
  });

  it('unread_count >= 3 sets urgency label', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'pre_stay_active',
      arrival: '2026-05-27',
      readiness: fullReadiness,
      unread_count: 5,
    }, '2026-05-24');
    expect(result.urgency_label).toBe('5 sin leer');
  });

  it('hours > 24h without response triggers urgency for pre-stay', () => {
    const result = computeStructuredSummary({
      ...baseInput,
      lifecycle_stage: 'pre_stay_active',
      arrival: '2026-05-30',
      readiness: fullReadiness,
      hours_since_last_response: 30,
    }, '2026-05-24');
    expect(result.urgency_label).toBe('30h sin respuesta');
  });
});
```

### 5.2 EXTEND `apps/web/src/components/inbox/InboxRow.test.tsx`

```typescript
describe('InboxRow summary rendering (thread/207)', () => {
  it('renders summary headline when summary is present', () => {
    const row = makeRow({
      summary: {
        headline: 'Pre-stay T-3 · Menú pendiente',
        stage_label: 'Pre-stay T-3',
        top_blocker: 'Menú pendiente',
        urgency_label: null,
        severity: 'warn',
      },
    });
    render(<InboxRow row={row} onClick={vi.fn()} />);
    expect(screen.getByText('Pre-stay T-3 · Menú pendiente')).toBeInTheDocument();
  });

  it('applies severity-specific CSS class', () => {
    const row = makeRow({
      summary: { headline: 'In-stay crítico', stage_label: '', top_blocker: null, urgency_label: '🔥 In-stay crítico', severity: 'critical' },
    });
    const { container } = render(<InboxRow row={row} onClick={vi.fn()} />);
    expect(container.querySelector('.inbox-row-summary-critical')).toBeInTheDocument();
  });

  it('renders urgency_label when present', () => {
    const row = makeRow({
      summary: { headline: 'Lead frío · 30h', stage_label: 'Lead frío', top_blocker: null, urgency_label: '30h sin respuesta', severity: 'muted' },
    });
    render(<InboxRow row={row} onClick={vi.fn()} />);
    expect(screen.getByText('30h sin respuesta')).toBeInTheDocument();
  });

  it('skips summary block when summary is null', () => {
    const row = makeRow({ summary: null });
    const { container } = render(<InboxRow row={row} onClick={vi.fn()} />);
    expect(container.querySelector('.inbox-row-summary')).not.toBeInTheDocument();
  });
});
```

---

## §6 · Definition of Done

- [ ] Branch `feat/inbox-structured-summary`
- [ ] Backend:
  - [ ] `apps/worker-bot/src/inbox/summary.ts` (NEW ~100 LoC)
  - [ ] `apps/worker-bot/src/inbox/aggregate.ts` modify (+15 LoC, llamadas en ambos loops)
  - [ ] `apps/worker-bot/tests/inbox/summary.test.ts` (NEW ~80 LoC, 11 tests mínimo)
- [ ] Types:
  - [ ] `apps/web/src/lib/inbox-client.ts` (+11 LoC, StructuredSummary type + InboxRow.summary)
- [ ] Frontend:
  - [ ] `apps/web/src/components/inbox/InboxRow.tsx` (+25 LoC)
  - [ ] `apps/web/src/components/inbox/InboxRow.test.tsx` (+30 LoC, 4 tests)
  - [ ] `apps/web/src/styles/inbox.css` (+20 LoC)
- [ ] `pnpm --filter worker-bot typecheck` PASS
- [ ] `pnpm --filter worker-bot test` verde (incl. 11 summary tests nuevos)
- [ ] `pnpm --filter web typecheck` PASS
- [ ] `pnpm --filter web test` verde (incl. 4 InboxRow tests nuevos)
- [ ] Commit: `feat(inbox): structured summary block per row (thread/207)`
- [ ] PR body referencia thread/207 + thread/204 §3.1
- [ ] ⚠️ MANUAL `npx wrangler deploy` POST-MERGE

---

## §7 · Risks + Mitigations

| Risk | Mitigation |
|---|---|
| Summary headline corre largo y rompe layout | `text-overflow: ellipsis` en CSS + max 80 chars guideline en compute |
| Severity 'critical' overflo en visual con muchas rows | OK por diseño: rows críticos DEBEN llamar atención |
| Backend cost overhead computar summary cada row | Pure function, no DB queries adicionales — costo trivial |
| Frontend breaks si backend devuelve summary=null | Frontend valida `row.summary && ...` antes de render |
| Test cases no cubren todos lifecycle stages | §5.1 cubre 11 stages explícitos |
| top_blocker mismatch con readiness real | Mismo readiness es input — no race condition |
| Conflicto con thread/206 cambios en aggregate.ts | thread/206 modifica preview/unread/last_msg. thread/207 agrega summary. Diff disjuntos → merge clean |
| `escalation_reason` para leads requires parse pending_handoff_data | aggregate ya hace ese parse, pass directly |

---

## §8 · Out-of-scope findings

Si CC encuentra:
- Otros lugares que se beneficiarían del summary (ej. BookingContextSidebar) → issue [thread/207 OOS], no implementar ahora
- Bugs preexistentes en lifecycle.ts → defer
- Casos lifecycle no cubiertos en §3.1 → reportar pero usar default fallback `stage_label === '' ? '—' : stage_label`
- ALTER TABLE needed → NO, post-Wave 1.5

---

## §9 · Kickoff command (Alex pegará a CC)

```
DoIt thread/207: Inbox row structured summary block. Backend + types + frontend en 1 PR (scope narrow).

Pre-requisito: threads/205 + thread/206 ya merged y deployed (P0 frontend + backend).

Lee spec completa:
c:/dev/rdm/dev/discussion/threads/207-wc-cc-inbox-structured-summary.md

Sigue §4 implementation exacto. Self-review §6 DoD antes de commit.

Working directory: c:/dev/rdm/dev/bot

Pre-flight:
1. cd c:/dev/rdm/dev/bot
2. git checkout main
3. git pull origin main
4. git log --oneline -5 — confirma thread/205 + thread/206 merged

Execution:
1. git checkout -b feat/inbox-structured-summary
2. Crear apps/worker-bot/src/inbox/summary.ts según §4.1 (NEW ~100 LoC)
3. Editar apps/worker-bot/src/inbox/aggregate.ts según §4.2 (+15 LoC, import + 2 loop additions)
4. Crear apps/worker-bot/tests/inbox/summary.test.ts según §5.1 (11 tests mínimo)
5. Editar apps/web/src/lib/inbox-client.ts según §4.3 (+11 LoC StructuredSummary type)
6. Editar apps/web/src/components/inbox/InboxRow.tsx según §4.4 (+25 LoC summary block render)
7. Editar apps/web/src/components/inbox/InboxRow.test.tsx según §5.2 (+30 LoC, 4 tests)
8. Editar apps/web/src/styles/inbox.css según §4.5 (+20 LoC)
9. pnpm --filter worker-bot typecheck — PASS
10. pnpm --filter worker-bot test — verde
11. pnpm --filter web typecheck — PASS
12. pnpm --filter web test — verde
13. git diff main --stat (~7 archivos)
14. git add archivos especificados
15. git commit -m "feat(inbox): structured summary block per row (thread/207)"
16. git push -u origin feat/inbox-structured-summary
17. gh pr create con title "feat(inbox): structured summary block per row (thread/207)" y body:
    - Closes thread/207, cierra gap thread/204 §3.1
    - Agrega summary estructurado por row (no es last_msg)
    - Cubre 11 lifecycle stages con headline + top_blocker + urgency_label + severity
    - ⚠️ MANUAL `npx wrangler deploy` REQUIRED post-merge

Scope ESTRICTO:
- apps/worker-bot/src/inbox/summary.ts (NEW)
- apps/worker-bot/src/inbox/aggregate.ts (modify, only summary integration)
- apps/worker-bot/tests/inbox/summary.test.ts (NEW)
- apps/web/src/lib/inbox-client.ts (modify, only types)
- apps/web/src/components/inbox/InboxRow.tsx (modify, only summary block)
- apps/web/src/components/inbox/InboxRow.test.tsx (modify, only summary tests)
- apps/web/src/styles/inbox.css (modify, only summary classes)

NO ejecutes:
- pnpm test completo
- Otras inbox file changes
- BookingContextSidebar (out of scope)
- Migrations
- ALTER TABLE
- wrangler deploy (Alex post-merge)

Si encuentras algo fuera de scope → issue [thread/207 OOS].

Bloqueado >30 min sub-tarea = STOP y reporta.

Reportar al final con:
- summary.ts creado
- aggregate.ts integración en 2 loops (reservas + leads)
- 11 tests summary.test PASS
- 4 tests InboxRow.test.tsx PASS
- typecheck + tests PASS
- PR URL
- ⚠️ Smoke test post-deploy:
  - /admin/inbox tab Reservas → cada row muestra summary headline + (opcional) urgency
  - Booking pre-stay sin pago: "Pre-stay T-3 · Pago $X MXN pendiente"
  - In-stay OK: "In-stay día X de Y · todo OK"
  - Booking AirBnB inquiry: "AirBnB inquiry · Xh sin confirmar"

GO.
```

---

## §10 · Verification visual esperada

Antes (hoy):
```
👤 Andrea Mendoza               [5 nuevos]  [WA]
📍 Huerta Cocotera · 👥 5 🐶 · T-3d
(preview vacío — AirBnB only)
[○ Menú] [○ ETA] [○ Reglas] ✓3   [Property]
```

Después (thread/207):
```
👤 Andrea Mendoza               [5 nuevos]  [WA]
📍 Huerta Cocotera · 👥 5 🐶 · T-3d
⚠ Pre-stay T-3 · Menú pendiente              [3h sin respuesta]
(preview if exists)
[○ Menú] [○ ETA] [○ Reglas] ✓3   [Property]
```

En CSS:
- Severity 'warn' → headline naranja
- Severity 'critical' → headline rojo + urgency badge fondo rojo
- Severity 'info' → headline normal text
- Severity 'muted' → headline gris

---

## §11 · References

- thread/204 §3.1 "Texto informativo estructurado" (origen pedido Alex)
- thread/196 §4.2.1 `InboxRow.preview` (preview que NO reemplazamos)
- thread/202 (5 decisiones gap analysis previas)
- thread/206 (preview/unread/last_msg fallback OTA, contexto)
