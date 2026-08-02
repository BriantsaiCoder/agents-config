# Step 0 — Vendored gate

## What it flags

`scripts/check-vendored.sh <folder>`:

| Flag | Signal | Meaning |
|---|---|---|
| `VND` | a tab-separated `<basename>` record in repo-root `vendored-skills.lock` (**checked first**), a LICENSE variant (`LICENSE`/`.md`/`.txt`/`COPYING`), an upstream-provenance marker in `README.md` / `SKILL.md` / `.claude-plugin/plugin.json`, an `upstream:` declaration anywhere in `SKILL.md`, **or** an exact `skill=<basename>` entry in repo-root `mattpocock-skills.lock` | Vendored |
| `VND*` | `VND`, and listed in the fork-index block of `vendored-forks.md` | Vendored, **already forked by a recorded decision** — read the record before judging it |
| `vnd?` | frontmatter `homepage:` / `source:` only | Probable — confirm by hand |
| `ERR` | directory or `SKILL.md` unreadable | **Unknown. Treat as vendored** until proven otherwise |
| `-` | none of the above | Self-owned |

`VND*` exists so the gate can say more than "don't". A vendored skill that has been edited in place is either a recorded decision or a defect, and if those look identical the same accepted fork gets re-litigated at every audit. `VND*` means the decision is already made and documented with a re-merge procedure — do not reopen it, and do not treat it as licence to edit further. A vendored skill that has been edited but is **not** listed is an unrecorded fork: that is the defect.

The record lives at the repo root (`vendored-forks.md`), never inside the vendored skill — writing the record into the skill would itself be the in-place edit the gate forbids. It must sit **between the `<!-- fork-index:begin/end -->` markers**; the lookup is confined to that block, so a table row of the same shape elsewhere in that file is inert (it was not always — a documentation table once promoted `agent-browser` to `VND*` by accident). A file with no markers fails closed. Lookup order: `$VENDORED_FORKS`, then `<audited-folder>/../vendored-forks.md`, then the repo root above this skill.

Detection is the **union** of five signals because none alone is sufficient — every one of them was learned from a miss or an immutable vendored-set requirement:

- `vendored-skills.lock` (repo root, tab-separated: `<basename>`, `source_url`, …) is checked **first** and outranks the rest. It is the general provenance ledger for payloads that carry no in-tree marker at all. Column 2 becomes the OWNER cell.
  - Consequence you must internalise before judging any row: **a `VND` flag is not proof of foreign authorship.** Resolve the recorded source before deciding editability. For example, `aspnet-api-architect` was removed from the lock after its source proved to be this repository's own initial snapshot; the evidence now lives under `vendored-forks.md` → "Resolved Stage B2 provenance".
- LICENSE alone missed `design-doc-mermaid`: no LICENSE file at all, upstream was a Skilz Marketplace listing (SpillwaveSolutions) declared only in its README. That skill has since been retired to `attic/`, but it remains the reason this is a union and not a single test.
- The provenance marker alone misses `playwright-best-practices` and `vueuse-functions`: `LICENSE.md`, no marker. `vueuse-functions` was merged into `vue-best-practices` and retired to `attic/` on 2026-08-02 under an explicit user override; its LICENSE notice moved with the payload to `vue-best-practices/references/vueuse/LICENSE.md`, which is what MIT attribution requires and what a marker-only scan would still miss.
- Both together still missed two skills (2026-07-25, caught by hand, fixed 2026-07-26): `tailwind-v4-shadcn` declares provenance only in `.claude-plugin/plugin.json`, which was not in the scanned file set; `agent-browser` puts its `upstream:` marker in an HTML comment **after** the closing `---`, where the frontmatter-bounded scan had already stopped. Both are now covered — the marker scan reads the whole `SKILL.md`, anchored on `^` / `<!--` / `|`.
- A pinned upstream set may intentionally keep provenance outside the payload to preserve byte identity. `mattpocock-skills.lock` is the central source/hash/inventory record for that case; an exact basename entry is vendored without adding wrappers or LICENSE copies to each skill.

The union returns every known vendored skill with 0 false positives across the corpus. `tests/vendored-detection.sh` (56 cases, in CI) pins that: every provenance form, both false-positive defences, both lock paths, and the exact `VND` set of `skills/`.

**LICENSE variants signal by existence; README, SKILL, and plugin-manifest files signal only by provenance content.** Plenty of self-owned skills have a `README.md`; `.claude-plugin/plugin.json` is read for its `repository` / `author`, not counted for being there.

`upstream:` resolves to `VND`, not `vnd?`: naming that key is an explicit statement of foreign origin. `homepage:` / `source:` stay `vnd?` because a skill can legitimately link its own project.

Everything fails closed: an unreadable file resolves toward `VND`, never toward `-`. A false `VND` costs one manual check; a false `-` authorises editing someone else's skill.

## The constraint

**A vendored skill takes no in-place structural edit** — no Trim, no Split, no rewriting its `SKILL.md` or references.

Editing an upstream skill in place IS a fork. It trades a one-off load saving for a permanent merge-conflict cost on every upstream update, so the constraint **outranks token cost and trigger precision** — those benefits are one-time, the conflict cost recurs. A defect found in a vendored skill gets *reported*, not fixed.

Still legal, because they don't edit the skill's own files:
- External integration — adding its name to a routing list, a rules file, a hub skill.
- Wholesale replacement (pull a newer upstream version) or removal of the skill entirely.

Note the vocabulary trap: "Delete" as a protocol verdict means *removing the whole skill*, which is legal. What is forbidden is *editing in place*.

## What the gate does NOT do

此 gate 不限制 **assessment**。每個 skill 都須依是否需要 tuning 或 optimisation 判斷：讀取內容、計數、lint、完成六個 steps，並依缺陷本身記錄 severity。Flag 不得弱化、降級、延後或隱藏 finding，只決定 verdict 如何落地。若稽核把 `VND` skill 記為 "n/a — vendored"，或降低缺陷等級，即缺少必要 assessment，必須重新開始。

Three reasons this has to be stated rather than left implied:

- The gate's whole vocabulary is prohibitive ("takes no", "is void", "forbidden"), and a prohibition read at speed generalises from *don't edit* to *don't bother*. That drift is the failure this section exists to block.
- The flag is not proof of foreign authorship. Refresh the locks and provenance record before judging: a formerly locked row may be reclassified as self-owned when evidence resolves its source, as happened with `aspnet-api-architect`.
- Reporting is a real output only if the report is real. A finding recorded at true severity is what a future override decision is argued from; a finding softened at capture time cannot be recovered later.

## The override: the constraint is a default, not an absolute

`vendored-forks.md` states it outright — the no-in-place-edit rule is *"a default requiring a recorded override, not an absolute"*, and its fork index is the accepted-fork inventory.

若 assessment 判定原地修改值得承擔永久 merge-conflict 成本，須保留 assessment verdict，並附加 execution constraint **`proposed override required`**：

1. Diff against the pinned upstream commit for that skill.
2. Add a dated row inside the `<!-- fork-index:begin/end -->` block naming the local change; a row outside that block is inert.
3. Recompute the recorded tree SHA-256 (and `invocation_manifest_sha256` where the record lists one).
4. Re-run the tests that skill's record names — at minimum `tests/vendored-detection.sh` and `tests/matt-thin-workflow.sh`.
5. Write a re-merge procedure into the record, so the next upstream move is reconcilable.

An unrecorded in-place edit is the defect. A recorded one is a decision. What the gate forbids is the *silent* fork, not the considered one — and the five steps above are the whole difference.

An existing `VND*` record does not license further editing: read its current scope in repo-root `vendored-forks.md`. Going beyond that scope is a **new** decision needing a new record, not a continuation of the old one.

## Why this is Step 0 and not a scored step

Steps 1–6 產出 assessment verdict；Step 0 只附加 execution constraint。不得因 `VND` 將 `Trim`、`Split` 或其他真實 assessment 改成 `Keep`；原地修改建議須記錄真實 verdict 加 `proposed override required`。

Steps 1–2 carry a `VND` column for the same reason: an over-limit word count reads as "Trim me", and that must not be readable without the constraint on the same line.

## Why it is mechanical and not a reviewer instruction

Written as prose, this axis failed three times on the same 52-skill folder:

1. A 2026-07-25 audit gave `native-feel-cross-platform-desktop` a **Trim**. Its own step-3 cell said *"this is a vendored third-party skill (LICENSE: MIT, Copyright (c) 2026 yetone)"*. The fact was already in the table; nothing made it bind. `vueuse-functions` and `design-doc-mermaid` went the same way.
2. Adding the axis as a prose section specified the check as `ls */LICENSE` — which is itself what missed two skills using `LICENSE.md`. Two hand-scans both reported 3; the script reported 5 on its first run.
3. The first script version used LICENSE-only detection and false-negatived `design-doc-mermaid`. Adversarial verification caught it — and by then commit `6daf12c` had already deleted 153 lines from that skill's `SKILL.md`. The fork this gate exists to prevent had already happened, unnoticed by both the audit and the first gate.
4. The union version then false-negatived the same skill *again*, but only when auditing `~/.claude/skills` — `grep -R <dir> --include=...` does not descend when the directory argument is itself a symlink, so the marker check silently returned "no match" on the exact path this skill's own description advertises. Fixed by naming the two candidate files instead of recursing. Sibling of the same class as `find` needing `-L`.

An axis in prose does not gate. An axis in a script gates only as well as its detection — so verify the detection against the corpus **through every documented path**, not against intuition. Both symlink bugs above passed a `~/.agents/skills` run and failed a `~/.claude/skills` run.
