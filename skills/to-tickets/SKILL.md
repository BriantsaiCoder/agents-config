---
name: to-tickets
description: "Split an agreed plan or specification into dependency-linked implementation tickets when requested; publish to the authorized tracker."
disable-model-invocation: true
---

# To Tickets

Break a plan, spec, or conversation into a set of **tickets** — tracer-bullet vertical slices, each declaring the tickets that **block** it.

The tracker contract is owned by repo `docs/agents/issue-tracker.md`, with `~/.agents/docs/agents/issue-tracker.md` as fallback under shared `dev-workflow` INT-5. Read the applicable contract; invoke setup only when the user explicitly requests it.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body and comments.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests) — vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

</vertical-slice-rules>

Give each ticket its **blocking edges** — the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

A mechanical refactor whose callers cannot migrate in independently green slices uses [wide-refactors.md](references/wide-refactors.md); ordinary work stays in vertical slices.


### 4. Resolve material breakdown decisions

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work

Reuse agreed granularity and dependencies. If a missing decision materially changes the deliverable or blocking edges, present the concrete alternatives and resolve that decision; otherwise use the smallest complete slices and state the assumption. A user-requested check-first gate still waits for selection. Publishing requires the tracker/action scope to be authorized.

### 5. Publish within authorization

Use [tracker-publication.md](references/tracker-publication.md) for local-file/native-issue formats, blocking edges, and templates. Publish only when that tracker action is covered by existing authorization; otherwise deliver the concrete drafts. Complete when every requested slice has an observable outcome, acceptance criteria, and valid blocking edges, and its actual publication state is reported.
