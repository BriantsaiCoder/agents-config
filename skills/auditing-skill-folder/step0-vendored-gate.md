# Step 0 — Vendored gate

## What it flags

`scripts/check-vendored.sh <folder>`:

| Flag | Signal | Meaning |
|---|---|---|
| `VND` | a LICENSE variant (`LICENSE`/`.md`/`.txt`/`COPYING`) **or** an upstream-provenance marker in `README.md`/`SKILL.md` | Vendored |
| `VND*` | `VND`, and listed in `vendored-forks.md` | Vendored, **already forked by a recorded decision** — read the record before judging it |
| `vnd?` | frontmatter `homepage:` / `source:` / `upstream:` only | Probable — confirm by hand |
| `ERR` | directory or `SKILL.md` unreadable | **Unknown. Treat as vendored** until proven otherwise |
| `-` | none of the above | Self-owned |

`VND*` exists so the gate can say more than "don't". A vendored skill that has been edited in place is either a recorded decision or a defect, and if those look identical the same accepted fork gets re-litigated at every audit. `VND*` means the decision is already made and documented with a re-merge procedure — do not reopen it, and do not treat it as licence to edit further. A vendored skill that has been edited but is **not** listed is an unrecorded fork: that is the defect.

The record lives at the repo root (`vendored-forks.md`), never inside the vendored skill — writing the record into the skill would itself be the in-place edit the gate forbids. Lookup order: `$VENDORED_FORKS`, then `<audited-folder>/../vendored-forks.md`, then the repo root above this skill.

Detection is the **union** of two signals because neither alone is sufficient — this was learned the hard way, twice:

- LICENSE alone misses `design-doc-mermaid`: no LICENSE file at all, upstream is a Skilz Marketplace listing (SpillwaveSolutions) declared only in its README.
- The provenance marker alone misses `playwright-best-practices` and `vueuse-functions`: `LICENSE.md`, no marker.

The union returns 6/6 known vendored with 0 false positives across the other 46 skills.

`README.md`'s **existence** is not a signal — plenty of self-owned skills have one. Only its provenance **content** counts (marketplace listing, "install this skill", a github URL naming a skill repo).

Everything fails closed: an unreadable file resolves toward `VND`, never toward `-`. A false `VND` costs one manual check; a false `-` authorises editing someone else's skill.

## The constraint

**A vendored skill takes no in-place structural edit** — no Trim, no Split, no rewriting its `SKILL.md` or references.

Editing an upstream skill in place IS a fork. It trades a one-off load saving for a permanent merge-conflict cost on every upstream update, so the constraint **outranks token cost and trigger precision** — those benefits are one-time, the conflict cost recurs. A defect found in a vendored skill gets *reported*, not fixed.

Still legal, because they don't edit the skill's own files:
- External integration — adding its name to a routing list, a rules file, a hub skill.
- Wholesale replacement (pull a newer upstream version) or removal of the skill entirely.

Note the vocabulary trap: "Delete" as a protocol verdict means *removing the whole skill*, which is legal. What is forbidden is *editing in place*.

## Why this is Step 0 and not a scored step

Steps 1–6 produce verdicts. This one decides which verdicts are *legal*, so it runs before them and voids anything that lands wrong — however well steps 1–6 argue for it. Record such a case as Keep plus a reported defect.

Steps 1–2 carry a `VND` column for the same reason: an over-limit word count reads as "Trim me", and that must not be readable without the constraint on the same line.

## Why it is mechanical and not a reviewer instruction

Written as prose, this axis failed three times on the same 52-skill folder:

1. A 2026-07-25 audit gave `native-feel-cross-platform-desktop` a **Trim**. Its own step-3 cell said *"this is a vendored third-party skill (LICENSE: MIT, Copyright (c) 2026 yetone)"*. The fact was already in the table; nothing made it bind. `vueuse-functions` and `design-doc-mermaid` went the same way.
2. Adding the axis as a prose section specified the check as `ls */LICENSE` — which is itself what missed two skills using `LICENSE.md`. Two hand-scans both reported 3; the script reported 5 on its first run.
3. The first script version used LICENSE-only detection and false-negatived `design-doc-mermaid`. Adversarial verification caught it — and by then commit `6daf12c` had already deleted 153 lines from that skill's `SKILL.md`. The fork this gate exists to prevent had already happened, unnoticed by both the audit and the first gate.
4. The union version then false-negatived the same skill *again*, but only when auditing `~/.claude/skills` — `grep -R <dir> --include=...` does not descend when the directory argument is itself a symlink, so the marker check silently returned "no match" on the exact path this skill's own description advertises. Fixed by naming the two candidate files instead of recursing. Sibling of the same class as `find` needing `-L`.

An axis in prose does not gate. An axis in a script gates only as well as its detection — so verify the detection against the corpus **through every documented path**, not against intuition. Both symlink bugs above passed a `~/.agents/skills` run and failed a `~/.claude/skills` run.
