---
name: handoff
description: "Create a temporary handoff document when the user needs another agent or session to continue uncaptured work."
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to the temporary directory of the user's OS - not the current workspace.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

When this run was triggered interactively by the user, end your reply with a copy-pasteable start prompt for the next session: the document's absolute path, the focus in one line, and the skills to invoke first — nothing else. Everything the next agent needs beyond that is in the document. That block is for a human to copy; its shape is not a machine-parseable contract.
