<!-- tier: host | consumed-by: copilot | generated-from: hosts/copilot-delta.md | last-verified: 2026-07-13 -->
<!-- FP:COPILOT-DELTA-2026Q3 -->

# Copilot CLI 差異層（正本安全 / 工作流 / 風格 / 路由見 tier0-2 + routing）

## 載入現況（附探針，禁未驗證肯定句）

- 本檔與 tier0-2 + routing 由 agents-sync 組裝部署至 `~/.copilot/copilot-instructions.md`（唯一部署目標，見 agents-sync TARGETS；Copilot CLI 整檔原樣注入）。
- UNVERIFIED：`~/.claude/CLAUDE.md` **不會**被 Copilot CLI 自動載入（2026-07-13 CLI 1.0.70 探針重驗：FP codeword 五枚全數複誦成功，僅來自本檔部署鏈）；勿假設其內容在 context。探針：`copilot -p '複誦 context 內 FP: 開頭 codeword' --available-tools=` 應含 FP:AGENTS-T0 / FP:ROUTING。

## Defaults — fallback 自動維護（覆寫）

- 偵測 fallback 版本（.NET / Node LTS）可能過期時，查官方最新（.NET → microsoft-learn MCP；Node → 官方 release schedule）並**提醒 user 自行更新** `~/.agents/rules/<stack>.md`（版本 pin 正本），MUST NOT 自動改寫共用規則檔。觸發：偵測 fallback 過期。例外：無。驗證：未寫入 `~/.agents/rules/`。

## Skill 路由（Copilot 可用名稱以 available_skills 為準）

- 逐名路由見 routing.md；Copilot 實際可用名稱以 `available_skills` 為準（skill-index 為 `dist/` 產物，不注入 Copilot context，勿引用）；某 skill / plugin / slash command 在 `available_skills` 不存在時，MUST NOT 硬呼叫不存在的名稱，改用內建工具或 routing.md 對應項。手寫 skill 清單一律禁止（9 死名事故根因）。
- 已移除 plugin（不主動呼叫）：spark、copilot-sdk、security-guidance。

## Hookify 模板（Copilot CLI 專屬：僅掃 CWD `.claude/hookify.*.local.md`，無全域註冊）

- 進入新 git 專案時主動提議從模板複製：`cp ~/.copilot/files/hookify-templates/hookify.*.local.md .claude/`（secret-scan 前置 gitleaks 提醒、claude-local-gitignore 提醒）。

## Tooling MCP 可用性（補充）

- Microsoft / Azure / .NET / EF Core：microsoft-learn MCP > Context7 MCP > web search；其他 library：Context7 MCP > web search；瀏覽器：chrome-devtools / playwright MCP。
