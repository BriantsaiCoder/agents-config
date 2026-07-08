# Copilot CLI — 差異層指令
<!--
角色：本檔為 Copilot CLI 專屬的「差異層」(delta layer)。
核心安全規則來源：~/.copilot/instructions/global-core.instructions.md（Copilot CLI 常駐載入，FP:COPILOT-CORE-2026Q3）。
更正（2026-07-07 CLI 1.0.69 bundle 逐字驗證）：~/.claude/CLAUDE.md **不會**被 Copilot CLI 自動載入，勿假設其完整內容在 context 中。探針：`copilot -p '複誦 FP:COPILOT-CORE 開頭句' --available-tools=`。
維護原則：本檔只放 Copilot 專屬「覆寫 / 補充」；共用核心規則維護於 global-core.instructions.md。
-->

## 優先序（覆寫 CLAUDE.md）

衝突時：
1. User 當下明確指示
2. 專案指令（`.github/copilot-instructions.md`、project `CLAUDE.md`、`AGENTS.md`）
3. 當前 skill / task context
4. 全域指令（`~/.claude/CLAUDE.md` + 本檔）

本檔在優先序 (4) 中作為 Copilot CLI 專屬覆寫層，沿用 CLAUDE.md 所有未在本檔出現的章節。

## 核心規則來源（更正：非繼承自 CLAUDE.md）

**~/.claude/CLAUDE.md 不會被 Copilot CLI 自動載入**（2026-07-07 CLI 1.0.69 bundle 逐字驗證：home 層 conventionPaths 不含 `.claude`）。核心安全底線由 `~/.copilot/instructions/global-core.instructions.md`（常駐，FP:COPILOT-CORE-2026Q3）提供：優先序、no-evidence-no-done、假設先驗證、模糊即停、force-push 禁令、high-risk rollback 義務、DB migration 分段、merge-gate bot review、驗證與溝通原則。

勿假設 CLAUDE.md 其餘章節（完整 Skill Routing、Workflow Playbooks 等）在 context 中；需要時明示讀取或改用本檔對應項。（終局遷移 Step 9：global-core 由生成檔取代，本段一併重寫。）

若某 skill、plugin、slash command 在 Copilot CLI `available_skills` 或 agent list 中不存在，**不要硬呼叫不存在的名稱**；改用本檔列出的 Copilot 對應 skill / agent，或直接使用內建工具完成。

## Defaults — fallback 自動維護（覆寫）

- CLAUDE.md 規定「fallback 過期須回寫該檔並通知 user」。Copilot CLI 環境覆寫為：
  - 偵測 fallback 版本可能過期時，**查官方最新 LTS（.NET → microsoft-learn MCP；Node → 官方 release schedule）並提醒 user 自行更新 `~/.claude/CLAUDE.md`，不自動改寫該檔**
  - 原因：跨工具寫入他工具設定檔具耦合風險

## Language（新增 — CLAUDE.md 未涵蓋）

- 用詞對照（一律使用台灣慣用詞）：
  create=建立、object=物件、queue=佇列、stack=堆疊、information=資訊、code=程式碼、running=執行、library=函式庫、building=建構、package=套件、class=類別、function=函式、memory=記憶體、built-in=內建、global=全域、example=範例、quality=品質、document=文件、file=檔案、data=資料、component=元件、integration=整合、search=搜尋、store=儲存
- 禁用：創建（用「建立」）、質量（用「品質」）、視圖（用「檢視表」）
- `/init` 或任何生成 `.github/copilot-instructions.md`、`README.md`、`AGENTS.md`、`CLAUDE.md` 等專案文件的指令，預設輸出 zh-TW（程式碼、API 名稱、設定 key、檔名、CLI 旗標、commit type 等保留原文）

## Code Style Principles（新增 — CLAUDE.md 未涵蓋）

- Favor pure functions; separate queries from commands (CQS)
- Fail fast：早期驗證，不靜默吞錯
- DRY 在第 3 次重複後才抽（Rule of Three）
- YAGNI：不必要的抽象不先建
- Composition > inheritance
- 命名表達 intent；註解解釋「why」
- 低耦合高內聚；外部依賴用 DI
- 巢狀深度 ≤ 2-3 層；超過就抽方法
- 重構時 extend，不破壞既有 interface

## Skills 使用指南（覆寫 — Copilot CLI 可用名稱）

CLAUDE.md 的 Skill Routing 可能包含 Claude Code 專屬或舊名稱；Copilot CLI 環境以目前 `available_skills` 與 agent list 為準：

- Stack 實作 / 審查 → 主動呼叫對應 skill（不要在本檔重複該 skill 規則）：
  - .NET / C#：`dotnet-core-best-practices`、`dotnet-framework-best-practices`、`dotnet-winforms-best-practices`、`dotnet-testing-best-practices`、`dotnet-logging-best-practices`
  - Data / SQL：`ef-core-best-practices`、`ef6-best-practices`、`dapper-best-practices`、`postgresql-best-practices`、`postgresql-optimization`、`mysql-best-practices`
  - Frontend / JS：`react-best-practices`、`next-best-practices`、`vue-best-practices`、`nuxt`、`pinia`、`vueuse-functions`、`typescript-best-practices`、`nodejs-best-practices`、`css-ui-best-practices`、`tailwind-v4-shadcn`
  - Testing / browser：`vitest`、`jest-best-practices`、`testing-library-react-best-practices`、`playwright-best-practices`
  - Infra / security：`containerization`、`dependency-security-scan`、`security-review`、`auth-implementation-patterns`
- 文件 / 專案初始化：
  - AI-assisted project docs / README / AGENTS / Copilot context → `init-project-docs`
  - Repository-level discovery / `docs/codebase/*` mapping → `acquire-codebase-knowledge`
- Release gate：
  - Frontend release gate → `frontend-release-verification`
  - Backend release gate → `backend-release-verification`
- Workflow：
  - Bug / hard diagnosis → `mp-diagnose`
  - Vertical-slice TDD → `mp-tdd`
  - Architecture deepening → `mp-improve-codebase-architecture`
- Agents / CLI workflows：
  - 程式碼審查 → built-in `code-review` agent 或 custom `feature-dev:code-reviewer`
  - 自己剛寫完程式碼後的簡化 pass → `pr-review-toolkit:code-simplifier`
  - Codex 二次驗證 / rescue → custom agent `codex:codex-rescue`
  - Commit → `commit` skill；push/PR → `commit-push-pr` skill；PR review → `review-pr` skill

### 已移除 plugins（不主動呼叫）
- `spark`（GitHub Spark SaaS app template，與 self-hosted 取向衝突）
- `copilot-sdk`（不開發 agentic SDK 應用）
- `security-guidance`（與 `security-review` / `dependency-security-scan` / `auth-implementation-patterns` 重疊；hook-only 在 Copilot CLI 不保證觸發）

## Hookify 模板（新增 — Copilot CLI 專屬）

Hookify 規則僅掃描 CWD `.claude/hookify.*.local.md`，**不支援全域註冊**。
進入新 git 專案時，主動提議從模板複製：

```bash
mkdir -p .claude && cp ~/.copilot/files/hookify-templates/hookify.*.local.md .claude/
```

模板：
- `hookify.secret-scan.local.md` — `git commit` 前提醒 gitleaks / detect-secrets（落實 CLAUDE.md Security § Secret 偵測）
- `hookify.claude-local-gitignore.local.md` — 編輯 `.claude/settings.local.json` 時提醒加入 `.gitignore`（落實 CLAUDE.md Commit § 不 commit 清單）

## Tooling 優先序（補充 — Copilot CLI MCP 可用性）

CLAUDE.md 已列共用優先序；下列為 Copilot CLI 環境的可用性註解：

- Microsoft / Azure / .NET / EF Core / ASP.NET Core API 設計：microsoft-learn MCP > Context7 MCP > web search
- 其他 library / framework 文件：Context7 MCP > web search（已啟用）
- 瀏覽器自動化：chrome-devtools MCP / playwright MCP（已啟用）
- Docker-dependent 專案啟動前：`docker compose up -d`

## 官方 Copilot 可攜層（新增）

- 為了在官方 Copilot 場景（例如 VS Code `~/.copilot/instructions`）也能套用核心規則，已同步建立：
  - `~/.copilot/instructions/global-core.instructions.md`
- 本檔維持 Copilot CLI 差異層職責；跨工具共用規則優先維護於 `~/.copilot/instructions/*.instructions.md`。

## 檔案路徑常數

- 全域共用偏好：`/Users/pochientsai/.claude/CLAUDE.md`
- Copilot CLI 差異層（本檔）：`/Users/pochientsai/.copilot/copilot-instructions.md`
- Copilot 官方可攜層：`/Users/pochientsai/.copilot/instructions/global-core.instructions.md`
- 專案層（若存在則優先）：`<repo>/.github/copilot-instructions.md`

<!-- agents-routing:begin | generated-from: ~/.agents/core/routing.md | last-verified: 2026-07-07 -->
<!-- FP:ROUTING-2026Q3 -->

# 開發任務路由（薄層；workflow 正本在 dev-workflow skill）

- 任何開發任務：先讀 ~/.agents/skills/dev-workflow/SKILL.md 並照其 S0 決策表路由。描述含錯誤行為 / 測試失敗 / regression 的走 SKILL.md 的 BUGFIX 鏈；單檔 / ≤1 天小需求走 skill sdd。
- 逐名點名 skill（Codex 端 description 被截斷至 2–6 字元，路由靠點名不靠 description）：dev-workflow、sdd、deps-check、mp-grill-with-docs、mp-diagnose、bug-fix-settlement、frontend-release-verification、backend-release-verification、dependency-security-scan、design-doc-mermaid。

## 最高風險攔截（常駐，防新鮮 skill prose 搶贏路由，尤其 superpowers 終態鏈）

- [R-1] 收尾類 skill（如 finishing-a-development-branch）MUST NOT 在 S4/S5 全綠前 invoke。觸發：任務仍有 FAIL 或未跑的 verify / review gate。驗證：S4 與 S5 四態全 PASS 才放行。例外：無。
- [R-2] fix 之前 MUST 先有 failing regression test（紅→綠）；無可測 seam 須明確標記例外並附替代驗證。觸發：修 bug 的變更無先行紅測。驗證：紅燈輸出存在於證據。例外：無。
- [R-3] S2 ⏸ plan gate 在任何 auto / autopilot 模式下 MUST NOT 豁免。觸發：非 plan 模式且將改檔。驗證：改檔前有計畫產物＋引用用戶確認原句。例外：無。

<!-- agents-routing:end -->
