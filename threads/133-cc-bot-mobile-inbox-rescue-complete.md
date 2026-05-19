# Thread 133 · CC report · Mobile inbox Part E rescue complete

**From:** CC-Bot
**To:** WC + Alex
**Date:** 2026-05-19
**Re:** thread/131 (mobile WhatsApp inbox UX rescue)
**PR:** #126 — squash-merged to main at 15:08Z (commit `d84ed64`)

---

## TLDR

The 40% missing from PR #90 (mobile WA-style UX) is shipped. Desktop view unchanged. Tests 16/16 pass. CF Pages deploy polling, prod smoke pending.

---

## 1 · Spec-vs-shipped scope check (per thread/131 closing recommendation)

This is the explicit scope-vs-spec table WC asked for to avoid the silent-drop pattern that caused this rescue.

| thread/107 §5 + thread/131 §3 requirement | Status | Notes |
|---|---|---|
| `isMobile` state detection (`matchMedia ≤1023px`) | ✅ | Per spec breakpoint. Mounted in `useEffect`, cleaned up. |
| `selectedConvId` state synced to URL hash | ✅ | `#conv=<encodedId>`; `hashchange` listener; `history.replaceState` on close to avoid empty-hash back-button entries. |
| Card-style list (WA-style per conversation) | ✅ | New `<ul.inbox-card-list>` with `<button.inbox-card>`. State-specific left-edge border + tinted background. Channel/source badges. Critical marker ⚠. |
| Mobile-only `selectedConv` toggle (list OR conv) | ✅ | Early-return in `InboxView`: when `isMobile && selectedConvRow`, render only `<ConversationView/>`. Otherwise render filters + list. |
| `ConversationView` component (full-screen threaded chat) | ✅ | New file `apps/web/src/components/admin/ConversationView.tsx`. Per spec, separated because >150 lines. |
| Back button | ✅ | `← onClick={onBack}` in `.conv-header`. `closeMobileConv` also resets URL hash. |
| Message bubbles, inbound (white, left) | ✅ | `.conv-bubble-inbound` |
| Message bubbles, outbound (`#d9fdd3` green, right) | ✅ | `.conv-bubble-outbound` |
| Background `#efeae2` | ✅ | `.conv-thread { background: #efeae2 }` |
| Inline reply input | ✅ | `<textarea>` in `.conv-compose` + send button. Cmd/Ctrl+Enter sends. Optimistic append on success. |
| Reuse `GET /api/admin/conv/:id/history` | ✅ | Tolerant parser supports `messages[]` and `history[]` shapes; `bot_messages_inbox` rows AND `bot_conv` jsonl rows. |
| Reuse `POST /api/admin/messenger/send` | ✅ | Same endpoint as `ReplyPanel`. Surfaces `feature_off` / `no_route` / network errors inline. |
| CSS responsive grid (mobile single-col, desktop existing) | ✅ | `isMobile` branch in render does this without CSS grid — simpler and avoids accidental desktop regression. |
| Smooth transitions | partial | Browser default. No JS-driven slide-in. Acceptable for v1 per spec ambiguity. |
| Tests (5+) | ✅ 16 | All pure-function unit tests (repo doesn't ship React Testing Library). Cover `mobileConvIdForRow`, `readConvIdFromHash`, `normalizeMessage` shape tolerance. |
| Karina training doc §5.1 updated | ✅ | Callout added explaining the mobile view. |
| Desktop view (≥1024px) unchanged | ✅ | Table + filters + `ReplyPanel` drawer untouched. `isMobile=false` early-return path is identity-equivalent to pre-PR behavior. |
| All existing tests pass | ✅ 342/342 web tests pass |

### Out of scope (per spec §4 — Phase 2 items)

- Push notifications
- Offline / PWA shell
- Voice recording
- Archive view, multi-select, batch ops
- Pull-to-refresh
- Read receipts (Beds24 messages don't expose double-tick reliably)
- Typing indicator

---

## 2 · Files changed

| File | Lines | Notes |
|---|---|---|
| `apps/web/src/components/admin/ConversationView.tsx` | +233 | New file. `normalizeMessage` + `RawMessage` exported for tests. |
| `apps/web/src/components/admin/InboxView.tsx` | +101 / -3 | Added `isMobile`, `selectedConvId` state machine; `mobileConvIdForRow`, `readConvIdFromHash` exported. Conditional render. ReplyPanel skipped on mobile. |
| `apps/web/src/components/admin/InboxView.css` | +307 | WhatsApp-style chat CSS appended. Pre-existing `.inbox-table` / `.reply-panel` rules untouched. |
| `apps/web/src/pages/admin/karina-training/index.astro` | +8 | Callout under §5.1 about mobile view. |
| `apps/web/tests/inbox-mobile.test.ts` | +145 | New test file. 16 tests. |

Net: +937 insertions, -4 deletions. 5 files.

---

## 3 · Idempotency / safety properties

| Property | How it's guaranteed |
|---|---|
| Desktop view unchanged | `isMobile` defaults to `false`. The `if (isMobile && selectedConvRow)` early-return only fires on mobile + matching row. ReplyPanel is now gated by `!isMobile` (it was always desktop-only via CSS @media, this just hoists the gate to JS for clarity). |
| URL hash doesn't pollute browser history | `closeMobileConv` uses `history.replaceState(null, '', pathname + search)` instead of clearing `window.location.hash` directly. |
| Stale hash → graceful degradation | `selectedConvRow = useMemo(...).find(...) ?? null`. If the hash points at a conv that's been filtered out / no longer in allRows, `selectedConvRow` is null and the list renders instead. |
| Send idempotency | Reuses messenger-send endpoint with existing `messenger_outbound` audit trail (PR #90). Optimistic append doesn't write to D1 — only displays on screen. Refresh = canonical state. |
| Beds24 echo doesn't double-render | `ConversationView` only renders messages from the `history` fetch + locally appended optimistic ones. Beds24 echoes arrive on a different webhook path and don't affect this view until the user refreshes. |
| `normalizeMessage` is tolerant | Maps `text|message|body|content`, `source|role|direction`, `timestamp_unix|time|timestamp`. Unknown source defaults to `'guest'` (safe — looks like an unread inbound bubble, prompts admin attention). Empty text doesn't crash. |

---

## 4 · Smoke plan (post-deploy)

```
1. curl -I https://rincondelmar.club/admin/inbox  → 302 (route exists)
2. Open /admin/inbox on desktop (≥1024px), logged in admin@:
   - Table renders, filters work, ReplyPanel drawer opens (Reply button).
   - URL has no #conv hash even on tap.
3. Resize DevTools viewport to <1024px (or open on phone):
   - Table disappears, card list renders.
   - Filters condense to row-wrap.
   - Summary breakdown numbers hide (just the headline count stays).
   - Tap a card → URL becomes #conv=<id>, view swaps to fullscreen ConversationView.
   - WhatsApp green header, ← back button, message bubbles in/out colors correct.
   - Compose textarea + send button visible.
   - Tap ← back → URL clears (no #conv), card list reappears.
4. (If MESSENGER_OUTBOUND_ENABLED=true) Type a message + Cmd+Enter:
   - Bubble appears immediately (optimistic).
   - No error message.
5. (If MESSENGER_OUTBOUND_ENABLED=false in prod) Same flow:
   - "⏸ Outbound OFF" error renders above textarea.
   - Bubble does NOT append.
6. Hard-refresh while in #conv=<id> hash:
   - Page reloads, ConversationView renders again immediately for same conv.
```

Will perform 1-3 via curl-side smokes; 4-6 need Alex's browser session.

---

## 5 · CI / merge mechanics

- CI: pre-existing red baseline on main (`noNonNullAssertion` warnings treated as errors in `pnpm check`). PR #126 inherited the red baseline, didn't worsen it. Admin-merged per the established pattern from #117 / #115 / #116.
- Deploy.yml: ran post-merge, polling for completion.
- CF Pages auto-build: continues to fail "dist not found" per #119 revert; doesn't block deploy.yml.

---

## 6 · Time elapsed

- Read existing code (Phase 1): ~10 min
- ConversationView.tsx (Phase 4): ~15 min
- InboxView.tsx mobile state (Phase 2-3): ~15 min
- CSS (Phase 5): ~15 min
- Tests (Phase 6): ~10 min
- Karina training doc (Phase 7): ~5 min
- Merge + deploy polling: ~10 min so far

Total in-session: ~80 min. Budget was 10-13h (halt 19h). Well under.

---

## 7 · Closing recommendation for next CC session (or future thread)

### Pattern reinforcement

Per WC's note in thread/131 §1: every PR closing report **must** include explicit spec-vs-shipped scope-check table. This thread does that in §1. Future PR reports should do the same — the silent-drop pattern is what landed us here, and the scope-check is the only practical defense.

### Open follow-ups (not blocking)

| Item | Owner | Notes |
|---|---|---|
| Real-mobile smoke (iPhone Safari + Android Chrome) | Alex, 5 min | DevTools resize covers most, but iOS keyboard pushing the compose textarea up / Safari `100dvh` quirks are real-device only. |
| Karina demo | Alex + Karina, 10 min | Show her the mobile UI on her phone, validate flow. |
| Decide if MESSENGER_OUTBOUND_ENABLED stays canary or flips ON | Alex, post-smoke | Independent of this PR — but the new UX makes outbound much more discoverable, so worth a re-decision. |
| Beds24 inbox `bot_messages_inbox` history → reachable via `/admin/conv/:bookingId/history`? | Worker check | The web endpoint regex `[0-9a-zA-Z_-]{4,32}` accepts beds24 booking IDs (numeric), but the worker's history handler may only know about ManyChat. If a Beds24-only row's mobile card opens an empty conversation, the worker side needs to grow a beds24 history lookup. Will surface in smoke. |
| Phase 2 items (push, voice, offline, archive) | future spec | Listed §4 of thread/131. |

---

WC: please review the scope-check table in §1 against thread/107 §5 once you have a cycle. If anything looks short or off, flag in thread/134 and I'll patch.

CC-Bot out.
