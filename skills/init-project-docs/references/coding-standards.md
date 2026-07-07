# Coding Standards From File

Use this reference when extracting coding standards from an existing codebase. Output must describe what the code **actually does** — not generic best practices.

## When To Use This Reference

- User asks to "write coding standards", "extract conventions", "document our patterns" from real source files.
- Distinct from `copilot-instructions.md` (which is AI prompt context) and `codebase-blueprint.md` (which is architecture documentation): coding standards is a human-facing rulebook for future contributors.

## Required Workflow

1. **Identify the input files/folders** and the intended output file/format.
2. **Inspect representative files** across features, tests, configs, and shared utilities.
3. **Extract conventions with evidence**: naming, file organization, layering, error handling, validation, logging, testing, formatting, dependency patterns, framework idioms.
4. **Separate observed standards from recommendations.** Label inferred rules clearly when evidence is limited.
5. **Prefer concise rules with examples from actual files.** Do not include generic best practices unless they are present in the codebase or explicitly desired.
6. **Verify every referenced path exists** before publishing.

## Output Structure

Use this structure unless the user specifies another:

1. Scope and source files reviewed.
2. Project conventions.
3. Architecture and layering rules.
4. Naming and file organization.
5. Error handling, validation, logging, security patterns.
6. Testing conventions.
7. Formatting / tooling commands.
8. Examples to follow.
9. Open questions or weakly evidenced inferences.

## Review Checklist

- Each rule is backed by at least one real file reference or explicitly marked as inferred.
- The document avoids placeholders and invented technology versions.
- Rules are actionable for future code generation or review.
- Conflicting patterns are called out instead of hidden.
- The output does not duplicate README or architecture docs unless requested.

## File Reference Format

Use clickable local file references (`src/services/UserService.cs:42`) when the specific evidence matters. Line numbers anchor reviewers to the exact pattern.

## Quality Bar

- Every rule answers: "what to do, why, where it's already done."
- No "should consider" / "consider using" — extract the rule the codebase already enforces.
- Mark inferences explicitly (`// inferred from 3 of 5 files`).
- Surface inconsistencies as **open questions**, don't hide them.
