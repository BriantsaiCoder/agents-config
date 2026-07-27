# Vendored forks — accepted, recorded, re-mergeable

Vendored skills take no in-place structural edit (see `skills/auditing-skill-folder/step0-vendored-gate.md`). That rule is a **default requiring a recorded override**, not an absolute. This file is the record. A fork that is not listed here is an unrecorded fork — a defect, not a decision.

Listing a skill here does NOT reopen it for further editing. It records one decision already taken, with the procedure to reconcile it when upstream moves.

<!-- MACHINE-READ by skills/auditing-skill-folder/scripts/lib-vendored.sh (fork_recorded).
     An index row MUST begin with "| `" followed by the exact skill directory name, and MUST sit
     between the fork-index markers below — the lookup is confined to that block, so a row of the
     same shape anywhere else in this file is inert. It did not used to be: a table elsewhere in
     this document promoted `agent-browser` to VND* by accident (2026-07-25).
     check-vendored.sh renders recorded forks as VND* instead of VND. -->

<!-- fork-index:begin -->

| Skill | Upstream | Forked from | Local change | Status |
|---|---|---|---|---|
| `design-doc-mermaid` | github.com/SpillwaveSolutions/design-doc-mermaid (v2.0.0) | `SKILL.md` 21,268B — byte-identical to upstream `main` HEAD, last pushed 2025-12-29 | `6daf12c` — −153 lines, pure de-duplication | **Retired to `attic/` 2026-07-25** |
| `tailwind-v4-shadcn` | github.com/jezweb/claude-skills (v1.0.0, per `.claude-plugin/plugin.json`; author Jeremy Dawes, MIT) | `9fdb7f2` baseline — a snapshot of an upstream layout that no longer exists; upstream renamed and restructured it to `plugins/frontend/skills/tailwind-theme-builder` | 2026-07-25 — two factual corrections in `references/common-gotchas.md` §17 and `rules/tailwind-v4-shadcn.md` | **Active** |

<!-- fork-index:end -->

Retired entries stay listed: the `attic/` copy still differs from upstream, so anyone restoring it needs this record. `check-vendored.sh` does not scan `attic/`, so a retired entry no longer renders as `VND*`.

## Unmodified vendored sets (NOT forks)

**`mattpocock/skills` stable 22 — active, pinned 2026-07-27.**

- Source: `https://github.com/mattpocock/skills.git` at `ed37663cc5fbef691ddfecd080dff42f7e7e350d`.
- Selection: `.claude-plugin/plugin.json` SHA-256 `e712cc026f5e78058067d17cd1fdf9665388d70db59dc50688286cb029e38eba`.
- Machine-readable inventory: `mattpocock-skills.lock`; only its 22 `skill=` entries are active.
- Payload is byte-for-byte upstream and immutable. Update by replacing the full pinned set after lock/hash verification; rollback by reverting the replacement commit.
- These entries are not forks and must not appear between the fork-index markers. Any local payload edit requires a new fork decision in that index.

## Hybrid — house wrapper over vendored payload

Outside the index table: nothing here is forked. The entry exists because the `VND` flag is
directory-level while the provenance is file-level, and treating the whole directory as untouchable
costs real work every audit.

**`agent-browser` — house `SKILL.md`, vendored payload.** Recorded 2026-07-26.

- **House-authored, editable, editing it is NOT a fork**: `SKILL.md`. Its banner is our own format
  per CONVENTIONS rule 1 (`tier: skill-wrapper | consumed-by: … | last-verified: …`) and it states
  「本檔刻意不快取上游內容，見下方權威來源」. The `upstream:` token in that banner is the wrapper
  *describing what it wraps*, not declaring itself foreign.
- **Vendored, no in-place edit**: `references/` (9 files), `templates/` (3 files) — `SKILL.md:24`
  declares them 「同一份上游內容的快取副本」, offline fallback only, CLI output wins on conflict.
  Also `install.sh`, an upstream CI artifact (`install.sh:20` writes `$GITHUB_ENV`; no workflow in
  this repo consumes it).
- **Why the flag is still `VND`**: detection resolves per directory, and fail-closed is the right
  default for a gate whose false-`-` authorises editing someone else's work. The flag is correct;
  this record is what narrows it.
- **Concrete cost of not recording it**: `agent-browser`'s description is 563 chars — the second
  longest in the corpus — and it was excluded from the 2026-07-25 trim pass on this flag alone.
  That exclusion was wrong: the description lives in the house-authored `SKILL.md`. Trimming it
  remains available and is not a fork.

## Retired vendored — no local modification (NOT forks)

Deliberately outside the index table above: these were never edited, so they are not forks and must not render as recorded forks. The record exists because retirement itself is a decision that needs a restore path.

**`ecpay` — retired to `attic/` 2026-07-25.**

- Upstream `github.com/ECPay/ECPay-API-Skill.git`, detached at `5b1ac76` (2026-07-07), per `attic/ecpay/UPSTREAM.txt`.
- LICENSE is **All Rights Reserved**, Copyright (c) 2025-2026 綠界科技股份有限公司 — not open source. It may be kept locally but not redistributed.
- **Zero local modification**: `git log --follow -- skills/ecpay/SKILL.md` shows one commit (`9fdb7f2`, the baseline import). The `attic/` copy is byte-identical to what was vendored, so no re-merge procedure is needed — restoring means re-cloning upstream or `git mv attic/ecpay skills/ecpay`.
- Removed on user instruction while trimming the resident skill listing. Wholesale removal is legal under the vendored gate — what is forbidden is editing in place.
- Cost it was carrying: 319 chars of name+description in every session's skill listing (2.9MB / 295 files on disk, which cost nothing resident).
- **Restore when**: a project actually integrates ECPay 金流 / 電子發票 / 物流. The knowledge is 綠界-specific and not model-stable — 12-language CheckMacValue / AES vectors, ECPG vs ecpayment dual-domain traps, per-service test MerchantIDs. Nothing else in `skills/` covers it.

---

## tailwind-v4-shadcn

**Decision (2026-07-25): accept the fork. Two factual corrections, both confirmed against upstream's current version.**

### How this fork happened without anyone deciding to make one

Its only provenance is `.claude-plugin/plugin.json`, a marketplace manifest the detector did not open at the time:

```json
{ "author": { "name": "Jeremy Dawes", "email": "jeremy@jezweb.net" },
  "license": "MIT", "repository": "https://github.com/jezweb/claude-skills" }
```

No LICENSE, no README, nothing in frontmatter — so `check-vendored.sh` rendered it `-` (self-owned) and the corrections below were made before its vendored status was known. The detector was fixed the next day and now flags it `VND*`; see "## Detector gap — check-vendored.sh missed 2 of 6 (fixed)" below for that fix and its test coverage.

The decision to keep the corrections was taken **after** the status was known, on the merits recorded below — not by default.

### Not fixed, deliberately: the `rules/` subdirectory

`rules/tailwind-v4-shadcn.md` carries a `paths:` frontmatter (single-line comma form, unlike the YAML-list form `~/.agents/rules/*` uses). Inside a skill that frontmatter never fires — path-triggered loading only reads `~/.claude/rules/` and `.claude/rules/` — so it is upstream residue that reads like a live rule. `SKILL.md:39` indexes the file correctly as "Rule text for agents/tools", and its content is correct (the `@apply` correction above landed there).

Left alone on purpose. Removing the dead frontmatter, or moving the file to `references/` where it belongs by type, is a second structural edit to someone else's skill — a new override decision bought for the removal of a misleading comment. That trade is the wrong way round, and per this file's opening rule, an existing record does not authorise further editing.

The tempting alternative is also rejected: promoting it to `~/.agents/rules/` would be legal (external integration touches none of the skill's own files) but wrong. External integration is already done — `core/routing.md:8` routes "Tailwind v4 → `tailwind-v4-shadcn`" and `rules/frontend-spa.md:16` declares the Tailwind + shadcn stack. A new rules file would duplicate skill content into the path-triggered layer on `**/*.css` / `**/*.tsx`, re-inflating resident context that a 2026-07-25 pass had just trimmed.

### What was wrong

Both defects were flagged in `proposals/2026-07-25-skill-audit/02-recommendations.md` (Batch B) and left unexecuted. Both are the skill contradicting itself, and following either branch produces broken output:

| Where | Said | Reality |
|---|---|---|
| `references/common-gotchas.md` §17 | `@import "tw-animate-css"` → "Package doesn't exist in v4"; install nothing, use native CSS animations | `rules/tailwind-v4-shadcn.md:45,51` in the *same skill* says `pnpm add -D tw-animate-css` and import it |
| `rules/tailwind-v4-shadcn.md:63-66,117` | "`@apply` — ❌ Deprecated in v4" | `SKILL.md:27` in the *same skill* says only "Avoid `@apply` for semantic token plumbing" |

### Why the fork was accepted rather than reported

Upstream's current version settles both, in our favour — verified 2026-07-25 against `plugins/frontend/skills/tailwind-theme-builder`:

- `SKILL.md:46` `pnpm add -D tw-animate-css`, `SKILL.md:77` `@import "tw-animate-css";` — the package exists and is the v4 path. §17 was simply wrong.
- `SKILL.md:197` lists only "Use `@apply` with `@layer base` classes (use `@utility` instead)" as the thing to avoid — `@apply` is not deprecated. Our correction adopts that `@utility` guidance verbatim.

So this is error correction validated by upstream, not local opinion injected into third-party content — the same category as `design-doc-mermaid`'s de-duplication.

**The merge-conflict cost that normally justifies the vendored rule does not exist here.** Upstream deleted both edited files: `tailwind-theme-builder` has no `common-gotchas.md` and no `rules/` directory at all. There is nothing upstream left for these edits to conflict with.

### Re-merge procedure (when upstream moves)

There is no 3-way merge to perform — the file-level correspondence is gone. If upstream is to be tracked again, it is a **replacement decision**, not a merge:

1. Diff our `SKILL.md` + `templates/` against `plugins/frontend/skills/tailwind-theme-builder/{SKILL.md,assets/}` — these are the only parts with a surviving upstream counterpart.
2. Decide whether the local-only material still earns its place: `references/common-gotchas.md` (17 gotchas) and `rules/tailwind-v4-shadcn.md` exist **only** in our snapshot. Upstream dropped them; nothing recovers them but this copy.
3. If replacing wholesale, that is legal under the gate — but the 17 gotchas and the rules file are lost with it. Copy forward anything still true first.
4. Update the "Forked from" cell above with the new upstream ref.

---

## design-doc-mermaid

**Decision 1 (2026-07-25): accept the fork. Do not re-pull.**
**Decision 2 (2026-07-25, same day): retire the skill entirely to `attic/`.** See "Retired" below — this supersedes the fork question in practice, but the record is kept because the `attic/` copy is still a fork of upstream.

### Why re-pulling was rejected

Our import baseline (`9fdb7f2`) is byte-identical to upstream's current `main` HEAD. Upstream has not changed `SKILL.md` since we took it, and its last push of any kind was 2025-12-29. So a re-pull recovers **zero** upstream improvement and its only effect would be to re-inflate 3.3KB of redundancy that `6daf12c` removed.

The recurring merge-conflict cost that justifies the vendored rule is unrealized here, and at this upstream cadence is not imminent. The rule was still right to flag it — the flag is what turned a silent fork into this record.

### What the fork actually is

Pure de-duplication, not customization. `6daf12c` removed three blocks from `SKILL.md` whose content already lived in the skill's own reference files, replacing each with a pointer:

| Removed from `SKILL.md` | Already present in |
|---|---|
| Resilient Workflow overview, file-naming convention, error-recovery priority chain | `references/guides/resilient-workflow.md` (16,172B, verified superset) |
| Three Unicode example diagrams | `unicode-symbols/guide.md` |
| Python utility flag examples | the three scripts' own `argparse --help` |

Preserved: the behavioural rule *"NEVER add a diagram to markdown until it passes validation."* No local opinion was injected; no behaviour changed. All internal pointers in the forked `SKILL.md` resolve (verified 2026-07-25).

### Re-merge procedure (when upstream moves)

1. Fetch upstream `SKILL.md` and diff it against our baseline `git show 9fdb7f2:skills/design-doc-mermaid/SKILL.md` — that is the true 3-way merge base, NOT our current file.
2. Apply the upstream delta to the baseline.
3. Re-apply the three condensations in the table above. The conflict region is confined to them; resolving is mechanical, not a judgement call.
4. Re-verify every `references/`, `scripts/`, `checklists/`, `unicode-symbols/` pointer in the result still resolves.
5. Update the "Forked from" cell in the index above with the new upstream ref.

### Retired (2026-07-25)

Moved to `attic/design-doc-mermaid` and removed from routing. Wholesale removal is legal under the gate — what is forbidden is editing in place.

Evidence it contributed nothing:

- **`mmdc` is not installed.** All three of its scripts hard-depend on `@mermaid-js/mermaid-cli`, so none of them could run. Its entire mechanical value — validation, image conversion, the resilient error-recovery chain — was never available on this machine.
- **The artifact it supposedly produced needs no tooling.** `docs/codebase/ARCHITECTURE.md` in the DCT project is 8 inline ````` ```mermaid ````` fenced blocks, 0 image references, no `diagrams/` directory. `專案架構視覺化.html` renders client-side via mermaid.js, not from pre-rendered images.
- **0 dispatches across 398 startups**, despite being hard-referenced in four routing files plus `dist/skill-index.md`.

What remains capable of producing the same output: writing ````` ```mermaid ````` fences directly. GitHub, Claude artifacts, and that HTML all render mermaid natively.

**The one scenario that would justify restoring it:** wanting pre-rendered PNG/SVG architecture diagrams committed to the repo, rather than fences rendered by the viewer. That needs `npm i -g @mermaid-js/mermaid-cli` plus this skill back out of `attic/` — follow the re-merge procedure above if upstream has moved by then.

---

## Detector gap — check-vendored.sh missed 2 of 6 (fixed)

Found 2026-07-25, fixed 2026-07-26. `check-vendored.sh` reported 4 vendored skills out of `skills/`; the real count was 6. Both misses were caught by hand during the description-trim pass — exactly the review this detector exists to make unnecessary.

Both were false negatives of the same shape: **provenance recorded somewhere the detector did not read.** That is the dangerous direction. A false VND costs one manual check; a false `-` silently licenses editing someone else's skill — and did: the `tailwind-v4-shadcn` corrections recorded above were made before anyone knew whose skill it was.

| Skill | Provenance | Why it was missed | Fix |
|---|---|---|---|
| agent-browser | `SKILL.md:7` `<!-- tier: … \| consumed-by: … \| upstream: agent-browser CLI … -->`; `SKILL.md:24` self-declares `references/` + `templates/` as cached upstream copies; `install.sh:20` writes `$GITHUB_ENV` | The `upstream:` token sits in an HTML comment **after** the closing `---`, where the frontmatter-bounded awk (`fm==2 exit`) had already stopped. No LICENSE either. | Marker scan moved out of the frontmatter to the whole file, anchored on `^` / `<!--` / `\|`. The `\|` anchor is required — the marker is the comment's 4th pipe-delimited field. |
| tailwind-v4-shadcn | `.claude-plugin/plugin.json` carries `author`, `license: MIT`, `repository: github.com/jezweb/claude-skills` | The detector never opened `.claude-plugin/plugin.json`. No LICENSE, no README, nothing in frontmatter. | That file joined the provenance file set. Its content already matched the existing URL pattern, so the fix was the file set, not the pattern — content-only detection stays the single rule. |

Both fixes landed in `vendored_flag()` **and** `vendored_owner()`. Fixing only the flag would have produced two VND rows with an empty OWNER column, which reads as a detector bug rather than as the finding.

A third defect surfaced while writing this section: `fork_recorded()` matched `| \`name\` |` anywhere in this file, so the table above — documentation, not an index — promoted `agent-browser` to `VND*`, asserting an accepted fork decision that was never made. The fork index now sits between `<!-- fork-index:begin/end -->` markers and the lookup is confined to that block; a file with no markers fails closed.

Regression coverage: `tests/vendored-detection.sh`, 33 cases — every provenance form, the false-positive defences (prose `upstream` with no colon; a README that merely exists), lock-set detection, flag/owner agreement, the `fork_recorded` scoping regression, and a corpus assertion pinning the exact VND set of `skills/`. Acceptance for the original detector fix itself was a baseline diff: exactly two skill rows changed, nothing else.
