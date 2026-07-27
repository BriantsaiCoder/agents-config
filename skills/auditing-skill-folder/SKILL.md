---
name: auditing-skill-folder
description: Use when auditing a skill folder (~/.agents/skills/, ~/.claude/skills/) for keep/trim/delete/migrate decisions. Apply when a prior audit kept everything (suspicious uniform-keep), when only "built-in knowledge sufficient?" was used as criterion, or when skill trigger rate feels low.
---

# Auditing a Skill Folder

## Overview

**Core principle:** Structural checks first, content relevance last. Jumping to "do I still need this" produces all-keep or vibes-delete results that miss real defects.

**Not for:** writing a new skill (use `superpowers:writing-skills`); debugging one skill's single trigger.

## Step 0 — Vendored gate (run FIRST; it decides which verdicts are legal)

`scripts/check-vendored.sh <folder>` → `VND` / `VND*` (fork already recorded in `vendored-forks.md`) / `vnd?` / `ERR` / `-`. Steps 1–2 repeat the flag as a column.

**Vendored skills take no IN-PLACE structural edit** — no Trim, no Split, no rewriting their files. Editing upstream in place is a fork; report the defect instead. Removing or replacing the whole skill stays legal. Details: `step0-vendored-gate.md`.

## Six-Step Protocol

Run in order after Step 0. Steps 1–2 mechanical, 3–5 read, 6 is the call you wanted to start with — defer it.

| # | Step | Tool | Output |
|---|---|---|---|
| 1 | Token cost | `scripts/count-words.sh <folder>` | >500 / 200 / 150 words; over → see `step1-verdict-guide.md` (Trim vs Externalize vs Refactor) |
| 2 | Description trap | `scripts/lint-descriptions.sh <folder>` | Descriptions summarizing workflow vs. trigger-only |
| 3 | Stance bleed | Read | Pure stance ("use Serilog", "no barrels") → propose CLAUDE.md |
| 4 | Mechanical-only | Read | Enforceable by lint/hook/regex → propose hook |
| 5 | Type clarity | Read | Technique / Pattern / Reference; flag mixed-type → propose split |
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
| "Bloated AND third-party, so trim hard" | Backwards — vendored makes the trim illegal, not overdue |
| "I'll eyeball which are vendored" | Two hand-scans missed 2 (`LICENSE.md` ≠ `LICENSE`). Run Step 0. |

## Step 7 (optional) — Style anti-patterns

**OPTIONAL REFERENCE:** see `step7-style-checks.md`. Tag-only, not restart-gating.

## Iron Law

**Every audit produces a written report scoring each skill against all six steps**, ending in a verdict block: Keep / Trim / Move-to-CLAUDE.md / Convert-to-hook / Split / Delete. "Looked at it, looks fine" is not a verdict. If you cannot fill in a step result, you did not run that step. Skipping any of steps 1–5 means restart.

**Step 0 is a gate, not a scored step:** an in-place structural verdict on a `VND` skill is void however well steps 1–6 argue it. Record Keep plus a reported defect. Treat `ERR` as `VND` until proven otherwise.

**REQUIRED BACKGROUND:** `superpowers:writing-skills` (authoritative source for the six standards).
