---
name: code-review
description: Use when reviewing a branch, PR, work-in-progress changes, or changes since a commit, tag, branch, or merge-base against repository standards and the originating request/spec.
---

# Code Review

Review along two independent axes: **Standards** (repository rules and code defects) and **Spec** (the originating request and approved scope). Keep their inputs and outcomes separate.

## 1. Fix the scope and source state

Use the user's baseline or an already-established PR base. If neither identifies the comparison, ask for the fixed point; do not guess a material review scope. Inspect status before raw diffs. For dirty work, read and complete the [dirty review package gate](../dev-workflow/references/dirty-review-package.md) first; gitleaks findings block package assembly.

The [snapshot procedure](references/snapshot.md) owns clean snapshots and dirty-package identity; load it when preparing that input, reusing unchanged context. Resolve the baseline and HEAD to SHAs; retain the exact diff command, commit list and immutable snapshot/package identity. Invalid refs or a missing requested diff need resolution before review, not a fabricated PASS. A review request does not authorize a commit.

**Complete:** both axes can receive the same immutable, non-empty review input, including requested uncommitted work, with source identity and applicable scan evidence.

## 2. Gather the requirements and standards

Read the original request and every human-approved scope/spec revision. Find the originating spec in commit-linked issues, a supplied path, or matching repository documents. Tracker lookup follows [dev-workflow INT-5](../dev-workflow/SKILL.md): repository configuration first, then the shared fallback; missing local setup does not authorize running setup.

Ask where the spec is only when missing or conflicting requirements prevent meaningful assessment. A sufficient request/approved conversation is evidence; do not demand a separate document. If no requirements source exists, mark Spec `SKIPPED` with the reason and continue Standards.

Identify the repository's standards sources. [Fowler smells](references/fowler-smells.md) supplies Standards heuristics when that coverage is needed; repository standards override those heuristics, and tool-enforced findings are skipped.

**Complete:** each applicable axis has traceable source material; unknown requirements are clarified or explicitly excluded from a Spec verdict.

## 3. Assemble and dispatch the full briefs

[Review dispatch](references/review-dispatch.md) owns the two-axis brief matrix and dispatch evidence; the canonical reviewer-template owns the full reviewer contract, and delegation.md owns independence/capability handling. Load those contracts when composing a brief; context that is complete and unchanged can be reused. Each actual reviewer input still includes its required full contract, matching immutable source identity, and requirements/standards evidence. Both reviews remain read-only.

**Complete:** every applicable axis received the full required contract and same source snapshot/package; preserve actual dispatch evidence, and do not dispatch Spec without requirements.


## 4. Aggregate within each axis

Apply canonical feedback handling and caller-side triage independently. Present `## Standards` and `## Spec`; order each actionable finding by severity/confidence. Do not merge or rerank across axes, silently discard an actionable finding, or turn one axis's PASS into the other's PASS.

**Complete:** report the reviewed SHA/package identity, status and finding count per axis, worst issue within each axis, and any clarified scope, skipped Spec or unavailable capability. Review findings do not authorize patches or closeout side effects.
