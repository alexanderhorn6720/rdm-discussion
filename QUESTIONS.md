# Preguntas abiertas

Formato: `[@responsable]` indica quién debe responder.

---

## Para Alexander `[@alex]`

### A1. Repo público / privado mid-migration
Este repo (`rincondelmar-bot-discussion`) es público ✅. El repo principal `rincondelmar-bot` sigue privado.
- ¿OK seguir así? Web Claude puede leer privado con PAT, Claude Code obvio sí. Mantener privado el código de producción es defensivo razonable.

### A2. PriceLabs vs alternativas
Recomendación de `decisions/03`: comprar PriceLabs $100/mes (5 listings).
- ¿Voto?
- ¿Quieres que primero hagamos demo / freemium trial?
- ¿Comparison con Beyond Pricing?

### A3. Timing 4.5 meses
Roadmap estima 18 semanas con 20h/sem dedicación.
- ¿Tiempo real disponible?
- ¿Algún hito de negocio que fuerce orden distinto (p.ej. temporada alta dic-ene exige bot estable antes)?

### A4. WABA propia Stage 2
Necesitas: número WhatsApp dedicado para WABA en Meta Business Manager.
- ¿Usas tu `+52 55 7061 8798` actual o creas uno nuevo?
- Si actual: número se desvincula de ManyChat para vincularse a WABA propia. Coexistence support de Meta permite mantener historial accesible en app, pero NO via API.

### A5. Pricing override layer Stage 2
`decisions/03` propone construir override Worker que ajusta PriceLabs según señales propias.
- ¿Te interesa esto en Stage 2 o aceptamos PriceLabs as-is indefinidamente?

### A6. Magic link único sin password
`decisions/05` propone magic link como único método auth.
- ¿OK con esto? (Mi voto: sí, password no aporta valor cuando email ya verificado).

### A7. Roles iniciales
Roles propuestos: `customer`, `staff`, `admin`, `chef`, `owner`.
- ¿Falta algún rol? P.ej. `accountant`, `manager`, `intern`?
- ¿Quiénes inicialmente son `admin`? (Probablemente solo tú).

### A8. APK timing
`decisions/07`: PWA día 1, APK on demand 6-12 meses post.
- ¿De acuerdo, o quieres APK en Play Store antes para marketing?

### A9. Sunset ManyChat completo
Tras Stage 2, ManyChat se cancela.
- ¿Hay alguna razón de negocio para mantenerlo (broadcasts, marketing flows que el equipo usa fuera de los bots)?

### A10. Domain destinations finales

Propuesta:
- `rincondelmar.club` → `apps/site`
- `bot.rincondelmar.club` → `apps/bot`
- `admin.rincondelmar.club` → `apps/admin`
- `api.rincondelmar.club` → `apps/api`
- `webhooks.rincondelmar.club` → `apps/webhooks`
- `pago.rincondelmar.club` → ¿desaparece o sigue como user-facing payment landing?
- `reservar.rincondelmar.club` → ¿retirar (legacy Worker)?
- `tours.rincondelmar.club` → `apps/tours`

¿Confirmas todos o ajustas?

---

## Para Claude Code `[@cc]`

### CC1. Schema D1 actual

Necesito `wrangler d1 execute rincon-pago --remote --command "SELECT name FROM sqlite_master WHERE type='table'"` + `PRAGMA table_info(...)` para cada tabla.

Mi deducción del bundle: `bookings, users, verifications, magic_links, sessions`. Verifica.

Commit el output a `threads/01-d1-schema-actual.md`.

### CC2. KV namespaces existentes

`wrangler kv:namespace list`. Veo `KV_IDEMPOTENCY` en el código. ¿Otros?

### CC3. Voto opciones técnicas

Lee `decisions/01-09` y vota:
- 01 — Monorepo: ¿A (Turborepo + pnpm)?
- 02 — Channel strategy: ¿Two-stage con channel abstraction layer desde día 1?
- 03 — Pricing: ¿Buy PriceLabs Stage 1?
- 04 — Admin: ¿React + shadcn + TanStack + PWA?
- 05 — Auth: ¿Custom magic link extendido o Better Auth?
- 06 — Future modules: ¿estructura modular ok?
- 07 — PWA Day 1 + APK on-demand: ¿OK?
- 08 — Orchestration: ¿Workflows + Queues + DOs reemplazan Make?
- 09 — Bots LLM: ¿port intacto + clean refactor?

### CC4. Stack actual del repo

- ¿pnpm/npm/yarn?
- ¿Wrangler version y compatibility_date?
- ¿Tests con vitest? Setup actual?
- ¿Drizzle ORM o queries raw?
- ¿Lint/format (biome, eslint, prettier)?
- ¿TS strict?
- ¿Monorepo ya iniciado o todavía single Worker?

### CC5. PriceLabs experience

¿Has integrado PriceLabs antes? Si sí, ¿pros/cons reales?

### CC6. Better Auth experience

¿Has usado Better Auth con D1/Workers? Si sí, ¿lo recomiendas vs custom?

### CC7. Cloudflare Workflows experience

¿Workflows está production-ready según tu experiencia? Limits que me preocupan no son problema para nuestro volume actual, pero quiero second opinion.

### CC8. Migración bookings históricos

¿Worth importar bookings históricos de Beds24 a D1 para reporting unificado? O dejamos `source='legacy'` y solo los nuevos van a D1?

### CC9. Errores que viste en stack actual

Tú construiste `rincon-pago`. Tras este planning, ¿hay decisiones del v1 que retrocederías? Cosas que harías distinto si arrancaras hoy?

### CC10. ¿Algún módulo futuro pinta antes?

¿Crees que `inventory` o `staff-tasks` debería arrancar antes que `chef`? ¿Priorización?

---

## Para Web Claude `[@wc]`

### WC1. Verificar property ID mapping
Necesito leer código de booking flow en `apps/site` para confirmar mapping slug ↔ Beds24 roomId.
- Action: cuando exista PR de Fase 0, leer `apps/site/src/lib/properties.ts` o equivalente.

### WC2. Knowledge files inventory
Listar archivos actuales en `rdm-greeter-kb` para planning migration a `apps/bot/knowledge/`.
- Action: clone + ls. Hacer después de votos.

### WC3. Make scenarios full inventory
Mapping completo de scenarios Make activos vs cuáles han sido reemplazados ya.
- Action: ya tengo el inventario en `CONTEXT.md`, verificar al cierre de Fase 1.

---

## Open research `[@research]`

### R1. AirDNA API costs y data quality
Si construimos pricing override Stage 2, necesitamos data de competencia local. AirDNA es opción.
- Action: investigar pricing exacto, sample data, coverage Acapulco/Pie de la Cuesta.

### R2. WhatsApp Flows: ¿valen el effort?
Stage 2 puede usar WhatsApp Flows para formulario de booking en-chat (sin redirect a sitio).
- Action: research limitaciones, examples en industry, fit con flujo actual.

### R3. Cloudflare Containers para apps pesadas
CF Containers (2026) permite Docker workloads en edge. Útil si algún módulo futuro requiere Python/Node libs no-edge-compatible (p.ej. heavy ML).
- Action: relevante solo si build pricing model custom from scratch.

### R4. Audit logs / compliance
Mexico Ley de Protección de Datos Personales (LFPDPPP) requirements para storage de PII (emails, phones, bookings).
- Action: research compliance, retention policies, right-to-be-forgotten implementation.

### R5. PWA push iOS limits actuales
iOS 16.4+ soporta Web Push parcial. Confirmar feature set 2026.
- Action: verificar caniuse + WebKit changelog.

### R6. Beds24 webhooks status
Beds24 ofrece webhooks para invalidate cache cuando hay booking externo (otro PMS). Saber si están active en plan actual.
- Action: revisar Beds24 admin panel o contactar soporte.

---

## Próximos pasos inmediatos

1. Alexander revisa README + VISION + decisions + ROADMAP.
2. Alexander vota lo que tenga claro.
3. Claude Code lee, responde en `threads/00-claude-code-first-response.md` con votos + correcciones.
4. Web Claude consolida en docs maestros.
5. Cuando converja: comenzar Fase 0 (Claude Code lidera).
