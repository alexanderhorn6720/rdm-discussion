# cc-instructions-bot/

Specs orientadas a **CC-Bot** (sesión que trabaja en `apps/worker-bot/` + `packages/agents/greeter/`).

Diferenciado de `cc-instructions/` (especificación general WC→CC) y `cc-instructions-data/` (CC-Data, data mining).

---

## Greeter v5 Fase 2 — execute spec

**Status**: ✅ READY for CC
**ETA total**: 3-5 días (CC ~12h distributed, Alex stage transitions)
**Branch**: `feat/greeter-v5-core` (CC-owned)

Read in order:

| # | File | Content |
|---|---|---|
| 1 | `2026-05-15-greeter-v5-prompt-part1-pra4.md` | **PR A4** — Tool definitions + intent-resolver integration |
| 2 | `2026-05-15-greeter-v5-prompt-part2-pra6.md` | **PR A6** — System prompt v5 verbatim + tests |
| 3 | `2026-05-15-greeter-v5-prompt-part3-pra7.md` | **PR A7** — Canary rollout + dashboard |

Total spec: ~3000 líneas distributed across 3 files for readability.

### Quick TL;DR

- **PR A4**: Replace free-text Stage 2 with tool-call enforcement. 4 tools: `route_user_to_url`, `request_clarification`, `handoff_to_booker`, `escalate_to_human`.
- **PR A6**: System prompt v5 — bilingual ES/EN, hardcoded pet policy ($300/max 2), strict guardarrails against hallucination, "Felix" persona for greetings, NO Casa Chamán mentions.
- **PR A7**: Canary 0→10→25→50→100% via D1 `bot_config` table, admin dashboard `/admin/bot-metrics`, Telegram alerts on error spikes.

### Implementation order

1. Day 1: PR A4 (~5h)
2. Day 2: PR A6 (~4h)
3. Day 3: PR A7 (~3h) + Alex starts canary at 10%
4. Days 4-7: Canary scale per metrics

---

## How to use

1. CC reads parts 1-3 sequentially
2. If clarifying questions → publish `thread/XX-cc-greeter-v5-questions.md`
3. WC responds within 2h
4. CC implements PRs in order
5. WC reviews each PR before merge
6. Alex does canary stage transitions via dashboard

---

## Out of scope reminders

- ❌ Booker refactor (separate sprint)
- ❌ Casa Chamán (Q3 2026)
- ❌ AirBnB vs WhatsApp prompt split (PR A8, deferred)
- ❌ Operator playbook integration (PR A6.1, post-Data-Mining-v2)
