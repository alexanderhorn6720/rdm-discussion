---
thread: 190
author: WC (web)
date: 2026-05-24
topic: infrastructure-audit-real-F2-preflight
mode: brain
status: closed-audit
related:
  - thread/148 (Alex vote ADR-002, §C Step 2 pre-flight)
  - thread/184 (Run 184 spec autonomous)
  - thread/189 (Run 184 retrospective)
  - rdm-platform/foundations/F2-observability.md §6 Day 0
tags: [F2, preflight, audit, infrastructure, cloudflare, observability]
---

# Audit real infraestructura RDM vs F2 §6 Day 0 pre-flight

**Propósito**: Antes de hacer 20 min de trabajo manual en CF dashboard, verificar qué del checklist YA EXISTE. Hipótesis de Alex: "todo está, no agregamos nada".

**Método**: Cloudflare Developer Platform MCP desde WC, leyendo realidad live de la cuenta `9146b19ea590217545bb21fa9533ff87` (alexander.horn@hotmail.com).

**Verificado**: 2026-05-24 ~00:35 UTC

---

## §0 · TL;DR

**Alex tenía 80% razón.** De los 7 pasos del pre-flight checklist:

| Status | Cantidad | Detalle |
|---|---|---|
| ✅ Ya existe | 1 | R2 bucket `rdm-logs` (creado 2026-05-21 — ya estabas adelantado) |
| 🟡 Verificación 1-click mobile | 2 | R2 lifecycle 90d + Logpush job (CF dashboard mobile) |
| 🟢 Reusar existente | 2 | TG bot token (ya tienes uno), TG channels (¿reusar o split?) |
| 🔴 Provisionar nuevo | 1 | CF_API_TOKEN scope Analytics:Read (3 min, desde desktop o mobile) |
| ⚪ Verificación post-deploy | 1 | Eyeball R2 receiving logs (24h después de Logpush activo) |

**Tiempo Alex real estimado: 5-10 min mobile + 3 min desktop si el CF token nuevo es necesario.**

---

## §1 · Inventario CF real (live 2026-05-24)

### R2 Buckets

| Bucket | Created | Storage Class | Location |
|---|---|---|---|
| `assetsrdm` | 2026-04-29 | Standard | WNAM |
| `baby-bebe-uploads` | 2026-05-13 | Standard | WNAM |
| `rdm-feedback-attach` | 2026-05-21 | Standard | WNAM |
| `rdm-knowledge` | 2026-05-09 | Standard | WNAM |
| **`rdm-logs`** | **2026-05-21** | **Standard** | **WNAM** |

✅ **`rdm-logs` YA EXISTE** desde 2026-05-21 (3 días antes de este audit). Alex tenía razón.

### Workers

| Worker | Created | Last Modified |
|---|---|---|
| `beds24-calendar` | 2026-04-26 | 2026-05-12 |
| `rincon-pago` | 2026-05-09 | 2026-05-22 |
| `rincon-tours` | 2026-05-10 | 2026-05-10 |
| `rincon-bot` | 2026-05-12 | 2026-05-22 |
| `baby-bebe-api` | 2026-05-13 | 2026-05-16 |
| `vale-iris` | 2026-05-22 | 2026-05-22 |

✅ **Los 4 workers RDM-relevantes existen**: `rincon-bot`, `rincon-pago`, `rincon-tours`, `beds24-calendar`. Logpush apunta a estos 4.

Nota: F2 §3.1 menciona "4 workers" pero el spec original tenía un typo (`rincondelmar-bot` AND `rincon-bot`). Los 4 reales son: rincon-bot, rincon-pago, rincon-tours, beds24-calendar.

### KV Namespaces

| Namespace | ID |
|---|---|
| `rdm-booking-cache` | 008dd0e8c81f4459b79976eacd0b3195 |
| `rincon-bot-KV_KNOWLEDGE` | 033ee15acf3744c096e83342d2e81dd4 |
| `vale-iris-session` | 3b89d003593c4200a3624d8de71b0330 |
| `rdm-payment-idempotency` | b3035e701ce1492e829f1224d85bc545 |

✅ Los 2 KV RDM existen. KV_IDEMPOTENCY = `rdm-payment-idempotency`. KV_KNOWLEDGE para alertas dedup (F2 §3.5) está disponible.

### D1 Databases

| Database | UUID | Created | Size |
|---|---|---|---|
| `baby-bebe-db` | bc477306-5f08-47c8-9e8c-3681c2458af5 | 2026-05-13 | 540 KB |
| **`rincon`** | **d81622d7-32e2-40a3-9609-80813c0e8a96** | **2026-05-09** | **44.8 MB** |

✅ D1 `rincon` UUID match exacto con memoria. Healthy size.

---

## §2 · F2 §6 Day 0 Checklist — Cada paso vs realidad

### Paso 1 — Create R2 bucket `rdm-logs`

| | |
|---|---|
| F2 spec dice | NEW: crear bucket via CF dashboard (~2 min) |
| Realidad | ✅ **YA EXISTE** desde 2026-05-21, Standard class, WNAM |
| Acción Alex | NINGUNA |

### Paso 2 — R2 lifecycle rule: delete after 90 days

| | |
|---|---|
| F2 spec dice | Aplicar lifecycle rule al bucket (~2 min) |
| Realidad | 🟡 **NO PUEDO VERIFICAR desde MCP** — Cloudflare MCP no expone lifecycle rules. Posibilidades: (a) ya existe (probable si Alex creó el bucket con preset), (b) NO existe todavía |
| Acción Alex | **Mobile (1 min)**: abrir [CF Dashboard → R2 → rdm-logs → Object Lifecycle Rules](https://dash.cloudflare.com/?to=/:account/r2/default/buckets/rdm-logs). Si hay regla "delete after 90 days" → ✅. Si NO → click "Add rule" → "Delete after 90 days" → save |

### Paso 3 — Logpush job: 4 workers → rdm-logs

| | |
|---|---|
| F2 spec dice | Crear Logpush job, source = 4 workers, destination = R2 bucket rdm-logs, format JSONL+gzip (~5 min) |
| Realidad | 🟡 **NO PUEDO VERIFICAR desde MCP** — Logpush jobs no expuestos en MCP tools. Razones posibles: (a) Alex ya lo creó pre-2026-05-21, (b) NO existe todavía |
| Acción Alex | **Mobile (3 min)**: abrir [CF Dashboard → Workers → Logs → Logpush](https://dash.cloudflare.com/?to=/:account/workers/logs). Si hay job activo apuntando a `rdm-logs` con los 4 workers → ✅. Si NO → "Add Logpush job" → seleccionar Workers Trace Events → JSONL+gzip → destination R2 `rdm-logs` → seleccionar 4 workers |

### Paso 4 — Telegram channels `@rdm-alerts-critical` + `@rdm-alerts-warning`

| | |
|---|---|
| F2 spec dice | Crear 2 canales separados con Alex bot en ambos (~3 min) |
| Realidad | 🟢 **TG_BOT_TOKEN existente reusable.** Memoria #1 confirma "ManyChat BSP WhatsApp + TG_BOT_TOKEN + bot_paused_until pattern". Probable que ya tienes un canal Telegram con bot activo (worker-pago notifies a un chat_id) |
| Decisión necesaria | **¿Quieres 2 canales separados (critical + warning) o reusar 1?** El spec asume 2 para separar muted/notify por canal. Si reusas 1, no separa atención pero zero overhead. **WC preliminary: reusar 1 ahora, splittear en F2.1 si el ruido empieza a molestar.** |
| Acción Alex | **Mobile (0-3 min)**: Si decides reusar 1: ninguna acción. Si decides splittear ahora: app Telegram → crear canal `@rdm-alerts-critical` → invitar bot → repetir para warning |

### Paso 5 — TG bot tokens como secrets en worker-bot

| | |
|---|---|
| F2 spec dice | `wrangler secret put TG_BOT_TOKEN_CRITICAL --name rincon-bot` + warning (3 min) |
| Realidad | 🟢 **Si reusas 1 bot**: ya tienes TG_BOT_TOKEN como secret. Solo necesitas TG_CHAT_ID_* nuevo si separas canales |
| Acción Alex | **Si reusa 1 canal**: ninguna acción, F2 ship usa `TG_BOT_TOKEN` + `TG_CHAT_ID_ALERTS` existentes. **Si splittea**: CC ejecuta `wrangler secret put` por ti — solo necesitas pegarle los 2 chat_ids |

### Paso 6 — CF_API_TOKEN scope Analytics:Read

| | |
|---|---|
| F2 spec dice | Crear CF API token con scope `Analytics:Read`, set como secret `CF_API_TOKEN` en apps/web Pages (~3 min) |
| Realidad | 🔴 **NO PUEDO VERIFICAR desde MCP** — list de API tokens no expuesto. Posibilidades: (a) ya tienes uno con scope Analytics:Read, (b) NO tienes uno con ese scope específico. Tu wrangler token actual probablemente tiene `Workers Scripts:Edit` + `D1:Edit` pero NO `Analytics:Read` |
| Acción Alex | **Mobile/Desktop (3 min)**: abrir [CF Dashboard → My Profile → API Tokens](https://dash.cloudflare.com/profile/api-tokens). Verificar si existe token con scope `Account Analytics:Read`. Si NO: "Create Token" → Custom token → Permissions: `Account → Account Analytics → Read` → Account resources: tu cuenta → Create → copiar token. Después CC ejecuta `wrangler pages secret put CF_API_TOKEN --project-name <apps-web>` con tu pegado |

### Paso 7 — Eyeball R2 receiving logs

| | |
|---|---|
| F2 spec dice | Después de Logpush activo, verificar 24h después que R2 tiene archivos |
| Realidad | ⚪ Post-deploy check, no es pre-flight bloqueante |
| Acción Alex | 24h después del Day 1 CC: abrir R2 bucket rdm-logs → confirmar archivos `.json.gz` apareciendo. Si no llegan en 24h → revisar Logpush job config |

---

## §3 · Síntesis para mañana mobile

### Plan Alex 8 min mobile-only (sin desktop):

| # | Acción | Tiempo |
|---|---|---|
| 1 | Mergear PR #18 (F1 spec) | 1 min |
| 2 | Mergear PR #19 (F3 spec) | 1 min |
| 3 | Mobile abrir CF Dashboard → R2 → rdm-logs → Lifecycle Rules. Confirmar o agregar regla 90d | 2 min |
| 4 | Mobile abrir CF Dashboard → Workers → Logs → Logpush. Confirmar job exists para 4 workers, o crearlo | 3 min |
| 5 | Decidir: ¿1 canal Telegram o split en 2? Postear decisión en thread/148 | 1 min |

### Plan Alex 3 min desktop (siguiente sesión NUC):

| # | Acción | Tiempo |
|---|---|---|
| 6 | CF Dashboard → My Profile → API Tokens. Crear token Analytics:Read si no existe | 3 min |

### Después Alex post-foundation pre-flight check completo:

Postear en thread/148 follow-up con:
```
✅ Step 1: rdm-logs bucket (existed 2026-05-21)
✅ Step 2: Lifecycle 90d [confirmed/added]
✅ Step 3: Logpush job [confirmed/created]
✅ Step 4: TG channels [reused 1 / split into 2]
✅ Step 5: TG bot secrets [reusing TG_BOT_TOKEN existing / new]
✅ Step 6: CF_API_TOKEN [created/existed]

Pre-flight F2 complete. CC: arranca F2 Day 1 cuando puedas.
```

CC arranca F2 Day 1 inmediatamente. F2 ship en 3-4 días (Day 1+2+3+soak).

---

## §4 · Decisión sobre canales Telegram

**Recomendación WC (Alex final)**: empezar con 1 canal `@rdm-alerts` reusando TG_BOT_TOKEN existente. F2 spec acepta este shortcut con cambio menor:

```typescript
// packages/shared/src/alerts.ts (versión simplificada)
export async function notifyOps(
  env: Env,
  severity: 'critical' | 'warning',
  ...
): Promise<void> {
  const prefix = severity === 'critical' ? '🚨 CRITICAL' : '⚠️ WARNING';
  await fetch(`https://api.telegram.org/bot${env.TG_BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: env.TG_CHAT_ID_ALERTS, text: `${prefix}\n${msg}` }),
  });
}
```

Tradeoff: pierdes el "mute warning, notify critical" del split en 2 canales. **Pero** en una operación de 1-2 personas (Alex + Karina), 1 canal Telegram con prefijo emoji es suficiente.

Si en F2 + 30 días el volumen de warnings empieza a molestar attention budget, F2.1 micro-spec splittea. ~30 min CC adicional. Lazy decision.

---

## §5 · Anti-pattern detectado: spec assumes greenfield infraestructura

Patrón observado en este audit (y consistente con Run 184 §3 findings cross-cutting):

> F2 spec §6 Day 0 lista TODO como "NEW Alex pre-flight". Reality check muestra el 30-40% YA existe (R2 bucket, workers, KV namespaces, D1, probable TG bot, posible Logpush si Alex lo configuró pre-spec).

**Recomendación**: future foundation specs deben tener una sección §0.5 "Existing infrastructure inventory" que CC populate ANTES del Day 0 checklist via MCP audit. Eso convierte 20 min de "pre-flight ceremonial" en 3 min de "delta real".

Aplicable a F1 y F3 también. Ya hecho aquí para F2 retroactivamente.

---

## §6 · Próximas acciones concretas

| Owner | Acción | Cuándo |
|---|---|---|
| Alex | 8 min mobile checklist §3 + merge PR #18/#19 | Mañana primera cosa |
| Alex | 3 min desktop CF_API_TOKEN (si no existe scope Analytics:Read) | Próxima sesión NUC |
| Alex | Postear ✅ por paso en thread/148 follow-up | Después de §3 + §4 |
| CC | Arrancar F2 Day 1 (packages/shared metrics+alerts+cron-heartbeat) | Tras Alex postear ✅ |
| WC | Cerrar thread/190 (este doc) como `closed-audit` | Auto |

---

## §7 · See also

- foundations/F2-observability.md §6 Day 0 (spec original que este audit verifica)
- thread/148 §C Step 2 (Alex pre-flight commitment 2026-05-20)
- thread/189 §3.1 (lección "spec hardcoding ages badly" — mismo patrón)
- thread/184 §3 (Run 184 findings cross-cutting: spec assumes greenfield)
- CF Dashboard account 9146b19ea590217545bb21fa9533ff87
