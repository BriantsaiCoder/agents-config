---
name: grilling
description: Use when the user asks to stress-test or clarify an under-specified plan, decision, or idea through one-at-a-time questions, or uses any 'grill' trigger phrase.
---

Interview me relentlessly about every aspect of this until we reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one.

For each decision question, provide 2–3 mutually exclusive options, put your recommended option first, and keep the choices compact enough to answer with a number or "accept recommendation."

Prefix every question with a progress header of the form **Question N of ~M — \\<topic\\>**, where M is your running estimate of the total number of questions. Re-estimate M as you go; it's fine for it to drift as new branches of the design tree surface.

By default, ask decision questions one at a time, wait for feedback before continuing, then summarize every decision and wait for explicit confirmation before acting.

If the user explicitly authorizes you to answer every decision you can and ask only when blocked, enter delegated-decision mode: process decisions in dependency order, adopt your recommended option without pausing, and record each adopted decision. When the calling workflow requires live HITL feedback, keep the default interactive mode unless the user explicitly overrides that requirement.

In delegated-decision mode, before asking, explore relevant available facts in the environment (filesystem, tools, etc.). Ask only when no defensible recommendation remains because a material fact or user-only constraint is unavailable, the choice depends on a user-only preference or authority, or your recommendation remains low-confidence and a wrong choice would materially matter. Risk alone does not make a decision unanswerable; it changes whether acting requires authorization. Keep the existing scope unless the user authorizes an expansion.

Before acting in delegated-decision mode, summarize every decision. Delegated decision-making is not implementation authorization. Proceed only when the action is already authorized and permitted by higher-priority rules. Ask for authorization only when authorization is the sole blocker; otherwise report the binding constraint.
