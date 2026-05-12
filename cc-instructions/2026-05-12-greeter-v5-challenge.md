# INSTRUCCIÓN PARA CC — Challenge Greeter v5 (thread/21)

**From**: Alex (vía WC)
**To**: CC
**Status**: Read thread/21 first. NO code yet. Only review + challenge + verify.
**Output**: Commit `threads/22-cc-greeter-v5-challenge.md`
**Decision after**: Alex decides scope MVP and what to implement (Q1-Q4 in thread/21)

---

## Contexto

WC publicó thread/21 con propuesta de "Greeter v5 site-first routing" + 4 features adicionales + 7 extensiones. Alex contribuyó las ideas de:
- Calendario con dropdown per-property
- FAQ expansion en site + reducción bot top-20
- Deflection a reserva online (enfatizar facilidad pago)
- Bot on-site

WC quiere que CC **rete las propuestas, verifique estado del sitio, proponga adicionales y recomiende scope MVP** antes de implementar nada.

---

## Tu misión (en orden)

### 1. Lee thread/21 completo

`threads/21-greeter-v5-site-routing-bot-onsite.md`

Entiende los 5 features core, las 7 extensiones, y las 6 áreas de challenge (sección 5).

### 2. Verifica estado actual del sitio (sección 5.2 thread/21)

Explora el repo monorepo (`apps/web/`) o navega el sitio en producción para responder:

**Páginas:**
- ¿`/reservar/` existe? ¿Es widget inline en fichas o página standalone?
- ¿Estado de la integración MP Checkout + Beds24 booking API?
- ¿`/tour-virtual/` hub está poblado con las 4 cards o vacío?
- ¿Hay `/cotizar/` o algo similar?
- ¿`/comparar/` o comparador casas?

**Anchors:**
- Verificar en `apps/web/src/pages/rincon-del-mar.astro` (o equivalente) si existen anchors `#galeria`, `#amenidades`, `#ubicacion`, `#reseñas`, `#faq`, `#calendario`
- Mismo check en las otras 3 fichas

**FAQ:**
- ¿Las preguntas individuales tienen `id="faq-X"` o solo las categorías?
- ¿Hay search/filter en la página?
- ¿Schema.org `FAQPage` markup?

**Analytics:**
- ¿Hay Cloudflare Web Analytics o Plausible activos?
- ¿Qué páginas son más visitadas hoy?
- ¿Cuál es el bounce rate de `/rincon-del-mar/`?

**Calendario actual:**
- ¿Las fichas tienen widget de calendario embebido o solo el placeholder "Cargando disponibilidad…"?
- ¿De dónde lee la data: R2 `availability.json`, Beds24 API directo, o otra fuente?

### 3. Challenge supuestos WC (sección 5.1 thread/21)

Responde con data, no opinión:

- **75% reducción tokens** — ¿es realista? Estima tokens promedio actual del Greeter v4 (10 last conversations en Make datastore 85639), y proyecta v5 con site-first routing
- **Bot on-site** — analiza patrones tráfico WhatsApp. ¿Los users que entran al sitio probablemente prefieren WA o se quedarían en sitio si hay chatbox? Investiga si hay data
- **`/disponibilidad/` SSR Astro vs fetch from edge** — qué es más performant para mobile 3G/4G?
- **Top-20 FAQs ranking** — 🔴 ALEX DECISIÓN Q4: NO usar datastore Make 85639 para analizar FAQs. Hay un thread previo entre Alex y CC sobre análisis de **WhatsApp históricos** (export chats raw, no Make conversations). USAR ESE thread existente. CC tiene acceso a ese histórico ya procesado. Devuelve lista ranked top-20 basado en WhatsApp histórico de Alex, no Make datastore.

### 4. Propón mejoras (sección 5.3 thread/21)

Ideas adicionales que se le escaparon a WC. Algunos vectores a explorar:

- **Service workers** para offline-first / prefetch del calendario
- **Edge caching** estratégico (HTML cache TTL agresivo + invalidación post Knowledge_Refresh)
- **AB testing infra** para canary Greeter v5 vs v4
- **Analytics granular** por intent → URL clicked → conversion
- **Competencia**: cómo lo hacen Plum Guide, AvantStay, Onefinestay, Misterb&b, Stayz. Robar lo que funcione
- **Mobile-first patterns** (bottom sheet, swipe gestures, voice input?)
- **i18n strategy** — sitio tiene `/en/` pero ¿está completo? ¿bot debería detectar idioma del user?
- **Schema.org** markup para SEO (FAQPage, LodgingBusiness, Reservation)
- **Open Graph dinámico** para shares WhatsApp
- **CDN images optimization** — están en Cloudflare Images, pero ¿se está usando responsive variants?

### 5. Identifica riesgos (sección 5.4 thread/21)

Lista riesgos técnicos y operacionales:

- ¿Qué pasa si el sitio se cae y el bot solo linkea? Fallback strategy
- ¿Versionado del sitio vs bot prompt — cómo evitar drift?
- ¿Cómo testear cambios de prompt sin romper conversaciones en vivo?
- ¿Si Greeter v5 reduce conversions vs v4, cómo detectarlo rápido (1 día, no 1 semana)?
- ¿Cuántos tokens cuesta el bot on-site vs WhatsApp bot por conversación?
- ¿Hay riesgos GDPR/privacy con session tracking del bot on-site?
- ¿`/disponibilidad/` con data 2h-old puede mostrar disponible una fecha que ya se reservó?
- ¿El sitio tiene rate limiting? Bot on-site puede ser abusado

### 6. Recomienda scope MVP (sección 5.5 thread/21)

Dado:
- Sprint 1 bot WhatsApp todavía en canary (no rampado 100%)
- AirBnB cutover apenas terminó (operational monitoring requerido 1ª semana)
- Reserva online si no existe = scope creep enorme

**Tu recomendación**: ¿qué entra en MVP Greeter v5 realistamente?

Opciones (Alex Q1 en thread/21):
- A: Solo Greeter v5 prompt + `/disponibilidad/` (1 sprint conservador)
- B: A + FAQ expansion (2 sprints)
- C: B + reserva online MVP (3-4 sprints — agresivo)
- D: C + bot on-site (4-5 sprints — overcommit?)

Da tu voto razonado. Considera capacidad team, riesgo, ROI esperado.

### 7. ETAs revisados

Reto las estimaciones de WC en sección 4 (Roadmap A→F):
- Fase A pre-requisites
- Fase B quick wins
- Fase C Greeter v5
- Fase D Bot on-site
- Fase E Reserva online (si entra)

¿Son realistas? ¿Faltan tareas? ¿Hay dependencies bloqueantes que no se vieron?

---

## Output format

Commit `threads/22-cc-greeter-v5-challenge.md` con estructura:

```markdown
# Thread 22 — CC challenge to Greeter v5 proposal

## 0. Site current state verification
[Resultados sección 2]

## 1. Challenge to WC assumptions
[Respuestas sección 3 con data]

## 2. Additional proposals
[Ideas sección 4]

## 3. Risks identified
[Sección 5]

## 4. Recommended MVP scope + vote
[Sección 6]

## 5. Revised ETAs
[Sección 7]

## 6. Open questions for Alex
[Cosas que CC necesita decisión antes de implementar]
```

Push a discussion repo. Avísale a Alex en chat cuando esté listo.

---

## Reglas

- **NO implementar nada** hasta que Alex decida Q1-Q4 (thread/21 sección 6)
- **Verificar antes de asumir** — leer Astro source code real, no asumir desde URLs
- **Data > opinión** — analizar Make datastore conversaciones, no intuición
- **Realista > ambicioso** — si algo es scope creep, decirlo claro
- **Challenge respetuoso** — WC propone, CC reta. El goal es Alex tener mejor decisión

ETA estimado para thread/22: 1-2 horas (read + verify + analyze + write).

---

*Esta instrucción es para CC. Alex la pasa al chat de CC.*

— Web Claude, 2026-05-12
