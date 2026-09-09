---
name: implement
description: "Implement an authorized spec or ticket, verify its behavior, and complete the agreed review and delivery scope."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Use [dev-workflow](../dev-workflow/SKILL.md) S4 and [evidence-integrity](../dev-workflow/references/evidence-integrity.md) to select checks for the changed behavior. Reuse the repo's test stack, complete required checks, and expand or repeat only for new changes, failures, unresolved concerns, or an explicit gate.

Once done, use /code-review to review the work.

Complete S4/S5 and the authorized delivery scope under `dev-workflow` S2/S6. Checkpoint/final commits require existing authorization; otherwise deliver reviewable local changes.
