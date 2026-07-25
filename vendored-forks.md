# Vendored forks — accepted, recorded, re-mergeable

Vendored skills take no in-place structural edit (see `skills/auditing-skill-folder/step0-vendored-gate.md`). That rule is a **default requiring a recorded override**, not an absolute. This file is the record. A fork that is not listed here is an unrecorded fork — a defect, not a decision.

Listing a skill here does NOT reopen it for further editing. It records one decision already taken, with the procedure to reconcile it when upstream moves.

<!-- MACHINE-READ by skills/auditing-skill-folder/scripts/lib-vendored.sh (fork_recorded).
     An index row MUST begin with "| `" followed by the exact skill directory name.
     check-vendored.sh renders recorded forks as VND* instead of VND. -->

| Skill | Upstream | Forked from | Local change | Status |
|---|---|---|---|---|
| `design-doc-mermaid` | github.com/SpillwaveSolutions/design-doc-mermaid (v2.0.0) | `SKILL.md` 21,268B — byte-identical to upstream `main` HEAD, last pushed 2025-12-29 | `6daf12c` — −153 lines, pure de-duplication | **Retired to `attic/` 2026-07-25** |

Retired entries stay listed: the `attic/` copy still differs from upstream, so anyone restoring it needs this record. `check-vendored.sh` does not scan `attic/`, so a retired entry no longer renders as `VND*`.

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
