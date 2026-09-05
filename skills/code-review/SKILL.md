---
name: code-review
description: Use when reviewing a branch, PR, work-in-progress changes, or changes since a commit, tag, branch, or merge-base against repository standards and the originating request/spec.
---

# Code Review

Review along two independent axes: **Standards** (repository rules and code defects) and **Spec** (the originating request and approved scope). Keep their inputs and outcomes separate.

## 1. Fix the scope and source state

Use the user's baseline or an already-established PR base. If neither identifies the comparison, ask for the fixed point; do not guess a material review scope. Inspect status before raw diffs. For dirty work, read and complete the [dirty review package gate](../dev-workflow/references/dirty-review-package.md) first; gitleaks findings block package assembly.

Read [snapshot procedure](references/snapshot.md) before preparing either a clean snapshot or dirty package. Resolve the baseline and HEAD to SHAs; retain the exact diff command, commit list and immutable snapshot/package identity. Invalid refs or a missing requested diff need resolution before review, not a fabricated PASS. A review request does not authorize a commit.

**Complete:** both axes can receive the same immutable, non-empty review input, including requested uncommitted work, with source identity and applicable scan evidence.

## 2. Gather the requirements and standards

Read the original request and every human-approved scope/spec revision. Find the originating spec in commit-linked issues, a supplied path, or matching repository documents. Tracker lookup follows [dev-workflow INT-5](../dev-workflow/SKILL.md): repository configuration first, then the shared fallback; missing local setup does not authorize running setup.

Ask where the spec is only when missing or conflicting requirements prevent meaningful assessment. A sufficient request/approved conversation is evidence; do not demand a separate document. If no requirements source exists, mark Spec `SKIPPED` with the reason and continue Standards.

Identify the repository's standards sources. Read [Fowler smells](references/fowler-smells.md) for the Standards coverage and rationale; repository standards override those heuristics, and tool-enforced findings are skipped.

**Complete:** each applicable axis has traceable source material; unknown requirements are clarified or explicitly excluded from a Spec verdict.

## 3. Assemble and dispatch the full briefs

**REQUIRED BACKGROUND:** Read the entire [canonical reviewer-template](../dev-workflow/references/reviewer-template.md) before composing prompts. It is the sole owner of the house five, input hygiene, finding/output contract, reviewer identity evidence, capability fallback and feedback handling. Follow [delegation](../dev-workflow/references/delegation.md) for host capability, independence and scheduling; no fixed tool name, agent count or parallel-call choreography is prescribed here.

Build the briefs below from the live canonical text. **Paste the required text into each actual reviewer input**; a path, abbreviated summary, or claim that it was applied is insufficient. Keep config-author design notes out of reviewer prompts.

| Brief | Required material actually sent |
|---|---|
| Both axes | Original request and approved revisions; exact diff command and commits; immutable SHA plus snapshot path, or HEAD plus scanned package hash/manifest. Include the canonical input-hygiene rules, finding format/severity/confidence, all-findings/no-word-or-count-cap/caller-side-filtering contract, and reviewer identity/result fields. Include the full “Ablation ownership” section from the snapshot reference. Ask each reviewer to state the source identity reviewed. |
| Standards | Send the complete canonical marked reviewer prompt block, including all five house items and the full performance/correctness priorities, plus standards sources and the Fowler reference. Avoid copying a canonical clause twice within this brief. Require source rule and file/hunk evidence; distinguish hard violations from heuristic smells. |
| Spec | Send the common material above, plus the requirements source. Ask: “Report missing or partial requirements, unrequested behavior (scope creep), and requested behavior that is implemented incorrectly. Quote the spec/request evidence for every finding. Apply the common finding and output contract.” Keep the house-five and Fowler baselines in Standards only. |

Both reviews are read-only; independent reviewers may run in parallel when the host supports it. Missing independent-review capability follows the canonical probe/`UNAVAILABLE` procedure, never an unmarked self-review substitute.

**Complete:** the dispatched input for each applicable axis contains its full contract and matching source state; preserve that input as dispatch evidence. Do not dispatch Spec without a requirements source.

## 4. Aggregate within each axis

Apply canonical feedback handling and caller-side triage independently. Present `## Standards` and `## Spec`; order each by severity/confidence and explain each dropped or folded finding within its own axis. Do not merge or rerank across axes, silently discard findings, or turn one axis's PASS into the other's PASS.

**Complete:** report the reviewed SHA/package identity, status and finding count per axis, worst issue within each axis, and any clarified scope, skipped Spec or unavailable capability. Review findings do not authorize patches or closeout side effects.
