# 89 · WC · Platform Wishlist + M5 Tasks module · brainstorm conceptual

**Modo:** brain (filosofía / brainstorm)
**Estado:** WISHLIST · pre-implementación · NO es spec doc
**Fecha:** 2026-05-17
**Audiencia:** CC (review/discuss) · WC (referencia futura) · Alex (decisión orden)
**Propósito:** baseline conceptual compartido sobre módulos que vienen. Cero implementación esta sesión.

> CC: este doc NO te pide construir nada. Te pide leer, opinar, identificar gaps, dar tu voto técnico sobre arquitectura (sobre todo PWA vs APK, schema D1 propuesto Tasks, cost estimate, sequencing). Respuesta esperada: nuevo thread `90-cc-platform-wishlist-feedback.md` con tu review estructurado. Ver `cc-instructions/2026-05-17-platform-wishlist-feedback.md`.

---

## §0 Contexto operacional

| Capa | Estado actual |
|---|---|
| Propiedades | 4 activas (RdM, Las Morenas, Combinada, Huerta) · Casa Chamán Q3 2026 |
| Stack | CF Workers (`rincon-bot`, `rincon-pago`, `rincon-tours`, `beds24-calendar`), D1 `rincon`, KV, R2 `rdm-knowledge`/`assetsrdm` |
| Bot | Greeter v6 + Booker live (Hono + Sonnet 4.5/Haiku 4.5) |
| PMS | Beds24 propertyId 31862 · `/v2/inventory/rooms/calendar` = source of truth daily price + minStay |
| Canales | AirBnB (Connect API post-cutover 2026-05-12), Booking.com, WhatsApp direct, sitio |
| Pricing today | Make `cron:pricing-daily` PAUSED. Beds24 estático. Sin escritor activo. |

**Principio:** Beds24 `/calendar` es **source of truth**. Cualquier módulo lee de ahí (vía KV cache o pull). Cualquier escritor escribe via `POST /v2/inventory/rooms/calendar` o `/bookings`. No hay 2do store.

---

## §1 Módulos prioritarios

### M1 · Pricing Agent

**Objetivo:** maximizar occupancy + ARN via 3 drivers.

| Driver | Mecanismo |
|---|---|
| Anti-orphan | Detectar gaps 1-3N, aplicar `noCheckIn` o bump `minStay` |
| Last-minute discount | -5% a -25% escalonado por horizon (<45/30/14/7/3d), excluye Combinada + premium seasons |
| MinStay dinámico | Matrix 5 properties × 5 seasons × 4 horizons, Saturday siempre 4N |

**Arquitectura propuesta:**
- Módulo dentro de `rincon-bot` (no worker separado) — reusa auth Beds24, KV, D1, alertas
- Cron daily 6 AM Acapulco
- **Lógica determinística** para cálculos (floors/ceilings, múltiplos de 250, validation, math)
- **LLM (Sonnet)** SOLO para email summary post-corrida (reasoning prosa) — fuera del path crítico
- Kill-switch en `bot_config` (`pricing_auto_apply=true/false`)
- D1 tabla nueva `pricing_runs` con audit trail por corrida

**Inputs:**
- `GET /v2/inventory/rooms/calendar` 360d (cache KV)
- `GET /v2/bookings` 360d live (confirmed)
- `beds24_bookings` D1 (segunda señal post-normalize)
- Eventual: `bot_link_clicks` + `greeter_turns` para demand signal

**Outputs:**
- `POST /v2/inventory/rooms/calendar` batch
- Email summary a Alex con razones + totales + warnings + auto-corrections
- Telegram alert si run falla

**Drivers extra a explorar:** demand signal (bot conv vs cotizaciones), comp set scraping AirBnB (Phase 2), channel mix optimizer.

---

### M2 · Menu / Grocery huésped

**Objetivo:** capturar preferencias comida pre-arrival, generar lista chef-reviewed, dar al huésped precio honesto.

**Stack:**
- PWA `apps/menu` con drag-and-drop catálogo + AI chat híbrido
- DB compartida con M3 Inventory (`ingredients`, `recipes`, `supplier_items`)
- 3 editores catálogo (Karina + 2)
- Captura huésped: magic link 1 booking a la vez
- Idiomas: menú ES/EN, recetas+grocery solo ES

**Data sources históricos:**
- **410 listas compras** detectadas en chat WhatsApp Compras (nov-2022 → may-2026)
- **5,778 strings únicos** crudos → normalizables a ~400-600 ingredientes canónicos
- **157 resúmenes costos** agregados por categoría (chat Personal Isis)
- Match con `Bookings_historicos.csv` via (fecha+1d) + property + guest_name → desbloquea **qty/persona/noche por item**

**Captura precios (4 capas):**

| Capa | Método | Cobertura |
|---|---|---|
| 1 | 157 resúmenes históricos | Baseline categoría |
| 2 | OCR tickets fotografiados via Claude vision | Precios unitarios reales |
| 3 | Scrape Chedraui/Bodega Aurrera | Items súper estándar |
| 4 | WhatsApp bot mensual a compradores | Verificación |

**Encapsulado:** NO toca bot conversacional. PWA separada que guest usa post-booking (link en welcome). Bot solo deflecta "¿quieres planificar tu menú?" → URL.

**Casa Chamán:** roomId 679176 NO entra hasta post-renovation Q3.

---

### M3 · Inventory Replenishment (casa)

**Objetivo:** mantener ~100 SKUs durables stockeados en cada propiedad.

**Modelo:**
- Misma DB que M2 (`ingredients`, `supplier_items`)
- Flag `is_stockable=true` distingue durables vs perecederos
- Tablas nuevas: `locations`, `inventory_items`, `stock_counts`, `replenishment_requests`

**Stock signal v1 (deliberadamente simple):**
- Post-stay checklist por property — ama llaves marca "ok/bajo/vacío" cada salida
- NO conteo periódico (overhead excesivo)
- Tú/Karina aprueban drafts agrupados por proveedor

**Proveedores:** Sam's Club Acapulco, MercadoLibre, Chedraui, Bodega Aurrera.

**Categorías empleados (importan más que propiedades para asignación):**
1. Fijo por property — Mary/Frank RdM, Marisol/Maritza Morenas
2. Compartido — Celene (chef), Heber/Isis (compradores)
3. On-call — Josué (fogatas), Mónica (masajes)

**NO en v1:** scrape precios Sam's/ML, bodega central.

---

### M4 · Staff Scheduling

**Objetivo:** generar horarios + asignación staff por booking + visibilidad por rol.

**2 motores paralelos:**

| Motor | Función |
|---|---|
| Base schedule | Templates + descansos fijos (lunes Karina off, mozos 8AM-6PM) |
| Booking-driven | Por cada `beds24_booking` deriva staff needs (chef RdM/Combinada, mozo según size, cocinera Morenas, fogatero si requested) |

**3 vistas:**
1. Calendario semanal — Alex + Karina cross-property
2. Diario por propiedad — staff sitio
3. "Mi semana" móvil — push lunes 8AM resumen empleado

**D1 tables:** `employees`, `shift_templates`, `shifts`, `time_off_requests`, `booking_staff_needs`.

**Preguntas abiertas (req. Alex):**
- Cuántos empleados (estimado 12-15)
- Schedule lo mantiene Karina hoy? Hoja Google? Ad-hoc?
- Descansos contractuales fijos o flexibles?
- Smartphones activos por empleado
- IMSS/compliance — fuera scope v1 pero ojo accounting

**Casa Chamán Q3:** puede traer staff nuevo, dimensionar capacity.

---

### M5 · Tasks ⭐ NUEVO

**Objetivo:** layer universal de gestión de tareas. Alex/Karina ↔ empleados, bidireccional, con recordatorios, fotos, deadline, recurring. Conector entre M2/M3/M4 y los demás módulos operativos.

#### Stack base

| Capa | Detalle |
|---|---|
| D1 tables | `tasks`, `task_comments`, `task_reminders_sent`, `task_templates`, `task_attachments` |
| Foto storage | R2 `tasks/{taskId}/` (multi-foto pre/post) |
| Notif primaria | Web Push (PWA + VAPID) |
| Notif fallback | WhatsApp via ManyChat (empleados que no instalan PWA) |
| Bidireccional | Empleado → Alex/Karina también puede crear tasks (report issue, request material) |
| Status enum | `pending` · `in_progress` · `completed` · `blocked` · `cancelled` · `skipped_valid` |
| Recordatorios | T-24h, T-1h, T-vencido, cada 24h post-vencido hasta resolver |
| Audio | Comments + dictado voz (Whisper o Anthropic vision/audio) |

#### Casos de uso reales

- Alex → Mary: "Cambiar bombilla baño master RdM antes del viernes 23" + foto
- Alex → Heber: "Comprar 4 cilindros gas Combinada" + deadline
- Frank → Alex: "Aire master Morenas hace ruido raro" + foto (empleado reporta)
- Karina → Roberto: "Recoger 8 huéspedes vuelo AM430 lun 15 jun 14:30"
- Mary → Alex: "Falta papel higiénico almacén" (urgente, no deadline)

#### Integración como conector

| Módulo origen | Genera task auto |
|---|---|
| M2 Menu | Lista compras aprobada → task a Heber/Isis |
| M3 Inventory | Stock bajo detectado → task replenishment |
| M4 Staff | Shift asignado = task implícita |
| I11 Photo audit | Daño detectado → task reparación |
| I13 Vendor marketplace | Service request = task hacia vendor externo |
| I14 Damage deposit | Workflow review = task a Karina |

#### Recurring tasks · sub-modelo

**Patrones de frecuencia:**

| Patrón | Ejemplo real RdM | RRULE |
|---|---|---|
| Cada N días | Limpiar filtros alberca cada 3d | `FREQ=DAILY;INTERVAL=3` |
| Semanal fijo | Lunes purga calentador, jueves jardín | `FREQ=WEEKLY;BYDAY=MO` |
| Multi-día semana | L-X-V revisar nivel cisterna | `FREQ=WEEKLY;BYDAY=MO,WE,FR` |
| Quincenal | Cambio filtros aires cada 15d | `FREQ=DAILY;INTERVAL=15` |
| Mensual día fijo | Día 1 cada mes: pago jardinero | `FREQ=MONTHLY;BYMONTHDAY=1` |
| Mensual día lógico | Primer lunes: revisar generadores | `FREQ=MONTHLY;BYDAY=1MO` |
| Trimestral | Fumigación cada 3m | `FREQ=MONTHLY;INTERVAL=3` |
| Anual | Renovar póliza seguro 15 marzo | `FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15` |
| Estacional | Cada lunes jul-ago revisión extra | `FREQ=WEEKLY;BYDAY=MO;BYMONTH=7,8` |
| Por booking | Pre-arrival checklist | event-driven, no calendar |

**D1 schema propuesto:**

```sql
task_templates
├── id, name, description, property_id (nullable=cross-property)
├── default_assignee_id (o pool_json[])
├── rrule (RFC 5545)
├── next_due_at (indexed para cron)
├── lead_time_hours (cuánta antelación crear instancia)
├── auto_skip_if_property_vacant (bool)
├── photo_baseline_url (R2 ref para photo audit)
├── sub_tasks_json (checklist anidado)
├── active (bool, pause/resume)
└── created_at, updated_at

tasks (instancias generadas o ad-hoc)
├── id, template_id (nullable si ad-hoc)
├── title, description, assignee_id, property_id
├── deadline, status, completed_at
├── recurrence_instance_number
├── created_by (user_id de Alex/Karina/empleado autor)
├── priority enum (low/normal/high/urgent)
└── photos[], comments[]
```

**Cron generator:**

```
cron:tasks-spawn (cada 1h)
  ├─ SELECT template WHERE active=1 AND next_due_at <= now() + lead_time_hours
  ├─ apply auto_skip rules (vacancy check con beds24_bookings)
  ├─ generate task instance
  ├─ assign (default_assignee o round-robin si pool)
  ├─ trigger notification (Web Push + WhatsApp fallback)
  └─ calculate + UPDATE next_due_at usando RRULE
```

#### Scope de recurring por módulo

| Tipo recurring | Quién lo gestiona |
|---|---|
| Operativos casa (filtros, jardín, limpieza profunda, fumigación) | **M5 Tasks** |
| Empleado-related (pago nómina, IMSS, vacaciones) | M4 Staff Scheduling |
| Pricing/availability (revisar precios, ajustar minStay) | M1 Pricing Agent |
| Marketing (post IG semanal, newsletter, review request) | a futuro (I8/I9 o módulo nuevo) |

---

## §2 Decisión arquitectónica · PWA vs APK Android

**Contexto:** todos los empleados usan Android (cero iOS). Necesitan: recibir tasks, marcar completion, subir fotos, comentar, ver schedule, marcar inventory stock, capturar grocery feedback, etc. Una sola "app staff" para todos los módulos M2/M3/M4/M5.

### Comparación

| Eje | PWA | APK nativo | TWA híbrido |
|---|---|---|---|
| Stack dev | Web (Astro/React) — mismo que ya usas | Kotlin/Flutter/RN — nuevo | PWA wrapped .apk |
| CC iteración | Deploy en segundos | Build + sign + reinstall | Deploy PWA, APK wrapper estable |
| Updates | Instant (cache invalidation) | Reinstall manual o Play Store | Instant (web side) |
| Camera fotos | `<input capture>` adecuado | Native intent (UX ligeramente mejor) | Igual PWA |
| Push notif | Web Push (VAPID) — funciona Android Chrome | FCM (más confiable, lock screen actions) | Web Push |
| Background sync | Service Worker (limitado) | WorkManager (robusto) | Service Worker |
| Geofencing | ❌ no nativo | ✅ sí | ❌ |
| Install | "Add to home screen" Chrome | Sideload .apk via WhatsApp | Sideload .apk |
| Sensación app | 8/10 | 10/10 | 9/10 |
| Costo mantener | Bajo | Alto | Medio |
| Tiempo a v1 | 2-3 semanas | 6-8 semanas | 3-4 semanas |

### 🎯 Voto WC: **PWA single multimódulo**

**Stack:** Astro 5 + React islands + Service Worker (Workbox) + VAPID Web Push + Capacitor.js standby.

**Path:** `apps/staff` (no apps separadas) — single PWA con secciones Tasks / Inventory / Schedule / Menu approval / etc.

**Razones:**
1. Stack existente — CC entrega más rápido, no aprende framework nuevo
2. Iteración rápida — crítica primeros 2-3 meses de cada módulo
3. Web Push en Android Chrome es robusto desde Android 5+ (2014), llega a lock screen
4. Cámara via `<input type="file" accept="image/*" capture="environment">` perfectamente buena para fotos task/audit/damage
5. Sideload via WhatsApp — Karina manda link, empleados "Add to home screen", listo
6. Fallback WhatsApp ManyChat — si empleado no instala, recibe notif por WhatsApp (ya conectado)
7. Capacitor.js standby — si algún día se necesita .apk real (geofencing, Play Store branding), wrap en horas

**Cuándo migrar a APK/TWA:**
- Geofencing serio necesario (auto check-in shift al entrar a propiedad)
- Web Push falla >5% (no típico)
- Distribución Play Store para legitimidad
- Empleado con Android <5 (improbable)

---

## §3 19 ideas creativas adicionales

### Guest experience (5)

#### I1 · Pre-arrival concierge AI personalizado
Bot proactivo escribe 7d/3d/1d antes check-in. Adapta tono a perfil booking (familiar vs corporate vs honeymoon). Sugiere tours, restaurantes, paseo laguna, fogata, masajes. **Stack:** cron pre-arrival → Sonnet con context `beds24_bookings` + `guests`. Genera intents `upsell:tour`, `upsell:fogata`.

#### I2 · Digital check-in/out con QR
Huésped recibe QR antes de llegar. Escanea → web wizard: dirección + Waze deep-link + código cerradura (rota por booking, expira post-checkout) + house manual + emergency. **Stack:** R2 manuals + D1 `access_codes` + Worker `/checkin/:bookingId`.

#### I3 · In-stay WhatsApp assistant
Bot dedicado durante estancia (lane separado del Greeter pre-booking). Detecta booking activo via `beds24_bookings.lifecycle=in_stay`. Maneja "¿cómo enciendo calentador?" "más toallas". Escala a Karina si no resuelve. KB específica de cada casa.

#### I4 · Welcome packet generator multilingüe
R2 templates por property × lang. Sustitución placeholders + LLM polish opcional. Ya empezado en `welcome-auto-send.ts` (status `approval_pending`). Falta: render PDF, send link al guest, EN/ES/FR.

#### I5 · Post-stay review request automation
Trigger T+24h post-checkout. Detecta canal (AirBnB review nativo vs sitio Google Maps). Plantilla suave, NO insistente. Review ≤3★ → Telegram a Alex sin auto-respuesta. Push side aún falta (audit ya existe en `reviews-sync.ts`).

### Revenue & marketing (5)

#### I6 · Upsell engine post-booking
Catálogo add-ons (chef Morenas $1k-1.5k/d, transport, tours, masajes, fogata, decoración, DJ, fotos, paseo a caballo). Bot envía 7d/3d antes con sugerencias contextuales. **Tablas:** `addons_catalog`, `booking_addons`. Track conversion per addon.

#### I7 · Lost-booking recovery
Si user llena fechas+huéspedes en booking engine sin completar pago en 2h, dispatch bot WhatsApp con incentivo suave. Métrica: % recovery. **Stack:** D1 `quote_requests` + cron 2h. Cuidado anti-spam: solo si dio teléfono explícito.

#### I8 · Repeat guest VIP segmentation
Cross-ref `guests` D1 con histórico booking count. Tiers: Bronce 1, Plata 2-3, Oro 4+. Beneficios: discount auto, upgrade probability, welcome amenity, named greeting. Greeter v7 detecta repeat via phone match, cambia tono saludo.

#### I9 · Drip campaign post-cotización
User cotiza, no reserva. Día+1 "¿revisaste?" Día+3 "preguntas?" Día+7 "¿otras fechas?" Día+14 break. Cada turno anchor a cotización original. Cohort conversion tracking.

#### I10 · Dynamic packaging
Paquetes pre-armados: "Bodas grupo 40" (Combinada+chef+bartender+DJ+decoración), "Retiro corporativo" (RdM+coffee breaks+actividades), "Año nuevo" (4N min+cena gala+champagne). Precio bundled vs à la carte savings visible.

### Operations (4)

#### I11 · Photo audit post-checkout
Ama llaves sube 8-12 fotos post-checkout. AI vision compara con baseline house standard + checkouts previos. Detecta faltantes, daños, wear-and-tear normal. Reporte con confidence score. Reduce ~80% tiempo Karina. **Stack:** R2 `audits/{bookingId}/` + Claude vision + D1 `audit_reports`.

#### I12 · Equipment lifecycle tracker
Inventario equipos críticos (aires, fridges, calefactores piscina, bombas agua, generadores). Each: install date, expected lifespan, maintenance log, warranty. Alert proactivo "aire RdM master 4 años, probable revisión preventiva próximos 3 meses". Reduce surprise breakdowns mid-stay.

#### I13 · Vendor marketplace con SLA tracking
Directorio plomeros, electricistas, jardineros, técnicos albercas, fumigadores. Vendor data: contact, área servicio, precio típico, SLA promedio, rating últimas 10 jobs. Karina pide → 1-click WhatsApp + tracking respuesta + completion. Después N jobs → tier "preferred" con discount negociado.

#### I14 · Damage deposit dynamic
Foto check-in (ama llaves) vs check-out (ama llaves o guest via QR). AI compara, detecta daños accionables. Daño → workflow Karina aprueba → cargo MP al método original. OK → release auto del depósito. Reduce disputas. Integra con I11.

### Analytics & intelligence (3)

#### I15 · Unit economics dashboard per booking
Por cada booking: revenue gross - commission canal - fees pago - costo chef/staff (M4) - costo grocery (M2) - consumibles (M3) - mantenimiento prorrateado - utilities prorrateado = **net margin**. Reveal cuál booking type es rentable real (grupos Combinada vs intimate Huerta vs Las Morenas mid). Cross-ref channel (AirBnB 17.98% vs directo cero).

#### I16 · Cancellation root cause analysis
Por cada cancelación capturar: timing (días antes arrival), razón (guest input + AI inference chat history), refund amount, channel. Patrones: ¿AirBnB cancela más cerca? ¿corporate menos? ¿temporada alta cancellation rate? Drive policy (deposit non-refundable threshold). Campo `cancellation_reason` ya existe en `bookings`.

#### I17 · Weather + event impact forecasting
Cross-ref `beds24_bookings.arrival` con pronóstico clima 14d + calendario eventos Acapulco (Tianguis Turístico, conciertos Foro Acapulco, congresos, vacaciones SEP, feriados, mareas, alertas huracán temporada jun-nov). Proactive: "huracán cat 2 proyectado fechas booking X, reschedule preventivo". Driver para M1 Pricing (subir precio si demand spike por evento).

### Brand & growth (2)

#### I18 · Guest UGC pipeline
Post-stay T+7d, bot opcional pregunta "¿compartir foto/video con crédito?" → R2 upload + consent firma digital + Airtable queue Karina curar + post auto IG/TikTok con tag. Reduce ~90% tiempo Karina haciendo content. Phase 2: Meta Graph API.

#### I19 · Casa Chamán launch playbook
Módulo dedicado al lanzamiento Q3 2026 (coordinador, no standalone). Sub-checklist con timing:
- T-90d: fotos pro, tour 360°, descripciones EN/ES, primer pricing, AirBnB listing, sitio landing con waitlist
- T-60d: open waitlist, drip leads históricos, IG/TikTok teaser
- T-30d: soft-launch grupo VIP (Oro tier I8), feedback, ajustes
- T-0d: launch público, integrar a Greeter prompt (excluido hasta ahora), M1 incluye 679176, M2/M3/M4 expanden capacity
- T+30d: review primer mes, iteración

---

## §4 19 ideas creativas adicionales para M5 Tasks específicamente

### Captura más rápida (5)
- **T1 Voice-to-task** — empleado dicta task con voz, Haiku transcribe + estructura (deadline, priority, assignee). Útil para Mary/Frank.
- **T2 Photo-first creation** — tomar foto del problema, bot pregunta "¿qué hacer con esto?" → task auto con foto.
- **T3 Voice batch dictation** — Alex dicta 20 tasks de corrido en audio (manejando al aeropuerto), AI separa y crea cada uno.
- **T4 Quick task macros** — 1-tap botones pre-templates: "agua faltante", "luz fundida", "limpiar urgente", "checkout listo".
- **T5 AI suggested deadline** — "comprar gas Combinada" → AI sugiere deadline T+2d basado en consumo histórico M3.

### Comunicación bidireccional (4)
- **T6 Audio comments** — empleado responde con audio en thread (más rápido que escribir).
- **T7 Photo annotation** — dibujar flechas/círculos sobre foto del problema (señalar fuga, daño).
- **T8 Voice playback recordatorio** — notif T-1h reproduce task en voz si user activa modo "manejando".
- **T9 Task del huésped** — guest via WhatsApp reporta issue durante estancia → genera task auto al equipo de su property.

### Logística inteligente (4)
- **T10 Recurring tasks templates** — "limpiar piscina cada lunes", "purga calentador cada mes", auto-genera. Ver §1 M5 sub-modelo recurring.
- **T11 Geofence auto-prioritize** — empleado entra a propiedad → tasks de esa property suben al top (Geolocation API limitada pero funciona con permission).
- **T12 Smart "ya que estás ahí"** — si Mary cerca del super, recordatorio "ya que estás cerca de Chedraui, pasa por X" (geo-ranked).
- **T13 Task dependencies** — "instalación A bloqueada hasta compra material B complete", auto-unblock cuando dep resuelve.

### Workflow & escalation (3)
- **T14 Auto-handoff** — assignee no marca read en T+X horas → reasignar auto a backup (Mary off → Maritza).
- **T15 Multi-asignee pool** — task para "cualquiera disponible turno Morenas hoy", primero que toma se asigna.
- **T16 Inter-empleado handoff** — Mary completa parte 1 → auto-asigna parte 2 a Frank con context + fotos.

### Templates & playbooks (2)
- **T17 Task templates con sub-tasks** — "preparar check-in Combinada grupo 40" expande a 12 sub-tasks pre-armadas.
- **T18 Booking-driven task generator** — cada booking confirmado dispara checklist auto: T-3d limpieza profunda, T-1d amenities, T+0 check-in, T+X intermediate cleaning, T-checkout salida.

### Performance & analytics (1)
- **T19 SLA dashboard sin punitivo** — % tasks on-time per empleado, avg completion time, reasons-blocked. Para 1-1s con cada uno, NO ranking público (cuidado gamification tóxica).

### Bonus · 10 ideas adicionales para recurring

- **R1 Snooze inteligente** — empleado "snooze" 1 vez sin penalizar. 2da vez → visibilidad supervisor.
- **R2 Skip with reason** — "tubería en reparación" marca `skipped_valid` con texto/foto, no cuenta missed.
- **R3 Vacancy-aware** — si no hay booking esta semana, "limpiar diario" reduce auto a "1x semana revisión".
- **R4 Pre-booking burst** — 3d antes de booking >15 huéspedes, recurring se duplican temporalmente. Auto-restore post-checkout.
- **R5 Photo-verified completion** — "limpiar filtros aire" exige foto del filtro limpio. AI vision compara baseline. Sin foto buena → no se cierra.
- **R6 Seasonal recurring** — cron detecta inicio temporada (jun=lluvias) → activa templates dormidos ("revisar drenajes 3d"), pausa otros ("regar pasto 2d" → 7d).
- **R7 Dependencies recurring** — "pago jardinero día 1" depende de "jardinero completó día 28-30". Sin evidence, pago queda pending.
- **R8 Recurring rotado** — "revisar cisterna" gira Mary L-X, Frank J-S, Maritza D. Round-robin auto.
- **R9 Completion streak** — 30d on-time sin missed → notif positiva ("Mary 30d streak filtros piscina, gracias"). Reconocimiento sin gamification tóxica.
- **R10 Recurring suggester** — sistema detecta task ad-hoc 4+ veces a intervalo similar → sugiere "¿convertir a recurring?". Captura recurring tácitos no formalizados.

---

## §5 Patrones cross-módulo

### Storage layering

| Datos | Storage |
|---|---|
| Source of truth bookings/pricing | Beds24 (no duplicar) |
| Source of truth conversación | D1 `conversations` + `greeter_turns` |
| Cache lectura | KV (TTL 7d típico) |
| Templates / assets | R2 (`rdm-knowledge`, `assetsrdm`, `tasks/`) |
| Datos derivados / normalizados | D1 (`beds24_bookings`, `reviews`, `tasks`, etc) |
| Secretos | CF Workers secrets bindings |

### Lógica determinística + LLM como capa de presentación

Módulos con dinero real (M1 Pricing, M2 Menu cost, I6 Upsell, I14 Damage deposit, I17 Pricing impact) usan **reglas duras** para cálculos. LLM se usa solo para:
- Explicación prosa al humano (email summaries)
- Detección de edge cases (no clasificación numérica)
- Voz/tono en comunicación al guest

**No-go:** LLM decidiendo montos finales, descuentos, qué cobrar, qué deducir. Auditable + reproducible siempre.

### Bot pre-booking ≠ Bot in-stay ≠ Bot post-stay

Tres "personalidades" distintas, mismo stack:
- **Pre-booking** (Greeter v6 actual): deflecta al sitio, captura intent, handoff Booker
- **In-stay** (I3): asistente práctico durante estancia, KB casa específica
- **Post-stay** (I5, I18, drip): review request, UGC capture, feedback

Distinguir via `beds24_bookings.lifecycle`: `booked` / `in_stay` / `past_stay`.

### Encapsulación

Cada módulo es PWA / endpoint / cron separado. Bot NO se vuelve "sistema de todo". Bot deflecta hacia módulo correcto con URL específica. Cada módulo testeable, deployable, debuggable independiente.

### Roles humanos

| Rol | Módulos que toca |
|---|---|
| Alex | Approval pricing (M1), unit economics review (I15), VIP outreach (I8), Chamán playbook (I19), task assigner (M5) |
| Karina | Editor menú (M2), inventory aprobador (M3), photo audit review (I11), vendor marketplace (I13), UGC curator (I18), task assigner (M5) |
| Ama llaves | Stock checklist (M3), photo audit upload (I11), damage deposit photos (I14), tasks recurring + ad-hoc (M5) |
| Heber/Isis | OCR tickets (M2 capa 2), compras según lista aprobada, tasks compra (M5) |
| Empleados staff | "Mi semana" móvil (M4), tasks recurring + ad-hoc (M5) |
| Vendors externos | Marketplace (I13) |
| Guest | Menu capture (M2), check-in QR (I2), in-stay bot (I3), UGC submission (I18), report issue → task (T9) |

---

## §6 Sequencing tentativo (NO compromiso)

Orden lógico, no fechas. Alex decide.

1. **M1 Pricing** — desbloquea revenue immediate, prerequisito de I15
2. **M5 Tasks** — habilita comunicación operativa estructurada, baseline de PWA staff
3. **M4 Staff Scheduling** — Karina pain point cotidiano, costing real per booking
4. **I3 In-stay bot + I2 Check-in QR** — guest satisfaction, low cost
5. **M3 Inventory** — reduce surprises operacionales (depende de M5 para task replenishment auto)
6. **M2 Menu/Grocery** — más complejo, dependencias, mayor payoff long-term
7. **I6 Upsell + I8 VIP** — revenue layer sobre baseline
8. **I11 Photo audit + I14 Damage deposit** — ops quality
9. **I15 Unit economics dashboard** — habilita decisión sobre todo lo anterior
10. **I19 Casa Chamán playbook** — coordinador Q3 launch
11. Resto según señal/oportunidad

**Cambio vs v1:** M5 Tasks sube a #2 porque es habilitador transversal (PWA staff = baseline para M3/M4 también).

---

## §7 Preguntas abiertas

| # | Pregunta | Para quién |
|---|---|---|
| Q1 | ¿Orden prioridad real (vs § 6 tentativo)? | Alex |
| Q2 | Cuántas horas/sem Karina puede dedicar por módulo nuevo? | Alex + Karina |
| Q3 | Empleados contractor o nómina? Afecta M4 + IMSS compliance | Alex + contador |
| Q4 | Budget cap mensual LLM API? Define cuánto a Claude vs reglas duras | Alex |
| Q5 | Casa Chamán incluida día 1 cada módulo o defer hasta Q3 launch? | Alex |
| Q6 | Booking.com sigue no-touch, o eventualmente entra a M1 y otros? | Alex |
| Q7 | Hardware nuevo necesario? (smart locks I2, tablets staff M4, scales/sensors M3, beacons geofence M5) | Alex |
| Q8 | Algún empleado con Android <8? Web Push requiere Android 5+ Chrome | Alex / Karina poll |
| Q9 | PWA single multimódulo `apps/staff` vs PWAs separadas (Tasks/Inventory/Schedule)? Voto WC: **single** | Alex / CC |
| Q10 | Smartphones activos por empleado (todos los 12-15)? | Karina poll |
| Q11 | CC capacity para esto en paralelo o serializar más? | CC |
| Q12 | Módulos missing en wishlist? | Alex, CC |
| Q13 | Algún módulo aquí no tiene sentido / scope creep / nice-to-have-no-essential? | Alex, CC |
| Q14 | Cómo se manejan las tasks **hoy** (WhatsApp ad-hoc, hoja Google, oral)? Baseline para M5 ROI | Alex |
| Q15 | Hay tasks recurring **hoy** documentadas en algún lado, o están todas en cabeza de Karina? | Alex |

---

## §8 Notas finales

- Este doc es **conceptual y vivo**. Cualquier módulo puede reclasificarse, agregarse, descartarse.
- CC: cuando llegue momento de implementar X módulo, **pedir spec doc dedicada** con scope/DoR/DoD/tests/rollout siguiendo template CLAUDE.md § "Spec doc template". Este wishlist NO es spec.
- WC: usar este doc como contexto para conversaciones futuras de brainstorm o validación de ideas nuevas.
- Alex: editar libremente. Versionar via commit cuando consolide.

**Próximo paso esperado:** CC lee, opina, abre `90-cc-platform-wishlist-feedback.md` con review estructurado siguiendo `cc-instructions/2026-05-17-platform-wishlist-feedback.md`.

---

**Versión:** v2 (v1 vivía en chat WC pre-thread, sin push)
**Última actualización:** 2026-05-17
