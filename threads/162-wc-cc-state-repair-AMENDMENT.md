# Thread 162 · AMENDMENT — chmod fallback + verificación CLAUDE.md/settings.json

**From:** WC (RDM Bot session)
**To:** CC ejecutando thread/162
**Date:** 2026-05-21
**Append a:** `threads/162-wc-cc-state-repair-doit.md`

---

## CONTEXT

Dos additions al spec original:

1. Clarificar comando chmod cuando archivos podrían NO estar tracked
2. Agregar Fase 5: verificar que CLAUDE.md y settings.json se ejecutan correctamente

---

## CLARIFICACIÓN · Comando chmod correcto

En Fase 2 (escenarios A o B), si `git update-index --chmod=+x` falla con
`does not exist and --remove not passed`, es porque el archivo no está
tracked todavía. Usar fallback:

```bash
# Si archivo ya tracked (caso normal):
git update-index --chmod=+x scripts/sync-secret.sh

# Si falla con "does not exist":
git add scripts/sync-secret.sh
git update-index --add --chmod=+x scripts/sync-secret.sh
```

Verificar con `git ls-files --stage scripts/*.sh` que mode sea 100755.

---

## FASE 5 (NUEVA) · Verificar que CLAUDE.md + settings.json se ejecutan bien

Después de Fase 4 (verificación final). Solo aplica si PR #156 está mergeado
(scripts ya en main) o si trabajaste en branch del PR.

### 5.1 · Validar settings.json JSON syntax

```bash
cat .claude/settings.json | python -c "import json,sys; json.load(sys.stdin); print('OK')"
# o si python no disponible:
node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json'))" && echo "OK"
```

Esperado: `OK`. Si falla → settings.json corrupto, halt + reporta.

### 5.2 · Verificar settings.json secciones

```bash
node -e "
const s = require('./.claude/settings.json');
const p = s.permissions;
console.log('allow:', p.allow.length);
console.log('ask:', p.ask.length);
console.log('deny:', p.deny.length);
console.log('git push allowed:', p.allow.some(r => r.includes('git push')));
console.log('rm -rf denied:', p.deny.some(r => r.includes('rm -rf')));
console.log('.env denied:', p.deny.some(r => r.includes('.env')));
console.log('wrangler deploy allowed:', p.allow.some(r => r.includes('wrangler') && !r.includes('delete')));
"
```

Esperado:
- allow >= 100
- ask >= 5
- deny >= 50
- git push allowed: true
- rm -rf denied: true
- .env denied: true
- wrangler deploy allowed: true

### 5.3 · Verificar CLAUDE.md presente y renderiza

```bash
test -f CLAUDE.md && echo "exists" || echo "MISSING"
wc -l CLAUDE.md
head -5 CLAUDE.md
```

Esperado: existe, ~250 líneas, primera línea es `# Claude Code · RDM Bot operating manual`.

### 5.4 · Verificar scripts ejecutan smoke test

```bash
# Test new-migration.sh dry-run (sin commit real)
bash -n scripts/new-migration.sh  # syntax check only
echo "new-migration.sh syntax OK"

bash -n scripts/safe-deploy.sh
echo "safe-deploy.sh syntax OK"

bash -n scripts/sync-secret.sh
echo "sync-secret.sh syntax OK"
```

Si alguno falla syntax check → halt, reporta cuál.

### 5.5 · Verificar permissions mode en scripts

```bash
ls -la scripts/*.sh
# o si Windows:
git ls-files --stage scripts/*.sh
```

Esperado en Linux: `-rwxr-xr-x` para los 3.
Esperado en git index: `100755` para los 3.

### 5.6 · Verificar .gitignore tiene patterns de seguridad

```bash
grep -E '\.dev\.vars|\.env' .gitignore
```

Esperado: al menos `.dev.vars` y `.env` en alguna forma.

### 5.7 · Verificar docs/secrets-inventory.md

```bash
test -f docs/secrets-inventory.md && echo "exists" || echo "MISSING"
grep -c "^|" docs/secrets-inventory.md  # cuenta líneas de tabla markdown
```

Esperado: existe, >5 líneas de tabla (catalog de secrets).

### 5.8 · Smoke test el flow nuevo

Sin modificar nada, valida que un workflow típico CC funcionaría:

```bash
# Simular "CC necesita crear nueva migration"
# (NO ejecutar, solo verificar que el script existe y es válido)
ls -la scripts/new-migration.sh
file scripts/new-migration.sh  # debería decir: "Bourne-Again shell script"

# Simular "CC necesita propagar secret"
ls -la scripts/sync-secret.sh
file scripts/sync-secret.sh
```

---

## CRITERIO DE ÉXITO ADICIONAL (Fase 5)

- [ ] settings.json JSON válido
- [ ] settings.json tiene allow/ask/deny con counts esperados
- [ ] CLAUDE.md existe, ~250 líneas
- [ ] 3 scripts pasan `bash -n` syntax check
- [ ] 3 scripts tienen mode 100755 en git index
- [ ] .gitignore protege .dev.vars + .env
- [ ] docs/secrets-inventory.md existe con catálogo

---

## SI ALGO DE FASE 5 FALLA

NO intentes fixear inline. Reporta el problema específico en thread/163
con:
- Qué validación falló
- Output exacto del comando
- Recomendación (regenerate file, manual fix, etc.)

WC decide si crear nuevo thread de fix o si Alex lo arregla manualmente.

---

## REPORTAR EN thread/163

Agregar sección "Fase 5 · Verificaciones funcionales" con:

```markdown
## Fase 5 · Verificaciones

| Check | Status | Detalle |
|---|---|---|
| settings.json JSON válido | ✅/❌ | ... |
| settings.json counts (allow/ask/deny) | ✅/❌ | XXX/YY/ZZ |
| CLAUDE.md presente | ✅/❌ | NNN líneas |
| scripts bash -n syntax | ✅/❌ | 3/3 |
| scripts mode 100755 | ✅/❌ | 3/3 |
| .gitignore patterns | ✅/❌ | ... |
| secrets-inventory.md | ✅/❌ | NN líneas tabla |
```

---

## COST BUDGET (sin cambio)

- LLM esperado: <$1 (Fase 5 son comandos read-only adicionales)
- Tiempo total con Fase 5: 15-25 min CC
