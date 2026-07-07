# references/ 索引

本目錄提供 `SKILL.md` 執行各 Phase 時要讀取的範本與教材。SKILL.md 本身只描述流程與對應關係，實際寫入專案的內容都放在這裡 —— 要改規則內容或模板時只需動這個資料夾，不必重寫 skill 主體。

## 檔案用途

| 路徑 | 對應 Phase | 用途 |
|------|-----------|------|
| [`host-matrix.md`](./host-matrix.md) | Phase 0.5 + 所有 host-specific 輸出 | 三 host（Claude Code / Codex CLI / Copilot CLI）的產物對照單一事實來源：指令檔名、設定檔格式、hook 事件名、agents frontmatter、合併策略 |
| [`docs-examples.md`](./docs-examples.md) | Phase 1 | docs 文件「骨架式 vs 充足」好壞對照範例（ARCHITECTURE.md、FEATURES.md），撰寫 docs 前先讀，建立詳細度基準 |
| [`fallback-defaults.md`](./fallback-defaults.md) | Phase 0 | Target host 的全域指令檔（Claude `~/.claude/CLAUDE.md` / Codex `~/.codex/AGENTS.md` / Copilot `~/.copilot/copilot-instructions.md`）不存在 / 解析失敗時套用的內建預設（ORM、DB、驗證、測試、API error format 等） |

### `hooks/` — Phase 5 Hook 腳本範本

每個 `.sh` 為**跨 host 共用的腳本本體**——開頭有一段 host-agnostic input shim，自行偵測 host 並正規化各 host 的 stdin JSON / env 慣例。挑選方式見 SKILL.md Phase 5 的 hooks 表。

| 檔案 | 對應 Hook 事件 | Matcher | 說明 |
|------|---------------|---------|------|
| [`hooks/protect-files.sh`](./hooks/protect-files.sh) | PreToolUse | `Edit\|Write` | 阻擋編輯 `.env`、`*.lock`、`*.pem`、`*.key` 等敏感檔案 |
| [`hooks/auto-format.sh`](./hooks/auto-format.sh) | PostToolUse | `Edit\|Write` | 編輯後依副檔名派發 prettier / eslint / dotnet format / ruff |
| [`hooks/run-tests.sh`](./hooks/run-tests.sh) | PostToolUse | `Edit\|Write` | 編輯後跑對應檔案的測試，含 5 秒 debounce + 僅跑對應測試 |
| [`hooks/auto-api-docs.sh`](./hooks/auto-api-docs.sh) | PostToolUse | `Edit\|Write` | 路由 / controller / API 檔變更後，優先執行專案自帶的 API 文件指令；無則提醒手動同步 docs |
| [`hooks/compact-reminder.sh`](./hooks/compact-reminder.sh) | SessionStart | `compact` | Compact 後抽取指令檔（CLAUDE.md/AGENTS.md/copilot-instructions.md）「關鍵規則」段落重新注入 |
| [`hooks/notify.sh`](./hooks/notify.sh) | Notification + Stop | — | 等待確認 / 任務完成時發 macOS 通知（osascript + 完成音效）；非 macOS 靜默結束 |

**Host 註冊範本**（腳本本體共用，只有「註冊到哪個檔、什麼格式」不同）：

| 子目錄 | host | 註冊產物 |
|--------|------|---------|
| [`hooks/claude/`](./hooks/claude/) | Claude Code | `settings-hooks.json` → 合併進 `.claude/settings.json` 的 `hooks` |
| [`hooks/codex/`](./hooks/codex/) | Codex CLI | `README.md` → `config.toml` 的 `[hooks.<Event>]` TOML 轉換指南 |
| [`hooks/copilot/`](./hooks/copilot/) | Copilot CLI | `hooks.json` → 複製為 `.github/hooks/init-project-docs-hooks.json` |

> **註**：`auto-api-docs.sh` 不硬產文件 —— 通用環境無法可靠地為任意框架（Swashbuckle / NSwag / swagger-jsdoc / drf-spectacular / FastAPI）產生 API 文件，故改走「專案指令優先」：偵測到 `package.json` script 名含 api/doc/openapi/swagger 才執行，否則僅提醒。`notify.sh` 偏 UX 用途，亦可放各 host 全域目錄使用。

### `agents/` — Phase 6 Subagent 範本

每個 `.md` 為 agent 定義的 host-neutral 骨架（MD + YAML frontmatter）。套用時替換 `{PROJECT_NAME}`、`{TECH_STACK}`、`{SKILLS_TO_CALL}`、`{PROJECT_CONVENTIONS}` 四個變數。

**Host 路由**：Claude 直接用 `.md`；Copilot 以同一批 `.md` 為來源，但輸出 `.github/agents/*.agent.md` 並轉換 frontmatter / tools（見 [`agents/copilot/README.md`](./agents/copilot/README.md)）；Codex 為 TOML、差異大 → 依 [`agents/codex/README.md`](./agents/codex/README.md) 轉換寫入 `.codex/agents/*.toml`（project）或 `~/.codex/agents/*.toml`（explicit global）。

| 檔案 | Model | Tools | 用途 |
|------|-------|-------|------|
| [`agents/code-reviewer.md`](./agents/code-reviewer.md) | opus | Read, Grep, Glob, Bash | 程式碼審查（安全 / 規範 / 效能） |
| [`agents/test-runner.md`](./agents/test-runner.md) | sonnet | Bash, Read, Grep | 執行測試、解析失敗、給修復建議（不改碼） |
| [`agents/debug-expert.md`](./agents/debug-expert.md) | opus | Read, Edit, Bash, Grep | 重現 → 根因 → 最小修復 → 回歸測試 |
| [`agents/doc-writer.md`](./agents/doc-writer.md) | sonnet | Read, Write, Edit | README / API / ARCHITECTURE 撰寫 |
| [`agents/security-auditor.md`](./agents/security-auditor.md) | opus | Read, Grep, Glob, Bash | Secret / Injection / XSS / Auth / Dependency 審計 |
| [`agents/refactor-assistant.md`](./agents/refactor-assistant.md) | opus | Read, Edit, Grep, Glob | 抽共用、改命名、拆大類別（行為不變） |
| [`agents/git-commit.md`](./agents/git-commit.md) | sonnet | Bash, Read, Grep | Conventional Commits zh-TW；**不加** Co-Authored-By |

> Model 選擇理由：`opus` = 判斷密集（review / debug / refactor / security）；`sonnet` = 執行密集（test / doc / commit）。使用 alias 而非具體版本號，以自動跟隨模型升級。

> **何時派哪個 agent**（觸發情境例，供使用者挑選 Phase 6 catalog 時參考）：
> - `code-reviewer` —— 完成一個功能 / PR 前，要一份安全 + 規範 + 效能的綜合審查。
> - `test-runner` —— 測試紅燈、要人解析失敗原因並給修復方向，但**不希望它改動程式碼**。
> - `debug-expert` —— 出現 bug / 例外 / 非預期行為，需要重現 → 根因 → 最小修復的完整流程。
> - `security-auditor` —— 處理 auth / 輸入處理 / 相依套件，想一次掃 secret / injection / XSS / 相依弱點。
> - `refactor-assistant` —— 程式可動但結構差（重複、命名亂、巨大類別），要在**行為不變**下整理。
> - `doc-writer` —— 要產出或更新 README / API 文件 / ARCHITECTURE 等與程式邏輯解耦的撰寫工作。
> - `git-commit` —— 要一個 Conventional Commits zh-TW 訊息，並確保**不加** Co-Authored-By。

### `rules/` — Phase 4 Rules 範本

每個 `.md` 為規則檔的預填內容，**內容 host 無關**。路徑限定型規則的 frontmatter `paths` 由 skill 根據 Phase 0 偵測結果動態填入。Host 路由：Claude → `.claude/rules/*.md`（保留 `paths:`）；Copilot → `.github/instructions/<name>.instructions.md`（鍵名改 `applyTo:`）或併入 `copilot-instructions.md`；Codex 無 path-scoping → 規則內容併入 `AGENTS.md` 分節。

| 檔案 | 選項 | 自動預填來源（target host 全域指令檔） |
|------|------|-----------------------------|
| [`rules/api-design.md`](./rules/api-design.md) | API 設計規則 | `.NET Preferences` 的 API error format |
| [`rules/db-access.md`](./rules/db-access.md) | 資料庫規則 | `New Project Defaults` 的 ORM / DB 選型 |
| [`rules/testing.md`](./rules/testing.md) | 測試規則 | `Testing Preferences`（framework、naming、integration 範圍）|
| [`rules/frontend.md`](./rules/frontend.md) | 前端 / 模板規則 | `Frontend Preferences`（a11y、error boundary）|
| [`rules/git-commit.md`](./rules/git-commit.md) | Git Commit 規則 | `Git Preferences`（Conventional Commits zh-TW、branch、tag）|
| [`rules/security.md`](./rules/security.md) | 安全性規則 | `Security`（JWT httpOnly、`.env.example`、DPAPI）|
| [`rules/observability.md`](./rules/observability.md) | Observability 規則 | `Observability`（X-Correlation-ID、`/health`、OTel）|

### `settings-templates/` — Phase 2 設定模板

依 host 分流：Claude 用 `claude/*.json`；Codex / Copilot 為各自的轉換指南（格式差異大，逐檔複製易腐化）。`detect-stack.sh` 回 stack 名，SKILL.md Phase 2 以 `<host>/<stack>` 組路徑。

| 路徑 | host | 內容 |
|------|------|------|
| [`settings-templates/claude/*.json`](./settings-templates/claude/) | Claude Code | 12 個 stack 的 `.claude/settings.json` 片段正本 |
| [`settings-templates/codex/README.md`](./settings-templates/codex/README.md) | Codex CLI | Claude JSON → `.codex/config.toml`（TOML）轉換指南 + worked example |
| [`settings-templates/copilot/README.md`](./settings-templates/copilot/README.md) | Copilot CLI | Copilot 無 Claude-style 專案 permissions/sandbox 設定檔 → 改以 `.github/hooks/guard-commands.json`（`preToolUse` guard hook）落地 deny 清單 |

`claude/` 下 12 個 `.json`：

| 檔案 | 對應專案類型 |
|------|-------------|
| `claude/dotnet-webapi.json` | ASP.NET Core Web API |
| `claude/dotnet-console.json` | C# Console |
| `claude/dotnet-worker.json` | .NET Worker Service / 背景服務 |
| `claude/dotnet-winforms.json` | .NET WinForms 桌面應用 |
| `claude/dotnet-library.json` | .NET 類別庫 / NuGet 套件 |
| `claude/dotnet-framework.json` | .NET Framework 4.x |
| `claude/nodejs-express.json` | Node.js Express |
| `claude/frontend.json` | Frontend (React / Vue + TS) |
| `claude/python.json` | Python |
| `claude/go.json` | Go |
| `claude/rust.json` | Rust |
| `claude/docker-addon.json` | 追加用，偵測到 Dockerfile / docker-compose 時合併 |

#### Settings 權限對照表（Phase 2 教學，以 Claude JSON 為準）

各 settings 模板採同一套權限模型，套用前先理解每段的作用與「為何這樣設」：

| 區塊 | 作用 | 預設策略 | 範例 |
|------|------|---------|------|
| `permissions.allow` | 免確認放行的工具呼叫 | 只放行套件快取等高頻、低風險路徑 | `Read(~/.nuget/**)`、`Edit(~/.npm/**)` |
| `permissions.deny` | 一律封鎖的工具呼叫（優先於 allow） | 封鎖會對外發佈 / 不可逆的指令 | `Bash(dotnet nuget push *)`、`Bash(npm publish *)` |
| `sandbox.enabled` | 開啟指令沙箱 | 一律 `true` | — |
| `sandbox.autoAllowBashIfSandboxed` | 沙箱內 Bash 免逐次確認 | `true`，須與 sandbox 並用才安全 | — |
| `sandbox.network.allowedDomains` | 沙箱可連線的網域白名單 | 只放套件來源 + `localhost:*` | `api.nuget.org`、`registry.npmjs.org` |

原則：

- **allow 從嚴** —— 只放高頻且無副作用的讀寫；破壞性操作（刪除、發佈、推送）永不進 allow。
- **deny 從寬** —— 發佈 / 推送 / 金鑰類指令明確列入；deny 優先級高於 allow，可安全地與較寬的 allow 並存。
- **網域白名單最小化** —— 只放專案實際需要的套件 registry 與本機埠，不放泛用網域。
- 專案模板為**增量**：與全域 settings 聯集去重合併，不覆蓋使用者既有設定。

## 其他 skill 附屬資源

以下不在 `references/` 下，但屬於同一 skill 的一部分：

- **`scripts/`**（skill 根目錄）
  - `detect-stack.sh` — Phase 0 的可選偵測加速器，輸出 JSON 摘要（primary、languages、orm、test、docker、monorepo、settings_template）
  - `detect-host.sh` — Phase 0.5 的可選 host 偵測器，輸出 env 訊號 + home 目錄 + 建議 host + 是否模糊
  - `merge-settings.py` — Phase 2 的可選 JSON 合併器（Claude `settings.json` + Copilot hooks JSON 共用），對 `allow`/`deny`/`allowedDomains` 做聯集去重，`hooks` 合併不覆蓋；Codex TOML 不適用

- **`evals/`**（skill 根目錄）
  - `evals.json` — 具代表性的測試案例（.NET WebAPI、Vite React、Node Express、Monorepo、Fallback defaults，以及三 host 偵測 + 多 host opt-in），用於評估 skill 輸出品質

## 新增 / 修改範本的準則

- **模板內容應為「通用、不含專案特定路徑」**：路徑、技術棧細節由 skill 在套用時注入，模板本身保持可重用。
- **避免重複全域 settings 已提供的規則**：見 SKILL.md Phase 2「與全域 settings 的關係」段落；專案模板只放本專案特有項目。
- **rules 模板的規則條目應為「標的明確、可驗證」**：避免 "寫好 code" 之類無法對照的陳述，保持每條規則可作為 review checklist 使用。
