# dotnet/skills 採用決策 — 逐 skill 對 DCT stack 評分

日期：2026-08-05｜upstream HEAD `805a42a`｜前份報告：`~/.agents/proposals/2026-08-04-dotnet-skills-comparison/00-report.md`

> **實作狀態（2026-08-05）**：本 candidate 已套用 actions 1a、2 的 static/safety fork、3、4；marketplace update 依 action 0 **SKIPPED**。Claude reauth 後的 collision canary 為 **3/3 PASS**（TP=1、TN=2、FP/FN=0，precision/recall=1.00），vendored skill 狀態為 `Active`；先前 OAuth `401` run 仍記為 **UNAVAILABLE**，不計入通過。Windows production crash-dump 設定未執行。下方 `0/6`、`0/8` 是實作前快照，不是目前狀態。

> **實作前重驗快照（2026-08-05 07:0x）**：upstream 現為 `4d25f17`，較 `805a42a` ahead 1 commit（`chore: recompile agentic workflows with gh-aw 0.84.3` #985），9 檔全在 `.github/workflows/`，**`plugins/` 零變動** → 本報告全部 skill 層結論在 HEAD 仍逐字成立。live 重驗：16 plugin／96 skill／16 agent（`dotnet-test` 10 agent）、`code-testing-agent:4` 與 `find-untested-sources:4` 的 `MANDATORY` 宣告仍在、marketplace 快照仍停 `ce75c35`、已裝 dotnet plugin 仍 0、**行動 1a～4 的 0/6 全未落地**（`security-performance.md` 的「On Linux containers」錯誤仍逐字存在）。

本報告**不重做**前份的 repo 比對與 eval 方法論分析（那部分成立，直接沿用）。本報告補三件前份沒做的事：

1. 前份 8 項行動的**落地狀態**（實測：0/8）
2. 前份推薦「只裝 `dotnet-test`」的**三項反證**（agent 數量、trigger 碰撞、MSTest 偏向）
3. 逐 skill 對 DCT 實際 stack 的評分（前份只到 plugin 層）

---

## 0. 前置事實（本次實測）

| 事實 | 值 | 驗證 |
|---|---|---|
| upstream HEAD | `805a42a`（2026-08-05） | `git log --oneline -1` |
| **本機已註冊 marketplace** | `dotnet-agent-skills` → `github.com/dotnet/skills`，快照停在 `ce75c35`（**2026-07-01**，落後 5 週） | `git -C ~/.claude/plugins/marketplaces/dotnet-agent-skills log -1` |
| **已安裝的 dotnet plugin** | **0 個**（`installed_plugins.json` 無任何 `dotnet-*` 項） | `installed_plugins.json` + `find ~/.claude/plugins -iname '*dotnet*'` |
| 落後期間 upstream 變動 | 移除 `dotnet-ai` 的 4 支 `mcp-csharp-*`；新增 `dotnet-data/create-datadriven-aspnetcore`、`dotnet-msbuild/copy-to-output-directory` | `comm` 比對兩份 SKILL.md 清單 |
| plugin skills 總數 | 96（16 plugin） | `find plugins -name SKILL.md \| wc -l` |
| 前份 8 項行動落地 | **0/8** | `~/.claude/agents/` 仍 3 檔無 Domain Relevance Check；`auditing-skill-folder` 無 triage 表、無 binomial bound、無 `reject_skills` 註記 |

**結論**：前份報告的 backlog **仍開著**（0/8），marketplace 2026-07-03 註冊後從未裝過任何 plugin。

注意 framing：「沒執行」只證明 backlog 未關，**不構成推翻前份「裝 dotnet-test」建議的證據**。推翻它的是 §2 的三項實質反證（+10 agent、MANDATORY 搶佔觸發、MSTest 偏向），那三項各自獨立成立。

---

## 1. Menu budget（本次重量，取代前份數字）

`name: description` frontmatter 字元合計，即每回合常駐成本：

```
本機 ~/.agents/skills:      71 skills   22,348 chars
dotnet/skills 全 16 plugin: 96 skills   67,697 chars   = 本機的 303%

  dotnet-test              20 skills   15,630   (排除 4 支 dmi：13,736)
  dotnet-msbuild           19 skills   13,038
  dotnet-maui               8 skills    6,418
  dotnet-blazor             9 skills    5,864
  dotnet-template-engine    6 skills    5,013
  dotnet-upgrade            6 skills    4,639
  dotnet-test-migration     5 skills    4,077
  dotnet-diag               7 skills    3,981
  dotnet-aspnetcore         4 skills    1,680
  dotnet-experimental       3 skills    1,675
  dotnet-advanced           3 skills    1,477
  dotnet-data               2 skills      943
  dotnet-ai / dotnet-nuget / dotnet11 / dotnet   各 1 skill   916 / 888 / 895 / 563
```

`dmi`（`disable-model-invocation: true`）只有 4 支，全在 `dotnet-test`：`code-testing-extensions`、`filter-syntax`、`test-analysis-extensions`、`platform-detection`。前份已記錄：upstream 宣稱 dmi 會被 Copilot menu 丟掉，**本機實測 Copilot 載 95/95 並忽略此旗標** → Copilot 側須以上界 15,630 計。

---

## 2. 前份推薦「只裝 dotnet-test」的三項反證

### 反證 A：`dotnet-test` 會帶進 10 個 agent

```
plugins/dotnet-test/agents/ →
  code-testing-builder / code-testing-fixer / code-testing-generator /
  code-testing-implementer / code-testing-linter / code-testing-planner /
  code-testing-researcher / code-testing-tester /
  test-quality-auditor / testability-migration
```

plugin agent **確實進 agent menu**（本 session 的 agent 清單就含 `hookify:conversation-analyzer`、`codex:codex-rescue`）。本機 agent 是 43→3 的刻意收斂，前份報告自己也寫「**不建議增加 agent 數量**」——同一份報告卻推薦裝一個會 +10 agent 的 plugin。這是內部矛盾。

### 反證 B：`code-testing-agent` 自稱 MANDATORY ENTRY POINT，會搶既有觸發

`plugins/dotnet-test/skills/code-testing-agent/SKILL.md:4-5`：

> `MANDATORY ENTRY POINT for generating or writing tests. Invoke this skill before editing files whenever the user asks to generate tests, write/add unit...`

`find-untested-sources/SKILL.md:4` 同樣寫 `MANDATORY for static requests to...`。

這直接對撞本機 `tdd`、`dotnet-testing-best-practices`，以及 `dev-workflow` kernel 的路由。本機整套 skill 紀律的核心量測就是 trigger precision（`0.33 → 0.50 → 1.00`）；前份報告只算了 menu 字元數，**沒有做任何碰撞分析**。

（`code-testing-agent` 本身是 framework-agnostic 的——它把 MSTest 專屬工作路由給 `writing-mstest-tests`，這點無疑慮。）

### 反證 C：`dotnet-test` 的 MSTest 偏向

DCT 用 **xunit 2.9.2 + Microsoft.NET.Test.Sdk 17.11.1（VSTest，非 MTP）**。`dotnet-test` 20 支中：

| skill | mstest 提及 | xunit 提及 |
|---|---:|---:|
| `writing-mstest-tests` | 57 | 2 |
| `test-anti-patterns` | 8 | 1 |
| `platform-detection` | 7 | 4 |
| `run-tests` | 13 | 12 |
| `filter-syntax` | 6 | 12 |
| `assertion-quality` | 5 | 2 |

`writing-mstest-tests` 對 DCT 是純負擔。`mtp-hot-reload` 需要 Microsoft.Testing.Platform，DCT 是 VSTest → 不適用。

---

## 3. 逐 skill 評分（workflow `wf_52355aad-6f7`，6 agents / 689,891 tokens / 0 error）

4 個獨立 scoring agent 各讀完整 SKILL.md + 對照的自有 skill；每個 ADOPT 判定再經一輪 adversarial refute（refute agent 實際跑了 `dotnet build`（0 errors/42s）與 `dotnet test --filter "Category!=Integration"`（476 passed / 0 failed / 1 skipped）驗證可行性）。

### 總表

| plugin group | skills | ADOPT | HARVEST | SKIP | plugin 判定 |
|---|---:|---:|---:|---:|---|
| `dotnet-test` | 20 | **1** | 4 | 15 | HARVEST_SUBSET |
| `dotnet-diag` | 7 | 0 | 2 | 5 | HARVEST_SUBSET |
| `dotnet-upgrade` | 6 | 0 | 0 | 6 | **SKIP_ENTIRELY** |
| `dotnet-msbuild`+`nuget`+`advanced` | 23 | 0 | 0 | 23 | **SKIP_ENTIRELY** |
| （附錄 A stack 事實排除：其餘 10 個 plugin） | 40 | 0 | 0 | 40 | SKIP |
| **合計** | **96** | **1** | **6** | **89** | |

### 3.1 唯一存活的 ADOPT：`test-gap-analysis`

經 adversarial refute **未被推翻**（`refuted=false`）。五條反駁路徑逐一失敗：

- **引用屬實**：`SKILL.md:25` / `:29` 逐字相符；`ci.yml:38` 確為 `/p:Threshold=25 /p:ThresholdType=line`
- **無框架阻擋**：polyglot，Step 3 catalog 自帶 C# 原生 row（`return default(T)`、`x?.Method()`、`x!`、跳過 `*.g.cs`），且 `SKILL.md:42` 明確排除跑 Stryker/mutmut → 只需 `dotnet test`
- **工具鏈當場可跑**：`--filter "FullyQualifiedName~ComputeImportResult"` → 9 passed / 3ms。apply-and-revert 迴圈每個 mutation ≈3ms，不會退化成 `SKILL.md:162` 的 "unverified (static reasoning)" 空轉
- **無自有覆蓋**：`grep mutation` 掃 71 支只命中 `clean-code-dotnet:24`（那裡指 mutable state）
- **無觸發衝突**：`dotnet-testing-best-practices` 打 "add a test for X"／"run the tests"／"flaky"；`tdd` 打 red-green-refactor；`diagnosing-bugs` 打 "something is broken"。無一宣告 "would my tests catch a bug in this code?"

**為何 DCT 特別需要它**：CI 唯一的測試閘是 25% line coverage。CLAUDE.md 釘死的 `8*recoveryRate + 4*tester + 2*testResult + failPin` 並警告 `不可改成 Math.Min(x,1)` —— 這正是 boolean/arithmetic mutation 存活型 bug，是該 skill 的 Boundary/Boolean 表直接生成的 mutant 類別。

**vendor 時的 local fork 修改（必要）**：
1. `SKILL.md:57` 硬指「Call the `test-analysis-extensions` skill」，而該 skill 帶 `disable-model-invocation: true` + `user-invocable: false` → 在 Claude 側呼不到。改成直接讀 vendored 的 `references/dotnet.md`
2. description 內 4 個指向不存在 skill 的 pointer（`code-testing-agent`、`writing-mstest-tests`、`test-anti-patterns`、`assertion-quality`）要拆掉

**風險控制**：正常 analysis/review 只做 static reasoning。Step 4b 的 real edit 必須另有 explicit mutation authorization，且只能在由 target HEAD 建立的 clean isolated copy/worktree 執行；先記錄原始 bytes/hash，narrow test 只作 triage，完整 affected suite 綠才算 survivor，inverse edit 後 bytes/hash 必須完全一致。不得修 project wiring，也不得用 `git stash`／`checkout`／`restore` 回復。

### 3.2 HARVEST 六項（折進既有自有檔，不新增 skill）

| 來源 | 折進 | 內容 |
|---|---|---|
| `test-analysis-extensions/extensions/dotnet.md` | `test-gap-analysis/references/dotnet.md` | 原判 ADOPT，**refute 降級為 HARVEST**：作者自承「Nothing standalone」+「prune to dotnet.md」→ 那就是一個 reference 檔，不是 skill。另 11 個 extension 檔對本 stack 是死重 |
| `crap-score` | `dotnet-testing-best-practices/references/`（Rule 12 下） | CRAP 公式 `comp²(1-cov)³+comp`、risk band、反解 `cov_needed = 1-((15-comp)/comp²)^(1/3)`、「complexity ≥ threshold 靠加測試修不好」、禁止估算覆蓋率。ci.yml:38 已產 cobertura → 零設定成本 |
| `test-anti-patterns` | `dotnet-testing-best-practices/SKILL.md` Severity Checklist | 只收錄可證明不會觀察目標行為的 patterns：assertion-free coverage touching、self-reference、swallowed exception、always-true、commented-out assertion、broad exception acceptance、missing await、no-value assertion message；保留合法 round-trip/no-throw tests，並依 xUnit exact-type semantics 校正 |
| `detect-static-dependencies` | `dotnet-testing-best-practices/references/mocking-frameworks.md` | category→abstraction 對照表 + 計數規則（依「碰到什麼」分類而非依 `static` 關鍵字；排除 `Path.Combine` 這類純 helper）。DCT 實測：173 `Console.WriteLine`、32 `DateTime.Now`、11 `File.Exists`、4 `File.Move`、6 `Environment.*` |
| `dotnet-trace-collect`（僅 Windows/非容器分支） | `dotnet-core-best-practices/references/security-performance.md` § Debugging and diagnostics（:754） | PerfView vs dotnet-trace 依 admin 權限分流、`/ThreadTime` hang triage（livelock vs thread starvation vs true deadlock）、`/StopOn` + `/CircularMB` 長時重現、artifact handoff checklist。自有樹只有 `dotnet-winforms-best-practices/references/threading-and-resources.md:606` 一句「PerfView: lightweight ETW-based tracing」無指令 |
| `dump-collect` | 同上錨點 | Windows PowerShell process-scope block、service-manager persistence/restart/write probe、dump type 表（1 Mini/2 Heap/3 Triage/4 Full）、create-dump diagnostics，以及 SDK-less host 可用的 standalone dotnet-dump 路徑 |

**`dump-collect` 順帶抓到自有檔一處事實錯誤**：`security-performance.md:766` 寫「On Linux containers, enable crash dumps via env vars」，但 `DOTNET_DbgEnableMiniDump` 等是**全平台**的（upstream 該節標題就是 "Automatic Crash Dumps (All Platforms)" 並附 Windows PowerShell block）。

> **已由一手來源證實（2026-08-05，`microsoft_docs_search`）**：MS Learn [Collect dumps on crash](https://learn.microsoft.com/dotnet/core/diagnostics/collect-dumps-crash) 的環境變數表無平台限定，唯一平台排除是「Dump collection isn't supported on mobile platforms (Android and iOS)」。決定性反證：同表中 **只有** `DOTNET_EnableCrashReport` 單獨標註 "(not supported on Windows.)" —— 若整組變數皆 Linux-only，就不需要為單一列另標 Windows 例外。
> 順帶兩項一手事實（harvest 時一併寫入）：① `DOTNET_DbgMiniDumpName` 預設 `/tmp/coredump.<pid>`，Windows 上應顯式指定路徑；② `DOTNET_DbgMiniDumpType` 預設 **2（Heap）**，而 `dotnet-dump collect --type` 預設是 **Full** —— 兩條路徑預設值不同，文件別寫成同一個。免 SDK 下載路徑亦經證實：`https://aka.ms/dotnet-dump/win-x64`。`PublishSelfContained=true` 只表示產物不依賴已安裝 runtime，不足以證明 host 沒有 SDK；執行前仍須 probe host。

**dump type 的適用範圍（實測釐清）**：upstream 的「single-file publish 只支援 type 4」限制**不適用於 DCT**——`csproj` 只設 `PublishSelfContained`，**未設 `PublishSingleFile`**（`grep -nE 'PublishSelfContained|PublishSingleFile'` 只命中前者於 :16/:20）。self-contained ≠ single-file，四種 dump type 都可用。harvest 這張表時要連這句一起寫進去，否則讀者會誤以為只能挑 4（Full），對 24/7 服務是不必要的大量磁碟寫入。

### 3.3 三個高價值 SKIP 的理由（避免日後重問）

- **`microbenchmarking`（76K，最大一支）** → 自有 `dotnet-testing-best-practices` description 已宣告 BenchmarkDotNet 觸發，`references/benchmarks.md` 已覆蓋
- **`analyzing-dotnet-performance`（~50 個 anti-pattern）** → 觸發與自有 `dotnet-core-best-practices`（"Symptoms include ... high CPU, memory leak"）對撞；且 `dotnet-diag` 隨附的 `agents/optimizing-dotnet-performance.agent.md` 寫死「**Always execute after Pass 1.** Do not ask whether to proceed」—— 強制 perf refactor pass，直接違反專案 CLAUDE.md 的 `不主動現代化`
- **`generate-testability-wrappers` / `migrate-static-to-wrapper`** → 同一條家規；且會動 `FileProcess`／`DbAccess`／`ImportData` 這批高扇入共用檔

### 3.4 跨主機注意（vendor `test-gap-analysis` 時）

`disable-model-invocation` 的隱藏機制**只在 Claude 有效**：
- Copilot 忽略此鍵（2026-07-31 實測：`copilot skill list --json` 對帶此鍵的 skill 回 `enabled: true` 且 description 完整曝光）
- Codex 的 validator **主動拒絕**此鍵（`validate_plugin.py:447-453`，非 None/False → "must be false"）；等價設定是 `<skill>/agents/openai.yaml` 的 `policy.allow_implicit_invocation: false`

→ vendor 後若要壓 menu，要改**兩處**，不是一處。

---

## 4. 最終建議

**不安裝任何 plugin。**96 支 skill 中 1 支 vendor、6 項 harvest、89 支排除。

| # | 動作 | 規模 | 依據 |
|---|---|---|---|
| 0 | **SKIPPED** marketplace update：最終決策是不安裝 plugin，且 skill payload 已直接以 upstream `4d25f17` 重驗；更新本機 marketplace metadata 對本批沒有行為效益 | 0 | §0 |
| 1a | **文件修正**：修「Linux containers」事實錯誤；補 Windows process/service scope、dump type 表（含「DCT 非 single-file，四型皆可」）、write/diagnostic probe、SDK-less host standalone dotnet-dump 路徑 | ~40 行文件 | §3.2 `dump-collect` |
| 1b | **production 設定變更（需你決定，不是文件事）**：在 Windows prod 機實際武裝 crash dump。這會在 24/7 服務上開啟磁碟寫入；目標目錄必須由實際 service identity 可寫，並應設定 `DOTNET_CreateDumpDiagnostics=1` 與 `DOTNET_CreateDumpLogToFile` 留下建立失敗原因 | prod 設定 | 24/7 三執行緒輪詢 + `RestartWorker`（`Program.cs:301`）會吞掉崩潰現場，目前未保存 crash artifact。建議先選 type 3（Triage）而非 4（Full）控制磁碟量 |
| 2 | vendor `test-gap-analysis` 進 `~/.agents/skills/`，走 `vendored-forks.md` + `vendored-skills.lock` 三道閘；套 §3.1 pointer 與 empirical-mutation safety fork。**然後**加一組 fire case + 兩個 quiet collision cases，跑 Claude collision arm | 1 skill + 1 reference + 3 eval cases | §3.1；vendor 完成 ≠ 完成，見下 |
| 3 | harvest `crap-score` / `test-anti-patterns` / `detect-static-dependencies` 進 `dotnet-testing-best-practices` | 3 段 | §3.2 |
| 4 | harvest `dotnet-trace-collect` Windows 分支進 `security-performance.md` 同錨點 | ~30 行 | §3.2 |
| 5 | 前份報告的 8 項行動仍是 0/8 —— 其中 #1（binomial 下界）與 #2（triage 表）與本次無關但仍未做 | 見前份 | §0 |

**不建議**：裝 `dotnet-test`（+10 agent、`code-testing-agent` 搶佔式 MANDATORY 觸發、MSTest 偏向）；裝 `dotnet` plugin（會與已啟用的 `csharp-lsp` 形成雙 Roslyn server）；裝 `dotnet-msbuild`（19 支對 2 個 csproj + 非預設 feed 的 MCP server）；vendor 任何 `dotnet-diag` skill（全部只該當 reference 段落）。

### 動作 #2 的「完成」定義

refute pass 驗證的是 `test-gap-analysis` **跑得起來**（build 綠、476 tests、filtered run 3ms），**不是它會被觸發**。它進的是 71 支的 menu，最近鄰是 `dotnet-testing-best-practices`（"reviewing .NET tests"）、`tdd`、`diagnosing-bugs`。refute 對碰撞的論證是讀 frontmatter 文字——而依記憶 `skill-trigger-must-be-the-ask-not-the-condition`，「description 讀起來不重疊」不足以證明 collision arm 不會輸。

所以 vendor 完不算完：要跑 collision arm。若輸給 `dotnet-testing-best-practices`，description 必須改成明示動作觸發（「would my tests catch a bug in X?」站觸發位置），才值得那個 slot。

---

## 附錄 A：其他 plugin 的具體排除理由（stack 事實）

| plugin | 排除理由（DCT 實測事實） |
|---|---|
| `dotnet-aspnetcore` (4) | 無 ASP.NET Core。DCT 是 `OutputType=Exe` Console App |
| `dotnet-blazor` (9) | 無 web UI |
| `dotnet-maui` (8) | 無行動端 |
| `dotnet-data` (2) | 兩支都是 EF Core / data-driven ASP.NET；DCT 用 Dapper + 手寫 SQL，房內 `dapper-best-practices` + `mysql-best-practices` 覆蓋 |
| `dotnet-msbuild` (19) | **2 個 csproj、無 `Directory.Build.props`、無 `Directory.Packages.props`、無 `NuGet.config`、無 `global.json`**。另：此 plugin 綁一個 MCP server（`Microsoft.AITools.BinlogMcp`，經 `dotnet dnx` 從 **dnceng Azure DevOps feed**（非 nuget.org）拉取）→ 新增常駐 tool surface + 非預設 feed 的供應鏈面 |
| `dotnet-nuget` (1) | 唯一 skill 是 `convert-to-cpm`；DCT 無 CPM 且 2 個 csproj 不值得導入 |
| `dotnet-template-engine` (6) | 不做 template authoring |
| `dotnet-ai` (1) | 無 AI/ML |
| `dotnet11` (1) | 鎖 net8（記憶 `net8-upgrade-constraints`） |
| `dotnet-test-migration` (5) | 方向相反：內含 `migrate-xunit-to-mstest`，DCT 是 xUnit。`migrate-vstest-to-mtp` 會違反「不主動現代化」家規 |
| `dotnet-experimental` (3) | upstream 自標 experimental |
| `dotnet` (1) | 唯一 skill 是 `setup-local-sdk`（DCT 已有 SDK 6/8/10）。真正的 payload 是 LSP：`dnx roslyn-language-server --prerelease`。**本機已啟用 `csharp-lsp@claude-plugins-official`** → 裝了會有兩個 Roslyn server 同時索引同一批 `.cs` |

---

## 附錄 B：驗證指令

```bash
# 重建 clone
git clone --depth 1 https://github.com/dotnet/skills.git /tmp/dotnet-skills

# marketplace 落後幾週
git -C ~/.claude/plugins/marketplaces/dotnet-agent-skills log -1 --format='%h %ci'

# 確認 0 個 dotnet plugin 已安裝
python3 -c "import json,os;d=json.load(open(os.path.expanduser('~/.claude/plugins/installed_plugins.json')));print([k for k in d['plugins'] if 'dotnet' in k])"

# menu budget 重量
# （見 §1，用 frontmatter name+description 字元合計）

# dotnet-test 會帶進的 agent 數
ls -1 /tmp/dotnet-skills/plugins/dotnet-test/agents/ | wc -l   # 預期 10

# MANDATORY 宣告
grep -n -i 'mandatory' /tmp/dotnet-skills/plugins/dotnet-test/skills/*/SKILL.md
```
