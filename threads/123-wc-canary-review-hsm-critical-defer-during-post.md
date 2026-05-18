# 123 — WC: thread/122 review — HSM as critical path + during/post-stay defer + cancel-race investigation

**Date**: 2026-05-18 night
**Author**: WC
**To**: CC-Bot + Alex
**Re**: thread/122 canary results review. HSM templates promoted from "nice-to-have" to **production critical path**. During-stay + post-stay specs deferred 1-2 weeks per stabilization. Cancel-race risk surfaced from Beds24 dump (37% cancel rate).
**Mode**: review + decision
**Status**: 🟢 Canary verified ✅. HSM is now the blocker for direct bookings coverage (32 of 75 = 43%). Pre-stay v1 partially complete — full coverage requires HSM ship + subscriber-sync merge.

---

## TL;DR

Pre-stay MVP shipped, canary verified, 19 real welcomes delivered. The architecture is sound. Three follow-ups from thread/122 are addressed here:

1. **HSM templates**: promote from §4 footnote to **production blocker for direct bookings**. 4 templates needed, ManyChat→Meta approval cycle 1-24h, Alex action.
2. **During-stay + post-stay**: defer 1-2 weeks per Week-1 stabilization observation. Speccing now is premature optimization.
3. **Cancel-race risk**: 37% Beds24 cancel rate means a non-zero number of pre-stay sends will land on already-cancelled bookings (small window between scan and webhook). Mitigation proposed.

Plus A4 micro-amendment (catch-up window `[now, now+14]`) and A5 still queued.

---

## §1 · HSM templates — production critical path

### §1.1 · Scale check

CC's thread/122 §2 reveals real universe:

| Channel | Active pre-stay bookings | Welcome status |
|---|---|---|
| AirBnB / OTA (Beds24 messages route) | 43 | 18 sent, 25 pending |
| Direct (ManyChat route) | 32 | 1 sent (canary), **31 will fail without HSM** |
| **Total** | **75** | 19 / 75 (25%) |

My previous analysis used 19-20 (only `arrival in 28 days`). CC's scan covers the full forward window (welcome detection has no arrival cap upstream of `welcome_sent_at IS NULL`). The 75 number is the right metric.

**Direct bookings are 43% of pre-stay universe.** Without HSM, that's a 43% coverage gap. Alex's stated objective ("todos los huéspedes que arriven en próximas 4 semanas reciben pre-arrival info") is unmet at this gap size.

### §1.2 · HSM is mandatory (revising my earlier "approve with caveats")

In thread/122 §4, CC clarifies that `setCustomField + sendFlow` worked for Alex's canary **only because Alex had a recent inbound (CSW open)**. New direct subscribers without prior inbound will fail the 24h check regardless of approach.

My earlier thread/121 caveat-A path ("HSM with CTA, full template later") still holds — but the HSM itself is no longer optional. It's the only path to direct booking coverage.

### §1.3 · Template design — vote on path

Three approaches from CC's proposal + my caveats:

| Path | Templates count | Approval surface | Coverage trade-off |
|---|---|---|---|
| **A** | 4 templates × 1 property (use {{property}} var) | Smallest Meta review surface | Property differences in variable substring only |
| **B** | 4 templates × per-property variant | 16 templates → multi-day Meta review | Per-property tone preserved |
| **C** | 4 templates condensed + "responde para detalle" CTA | 4 templates | Free-form full template sent after guest replies (opens CSW) |

**My vote: C + A combined.** 4 templates total, condensed (~800 chars each), property as variable, CTA "responde para detalle" at end. After guest responds, the full TS template (with property-specific richness) sends in the now-open CSW. This:

- Minimizes Meta approval risk (4 templates, UTILITY category, transactional booking update)
- Preserves direct-booking coverage day-1 (HSM lands always)
- Preserves full template richness for engaged guests (CTA path)
- Aligns with WhatsApp Business policy intent (transactional + opt-in via booking)

CC's proposed welcome template (~600 chars) already fits. T-14 and T-7 need trim from 1200-1800 → 800. Drafts below in §1.5.

### §1.4 · Variable shape — strict 3 variables

WhatsApp HSM template policy: variables 1-3 strongly preferred for UTILITY category (4+ triggers stricter review, may be reclassified MARKETING). My condensed templates need to fit:

```
{{1}} = guest_first_name (text, 1-25 chars)
{{2}} = property_name (text, 1-50 chars; e.g. "Villa Rincón del Mar")
{{3}} = arrival_date_formatted (text, 1-30 chars; e.g. "viernes 24 de mayo")
```

CC's T-14 condensed proposal added `{{4}} = chef_phone`. Re-think: instead of variable, hardcode "consulta a Karina por WhatsApp después de recibir este mensaje". The chef phone is sensitive to expose in template body anyway (Meta scrutinizes contact info in HSMs). Move chef phone to **free-form follow-up** after guest CTA reply.

### §1.5 · Final 4 templates (condensed, ≤800 chars, 3 vars each)

#### `rdm_pre_stay_welcome_es` (UTILITY)

```
¡Hola {{1}}! 🌅

¡Gracias por reservar {{2}}!

Tu llegada es el {{3}} a las 3 PM.

Yo soy Alexander, dueño hace 9 años. Karina los recibe en persona el día de su llegada y está disponible toda su estancia.

Te escribo de nuevo:
• 2 sem antes: ocasión especial, headcount, chef
• 1 sem antes: kit pre-llegada completo
• 1 día antes: instrucciones de check-in

¿Algo que quieras preguntar ahora? Responde aquí.

— Alexander 🌅
```

(~480 chars)

#### `rdm_pre_stay_t14_es` (UTILITY)

```
¡Hola {{1}}! 🌅

Faltan 2 semanas para tu llegada a {{2}} el {{3}}.

Para preparar bien tu estancia, confírmame por favor:

1) Headcount final (si es grupo grande, hay tarifa por persona extra arriba de la base)

2) ¿Alguna ocasión especial? Cumpleaños, aniversario, retiro — podemos ayudar con cena en el jardín, mesero/cocinera nocturna, DJ.

3) Dieta/alergias importantes

Responde "detalles" para que te cuente del chef y opciones de transporte.

— Alexander 🌅
```

(~510 chars)

#### `rdm_pre_stay_t7_es` (UTILITY)

```
¡Hola {{1}}! 🌅

1 semana para tu llegada a {{2}} el {{3}}. Datos clave:

📍 Ubicación en rincondelmar.club/llegar
🌤️ Clima: busca "clima Pie de la Cuesta Acapulco" en Google
🚗 Recomendado: libramiento Acapulco-Zihuatanejo, caseta La Venta
🐾 Mascotas: $300 MXN por mascota por estancia, máx 2

Responde "kit" para recibir detalles completos (chef/cocina, supermercado cercano, actividades, restaurantes).

¿Algo más? Avísame.

— Alexander 🌅
```

(~470 chars)

#### `rdm_pre_stay_t1_es` (UTILITY)

```
¡Hola {{1}}! 🌅

Mañana es tu llegada a {{2}}.

📍 Maps: rincondelmar.club/llegar
🕒 Check-in desde 3 PM
🕒 Check-out 11 AM
📶 WiFi: Karina te lo da al llegar
🌤️ Pronóstico: busca "clima Pie de la Cuesta" en Google

Cualquier emergencia llegando, este chat.

¡Te esperamos!

— Alexander 🌅
```

(~340 chars)

### §1.6 · EN counterparts

Same shape, literal translation. CC has the TS templates EN equivalents — adapt them to condensed form. WC voto: CC does the EN trim during ManyChat UI submission (Alex/Karina handle ES, CC drops EN in same PR).

### §1.7 · Alex actions for HSM submission

| Step | Owner | Effort |
|---|---|---|
| 1 | Open ManyChat → WhatsApp → Templates → Create new | Alex | 5 min |
| 2 | Submit 4 templates ES (use §1.5 copy verbatim) | Alex | 20 min |
| 3 | Submit 4 templates EN (CC drops EN drafts via thread) | Alex | 20 min |
| 4 | Wait for Meta approval | passive | 1-24h |
| 5 | Once approved, create 4 ManyChat Flows (1 per touchpoint) that invoke the approved template | Alex | 30 min |
| 6 | Share each flow_ns with CC for env var wiring | Alex | 5 min |
| 7 | CC adds `MANYCHAT_FLOW_PRE_STAY_{TOUCHPOINT}_NS` env vars + code dispatch | CC | 1-2h |
| 8 | Smoke test with new direct booking | Alex + CC | 30 min |

**Total Alex time**: ~80 min spread across 1-3 days (Meta review wait).

### §1.8 · Until HSM approved — interim coverage

Until §1.7 completes, direct bookings without prior CSW will fail. Options:

| Option | Action | Trade-off |
|---|---|---|
| Pause direct booking pre-stay sends | Filter `routed_to='manychat'` in scan | Misses 32 guests temporarily |
| Manual Alex/Karina send via drawer | Per-row manual via `/admin/pre-stay` | Sustainable for low volume (~3 direct/wk?) |
| Subscriber-sync (PR #112) covers part | Auto-create subscriber → still hits 24h block | Half solution |

**Vote**: combination — subscriber-sync runs (creates subscribers preemptively), Alex/Karina manual-fire direct bookings via drawer (with manual phrase like "Hola, soy Alexander..."), then HSM lands and auto-cron takes over. Bridge period 1-3 days.

---

## §2 · During-stay + post-stay — defer 1-2 weeks

CC asks for spec direction (§6.1 thread/122). My vote: **defer**.

### §2.1 · Why defer

| Reason | Detail |
|---|---|
| Pre-stay v1 not yet stable | 75 universe, 19 sent, 5+ failures observed, 3 hotfixes in canary. Need Week-1 observation before scope expansion |
| Post-stay needs Client Bot Phase A | Review timing, sentiment monitoring, escalation — not just template-render. This is TIER 5 in pipeline future |
| During-stay needs reply handling | "Hay un problema con el AC" can't be answered by next-touchpoint template. Reply handling is separate scope |
| HSM bandwidth | Adding 4-8 more HSM templates now expands Meta approval surface 2-3x and slows down pre-stay HSM ship |
| Karina onboarding | Handoff objective requires Karina active in `/admin/pre-stay` and `/admin/inbox` before adding touchpoints she'll also need to monitor |

### §2.2 · When to spec

After **2 consecutive weeks of pre-stay green metrics**:
- Cron error rate < 5% sustained
- Direct bookings coverage > 90% (HSM ship done)
- No guest complaints about template content
- Karina actively managing skips/sends in drawer

Estimated calendar: 2-3 weeks from today (2026-06-01 to 2026-06-08).

### §2.3 · Backlog placement

Updated BACKLOG.md sequencing:

| Tier | Item | Effort | When |
|---|---|---|---|
| Pre-stay stabilization | Welcome flag flip per direct booking + subscriber-sync ship + HSM approval cycle | 8-12h CC + 80min Alex + Meta review | Week 1 |
| Pre-stay full ramp | All 4 touchpoints autonomous, both channels, all properties | observation | Week 2 |
| **Then**: during/post-stay spec | WC brain deep — `t_arrive`, `t_mid_stay`, `t_checkout`, `t_post_stay` | 1.5-2h WC | Week 3+ |
| Client Bot Phase A spec | Reply handling, escalation, sentiment | separate effort | After during/post-stay v1 |

### §2.4 · Quick sketch for context (not the spec, just the shape)

When spec time comes, expect:

| Touchpoint | Cron timing | Channel | Content gist |
|---|---|---|---|
| `t_arrive` | day-of, 13:00 MX (2h pre-check-in) | WA or Beds24 | "Tu villa lista. Karina te recibe a las 3 PM. WiFi al llegar." |
| `t_mid_stay` | day 2-3 if stay >4 days | WA | "¿Cómo va todo? ¿Algo que necesitan?" — engagement-only, sender expects reply or silence |
| `t_checkout` | day-of, 9:00 MX | WA | "Check-out 11 AM. Karina pasa por las llaves." |
| `t_post_stay` | day+1, 10:00 MX | WA | "Gracias por hospedarse. Si tienes 30 segundos, deja una reseña en AirBnB: [link]" |

`t_mid_stay` is the riskiest — silent absence is desired UX, not failure. Need careful skip-logic: only fire if guest hasn't messaged in last 24h.

But this is all premature without pre-stay stabilization data. Park here.

---

## §3 · Cancel-race risk (37% Beds24 cancel rate finding)

CC's thread/122 §5: Beds24 historical dump shows **414 cancelled / 1,119 total = 37% cancel rate**. That's high — means in any given 4-week window, a meaningful number of "booked" bookings will cancel before stay.

### §3.1 · Race window

Pre-stay scan filters `status='booked'`. But there's a small window:

1. Cron scan @ T=0 returns booking B (status='booked')
2. Beds24 webhook for B cancellation arrives @ T=0.5s
3. Webhook normalize handler updates B.status='cancelled' @ T=2s
4. Pre-stay cron sends message to B @ T=3s (already cancelled)

Result: **ghost send to a cancelled booking**. Guest gets pre-arrival message hours/days after they cancelled. Bad UX.

### §3.2 · How often?

Estimation: at 30 bookings/month, 11 cancellations/month (37%). If cancel ↔ pre-stay send racing happens, even at 1% race probability = ~1.3 ghost sends/year. Low but not zero.

A more impactful path: bookings cancel **days** after the cron sends. Pre-stay T-14 send today, guest cancels in 5 days → guest already received T-14 message. Less of a race, more of a stale-info problem. **This is the bigger volume**: probably 30-40% of cancellations happen post-some-pre-stay-touchpoint.

Mitigation needed? **Probably no, accept**: the guest who cancels mid-process doesn't care that they received a pre-stay message 3 days ago. The opposite (no message) is worse for guests who don't cancel.

### §3.3 · One concrete mitigation worth doing

**Re-check `status='booked'` immediately before send**, not just at scan time. Code change:

```typescript
async function sendOneTouchpoint(...) {
  // ... existing pre-send checks ...
  
  // Last-second status verify (mitigates race + stale scan results)
  const fresh = await env.DB.prepare(
    'SELECT status FROM beds24_bookings WHERE beds24_booking_id=?'
  ).bind(bookingId).first<{status: string}>();
  
  if (fresh?.status !== 'booked') {
    await audit(env, { ..., delivery_status: 'skipped_status_changed', failure_reason: `status=${fresh?.status}` });
    return { status: 'skipped' };
  }
  
  // ... continue to send ...
}
```

Cost: 1 extra D1 read per send (cheap, ~1ms). Benefit: closes the race window from seconds to <100ms.

Effort: 30-60 min CC. Worth folding into the A4 cleanup pass.

---

## §4 · Open items reconciliation

| From | Item | Status |
|---|---|---|
| thread/121 | A4 catch-up window `[now, now+14]` | CC noted in §6.2 "will fold into next PR" |
| thread/121 | A5 bulk approve + AirBnB write-back | CC noted in §6.3 "separate scope after pre-stay closes" |
| thread/122 | PR #112 subscriber-sync | In flight, near merge |
| this thread | 4 HSM templates submission | Alex action |
| this thread | Last-second status re-check in sendOneTouchpoint | CC fold into A4 cleanup PR |
| this thread | During/post-stay spec | WC, deferred 2-3 weeks |
| this thread | Karina `/admin/pre-stay` walkthrough | Alex+Karina 30-45 min |

---

## §5 · Recommended sequencing (revised)

Week 1 (now → 2026-05-25):

| # | Item | Owner | Effort |
|---|---|---|---|
| 1 | Alex: submit 4 HSM templates ES + EN to ManyChat | Alex | 80 min total over 1-3 days |
| 2 | CC: ship PR #112 subscriber-sync | CC | in flight |
| 3 | CC: A4 cleanup pass — add catch-up `[now, now+14]` + last-second status re-check + any residual fixes | CC | 1-2h |
| 4 | Alex+Karina: 30-45 min walkthrough `/admin/pre-stay` + drawer | Alex+Karina | 45 min |
| 5 | Alex: monitor messenger_outbound audit; flip flag OFF if surge of failures | passive | ad hoc |

Week 2 (2026-05-25 → 2026-06-01):

| # | Item | Owner |
|---|---|---|
| 6 | Meta approves HSM templates | passive |
| 7 | Alex creates 4 Flows in ManyChat UI | Alex |
| 8 | CC wires env vars + per-touchpoint flow_ns dispatch | CC |
| 9 | Smoke test new direct booking with HSM | Alex+CC |
| 10 | A5 start (bulk approve AirBnB content + write-back) | CC |

Week 3 (2026-06-01 → 2026-06-08):

| # | Item | Owner |
|---|---|---|
| 11 | A5 complete — all 8 AirBnB listings published from R2 | CC + Alex spot-check |
| 12 | Pre-stay green-light review: error rate, coverage, Karina activity | Alex + WC |
| 13 | **IF green**: WC brain deep during/post-stay spec | WC |
| 14 | FAQ curation 174 → 50-80 starts | Alex + Karina |

---

## §6 · Definition of done for "Pre-stay v1 complete"

Closure criteria (all must hold for ≥5 consecutive days):

- [ ] 4 HSM templates approved by Meta + wired in 4 ManyChat Flows
- [ ] Subscriber-sync cron running, no orphaned direct bookings without `manychat_subscriber_id`
- [ ] Welcome cron + T-14 + T-7 + T-1 crons all green (error rate <5%)
- [ ] `messenger_outbound` shows >90% direct bookings reach `sent` status within 30 min of eligibility
- [ ] A5 closure (all 8 AirBnB listings deployed from R2)
- [ ] Karina demonstrates skip + send-now in `/admin/pre-stay` drawer unassisted
- [ ] Alex weekly self-report: "responding ↓40% manual WA/AirBnB messages"

At that point: pre-stay v1 is complete. During-stay + post-stay spec opens.

---

— WC, 2026-05-18 night
