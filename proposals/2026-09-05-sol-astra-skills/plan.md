# Sol / Astra skill optimization

Authorization: user「依照建議開始實作」(2026-09-05), accepting the preceding stages 1–3 plan. Scope: shared A/B/D/E/F, Ponytail C only at its maintainable injection source, conditional Codex exposure cleanup only when individual suppression and runtime canaries pass. Stage 4 recommendations remain deferred.

Baseline: agents-config `017c0017b2e305f45b019b184ae7aaf4bec75617`; dotcodex `fa78f8937c3168d01ff9a4f99c90a38d95e020a7`. Both live main trees clean at start. Worktree: `/private/tmp/global-skills-impl-20260905/codex/skills-sol-astra`; live shared path remains unchanged until verification/cutover gates pass.

Risk: High (global multi-host workflow policy). Delivery: isolated implementation and verification, then Ready PR / current-head CI and independent review / squash merge under dev-workflow INT-10 when applicable gates pass. No irreversible removal. No expanded plugin uninstall or changes to credentials/model defaults.

| Group | Change | Rules retained / canonical owner | Validation |
|---|---|---|---|
| A | Fold sdd tiny-task acceptance into workflow; archive sdd and migrate active callers | dev-workflow authorization, acceptance, risk and delivery; optional persisted artifacts | caller inventory, routing checks, small authorized task and protected task canaries |
| B | speak-human-tw modes; externalize repetition/history | explicit check-first requests, factual/numeric/technical preservation and secret handling | direct rewrite vs check-only/explicit checklist scenarios |
| C | Ponytail injected instruction conflict | reuse ladder, complete requested task, existing verification conventions | real injection source and fresh-session probe; retain original if unavailable |
| D | tdd/deps approval duplication | workflow INT-2/3/8/9; caller inventory, UNKNOWN fail-closed | existing seam and high-fan-in authorized change / unknown evidence scenarios |
| E | code-review references and one reviewer contract owner | immutable snapshot, dirty package, independent Standards/Spec, complete findings, own-copy ablations | full content/refs audit, review scenarios, independent review |
| F | test-gap and .NET testing concise entrypoints | static/empirical distinction, restoration, vacuity, versions | static report and empirical boundary / version cases |
| Exposure | rescue helpers, duplicate Chrome/React, Ponytail helpers conditional | supported per-skill control; retained runtime/hooks and unique references | actual prompt-input list + relevant capability canary; unavailable means retain |

Verification is layered: (1) repository contracts/links/provenance and baseline→candidate CI; (2) fixed-prompt model A/B, same model/effort/tools and one group changed at a time; (3) host exposure/cutover. Static checks or model self-reports do not prove invocation or real output quality. Record unavailable probes honestly; do not activate a conditional change on assumed evidence.

Rollback: before merge, discard candidate branch without changing live skills; after merge, revert each group's commit(s), restoring callers and callee together. sdd remains versioned under attic. Vendored fork records include exact current tree hash and remerge instructions. Plugin caches are never edited. Restart fresh sessions after any confirmed cutover; already-loaded contexts retain prior instructions.

Official references verified on 2026-09-05:
- https://developers.openai.com/api/docs/guides/latest-model?model=gpt-5.6
- https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra
- https://learn.chatgpt.com/docs/build-skills

The model guides support lean, consistent instructions, preserving domain/safety/success criteria, and comparing one change at a time. These are review principles, not evidence that any specific deletion already passed both models.
