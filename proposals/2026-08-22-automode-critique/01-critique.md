# Claude Code Auto Mode 批判性審查

- 日期：2026-08-22
- 受測 binary：`~/.local/share/claude/versions/2.1.239`（Mach-O arm64, 325 MB）
- 受測設定：`~/.claude/settings.json`（`permissions.defaultMode: "auto"`, `skipAutoPermissionPrompt: true`）
- 實證資料：`~/.claude/projects/**/*.jsonl` 共 1273 份 transcript
- 方法：binary strings 反查 classifier prompt 與決策路徑 + transcript 全量統計 + 本 session 現場複現

---

## 0. 量化基線（先給尺度，避免把稀有事件講成常態）

統計窗 **2026-08-01 → 2026-08-22**。這個起點不是 auto mode 啟用日，而是 `cleanupPeriodDays: 30` 的保留邊界。

分子與分母都以 `tool_use_id` 去重（transcript 會因 fork／resume 重複收錄整段前綴，不去重會系統性灌水分母）：

| 指標 | 值 |
|---|---|
| 去重後 tool_use 總數（全工具） | 21,194 |
| 去重後 Bash tool_use | 15,402 |
| classifier 攔截（`toolDenialKind: automode-blocked`） | **29** |
| 攔截率（全工具） | **0.137%（1 / 730）** |
| 攔截率（僅 Bash） | 0.149%（1 / 669） |

同期各類拒絕的組成：

| `toolDenialKind` | 次數 |
|---|---|
| `permission-rule`（確定性規則：自訂 deny／hook） | 296 |
| `automode-blocked`（classifier） | 29 |
| `user-rejected` | 28 |
| `automode-unavailable` | 2 |
| `cancelled` | 2 |

**結論先講**：auto mode 不吵。真正在擋事的是使用者自己的確定性規則，比例 10:1。classifier 只佔全部拒絕的 8%，但它是**唯一不可預測、且無法歸因**的那一層——下面的批評全部集中在這個性質上，而不是在頻率上。

29 筆經三軸獨立交叉裁決（詳見 [02-verification.md](02-verification.md)）：

- **20 筆 false positive、9 筆 justified**（多數決）。其中 id 5／6 為 2:1 contested——反對軸引述 `PREEMPTIVE BLOCK ON CLEAR INTENT` 且**引述正確**，故保守讀數是 **18 筆無爭議 FP**
- 9 筆 justified 全部是持久化／權限放寬／外部化；其中 4 筆是**使用者自訂規則**命中，不是內建規則
- 20 筆 FP 有 **0 筆**寫到 session scratchpad 以外
- **17/20 的 FP 共用同一個語法特徵：一行多段 Bash**（分隔符最少 2、中位數約 7、最多 41）；而 justified 的 Bash 攔截多在 0–1 個分隔符
- 失效模式是「**讀 token，讀不出 mode**」：`sed` 無 `-i`、`sed -n` 純列印、`gh api` 無 `--method`（GET）、輸出到 `/dev/null`、目的地在 `/private/tmp`——但字串裡有 `rm`／`merge`／`~/.claude`／`/pulls/` 這類 token，就擋

---

## A. 機制層批判（Claude Code 本身）

### A1〔最高〕`steerOnly` 分支把安全指引換成了 bash-first 效能提示

Binary offset 300785118 附近的組裝邏輯（去混淆後）：

```js
i = `Do your work through the ${Bash} tool wherever it can accomplish the job: read files with
     cat, head, or sed -n, search with grep and find, and make file changes with sed, heredocs,
     or short scripts, rather than using the dedicated ${Read}, ${Edit}, or ${Write} tools. ...`

s = e.bypass    ? `While bypass permissions mode is active:\n\n${i}`
  : e.steerOnly ? `While auto mode is active:\n\n${i}`
  :               n + o + (e.bashFirst ? `\n\n${i}` : "")
```

三個分支的差異是實質的：

- `n` = git 安全指引（destructive 指令前先 `git status`、先 stash `-u`、broad `git add` 後複查、推送前查可疑檔案）
- `o` = `autoModeConsentFlow`（被擋時怎麼辦：先找無規則阻擋的替代路徑並繼續；不行就 hold 住並在回合結束前批次提問；**"If you believe a block is wrong, ask that directly"**）
- `i` = bash-first 提示

`steerOnly` 為真時，`n` 與 `o` **都不注入**，只留 `i`。

本 session 收到的注入文字逐字就是 `While auto mode is active:` + bash-first 段落，沒有 consent-flow、沒有 git 安全段——即 `steerOnly = true` 這條分支。這不是推論，是本 session 的 system-reminder 原文。

批評成立點有兩個，而且互相加乘：

1. **方向錯誤**。三個工具面裡，Bash 是確定性閘門最弱、classifier 曝險最高的那一個；Read/Edit/Write 有 path-based `permissions.deny`、protected-path 檢查、Edit 的 diff 可視性。指示 agent 優先走 Bash，等於把工作推向唯一需要 LLM 逐次裁決的通道，同時放大 classifier 的呼叫量與誤判面。
2. **配套被拿掉**。同一分支同時刪掉了「被擋時該怎麼反應」的協定。agent 被要求多用高風險通道，卻沒被告知遇到攔截要找替代路徑、要批次提問、可以直接質疑攔截是否錯誤。

`bashFirst` 的開關 `dci()` 由 `CLAUDE_CODE_THRIFTY_SONIC` env、`tengu_thrifty_sonic` GrowthBook flag、或 `bashFirstSessionAssignment()` cohort 決定。**〔推測〕** 從 "thrifty"（省）這個命名與行為看，bash-first 是 token 成本實驗，不是安全或正確性特性；把它掛在 `steerOnly` 分支並順帶擠掉安全段落，看起來是組裝順序的副作用而不是設計意圖。

### A2〔高〕攔截無法歸因，因此政策無法調校

classifier prompt 自己強制輸出格式：

> `<block>yes</block><category>Exact BLOCK Rule Name</category><reason>[Exact BLOCK Rule Name] one short sentence</reason>`
> `<category> is the matched BLOCK rule's name, using only letters, digits, and spaces`

實際落到 agent 與 transcript 的是什麼：**38 筆攔截訊息裡 36 筆的 reason 是字面常數 `Blocked by classifier`**，另 2 筆是 `Stage 2 classifier error`。transcript 唯一的結構化欄位是 `toolDenialKind: "automode-blocked"`。29 筆去重攔截，**沒有任何一筆帶規則名**。

`Blocked by classifier` 在 binary 裡（line 175840 附近）與 `Allowed by classifier`、`Blocked by fast classifier`、`No reason provided`、`parse_failure`、`policy_refusal` 並列，是一組泛用常數。

同時，內部**確實有**一套細緻的歸因分類法（line 356066）：

```
rule:<source> / mode:<mode> / hook:<name> / classifier:<name> /
subcommands:<a+b> / sandboxAutoAllow / readOnlyCommand /
classifierTranscriptTooLong / permissionStreamClosed / bashMiss:<kind>
```

但**規則名不在這套分類法裡**——它只標「決定來自哪一層」（`classifier:auto-mode` / `:unavailable` / `:no-verdict`），不標命中哪條規則。

規則名（`category`）實際只有兩個去處，兩個都預設不可見：

1. `tengu_auto_mode_decision` 遙測的 `classifierCategory` 欄位（不落本機）。
2. **本機 opt-in log**：`AUTOMODE_DECISION_LOG=1` 時，`M4f.append` 會把每筆決定寫成 `.automode_decisions.jsonl`，欄位包含 `tool` / `decision` / **`category`** / `classifierModel` / `stage` / `stage1Severity` / `stage2Severity` / `costUSD` / `durationMs`。

```js
class M4f{ logPath;
  append(e){ if(this.logPath===undefined)
      this.logPath = process.env.AUTOMODE_DECISION_LOG==="1"
        ? path.join(rr(), ".automode_decisions.jsonl") : null;
    if(!this.logPath) return;
    fs.appendFile(this.logPath, JSON.stringify({ts:Date.now(), ...e})+"\n") } }
```

已逐層驗證到底（不是推論）：

- `yal(session, payload)` 的定義是 `function yal(e,t){ R9v.of(e).append(t) }`，而 `R9v = new Ap(() => new M4f)` —— **`yal` 就是這支 log 的寫入口**，classifier 路徑的呼叫帶 `category: j.category`。
- 落點 `rr()` = `Bqo.getStore()?.cwd ?? pZ()` —— **是 session 的 cwd，不是 `~/.claude`**。

⚠️ **啟用前先處理落點**：檔案會寫在每個 session 的工作目錄根部，也就是會掉進 git repo 裡。**先把 `.automode_decisions.jsonl` 加進 global gitignore**（或各 repo 的 `.gitignore`），再開啟——否則會被 `git add` 掃進 commit。

**這條把 A2 從「無解」變成「一個 env var + 一行 gitignore」**，是本審查最實用的單一發現。設定後即可對照「哪條規則在擋」再回頭修 `autoMode.allow`。

後果具體且可衡量：使用者手上有 66 條內建 SOFT BLOCK 規則、1 條內建 HARD 規則、16 條 ALLOW 例外，加上自己寫的 12 條，卻在被擋時拿不到「命中哪一條」。**要調 `autoMode.allow` 只能猜。** 這是本審查裡對使用者實務影響最大的一條。

### A3〔高〕全部失敗路徑 fail-closed，長 session 結構性受害

Binary offset ~369596，每一條錯誤路徑的回傳都是 `{shouldBlock: true, ...}`：

| 情境 | reason 字串 |
|---|---|
| 請求中止 | `Classifier request aborted` |
| **transcript 超出 context window** | `Classifier transcript exceeded context window`（遙測 `transcript_too_long`） |
| stage 2 失敗 | `Stage 2 classifier error - blocking based on stage 1 assessment (usually transient — retrying often succeeds)` |
| 其他不可用 | `Classifier unavailable - blocking for safety` |
| **classifier 模型自己拒答** | `policy_refusal` / `refusedBySafeguard: true` |

**修正（獨立驗證後）**：上表是 classifier **函式本身**的回傳值，不等於權限結果。呼叫端不一致——而且不一致的方向是壞的：

| 消費端 | 失敗時行為 |
|---|---|
| Bash/Edit 等工具權限（`unavailable`） | **fail-closed**（拒絕） |
| `transcript_too_long`，互動模式 | 降級為 ASK（`falling back to normal permission handling`）；只有 `dontAsk` 模式才 DENY |
| **Task 工具 + `transcript_too_long`** | **fail-OPEN**（`return {behavior:"allow"}`，356169 @15463） |
| **workflow gate**（`unavailable`） | **fail-OPEN**（`u.shouldBlock&&!u.unavailable?{reason}:null` → `null`，無閘） |
| **subagent handoff review**（`refusedBySafeguard` / unavailable） | **fail-OPEN**（只回 advisory warning，子代理輸出照過） |

也就是說：**單一 Bash 指令 fail-closed，但「生一整個子代理」與「子代理交回結果」這兩個槓桿更大的面 fail-OPEN**。這比一致的 fail-closed 更值得擔心。

兩個副作用值得指出：

- `transcript_too_long`：classifier 吃的是**對話 transcript**。session 越長，classifier 越可能因為自己的 context 溢出而攔截——與被評估的動作本身危險與否無關。這台機器 `ultracode: true` + `effortLevel: xhigh` + 15M token 預算，正是最容易撞到的使用型態。
- `policy_refusal`：裁決模型的安全拒答被轉成「拒絕執行」。判斷者的 refusal 與被判斷動作的危險性是兩件事，這裡被折疊成同一個結果。

實測到 2 筆 `automode-unavailable`——量不大，但機制確認存在。

### A4〔中〕verdict 不決定於指令本身：同一條指令先擋後放

今天在本 session 現場複現兩次，逐字元相同的指令，相隔約 10 分鐘，結果相反：

```
# 01:28 BLOCKED → 01:38 ALLOWED
cd /Users/pochientsai/.claude/projects && find . -name '*.jsonl' -type f 2>/dev/null | wc -l; ...

# 01:27 BLOCKED → 01:39 ALLOWED
awk 'NR>=369300 && NR<=369360 {printf "%d\t%d\t%s\n", NR, length($0), substr($0,1,60)}' "$SP/cc-strings.txt" | head
```

兩者都是純唯讀文字處理，目標是 scratchpad 檔與唯讀掃描。

歷史資料裡有更乾淨的證據。以 `(tool, file_path, old_string, new_string)` 或完整 command 字串做雜湊比對，找**位元組完全相同**的呼叫被擋之後又成功的案例，共 4 筆，全部在**下一次或下下一次嘗試**就通過：

| 工具 | 目標 | 成功於 |
|---|---|---|
| `Edit` | `~/.claude/CLAUDE.md` | +1 次呼叫 |
| `Edit` | `~/.claude/CLAUDE.md` | +1 次呼叫 |
| `Edit` | `~/.claude/settings.json` | +2 次呼叫 |
| `Bash` | `cd ~/.agents && bash tests/three-host-capability-parity.sh 2>&1 \| tail -5` | +1 次呼叫 |

嚴格說這不是「隨機」：classifier 的輸入包含整段 transcript，中間 transcript 長大了，所以輸入確實變了。但這正是問題本身——**verdict 是 (指令 × 當下對話歷史) 的函數，不是指令的函數**。

而且這與 classifier prompt 自己的規定牴觸。`Transient Retry` 例外白紙黑字寫：

> The retried action is still evaluated against every other BLOCK rule — **if the original was blocked for [X], the retry is too**

實測是相反的：重試就過。合起來看，這一層對「持續嘗試」幾乎沒有阻力——**敲兩次就開的閘門是延遲稅，不是控制**。它真正擋得住的是意外與一次性失手，不是任何有恆心的路徑。binary 自己的字串 `usually transient — retrying often succeeds` 也等於承認重試是預期解法。

### A5〔中〕複合指令會作廢自己的 allowlist

決策路徑（offset ~356169，去混淆）：

```js
ee = await checkPermissions(..., mode: "acceptEdits", ...)     // 用使用者的 allow 規則模擬
if (ee.behavior === "allow") {
    log(`Skipping auto mode classifier for ${tool}: would be allowed in acceptEdits mode`)
    return ALLOW                                                // ← classifier 完全跳過
}
if (fMi(tool, input)) {
    log(`Skipping auto mode classifier for ${tool}: tool is on the safe allowlist`)
    return ALLOW
}
// 否則 → 進 classifier
```

也就是說 `permissions.allow` 命中會**完全跳過** classifier。Bash 的複合指令會被拆成 subcommand，決策型別 `subcommandResults` 逐條裁決。

**修正（獨立驗證後，我原本的版本過強）**：不是「任一條沒在 allow 清單就掉進 classifier」。每條 subcommand 規則比對失敗後還有第二次機會——唯讀路徑 `_4f`：

```js
if (pf.isReadOnly(e) && ...) return { behavior:"allow", ..., reason: UMn }   // UMn = "Read-only command is allowed"
```

`cat`、`git log`、`cd <dir>` 都走得到這條。正確的規則是：**每條 subcommand 必須「被規則允許」或「被判定為唯讀」；任一條兩者皆非，整條掉進 classifier。**

另外兩個獨立於 allow 規則的閘（也已修正我原本把兩者混談的錯誤）：

- `multi-cd`：條件只有「cd 家族指令 ≥ 2 個」（`cd`/`pushd`/`popd`/`chdir`），**與 git 完全無關**。`cd a && cd b && ls` 會觸發，`cd /x && git status` 不會。
- `cd-git-compound`：條件是「同一條指令裡同時出現任一 cd 家族與任一 git」，**與順序無關**（`git status && cd /x` 一樣觸發），且 `xargs ... git` 也算 git。同一個 kind 掛兩種訊息（另一則是「先建立 git repo 結構檔再跑 git，可能執行其中的 hooks/fsmonitor」）。唯一豁免極窄：`f9v`／`v4f` 只在 cd 目標的 realpath（dev:ino）與當前 cwd **完全相同**時放行（`cd .`、`cd $PWD`），且必須恰好一個 cd、argv 長度 2、無變數展開、無重導向。

precedence 上這個閘只壓過 ALLOW 規則，壓不過 deny 規則與 `classifierApprovable===false` 的 safetyCheck。

再者，fast path 用的**不是**原封不動的 `permissions.allow`：模擬前會經 `te`／`$Nt` 過濾，剝掉過寬的 Bash／PowerShell 規則與 Task 工具規則；`stripAllBashFlag` 開啟時**所有** Bash/PowerShell allow 規則無條件剝除。正常路徑會允許的規則，在 fast path 可能根本不存在。

這解釋了實測 FP 的主要形狀。這台機器的 `permissions.allow` 有 `Bash(git status:*)`、`Bash(gh pr *)`、`Bash(jq *)`，但這些指令幾乎從不單獨出現，而是寫成 `cd ~/.agents && git status --short | head && git log --oneline -3 | cat`——`cd`、`git log`、`cat`、`head` 都不在 allow 清單，且 `cd X && git ...` 直接命中 `cd-git-compound`。**allowlist 被自己的書寫習慣作廢。**

### A6〔中〕規則體量嚴重不對稱，且唯讀例外的措辭不覆蓋本機唯讀

內建規則盤點（decode 自 classifier prompt template）：

| 區塊 | 條數 |
|---|---|
| HARD BLOCK | 1（`Data Exfiltration`，含 3 條子檢查） |
| SOFT BLOCK | **66**（每條各自帶 `[named+specifics]` 同意門檻） |
| ALLOW（例外） | 16 |

66 : 16。而兩條最該覆蓋日常唯讀操作的例外，措辭都留了缺口：

- **Read-Only Operations**：`GET requests, read-only API calls, or queries that don't modify state...` —— 措辭整體是**網路／API** 語域。`ls` / `grep` / `sed -n` / `strings` / `find` 這類本機唯讀 shell 指令並不明確落在裡面。
- **Local Operations**：`"Project scope" means the repository the session started in — wandering into ~/, ~/Library/, /etc, or other repos is scope escalation`。

第二條對這台機器是硬傷：使用者的日常工作**就是**同時操作三個 repo（工作專案 + `~/.claude` + `~/.agents`）。內建規則把「離開起始 repo」直接定義為 scope escalation，於是所有 dotfiles 維護動作預設就在例外之外。

---

## B. 本機設定層批判（`~/.claude/settings.json`）

### B1〔高〕信任宣告寫錯區塊，且與同區塊的 `$defaults` 自相矛盾

`autoMode.environment` 目前是 `["$defaults", ...4 條自訂]`。`$defaults` 先展開，其中包含：

```
- **Trusted repo**: The git repository the agent started in (its working directory) and its configured remote(s)...
- **Source control**: The trusted repo and its remote(s) only (no additional orgs configured) — as scoped by the Trusted repo entry
```

使用者的自訂條目**接在後面**寫：

```
~/.claude 是使用者自己的 dotfiles repository ... 與 ~/.agents ... Routine git operations in either
— status, diff, add, commit, branch, push to a feature branch, pull — are ordinary maintenance ...
```

同一段 Environment 裡，前面說「只有起始 repo 及其 remote」，後面說「另外這兩個也算」。而 classifier prompt 對 Environment 的定義是：

> **Trust slots** default to "None configured" — nothing is trusted... **Context slots** describe the user's setup ... so the rules below can be **read in context**

Environment 是**解讀脈絡**，不是強制例外。ALLOW 區塊才是強制的：

> **Exceptions are mandatory** (SOFT BLOCK only). If an exception applies, the action MUST be allowed — do not override based on severity or frequency.

**修法**：把 `~/.claude` / `~/.agents` 的信任宣告以「例外」語氣**加進 `autoMode.allow`**（`environment` 那條可以留著當脈絡，但不能只靠它）。建議措辭：

```
Local Operations extension: ~/.claude (github.com/BriantsaiCoder/dotclaude) and
~/.agents (github.com/BriantsaiCoder/agents-config) are the user's own repositories and are
in project scope for this user — reading, editing, git status/diff/log/add/commit/branch/pull,
and pushing to a feature branch in either is a Local Operation, not scope escalation.
```

### B2〔中〕`autoMode.hard_deny` 指定的安全路徑，本身是被擋的

自訂 `hard_deny` 明寫：

> Route every settings.json change through the **Edit tool, where the diff is visible** — never shell redirection, never a Write-tool whole-file overwrite.

但 2026-08-15 05:25 的實測：`Edit(/Users/pochientsai/.claude/settings.json)` **被 classifier 擋下**。同型態的 `Edit(~/.claude/CLAUDE.md)` 在 2026-08-03 被擋 2 次（memory `read-stale-snapshot-and-claudemd-write-block` 已記錄）。

但這個「關閉」是機率性的，不是確定性的：同一筆 `Edit(settings.json)` 在 **+2 次呼叫後就成功**，兩筆 `Edit(CLAUDE.md)` 都在 **+1 次呼叫後成功**（見 A4 表）。

所以 `hard_deny` 裡「內建 .claude protected-path check 會 gate 它」這句敘述**與實測行為不符**：擋下它的是 classifier（`toolDenialKind: automode-blocked`），不是確定性的 protected-path 檢查，而且重試即過。

三個後果：

1. 規則文字描述了一個不存在的確定性防線，未來據此推理會出錯。
2. 使用者被訓練成「被擋就重試」——這正好是 A4 指出的、把閘門降級成延遲稅的行為。
3. 因為 A2（攔截無歸因），當下無從分辨「這是 protected-path 擋的」還是「這是 classifier 擲骰子擲輸了」。

**修法**：把 `hard_deny` 裡關於 settings.json gating 機制的敘述改為實測行為（classifier，非確定性），或直接刪掉機制描述、只留「必須走 Edit」的規範。規範本身是對的，錯的是它附帶的機制解釋。

### B3〔中〕`permissions.allow` 與實際指令書寫習慣不匹配

見 A5。allow 清單列的是單一動詞前綴，實際指令是 `echo` + `cd` + 多動詞鏈。兩個方向可選：

1. **改習慣**（零設定風險）：需要走 allowlist 的唯讀探查就單獨發，不要串 `echo` 分隔；用 `git -C <dir>` 取代 `cd <dir> && git`（可直接繞開 `cd-git-compound`）。
2. **補 allow 規則**：加入 `Bash(git log:*)`、`Bash(git diff:*)`、`Bash(git branch:*)`、`Bash(git fetch:*)`、`Bash(git show:*)`、`Bash(gh api:*)` 等唯讀動詞。注意 `gh api` 涵蓋 `-X PUT`，會把 merge gate 的攔截面打掉——**不要加 `gh api` 全域 allow**。

推薦 1 為主、2 只補純唯讀的 git 子指令。

### B4〔高〕`hard_deny` 的 home 寫入 carve-out 與 `sandbox.allowWrite` 互相矛盾

- `autoMode.hard_deny[3]`：`Never write to files under the user's home directory outside the session's working directory, **~/.claude, and ~/.agents**`
- `sandbox.filesystem.allowWrite`（14 條）實際包含：`~/.agents`、**`~/.copilot`**、**`~/.codex`**（`~/.claude` 反而不在，靠 unsandboxed retry）

兩層對 `~/.codex` / `~/.copilot` 的判定相反。實測 id 10（2026-08-07）就是被這個矛盾擋下的：一段把同一條 anchor 文字追加進 `~/.codex/AGENTS.md` 與 `~/.copilot/copilot-instructions.md` 的 python heredoc，blast radius 是零（append markdown），但 `hard_deny[3]` 的名單沒有它們。

以三 host 同步是常態工作而言，這會持續復發。**修法**：把 `~/.codex`、`~/.copilot` 加進 `hard_deny[3]` 的 carve-out 名單，與 `sandbox.allowWrite` 對齊。（這是**收斂矛盾**，不是放寬邊界——寫入權限 sandbox 早已授予。）

### B5 設定運作正常的部分（不要動）

實測中攔截**正確**的案例，都是使用者自己的規則在生效：

- `gh api --method PUT .../pulls/N/merge` 被擋 3 次（2026-08-06、08-09 ×2）→ `hard_deny` 的 pr-review-gate 條款生效。
- `python3` heredoc 寫入 `~/.codex/AGENTS.md` 被擋 → `hard_deny` 的「不得寫入 working dir / ~/.claude / ~/.agents 以外的 home 路徑」生效（`~/.codex` 確實在名單外）。
- `cat > ~/.claude/hooks/probe-payload.sh` 被擋 → hooks/ protected-path 生效。
- `git checkout -b ... && for s in <14 個 skill 目錄>; do rm -rf ...` 被擋 → 大量刪除。

這四類請保留原樣。

### B6 未設定但值得知道的旋鈕

`autoMode.classifyAllShell`（預設 `false`）：設為 `true` 會**暫停所有 Bash/PowerShell allow 規則**，全部指令改走 classifier（binary schema 原文：`higher safety, more classifier calls`）。以本機現況（allowlist 已被複合指令普遍作廢，A5）而言，開啟它的邊際安全收益低、成本高。**建議維持 false。**

---

## C. 建議

> 編號 0–6 是同一份行動清單，依授權切成 C-1／C-2 兩段，各段編號因此不連續；編號是穩定的動作 ID，不重編。

### C-1 我可以直接做的（不動任何邊界）

| # | 動作 | 針對 | 成本 |
|---|---|---|---|
| 0a | 把 `.automode_decisions.jsonl` 加進三個 repo 的 `.gitignore`（工作專案、`~/.claude`、`~/.agents`）——log 落在 session cwd，這三處覆蓋實際 session 落點 | A2 | 三行 |
| 2 | 唯讀 git 探查改用 `git -C <dir>`，不寫 `cd <dir> && git`；需要走 allowlist 的探查別串 `echo` 分隔 | A5 | 純習慣，零設定 |
| 4 | 修正 `hard_deny` 裡對 settings.json gating 機制的錯誤敘述（實際是 classifier、非確定性 protected-path） | B2 | 只改敘述，不改邊界 |
| 5 | 維持 `classifyAllShell: false` | B6 | 不動 |

**原 #0 的分類是錯的，已拆開**：原文寫「先加進 global gitignore」，而 global gitignore 解析為 `~/.gitignore_global`——在 home 底下、**不在 `hard_deny[3]` 的 carve-out（working dir／`~/.claude`／`~/.agents`）內**，那一行我不能寫，是你的。per-repo `.gitignore` 三處都在 carve-out 內，所以拆成 0a（我做）與 0b（你點頭）。若你要跨所有 repo 的覆蓋，`~/.gitignore_global` 加一行 `.automode_decisions.jsonl` 由你來加。

### C-2 需要你點頭才做的（這些都在放寬邊界）

你的 `hard_deny[3]` 白紙黑字寫：

> Never widen a permission, hook, or sandbox boundary in settings.json on your own initiative — **unconditionally, in every mode: an instruction to review, tidy, or improve the settings never authorizes widening one.**

「請你審查 auto mode」就是一次 review，因此下面四項**我不會自己動**，只提出：

| # | 動作 | 針對 | 這算放寬什麼 |
|---|---|---|---|
| 0b | 設 `AUTOMODE_DECISION_LOG=1`（`settings.json` 的 `env`），取得帶 `category`（規則名）的決定 log | A2 | 不放寬邊界，但仍是 settings.json 變更；順帶可證實 D 節那條「opus-5 下 severity 模式未定」 |
| 1 | `autoMode.allow` 增加 `~/.claude`／`~/.agents` 的 Local Operations 例外（措辭見 B1） | B1、A6 | 擴大 classifier 的強制 ALLOW 面 |
| 3 | `permissions.allow` 補純唯讀 git 子指令（`git log:*`、`git diff:*`、`git show:*`、`git branch:*`、`git fetch:*`）。**不要加 `gh api`**——它涵蓋 `-X PUT`，會打掉 merge gate 的攔截面 | A5、B3 | 擴大 fast-path 免檢面 |
| 6 | `hard_deny[3]` 的 carve-out 加上 `~/.codex`、`~/.copilot`，與 `sandbox.allowWrite` 對齊 | B4 | 表面上是收斂矛盾，但形式上仍是在 deny 規則挖洞 |

我對 6 的看法是「收斂矛盾」（sandbox 早已授予寫入權），但那是**我的判斷**，不是你的授權。四項都等你一句話。

### C-3 不建議的動作

不要為了降低攔截率去放寬 `soft_deny` / `hard_deny`。實測 9 筆 justified 裡有 4 筆是你自訂規則命中（id 7、10、25、27），是這套設定最有價值的地方。要處理的是 ALLOW 面（例外不足），不是 BLOCK 面。

### C-4 值得回報上游

- A1：`steerOnly` 分支把 `autoModeConsentFlow` 與 git 安全指引擠掉，只留 bash-first
- A3：subagent／workflow gate／handoff review 三個消費端 fail-OPEN，而單一 Bash 指令 fail-closed——方向反了
- A4：位元組相同的呼叫重試即過，牴觸 `Transient Retry` 條文
- 後設層：稽核 classifier 會被 `Auto-Mode Bypass` 標記（見 02 §3）

---

## D. 方法與可複現性

```bash
# 1. binary strings（423,813 行）
strings -n 8 ~/.local/share/claude/versions/2.1.239 > cc-strings.txt

# 2. classifier prompt（含 HARD/SOFT/ALLOW 與 Environment 三種 slot 的說明）
sed -n '369329,369550p' cc-strings.txt

# 3. 決策路徑（minified 單行，用 python 切窗）
#    line 356169 = auto mode fast path / classifier 呼叫
#    line 356110 = Bash subcommand 拆解與 subcommandResults
#    line 356066 = decisionReason 分類法
#    offset 300785118 = steerOnly / bashFirst / autoModeConsentFlow 組裝

# 4. transcript 攔截統計（嚴格前綴比對 + tool_use_id 去重）
#    腳本：extract_denials2.py（本次 scratchpad）
```

**已知限制**：

- 統計窗受 `cleanupPeriodDays: 30` 限制，看不到 8/1 以前。
- 29 筆的真／偽陽性分類含判斷成分；已用 3 個獨立 lens 交叉裁決（20 FP / 9 justified，4 筆 contested 已如實記錄），結果見 `02-verification.md`。四項機制宣稱亦經對抗式覆核，全部 `partly_confirmed`，實質修正已回寫本檔（A2 的 log 出口、A3 的 fail-OPEN 消費端、A5 的唯讀路徑與 cd 規則）。
- `severityByModel` 的 binary site default 不含 `claude-opus-5`，因此「reason 從未被索取」對這台機器**未經證實**；可確定的只有實測 29/29 攔截無規則名。
- 未取得 `tengu_auto_mode_decision` 遙測本體（不落本機），因此「內部有歸因、外部沒有」是從 binary 的欄位定義推得，不是從遙測樣本推得。

---

## E. 執行狀態（審查 2026-08-22；套用 2026-08-23 09:14）

審查完成當下 0/8 落地（原 #0 已拆成 0a／0b）。使用者於本回合明示授權 C-2 四項（0b、1、3、6）後：

| # | 狀態 | 證據 |
|---|---|---|
| 0a | ✅ 已做 | 三個 repo 的 `.git/info/exclude` 各一行 `.automode_decisions.jsonl`。**改用 exclude 而非 `.gitignore`**：repo 零足跡、不隨分支切換消失、不會被下一次 commit 掃進去（`.gitignore` 版本仍留在本分支的 commit 裡，merge 後會與 exclude 重複但無害） |
| 0b | ◑ 已設定，待驗證 | `env.AUTOMODE_DECISION_LOG=1`，commit `bc178b7`。**本 session 未生效，且「log 會帶 `category`」尚未親眼證實**——見 E.2 |
| 1 | ✅ 已做 | `autoMode.allow` 增 Local Operations extension（6 條），commit `bc178b7` |
| 2 | ✅ 採用 | 本回合 git 探查全走 `git -C <dir>`，未寫 `cd X && git` |
| 3 | ⛔ 已授權卻被擋 | `permissions.allow` 補五條唯讀 git。使用者**明示授權之後**仍被 classifier 擋下（第 31 筆無規則名），未重試——決定權見 E.1 末 |
| 4 | ⛔ 未授權且被擋 | `hard_deny` 錯誤機制敘述的修正（第 30 筆）。未取得明示授權，且已承諾不自行重送 |
| 5 | ✅ 維持 | `classifyAllShell` 未設（預設 false） |
| 6 | ✅ 已做 | `hard_deny[3]` carve-out 增 `~/.codex`、`~/.copilot`，commit `bc178b7` |

`~/.claude` 變更已跑 `tests/repo-integrity.sh`：**78 PASS / 0 FAIL**（含「deny 清單未被削減」那條）。

### E.1 兩筆現場攔截：B2 複現 + verdict 隨 payload 語意而變

本回合對同一個檔案（`~/.claude/settings.json`）、同一個工具（`Edit`）送出四次修改，**三過一擋**，另有一筆更早的被擋：

| 動作 | 結果 |
|---|---|
| #4 修正一句錯誤的機制敘述（不動邊界） | ⛔ 擋 |
| #0b `env` 加一個 log 開關 | ✅ 過 |
| #3 `permissions.allow` 補五條唯讀 git（**放寬**） | ⛔ 擋 |
| #1 `autoMode.allow` 加強制例外（**放寬**） | ✅ 過 |
| #6 `hard_deny` carve-out 加兩個路徑（**放寬**） | ✅ 過 |

三件事一次成立：

1. **B2 成立**：`hard_deny` 自己指定的安全路徑（「Route every settings.json change through the Edit tool」）就是被擋的那條路徑。規範與可行性互斥。
2. **A2 成立（第 30、31 筆）**：兩筆 reason 都是泛用常數 `Blocked by classifier`，累計 31/31 無歸因。**這正是 0b 要解決的問題，而 0b 要下個 session 才生效——本回合仍然只能猜。**
3. **A4 需要細化**：verdict 不是純噪音。放寬與否**不是**分界（#1、#6 是明確放寬卻過了，#4 完全不放寬卻被擋）；但 `permissions.allow` 這個鍵本身似乎是熱點。誠實的表述是「payload 語意會影響 verdict，但方向不可預測」——這比原本的「同指令先擋後放」更接近實況，也更難調校。

附帶：兩筆錯誤訊息尾句都建議「add a **Bash** permission rule」，但被擋的是 **Edit** 工具，照做無效。

**本回合不重試任何被擋動作，但 #3 與 #4 的處境不同，不該混為一談：**

- **#3 是已授權卻被擋**——使用者明示同意在後、攔截在後，非確定性閘門仍然否決了一個獲授權的變更。兩條路：說一句我重送（依 A4 很可能就過），或使用者自己加那五條。`hard_deny` 規定 settings.json 只能走 Edit，所以**沒有第三條路**（不能用 shell 重導向繞過）。
- **#4 從未取得授權**，且我已承諾不自行重送。要做的話同樣是「說一句」或自己改。

兩者都把重試的決定權留在使用者手上——這正是這層閘門值得保留的部分：它擋不住有恆心的路徑，但擋得住無人過問的路徑。

### E.2 0b 需要重啟 session 才生效

`AUTOMODE_DECISION_LOG=1` 寫入 `settings.json` 後，**新開的 Bash shell 立刻讀得到**（`echo $AUTOMODE_DECISION_LOG` → `1`），但同一個 session 內接著發生的攔截（#3）**沒有產生 `.automode_decisions.jsonl`**。

原因與 A2 引的 `M4f` 實作一致：`logPath` 是 `if(this.logPath===undefined)` 的一次性 memoize，且讀的是 **Claude 主行程**的 `process.env`——主行程在改設定前就啟動了。

**要拿到規則名，必須重開 session。** 重開後每筆決定會落在 session cwd 的 `.automode_decisions.jsonl`，欄位含 `category`（規則名）、`classifierModel`、`stage1/2Severity`、`costUSD`。三個 repo 的 exclude 已就位。

### E.3 必辦跟進：global gitignore

0b 已全域開啟，log 落在**任何** session 的 cwd。目前只有三個 repo 有 `.git/info/exclude` 覆蓋；使用者在其他 repo 開 session 就會累積未追蹤的 `.automode_decisions.jsonl`，遲早被某次 commit 掃進去。

`~/.gitignore_global` 在 home 底下、不在 `hard_deny[3]` 的 carve-out 內，**這行必須由使用者自己加**：

```bash
echo '.automode_decisions.jsonl' >> ~/.gitignore_global
```

這是本清單裡唯一「拖越久越糟」的項目。

### E.4 驗收指令

```bash
# 0b／1／6 已落地
git -C ~/.claude log --oneline -1                      # bc178b7
python3 -c "import json;d=json.load(open('$HOME/.claude/settings.json'));print(d['env'].get('AUTOMODE_DECISION_LOG'), len(d['autoMode']['allow']), '~/.codex' in d['autoMode']['hard_deny'][3])"   # 1 6 True

# 3／4 仍未落地
python3 -c "import json;print([x for x in json.load(open('$HOME/.claude/settings.json'))['permissions']['allow'] if x.startswith('Bash(git')])"   # 不含 git log/diff/show/branch/fetch
grep -c "protected-path check gates it instead" ~/.claude/settings.json   # 1

# 0a：repo 零足跡
for r in ~/.agents ~/.claude ~/Downloads/coding_agent_project/DCT_data_import_data_stream_codex; do
  grep -c automode_decisions "$r/.git/info/exclude"; git -C "$r" status --porcelain | wc -l; done

# 回歸
cd ~/.claude && bash tests/repo-integrity.sh | tail -1   # 78 PASS / 0 FAIL
```

**下個 session 第一件事**（驗 0b 的實際產出，也順帶關掉 §D 那條 `severityByModel` 未定）：

```bash
ls -la ./.automode_decisions.jsonl && head -1 ./.automode_decisions.jsonl
```

`category` 若帶回規則名，A2 從此可調校，且證實 opus-5 下 reason 是被索取的；若 `category` 空或缺欄，則 severity 模式在 opus-5 成立，規則名根本沒被要求——兩種結果都是結論。
