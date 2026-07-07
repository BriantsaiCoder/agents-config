---
name: mp-improve-codebase-architecture
description: Use when improving codebase architecture, finding refactoring opportunities, consolidating tightly-coupled modules, or making code more testable / AI-navigable. Informed by CONTEXT.md domain language and docs/adr/ decisions.
---

# Improve Codebase Architecture

Surface friction; propose **deepening opportunities** (shallow → deep modules). Goal: testability + AI-navigability.

## Glossary

Use these terms exactly (no drift to "component/service/API/boundary"). Definitions: [LANGUAGE.md](LANGUAGE.md).

- **Module** = interface + implementation
- **Interface** = everything a caller must know (types, invariants, errors, ordering, config)
- **Depth** = leverage at the interface (deep = lot behind small interface)
- **Seam** = where an interface lives; where behaviour can change without editing in place
- **Adapter** = concrete thing satisfying an interface at a seam

Key principles:

- **Deletion test**: delete the module mentally — complexity vanishes (pass-through) or reappears across N callers (earns its keep).
- **Interface is the test surface.**
- **One adapter = hypothetical seam. Two = real seam.**

Informed by CONTEXT.md / ADRs; don't re-litigate them.

## Process

### 1. Explore

Read CONTEXT.md + area ADRs. Dispatch `Agent(subagent_type=Explore)`. Note friction:

- One concept requires bouncing between many small modules
- Modules **shallow** (interface ≈ implementation)
- Pure functions extracted for testability, but bugs hide in callers (no **locality**)
- Tightly-coupled modules leak across seams
- Hard to test through current interface

Apply **deletion test** to suspects.

### 2. Present candidates

Numbered list. For each: **Files** / **Problem** / **Solution** (plain English) / **Benefits** (locality, leverage, test impact).

Use CONTEXT.md vocabulary for the domain, [LANGUAGE.md](LANGUAGE.md) vocabulary for architecture — "the Order intake module," not "FooBarHandler" or "Order service."

**ADR conflicts**: surface only if friction warrants revisiting (mark _"contradicts ADR-0007 — worth reopening because…"_). Don't list every refactor an ADR forbids.

Do NOT propose interfaces yet. Ask: "Which would you like to explore?"

### 3. Grilling loop

User picks a candidate → grill the design tree: constraints, dependencies, deepened module shape, what sits behind the seam, what tests survive.

Inline side effects:

- New concept not in CONTEXT.md → add lazily ([CONTEXT-FORMAT.md](../mp-grill-with-docs/CONTEXT-FORMAT.md))
- Sharpening fuzzy term → update `CONTEXT.md` right there
- User rejects with load-bearing reason → offer ADR _only if_ future explorers need it; skip ephemeral / self-evident ([ADR-FORMAT.md](../mp-grill-with-docs/ADR-FORMAT.md))
- Alternative interfaces → [INTERFACE-DESIGN.md](INTERFACE-DESIGN.md)

## Red Flags — STOP

- Refactoring without a test seam at the change site.
- Collapsing N callers into one module without measuring how they use it.
- Proposing concrete interfaces in step 2 instead of step 3.
- Drifting into "service / boundary / component" — glossary abandoned.

**All mean: stop. Return to prior step.**

## No Exceptions

- **No refactor without a seam.** No seam → building one IS the refactor; name it.
- **Two adapters before declaring "real seam"** — one is hypothetical.
- **Glossary terms only** — drift kills consistent language.
- **Letter = spirit** — "too small for the deletion test" is when shallow modules sneak in.
