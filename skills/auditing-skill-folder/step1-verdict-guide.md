# Step 1 verdict guide — Trim vs Externalize vs Refactor

When `count-words.sh` flags a skill as OVER, use the per-row limit it reports; the next move depends on **why** the skill exceeds that limit.

## Decision

| Cause of overage | Verdict | How |
|---|---|---|
| Body has 100+ lines of API doc, syntax table, regex list, or other heavy reference | **Externalize** (Split) | Move content to `<topic>.md` sibling; SKILL.md keeps overview + cross-ref |
| Body bundles reusable scripts / tools inline | **Externalize** (Split) | Move to `scripts/` dir; SKILL.md links from Implementation section |
| Body repeats workflow already covered by another skill | **Refactor** | Replace with `**REQUIRED:** use <skill-name>` cross-reference |
| Body documents every CLI flag inline | **Refactor** | Replace with `Run --help for details` and let the tool be the source of truth |
| Body has verbose example or multiple examples of the same pattern | **Refactor** | Compress to one minimal example; delete redundancy |
| Body is just core principles + concepts, prose is genuinely dense | **Trim** | Tighten wording; remove filler; no structural change needed |

## Inline-keep rule

Principles, concepts, and code patterns < 50 lines belong in SKILL.md regardless of word pressure. Do not externalize these to game the count.

## Iron Law

**Never use `Trim` as the default verdict.** Identify the cause first. `Trim` only applies when no Externalize / Refactor cause fits — otherwise you lose information (Trim) instead of relocating it (Externalize) or deduplicating it (Refactor).
