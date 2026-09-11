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
| `ask-matt` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — keep the router thin and point phase/context transitions to the canonical shared continuation contract instead of vendoring a second authority; tree SHA-256 `55c1bb438af24491d140f05ea644de7f8ff40756276915aba39458cc2b4d87f5`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-11 — research route defers delegation and output ownership to shared INT-4/S2; tree SHA-256 `0a3e6cd9b9cd4a06edd26c27d3caed25636521f04c0ba70c14daabeaf967091b` (see Opus 5 record below) | **Active** |
| `clean-code-dotnet` | github.com/thangchung/clean-code-dotnet | Stage B2 snapshot `7080450`; upstream `a604cf99e618de359cf34c5384a16fe72a5db2f4` | 2026-08-02 — re-adjudicated thin fork: narrow Clean Code triggers, retain a 360-word judgment checklist, keep only self-consistent illustrative SOLID snippets, and remove duplicated async/editorconfig payload; tree SHA-256 `ec219244eb5c194376737b6bae6894c83c13ae3fadcc7182687d138182663153`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `design-doc-mermaid` | github.com/SpillwaveSolutions/design-doc-mermaid (v2.0.0) | `SKILL.md` 21,268B — byte-identical to upstream `main` HEAD, last pushed 2025-12-29 | `6daf12c` — −153 lines, pure de-duplication | **Retired to `attic/` 2026-07-25** |
| `diagnosing-bugs` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-01 — add Agent Skill trigger-failure routing; 2026-09-07 — allow bounded unverified read-only investigation without a repro and evidence-sized hypotheses; tree SHA-256 `291698386c7fec63e5503b449df0fb3dc9579d1c2058804353c0160c1b6ef1bb`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `implement` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-07 — defer test scope and repetition to shared S4/evidence-integrity; tree SHA-256 `031b9b743fcaedc0fa57f446712d5730a2c7d5c0f10f99c2f08c93122a2ab206`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `improve-codebase-architecture` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-19 — report 與 reply prose 預設使用 zh-TW；technical terms、code identifiers、paths 與 domain terms 保持 English 或原文；tree SHA-256 `9c57cc581b532e7dbf752d09f15b06dd61e08199f151684da72accbddb96c8c7`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-09 delta — approved Fable 5.1 audit delta (see "2026-09-09 Fable 5.1 audit delta" record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared; 2026-09-11 — alternative-interface routing defers delegation to the updated design-it-twice workflow instead of promising parallel subagents; tree SHA-256 `a52d5278556bce310ee50d64e00ac10c381a78302c01be5fe038c65507d311c1` | **Active** |
| `dotnet-core-expert` | github.com/Jeffallan/claude-skills | Stage B2 snapshot `7080450`; upstream assessed at `e8be415bc94d8d6ebddc2fb50e5d03c6e27d4319` | 2026-08-02 — extract the unique CQRS/MediatR behavior into `dotnet-core-best-practices`, then archive the fork; archived tree SHA-256 `ec640f9552257d643b91a8abb60f8b0ee4fbe59810a88b4def4a92d6a8a2cddb` | **Retired to `attic/` 2026-08-02** |
| `dotnet-test` | github.com/GiantCroissant-Lunar/pigeon-pea | Stage B2 variant of `d62332d0efb2b45be1a6f1350a399149f8ce494e` | 2026-08-01 — route duplicated unit/coverage guidance to the canonical house skill, remove PigeonPea-only files, and retain a portable BenchmarkDotNet procedure; tree SHA-256 `d583ef03da7e559d0f63a599cbc9b57ab942ff1bbe6a23c96d808cc65c085697` | **Retired to `attic/` 2026-08-02** |
| `vueuse-functions` | github.com/serkodev (MIT, Copyright (c) 2026 SerKo) | LICENSE.md only; no upstream revision was ever recorded | 2026-08-02 — **user-authorized override**: the 11-row requirement map and the 6-entry high-frequency index both merged into `vue-best-practices/references/vueuse/INDEX.md`; the use-vs-hand-roll judgment and the SSR/PII guardrails merged into the same file; MIT notice carried with the payload and retained in the archive. Archived tree SHA-256 `95db99f6a5082d25b311154bf6410cf9e7cd3be306417005caf730fc986f8913`（`vendored_tree_sha256 attic/vueuse-functions`，與其他列同公式） | **Retired to `attic/` 2026-08-02** |
| `playwright-best-practices` | github.com/currents-dev/playwright-best-practices-skill | `283d5cbc5d11aac1abda058b16ad22c317d54dc0` (v1.2) | 2026-08-01 — record the curated 44-line router plus local MCP/common/Python references, and remove 18 dead pointers to omitted upstream-only directories; tree SHA-256 `a14c2bca1f11a8665f30cfdc0595c15f5d57cdb3af42aab6e18a2238ba2e9f08`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `ui-ux-pro-max` | github.com/nextlevelbuilder/ui-ux-pro-max-skill | `14ddef5c05e52d7c253b8f0129de7bcd1045ae5b` | 2026-08-02 — vendor only the offline core, port Claude-only paths to the shared root, narrow routing ownership, and harden search/persistence; 2026-09-09 — preserve the material-choice gate while honoring delegated or accepted targets, briefly state assumptions for a delegated choice, and scope failed lookups to dependent work with an `UNAVAILABLE` probe; tree SHA-256 `20a373233625a27d8118204b18686f9c7b7e30f85f12da36e817e81740fb1d36`; 2026-09-09 delta — approved Fable 5.1 audit delta (see "2026-09-09 Fable 5.1 audit delta" record below); tree SHA-256 `20a373233625a27d8118204b18686f9c7b7e30f85f12da36e817e81740fb1d36`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `web-design-reviewer` | github.com/github/awesome-copilot | `952c4f45a7bba173f32176a2658a03a1a5ad462c` | 2026-08-02 — replace 3,586 words of duplicated framework/checklist material with a thin rendered-page → source → authorized repair → same-viewport verification loop; tree SHA-256 `9cb920d7a0ff465228ce4b9ed005ec4b8ea259d2921f49be34ce9454f654c4e4`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-09 delta — approved Fable 5.1 audit delta (see "2026-09-09 Fable 5.1 audit delta" record below); tree SHA-256 `9cb920d7a0ff465228ce4b9ed005ec4b8ea259d2921f49be34ce9454f654c4e4`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `grilling` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — narrow the trigger to an explicit interview request, adopt design-tree/frontier dependency sequencing, retain the canaried one-question HITL default, add re-estimated progress headers, and keep delegated decisions behind a separate action gate; payload SHA-256 `d3c4cd7caf20eeae2004190c387f09fe80ff06d4f9cea20e90d6fa0745967ca8`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `handoff` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-07-31 — interactively-triggered runs end the reply with a copy-pasteable start prompt for the next session; 2026-09-07 — drop the four-line cap on that prompt (prompt-audit rule 1f, numeric output ceiling); payload SHA-256 `b8ecbfb0706efc72b859f3387c741fe2d116df07f76ae0cab96be46bedcb9761`; 2026-09-09 supplement — complete approved disclosure/description changes; tree SHA-256 `bf149c42a210d0ecdd4f7c1a1914a842e369688f0db4e094adc4583a51e584db` | **Active** |
| `qa-tester` | github.com/finos/morphir-dotnet | Stage B2 subset of `90670e94ea038ba5cc453110f2cdc938c578614d` | 2026-07-31 — preserve the four runtime skill files and omit upstream `README.md`; tree SHA-256 `eeadca3b6b0246f3350d908ba8cb2d461aef4c667a12fa494325270f375c2624` | **Removed 2026-08-01** |
| `prototype` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — adopt the self-contained HTML logic demo and add the local offline/synthetic-data/no-secret/no-production-build boundary; tree SHA-256 `bba188786b02d904821b549b20c110286f59115f21dc7ffea099557df1d29097`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below) | **Active** |
| `triage` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — delegate question cadence to the canonical `grilling` contract instead of copying one-at-a-time or rounds behavior into the caller; tree SHA-256 `a10173ea5cf4563fceb4b23a0749fdba0762449c4a2a9ef3b7dcd124afc8a623`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `writing-for-agents` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-06 — generalize the local authoring contract to Agent Skills, AGENTS.md, CLAUDE.md, and pointed-at docs while preserving RED ownership, host invocation metadata, the glossary, thin-kernel ownership, and pinned provenance precedence; tree SHA-256 `1ba596aee238d4ca655adf6a4c3e66319d2695984e9a4cded21a87fb3f310c6d`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `speak-human-tw` | github.com/Raymondhou0917/speak-human-tw | `ee860be6fb190cbc53dc1d45a2a47c9c9c680243` | 2026-08-29 — add a technical-work communication scene, protect technical tokens and evidence, and add paired SF/SNF plus secret-redaction coverage; 2026-09-05 preserve factual tool use separately from unsupported benefits; tree SHA-256 `5e3e7a4811ff46b811f4b550668564a4cd847abf3df5c5ad4a1fb77753c129d8`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `tailwind-v4-shadcn` | github.com/jezweb/claude-skills (v1.0.0, per `.claude-plugin/plugin.json`; author Jeremy Dawes, MIT) | `9fdb7f2` baseline — a snapshot of an upstream layout that no longer exists; upstream renamed and restructured it to `plugins/frontend/skills/tailwind-theme-builder` | 2026-07-25 — two factual corrections in `references/common-gotchas.md` §17 and `rules/tailwind-v4-shadcn.md`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared; 2026-09-11 — preserve valid project-native `oklch`, `hsl`, and `var()` color formats instead of forcing HSL conversion; tree SHA-256 `7c8ffe8eb2fb601f9e4dadb18ab0efd2091a1292c874d026a510228a01077b95` | **Active** |
| `tdd` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-05 — canonical workflow seam/authorization and GREEN refactor; tree SHA-256 `d1dfcd70fe2940d4231d4be2cb2418713fd6776d749941638137b83945029207`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `code-review` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-08-03 — drop the `Under 400 words` cap from both sub-agent briefs, add the within-axis filter and two house over-engineering baseline rules, and accept v1.2.2 spec terminology; 2026-08-08 — widen that baseline to five rules and add the performance and correctness clauses to the Standards brief; 2026-08-25 — pin the review to an immutable SHA snapshot instead of a moving HEAD (issue #90); 2026-09-05 — align both axes with the canonical evidence-first actionable contract while retaining no output cap and axis separation; tree SHA-256 `e404954a8a0123e1933fc02d66ddaed079f425622089afca2d445b99426c6179`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `test-gap-analysis` | github.com/dotnet/skills (MIT, .NET Foundation and Contributors) | `4d25f171766a9b852b229540bf9b8a6874ef16db`, `plugins/dotnet-test/skills/test-gap-analysis` | 2026-08-05 — re-point dead sibling-skill pointers, inline the .NET reference, require authorized isolated full-suite empirical mutation with fingerprinted cleanup, and calibrate runtime-equivalent/xUnit cases; tree SHA-256 `08366541fafcc856569cf5de0946d3e60806741880b070a7e7891343fde58380`; 2026-09-09 — approved description/ownership/branch-routing optimization (see batch record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |

| `agent-browser` | installed agent-browser CLI bundled core | local wrapper baseline `60c840b`; no CLI revision pinned | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `8916f6658118cd35fb4db907128334782c6a984c809781cadba1555d651e8a32`; tree SHA-256 `85cdaedc49a2bc0604de81017422e744fd01ee1b299c64a6e83b9f1a85920c75`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `codebase-design` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `1a383c195d752de7f28a495f5fb3db54eaad06734c57ccd810390fe31eea9579`; tree SHA-256 `5d83418ecbaa7499a43a017780ff2ab5f61d5b613326fcb660a67d04b5b16b1f`; 2026-09-09 delta — approved Fable 5.1 audit delta (see "2026-09-09 Fable 5.1 audit delta" record below); 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared; 2026-09-11 — Design It Twice keeps at least two alternatives while routing optional agent use through shared INT-4 and removing the fixed three-agent floor; tree SHA-256 `628d0fbe2aeea1996204f657dabaab1e0ff034830d3585de91e067c3206ff128` | **Active** |
| `microsoft-code-reference` | https://github.com/github/awesome-copilot/tree/1918e6f868fdce88ad5d848406fe472fa3948b7a/skills/microsoft-code-reference | `1918e6f868fdce88ad5d848406fe472fa3948b7a` | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `8ee7c32860e0b751aeedcde1c84b725235ec1d2ac63ab9be5d3799ae26417a1c`; tree SHA-256 `8d7a68b5608140152957931c96d8700b6a9898032a90e9f72c269cb995be2048`; 2026-09-09 delta — approved Fable 5.1 audit delta (see "2026-09-09 Fable 5.1 audit delta" record below); tree SHA-256 `be249a9695b5390872b4a46ec58240b2e433459ffe79e36ba706d1a6bcd330df` | **Active** |
| `microsoft-docs` | https://github.com/github/awesome-copilot/tree/a3035a6e7cad53ef68ca321d5f5365c0043af519/skills/microsoft-docs | `a3035a6e7cad53ef68ca321d5f5365c0043af519` | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `e656618a3bc63d9d8d5bdc381f3eb1bf4327b9ef4bb22ff399c301551f421acf`; tree SHA-256 `c1cc5bf59d6113fee38facb5bd2fd0cc2cabf28303fa4975220b6f790c9e0d7e`; 2026-09-09 delta — approved Fable 5.1 audit delta (see "2026-09-09 Fable 5.1 audit delta" record below); tree SHA-256 `9becdf0c515f00430ce7027f9224dc0ec114d6ff20923bfa9edc0c4cc5014d77` | **Active** |
| `resolving-merge-conflicts` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `52162eecbd8366e1d4b145e0964dfab7fe3cd534773d85e79c750f6e04aa65f5`; tree SHA-256 `b442690537b7375f2ea50da67aee174769b27dec9455ea62779f542340d51f60` | **Active** |
| `setup-matt-pocock-skills` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `20fabc63fdb530037748eaf9b1a62a53ea91ac5a18cecc0fb001c3002b2673fc`; tree SHA-256 `8b7884991baff72c74b6773404d13105976c6229d683cafb2a58165370585631`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `teach` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `10707673896f85135ada4425709be25a349ec85f576b5f9a7926615971db19b1`; tree SHA-256 `2ba4420265e8e9aceeed1776e27235cc551df4fffe529ae74ae3493f8b72860b`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `to-spec` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `7fe9db6b276a87383996b138efa07e7e20fb5fbec8bd6027e084733b48efba60`; tree SHA-256 `f376e4846d39646535e6aa708ce142d8a5c01eaac95cd2fdb519c8e2aff7d08e`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |
| `to-tickets` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `030ff9a692ff972061b8fa98caf5fd2cafd5c3b64d1f78480ba8c37bc6d5e454`; tree SHA-256 `3c510a1963e7a711ceb25f3c5747c0c5678f084349e59d319ae396062d05e52a` | **Active** |
| `wayfinder` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved description/ownership/branch-routing optimization; baseline tree `8c91f90c7129883d2c4cd1f7c255873e215c292801ecf4ed47af995a752b81dd`; tree SHA-256 `e9ee62e139a829fbc9cc3d43f6fb5c3a95e201bc5aea54010afe9fc0e78fb2d4`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared; 2026-09-11 — research tickets use shared INT-4 instead of one automatic subagent and branch per ticket; tree SHA-256 `1602431050363c55074639577eebbf4dbd5ca887aec80e40d000cbc65b581225` | **Active** |

| `domain-modeling` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved disclosure/description supplement; baseline tree `1918befd92fd79e48b96698c79bdcea0b925b188d6c70004c077515153750101`; tree SHA-256 `43720a21f56e478a1596f0343a9b74f5ae6eac273811aceab671383ac460e5a2`; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |

| `grill-me` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved disclosure/description supplement; baseline tree `0da3a0d6c13e90dd18565754376f49c533a8779a6079c88e7a1bbc7d3dab4b10`; tree SHA-256 `102f60886284e139d580a2b4ad321e2470aa5d838edd5bc424b11649d7fde513` | **Active** |

| `grill-with-docs` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2) | 2026-09-09 — user-approved disclosure/description supplement; baseline tree `2709e7d916096a783dae120d269fa1b62e01bc58125ce6c58e4bf645adec766b`; tree SHA-256 `9e44d8a8d61d7561ed646054743b170792e06ec06491d1836053d46ab971db1a` | **Active** |
| `ai-level-check` | github.com/Raymondhou0917/ai-level-check (v0.4.6) | `6497ee9e681da0b676322b307f12c4c184b87f42` | 2026-09-09 — vendor the SKILL.md fixpoint closure (14 of 49 upstream files) and drop two sets of pointers rather than content: the four persona-quadrant diagrams under `assets/personas/` become the plain-text type catalogue their own alt text carried, and the fifth file there (`four-axes.png`) is dropped outright because only the un-vendored `README.md` referenced it — `assets/` totals 7.4MB, and the `docs/lv{1,3,4}.html` demo files are unnamed in `SKILL.md` / `references/report-design.md` while the do-not-borrow-a-type prohibition and the public demo URL stay; upstream `.gitignore` is retained because `references/privacy.md` points at it and it carries the `evidence/` and `reports/*` exclusions this public repo needs; the approved estimate was 12 files and the fixpoint closure landed 14 — the extra two are upstream `.gitignore` (load-bearing: `references/privacy.md` points at it) and the zero-byte `reports/.gitkeep`, both required by the same closure rule; tree SHA-256 `13c97ee25cbb49cd382d6240006180c5fce9c7dee8a1c377fa56208a61960c06`; 2026-09-09 — removed at user request (unused); no attic copy, restore from the commit before removal | **Removed 2026-09-09** |

| `security-audit` | github.com/cloudflare/security-audit-skill (MIT, Cloudflare, Inc.) | original pre-fork tree `32ae587e750309e92d02c4668a4411ca90adef9a36d38313783393e4e6c8f1d0`; upstream reassessed at `d24bc269171a9171fac58493e0ffba511d571a4a` on 2026-09-11 | 2026-09-09 — approved Fable 5.1 audit delta: move Setup and prior-run coverage to `references/setup.md`, move Core Principles and Anti-Patterns to `references/principles.md`, default the output directory before asking, sync `README.md` file table and output-directory sentence to the split; 2026-09-10 shared audit — scope/routing/disclosure override; full before/after fixtures in docs/skill-overrides/2026-09-10-shared; 2026-09-11 — route recon/hunting fan-out through shared INT-4, remove the duplicate verifier fleet, and retain one Phase 3 validator that sees every factual and remediation field before Phase 4/5 serialize it; PR review follow-ups narrow delegated context and attack-class splitting, require a fresh validator after substantive correction, retain unavailable candidates outside `findings.json`, bound optional hardening notes, align setup/README output and prior-run loading with retained candidates, define the distinct fresh-context fallback, and redact sensitive candidate literals before they leave source context; tree SHA-256 `1f675cc40bc37cb2d043a73bab8600ea9fffb534310b1bf079fdb9656a4fd531` | **Active** |

| `research` | github.com/mattpocock/skills | `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (v1.2.2); baseline tree `679ea679b8e4d0381b74dd9dc3fa0d329f8b7134c1151d1c2458824c1c24c016` | 2026-09-10 shared audit — substantial-report trigger, optional delegation, authorized output path; tree SHA-256 `91bac5b97b47cd81d7c333b1484b98d4f0d2b6435e9f2f37ce795360f58183d8`; full before/after fixtures in docs/skill-overrides/2026-09-10-shared | **Active** |

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

**Decision (2026-09-09, user-authorized audit remediation):** Keep the material-choice selection gate for unresolved visual direction, while allowing implementation to proceed when the user explicitly delegates that choice or has already accepted a target. A delegated choice selects a concrete direction, states brief assumptions, and continues. Record failed searches as `UNAVAILABLE` with their probe and stop only dependent work; never claim the lookup succeeded.

**Decision (2026-08-02): vendor the complete offline core as a recorded portability and security fork.**

The core keeps the upstream data, search engine, references, tests, and MIT license. The full plugin
suite is deliberately excluded: its six sibling skills overlap existing shared/host capabilities,
and its global installer would create additional trigger owners outside this repository's routing.

Six local changes are intentionally small:

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
6. Preserve the three-direction choice gate without re-asking after explicit delegation or target
   acceptance; for delegated choices select a concrete direction and state brief assumptions before
   continuing. Scope failed lookups to dependent work with `UNAVAILABLE` probe evidence.

Upstream-only trailing whitespace in `design_system.py` is normalized mechanically so the shared
repository's diff check remains clean.

Approved payload SHA-256: `3fff0dd81f63654f8984d8b08b8e0156af687e80d545062191a261e520251eca`;
approved tree SHA-256: `20a373233625a27d8118204b18686f9c7b7e30f85f12da36e817e81740fb1d36`.

### Re-merge procedure (when upstream moves)

1. Fetch the new `.claude/skills/ui-ux-pro-max` tree and verify its license and runtime dependency
   boundary before replacing the pinned payload.
2. Reapply only the thin shared router, scoped `UNAVAILABLE` lookup handling, selection authorization
   boundary, fail-loud search/limit validation, persistence safety, relative-link corrections, and
   bytecode suppression that upstream still lacks; never run the global installer or import sibling
   skills as part of this update.
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

## Pinned Matt set — 0 unmodified + 22 recorded forks

**`mattpocock/skills` selected 22 — active, rebased to v1.2.2 on 2026-08-06.**

- Source: `https://github.com/mattpocock/skills.git` at `8b36d4fb2635b3c21998dcd8144439c9e5ba7302` (`v1.2.2`).
- Upstream manifest: `.claude-plugin/plugin.json` SHA-256 `85a5f2ad87b1070c13a97a9379887fc43e5e786a0ab7a3c0f0281d2b30f523b2` (25 published skills).
- Machine-readable inventory: `mattpocock-skills.lock`; only its 22 `skill=` entries are active.
- Excluded from the 25 published skills: `wizard` (credential/migration side-effect generator overlaps protected house gates), `wait-what` (personal communication modifier, not engineering workflow), and `to-questionnaire` (unneeded outward async-document flow overlapping existing clarification routes). Re-entry requires a new decision record and canary.
- Active `upstream_tree_sha256` entries in the lock identify only byte-for-byte upstream trees. Baselines for newly recorded forks remain historical provenance; the fork index owns each current fork fingerprint.
- Recorded forks have exact payload fingerprints and re-merge procedures below.
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

Approved tree SHA-256: `55c1bb438af24491d140f05ea644de7f8ff40756276915aba39458cc2b4d87f5`.

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

Approved tree SHA-256: `bba188786b02d904821b549b20c110286f59115f21dc7ffea099557df1d29097`.

On upstream update, replace the directory, reapply the single offline boundary only if absent, run
relative-reference checks and `tests/mattpocock-workflow.sh`, then recompute the tree fingerprint.

---

## triage

**Decision (2026-08-06): make the caller cadence-neutral.**

`triage` invokes `grilling` and `domain-modeling`, but the canonical `grilling` contract owns whether
questions are asked singly or in independent rounds. This prevents callers from drifting whenever
the interview cadence changes.

Approved tree SHA-256: `a6bd17ced740043523c08822bd21b9d93cfcf08890baa167b7f9bdd2e9640bc2`.

On upstream update, keep the cadence-neutral pointer unless upstream has equivalent wording, then
recompute the tree fingerprint and run the Matt workflow tests.

---

## code-review

**Decision (2026-09-05, user-authorized Fable/Astra optimization):** Canonical reviewer-template now owns house-five and the evidence-first actionable output contract: findings require a concrete trigger, impact, and fix; nitpicks require repo-standard or maintenance-cost evidence; questions are reserved for missing information that blocks the verdict. The entrypoint retains the no-word-or-count-cap rule, full per-axis dispatch requirements, and axis separation while moving snapshot/Fowler detail into required references. This also closes the historical breaking-change/stack-priority gap through the complete canonical prompt. Re-merge only when upstream preserves these semantics; rerun the recorded two-model canaries and repository gates after updating fingerprints. Roll back this batch by reverting its changes together with callers/lock records; do not remove earlier local forks.

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

Approved tree SHA-256: `e404954a8a0123e1933fc02d66ddaed079f425622089afca2d445b99426c6179`.
Driving rules: `[S5-4]` and `[S5-3]` in `skills/dev-workflow/SKILL.md`.

Current re-merge procedure (2026-09-05): compare upstream against the pinned revision. Preserve the immutable snapshot/dirty package and independent axis contracts; use the canonical reviewer-template as the sole house-five and reviewer-output owner. Reapply only missing behavior, retaining the full canonical prompt in the actual Standards dispatch and the common output/hygiene contract in Spec. Do not restore duplicate inlined baselines. Recompute the tree fingerprint, run workflow/reference guards and the recorded model canaries. Historical step numbers above are evidence of prior fixes, not the current dispatch API.

---

## diagnosing-bugs

**Decision (2026-08-01): add one trigger branch for Agent Skill invocation failures.**

The generic upstream description names broken, failing, flaky, and slow software, but not an Agent
Skill that fires unreliably. Routing canaries therefore let `writing-for-agents` steal the first
step even though the canonical workflow requires a RED trigger canary first. The local change adds
only that missing description branch; the body is untouched.

The v1.1→v1.2.2 upstream comparison is empty: `git diff --exit-code ed37663cc5fbef691ddfecd080dff42f7e7e350d 8b36d4fb2635b3c21998dcd8144439c9e5ba7302 -- skills/diagnosing-bugs` returned 0.

Approved tree SHA-256: `291698386c7fec63e5503b449df0fb3dc9579d1c2058804353c0160c1b6ef1bb`.
Evidence and the 21:00 control are recorded in
`proposals/2026-08-01-two-skill-tuning-audit/02-writing-great-skills.md`.

**Extension (2026-09-07):** user approved Astra audit items 1–6. Retain the trigger branch; allow code/log tracing and falsifiable, explicitly unverified hypotheses while a repro is unavailable. Keep fix/confirmation evidence requirements, and replace the fixed hypothesis quota with evidence-based ranking. The previous tree was `d044ea6809882228085061b89347026b7360e520cc4c68680d8f0eb359da21ba`; compare against local baseline `9de079a` for this extension. A fresh fetch of the pinned upstream SKILL.md returned HTTP 404, so direct upstream comparison is `UNAVAILABLE`, not re-verified.

On upstream update, compare both the trigger and read-only investigation branches. Drop each local override only if upstream provides equivalent behavior; otherwise reapply it and recompute the tree fingerprint. Run `tests/mattpocock-workflow.sh`, `tests/matt-thin-workflow.sh`, and `tests/vendored-detection.sh`.

## implement

**Decision (2026-09-07):** user approved Astra audit item 2 as part of items 1–6. Replace only the unconditional regular/full-suite test instruction with shared S4/evidence-integrity routing. Keep explicit-only invocation metadata and other workflow text unchanged; the shared kernel continues to own branch and closeout gates.

Baseline tree `08a0cb886cb9474eee27feb13ddb96b9087d90b39a6f9ff913195d9b60728bd0` matched the pinned lock at local baseline `9de079a`. A fresh fetch of the upstream SKILL.md returned HTTP 404; direct upstream comparison is `UNAVAILABLE`. Current tree SHA-256 is recorded in the fork index; invocation metadata and its manifest fingerprint are unchanged.

On upstream update, compare the testing instruction against the pinned baseline and this fork. Drop the override if upstream delegates risk-appropriate verification and repetition to the host workflow; otherwise reapply only that instruction and update the tree fingerprint. Run `tests/mattpocock-workflow.sh`, `tests/matt-thin-workflow.sh`, and `tests/vendored-detection.sh`.

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
- **`nothing else` + `Everything the next agent needs beyond that is in the document`** — the three
  required elements alone let the first live run (2026-07-31) produce a four-paragraph block that
  restated environment state already in the document; the exclusion clause is what keeps the block a
  pointer rather than a summary. A numeric cap (`at most four lines`) was added the same day and
  dropped 2026-09-07 (prompt-audit rule 1f, numeric output ceiling): a number tuned against one run
  over-constrains Fable 5.1 — do not re-add one.
- **`not a machine-parseable contract`** — prevents a downstream script from parsing the block and
  turning a human convenience into an undeclared interface.

**Extension (2026-09-07):** user approved dropping the numeric cap (`at most four lines`) from the
start-prompt sentence — prompt-audit rule 1f: numeric output ceilings come out and the surviving format
instruction (three named elements, nothing else) carries the bound. The previous payload SHA-256 was
`94b9c425dbbe1c5b3f788fbea1fd588b6c6fa9f5e1c5b8c2c201c07088204560`; compare against local baseline
`1ea47b2` for this extension.

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

Approved tree SHA-256: `1ba596aee238d4ca655adf6a4c3e66319d2695984e9a4cded21a87fb3f310c6d`.

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

## speak-human-tw

**Decision (2026-09-05, preservation follow-up):** Clarify the demonstrated mixed-sentence ambiguity: retain identifiable facts and tool use in the delivered rewrite, remove unsupported benefit language separately, and annotate only the missing effect evidence. Preserve the existing live FAIL as evidence, without attributing it causally to cutover. Add paired SF-30/SNF-17 semantic checks; Check-first, Annotation and safety boundaries remain unchanged. Re-merge only when upstream retains this distinction; roll back this follow-up with its paired evals and exact fingerprint records, retaining earlier forks.

**Decision (2026-09-05, user-authorized Sol/Astra optimization):** Select Rewrite, Annotation or explicit Check-first from the request; existing rewrite authorization no longer requires a second confirmation. Preserve technical/SF/SNF/secret invariants; demand-load history. Re-merge only when upstream preserves these semantics; rerun the recorded two-model canaries and repository gates after updating fingerprints. Roll back this batch by reverting its changes together with callers/lock records; do not remove earlier local forks.

**Decision (2026-08-29): accept a local fork for technical-work communication.**

The imported 10-file payload was first verified byte-for-byte against pinned upstream commit
`ee860be6fb190cbc53dc1d45a2a47c9c9c680243`. The local fork keeps the existing general-purpose
humanizer and adds only the missing technical branch:

- `SKILL.md` adds the technical-writing trigger, scene summary, protected-token invariant, and v1.5.0 record.
- `references/scenes.md` keeps outcome, decision, evidence, risk, rollback, and functional structure intact.
- `references/protected-list.md` protects code, paths, APIs, config keys, commands, versions, results, errors, and logs while redacting credential/secret values.
- `evals/benchmark.md` adds paired SF-28/SNF-16 coverage plus SF-29 secret redaction; `evals/trigger-cases.jsonl` fixes one technical-writing fire and one raw-log-analysis quiet case.

Approved payload SHA-256 `a34245a46b31c89369f708ff0a84c3da5bccc4fc141d157c887f7d21a4893acd`;
approved tree SHA-256 `5e3e7a4811ff46b811f4b550668564a4cd847abf3df5c5ad4a1fb77753c129d8`.

### Re-merge procedure (when upstream moves)

1. Diff the new upstream revision against pinned commit `ee860be6fb190cbc53dc1d45a2a47c9c9c680243`.
2. Rebuild the same transitive-reference closure plus `LICENSE`; keep the selection rule in `vendored-skills.lock`.
3. Replace the payload, then reapply the technical scene, protected-token invariant, paired benchmark, and mixed-sentence preservation boundary only where upstream still lacks equivalent behavior.
4. Recompute payload/tree fingerprints and update this section, the index row, and `vendored-skills.lock`.
5. Run `tests/vendored-detection.sh`, `tests/matt-thin-workflow.sh`, relative-reference checks, SF-28/SF-29/SF-30/SNF-16/SNF-17, and `evals/trigger-cases.jsonl`.

Rollback by reverting the fork commit: restore the pinned upstream payload and original lock hashes, then remove this section and its index row in the same change.

---

## test-gap-analysis

**Decision (2026-09-05, user-authorized Sol/Astra optimization):** Externalize the language mutation catalog, remove the claim that mutation score misses nothing, and retain static/empirical evidence, authorization, bounded process-tree timeout and restoration contracts. Re-merge only when upstream preserves these semantics; rerun the recorded two-model canaries and repository gates after updating fingerprints. Roll back this batch by reverting its changes together with callers/lock records; do not remove earlier local forks.

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
Local `SKILL.md` SHA-256 `61bc459dd039726ec6f42adedc2e8569743da00c69aafe52f336a1548b0f9f9a`.
Lock `payload_sha256` (hash-of-hashes over every file in the directory, the column's convention)
`4b95660dc88bde2ce3ba1bf301a48991603feae10dbf26eed02249b640437ff0`;
approved tree SHA-256 `4488dbf0b45a791650f4af4c23380be31fb4274378a3463ef8120ba36fc324a2`.
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

---

## tdd

**Decision (2026-09-05):** user approved the Sol/Astra optimization plan. Replace repeated seam confirmation and the blanket no-refactor rule with dev-workflow INT-2/INT-9 and S2 ownership. Independent behavior oracles, public seams and RED-before-GREEN remain.

Approved tree SHA-256: `adb945d6b36b9a54fb49817e76458ddffc4a0a275db91828f40e5d4bb4b39c42`. Upstream baseline tree remains `807b29b3f7d1ae9c14d8970ad981b697ad908af932b8aa74cf095f671038f346` in mattpocock-skills.lock.

On re-vendor compare the pinned Matt revision, preserve canonical authorization and GREEN micro-refactoring if upstream lacks them, then recompute this tree fingerprint and rerun workflow/caller/model canaries. Rollback: revert this local fork and its index entry together; leave the upstream pin unchanged.


## 2026-09-09 shared prompt optimization

User authorization: 「全部依照建議優化調整」 after the complete global/skill audit report. Delivery scope is an isolated local candidate; this record does not claim live-host cutover, PR, or model-canary success.

The reviewed source baseline is local commit `60c840b9cbb9933c2b943508b8d534c43910bcf9`. Every targeted SKILL.md matched the audit SHA-256 before modification; machine-local exec-briefing was prepared separately rather than silently added to this tracked corpus. Pinned upstream revisions and licenses are retained. For newly forked Matt trees, the unchanged local baseline was checked against the upstream-tree fingerprints in the lock; previously recorded forks are compared against their accepted local baseline, retaining their earlier upstream comparison record. The agent-browser wrapper has no pinned CLI revision; its live bundled core remains the syntax authority.

Changes shorten redundant description lists, split independently loaded setup/operation/empirical/report branches, align downstream setup/merge/review rules with shared authorization, and allow scope-preserving local disposable checks/fixes/retries. Explicit plan-first, reviewer read-only, protected action-time gates, unknown fixture isolation, production data preservation, and external-write authorization remain binding. No invocation visibility keys or implicit-invocation flags changed; the invocation manifest remains unchanged.

Current changed vendored payloads:

| Skill | Baseline tree SHA-256 | Current tree SHA-256 | Current SKILL.md SHA-256 |
|---|---|---|---|
| agent-browser | `8916f6658118cd35fb4db907128334782c6a984c809781cadba1555d651e8a32` | `677fcd1b5b89c9fbc42e2b1699332af58d55567ce63a184f1f33a1908cdffc42` | `439fa8c8a549f6e51fb6325c51e82a397179cddf47717fa87ef55a6abcd33f08` |
| ask-matt | `beb486c313e815a3381d4fbc1b1a05e935ce6b4d957f7b50dabd0d8c33318d2f` | `55c1bb438af24491d140f05ea644de7f8ff40756276915aba39458cc2b4d87f5` | `9b9dad77de6c55b64cb46010e02fc4a307e0535d6b9fda5713dc2a7efc224dbe` |
| clean-code-dotnet | `3f1cb3c62da34813c63d3d041feb0287044a5df5047f1cf824d95a25ba8f89b0` | `648eafb5e500fd97feecdfc5d59ad02d739bd268f0f2c078e2030bc14028d876` | `4253e2e6ba4b7a381a894f2d8c7ff0725f042a61ed46b93306f8ecbf0141b729` |
| code-review | `13c0fc08ad0b0d26be7229a16e9328ccfc40dd5c763d85079b5433646bbb2272` | `0554f1e9fa58138e5e692977d5b1d2ba97f446c5a9ae93e0d96cf1dc2e02e5ab` | `ac678b0e9de6363446c009939ca4e1b42cec5f19db8702e7c7e3fa6b5d4af52e` |
| codebase-design | `1a383c195d752de7f28a495f5fb3db54eaad06734c57ccd810390fe31eea9579` | `261b3b7c67fd41342fb83c3d0aa34d4a0637d26dc9b18fab7e975c50bc71d5c8` | `e06021f5798900e9cfaae4f6fcaf4aa2114d4e441336c5344e2561c15a4b4958` |
| diagnosing-bugs | `84993bd42da0fab491570f8c13d42b21b93286d956afa02047acaf6b8ed15a7c` | `e18cf293ae5b4d7962c4a80f7a92d1d653fa531fa91d1dd8d338aafa6d1a12fc` | `46bac7c608763dcb556979b9ab61f4857c3ec0f38581e5986667d26370f8f984` |
| grilling | `0595aaade00510aa08374ec337f1b926889595af83124deb84771d9f095cd4c7` | `686579e9cde62b7b4e993385e0b72d0292b5c3bc039b71ea0158834a4618dfc6` | `29f894e289a2969488d5e4ebba6e1ecf0e0ee96d9d3d5ca7c196615ec7dff85b` |
| improve-codebase-architecture | `5e331195ca420e2ea8258ed32fb054043f6ac521fdce99f520822cc8e254b8fc` | `78544103d7c78120e6fcdd2aecc2c89a0d403af1810e31c79a8e2feed9559670` | `f41ec6fd7e512946c4b513fba235f8742e64cab6eb9586fe619169b207a12937` |
| microsoft-code-reference | `8ee7c32860e0b751aeedcde1c84b725235ec1d2ac63ab9be5d3799ae26417a1c` | `8d7a68b5608140152957931c96d8700b6a9898032a90e9f72c269cb995be2048` | `d111de4973499376d87c7ba07026e749f7ff089350384ac4f3b2f6f3cbc0e6a9` |
| microsoft-docs | `e656618a3bc63d9d8d5bdc381f3eb1bf4327b9ef4bb22ff399c301551f421acf` | `c1cc5bf59d6113fee38facb5bd2fd0cc2cabf28303fa4975220b6f790c9e0d7e` | `70e57ed9ab0a2ec2c1bcaed7ff735886441248501d20128a0dd0f41481c48806` |
| prototype | `b58e8a09e2630c9ef3fd009562c33f1cc5770881854550be2767809b631fce4a` | `bba188786b02d904821b549b20c110286f59115f21dc7ffea099557df1d29097` | `35a7ad3d5597835ae75a02b90272bd540cc4e7a4ea45ac5e73726b00840631f5` |
| resolving-merge-conflicts | `52162eecbd8366e1d4b145e0964dfab7fe3cd534773d85e79c750f6e04aa65f5` | `b442690537b7375f2ea50da67aee174769b27dec9455ea62779f542340d51f60` | `ed21a7b205bdcd5d174c8591a1ba648dacb7b9e5d1114a3fcf9d2c2a21d316ef` |
| setup-matt-pocock-skills | `20fabc63fdb530037748eaf9b1a62a53ea91ac5a18cecc0fb001c3002b2673fc` | `04e5bd5e851a78da279cc7833cc15e43e3cc3f498502154710a0426777036389` | `efc377ed6804df4838a2594154b6e7507a328203418570ea33a5230cb3bcc658` |
| speak-human-tw | `e51d4b63b2ec7934f55cc0d239e73febd1214cb45cfc6ba3fab7db20d9a80384` | `81ad5747bb8442ad452f85d21f4dc1225f05e3980b3e0ce14e2906d431d509f4` | `306f441f8f4b851b102d33f89fd65830237e979ee888eab2b93e310a7153477b` |
| tdd | `331550f33e18c8938c55facb6470f6298ce7525605c2aa1986582571b430e461` | `d761f702fff6cfcfbba1bfe153b55055f62d667a831eb2cf3d7b230a50714df5` | `1df665fb821febb4ef110dbaee473bdf74183d3996e5465840ac778fb882e6ac` |
| teach | `10707673896f85135ada4425709be25a349ec85f576b5f9a7926615971db19b1` | `c9870a3a77cedfdd69a0812b37ed5c2394e073eff39d1c9d29c41a1dabaeae78` | `40b6e0c97d74dadfa41c3a26650ed88ff5a8cf50a9c2a918789b6cc31c970881` |
| test-gap-analysis | `cb642c4dc5b6fc0011144b08d5fdbd40a8e98e8e4cfddb6c45c3dcd275a42a37` | `4488dbf0b45a791650f4af4c23380be31fb4274378a3463ef8120ba36fc324a2` | `7420b0c0e3446348db4900f5c73c36a904dd256d87ad8a1c3dd066cc6ec6c06e` |
| to-spec | `7fe9db6b276a87383996b138efa07e7e20fb5fbec8bd6027e084733b48efba60` | `245203535a0dba3bd4c4925b5f76b60367d814b620f8506bc68d648a0831a202` | `dfc0ae7333a103a32ee9233e81372799104d5716e5183698987c22226c44b535` |
| to-tickets | `030ff9a692ff972061b8fa98caf5fd2cafd5c3b64d1f78480ba8c37bc6d5e454` | `3c510a1963e7a711ceb25f3c5747c0c5678f084349e59d319ae396062d05e52a` | `167daa43089ee030cd1ee9962bf4cea96cd8efb57d7ffd71c0d7baf35de8b037` |
| triage | `f627c556c9ced84f0f8cb529011655b28e85d77c8804bbb9c1cbfe0fdfe73be4` | `a6bd17ced740043523c08822bd21b9d93cfcf08890baa167b7f9bdd2e9640bc2` | `5a22f48927e28dcb9721721e592dc5c5f9c844f1be2d77a950f521fb0245c183` |
| wayfinder | `8c91f90c7129883d2c4cd1f7c255873e215c292801ecf4ed47af995a752b81dd` | `779de7ed2a2888676853f613560da7703cc38ec4b52d6005104dc4117122afed` | `2ed4b7faed29da939d6ccc7efaf9de1906cb3bed23d9b9a37053c703cd4ebda2` |
| web-design-reviewer | `f7fa17f95793aebd5ce22009d0354ea1e6dd778c227a83077b89832863dde48b` | `7d343d08b963ce92b8696574dc901ad1f89b4396bf6365b96d82849527ae4f44` | `4b61fab18888d2fa761f97b512fb59d9c29e741becc6346262271c608573424b` |
| writing-for-agents | `9374753ea57c4512799632b8a2568cebb70e66c017e2ebffaefa691a65767e46` | `e6473c2b453526a712dcf053a12b32f6faa4ed7519ad5c7c57ff7d1615cc37ff` | `4b7c5b26ab5125fe35bfc1890c2014fccfb59bff7f5720d077d968a5bee0e348` |

### Verification and re-merge

1. Compare the next upstream revision with its pinned source and the baseline above. Preserve only still-needed local behavior; do not drop downstream guards while moving prose into references.
2. Reapply the specific description boundary, owner pointer, and branch-only attachment changes approved in this batch. Keep existing licenses, user-only metadata, higher-priority authorization, and cross-host invariants.
3. Recompute `vendored_tree_sha256` and SKILL.md payload hashes; update this index, current approved annotations, and applicable lock entries together. Invocation manifest changes require an explicit separate decision.
4. Run relative-reference/frontmatter validation, `tests/conformance.sh`, `tests/vendored-detection.sh`, `tests/matt-thin-workflow.sh`, and affected workflow/skill tests. Wording-bound tests must continue checking the same behavioral constraint after its canonical owner or attachment changes.
5. Preserve real model before/after routing evidence for unreliable-trigger changes. An unavailable or rejected runner is UNAVAILABLE, never quiet/PASS; static checks are not model invocation evidence. Each consuming host/model remains separately reported before cutover.

Rollback: restore this batch’s changed payloads, new attachments, current fingerprint/index annotations and corresponding lock changes from the reviewed local baseline as one scoped reversal; retain earlier forks. Do not revert unrelated concurrent work or force-push protected branches.


### 2026-09-09 disclosure and description supplement

The same approved audit explicitly requires the five outstanding disclosure changes: codebase-design examples, diagnosing-bugs feedback/instrumentation branches, domain-modeling file-layout examples, React Router examples already covered by its existing references, and speak-human-tw rewrite/delivery details. Entry points preserve glossary/principles, red-capable diagnosis and cleanup, lazy domain-document creation, version checks, mode/faithfulness/secret boundaries. Six ordinary descriptions (grill-me, grill-with-docs, handoff, implement, mp-zoom-out, ui-ux-pro-max) now match the approved matrix; user-only and caller contracts are unchanged. ui-ux-pro-max offers materially distinct choices instead of a fixed count, retaining explicit delegated-choice and existing-target exceptions.

New Matt forks were compared against their locked upstream tree before the supplement; pins and licenses remain unchanged. On re-vendor, compare the pinned source, preserve only these still-needed routing/description changes, then refresh tree/payload fingerprints and consuming-host validation. Rollback restores these 11 skill payloads and six new attachments with the related index and lock changes as one scoped reversal, without reverting concurrent work.

| Skill | Baseline tree SHA-256 | Current tree SHA-256 | Current SKILL.md SHA-256 |
|---|---|---|---|
| codebase-design | `1a383c195d752de7f28a495f5fb3db54eaad06734c57ccd810390fe31eea9579` | `261b3b7c67fd41342fb83c3d0aa34d4a0637d26dc9b18fab7e975c50bc71d5c8` | `e06021f5798900e9cfaae4f6fcaf4aa2114d4e441336c5344e2561c15a4b4958` |
| diagnosing-bugs | `84993bd42da0fab491570f8c13d42b21b93286d956afa02047acaf6b8ed15a7c` | `e18cf293ae5b4d7962c4a80f7a92d1d653fa531fa91d1dd8d338aafa6d1a12fc` | `46bac7c608763dcb556979b9ab61f4857c3ec0f38581e5986667d26370f8f984` |
| domain-modeling | `1918befd92fd79e48b96698c79bdcea0b925b188d6c70004c077515153750101` | `1489186bdfdac8a94f7a5479fd737580d00132ba3a11eb7d5b8b872f36a6b262` | `89936c726bec0f8460b2325958c433df64f0e759d3f17ac31be664226192e102` |
| react-router-framework-mode | `80ff71ee21b3c8aadebefd7d59765f0b3b9f385f39b06bfc502d9f6b81f7ed48` | `3a1e41af471c0e86e9580dc8fe6d47eb290adaefb29aa2197dfcde76d28574a8` | `30455aaf9ff77c7581fe1efd8156497ff433cebef1e3f02335e81fffc692d491` |
| speak-human-tw | `e51d4b63b2ec7934f55cc0d239e73febd1214cb45cfc6ba3fab7db20d9a80384` | `81ad5747bb8442ad452f85d21f4dc1225f05e3980b3e0ce14e2906d431d509f4` | `306f441f8f4b851b102d33f89fd65830237e979ee888eab2b93e310a7153477b` |
| grill-me | `0da3a0d6c13e90dd18565754376f49c533a8779a6079c88e7a1bbc7d3dab4b10` | `102f60886284e139d580a2b4ad321e2470aa5d838edd5bc424b11649d7fde513` | `d54e4da99fd4bc4a1a21cb8ad371c67e18543825af0b2288deda8265501d3911` |
| grill-with-docs | `2709e7d916096a783dae120d269fa1b62e01bc58125ce6c58e4bf645adec766b` | `9e44d8a8d61d7561ed646054743b170792e06ec06491d1836053d46ab971db1a` | `efbddba4c9d22f4e05e37e9fb85ee0c0ef7ecb1e904c2c214f7b4f751ecfd69f` |
| handoff | `08e750e3c46431783cd5d54bc183d0f7383de404b3a9fdfb7e7f91b91c068413` | `bf149c42a210d0ecdd4f7c1a1914a842e369688f0db4e094adc4583a51e584db` | `b8ecbfb0706efc72b859f3387c741fe2d116df07f76ae0cab96be46bedcb9761` |
| implement | `bdf2616dab353cbc48103fb216df721ee52088f30c9e0fbae4897e49d3b3cddf` | `7dc10b8ca3a60bfbf7d6da70d8e8f326c51efc4dee2cb4612de0be2a50859e3b` | `c8af4bc392edae614c2c173bbee30534ee1ddec19226a6781ccfd08181395e66` |
| mp-zoom-out | `6865bea2ffaf170eb03060c631a8f8b9841c796a3ee9f0bf0ed1ef41a1ade4c5` | `92fc2574df79565b57ff030bbfc76412f43ebe3a9e00f98aeb50bcd994348f35` | `301816da5e996e61f17688aca4c6b1baa3d7efbb4c299290664fa1d2efba08e5` |
| ui-ux-pro-max | `d86dc3d84856b2bff0b2ae8fa2c9f4824f9cf3934e27ec28e0b05db1d2132aee` | `3d4961748d14b6f2c86da053dbf9658d8c3e224d51c460c044f6c2a6fa662804` | `f47a60591fae653545474aaf9c505cf3b869c2f603a5386e5791951b27906a3f` |

### 2026-09-09 Fable 5.1 audit delta

**Decision (2026-09-09, user-authorized, "全部項目依照建議實作"):** second pass of the Fable 5.1 / Astra skill audit after #147. Seven vendored payloads change:

- `codebase-design` — description gains the `/improve-codebase-architecture` whole-codebase survey pointer.
- `improve-codebase-architecture` — root-level `HTML-REPORT.md` and the card-field spec move to `references/html-report.md`; process, language contract, and user selection point unchanged.
- `microsoft-code-reference` — sample search, API lookup + validation workflow, and error troubleshooting move to three `references/` files behind a routing table; Tools and When to Verify stay in the root.
- `microsoft-docs` — Query Effectiveness moves to `references/query-tips.md`; the "Why Use This" persuasion section is dropped.
- `security-audit` — first recorded fork (Cloudflare MIT payload, previously VND by license only): Setup and Core Principles/Anti-Patterns move to `references/`, output directory defaults before asking; `README.md` file table and output-directory sentence synced to the split.
- `ui-ux-pro-max` — a request that already asks to build proceeds with the recommended direction; the selection gate remains for option requests or materially different scopes, delegated-choice and accepted-target exceptions retained.
- `web-design-reviewer` — description points read-only S5 UX reports to the `uiux-reviewer` agent; fix／repair／修 in the request authorizes source changes within the reviewed page, a bare review stays report-only.

`ai-level-check` is removed at the user's request (unused); its index row stays as the restore record. Re-merge rule: on the next upstream comparison, preserve only these routing/attachment changes, then refresh fingerprints and rerun `tests/vendored-detection.sh`, `tests/matt-thin-workflow.sh`, and `tests/mattpocock-workflow.sh`. Rollback: revert this batch's payloads, new attachments, index annotations, and lock rows as one scoped reversal; retain earlier forks.

| Skill | Baseline tree SHA-256 | Current tree SHA-256 | Current SKILL.md SHA-256 |
|---|---|---|---|
| codebase-design | `261b3b7c67fd41342fb83c3d0aa34d4a0637d26dc9b18fab7e975c50bc71d5c8` | `8cac9e5530b070d2d50e76b72cf442a0b387ef581639aac44849675c3ff998b1` | `4e823e6aa07d0f3dfdc26e9a4469b0e18ee20cdc5f41a2a4292207c4b2fc9e33` |
| improve-codebase-architecture | `78544103d7c78120e6fcdd2aecc2c89a0d403af1810e31c79a8e2feed9559670` | `e2989dc376bff6f0be13b3775734c496a10915fe60b8517614507339868d512c` | `5e523ec8230f846dc99df2e152f9625877dc72a151d7a476b45e8745fece4f29` |
| microsoft-code-reference | `8d7a68b5608140152957931c96d8700b6a9898032a90e9f72c269cb995be2048` | `be249a9695b5390872b4a46ec58240b2e433459ffe79e36ba706d1a6bcd330df` | `0f57a614dade3724286620208e2d83113b7318397ed73736e8f58f8f96af5366` |
| microsoft-docs | `c1cc5bf59d6113fee38facb5bd2fd0cc2cabf28303fa4975220b6f790c9e0d7e` | `9becdf0c515f00430ce7027f9224dc0ec114d6ff20923bfa9edc0c4cc5014d77` | `52e9c87431984bc0f2554c3084c8ce683a0eceea11f854507b3895c8b2a6ba0b` |
| security-audit | `32ae587e750309e92d02c4668a4411ca90adef9a36d38313783393e4e6c8f1d0` | `17e3b83a848b93e6778e711af29f0c4964431ba086b713addb8760bf0d4f5fc5` | `52b4d1f83b9664d252b2fb482857147c1abcb78a7aa0c662cdcf00de58c5f2d3` |
| ui-ux-pro-max | `3d4961748d14b6f2c86da053dbf9658d8c3e224d51c460c044f6c2a6fa662804` | `5e2180d732f14b1bc7cc185986313f8b4fbdb9126b1d0dfc5eca4025b7e4d707` | `f8241708f9860756b107917ac7e452fdddf17dcaae4cb123497250b91ed9c255` |
| web-design-reviewer | `7d343d08b963ce92b8696574dc901ad1f89b4396bf6365b96d82849527ae4f44` | `e02224e287fc99c6ef7ce52e9bb403d250a1b801761a59e2ade850e95c7aec23` | `778f4e658e66b11d8039c1816301fe67525c38e838936bbec3687a978aac8033` |

### 2026-09-10 shared audit maintained override

User-authorized implementation of SH001–SH074 from the approved 322-item assessment, Delivery Scope Local-only. Existing licenses, invocation manifests, upstream revision pins, and archived payloads remain intact. The research upstream-identical tree row moves from the lock into its recorded-fork baseline above; the upstream revision is unchanged.

The index and specifically labelled current approved fingerprints above describe this candidate worktree. Older batch tables are historical snapshots. Complete per-file fixtures, hashes, checks, and rollback instructions are in the machine-local package at `docs/skill-overrides/2026-09-10-shared/README.md`; it contains private fixtures and is intentionally not published. A fresh checkout can compare tracked changes against the original baseline with `git diff 6017129b952d48803c572d6fb11fb658e89bafc3 HEAD`; private fixtures are not available from Git. No live payload is activated by this record; host cutover belongs to the parent.

On upstream refresh, compare the original revision and fixture, retain only still-needed scoped authorization/routing/disclosure changes, refresh candidate hashes, and rerun affected contracts. Rollback applies the manifest's exact before fixtures only after confirming current hashes still match the after fixtures; do not overwrite concurrent changes.

| Skill | Candidate tree SHA-256 | Candidate SKILL.md SHA-256 |
|---|---|---|
| acquire-codebase-knowledge | `9b5e6c39c86d320827708a2e0ba281ca703cbfbf74cc3a481689dff108344dee` | `b0ddc523f61abb775f8b9c83e1a3e9d15f01305cd4360e0d845c33b8745106bb` |
| ask-matt | `0a3e6cd9b9cd4a06edd26c27d3caed25636521f04c0ba70c14daabeaf967091b` | `9b9dad77de6c55b64cb46010e02fc4a307e0535d6b9fda5713dc2a7efc224dbe` |
| agent-browser | `85cdaedc49a2bc0604de81017422e744fd01ee1b299c64a6e83b9f1a85920c75` | `9fb4dfbebbbaab5358a3e9d969cd42db89546d645f2a4d3f4e34e67912af720a` |
| apple-calendar | `e74cee7fff041c52cb0848b8cfe3eecc52dded7b64d1fcfd133cc215bbb656c0` | `123152bcbce8bcb07189ef738b13d86da66ebbfe6296f17db96ac1007d724b26` |
| aspnet-api-architect | `27b0057f57f228bcc32735b2b8414882220eefb0333b6a57bb57d728e01a47df` | `c0266ccc0e22c543177b2f4d670ed2cf448257eb39d5751e10cb189ffdde892e` |
| auditing-skill-folder | `8e34f68c1d5c76aa4e64ddb5060e3ff65319cddc18c27b34cb63cb79bf64e391` | `ad7880ab9262ff48b968657062a559e99cdd9eec1fa148680df9bec8e279b031` |
| bug-fix-settlement | `c00d969753beaebf16315648204ec91a3ff29ee0c32c4279b3bff9e1ad25fb16` | `0e079677d3f769efb8654d573ac5668b05d6833b645414fd839137d004b9fa72` |
| c-cpp-best-practices | `5852ca3d02b9ce82fb1823399157f85903d275d56a8dc98fbf9ecc5097d22a81` | `8faeff110dcbc43868bfda0d845ccd3e3248233aa421503c12078ebcd147c7ad` |
| clean-code-dotnet | `ec219244eb5c194376737b6bae6894c83c13ae3fadcc7182687d138182663153` | `3d49eca204a0ad2c8022de16389b6f421af8967b9dd8d4b83626255106c07572` |
| code-review | `e404954a8a0123e1933fc02d66ddaed079f425622089afca2d445b99426c6179` | `b2102d077035ab62f6c352caf9e1315276c25c1c8851e3fd14f0473aa7b41631` |
| codebase-design | `628d0fbe2aeea1996204f657dabaab1e0ff034830d3585de91e067c3206ff128` | `1871eff971a67944a7204f5b4f0fa4bc4cdd4934d9924e795bdb85ddba1fba04` |
| css-ui-best-practices | `b99bfb85e1825bbe8c9a79db2d557ecd6b36647b6a36735c1416be5ef962c39e` | `769da2a89e4908c866dc163d668c9a0adf97450c4930e5a8f10d27689b11863c` |
| dapper-best-practices | `c97379e2f65e555c3429278acdc50ccf85fcd97f526e5261edcb610183228544` | `33fe67e96cfa1954abc7b855d2b31ada1ffe5e2170b7f0666fe2a70d914177c8` |
| dependency-security-scan | `8a84b4f24032535b90f420760d545774061b389d83bdd5abbadce01e8bffdf6e` | `d11388da203125648f12dff7ef88a27003f3a70bfd98c325642323b34e0642d9` |
| dev-workflow | `b2094de462439f2dbd14924d6a32228ec0a399a18c6e79f2ba8d9b55a4674a38` | `cd27c4c36d437d8d0808cc431c6d50109e0fa8993f1e477950dbbed84b7fd6df` |
| diagnosing-bugs | `291698386c7fec63e5503b449df0fb3dc9579d1c2058804353c0160c1b6ef1bb` | `201616eedc945503c20a74ce0e8ae4add8dc4afaff8f3c97acec5ef7b47a1ef9` |
| domain-modeling | `43720a21f56e478a1596f0343a9b74f5ae6eac273811aceab671383ac460e5a2` | `197cf181455dd2b3d7fe3623bf82d199963e175dc5c15403af1d5b115796c5c4` |
| dotnet-core-best-practices | `4ce349aa2b90e3f29a6a232352510c977365887d972f9f2c11f90b75461b9599` | `91d878b28f34d4abc680fdc73d26fa9452b86f2fa98991c2695dc44194a1954f` |
| dotnet-framework-best-practices | `121a7586574028f930d1dca43aacb293708795404230b2e66b8a11c57bc8f3a7` | `b2cd2d193709307adbbe04c3f666309887e7908fb8d3b6fa18e8e464322ea202` |
| dotnet-logging-best-practices | `07bb3ad20efc68772177ddc4dd95aebbf6f2c65f281c218f1cb0a7cb17873bef` | `b7183b1b9ca5cf7ce2bc9c1526022e9a1e08fa90310cc0cdf4974087247c50f2` |
| dotnet-winforms-best-practices | `6a6b091a4db810bcb30f8c17b01c2260867b928e9bf4e5b5eb20be2e7cf06913` | `c25301e3b66eb0b4ba480dfa9597d7a7d5f03217268cdb609c83a7d9ab5173c2` |
| ef-core-best-practices | `9a5ac078a04fb5cfac4bf32b31c58190c5f0936cd3f8b2017659e1c4a567c4aa` | `2c81591ee1d652cdd69f90284ed836c7e3789eae16037aead9f0d3b3daa24048` |
| ef6-best-practices | `023c9e45d152649bd158233c814e82d3dfc4645004989e086acf1d2f8ac999b0` | `3744520e3bd0977d765214be595905686a82f66b68e48978a9d61b48e9cc8096` |
| exec-briefing | `e095e2f573155c4c55037cbd2839c5c9759576cb7950e7be5ba82d6fb08100eb` | `6a55f97a792de2c8d1a9a2c8b187da4948dc1102169d95d923c085e981d945c6` |
| frontend-release-verification | `d5f21add181c4720d29a4401e90dee07e70e7e298707e1e749f5244a750608ff` | `4173ca9c9bdef47bf312a07c8c2db6e5687084db3d8044c2f1315e74e6ea9a89` |
| grilling | `f9702850e9fa9a2fb264e877eeb5899deac4c09a05c01df0cde526a1d53160c4` | `d3c4cd7caf20eeae2004190c387f09fe80ff06d4f9cea20e90d6fa0745967ca8` |
| implement | `031b9b743fcaedc0fa57f446712d5730a2c7d5c0f10f99c2f08c93122a2ab206` | `555457452b1f76a58ab516d5ed39fc65f427aa98a052e8df76216639e86a645e` |
| improve-codebase-architecture | `a52d5278556bce310ee50d64e00ac10c381a78302c01be5fe038c65507d311c1` | `2dc64caf0299cb298bb8fe7618407f1a441a376d0c14282d802931dc49d1dab4` |
| init-project-docs | `2fb78eb6ea24fa14409ec8bdd340c7ccc1db3bb1853fe2f5353979152c219276` | `6c888be764ddc34e354f7195b9ddb45c1f61e0c981d27e61423973018195f6ac` |
| jest-best-practices | `0e6a053968a416681ebec39b49f3cbb3735201dd68a807f37bdbed9e63431d28` | `3d10acee92e2cdfb8922d546d42da5f6a0ded573b5b9782184ecc02951b8875e` |
| mysql-best-practices | `c99370462845e06a0b88ecc5b310d623720f5b6c06552b8787547b9fcefe9b94` | `8e660d9eaa6b6461c5e71fc880b73eb475cb551d9cb8b933c6efe9705324f95e` |
| next-best-practices | `7a96bfb88ddbb38af2830f6df37fc28e0a56075d73af62125701c055683db4ab` | `3d7faa6eacc7266789f72a0ada344e1e014d9378f01981b60601b20c289c1d97` |
| nodejs-best-practices | `20498638a417d81292ce673d19b3383610b79981e03fd22ee0453730cc151c46` | `1dc68efb46f85f03e34590f6951b9e159b2411a4247d2f5d1d46333b4745d4fc` |
| playwright-best-practices | `a14c2bca1f11a8665f30cfdc0595c15f5d57cdb3af42aab6e18a2238ba2e9f08` | `595b525ede80e92cf617e2f81c61c10ad296ed2326d49890dc8b0b5e0aeb1558` |
| postgresql-best-practices | `91b69e636cb33d8f8c3609b235acb59ca2566db65a6a6fdf703faa0f30da4007` | `5b9810ac08488071b9e5e8c370dd33212e2c2c1db3d4002efee20bcb7e7372d3` |
| postgresql-optimization | `45188feacc55240882eb226e9beae48b50f17fbd367628b4297baaef01fe247c` | `f806f37c63c43193d886fc49ffeaad14dd7e31b424cea5e656fdaf8391a6e178` |
| react-best-practices | `e3931362133299e10b46ce13f0d7b2b1e5a5bc00b91143837a90141cc490ab31` | `bca124ac6a8ecc306461e9a1af18bc1fcf1697a8c19c709fe9d643f419f35eb5` |
| research | `91bac5b97b47cd81d7c333b1484b98d4f0d2b6435e9f2f37ce795360f58183d8` | `52945b9041a4ffe93bb380db5e77dc46ac3f1edc7c111dbeb96051a1227c1e01` |
| security-audit | `1f675cc40bc37cb2d043a73bab8600ea9fffb534310b1bf079fdb9656a4fd531` | `a146dd2a5b06ed476885d36b2653e4b83a79cec4a0d225cf25d824c36b8489a9` |
| setup-matt-pocock-skills | `8b7884991baff72c74b6773404d13105976c6229d683cafb2a58165370585631` | `f52a7ecb62f61e0b42a75b2937666e80495480b74109802d994fcfb588dffbb5` |
| shared-security-review | `b035fc8218ad8cea5729f304852482ce2da4b5cf686da00cc619b8c313fe6eb1` | `e7c8f4d4cd61febbfde08b1e44422e1705479fe6860e6bf8f7e0dc1b5f70989a` |
| speak-human-tw | `5e3e7a4811ff46b811f4b550668564a4cd847abf3df5c5ad4a1fb77753c129d8` | `059d6074a27fcd48684fbbd07270e8a3d9dc4198f69b18baa792cdaf851de1ea` |
| tailwind-v4-shadcn | `7c8ffe8eb2fb601f9e4dadb18ab0efd2091a1292c874d026a510228a01077b95` | `f8513a1704147c9cf3ecf75cc2a991adb4c04864cd3608bcd841ed5efab61c79` |
| tdd | `d1dfcd70fe2940d4231d4be2cb2418713fd6776d749941638137b83945029207` | `7f674420104ea3db80c8192ca4e5a7b5ebe262d60f1d87e4efb39ccd88a25def` |
| teach | `2ba4420265e8e9aceeed1776e27235cc551df4fffe529ae74ae3493f8b72860b` | `e8db656c58d3e0d29633acbdd527c6936f1e0befb089d80154fdd5d1ba524ada` |
| test-gap-analysis | `08366541fafcc856569cf5de0946d3e60806741880b070a7e7891343fde58380` | `9c0ff68f06f857a5cce49270f1b15e945d3aa63db553d73797d501e291e00237` |
| to-spec | `f376e4846d39646535e6aa708ce142d8a5c01eaac95cd2fdb519c8e2aff7d08e` | `f7b1c09a82dc52e41c5e0e54f1d1b694e82ac5de61f576aa0836a6610fc23b2f` |
| triage | `a10173ea5cf4563fceb4b23a0749fdba0762449c4a2a9ef3b7dcd124afc8a623` | `a6a8fca8fba61617bcb6e94a405f2f49cd4908a2be9ac956425819d23283f293` |
| typescript-best-practices | `73c21ca5f90fef502dc639b2f33d5dec22de3e9409229068a47c8fb1d7daf177` | `9beb4454c4193d57b3925fb2ab4e392e391c8192d6e60f5f02d2e3d48545f712` |
| ui-ux-pro-max | `20a373233625a27d8118204b18686f9c7b7e30f85f12da36e817e81740fb1d36` | `cb1c626913d216962c7d3e61eff3446b37297095439474e268c8318ba771538c` |
| vite | `8bdafc20bd8c436bf5eca9f7ed8e654d738f12543556f01d4430e83a74046f7c` | `1292d24e9751916f3dd4d52b7a97333d4f0b52f842095420bdb0eabc2159e7e9` |
| vitest | `3c51312772f9819717d03ee11b3b048866fd40970a822845c73ae138cf8e3f87` | `688b204c57d48f8775993573fbb76e2bc8e57006ad6de5c2f7dcd83e069ff445` |
| vue-best-practices | `a17da191a4e8004a7117389f9b6461b9575c859e994c0fcf4aa02142993174ae` | `991356a89fcc53258870a6af9b019e8f957d0405ae331f6d01a91ced87525dd8` |
| wayfinder | `1602431050363c55074639577eebbf4dbd5ca887aec80e40d000cbc65b581225` | `5789d703dd028d917ffeebe639f4a2526e6468582fbb3f5b595d2530a56e0cec` |
| web-design-reviewer | `9cb920d7a0ff465228ce4b9ed005ec4b8ea259d2921f49be34ce9454f654c4e4` | `d3b87a8cc6068fa411f93bd2a7f887200145d42daa6b7e744af5467301ed564d` |
| writing-for-agents | `1ba596aee238d4ca655adf6a4c3e66319d2695984e9a4cded21a87fb3f310c6d` | `ed9c3519a5abeb0b7c03e442b681c12001e97ea2551aa0253185c707f8b5f4e3` |

### 2026-09-11 Opus 5 compatibility and factual-correction override

**Decision:** the user authorized all recommended shared remediations. The active and retired skill
corpus was audited against Anthropic's official Claude Opus 5 prompting guidance. Generic fixed
agent fleets, nested context-offload, and a duplicate verifier fleet were removed where found.
Task-specific repository checks and the independent adversarial validation for whole-codebase
security audits remain because they establish source-bound completion or exploitability rather than
asking the same model to recheck itself.

The Matt payloads were compared with locked upstream commit
`8b36d4fb2635b3c21998dcd8144439c9e5ba7302`. `security-audit` was reassessed against Cloudflare
upstream `d24bc269171a9171fac58493e0ffba511d571a4a`; the existing local split references and narrowed
trigger remain part of the recorded fork. `tailwind-v4-shadcn` retains its `9fdb7f2` local upstream
snapshot because the upstream package was renamed and restructured. Licenses and source attribution
remain unchanged.

| Skill | Before tree SHA-256 | Current tree SHA-256 | Current SKILL.md SHA-256 | 2026-09-11 delta |
|---|---|---|---|---|
| ask-matt | `55c1bb438af24491d140f05ea644de7f8ff40756276915aba39458cc2b4d87f5` | `0a3e6cd9b9cd4a06edd26c27d3caed25636521f04c0ba70c14daabeaf967091b` | `9b9dad77de6c55b64cb46010e02fc4a307e0535d6b9fda5713dc2a7efc224dbe` | Research no longer forces a background agent or repo artifact; shared INT-4/S2 owns those choices. |
| codebase-design | `5d83418ecbaa7499a43a017780ff2ab5f61d5b613326fcb660a67d04b5b16b1f` | `628d0fbe2aeea1996204f657dabaab1e0ff034830d3585de91e067c3206ff128` | `1871eff971a67944a7204f5b4f0fa4bc4cdd4934d9924e795bdb85ddba1fba04` | Main context owns at least two alternatives; agent use is conditional and has no three-agent floor. |
| improve-codebase-architecture | `9c57cc581b532e7dbf752d09f15b06dd61e08199f151684da72accbddb96c8c7` | `a52d5278556bce310ee50d64e00ac10c381a78302c01be5fe038c65507d311c1` | `2dc64caf0299cb298bb8fe7618407f1a441a376d0c14282d802931dc49d1dab4` | The deepening entrypoint now describes alternatives and leaves delegation to the routed design workflow. |
| security-audit | `155518fb25be3a8d88566ea7fc051aef82b57bb2b4a11886f63793c40693a82c` | `1f675cc40bc37cb2d043a73bab8600ea9fffb534310b1bf079fdb9656a4fd531` | `a146dd2a5b06ed476885d36b2653e4b83a79cec4a0d225cf25d824c36b8489a9` | Recon/hunting use conditional delegation and scoped Phase 1 context; Phase 3 uses a separate validator or the defined fresh-context fallback, redacts sensitive candidate literals before prompts or retained artifacts, and keeps Phase 5 limited to validated content. |
| tailwind-v4-shadcn | `bbd4b1098c7ad46d915a8238ec870c787811328b43d9535cdc8f54ee3d78e493` | `7c8ffe8eb2fb601f9e4dadb18ab0efd2091a1292c874d026a510228a01077b95` | `f8513a1704147c9cf3ecf75cc2a991adb4c04864cd3608bcd841ed5efab61c79` | Color guidance preserves valid project-native oklch, hsl, and var formats. |
| wayfinder | `e9ee62e139a829fbc9cc3d43f6fb5c3a95e201bc5aea54010afe9fc0e78fb2d4` | `1602431050363c55074639577eebbf4dbd5ca887aec80e40d000cbc65b581225` | `5789d703dd028d917ffeebe639f4a2526e6468582fbb3f5b595d2530a56e0cec` | Research tickets follow INT-4 and their authorized output contract instead of spawning one agent and branch per ticket. |

Re-merge these six skills by applying only the still-needed deltas above to the named upstream
revision or successor layout, recomputing the tree fingerprints, and rerunning
`tests/mattpocock-workflow.sh`, `tests/matt-thin-workflow.sh`, and
`tests/vendored-detection.sh`. Rollback restores each listed Before tree from the reviewed baseline
and reverts its fork-index annotation, current fingerprint row, and corresponding regression
assertions as one scoped change; retain earlier fork history, licenses, and unrelated concurrent
work.

### 2026-09-11 S5 review follow-up

The independent Standards/Spec review found three remaining contract gaps in the approved candidate.
`acquire-codebase-knowledge` now keeps focus/read-only scan output in the session, withholds an entire
manifest preview when a credential-shaped value has an uncertain boundary, consumes quoted dotenv
logical values before looking for the next key, and reports TODOs as path/line/marker only. Its review
baseline tree was `a6586bf08a5d799309b2b30046b77da64a6f396ab5ee3226b1a1f49f7ec69d6b`;
the reviewed candidate tree is `b03e1967cb4b00f32b711e88afd081ee9b5dd2af645f776c89fecb0fd78aef6f`.

`init-project-docs` now accepts the shared Claude/Codex/Copilot path shapes, reports malformed or
missing targets as `NOT_RUN`, and executes the repo command with Bash `pipefail`. Its review baseline
tree was `b306e6cfd675802df4e5a71b5e0514deef33451c91fa7ddac3de6ab11760bae1`;
the reviewed candidate tree is `29932a08dadf116630b4decccfd9f3d07bc0a6d4ddaee56dc4693f0f656d93da`.

`security-audit` now constructs all `report-schema.json` factual and remediation fields before its
single independent Phase 3 validator, derives reports from that record, and sends any substantive
change back to the same validator before Phase 5 serialization. Its review baseline tree was
`f7e103352aa9a8b2f45a0937507bb146487eada1b7fac386af88ddda73885ab4`;
the reviewed candidate tree is `e62ccc330add8d1ecab0f33ab8cef7b36e64ab894253544a8a8852093e198539`.

The retained regression starts at 499 PASS / 12 FAIL on the reviewed source and reaches 511 PASS /
0 FAIL after these fixes. Re-merge keeps the conservative summary boundaries and complete-record
validator loop only while upstream lacks them. Rollback restores each named review-baseline tree and
its matching assertions together; it does not recreate deleted historical evidence or modify a live
host configuration.

### 2026-09-11 PR review follow-up

The PR review found credential-boundary and orchestration cases that the prior regression did not
cover. `acquire-codebase-knowledge` now recognizes `auth`, `authorization`, and `credentials` keys
and withholds malformed XML credential values that lack a closing tag. Its before tree was
`b03e1967cb4b00f32b711e88afd081ee9b5dd2af645f776c89fecb0fd78aef6f`; the corrected tree is
`2146852b0527f1748c7cb0524cd0e7f5fddc5cd4115a1860208c1de3cefd2a72`.

`security-audit` now keeps each delegated prompt to the relevant Phase 1 excerpt, applies INT-4 to
attack-class splits, and has the coordinator make evidence-backed substantive corrections before a
fresh independent validator checks the complete record. Its before tree was
`e62ccc330add8d1ecab0f33ab8cef7b36e64ab894253544a8a8852093e198539`; the corrected tree is
`ff80a49843e5f518e3513121a760b543065cb8902a8503a12da9cb0a3b9a71fb`.

The focused regression starts at 511 PASS / 7 FAIL with the new assertions on the prior source and
reaches 518 PASS / 0 FAIL after these corrections. Rollback restores both before trees and removes
their matching assertions together; the earlier reviewed candidate and its historical record stay
intact.

### 2026-09-11 independent PR review XML follow-up

The independent review of the PR correction found two additional XML credential shapes at the same
preview boundary: a credential element can use a namespace prefix, and generic XML elements can put
the bounded credential key in a `name` or `key` attribute. `acquire-codebase-knowledge` now withholds
complete and malformed previews for both shapes while leaving safe near-matches visible in stdout
and authorized output mode. Its before tree was
`2146852b0527f1748c7cb0524cd0e7f5fddc5cd4115a1860208c1de3cefd2a72`; the corrected tree is
`a5c0078a864671e95b8a772a6343ae387ebbbff90f7231f5db6403ef67d26ca5`.

The added regression starts at 518 PASS / 1 FAIL on the prior source and reaches 519 PASS / 0 FAIL
after the scanner correction. Rollback restores the before tree and removes the XML-boundary
assertions together; the earlier review records remain historical snapshots.

### 2026-09-11 second PR review follow-up

The next complete live review exposed seven further contract gaps that were absent from the frozen
review snapshot. `acquire-codebase-knowledge` now recognizes compound `secret_key_base` / camel-case
and `signingKey` credential fields; its tree moves from
`a5c0078a864671e95b8a772a6343ae387ebbbff90f7231f5db6403ef67d26ca5` to
`2e5d14be9fc227bf4080b10eb0d3b0f4936ab6af4ccdeac95faf8c26682fbffa`.

`init-project-docs` now preserves the environment file target when `jq` cannot parse the payload,
streams command output through the existing 30-line bound, recognizes C#, Python, and Go test-file
names, and aligns the Phase 2 merge text with complete wrapper-metadata identity. Its tree moves from
`29932a08dadf116630b4decccfd9f3d07bc0a6d4ddaee56dc4693f0f656d93da` to
`7826f2fe1f3fb8972289e3312dbd03e2fb6314b7e8d8b16bed43c34803bf741d`.

`security-audit` now persists an unavailable validator's complete candidate in
`UNCONFIRMED-CANDIDATES.md` outside `findings.json` and gives optional hardening notes an explicit
non-finding evidence boundary. Its tree moves from
`ff80a49843e5f518e3513121a760b543065cb8902a8503a12da9cb0a3b9a71fb` to
`1f5214a6852eb795dd5b45273ea2478162778157c99735ff764449e4178f834e`.

The combined regression starts at 518 PASS / 7 FAIL on the prior source and reaches 525 PASS / 0
FAIL. Rollback restores the three before trees and removes their seven matching assertions together;
the earlier review records remain historical snapshots.

### 2026-09-11 current-head PR review follow-up

The current-head review found five remaining gaps across three existing contracts.
`acquire-codebase-knowledge` now treats a bounded credential key plus its assignment separator as
sufficient to withhold a manifest preview, covering empty, comment, and block-style YAML values
without broadening safe near-matches. Its tree moves from
`2e5d14be9fc227bf4080b10eb0d3b0f4936ab6af4ccdeac95faf8c26682fbffa` to
`083efa946154b1657d37e830c234948aec76e98c89c44bf68fd75587ed8619bb`.

`init-project-docs` now includes Python's `*_test.py` convention in the existing test-edit recursion
guard. Its tree moves from
`7826f2fe1f3fb8972289e3312dbd03e2fb6314b7e8d8b16bed43c34803bf741d` to
`2fb78eb6ea24fa14409ec8bdd340c7ccc1db3bb1853fe2f5353979152c219276`.

`security-audit` now states that independent validation is required to promote a finding, lists the
conditional `UNCONFIRMED-CANDIDATES.md` artifact, and reloads retained records for Phase 3 on later
runs. Its tree moves from
`1f5214a6852eb795dd5b45273ea2478162778157c99735ff764449e4178f834e` to
`4006c5fa0159040b65a491c430db721308e5022db002599fb0845fb6be2ae6ce`.

The combined regression starts at 523 PASS / 6 FAIL on the prior source and reaches 529 PASS / 0
FAIL. Rollback restores the three before trees and removes their matching assertions together; the
earlier review records remain historical snapshots.

### 2026-09-11 second current-head PR review follow-up

The next current-head review found six corrections across the existing scanner, audit-validation,
coverage and provenance contracts. `acquire-codebase-knowledge` now recognizes the compound
`AWS_ACCESS_KEY_ID` credential key. A separate URL-userinfo-only fixture verifies both output modes;
that detector already passed on the prior source, so the review's missing-fixture premise is recorded
as false rather than as a source defect. Its tree moves from
`083efa946154b1657d37e830c234948aec76e98c89c44bf68fd75587ed8619bb` to
`9b5e6c39c86d320827708a2e0ba281ca703cbfbf74cc3a481689dff108344dee`.

`security-audit` now defines its independent fallback as a distinct fresh-context, read-only
reviewer with pinned-source and field-evidence receipts. Candidates are field-complete but redact
credential values and other sensitive literals before entering a validator prompt or retained
artifact. Its tree moves from
`4006c5fa0159040b65a491c430db721308e5022db002599fb0845fb6be2ae6ce` to
`1f675cc40bc37cb2d043a73bab8600ea9fffb534310b1bf079fdb9656a4fd531`.

`vitest` now labels `coverage.thresholds.autoUpdate: true` as an explicit opt-in that requires repo
policy and authorization because it writes the config. Its tree moves from
`078b26acb6760cb38df9084260b51cfa6a8e53d034694548ae7c2dcd1e70d6e0` to
`3c51312772f9819717d03ee11b3b048866fd40970a822845c73ae138cf8e3f87`.

The combined regression starts at 529 PASS / 6 FAIL on the prior source and reaches 535 PASS / 0
FAIL. Rollback restores the three before trees, the current provenance fields and the matching
assertions together; earlier review and tree-transition records remain historical snapshots.
