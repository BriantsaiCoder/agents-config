---
name: mp-zoom-out
description: Use when entering an unfamiliar area of code and you need a system map before editing — how the code fits the bigger picture, which modules and callers surround it. Also available as `/mp-zoom-out`.
---

Go up a layer of abstraction before touching this code.

Produce a map of the area:

- The modules involved and what each is responsible for.
- The callers into this area, and what this area calls out to.
- Where the boundaries are (what is safe to change locally vs. what is high fan-in).

Use the project's domain glossary vocabulary (`CONTEXT.md`, `docs/codebase/CONVENTIONS.md`). If the project has no glossary, say so and fall back to generic descriptive terms — do not invent domain names.
