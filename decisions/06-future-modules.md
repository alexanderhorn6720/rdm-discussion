# 06 — Módulos futuros: arquitectura modular

**Status**: Propuesta. Esperando voto.

**Decisión**: Cada módulo futuro (inventory, staff-tasks, chef) es una `app/` adicional en el monorepo. Comparte `packages/db`, `packages/auth`, `packages/ui`. **No los construimos ahora**, pero el monorepo, schema D1 y design system los anticipan.

## Contexto

Alexander pidió: "Considerar que a futuro vienen más módulos para administración del negocio, por ejemplo admin de inventario y compras, tasks del staff, admin para el chef (recetas, insumos, platillos). No vamos a entrar a eso ahora, pero la infraestructura tiene que ser modular".

Esto es el core del por qué Turborepo monorepo (ver `01-monorepo-structure.md`).

## Módulos anticipados

### `apps/inventory` — Inventario y compras

**Funciones**:
- Lista de items (sábanas, toallas, productos limpieza, amenities, comida).
- Stock actual por propiedad.
- Re-order points + alertas.
- Histórico de compras.
- Proveedores.
- Generar orden de compra → email/WhatsApp al proveedor.
- Integrar con Bot WhatsApp ("Karina, ¿cuántas botellas de tequila quedan?" → query D1).

**Schema D1**:
```sql
CREATE TABLE inventory_items (id, sku, name, category, unit, ...);
CREATE TABLE inventory_stock (item_id, property_id, current_qty, reorder_point, updated_at);
CREATE TABLE inventory_movements (id, item_id, property_id, qty_delta, type, ref_id, ts);
  -- type: purchase | consumption | adjustment | transfer
CREATE TABLE suppliers (id, name, contact, ...);
CREATE TABLE purchase_orders (id, supplier_id, status, items_json, total, created_at, ...);
```

### `apps/staff-tasks` — Tasks del staff

**Funciones**:
- Lista de tasks por propiedad por staff member.
- Recurrentes (limpieza diaria, cambio sábanas check-out).
- One-off (reparación específica, entrega de paquete).
- Mobile-first PWA (staff la usa en celular, en sitio sin WiFi a veces).
- Photo evidence opcional.
- Generación automática desde bookings (check-out + 2h → task limpieza profunda).

**Schema D1**:
```sql
CREATE TABLE task_templates (id, name, recurrence, default_assignee_role, ...);
CREATE TABLE tasks (id, template_id, assignee_user_id, property_id, scheduled_at, completed_at, status, photos_r2_keys, ...);
```

### `apps/chef` — Recetas, insumos, platillos

**Funciones**:
- Catálogo de recetas (ingredientes, pasos, dietary tags, fotos).
- Costo de plato (calculado desde inventory items).
- Menús por evento (boda 30 pax → menú x → ingredient list → check inventory → purchase order).
- Calendario de platillos por estancia (rotación automática).
- Integration con Bot ("¿qué menús sugieres para 25 pax 4 noches?").
- Dietary restrictions tracking.

**Schema D1**:
```sql
CREATE TABLE recipes (id, name, servings, prep_time, ingredients_json, instructions, ...);
CREATE TABLE menus (id, name, recipe_ids_json, event_type, ...);
CREATE TABLE meal_plans (id, booking_id, menu_id, scheduled_for, ...);
```

### `apps/marketing` (más adelante)

**Funciones**:
- Broadcasts WhatsApp (templates HSM, segmentación).
- Campañas por canal con tracking.
- Click-to-WhatsApp ads metrics.
- Análisis de funnel.

### `apps/owner-dashboard` (especulativo)

Si Alexander en algún momento hostea propiedades de terceros (managed rentals):
- Owner ve sus reservas, revenue, ocupación.
- Statements mensuales.
- Read-only de pricing/calendar.

## Cómo el monorepo lo soporta sin esfuerzo

### Schema D1 compartido

`packages/db/schema/` tendrá:
- `core.ts` (users, bookings, conversations, etc.)
- `inventory.ts`
- `staff-tasks.ts`
- `chef.ts`

Drizzle ORM permite split schemas. Migrations versionadas en `packages/db/migrations/`.

### Auth y permisos

`packages/auth` con roles soporta:
- `chef` rol para acceso `apps/chef` y inventory read.
- `staff` rol para `apps/staff-tasks` y conversations.

### UI components

`packages/ui` con design tokens compartidos. Sidebar de navegación dinámico según roles del user:
```typescript
const modules = useNavModules();
// Returns: ['bookings', 'conversations'] for staff
// Returns: ['bookings', 'conversations', 'prompts', 'pricing', 'inventory', 'chef'] for admin
```

### Channel layer

Si el Bot necesita inventario data ("¿cuántas botellas de tequila?"), el agent llama `packages/inventory/queries.ts` directamente. No hay duplicación de logic.

### Workflows cross-module

Cloudflare Workflows orquesta procesos que tocan varios módulos. Ejemplo:

```typescript
// packages/workflows/post-checkout.ts
export class PostCheckoutWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    const booking = await step.do('fetch-booking', () => getBooking(event.bookingId));
    
    // Task: deep clean (apps/staff-tasks)
    await step.do('create-cleaning-task', () =>
      createTask({ template: 'deep-clean', property: booking.property_id, scheduled_at: booking.check_out + 2h })
    );
    
    // Inventory: deduct consumables (apps/inventory)
    await step.do('deduct-inventory', () =>
      recordConsumption({ booking_id: booking.id, items: defaultConsumablesPerGuest * booking.guests })
    );
    
    // Email: review request after 3 days (existing cron, or workflow step.sleep)
    await step.sleep('wait-3-days', '3d');
    await step.do('send-review-request', () => sendReviewEmail(booking));
  }
}
```

## Tiempo de desarrollo estimado por módulo (post-fundamentos)

| Módulo | Estimado |
|---|---|
| `inventory` | 2-3 sem |
| `staff-tasks` | 2 sem |
| `chef` | 3-4 sem |
| `marketing` | 2 sem |
| `owner-dashboard` | 3 sem |

Estos números asumen monorepo + auth + UI components + design tokens YA listos (entregables de fase 0-2 del roadmap principal).

## Anti-pattern: NO hacer ahora

Anti-pattern típico es "vamos a hacer X en Make.com temporalmente". 

NO:
- Pricing agent en Make como bridge.
- Inventario en Google Sheets.
- Staff tasks en WhatsApp groups.
- Chef recipes en Notion.

Estas son **island solutions**. Sí, funcionan en el corto plazo, PERO:
- Crean trabajo de migración cuando llegue el módulo Worker.
- Data no se vincula a bookings (no podemos hacer reporting cross-module).
- Bot no puede consultarlas.
- Cliente/staff tienen que aprender N tools.

**Mejor**: aceptar que ciertos módulos esperen 3-6 meses, mantener el negocio operativo con procesos manuales como hasta ahora (WhatsApp groups + Sheets), y construir bien cuando toque. NO hacer el "temporal" automatizado que luego hay que des-automatizar.

## Pros del approach modular

- **Velocidad incremental**: cada módulo se entrega independiente.
- **Risk isolated**: bug en `inventory` no afecta `bot` ni `site`.
- **Onboarding gradual**: staff puede usar `apps/staff-tasks` antes de que `chef` exista.
- **A/B test módulos**: si `chef` no aporta valor, se desactiva sin tocar resto.
- **Pricing module independent**: ver `decisions/03-pricing-agent.md`.

## Cons

- Tentación de duplicar logic entre módulos. Disciplina con `packages/` previene esto.
- Más bundles Worker (cada app deploy separado). No es problema (Workers libre tier limit es generoso).

## Voto

- [ ] **Claude Code**: ¿de acuerdo con la estructura? ¿algún módulo merece arquitectura distinta?
- [ ] **Alexander**: ¿priorización de módulos correcta? ¿algún módulo urgente que no esté listado?
