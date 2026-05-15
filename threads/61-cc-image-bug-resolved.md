# Thread 61 — CC: P0 image bug RESOLVED + status update

**Date**: 2026-05-15 morning
**Author**: Claude Code (CC-Bot)
**To**: WC `[@wc]` + Alex `[@alex]`
**Re**: thread/60 P0 bug imágenes broken
**Status**: 🟢 FIXED — auto-deployed live, verified

---

## TL;DR

PR #34 merged + auto-deployed. Imágenes live en producción. Bug NO era regresión de PRs #27/#31/#33 — pre-existía desde commit `737fff1` (2026-05-08).

---

## Diagnosis

`apps/web/src/lib/images.ts:33`:
```ts
const HASH = import.meta.env.PUBLIC_CF_IMAGES_HASH ?? '';
return id.startsWith('placeholder-') || HASH === '';  // cascade fail
```

Build-time env var (`PUBLIC_CF_IMAGES_HASH`) NO disponible si:
- `pnpm build` desde shell sin `.env` (mi caso en builds de los PRs anteriores)
- GH Actions workflow sin `vars.PUBLIC_CF_IMAGES_HASH` repo var seteada
- Cualquier deploy sin la env explícita

→ HASH='' → isPlaceholderId returns true para CUALQUIER id → URLs literales `:placeholder:UUID:variant` → ~100+ imágenes broken.

`wrangler.toml [vars]` son **runtime**, NO build-time. Astro `import.meta.env.X` lee de Vite que solo tiene env vars del shell que invoca la build.

## Fix bidireccional

**1. Hardcoded fallback en código** (`apps/web/src/lib/images.ts`):
```ts
const HASH_FALLBACK = 'pxVZVbOKrSOn7mOCVIbkKA';
const HASH = import.meta.env.PUBLIC_CF_IMAGES_HASH ?? HASH_FALLBACK;

export function isPlaceholderId(id: string): boolean {
  return id.startsWith('placeholder-');  // removido cascade `|| HASH === ''`
}
```

Hash es PÚBLICO (visible en cada URL imagedelivery.net), no es secret.

**2. Defense en profundidad en `deploy.yml`**:
```yaml
PUBLIC_CF_IMAGES_HASH: ${{ vars.PUBLIC_CF_IMAGES_HASH || 'pxVZVbOKrSOn7mOCVIbkKA' }}
PUBLIC_WHATSAPP_NUMBER: ${{ vars.PUBLIC_WHATSAPP_NUMBER || '+525570618798' }}
```

Si `gh variable list` está vacío, el workflow ahora usa fallback.

## Verificación post-deploy

```bash
$ curl -sSL https://rincondelmar.club/rincon-del-mar/ | grep -oE 'imagedelivery.net/pxVZVb[^"]{30}' | head -3
imagedelivery.net/pxVZVbOKrSOn7mOCVIbkKA/8a45c5cc-7ce8
imagedelivery.net/pxVZVbOKrSOn7mOCVIbkKA/8a45c5cc-7ce8
imagedelivery.net/pxVZVbOKrSOn7mOCVIbkKA/8a45c5cc-7ce8

$ curl -sSL https://rincondelmar.club/rincon-del-mar/ | grep -cE ':placeholder:'
1   # legítimo, image not uploaded yet (NOT bug)
```

Auto-deploy timing: PR merged 16:28 UTC → workflow run completed ~16:30 UTC (~1.5 min).

---

## Status del overnight (resumen para WC)

### Mis PRs (Fase 1) — 6 total ahora
- ✅ #27 deploy.yml fix + SITE_URL
- ✅ #28 ADMIN_EMAILS
- ✅ #29 click tracking endpoint /r/bot/[slug] + intent-resolver
- ✅ #30 Telegram /internal/notify-human + reminders cron
- ✅ #31 property page anchors (8 IDs LIVE)
- ✅ #33 lang detection ES/EN heuristic
- 🟡 #32 BookingCard URL params (DRAFT, espera Alex)
- ✅ #34 image hash fallback (P0 fix today)

### Worker bot deployment
Alex deployó `wrangler deploy` esta mañana. Verificado:
- `bot.rincondelmar.club/health` OK
- `bot.rincondelmar.club/r/bot/precios?prop=rincon-del-mar` → 302 ✅

### Pending (post-image-fix)
- Alex: review PR #32 BookingCard URL params (5 min smoke test)
- CC-Bot: PR A1.5 sub-components (3-4h, copy listo en thread/59)
- WC: cc-instructions Greeter v5 Fase 2 (PR A4 + A6)

---

## Lessons learned (para CLAUDE.md o follow-up)

1. **Smoke test post-deploy debe incluir image render check**. Sin esto, P0 bug se descubrió cuando Alex visitó site, no cuando deployamos. Add a `12-operations.md`:
   ```bash
   # post-deploy smoke
   curl -s https://rincondelmar.club/rincon-del-mar | grep -cE 'imagedelivery.net' | grep -q '[1-9]'
   ```
2. **Env vars públicas con fallback hardcoded** es buen pattern cuando la "secret" no es secret (e.g. CF Images hash). Reduce single-point-of-failure.
3. **wrangler.toml [vars] vs build-time**: importante distinguir. Astro `import.meta.env` solo lee de shell/CI env vars, no de wrangler.toml.

---

**FIN thread/61**. Sitio recovered. CC-Bot continúa con PR A1.5 después de Alex review #32.

— Claude Code, 2026-05-15 morning
