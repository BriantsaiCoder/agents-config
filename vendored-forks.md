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
| `ask-matt` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — keep the router thin and point phase/context transitions to the canonical shared continuation contract instead of vendoring a second authority; tree SHA-256 `beb486c313e815a3381d4fbc1b1a05e935ce6b4d957f7b50dabd0d8c33318d2f` | **Active** |
| `clean-code-dotnet` | github.com/thangchung/clean-code-dotnet | Stage B2 snapshot `7080450`; upstream `a604cf99e618de359cf34c5384a16fe72a5db2f4` | 2026-08-02 — re-adjudicated thin fork: narrow Clean Code triggers, retain a 360-word judgment checklist, keep only self-consistent illustrative SOLID snippets, and remove duplicated async/editorconfig payload; tree SHA-256 `3f1cb3c62da34813c63d3d041feb0287044a5df5047f1cf824d95a25ba8f89b0` | **Active** |
| `design-doc-mermaid` | github.com/SpillwaveSolutions/design-doc-mermaid (v2.0.0) | `SKILL.md` 21,268B — byte-identical to upstream `main` HEAD, last pushed 2025-12-29 | `6daf12c` — −153 lines, pure de-duplication | **Retired to `attic/` 2026-07-25** |
| `diagnosing-bugs` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-01 — add the missing Agent Skill trigger-failure branch before RED-canary handoff; tree SHA-256 `d044ea6809882228085061b89347026b7360e520cc4c68680d8f0eb359da21ba` | **Active** |
| `improve-codebase-architecture` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-19 — report 與 reply prose 預設使用 zh-TW；technical terms、code identifiers、paths 與 domain terms 保持 English 或原文；tree SHA-256 `5e331195ca420e2ea8258ed32fb054043f6ac521fdce99f520822cc8e254b8fc` | **Active** |
| `dotnet-core-expert` | github.com/Jeffallan/claude-skills | Stage B2 snapshot `7080450`; upstream assessed at `e8be415bc94d8d6ebddc2fb50e5d03c6e27d4319` | 2026-08-02 — extract the unique CQRS/MediatR behavior into `dotnet-core-best-practices`, then archive the fork; archived tree SHA-256 `ec640f9552257d643b91a8abb60f8b0ee4fbe59810a88b4def4a92d6a8a2cddb` | **Retired to `attic/` 2026-08-02** |
| `dotnet-test` | github.com/GiantCroissant-Lunar/pigeon-pea | Stage B2 variant of `d62332d0efb2b45be1a6f1350a399149f8ce494e` | 2026-08-01 — route duplicated unit/coverage guidance to the canonical house skill, remove PigeonPea-only files, and retain a portable BenchmarkDotNet procedure; tree SHA-256 `d583ef03da7e559d0f63a599cbc9b57ab942ff1bbe6a23c96d808cc65c085697` | **Retired to `attic/` 2026-08-02** |
| `vueuse-functions` | github.com/serkodev (MIT, Copyright (c) 2026 SerKo) | LICENSE.md only; no upstream revision was ever recorded | 2026-08-02 — **user-authorized override**: the 11-row requirement map and the 6-entry high-frequency index both merged into `vue-best-practices/references/vueuse/INDEX.md`; the use-vs-hand-roll judgment and the SSR/PII guardrails merged into the same file; MIT notice carried with the payload and retained in the archive. Archived tree SHA-256 `95db99f6a5082d25b311154bf6410cf9e7cd3be306417005caf730fc986f8913`（`vendored_tree_sha256 attic/vueuse-functions`，與其他列同公式） | **Retired to `attic/` 2026-08-02** |
| `playwright-best-practices` | github.com/currents-dev/playwright-best-practices-skill | `283d5cbc5d11aac1abda058b16ad22c317d54dc0` (v1.2) | 2026-08-01 — record the curated 44-line router plus local MCP/common/Python references, and remove 18 dead pointers to omitted upstream-only directories; tree SHA-256 `6d62ea8fd597e9fc40475d421f2f98b8c93a5e79b5a8f0ef4339752c24c7fb1f` | **Active** |
| `ui-ux-pro-max` | github.com/nextlevelbuilder/ui-ux-pro-max-skill | `14ddef5c05e52d7c253b8f0129de7bcd1045ae5b` | 2026-08-02 — vendor only the offline core, port Claude-only paths to the shared root, narrow routing ownership, and harden search/persistence; tree SHA-256 `83f5bceecfb9539f780fae0e611fd5627b6cf785f8226afc03bb9ca550f9fa21` | **Active** |
| `web-design-reviewer` | github.com/github/awesome-copilot | `952c4f45a7bba173f32176a2658a03a1a5ad462c` | 2026-08-02 — replace 3,586 words of duplicated framework/checklist material with a thin rendered-page → source → authorized repair → same-viewport verification loop; tree SHA-256 `f7fa17f95793aebd5ce22009d0354ea1e6dd778c227a83077b89832863dde48b` | **Active** |
| `grilling` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — narrow the trigger to an explicit interview request, adopt design-tree/frontier dependency sequencing, retain the canaried one-question HITL default, add re-estimated progress headers, and keep delegated decisions behind a separate action gate; payload SHA-256 `dcbdd6b8968b8ea2f35a56ce4d1be62a90d4421ac0228e379d24d8e9bbb9802f` | **Active** |
| `handoff` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-07-31 — interactively-triggered runs end the reply with a copy-pasteable start prompt for the next session, capped at four lines; payload SHA-256 `94b9c425dbbe1c5b3f788fbea1fd588b6c6fa9f5e1c5b8c2c201c07088204560` | **Active** |
| `qa-tester` | github.com/finos/morphir-dotnet | Stage B2 subset of `90670e94ea038ba5cc453110f2cdc938c578614d` | 2026-07-31 — preserve the four runtime skill files and omit upstream `README.md`; tree SHA-256 `eeadca3b6b0246f3350d908ba8cb2d461aef4c667a12fa494325270f375c2624` | **Removed 2026-08-01** |
| `prototype` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — adopt the self-contained HTML logic demo and add the local offline/synthetic-data/no-secret/no-production-build boundary; tree SHA-256 `b58e8a09e2630c9ef3fd009562c33f1cc5770881854550be2767809b631fce4a` | **Active** |
| `triage` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — delegate question cadence to the canonical `grilling` contract instead of copying one-at-a-time or rounds behavior into the caller; tree SHA-256 `f627c556c9ced84f0f8cb529011655b28e85d77c8804bbb9c1cbfe0fdfe73be4` | **Active** |
| `writing-for-agents` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — generalize the local authoring contract to Agent Skills, AGENTS.md, CLAUDE.md, and pointed-at docs while preserving RED ownership, host invocation metadata, the glossary, thin-kernel ownership, and pinned provenance precedence; tree SHA-256 `9374753ea57c4512799632b8a2568cebb70e66c017e2ebffaefa691a65767e46` | **Active** |
| `tailwind-v4-shadcn` | github.com/jezweb/claude-skills (v1.0.0, per `.claude-plugin/plugin.json`; author Jeremy Dawes, MIT) | `9fdb7f2` baseline — a snapshot of an upstream layout that no longer exists; upstream renamed and restructured it to `plugins/frontend/skills/tailwind-theme-builder` | 2026-07-25 — two factual corrections in `references/common-gotchas.md` §17 and `rules/tailwind-v4-shadcn.md` | **Active** |
| `code-review` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-03 — drop the `Under 400 words` cap from both sub-agent briefs, add the within-axis filter and two house over-engineering baseline rules, and accept v1.2.2 spec terminology; 2026-08-08 — widen that baseline to five rules and add the performance and correctness clauses to the Standards brief; 2026-08-25 — pin the review to an immutable SHA snapshot instead of a moving HEAD (issue #90); tree SHA-256 `840273dbf411352fe1220fbda428b8b5bb6997316c4648d4791df44f8d3be73a` | **Active** |
| `test-gap-analysis` | github.com/dotnet/skills (MIT, .NET Foundation and Contributors) | `4d25f171766a9b852b229540bf9b8a6874ef16db`, `plugins/dotnet-test/skills/test-gap-analysis` | 2026-08-05 — re-point dead sibling-skill pointers, inline the .NET reference, require authorized isolated full-suite empirical mutation with fingerprinted cleanup, and calibrate runtime-equivalent/xUnit cases; tree SHA-256 `a3e8e49626898da48b1640d6c4adda5fa3878d0fc3a5e905b5d32351db634b81` | **Active** |

<!-- fork-index:end -->

Retired entries stay listed: the `attic/` copy still differs from upstream, so anyone restoring it needs this record. `check-vendored.sh` does not scan `attic/`, so a retired entry no longer renders as `VND*`.

## Resolved Stage B2 provenance

- `aspnet-api-architect` is self-owned. Its former lock pointed only to this repository's first
  tracked snapshot (`44c7fd0`, authored by BriantsaiCoder), while a 2026-08-01 GitHub code search
  found zero copies outside BriantsaiCoder repositories. Its lock rows were removed before the
  focused requirements-to-design/tasks-to-scaffold rewrite.
- `native-feel-cross-platform-desktop` (MIT, Copyright (c) 2026 yetone) was never forked — it is recorded here rather than in the
  fork index because `VND*` means "already forked by a recorded decision", and listing an unforked skill there would grant its name a
  permanent `fork_recorded` bypass of the per-file allowlist in `tests/matt-thin-workflow.sh`. **Retired to `attic/` 2026-08-02**,
  byte-identical, no content extracted; the user confirmed no cross-platform desktop work is planned.
- `dotnet-find-bugs` was a byte-identical upstream snapshot from
  `ricoisme/vscode-agents@2b1240abad239703d09875acefd7ae42685c88ff`. Its per-file coverage
  behavior was added to `shared-security-review`. The former `security-review` identity collided
  with native host owners, so the shared owner was renamed first. **Retired to `attic/`
  2026-08-02**: the one deferral condition — the unmigrated matching-binaries/PDB guard — was
  closed by writing it into `dotnet-core-best-practices/references/security-performance.md`
  ("Debugging and diagnostics"). Replacement coverage was re-verified at retirement, not assumed:
  the 11-item security checklist maps onto `shared-security-review/references/{vuln-categories,
  workflow}.md`, and all five runtime-diagnostic tools are in the `dotnet-core-best-practices`
  symptom table, which additionally owns `dotnet-gcdump`, `dotnet-stack`, and the container
  minidump environment variables the retired skill never carried.

### Where the retired payloads went

Relocation notes are recorded here, **not inside the archived payloads**. Appending a note to an archived
`SKILL.md` changes its tree hash: the 2026-08-02 first attempt did exactly that and silently invalidated the
recorded fingerprint of `attic/dotnet-test` (`d583ef03…`) while also breaking the "byte-identical upstream
snapshot" claim for `attic/dotnet-find-bugs`. Both were reverted; `attic/pinia` and `attic/vue-debug-guides`
keep their inline notes because they are self-owned and carry no pinned fingerprint.

| Archive | Payload now lives at |
|---|---|
| `attic/dotnet-find-bugs` | matching-binaries/PDB precondition → `skills/dotnet-core-best-practices/references/security-performance.md`; per-file attack-surface mapping → `skills/shared-security-review/references/changed-file-attack-surface.md` |
| `attic/dotnet-test` | `skills/dotnet-testing-best-practices/references/benchmarks.md` |
| `attic/vueuse-functions` | `skills/vue-best-practices/references/vueuse/` (INDEX.md + LICENSE.md) |
| `attic/native-feel-cross-platform-desktop` | nothing extracted — retired byte-identical |

**Known trigger-surface gap.** `errorCaptured` / `app.config.errorHandler` survived the merge as *content*
(`skills/vue-best-practices/references/debugging/INDEX.md`) but not as a *trigger word* — the retired
`vue-debug-guides` description carried it and the merged `vue-best-practices` description does not (497/500 words,
no headroom). "my `errorCaptured` hook isn't firing" has no description-level route and only lands once the user
is already inside `vue-best-practices`. Accepted: one narrow symptom against three words of budget.

### Re-merge procedure for `vueuse-functions` (if it is ever restored)

1. Diff `attic/vueuse-functions/SKILL.md` against the current upstream skill; no revision was ever pinned, so treat the archive as the baseline.
2. The requirement map, high-frequency index, guardrails, and MIT notice all live in `skills/vue-best-practices/references/vueuse/`. Re-merge means
   reconciling upstream changes into that file, not restoring the directory.
3. Only restore it as a separate skill if the corpus reverts the Vue consolidation; a restored copy re-enters the vendored gate as plain `VND`.

## clean-code-dotnet

**Decision (2026-08-02): supersede the preservation-only record with a re-adjudicated thin fork.**

The upstream still ends at `a604cf99e618de359cf34c5384a16fe72a5db2f4`. The imported main file
spent 1,899 words on generic examples, repeated the five SOLID examples already disclosed in
`references/solid-principles.md`, claimed general C# review/write triggers, and carried async and
`.editorconfig` payload already owned by stack skills and repository enforcement. A one-section
trim would still leave 1,529 words while paying the same fork cost, so the recorded override keeps
only the judgment-heavy readability checklist and explicit ownership boundaries.

The thin main file is 360 words. Its three-case Claude collision canary stayed 3/3 before and after:
explicit Clean Code/SOLID fires, ASP.NET Core DI routes to `dotnet-core-best-practices`, and xUnit
authoring routes to `dotnet-testing-best-practices`. The exact payload and tree remain pinned in
`vendored-skills.lock`.

The retained SOLID reference is explicitly illustrative: placeholder methods throw instead of
silently omitting required returns, generic examples no longer assume ABP registration, and
render-only methods use `void`.

### Re-merge procedure (when upstream moves)

1. Compare the full upstream skill against the assessed revision and this thin checklist.
2. Pull only new judgment-heavy Clean Code failure shields. Keep framework, async, UI, testing,
   formatting, analyzer, and repository-style guidance with their named owners.
3. Preserve the narrow fire/quiet cases and the disclosed SOLID reference; do not restore duplicate
   examples to the main file.
4. Recompute both fingerprints and run `tests/vendored-detection.sh`,
   `tests/matt-thin-workflow.sh`, relative-reference checks, and the three-case trigger canary.

---

## dotnet-core-expert

**Decision (2026-08-02): retire the recorded fork to `attic/dotnet-core-expert`.**

The imported payload differs from upstream in its Controllers guidance, workflow, and templates.
Its unique portable CQRS/MediatR rules now live in
`dotnet-core-best-practices/references/architecture-di.md`; Controllers, auth, EF Core, deployment,
and templates already have narrower owners. The archived copy preserves the full fork and history.

### Restore procedure

1. `git mv attic/dotnet-core-expert skills/dotnet-core-expert`.
2. Restore its prior rows in `stage-b2-skills.lock` and `vendored-skills.lock`, set the index status
   to Active, and reassess overlap with the canonical .NET skills.
3. Recompute fingerprints and run `tests/vendored-detection.sh`,
   `tests/matt-thin-workflow.sh`, and `tests/version-tripwire.sh`.

---

## dotnet-test

**Decision (2026-08-01): retain only the portable value as a recorded fork.**

The imported entrypoint and two references assumed PigeonPea's `./dotnet` layout, solution,
projects, test names, and a missing `dotnet-build` skill. Unit-test/coverage procedures are already
owned by `dotnet-testing-best-practices`; the fork now routes there and keeps the unique
BenchmarkDotNet baseline/statistics procedure. The full local payload and tree are pinned in
`vendored-skills.lock`.

### Re-merge procedure (when upstream moves)

1. Compare the full upstream skill against the assessed revision.
2. Retain the house route and benchmark reference only while upstream remains repo-bound or the
   canonical testing skill still omits benchmark interpretation.
3. Recompute both fingerprints and run `tests/vendored-detection.sh` and
   `tests/matt-thin-workflow.sh`.

---

## ui-ux-pro-max

**Decision (2026-08-02): vendor the complete offline core as a recorded portability and security fork.**

The core keeps the upstream data, search engine, references, tests, and MIT license. The full plugin
suite is deliberately excluded: its six sibling skills overlap existing shared/host capabilities,
and its global installer would create additional trigger owners outside this repository's routing.

Five local changes are intentionally small:

1. Replace the 1,805-word Claude-specific entrypoint with a 383-word shared router using
   `$HOME/.agents/skills/ui-ux-pro-max`; stack skills own implementation and
   `web-design-reviewer` owns rendered-page QA.
2. Surface missing/corrupt search data as errors instead of plausible defaults, and reject
   non-positive result limits at the API and CLI boundaries.
3. Refuse persistence through symlinked managed paths, preserve existing Master/page files unless
   `--force` is explicit, and allow either missing target to be created independently.
4. Correct persisted relative links so Master points to `pages/` and page overrides point to
   `../MASTER.md`.
5. Suppress Python bytecode in shipped entrypoints and documented commands so normal use cannot
   mutate the pinned vendored tree or invalidate its fingerprints.

Upstream-only trailing whitespace in `design_system.py` is normalized mechanically so the shared
repository's diff check remains clean.

Approved tree SHA-256: `83f5bceecfb9539f780fae0e611fd5627b6cf785f8226afc03bb9ca550f9fa21`.

### Re-merge procedure (when upstream moves)

1. Fetch the new `.claude/skills/ui-ux-pro-max` tree and verify its license and runtime dependency
   boundary before replacing the pinned payload.
2. Reapply only the thin shared router, fail-loud search/limit validation, persistence safety,
   relative-link corrections, and bytecode suppression that upstream still lacks; never run the
   global installer or import sibling skills as part of this update.
3. Run `validate_data.py`, the bundled unittest suite, relative-reference checks,
   `tests/vendored-detection.sh`, `tests/matt-thin-workflow.sh`, and `bin/ci-local`.
4. Recompute payload/tree fingerprints and update this section plus `vendored-skills.lock`.

### Rollback

1. Revert the installation commit so the core payload, routing, CI step, provenance lock, and fork
   record are removed together.
2. Run `bin/agents-sync --bootstrap` followed by `bin/agents-sync --doctor`; this removes the stale
   Claude symlink while Codex and Copilot immediately return to the remaining shared tree.
3. Start fresh host sessions and verify `ui-ux-pro-max` is absent. If a host has no resolver/list
   command, record `UNAVAILABLE` with that probe instead of claiming PASS.

---

## web-design-reviewer

**Decision (2026-08-02): retain the unique visual repair loop as a recorded thin fork.**

The upstream payload mixed generic visual checklists, framework-specific snippets, browser details,
and release verification into a 3,586-word skill. Those concerns already belong to
`css-ui-best-practices`, `playwright-best-practices`, and `frontend-release-verification`. The fork
keeps only rendered-element reverse lookup, authorization-aware source repair, same-viewport
before/after evidence, shared-CSS regression checks, and the three-attempt stop condition.

### Re-merge procedure (when upstream moves)

1. Compare behavior, not file count, against the assessed upstream revision.
2. Pull only new visual-to-source failure shields absent from the thin loop; keep generic CSS,
   framework, accessibility, browser, and release procedures with their canonical owners.
3. Recompute payload/tree fingerprints and run trigger, relative-reference, word-budget, and
   vendored-detection gates.

---

## playwright-best-practices

**Decision (2026-08-01): record the existing curated fork rather than wholesale-expand it.**

Upstream v1.2 ships a 303-line entrypoint and more than 60 detailed references. The local payload
uses a 44-line high-signal workflow, three local references, and a current-doc escape hatch. A
wholesale replacement would restore the structural links but multiply always-read routing prose
and remove the local MCP/Python branches. Recording the fork makes the existing divergence
reviewable instead of silently treating a LICENSE-only payload as pristine upstream. The local
references also omit pointers into upstream directories that are intentionally not part of this
curated payload; their adjacent examples remain self-contained.

### Re-merge procedure (when upstream moves)

1. Compare upstream's full activity map and the three local references by behavior, not file count.
2. Pull only new failure shields that are absent from the local corpus; keep version-sensitive API
   detail in official docs.
3. Recompute both fingerprints and run `tests/vendored-detection.sh`,
   `tests/matt-thin-workflow.sh`, and `tests/relative-references.sh`.

---

## qa-tester

**Decision (2026-08-01): removed from `skills/`.** Wholesale removal is legal under the vendored
gate; this supersedes the preservation decision below without overturning its record.

- Grounds: the skill is bound to FINOS `morphir-dotnet` (its `description` opens with
  "Specialized QA testing for morphir-dotnet"; 30 in-body references to that repo's layout), and
  its four relative references resolve to `/Users/pochientsai/docs/content/contributing/qa/*`,
  which does not exist here. No local checkout of `morphir-dotnet` exists to move it to.
- Cost it was carrying: 2473 effective words — the largest skill in the corpus.
- **Restore when**: this machine gains a `morphir-dotnet` checkout. Restore with
  `git checkout <commit-before-removal> -- skills/qa-tester` plus its `vendored-skills.lock` /
  `stage-b2-skills.lock` rows, then re-add `qa-tester` to the `for fork in ...` list in
  `tests/matt-thin-workflow.sh` and bump the two count assertions back.
- Step 6 A/B canary was **not** run (read-only audit scope); removal was authorised directly by
  the user on 2026-08-01 after a domain-scope review.

**Superseded decision (2026-07-31): preserve the Stage B2 runtime-only subset as a recorded fork.**

The four local files are content-identical to FINOS `morphir-dotnet` at the assessed revision.
The local skill omits only upstream `README.md`; payload and tree are pinned in
`vendored-skills.lock`.

### Re-merge procedure (when upstream moves)

1. Compare the four runtime files and upstream `README.md` against the assessed revision.
2. Keep omitting `README.md` only while it remains non-runtime documentation.
3. Recompute both fingerprints and run `tests/vendored-detection.sh` and
   `tests/matt-thin-workflow.sh`.

---

## Pinned Matt set — 13 unmodified + 9 recorded forks

**`mattpocock/skills` selected 22 — active, rebased to v1.2.2 on 2026-08-06.**

- Source: `https://github.com/mattpocock/skills.git` at `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (`v1.2.2`).
- Upstream manifest: `.claude-plugin/plugin.json` SHA-256 `85a5f2ad87b1070c13a97a9379887fc43e5e786a0ab7a3c0f0281d2b30f523b2` (25 published skills).
- Machine-readable inventory: `mattpocock-skills.lock`; only its 22 `skill=` entries are active.
- Excluded from the 25 published skills: `wizard` (credential/migration side-effect generator overlaps protected house gates), `wait-what` (personal communication modifier, not engineering workflow), and `to-questionnaire` (unneeded outward async-document flow overlapping existing clarification routes). Re-entry requires a new decision record and canary.
- The 13 entries other than `ask-matt`, `code-review`, `diagnosing-bugs`, `grilling`, `handoff`, `improve-codebase-architecture`, `prototype`, `triage`, and `writing-for-agents` are byte-for-byte upstream and immutable.
- The nine recorded forks have exact payload fingerprints and re-merge procedures below.
- Update by replacing the full pinned set after lock/hash verification, then reapply only recorded forks. Any additional local payload edit requires a new decision and fingerprint.

2026-08-06 rebase 的歷史 evidence 同時釘住 local commit
`d2e78888787e1bd0534cff363442e336e5c609d9` 與 upstream commit
`8b36d4fb2635b3c21998dcd8144439c9e5ba7302`。在該 local commit 的 clean checkout 執行
`bash tests/matt-thin-workflow.sh`，預期末行為 `PASS: Matt thin workflow contract`；執行
`git show d2e78888787e1bd0534cff363442e336e5c609d9:mattpocock-skills.lock | grep -c '^upstream_tree_sha256='`，預期為 `14`。
當次 lock/local/upstream `vendored_tree_sha256` replay 為 `14 PASS / 0 FAIL`。該次 rebase 中
四個 visibly changed 的 upstream-identical trees 為
`setup-matt-pocock-skills=20fabc63…`, `tdd=807b29b3…`, `to-spec=7fe9db6b…`, and
`wayfinder=8c91f90c…`; their complete hashes are the lock entries above. House tripwires cover
selected upstream behavior in setup, TDD, spec terminology, wayfinder, and caller cadence; if a
later upstream revision changes one, re-run the upstream comparison and make a fork decision
instead of merely weakening the test. The follow-up grilling PR advanced `WORKFLOW_BASE` to the
landed rebase and removed the temporary assessed-commit and writing-skill rename exceptions.

### improve-codebase-architecture

**決策（2026-08-19）：記錄 zh-TW output fork。**

此 fork 新增一份 user-facing replies 與 generated HTML reports 共用的 language contract，並將
report scaffold、labels、examples 與固定 follow-up prompts 在地化。technical terms（包含
`/codebase-design` architecture vocabulary）、code identifiers、paths 與 domain terms 保持 English 或原文。
Invocation 維持 explicit-only；frontmatter 與 `agents/openai.yaml` 不變。

#### Re-merge procedure（upstream 更新時）

1. 將完整 upstream skill 與 `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` 及此 fork 進行 diff。
2. 若 upstream 尚未採用等效的 zh-TW default，只重套 language contract 與 report localization；
   architecture vocabulary 仍由 `/codebase-design` 維護。
3. 保留 explicit-only invocation metadata，並確認所有 relative references 仍可解析。
4. 重新計算 tree fingerprint，並執行 `tests/vendored-detection.sh`、
   `tests/matt-thin-workflow.sh`（包含 language canary）及 `tests/conformance.sh`。

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

**13 skills — removed 2026-08-01 after a domain-scope review.** Zero local modification; all were
byte-identical Stage B2 vendored payload. Their rows were deleted from `vendored-skills.lock` and
`stage-b2-skills.lock` in the same commit.

| Skill | Upstream | Why removed |
|---|---|---|
| `analyzing-financial-statements` | anthropics/claude-cookbooks | Out of domain. Also defective: `calculate_ratios.py` collapses missing values and zero denominators to `0.0`, so a company with +150,000 net income reports `Negative returns` and a balance sheet holding only `current_assets` yields "conservative leverage"; benchmarks in `interpret_ratios.py` are hardcoded with no source |
| `data-storytelling` | wshobson/agents | Out of domain (stakeholder analytics narrative) |
| `youtube-downloader` | ComposioHQ/awesome-claude-skills | Out of domain. Also defective: `download_video.py:19` silently runs `pip install --break-system-packages` (called unconditionally at :44), and hardcodes `/mnt/user-data/outputs` at :33/:110/:111 — a container path that does not exist on macOS |
| `connection-properties` | microsoft/aspire | Repo-specific to Aspire |
| `vscode-ext-commands` | github/awesome-copilot | Owner does not build VS Code extensions |
| `vscode-ext-localization` | github/awesome-copilot | Same |
| `create-mcp-app` | modelcontextprotocol/ext-apps | Owner does not build MCP servers/apps |
| `appinsights-instrumentation` | github/awesome-copilot | No Azure work in scope. Also carried 2 broken references: `references/ASPNETCORE.md` links to `scripts/appinsights.ps1` without a `../` prefix, so both resolve to a non-existent `references/scripts/` path (the script itself was vendored correctly at the skill root) |
| `azure-resource-visualizer` | github/awesome-copilot | No Azure work in scope |
| `azure-role-selector` | github/awesome-copilot | Same |
| `azure-static-web-apps` | github/awesome-copilot | Same |
| `github-issues` | github/awesome-copilot | **Non-functional here**: `SKILL.md:8` requires `@modelcontextprotocol/server-github` and its body calls `mcp__github__*`; none of the three hosts has a github MCP server configured (verified in `~/.codex/config.toml`, `~/.copilot/mcp-config.json`, and the Claude tool surface). GitHub work here goes through the `gh` CLI |
| `webapp-testing` | github/awesome-copilot | Superseded: `playwright-best-practices/references/python-tooling.md:5` already records "Merged from: `webapp-testing`", and `agent-browser` covers browser control |

For those 13 removals, the Step 6 A/B canary was not run: their 2026-08-01 audit was read-only,
and the user authorised removal directly on domain-scope grounds rather than usage telemetry.

**4 skills — archived unchanged on 2026-08-02 after behavior-preserving consolidation.**

| Skill | Upstream | Why archived |
|---|---|---|
| `clarify` | team-attention/plugins-for-claude-natives | Requirement clarification already routes through `grilling` plus the global ambiguity stop gate; keeping both created competing interviews |
| `csharp-developer` | Jeffallan/claude-skills | General C# is covered by the modern/legacy .NET owners; its remaining Blazor/MAUI/SignalR persona is outside the owner's declared technology scope |
| `make-skill-template` | github/awesome-copilot | All three hosts expose a native skill creator, so a fourth template owner only creates drift |
| `nuget-manager` | github/awesome-copilot | SDK-style NuGet/CPM is already covered by `dotnet-core-best-practices`; a thin `packages.config` branch was added to `dotnet-framework-best-practices` |

**Restore any of them with**: `git checkout <commit-before-removal> -- skills/<name>`, then re-add its
row to both lock files. For the four tracked attic copies above, prefer
`git mv attic/<name> skills/<name>`. Update the exact inventory and regression tripwires in
`tests/vendored-detection.sh` and `tests/matt-thin-workflow.sh` in the same change.

**2026-08-02 candidate canary:** after deferring `dotnet-find-bugs` retirement, Claude scratch
bootstrap/doctor resolves 76/76 active links, with zero retired identities and all replacement
owners present (**PASS**). Copilot resolves 76 candidate personal skills, zero retired identities,
one retained `dotnet-find-bugs`, and all replacement owners (**PASS**). The
Codex CLI exposes no local skill-list command (**UNAVAILABLE**); its user-only policy check passed
12/12. Live trigger evaluation passed 15/15 measurable new fire/quiet cases; the candidate
`security-review` case was **UNAVAILABLE** because Claude's same-named built-in won the namespace,
so `dotnet-find-bugs` remains active and that result was not converted into a false PASS.

**2026-08-02 namespace migration canary:** the self-owned focused reviewer moved to
`shared-security-review`; no compatibility alias remains. Claude Code 2.1.220 loaded the full
76-skill candidate corpus and passed 5/5 exact-identity, natural-fire, attack-map, CI-quiet, and
runtime-quiet cases. The first natural-fire run exposed a `security-audit` collision; one focused
trigger clause turned that preserved RED case GREEN, and the complete rerun passed. Codex 0.146.0
and Copilot 1.0.75 still lack a machine-readable named invocation observable here, so both remain
**UNAVAILABLE**, not PASS. At this gate, `dotnet-find-bugs` stayed active pending the separate
archive decision recorded below.

**2026-08-02 post-migration retirement gate:** a temporary A/B corpus pinned to `main@c77d29f`
contained 76 current skills in A and a byte-identical 75-skill B with only `dotnet-find-bugs/`
omitted. B kept `shared-security-review`, `dotnet-core-best-practices`, `diagnosing-bugs`, and
`code-review`; 469 relative references passed. The gate failed before model-quality scoring:
the original still uniquely warns that accurate stack analysis may require matching binaries/PDBs.
That non-empty unique-behavior inventory is the decisive Step 6 failure. Complete removal also
changes the public route from explicit identity present (`1`) to absent (`0`); this is recorded as
an expected compatibility impact, not scored circularly as a deletion regression. Codex and Copilot
named invocation remain **UNAVAILABLE**. Final verdict: **retain active**; no archive or live mutation
was performed, and model turns were skipped after the decisive unique-value failure.

Probe from the repository root (Bash or Zsh):
`skills/auditing-skill-folder/scripts/eval-triggers.sh --runner claude --cases <(jq -c 'select(.skill == "shared-security-review")' skills/auditing-skill-folder/evals/cases.jsonl) --skills skills`.
Expected output includes `# arm=collision  skills loaded=76  runner=claude` and
`cases=5  pass=5  fail=0  skipped=0  err=0`.

**`ecpay` — retired to `attic/` 2026-07-25.**

- Upstream `github.com/ECPay/ECPay-API-Skill.git`, detached at `5b1ac76` (2026-07-07), per `attic/ecpay/UPSTREAM.txt`.
- LICENSE is **All Rights Reserved**, Copyright (c) 2025-2026 綠界科技股份有限公司 — not open source. It may be kept locally but not redistributed.
- **Zero local modification**: `git log --follow -- skills/ecpay/SKILL.md` shows one commit (`9fdb7f2`, the baseline import). The `attic/` copy is byte-identical to what was vendored, so no re-merge procedure is needed — restoring means re-cloning upstream or `git mv attic/ecpay skills/ecpay`.
- Removed on user instruction while trimming the resident skill listing. Wholesale removal is legal under the vendored gate — what is forbidden is editing in place.
- Cost it was carrying: 319 chars of name+description in every session's skill listing (2.9MB / 295 files on disk, which cost nothing resident).
- **Restore when**: a project actually integrates ECPay 金流 / 電子發票 / 物流. The knowledge is 綠界-specific and not model-stable — 12-language CheckMacValue / AES vectors, ECPG vs ecpayment dual-domain traps, per-service test MerchantIDs. Nothing else in `skills/` covers it.

---

## ask-matt

**Decision (2026-08-06): retain a thin router while rebasing to v1.2.2.**

Upstream adds a second, detailed phase-boundary tree. The shared `dev-workflow` already owns
continuations and authorization, so the local router carries one context pointer to
`references/routing-continuations.md` and omits `PHASE-BOUNDARIES.md`. The pointer also states that
routing does not grant implementation authorization.

The router retains `/handoff` in its standalone index while leaving phase-boundary behavior with the
canonical continuation owner.

Approved tree SHA-256: `beb486c313e815a3381d4fbc1b1a05e935ce6b4d957f7b50dabd0d8c33318d2f`.

On upstream update, start from the new `ask-matt/`, omit any duplicate phase-boundary body, keep the
canonical continuation pointer, update renamed selected skills, then recompute the tree fingerprint.

---

## prototype

**Decision (2026-08-06): adopt the v1.2.2 HTML logic demo with one local safety boundary.**

The upstream universal HTML/JavaScript branch is retained even for non-JavaScript projects because
its artifact opens without a project runtime. The local addition keeps fixture data synthetic and
the artifact offline, excluding CDN, external network requests, remote assets, secrets, and
production build-path dependencies. Existing prototype branch capture and non-production rules
remain unchanged.

Approved tree SHA-256: `b58e8a09e2630c9ef3fd009562c33f1cc5770881854550be2767809b631fce4a`.

On upstream update, replace the directory, reapply the single offline boundary only if absent, run
relative-reference checks and `tests/mattpocock-workflow.sh`, then recompute the tree fingerprint.

---

## triage

**Decision (2026-08-06): make the caller cadence-neutral.**

`triage` invokes `grilling` and `domain-modeling`, but the canonical `grilling` contract owns whether
questions are asked singly or in independent rounds. This prevents callers from drifting whenever
the interview cadence changes.

Approved tree SHA-256: `f627c556c9ced84f0f8cb529011655b28e85d77c8804bbb9c1cbfe0fdfe73be4`.

On upstream update, keep the cadence-neutral pointer unless upstream has equivalent wording, then
recompute the tree fingerprint and run the Matt workflow tests.

---

## code-review

**Decision (2026-08-03): remove the sub-agent output cap, and give the aggregate step the filter the briefs now defer to.**

Step 4's two sub-agent briefs both ended `Under 400 words.` A reviewer follows an output cap
literally and reports less, so the cap suppressed recall inside the sub-agent — and step 5's
no-merge/no-rerank rule meant nothing downstream could recover what a sub-agent had already
dropped. The local change replaces the cap in both briefs with report-everything plus per-finding
severity and confidence, and adds one paragraph to step 5 defining the within-axis filter those
briefs point at (order by severity/confidence; disclose anything dropped). The cross-axis
separation — the reason the skill has two axes at all — is deliberately untouched, and [S5-4] in
`skills/dev-workflow/SKILL.md` states that it does not override it.

**Decision (2026-08-03, same fork): carry the two house over-engineering baseline rules.**

`[S5-3]` names this skill's Standards axis as the FIRST of its three targets, but only the other
two ever received the rules — the Standards brief was left prose-only because editing a vendored
skill was barred. That bar lifted the same day, when the [S5-4] change above made this a recorded
fork. The rules go into the step-3 smell baseline rather than the brief text, because step 4
already pastes that baseline into the Standards sub-agent verbatim; one insertion point, no
duplication. Both binding rules of that baseline (repo overrides; always a judgement call) apply
to them unchanged.

The v1.2.2 rebase also accepts upstream's PRD-to-spec terminology cleanup without changing either
review axis.

**Decision (2026-08-08, same fork): the baseline widens from two rules to five.**

The two rules carried above (Reinvented Stdlib, Redundant Dependency) are both reuse-of-platform
checks. Nothing in them catches reuse of *this repo's own* assets, a one-use indirection layer, or
a decision sitting at the wrong abstraction level. `[S5-3]` now names five rules and this fork
carries all five in full.

Mapping the overlapping rule onto the Fowler list above was tried and rejected as not equivalent —
the boundary is written into the entry itself rather than restated here.

The same edit adds performance and correctness to the Standards sub-agent brief. The house baseline
leaves efficiency out on the grounds that the reviewer's priority list already carries it — sound
for the host-neutral template, which has such a list, but this skill never did. Walking that list's
five levels against this path: security routes to `shared-security-review` via S0, so it has a home
elsewhere; performance and correctness had nowhere to land at all and are now clauses (c) and (d)
of the step-4 Standards brief — adding only performance would have left the same hole one level
down, for the same reason.

Two levels remain **known gaps, recorded and not fixed**. Breaking changes: `deps-check` is a
pre-edit caller-enumeration tool scoped to TS/JS and C#, not an S5 detector, and it says nothing
about the data-contract clause — the earlier claim that it gave that level a home does not hold.
Stack-specific checks: the Fowler list above is structural (Mysterious Name, Feature Envy, Middle
Man …) and covers none of DI lifetime mismatch, middleware order, `useEffect` cleanup, or `any`
leaking across a boundary; on the Claude path those reach a stack-specialist agent through S0
routing, which is not this brief. Closing either is its own decision, not a side effect of this one.

2026-08-25 (issue #90) — pin the review to an immutable SHA snapshot instead of a moving `HEAD`.
Step 1 resolves `HEAD` once and builds the snapshot with `git worktree add --detach`; both step-4
briefs carry the SHA, the snapshot path, and the instruction to make git-capable copies rather
than `cp -r`; step 5 reports the reviewed SHA. `git archive | tar` was rejected as the snapshot
mechanism because it exits 0 on a bad ref and leaves an empty directory — both axes would then
review nothing and both return PASS. Reapply on upstream update: without the pin, a review that
runs for tens of minutes silently retargets whenever the branch moves.

Approved tree SHA-256: `840273dbf411352fe1220fbda428b8b5bb6997316c4648d4791df44f8d3be73a`.
Driving rules: `[S5-4]` and `[S5-3]` in `skills/dev-workflow/SKILL.md`.

On upstream update, drop this fork if the new step-4 briefs carry no output cap and step 5 already
defines a within-axis filter; otherwise reapply every edit listed here — delete any word/finding-count
limit from every sub-agent brief, keep the report-everything + severity/confidence wording, re-add
the within-axis filter paragraph to the aggregate step, re-narrow step 5's `Do not merge or rerank
findings` to `**across** the two axes` (without that word it contradicts the within-axis filter
added one line earlier), re-add all five baseline rules to the step-3 smell baseline, re-add the
performance and correctness clauses to the Standards brief, and re-add the sentence stating that
step 4 pastes the baseline into the Standards sub-agent only (dropping it re-opens the "mandatory
in every reviewer prompt" mismatch with `[S5-3]`) — then recompute
the tree fingerprint with
`vendored_tree_sha256 skills/code-review` and update both this section and the index row. If
upstream renumbers the steps, re-anchor on the brief text and the `## Standards` / `## Spec`
aggregate headings rather than the step numbers.

---

## diagnosing-bugs

**Decision (2026-08-01): add one trigger branch for Agent Skill invocation failures.**

The generic upstream description names broken, failing, flaky, and slow software, but not an Agent
Skill that fires unreliably. Routing canaries therefore let `writing-for-agents` steal the first
step even though the canonical workflow requires a RED trigger canary first. The local change adds
only that missing description branch; the body is untouched.

The v1.1→v1.2.2 upstream comparison is empty: `git diff --exit-code ed37663cc5fbef691ddfecd080dff42f7e7e350d 8b36d4fb2635b3c21998dcd8144439c9e5ba7302 -- skills/diagnosing-bugs` returned 0.

Approved tree SHA-256: `d044ea6809882228085061b89347026b7360e520cc4c68680d8f0eb359da21ba`.
Evidence and the 21:00 control are recorded in
`proposals/2026-08-01-two-skill-tuning-audit/02-writing-great-skills.md`.

On upstream update, drop this fork if the new description carries an equivalent Agent Skill
trigger-failure／RED-canary branch; otherwise reapply the one-line description change and recompute
the tree fingerprint.

---

## grilling

**Decision (2026-08-04): keep the existing fork and add visible progress estimates to every question.**

Every question starts with `Question N of ~M — <topic>`, where `M` is a running estimate that may be
revised as new decision-tree branches surface. The estimate communicates progress without changing
the one-question-at-a-time flow.

The default remains a live HITL exchange. The user may explicitly open a delegated, non-HITL branch
where the selected model answers every decision it can and asks only when blocked. In that branch the
agent processes decisions in dependency order, adopts defensible recommendations, and asks only for
an unavailable material fact or user-only constraint, a user-only preference or authority, or a
low-confidence choice with material downside. Callers that require live HITL stay interactive unless
the user explicitly overrides that requirement. Risk changes the action gate rather than whether the
model can answer; scope expansion and implementation remain separately authorized.

The earlier 2026-08-02 description-only change added explicit under-specified/clarify routing so the
byte-identical `clarify` skill could retire without losing one-at-a-time requirement interviews. It
left the body unchanged; the 2026-08-03 delegated-decision change became the behavior fork, and this
2026-08-04 progress-header rule extends it. The global ambiguity gate alone was insufficient because
an explicit "clarify this" request did not auto-invoke this skill in the RED canary.

**Decision (2026-08-04, later the same day): narrow the trigger to an explicit user request.**

The 2026-08-02 widening also made routine requirement clarification route here, and the trailing
"or uses any 'grill' trigger phrase" matched conversations *about* this skill. A live Step 2c canary
measured the cost: of three grilling prompts, the two that should have stayed quiet both fired
(precision 0.33) — one of them a request to analyse whether the global workflow should keep using
grilling at all, which the trigger read as a request to be grilled. The description now requires an
explicit ask, excludes routine clarification that plan mode covers, and excludes discussions where
grilling itself is the topic. The wording matters more than it looks: a first attempt that still led
with "explicitly asks to clarify unresolved decisions in an under-specified plan" fixed the
meta-discussion case but left routine clarification firing (precision 0.50), because "under-specified"
reads as a trigger on its own. Only when the explicit request for the interview became the trigger —
with vagueness demoted to a routed-away condition — did all three cases pass (precision 1.00). Keep
that shape on any re-merge. The trigger stays natural-language and model-invocable: `clarify`'s
retirement depends on an explicit "clarify this" still reaching this skill without a slash command,
and `/grill-me` remains the separate explicit-command entry point. The body is unchanged — cadence is
handled by the kernel's Claude adapter, which routes decision questions through `AskUserQuestion`.

**Decision (2026-08-06): adopt design-tree/frontier sequencing, not frontier rounds.**

The skill now maps eligible questions onto the current frontier and defers dependent decisions until
their prerequisites are settled. The default remains one live question at a time. A cross-host
canary for rounds passed on Codex (`019fd5c7-79a2-7842-8a31-65b3cff20a3d`), but Claude was
`UNAVAILABLE` (`401 OAuth access token has expired`) and Copilot was `UNAVAILABLE` after a bounded
timeout with no output. Because the canary did not pass on all three hosts, the PR keeps the proven
HITL cadence while absorbing the upstream dependency model and completion criterion.

### Re-merge procedure (when upstream moves)

1. Diff the new upstream `grilling/SKILL.md` against pinned commit
   `8b36d4fb2635b3c21998dcd8144439c9e5ba7302`.
   This baseline contains design-tree/frontier rounds; the local fork keeps the design-tree/frontier
   model but deliberately retains one-question HITL unless a later three-host canary passes.
2. Replace the pinned Matt set normally, then reapply the progress-header rule,
   delegated-decision paragraphs, and clarify trigger only if upstream still lacks equivalent behavior.
3. Run `tests/matt-thin-workflow.sh`, `tests/vendored-detection.sh`, and the skill validator.
4. Update the fork index's upstream commit; remove this record if upstream fully absorbs the behavior.

---

## handoff

**Decision (2026-07-31): accept the fork.**

The v1.1→v1.2.2 upstream comparison is empty: `git diff --exit-code ed37663cc5fbef691ddfecd080dff42f7e7e350d 8b36d4fb2635b3c21998dcd8144439c9e5ba7302 -- skills/handoff` returned 0.

Upstream writes the handoff document to the OS temp directory and stops there. Nothing tells the
user where it landed or what to say next, so the bridge between two sessions depends on the user
noticing the path in the reply and composing the follow-up prompt themselves. The added paragraph
closes that gap: an interactively-triggered run ends with a copy-pasteable start prompt carrying the
document's absolute path, the next session's focus, and the skills to invoke first.

Four constraints are deliberate and must survive any re-merge:

- **`When this run was triggered interactively by the user`** — scopes the behavior to human-driven
  runs. A future automated caller (a workflow `agent()` step, especially one with a `schema`) is
  exempt without needing another edit to this skill.
- **absolute path, not a literal one** — the skill still says "temporary directory of the user's OS".
  `$TMPDIR` differs per host (Claude Code sets `/tmp/claude-<uid>`; Codex and Copilot get the macOS
  default `/var/folders/…`), so the resolved path belongs in the emitted block, never in this file.
- **`nothing else, at most four lines`** — added 2026-07-31 after the first live run. The original
  wording named the three required elements but set no ceiling, and the run produced a four-paragraph
  block that restated environment state already in the document. The cap plus "everything the next
  agent needs beyond that is in the document" is what keeps the block a pointer rather than a summary.
- **`not a machine-parseable contract`** — prevents a downstream script from parsing the block and
  turning a human convenience into an undeclared interface.

Explicitly out of scope for this fork, each its own future decision: a fixed `handoff-latest.md`
filename, a `SessionStart` hook that auto-injects the pending handoff (needs consume-or-expire, or it
leaks a stale handoff into unrelated sessions), and relaxing "temp dir" to a durable path.

Baseline before the fork: `SKILL.md` SHA-256
`57c9f1f392d7352cdc85b1e39ca49eddc70ce1dc278bd9653fb4f23dfc2560fc` (byte-identical to pinned
`ed37663cc5fbef691ddfecd080dff42f7e7e350d`). The fork is +2 lines; nothing upstream was removed or
reworded.

### Re-merge procedure (when upstream moves)

1. Diff the new upstream `handoff/SKILL.md` against pinned commit
   `8b36d4fb2635b3c21998dcd8144439c9e5ba7302`.
2. Replace the pinned Matt set normally, then reapply the final paragraph only if upstream still
   emits no start prompt for the next session.
3. Run `tests/matt-thin-workflow.sh` and `tests/vendored-detection.sh`; confirm `check-vendored.sh`
   renders `handoff` as `VND*`.
4. Update the fork index's payload SHA-256; remove this record if upstream absorbs the behavior.

---

## writing-for-agents

**Decision (2026-08-06): accept the upstream rename and generalize the local contract.**

The current payload covers Agent Skills, `AGENTS.md`, `CLAUDE.md`, and pointed-at documents. It
retains the local RED ownership, model-invocation metadata, branch-aware completion, evidence-gated
leading words, and glossary. `SKILL-MECHANICS.md` carries skill-only packaging; the top level remains
under the 500-word house budget. The live environment informs discoverable facts, while the lockfile
remains authoritative for approved provenance. The shared `dev-workflow` still decides canonical
placement and authorization. Historical decisions below explain the retained skill-authoring fork;
this paragraph supersedes their old name and narrower frontmatter description for current behavior.

**Decision (2026-07-31): accept the model-invocation metadata fork.**
**Decision (2026-08-01): widen the scope to body corrections. Supersedes the above.**
**Decision (2026-08-01, second pass): add trigger ownership and structural trim. Supersedes the above.**
**Decision (2026-08-01, third pass): scope the RED gate, restore the bold-term contract, restore the identity clause, and reconcile this record with what the second pass actually shipped. Supersedes the above.**
**Decision (2026-08-01, fourth pass): restore evidence-gated leading-word discovery and canonical glossary terminology. Supersedes the above.**

The 2026-07-31 decision was scoped to invocation metadata and said "do not extend it". This
decision extends it deliberately, on the strength of a two-round audit
(`proposals/2026-08-01-two-skill-tuning-audit/`) in which every finding survived adversarial
verification and was then re-verified against the live tree. Provenance was excluded from the
judgement by standing instruction; it governs only this landing procedure.

The second pass is backed by fresh Claude, Codex, and Copilot routing canaries recorded in
`proposals/2026-08-01-two-skill-tuning-audit/02-writing-great-skills.md`. The candidate makes host
creators own scaffolding, accepts a valid RED from the folder auditor's Step 2c, sends missing-RED
reproduction to `diagnosing-bugs`, and gives this skill the behavioral rewrite after either handoff.
It replaced the 1,641-word top level with an executable checklist — 427 words as the second pass
landed it, 437 after the third pass restored the identity clause and the bold-term contract — and
makes completion branch-aware instead of forcing a full audit for every scoped edit. The evidence record keeps the
mixed D-route canary as a residual instead of claiming a three-host clean sweep.

The third pass answers a post-landing review
(`proposals/2026-08-01-two-skill-tuning-audit/05-post-landing-review.md`, findings F2/F3/F5) of what
the second pass shipped. It scopes the `diagnosing-bugs` gate to the branch it was written for,
gives the glossary pointer back the term-to-heading contract the trim removed, and restores the
identity clause the skill's own Description rule requires. F1 is actioned as a record correction only:
the two `Reconciliation (F1)` blocks below give every second-pass claim its status in HEAD, with the
two live divergences recorded rather than repaired, because repairing either would widen the fork a
fourth time. F4 (the `_Avoid_:` removal has no canary covering the behavior those lines protected) is
recorded in the review and **not** actioned here.

The fourth pass targets only the leading-word and canonical-terminology evidence gap. A paired,
blind low-reasoning Codex canary used the same prompt against the live third-pass payload and an
isolated candidate. RED returned `LEADING_WORD=NONE` and `CANONICAL_TERMS=NONE`; GREEN returned
`LEADING_WORD=TRACER BULLETS` and mapped three synonyms to the exact glossary headings `Single Source
of Truth`, `Duplication`, and `Completion Criterion`. Claude's live tool-event canary passed positive
and negative routing (`2/2`); isolated candidate-only Codex and Copilot meta-routing each returned
positive `FIRE` and negative `QUIET`. The evaluated draft and output contract, scoring-rule summary,
two rejected prompt-contaminated attempts, resolution limits, and host-canary evidence are in
`proposals/2026-08-01-two-skill-tuning-audit/05-post-landing-review.md`. This does not validate or
restore the 28 removed `_Avoid_:` aliases.

Approved tree SHA-256: `9374753ea57c4512799632b8a2568cebb70e66c017e2ebffaefa691a65767e46`.

### Local changes

**Invocation metadata (carried over from 2026-07-31).** `disable-model-invocation: true` removed;
`agents/openai.yaml` sets `allow_implicit_invocation: true`.

**Frontmatter description (B3, second-pass ownership, third-pass identity).** Identity clause plus
triggers, narrowed to one existing Agent Skill behavioral edit or an already-red rewrite handed off by
another skill. New-skill scaffolding remains with the host creator and directory-wide assessment with
the folder auditor. The body requires a preserved RED, accepts the auditor's Step 2c handoff, and
invokes `diagnosing-bugs` for a misbehavior rewrite when no caller supplied one; the exact ownership
anchors are asserted by `tests/matt-thin-workflow.sh` and `tests/trigger-eval.sh`.

**Reconciliation (F1).** B3's original correction added four diagnostic symptom triggers ("fires
unreliably, sprawls, repeats itself, or lets the agent stop early"). The second pass removed all four,
leaving `pruning` as the only route to the six `_Failure mode._` entries `GLOSSARY.md` still carries.
Recorded, not repaired: restoring them widens the description this decision deliberately narrowed for
ownership, and the paired A/B/C/E canary shows no primary-owner regression without them.

**Body corrections (introduced by the second-pass decision; reconciled against HEAD below).**

| Site | Change | Why |
|---|---|---|
| `SKILL.md` after the predictability line | Added an exhaustiveness bar | The skill declares itself "all reference" and teaches that flat reference still needs one; four of six sections carried no demand, so coverage varied with whichever section the prompt named |
| `GLOSSARY.md` Description / User-Invoked / Router Skill / Context Load / External Reference, and `SKILL.md` Mechanics | Replaced "delete the description" with "withhold it from the agent" across all 6 sites | **Upstream defect.** `GLOSSARY` prescribed deleting the field; `SKILL.md` prescribed setting the flag and keeping it. Verified against this tree: all 12 user-invoked skills retain a populated `description:`. `SKILL.md`'s own line-8 pointer sends the agent to `GLOSSARY` for the authoritative meaning, so the agent following the skill's navigation was told to strip a required field |
| `SKILL.md` Model-Invoked conclusion in `GLOSSARY.md` | Deleted the duplicated sentence | It restated `SKILL.md`'s conclusion and had already dropped "or another skill must", so the two copies gave different rules |
| `SKILL.md` information-hierarchy rung 3 | "External reference" → "**Reference**, disclosed" | The rung's name resolved to a `GLOSSARY` definition that excludes the sibling file the rung offers as its own example |
| `SKILL.md` bold-terms pointer | Added a reaching condition | The skill's own definition says a pointer's wording decides when and how reliably the agent reaches; this one named no when |
| `SKILL.md` user-invoked Mechanics | Added per-host invocation keys | Verified: all 12 user-invoked skills carrying `agents/openai.yaml` set both keys. This skill's own folder carries that file |
| `SKILL.md` leading-word section | Moved the imperative up from `GLOSSARY` | The one instruction the section exists to produce lived only in the on-demand file |
| `SKILL.md` completion-criterion line | "where it matters" → "wherever the work sweeps a set" | An undecidable hedge whose default resolution is to skip the harder half |

**Reconciliation (F1).** The table above states its rows as facts about the deployed payload, but the
same-day structural trim landed after it and changed four of them. Rows are kept with their original
rationale; the status column is what HEAD actually carries.

| Row | Status in HEAD | Evidence |
|---|---|---|
| exhaustiveness bar | **Superseded** — the trim replaced the single exhaustive bar with branch-aware completion (full / scoped / RED→GREEN) | `SKILL.md:12` |
| `GLOSSARY` + `SKILL.md` "withhold the description" | **Active** — all 6 sites carry it; four use non-literal wording ("out of the agent's reach", "the agent sees neither one's description") | `sed -n '/^### /p'` walk of the 5 glossary entries plus `SKILL.md:21` |
| deleted duplicated Model-Invoked conclusion | **Active** | `grep -c "Pick model-invocation" GLOSSARY.md` → 0 |
| rung 3 "External reference" → "**Reference**, disclosed" | **Superseded** — the trim rewrote rung 3 whole; neither phrase survives, and the ambiguity went with them | `SKILL.md:35` |
| bold-terms pointer reaching condition | **Active** — restored and reworded by the third pass | `SKILL.md:14` |
| user-invoked per-host invocation keys | **Active** | `grep -c "allow_implicit_invocation: false" SKILL.md` → 1 |
| leading-word imperative moved up from `GLOSSARY` | **Reactivated by the fourth pass** — `SKILL.md:41` now requires the search while retaining the canary acceptance gate | blind paired RED→GREEN semantic canary plus three-host positive／negative routing evidence |
| completion criterion "wherever the work sweeps a set" | **Active** — reworded to "Criteria that sweep a set are exhaustive" | `SKILL.md:33` |

The diagnostic-description divergence remains recorded, not repaired. The leading-word text gap and
canonical-term contract are repaired by the fourth pass and satisfy the strict paired RED→GREEN
acceptance fixture; no broader alias-restoration claim is made.

**Second-pass structural trim.** `SKILL.md` is now an executable checklist within the 500-word
house budget; `GLOSSARY.md` remains the definition source. Completion is exhaustive for a full
behavioral-authoring/pruning audit, scoped to the named branch for a focused edit, and RED→GREEN for a
misbehavior rewrite. The glossary's 28 `_Avoid_:` negation lists were removed, and `Legwork` now
uses `_relentless_` rather than presenting `_thorough_` as both weak and effective.

**Third-pass corrections.** Applied on top of the trim; each is house-authored, not an upstream defect.

| Site | Change | Why |
|---|---|---|
| `SKILL.md` `REQUIRED SUB-SKILL` line | "When no caller provides that RED" → "For a misbehavior rewrite with no caller-supplied RED" | The gate read unconditionally while its branch scoping arrived two paragraphs later, so a scoped metadata edit was routed through `diagnosing-bugs`. Paired `fire-writing-skill-user-only` / `quiet-diagnosing-skill-user-only` cases now fix that boundary, asserted in `tests/trigger-eval.sh` |
| `SKILL.md` glossary pointer, plus 13 term sites | Restored the term-to-heading contract and the bold markers | The trim deleted the original "**Bold terms** are defined in `GLOSSARY.md`" contract along with 43 markers, but kept a pointer that presupposes the agent can still identify headings; 11 glossary terms sat bare in the body. Every bold term now resolves to a matching `###` heading, `completion criterion` included (the plural did not). The contract is worded "Every bold term **below**" and is itself unbolded, because the two `REQUIRED` labels above it are bold and are not headings — an unscoped contract would have made its own file a counterexample |
| `SKILL.md` frontmatter description | Restored the identity clause (`Agent Skill authoring.`) | `SKILL.md`'s own Description rule requires identity plus one trigger per branch; the trim dropped identity, so the skill violated the rule it teaches |

**Fourth-pass corrections.** `SKILL.md` now actively searches for repeated phrasing that a leading
word can collapse, but accepts the word only after a canary improves invocation or execution.
`GLOSSARY.md` now directs authors to use each heading's exact term, preserving canonical vocabulary
without restoring its 28 negative alias lists.

`SKILL.md` is 466 words against the 500-word budget.

**Historical upstream report.** The description-mechanic correction (6 sites) was reported in
`mattpocock/skills#714`, then closed at the user's request on 2026-08-02; no upstream follow-up is
pending. If a future upstream refresh independently absorbs the fix, drop that row here and take
the correction back via wholesale replacement rather than carrying it as a fork. The frontmatter
description is the opposite: house-authored, so upstream has nothing to fix.

### Re-merge procedure (when upstream moves)

1. Diff the new upstream `writing-for-agents/` against pinned commit
   `8b36d4fb2635b3c21998dcd8144439c9e5ba7302`.
2. Replace the pinned Matt set, then reapply invocation metadata, every still-live row of the
   body-corrections table, the second-pass trigger ownership/structural trim, and the third-/fourth-
   pass corrections. Check each correction against the new upstream first — a row upstream has
   since fixed is dropped, not reapplied.
3. Recompute `invocation_manifest_sha256` and the recorded tree SHA-256.
4. Before merge, run `tests/matt-thin-workflow.sh`, `tests/mattpocock-workflow.sh`, and
   `tests/vendored-detection.sh`; run `tests/host-skill-resolver.sh` from an isolated candidate HOME
   with the exact `Candidate host resolver replay` recipe in
   `proposals/2026-08-01-two-skill-tuning-audit/02-writing-great-skills.md`; require exit 0 and
   `3 PASS / 0 FAIL / 1 UNAVAILABLE` so Copilot resolves the candidate rather than live main.
5. After landing to live main, run `tests/host-skill-resolver.sh` without overrides.
6. Remove this record only when upstream provides equivalent model-invocation behaviour **and** has
   absorbed the body corrections.

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

`rules/tailwind-v4-shadcn.md` carries a `paths:` frontmatter (single-line comma form, unlike the YAML-list form the house stack rules use). Inside a skill that frontmatter never fires — path-triggered loading only reads `~/.claude/rules/` and `.claude/rules/` — so it is upstream residue that reads like a live rule. `SKILL.md:39` indexes the file correctly as "Rule text for agents/tools", and its content is correct (the `@apply` correction above landed there).

Left alone on purpose. Removing the dead frontmatter, or moving the file to `references/` where it belongs by type, is a second structural edit to someone else's skill — a new override decision bought for the removal of a misleading comment. That trade is the wrong way round, and per this file's opening rule, an existing record does not authorise further editing.

The tempting alternative is also rejected: promoting it to a shared house `rules/` file would be legal (external integration touches none of the skill's own files) but wrong. External integration is already done — the `dev-workflow` S0 route sends "Tailwind v4 → `tailwind-v4-shadcn`", and each host's own `rules/frontend-spa.md` declares the Tailwind + shadcn stack. (Both coordinates moved on 2026-07-30: `core/` and `rules/` retired to `attic/`, the routing assertion now reads `skills/dev-workflow/SKILL.md`, and the stack rules live only in `~/.claude|.codex|.copilot/rules/`.) A new rules file would duplicate skill content into the path-triggered layer on `**/*.css` / `**/*.tsx`, re-inflating resident context that a 2026-07-25 pass had just trimmed.

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

## test-gap-analysis

**Decision (2026-08-05): vendor one skill out of a 96-skill marketplace, as a recorded fork.**

**Activation status:** active. After Claude reauthentication on 2026-08-05, the three-case collision canary passed (`3 PASS / 0 FAIL / 0 ERR`; TP=1, TN=2, FP=0, FN=0; precision=recall=1.00). The earlier OAuth `401` run remains recorded as `UNAVAILABLE`, not as a pass.

`github.com/dotnet/skills` is the .NET team's official marketplace — 16 plugins, 96 skills, 16 agents at
`4d25f17`. The adoption review (`proposals/2026-08-05-dotnet-skills-adoption/`) scored all 96 against this
corpus and installed none of them: `dotnet-test` alone would add 10 agents to a menu deliberately reduced
from 43 to 3, its `code-testing-agent` declares itself a `MANDATORY ENTRY POINT for generating or writing
tests` (`SKILL.md:4`) which pre-empts `tdd` and `dotnet-testing-best-practices`, and its 20-skill payload leans
MSTest against an xUnit corpus. Six further skills were harvested as reference sections into existing house
files rather than vendored. This is the single skill that survived adversarial refute as a standalone
capability: `grep mutation` across all 71 prior skills matched only `clean-code-dotnet:24`, where it means
mutable state. Nothing here asks "would my tests catch a bug in this code?".

Its value is orthogonal to coverage. A CI line-coverage threshold is satisfied by testing the easy half of a
codebase; pseudo-mutation asks whether an assertion would actually fail if the line were wrong. The
boolean-and-arithmetic mutation classes it generates are exactly the survivable defect shape that weighted-sum
scoring code produces.

### Local fork changes

| Site | Change | Why |
|---|---|---|
| frontmatter `description` | `DO NOT USE FOR` re-pointed: `code-testing-agent` / `writing-mstest-tests` → `tdd` + the stack's testing skill; `test-anti-patterns` + `assertion-quality` → the stack's testing skill | All four name skills that do not exist in this corpus. A routing pointer to a missing owner routes nowhere |
| `SKILL.md` header note and Step 1 | `Call the test-analysis-extensions skill` → read the vendored `references/dotnet.md` | That skill ships `disable-model-invocation: true` **and** `user-invocable: false`, so on Claude it is unreachable by any path. Its `extensions/dotnet.md` is the only one of 12 extension files this stack needs; the other 11 are dead weight. Upstream's own note calls the payload "nothing standalone" |
| `When Not to Use` and the `Common Pitfalls` integration row | Same four pointers re-targeted | Same reason; these were the in-body copies |
| Step 4b | Static-only is the default. Empirical mutation requires explicit authorization, a clean isolated temporary copy/worktree, original-file fingerprints, a full affected-suite check, inverse editing, and exact cleanup proof | An analysis request does not authorize production edits. Narrow tests are triage, not proof that a mutant survived every affected test |
| Empirical timeout and score | Calibrate each timeout from the same command's unmutated duration, terminate timed-out process trees before mandatory inverse-edit cleanup, count `TimedOut` as detected, and use one non-equivalent denominator with `N/A` at zero | Mutants can introduce infinite loops; arbitrary timeouts create false kills, while an undefined denominator creates incompatible scores |
| Mutation/reference calibration | Treat C#/TypeScript null-forgiving removal as equivalent, and tie xUnit APIs to assertion-package semantics rather than the target framework | Compile-time-only operators are not runtime mutations; xUnit `Throws<T>` is exact-type and `Assert.Fail` availability is package-version dependent |

`references/dotnet.md` carries two one-line corrections of the same class: its header named four
non-existent sibling skills as consumers, and a section heading was labelled "for `test-tagging`".

Baseline before the fork: upstream `SKILL.md` SHA-256
`cfec7d0e13deaee15fb97151d0cd5339fa5f14c109a10c49de81e9a5512231b7` (blob `973a20d`, 19,121B).
Local `SKILL.md` SHA-256 `f7a49f4422309f92f59abb728838fb73cc16671ede3c2b2133d918062532e1ab`.
Lock `payload_sha256` (hash-of-hashes over every file in the directory, the column's convention)
`718315d6c125ac404ef713b0975de76a3b88527f07c9ac0e3bf10ed5e0cf67fe`;
approved tree SHA-256 `a3e8e49626898da48b1640d6c4adda5fa3878d0fc3a5e905b5d32351db634b81`.
Upstream `LICENSE` (MIT, .NET Foundation and Contributors) is carried with the payload.

The polyglot mutation catalog is deliberately **not** trimmed to .NET. It is the bulk of the file and the
part most likely to move upstream; trimming it would buy a one-time load saving against a recurring
merge-conflict cost on every update — the exact trade `step0-vendored-gate.md` says the constraint outranks.

### Re-merge procedure (when upstream moves)

1. Diff the new `plugins/dotnet-test/skills/test-gap-analysis/SKILL.md` against blob `973a20d` at `4d25f17`.
2. Replace the payload, then reapply the local changes above **only where upstream still lacks them**. Drop
   the pointer re-targeting for any pointer whose named skill has since been vendored here. Keep the Step 4b
   authorization, isolation, full-suite, fingerprint, calibrated timeout/process-tree termination, canonical
   score/zero-denominator, and mandatory inverse-edit contract unless upstream provides an equivalent or
   stronger safety boundary.
3. Re-pull `extensions/dotnet.md` into `references/dotnet.md` and reapply its two heading corrections.
4. Recompute both fingerprints (`vendored_tree_sha256 skills/test-gap-analysis`) and update this section,
   the index row, and `vendored-skills.lock`.
5. Run `tests/vendored-detection.sh`, `tests/matt-thin-workflow.sh`, relative-reference checks, and the
   Step 2c trigger canary (fire + quiet cases in `skills/auditing-skill-folder/evals/cases.jsonl`).

### Rollback

Rollback is coordinated and PR-based; do not delete the shared payload first:

1. In `dotclaude`, open a Ready PR that removes the tracked `skills/test-gap-analysis` symlink introduced by
   PR #13, merge it, and confirm no host link still targets the shared directory.
2. In an isolated `agents-config` branch, remove the three trigger-eval cases, the dedicated safety assertions
   in `tests/matt-thin-workflow.sh`, the vendored expected-set/count entries, the lock row, the skill directory,
   and this section plus its index row. Use Git history/revert for recovery rather than a raw recursive delete.
3. Run vendored detection, workflow, relative-reference, trigger, and `agents-sync --doctor` checks; publish the
   rollback through the same Ready PR and review gate.

The harvested reference sections in `dotnet-testing-best-practices` and `dotnet-core-best-practices` are
independent and stay.

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

Regression coverage: `tests/vendored-detection.sh`, 58 cases — every provenance form, Git-untracked empty-directory invariance, fail-closed tree scanning, the false-positive defences (prose `upstream` with no colon; a README that merely exists), lock-set detection, flag/owner agreement, the `fork_recorded` scoping regression, and a corpus assertion pinning the exact VND set of `skills/`. Acceptance for the original detector fix itself was a baseline diff: exactly two skill rows changed, nothing else.
