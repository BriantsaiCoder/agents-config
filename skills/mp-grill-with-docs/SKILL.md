---
name: mp-grill-with-docs
description: Use when clarifying requirements or stress-testing a feature's design before implementation — grills the user relentlessly to sharpen domain terminology and resolve design decisions one branch at a time. Produces and updates CONTEXT.md (domain glossary) and ADRs inline as decisions crystallise; these docs are outputs created lazily, not preconditions — applies whether or not they already exist.
disable-model-invocation: true
---

Interview the user relentlessly about every aspect of this plan until you reach shared understanding. Walk each branch of the design tree, resolving dependencies one-by-one. For each question, provide your recommended answer. Ask one question at a time, wait for feedback before continuing. If codebase exploration would answer it, explore instead of asking.

## File structure

Single context:

```
/
├── CONTEXT.md
├── docs/adr/
└── src/
```

Multi-context (root has `CONTEXT-MAP.md` pointing to per-context locations like `src/ordering/CONTEXT.md` + `src/ordering/docs/adr/`).

Create files lazily — only when you have something to write.

## During the session

### Challenge & sharpen language

- **Glossary conflict**: term clashes with `CONTEXT.md` → call it out immediately. _"Your glossary defines 'cancellation' as X, but you mean Y — which is it?"_
- **Fuzzy term**: propose precise canonical replacement. _"'account' — Customer or User? Those are different."_
- **Concrete scenarios**: invent edge-case scenarios that force precision about concept boundaries.
- **Code vs claims**: cross-check; if code contradicts what the user just said, surface it. _"Your code cancels entire Orders, but you said partial cancellation is possible — which is right?"_

### Update CONTEXT.md inline

When a term resolves, update `CONTEXT.md` right there — don't batch. Format: see [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md). Only include terms meaningful to domain experts; don't couple to implementation details.

### Offer ADRs sparingly

Only when **all three** hold:

1. **Hard to reverse** — meaningful cost to change later
2. **Surprising without context** — future reader will wonder "why this way?"
3. **Real trade-off** — genuine alternatives existed, you picked one for specific reasons

Missing any → skip. Format: [ADR-FORMAT.md](./ADR-FORMAT.md).

## Red Flags — STOP and Reset

- Glossary conflict surfaced and you continued without resolving it.
- Batched ≥ 3 `CONTEXT.md` updates "to do at the end" — they will drift.
- Code/spec contradiction appeared and you noted instead of forcing the user to pick.
- Used the user's vague term without proposing a canonical replacement.

**All of these mean: stop. Resolve now. Update `CONTEXT.md` inline.**

## No Exceptions

- **Glossary conflicts blocking** — never let a term mean two things in one conversation.
- **Updates inline, not batched** — each resolution writes immediately.
- **Code wins over claims** — surface contradictions; don't paper over.
- **Violating the letter is violating the spirit** — "we'll update after this session" guarantees drift.

| Rationalization | Reality |
|---|---|
| "I'll update CONTEXT.md at the end" | You'll forget half the resolutions and re-litigate them later. |
| "Close enough to the existing term" | "Close enough" = ambiguous. Force the user to pick. |
| "User is on a roll, don't interrupt" | Terminology drift is the bug. Interrupting now saves a future incident. |
