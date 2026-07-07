<!-- status: PROPOSAL 附件 | audited: 2026-07-06 ~ 2026-07-07 | method: 活體探針優先於檔案宣稱 | readers: AI models -->
# 01 審查發現全錄

> 適用：全 host｜載入：無（PROPOSAL，未生效）
>
> 方法論：**任何「被載入」宣稱都以活體探針驗證**（`claude -p` 複誦、`codex debug prompt-input` grep、`copilot -p` 禁工具複誦、CLI bundle 逐字比對），不信任檔案自述。本檔每條 finding 標注證據形態；未驗證項一律 `UNVERIFIED:` 前綴。

## F1 三家 live 層真相（核心發現）

| Host | 實際載入的全域注入 | 完整規則覆蓋率 | 證據 |
|------|--------------------|----------------|------|
| Claude Code | `~/.claude/CLAUDE.md` + `~/.claude/rules/`（cookbook 常駐、其餘 7 檔 paths 條件掛載）+ skills symlink | ~100% | 原生機制 + session 實測 |
| Codex CLI 0.142.5 | **僅** `AGENTS.override.md`（~1.5KB：zh-TW / Closeout Ledger / PR 監控三節） | **~5%**（32KB `AGENTS.md` 被整檔取代，10 大防線休眠） | sampled session rollout：32KB 內容 0 出現 |
| Copilot CLI 1.0.69-2 | **僅** `~/.copilot/copilot-instructions.md` + `~/.copilot/instructions/*.instructions.md`（整檔注入，applyTo frontmatter 不解析） | **摘要式部分覆蓋**（宣稱繼承 `~/.claude/CLAUDE.md` 為假；但 `instructions/global-core.instructions.md` 45 行英文摘要確實常駐，涵蓋 force-push 禁令、no-evidence-no-done、模糊即停等；**缺 rollback 義務、DB migration 分段、merge-gate bot review**。精度修正 2026-07-07，見 06 C-R2） | bundle 逐字驗證：home 層 conventionPaths 不含 `.claude`；global-core 內容比對 |

**教訓（制度化依據）**：兩起事故（override 吃掉 32KB、Copilot 假繼承）共同點是「檔案層看起來正常、context 層死透」。故制度必須把驗證做到 **context 級**（fingerprint 探針），不能停在檔案級（symlink 存在、hash 相符）。

## F2 Codex 防線休眠 + approval 層複合風險

- 休眠內容：Hard Rules 全套（force-push 禁令、模糊即停、高風險 rollback）、DB migration 五段式、merge gate、release gates、產物路徑約定（`sdd/`、`CONTEXT.md`、ADR/spec/plan 分工）——AGENTS.override.md 存在期間全部未注入。
- **複合風險**：`~/.codex/rules/default.rules` 對 `['git','commit']`、`['git','push','origin']` 無條件前綴放行。instruction 層（防線休眠）與 approval 層（自動放行）**兩道煞車同時離線**。
- Codex 端 skill description 被截斷至 2–6 字元（metadata budget，272 條超額）→ **routing 不能靠 description，只能靠注入檔逐名點名**。
- Codex 無 config import 機制（全鍵枚舉 + --help 驗證）→ 共用層消費只能走「生成部署」。

## F3 Copilot 假繼承 + 死引用

- `copilot-instructions.md` 第 4 行「Copilot CLI 已自動載入 ~/.claude/CLAUDE.md」——**假**。一句未驗證的肯定句讓 Copilot 對完整 Hard Rules 的取得失守一個月無人察覺（實際殘存覆蓋僅 global-core 英文摘要，見 F1 精度修正）。
- global-core 摘要同時構成**第三份無同步的平行正本**（CLAUDE.md 完整 zh-TW 版／global-core 英文摘要版／AGENTS.override 近乎無）——強化而非削弱收斂理由。
- 9 個指向不存在 skill/agent 的死引用（含 code-simplifier agent 路由），逐名（2026-07-07 對 `~/.agents/skills/` 機械核對）：`dotnet-design-pattern-review`、`dotnet-timezone`、`api-design-principles`、`devops-rollout-plan`、`refactor-plan`、`refactor-method-complexity-reduce`、`mp-to-prd`、`ai-prompt-engineering-safety-review`、`unit-test-vue-pinia`。
- MCP server 名拼錯：`chrome-devtoolss`（多一個 s）——skill/指令點名 `chrome-devtools` 會失配。
- 用戶 zsh alias 把 `copilot` 包成 `copilot --autopilot`——預設繞過 plan 確認 gate。

## F4 Hooks 盤點

- 4 支 hook script 在 Claude/Codex 兩家 **byte-identical 零 drift，但無同步機制**（巧合而非制度）；只有 `~/.claude/hooks/` 有版控。
- `~/.codex/hooks.json` live：SessionStart 掛 2 支 patch script，動的是 **Claude 的 plugin cache**——跨 host 互保已是既成事實，證明 Claude↔Codex hook 協定同構。
- Codex 端 `audit-bash.sh` / `session-time.sh` 為死副本（未註冊）。
- `UNVERIFIED:` Codex PreToolUse / PostToolUse 有 schema、無觸發證據——搬阻擋型 hook 前必須先最小實測（echo hook + 觀察 hooks.state），掛了不觸發的假守護比沒守護更糟。
- Copilot **無 user-level hook 掛載點**（原生 hooks 引擎只讀 repo git-root `.github/hooks/`；bundle getHooksDir 證實）。
- 三家皆缺的守護：secret-scan（正解 = git pre-commit gitleaks，host 無關）、cookbook orphan guard、watch-ci。

## F5 Skill 平權現況（workflow 的原料已齊）

- **50 個共用 skill 三家全通**：`~/.agents/skills/` 為正本——Codex skill root 原生載入、Copilot 原生讀、Claude 經 `~/.claude/skills/` symlink（48 條為絕對路徑，換機會斷）。SKILL.md 格式三家同構。
- **superpowers 14 件套三家同版 6.1.1**（Claude plugins cache / Codex superpowers-dev enabled / Copilot installed-plugins 註冊）——brainstorming、writing-plans、TDD、systematic-debugging 等「同一條 workflow 的執行件」已就位。
- 缺口：`sdd` Claude-only（commands/ 形式）；`code-simplifier` / `dotnet-code-reviewer` agent 缺 Copilot 版；`uiux-reviewer` 硬依賴 claude-in-chrome 不可平移；feature-dev plugin 缺 Codex。
- **結論：真缺口在路由層，不在能力層。**

## F6 Host 能力矩陣

已平權（三家原生）：plan mode（EnterPlanMode / Plan Mode `<proposed_plan>` / `--mode plan`）、todo（TodoWrite / update_plan / update_todo）、MCP 四件套（context7 / microsoft-learn / playwright / chrome-devtools）。

**4 面永遠無法平權的結構牆**（制度必須繞行，不可假裝能補）：

| # | 牆 | 事實 | 等效策略 |
|---|----|------|----------|
| 1 | 全域機械守護 | Copilot hooks 僅 repo `.github/hooks/`，無全域註冊點 | 強制性檢查降到 repo 層：git pre-commit + CI（host 無關）；host hooks 只當第二道加速層 |
| 2 | 全域正本自動繼承 | Codex 無 import 且 override 整檔取代；Copilot 不讀 CLAUDE.md | 生成部署（設定層）+ repo 層 AGENTS.md 為權威描述最大公約數 |
| 3 | 子代理生態 | agent 定義三格式互不相容（.md / .toml / .agent.md），數量 44/43/5 | 審查/簡化邏輯放 **skills**（唯一三家同構載體）；workflow 描述「行為」不點名「agent」 |
| 4 | 編排工具語彙 | 同構能力、名稱互異、不可跨家點名 | canonical 只寫 host 中立行為指令；各 host adapter 做名稱映射 |

## F7 破口與待辦清單（帶外處理，與遷移不混批）

1. **rotate stitch MCP `X-Goog-Api-Key`**：同一 53 字元 key 明文存在於 `~/.codex/config.toml`、`~/.claude.json`、2 份 .bak（.bak 直接刪）。處理時只認 key 名、勿印值。
2. 移除 zsh `copilot --autopilot` alias（要 autopilot 另立 `copilot-auto` 顯式選用）。
3. `~/.copilot/mcp-config.json` 的 `chrome-devtoolss` 改名 `chrome-devtools`。
4. 修剪 `~/.codex/rules/default.rules` 兩條無條件放行。
5. Codex hooks.json 補註冊三支 guard（前置：PreToolUse 最小實測通過）。
