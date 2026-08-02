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
| `clean-code-dotnet` | github.com/thangchung/clean-code-dotnet | Stage B2 snapshot `7080450`; upstream assessed at `a604cf99e618de359cf34c5384a16fe72a5db2f4` | 2026-07-31 — preserve the imported agent-skill adaptation; tree SHA-256 `7e53e673348379b72f76c7a85c3c199720ddd09e4b963c85092a03eefa054408` | **Active** |
| `design-doc-mermaid` | github.com/SpillwaveSolutions/design-doc-mermaid (v2.0.0) | `SKILL.md` 21,268B — byte-identical to upstream `main` HEAD, last pushed 2025-12-29 | `6daf12c` — −153 lines, pure de-duplication | **Retired to `attic/` 2026-07-25** |
| `diagnosing-bugs` | github.com/mattpocock/skills | `ed37663cc5fbef691ddfecd080dff42f7e7e350d` | 2026-08-01 — add the missing Agent Skill trigger-failure branch before RED-canary handoff; tree SHA-256 `d044ea6809882228085061b89347026b7360e520cc4c68680d8f0eb359da21ba` | **Active** |
| `dotnet-core-expert` | github.com/Jeffallan/claude-skills | Stage B2 snapshot `7080450`; upstream assessed at `e8be415bc94d8d6ebddc2fb50e5d03c6e27d4319` | 2026-08-02 — extract the unique CQRS/MediatR behavior into `dotnet-core-best-practices`, then archive the fork; archived tree SHA-256 `ec640f9552257d643b91a8abb60f8b0ee4fbe59810a88b4def4a92d6a8a2cddb` | **Retired to `attic/` 2026-08-02** |
| `dotnet-test` | github.com/GiantCroissant-Lunar/pigeon-pea | Stage B2 variant of `d62332d0efb2b45be1a6f1350a399149f8ce494e` | 2026-08-01 — route duplicated unit/coverage guidance to the canonical house skill, remove PigeonPea-only files, and retain a portable BenchmarkDotNet procedure; tree SHA-256 `435a220786ad2ef6c8023111330cd4d822717af241952c6d404160a3acb07bae` | **Active** |
| `playwright-best-practices` | github.com/currents-dev/playwright-best-practices-skill | `283d5cbc5d11aac1abda058b16ad22c317d54dc0` (v1.2) | 2026-08-01 — record the curated 44-line router plus local MCP/common/Python references, and remove 18 dead pointers to omitted upstream-only directories; tree SHA-256 `6d62ea8fd597e9fc40475d421f2f98b8c93a5e79b5a8f0ef4339752c24c7fb1f` | **Active** |
| `web-design-reviewer` | github.com/github/awesome-copilot | `952c4f45a7bba173f32176a2658a03a1a5ad462c` | 2026-08-02 — replace 3,586 words of duplicated framework/checklist material with a thin rendered-page → source → authorized repair → same-viewport verification loop; tree SHA-256 `f7fa17f95793aebd5ce22009d0354ea1e6dd778c227a83077b89832863dde48b` | **Active** |
| `grilling` | github.com/mattpocock/skills | `ed37663cc5fbef691ddfecd080dff42f7e7e350d` | 2026-08-02 — preserve the opt-in decision workflow and add the minimal under-specified/clarify trigger needed to absorb retired `clarify`; payload SHA-256 `a9f97fa0cb597c21ec4beedbb3cce6670f9f48835bd032a3d8605c34c5d70dd2` | **Active** |
| `handoff` | github.com/mattpocock/skills | `ed37663cc5fbef691ddfecd080dff42f7e7e350d` | 2026-07-31 — interactively-triggered runs end the reply with a copy-pasteable start prompt for the next session, capped at four lines; payload SHA-256 `94b9c425dbbe1c5b3f788fbea1fd588b6c6fa9f5e1c5b8c2c201c07088204560` | **Active** |
| `qa-tester` | github.com/finos/morphir-dotnet | Stage B2 subset of `90670e94ea038ba5cc453110f2cdc938c578614d` | 2026-07-31 — preserve the four runtime skill files and omit upstream `README.md`; tree SHA-256 `eeadca3b6b0246f3350d908ba8cb2d461aef4c667a12fa494325270f375c2624` | **Removed 2026-08-01** |
| `writing-great-skills` | github.com/mattpocock/skills | `ed37663cc5fbef691ddfecd080dff42f7e7e350d` | 2026-08-01 — **scope widened through four evidence-backed passes**: invocation metadata, factual body corrections, trigger ownership, branch-aware completion, executable checklist, glossary cleanup, and evidence-gated leading-word/canonical-term rules; tree SHA-256 `3a4945d7c29f0318d556eb01d7c5d9da80b998c88f950c8a4c099857011c32aa` | **Active** |
| `tailwind-v4-shadcn` | github.com/jezweb/claude-skills (v1.0.0, per `.claude-plugin/plugin.json`; author Jeremy Dawes, MIT) | `9fdb7f2` baseline — a snapshot of an upstream layout that no longer exists; upstream renamed and restructured it to `plugins/frontend/skills/tailwind-theme-builder` | 2026-07-25 — two factual corrections in `references/common-gotchas.md` §17 and `rules/tailwind-v4-shadcn.md` | **Active** |

<!-- fork-index:end -->

Retired entries stay listed: the `attic/` copy still differs from upstream, so anyone restoring it needs this record. `check-vendored.sh` does not scan `attic/`, so a retired entry no longer renders as `VND*`.

## Resolved Stage B2 provenance

- `aspnet-api-architect` is self-owned. Its former lock pointed only to this repository's first
  tracked snapshot (`44c7fd0`, authored by BriantsaiCoder), while a 2026-08-01 GitHub code search
  found zero copies outside BriantsaiCoder repositories. Its lock rows were removed before the
  focused requirements-to-design/tasks-to-scaffold rewrite.
- `dotnet-find-bugs` remains a byte-identical upstream snapshot from
  `ricoisme/vscode-agents@2b1240abad239703d09875acefd7ae42685c88ff`. Its per-file coverage
  behavior was added to `security-review`, but Claude's same-named owner won the canary namespace
  and its payload could not be verified; retirement is deferred rather than treating
  **UNAVAILABLE** as PASS.

## clean-code-dotnet

**Decision (2026-07-31): preserve the Stage B2 imported agent-skill adaptation as a recorded fork.**

The local skill names `thangchung/clean-code-dotnet` as its source but is not a wholesale upstream
checkout. Its exact payload and tree are pinned in `vendored-skills.lock`.

### Re-merge procedure (when upstream moves)

1. Compare the full local skill against upstream from the assessed revision.
2. Replace it wholesale or explicitly retain the agent-skill adaptation; do not silently mix trees.
3. Recompute both fingerprints and run `tests/vendored-detection.sh` and
   `tests/matt-thin-workflow.sh`.

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

## Pinned Matt set — 18 unmodified + 4 recorded forks

**`mattpocock/skills` stable 22 — active, pinned 2026-07-27.**

- Source: `https://github.com/mattpocock/skills.git` at `ed37663cc5fbef691ddfecd080dff42f7e7e350d`.
- Selection: `.claude-plugin/plugin.json` SHA-256 `e712cc026f5e78058067d17cd1fdf9665388d70db59dc50688286cb029e38eba`.
- Machine-readable inventory: `mattpocock-skills.lock`; only its 22 `skill=` entries are active.
- The 18 entries other than `diagnosing-bugs`, `grilling`, `handoff`, and `writing-great-skills` are byte-for-byte upstream and immutable.
- The four recorded forks have exact payload fingerprints and re-merge procedures below.
- Update by replacing the full pinned set after lock/hash verification, then reapply only recorded forks. Any additional local payload edit requires a new decision and fingerprint.

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

**`ecpay` — retired to `attic/` 2026-07-25.**

- Upstream `github.com/ECPay/ECPay-API-Skill.git`, detached at `5b1ac76` (2026-07-07), per `attic/ecpay/UPSTREAM.txt`.
- LICENSE is **All Rights Reserved**, Copyright (c) 2025-2026 綠界科技股份有限公司 — not open source. It may be kept locally but not redistributed.
- **Zero local modification**: `git log --follow -- skills/ecpay/SKILL.md` shows one commit (`9fdb7f2`, the baseline import). The `attic/` copy is byte-identical to what was vendored, so no re-merge procedure is needed — restoring means re-cloning upstream or `git mv attic/ecpay skills/ecpay`.
- Removed on user instruction while trimming the resident skill listing. Wholesale removal is legal under the vendored gate — what is forbidden is editing in place.
- Cost it was carrying: 319 chars of name+description in every session's skill listing (2.9MB / 295 files on disk, which cost nothing resident).
- **Restore when**: a project actually integrates ECPay 金流 / 電子發票 / 物流. The knowledge is 綠界-specific and not model-stable — 12-language CheckMacValue / AES vectors, ECPG vs ecpayment dual-domain traps, per-service test MerchantIDs. Nothing else in `skills/` covers it.

---

## diagnosing-bugs

**Decision (2026-08-01): add one trigger branch for Agent Skill invocation failures.**

The generic upstream description names broken, failing, flaky, and slow software, but not an Agent
Skill that fires unreliably. Routing canaries therefore let `writing-great-skills` steal the first
step even though the canonical workflow requires a RED trigger canary first. The local change adds
only that missing description branch; the body is untouched.

Approved tree SHA-256: `d044ea6809882228085061b89347026b7360e520cc4c68680d8f0eb359da21ba`.
Evidence and the 21:00 control are recorded in
`proposals/2026-08-01-two-skill-tuning-audit/02-writing-great-skills.md`.

On upstream update, drop this fork if the new description carries an equivalent Agent Skill
trigger-failure／RED-canary branch; otherwise reapply the one-line description change and recompute
the tree fingerprint.

---

## grilling

**Decision (2026-08-02): keep the existing fork and widen only its trigger description.**

The user may explicitly authorize all remaining low-risk, reversible recommendations once instead
of confirming each one. That authorization remains HITL feedback: the agent records each adopted
default, pauses for high-risk, irreversible, scope-expanding, or low-confidence decisions, then
summarizes every decision and waits for final confirmation before acting.

The 2026-08-02 description-only change adds explicit under-specified/clarify routing so the
byte-identical `clarify` skill can retire without losing one-at-a-time requirement interviews. The
body and all upstream procedures remain unchanged; the global ambiguity gate alone was insufficient
because an explicit "clarify this" request did not auto-invoke this skill in the RED canary.

### Re-merge procedure (when upstream moves)

1. Diff the new upstream `grilling/SKILL.md` against pinned commit
   `ed37663cc5fbef691ddfecd080dff42f7e7e350d`.
2. Replace the pinned Matt set normally, then reapply the opt-in default paragraph and clarify
   trigger only if upstream still lacks equivalent behavior.
3. Run `tests/matt-thin-workflow.sh`, `tests/vendored-detection.sh`, and the skill validator.
4. Update the fork index's upstream commit; remove this record if upstream fully absorbs the behavior.

---

## handoff

**Decision (2026-07-31): accept the fork.**

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
   `ed37663cc5fbef691ddfecd080dff42f7e7e350d`.
2. Replace the pinned Matt set normally, then reapply the final paragraph only if upstream still
   emits no start prompt for the next session.
3. Run `tests/matt-thin-workflow.sh` and `tests/vendored-detection.sh`; confirm `check-vendored.sh`
   renders `handoff` as `VND*`.
4. Update the fork index's payload SHA-256; remove this record if upstream absorbs the behavior.

---

## writing-great-skills

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

Approved tree SHA-256: `3a4945d7c29f0318d556eb01d7c5d9da80b998c88f950c8a4c099857011c32aa`.

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

`SKILL.md` is 442 words against the 500-word budget.

**Reported upstream.** The description-mechanic correction (6 sites) is tracked in
`mattpocock/skills#714`. If accepted upstream, drop that row here and take the correction back via
wholesale replacement rather than carrying it as a fork. The frontmatter description is the
opposite: house-authored, so upstream has nothing to fix.

### Re-merge procedure (when upstream moves)

1. Diff the new upstream `writing-great-skills/` against pinned commit
   `ed37663cc5fbef691ddfecd080dff42f7e7e350d`.
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

## Detector gap — check-vendored.sh missed 2 of 6 (fixed)

Found 2026-07-25, fixed 2026-07-26. `check-vendored.sh` reported 4 vendored skills out of `skills/`; the real count was 6. Both misses were caught by hand during the description-trim pass — exactly the review this detector exists to make unnecessary.

Both were false negatives of the same shape: **provenance recorded somewhere the detector did not read.** That is the dangerous direction. A false VND costs one manual check; a false `-` silently licenses editing someone else's skill — and did: the `tailwind-v4-shadcn` corrections recorded above were made before anyone knew whose skill it was.

| Skill | Provenance | Why it was missed | Fix |
|---|---|---|---|
| agent-browser | `SKILL.md:7` `<!-- tier: … \| consumed-by: … \| upstream: agent-browser CLI … -->`; `SKILL.md:24` self-declares `references/` + `templates/` as cached upstream copies; `install.sh:20` writes `$GITHUB_ENV` | The `upstream:` token sits in an HTML comment **after** the closing `---`, where the frontmatter-bounded awk (`fm==2 exit`) had already stopped. No LICENSE either. | Marker scan moved out of the frontmatter to the whole file, anchored on `^` / `<!--` / `\|`. The `\|` anchor is required — the marker is the comment's 4th pipe-delimited field. |
| tailwind-v4-shadcn | `.claude-plugin/plugin.json` carries `author`, `license: MIT`, `repository: github.com/jezweb/claude-skills` | The detector never opened `.claude-plugin/plugin.json`. No LICENSE, no README, nothing in frontmatter. | That file joined the provenance file set. Its content already matched the existing URL pattern, so the fix was the file set, not the pattern — content-only detection stays the single rule. |

Both fixes landed in `vendored_flag()` **and** `vendored_owner()`. Fixing only the flag would have produced two VND rows with an empty OWNER column, which reads as a detector bug rather than as the finding.

A third defect surfaced while writing this section: `fork_recorded()` matched `| \`name\` |` anywhere in this file, so the table above — documentation, not an index — promoted `agent-browser` to `VND*`, asserting an accepted fork decision that was never made. The fork index now sits between `<!-- fork-index:begin/end -->` markers and the lookup is confined to that block; a file with no markers fails closed.

Regression coverage: `tests/vendored-detection.sh`, 55 cases — every provenance form, the false-positive defences (prose `upstream` with no colon; a README that merely exists), lock-set detection, flag/owner agreement, the `fork_recorded` scoping regression, and a corpus assertion pinning the exact VND set of `skills/`. Acceptance for the original detector fix itself was a baseline diff: exactly two skill rows changed, nothing else.
