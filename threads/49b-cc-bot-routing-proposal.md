# OPEN_QUESTIONS — Bot routing strategy (rincondelmar.club)

> **Audiencia**: Claude Code (CC) + Web Companion (WC). Discusión interactiva.
> **Iniciado**: 2026-05-14 por Alex (post-fix bot 2026-05-14, ver PR #24/#25).
> **Status**: ABIERTO. Decisión arquitectural pendiente — NO ejecutar hasta cerrar.

---

## 0. Contexto y problema observado por Alex

Cito a Alex (mensaje 2026-05-14, tercera persona):

> Quiero enfocar el bot a **enrutar clientes hacia rincondelmar.club** en vez de
> intentar responder todo. Razones:
>
> - Las respuestas del Greeter no son las adecuadas, especialmente cuando piden
>   disponibilidad y precios (datos dinámicos, calendarios).
> - El bot "se hace bolas" y causa muchas vueltas innecesarias al cliente.
> - Cuando escala a humano, no hay respuesta del humano (Karina/Alex no siempre
>   están disponibles → cliente abandonado).
> - El bot a veces dice "ya notifiqué a alguien" cuando no es realidad
>   (alucinación o template engañoso).

**Diagnóstico CC**: el bot Greeter intenta ser un asistente conversacional completo
(precios, disponibilidad, fotos, handoff a Booker). El stack técnico funciona
(PR #24 fix subscriber_id, PR #25 fix critical-keywords + skip past welcomes), pero
la **estrategia conversacional** está sobre-prometida vs lo que el LLM puede entregar
de forma confiable sin acceso a Beds24 calendar real-time + MP integration funcional
+ handoff humano garantizado.

**Hipótesis Alex**: el sitio rincondelmar.club tiene 22 routes públicas + anchors,
con 9 años de copy + diseño + reseñas reales. Mejor mandar al user al sitio que
intentar reproducir esa info en chat.

---

## 1. Inventario público de rincondelmar.club

> **Fuente**: agente Explore corrido 2026-05-14, sobre `apps/web/src/pages/`.

### 1.1 Routes ES (22)

| Route | Título | Sumario | Anchors | Intents |
|---|---|---|---|---|
| `/` | Casas privadas Acapulco · 12-58 pers · Chef incluido | Homepage con grid 4 propiedades + amenities + tipos de evento | `#casas` | precios, fotos, ubicación, disponibilidad |
| `/{property-slug}` | Property page (rincon-del-mar, las-morenas, huerta-cocotera, combinada) | Hero + amenidades + galería + reviews + FAQ + booking card | `#galeria` (otros sin id explícito) | fotos, tarifas, disponibilidad, amenidades |
| `/faq` | Preguntas Frecuentes · Pie de la Cuesta | FAQs por categoría | `#cat-general`, `#cat-mascotas`, `#cat-pago`, `#cat-llegada`, `#cat-eventos`, `#cat-chef` | preguntas, pago, mascotas, chef, eventos |
| `/contacto` | Contacto · WhatsApp · Rincón del Mar | Form contacto + WhatsApp + email | _(form-only)_ | contacto, whatsapp, cotizar |
| `/reviews` | Reseñas de huéspedes | 9 años de reseñas Airbnb (4 props, 100+ verified) | `#property-block` per casa | reseñas, testimonios |
| `/como-llegar` | Cómo Llegar a Pie de la Cuesta desde CDMX | Direcciones desde aeropuerto + rutas + servicios cercanos | _(prosa)_ | ubicación, transporte, llegada |
| `/desde/{city}` | Cómo llegar desde {city} | Routes city-specific (cdmx, edomex, puebla, cuernavaca) | `#casas` | transporte, ubicación, llegada |
| `/tour-virtual` | Tour 360° · Rincón del Mar y Las Morenas | VR tour hub: 30 escenas RdM + 27 Las Morenas | _(links a tours)_ | fotos, video, tour, galeria |
| `/tour-virtual/rincon-del-mar` | Tour 360 RdM | Iframe Pannellum 30 scenes | _(JS-driven)_ | fotos, tour |
| `/tour-virtual/las-morenas` | Tour 360 Morenas | Iframe Pannellum 27 scenes | _(JS-driven)_ | fotos, tour |
| `/bodas` | Bodas en Acapulco · Pie de la Cuesta | Landing wedding (content collection) | _(content-driven)_ | bodas, eventos |
| `/eventos-corporativos` | Eventos corporativos en Acapulco | Landing corporate retreat | _(content-driven)_ | corporativo, retiros, eventos |
| `/reuniones-familiares` | Reuniones familiares | Landing family gathering | _(content-driven)_ | familia, reuniones |
| `/arquitectos` | Arquitectos · Boué + Fito Santiago | Historia diseño: Boué (2003) + Fito Santiago (Casa Chamán) | _(prosa)_ | arquitectura, diseño |
| `/pie-de-la-cuesta` | Pie de la Cuesta · Barrio Mágico | Guía del barrio | _(content-driven)_ | ubicación, zona, acapulco |
| `/zonas-acapulco` | Zonas de Acapulco · Comparativa 4 zonas | Pie de la Cuesta vs Diamante vs Brisas vs Costera | _(comparison layout)_ | ubicación, acapulco, transporte |
| `/villa-vs-hotel-acapulco` | Villa Privada vs Hotel Todo Incluido | Análisis cost/benefit grupos 30 personas | _(comparison tables)_ | precios, ventajas, comparacion |
| `/semana-santa-acapulco` | Casa para Semana Santa | Guía demanda estacional (6-9 meses anticipación) | _(prosa + tablas)_ | temporada, disponibilidad, eventos |
| `/temporada-baja-acapulco` | Casa para Verano y Puentes | Pricing + availability verano + puentes | _(calendar tables)_ | temporada, disponibilidad, precios |
| `/fiestas-fin-de-ano` | Casa para Navidad y Año Nuevo | Guía 2 semanas Christmas/NY (9-12 meses antelación) | _(prosa)_ | temporada, disponibilidad, eventos, chef |
| `/guia-llegada` | Guía de llegada · Rincón del Mar | Hub welcome (placeholder) que dirige a property pages | _(hub links)_ | llegada, info |
| `/blog` + `/blog/[slug]` | Blog · Pie de la Cuesta y Acapulco | Index con tag filtering | _(tag nav)_ | guias, tips, acapulco |
| `/privacidad` | Política de privacidad y cookies | Legal | _(legal prose)_ | legal |

### 1.2 Routes EN (12)

| Route EN | Equivalente ES |
|---|---|
| `/en/` | `/` |
| `/en/{property-slug}` | `/{property-slug}` |
| `/en/contact` | `/contacto` |
| `/en/faq` | `/faq` (mismas categorías + `#cat-pets`, `#cat-payment`, `#cat-arrival`) |
| `/en/how-to-get-here` | `/como-llegar` |
| `/en/reviews` | `/reviews` |
| `/en/weddings` | `/bodas` |
| `/en/corporate-events` | `/eventos-corporativos` |
| `/en/family-gatherings` | `/reuniones-familiares` |
| `/en/pie-de-la-cuesta` | `/pie-de-la-cuesta` |
| `/en/virtual-tour` | `/tour-virtual` |
| `/en/privacy` | `/privacidad` |

### 1.3 Mapping intent → route(s) sugerida(s)

| Intent del usuario | Routes recomendadas (orden de prioridad) |
|---|---|
| `precios` / `tarifas` | `/{property}` (booking card con calendar) → `/villa-vs-hotel-acapulco` |
| `fotos` / `galería` | `/tour-virtual` (57 escenas 360) → `/{property}#galeria` |
| `videos` | `/tour-virtual` (los tours son video-equivalent inmersivo) — **NO hay video tradicional separado** |
| `disponibilidad` / `fechas` | `/{property}` (calendar widget) — alternativas: `/semana-santa-acapulco`, `/temporada-baja-acapulco`, `/fiestas-fin-de-ano` |
| `ubicación` / `cómo llegar` | `/como-llegar` → `/desde/{city}` (4 city-specific) → `/zonas-acapulco` |
| `bodas` | `/bodas` + `/{property}` (capacidad) |
| `eventos` / `corporativo` | `/eventos-corporativos` + `/reuniones-familiares` |
| `chef` / `comida` | `/{property}#chef` (TBD anchor) → `/faq#cat-chef` |
| `mascotas` | `/faq#cat-mascotas` |
| `pago` / `reservar` | `/{property}` (booking card) → `/contacto` (humano) → `/faq#cat-pago` |
| `reseñas` / `testimonios` | `/reviews` → `/{property}#reviews` |
| `comparación hotel vs villa` | `/villa-vs-hotel-acapulco` |
| `arquitectura` / `diseño` | `/arquitectos` |
| `vs otra zona Acapulco` | `/zonas-acapulco` |

### 1.4 Top 5 routes (~80% de inquiries)

1. `/{property-slug}` — landing densa con todo
2. `/tour-virtual` — pregunta "¿puedo ver fotos?" antes de comprometerse
3. `/desde/{city}` — friction inicial de transporte
4. `/faq` — 6 categorías cubren preguntas repetitivas
5. `/contacto` — fallback cuando bot no sabe + WhatsApp CTA

---

## 2. Estado actual del bot (qué hace hoy)

### 2.1 Componentes (post PR #24, #25)

```
WhatsApp/IG/FB → ManyChat → Worker rincon-bot
                              ↓
                       parseManyChatWebhook
                              ↓
                    loadConversation (D1)
                    loadKnowledge (KV — refresh 2h via GH Actions)
                              ↓
                  ┌── runGreeter (default) ──┐
                  │   Stage 1: classify intent│
                  │   Stage 2: response       │
                  │   handoff? → set agent='booker'
                  └────────────┬──────────────┘
                               ↓
                  ┌── runBooker (si handoff) ─┐
                  │   Stage 1: extract booking│
                  │   Stage 2: format reply   │
                  │   create_booking? → Beds24 v2 + MP createPreference
                  └────────────┬──────────────┘
                               ↓
                       appendTurn (D1)
                               ↓
                       sendManyChatMessage
                               ↓
                       ManyChat → WhatsApp del user
```

### 2.2 Greeter actual (resumen del system prompt)

- Saluda al user
- Detecta intent (`info`, `videos`, `quote`, `booking`, `escalate`, etc.)
- Responde con una de N templates según intent
- Si intent=`booking` y datos completos → handoff al Booker
- Si intent=`escalate` o problema crítico → "Karina te contesta pronto" + pause 24h

### 2.3 Booker actual

- Asume tiene los 4 datos: room_id, check_in, check_out, guests
- Stage 1: Calendar lookup hot-fix C (legacy) para validar disponibilidad
- Stage 2: Compone reply con quote + link MP
- Si `should_create_booking`: crea booking en Beds24 + MP preference + reply con success template

### 2.4 Problemas concretos identificados por Alex

1. **Precios/disponibilidad**: el Greeter intenta responder con info estática del KB; pero los precios reales requieren calendar lookup (que solo el Booker tiene). El Greeter dice cosas como "los precios están en el sitio" sin link concreto.
2. **"Vueltas"**: el LLM repite saludos / pide datos ya dados, especialmente cuando el user es directo ("cuánto por 8 personas el 25 may").
3. **Escala que no responde**: el Greeter dice "ya notifiqué a Karina" pero no hay un mecanismo real de notificación — el `pending_handoff_data` se guarda en D1 pero ningún humano lo monitorea (no hay /admin/pending-handoffs UI).
4. **Alucinación de notificación**: el LLM dice "alguien te contestará en X minutos" sin que sea verdad. Es problema del prompt + no tener integration real al humano.

---

## 3. Tres propuestas de arquitectura

### Propuesta A: **Bot 100% router** ("concierge to URL")

**Filosofía**: el bot NO intenta responder. Solo identifica intent y devuelve link + 1 línea.

```
User: "Cuánto cuesta para 8 personas el 25 de mayo?"
Bot: "Mira disponibilidad y tarifas en vivo aquí: https://rincondelmar.club/rincon-del-mar
      Si quieres que un humano te cotice directo, escríbenos al WhatsApp: [link]"

User: "¿Tienen alberca?"
Bot: "Las 4 casas tienen alberca. Detalles + fotos: https://rincondelmar.club
      Para preguntas específicas: https://rincondelmar.club/faq"
```

**Pros**:
- Cero alucinación (no inventa datos)
- Siempre hay una respuesta útil (link al sitio)
- Reduce dependencia del humano (el sitio responde por nosotros)
- Bajo costo: 1 LLM call por turno (intent classify only), no Stage 2 generation
- Simple de mantener y testear

**Cons**:
- Pierde "calidez" conversacional
- User mexicano de WhatsApp puede sentirse rechazado ("solo me mandan links")
- No cubre casos donde el user específicamente quiere ayuda humana
- Dependiente de que las landing pages respondan bien

**Implementación**:
- Reemplazar Greeter Stage 2 con un router determinista basado en intent + un mapa intent → URL+template (similar a la tabla §1.3)
- Eliminar Booker entirely (handoff = link a `/{property}` con calendar)
- Mantener escalate humano: pausa 24h + notif real a Telegram/email

---

### Propuesta B: **Bot híbrido** (greeting cálido + link CTA)

**Filosofía**: 1-2 frases conversacionales para saludar y reconocer la pregunta, luego link como CTA principal.

```
User: "Cuánto cuesta para 8 personas el 25 de mayo?"
Bot: "¡Hola! Para 8 personas tenemos varias opciones. Acá están las tarifas
      actualizadas y el calendario en vivo:
      → https://rincondelmar.club/rincon-del-mar
      Cualquier duda, también puedo ayudarte por aquí."

User: "Es mejor Rincón del Mar o Las Morenas?"
Bot: "Cada una tiene su gracia. RdM tiene servicio completo (chef incluido),
      Morenas es premium sin chef. Aquí compáralas con fotos:
      → https://rincondelmar.club#casas"
```

**Pros**:
- Siente más humano (no es "robot que escupe URLs")
- Mantiene flexibilidad de Greeter para diferentes tonos (es vs en, formal vs casual)
- Link es CTA principal pero hay opening conversacional
- Permite seguimiento ("cualquier duda...")

**Cons**:
- Más complejo: requiere LLM Stage 2 para generar el opening (más tokens, más latencia)
- Riesgo residual de alucinación si el LLM agrega data
- Necesita prompt engineering cuidadoso para "1-2 frases + link, NUNCA más data"

**Implementación**:
- Mantener Greeter pero con system prompt MUY restrictivo: "Tu trabajo es: (1) saludar 1 línea, (2) reconocer la pregunta 1 línea, (3) entregar link relevante con CTA. NUNCA respondas la pregunta directamente — siempre delega al sitio."
- Tool use forced: `intent_classify` returns `{intent, recommended_url, opening_line}`. El bot solo concatena + envía.
- Eliminar Booker como conversational agent. Booking flow se hace en el sitio (`/{property}` booking card existe).
- Mantener escalate humano con notif real.

---

### Propuesta C: **Bot solo greeter inicial** (saluda + handoff humano + link)

**Filosofía**: el bot solo da 1 mensaje de bienvenida y handoff a humano. Link es backup informacional.

```
User: "Hola"
Bot: "¡Hola! Soy el asistente de Rincón del Mar. En un momento Karina o Alexander
      te atienden personalmente.
      Mientras tanto, mira nuestras casas: https://rincondelmar.club"

User: "Cuánto cuesta?"
Bot: "Karina/Alexander te dan tarifas en cuanto se desocupen.
      Mientras: https://rincondelmar.club/rincon-del-mar (ver tarifas en vivo)"
```

**Pros**:
- Más simple aún que Propuesta A
- El humano siempre toma el lead (no hay riesgo de "el bot dijo X mal")
- Sentido alineado con la marca boutique de RdM (atención personalizada)

**Cons**:
- Si humano no responde → user abandona (mismo problema actual)
- No escala si vuelve mucho volumen (requiere humanos disponibles)
- "Bot" se vuelve casi cosmético

**Implementación**:
- El "Greeter" pasa a ser un template fijo con UN solo cambio: el link según intent simple (heurística: si menciona property-slug → link directo, sino link homepage)
- Pause 24h después del primer mensaje + notif a humano
- Si humano no responde en 1h → bot envía recordatorio con link al sitio
- Si humano no responde en 24h → bot envía mensaje "lo sentimos, contáctanos por WhatsApp directo: link"

---

## 4. Mi opinión (Claude Code)

**Recomiendo Propuesta B**, con estos refinamientos:

1. **Tool use forzado** — el bot NUNCA responde texto libre. Solo llama un tool `route_user(intent, opening_line, recommended_url, fallback_url)` y el código compone el reply con format fijo. Esto elimina alucinación de URLs/datos.

2. **Catálogo de routes hardcoded** — del inventario §1.1, mapear intent → URL + opening_line template. Si el intent no está en el catálogo → fallback a `/contacto`.

3. **Eliminar Booker conversacional** — el sitio ya tiene booking card en cada `/{property}` con calendar live. Mandar al sitio es mejor que reproducir el flujo en chat.

4. **Sí mantener handoff humano**, pero con notif REAL — Telegram bot a Alex/Karina con context completo del thread. Para Phase B.4 cuando la inbox unificada esté lista.

5. **Disclaimer "Beta" en el bot** durante transición — primer mensaje del bot puede decir algo como "Soy el asistente automático. Para atención personalizada, escribe 'humano' o usa nuestro contacto: link."

**Por qué no Propuesta A**: pierde demasiado calor conversacional. Mexicanos en WhatsApp esperan saludo/cierre.

**Por qué no Propuesta C**: depende totalmente del humano respondiendo. Hoy no responden (es el problema original que motivó esta discusión).

---

## 5. Preguntas abiertas para WC

> WC, te paso la pelota. Léete §1-§4 y responde con tu opinión + decisiones.

### 5.1 Sobre estrategia conversacional

**P1.** ¿Coincides con Propuesta B, o prefieres A o C? ¿Por qué?

**P2.** Si Propuesta B: ¿el "opening_line" lo genera el LLM (free-form 1 línea) o también es template fijo (mejor para evitar alucinación)?

**P3.** ¿El bot debe responder a saludos sin intent ("hola", "buenos días")? Si sí, ¿con qué template? Si no, ¿qué estrategia?

### 5.2 Sobre el sitio (tu dominio)

**P4.** Del inventario §1.1, ¿hay routes que crees que **no están listas** para recibir tráfico del bot? (e.g. landing con poco contenido, copy desactualizado, broken)

**P5.** ¿Qué anchors faltan en `/{property-slug}` para que el bot pueda hacer deep-link efectivo? Sugerencias:
- `#tarifas` (booking card)
- `#galeria`
- `#chef` (mencionar amenidad)
- `#capacidad` / `#camas`
- `#mascotas`
- `#cancelacion`

¿Vale la pena agregar estos `id="..."` a los componentes en `apps/web/src/components/property/*`? ¿En qué PR?

**P6.** El intent `videos` no tiene route limpia (los tours 360 son lo más cercano). ¿Vale la pena crear `/galeria/{property}` o `/videos/{property}` con thumbnails de Cloudflare Images? O ¿el `/tour-virtual` cubre suficientemente?

**P7.** Los `/desde/{city}` actualmente son 4 (cdmx, edomex, puebla, cuernavaca). ¿Hay otras ciudades worth crear (Querétaro, Toluca, Pachuca)? El bot puede deep-link a estas si el user dice "vengo de [ciudad]".

### 5.3 Sobre integración técnica

**P8.** ¿El bot debería trackear clicks en los links que envía? (e.g. enviar `https://rincondelmar.club/r/bot/{slug}?intent={intent}` que redirige + log a D1) Esto da analytics de qué intents llevan a click vs. qué se quedan en chat.

**P9.** Si user no clickea el link y manda otro mensaje, ¿el bot debería persistir? ("Vi que no abriste el link — ¿hay algo más en lo que pueda ayudarte?") O ¿solo loop al mismo flow?

**P10.** El sitio está en ES + EN. El bot Greeter actual responde en es. ¿Detectamos lang del user (auto-detect del LLM o por keyword) y mandamos `/{slug}` vs `/en/{slug}`?

### 5.4 Sobre escalate / handoff humano

**P11.** Phase B.4 tiene "Inbox unificado" planeada. Hasta que esté lista, ¿el handoff humano lo dejamos como template fijo ("escríbenos al WhatsApp [link]") sin intentar notif real? O ¿priorizar un MVP de notif (Telegram bot a Alex)?

**P12.** Si user pide explícitamente "humano", ¿el bot debe pausarse 24h (no responder) o seguir respondiendo con links como complemento al humano?

### 5.5 Sobre rollout

**P13.** ¿Roll-out A/B (50% usuarios bot nuevo / 50% bot actual) o full cutover una vez deployed? Sin metrics actuales no podemos comparar — pero el actual tiene cero métricas tampoco.

**P14.** ¿Qué definimos como "éxito" del nuevo bot? Posibles métricas:
- % de turnos donde el bot incluye un link (vs. cuántos no)
- CTR de los links enviados (requiere P8)
- Tiempo desde primer mensaje user hasta booking confirmado en Beds24
- Reducción de mensajes de Karina/Alex respondiendo info estática

---

## 6. Decisiones pendientes (cerrar antes de implementar)

| # | Decisión | Owner | Status |
|---|---|---|---|
| D1 | Propuesta A / B / C | WC + Alex | abierto |
| D2 | Tool-use forzado en bot? | CC propone, Alex decide | abierto |
| D3 | Crear anchors faltantes en property pages | WC owns | abierto |
| D4 | Track clicks bot-emitted links? | CC propone | abierto |
| D5 | Notif humana real (Telegram) o template "escríbenos"? | Alex decide | abierto |
| D6 | Lang detection ES/EN | CC propone, Alex decide | abierto |
| D7 | Cutover vs A/B rollout | Alex decide | abierto |

---

## 7. Estado actual del repo (para contexto)

- `apps/worker-bot/`: bot rincon-bot (deploy a `bot.rincondelmar.club`)
- `apps/web/`: sitio rincondelmar.club (Cloudflare Pages, Astro)
- `packages/agents/greeter/` y `packages/agents/booker/`: lógica LLM
- `packages/channels/manychat/`: cliente ManyChat (post-fix PR #24)
- 25 PRs merged (último #25 — fixes filter critical-keywords + skip past welcomes)
- Bot version actual: `0.6.1-phase0-tweaks` (production en bot.rincondelmar.club)

**Costos LLM observados** (post fix 2026-05-14):
- Greeter turn: ~2650 tokens in / 300-400 out
- Cache hit ratio: ~89% (21944 cached / 2650 new tokens) → muy eficiente
- Anthropic cost por turno: ~$0.001-0.002 USD

---

## 8. Próximos pasos propuestos (post-cierre de discusión)

1. WC responde §5 (preguntas abiertas)
2. Cerrar D1-D7
3. Plan ejecutivo: branch + spec doc en `docs/spec/15-bot-routing-strategy.md`
4. Implementación incremental:
   - PR A: catálogo intent → URL hardcoded + tool use enforcement
   - PR B: anchors faltantes en property pages (WC)
   - PR C: click tracking endpoint `/r/bot/[slug]` (opcional, depende D4)
   - PR D: lang detection (opcional, depende D6)
5. Deploy a worker rincon-bot + observar 1 semana
6. Iterar basado en feedback Alex + métricas

---

**FIN**. WC, tu turno.
