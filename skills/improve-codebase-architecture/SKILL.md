---
name: improve-codebase-architecture
description: "Survey a codebase for module-deepening opportunities when explicitly requested; present visual candidates and explore the user’s selected design."
disable-model-invocation: true
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This command is _informed_ by the project's domain model and built on a shared design vocabulary:

- Run the `/codebase-design` skill for the architecture vocabulary (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Use these definitions when discussing this design model, while preserving the repository's established names for components, services, APIs, and domain boundaries.
- The domain language in `CONTEXT.md` gives names to good seams; ADRs in `docs/adr/` record decisions this command should not re-litigate.

## Language

The active host/profile owns the default output language. Preserve technical identifiers, paths, and repository domain terms; use that language consistently in the visual report and any routed interview.

## Process

### 1. Explore

**Scope before you scan — YAGNI.** Deepening a module pays off by making future changes to it easier, so put extra weight on the parts of the codebase that have recently changed. Decide *where* to look before you look:

- If the user named a direction — a module, a subsystem, a pain point — take it, and skip the inference below.
- Otherwise, walk back a good stretch of the commit history (`git log --oneline`) to find the codebase's hot spots — the files and areas that keep coming up — and let those paths pull your attention first. If the changes are scattered with no clear hot spot, widen the net.

Read the project's domain glossary (`CONTEXT.md`) and any ADRs in the area you're touching first.

Use the active host's available exploration capability. Delegate read-only exploration when useful and available under `dev-workflow` INT-4; otherwise explore in the main context. Note concrete friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the OS temp directory so nothing lands in the repo. Resolve the temp dir from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows), and write to `<tmpdir>/architecture-review-<timestamp>.html` so each run gets a fresh file. Open it for the user — `xdg-open <path>` on Linux, `open <path>` on macOS, `start <path>` on Windows — and tell them the absolute path.

Report format, card fields, badges, and diagram patterns are in [html-report.md](references/html-report.md); load it when writing the file.

**Preserve CONTEXT.md terms and actual repository symbols**, including service/component/API names. Add module/interface/seam roles when they help explain depth; do not rename domain symbols to fit the glossary.

**ADR conflicts**：candidate 若與既有 ADR 衝突，只在 friction 大到值得重啟討論時提出，並在 card 中清楚標示，例如：_「與 ADR-0007 衝突，但值得重新討論，因為……」_。不要列出 ADR 禁止的所有理論性 refactor。

此階段不要提出 interfaces。寫完檔案後，詢問使用者：「這些候選項目中，你想先深入探索哪一個？」

### 3. Grilling loop

Once the user picks a candidate, run the `/grilling` skill to walk the decision tree with them — constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive.

Use `/domain-modeling` as decisions crystallize. Update only an already authorized docs path/scope; a read-only survey delivers term/ADR proposals in the session. Selecting a candidate and clarifying its design do not authorize implementation. Within that docs boundary:

- **Naming a deepened module after a concept not in `CONTEXT.md`?** Add the term to `CONTEXT.md`. Create the file lazily if it doesn't exist.
- **Sharpening a fuzzy term during the conversation?** Update `CONTEXT.md` right there.
- **使用者因關鍵理由否決 candidate？** 提議記錄 ADR：_「要我把這項理由記錄成 ADR，避免未來的架構審查再次提出相同建議嗎？」_。只有未來 explorer 確實需要這項理由才能避免重提時才詢問；略過暫時性理由（「目前不值得做」）與顯而易見的理由。
- **Want to explore alternative interfaces for the deepened module?** Run the `/codebase-design` skill and use its design-it-twice alternatives pattern; that workflow decides whether delegation helps.
