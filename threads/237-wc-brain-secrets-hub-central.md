---
thread: 237
author: wc
topic: secrets-hub-central
status: decided
mode: brain deep
workstream: WC-Platform
blocks: nada (no es critical-path)
related: 234 (incidente), 235 (crons nativos), 236 (CC completion 235)
decision: Opción 2 (Alex 2026-05-30) — ejecución en thread/238
created: 2026-05-30
---

# Brain deep — Hub central de secrets/tokens (Workstream B)

MODE: brain deep (decisión arquitectural)

**RESUELTO**: Alex votó Opción 2 (2026-05-30). Modelo: un master plano, todos los
targets reciben todas las claves, backup age. Ejecución → thread/238 (DoIt).

---

## §1. Contexto

### Objetivo (Alex)
Un solo lugar para todos los tokens/secrets, accesible para todos los workers,
Pages y demás. Eliminar el drift que rompió la operación el 2026-05-29
(GitHub Secrets ≠ worker → 401 en toda la capa scheduled). Ya existe un
**file local con el inventario completo** (levantamiento previo).

### Estado tras Workstream A (crons nativos)
Importante para la decisión: el cron nativo **elimina GitHub de la operación
diaria**. Tras A, `ADMIN_REFRESH_SECRET` deja de usarse para crons. El drift
worker↔GitHub — la causa exacta del incidente — desaparece como clase.

Lo que queda por resolver del objetivo del hub:
- Duplicación de secrets entre workers (BEDS24_TOKEN, MP, etc. en worker-bot +
  worker-pago) — cada uno seteado y rotado a mano.
- Sin fuente única de verdad propagada confiablemente a todos los runtimes.
- `sync-secret.sh` solo cubre workers, uno a la vez, manual.

---

## §2. Hallazgos verificados de producto (2026-05-30)

Decisivos para la viabilidad. Todos confirmados en doc CF.

| # | Hallazgo | Fuente |
|---|---|---|
| H1 | Secrets Store es **open beta** | docs "Overview Beta" |
| H2 | **Un store por cuenta** (sin aislamiento prod/dev/staging nativo) | wrangler secrets-store docs |
| H3 | **Solo soporta Workers. NO Pages.** ("currently supports only Cloudflare Workers") | blog beta + integraciones |
| H4 | El binding **NO devuelve string** — acceso async `await env.BINDING.get()` | integración Workers, §3 |
| H5 | RBAC real (Super Admin / Secrets Store Admin / Deployer) + audit logging | access-control docs |
| H6 | Binding vía `[[secrets_store_secrets]]` en wrangler.toml (binding + store_id + secret_name) | integración Workers, §2 |
| H7 | Tu wrangler 4.14.1 marca `secrets-store [alpha]`; actual 4.95 lo trata como beta | tool list + deploy output |

### Consecuencia de H4 (la más cara)
El código actual usa secrets como **strings síncronos**: `env.ANTHROPIC_API_KEY!`,
headers `token: env.BEDS24_TOKEN`, params a funciones. Secrets Store obliga a
`await env.X.get()`. Migrar worker-bot (15+ secrets, usados en decenas de sitios,
muchos sync) NO es drop-in. Mitigable con wrapper de bootstrap (§4.3) pero es
refactor real, no un cambio de binding.

### Consecuencia de H3
apps/web (Pages, rincondelmar.club) **no puede** bindear Secrets Store. Se queda
en secrets per-project. O sea: "hub para TODO" no es posible hoy con Secrets Store
puro. El hub real sería "hub para Workers; Pages aparte".

---

## §3. Opciones + tradeoffs

| | Opción 1 — Secrets Store puro | Opción 2 — Master local + propagación | Opción 3 — Híbrido |
|---|---|---|---|
| Hub en CF | Sí (account-level real) | No (master local, CF recibe copias) | Parcial (shared en Store) |
| Cubre Pages | **No** (H3) | **Sí** (`wrangler pages secret put`) | Sí (Pages vía propagación) |
| Cambio de código | **Alto** (H4, async `.get()`) | **Cero** (sigue string) | Alto solo en workers migrados |
| RBAC + audit | **Sí** (H5) | No (control = acceso al file) | Sí para shared |
| Riesgo beta | Sí (H1) | No | Acotado a shared |
| Rotación centralizada | Sí | Sí (edita master, corre sync) | Mixto |
| Esfuerzo | Alto | Bajo (~2-3h) | Medio→Alto |
| DRY (no duplicar) | Sí | No (copia a cada target) | Sí para shared |

### Opción 2 en detalle (elegida)
- **Master**: el file de inventario local que ya existe = fuente única de verdad.
  Backup cifrado age obligatorio. El riesgo "se pierde la máquina" se mitiga así.
- **Propagación**: `sync-all.sh` idempotente que lee el master y empuja a CADA
  target: `wrangler secret put` por worker + `wrangler pages secret put` para apps/web.
- Es el "hub funcional": un master, un comando, todos los runtimes sincronizados.
  No es account-level en CF, pero resuelve el problema operacional real.
- Modelo Alex: **todos los targets reciben todas las claves** (un file plano, sin
  secciones). Acepta mayor superficie a cambio de simplicidad.

### Opción 3 (evolución futura)
- Secrets COMPARTIDOS (BEDS24_TOKEN, MP_ACCESS_TOKEN, los que viven en ≥2 workers)
  → Secrets Store, por DRY + RBAC + audit. Refactor async solo en esos accesos.
- Resto + Pages → master local + propagación (Opción 2).
- Migrar a Store cuando salga de beta o cuando el valor de RBAC/audit lo justifique.

---

## §4. Recomendación WC (confirmada por Alex)

**Opción 2 ahora, Opción 3 como evolución selectiva. NO Opción 1 pura hoy.**

Razones:
1. El dolor agudo (drift worker↔GitHub) ya lo mató Workstream A. Lo que queda es
   DRY + propagación confiable, que Opción 2 resuelve con cero refactor y cero beta.
2. Opción 1 pura es inviable para el objetivo "todo": deja Pages fuera (H3).
3. El refactor async (H4) es costo real sin beneficio operacional inmediato —
   RBAC/audit son valiosos pero no urgentes para una operación de 1 persona + Karina.
4. Opción 2 es reversible y compatible: si mañana migras shared a Store (Opción 3),
   el master local sigue siendo la fuente para Pages y para el resto.

Secrets Store entra cuando: (a) sale de beta, o (b) el valor de RBAC/audit/account-level
justifica el refactor — p.ej. si entran más personas con acceso diferenciado.

### 4.1 Arquitectura (Opción 2)
```
master.env (un file plano, todas las claves, gitignored + backup age)
        │  sync-all.sh (idempotente)
        ├──→ wrangler secret put   → worker-bot
        ├──→ wrangler secret put   → worker-pago
        ├──→ wrangler secret put   → worker-tours
        ├──→ wrangler secret put   → worker-feedback
        └──→ wrangler pages secret put → apps/web (Pages)
```

### 4.2 Inventario (a confirmar contra el file del levantamiento)
Secrets que el código referencia (worker-bot, del index.ts):
ANTHROPIC_API_KEY · MANYCHAT_API_TOKEN · MANYCHAT_SEND_FLOW_NS · BEDS24_TOKEN ·
BEDS24_REFRESH_TOKEN · BEDS24_WEBHOOK_SECRET · MP_ACCESS_TOKEN · MP_USE_SANDBOX ·
GITHUB_PAT · ADMIN_REFRESH_SECRET · ADMIN_EMAIL · TG_BOT_TOKEN · BEDS24_PROXY_TOKEN ·
HANDOFF_NOTIFY_CHANNEL · MESSENGER_OUTBOUND_ENABLED

El file del levantamiento es la fuente real; esto es el subset visible en código.

### 4.3 Si en el futuro se va a Store (Opción 3) — wrapper de bootstrap
Para no esparcir `await .get()` por todo el código:
```ts
async function resolveSecrets(env): Promise<ResolvedSecrets> {
  return {
    ANTHROPIC_API_KEY: await env.ANTHROPIC_API_KEY.get(),
    BEDS24_TOKEN: await env.BEDS24_TOKEN.get(),
    // ...
  };
}
```
El resto del código consume `secrets.X` (string), no `env.X`. Acota el refactor a
un punto. Canary: worker-tours primero (menos secrets, bajo riesgo).

---

## §5. Decisión cerrada (Alex 2026-05-30)

1. **Opción 2.** Master local + propagación.
2. **Formato master**: un file plano, todas las claves, todos los targets reciben todo.
3. **Backup**: age (Alex no usa gestor de contraseñas), keypair sin passphrase.

Ejecución detallada → **thread/238** (DoIt).

---

## §6. Riesgos

| Riesgo | Mitigación |
|---|---|
| Master local = single point of failure | Backup cifrado age obligatorio (thread/238 DoD) |
| Secret en texto plano en el master | gitignored + cifrado en reposo. NUNCA commiteado |
| Propagación parcial (un target falla) | sync-all.sh reporta por target, falla ruidoso, re-ejecutable |
| Pérdida de age-key.txt | Alex respalda offline 1 vez |
| ADMIN_REFRESH_SECRET expuesto en chat 2026-05-30 | Ya rotado. Tras crons nativos deja de ser crítico |

### Costo
LLM ~$0 (infra). age = gratis, local. Sin gasto externo.

---

## §7. Followup

- Opción 3 (Secrets Store para shared + RBAC/audit): evolución futura, post-GA.
- Master local sigue siendo fuente para Pages y resto incluso en Opción 3.
