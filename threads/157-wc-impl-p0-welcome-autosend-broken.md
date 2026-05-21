# 🚨 Thread/157 · P0 ALERT · Welcome auto-send silently broken

**From**: WC-Implementation (Day 1 second-pass)
**To**: Alex (lectura prioritaria al despertar)
**Date**: 2026-05-21 ~05:45 UTC
**Severity**: 🔴🔴🔴 **P0**
**Discovery**: D1 evidence query during Day 1 second-pass audit

---

## TL;DR

Durante el second-pass audit descubrí en D1 que **10 bookings con arrival próximas 14 días NO tienen welcome record en pending_welcomes**. **Sara Ramos llega MAÑANA 2026-05-22**.

El flow welcome auto-send está roto silently desde aprox 2026-05-14 (`manual_batch_reject` cleanup).

Esto es PEOR que el F-6 de audit-2026-Q2 (que dijo "12/37 pending welcome catch-up button no se usa"). Reality: el catch-up button es irrelevante porque el flow underlying NO está creando nuevos rows en pending_welcomes.

---

## Lista de bookings impactados

| Arrival | Property | Guest | Phone | Welcome status |
|---|---|---|---|---|
| 🔴 **2026-05-22 (mañana)** | Rincón del Mar | Sara Ramos | +52 5584910041 | NULL |
| 🔴 **2026-05-22 (mañana)** | Huerta Cocotera | Claudia Becerra Alcantara | +52 5516264567 | NULL |
| 🔴 **2026-05-22 (mañana)** | Las Morenas | Erik Tchalla Molina Mendez | +52 5534956750 | NULL |
| 2026-05-24 | Rincón del Mar | Alexander Horn (direct) | +52 15661027255 | NULL |
| 2026-05-25 | Rincón del Mar | Alan Granados (direct) | +52 5582528741 | NULL |
| 2026-05-25 | Las Morenas | Lucero Valadez | +1 7144126946 | NULL |
| 2026-05-28 | Las Morenas | Yosselin Sánchez Osorio | +52 5574468496 | NULL |
| 2026-05-29 | Rincón del Mar | Marycarmen Cornejo Ortega | +52 15514935302 | NULL |
| 2026-06-01 | Las Morenas | Leticia Ramirez Lopez | +1 7792795326 | NULL |
| 2026-06-01 | Rincón del Mar | Araceli Garcia | +1 2076046453 | NULL |

---

## Acciones inmediatas (cuando despiertes)

### Hoy 2026-05-22 antes de 12pm CDMX

**A. Triage manual P0 (~15min)**:
- Mensaje manual via WhatsApp/Airbnb a Sara + Claudia + Erik (3 que llegan mañana)
- Plantilla rápida: "Hola {nombre}, te esperamos mañana en Rincón del Mar. Llegada después de 3pm. ¿Necesitas instrucciones de cómo llegar? — Karina"
- Marcar en GitHub Issues o nota personal que ya enviaste manual

**B. Decidir path-forward**:
- (a) Re-habilitar `pending_welcomes` flow con template ACTUAL (incluso si imperfecto) hasta que template nuevo esté listo
- (b) Backfill rows manualmente para las 10 → permite catch-up button usarse
- (c) Esperar template nuevo + accept window de ~2-3 días sin welcomes automatizados

**Voto WC**: (a) — riesgo de operación silente sin welcomes > riesgo de template imperfecto. Mejor algo decent que nada.

### Esta semana

**C. Asignar a CC el spec I0 (welcome auto-send rebuild)**:
- Spec pre-staged: `rdm-discussion/cc-instructions-bot/2026-05-21-i0-welcome-autosend-rebuild.md`
- Effort: 4-8h CC
- Prioridad ahora P0 ahead de los 5 originales Top 5

---

## Root cause analysis (preliminary)

### Evidence (D1 queries)

```sql
-- pending_welcomes tiene 10 rows, TODOS status='rejected'
SELECT status, COUNT(*) FROM pending_welcomes GROUP BY status;
-- → rejected: 10

-- Razón rejection (idéntica para los 10):
SELECT DISTINCT failed_reason FROM pending_welcomes;
-- → "manual_batch_reject_2026-05-14 — backlog cleanup post bot-fix-deploy: 
--    3 past arrivals (auto-generated en catch-up post polling fix), 
--    Moy/Ricardo ya con msg manual via Airbnb, 
--    otros pending hasta rebuild template enfocado a routear a rincondelmar.club"

-- Pero bookings nuevos NO entran a pending_welcomes:
SELECT bb.beds24_booking_id, bb.arrival, pw.status
FROM beds24_bookings bb
LEFT JOIN pending_welcomes pw ON pw.beds24_booking_id = bb.beds24_booking_id
WHERE bb.arrival >= date('now')
  AND bb.arrival <= date('now', '+14 days')
  AND bb.status NOT IN ('cancelled','archived')
  AND bb.room_id != 679176;
-- → 10 rows, TODOS welcome_status NULL
```

### Hipótesis (preliminary, requiere CC investigation)

1. **Cron de generación pending_welcomes no está corriendo** o crashed silently
2. **Polling fix mencionado en failed_reason** introdujo regresión que bloqueó nueva generación
3. **Template R2 key dependency**: si template key no existe, cron skip-and-continue silent
4. **Beds24 webhook drop**: si webhooks no llegan → cron no detecta new bookings → no row

Verificable en code review + `/admin/health` cron status + logs.

---

## Conexiones con audit findings previos

### audit-2026-Q2 follow-up F-1 (ManyChat 99.6% fail)

D1 confirma cumulative numbers PEOR:
- messenger_outbound: 1039 failed vs 88 sent = **92% failure ratio**
- Top error: 992× "Subscriber does not exist" (ManyChat tracking broken)

Aunque welcome rebuild se desbloquee, los SENDS seguirán failing si messenger_outbound roto. Ambos problemas compound.

### audit-2026-Q2 follow-up F-6 (12/37 pending welcome)

Esa cifra del audit anterior era simplificación. Reality post-D1:
- Catch-up button apunta a `pending_welcomes` table
- Tabla tiene 10 rejected (nada actionable)
- Bookings nuevos NO entran a tabla
- Karina ve "10 rejected", no ve los 10 fantasmas

Fix mínimo: surface ambos sets en `/admin/pre-stay`:
1. "Pending en tabla" (current view)
2. "Sin record" (new view) — joins beds24_bookings con LEFT JOIN pending_welcomes WHERE pw IS NULL

---

## Acción para Day 1 + Day 2 peer reviewers

### WC-Platform (Day 1)

Por favor lee este thread + `10-wc-impl-day1-second-pass.md` ANTES de finalizar tu `07-wc-platform-review.md`. Esta evidence cambia el ranking Day 0 Top 5.

### CC (Day 1)

Por favor lee este thread + `10-wc-impl-day1-second-pass.md` ANTES de finalizar tu `08-cc-tech-validation.md`. Adicionalmente:
- En `/admin/pre-stay` smoke test, verifica que las 10 upcoming bookings aparezcan o no
- En `/admin/health` cron status, verifica cuándo fue último heartbeat de cron-pre-stay-orchestrator o similar
- En logs locales, busca evidencia de welcome auto-send failures

### Synthesis Day 2 (WC-Platform)

I0 (welcome rebuild) debe entrar al Top X final ahead del Day 0 Top 5. ~4-8h CC. Spec ya pre-staged.

---

## Verdict

🔴 **No esperar Day 3 ranking**. Cuando despiertes, primer task = manual outreach a Sara/Claudia/Erik. Segundo task = decidir rebuild path (a/b/c).

CC spec I0 está listo cuando elijas path-forward.

---

**Signed**: WC-Implementation, brain mode Day 1, urgent escalation per audit second-pass evidence. 2026-05-21 ~05:45 UTC.
