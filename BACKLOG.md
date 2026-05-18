# RdM Bot · Backlog Completo

**Fecha**: 2026-05-18
**Autor**: WC (brain mode)
**Alcance**: Bot conversacional + admin tools + features estratégicos
**Propósito**: Inventario único, exhaustivo, no perderlo en hand-offs futuros

**Relación con otros docs canónicos del repo**:
- `CONTEXT.md` → estado verificado del sistema (propiedades, stack, IDs). Source of truth técnico.
- `ROADMAP.md` → fases macro (Fase 0/1/2/3/4) con timeline mensual.
- `VISION.md` → norte estratégico de largo plazo.
- `BACKLOG.md` (este doc) → inventario operacional P2/P3 con effort estimates + sequencing.

Este doc NO reemplaza a los demás. Es complemento táctico para no perder items específicos entre sesiones. Si hay contradicción con `CONTEXT.md`, gana `CONTEXT.md`.

**Excluidos por scope**: Foundations + Charter, personal items, M1-M5 conceptual modules, ideas I11-I14 operations. Esos viven en `rdm-platform/` y `VISION.md`.

---

## 1 · Resumen ejecutivo

Hand-off documentation perdió items específicos de los buckets P2 y P3. Este doc consolida **TODO** el backlog descubierto a lo largo de threads 89-115 y memorias acumuladas, organizado por:

- **Estado actual** del sistema (qué está LIVE, qué está en pipeline CC)
- **P2 — Operational fixes** (sprints cortos, 1-8h cada uno)
- **P3 — Strategic features** (multi-day, requieren brain mode + spec)
- **Voto WC sequencing** post-pipeline-actual

Estimado total backlog: **~150-200h CC** + brain mode WC para specs.

---

## 2 · Objetivo

Construir el **journey huésped completo automatizado** end-to-end para Rincón del Mar (4 propiedades + Casa Chamán Q3), donde Alex interviene **por elección**, nunca por necesidad.

El bot conversacional fue la primera capa. Las siguientes capas son:

1. **Operational hardening** — fixes que están afectando users hoy
2. **Guest intelligence** — saber quién es el huésped antes de saludarlo (Guest 360)
3. **Proactive lifecycle** — bot escribe primero en pre-stay/in-stay/post-stay
4. **Revenue optimization** — upsells, drip campaigns, lost-booking recovery
5. **Analytics layer** — unit economics, forecasting, cancellation analysis
6. **Brand growth** — UGC pipeline, Casa Chamán launch coordinado

Métrica norte: **% de touch-points huésped manejados sin Alex/Karina activos** (hoy ~40-50%, target 90%+ pre-checkout, 70%+ in-stay).

---

## 3 · Espíritu

### Principios no-negociables

| Principio | Implicación práctica |
|---|---|
| **Beds24 source of truth** | Sync mode `Prices & Availability` ONLY. NUNCA `Everything` |
| **AirBnB source of truth para listings** | Bot no genera content de listings; sólo Karina edita |
| **No LLM en decisiones de dinero** | Pricing, descuentos, deducciones = deterministic logic. LLM solo para prose summary |
| **Bot nunca obliga, siempre habilita** | Alex interviene por elección, no por urgencia |
| **Encapsulación por módulo** | Bot pre-stay separado de in-stay, separado de post-stay. No "do-it-all bot" |
| **Multi-canal mismo prompt MVP** | WhatsApp + FB + IG + TikTok, single prompt; templates HSM fase final |
| **Debounce 8s sin excepciones** | Excepto `/start` y `/stop`. Sin typing indicator |
| **Mobile-first siempre** | Xiaomi 15 es el primary device de operación |

### Working modes (WC ↔ CC ↔ Alex)

| Mode | Output | Cuándo |
|---|---|---|
| brain | Análisis + opciones | Default, decisiones complejas |
| brain quick | Recommendation 5min | Decisión rápida |
| brain deep | Spec doc completa | 1h+ análisis pre-implementation |
| DoIt | Spec ejecutable autónomo | CC implementa sin permisos a cada paso |
| verify | Comandos guiados Alex | Validación pegada a sistema real |

Flujo típico: `brain → spec → DoIt → verify`.

### Anti-patrones generales

- ❌ Reintervenir CC en scope mid-flight (issue separada, no fix aquí)
- ❌ Bypass DoIt template v3 conventions
- ❌ Auto-merge PRs a main sin Y/N
- ❌ Force-push, delete branches, drop databases (DENIED en autonomy config)
- ❌ Promote a producción sin smoke test
- ❌ Casa Chamán visible en Greeter prompt antes de Q3 renovation

---

## 4 · Estado actual del sistema

### LIVE (no tocar sin razón fuerte)

| Componente | Status |
|---|---|
| Greeter V6 | 100% canary, telemetría verde |
| Booker | LIVE |
| Multi-canal AirBnB Connect API | Post-cutover 2026-05-12 |
| Beds24 integration | `/v2/inventory/rooms/calendar` source of truth |
| ManyChat WhatsApp | LIVE |
| Anti-loop guards | LIVE |
| Telegram alerts | LIVE |
| `/admin/conv` | LIVE |
| `/admin/bookings` | LIVE (PR #82 merged, post-feedback fixes shipped) |
| `/admin/inbox` | LIVE (PR #85 thread/105-106) |
| `/admin/airbnb-content` | LIVE (Karina pendiente onboarding) |
| `/admin/health` | LIVE |
| `/proxReservas` | LIVE post hotfix thread/113 |
| Beds24 backfill | LIVE 62 pre-webhook bookings recovered |
| Greeter V6 small items wave #1 | F+C+A+B shipped PR #87 thread/108 |

### Pipeline CC (queued ahora)

| Orden | Item | Effort | Status |
|---|---|---|---|
| 1 | thread/113 hotfix `/proxReservas` guest name | 30min | ✅ Pushed |
| 2 | thread/115 guests resync from Beds24 | 2-3h | ✅ Pushed |
| 3 | C+E+D+P2 sprint (thread/111 blessings) | 15-19h | ✅ Spec'd |
| 4 | thread/109 wave-2 G+H+I+J | varies | ✅ Spec'd |

Total CC autónomo pipeline: **~20-25h**.

### Datos clave del stack

| Recurso | Detalle |
|---|---|
| D1 database `rincon` | `d81622d7-32e2-40a3-9609-80813c0e8a96` |
| R2 buckets | `assetsrdm`, `rdm-knowledge` |
| KV | `KV_KNOWLEDGE` |
| WhatsApp business | `+52 55 7061 8798` |
| Beds24 propertyId | `31862` |
| Rooms | 78695 RdM · 374482 Morenas · 74316 Combinada · 637063 Huerta · 679176 Casa Chamán (hidden Q3) |
| Repos GitHub | `rdm-platform`, `rdm-bot`, `rdm-discussion` bajo `alexanderhorn6720` |
| Path local Windows | `C:\Users\Alexa\rdm\dev\{platform,bot,discussion}\` |
| Latest D1 migration | 0031 (post-thread/108), próximas 0032+ |

---

## 5 · P2 — Operational fixes

Sprints cortos, 1-8h cada uno. Pueden tomarse uno a la vez sin spec brain mode.

| # | Item | Effort | Trigger / contexto |
|---|---|---|---|
| P2.1 | **Welcome auto-send bug** — `pending_welcomes` no se crea pese a fix v2 | 2-4h | Mismo patrón "downstream pipeline never wired" que PR #80 |
| P2.2 | **Cron threshold ajuste per-cadence** | 30min | Thread/108 reveló false positive 15min para crones 5/15/30min/24h cadences |
| P2.3 | **Conversation rule tuning** `lead_cold_7d` → 5d | 15min | Thread/108: 5 closed `pause_expired`, 0 `lead_cold_7d` firing |
| P2.4 | **Pet fee uniformización** $300/estancia max 2 across 4 AirBnB listings | 1-2h Karina + tu approval | Memoria backlog desde mayo |
| P2.5 | **Gantt range default** 180d → 365d | 5min | Mencionado durante review |
| P2.6 | **Real logos swap** en `apps/web/public/logos/` | 5min tú + 30min CC | Pendiente desde Day 1 |
| P2.7 | **Rotar PAT expuesto** (ver memoria thread/56) + `ADMIN_REFRESH_SECRET` | 15min | Exposed en thread/56 |
| P2.8 | **Old paths cleanup** `C:\rincondelmar-*\` | 10min tú | Post-rename to `rdm-*` |
| P2.9 | **Strip " (AirBnB)" suffix retroactivo** ~30 guest names | Cubierto thread/115 edge 4 | Old rows stay; only new writes stripped |
| P2.10 | **Re-link 3 promo bookings** 86496769/86497786/86685323 → recipients reales | 1h investigación + manual | Separate dedupe post-thread/115 |
| P2.11 | **Re-dedupe Alex 2 guest records** (g_01KRSZ + g_XRP4Y5, phones distintos) | 1h | Separate dedupe post-thread/115 |
| P2.12 | **Beds24 webhook Phase C** — apply migration 0011 + secret + deploy + Beds24 panel config | 30min tú | Branch `feat/beds24-booking-webhook` ready commit aa23eaa |
| P2.13 | **Worker `rincon-bot` manual deploy** | 5min | Pendiente desde Greeter v5 Fase 1 |
| P2.14 | **PR #32 review** (BookingCard URL params) | 20min tú | Pendiente review |
| P2.15 | **Greeter v5 PR A1.5 sub-components spec** (`#chef`, `#mascotas`, `#capacidad`) | 1-2h brain mode | Pending spec from thread/58 |
| P2.16 | **AirBnB content sync** — CC R2 import drafts + Karina onboarding `content_editor` | 2-3h | Drafts 96/96 textboxes DELIVERED, sync pending |
| P2.17 | **Pet policy /noche→/estancia content-drafts retroactive** | 30min Karina | Transcription error thread/59 |
| P2.18 | **weekend_price RdM erróneo** + cache expiry post-Jun 2027 → Default fallback | 1h | Beds24 integration backlog |
| P2.19 | **Data Mining v2 Day 1 start** | CC autonomous | Q-54: awaiting mascotas policy (ya resuelta, puede arrancar) |

**Total P2 estimado**: ~25-35h trabajo (CC + Alex + Karina combinado).

---

## 6 · P3 — Strategic features

Requieren brain mode + spec doc antes de DoIt.

### 6.1 · P3-A · Guest 360

**Objetivo**: Saber quién es el huésped antes de saludarlo. Cross-property history, repeat detection, VIP segmentation, lifetime value.

**Scope total**: ~80h CC, ~2 meses calendario.
**Status memoria**: D1 Phase B tables built (`guests`, `leads`, `guest_events`, `beds24_bookings` — 0 rows ready for seed). Architecture approved.

| Phase | Scope |
|---|---|
| B.1 | Guest profile unified view across channels |
| B.2 | Repeat guest detection via phone match |
| B.3 | VIP tier segmentation — Bronce (1 stay), Plata (2-3), Oro (4+) per I8 |
| B.4 | Cross-property guest history |
| B.5 | Lifetime value calculation per guest |
| B.6 | Guest events timeline (bookings + messages + reviews) |
| B.7 | `/admin/leads` UI unificado |
| B.8 | Booking.com integration (deferred from initial scope) |

**Drivers downstream**: alimenta I1 pre-stay, I3 in-stay, I8 VIP, I9 drip, M4 staff scheduling.

---

### 6.2 · P3-B · Pre-stay notifications (I1 Pre-arrival concierge)

**Objetivo**: Bot proactivo escribe T-7d / T-3d / T-1d antes check-in con tono adaptado y upsells contextuales.

**Effort**: ~12-16h CC + brain mode spec.

| Component | Stack |
|---|---|
| Cron pre-arrival T-7d/T-3d/T-1d | Worker cron + Sonnet |
| Tone adaptation | LLM con context `beds24_bookings` + `guests` — familiar / corporate / honeymoon |
| Upsells contextuales | Tours, restaurantes, paseo laguna, fogata, masajes, paseo a caballo |
| Intents generación | `upsell:tour`, `upsell:fogata`, `upsell:masaje`, `upsell:transport` |
| Channel routing | WhatsApp primary (template HSM ACCOUNT_UPDATE fuera 24h), email fallback |

**Anti-patrón**: nunca enviar pre-stay si el huésped escribió en últimas 48h (sería ruido).

---

### 6.3 · P3-C · Ideas catalogadas (subset)

19 ideas totales en `rdm-platform/ideas/`. Aquí el subset relevante para hand-off (sin I11-I14 operations):

#### Guest experience (4)

| ID | Idea | Foundation requerida |
|---|---|---|
| I1 | Pre-arrival concierge AI personalizado | Cubierto en P3-B arriba |
| I2 | Digital check-in/out con QR — direcciones + Waze + código cerradura rota + house manual | R2 manuals + D1 `access_codes` |
| I3 | In-stay WhatsApp assistant — lane separado del Greeter pre-booking | V7 multi-bot personality routing |
| I4 | Welcome packet generator multilingüe — render PDF + send link, EN/ES/FR | Welcome-auto-send v2 (ya en `welcome-auto-send.ts`) |
| I5 | Post-stay review request automation — T+24h, plantilla suave, ≤3★ → Telegram | `reviews-sync.ts` ya tiene audit |

#### Revenue & marketing (5)

| ID | Idea | Detalle |
|---|---|---|
| I6 | Upsell engine post-booking | Catálogo: chef Morenas $1k-1.5k/d, transport, tours, masajes, fogata, decoración, DJ, fotos, paseo caballo. Tablas `addons_catalog`, `booking_addons` |
| I7 | Lost-booking recovery | User llena fechas+huéspedes sin pagar en 2h → bot WhatsApp con incentivo suave. Anti-spam: solo si dio teléfono explícito |
| I8 | Repeat guest VIP segmentation | Tiers Bronce/Plata/Oro (driver para P3-A) — discount auto, upgrade prob, welcome amenity, named greeting |
| I9 | Drip campaign post-cotización | Día+1/+3/+7/+14 anchor a cotización original. Cohort conversion tracking |
| I10 | Dynamic packaging | "Bodas grupo 40" / "Retiro corporativo" / "Año nuevo 4N+gala" — precio bundled vs à la carte savings visible |

#### Analytics & intelligence (3)

| ID | Idea | Detalle |
|---|---|---|
| I15 | Unit economics dashboard per booking | `revenue gross - commission canal - fees pago - costo chef/staff - grocery - consumibles - mantenimiento prorrateado - utilities prorrateado = net margin`. Revela cuál booking type es rentable real |
| I16 | Cancellation root cause analysis | Timing antes arrival + razón (guest input + AI inference) + refund amount + channel. Drive policy `deposit_non_refundable_threshold`. Campo `cancellation_reason` ya existe en `bookings` |
| I17 | Weather + event impact forecasting | Cross-ref `beds24_bookings.arrival` con pronóstico clima 14d + calendario eventos Acapulco (Tianguis, Foro, congresos, vacaciones SEP, mareas, alertas huracán jun-nov). Proactive reschedule preventivo |

#### Brand & growth (2)

| ID | Idea | Detalle |
|---|---|---|
| I18 | Guest UGC pipeline | T+7d post-stay opt-in "¿compartir foto/video con crédito?" → R2 upload + consent firma digital + Airtable queue Karina curar + post auto IG/TikTok con tag. Reduce ~90% tiempo Karina haciendo content |
| I19 | Casa Chamán launch playbook | Coordinador Q3 2026 — checklist T-90d (fotos, tour 360°, EN/ES, pricing, AirBnB listing, landing waitlist) · T-60d (drip históricos, IG/TikTok teaser) · T-30d (soft-launch VIP) · T-0d (público + Greeter prompt incluye 679176) · T+30d (review iteración) |

---

### 6.4 · P3-F · Bot lifecycle V7

**Objetivo**: Separar Greeter pre-booking de Concierge in-stay de Relationship post-stay.

| Lifecycle | Bot personality | Trigger |
|---|---|---|
| `booked` (pre-arrival) | Greeter actual | New conversation, lead nurturing |
| `in_stay` | Concierge bot (I3) | `beds24_bookings.lifecycle=in_stay` — operación casa, "¿cómo enciendo calentador?", "más toallas" |
| `past_stay` | Relationship bot | Post-checkout T+24h — review request, retention, drip |

**Decisión pendiente**:

| Voto | Aproach |
|---|---|
| WC-Implementation | 3 distinct prompts (`greeter-prebooking-v7`, `concierge-instay-v1`, `relationship-poststay-v1`) selected by router |
| WC-Platform thread/91 | 1 prompt con condicionales lifecycle internas |

**Tradeoff**: 3 prompts = separate concerns + caching + testing + debug; penalty = 3x management overhead. 1 prompt = single source of truth; penalty = condicionales explotan rápido.

**Acción**: Alex pick + WC spec deep mode antes implementation.

---

### 6.5 · P3-G · Beds24 Reviews API integration (Beta)

**Objetivo**: Ingestar reviews de huéspedes directamente desde Beds24 Reviews API Beta para display en sitio + bot KB enrichment, sin necesitar AirBnB OAuth.

| Component | Status |
|---|---|
| Reviews ingestion P1 | Spec pending |
| Display on `rincondelmar.club` | Spec pending |
| Bot KB enrichment con reviews | Spec pending |
| Client Bot Phase A | DEMOTED to P2 después de Reviews API discovery |

**Por qué importante**: ~360+ reviews históricas en AirBnB (rating 4.85) + Booking.com. Desbloqueadas en KB del bot suben significativamente la calidad de respuestas sobre "¿cómo es la propiedad?" "¿qué dicen huéspedes?".

---

### 6.6 · P3-H · 174 FAQs curation → 50-80 finales

**Objetivo**: Curar FAQ extraction (PR #81) a entries usable en Vectorize embeddings para Greeter KB retrieval.

| Status | Detail |
|---|---|
| Extracted | 174 candidates DELIVERED PR #81 |
| Pending | Curation Alex/Karina, finalize 50-80 |
| Phase next | Vectorize embeddings rebuild + Greeter KB retrieval |

**Effort**: 4-6h Alex + Karina manual review. CC handles Vectorize rebuild post-curación (~1h).

---

## 7 · Voto WC · sequencing post-pipeline-actual

Después que CC termine pipeline actual (thread/113 + 115 + C+E+D+P2 sprint + wave-2):

| Orden | Block | Razón |
|---|---|---|
| 1 | **P2.1 Welcome bug** | Único bug operacional crítico afectando users hoy |
| 2 | **P2.7 Rotar PAT** | Security hygiene, 15min |
| 3 | **P2.16 AirBnB content sync + Karina onboarding** | Unblocks Karina workflow |
| 4 | **P3-H FAQs curation 50-80** | Manual work, unblocks Greeter KB v2 |
| 5 | **P3-A Guest 360 Phase B.1-B.3** | Foundation para repeat detection + VIP tiers |
| 6 | **P3-B Pre-stay notifications I1** | High user value, leverages Guest 360 |
| 7 | **P3-F V7 lifecycle decisión + spec** | Necesario antes de scaling bot a in-stay/post-stay |
| 8 | **P3-G Beds24 Reviews API** | Reviews enrichment para bot KB + site display |
| 9 | **P3-C ideas restantes** en orden valor/effort | I6 Upsell → I9 Drip → I7 Lost-booking → I8 VIP completion → I5 Review automation → I2 QR check-in → I10 Dynamic packaging → I15 Unit economics → I16 Cancellation → I17 Weather → I18 UGC → I19 Casa Chamán |

---

## 8 · Lecciones clave acumuladas

### Técnicas

- **Beds24 sync mode permanente**: `Prices & Availability` ONLY (NUNCA `Everything`)
- **AirBnB phone field**: en `phone`, no `mobile`. UI cap guest input = 16
- **Pet policy**: $300 MXN/mascota/**estancia** (NO per night), max 2
- **Channel mapping**: `apps/worker-bot/src/beds24-normalize.ts:91` referer→channel
- **Webhook activation**: ~mayo 2026. Pre-may bookings necesitan backfill via API (resuelto thread/103)
- **Beds24 messages**: `POST /v2/bookings/messages` FIRST OUTBOUND
- **Beds24 invoice items**: `POST /v2/bookings` con `invoiceItems` array FIRST WRITE
- **ManyChat send**: `api.manychat.com/fb/sending/sendContent` tag `ACCOUNT_UPDATE` fuera 24h
- **MESSENGER_OUTBOUND_ENABLED**: default-OFF, Alex canary mode

### Coordinación

- **DoIt template v3**: pre-flight auto-verifiable commands · placeholders `<USER_HOME>`/`<OWNER>`/`<EMAIL>` · absolute paths · additive-first then mutating · defaults explicit
- **CC autonomy 3-tier** `.claude/settings.json`: allow (tests, lint, build, read) · ask (deploy, push, merge, kv put, d1 migrations apply) · deny (force push, rm-rf, db delete)
- **Conservative defaults sprint**: opt-in flags, manual canary, halt-on-failure, smoke verify
- **CC spec gap protocol**: halt + report 4 options (A/B/C/D pattern), no auto-pick

### Diseño

- **Encapsulación per lifecycle**: bot pre-booking ≠ in-stay ≠ post-stay (V7 spec pendiente)
- **No LLM en money path**: deterministic for prices/discounts; LLM solo para prose summary
- **Visualizaciones admin**: refresh-based MVP, polling acceptable, real-time = Phase 2

---

## 9 · Métricas norte (cuando todo el backlog viva)

| Métrica | Hoy estimado | Target post-backlog |
|---|---|---|
| % touch-points pre-checkout sin Alex/Karina | ~40-50% | 90%+ |
| % touch-points in-stay sin Alex/Karina | ~5% | 70%+ |
| % bookings con upsell adicional | ~3-5% | 25-35% |
| Cotización → booking conversion rate | TBD baseline | +15-20 pts |
| Lost-booking recovery rate | 0% | 10-15% |
| Repeat guest rate | TBD baseline | +20-30% |
| Review request response rate | TBD baseline | 40%+ |
| Cancellation rate proactive intervention | 0% | Caso huracán: 80%+ catch |

---

## 10 · Cierre

Este doc es **fuente única de verdad** para el backlog completo. Si en una sesión futura no aparece un item aquí, lo perdimos.

**Próximo paso sugerido**: Tu pick de cuál bucket abordamos en próxima sesión (P2 fixes vs P3-A Guest 360 vs P3-B Pre-stay vs descansar).

**Save location recomendada**: `rdm-discussion/BACKLOG.md` (push como commit aparte para versionado).

---

— WC, 2026-05-18 fin-de-sesión
