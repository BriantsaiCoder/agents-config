# 兩份報告裁決：Copilot（Opus 5）vs Codex（GPT-5.6 Sol）

日期：2026-08-05｜裁決者：Claude Code（Opus 5）｜對象：[01-independent-rereview.md](01-independent-rereview.md)（Copilot）、[00-report.md](00-report.md) 與 Codex 口頭結論
本檔未修改任何設定。所有判定附 live 指令與輸出。

> **發布註記**：本檔保存 2026-08-05 的裁決證據，不宣稱表內 live counts／settings 仍是現在值。
> 後續 [agents-config PR #57](https://github.com/BriantsaiCoder/agents-config/pull/57) 已以 semantic capability parity 取代逐字 T2-6 parity；host-local 變更由
> 各自 PR 擁有。未合併的排序項目只是 backlog，沒有自動延伸成實作授權；重用前先做 live probe。

### 發布後狀態 ledger

| 原排序項目 | 狀態 | Durable evidence |
|---|---|---|
| 1. 還原 Copilot／Codex T2-6，解除 byte-gate 衝突 | **MERGED** | [Copilot PR #5](https://github.com/BriantsaiCoder/dotcopilot/pull/5)、[Codex PR #8](https://github.com/BriantsaiCoder/dotcodex/pull/8)；shared enforcement 改由 [agents-config PR #57](https://github.com/BriantsaiCoder/agents-config/pull/57) 驗 semantic capability |
| 2. 縮 Copilot write scope | **MERGED** | [Copilot PR #6](https://github.com/BriantsaiCoder/dotcopilot/pull/6) |
| 3. 從 session 蒐集 3–5 個實際卡點 | **BACKLOG** | 尚無 durable artifact；不得視為已授權工作 |
| 4. 改 Context7 設定 | **REJECTED／KEEP CURRENT** | 使用者決定維持原來設定方式；本批無 Context7 host PR |
| 5. 為 SEMANTIC／TONE-LOCK 規則加 alternation | **REJECTED** | 未做逐字 alternation；依本裁決 §1-1、§1-3、§1-4 的錯誤前提、byte-gate 衝突與結構性契約風險退回 |
| 6. Codex `high`／`medium` 對照 eval | **BACKLOG** | 尚未執行；只表示待評估，不授權變更 effort，current value 必須 live probe |
| Companion：Claude autonomy defaults | **MERGED** | [Claude PR #12](https://github.com/BriantsaiCoder/dotclaude/pull/12) |

---

## 一句話

**兩份都沒說中病灶。** Copilot 的「棘輪」診斷被自家測試檔實測推翻（`lacks` 是**只准放鬆**的釘，且降級實驗中維持 GREEN）；Codex 方向對，但三條主要建議中兩條的前提不成立、一條是重提你已否決的項目。

真正被焊死的地方兩份都沒看到：`~/.copilot/tests/global-config-ownership.sh:138` 的 3600B 硬閘與 `~/.agents/tests/three-host-global-config-ownership.sh:84` 的逐字 T2-6 斷言**互相排斥**——滿足其一必然違反另一，距可通過上限差 **8 bytes**。而該 3600B 預算查無任何官方依據（§5-5），所以這個死結有零風險解。

---

## 一、Copilot 報告：核心診斷不成立

### 1-1 MUST 密度表錯了（51 → 實測 33）

| 檔 | 宣稱 | 實測 | 是否常駐 |
|---|---|---|---|
| `~/.claude/CLAUDE.md` | — | **1** | ✅ |
| `core/tier0-safety.md` | — | **9** | ✅（`@`-import） |
| `core/tier1-workflow.md` | — | 12 | ❌ 刻意不載入 |
| `core/tier2-style.md` | — | 6 | ❌ 刻意不載入 |
| **Claude 常駐合計** | **28** | **10** | |
| kernel | 23 | 23 | 按需讀 |
| **總計** | **51** | **33** | |

`9 + 12 + 6 + 1 = 28` — 完全吻合，代表該報告把 tier1／tier2 當成常駐加總。

**一手證據（非推論）**：本 session 的 system prompt 逐字含有 `CLAUDE.md` 與 `tier0-safety.md` 全文，**不含** tier1／tier2 任何一行。`CLAUDE.md:46-52` 的 `@~/.claude/rules/*.md` 是包在反引號裡的清單指標，不是 `@`-import；唯一真正展開的是 `CLAUDE.md:4` 的 `@~/.claude/core/tier0-safety.md`。

### 1-2 斷言數是 filter 產物，不是現象（29 可達，但無原則）

兩個數字都對，取決於用哪條 filter：

```bash
grep -E "rg -q|has |rule_has"        → 25   # 報告正文引用的版本
grep -E "rg -q|has |rule_has|grep"   → 29   # 報告內另一處展示的版本
```

問題不在 25 或 29，在於這個 token-grep 三個方向同時失真：

- **多算**：`pr-path-gate.sh:54` 的 `MUST` 在 `miss="..."` 失敗訊息字串裡，不是 regex。真正的 pattern 在 `:33` 的 `PROHIBITION='MUST NOT 直接 push'`，而該行 filter 抓不到。
- **漏算**：`tests/*.sh` 共 **58** 行含 MUST。被 `grep -v tier0-parity` 排掉的 `tier0-parity.sh:100-108` 是九條 tier0 canonical 全文的 REQUIRED fixture 表——**全 repo 最強的釘死**，報告未說明為何排除。`delegation-policy-parity.sh:40/66`（`NOASK_RE`／`ASKFIRST_RE`）是真正的斷言 regex 且**已經**用 `(MUST NOT|不得)` alternation，正是報告要推廣的那個 class，卻被 filter 藏起來。
- **幻算**：`matt-thin-workflow.sh` 的 23 個 `lacks` grep 命中**全是失敗訊息字串**，0 個斷言；它真正的反向斷言是 20 個 `! rg -q` 形式。

### 1-3 「棘輪」不成立（最關鍵反證）

宣稱：「語氣只能單向變強，永遠無法調弱」。

**直接反證**：`tests/mattpocock-workflow.sh` 有約 23 條 `lacks`（反向）斷言，其中 `:194`

```bash
lacks "bugfix no longer has unconditional RED" 'MUST 在 fix 前先有 failing regression test.*例外：無' skills/dev-workflow/SKILL.md
```

**這條斷言的存在，正是為了強制某條 MUST 必須維持在「已被移除」狀態。** 同類還有 `:149`（禁止恢復 blanket ask-before-edit）、`:219`（禁止恢復 S4 全跑）、`:238`（禁止恢復 blanket RED）、`:274`（禁止恢復固定 fan-out 數字）。測試套件是**雙向釘死**，而且歷史上已經被用來執行降級。棘輪的方向性前提在自家測試檔裡就被推翻。

`lacks()` 的語意是 **rg 命中就 FAIL**——`:194` 這條的意思是「這個 MUST 一旦被加回來就紅燈」。這是**只准放鬆**的釘，方向與所謂棘輪完全相反。而且它就在該報告自己那 29 條之內。

**實測（clone 到 scratch，把 kernel 全部 `MUST NOT→不得`、`MUST→必須`）**：

```
baseline: 210 PASS / 0 FAIL
降級後  : 189 PASS / 21 FAIL
其中 mattpocock:194（那條 lacks）維持 GREEN，21 個鄰居轉紅
```

`sed` 實驗（改措辭 → 斷言 FAIL）本身為真，但那只證明「測試會抓到你改了它在測的東西」——這是測試的定義，不是棘輪。棘輪需要「無法連帶修改測試」的機制。實測**不存在**：`tests/` 不在 `[INT-10]` 的列舉範圍內、無 CODEOWNERS、無 branch protection、無 checksum、`protect-files.sh` 的 `PROTECTED_PATTERNS` 只有 11 條 secret 檔樣式、CI 只跑測試不釘內容。

**測試很嚴（21 個實測紅燈是真的），但嚴 ≠ 焊死。** 28 條分類後：純 TONE-LOCK 只有 **1** 條，STRUCTURAL 3 條，SEMANTIC 23 條，ALREADY-SEMANTIC 1 條。23 條的修法就是加一個 token 的 alternation，而 repo 裡維護者自己已經寫過那個 alternation。

**同一場實驗還撞出一個兩份報告都沒預料的結果**：語氣降級本身就爆掉 kernel byte 閘——

```
FAIL: dev-workflow kernel exceeds 12700 bytes: 12717
```

`必須`(6 B) > `MUST`(4 B)、`不得`(6 B) < `MUST NOT`(8 B)，淨 +18 B。**N1 的措辭改法在機械上就執行不了**，這不是推論，是量到的。

### 1-4 N1-a 解不開 N1（報告內部自相矛盾）

25 條中的 STRUCTURAL 子集，`MUST` 不是語氣而是**四欄規則契約的第一欄**：

```bash
rule_has "S5 risk contract has five elements" S5-1 'MUST.*觸發：.*例外：.*驗證：'
```

tier0 九條全部是 `MUST／觸發／例外／驗證` 這個 schema，而 `tier0-safety.md` 自己要求「衝突條文引用一律用規則 ID，讓裁決過程可稽核」。

該報告的 N1 示範改法把契約行改成散文：

> `[T1-5] 除非任務明確要求重構，MUST NOT 順手改…` → `只改任務範圍內的 code；格式與命名沿用該檔既有風格。`

這不是「語意一字不動、零行為變更」——它刪掉規則 ID、刪掉 `觸發／例外／驗證` 三欄，拆掉 parity 測試與裁決機制共同依賴的 schema。而 N1-a 的語意錨點 `(MUST NOT|不得|不可|禁止)` **仍要求存在一個禁止詞**，直述句改法照樣 FAIL。**N1-a 無法解鎖 N1 的結構性子集**，這是報告自身優先序內的矛盾。

### 1-5 成立的部分

- ✅ Copilot CLI 跑 `claude-opus-5`：`~/.copilot/settings.json:85-86`（`"model": "claude-opus-5"`, `"stayInAutopilot": true`）。三家實為 2× Opus 5 + 1× GPT-5.6。
- ✅ 語意錨點慣例確實存在且未推廣：`tests/delegation-policy-parity.sh:40,66` 的 `NOASK_RE`／`ASKFIRST_RE` 已用 alternation；25 條中只有 `matt-thin-workflow.sh:366` 一條跟進。

### 1-6 未察覺套件正在紅燈

該報告聲稱跑過測試，但完全沒提到 `three-host-global-config-ownership.sh` 目前 **exit 1**。

---

## 二、Codex 報告：方向對，頭號建議應退回

| # | 建議 | 判定 |
|---|---|---|
| 1 | Codex ultra → high（CP 極高） | ❌ **重提已否決項**。2026-08-04 使用者明確答覆 `~/.codex/config.toml:11` 的 `ultra` 是量測後選定、不降級。可保留的只有「跑一次 high/medium 對照 eval」這半——那確實從未執行。 |
| 2 | gate 改依 action/risk 觸發 | ❌ **改已經開著的門**。`SKILL.md:20` 的 `[INT-3]` 方向與宣稱**相反**：「Medium-risk MUST NOT 成為第二次確認 gate」，例外句明文允許 clear／in-scope／local／reversible 的 Low／Medium-risk 直接做、Medium 只留 session plan。`SKILL.md:67` 再述一次。 |
| 3 | global config 分兩類（安全政策 vs 可逆偏好） | ❌ **前提不成立**。`SKILL.md:28` 的 `[INT-10]` 不是依檔案身分而是依**列舉類別**：`CLAUDE.md／AGENTS.md／copilot-instructions.md、tier0/1/2、kernel／references、hooks、permission／sandbox、CI workflow`。model／effort／verbosity／plugin／MCP **都不在列**——整個 dev-workflow 樹 grep `settings.json\|effortLevel\|verbosity\|MCP\|plugin` 回 **0 命中**。可逆偏好從來就不受 INT-10 管。 |
| 4 | host-adapters「只能加嚴」改「可採等價 host-native enforcement」 | ⚠️ 條文在 `host-adapters.md:5` 不是 `:3`（`:3` 是載入時機句）。實際條文比轉述更強：「⋯MUST NOT 放鬆其 MUST 或無條件約束；**放鬆需 user 當下明示**」。這是放鬆 tier0 裁決鏈，須你明示，不在審查自主範圍。 |
| 5 | 修 `three-host-global-config-ownership.sh`（現 exit 1） | ✅ **唯一被兩份報告之一抓到的真實紅燈**，且只有 Codex 抓到。但**修法建議錯**，見下節。 |
| 6 | Copilot home-wide write 縮到 coding roots | ✅ 合理（待 workflow 驗證實際 scope）。 |
| 7 | 71 skills 不整批刪，先收斂 description | ✅ 與既有 skill 稽核結論一致。 |
| 8 | 版本／尺寸事實 | ✅ 全部正確：codex-cli 0.146.0、Copilot CLI 1.0.78、Claude Code 2.1.220、`dev-workflow/SKILL.md` = 12,699 B。 |

---

## 三、兩份都漏的：真正的焊死點

### 3-1 兩道機械閘直接對撞

`~/.agents/tests/three-host-global-config-ownership.sh:84` 要求三個 host 的 active config **逐字**含有：

```
- 回覆 SHOULD outcome-first、無空泛前後文；決策列編號選項／推薦／取捨，單字或數字即為完整回答，推測標記，已決不列替案。
```

實際狀態：

| Host | 現行文字 | bytes | 符合 |
|---|---|---|---|
| Claude | 逐字相符 | 167 | ✅ |
| Copilot | `回覆 outcome-first，決策列推薦／取捨，推測標記。`（併入 zh-TW 句） | 105 | ❌ |
| Codex | `回覆 outcome-first；決策列推薦／取捨；推測標記。` | 67 | ❌ |

Copilot／Codex 共同丟失 4 個子句：`無空泛前後文`、`編號選項`、`單字或數字即為完整回答`、`已決不列替案`。這是**語意損失，不是同義改寫**。測試迴圈先撞到 Codex 就 `fail` 退出，所以只報一個——**實際是 2/3 host 漂移**。

而 `~/.copilot/tests/global-config-ownership.sh:138`：

```bash
[ "$bytes" -lt 3600 ] || fail "copilot-instructions.md must stay below 90% of its 4000B budget: ${bytes}B"
```

算術：

```
copilot-instructions.md 現況 = 3545 B，headroom = 54 B
還原 canonical T2-6 = +62 B（167 − 105）
還原後 = 3607 B，較可通過上限 3599 B 超出 8 B（62 − 54）
```

**差 8 bytes。滿足 shared parity 斷言必然違反 Copilot byte 閘，反之亦然。** 這才是字面意義上「規則被焊死」——而且與 `MUST` 一個字都無關。

### 3-2 kernel byte 閘只剩 1 byte

`tests/matt-thin-workflow.sh:66-68` 硬閘 `kernel ≤ 12700`，現值 **12699**。任何 kernel 改寫（含 Copilot 的 N1 語氣降級、Codex 的 gate 重構）都在 1 byte 的餘裕內動作。兩份報告都提了要改 kernel，都沒量。

### 3-3 沒有任何一份舉出實際 overtrigger 案例

使用者的訴求是「綁手綁腳」——實際摩擦。兩份報告都只從官方文件推導到「你的 prompt 太 aggressive」，**沒有任何一個具體 session 中某條規則實際卡住工作的實例**。

`~/.claude.json` 的 `skillUsage`（權威來源，非 grep transcript）：83 個 skill、691 次呼叫、**0 個從未觸發**。這不能證明沒有 overtrigger，但也完全不支持「規則太強導致誤觸」的假說——它只證明 routing 是活的。

### 3-4 使用者自訂 MUST 相對 harness 是捨入誤差

Anthropic 的「dial back aggressive language」針對的是「你的 prompt 是主要訊號」的情境。本機不是：Claude Code harness 自身注入的 system prompt 就含有 `IMPORTANT: These instructions OVERRIDE any default behavior and you MUST follow them exactly as written`、`you MUST load the artifact-design skill`、`MUST be a PURE LITERAL`、`you must call request_access`、`Never publish`⋯⋯以及數十處 NEVER／ALWAYS／IMPORTANT／CRITICAL，量級在 100+。使用者常駐 MUST 是 **10**。

即使密度表沒算錯，33 → 9 的效果也與零無法區分，代價卻是 25 處測試改動 + 撞上 byte 閘。**N1 在自己的前提上就不成立。**

---

## 四、合併排序

| 序 | 項目 | 提出者 | 風險 | 理由 |
|---|---|---|---|---|
| **1** | 提高 `~/.copilot/tests/global-config-ownership.sh:138` 的 3600/4000B 預算，然後把遺失的 4 個 T2-6 子句還原進 Copilot／Codex active config | **NEW** | 低 | 唯一在紅的閘。§5-5 已證該預算無官方依據，調高是零風險解；還原後 `three-host-global-config-ownership.sh` 轉綠 |
| 2 | 縮 Copilot write scope：把 `"/Users/pochientsai"` 的裸 `{"kind":"write"}` 與無限定 `docker`／`git clone`／`dotnet publish` 降到實際 coding roots | Codex（範圍低估） | 低 | 目前整個 home 可寫，且指令授權比轉述更寬 |
| 3 | 從實際 session 找 3–5 個規則卡住工作的實例，逐條修 | **NEW** | 低 | 唯一直接回答「綁手綁腳」的路徑；兩份報告都零實例 |
| 4 | 決定 Context7：恢復安全的 env 注入並做 restart canary，或停用該 MCP | Codex | 低 | `enabled = true` 但 key unset。launchctl 半段無法從受保護 wrapper 驗證，需你在互動 shell 自行確認 |
| 5 | 28 條中 SEMANTIC(23) + TONE-LOCK(1) 子集加 alternation | Copilot（N1-a） | 低 | 每條只加一個 token；維護者自己已寫過該慣例（`NOASK_RE`／`ASKFIRST_RE`）。**STRUCTURAL(3) 不適用**——那是四欄契約的第一欄 |
| 6 | Codex `high`／`medium` 對照 eval | Codex（半項） | 低 | `ultra` 本身不動；只補從未做過的量測。官方定義 Ultra = subagent 平行模式，適用於「可切成獨立部分」的任務——這是可量的判準 |

**應退回**：

| 項目 | 提出者 | 退回理由 |
|---|---|---|
| N1 語氣降級 33→9 | Copilot | 前提錯誤（§1-1、§5-2、§3-4）、與 N1-a 自相矛盾（§1-4）、**實測撞 kernel byte 閘 12717 > 12700**（§1-3） |
| N1-a 全面改 29 條 | Copilot | 只有 1 條純 TONE-LOCK；STRUCTURAL 3 條改了會拆掉四欄契約 |
| ultra → high | Codex | 你 2026-08-04 已否決 |
| gate 改依 risk 觸發 | Codex | `[INT-3]` 方向與宣稱相反，門已經開著（§二 #2） |
| config 分兩類解 INT-10 | Codex | `[INT-10]` 範圍不含 model／effort／verbosity／plugin／MCP，kernel 全樹 0 命中（§二 #3） |
| host-adapters 放鬆 | Codex | `host-adapters.md:5` 明載放鬆需你當下明示 |

**兩份都對、保留不動**：tier0 九條、`[S5-3]`／`[S5-4]`／`[INT-4]`（§5-1 證實 `[S5-4]` 正面對齊官方）、S4 機械 gate、三層 progressive disclosure、Claude `high` + thinking + auto + sandbox（`model` 刻意不 pin）、Codex Sol + workspace-write + auto-review、Copilot Opus 5 + autopilot、71 skills 不整批刪。

---

## 五、官方文件裁決

### 5-1 兩份報告的直接矛盾：Codex 對，Copilot 錯

[Opus 5 的 Code review and bug-finding](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5#capability-improvements) 建議 review pass 先廣泛回報，再由後續 pass 過濾；它沒有要求後續 pass 必須由另一個 agent 執行。因此 Copilot 拿這段支撐「獨立 reviewer」是引用錯 scope。

Codex 對 [Task scope and over-verification](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5#task-scope-and-over-verification) 的 scope 判讀成立：Opus 5 已會自我驗證，額外 final-verification、subagent double-check 與 legacy verification scaffolding 會增加成本而不改善結果。相鄰的 `Controlling subagent spawning` 與 `Self-correction` sections 也反對把 subagent／re-check 當重複自驗證層。

**但 scope 有硬界限**：全部針對「叫模型驗證**自己**工作」的 prompt 指令與 legacy harness scaffolding。**官方全篇沒有一句提到機械 gate（跑 test／build／lint／CI）**。S4 是機械 gate，不在射程內。

**逐條落點**：

| 規則 | 官方立場 | 處置 |
|---|---|---|
| `[S5-4]`「全部回報、下游過濾」 | **正面背書**——這正是官方要你做的 | 不動 |
| `[S5-3]` reviewer contract | 未涉及 | 不動 |
| `[INT-4]` main context 重驗 subagent 回報 | 未涉及（官方講的是「派 subagent 去驗自己」，方向相反） | 不動 |
| `CLAUDE.md`「S5 以外不另派 subagent 做 verification」 | **已對齊** | 不動 |
| S4／`[INT-1]` 機械 gate | 明示不在射程 | 不動 |

**結論：這條軸上你的設定已經對齊官方，兩份報告都在爭一個不存在的缺口。**

### 5-2 「dial back aggressive language」不適用 Opus 5（Copilot 的 N1 前提）

[Prompting best practices 的 Tool use section](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices#tool-use) 確實警告 aggressive undertrigger 補丁可能造成 overtrigger，但該段明確只點名 **Opus 4.5 與 4.6**。

**Opus 5 專屬頁完全沒有這一段**——它的對應章節是 `Task scope and over-verification`／`Controlling subagent spawning`／`Self-correction`／`Response length and verbosity`。migration guide 的 Opus 5 段落同樣沒有；反方向只剩 [general principles](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices#general-principles) 對 current models 的泛用聲明，不能覆寫 model-specific 主詞。

**「Anthropic 對 Opus 4.5+ 的警告覆蓋你 2/3 表面積」是審查者的推論，不是 Anthropic 的文字。**

### 5-3 「reduce adherence」成立，但單位是行數不是 MUST 數

CONFIRMED，出處是 [Claude Code memory guidance](https://code.claude.com/docs/en/memory) 不是 prompting guide：它以 200 行作為每份 `CLAUDE.md` 的建議上限，理由包含 context 使用與 instruction adherence。

`CLAUDE.md` 現況 **56 行**，遠低於 200。這條對本機不構成問題，也不支持 N1（換掉 MUST 不減行數）。

### 5-4 GPT-5.6：`ultra` 不是 API effort 值

- **lean prompt 成立**：[GPT-5.6 Favor leaner prompts](https://developers.openai.com/api/docs/guides/latest-model#favor-leaner-prompts) 要求規則單一歸屬，並把 internal coding-agent sample 的 eval、token、cost 改善視為方向性結果，仍須用 representative tasks 驗證。
- **effort ladder 是兩套**：[API migration guidance](https://developers.openai.com/api/docs/guides/latest-model#update-api-and-model-parameters) 的 enum 為 `none`→`max`、一般起點 `medium`；[Codex model guidance：Pick a reasoning effort](https://learn.chatgpt.com/docs/models#pick-a-reasoning-effort) 另有產品層模式。
- **`ultra` 不在 API `reasoning.effort` enum**；[Codex 的 Max／Ultra section](https://learn.chatgpt.com/docs/models#know-when-to-use-max-or-ultra) 將 Ultra 定義為用 subagents 平行處理可拆分的大型任務，並提醒多數任務不需要 Max／Ultra。
- Codex 報告對這段的轉述**正確**。

### 5-5 GitHub：3600B 硬閘沒有官方依據

- 2026-08-05 重驗的 official surfaces 包含 [repository custom instructions](https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot) 與 [customizing Copilot code review](https://docs.github.com/en/copilot/customizing-copilot/customizing-copilot-code-review)。數字型建議只出現在特定 code-review／prose 情境，不能外推成全域 prompt byte cap。
- 上述官方頁與其 GitHub Docs source 在該日均未定義 byte／character／token 限制；因此 3600/4000B 只能視為本機自訂 budget，而非 vendor requirement。這是 negative-search 結論，官方文件日後變更時須重驗。

→ **`~/.copilot/tests/global-config-ownership.sh:138` 的 `< 3600` 與 4000B 預算是自訂的，沒有官方基礎。** 這讓第三節的對撞有一個零風險解法：調高該預算。

### 5-6 剩餘 live 宣稱

| 宣稱 | 判定 | 證據 |
|---|---|---|
| Copilot home-wide write | ✅ **且比轉述更寬** | `permissions-config.json` 在 key `"/Users/pochientsai"` 下是裸 `{"kind":"write"}` 無 path 限定，另含無限定的 `docker`／`git clone`／`dotnet publish`／`awk`／`kill`／`sleep` |
| CONTEXT7_API_KEY unset | ⚠️ 一半 | config.toml:58-64 `enabled = true`、`env_vars = ["CONTEXT7_API_KEY"]`；shell 與 login shell 皆 **unset**（只報 set/unset）。**launchctl 半段 UNVERIFIABLE**——受保護 wrapper 的 allowlist 無 `getenv` |
| `agents-sync --check/--doctor` exit 0、71/71 | ✅ | 兩者 exit 0；`ls ~/.claude/skills \| wc -l` = 71 symlink |
| `hook-parity-check --strict` exit 0 | ✅ 非靜默假綠 | flag 有解析；三份 `guard-git-push.sh` SHA256 完全相同 |
| 71 shared skills | ✅ | 72 個 top-level 目錄，多的那個是 `.claude`（非 skill）；71 個各有 1 份 SKILL.md，無空目錄 |
| Claude 主模型未 pin | ✅ | `settings.json` `model` ABSENT、`effortLevel = "high"`、無 `ultracode`／`workflowSizeGuideline`；env 無 `ANTHROPIC_MODEL`。註：`advisorModel` 有設 |
| Copilot instructions 28 行 | ✅ | `wc -l` = 28（3545 B） |
