---
name: writing-for-agents
description: "Revise an existing Agent Skill, AGENTS.md, CLAUDE.md, or agent-facing document once its canonical owner is known; directory audits use auditing-skill-folder."
---

# Writing for agents

Write documents that make a stochastic agent follow a predictable process. This skill improves content inside the owner already selected by the host workflow; it does not decide whether policy belongs in a thin host kernel, shared workflow, skill, or repo document.

Existing-skill invocation edits stay here; the host creator owns new-skill scaffolding; the folder auditor owns directory audits.

## Choose the branch

- **Agent Skill:** load [SKILL-MECHANICS.md](SKILL-MECHANICS.md) for invocation and packaging.
- **AGENTS.md, CLAUDE.md, or pointed-at docs:** first identify the canonical owner and every inbound pointer. Preserve higher-priority workflow and authorization rules; edit the owning document instead of copying its meaning into callers. Before writing a host policy file, apply shared `dev-workflow` S2 and the host's [T0-8] gate.

**REQUIRED PRECONDITION:** Unreliable invocation needs a preserved RED trigger canary; an `auditing-skill-folder` Step 2c RED satisfies this gate.

**REQUIRED SUB-SKILL:** For a misbehavior rewrite with no caller-supplied RED, invoke `diagnosing-bugs` first.

For a full audit, record a verdict for every applicable section. For a scoped edit, cover only the named branch and dependent rules. For a misbehavior rewrite, preserve the trigger RED canary and verify it turns GREEN. Report decisions as `KEEP`, `CHANGE`, or `N/A` with evidence.

Every bold term below names a [GLOSSARY.md](GLOSSARY.md) heading. Load only the branch-specific definitions needed by the current task.

## Context pointers and load

A **Context Pointer** names out-of-context material and says when to load it. Front-load its **Leading Word**, give one trigger per real **Branch**, and sharpen a weak pointer before inlining its target.

Spend **Context Load** only on rules needed every run. Spend **Cognitive Load** where human judgement or explicit invocation matters. Keep host kernels thin when their workflow already owns detailed choreography.

## Information hierarchy

Put ordered **Steps** and their checkable **Completion Criterion** in the main file. Criteria that sweep a set are exhaustive. Keep common **Reference** beside them; move branch-only reference behind a context pointer. Preserve **Co-location** by keeping each concept, rule, and caveat together.

## Pruning

Keep each meaning in one **Single Source of Truth**. Remove **Duplication**, stale **Sediment**, irrelevant branches, and instructions that are a model **No-Op**. State target behavior positively. Look for repeated phrasing a **Leading Word** can collapse; keep it only when a canary shows improved invocation or execution.

The live environment is a source of truth for discoverable commands, paths, config, and layout; prose that repeats those facts is only a cache. Inspect the environment before refreshing such prose. A lockfile or recorded pin retains precedence for pinned provenance: current files explain behavior, not which upstream revision was approved.
