---
thread: 169
author: WC
date: 2026-05-22
topic: cc-harness-oss-survey
mode: brain deep
status: open-for-cc-challenge
related:
  - cc-instructions-bot (CLAUDE v2 atomic, settings v2)
  - thread/134 (Beds24 read-only proxy → posible MCP)
  - thread/162 (state repair, multi-CC safety)
deliverable: decisión adopt/adapt/reject por cada herramienta OSS evaluada
---

# Survey OSS para harness Claude Code en RdM

## 0. Propósito del thread

Documentar el search, análisis y priorización detrás de mi recomendación de **adoptar `cloudflare/skills` + `obra/superpowers` + `ccusage` como base del harness CC para RdM**, con datos suficientes para que un CC lo rete con fundamento.

Este thread NO es spec ejecutable. Es **decision-making sustantivo** previo a un DoIt. Si CC encuentra error en datos, supuesto, o priorización: abrir thread de respuesta con evidencia, no hacer fix inline.

---

## 1. Pregunta original

Alex (mobile chat, brain deep mode):
> "Que Best practices ya se han implementado y están disponibles en open source, GitHub por ejemplo? Frameworks, skills, tools que pueda usar?"

Contexto implícito: 3+ sesiones CC concurrentes, stack Cloudflare-native, workflow brain→spec→DoIt→verify ya formalizado, CLAUDE v2 atomic ya en place. Pregunta real = **qué reinvento que ya existe**.

---

## 2. Search trail

Búsquedas ejecutadas vía `web_search` desde claude.ai mobile, ordenadas:

| # | Query | Intención | Hits útiles |
|---|---|---|---|
| 1 | "Claude Code docs map best practices 2026" | Anclar canonical guidance | Anthropic official docs page, SAP community post, beginnersinai playbook |
| 2 | "Anthropic Claude Code official best practices skills subagents hooks plan mode" | Skills + hooks + subagents oficiales | code.claude.com/docs/en/best-practices, ofox guide, shipyard cheatsheet |
| 3 | "awesome claude code github open source skills hooks subagents 2026" | OSS landscape | hesreallyhim/awesome-claude-code, rohitg00 toolkit, ComposioHQ, GetBindu, jqueryscript |
| 4 | "claude code subagents framework orchestration multi-agent github stars" | Frameworks de orquestación | obra/superpowers, ruvnet/claude-flow (Ruflo), wshobson/agents, claude_code_agent_farm, barkain orchestration |
| 5 | "claude code cloudflare workers wrangler skills hooks typescript monorepo" | Match a tu stack específico | **cloudflare/skills oficial**, developers.cloudflare.com/agent-setup/claude-code/, workers-mcp |
| 6 | "anthropic skills repository github official agent skills" | Skills marketplace canónico | anthropics/skills (17 dirs), anthropics/claude-plugins-official, VoltAgent/awesome-agent-skills |
| 7 | "claude code hooks library guardrails ccguard ccusage cost monitoring observability" | Cost + safety layer | ryoppippi/ccusage, ccflare, Claude-Code-Usage-Monitor, AgentsRoom, ECC/agentshield |
| 8 | "claude code spec-driven development TDD superpowers github obra workflow" | Validar Superpowers como match a brain→spec→DoIt | obra/superpowers detail, DataCamp tutorial, marcnuri analysis, yuv.ai writeup |

**Gaps de search reconocidos**:
- No busqué específicamente skills para "ManyChat / WhatsApp BSP" — gap real para tu inbox
- No busqué frameworks de testing E2E específicos para Cloudflare Workers + Vitest
- No comparé Superpowers vs Claude Flow head-to-head en repos con benchmarks reales
- No verifiqué que los repos citados sigan activos en 2026-05 (algunos pueden estar abandonados)

CC vale repetir estas búsquedas o ampliarlas antes de adoptar.

---

## 3. Inconsistencias detectadas en datos

**Importante para honestidad técnica**: las búsquedas mostraron datos inconsistentes que NO resolví. Un CC vale verificar:

| Item | Fuentes contradictorias |
|---|---|
| Stars de `obra/superpowers` | Vi citado: 11.8k (vibesparking dic 2025), 170,634 (pasqualepillitteri), 174k (marcnuri may 2026), 194k (DataCamp). Probablemente crecimiento real, pero las cifras altas son improbables para 7 meses |
| Stars de Ruflo/claude-flow | Citado 31.1k. No verificado contra GitHub directamente |
| % SWE-bench Ruflo (84.8%) y cost savings (75%) | Vienen de un blog promocional (pasqualepillitteri.it), no de paper o benchmark independiente |
| ccusage features | Cita output con muchos providers (claude, codex, gemini, copilot, etc.) — verificar que actualmente soporten todos |
| Anthropic CC version actual | No verifiqué versión exacta del CLI |

**Acción CC**: antes de adoptar Superpowers, verificar repo activo + revisar últimos 30 días de commits. No instalar basándose en stars únicamente.

---

## 4. Taxonomía OSS construida

5 capas detectadas. Síntesis del análisis:

| Capa | Madurez | Match RdM | Decisión propuesta |
|------|---------|-----------|---------------------|
| Anthropic oficial (skills, plugins, cookbooks) | Alta | Alta | Adoptar selectivamente |
| Cloudflare oficial (skills repo + agent-setup docs) | Alta | **Crítica** | Adoptar completo |
| Frameworks discipline (Superpowers, Ruflo, agent-farm) | Alta para Superpowers | Alta para Superpowers, baja para resto | Adoptar Superpowers, rechazar resto |
| Awesome-lists / discovery | Alta | Media | Bookmark, no adoptar |
| Subagents drop-in (wshobson, dotclaude, etc.) | Variable | Alta vía cherry-pick | Cherry-pick específicos |
| Hooks + guardrails (rins, ccguard, agentshield) | Media-alta | Alta para agentshield | Adoptar agentshield, evaluar resto |
| Observability + cost (ccusage, ccflare, monitor) | Alta para ccusage | **Crítica** (multi-CC) | Adoptar ccusage |
| Memory + context (reporecall, auto-memory, recall) | Variable | Baja-media | Diferir |
| Container / safety (claude-code-container, Sandbox SDK) | Alta | Media | Evaluar post-Sprint 2 |

---

## 5. Priorización — criterios usados

Ordené no por capa lógica sino por **ratio valor/esfuerzo** para tu situación específica:

| Criterio | Peso | Razón |
|---|---|---|
| Reduce retrabajo concreto identificado | Alto | CC inventando APIs Workers v3 viejas = retrabajo medible |
| Compatible con anti-patterns RdM existentes | Alto | No puede contradecir CLAUDE v2 atomic |
| Multi-CC safe | Alto | 3+ sesiones paralelas activas |
| Esfuerzo de adopción <1 día | Alto | Estás mid-pipeline (thread/160, BEDS24+TG manuales, A5 brain pendiente) |
| Reversible si falla | Alto | Skills y hooks son markdown + shell, fork-able |
| Stars / community size | **Bajo** | Anti-criterio: muchos repos top son AI-bulk-generated |
| Mantenido por vendor oficial | Alto | cloudflare/skills y anthropics/skills > comunidad |

**Lo que NO usé como criterio**: hype, "trending GitHub Feb 2026", "84.8% solve rate", stars >100k. Todos esos vienen de marketing y no predicen retorno real para tu setup.

---

## 6. Decisiones propuestas — con justificación retable

### 6.1 Adoptar `cloudflare/skills` completo

**Razón principal**: bias retrieval de docs oficiales sobre baked-in knowledge. Tu CC opera con conocimiento desactualizado de Wrangler 4.x APIs.

**Skills directamente relevantes para RdM stack**:
- `workers-best-practices` (anti-patterns: streaming, floating promises, global state, secrets, bindings)
- `cloudflare` (umbrella: D1, R2, KV, Workers AI, Vectorize, Agents SDK)
- `durable-objects` (útil cuando muevas conversation-state a DO)
- `cloudflare-email-service` (evaluar vs Resend actual)

**Retos potenciales para CC**:
- ¿Cuánto contexto consumen estas skills cuando activan? ¿Inflan sesión a >70%?
- ¿El "bias retrieval" colisiona con tu prompt caching de Haiku 4.5 en bot prod?
- ¿Has medido la tasa real de "CC inventó API que no existe" o es asumida?

### 6.2 Adoptar `obra/superpowers` como base de discipline

**Razón principal**: workflow ya alinea con tu brain→spec→DoIt→verify, ahorra reinventar discipline-as-skills.

Mapping propuesto:
- brain mode → skill `brainstorming`
- spec doc v3 → skill `plan-creation`
- DoIt → skill `subagent-driven-development`
- verify → skill `verification-before-completion`

**Retos potenciales para CC**:
- ¿Superpowers asume git worktrees como parte del flujo? Tu setup actual es múltiples ramas en repos separados, no worktrees. Posible fricción
- ¿El SessionStart hook de Superpowers chocaría con tu SessionStart hook propuesto (anti-patterns)? Hay que componerlos sin conflicto
- TDD enforcement: tu codebase actual no es TDD-first. ¿Aceptas que Superpowers force red/green ciclo o lo deshabilitas?
- Superpowers ships como markdown distributed → puede actualizarse upstream y romper tu adaptación. Estrategia: fork y pinear versión

### 6.3 Adoptar `ccusage` + alert

**Razón principal**: visibilidad costo con 3+ CCs paralelos es no-negociable. Tu regla "stop si excede 1.5×" requiere telemetría real-time.

**Retos potenciales para CC**:
- ¿`bunx ccusage` requiere Bun instalado? Tu stack es pnpm + Node. Validar alternativa npm/pnpm
- ¿ccusage en Windows funciona igual que en Unix? Verificar paths `%USERPROFILE%\.claude\projects\*.jsonl`
- ¿Cómo cuenta tokens de subagentes? Si Superpowers spawnea muchos subagents, ¿se atribuyen al CC main o por separado?

### 6.4 Cherry-pick agents de `wshobson/agents`

Candidatos: `code-reviewer`, `database-architect`, `test-automator`, `security-auditor`.

**Retos potenciales para CC**:
- ¿Los agents asumen stack distinto (e.g. Postgres en database-architect)? D1 / SQLite tienen quirks que un agent genérico ignora
- ¿security-auditor genérico contradice tu lista de anti-patterns específicos (no ALTER TABLE multi-CC, etc.)?
- ¿Vale más definir tus agents desde cero usando `skill-creator` de Anthropic?

### 6.5 Adoptar `ECC/agentshield`

**Razón**: PAT expuesto en handoff. Scan inmediato necesario.

**Retos para CC**: 
- ¿Falsos positivos en tu codebase? Probar primero en branch aislada
- ¿Escala a 3 repos? Doc dice scan single-repo, no monorepo cross-repo

### 6.6 Rechazos explícitos

| Item | Por qué NO |
|---|---|
| `ruvnet/claude-flow` (Ruflo) | Overkill para tu tamaño; hive-mind queens/workers no aplica a 3 CCs |
| `claude_code_agent_farm` | Tu split A/D ya hace orquestación a escala humana |
| `claude-code-auto-memory` | CLAUDE v2 atomic es manual a propósito |
| `claude-user-memory` (12 agents) | Complejidad >> beneficio |
| Claude Code Agent Teams experimental flag | Esperar GA, no apostar a feature flag |
| SigNoz + OTel | Cuando tengas team multi-humano. Hoy solo eres tú |

---

## 7. Plan de adopción propuesto (4 sprints)

### Sprint 1 — alto retorno inmediato (1-2 días)
1. Instalar `cloudflare/skills` (workers-best-practices, cloudflare, durable-objects)
2. `ccusage daily` + cron diario a Telegram
3. `agentshield scan` sobre rdm-bot, rdm-discussion, rdm-platform
4. Instalar `anthropics/skills` plugin marketplace

### Sprint 2 — discipline harness (3-5 días)
5. Instalar `obra/superpowers`
6. Mapear modos RdM a skills Superpowers
7. Cherry-pick agents wshobson
8. Hook PostToolUse: biome + vitest related

### Sprint 3 — skills propios RdM (5-7 días)
9. `rdm-beds24-sync`
10. `rdm-d1-migration`
11. `rdm-canary-deploy`
12. `rdm-doit-spec`
13. `rdm-anti-patterns` (SessionStart hook)

### Sprint 4 — observability profunda (opcional)
14. `Claude-Code-Usage-Monitor` con alertas Telegram
15. `recall` para búsqueda cross-session
16. `reporecall` cuando monorepo crezca

---

## 8. Riesgos identificados

| Riesgo | Probabilidad | Severidad | Mitigación propuesta |
|---|---|---|---|
| Superpowers cambia workflow probado | Media | Alta | Adopción gradual; DoIt v3 sigue siendo override |
| Skills Cloudflare consumen mucho contexto | Media | Media | Activación solo en trigger; Plan Mode acota |
| Agents cherry-picked contradicen anti-patterns RdM | Alta | Alta | Validar con tarea de prueba antes de merge a main |
| Multi-CC choca con hooks que mutan archivos | Media | Alta | Hooks idempotentes; settings v2 atomic ya cubre |
| ccusage no captura subagent tokens correctamente | Baja-Media | Media | Cross-validar con claude-token-lens |
| OSS proyecto abandonado | Baja | Baja | Fork-able trivialmente |
| ECC/agentshield false positive bloquea trabajo | Baja | Baja | Modo scan no bloquea |

---

## 9. Datos que NO encontré (gaps explícitos)

- No existe skill OSS específica para **Beds24**. Tu thread/134 (read-only proxy) sería novedad si lo publicaras como MCP/skill.
- No existe skill OSS para **ManyChat / WhatsApp BSP**. Gap real, posible contribución de RdM al ecosistema.
- No existe skill OSS estable para **AirBnB scraping** (thread/127). El ecosistema legal-grey es por razón.
- No encontré benchmark independiente que compare Superpowers vs Claude Flow en tasks reales.
- No encontré data sobre cuánto retrabajo evita `cloudflare/skills` en producción (es asumido, no medido).

---

## 10. Challenge points explícitos para CC

CC, si vas a retar este thread, estos son los puntos más vulnerables del análisis:

1. **Stars / hype como señal**: usé como criterio negativo pero no medí calidad real de skills/agents adoptables. Vale auditar contenido de obra/superpowers/skills/*.md uno por uno antes de adoptar.
2. **No probé nada**: este es analytical-only. Cero validación empírica. Sprint 1 debería empezar con tarea ficticia de prueba en branch aislada, no en producción.
3. **Asumí compatibilidad de hooks**: Superpowers SessionStart hook + tu propuesto SessionStart hook anti-patterns pueden chocar. No verifiqué cómo Claude Code resuelve múltiples hooks del mismo tipo.
4. **Ignoré costo de instalación recurrente**: adoptar 4 skills Cloudflare + Superpowers + 4 agents + 5 skills propios = harness de ~14 piezas que un futuro CC debe entender. Posible over-engineering del harness.
5. **No comparé con NO adoptar**: ¿qué tan mal está tu setup actual sin nada de esto? Si ya entregas con CLAUDE v2 + settings v2 + tu workflow, ¿el incremento justifica el cambio?
6. **Modelo en cada agent**: wshobson/agents usa modelos default (sonnet) en frontmatter. Tu setup actual es Haiku 4.5 en bot prod. ¿Asignamos modelos óptimos por agent? No lo resolví.
7. **Windows quirks**: Alex está en Windows; muchos hooks asumen bash/Unix. rins_hooks dice cross-platform pero no validé. ccusage paths Windows no verificados.
8. **Costo $ real del harness**: Adoptar Superpowers + subagents adicionales puede multiplicar tokens por turno. No estimé incremento. Ironía: instalo ccusage para vigilar costo causado por instalar Superpowers.

---

## 11. Decisión solicitada de CC

Por orden de impacto:

- [ ] **Confirmar o retar punto #5** (¿incrementa el harness lo suficiente sobre tu setup actual?)
- [ ] **Confirmar o retar punto #4** (¿14 piezas es over-engineering?)
- [ ] **Probar Sprint 1 en branch aislada** antes de commit a main
- [ ] **Validar stars/maintenance reales** de los repos críticos (Superpowers, cloudflare/skills, ccusage)
- [ ] **Validar compatibilidad Windows** de tooling propuesto

Si CC valida ≥3 de 5: proceder con DoIt Sprint 1.
Si CC reta ≥2: parar, abrir thread de respuesta con propuesta alternativa.

---

## 12. Apéndice — fuentes consultadas

URLs verificables (CC vale re-fetch para confirmar):

- https://github.com/anthropics/skills
- https://github.com/anthropics/claude-plugins-official
- https://github.com/cloudflare/skills (referenciado pero no visitado directamente; verificar URL)
- https://developers.cloudflare.com/agent-setup/claude-code/
- https://github.com/obra/superpowers
- https://github.com/ryoppippi/ccusage
- https://github.com/wshobson/agents
- https://github.com/rohitg00/awesome-claude-code-toolkit
- https://github.com/hesreallyhim/awesome-claude-code
- https://github.com/VoltAgent/awesome-agent-skills
- https://github.com/affaan-m/everything-claude-code (ECC/agentshield)
- https://docs.claude.com/en/docs/claude-code/overview
- https://code.claude.com/docs/en/best-practices

Búsquedas originales: ver §2.

---

**Fin del thread.** Esperando challenge o approval de CC antes de proceder a DoIt Sprint 1.
