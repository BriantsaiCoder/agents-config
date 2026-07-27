# Step 7 (optional) — Style & structural spot-check

Checks Steps 1–6 do not catch. Run after the six-step protocol to surface lower-priority defects. Findings are tag-and-fix, not restart-gating; never promote Style → Delete (deletion belongs to Step 6).

Read [references/skill-standards.md](references/skill-standards.md) before applying these checks.

## Checks

| Check | Source | Flag |
|---|---|---|
| Name matches directory; 1–64 lowercase letters/numbers/hyphens; no edge/double hyphen | Agent Skills spec | `Style:fix-naming` |
| Required `name` / `description`; description non-empty and ≤1024 characters | Agent Skills spec | `Style:fix-frontmatter` |
| Description says what + when with useful routing keywords; house model-invoked skills prefer trigger-focused `Use when...` wording | Agent Skills spec + Matt guidance + house policy | `Style:fix-description` |
| Relative file references resolve; house cross-skill dependencies use explicit required markers and never auto-depend on user-invoked skills | Agent Skills spec + house policy | `Style:fix-cross-reference` |
| Steps have checkable completion criteria; branch-only reference is progressively disclosed; stale/no-op content is absent | Matt guidance | `Style:fix-information-hierarchy` |

Fixed section templates, gerund names, rationalization tables, Red Flags, Iron Laws, flowchart rules, and example-count rules were Superpowers-specific. They are not generic audit failures; use them only when an observed behavior requires that shape.

## Verdict augmentation

Append to existing verdict block per skill:

- `Style:fix-naming`
- `Style:fix-frontmatter`
- `Style:fix-description`
- `Style:fix-cross-reference`
- `Style:fix-information-hierarchy`

Multiple tags allowed. Style findings stack with the Step 1–6 verdict (Keep / Trim / Move / Hook / Split / Delete) but never override it.
