---
name: mp-diagnose
description: Use when reproducing hard bugs and performance regressions where root cause is non-obvious — flaky tests, intermittent failures, perf drift, "broken/throwing/failing" symptoms. Apply when user says "diagnose this", "debug this", or describes a symptom whose root cause requires reproduce-minimise-instrument loop.
---

# Diagnose

Discipline for hard bugs. Skip phases only when justified. Use CONTEXT.md + area ADRs while exploring.

## Phase 1 — Build a Feedback Loop

**This is the skill.** Without a fast deterministic pass/fail signal, no code-staring saves you. Spend disproportionate effort here.

See `references/feedback-loop.md` for patterns. Don't proceed without a loop.

## Phase 2 — Reproduce

Run the loop; watch the bug appear. Confirm: produces the **user**-described failure (not a nearby one); reproducible across runs (or high enough rate); exact symptom captured for later verification.

## Phase 3 — Hypothesise

Generate **3–5 ranked hypotheses** before testing any (single = anchoring). Each must be **falsifiable**:

> "If <X> is the cause, then <changing Y> makes the bug disappear / <changing Z> makes it worse."

If you can't state a prediction, it's a vibe — discard or sharpen. Show the ranked list to the user (domain knowledge re-ranks instantly); don't block if AFK.

## Phase 4 — Instrument

Each probe maps to a Phase 3 prediction. **Change one variable at a time.**

Tool order: debugger / REPL (one breakpoint beats ten logs) → targeted logs at hypothesis-distinguishing boundaries → never "log everything and grep."

**Tag every debug log** `[DEBUG-a4f2]` so cleanup = single grep.

**Perf branch**: logs usually mislead. Baseline first (timing harness / profiler / query plan), then bisect.

## Phase 5 — Fix + Regression Test

Regression test **before the fix** — but only if a **correct seam** exists (exercises the real bug pattern at the call site; shallow seams = false confidence).

No correct seam = the finding (architecture blocks lockdown — flag for Phase 6).

If correct seam exists: minimised repro → failing test → fix → passing test → re-run Phase 1 on un-minimised scenario.

## Phase 6 — Cleanup + Post-Mortem

Before declaring done: original repro no longer reproduces (re-run Phase 1); regression test passes (or seam absence documented); all `[DEBUG-...]` removed (grep the prefix); prototypes deleted; correct hypothesis in commit/PR.

If architecture prevented a good seam → hand off to `mp-improve-codebase-architecture` AFTER fix lands.

## Red Flags — STOP

- Skipping Phase 1 ("I see the bug, just fix it")
- Single hypothesis in Phase 3 (anchoring)
- Untagged debug logs (survive cleanup)
- Regression test at shallow seam (false confidence)
- Claiming "fixed" without re-running Phase 1 on original scenario

**All mean: stop. Return to the failing phase.**

## No Exceptions

- **No fix without feedback loop** — "I'm sure" without loop = guess
- **3–5 ranked hypotheses** before testing any
- **Tag every debug log** `[DEBUG-xxxx]`
- **Re-run Phase 1 on un-minimised scenario** before declaring done
- **Letter = spirit** — "this bug is simple, skip Phase 3" is exactly when bias bites
