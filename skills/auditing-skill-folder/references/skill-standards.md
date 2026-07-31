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
5. Vendored payload is reported, never rewritten to satisfy house style. Reporting is the default landing, not a gag: the assessment itself is never gated by the flag, and an edit judged worth its recurring cost lands as a recorded override (`vendored-forks.md`).

## Step 5 type taxonomy

Step 5 asks which of three types a skill is. The types were previously named but never defined anywhere in this folder or in the guidance it cites, which left the `Split` verdict firing on an unstated judgement. One discriminating question each:

| Type | Discriminating question | Example |
|---|---|---|
| **Technique** | Does it prescribe an **order** the agent must follow, where doing step 3 before step 2 is wrong? | `tdd` — red, green, refactor is the content |
| **Pattern** | Does it supply **rules applied to work the agent is already doing**, in no particular order? | `dapper-best-practices` — every rule stands alone |
| **Reference** | Is it consulted to **answer a question**, producing no change by itself? | `microsoft-docs` — a lookup surface |

Mixed-type is the common defect, not an absent type. It is checkable rather than felt: **a skill is mixed-type when it carries a mandatory ordered procedure AND a flat rule-set that no step of that procedure consumes.** Rules a step actually reaches for are that step's reference and do not make the skill mixed. If neither half is mandatory, there is no split to propose.

## Retired Superpowers-specific checks

Do not require gerund names, fixed Overview / When to Use / Quick Reference / Common Mistakes headings, rationalization tables, Red Flags, Iron Laws, “spirit vs letter” prose, or a fixed example count. Apply those shapes only when a skill’s observed failure calls for them.
