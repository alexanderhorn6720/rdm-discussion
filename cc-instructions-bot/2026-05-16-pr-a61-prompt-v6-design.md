# PR A6.1 Design — Greeter v5 prompt → v6 con operator_playbook patterns

**Date**: 2026-05-16
**Author**: CC-Bot (autonomous PR C draft)
**Status**: 🟡 DRAFT — no merged. Para revisión post canary v5 100%.
**Branch**: `pr-a61-prompt-v6-prep-DRAFT`
**Source patterns**: `data/artifacts/operator_playbook.md` (Stage C output, 18 patterns extraídos)

---

## Goal

Upgrade el Greeter v5 system prompt incorporando patterns reales observados
en 11 años de WhatsApp histórico (360 conversaciones analizadas). Objetivo:
mejorar conversion rate del bot manteniendo la architecture v5 (deflective
routing).

## Approach: incremental, NOT rewrite

v5 funciona (canary 50% sin issues post-hotfix). v6 NO reescribe, sino:

1. **Append nueva sección** "Patterns observados" después del INTENT_CATALOG
2. **Añadir 3 new few-shot examples** demostrando los patterns más críticos
3. **Modifica una sola regla v5** (§5 saludo): de routing genérico a
   `request_clarification` para extraer intent del user
4. **Conservar** todas las otras reglas + estructura tools-v5

## Patterns incorporados (8 reglas distiladas de 18 del playbook)

| ID | Pattern | Aplicabilidad | Source playbook |
|---|---|---|---|
| **P1** | Eco de datos del user (fechas+grupo en opening_line) | Universal | Section group_specified §1+5, price_quoted §1 |
| **P2** | Saludo con nombre cuando disponible | Universal | Section group_specified §3 |
| **P3** | Reconocer referido / repeat | Universal | Section initial_inquiry §3, group_specified §7 |
| **P4** | Aperturas vacías → clarification | First turn | Section initial_inquiry §6 (anti-pattern) |
| **P5** | "Déjame ver con grupo" → ofrecer materiales | Mid-conv | Section price_accepted §2 (anti-pattern) |
| **P6** | Fechas distantes → hint escasez temporada alta | Conditional | Section price_accepted §5 (anti-pattern) |
| **P7** | Preguntas chef/menú = high intent → priorizar handoff | Conditional | Section initial_inquiry §4 |
| **P8** | Vague commits ("esta semana") → micro-acción | Closing | Section price_accepted §1 |

**Excluidos del bot scope**: patterns que requieren OPERADOR action
(emitir cifra total calculada, incluir datos bancarios, ofrecer alternativa
de fechas cuando hay choque). Esos son del sitio web (intent-resolver → URL),
no del bot deflector.

## File changes (draft)

| File | Type | Status |
|---|---|---|
| `packages/agents/greeter/system-prompt-v6-DRAFT.ts` | NEW | Draft branch only |
| `packages/agents/greeter/system-prompt-v5.ts` | UNCHANGED | v5 sigue activo en prod |
| `packages/agents/greeter/index.ts` | UNCHANGED | No exporta v6 todavía |
| `apps/worker-bot/src/run-greeter-v5.ts` | UNCHANGED | Sigue usando v5 |

Cuando se active PR A6.1 final:
1. Renombrar `system-prompt-v6-DRAFT.ts` → `system-prompt-v6.ts`
2. Exportar `GREETER_SYSTEM_PROMPT_V6` desde `greeter/index.ts`
3. `run-greeter-v5.ts` cambia import v5 → v6 (o nuevo `run-greeter-v6.ts`)
4. Tests anti-regression: prompt size <32KB, contains all patterns P1-P8

## Activation plan

```
[ahora]    canary v5 = 50% → observar greeter_turns 24-48h
[+24-48h]  si métricas verdes → canary 100% v5
[+24-72h]  observación post-100% → confirmar stable
[+72h+]    PR A6.1 final: merge v6, deploy, canary v6 = 10% (sub-rollout)
[+1 sem]   si v6 mejora conversion → scale a 50% → 100%
```

## Riesgos

- **R1**: prompt v6 más largo → más tokens input por turn. Mitigation: el
  prompt cache hit ratio compensa; size check en PR final.
- **R2**: v6 puede emitir intents diferentes vs v5 con mismo user input →
  click attribution rota baseline. Mitigation: tag `bot_version='v6'` en
  greeter_turns + comparar metrics aisladas.
- **R3**: nuevos few-shot examples pueden over-fit a casos específicos.
  Mitigation: tests con varied prompts, verificar diversidad.

## NO-merge conditions

NO mergear PR A6.1 si cualquiera de estos:
- canary v5 a 100% reveló bug stable
- greeter_turns muestra escalate rate v5 > 5% (anti-escalate prompt fail)
- Vectorize index NO populado (PR A6.1 puede consumir Vectorize en runtime
  para semantic similarity lookup — opcional, ver futuro PR A6.2)

## Open questions para WC review

1. ¿P5 ("ofrecer materiales para grupo") debe usar intent `fotos` o
   `comparar-casas`? Patterns suggest comparar-casas si grupo no específico
   property, fotos si ya hay property mencionada.
2. ¿P6 (urgency escasez) requiere validación real del calendar D1
   (consumir intent-resolver con check_in/out)? Por ahora prompt dice
   "menciona temporada alta" estático.
3. ¿Cuántos few-shot mantenemos? v5 tiene 7. v6 propone +3 = 10. Anthropic
   recommend max 10 para cache consistency.

---

**Next step**: WC review + Alex sign-off → CC procede con PR A6.1 final.
