# Step 0 — Vendored gate

## What it flags

`scripts/check-vendored.sh <folder>`:

| Flag | Signal | Meaning |
|---|---|---|
| `VND` | a LICENSE variant (`LICENSE`/`.md`/`.txt`/`COPYING`), **or** an upstream-provenance marker in `README.md` / `SKILL.md` / `.claude-plugin/plugin.json`, **or** an `upstream:` declaration anywhere in `SKILL.md` | Vendored |
| `VND*` | `VND`, and listed in the fork-index block of `vendored-forks.md` | Vendored, **already forked by a recorded decision** — read the record before judging it |
| `vnd?` | frontmatter `homepage:` / `source:` only | Probable — confirm by hand |
| `ERR` | directory or `SKILL.md` unreadable | **Unknown. Treat as vendored** until proven otherwise |
| `-` | none of the above | Self-owned |

`VND*` exists so the gate can say more than "don't". A vendored skill that has been edited in place is either a recorded decision or a defect, and if those look identical the same accepted fork gets re-litigated at every audit. `VND*` means the decision is already made and documented with a re-merge procedure — do not reopen it, and do not treat it as licence to edit further. A vendored skill that has been edited but is **not** listed is an unrecorded fork: that is the defect.

The record lives at the repo root (`vendored-forks.md`), never inside the vendored skill — writing the record into the skill would itself be the in-place edit the gate forbids. It must sit **between the `<!-- fork-index:begin/end -->` markers**; the lookup is confined to that block, so a table row of the same shape elsewhere in that file is inert (it was not always — a documentation table once promoted `agent-browser` to `VND*` by accident). A file with no markers fails closed. Lookup order: `$VENDORED_FORKS`, then `<audited-folder>/../vendored-forks.md`, then the repo root above this skill.

Detection is the **union** of three signals because none alone is sufficient — every one of them was learned from a miss:

- LICENSE alone missed `design-doc-mermaid`: no LICENSE file at all, upstream was a Skilz Marketplace listing (SpillwaveSolutions) declared only in its README. That skill has since been retired to `attic/`, but it remains the reason this is a union and not a single test.
- The provenance marker alone misses `playwright-best-practices` and `vueuse-functions`: `LICENSE.md`, no marker.
- Both together still missed two skills (2026-07-25, caught by hand, fixed 2026-07-26): `tailwind-v4-shadcn` declares provenance only in `.claude-plugin/plugin.json`, which was not in the scanned file set; `agent-browser` puts its `upstream:` marker in an HTML comment **after** the closing `---`, where the frontmatter-bounded scan had already stopped. Both are now covered — the marker scan reads the whole `SKILL.md`, anchored on `^` / `<!--` / `|`.

The union returns every known vendored skill with 0 false positives across the corpus. `tests/vendored-detection.sh` (30 cases, in CI) pins that: every provenance form, both false-positive defences, and the exact `VND` set of `skills/`.

**File existence is never the signal — provenance content is.** Plenty of self-owned skills have a `README.md`; `.claude-plugin/plugin.json` is read for its `repository` / `author`, not counted for being there. (The existence test would also have been 0-false-positive on this corpus — exactly 1 of 50 skills has that directory — and was rejected anyway, because content-only keeps this one rule rather than two.)

`upstream:` resolves to `VND`, not `vnd?`: naming that key is an explicit statement of foreign origin. `homepage:` / `source:` stay `vnd?` because a skill can legitimately link its own project.

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
