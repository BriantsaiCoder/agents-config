# Shared skills tuning closure — 2026-08-02

## 結論

- 原始母體已逐支 closure：`76 active + 5 archived = 81/81`。
- 「已調教」不等於「每支都改寫」：只有有 factual、routing、scope 或 information-hierarchy finding 的 skill 才修改；其餘保留其 unique value，避免製造無收益 fork。
- Batch 3/4 最終沒有再移除 active skill。`clean-code-dotnet` 與 `dotnet-find-bugs` 是兩個 provisional retain；前者需 temporary-disable A/B，後者需先解決 replacement namespace/canary，才可安全 archive。
- `dotnet-test` **不是 benchmarks-only**。它仍是 routine `dotnet test`／coverage execution router；只有 BenchmarkDotNet 是未委派的深入 procedure，因此目前不改名。

Inventory 原捕捉於 patch-equivalent Batch 2 snapshot `ea475bbe014f6be29f1140dda2162402090ea905`；final candidate 已 rebase 至 `main@6584d62`，76-skill set 不變，再加上 `attic/` 的 5 個已歸檔 skill。A–I、M–W 分組原本漏掉唯一的 J–L skill `jest-best-practices`；closure 時已另行補讀並驗證，未把 75/76 誤報為全量。

## Batch 3/4 實際修改

| Skill | 調教前 | 調教後仍保留 | 最終處置 |
|---|---|---|---|
| `aspnet-api-architect` | description 同時宣告 generic review/MSTest，會撞 .NET owners | requirements → design/tasks → authorized scaffold orchestration | 窄化 trigger；generic ASP.NET review RED→GREEN 改由 `dotnet-core-best-practices` 接手 |
| `bug-fix-settlement` | main 1299 EFF，混入 rubric、examples、templates | root-cause settlement、mechanical-vs-doc 判斷、authorization boundary、visible summary | main 377 EFF；詳例下沉 `references/settlement-guide.md` |
| `clean-code-dotnet` | 1899 words，重複 SOLID、async、editorconfig 與 generic C# ownership | 360-word C# readability/naming/responsibility/SOLID judgment overlay + illustrative SOLID snippets | recorded thin fork；刪除重複 refs、修正 snippet correctness；仍為 provisional retain |
| `css-ui-best-practices` | 把 WCAG 2.2 AA 說成 ADA/EAA/EN 301 549 universal legal floor | CSS/UI/a11y implementation checklist | 改為 WCAG 2.2 AA default target，法律標準依 product/jurisdiction 驗證；ADA Title II 實際採 WCAG 2.1 A/AA，[官方規則](https://www.ada.gov/law-and-regs/regulations/title-ii-2010-regulations/) |
| `deps-check` | main 1127 EFF，內嵌 script mechanics/hook sample | fail-closed caller inventory、exit interpretation、fan-in decision gate | main 307 EFF；mechanics 由既有 script 擁有 |
| `dotnet-core-best-practices` | Controllers-only 與 Global CLAUDE stance bleed | modern .NET DI/API/runtime diagnostics | 改成 requirements-based endpoint model；移除 host-specific wording |
| `dotnet-logging-best-practices` | description 宣告 tracing/OTel exporters，但正文排除 distributed tracing | structured logging、redaction、correlation/logging scopes | description 與 owned scope 對齊 |
| `frontend-release-verification` | hard-code `npm run build` / `npm ci` | risk→evidence map、browser/RWD/a11y、三項 deployment safety gates | 改 repo-configured package manager/scripts；未弱化 mandatory gates |
| `init-project-docs` | main 1146 EFF，重複 Phase 1–7 與 catalogs | host confirmation、catalog selection、baseline/merge/secrets guards、validation | main 498 EFF；細節由既有 references 擁有 |
| `sdd` | Batch 2 後仍 722 EFF | proposal → implementation → optional archive、approval、≤3 tasks gate | 再縮至 418 EFF |
| `testing-library-react-best-practices` | Vue component 與 Pinia store 一律路由 `pinia` | React Testing Library query/userEvent/async workflow | Vue component/composable → `vue-best-practices`；Pinia store → `pinia`；RTL 3/3 PASS，與 ASP.NET 合併 post-canary 5/5 |

`playwright-best-practices` 經實測未修改：Playwright test 與 explicit Playwright MCP 兩個 fire case PASS；generic browser explore/fill case保持 quiet，並由 `agent-browser` 接手。靜態 overlap 不足以 justify 擴張 VND* fork。

## 76 active skills final ledger

`Keep` 表示 current boundary 有 unique value；`Tuned → Keep` 表示本輪有修改；`Provisional retain` 表示移除 gate 尚未滿足。

| # | Skill | Final status | 調教後仍保留的 unique value／未移除原因 |
|---:|---|---|---|
| 1 | `acquire-codebase-knowledge` | Keep | evidence-based repo map 與 onboarding；不是一般架構建議 |
| 2 | `agent-browser` | Keep | CLI snapshot/reference automation loop 與 failure shields；541 EFF 的 VND 超限不足以製造新 fork |
| 3 | `ask-matt` | Keep | user-only Matt workflow router；無 implicit-load cost |
| 4 | `aspnet-api-architect` | Tuned → Keep | requirements → design/tasks → authorized scaffold |
| 5 | `auditing-skill-folder` | Keep | provenance、verdict、collision、trigger-eval 與 portable audit contract |
| 6 | `auth-implementation-patterns` | Keep | auth-specific token/session/cookie/CSRF failure shields |
| 7 | `backend-release-verification` | Keep | production evidence、rollback、go/no-go boundary |
| 8 | `bug-fix-settlement` | Tuned → Keep | bugfix 後的 knowledge routing 與 explicit authorization gate |
| 9 | `c-cpp-best-practices` | Keep | ABI、ownership、RAII、sanitizer/toolchain decisions |
| 10 | `clean-code-dotnet` | Provisional retain after thin rewrite | 只剩 C# readability/responsibility judgment；是否整併移除仍需 no-skill A/B |
| 11 | `code-review` | Keep | fixed-point Standards/Spec two-axis review；VND 超限不值得 fork |
| 12 | `codebase-design` | Keep | deep-module vocabulary 與 design principles；VND 超限不直接等於可刪 |
| 13 | `containerization` | Keep | Docker/IIS build-runtime-security boundaries |
| 14 | `context7-mcp` | Keep | current library docs resolve/query procedure；與 Microsoft docs 有 negative routing |
| 15 | `css-ui-best-practices` | Tuned → Keep | CSS/UI/a11y implementation checklist；移除錯誤 legal-floor claim |
| 16 | `dapper-best-practices` | Keep | connection/transaction/multi-mapping failure shields |
| 17 | `dependency-security-scan` | Keep | secret/dependency/container/SBOM gates 與 exception lifecycle |
| 18 | `deps-check` | Tuned → Keep | fail-closed TS/JS/C# caller inventory 與 fan-in gate |
| 19 | `dev-workflow` | Intentional Keep | always-on 三 host kernel、authorization、RED→GREEN、S4–S6；外移不降低載入且破壞 inline gate |
| 20 | `diagnosing-bugs` | Keep | hard-diagnosis RED loop、hypothesis ranking、instrumentation、regression；VND* 不擴張 |
| 21 | `domain-modeling` | Keep | glossary、bounded contexts、ADR gates；只超 budget 15，fork cost 高於收益 |
| 22 | `dotnet-core-best-practices` | Tuned → Keep | modern .NET DI/API/runtime diagnostics，已移除 host stance |
| 23 | `dotnet-find-bugs` | Provisional retain | unique content 已由 narrower owners 覆蓋，但 same-name `security-review` replacement canary 尚無可證明 payload |
| 24 | `dotnet-framework-best-practices` | Keep | classic ASP.NET/OWIN/config/async-context guidance |
| 25 | `dotnet-logging-best-practices` | Tuned → Keep | structured logging、redaction、correlation；不再宣告 tracing ownership |
| 26 | `dotnet-test` | Keep; no rename | routine test/coverage execution router + BenchmarkDotNet procedure；不是 benchmark-only |
| 27 | `dotnet-testing-best-practices` | Keep | xUnit/NUnit/MSTest authoring/review、integration、Testcontainers；與 runner 分工 |
| 28 | `dotnet-winforms-best-practices` | Keep | Designer serialization、UI thread、GDI/disposal、DPI |
| 29 | `ef-core-best-practices` | Keep | DbContext lifetime、query shape、migration/concurrency guards |
| 30 | `ef6-best-practices` | Keep | EDMX、EF6 loading/context/migration；以 `System.Data.Entity` 分流 |
| 31 | `frontend-release-verification` | Tuned → Keep | browser/RWD/a11y production evidence 與 deployment gates |
| 32 | `grill-me` | Keep | user-only backward-compatible alias，零 resident model cost |
| 33 | `grill-with-docs` | Keep | explicit `grilling` + `domain-modeling` composite |
| 34 | `grilling` | Keep | one-question-at-a-time、risk pause、final confirmation；已吸收 retired `clarify` trigger |
| 35 | `handoff` | Keep | redacted canonical handoff 與 copy-paste next-session prompt |
| 36 | `implement` | Keep | explicit invocation compatibility；execution gates 由 kernel 擁有 |
| 37 | `improve-codebase-architecture` | Keep | user-only hotspot/deepening/HTML/grilling workflow；VND 超限無 implicit-load cost |
| 38 | `init-project-docs` | Tuned → Keep | cross-host confirmation、catalog selection、merge/secrets、validation gates |
| 39 | `jest-best-practices` | Keep | Jest config、ESM/CJS mocking/hoisting、timers/snapshots/flake triage；387 EFF、refs PASS |
| 40 | `microsoft-code-reference` | Keep | Microsoft API signatures、packages、official code samples、hallucination shield |
| 41 | `microsoft-docs` | Keep | Microsoft concepts/tutorial/configuration/quota；與 code-reference 互補，不套用重新擴張 collision 的 upstream |
| 42 | `mp-zoom-out` | Keep | module/caller/boundary system map 與 domain glossary reuse |
| 43 | `mysql-best-practices` | Keep | MySQL version/charset/locking/DDL/index/driver failure shields |
| 44 | `native-feel-cross-platform-desktop` | Keep | native shell + system WebView、IPC/memory/native-convention checklists；VND trim 暫不建 fork |
| 45 | `next-best-practices` | Keep | Next version gate、RSC/App Router/async APIs |
| 46 | `nodejs-best-practices` | Keep | event loop、async errors、logging、HTTP/DB test-layer rules |
| 47 | `nuxt` | Keep | Nuxt 3/4、Nitro、SSR/data-fetch/runtime-config；Batch 2 negative routing 已完成 |
| 48 | `pinia` | Keep | store boundaries、SSR/HMR、createTestingPinia decisions |
| 49 | `playwright-best-practices` | Keep; canary-confirmed | Playwright tests/trace/flaky diagnosis/explicit MCP；generic browser task已由 agent-browser 接手 |
| 50 | `postgresql-best-practices` | Keep | schema/migration/RLS/DAL correctness；與 optimization 雙向分流 |
| 51 | `postgresql-optimization` | Keep | EXPLAIN-first、index/operator/JSONB/FTS/partition tuning |
| 52 | `prototype` | Keep | throwaway logic/UI prototype、observable state、decision capture |
| 53 | `react-best-practices` | Keep | hooks/RSC/keys/compiler/state/error/a11y failure shields |
| 54 | `react-router-framework-mode` | Keep | loader/action/Form/fetcher/session/SSR/version patterns |
| 55 | `research` | Keep | primary-source background research + cited artifact；kernel 負責 Context7/Microsoft routing與寫檔授權 |
| 56 | `resolving-merge-conflicts` | Keep | intent-preserving conflict resolution與 merge/rebase verification；kernel 覆寫危險 upstream wording |
| 57 | `sdd` | Tuned → Keep | single-file/single-behavior/≤3 tasks 的三階段流程 |
| 58 | `security-audit` | Keep | whole-codebase adversarial hunt、independent validation、structured artifacts；VND trim 留待 upstream/新 override |
| 59 | `security-review` | Keep | focused code/diff data-flow review、changed-file ledger、patch authorization |
| 60 | `setup-matt-pocock-skills` | Keep | user-only repo tracker/labels/domain-doc setup；dangling `qa` 留在 override backlog，不因此 fork |
| 61 | `tailwind-v4-shadcn` | Keep | Tailwind v4/shadcn token wiring、dark mode、build checklist |
| 62 | `tdd` | Keep | public seam、vertical tracer bullet、RED→GREEN anti-patterns；只超 6 words，kernel 已解衝突 |
| 63 | `teach` | Keep | user-only multi-session teaching workspace、ZPD、learning records；無 implicit-load cost |
| 64 | `testing-library-react-best-practices` | Tuned → Keep | React RTL query priority、userEvent、async/public-behavior tests；Vue/Pinia routing已校正 |
| 65 | `to-spec` | Keep | user-only conversation→spec publishing；只超 1 word，不建立 fork |
| 66 | `to-tickets` | Keep | user-only tracer-bullet slicing、blocking edges、expand/contract |
| 67 | `triage` | Keep | user-only tracker state machine、claim verification、agent-ready brief |
| 68 | `typescript-best-practices` | Keep | strict/narrowing/discriminated unions/runtime boundary shields |
| 69 | `vite` | Keep | mode/plugin/env/HMR/Rolldown workflow |
| 70 | `vitest` | Keep | Vite-shared runner config、mocks/timers/environments/migration |
| 71 | `vue-best-practices` | Keep | Vue 3.4/3.5 semantics、reactivity/component rules；repo-first styling stance |
| 72 | `vue-debug-guides` | Keep | symptom→category→minimal verified Vue/Nuxt runtime fix |
| 73 | `vueuse-functions` | Keep | VueUse decision map、SSR/browser boundaries、storage secret guard |
| 74 | `wayfinder` | Keep | user-only cross-session decision map、frontier/fog/out-of-scope semantics；無 implicit-load cost |
| 75 | `web-design-reviewer` | Keep | rendered page → DOM/source → authorized repair → same-viewport evidence loop |
| 76 | `writing-great-skills` | Keep | invocation modes、description design、information hierarchy、pruning criteria |

## 5 archived skills closure

| Archive | Replacement coverage | 為何維持歸檔 | Recoverability |
|---|---|---|---|
| `clarify` | `grilling` 吸收 ambiguity/clarify trigger；T0-5 保留 stop gate | active owner 已覆蓋，無需同義 skill | `attic/clarify/SKILL.md` + git history |
| `csharp-developer` | modern → dotnet-core；legacy → dotnet-framework；EF/testing 有窄 owner | broad persona 被更窄 owners 完整拆分；Blazor/MAUI 不在使用者 scope | 完整 SKILL + 5 refs 在 `attic/csharp-developer/` |
| `dotnet-core-expert` | CQRS/MediatR 搬到 dotnet-core reference；API/auth/EF 有窄 owner | unique payload 已遷移 | 完整 fork/templates 在 `attic/`，recorded tree fingerprint |
| `make-skill-template` | Codex system skill-creator、Claude official creator、Copilot plugin creator | 三 host 都有 maintained replacement | attic copy + git history |
| `nuget-manager` | SDK/CPM → dotnet-core；`packages.config` → dotnet-framework | modern/legacy ownership 已分流 | attic copy + git history |

Restore 任何一支都應用 `git mv attic/<name> skills/<name>`，恢復 lock row、重算 fingerprints，再跑 vendored、relative-reference、Matt workflow 與 host resolver gates；不可只複製回 active tree。

## 原先建議整併／移除，但新版未移除

| Skill / group | 原建議 | 這次為何未移除 | 建議決策 |
|---|---|---|---|
| `clean-code-dotnet` | generic Clean Code 可整併後移除 | 已薄化到 360 words，但尚無 temporary-disable/no-skill A/B 證明 explicit Clean Code/SOLID prompt 不降質 | **建議暫留 thin fork**；若想再減一支，下一批只做可逆 archive A/B，PASS 才移除 |
| `dotnet-find-bugs` | unique ledger 遷移後 retire | runtime/security/diagnosis 已有 owners，但 Claude collision arm 被另一個 same-name `security-review` 選中，無法證明 replacement payload | **現在不要移除**；先修 alias/identity 並取得 Claude + Copilot + Codex 可觀測 canary |
| `dotnet-test` | 舊 audit 曾建議移除／改 benchmark 名 | current skill 仍負責 routine execution routing；僅 BenchmarkDotNet 是自有深入內容；改名會丟失既有 trigger | **保留現名與內容**；若未來實測 misrouting，再把 benchmark reference 併入 canonical testing skill後 archive，不另造 `dotnet-benchmark` |
| `web-design-reviewer` | 與 CSS/release/browser 整併後移除 | thin fork 仍有 rendered evidence → source → authorized repair → same viewport 的 unique loop | **保留**；只有 loop 被其他 owner完整吸收才再 archive |
| Microsoft pair | 合併或 wholesale refresh | current concept/tutorial 與 API/signature/code sample 分工清楚；目前 upstream broad description 會重新撞 Context7/code-reference | **保留兩支**；未來若 refresh，兩支一起遷移並重跑 collision canary |
| PostgreSQL pair | general 與 optimization 可合併 | correctness/migration/RLS 與 EXPLAIN-first performance tuning 有不同 trigger、procedure、evidence | **保留兩支**；現有雙向 route 已足夠 |

## Remaining debt（不冒充已解決）

1. `clean-code-dotnet` removal A/B 尚未跑；這是使用者決策，不是 completion blocker。
2. `dotnet-find-bugs` replacement identity/cross-host canary 尚未通過；在此之前 archive 不安全。
3. VND over-budget skills 保留原樣：`agent-browser`、`ask-matt`、`code-review`、`codebase-design`、`diagnosing-bugs`、`domain-modeling`、`dotnet-find-bugs`、`improve-codebase-architecture`、`native-feel-cross-platform-desktop`、`security-audit`、`setup-matt-pocock-skills`、`tdd`、`teach`、`to-spec`、`to-tickets`、`triage`、`wayfinder`。原因是沒有足夠 behavioral benefit 支付永久 remerge cost；其中多支是 user-only，沒有 implicit-load token cost。
4. `dev-workflow` 超常駐 budget 是明示的 kernel exception；它的 inline authorization/gate contract 不外移。

## Verification ledger

| Gate | Result |
|---|---|
| Candidate local CI | `bin/ci-local` exit 0；17 PASS、0 FAIL、4 expected SKIP |
| Relative references | 471 checked，PASS |
| Vendored fingerprints | 58 PASS、0 FAIL；clean-code payload/tree locks current |
| Description / trigger / word harness | 22 / 122 / 30 PASS |
| Live trigger canary | pre 8 cases：7 PASS + 1 intentional ASP.NET RED；post ASP.NET + RTL 5/5 PASS；Playwright unchanged 3/3 PASS |
| Secret scan | staged、pre-commit、2 untracked candidate scans皆 exit 0 |
| Independent S5 | Standards fixed-point PASS；Spec fixed-point PASS |
| Active/archive set | 76/76 active symmetric difference empty；5/5 attic copies readable |
| Live fast-forward | `main`：`6584d62 → 84f2ff3`，`--ff-only` |
| Live bootstrap / doctor | source 76；Claude links 76 valid；兩者 exit 0 |
| Live host resolver | Claude 22/22、Codex policy 12/12、Copilot 22/22；3 PASS、0 FAIL、1 Codex runtime `UNAVAILABLE` |
| Live local CI | `bin/ci-local` exit 0；17 PASS、0 FAIL、4 expected SKIP |

S6 live cutover 已完成。Codex current CLI 沒有 local skill-list command，因此 runtime resolver 維持 `UNAVAILABLE`，不算 PASS；其餘適用 gates 均已通過。
