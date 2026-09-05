# Shared-skill results

Implementation is staged in an isolated worktree; this document does not claim live activation, PR approval or a general model benchmark.

## Controlled two-model comparison

24 completed Codex CLI 0.153.3 runs: six scenario groups × old/new × GPT-5.6 Sol / GPT-6 Astra, fixed high effort. Exact prompts, source entrypoint hashes, output/trace hashes, tokens and elapsed times are in model-evidence.json. Each run uses a fresh fixture; all original local/plugin skill entries are disabled for that invocation and the fixture contains the intended skill copies. Tool command traces contain no reads of the live user skill paths; the fixture skill copies remained unchanged.

| Group | Result in both models | Limit |
|---|---|---|
| A (AD2) | Both versions complete the approved None-handling fix, retaining trim behavior and regression evidence. | No behavioral improvement claimed; removal of the extra sdd router did not regress this case. |
| D | Both versions complete the same fix with five callers and an existing seam. | Kernel already overrode the old leaf rules in these runs; this establishes consistency, not a universal latency gain. |
| B | Old versions stop for an additional confirmation; new versions deliver the requested rewrite, preserving date, command, counts and API path. | One direct-rewrite input per model; not a broad writing-quality benchmark. |
| E | Both versions identify the deliberately introduced lowercase regression in Standards and Spec, cite source and preserve the reviewed files. | Fixture forbids delegation; these are behavior canaries, not independent S5 approval. |
| F | Both versions report static/unverified test-gap candidates, retain whitespace/mixed-input gaps, and select existing xUnit v2/.NET Framework conventions without adding dependencies. | No empirical mutation or .NET execution was requested or performed. |
| B protection | Both versions preserve explicit Check-first and Annotation; SF-28 technical evidence, synthetic SF-29 redaction and SNF-16 functional structure survive. | Five independent inputs batched in one turn per arm/model; not the complete SF/SNF corpus. |

For each of the eight A/D output fixtures, the parent independently ran 36 API/caller cases (`None`, trim, mixed case, whitespace, interior spaces and empty strings): all passed. Both models' tool traces record RED before the production fix and GREEN afterward. All E/F fixtures retain their production/test/package files. B protection outputs do not contain the synthetic sensitive value and retain the protected commands/results/URL.

The first A experiment used a main-branch fixture, where the inner sandbox could not create a task branch. Those four runs are retained under /private/tmp/skills-eval/AD and excluded from the comparison. The corrected AD2 fixtures pre-create codex/canary; no sandbox restriction was relaxed. The additional Codex connectivity run is also excluded.

These controls verify selected CLI source loading and behavior. They do not prove Desktop hook execution, implicit routing for all prompts, or fresh Claude/Copilot behavior. Existing cross-host structural checks are separate evidence. Invocation-only settings do not change model defaults; Codex automatically added trust entries for temporary fixture projects, which are removed during cleanup.

## Preservation and rollback

- sdd is archived byte-for-byte under attic/sdd; active callers and the trigger corpus now use dev-workflow. Optional persisted SDD artifacts remain documented, including completed-task and non-overwrite archive guards.
- Authorization stays in dev-workflow S2; RED/valuable seams/UNKNOWN/dynamic callers and current-head release/review gates remain.
- code-review uses the complete canonical reviewer-template in its actual dispatch, with snapshot and Fowler material in required references. Contract tests follow that reference edge instead of requiring duplicated inline text.
- Test-gap mutation mechanics, full-suite certification, finite timeouts/process-tree cleanup, inverse edits, hashes and static/empirical distinctions remain.
- Upstream pins and licenses remain. tdd is now explicitly recorded as a fork; the current Matt split is 12 unmodified / 10 recorded forks. Payload and tree fingerprint conventions are preserved.
- After a squash merge, reverting the whole PR is the default atomic rollback. A selective rollback must restore the affected skill, callers, contract tests and associated provenance/lock entries together.

Changed active entrypoint bytes total 84,658 → 46,872 (44.6% reduction). This includes one retired entrypoint and excludes referenced files; it is not a claim that the always-loaded prompt or every task uses 44.6% fewer tokens.

## Failure model and catching layer

| Failure | Catching layer |
|---|---|
| Caller points at archived sdd | active routing/corpus checks + relative-reference scan |
| Confirmation disappears for protected work | unchanged kernel/authorization guards + explicit Check-first canary |
| Old/new skills silently mix | per-invocation suppression, prompt-input observer, skill hashes and tool traces |
| Review loses a category or output contract | canonical template guards + dispatch-edge tests + independent S5 review |
| Static guesses become empirical results, mutations escape isolation | test-gap contract guards + F read-only canary |
| Upstream refresh silently restores old behavior | recorded forks, exact payload/tree hashes and re-merge procedure |

Replay repository verification from this checkout: `bash bin/ci-local`. Baseline output: /private/tmp/skills-baseline-ci.log; final output and status are recorded in the delivery ledger. Hook installation is not executed by the default local runner because it writes .git/hooks.
