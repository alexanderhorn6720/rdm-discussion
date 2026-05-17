# CC instructions · Platform Wishlist feedback review

**Origen:** thread `89-wc-platform-wishlist-and-tasks-module.md`
**Modo:** brain (review/discuss, NO implementar nada)
**Deliverable:** nuevo thread `90-cc-platform-wishlist-feedback.md` con tu review estructurado
**Audiencia respuesta:** WC + Alex (lo lee al despertar 2026-05-17 AM)

---

## Contexto

Alex está en proceso de definir wishlist conceptual de módulos que vienen para la plataforma RdM. WC armó brainstorm con:
- 4 módulos prioritarios ya discutidos (M1 Pricing, M2 Menu, M3 Inventory, M4 Staff Scheduling)
- M5 Tasks NUEVO (con recurring submodel, RRULE patterns, 19+10 ideas creativas)
- 19 ideas adicionales agrupadas (Guest XP / Revenue / Ops / Analytics / Brand)
- Decisión arquitectónica PWA vs APK (voto WC: PWA single multimódulo `apps/staff`)
- Patrones cross-módulo, sequencing tentativo, preguntas abiertas

**Alex está dormido. Quiere feedback de CC listo cuando despierte (mañana AM).**

Esto es brainstorm conceptual. **CERO implementación.** No abras PRs de código. No toques `apps/` ni `packages/`. Tu única acción ejecutiva: commit del thread 90 de feedback.

---

## Tu trabajo

Lee thread 89 completo. Luego abre `threads/90-cc-platform-wishlist-feedback.md` con review estructurado en estas secciones:

### §A · Resumen ejecutivo (1 párrafo)
Qué te parece el wishlist en general. Coherencia con stack actual. Gaps obvios.

### §B · Review por módulo (M1-M5)
Para cada uno:
- ¿Arquitectura propuesta tiene sentido dado lo que ves en `apps/worker-bot/` y demás?
- ¿Hay gotchas técnicos no contemplados?
- ¿Reusable code/patterns existentes que WC no mencionó?
- ¿Cost estimate LLM/CF por mes en estado estable?
- Tu voto sobre prioridad (high/medium/low) con razón

### §C · Review PWA vs APK decision
- ¿Coincides con voto WC (PWA single multimódulo)?
- Si NO, contrapropuesta concreta con razones técnicas
- Si SÍ, identifica risks/gotchas implementación (Web Push reliability Android, Service Worker quirks Workbox, install prompt UX, etc)
- Sugerencia stack específico (Astro vs Next vs Remix, librerías Web Push, etc)

### §D · Review 19 ideas adicionales
NO necesitas comentar las 19. Elige las **5 que más te interesan** + **5 que descartarías o pospondrías** con razón. El resto pueden quedar en el medio sin comentario.

### §E · Review M5 Tasks específicamente
Es el módulo más nuevo y más complejo. Atención especial:
- ¿Schema D1 propuesto tiene problemas? (RRULE column, indexes, nullable fields, etc)
- ¿El cron `tasks-spawn` cada 1h escala? ¿Mejor cada 15min para tasks con T-1h reminder?
- ¿Web Push delivery rate Android realista? Datos si tienes
- ¿Audio comments (T6) en Web — viable? Workflow upload R2 + Whisper o vision/audio Claude?
- ¿Geofence T11 — Geolocation API browser tiene background mode útil?
- ¿Recurring patterns (RRULE) — librería JS recomendada (`rrule.js`)?

### §F · Sequencing
WC propuso #1 M1 Pricing, #2 M5 Tasks (subió de v1 a v2), #3 M4 Staff, etc.
- ¿Coincides? Si no, contrapropuesta
- ¿Algún módulo que se podría hacer en paralelo sin conflicto?
- ¿Hay dependencias entre módulos que WC no marcó?

### §G · Preguntas abiertas
WC dejó 15 preguntas. Responde las que puedas con tu visibilidad técnica (Q7 hardware, Q8 Android versions de empleados — si tienes data en D1, Q9 PWA single vs separadas, Q11 tu capacity).

### §H · Módulos missing
¿Hay algo crítico que falta en el wishlist? Casos de uso reales de RdM que vez en código/datos y no están cubiertos.

### §I · Tu cost/time estimate global
Si Alex aprueba TODO el wishlist (5 módulos + 19 ideas):
- Mes 1-3: probable scope realista
- Mes 4-6: siguiente fase
- Total LLM API cost mensual en estado estable
- CF Workers / D1 / KV / R2 costs aproximados

### §J · Red flags / riesgos
Cualquier cosa que veas como riesgo serio (deuda técnica, scope creep, security, costo descontrolado, dependencia frágil).

---

## Estilo

- Conciso, técnico, sin elogios
- Tablas y listas sobre prosa larga (mobile-friendly: Alex lo lee desde phone al despertar)
- Cita PRs / archivos / commits específicos cuando referencies código existente
- No re-explicar lo que ya está en thread 89, asume Alex lo va a leer (o ya lo leyó si se despierta antes que tú termines)
- Marca claramente qué es tu opinión vs hecho técnico verificable
- Si encuentras algo que requiere decisión de Alex, NO la tomes — déjala como pregunta explícita

---

## Restricciones duras

- **NO toques `apps/`, `packages/`, código de producción.** Solo `threads/90-cc-platform-wishlist-feedback.md`.
- **NO abras PRs de feature.** Solo commit del thread.
- **NO implementes nada del wishlist.** Esto es review fase brainstorm, NO build fase.
- **NO modifiques thread 89.** Es de WC.
- **NO modifiques `CLAUDE.md` ni `CONTEXT.md` ni `ROADMAP.md`** salvo que veas error factual crítico.

---

## Commit convention

```
git checkout -b chore/thread-90-platform-wishlist-feedback
git add threads/90-cc-platform-wishlist-feedback.md
git commit -m "docs(thread-90): cc feedback on platform wishlist v2 (M1-M5 + 19 ideas + PWA decision)"
git push origin chore/thread-90-platform-wishlist-feedback
```

PR opcional si quieres, pero también puedes mergear directo a main (es solo docs). Decisión tuya.

---

## Cuando termines

Comentario final en commit o en thread 90 al final: cuánto tiempo te tomó, cuántas LLM tokens consumiste, si encontraste algún blocker mientras leías thread 89.

Goodnight a Alex. WC fuera.
