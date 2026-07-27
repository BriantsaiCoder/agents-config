---
name: mp-tdd
description: 'Use when user explicitly wants vertical-slice tracer-bullet TDD — one-test-one-impl loop instead of writing all tests up front. For general red-green-refactor philosophy use superpowers:test-driven-development.'
disable-model-invocation: true
---

# mp-tdd — Vertical-Slice Tracer Bullet

## Overview

Base RED-GREEN-REFACTOR is in `superpowers:test-driven-development`. This skill adds **vertical slice**.

- **WRONG** — all tests up front, then all impls (horizontal → testing imagination; impl change collapses the suite).
- **RIGHT** — `test1 → impl1 → test2 → impl2 → ...` Each round uses real behavior from the last to drive the next.

First test = **tracer bullet** — prove the end-to-end path, then add increments.

## When to Use

- User asks for "one test at a time", "tracer bullet", or "vertical slice" workflow.
- Refactor / new feature where interface design must evolve under real signal.
- First cut into an unknown system — fire one round to confirm the path works.

## Workflow

1. Thinnest slice crossing the system end-to-end.
2. One failing test.
3. Minimum impl to pass.
4. Refactor with next test in mind.
5. Repeat — last impl informs next test.

## Common Mistakes

- **First test mocks the boundary** → no tracer signal. Slice 1 must hit the real seam, even with fake data.
- **Refactor step skipped after green** → next test inherits messy impl and learns the wrong shape.
- **Slice picked for ease, not coverage** → you'll learn nothing about the unknown. Pick the thinnest that crosses every layer.

## Red Flags — STOP and Reset

- About to write `test2 + test3` before `impl1` lands — that's horizontal slicing in disguise.
- About to draft all interfaces "to see the shape" — the next test is supposed to teach you the shape.
- "test1 was so simple, I'll batch test2 + impl2 + test3 + impl3" — batching collapses the discovery loop.
- Skipping the failing-test step because "I already know what the impl is" — you don't, the cycle is the proof.

**All of these mean: stop. Go back to one test → one impl. Delete batched code.**

## No Exceptions

- **One test → one impl → next test.** Never two ahead.
- **Tracer bullet first.** The thinnest end-to-end slice precedes any vertical depth.
- **Violating the letter is violating the spirit** — "I'll write 2 tests because they're related" is still horizontal slicing.

| Rationalization | Reality |
|---|---|
| "Tests are coupled, I'll write them together" | Coupled = same impl. Write one; impl shape changes the next test from your guess. |
| "I already know the design" | If you knew, you wouldn't need TDD. Impl reveals next test. |
| "Batching is faster" | Faster to write, slower to find wrong design. Velocity ≠ progress. |

## Cross-Reference

- Base R-G-R, anti-rationalization → `superpowers:test-driven-development`
- Full vertical-slice workflow + per-cycle checklist → `references/tracer-bullet.md`
- Test examples, mock rules, deep modules, interface design, refactor → `references/tests.md`, `mocking.md`, `deep-modules.md`, `interface-design.md`, `refactoring.md`
