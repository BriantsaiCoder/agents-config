---
name: auditing-skill-folder
description: Use when auditing a skill folder (~/.agents/skills/, ~/.claude/skills/) for keep/trim/delete/migrate decisions. Apply when a prior audit kept everything (suspicious uniform-keep), when only "built-in knowledge sufficient?" was used as criterion, or when skill trigger rate feels low.
---

# Auditing a Skill Folder

## Overview

**Core principle:** Structural checks first, content relevance last. Jumping to "do I still need this" produces all-keep or vibes-delete results that miss real defects.

**Not for:** one skill rather than a folder. Route single-skill work through [`../dev-workflow/SKILL.md`](../dev-workflow/SKILL.md), the canonical routing authority.

## Step 0 — Vendored gate (run FIRST; it decides which verdicts are legal)

`scripts/check-vendored.sh <folder>` → `VND` / `VND*` (fork recorded in `vendored-forks.md`) / `vnd?` / `ERR` / `-`. Steps 1–2 repeat the flag as a column.

**Vendored skills take no IN-PLACE structural edit** — no Trim, no Split, no rewriting their files. Removing or replacing the whole skill stays legal.

**The flag gates execution, not assessment.** Score every skill on merit and record each defect at the severity it earns; a row left unscored because of its flag is a skipped step.

**The rule is a default with a recorded override, not an absolute.** An assessment concluding the edit is worth its recurring cost lands as a *proposed override* against `vendored-forks.md` — the silent fork is forbidden, not the considered one.

**A flag you cannot explain from the skill's own files is normal.** Detection is a union of five signals; `vendored-skills.lock` is checked first, and its recorded source may be this repo.

Detection detail, the override procedure, and why each of the three rules above needs stating: `step0-vendored-gate.md`.

## Six-Step Protocol

Run in order after Step 0. Steps 1–2 use scripts, 2b is a semantic cross-row comparison, 3–5 read, and 6 is the call you wanted to start with — defer it. Every rung except 2b scores one skill in isolation; 2b is the only one that compares skills to each other.

| # | Step | Tool | Output |
|---|---|---|---|
| 1 | Token cost | `scripts/count-words.sh <folder>` | Effective count over its row's limit; over → `step1-verdict-guide.md` (Trim vs Externalize vs Refactor) |
| 2 | Description trap | `scripts/lint-descriptions.sh <folder>` | Descriptions summarizing workflow vs. trigger-only |
| 2b | Trigger collision | Same table, read **across** rows | Two model-invoked descriptions claiming one trigger space with no disambiguator = Collision. Invisible to every per-skill rung, and a cause of "which skill fires" being nondeterministic |
| 2c | Trigger accuracy — OPT-IN, spends rate limit | `scripts/eval-triggers.sh --runner claude` | Did it actually fire? Names the winner when skills contest one prompt, making 2b observable rather than argued. Detail: `step2c-trigger-eval.md` |
| 3 | Stance bleed | Read | Pure stance ("use Serilog", "no barrels") → propose CLAUDE.md |
| 4 | Mechanical-only | Read | Enforceable by lint/hook/regex → propose hook |
| 5 | Type clarity | Read | Technique / Pattern / Reference (defined in `references/skill-standards.md`); mixed-type → propose split |
| 6 | Built-in coverage | Judgement + Context7 | Only now: training-data + Context7 covers it AND no user stance AND no workflow discipline → candidate delete |

## Red Flags / Rationalizations — STOP and Restart from Step 1

| Trigger | Reality |
|---|---|
| "Quick 5-min pass, skip scripts" | Scripts run in <2 sec. Refusing them IS the bias. |
| "Last audit kept all, trust it" | Last audit may have skipped 1–5 too — re-verify, don't recurse |
| "Sort by line count instead of `wc -w`" | Wrong proxy, use the script |
| "User stance obvious, skill stays" | Step 3 skipped; stance often belongs in CLAUDE.md, not skill |
| "Mechanical part is short, leave inline" | Step 4 skipped; hooks fire 100%, skills ~50% — mechanical → hook |
| "Type is obviously Technique" | Step 5 skipped; mixed-type is the common defect, not absent type |
| "Built-in coverage is what matters at the end" | Step 6 of 6, not step 1 of 1 |
| "Stance and operation inseparable here" | True for some — document the call, don't skip step 3 wholesale |
| "Bloated AND third-party, so trim hard" | Backwards — vendored makes the trim need an override, not makes it overdue |
| "It's vendored, so scoring it is pointless" | The flag gates execution, not assessment. Unscored = skipped step = restart |
| "Vendored, so I'll log it as low severity" | Severity comes from the defect, never from the flag. Landing cost is recorded separately |
| "Each description reads fine on its own" | Step 2b skipped. Collisions are invisible per-skill — compare descriptions to each other, not just to the rules |
| "Step 2 says trigger-led, so it fires" | Step 2 is a regex proxy for firing. Run 2c, or record that you did not |
| "2c came back green, ship it" | Read `err=` and `TRUNCATED`; `--runner mock` is canned data, never an audit number |
| "I'll eyeball which are vendored" | Two hand-scans missed 2 (`LICENSE.md` ≠ `LICENSE`). Run Step 0. |

## Step 7 (optional) — Style anti-patterns

**OPTIONAL REFERENCE:** see `step7-style-checks.md`. Tag-only, not restart-gating.

## Iron Law

**Every audit produces a written report scoring each skill against every step**, ending in a verdict block: Keep / Trim / Move-to-CLAUDE.md / Convert-to-hook / Split / Delete / Collision. "Looked at it, looks fine" is not a verdict. If you cannot fill in a step result, you did not run that step. Skipping any of steps 1–5 means restart. Step 2b is scored once per folder rather than per skill, and its absence from the report means the same restart.

**Step 0 is a gate, not a scored step:** an in-place structural verdict on a `VND` skill is void *as an immediate action* — it becomes a proposed override against `vendored-forks.md`, not a discarded finding. Default outcome: Keep plus a reported defect at its true severity. Treat `ERR` as `VND`.

**Every skill appears in the report whatever its flag.** A row reading "n/a — vendored" is a skipped step and means restart; the constraint is recorded *alongside* the verdict, never instead of it.

**REQUIRED BACKGROUND:** Read [references/skill-standards.md](references/skill-standards.md), the automatically loadable house authority.
