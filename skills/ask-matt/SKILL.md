---
name: ask-matt
description: Ask which skill or flow fits your situation. A router over the skills in this repo.
disable-model-invocation: true
---

# Ask Matt

Choose a route for the user’s task; this user-only router does not grant implementation or invocation authorization.

| Situation | Route |
|---|---|
| Interview a repo idea; no repository | grill-with-docs; grill-me |
| A concrete question needs runnable evidence | prototype |
| Agreed implementation plan; multiple build slices | implement; to-spec → to-tickets when needed |
| Difficult bug or performance regression | diagnosing-bugs |
| Incoming issues or enabled external PRs | triage |
| Large, uncertain decision space spanning sessions | wayfinder |
| Explicit architecture survey | improve-codebase-architecture |
| Domain language; module shape | domain-modeling; codebase-design |
| Uncaptured context transfer; research; ongoing teaching | handoff; research; teach |
| Existing agent document editing | writing-for-agents |

For branch choices and flow examples, load [engineering-flows.md](references/engineering-flows.md). Phase/context transitions belong to [routing continuations](../dev-workflow/references/routing-continuations.md); tasks outside this subset return to dev-workflow S0. Setup runs only on an explicit request. Recommend the host’s explicit invocation command for user-only skills, then wait for that invocation.

Complete with a recommended route and the reason it fits the user’s actual task; do not add an itinerary of unnecessary phases.
