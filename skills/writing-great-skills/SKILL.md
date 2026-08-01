---
name: writing-great-skills
description: Use when editing one existing Agent Skill's model/user invocation mode, description, hierarchy, completion criteria, or pruning, or when another skill routes an already-red single-target behavior rewrite here. Existing-skill invocation edits stay here; the host creator owns new-skill scaffolding, and the folder auditor owns directory audits.
---

A skill exists to make a stochastic agent follow a predictable process. Every instruction must earn that predictability.

**REQUIRED PRECONDITION:** Unreliable invocation needs a preserved RED trigger canary. A caller-provided `auditing-skill-folder` Step 2c RED satisfies this gate.

**REQUIRED SUB-SKILL:** When no caller provides that RED, invoke `diagnosing-bugs` first.

For a full behavioral authoring or pruning audit, record a verdict for every applicable section. For a scoped edit, cover only the named branch and its dependent rules. For a misbehavior rewrite, preserve the trigger RED canary and verify it turns GREEN. Report each applicable decision as `KEEP`, `CHANGE`, or `N/A` with evidence.

Definitions and failure modes live in [`GLOSSARY.md`](GLOSSARY.md). Load only the headings the current branch needs; a full pruning audit rules every failure mode in or out.

## Invocation

Choose one mode:

- **Model-invoked:** use when the agent or another skill must discover it. Keep a trigger-rich `description`, omit `disable-model-invocation`, and keep every host's implicit-invocation policy enabled.
- **User-invoked:** use for deliberate manual reach. Keep `description` as a short human summary, set `disable-model-invocation: true`, and disable every other host invocation key the folder carries, such as `allow_implicit_invocation: false` in `agents/openai.yaml`.

Several user-invoked skills that are hard to remember justify one user-invoked router.

## Description

A model-invoked description states the skill's identity and one real trigger per branch. Start with the words users actually use, remove synonymous triggers, and include a reach clause only when another skill needs it. Describe trigger conditions, not the procedure performed after invocation.

## Information hierarchy

Place content at the highest useful rung:

1. Ordered actions stay in `SKILL.md` as steps with checkable completion criteria. Criteria that sweep a set are exhaustive.
2. Rules every branch needs stay as in-skill reference.
3. Branch-specific definitions or examples move to a named sibling file behind a pointer that says when to load it.

Keep each concept's rule and caveats together. Split by invocation only for an independently discoverable trigger; split by sequence only when an observed rush survives a sharper completion criterion.

## Pruning

Keep each meaning in one authoritative place. Check every sentence for relevance, duplication, and no-op behavior; delete a failing sentence whole. Use a leading word only when a canary shows that it improves invocation or execution. State the target behavior positively.
