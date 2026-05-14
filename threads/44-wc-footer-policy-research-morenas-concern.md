# Thread 44 — Footer industry research + 🚨 Morenas servicio policy risk

**Date**: 2026-05-13
**Author**: Web Claude (WC)
**To**: Alex `[@alex]` — decision Q-A13 + new policy risk awareness, Claude Code (CLI) `[@cc]` — visibility (NO action requerida en esta thread)
**Re**: AirBnB Off-Platform Policy update 2026 invalida WC opción B IG handle. Research + opciones nuevas. Raise Morenas servicio modelo = posible policy violation worth investigating.

---

## 0. TL;DR

🚨 **AirBnB Off-Platform Policy endureció 2026** (artículo 2799 + new ToS Feb 2026):
- **Prohibido** sharing email addresses, phone numbers, personal websites en messages
- **Prohibido** suggesting guests contact "outside of Airbnb" for repeat/future bookings
- **All fees must be disclosed through AirBnB pricing tools** — collecting separately is violation

**Mi opción B previa** (footer `@villarincondelmar` IG handle) **probablemente viola** la policy actual. Necesito revisar opciones más conservadoras.

**Nuevo concern crítico**: el modelo Morenas servicio OPCIONAL ($1,000/$1,500 cobrado en efectivo a llegada) podría ser violación del fee disclosure rule. Worth investigating antes de Fase 1b cleanup que ya menciona esto explicit en templates.

---

## 1. Lo que dice la policy 2026

Sources researched:
- AirBnB help article 2799 (Off-Platform Policy)
- StaySTRA 2026 ToS update analysis
- Cascadia Getaways 2026 host alert
- BiggerPockets host community discussion (March 2026)

Key quotes (paraphrased):
- Hosts **can no longer** suggest guests contact them outside AirBnB for questions or direct bookings
- Sharing email addresses, phone numbers, or personal websites = explicitly prohibited
- All fees (cleaning, pet, resort, security deposits, **extra services**) must be disclosed through AirBnB pricing tools
- Hiding fees or collecting separately = violation → listing suspension risk

Mexico-specific: AirBnB Payments Mexico (post-March 2026) handles transactions, new payment verification requirements.

---

## 2. Implicaciones para footer cleanup Q-A13

### Mi opción B previa (IG handle `@villarincondelmar`) — INVALIDADA

Razón: handle Instagram con `@` = potentialmente interpretable como sharing social media handle to bypass platform. AirBnB algoritmo + policy ambiguity = riesgo medio-alto.

### Opciones revisadas (Mayo 2026)

**Opción A: Eliminar footer completamente** (WC vote)
- Mensajes AirBnB cero hint a canal externo
- Para hint use: placa física in-property + QR code post-checkout
- Post-stay 2-3 días después: Karina contacta vía WhatsApp con tel de la reserva (zona gris pero más tolerada per host community)
- Riesgo penalización: **mínimo**
- Efectividad direct booking: medio-bajo (guests motivados deben recordar marca)

**Opción B-revisada: Firma branded sin hint canal**
```
— Alexander
Rincón del Mar 🌅
```
- "Rincón del Mar" = marca, no URL
- Guests motivados googlean → orgánicamente llegan al sitio
- Cero pista WhatsApp/email/URL/social
- Riesgo: **mínimo**
- Efectividad: medio (depende reconocimiento de marca)

**Opción C: Provocar curiosidad memorable**
```
— Alexander · 🌅 Rincón del Mar
```
- Branding sin pista directa
- Guests recuerdan, buscan después
- Riesgo: mínimo
- Efectividad: medio

**Opción D: Status quo `--> rincondelasmorenas / --> rincondelmar`**
- Cripticidad protege legalmente (AirBnB algoritmo no decodea fácil)
- Pero post-2026 policy update, AirBnB human reviewer **podría** interpretar como pista a website externo
- Riesgo: medio (gris)
- Efectividad: alto para guests que decodean

### WC vote final

**A (eliminar) o B-revisada (firma branded)** según preferencia Alex.

- A si Alex prioriza zero-risk
- B si Alex quiere algún branding pero zero hint a canal

Alternativas A + B son **defensivamente más seguras** que la C originalmente propuesta.

---

## 3. 🚨 Nuevo concern: Morenas servicio OPCIONAL

### El issue

Per Q-A1 confirmed:
> AirBnB Morenas: servicio OPCIONAL con pago extra:
> - $1,000/noche (≤16 pax, dos cocineras)
> - $1,500/noche (>16 pax, tres personas + mozo)
> - Cobro en efectivo a llegada (NO via AirBnB)

Per policy 2026:
> All fees (cleaning, pet, resort, security deposits, extra services) must be disclosed through AirBnB pricing tools. Hiding fees or collecting separately is a violation.

**Análisis**:
- "Servicio opcional cocina" puede argumentarse como "additional service" no obligatorio
- Pero si el guest acepta + paga $1,000-1,500/noche en efectivo, eso es transacción off-platform
- AirBnB historically tolerated optional add-ons paid in person (massage, extra cleaning, etc.)
- Pero 2026 update endureció esto

### Risk level: 🟡 MEDIUM

Probably no penalización inmediata (modelo es "optional service" no "hidden fee mandatory"), pero:
- AirBnB puede pedir que sea disclosed en pricing tools
- O moverlo a AirBnB Experiences (chef como servicio en plataforma)
- O cobrar via Resolution Center post-arrival (más auditable)

### Acciones recomendadas

1. **Antes de Fase 1b cleanup** (que va a modificar template `3 - Morenas` clarificando servicio OPCIONAL $1,000/$1,500): Alex valida que mencionar precio en template inquiry está OK o si mejor solo decir "servicios opcionales disponibles, contactar"
2. **Consultar AirBnB host support**: pregunta directa "¿permitido cobrar servicio opcional cocina off-platform al guest?" (en español, vía panel host)
3. **Considerar AirBnB Experiences** para chef Morenas: hace el servicio bookable + paid via AirBnB. Pros: cero violación. Cons: AirBnB toma fee adicional.
4. **Status quo si Alex acepta riesgo**: marcar en parking lot, monitor por warnings de AirBnB

### Decisión

⚠️ **Bloquea Fase 1b** task "Fix template `3 - Morenas` clarificando servicio OPCIONAL $1,000/$1,500" hasta Alex confirma approach.

Opción A: mencionar precios en template (status quo, mediano riesgo)
Opción B: mencionar "servicios opcionales disponibles, consultar Karina/Alex" SIN precios (más conservador)
Opción C: migrar a AirBnB Experiences (futuro, no Fase 1b)

---

## 4. Bot conditional Q-A15 still OK

El render conditional del bot (`bookings.channel == airbnb` → render OPCIONAL info) está OK porque:
- Bot habla a guests que YA tienen booking AirBnB confirmado
- Mencionar servicio opcional disponible al post-booking guest NO es ad/marketing
- Es info operacional ("durante tu estancia puedes contratar chef extra")

Pero ojo:
- Bot NO debe mencionar pagos en efectivo explicit
- Mejor: "el servicio opcional se coordina al llegar con Karina"

---

## 5. ENV var feedback

Alex pregunta: "Setup ENV var done - a mi no me necesitan ahi? por admin?"

**Respuesta**: No, Alex YA estás cubierto por `ADMIN_EMAILS` existente. La función `isContentEditor` (thread/42 §2.2) hereda admin access:

```typescript
export function isContentEditor(env, email): boolean {
  if (!email) return false;
  if (isAdmin(env, email)) return true;   // ← admins son automáticamente content_editor
  // resto lógica
}
```

Quien está en `ADMIN_EMAILS` tiene acceso total: `/admin/templates`, `/admin/health`, `/admin/airbnb-content`, futuro `/admin/leads`. No redundante.

Karina con `CONTENT_EDITOR_EMAILS=karina@rincondelmar.club` solo `/admin/airbnb-content`. Restringida by design.

Verificación: cuando CC implemente, Alex puede ver Content + todos los otros menús en `/admin`. Karina cuando entre solo verá Content.

---

## 6. Action items

### Alex (decisión inmediata)

- [ ] Q-A13 footer: vote **A** (eliminar) o **B-revisada** (firma branded sin hint canal). WC vote A.
- [ ] Morenas template inquiry: **A** (mantener precios en template, riesgo medio) o **B** (remover precios, decir "consultar", más conservador). WC vote B por now.
- [ ] (Opcional defer) Investigar AirBnB Experiences para chef Morenas, fix definitivo policy compliance

### WC standby

- [ ] Esperar Alex decision Q-A13 final
- [ ] Después arranco drafting RdM ES como propiedad piloto (sin signature decidida no puedo cerrar fields)

### CC visibility

- [ ] Read this thread for awareness
- [ ] **Pause** Fase 1b cleanup task "Fix template `3 - Morenas`" hasta Alex resuelve Morenas servicio approach
- [ ] Otras Fase 1b tasks (footer cleanup approach pendiente Alex, "inseguridad" → "alejado del bullicio", bodas $1,400, reseñas count) pueden proceder cuando Alex Q-A13 confirmada

---

## 7. Status

- ✅ ENV var Alex done
- ✅ thread/42 + thread/43 GO oficial
- 🟡 Q-A13 needs revision per 2026 policy
- 🟡 Morenas template approach needs Alex decision
- 🟢 Bot conditional Q-A15 sin cambios
- 🟢 CC sigue Fase 0.5 + parts of Fase 1b + Fase 1.5 build (path no bloqueado por estos 2 items)

— Web Claude (WC), 2026-05-13
