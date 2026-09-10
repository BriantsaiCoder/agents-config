# Host adapters

需將 workflow action、user-only command、提問、delegation、handoff 或 hook 對應到 active host 時載入。

Host adapter 對本 kernel 只可加嚴，MUST NOT 放鬆其 MUST 或無條件約束；放鬆需 user 當下明示。Matt skill body 的 `/skill-name` 只表示 skill routing；需要顯式 invocation 時，實際 command 前綴與啟動權限以本 reference 對應 host adapter 為準。

載入時先讀本檔共用條款與 active host section；一般 single-host work 可停在該 section。只有 cross-host audit／parity 才讀 full document。

## Capability parity

三家等價以 capability 與各自 semantic anchors 判定，不要求 prose、檔案結構或 hash 相同。`^` 分隔同一 capability 必備的 clauses；此表是三家 parity 的 canonical mapping（測試的失敗訊息用的就是這個詞）。

本表有**兩個** consumer，比對語意不同，改動時兩邊都要顧：

- `tests/three-host-capability-parity.sh` — 表內每一列，`grep -Fq` **子字串**比對。
- `tests/ponytail-host-parity.sh` — 只讀 CAP-PONYTAIL 那列，把 host 檔依 `[；。]` 切段後逐段**全等**比對。它嚴格得多：mapping 的 anchor 必須是某一整段，而不是某段的一部分。它的 selftest fixture 另有一份 CAP-PONYTAIL 的手抄本，改本表時會一起紅（2026-08-27 實測）。
- meaning 欄（第 2 欄）不參與任何語意斷言：前者只比對三個 host 欄，後者只檢查它非空。gate 全綠不代表三家語意相同，語意是否一致只能靠人讀。

anchor 與 host 實際措辭對不上時，改哪一邊的判準：**語意分歧改 host，措辭／標點差異改本表。** 前者是三家該一致的東西真的不一致——2026-08-27 曾出現 Codex 寫 `action-first` 而 Claude、Copilot 與本表 meaning 欄都是 `outcome-first`，該次改的是 `~/.codex/AGENTS.md`；後者是同一語意的各家寫法，例如 Codex 那一行整行用半形 `/`，本表 Codex 欄就跟著半形。兩個 matcher 都分不出這兩者，判準只能靠人。

**Accepted divergence（CAP-PONYTAIL）**：三家對 ponytail 的適用範圍是使用者明示接受的語意分歧（#120、#121），不是待修的 drift；各 host 的實際範圍以下表 CAP-PONYTAIL 列的三個 anchor 欄為準，meaning 欄只寫「適用範圍 host-local」。

<!-- capability-parity:start -->
```tsv
CAP-WORKFLOW	Shared workflow 是唯一方法來源	dev-workflow/SKILL.md^host-local prose 不複製 method	dev-workflow/SKILL.md^程序只由該 skill 維護	dev-workflow/SKILL.md^workflow 方法與 gates 唯一來源
CAP-LOCAL-AUTONOMY	安全、local、reversible 工作 MUST 一次執行至完成（[INT-8]）	local、reversible^MUST 一次執行至完成	local、reversible^MUST 一次執行至完成^可直接實作	local、reversible^MUST 一次執行至完成^可直接實作
CAP-DELEGATION	Delegation 由 AI 自主判定且無須先問	[INT-4]^AI 自主判定^無須另問	[INT-4]^AI 自主判定^無須另問	[INT-4]^AI 自主判定^無須另問
CAP-RESPONSE	Outcome-first 且決策列出 recommendation 與 trade-off	回覆 SHOULD outcome-first^編號選項／推薦／取捨	回覆 SHOULD outcome-first^編號選項/推薦/取捨	回覆 SHOULD outcome-first^編號選項／推薦／取捨
CAP-PONYTAIL	Plan／implement 套用 Ponytail 慣例，適用範圍 host-local（見表上方 Accepted divergence）	ponytail 等風格注入=通用慣例	[T0-10] dev MUST 採 reuse／YAGNI／最小完整實作	[T0-10] 開發套用 ponytail=慣例，但只採 reuse／YAGNI 原則
```
<!-- capability-parity:end -->

Tier0 安全內容由 `tests/tier0-parity.sh` 驗；model、effort、permission 與 hook 是 host-local capability，不以跨 host 相同值判定；control-plane materialization 仍由 ownership tests 驗。

## Ponytail approved payloads

CAP-PONYTAIL 的 Accepted divergence 也適用於 skill body。`tests/ponytail-host-parity.sh` 依各 host 下列 pin 驗完整 `skills/ponytail/SKILL.md`；每家必須恰有一列、SHA256 為 64 位小寫十六進位，缺失或不符即拒絕。此檢查保留 enabled、full mode、runtime 選版與 capability anchors；檔案與 inventory 證據不等於 model loader canary。

2026-09-10 核准來源：Claude／Copilot 為已核准的 Ponytail 4.9.0 修改內容；Codex 保留已 review 的 KEEP 內容，來源為 [dotcodex #33](https://github.com/BriantsaiCoder/dotcodex/pull/33) 的 `maintenance/skill-optimization/plugins.json` 對應 target 的 `after_sha256`。更新 payload 須先獨立 review，再更新該 host pin，不可為讓 checker 通過而從未核准的 live 檔自動重算。

```tsv
PONYTAIL-SHA256	Claude	42167fda5759eb53e2f2f04983785f9a8269ebe438f1a055c296b3667f435eaf
PONYTAIL-SHA256	Codex	da1324215bea1bbf674f91fd3fb62e35df4bc8128709ec1097593513a52dcd85
PONYTAIL-SHA256	Copilot	42167fda5759eb53e2f2f04983785f9a8269ebe438f1a055c296b3667f435eaf
```

## S5 simplification apply outcome

Standards／Spec reviewer 保持 read-only；findings disposition 完成後由 active host 的 implementation owner 做一次 apply pass，只處理已核准 scope 與 `reviewer-template.md` 五條 over-engineering baseline。結果 MUST 記為 `changed` 或 `no-op`；`changed` 回 S4 並把 affected diff 重新納入 S5，避免 simplify output 繞過 [S5-1]；`no-op` 留明確 evidence。

## Claude

- plan = EnterPlanMode；todo = TodoWrite；子代理 = Task／Agent；決策提問 = AskUserQuestion；前端視覺 review agent = `uiux-reviewer`（Claude-only）。
- Claude main role = `~/.claude/settings.json` 的 configured `model` 與 `effortLevel`, including plan mode。Claude main owns investigation／root causes／architecture／design／decisions、final evidence verification、independent read-only S5 review coordination、final user response 與 overall result；Claude main MAY implement 已授權 scope end-to-end。
- Claude conditional implementation routing：Claude main MUST 自主判定 direct work 或 implementer delegation，不需為 model routing 另問使用者。small 或 tightly dependent task，Claude main SHOULD 直接完成，除非下列 delegation benefit 成立；packet 已完整規範（委派訊息已滿足 delegation.md 的訊息契約）、驗收可機械判定、且預期不需回頭問設計時 MAY delegate；工作可獨立平行且 delegation 預期能實質改善品質或 wall-clock time 時 SHOULD delegate。Model difference 本身 MUST NOT 觸發 delegation；需要 delegation 時交給 configured `implementer` agent（`claude-opus-5`；定義在 `~/.claude/agents/implementer.md`）。相依 scope 依序執行，same-work recursion is forbidden。
- 實作分工通報：Claude main MUST 在開始該任務的已授權實作前，用一句簡短進度訊息告知實作者（Claude main 直接實作或 configured `implementer`）、負責範圍與選擇原因；實作者或委派範圍變更時 MUST 更新通報。通報不新增使用者確認 gate；僅啟動 read-only reviewer 不視為更換實作者。
- routine implementation／test failures 由 current implementation owner diagnose、fix、retest within owned scope；delegated implementer 遇到 invalid design premise 時，stop dependent writes，return evidence to Claude main for decision 與 needed authorization。
- Claude main may run checks and inspect evidence；implementer report is not completion evidence，Claude main MUST reverify source state 與結果。implementer unavailable 時，Claude main MAY 接手，但只限既有授權、runtime permission 與 tool capability；MUST NOT bypass denied tools、sandbox、[T0-8] 或 independent read-only S5 review 要求。
- 建立新子代理時 MUST 預設不繼承父對話（不用 `subagent_type: "fork"`）；fork 會帶入完整父對話並強制沿用 main 的 model（`model` override 被忽略），因此 MUST NOT 用 fork 取代委派給 configured `implementer`，只有完整父對話不可省略時才用 fork。
- 同一 scope 的修正與重測，host 有 `SendMessage` 時 MUST 優先依回傳的 agent id 續用原 implementer；只有在原代理不可用、host 無 `SendMessage`（開工前以工具清單為準）或工作是新的獨立任務這三種情形之一時，才建立新代理。為同一 scope 建立新代理時 packet 內容與背景摘要依 [delegation contract](delegation.md)，且 MUST 標註前一輪的 changed files 與失敗項；已交付且未變更的部分 MUST NOT 逐字重貼。
- 同一 ready frontier 上彼此獨立的 1–4 個 blocker MUST 合併在同一次 `AskUserQuestion`；dependent 題等前一批回答。Skip／dismiss MUST NOT 視為答案、核准或採用預設值。
- user-only skill command = `/<skill-name>`。
- 用專屬 review agent 不豁免 `references/reviewer-template.md`：豁免的是 prompt 區塊本身與「怎麼用」中以該區塊為前提的步驟，其餘各節對 Claude 一樣有約束力，MUST 在維護 `code-review` 的 baseline 或判 S5 EXIT 時讀。不在此列舉是哪幾節——列舉會漏，新增的節就掉在外面。這條與 `simplify` 綁定都不因專屬 agent 而豁免。
- 兩軸 findings 處理完後 MUST 跑 `simplify`（Claude-only）當 apply pass；`changed`／`no-op` 與重驗依共用 S5 simplification outcome。
- S5 simplification mechanism = Claude main decides disposition; active implementation owner applies authorized edits, then S4/S5 reverify。
- `ledgers.md` Preflight 要求的兩軸狀態行與 row 6 三欄／baseline 標題，在 Claude 側由 `~/.claude/hooks/guard-s5-ledger.sh`（PreToolUse，攔 `gh pr create`）機械檢查——缺項在開 PR 當下就被擋，不是事後才發現。兩軸皆 `SKIPPED` 走豁免路徑（沒跑審查就沒有記錄可填）。已知不修的破口：inline `--body` 時 `--title`／`--label` 的值也算進 body、`gh pr edit` 不在射程內；細節與理由寫在該檔註解。

## Codex

- plan = Plan Mode（僅 host／user 可切換）；todo = update_plan；子代理 = spawn_agent／wait_agent。工具未提供時以文字列 session plan／進度；不得模擬工具呼叫或略過 protected gate 核准。
- Codex main role = `gpt-6-astra`，reasoning effort 依 `~/.codex/config.toml` 的 `model_reasoning_effort`，Plan Mode 依 `plan_mode_reasoning_effort`。Astra owns investigation／root causes／architecture／design／decisions、final evidence verification、independent read-only S5 review coordination、final user response 與 overall result；Astra MAY implement 已授權 scope end-to-end。
- Codex conditional implementation routing：Astra MUST 自主判定 direct work 或 implementer delegation，不需為 model routing 另問使用者。small 或 tightly dependent task，Astra SHOULD 直接完成，除非下列 delegation benefit 成立；工作可獨立平行且 delegation 預期能實質改善品質或 wall-clock time 時 SHOULD delegate；bounded scope 的 large/noisy context 明確受益於 isolation 時 MAY delegate。Model difference 本身 MUST NOT 觸發 delegation；需要 delegation 時可交給 configured `implementer`（`gpt-5.6-sol`；定義在 `~/.codex/agents/implementer.toml`）。相依 scope 依序執行，same-work recursion is forbidden。
- 實作分工通報：Astra MUST 在開始該任務的已授權實作前，用一句簡短進度訊息告知實作者（Astra 直接實作或 Sol implementer）、負責範圍與選擇原因；實作者或委派範圍變更時 MUST 更新通報。通報不新增使用者確認 gate；僅啟動 read-only reviewer 不視為更換實作者。
- routine implementation／test failures 由 current implementation owner diagnose、fix、retest within owned scope；delegated implementer 遇到 invalid design premise 時，stop dependent writes，return evidence to Astra for decision 與 needed authorization。
- Astra may run checks and inspect evidence；implementer report is not completion evidence，Astra MUST reverify source state 與結果。implementer unavailable 時，Astra MAY 接手，但只限既有授權、runtime permission 與 tool capability；MUST NOT bypass denied tools、sandbox、[T0-8] 或 independent read-only S5 review 要求。
- 建立新子代理時，MUST 預設使用 `fork_turns="none"`；委派訊息內容與背景摘要依 [delegation contract](delegation.md)；摘要不足時才繼承必要的近期 turns，只有完整父對話不可省略時才使用 `fork_turns="all"`。
- 同一任務的修正與重測 MUST 優先用 follow-up 續用原代理；只有原代理不可用或工作是新的獨立任務時才建立新代理。
- user-only skill command = `$<skill-name>`。
- Codex native Local/Worktree Handoff 只移動同一 chat 與 code，MUST NOT 觸發 Matt `$handoff`；跨 session／agent 文件仍走 `$handoff`。
- `implement` 先用 `~/.agents/bin/agents-branch` 或 repo worktree 建 isolated branch；S6 用 PR heartbeat。
- S5 simplification mechanism = Astra decides disposition; active implementation owner applies authorized edits, then S4/S5 reverify。
- Git guard 由 `~/.codex/hooks.json` 與 `~/.codex/rules/default.rules` 疊加，不能取代 tier0／CI。

## Copilot

- plan = `--mode plan`；todo = update_todo；子代理 = `task` 工具。
- user-only skill command = `/<skill-name>`。
- 命中 [T0-8] protected gate 時，非 plan mode 必須先提出計畫並取得核准。
- S5 simplification mechanism = main-context explicit apply pass。
- Copilot user-level Git guard MUST 位於 `~/.copilot/hooks/guard-git-push.{json,sh}`。
- 子代理沿用模型預設 effort；僅 hard debugging、security、migration 或高風險 review 升 `high`，`xhigh`／`max` 需量測證明收益。
