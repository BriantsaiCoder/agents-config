# dotnet/skills 對照本機全域設定 — 分析報告

日期：2026-08-04｜來源：`github.com/dotnet/skills`（shallow clone，96 個 plugin skills + 5 個 repo 自用 authoring skills + 16 個 `.agent.md`）
對照對象：`~/.agents/skills`（71）、`~/.claude/agents`（3）、`~/.agents/skills/auditing-skill-folder`（trigger eval）

> **狀態：SUPERSEDED。** 本報告保留為 2026-08-04 的分析快照；採用判定與實作狀態以翌日的 [dotnet/skills 採用決策](../2026-08-05-dotnet-skills-adoption/00-report.md) 為準。

---

## 結論

| 面向 | 判定 |
|---|---|
| **Skill 內容** | 名稱零重疊、功能互補。缺口集中在 build／diag／test-analysis 三塊。建議只裝 `dotnet-test` 一個 plugin，且走 plugin install 不 vendor。 |
| **Agent 格式** | 對方的 `.agent.md` 有本機三個 agent 缺的兩件事：`handoffs` 顯式接力、Domain Relevance Check（不適用時主動退出）。值得抄格式，不值得抄數量。 |
| **Eval 基礎建設** | **本報告最高價值項**。本機量 invocation，對方量 output delta。對方的小樣本門檻直接指出本機既有 gate 的一個真缺陷（但要用二項區間，不是符號檢定 —— 見 §4-①）。 |
| **一項反證** | upstream 文件宣稱 `disable-model-invocation` 會讓 skill 被 Copilot CLI menu 丟掉；本機實測 Copilot 載 95/95 並忽略此旗標。這是全報告唯一 upstream 尚不知情的發現。 |
| **平台本身**（vally／skill-validator／dashboard） | 不建議。vally 未公開，其餘是「單一 repo + 專職團隊」規模的東西。 |

---

## 1. 事實面

### repo 是什麼

.NET 團隊官方 skill marketplace，16 個 plugin、96 個 skill、16 個 agent。四份平行 marketplace manifest（`.claude-plugin/`、`.agents/plugins/`、`.cursor-plugin/`、`.github/plugin/`）覆蓋 Claude Code／Codex CLI／Cursor／Copilot＋VS Code。

支撐它的工程量遠大於 skill 本身：

- `eng/skill-validator/` — C# AOT 工具，含 `Judge.cs`／`PairwiseJudge.cs`／`OverfittingJudge.cs`／`Statistics.cs`／`BaselineStore.cs`
- `eng/eval-quality/check_eval_quality.py` — 10 個結構性缺陷閘（另附 `selftest_eval_quality.py` 自證閘還會 fire）
- `eng/dashboard/` — 準確率／token 趨勢儀表板（github.io 公開）
- `tests/<plugin>/<skill>/eval.yaml` — 每 skill 一份 eval
- CODEOWNERS 強制「2 位 FTE 或 1 個 team」

### 核心機制：三臂 head-to-head

每個 skill 跑三個 arm：**baseline**（無 skill）／**skilled**（只載該 skill）／**plugin**（整包載入）。skill「通過」的定義是 skilled arm **顯著優於 baseline**——不是「有用」，是「比沒有它更好，且統計上站得住」。

---

## 2. Skill 內容比較

### 機械化比對結果

96 個 plugin skill 名稱 vs 本機 71 個：**交集 0**（`comm -12` 實測）。功能層面的差異是結構性的：

| | 本機 | dotnet/skills |
|---|---|---|
| 切法 | 橫向 stack best-practices（1 skill = 1 技術面向） | 縱向 task-specific（1 skill = 1 個具體任務） |
| 例 | `dotnet-testing-best-practices` 一支涵蓋 xUnit／Moq／覆蓋率／BenchmarkDotNet | `coverage-analysis`、`crap-score`、`test-gap-analysis`、`find-untested-sources`、`microbenchmarking` 各一支 |
| description 平均長度 | 307 字元 | 691 字元 |

### 本機完全沒有覆蓋的區塊

| 區塊 | 數量 | 本機現況 | 與 DCT 專案相關性 |
|---|---|---|---|
| **dotnet-msbuild** | 19 | 無。`dotnet-core-best-practices` 只在 description 提一句「SDK-style NuGet/CPM」 | 低（DCT 是單一 csproj） |
| **dotnet-diag** | 7（dump-collect、dotnet-trace-collect、analyzing-dotnet-performance、microbenchmarking、clr-activation-debugging…） | 無。`dotnet-core-best-practices` description 提「runtime diagnostics (dotnet-counters/trace/dump)」但 body 未展開 | **中**：DCT 是 Windows 長駐 3-thread 輪詢服務，hang／leak 診斷有實際場景 |
| **dotnet-test 分析類** | 9（coverage-analysis、crap-score、test-gap-analysis、find-untested-sources、detect-static-dependencies、generate-testability-wrappers、test-smell-detection、assertion-quality、grade-tests） | 無。本機 `dotnet-testing-best-practices` 教「怎麼寫測試」，沒有「分析既有測試品質」 | **高**：DCT 有 443 unit + 14 integration test，正是這批 skill 的輸入 |
| **dotnet-upgrade** | 6（含 `migrate-nullable-references`、`thread-abort-migration`、`dotnet-aot-compat`） | 無 | **中**：DCT `csproj` 未設 `<Nullable>`（實測 grep 只有 `<TargetFramework>net8.0</TargetFramework>`），`migrate-nullable-references` 直接適用 |
| MAUI／Blazor／template-engine | 23 | 無 | 無 |

反向：本機有而對方沒有的，是全部非 .NET 的東西（TypeScript／React／Vue／Postgres／MySQL／安全審查／工作流 kernel）。兩邊是互補不是競爭。

### 採用建議：plugin install，不 vendor

這條分界決定安全性：

- **plugin install**（`/plugin marketplace add dotnet/skills` → `/plugin install dotnet-test@dotnet-agent-skills`）：逐 plugin opt-in、`/plugin update` 更新、**不進** `vendored-forks.md` 的漂移偵測／allowlist／指紋三道閘。
- **vendor 進 `~/.agents/skills/`**：多 6 個 fork 指紋面，且要吃 menu budget。

**Menu budget 實測**（每個 SKILL.md frontmatter 的 `name: description` 字元數合計）：

```
本機 ~/.agents/skills:        71 skills, 21,802 chars (avg 307)
dotnet/skills 全部 plugins:   96 skills, 66,345 chars (avg 691)
  dotnet-test:                20 skills, 15,084 chars (avg 754)
  dotnet-msbuild:             19 skills, 13,038 chars (avg 686)
  dotnet-diag:                 7 skills,  3,941 chars (avg 563)
  dotnet-upgrade:              6 skills,  4,515 chars (avg 752)
```

裝 `dotnet-test` 一個 plugin 的成本是 **13,430–15,084 字元 = 本機現有清單的 62%–69%**。區間下界排除該 plugin 的 4 支 `disable-model-invocation` skill（合計 1,654 字元）——依 upstream 說法它們不進 menu，但**該說法在 Copilot 上與本機量測相矛盾**（見 §5），所以在 Copilot 側應以上界 15,084 計。plugin skill 確實計入清單（本 session 的 available-skills 列表就含 `ponytail:*`、`engineering:*`、`anthropic-skills:*`）。

**建議**：只裝 `dotnet-test`（與 DCT 的 443 個測試直接對得上），暫不裝其餘。Codex 側可用（本機 `codex-cli 0.146.0` ≥ 0.121.0 的 marketplace 門檻）。

---

## 3. Agent 格式比較

本機 3 個 agent（43→3 的收斂是刻意的，不建議加回數量）。對方 16 個 agent 用的 `.agent.md` 格式有兩件本機沒有的：

**（1）`handoffs` — 顯式接力**

```yaml
handoffs:
  - label: Audit Test Quality
    agent: test-quality-auditor
    prompt: >-
      The test framework migration is complete. Please audit...
    send: false
```

本機三個 agent 的接力全靠 description 散文（「This agent reports issues — the parent agent applies fixes with…」）。差別在於 handoff 是結構化欄位、可被 host 渲染成按鈕；散文只能靠模型自己讀懂。

**（2）Domain Relevance Check — 主動退出**

`test-migration.agent.md` 開頭就檢查 workspace 有沒有 .NET 測試專案，沒有就「explain this agent specializes in… and suggest general-purpose assistance instead」。本機三個 agent 都沒有 negative path，被誤派時會硬做。

**（3）Triage and Routing 表** — user intent → skill 的明表，取代散文式判斷。`test-migration.agent.md` 用 11 行表格取代「這個 agent 會判斷該用哪個 skill」。

三者都是格式借鑑，改本機 3 個檔案即可，不新增 agent。

---

## 4. Eval 基礎建設 — 本報告的重點

### 本機現況

`auditing-skill-folder` 的 Step 2c：73 個 case（`evals/cases.jsonl`）、collision arm（全 corpus）＋ isolate arm（只 target）、precision/recall、signal 分類（`FAIL collision — won by X` / `FAIL no skill fired` / `FAIL fired when it should not`）。runners.json 有帶日期的 isolation rationale 與 UNVERIFIED 標記。

**明文限制**：「只量測 invocation，不量測 output quality」。

dotnet/skills 補的正是後半段。以下是**確實可搬**的四項，與**不可搬**的一項。

### 可搬 ①：小樣本認證門檻 — 這指出本機一個真缺陷（但要用對檢定）

**先釐清兩種不同的統計對象，照抄會搬錯檢定。**

對方的 pass gate 是 discordant（非平手）trial 上的**單邊精確符號檢定**，p ≤ 0.05。這是**配對**比較：每個 trial 把 skilled arm 對打 baseline arm，產出 W/T/L。

| discordant trials | 能通過的紀錄 | p |
|---:|---|---:|
| ≤ 4 | 無論多好都不可能 | ≥ 0.0625 |
| 5–7 | 只有零敗（5W/0L） | 0.031 |
| 8 | 可容一敗（7W/1L） | 0.035 |

`0.5⁴ = 0.0625 > 0.05`，所以**低於 5 個 discordant trial，任何紀錄都不可能過**。平手不會被丟棄，而是壓低 discordant 數 —— 5 trial 時一個平手即致命（剩 4 discordant）。

他們的 run `30611635547` 是實例：5 個 skill 被拉到剛好 5 trials，總計 **16W/8T/1L**（每個 skill 都贏、無一退步），**五個全部失敗**，其中四個是平手讓通過在開跑前就不可能。在該次量到的 32% 平手率下，一個真的有幫助的 skill 停在 5 trials 只有約 **1/10** 機會被認證；15 trials 約 **9/10**。

**本機的 `cases.jsonl` 不是配對的。** 每個 case 是單臂二元結果（target 有沒有 fire），算出來是**比例**，不是 W/T/L。符號檢定的 5-trial floor 對它不適用；適用的是小樣本**二項區間**。全勝 k/n 的 95% 單邊下界是 `0.05^(1/n)`：

| 紀錄 | 點估計 | 95% 單邊下界 |
|---|---:|---:|
| 3/3 | 1.00 | **0.368** |
| 5/5 | 1.00 | 0.549 |
| 10/10 | 1.00 | 0.741 |
| 20/20 | 1.00 | 0.861 |

**對照本機**：`.remember` 記錄的 `precision 0.33 → 0.50 → 1.00` GREEN 3/3。結論方向沒錯，但那個 `1.00` 實際只支撐到「真實 precision ≥ 0.37」—— 與「0.5 也完全相容」。三個 case **承載不了它看起來承載的證據量**。這是本機 gate 的實際缺口，不是假想。

**兩條修法，擇一（不可混用）：**

1. **維持單臂，改報區間**（建議先做，較便宜）：`eval-triggers.sh` 輸出加 n 與二項下界，`n < 5` 時印 `CANNOT CERTIFY — report interval, not point estimate`，禁止回報 pass。約 30 行。
2. **定義配對量，再套符號檢定**（較有力）：本機**已經有兩個 arm**（collision 與 isolate）。同一個 case 在 isolate 觸發、在 collision 被別的 skill 搶走 = 一個 discordant pair。對**這個量**套符號檢定，對方的算術就直接適用，且量到的是 disambiguation 品質（本機真正在乎的東西）。

現行報告若照原樣把符號檢定的 5-trial floor 套進單臂 precision，會是搬錯檢定。

### 可搬 ②：只看方向，不看幅度

他們原本用五級序數（`much-better` +1.0／`slightly-better` +0.4／`equal` 0／…）加權算信賴區間，結果**同一紀錄、贏得更漂亮反而判失敗**：

| 7 trials（4W/3T） | mean | ci_low | verdict |
|---|---:|---:|---|
| 每場都 `slightly-better` | +0.229 | +0.031 | ✅ |
| 其中一場 `much-better` | +0.314 | −0.021 | ❌ |

t 區間把 0.4 → 1.0 的跳升讀成 variance。這造成 A/A 測試（同樣輸入跑兩次）**11 個判決翻掉 3 個**；`coverage-analysis` 以 3W/0T/0L 連續失敗五次後第六次才過，差別只在分數是 `[+0.4,+0.4,+1.0]` 還是 `[+0.4,+0.4,+0.4]`。

修法是只讀每個 trial 的**勝方**，不讀幅度 —— 判決成為 W/T/L 紀錄的決定性函數，同紀錄必同結果。幅度仍照報（triage 用），但不決定任何事。

**本機適用時機**：一旦在 eval 裡引入任何 LLM judge，這條立刻生效。

### 可搬 ③：先分類再改寫 — triage 表

`improve-skill-quality` 的核心：**在改 skill 內容之前先分類失敗原因**，順序是照「最常被誤診成 skill 內容問題」排的：

| 症狀 | 真正原因類別 |
|---|---|
| fixture 建不起來／不在 git index／因錯誤理由失敗／自相矛盾 | Fixture |
| 沒有 results.json、「produced no results」、spec 沒載入 | Harness / spec-load |
| trial 出錯、逾時、空輸出 | Reliability |
| 正向紀錄（16W/8T/1L）、比較有結論、判決仍非 pass | **統計檢定力**（不是內容） |
| skilled arm 依構造等於 baseline arm | Eval 設計 |
| 有觸發但輸品質輸、judge 指出具體缺陷 | Skill 內容 |
| isolate 觸發但 plugin 不觸發 | Activation / routing |
| 兩個 arm 都沒觸發 | frontmatter description |

規則：**「不能引用一個輸掉的 trial 與 judge 的理由，就不准動 skill 內容。」**

這正是本機記憶裡逐條學到的東西的一般化形式 —— 壞 fixture 被讀成回歸（`e2e-alias-fixture-not-regression`）、缺 rg 讓反向斷言整段沒跑仍回綠（`ci-missing-rg-polarity-false-pass`）、殘留 schema 被讀成假綠（`integration-suite-residual-partial-schema`）。搬這張表比逐條記教訓便宜。

### 可搬 ④：兩個結構性檢查，對應本機已踩過的坑

10 個檢查裡有兩個直接對應本機歷史：

- **檢查 2「fixture 在磁碟上但不在 git index」**：他們的 `.gitignore` 有 `coverage*.xml`（Coverlet 輸出的合理規則），靜默吞掉一個 committed 的 Cobertura **fixture**。`git add -A` 回報成功、本機 eval 通過、CI 上三個 scenario 在 setup 就死。**只有 `git ls-files` 看得到，比對工作區永遠抓不到。** 對應本機 `write-tool-no-exec-bit-silent-gate`／`fork-fingerprint-includes-gitignored-scratch` 的同一族缺陷。
- **檢查 6「grader 缺必填 config」**：`config: null` 的 grader **什麼都不檢查**，但 YAML 合法、scenario 看起來多一條斷言。他們的驗證器寫 `(g.get("config") or {}).get("pattern")` 靜默跳過，前後 pattern 數一樣，只有人工 review 抓到。對應本機 CI 反向斷言假 PASS 的同一族。

另外**檢查 9「mapping 重複鍵」**：`yaml.safe_load` 接受重複鍵並保留**最後一個**，所以編輯殘留的第二個 `prompt:` 會落進**下一個** stimulus 並覆寫它 —— spec 解析成功、scenario 數目正確、其中一個是另一個的逐位元組複製。他們 PR #971 真的出過：新增的 scenario 是舊 scenario 的靜默複本，為它建的 fixture 從未被載入。修法是用**拒絕重複鍵的 loader**。

### 已經收斂（不是借鑑，是印證）

本機 `cases.jsonl` 的規則「每個 `fire` case 都須搭配同一 description 所隱含的 `quiet` case」= 對方的 dormancy guard（`expect_activation: false`）。兩邊獨立長出同一個東西。

對方多一條警告值得記：dormancy guard **不可同時**設 `constraints.reject_skills` —— 那會讓 skilled arm 變成無 skill，等同 baseline，分數純粹是 judge 噪音。同一個 guard 在四個 eval 上分別拿到 −0.4／+0.4／+0.4／0，兩次害 skill 沒過。

### 不可搬：平台本身

- **vally 未公開**（他們自己 CONTRIBUTING 裡的 TODO：「Vally is not yet public」）。整套 eval schema 依賴它。
- **skill-validator + dashboard + PAT pool + 2-FTE CODEOWNERS** 是單一 repo 加專職團隊的規模。
- 實際可搬的是：**算術（30 行）+ triage 分類表（一份 md）+ 兩三個結構性檢查**，不是一套 eval 平台。

---

## 5. 跨主機注意事項

**本機量測與 upstream 的文件化主張直接矛盾 —— 這是全報告唯一 upstream 尚不知情的發現。**

`eng/eval-quality/README.md:376-378` 寫得很明確：

> 設 `disable-model-invocation: true` 的 skill「is dropped from the Copilot CLI's `<available_skills>` menu, so the model cannot reach it from a user prompt」

這是他們把該旗標當 menu budget 工具的整套理由（實測把 `dotnet-test` menu 從 14,981 壓到 14,261 字元；96 個 skill 中 4 個設了此旗標）。

**但本機已量測到 Copilot 原生載入 95/95 並忽略此旗標**（記憶 `cross-host-skill-loading-and-user-invoked`）。同一個主機、同一個旗標、相反結果。

這不是「技術在某主機上效果打折」，是對 upstream 一項**具名主機的具體主張**的直接反證，而反證的一方（本機）有實測。實務後果：照抄此技術會得到「我壓了 menu」的錯覺，Copilot 側一個字元都沒少。若要向 upstream 回報，需先重跑一次本機 probe 確認在 `copilot 1.0.77` 上仍成立（本機記憶的量測日期早於此版本檢查）。

---

## 6. 建議動作（依價值排序）

| # | 動作 | 規模 | 依據 |
|---|---|---|---|
| 1 | `eval-triggers.sh` 加 n 與二項單邊下界，`n < 5` 印 `CANNOT CERTIFY`（**不是**符號檢定 floor —— 單臂比例不適用） | ~30 行 | §4-① 修法 1 |
| 2 | 把 triage 分類表（fixture→harness→reliability→power→eval-design→content→activation）寫進 `auditing-skill-folder` | 一份 md | §4-③ |
| 3 | `.claude/agents/*.md` 三個檔加 Domain Relevance Check（negative path） | 3 檔各 ~5 行 | §3-（2） |
| 4 | 重跑 Copilot dmi probe（`copilot 1.0.77`）確認是否仍與 upstream 主張相反；成立則回報 upstream | 一次 probe | §5 |
| 5 | 裝 `dotnet-test` plugin（**只此一個**），跑一輪對 DCT 測試套件的實測 | 一次安裝 | §2，13,430–15,084 chars menu 成本 |
| 6 | cases.jsonl 的 quiet case 加註「不得同時 reject 全部 skills」 | 註解一行 | §4「已收斂」段 |
| 7 | 定義 collision-vs-isolate 配對量後才套符號檢定（§4-① 修法 2） | 中等 | 有力但較貴，晚於 #1 |
| 8 | 若日後引入 LLM judge：只讀勝方，不讀幅度 | 條件觸發 | §4-② |

**不建議**：vendor 任何 dotnet/skills 內容進 `~/.agents/skills/`；複製 vally／skill-validator／dashboard；增加 agent 數量；把 `disable-model-invocation` 當跨主機 menu 工具。

---

## 驗證

clone 已在 session-local scratchpad，會消失。重跑前先重建：

```bash
git clone --depth 1 https://github.com/dotnet/skills.git /tmp/dotnet-skills
```

```bash
# 重現名稱零重疊（實際跑過的形式：先抽成 plugin|name|dmi，再取 name 欄）
D=/tmp/dotnet-skills
find $D/plugins -name SKILL.md | while read f; do
  p=$(echo "$f" | sed "s|$D/plugins/||; s|/skills/.*||")
  n=$(awk -F': *' '/^name:/{print $2; exit}' "$f")
  d=$(grep -c '^disable-model-invocation: *true' "$f")
  echo "$p|$n|$d"
done | sort > /tmp/dotnet-skill-names.txt
comm -12 <(awk -F'|' '{print $2}' /tmp/dotnet-skill-names.txt | sort -u) \
         <(ls -1 ~/.agents/skills/ | sort)     # 預期：無輸出
```

```bash
# 二項下界（§4-① 的表）
python3 -c "[print(f'{n}/{n}: {0.05**(1/n):.3f}') for n in (3,5,10,20)]"

# 版本門檻
codex --version   # 0.146.0 ≥ 0.121.0 → plugin marketplace 可用
```

menu budget 數字用本報告 §2 引述的 python3 frontmatter 解析片段（`name: description` 合併後計長）重跑。

已驗證事實：clone 檔案樹、96 個 plugin skill 名稱、4 個 `disable-model-invocation`、名稱交集為空、description 字元數（含 dotnet-test 含／不含 dmi 兩版）、`eng/eval-quality/README.md:376-378` 的 Copilot 主張原文、`codex-cli 0.146.0`、`copilot 1.0.77`、DCT csproj 無 `<Nullable>`。
未驗證：dotnet/skills 各 skill 對本機工作流的實際 output delta（需真的裝來跑）；Copilot dmi 行為在 `1.0.77` 上是否仍與 upstream 主張相反（本機記憶的量測早於此版本檢查）。
