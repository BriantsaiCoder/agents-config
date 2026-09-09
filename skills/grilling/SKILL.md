---
name: grilling
description: Use when the user explicitly asks to be interviewed, grilled, or stress-tested about an under-specified plan, decision, or idea before implementation. The explicit request for the interview is what triggers this; a vague or under-specified request on its own routes to plan mode instead. Not when grilling itself is the topic of discussion.
---

Interview me relentlessly about every aspect of this until we reach a shared understanding. Map decisions as a design tree; the frontier is every decision whose prerequisites are already settled and can be answered without guessing.

Before putting a question on the frontier, inspect relevant context and available facts in the environment. Delegate only independently scoped fact-finding when the higher-priority workflow permits it; an unsettled fact delays only decisions that depend on it.

For each decision question, provide 2–3 mutually exclusive options, put your recommended option first, and keep the choices compact enough to answer with a number or "accept recommendation."

Prefix every question with a progress header of the form **Question N of ~M — \\<topic\\>**, where M is your running estimate of the total number of questions. Re-estimate M as you go; it's fine for it to drift as new branches of the design tree surface.

By default, work interactively one frontier decision at a time. Ask one eligible question, wait for feedback, then recompute the frontier; a question that depends on another unresolved decision belongs to a later turn. Keep dependent decisions recorded off the frontier until their prerequisites settle. When the frontier is empty, summarize every decision. Proceed when existing implementation authorization covers those decisions and the scope/risk is unchanged; otherwise wait for the missing action authorization. An explicit interview-only or plan-first request still stops before implementation.

If the user explicitly authorizes you to answer every decision you can and ask only when blocked, enter delegated-decision mode: process decisions in dependency order, adopt your recommended option without pausing, and record each adopted decision. When the calling workflow requires live HITL feedback, keep the default interactive mode unless the user explicitly overrides that requirement.

In delegated-decision mode, before asking, explore relevant available facts in the environment (filesystem, tools, etc.). Ask only when no defensible recommendation remains because a material fact or user-only constraint is unavailable, the choice depends on a user-only preference or authority, or your recommendation remains low-confidence and a wrong choice would materially matter. Risk alone does not make a decision unanswerable; it changes whether acting requires authorization. Keep the existing scope unless the user authorizes an expansion.

Before acting in delegated-decision mode, summarize every decision. Delegated decision-making is not implementation authorization. Proceed only when the action is already authorized and permitted by higher-priority rules. Ask for authorization only when authorization is the sole blocker; otherwise report the binding constraint.

The interview is complete only when the frontier is empty: every branch has been visited and nothing left silently assumed.
