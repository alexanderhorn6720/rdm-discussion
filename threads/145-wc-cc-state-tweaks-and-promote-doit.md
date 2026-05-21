# Thread 145 · State system tweaks + promote-to-root

**From:** WC
**To:** CC
**Mode:** DoIt (autónomo, scope estricto)
**Date:** 2026-05-19
**Depends on:** PR #3 rdm-discussion (thread/143) merged

---

## CONTEXT

PR #3 (thread/143) entregó 6 archivos en `STATE-drafts/` + `reports/`. WC review identificó 2 tweaks pre-promote y luego promote-to-root de los 3 STATE.md a sus repos respectivos.

Boundary CC=RO en `rdm-platform` se respeta: CC NO commitea a platform. WC commitea ese paso directo (desde sesión Alex/WC).

---

## PRE-FLIGHT (auto-verificable, halt only on real failure)

1. `Test-Path "<USER_HOME>\rdm\dev\rdm-discussion"` → True
2. `Test-Path "<USER_HOME>\rdm\dev\rdm-bot"` → True
3. `cd rdm-discussion; gh pr view 3 --json state` → `state: OPEN` o `MERGED` (si OPEN, parte 1 ejecutable; si MERGED, saltar a parte 2)
4. `git -C rdm-discussion status` → clean
5. `git -C rdm-bot status` → clean
6. `gh auth status` → logged in

---

## DELIVERABLES

### PARTE 1 · Tweaks a PR #3 (si aún no mergeado)

**Branch:** `chore/state-system-and-audit` (existente)

**Tweak A · `STATE-drafts/rdm-bot-STATE.md` §C** (branches activas)
- Eliminar de la lista todas las branches con status "shipped & sin podar" (las 15+ del 2026-05-18).
- Conservar solo branches realmente activas:
  - `feat/admin-nav-phase-2-4`
  - `feat/beds24-proxy-calendar`
  - `feat/a6-reglas-adicionales-deploy`
  - `feat/a5-airbnb-bulk-approve-writeback`
  - `feat/journey-templates-editor`
- Agregar al final de la sección:
  ```
  > **Nota:** 15+ branches mergeadas sin podar pendientes de cleanup
  > (post auto-delete on merge en thread/146).
  ```

**Tweak B · `STATE-drafts/rdm-bot-STATE.md` §D** (post-merge pending)
- Eliminar la frase "Aplicación a prod NO verificada en este snapshot — verificar con..."
- Ejecutar: `wrangler d1 migrations list rincon --remote` para obtener lista real de aplicadas.
- Reemplazar con tabla:
  ```
  | Migration | Status |
  |---|---|
  | 0001-NNNN | applied (✅) o pending (⚠️) |
  ```
- Si `wrangler` no disponible o falla, escribir: `> Pendiente: ejecutar wrangler d1 migrations list rincon --remote` y continuar.

**Tweak C · `STATE-drafts/rdm-discussion-STATE.md` §A** (threads activos)
- Cap tabla a 15 threads más recientes (no 28).
- Agregar al final:
  ```
  > **Nota:** ver `reports/threads-audit-2026-05-19.md` para tabla completa de 159 threads.
  ```

**Tweak D · `STATE-drafts/rdm-bot-STATE.md` §A** (stack)
- Línea "Last deploy dates": ejecutar `wrangler deployments list` por cada worker para fechas reales.
- Si no disponible, reemplazar "verify with wrangler whoami" con:
  ```
  > Last deploys: pendiente capturar via `wrangler deployments list <worker>`.
  ```

**Tweak E · review final**
- Re-leer los 3 STATE.md drafts buscando otros "verify with X" o "CONFIRMAR" TODOs.
- Cualquier TODO en STATE.md = anti-pattern (un dashboard no tiene TODOs sobre sí mismo).
- Resolver o convertir en nota explícita.

**Commits:**
- `chore(state): cap discussion §A to 15 + prune bot §C shipped branches`
- `chore(state): replace TODOs with resolved data or explicit notes`

**Push + esperar Alex merge.**

---

### PARTE 2 · Promote-to-root (post-merge PR #3)

**Branch nuevo:** `chore/promote-state-to-root` (en rdm-bot)

**Acciones:**

1. Crear branch desde main en rdm-bot
2. Copiar `rdm-discussion/STATE-drafts/rdm-bot-STATE.md` → `rdm-bot/STATE.md`
3. Editar header del archivo copiado:
   - Cambiar primera línea `# rdm-bot · STATE (draft)` → `# rdm-bot · STATE`
   - Cambiar `> Generado por CC vía DoIt thread/143 (2026-05-19). Para promote-to-root, ver §H.` → `> Source of truth ligero para "qué hay vivo ahora" en rdm-bot.`
   - Actualizar §H "Last updated" a fecha actual + thread/145
4. Commit: `chore(state): promote STATE.md from rdm-discussion draft to root`
5. Push + abrir PR título: `chore(state): promote STATE.md to root`
6. PR body:
   ```
   Closes thread/145

   Promotes STATE.md from rdm-discussion/STATE-drafts/ to rdm-bot/STATE.md root.

   Source draft: rdm-discussion PR #3 (merged).

   ## What to verify
   - STATE.md aparece en root
   - Contenido refleja tweaks de Parte 1 (sin TODOs, branches podadas, etc.)
   - No otros cambios fuera de scope

   ## Refresh protocol
   Update protocol vive en §H del propio archivo.
   ```

**Acción paralela en rdm-discussion** (mismo PR si posible, o segundo):
- Branch `chore/promote-state-to-root` en rdm-discussion
- Copiar `STATE-drafts/rdm-discussion-STATE.md` → `STATE.md` root
- Mismo header update
- Push + PR

**rdm-platform NO lo toca CC.** WC commitea desde sesión brain mode directo a main de rdm-platform tras aprobación Alex (boundary CC=RO).

---

## COMMIT STRATEGY

- Parte 1: amend a branch existente `chore/state-system-and-audit`
- Parte 2: branch nuevo `chore/promote-state-to-root` por repo (bot, discussion)
- Commits semánticos
- NO auto-merge en ninguno

---

## DEFAULTS

- Encoding: UTF-8 file contents, ASCII shell args
- Idioma: ES en STATE.md, mixto en specs
- 0 secretos, 0 PII, 0 tokens
- NO modificar contenido sustantivo (solo tweaks listed + header changes en promote)

---

## OUT OF SCOPE

- NO modificar threads existentes
- NO crear thread/146 (eso es spec aparte)
- NO commitear a rdm-platform (WC lo hace)
- NO refactor de los reports/ (solo STATE-drafts/)
- NO deploys
- NO modificar SKILL.md, CLAUDE.md, ni configuración

---

## EXTERNAL STATE (informational only)

- Verify que ninguna GH Action falle por presencia de STATE.md en root
- Verify que no haya .gitignore patterns que excluyan STATE.md

---

## CRITERIO DE ÉXITO

- [ ] PR #3 actualizado con tweaks A-E (si aún OPEN)
- [ ] STATE.md en root de rdm-bot via PR nuevo
- [ ] STATE.md en root de rdm-discussion via PR nuevo
- [ ] Ambos PRs nuevos NO mergeados (esperan Alex review)
- [ ] No TODOs ni "verify with X" en STATE.md final
- [ ] Header docs updated en archivos promote

---

## SI TE ATORAS

- `wrangler` no disponible localmente → fallback a notas explícitas, no halt
- PR #3 ya mergeado cuando empiezas → saltar Parte 1, ir directo a Parte 2
- Conflict en branch → rebase si trivial, halt + report si >5min de resolución

---

## REPORTAR AL FINAL

- PR # actualizado (Parte 1)
- PR # nuevo rdm-bot
- PR # nuevo rdm-discussion
- Cualquier tweak que no se pudo aplicar + razón
- Tiempo invertido
- Confirmación: rdm-platform queda pendiente WC commit directo

---

## COST BUDGET

- LLM esperado: <$2
- Tiempo: 1-1.5h CC
- Halt si excede $4 o 2h
