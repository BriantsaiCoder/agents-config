---
name: code-review
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

The issue tracker should have been provided to you — run `/setup-matt-pocock-skills` if `docs/agents/issue-tracker.md` is missing.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. If they didn't specify one, ask for it.

Resolve `HEAD` to a SHA first (`review_sha=$(git rev-parse HEAD)`), then capture the diff command once: `git diff <fixed-point>...<review_sha>` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..<review_sha> --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here — not inside two parallel sub-agents.

Also confirm `git status --porcelain` is empty. The snapshot below is built from a commit, so
uncommitted work is silently absent from it — and this skill advertises reviewing
work-in-progress changes. Dirty tree means commit first (or review the dirty tree by the
`[S5-2]` package route instead); it does not mean pinning a SHA and hoping.

**Resolve `HEAD` to a SHA and pin an immutable snapshot before spawning anything.** A review
runs for tens of minutes; if you keep working on the branch meanwhile — and in a multi-round
review you almost certainly will — the sub-agents' line numbers, `git status`, and even `HEAD`
itself start describing a different commit. The failure mode isn't hypothetical: in one review
a sub-agent spent effort deciding whether a line-number mismatch was a tool bug or the file
moving under it, and the worst case is an axis returning PASS on content that no longer exists.

```
review_sha=$(git rev-parse HEAD) &&
git worktree add --detach <snapshot-dir> "$review_sha"
```

`git worktree add --detach` rather than `git archive | tar`, for two reasons. It fails loudly on
a bad ref, where the pipeline does not: `git archive <bad-ref> | tar -x -C <existing-dir>` exits
**0** and leaves an empty directory, so both sub-agents would review nothing and both return
PASS. And the result **is** a git repository, so checks that shell out to git run there — an
extracted archive is not one, and every such check fails inside it for reasons that have nothing
to do with the code under review.

If the sandbox denies writes to the source repo's `.git/worktrees`, fall back to
`git clone --local --no-hardlinks <repo> <snapshot-dir> && git -C <snapshot-dir> checkout
--detach "$review_sha"`. `--no-hardlinks` is not optional where hardlinks are blocked: with an
explicit `--local`, git dies instead of silently degrading to a copy.

The other way to stop the tree moving is to freeze the branch until both axes finish. Pinning
is preferred because it costs no serialisation, and it subsumes the freeze's side benefit —
a reviewer reading a pinned snapshot never sees the main context's in-flight ablation edits
at all, so there is nothing to misread as an uncommitted change.

Pass **`<fixed-point>...<review_sha>`** to the sub-agents, never `...HEAD`, and hand them the
snapshot path. Put the snapshot **outside the repo** (`$TMPDIR` or a scratch dir) — a copy
created inside the worktree shows up in `git status` and, in repos that fingerprint directory
trees, changes the very hashes a checker is verifying.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.) — fetch via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below — a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation — and, like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

The house over-engineering baseline — **five items**, mandatory in the Standards-axis reviewer prompt per `[S5-3]` in `../dev-workflow/SKILL.md` (host path: `~/.agents/skills/dev-workflow/SKILL.md`). Step 4 pastes this baseline into the Standards sub-agent only; the Spec brief neither carries it nor should. Same binding rules above apply (repo overrides; judgement call):

- **Reinvented Stdlib** — 手刻標準庫或平台已提供的功能 → 指名該 API 取代。
- **Redundant Dependency** — 為平台／既有模組已有的能力新增依賴 → 依選型階梯（原生 > 標準庫 > 既有模組 > 第三方 > 手寫）回退。
- **Unused Local Reuse** — 這個 repo 裡已經有的 helper／type／pattern 被重寫一份。與上方 **Duplicated Code** 不同：那條看同一 diff 內的重複，這條看 diff 對**既有資產**的重複 → 指名既有符號並改呼叫它。
- **Needless Indirection** — 只有一個呼叫端的抽象層（即使它確實做事、也確實是 spec 要的——那正是上方 **Middle Man** 與 **Speculative Generality** 都不命中的情況）→ 內聯回去，等真的第二個使用點出現再抽。
- **Wrong Altitude** — 抽象層級錯置：實作細節洩漏進高層介面，或高層策略埋進低層工具 → 把該決策移回它該在的層。

### 4. Spawn both sub-agents in parallel

Send a single message with two `Agent` tool calls. Use the `general-purpose` subagent for both.

Both briefs must carry the pinned SHA and the snapshot path from step 1.

**Standards sub-agent prompt** — include:

- The full diff command (`<fixed-point>...<review_sha>`, not `...HEAD`), the commit list, and the snapshot path.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Report — per file/hunk where relevant — (a) every place the diff violates a documented standard: cite the standard (file + the rule); (b) any baseline smell you spot: name it and quote the hunk; (c) performance regressions the diff introduces — N+1, full scans, blocking calls on a hot path, worse algorithmic complexity, needless repeated work; and (d) correctness defects — boundary conditions, null/empty handling, off-by-one, missing error handling, wrong state transitions. Distinguish hard violations from judgement calls — documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Report every hit, nitpicks included; raise anything you are unsure about as `question:` rather than dropping it. Tag each finding with a severity and a confidence. No word or finding-count limit — do not filter or truncate; the caller filters. You are reviewing an immutable snapshot: the assignment names an explicit SHA and a copy path you must treat as read-only (nothing on disk enforces that — it is a behavioural constraint, and the other axis is reading the same path). Do every ablation on your own copy of it — the live worktree is off limits, another axis is reading it, and mutating it corrupts both reviews. If a check has to shell out to git, make that copy with `git worktree add --detach` or `git clone --local --no-hardlinks` rather than a plain `cp -r`, so the copy is a real repository. State the SHA you reviewed in your report so a stale result is identifiable later."

**Spec sub-agent prompt** — include:

- The diff command (pinned to `<review_sha>`), the commit list, and the snapshot path.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Report every hit; raise anything you are unsure about as `question:` rather than dropping it. Tag each finding with a severity and a confidence. No word or finding-count limit — do not filter or truncate; the caller filters. You are reviewing an immutable snapshot: the assignment names an explicit SHA and a copy path you must treat as read-only (nothing on disk enforces that — it is a behavioural constraint, and the other axis is reading the same path). Do every ablation on your own copy of it — the live worktree is off limits, another axis is reading it, and mutating it corrupts both reviews. If a check has to shell out to git, make that copy with `git worktree add --detach` or `git clone --local --no-hardlinks` rather than a plain `cp -r`, so the copy is a real repository. State the SHA you reviewed in your report so a stale result is identifiable later."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings **across** the two axes — they are deliberately separate (see _Why two axes_).

You are the filter the sub-agent briefs defer to, and it operates **within one axis only**: order that axis's findings by the severity and confidence the sub-agent tagged, and if you drop or fold any of them, say which and why in that axis's section. Silently discarding a reported finding defeats the point of removing the output cap.

End with a one-line summary: the pinned `<review_sha>` both axes reviewed, total findings per axis, and the worst issue _within each axis_ (if any). Without the SHA the whole pin is unauditable at the last step. Don't pick a single winner across axes — that's the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
