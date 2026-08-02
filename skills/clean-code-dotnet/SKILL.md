---
name: clean-code-dotnet
description: Use when a C#/.NET change is explicitly about readability, naming, responsibility boundaries, code smells, or SOLID refactoring. Routine framework, data-access, logging, UI, or test guidance belongs to its stack skill; fixed formatting and style belong to repository analyzers and .editorconfig.
---

# Clean Code .NET

Apply judgment-heavy Clean Code review to C#/.NET without changing observable behavior unless the user authorizes that change.

## Procedure

1. Read the target code, callers, and tests. State the behavior that must remain stable.
2. Identify concrete readability or responsibility problems using the review lens below. Tie every finding to a symbol or line; do not report personal style as a defect.
3. Make the smallest cohesive refactor. Prefer deletion, clearer names, guard clauses, and explicit boundaries over new abstractions.
4. Run the narrowest relevant tests, then the repository's required verification.

Complete when every accepted finding has a concrete location and rationale, observable behavior is preserved, and verification passes.

## Review lens

- **Intent:** Names express domain meaning and avoid redundant context, encodings, or double negatives.
- **Cohesion:** A method or type has one reason to change; flag parameters and unrelated dependencies are evidence to inspect, not automatic violations.
- **Flow:** Guard clauses expose the happy path; nesting and conditionals remain as complex as the domain requires, but no more.
- **Effects:** Mutation, I/O, time, randomness, and global state are visible at the boundary rather than hidden in helpers.
- **Exceptions:** Handle or propagate failures deliberately. Preserve the original stack with `throw;`; when wrapping, keep the original exception as `InnerException`.
- **Comments:** Explain non-obvious constraints and trade-offs. Names and structure carry information that merely repeats the code.
- **Metrics:** Dependency count, method size, complexity, and maintainability index are investigation signals. Repository policy and measured risk decide thresholds.

## Ownership boundaries

- Modern .NET/ASP.NET Core and async behavior → [dotnet-core-best-practices](../dotnet-core-best-practices/SKILL.md).
- .NET Framework compatibility → [dotnet-framework-best-practices](../dotnet-framework-best-practices/SKILL.md).
- WinForms threading and UI lifecycle → [dotnet-winforms-best-practices](../dotnet-winforms-best-practices/SKILL.md).
- Test design and runner behavior → [dotnet-testing-best-practices](../dotnet-testing-best-practices/SKILL.md).
- Module architecture or public seam design → [codebase-design](../codebase-design/SKILL.md).
- Formatting and naming enforcement → repository `.editorconfig`, Roslyn analyzers, and CI.

For a SOLID-specific explanation or example, read [SOLID principles](references/solid-principles.md).
