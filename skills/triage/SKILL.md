---
name: triage
description: "Evaluate issues or enabled external PRs when a maintainer requests triage; tracker changes stay within the authorized scope."
disable-model-invocation: true
---

# Triage

Move issues on the project issue tracker through a small state machine of triage roles.

If this repo treats external pull requests as a request surface (see the issue-tracker config), triage covers them too: **a PR is an issue with attached code** — same roles, same states, same machine, with a few deltas marked "for a PR" below. Resolve a bare `#42` to an issue or PR per the tracker config.

Follow the selected repo/tracker contract's disclosure requirements for published comments/issues. Preserve user/team-specified disclosure text; this algorithm does not impose its own prefix.

## Reference docs

- [AGENT-BRIEF.md](AGENT-BRIEF.md) — how to write durable agent briefs
- [OUT-OF-SCOPE.md](OUT-OF-SCOPE.md) — how the `.out-of-scope/` knowledge base works

## Roles

Two **category** roles:

- `bug` — something is broken
- `enhancement` — new feature or improvement

Five **state** roles:

- `needs-triage` — maintainer needs to evaluate
- `needs-info` — waiting on reporter for more information
- `ready-for-agent` — fully specified, ready for an AFK agent
- `ready-for-human` — needs human implementation
- `wontfix` — will not be actioned

For a PR, the same states read against the attached code: `ready-for-agent` means a brief is attached and an agent should take the next step on the diff; `ready-for-human` means it's ready for a human to merge.

Every triaged issue should carry exactly one category role and one state role. If state roles conflict, identify the intended transition from existing instructions; ask only when that decision is missing. Pause mutation of that item while continuing authorized read-only analysis and independent items.

These are canonical role names — the actual label strings used in the issue tracker may differ. The mapping belongs to repo `docs/agents/triage-labels.md` and its tracker contract; use the shared fallback under `dev-workflow` INT-5 when absent. Setup runs only on an explicit user request.

State transitions: an unlabeled issue normally goes to `needs-triage` first; from there it moves to `needs-info`, `ready-for-agent`, `ready-for-human`, or `wontfix`. `needs-info` returns to `needs-triage` once the reporter replies. The maintainer can override at any time. Execute an explicit authorized transition; ask only when a conflicting state or missing authority leaves its intended outcome unresolved.

## Invocation

The maintainer invokes `/triage` and describes what they want in natural language. Interpret the request and act. Examples:

- "Show me anything that needs my attention"
- "Let's look at #42" (issue or PR)
- "Move #42 to ready-for-agent"
- "What's ready for agents to pick up?"

## Choose the scope

- Queue discovery → [queue-discovery.md](references/queue-discovery.md): eligible issues/external PRs, counts, and maintainer selection.
- A named issue/PR or explicit state change → [issue-triage.md](references/issue-triage.md): verify claims, brief, transition, and needs-info format.

Review/analysis alone authorizes no comment, close, label mutation, or domain-document write. Existing authorization for the specific outcome is reused; a missing item decision pauses only its dependent mutation.


## Completion

Every requested item has traceable evidence and the intended state/brief or a precise unresolved decision. Apply only authorized tracker actions and report what actually changed.


## Resuming a previous session

If prior triage notes exist on the issue or PR, read them, check whether the reporter has answered any outstanding questions, and present an updated picture before continuing. Don't re-ask resolved questions.
