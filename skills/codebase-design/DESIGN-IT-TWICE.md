# Design It Twice

When the user wants to explore alternative interfaces for a chosen deepening candidate, produce materially different designs before selecting one. Based on "Design It Twice" (Ousterhout) — your first idea is unlikely to be the best.

Uses the vocabulary in [SKILL.md](SKILL.md) — **module**, **interface**, **seam**, **adapter**, **leverage**.

## Process

### 1. Frame the problem space

Before producing alternatives, write a user-facing explanation of the problem space for the chosen candidate:

- The constraints any new interface would need to satisfy
- The dependencies it would rely on, and which category they fall into (see [DEEPENING.md](DEEPENING.md))
- A rough illustrative code sketch to ground the constraints — not a proposal, just a way to make the constraints concrete

Show this to the user, then immediately proceed to Step 2.

### 2. Produce independent alternatives

The main context produces at least two **radically different** interfaces. Under shared `dev-workflow` INT-4, use one sub-agent for a substantial independent alternative only when that perspective materially improves the comparison; otherwise produce both in the main context. Add another agent only when a distinct, substantial constraint cannot be covered by the existing work, and keep user-authored or runtime limits.

Give each design a separate technical brief (file paths, coupling details, dependency category from [DEEPENING.md](DEEPENING.md), what sits behind the seam). A delegated brief is independent of the user-facing problem-space explanation in Step 1. Choose contrasting constraints that expose real trade-offs, such as:

- "Minimize the interface — aim for 1–3 entry points max. Maximise leverage per entry point."
- "Maximise flexibility — support many use cases and extension."
- "Optimise for the most common caller — make the default case trivial."
- "Design around ports & adapters for cross-seam dependencies."

Include both [SKILL.md](SKILL.md) vocabulary and CONTEXT.md vocabulary in each brief so every design uses the architecture language and the project's domain language consistently.

Each design includes:

1. Interface (types, methods, params — plus invariants, ordering, error modes)
2. Usage example showing how callers use it
3. What the implementation hides behind the seam
4. Dependency strategy and adapters (see [DEEPENING.md](DEEPENING.md))
5. Trade-offs — where leverage is high, where it's thin

### 3. Present and compare

Present designs sequentially so the user can absorb each one, then compare them in prose. Contrast by **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**.

After comparing, give your own recommendation: which design you think is strongest and why. If elements from different designs would combine well, propose a hybrid. Be opinionated — the user wants a strong read, not a menu.
