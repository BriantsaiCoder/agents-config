# Review dispatch

Bundled-reference links resolve from this file. Repository/output paths refer to the target workspace; script paths retain their stated skill-root location.

## 3. Assemble and dispatch the full briefs

**REQUIRED BACKGROUND:** Read the entire [canonical reviewer-template](../../dev-workflow/references/reviewer-template.md) before composing prompts. It is the sole owner of the house five, input hygiene, finding/output contract, reviewer identity evidence, capability fallback and feedback handling. Follow [delegation](../../dev-workflow/references/delegation.md) for host capability, independence and scheduling; no fixed tool name, agent count or parallel-call choreography is prescribed here.

Build the briefs below from the live canonical text. **Paste the required text into each actual reviewer input**; a path, abbreviated summary, or claim that it was applied is insufficient. Keep config-author design notes out of reviewer prompts.

| Brief | Required material actually sent |
|---|---|
| Both axes | Original request and approved revisions; exact diff command and commits; immutable SHA plus snapshot path, or HEAD plus scanned package hash/manifest. Include the canonical input-hygiene rules, finding format/severity/confidence, actionable/no-word-or-count-cap/caller-side-triage contract, and reviewer identity/result fields. Include the full “Ablation ownership” section from the snapshot reference. Ask each reviewer to state the source identity reviewed. |
| Standards | Send the complete canonical marked reviewer prompt block, including all five house items and the full performance/correctness priorities, plus standards sources and the Fowler reference. Avoid copying a canonical clause twice within this brief. Require source rule and file/hunk evidence; distinguish hard violations from heuristic smells. |
| Spec | Send the common material above, plus the requirements source. Ask: “Report missing or partial requirements, unrequested behavior (scope creep), and requested behavior that is implemented incorrectly. Quote the spec/request evidence for every finding. Apply the common finding and output contract.” Keep the house-five and Fowler baselines in Standards only. |

Both reviews are read-only; independent reviewers may run in parallel when the host supports it. Missing independent-review capability follows the canonical probe/`UNAVAILABLE` procedure, never an unmarked self-review substitute.

**Complete:** the dispatched input for each applicable axis contains its full contract and matching source state; preserve that input as dispatch evidence. Do not dispatch Spec without a requirements source.
