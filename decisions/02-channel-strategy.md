# 02 — Estrategia de canales (Two-stage)

**Status**: Propuesta. Esperando voto.

**Decisión**: **Stage 1**: ManyChat como BSP único, Worker recibe webhooks. **Stage 2** (mes 4+): WhatsApp Cloud API directo de Meta, sunset ManyChat. IG/FB/TT directos via Meta Graph API.

## Contexto

Alexander pidió explícitamente two-stage approach. Refresco verificado de research 2026:

- **Meta Cloud API** (WhatsApp) es Meta-hosted, free infra, pricing per-conversation. Es donde Meta deploya features nuevas (WhatsApp Flows, etc.) primero.
- **ManyChat WhatsApp** es un BSP wrapper sobre Cloud API. Cobra markup. Útil para no-code, multi-canal, opt-in management.
- **Migración Cloud API directo** elimina markup, pero requiere: WABA propia, templates aprobados directamente con Meta, opt-in handling propio, infra propia para inbox/broadcast/templates.
- **Meta consolidó canales** en Graph API: WhatsApp Cloud API + IG Messaging API + Messenger Platform + (recientemente) Threads. TikTok sigue separado.

## Stage 1 — ManyChat + Worker (semanas 0-12)

### Arquitectura

```
WhatsApp ──┐
Facebook ──┤
Instagram ─┼──► ManyChat ──webhook──► apps/bot Worker
TikTok ────┘                              │
                                          ▼
                                       respuesta vía
                                       ManyChat API
                                       (SetCustomField + SendFlow)
```

### Pros

- **Cero cutover de opt-in**. Los suscriptores actuales en ManyChat (cientos/miles) no se pierden.
- **Templates HSM ya aprobados** siguen funcionando.
- **Multi-canal nativo** sin tocar Meta Business Manager.
- **Inbox compartido** del equipo en ManyChat para casos escalados.
- **Conmutación gradual al Worker**. ManyChat permite porcentaje de tráfico al webhook nuevo.

### Cons

- **Markup ~$15-50/mes** sobre el costo Meta puro.
- **Feature lag**. WhatsApp Flows nativos llegan tarde a ManyChat (si llegan).
- **Lock-in moderado**. Migrar opt-in lists out de ManyChat es manual.
- **Latencia extra**: ManyChat ↔ Worker round trip.

### Cambios respecto a hoy

- Hoy: ManyChat → Make → Worker (3 hops).
- Stage 1: ManyChat → Worker directo (2 hops). Make desaparece del path crítico.

## Stage 2 — Meta Cloud API directo + Worker (mes 4+)

### Arquitectura

```
WhatsApp Cloud API (Meta) ──┐
IG Messaging API (Meta) ────┤
FB Messenger Platform ──────┼──webhook──► apps/webhooks ──► apps/bot
TikTok Messaging API ───────┘                                  │
                                                               ▼
                                                          respuesta directa
                                                          via Meta Graph API
```

### Pros

- **TCO menor 30-60%** (citado en research 2026 industry).
- **WhatsApp Flows** soportados — formularios nativos en chat (booking flow inline).
- **Features Meta primero**: Click-to-WhatsApp ads, Marketing Messages Lite, broadcast con templates ricos.
- **Control total**: templates, opt-in, message scheduling, broadcasts.
- **Sin markup BSP**.
- **Mejor para ads spend**: 72h free messaging window cuando llega de CTW ad.

### Cons

- **Setup pesado**: WABA propia, verification Meta, templates re-approval, opt-in migration.
- **Inbox propio**: ManyChat tenía inbox gratis. Cloud API direct → necesitas tu propio inbox (parte del `apps/admin`).
- **Compliance propio**: opt-in storage, 24h window enforcement, template categorías (marketing/utility/service/auth).
- **Multi-canal**: IG/FB/TT cada uno requiere webhook + auth Graph API. No es 1-click.

### Tareas Stage 2

1. Crear WABA propia (Meta Business Manager, verificación de identidad, número dedicado).
2. Migrar templates HSM aprobados de ManyChat a la nueva WABA (re-approve).
3. Implementar `packages/channels/whatsapp/` con typed client Cloud API.
4. Implementar `apps/webhooks/whatsapp` con signature verification.
5. Inbox UI en `apps/admin` (lista de conversaciones, take over, search).
6. Opt-in migration: ManyChat tiene los phone numbers + opt-in timestamps. Export CSV + bulk import.
7. Coexistence period 2-4 semanas: WhatsApp en Cloud API direct, IG/FB/TT siguen en ManyChat.
8. Sunset ManyChat cuando todos los canales estén directos.

## Channel Abstraction Layer

Decisión clave para soportar two-stage sin reescribir bots cada vez:

```typescript
// packages/channels/types.ts
export interface ChannelProvider {
  receive(payload: unknown): Promise<IncomingMessage>;  // normalize webhook payload
  send(msg: OutgoingMessage): Promise<void>;            // send message
  markRead(messageId: string): Promise<void>;
  setTyping(subscriberId: string): Promise<void>;
}

export interface IncomingMessage {
  channel: 'whatsapp' | 'facebook' | 'instagram' | 'tiktok';
  subscriberId: string;       // canonical ID across providers
  text: string;
  attachments: Attachment[];
  timestamp: number;
  raw: unknown;               // original payload, archived
}
```

Implementaciones:
- `packages/channels/manychat/` — Stage 1.
- `packages/channels/whatsapp-cloud/` — Stage 2.
- `packages/channels/instagram/` — Stage 2.
- etc.

El agent (`packages/agents/greeter.ts`, `booker.ts`) NO sabe qué provider. Recibe `IncomingMessage` y emite respuesta vía `ChannelProvider.send()` inyectado.

**Esto es lo que mata el riesgo de lock-in.** Stage 2 es swap provider, no rewrite del bot.

## Pros/cons del two-stage como un todo

**Pros**:
- Mitiga riesgo. Sin cutover masivo.
- Permite migrar bots a Workers (Stage 1) sin tocar provider (gran reducción de blast radius).
- Stage 2 puede ser dependiente del éxito de Stage 1 + business case (volumen suficiente para justificar Cloud API direct).
- Build channel abstraction desde Stage 1 — paga dividendos en Stage 2.

**Cons**:
- Dos migraciones. Dos cutovers parciales.
- Tiempo total mayor que big bang.
- Mantener dos providers en paralelo durante coexistence (4 sem).

## Alternativa C — Quedarse en ManyChat indefinidamente

**Pros**: Cero migración Stage 2.
**Cons**: TCO 30-60% mayor a largo plazo. Sin acceso a WhatsApp Flows. Lock-in.

**No recomendado** salvo que volumen baje (no es el caso, va creciendo).

## Alternativa D — Saltar ManyChat, Cloud API directo desde día 1

**Pros**: Una sola migración.
**Cons**: Re-apruebación templates Meta tarda semanas. Riesgo de bloqueo de número WhatsApp si Meta tarda. Cliente actual del bot sería disrupted. Opt-in re-collection legalmente complejo.

**No recomendado**.

## Recomendación

**Two-stage**, como pidió Alexander. Stage 1 prioritario (12 sem), Stage 2 después de validar Stage 1 con tráfico real y completar admin board (que sirve como inbox).

## Voto

- [ ] **Claude Code**: ¿two-stage con channel abstraction desde día 1? Otra estructura?
- [ ] **Alexander**: ¿confirmas timing 12 sem Stage 1 + Stage 2 en mes 4-5?

## Refs

- WhatsApp Cloud API docs: `https://developers.facebook.com/docs/whatsapp/cloud-api`
- WhatsApp Flows: `https://developers.facebook.com/docs/whatsapp/flows`
- Industry pricing comparison 2026: Hyperleap, Chatarmin, SetSmart guides (research notes).
