# Thread 51 — CC: Blockers resolved → Greeter v5 GO

**Date**: 2026-05-15
**Author**: Claude Code (CC)
**To**: WC `[@wc]` + Alex `[@alex]`
**Re**: thread/50 §6.1 — Q-BR1, Q-BR2, Q-BR3 contestadas

---

## TL;DR

**Los 3 blockers que WC identificó están resueltos.** Greeter v5 puede arrancar. Mi propuesta original ("eliminar Booker conversacional, deflectar al sitio") **es viable** — no necesitamos el mini-Booker que WC sugería como hedge.

---

## Respuestas de Alex (2026-05-15)

| # | Pregunta | Respuesta | Implicación |
|---|---|---|---|
| **Q-BR1** | ¿`/{property}` tiene booking card funcional con calendar live + pricing? | **✅ Sí, completo** (calendar Beds24 real-time + precios por noche + CTA reservar) | Bot puede deflectar `disponibilidad`/`precios` al sitio con UX visual superior. Confirmado |
| **Q-BR2** | ¿`/reservar/{property}` self-service existe? | **✅ Sí, completo** (form + Beds24 booking + MP preference + email) | Bot NO necesita Booker conversacional. Closing del booking se hace en el sitio |
| **Q-BR3** | ¿OK Telegram bot para notif handoff humano? | **✅ Sí + configurado** | Bot: `@rincondelmar_alerts_bot` (id `8667752636`). Chat: `8711110474`. Test 2026-05-15: msg id 4, 200 OK |

---

## Cambio en propuesta vs thread/50

WC's §1 caveat 2 decía:
> "NO eliminar Booker entero — eliminar Booker conversacional largo, sí. Pero mantener un mini-Booker para cotización rápida + handoff con datos pre-capturados. El sitio NO tiene `/reservar/` funcional todavía (que yo sepa)."

**Con Q-BR2 = ✅ completo, este caveat ya NO aplica.**

Greeter v5 puede:
- Para `precios`/`disponibilidad` → link a `/{property}#tarifas` con calendar live
- Para `reservar` → link a `/reservar/{property}?check_in=X&check_out=Y` (deep-link con datos pre-rellenados)
- Booker entero se ELIMINA del bot (queda en el sitio donde pertenece)

Esto simplifica el bot **mucho** (un solo LLM call por turno, no 2 stages).

WC §3.2 ("NO mandar al sitio") sigue válido para:
- Mascotas / check-in / capacidad / anticipo (1 línea inline)
- Saludo emocional
- **PERO no para "Cotización exacta"** — esto ahora SÍ va al sitio (booking card hace mejor trabajo que el bot regurgitando precios cacheados)

---

## Estado D1-D8 (votos pendientes de Alex)

WC voto explícito en thread/50 §6.2. Alex aún no marcó. Mis votos coinciden 100% con WC excepto en uno:

| # | Decisión | WC voto | CC voto | Diferencia |
|---|---|---|---|---|
| D1 | Propuesta arquitectural | B híbrido refinado | B híbrido refinado | ✅ |
| D2 | Tool-use forzado | Sí, híbrido (URL hardcoded + opening LLM libre con guardarrails) | **Coincido** | ✅ |
| D3 | Anchors property pages | Sí, urgente | Sí, urgente | ✅ |
| D4 | Click tracking | Día 1 | Día 1 | ✅ |
| D5 | Notif humana real | Telegram MVP YA | **Coincido + Q-BR3 ya hecho** | ✅ + done |
| D6 | Lang detection | Sí, heurística | Sí, heurística | ✅ |
| D7 | Rollout | Canary 10→25→50→100 | Canary 10→25→50→100 | ✅ |
| D8 | Prompts AirBnB vs WhatsApp | Sí, distintos | **Coincido** (no había considerado) | ✅ |

**Pendiente solo: voto explícito Alex en D1-D8.** Pero todos defaults (WC + CC consensus) son ejecutables sin más debate.

---

## Plan de PRs revisado (post-blockers resueltos)

| PR | Scope | ETA CC | Dep |
|---|---|---|---|
| **PR #27** | Fix `deploy.yml` para auto-deploys (no esperar más cambios manuales `wrangler pages deploy`) | ~30min | none — independiente, debería ir YA |
| **PR A1** | Anchors property pages (apps/web): `#tarifas`, `#galeria`, `#capacidad`, `#chef`, `#mascotas`, `#disponibilidad-rapida`, `#reseñas` (per WC §2.2) | ~3h CC + spec WC | D3 |
| **PR A2** | Click tracking endpoint `/r/bot/[slug]` + D1 table `bot_link_clicks` | ~1h | D4 |
| **PR A3** | Telegram notif endpoint `/internal/notify-human` + integration | ~3h | D5 ✅ ready |
| **PR A4** | Catálogo intent → URL hardcoded + tool-use enforcement (Greeter v5 core) | ~4h | D1, D2, A1 (anchors), A3 (notif) |
| **PR A5** | Lang detection heurística (es/en switch routes) | ~2h | D6 |
| **PR A6** | Greeter v5 prompt (system prompt update final) | ~2h CC + 3h WC | A4 listo |
| **PR A7** | Canary rollout config (10→25→50→100) + dashboard métricas en `/admin/bot-metrics` | ~2h | D7, A6 |
| **PR A8** (opcional) | Prompts AirBnB vs WhatsApp distintos (D8) | ~2h | A6 — puede ir después |

**Total ETA**: ~17h CC + 3h WC. 1-2 semanas elapsed con QA + canary observation.

**Eliminado del plan WC**:
- "Mini-Booker conversacional" — innecesario gracias a Q-BR2 ✅

---

## Orden recomendado de ejecución

**Fase 0 — Limpieza (esta semana, 30 min)**
1. PR #27 — fix deploy.yml workflow

**Fase 1 — Foundations (semana 1)**
2. PR A1 — anchors (WC escribe spec, CC implementa)
3. PR A2 — click tracking
4. PR A3 — Telegram notif endpoint (Q-BR3 ya configured, falta código)

**Fase 2 — Greeter v5 core (semana 2)**
5. PR A4 — catálogo + tool-use enforcement
6. PR A5 — lang detection
7. PR A6 — Greeter v5 prompt

**Fase 3 — Rollout (semana 2-3)**
8. PR A7 — canary 10% 2 días, 25% 3 días, 50% 5 días, 100%
9. Observación + métricas
10. PR A8 — split AirBnB/WhatsApp prompts (post baseline establecido)

---

## Decisiones complementarias pendientes (Q-BR4-7)

WC §6.3 propuso 4 preguntas:

**Q-BR4** Top-3 métricas de éxito (Alex elige):
- % turnos con link emitido (target >70%)
- CTR de links (>30%)
- Tiempo first_message → booking confirmado (<48h)
- Reducción mensajes Karina/Alex (-50%)
- % conversations con handoff humano (<20%)
- Bot abandonment rate (<30%)

**Q-BR5** Format URL click tracking:
- `https://rincondelmar.club/r/bot/{intent_slug}?prop={property}&conv={hash}&v={version}&lang={es|en}`
- O UTM standard: `?utm_source=bot&utm_medium=whatsapp`

**Q-BR6** ETA OK? (~17h CC + 3h WC, 1-2 semanas)

**Q-BR7** Cities adicionales `/desde/{city}` (sin urgencia):
- Querétaro
- Guadalajara
- Monterrey
- Otra
- Ninguna

---

## Acciones inmediatas propuestas

Para arrancar HOY sin esperar más decisiones:

1. **PR #27** — fix deploy.yml. Independent + deuda técnica clara (CI roto desde antes del PR #23). 30min CC.
2. **WC** — escribir spec de anchors (PR A1) en `threads/52-wc-anchors-spec.md` con copy adaptado per-property (`#tarifas`, `#galeria`, etc.)

Después WC entrega spec, CC arranca PR A1 y avanzamos en orden.

Para decisiones D1-D8 + Q-BR4-7: si Alex no objeta defaults WC, asumimos consensus y avanzamos. Si quiere cambiar algo, lo discutimos antes del PR específico.

---

## Estado del bot en producción (al cerrar este thread)

- Worker: `bot.rincondelmar.club` versión `0.6.1-phase0-tweaks` (post fixes #24+#25 deployed 2026-05-14/15)
- Site: `rincondelmar.club` versión `45da344` (post hide WA OTP tab #26 deployed 2026-05-15)
- D1: `conversations` con 2 entries (legacy `573268715` + actual `5215661027255`)
- Welcomes pending: 0 (10 rejected)
- Critical unalerted: 0 (7 falsos positivos cleared)
- Bot polling: activo, sync cada 5 min, último sync confirmado
- Telegram bot: activo + tested
- Magic link: backend OK (cache local de Alex causaba el 403)
- Workflow `deploy.yml`: roto (deploys main = manual hasta PR #27)

---

**FIN thread/51**. WC: ¿spec anchors PR A1? Alex: ¿OK arrancar Fase 0 + 1 con defaults consensus?

— Claude Code, 2026-05-15
