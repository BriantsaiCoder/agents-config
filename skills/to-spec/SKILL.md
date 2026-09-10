---
name: to-spec
description: "Synthesize an agreed conversation into a feature specification when the user requests a spec."
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user — just synthesize what you already know.

The tracker contract is owned by repo `docs/agents/issue-tracker.md`, with `~/.agents/docs/agents/issue-tracker.md` as fallback under shared `dev-workflow` INT-5. Read the applicable contract; invoke setup only when the user explicitly requests it.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Reuse already-confirmed public behavior seams. Confirm only a proposed seam that changes the public contract, architecture, or authorized scope; shared `dev-workflow` S2/INT-9 owns that decision.

3. Write the spec using the linked template. Publish it and apply the `ready-for-agent` label when tracker publication is already authorized; otherwise deliver the concrete draft and identify only the missing publication authorization. A spec request does not authorize implementation.

The [spec template](templates/spec.md) owns the required sections and prototype-snippet exception. Complete when the draft covers the agreed problem, behavior, testing decisions, and non-goals, with publication state stated accurately.
