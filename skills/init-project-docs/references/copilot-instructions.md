# Copilot Instructions Generator

Use this reference when generating or refreshing `.github/copilot-instructions.md` (or an equivalent Copilot guidance file). Output must be grounded in repository evidence, not generic best practices.

## Required Workflow

1. **Locate existing Copilot/context files**: `AGENTS.md`, `.github/copilot-instructions.md`, `.github/instructions/**/*.instructions.md`, `.github/copilot/`, docs, ADRs, README, project-specific Claude/Codex files.
2. **Detect exact technologies and versions** from real files: project files, lockfiles, package manifests, config, CI, runtime pins.
3. **Inspect representative source and test files** before writing standards.
4. **Extract existing conventions** for architecture, naming, error handling, validation, logging, data access, UI patterns, testing.
5. **Label weak inferences and conflicts.** Don't hide inconsistent patterns — surface them as open questions.
6. **Generate concise instructions** that Copilot can follow while coding.
7. **Verify referenced paths** exist; never invent commands, versions, or frameworks.

## Output Structure

Use this structure unless the user requests another:

1. Priority and instruction precedence (what overrides what).
2. Technology versions and compatibility boundaries.
3. Architecture and module boundaries.
4. Code style and naming conventions.
5. Error handling, validation, logging, security patterns.
6. Data access and external integration patterns.
7. Frontend / UI patterns if applicable.
8. Testing standards and command references.
9. Examples to follow with real file references.
10. Open questions or known inconsistent patterns.

## Quality Rules

- Prefer actual file examples over abstract rules.
- Don't duplicate long docs — link and summarize the behavior Copilot must follow.
- Keep instructions stable and repo-specific; avoid broad language tutorials.
- Mention version limits when newer APIs would be incompatible.
- Include commands only when they exist in scripts, project files, docs, or CI.
- No secrets, private credentials, or sensitive operational details.

## Review Checklist

- Every rule has evidence or is clearly marked as an inference.
- All file paths and commands valid.
- Generated file short enough to read as active instructions (typically < 300 lines; long-form rationale belongs in `docs/`).
- Doesn't conflict with higher-priority project instructions.
- Guides behavior: what to do, what to avoid, how to verify.

## Difference From Full Host Instruction Files

- `init-project-docs` Phase 1 can generate full host instruction files: `CLAUDE.md` for Claude Code and `AGENTS.md` for Codex / shared agent context.
- This reference generates `.github/copilot-instructions.md` for GitHub Copilot.
- In Copilot-only output, this file can be full project instructions.
- In all-host output where `AGENTS.md` is also generated, keep this file as a thin Copilot adapter: point to `AGENTS.md` and `docs/`, then add only Copilot-specific behavior or `.github/instructions` routing.
- When generating multiple hosts, factor common content into `AGENTS.md` and shared docs (e.g., `docs/ARCHITECTURE.md`) to avoid duplicated or conflicting prompt context.
