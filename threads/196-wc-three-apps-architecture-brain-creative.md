---
thread: 196
author: wc
type: brain
mode: creative
status: open
created: 2026-05-23
topic: three-apps-architecture-and-admin-stack
relates_to:
  - thread/89
  - thread/148
  - thread/188
supersedes: []
superseded_by: []
---

# Thread 196 — Three apps architecture + admin stack (brain creative)

**Mode**: brain creative (web chat session 2026-05-23)
**Author**: WC
**Status**: brain output. NO spec ejecutable. Requiere spec deep antes de DoIt.
**Audiencia**: Alex (decisor), futuro CC (implementador), futuro WC (continuador).

---

## §1. Contexto

Sesión web chat 2026-05-23. Alex solicitó investigación de admin theme + amCharts integration + librerías cal/Gantt para área admin. Agregó `cloudflare/templates` como fuente adicional.

Crítico, tras leer specs M1-M5 en `rdm-platform/modules/` + wishlist completo:

- **Guests logged-in** van a usar el sitio actual (M2 menu capture, I2 QR check-in, I3 in-stay bot, I6 upsell, I8 VIP tier, I14 damage deposit, I18 UGC pipeline). El branding warm/photographic actual debe preservarse.
- **Admin va a crecer exponencialmente** con M1-M5 + 19 ideas operativas (I1-I19) + 19 ideas adicionales para M5 Tasks (T1-T19) + 10 ideas recurring (R1-R10).
- **apps/staff PWA empleados** ya está decidido separado en F3 (ADR-002 foundations).

**Alex (cita literal)**: "puede ser buen momento de hacer algo ahora, antes de implementar eso".

Este thread captura el análisis y propuesta. **NO es spec ejecutable** — es brain output para retomar en sesión próxima.

---

## §2. Reframe: 3 audiencias, no 2

| Audiencia | Hoy | Crecimiento esperado | Branding | Densidad UI |
|---|---|---|---|---|
| **Público + guest logged-in** | `apps/web` marketing + booking | M2, I2, I3, I6, I8, I14 guest side, I18 | Warm, photographic, RdM identity | Baja, mobile-first |
| **Admin owner-operator** (Alex+Karina) | `/admin/*` sub-pages en apps/web | M1 audit, M2 chef approval, M3 drafts, M4 matrix, M5 board, I11/I13/I14/I15/I17/I19 review surfaces | Minimal, tool-feel (Linear/Notion) | Alta, desktop-first |
| **Staff PWA empleados** | NO existe (F3 pendiente) | M4 mi-semana, M5 recurring+adhoc, M3 stock checklist, I11/I14 photo upload, T1-T19 captures | Friendly, low-cognitive | Baja, mobile-only |

**Implicación**: las 3 son técnicamente distintas. Mezclar degrada las 3.

---

## §3. Decisión arquitectural propuesta: 3 apps separadas

```
rincondelmar.club        → apps/web      Astro 5 + React islands         (público + guest portal)
admin.rincondelmar.club  → apps/admin    Vite + React 19 SPA             (Alex+Karina)
staff.rincondelmar.club  → apps/staff    Astro 5 + islands + SW + VAPID  (empleados PWA, F3)
```

Subdominios distintos. Backend compartido (worker-bot + futuro worker-admin si justifica). Auth Better Auth con roles distintos por app.

**Razones técnicas para separar `apps/admin` AHORA**:

| Razón | Detalle |
|---|---|
| Bundle SEO | apps/web = marketing + SSG. Cada vista admin agregada infla bundle público y hurts Core Web Vitals |
| Branding conflict | Guest = photographic warm. Admin = data-dense neutral. Una Tailwind config sirve mal a ambos |
| Auth boundary | Mezclar guest magic-link (M2/I2 1-booking) con admin Better Auth full-session duplica middleware |
| Componentes irreconciliables | apps/web NO necesita TanStack Table, FullCalendar resource view, Gantt, kanban, command palette. Cargarlos = 500kB+ desperdicio en visitas marketing |
| Velocidad iteración | Admin va a iterar fuerte M1-M5+I1-I19. apps/web debe ser estable (Google penaliza cambios constantes) |
| Stack divergente | Astro brilla con SSG+islands. apps/admin necesita SPA puro (90% interactivo). Forzar mismo stack pierde en ambos lados |

---

## §4. Stack mapping por componente (M1-M5 + ideas)

| Componente UI | Lib recomendada | Lic | Consume |
|---|---|---|---|
| **Charts** (revenue, occupancy, ARN, demand) | **amCharts 5** (licencia Alex) | Comercial Alex | M1, I15, I17, M3 cost |
| **Data tables** (sort/filter/paginate/virtualize) | TanStack Table v8 (headless) + shadcn wrapper | MIT | M1 audit, M5 list, todos CRUD |
| **Calendar matrix** (occupancy grid 5 props × 90d) | FullCalendar v6 + **Resource Timeline plugin** | MIT + premium ~$480/y | M4 schedule, M1 viz |
| **Gantt** (recurring roadmap, lifecycle equipos) | **amCharts Gantt** (verificar lic) o frappe-gantt MIT | Mixto | M5 recurring, I12, I19 |
| **Kanban** (tasks by status, photo audit pipeline) | dnd-kit + shadcn | MIT | M5 board, I11, I13 |
| **Forms multi-step** | React Hook Form + Zod | MIT | Todo admin |
| **Rich text editor** | TipTap 3 | MIT | M2 catálogo, journey templates, KB |
| **File upload R2** | Uppy + R2 direct-upload | MIT | I11, I14, M5 photos |
| **Maps + tours** | MapLibre GL + Pannellum (worker-tours) | MIT | I17 weather overlay, property map |
| **Command palette** (Cmd+K) | cmdk | MIT | Admin nav, quick task create |
| **Date pickers** | shadcn DatePicker (Radix) | MIT | M5 deadlines, M4 shifts |
| **Toasts** | Sonner | MIT | Acciones admin |
| **Audio recording** | MediaRecorder API + Whisper | Native + API | T3, T6, M5 voice |
| **Photo annotation** | tldraw o fabric.js | MIT | T7 |
| **API client + cache** | TanStack Query v5 | MIT | Todo admin |
| **Routing** | TanStack Router (viene con Shadcn Admin) | MIT | apps/admin internal |
| **State global** (si aparece) | Zustand | MIT | Defer hasta necesidad real |

**Costos a validar antes de spec deep**:
- amCharts Gantt: producto separado en pricing, verificar si licencia Charts actual cubre o requiere upgrade
- FullCalendar Resource Timeline plugin: ~$480/y per dev. Alternativa MIT: DayPilot Lite (menos pulido)

---

## §5. Theme/template recommendation

| App | Theme | Razón |
|---|---|---|
| **apps/admin** | **Shadcn Admin** (Vite + React + shadcn/ui + TanStack Router) + amCharts wrapped components | CC ya domina shadcn, vendored primitives = ownership, copy-paste sin lock-in, dark mode built-in, Cmd+K integrado, deploy CF Pages directo |
| **apps/web** | Mantener Astro + Tailwind actual + refinar branding RdM | No romper SEO/performance existente |
| **apps/staff** | Astro 5 + React islands + Workbox + VAPID + Tabler icons (gratis) o shadcn-lite | Mobile-first, evita Bootstrap full (overkill), misma Tailwind config que admin para consistencia visual interna |

**Themes considerados y descartados**:

| Theme | Stack | Razón descarte |
|---|---|---|
| Tabler v4 | Bootstrap 5 + vanilla JS | Bootstrap colisiona con Tailwind apps/admin |
| Gentelella v4 | Vite + vanilla ES2022 + ECharts 6 | Vanilla JS limita reuso con React 19 islands |
| TailAdmin React | React 19 + Tailwind v4 + Vite | Empate técnico con Shadcn Admin, pero menos vendored primitives |
| Apex Dashboard (premium $69+) | Next.js 16 + shadcn | Next.js SSR overhead innecesario en CF Workers; Vite SPA más simple |

---

## §6. Cloudflare templates — su rol real

`github.com/cloudflare/templates` = **stack bootstrap, NO admin theme**. Templates relevantes:

| Template | Uso para RDM |
|---|---|
| `vite-react-template` | Starter perfecto para apps/admin SPA |
| `astro-blog-starter-template` | apps/web ya está aquí, skip |
| `chanfana-openapi-template` | Si decidimos worker-admin separado con OpenAPI auto |
| `next.js template` | NO recomendado (SSR overhead en CF Workers innecesario para admin) |

**Plan minimum apps/admin**: `vite-react-template` base + Shadcn Admin theme sobrepuesto + Better Auth + bindings D1/R2 vía Wrangler. Tiempo a primer commit funcional: ~2h CC.

---

## §7. Sequencing — 3 opciones

| Opción | Esfuerzo CC | WC | Riesgo | M1 arranca |
|---|---|---|---|---|
| **A) Apps/admin shell ahora solo** | 1-2 sem | 0.5 sem spec | Bajo. Skeleton aislado | Dentro del nuevo shell |
| **B) Foundations primero, admin después** | 0 sem | 0 sem | Medio. M1 en /admin actual → refactor caro luego | En apps/web sub-pages |
| **C) Híbrido — admin shell paralelo a foundations** | 2-3 sem total | 1 sem | Bajo-medio. F2 vive en apps/admin desde día 1 | Directo en apps/admin nuevo |

**Voto WC: Opción C híbrido**.

Razones:
- Alex pidió "buen momento de hacer algo ahora" → descarta B
- A pospone F2 observability con ADR-002 Accepted → ineficiente
- C permite F2 viva dentro apps/admin desde día 1. F1 events bus y F3 staff PWA siguen su path en paralelo. M1 arranca limpio.

**Voto Alex registrado en chat 2026-05-23**: "De acuerdo con el analisis, y la mayor parte de la conclusion". Asumo C aprobado con caveats menores a discutir en spec deep.

---

## §8. Qué entra AHORA en apps/admin shell (no spec, solo scope mental)

1. Vite + React 19 + TypeScript + Tailwind v4 + shadcn primitives setup
2. Better Auth integration (reuse existing)
3. Layout shell (sidebar colapsable, top bar, breadcrumbs, dark mode)
4. TanStack Router + Query setup
5. amCharts wrapped component (`<AmChart type=... data=... />`)
6. cmdk command palette base
7. Migrar 1-2 sub-pages clave (/admin/health para F2 + /admin/karina-training existente)
8. Auth boundary clara — admin role required
9. CI: deploy preview por PR a Cloudflare Pages
10. Documentar convenciones para CC (donde van charts, donde tables, etc.)

**NO entra ahora** (defer):
- Migrar todos los /admin/* existentes (gradual, módulo por módulo)
- M1-M5 implementation (necesitan specs dedicadas)
- apps/staff (F3 sigue path independiente post-foundations)
- Re-skin apps/web (separate effort baja prioridad)

---

## §9. Riesgos críticos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Refactor /admin existente disrupts flow Karina | Alto | Mantener /admin viejo activo en apps/web, apps/admin nuevo en subdomain paralelo. Migración gradual módulo a módulo |
| Bundle amCharts size en mobile | Medio | Lazy load por chart type, dynamic import. amCharts soporta tree-shaking nativo |
| FullCalendar Resource Timeline $480/y compromiso recurring | Bajo | Probar 14d trial primero, validar M4 needs antes de comprar |
| Better Auth multi-app config complexity | Medio | Single shared auth worker con scope/role check, no duplicar |
| amCharts Gantt licencia NO cubierta | Bajo | Confirmar con amCharts soporte; fallback frappe-gantt MIT |
| Stack divergente entre 3 apps complica onboarding CC | Medio | Documento "stack por app" en cc-instructions-bot/ + ejemplos copy-paste por componente |
| Choca con thread/188 CC apps/admin investigation | Desconocido | **Pendiente leer thread/188 antes de spec deep** |

---

## §10. Conexión con backlog existente

| Item backlog | Cambio |
|---|---|
| §3.3 apps/admin PWA decision (rdm-pipeline-open-state-v2) | **CIERRA** con voto B (build separate). Update §3.3 → DONE post spec |
| F2 Observability lite (ADR-002) | Sin cambio en alcance. **Vive dentro apps/admin desde día 1**, no en apps/web |
| F1 booking_lifecycle_events bus | Sin cambio. Backend, ortogonal a app split |
| F3 apps/staff PWA shell | Sin cambio. Path independiente para empleados |
| M1 Pricing | Su admin UI (kill-switch, audit viewer, summary) vive en apps/admin nuevo desde inicio |
| Decisions stores policy §3.2 | Sin cambio, paralelo |
| G7 thread/148 voto sub-items | Sigue pendiente, no bloquea Opción C |
| thread/188 CC apps/admin PWA decision | **Revisar coherencia** con esta propuesta antes de spec deep |

---

## §11. Pendientes para retomar (próxima sesión WC)

| # | Item | Tipo | Esfuerzo |
|---|---|---|---|
| 1 | Leer thread/188 CC investigation previa apps/admin PWA | WC homework | 30 min |
| 2 | Validar amCharts Gantt cobertura licencia (email amCharts soporte o billing check) | Acción Alex | 15 min |
| 3 | Decisión FullCalendar Resource Timeline plugin $480/y | Decisión Alex | 5 min |
| 4 | Validar branding/UX goals 3 apps con Alex (mood boards, palettes) | Brain conversación | 30 min |
| 5 | Spec deep apps/admin shell (7 secciones template DoIt v3) | WC brain deep | 1h |
| 6 | DoIt task para CC: scaffold apps/admin en rdm-bot monorepo | CC ejecución | 2-3 días |
| 7 | Update §3.3 backlog → DONE post spec | WC | 5 min |
| 8 | Actualizar memorias account-level con "3-apps architecture" | WC | 5 min |
| 9 | Update STATE.md rdm-discussion + rdm-bot post merge | WC + CC | 10 min |

---

## §12. Próximos pasos (orden)

1. **Alex revisa este thread** en GitHub mobile o desktop
2. Si aprueba sequencing Opción C: WC procede §11 items 1-5
3. Si vota distinto: WC re-evalúa según opción seleccionada
4. Una vez spec deep lista: DoIt task scaffolds apps/admin (§11 item 6)
5. F2 observability migra a apps/admin como home (cierra parte de ADR-002)

---

## §13. Notas finales

Este thread captura **conclusiones del análisis**, no la deliberación completa (que vivió en chat web claude.ai 2026-05-23). La sesión incluyó:

- Web searches sobre admin themes 2026 (Tabler, Gentelella, TailAdmin, Shadcn Admin, Apex)
- Web searches amCharts 5 licensing + Gantt
- Web searches FullCalendar v6 vs Bryntum vs DHTMLX vs DayPilot
- Lectura completa de `rdm-platform/modules/{pricing,menu,inventory,staff-scheduling,tasks}/README.md`
- Lectura `rdm-platform/vision/02-wishlist.md`

**WC voto resumido**: 3 apps separadas (web/admin/staff) + Shadcn Admin theme + amCharts charts + FullCalendar resource view + Opción C sequencing.

**Voto Alex parcial registrado**: "De acuerdo con el analisis, y la mayor parte de la conclusion".

Caveats a discutir en spec deep (próxima sesión):
- Validación licencias (§11 items 2-3)
- Branding/UX 3 apps (§11 item 4)
- Coherencia con thread/188 (§11 item 1)
- Cualquier sub-decisión de la "mayor parte" que Alex quiera amendear

---

**Versión**: v1 brain creative output
**Próxima revisión**: post §11 items 1-4 completados, antes de spec deep WC
