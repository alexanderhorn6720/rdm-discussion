# Thread 01 — Alexander vota A1-A10

**Date**: 2026-05-10
**Author**: Alexander Horn (transcrito por Claude Code)
**To**: Web Claude `[@wc]`, Claude Code `[@cc]`
**Re**: Respuestas a las 10 preguntas `[@alex]` en QUESTIONS.md

---

## A1 — Repo público / privado mid-migration

> "¿Algún problema si ponemos repo público? Más práctico con Claude web."

**Voto: público OK**.

Razón de Alexander: facilita trabajo con Claude Web (que necesita PAT para privado pero acceso anónimo a público). Trade-off conscientemente tomado: el repo `rincondelmar-bot-discussion` queda público, el repo principal `rincondelmar-bot` (código de producción) sigue privado.

**Implicación operativa**: NO commit a `rincondelmar-bot-discussion`:
- Secrets, API tokens, customer PII.
- Booking IDs reales, subscriber IDs particulares.
- Stack traces con datos sensibles.

Para todo eso: chat directo con Claude Web/Code, o thread en repo privado.

---

## A2 — PriceLabs vs alternativas

> "Claude Web no analizó bien pricing agent actual en Make, es simple."

**Decisión: no se compra PriceLabs**. (Ver también A5.)

Contexto que Web Claude no tenía: el pricing agent actual en Make es simple — heurísticas básicas que Alexander gestiona directo. No justifica comprar SaaS $100/mes. La estrategia futura es construir lo mínimo necesario interno, no externalizar a PriceLabs.

**Implicación para `decisions/03-pricing-agent.md`**:
- Marcar opción A (PriceLabs) como **descartada**.
- Marcar opción E (híbrido) como **descartada**.
- Pivote a opción D (build) o variante: Worker propio que reemplaza el pricing agent simple actual de Make. Tiempo: empezar con heurística que ya está calibrada, no construir ML desde cero.
- Web Claude: por favor releer scenarios pricing en Make folder 316545 y documentar la lógica actual antes de proponer reemplazo.

**Acción para Claude Code**: NO crear `apps/pricing` con integración PriceLabs. Cuando llegue Fase 1 Sprint pricing, será port de la lógica simple actual a Worker, no buy.

---

## A3 — Timing 4.5 meses

> "Lo hacemos en esa semana :-)"

**Voto: OK con timing propuesto.** 18 semanas total con 20h/sem dedicación de Alexander es realista.

Sin hitos de negocio que fuercen reordenamiento. Calendario actual no requiere terminar antes de Navidad/Semana Santa.

---

## A4 — WABA propia Stage 2

> "Sí" (= usa el número actual)

**Decisión**: en Stage 2, migrar el número actual `+52 55 7061 8798` de ManyChat a WABA propia en Meta Business Manager.

**Implicación operativa**:
- Coexistence support de Meta permite mantener historial accesible en app, pero NO via API. Backup de conversaciones ManyChat antes de la migración es importante.
- Re-aprobación de templates HSM con Meta (1-2 semanas típico).
- Cero downtime no garantizado durante el switch — agendar para período de tráfico bajo (ej. mediados de semana, no fin de mes).

---

## A5 — Pricing override layer Stage 2

> "No habrá pricing labs"

**Decisión**: descartado el approach "PriceLabs + override". El pricing agent será 100% custom, basado en la heurística simple actual de Make.

Esto cambia significativamente `decisions/03`. Reescribir esa decision con focus en:
- Auditar el pricing agent actual de Make (qué señales usa, qué reglas).
- Port a `apps/pricing` Worker con cron diario.
- Incremental: agregar señales propias (occupancy histórica D1, intent del bot, eventos manuales).

---

## A6 — Magic link como único método de auth

> "Sí, o código por WhatsApp"

**Decisión**: magic link como default, pero **adicionalmente código por WhatsApp** como segunda opción.

**Implicación**:
- Better Auth ya tiene magic link funcionando. Mantener.
- WhatsApp OTP: en estado actual hay scaffolding parcial (PR3 spec menciona `/api/auth/wa-otp/{send,verify}` con ManyChat HSM template). En Stage 2 (WhatsApp Cloud API directo) se simplifica usar Cloud API direct para enviar OTP.
- Stage 1: usar ManyChat HSM template "rdm_otp" si está aprobado (verificar). Si no, defer a Stage 2.

**No hay password.** Confirmado.

---

## A7 — Roles iniciales

> "Admin soy yo en ese momento"

**Decisión**: roles iniciales como propuestos (`customer`, `staff`, `admin`, `chef`, `owner`). Inicialmente solo Alexander tiene rol `admin`. Otros se agregan cuando se sumen colaboradores específicos.

No hace falta agregar `accountant` ni `manager` por ahora — si llegan, se agregan trivialmente con la tabla `user_roles` (ver `decisions/05`).

---

## A8 — APK timing

> "Timing TBD"

**Decisión**: PWA día 1 confirmado. APK on demand cuando justifique. Sin compromiso de fecha. Re-evaluar en 6-12 meses post-PWA launch según uso real.

---

## A9 — Sunset ManyChat completo

> "Sunset sin problema"

**Decisión**: ManyChat sale completo en Stage 2. No hay broadcasts ni marketing flows que el equipo use fuera de los bots que justifiquen mantenerlo.

Calendario: post-Stage 2 (mes 4+), tras coexistence period de 2-4 semanas, cancelar subscription Make + ManyChat en Fase 5 (semana 16-18).

---

## A10 — Domain destinations

> "Sí" (= confirma todos)

**Decisión**: dominios confirmados como propuestos:

| Dominio | App |
|---|---|
| `rincondelmar.club` | `apps/site` (= `apps/web` actual, Astro) |
| `bot.rincondelmar.club` | `apps/bot` |
| `admin.rincondelmar.club` | `apps/admin` (PWA) |
| `api.rincondelmar.club` | `apps/api` |
| `webhooks.rincondelmar.club` | `apps/webhooks` |
| `tours.rincondelmar.club` | `apps/tours` (= `apps/worker-tours` actual, **ya live**) |
| `pago.rincondelmar.club` | **A confirmar**: ¿sigue como user-facing post-pago landing, o desaparece cuando `apps/webhooks` tome el webhook MP? |
| `reservar.rincondelmar.club` | **A retirar**: legacy worker, decommission antes de Fase 0 (ver CC-WC3). |

**Pregunta pendiente para Alexander**: ¿`pago.rincondelmar.club` mantiene las páginas user-facing `/exitoso`, `/fallido`, `/pendiente` que renderiza hoy `apps/worker-pago`, o esas páginas se migran a `rincondelmar.club/pago/{exitoso,fallido,pendiente}`?

Mi recomendación (Claude Code): mover a `rincondelmar.club/pago/*` para reducir subdominios y mantener brand consistency. `pago.rincondelmar.club` se desactiva cuando `apps/webhooks` toma el webhook MP. Pero NO bloqueante para Fase 0.

---

## Resumen para Web Claude

| # | Decisión |
|---|---|
| A1 | Repo público OK |
| A2 | NO PriceLabs — pricing custom basado en lógica simple actual de Make |
| A3 | 4.5 meses con 20h/sem |
| A4 | Migrar número actual a WABA propia |
| A5 | Pricing 100% custom, no SaaS |
| A6 | Magic link default + WhatsApp OTP como segunda opción |
| A7 | Alexander = único admin inicialmente |
| A8 | APK on demand sin fecha |
| A9 | Sunset ManyChat completo en Stage 2 |
| A10 | Dominios confirmados; `pago.r.club` y `reservar.r.club` a definir/retirar |

## Acciones para Web Claude

1. Reescribir `decisions/03-pricing-agent.md` con focus en build custom + auditar pricing actual de Make.
2. Marcar `airdm` y `reservar` workers para investigation/decommission (CC-WC2, CC-WC3).
3. Verificar via Cloudflare MCP que `database_name` es `rincon` (CC-WC1).
4. Pivote en `decisions/05` para reflejar Better Auth en producción + WhatsApp OTP como segunda opción auth.

## Acciones para Claude Code (yo)

Una vez Web Claude integre los cambios:
1. Arrancar Sprint 0 (Turborepo monorepo refactor) en branch `chore/monorepo-turborepo`.
2. NO crear `apps/pricing` con PriceLabs. Esperar audit del pricing agent actual antes de port.

---

*FIN. Web Claude integra cambios → Sprint 0 puede arrancar.*

— Alexander Horn (transcrito por Claude Code), 2026-05-10
