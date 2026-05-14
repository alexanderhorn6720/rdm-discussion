# AirBnB Emoji Blocklist — empirical findings 2026-05-14

**Source:** Chrome MCP write-back de RdM ES, 12 fields x AirBnB hosting editor.
**Discovery:** AirBnB rechaza algunos emojis con error "Contiene caracteres no válidos. Elimina X antes de continuar." mientras acepta otros.

---

## TL;DR

AirBnB tiene un **blocklist específico** de emojis (no documentado oficialmente). Algunos emojis empíricamente probados pasan el save, otros lanzan error de validación.

**Política oficial:** AirBnB dice "no emojis allowed in listing titles/descriptions" desde update 2022-08, pero en práctica enforcement es inconsistente — bloquean SELECT emojis, no todos.

---

## ✅ Empíricamente WORKING (saved exitoso en RdM ES 18780853)

### En `tu_propiedad` (Description URL):
- 🛏️ (bed)
- ✅ (check mark)
- 👨‍🍳 (man cook ZWJ sequence)
- 🏊 (swimming person)
- 🏖️ (beach with umbrella)
- 🧹 (broom)
- 🎵 (musical note)
- 🛻 (pickup truck)
- 🛥️ (motorboat)
- 🛎️ (bellhop bell)
- 🛒 (shopping cart)
- 🍹 (tropical drink)
- 🔥 (fire)
- 🥥 (coconut)
- 💆 (person massage)
- 🐴 (horse face)
- 🚣 (rowboat)
- 🤿 (diving mask)
- 🎉 (party popper)
- 🏅 (sports medal)
- 💬 (speech balloon)

### En `como_llegar` (Arrival/directions URL):
- ⛱️ (umbrella on ground) — used 7+ times
- 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ (digit emojis)

### En `manual_casa` (Arrival/house-manual URL):
- ☀️ (sun, U+2600 + VS-16 U+FE0F) — substituyó a 🌅

---

## ❌ BLOCKED (error "Contiene caracteres no válidos. Elimina X")

### Confirmados durante esta sesión:
- **🌅** (sunrise over horizon, U+1F305) — bloqueado en `manual_casa`
- **📶** (antenna bars, U+1F4F6) — bloqueado en `manual_casa`

### Sospechosos (no confirmé save individual, pero los REMOVÍ del manual_casa antes del save final):
- 🔒 (lock)
- 🍳 (cooking pan)
- 🚿 (shower)
- 🚨 (alarm/police light)

> NOTE: estos 4 podrían pasar — no los probé individualmente. Removí en bulk para asegurar el save. Próxima sesión: probar uno por uno para refinar el blocklist.

---

## Patrón aparente

No hay pattern obvio por Unicode version o categoría. Hipótesis:
- **Algunos emojis "símbolo de servicio/utility"** bloqueados (📶 wifi, 🔒 lock, 🚨 alarm, 🌅 amanecer)
- **Emojis "people/objects/food"** mayormente OK (🛏️ 👨‍🍳 🍹 🥥)
- **Emojis decorativos/marcadores** OK (✅ 🎉 ⛱️ 🏅 1️⃣)

Hipótesis alternativa: blocklist relacionado con anti-spam/scam (los bloqueados parecen "señales de alerta" que spammers podrían usar).

---

## Recomendaciones para WC + drafting futuro

**Para drafts WC nuevos:**

1. **Evita 🌅 en signature canonical** — el footer `— Alexander 🌅` será rechazado. Alternativas:
   - `— Alexander ☀️` (sun básico — confirmé que pasa)
   - `— Alexander 🏖️` (beach — confirmé que pasa)
   - `— Alexander 🌊` (wave — no probado, riesgo)
   - `— Alexander` (sin emoji — bulletproof)

2. **Evita estos emojis "señal/alerta":** 📶 🌅 (confirmados), 🔒 🚨 🍳 🚿 (sospechosos)

3. **Prefiere "set seguro" para section markers:** 
   - ⛱️ 🛏️ ✅ 👨‍🍳 🏊 🏖️ 🧹 🎵 🛻 🛥️ 🛎️ 🛒 🍹 🔥 🥥 💆 🐴 🚣 🤿 🎉 🏅 💬 ☀️

4. **Para `manual_casa` específicamente** (campo más estricto aparentemente): considera **plain text section headers** con `——` o `##` para bulletproof:
   ```
   —— WiFi ——
   Red: ... Contraseña: ...
   
   —— Boiler ——
   ...
   ```

5. **Test approach:** si tienes un emoji nuevo no probado, primero pushéalo en `tu_propiedad` (parece más permisivo) antes de usarlo en `manual_casa`.

---

## Acciones para CC (este sprint)

- [x] Documentar findings (este file)
- [ ] Update R2 RdM ES draft `manual_casa.content` para reflejar la versión sin 🌅 + sin section emojis (versión que efectivamente saved a AirBnB)
- [ ] Update R2 deploy_at + airbnb_snapshot para 12 cells RdM ES
- [ ] Notify WC para que ajuste signature canonical + remueva 🌅/📶 de drafts pendientes

## Acciones para WC (próximo sprint)

- [ ] Update `_signature_canonical` constant en wc-seed-converter — drop 🌅
- [ ] Re-validate Las Morenas, Combinada, Huerta drafts para emojis bloqueados
- [ ] Actualizar drafts de los 3 properties con safe emoji set

---

**Spec status:** este blocklist NO está en docs oficiales AirBnB. Viene de empirical testing 2026-05-14. Si cambia (AirBnB ajusta filtros), re-validar.
