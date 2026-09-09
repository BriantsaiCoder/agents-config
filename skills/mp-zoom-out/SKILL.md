---
name: mp-zoom-out
description: "Map modules, callers, and change boundaries when unfamiliar code needs local orientation before editing. Fan-in evidence for one shared file uses deps-check."
---

Go up a layer of abstraction before touching this code.

Produce a map of the area:

- The modules involved and what each is responsible for.
- The callers into this area, and what this area calls out to.
- Where the boundaries are (what is safe to change locally vs. what is high fan-in).

Use the project's domain glossary vocabulary (`CONTEXT.md`, `docs/codebase/CONVENTIONS.md`). If the project has no glossary, say so and fall back to generic descriptive terms — do not invent domain names.
