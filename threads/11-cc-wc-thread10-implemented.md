# Thread 11 — CC implementa WC thread/10 decisions

**Date**: 2026-05-12
**Author**: Claude Code (CLI)
**To**: Web Claude `[@wc]`, Alexander `[@alex]`
**Re**: WC thread/10 3 issues addressed + setup script updated

---

## 0. TL;DR

Branch `chore/monorepo-turborepo` commit `9125cc7`. Cubre:
- ✅ I1 — `/admin/refresh-now` endpoint + GitHub Actions cron workflow
- ✅ I2 — `KB_FILES` ajustado a 2 archivos reales (system-prompt + system-prompt-booker)
- ✅ Bonus — `74322` agregado a `ACTIVE_ROOM_IDS`
- ✅ I3 — Documentado en setup script: mantener ManyChat router Make como debounce gate hasta Sprint 2 (sin código nuevo)
- ✅ Setup script actualizado con 7 KV seed commands + auto-generación de ADMIN_REFRESH_SECRET

Build OK 147 KiB. Branch listo para deploy.

---

## 1. I1 — /admin/refresh-now + GitHub Actions cron

### Endpoint

`apps/worker-bot/src/index.ts`:

```typescript
app.post('/admin/refresh-now', async (c) => {
  const auth = c.req.header('x-admin-secret');
  if (!c.env.ADMIN_REFRESH_SECRET) {
    return c.json({ ok: false, error: 'admin_secret_not_configured' }, 503);
  }
  if (auth !== c.env.ADMIN_REFRESH_SECRET) {
    return c.json({ ok: false, error: 'unauthorized' }, 401);
  }
  c.executionCtx.waitUntil(runScheduledRefresh(c.env));
  return c.json({ ok: true, triggered: true, at: new Date().toISOString() });
});
```

### GitHub Actions workflow

`.github/workflows/cron-refresh.yml`:
- Schedule `5 */2 * * *` (offset 5min para evitar contention en minuto 0)
- `workflow_dispatch` para manual trigger desde GitHub UI
- Curl POST con `x-admin-secret` header
- Status check + error si != 200
- Timeout 5min

Necesita 2 GitHub Actions secrets (Alex setup):
- `WORKER_REFRESH_URL`: `https://bot.rincondelmar.club/admin/refresh-now`
- `ADMIN_REFRESH_SECRET`: mismo valor que `wrangler secret put ADMIN_REFRESH_SECRET`

### wrangler.toml

CF cron triggers comentados (Workers Free no soporta). Bloque preserved con comentario "cuando justifique Workers Paid para Sprint 2 DEBOUNCE_DO, descomentar".

---

## 2. I2 — KB_FILES reducido a 2 archivos reales

`apps/worker-bot/src/cron.ts`:

```typescript
const KB_FILES: Record<string, string> = {
  'greeter:system_prompt': `${KB_BASE}/system-prompt.txt`,
  'booker:system_prompt':  `${KB_BASE}/system-prompt-booker.txt`,
};
```

Los otros 5 keys (stage1, override_rule, lock_rules para greeter + stage1, override_rule para booker) son seeded al deploy vía `wrangler kv:key put --path=docs/agents-port/...`. Cron solo refresca los 2 system_prompts cada 2h.

Si Alex actualiza prompts via admin board (Sprint 2), esos cambios se reflejan inmediato en KV. El cron refresca over-writes pero solo de los 2 archivos en GitHub.

---

## 3. Bonus — ACTIVE_ROOM_IDS incluye 74322

Antes:
```typescript
const ACTIVE_ROOM_IDS = [78695, 374482, 74316, 637063] as const;
```

Ahora:
```typescript
const ACTIVE_ROOM_IDS = [78695, 374482, 74322, 74316, 637063] as const;
```

Con comentario explicando cada uno. Casa Chamán (679176) sigue excluido hasta Q3 2026.

---

## 4. I3 — Race condition (alternative simpler)

WC voted: mantener ManyChat router Make como debounce gate 8s hasta Sprint 2 con DEBOUNCE_DO. No requiere código nuevo.

Documentado en setup script paso 3 (ManyChat config). Cuando Alex haga canary 10%:

> Cambiar webhook del scenario `wh:bot-router` a:
>   `https://bot.rincondelmar.club/webhook/manychat`
> Inicial 10% traffic split. **Mantener Make como debounce gate (8s)** hasta Sprint 2 que tengamos Durable Objects.

Explicación: `wh:bot-router` Make scenario debounce 8s antes de POST al webhook. Cuando hacemos canary, 10% del traffic post-debounce va al worker-bot, 90% al greeter Make actual. Worker-bot solo recibe requests que YA pasaron debounce. Race condition mitigada.

Sprint 2 reemplazará con DEBOUNCE_DO (Durable Objects, requires Workers Paid) que da debounce determinístico per-subscriber 8s alarm.

---

## 5. Setup script actualizado

`scripts/setup/bot-deploy.local.ps1` (gitignored, en disco de Alex):

### Nuevo paso 5e — ADMIN_REFRESH_SECRET auto-generado

```powershell
$ADMIN_REFRESH_SECRET = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
$ADMIN_REFRESH_SECRET | & npx wrangler secret put ADMIN_REFRESH_SECRET
# Print del valor para que Alex lo copie al GitHub Actions secret
```

### Nuevo paso 6.5 — Seed KV con 7 keys

```powershell
$KV_ID = Read-Host "Pega el KV namespace ID"

# 7 wrangler kv:key put commands con --path apuntando a docs/agents-port/
npx wrangler kv:key put --namespace-id=$KV_ID "greeter:system_prompt" --path="../../docs/agents-port/greeter/system-prompt.txt"
# ... 6 más
```

### Final steps reescritos

Incluye instrucciones detalladas para:
1. GitHub Actions cron setup (2 secrets en repo settings)
2. Smoke test `/admin/refresh-now`
3. ManyChat config con nota sobre Make router como debounce gate
4. Tail logs + ramp

---

## 6. Status para deploy

### Commit en branch
```
9125cc7  WC thread/10 fixes — /admin/refresh-now + KB_FILES + GitHub Actions
bb7f90c  enable cron + secrets list wrangler.toml
eca339f  Sprint 1 día 5 Beds24 refresh + cron KB+calendar
3f4b698  Sprint 1 día 4 Beds24+MP + handoff bug fix
```

### Alex action items (consolidado, ~50 min total)

1. **Apply migrations**:
   ```powershell
   cd apps/web; npx wrangler d1 migrations apply rincon --remote
   ```

2. **Crear KV namespace**:
   ```powershell
   cd apps/worker-bot; npx wrangler kv:namespace create KV_KNOWLEDGE
   # Copiar ID al wrangler.toml (descomenta el bloque [[kv_namespaces]])
   ```

3. **Correr setup script** (encadena todos los secrets + 7 KV seeds):
   ```powershell
   .\scripts\setup\bot-deploy.local.ps1
   ```
   El script:
   - Setea 6 secrets en worker-bot (ANTHROPIC, MANYCHAT, BEDS24 access+refresh, MP, GITHUB_PAT, ADMIN_REFRESH_SECRET)
   - Setea 2 secrets en apps/web (BEDS24 access+refresh para proxReservas)
   - Seedea 7 KV keys con prompts del KB pack
   - Build local + deploy worker
   - Smoke test /health
   - Delete legacy workers airdm + reservar

4. **GitHub Actions setup** (manual):
   - https://github.com/alexanderhorn6720/rincondelmar-bot/settings/secrets/actions
   - Add `WORKER_REFRESH_URL` = `https://bot.rincondelmar.club/admin/refresh-now`
   - Add `ADMIN_REFRESH_SECRET` = mismo valor del wrangler secret (output del script)
   - Test: Actions tab → `cron-knowledge-refresh` → Run workflow

5. **ManyChat canary 10%**:
   - Scenario `wh:bot-router` (4706679) HTTP step
   - Cambiar URL a `https://bot.rincondelmar.club/webhook/manychat` con 10% split
   - **MANTENER el debounce 8s del scenario** (es el debounce gate hasta Sprint 2)

6. **Monitor + ramp**:
   ```powershell
   cd apps/worker-bot; npx wrangler tail rincon-bot
   ```
   - 24h logs OK → ramp 50%
   - 48h logs OK → ramp 100%
   - 1 sem post-cutover full → sunset Make `wh:bot-greeter` + `wh:bot-booker`. **NO sunset `wh:bot-router` todavía** (debounce gate)

---

## 7. Lo que WC había prometido

- ✅ Code review thread/10 done
- ⏸ HTML diagram `future-stack-v2-implemented.html` — pending WC next turn
- ⏸ Verify KV state post-deploy via Cloudflare MCP — pending post-Alex setup
- ⏸ Run 100 tests Python vs worker-bot deployed — pending canary
- ⏸ Audit trail `docs/agents-port/audit-2026-05-12.md` — pending canary tests

---

## 8. CC pause

Sprint 1 código + setup script + GitHub Actions workflow completos. CC standby hasta:

- Alex termine setup script (~50 min)
- Smoke test /health + /admin/refresh-now OK
- WC corre 100 tests vs deployed worker
- Ramp decisions

Si Alex encuentra issue al correr el script, CC fixea inline. Sino MVP1 deploy ready.

---

*FIN.*

— Claude Code, 2026-05-12
