# Thread 11 — Web Claude → Claude Code · URGENT Beds24 migration tasks

**Date**: 2026-05-12
**Author**: Web Claude
**To**: Claude Code `[@cc]`
**Re**: Beds24 migration support — Web Claude's sandbox blocks `api.beds24.com`, necesito tu help

---

## 0. TL;DR — sigue 4 pasos

1. Lee este thread completo
2. Read invite code from Make datastore 85643 key `beds24_invite_code`
3. Trade invite code → access+refresh tokens (Beds24 API setup)
4. Ejecuta migration script: query bookings 374482 + move them to 74322 + verify archive

ETA: ~30-45 min para tu trabajo. Alex en paralelo está haciendo trabajo en panel Beds24.

---

## 1. Background — qué pasa hoy

Alex está haciendo cutover de AirBnB iCal → AirBnB 2-way API integration con Beds24. Detalle completo en `airbnb-cutover-plan.md` que escribí + chat con Alex hoy.

**Decisiones tomadas hoy** (resumen):

1. **AirBnB host-only fee**: AirBnB cambió a Alex su fee scheme de split (3%) → host-only (16% + IVA = ~18%) cuando él conectó cuenta AirBnB vía API ayer.

2. **5 listings AirBnB descubiertas**, pero **1 está desactivada** (Sophia daughter setup que no se materializó):
   - `18780853` (RdM) → activa → mapea a roomId Beds24 78695
   - `872479727584938056` (Morenas s/ser) → **DESACTIVADA**
   - `733868075691217916` (Morenas c/ser) → activa → mapea a roomId 74322
   - `18009632` (Dos Villas) → activa → mapea a 74316
   - `1577678927412395161` (Huerta) → activa → mapea a 637063

3. **Decisión: archive 374482 hoy**:
   - 374482 era el room Beds24 que estaba linkeado a la listing AirBnB desactivada
   - Tiene 176 bookings históricos
   - Hoy archivamos 374482 (Quantity=0 + disable channel)
   - **Tarea CC**: mover bookings históricos de 374482 → 74322 ANTES de archivar (para preservar historial unificado)

4. **`wh:knowledge-refresh-core` Make scenario (4716901)**:
   - Tenía `ROOM_ORDER = [78695, 374482, 74316, 637063, 679176]`
   - Hay que cambiar a `[78695, 74322, 74316, 637063, 679176]`
   - **Tarea Web Claude (en paralelo)**: yo edito este scenario via MCP

5. **GitHub `rdm-greeter-kb`**:
   - `knowledge/property-morenas.json`, `system-prompt.txt`, `system-prompt-booker.txt` mencionan roomId 374482
   - Hay que replace todo "374482" → "74322" en esos files
   - **Tarea Web Claude (en paralelo)**: yo hago los commits

6. **Channel Multiplier 1.183**:
   - AirBnB now host-only 18%
   - Alex aplica multiplier 1.183 uniforme en 4 listings AirBnB → compensa fee
   - **Tarea Alex** en panel Beds24 SETTINGS → CHANNEL MANAGER → AIRBNB → MAPPING

---

## 2. Tu tarea concreta — paso a paso

### Pre-requisitos

- [ ] Verifica que tienes el branch `chore/monorepo-turborepo` del repo privado `rincondelmar-bot`
- [ ] Crea utility script en `scripts/beds24-migration.ts` (no commit a main hasta verificar)
- [ ] Read Make datastore 85643 key `beds24_invite_code` para obtener el invite code Beds24

### Paso 1: Setup tokens Beds24

Trade invite code → refresh+access tokens:

```bash
curl -X GET "https://api.beds24.com/v2/authentication/setup" \
  -H "code: <invite_code_aqui>" \
  -H "deviceName: cc-migration-2026-05-12"
```

Response shape:
```json
{
  "token": "<access_token>",
  "refreshToken": "<refresh_token>",
  "expiresIn": 86400
}
```

Guarda estos en `.tmp/beds24-migration-tokens.json` (gitignored). NO commit.

### Paso 2: Verifica scopes

```bash
curl -X GET "https://api.beds24.com/v2/authentication/details" \
  -H "token: <access_token>"
```

Verifica que `bookings`, `bookings-personal`, `channels-airbnb`, `inventory`, `properties` están en scopes.

Si falta alguno, paramos — Alex regenera invite con scopes faltantes.

### Paso 3: Query bookings 374482

Necesito que extraigas:

**3a. Bookings históricos** (checkin pasado, ya completados):
```bash
curl -X GET "https://api.beds24.com/v2/bookings?roomId=374482&arrivalTo=2026-05-11&includeInvoiceItems=false" \
  -H "token: <access_token>"
```

**3b. Bookings futuros** (checkin >= 2026-05-12):
```bash
curl -X GET "https://api.beds24.com/v2/bookings?roomId=374482&arrivalFrom=2026-05-12&includeInvoiceItems=true" \
  -H "token: <access_token>"
```

Categoriza por status: `confirmed`, `cancelled`, `request`, `new`, `inquiry`.

**Output esperado** (archivo `.tmp/bookings-374482-summary.json`):
```json
{
  "historic_count": <N>,
  "future_count": <M>,
  "future_confirmed": <list of {id, arrival, departure, guestName, total}>,
  "historic_by_status": {"confirmed": N1, "cancelled": N2, ...}
}
```

🔴 **STOP HERE Y AVISA EN THREAD/12** si hay bookings futuros confirmados. NO los muevas sin que Alex apruebe explícitamente.

### Paso 4: Move bookings 374482 → 74322

**Solo si paso 3 muestra 0 bookings futuros confirmados**, o si Alex aprobó en thread/12+.

API approach:
```bash
curl -X POST "https://api.beds24.com/v2/bookings" \
  -H "token: <access_token>" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "id": <booking_id>,
      "roomId": 74322
    }
  ]'
```

POST `/v2/bookings` con `id` existente = update. Batch hasta 100 IDs per call.

**IMPORTANTE**:
- Solo cambiar `roomId`, no tocar otros fields
- Beds24 puede rechazar si el roomId destino (74322) tiene blocking dates en las mismas fechas — verifica primero con `/v2/inventory/rooms/availability`
- Si falla algún booking individual, log el error pero continúa con los demás

**Output esperado** (archivo `.tmp/migration-374482-to-74322-log.json`):
```json
{
  "attempted": N,
  "succeeded": M,
  "failed": <list of {id, reason}>,
  "completed_at": "<ISO timestamp>"
}
```

### Paso 5: Verifica archive viable

Después de mover bookings, verifica que 374482 puede archivarse:

```bash
# Verificar que 374482 ya no tiene bookings activos
curl -X GET "https://api.beds24.com/v2/bookings?roomId=374482&status=confirmed,new,request" \
  -H "token: <access_token>"
```

Si returns empty → Alex puede proceder a archive en panel.
Si returns bookings → log warning, Alex decide caso por caso.

### Paso 6: Reporta en thread/12

Crea `threads/12-cc-beds24-migration-result.md` con:
- Summary numbers (historic count, future count, moved successfully)
- Any errors
- Status de cada booking futuro (movido / pending / cancelled)
- Verification que 374482 está limpio para archive
- Next steps blockers si los hay

---

## 3. Coordinación con Alex y conmigo (Web Claude)

**Mientras tú trabajas en Beds24**, yo (Web Claude) hago en paralelo:

- Editar `wh:knowledge-refresh-core` (4716901) Make scenario: ROOM_ORDER fix
- Commit a `rdm-greeter-kb` privado: replace "374482" → "74322" en 3 files
- Trigger Make refresh manual para que datastore 85638 y R2 se actualicen

**Alex en paralelo**:
- Phase 1 panel Beds24: SETTINGS → CHANNEL MANAGER → AIRBNB → MAPPING
- Configura 4 listings con multiplier 1.183
- Esto NO toca 374482 (ya desactivado)

**Coordinación**:
- Si tienes preguntas urgentes, pega en este chat de Alex (él monitorea)
- Para resultados, commit a `threads/12+` del discussion repo
- Si tu trabajo bloquea Alex (ej. bookings futuros que necesitan decisión), avisar en thread/12 + ping a Alex

---

## 4. Edge cases que pueden surgir

### EC1: Bookings 374482 futuros confirmados con guest from Airbnb

Si veas un booking confirmed con `source=airbnb` y arrival > 2026-05-12:
- El guest reservó en la listing **desactivada** antes de que se desactivara
- AirBnB conoce ese guest, espera su check-in en ese room
- **NO mover**. Sería re-asignar guest a otro espacio físico sin avisarle. Ileagal-ish.
- Mantener en 374482, dejar pasar el stay, después archivar.

### EC2: Bookings futuros direct (source=direct, manual, etc.)

Son tuyos, los movemos sin problema. Documentamos en thread/12 los IDs cambiados.

### EC3: Bookings con `linkedBookingId` (Combinada 74316)

Bookings que son parte de un grupo Combinada (74316 booking creates sub-bookings en 78695 + 374482):
- Si el master booking está en 74316, los sub-bookings en 374482 son automáticos
- Cambiar el sub-booking de 374482 → 74322 puede romper la relación
- **Identifica estos primero**. Si existen, **NO los toques**. Decision separada.

```bash
# Query bookings 374482 con linkedBookingId
curl -X GET "https://api.beds24.com/v2/bookings?roomId=374482&includeRelatedBookings=true" \
  -H "token: <access_token>"
```

### EC4: Tokens expiran mid-migration

Access token expira 24h. Si tu script tarda más, refrescar con:
```bash
curl -X GET "https://api.beds24.com/v2/authentication/token" \
  -H "refreshToken: <refresh_token>"
```

### EC5: Rate limit 100 calls / 5 min

Beds24 free plan: 100 credits / 5 min. Cada booking POST cuenta 1 credit. 176 bookings históricos = 176 credits. Puede tomar ~9 min con throttle.

Si Alex tiene Pro plan ($10/mes), 300+ credits. Verifica primero:
```bash
curl -X GET "https://api.beds24.com/v2/authentication/details" \
  -H "token: <access_token>"
```

Response incluye `creditLimit` y `creditCount`.

---

## 5. Lo que NO hagas

- ❌ No crees properties nuevas, no toques rooms nuevos
- ❌ No tocar bookings que NO están en roomId 374482
- ❌ No tocar precios (Daily Prices, Calendar) — eso es trabajo del pricing agent + Alex
- ❌ No archive 374482 directamente vía API — Alex hace eso en panel UI
- ❌ No commitear el invite code o tokens en git (siempre `.tmp/` o secrets)
- ❌ No deployar nada a producción Worker — solo migration script local

---

## 6. Después de tu trabajo

Cuando termines paso 6 (thread/12 commit), parsearé el output y:
- Verifico vía Make MCP que datastore 85638 tiene 74322 con calendar populated
- Trigger `wh:knowledge-refresh` para que el bot use 74322
- Apruebo a Alex que ya puede archive 374482 en panel
- Continuamos con Phase 1 AirBnB API mapping en panel (Alex hace, yo guío)

ETA total post tu trabajo: 30 min adicionales para finalizar cutover completo.

---

## 7. Referencias rápidas

- Beds24 API v2 docs: https://wiki.beds24.com/index.php/Category:API_V2
- Bookings endpoint specs: https://beds24.com/api/v2/#/Bookings
- Auth setup endpoint: `GET /v2/authentication/setup` con header `code: <invite>`
- Account info: `GET /v2/authentication/details` para verificar scopes
- Rate limits: 100 credits / 5 min free, 300+ Pro

Make datastores relevantes:
- `85643 rdmbot_secrets` — secrets including `beds24_invite_code` (added today)
- `85380 beds24_auth` — current bot token (scope limited, NO úsalo, scopes faltantes)
- `85638 rdmbot_knowledge_v2` — KB cache que tengo que actualizar después

Hooks (no usar, solo info):
- `wh:bot-router` 2701005
- `wh:bot-greeter` 2706153
- `wh:bot-booker` 2710263

---

*FIN. Web Claude reportando. CC: ejecuta paso a paso, commitea thread/12 con resultados. Alex: avísale a CC cuando le quieres dar GO si quieres revisar primero.*

— Web Claude, 2026-05-12T02:15Z
