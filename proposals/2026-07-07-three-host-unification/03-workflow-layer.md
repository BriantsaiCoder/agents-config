<!-- status: PROPOSAL 附件 | source: workflow 層判決優勝案（31/40，唯一通過「拔掉全部 Claude 專屬件仍能跑」測試）+ 10 項嫁接（已織入本文）| readers: AI models -->
# 03 Canonical Workflow：dev-workflow 單一 skill + 薄路由

> 適用：全 host｜載入：無（PROPOSAL，未生效）
>
> 設計原則：骨架 = 三家 100% 可執行的最大公約數（needs → plan⏸ → implement(TDD) → verify → review → closeout）。任何標「enhancement」的東西缺席時 workflow 仍完整成立。**skill 是三家唯一同構執行載體**——workflow 正本放 skill，注入檔只剩薄路由。

## 封裝

```
~/.agents/skills/
├── dev-workflow/                 # canonical 正本（唯一權威）
│   ├── SKILL.md                  # S0–S6 + BUGFIX 鏈 + 四態 gate 制度（正文 ≤400 行；檔首 = X1 產物路徑表）
│   └── references/
│       ├── ledgers.md            # Preflight 8 rows / Closeout / Postflight 定義 + 範例（收割 Codex override 的 Closeout Ledger 原文）
│       ├── review-triage.md      # bot-review triage 合併規格（異步等待 + thread-aware + 子集教訓）
│       └── reviewer-template.md  # S5 泛用 reviewer prompt（無專屬 agent 的 host 直接餵這份）
└── sdd/                          # 自 ~/.claude/commands/sdd.md 改寫為共用 SKILL.md（LIGHT tier 產物規格）
```

- SKILL.md 三家同構格式；**routing 不靠 description（Codex 截斷 2–6 字元），靠注入檔逐名點名**；skill 名短且穩定。
- **X0 機械判定契約**：每個 gate 寫成「進入 / 動作 / 退出 / 失敗出口」四段式；ENTER/EXIT 條件只允許三種形態——**檔案存在性、用戶關鍵字、指令 exit code**。禁止只有人類能意會的散文條件。
- **X1 產物路徑表**：dev-workflow 檔首單一表列全部產物路徑（`CONTEXT.md` / `docs/adr/` / `docs/superpowers/{specs,plans}/` / `sdd/<slug>/` / `docs/codebase/` / `tasks/lessons.md`），各階段引用表不重複路徑字串。

## 薄路由（三家注入層的唯一 workflow 內容）

`core/routing.md`（≤30 行 cap，超標 `--check` 報錯）內容：
1. 「任何開發任務先讀 `~/.agents/skills/dev-workflow/SKILL.md` 並照其 S0 路由；bug 走其 BUGFIX 鏈；輕量走 skill `sdd`。」
2. 逐 skill 點名清單（dev-workflow / sdd / deps-check / mp-grill-with-docs / mp-diagnose / bug-fix-settlement / frontend-release-verification / backend-release-verification / dependency-security-scan / design-doc-mermaid）——Codex 端另附逐名點名附錄（description 截斷故必須點名）。
3. **3 條最高風險攔截規則常駐 stamp**（防「新鮮 skill prose 搶贏路由」，特別是 superpowers 終態鏈）：
   - 收尾類 skill（如 finishing-a-development-branch）只能在 S4/S5 全綠**後**才 invoke。
   - fix 之前必先有 failing regression test（紅→綠），無 seam 須明確標記例外。
   - S2 ⏸ plan gate 在任何 auto/autopilot 模式下**不豁免**。

以 fenced markers `<!-- agents-routing:begin/end -->` stamp 進三家注入檔；stamp 由 agents-sync 管線執行（整合裁決見 README——終局併入生成檔，過渡期 stamp 現行 live 檔）。

## Canonical 骨架（S0–S6）

全鏈制度：所有 gate 用**四態標記** PASS / FAIL / UNAVAILABLE（須附 probe 證據）/ SKIPPED（須附理由）；無證據不得宣稱完成；ledger 之後出現新 commit → 前次 closeout 失效，重跑 S4–S6；每階段完成回報三欄一行 `目前階段 / 下一步 / 是否可驗證`。

### S0 ROUTE 進場判定（決策表由上而下第一命中即走）
1. 無 manifest 或原始碼 < 5 檔 → NEW-PROJECT 路（骨架手動落地 + baseline commit，不走 plan 工具鏈）
2. 描述含錯誤行為 / 測試失敗 / regression → BUGFIX 鏈
3. 接手且無 `docs/codebase/` → 先提議 `acquire-codebase-knowledge` 再回 S0
4. 預估單檔 / ≤1 天 → LIGHT tier（產物走 `sdd/<slug>/`）
5. 其他 → HEAVY tier（產物走 `docs/superpowers/plans/`）
6. tier 判不準 → 停下問用戶，不自選

### S1 NEEDS
- HEAVY = `mp-grill-with-docs` → `CONTEXT.md` + `docs/adr/`（lazily）；LIGHT = 3 問模板 → `sdd/<slug>/proposal.md`（為什麼做 / 要改什麼 / 影響範圍 三節非空）。
- 退出（機械）：產物檔存在且必填節非空。關鍵模糊未決 → 停下發問，禁止靜默推進。

### S2 PLAN ⏸（硬人工 gate）
- host 中立指令：「進 plan 模式或取得用戶明確確認前不得改檔」（名稱映射見 adapter）。
- 產 `sdd/<slug>/tasks.md`：每條 `- [ ]`、≤1h、驗收條件用情境句、每條內嵌測試名（紅→綠）；>10 條 → 升 HEAVY 產 plans doc。**LIGHT/trivial 也不得以口頭確認代替——最小 3 行 tasks.md 仍必產**（消滅無檔案軌跡的例外路徑）。
- **HEAVY tier 雙硬 gate**：brainstorming 產出的 design spec（`docs/superpowers/specs/`）須先經用戶簽核 ⏸，再進 plan ⏸——LIGHT 只有 S2 一個硬 gate。
- 退出（機械）：tasks.md（或 plans doc）存在 + 用戶明確說開始實作；**⏸ 的 EXIT 證據 = 引用用戶確認原句**，不得以「合理推定同意」代替。
- executor enhancement：`superpowers:writing-plans`（三家皆裝 6.1.1）；不可用照 inline 規格手寫。

### S3 IMPLEMENT（TDD 內嵌）
- 先開分支（feat/ / fix/）；每 task 紅→綠，紅燈輸出即證據；動高扇入共用檔前必跑 `deps-check`；stack `*-best-practices` skill 必套。
- **subagent 回報 ≠ 完成證據，主 context 須親自驗**（收自 Codex，升 canonical）。
- 退出（機械）：tasks.md checkbox 全勾 + 全套測試指令 exit 0。
- 失敗出口：同一 bug 連 3 次修復失敗 → 停手，與用戶確認後交接 `mp-improve-codebase-architecture`；flaky / 效能找不到根因 → `mp-diagnose`。

### S4 VERIFY
(a) build/test/lint 全跑；(b) **Self-simplification 4 項檢核**（無 unrequested abstraction / 無新依賴 / 無單一使用點抽象層 / 無 speculative config）——取代 code-simplifier agent 成 canonical 標準；(c) 前端 UI 變更附 Playwright 證據（headed 優先，缺 GUI 明確回報 fallback headless）；(d) 會部署 → 對應 `*-release-verification` + `dependency-security-scan`（正交必跑非三選一）；(e) 中高風險附 baseline capture。
- 退出（機械）：verify 區塊每 gate 標四態 + 證據（指令 + exit code / 輸出摘錄）。FAIL → 回 S3。

### S5 REVIEW
- 必記錄 reviewer 型別 + 結論；UNAVAILABLE 只能在 probe 失敗證據後標記，**不得默默降級成自審**；回饋逐條技術評估（採納或有據 pushback），不表演式同意。
- 退出（機械）：0 條未處理 actionable findings。findings 是 bug → 回 S3 且先寫紅測。

### S6 CLOSEOUT
1. Preflight Ledger 8 rows（Scope / Git state / Diff self-review / Self-simplification / Tests evidence / Review gate / Security-release gates / Residual risks）寫進 PR body；缺 row 或缺證據不得 push/開 PR。
2. zh-TW Conventional Commit、squash merge 預設、合併後刪分支。
3. Bot-review triage（合併兩家拼圖）：等 Copilot review 異步 2–3 分鐘勿誤判無；thread-aware 逐條讀、正確 actionable 自動修、已修 thread resolve、錯誤/YAGNI 附 technical reason 不盲修；**bot findings = 子集**——改共用函式反模式時另跑 `deps-check`/grep 枚舉全 caller（PR #34/#36 教訓）。
4. BUGFIX 鏈必跑 `bug-fix-settlement`（即使結論是不沉澱也要輸出評估摘要）。
5. 動到架構 → 同步 `docs/codebase/ARCHITECTURE.md` mermaid（HTML 一律 opt-in）。
- **時機攔截**：S4/S5 全綠前不得進 S6；`finishing-a-development-branch` 只能在此時 invoke（Claude enhancement）。

### BUGFIX 鏈（同骨架映射）
S1 = reproduce + root cause（鐵則 inline：**failing regression test 先於 fix**；無 seam 允許「記錄架構問題」例外但須明確標記，且 fix 落地後交接 `mp-improve-codebase-architecture`）→ S2 輕量（root cause + 修法攤開等確認，仍產最小 tasks.md）→ S3 紅測→fix→綠 → S4 → S5 → S6（含 settlement）。escalation：重現率 <50% / flaky / 效能 → `mp-diagnose`。

## 現行環節的降級 / 砍除判定

- **降為 Claude enhancement**：subagent-driven 兩段審查、EnterPlanMode/Workflow 編排、code-simplifier agent（S4 檢核表取代）、uiux-reviewer（硬依賴 claude-in-chrome 不可平移；canonical 前端驗證 = Playwright 證據）、/sdd 與 /mp-zoom-out slash 進入點（skill 本體共用，slash 只是 Claude 快捷）。
- **降為 Codex enhancement**：multi_agent spawn 編排、codex-security:* 掃描、heartbeat PR 監控。
- **降到 repo 層**：全部機械守護 → git pre-commit + CI；host hooks 只當第二道加速層。
- **砍除**：Codex architecture-html-doc 的 HTML-default 路線；Copilot 9 個 dangling 引用與假繼承宣稱；grill 作為所有功能的強制第一站（改 HEAVY 才必經）；brainstorming spec 簽核作為**通用**硬 gate（收斂為 HEAVY 專屬雙 gate）。
- **反向統一（Codex 版較優，升 canonical）**：三欄階段回報、tasks.md 細則、commit gate（先 inspect status/diff 只 stage 相關檔）、四態 gate 證據制度、subagent 回報≠證據。

## Host adapters（只放能力差異與名稱映射，不重複 canonical）

### Claude（CLAUDE.md adapter 段，或 `~/.claude/rules/dev-workflow-adapter.md` 原生自動載入）
- 映射：plan=EnterPlanMode；todo=TodoWrite；子代理=Task/Agent。
- enhancement：S2 前 `superpowers:brainstorming`（HEAVY）；S3 `executing-plans`/`subagent-driven-development`；S4 `code-simplifier` agent 可代跑檢核（前置：repo CLAUDE.md 掛 stack rules，否則跳過並回報）；S5 `requesting-code-review` 或 stack 專精 agent 擇一；S6 `finishing-a-development-branch`（僅 S4/S5 全綠後）；前端 `uiux-reviewer`（Claude-only；另兩家該步標 UNAVAILABLE + 理由即合規）。

### Codex（注入檔 adapter 段）
- 映射：plan=Plan Mode（`<proposed_plan>` 收斂）；todo=update_plan；子代理=spawn_agent/wait_agent。
- enhancement：S3/S5 multi_agent spawn（file ownership 不重疊；UNAVAILABLE 須 smoke spawn 失敗證據）；S4 codex-security 疊加；S6 heartbeat PR 監控。
- 守護：hooks.json 補三支 guard（前置 PreToolUse 實測）；architecture-html-doc 退役為 mermaid→HTML 衍生器。

### Copilot（copilot-instructions.md adapter 段）
- 映射：plan=--mode plan（requestExitPlanMode）；todo=update_todo；子代理=task 工具 / --agent。
- **S2 強制令**：非 plan 模式啟動時，改檔前必先輸出計畫並取得用戶明確確認（補償 autopilot alias 風險；alias 本身建議移除）。
- S5：內建 code-review agent 或 feature-dev:code-reviewer + reviewer-template.md；.NET 深審降級已知（實測不足再轉寫 .agent.md，延後決策避免預養第三格式）。
- 守護：**無全域 hooks，明文寫死**——機械守護一律依賴 repo 層 `.github/hooks/` + pre-commit + CI（init-project-docs 模板落地）。
- MCP：chrome-devtoolss 更名；codegraph 視需要補。

## 與 repo 層的分工

全域層管「路由到 canonical」；**repo 層管「路徑約定 + 機械守護」**（repo 三份協作檔是三家必然讀到的最大公約數）。擴充 `init-project-docs` 模板：repo 協作檔各含 (a) 一行 dev-workflow 路由；(b) 產物路徑約定表；(c) `.github/hooks/` + pre-commit + CI 守護骨架。既有 repo 下次動協作檔時補同段，不強制立刻回填。superpowers 鏈不搬不改——canonical 只點名為 preferred executor + 附 inline fallback 規格。

## Tradeoffs（明示接受的代價）

1. **平權 vs 深度**：S4/S5 在 Codex/Copilot 的審查深度確定低於 Claude 現況；深度以 adapter enhancement 保留在 Claude，不是消失。
2. **inline fallback 薄重複**：canonical inline 各階段最小規格與 superpowers 有少量語意重疊，plugin 升版有 drift 風險——inline 只寫「產物 + gate 條件」不抄流程細節。
3. **ledger 屬 prose gate**：pre-commit 查不到 PR body；機械化（CI job 查 body）先不做，模型不遵守兩次再上。
4. **硬人工 gate 集中**：LIGHT 單 gate（S2）、HEAVY 雙 gate（spec 簽核 + S2）；LIGHT 的設計錯誤會晚到 S2 才被抓——換輕量任務不被重鏈拖慢。
5. **32KB AGENTS.md 歸檔**：未收割細節失效——但它本來就休眠，實際損失為零；歸檔前人工掃一次、檔頭加警語（「本檔已退役，正本見 ~/.agents；勿復活為第二真實來源」）。
6. **不移植 agent 三格式**：省 44/43/5 清單同步 rot；reviewer 輸出風格三家有差——canonical 只約束「必記錄型別與結論」。
