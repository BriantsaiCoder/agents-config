# Skill standards

This is the automatically loadable house authority for skill audits. Third-party authoring skills are optional references, not background dependencies.

## Sources

| Source | Binding scope |
|---|---|
| [Agent Skills specification](https://agentskills.io/specification) | Portable format: `SKILL.md`, required `name` / `description`, name constraints, 1024-character description limit, relative references, progressive disclosure |
| Matt `writing-great-skills` | Guidance: model-vs-user invocation, trigger-rich descriptions, information hierarchy, checkable completion criteria, pruning |
| House policy | Vendored gate, word budgets, required-marker syntax for house cross-skill dependencies, mechanical checks before judgement |

## Audit rules

1. `name` must match its directory, use lowercase letters/numbers/hyphens, be 1–64 characters, and have no leading, trailing, or consecutive hyphen.
2. `description` must be non-empty, at most 1024 characters, and describe what the skill does and when it applies. For house model-invoked skills, prefer a trigger-focused `Use when...` sentence; do not impose that house wording on vendored payload.
3. Body headings are not prescribed. Check for executable steps, checkable completion criteria, relevant edge cases, and relative file references instead of requiring a fixed template.
4. House cross-skill dependencies use `REQUIRED SUB-SKILL` or `REQUIRED BACKGROUND`; a user-invoked skill cannot be an automatic dependency.
5. Vendored payload is reported, never rewritten to satisfy house style.

## Retired Superpowers-specific checks

Do not require gerund names, fixed Overview / When to Use / Quick Reference / Common Mistakes headings, rationalization tables, Red Flags, Iron Laws, “spirit vs letter” prose, or a fixed example count. Apply those shapes only when a skill’s observed failure calls for them.
