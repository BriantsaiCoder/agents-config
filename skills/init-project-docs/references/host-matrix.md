# Host Matrix — 跨 host 產物對照

本檔是 `SKILL.md` 各 Phase 做 host 分流時的**單一事實來源**。三個 host（Claude Code / Codex CLI / GitHub Copilot CLI）共用同一個 skill（皆掃描 `~/.agents/skills`），但產出的原生檔不同。SKILL.md 只描述流程，「該寫哪個檔、用什麼格式」一律查本表。

> 版本敏感：Codex hooks / subagents / config 與 Copilot instruction surfaces 會變動。實際套用 Phase 2/5/6 前，先查官方 docs 或本機 CLI help；若與本表不一致，以官方 docs / local schema 為準並回報差異。

> 最近重驗：2026-08-02（Claude Code 2.1.220、Codex CLI 0.146.0、GitHub Copilot CLI 1.0.75）。

> 重要事實（2026-05 查證）：Claude Code **不**原生讀 `AGENTS.md`（GitHub issue #6235 未實作），只讀 `CLAUDE.md`。因此每個 host 必須產自己的原生指令檔，不能靠單一 `AGENTS.md` 通吃。

套用前的 current-doc revalidation：

- [ ] 記錄 Claude Code、Codex CLI、Copilot CLI 的本機版本。
- [ ] 對照三者官方 config、hooks、custom agents 文件；若 schema 漂移，先更新本表與範本。
- [ ] 解析所有要寫出的 JSON / TOML / YAML fixture。
- [ ] 用 fresh session inventory 驗證 hooks / agents；blocking hook 再跑一個 safe negative canary。

## 產物對照表

| 產物 | Claude Code | Codex CLI | GitHub Copilot CLI |
|------|-------------|-----------|--------------------|
| 指令檔（專案） | `CLAUDE.md` | `AGENTS.md` | `.github/copilot-instructions.md`；Copilot CLI 也會讀 `AGENTS.md` |
| 指令檔（全域） | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.copilot/copilot-instructions.md` |
| 設定檔（專案） | `.claude/settings.json`（JSON） | `.codex/config.toml`（TOML） | `.github/copilot/settings.json`（僅限官方 supported keys，無 Claude-style permissions/sandbox parity）；個人專案 override 為 `.github/copilot/settings.local.json`，必須 gitignore |
| 設定檔（全域） | `~/.claude/settings.json` | `~/.codex/config.toml` | `~/.copilot/settings.json`（home dir 使用者設定；專案可攜 hooks 走 `.github/hooks/*.json`） |
| hooks 註冊位置 | `.claude/settings.json` 的 `hooks` 物件（JSON） | `.codex/config.toml` 的 `[[hooks.<Event>]]` inline TOML；也可由 Codex hooks JSON 載入 | `.github/hooks/*.json`（JSON，`version: 1` + `hooks` 物件） |
| hook 事件名 | PascalCase：`PreToolUse`、`PostToolUse`、`SessionStart`、`Notification`、`Stop` | PascalCase：`PreToolUse`、`PostToolUse`、`SessionStart`、`UserPromptSubmit`、`Stop`、`PermissionRequest` | camelCase：`preToolUse`、`postToolUse`、`sessionStart`、`preCompact`、`notification`、`agentStop` 等（payload 內 `hook_event_name` 仍 PascalCase） |
| hook matcher | `matcher` 欄位，正則比對工具名（如 `Edit\|Write`） | `matcher` 欄位，regex；`PreToolUse` / `PostToolUse` / `PermissionRequest` 比對工具名（`Bash`、`apply_patch`、MCP tool 等），`SessionStart` 比對 `startup\|resume\|clear\|compact`；省略則全事件觸發 | `matcher` 欄位，正則比對工具名；Copilot tool id 版本敏感，未實測時優先省略 matcher，讓腳本由 payload 判斷 |
| hooks merge identity | wrapper metadata（matcher 與其他 wrapper 欄位）全相同才聯集內層 `hooks`；metadata 不同則保留獨立 wrapper | 同 Claude wrapper 規則；TOML 由 agent 增量合併 | flat entry 以完整 object 聯集去重；不以缺省 matcher 當成同一 entry |
| agents | `.claude/agents/*.md`（MD + YAML frontmatter） | `.codex/agents/*.toml`（project）或 `~/.codex/agents/*.toml`（personal/global） | `.github/agents/*.agent.md`（MD + YAML frontmatter；tools 需轉為 Copilot tool ids） |
| rules（path-scoped） | `.claude/rules/*.md` + frontmatter `paths:` glob | 無 path-scoping → 併入 `AGENTS.md` 分節 | `.github/instructions/**/*.instructions.md`（`applyTo:` glob）或併入 `copilot-instructions.md` |
| skill 目錄 | `~/.agents/skills`（共用） | `~/.agents/skills`（共用） | `~/.agents/skills`（共用） |

## Host 偵測訊號

| Host | env 訊號 | home 目錄 |
|------|----------|-----------|
| Claude Code | `CLAUDECODE`、`CLAUDE_CODE_ENTRYPOINT` | `~/.claude/` |
| Codex CLI | `CODEX_HOME`、`CODEX_SANDBOX` | `~/.codex/` |
| Copilot CLI | `COPILOT_HOME`、`COPILOT_AGENT` | `~/.copilot/` |

偵測優先序見 SKILL.md Phase 0.5：(1) 執行中 agent 自知身分最可靠；(2) `scripts/detect-host.sh` 的 env 訊號佐證；(3) home 目錄僅供推測與 `other_homes` scope confirmation，不可單獨當成目前 runtime 身分。

Phase 0.5 進入 Phase 1 前必須先回報：

```text
detected_host=<runtime self-knowledge>
script_suggested=<detect-host.sh suggested>
ambiguous=<true|false>
other_homes=<comma list or none>
proposed_target_hosts=<host list>
```

若 `other_homes` 非空，且使用者本輪沒有明確指定 target hosts，只有涉及 host-specific output scope（instructions、config、hooks、agents）時才停止並請使用者確認要只產 detected host，或也產哪些 `other_homes`。host-neutral README／architecture 不觸發確認，host scope 記 `N/A`；已授權的 target hosts 直接沿用，不重問。這是 output-scope confirmation，不代表 runtime 混淆。

## skill 呼叫語法（指令檔內提及時依 host 套用）

| Host | 呼叫 skill 的語法 |
|------|------------------|
| Claude Code | `Skill` 工具（`Skill(skill: "name")`） |
| Codex CLI | `$skill-name`（prompt 中以 `$` 前綴） |
| Copilot CLI | `/skill-name`（slash command） |

## 多 host 輸出規則

- 使用者明確要求或在 Phase 0.5 確認三 host 時，同時產出 `CLAUDE.md`、`AGENTS.md`、`.github/copilot-instructions.md`。
- `CLAUDE.md` 與 `AGENTS.md` 可各自是完整指令檔，因 Claude Code 不原生讀 `AGENTS.md`，Codex 也不讀 `CLAUDE.md`。
- Copilot CLI 會讀 `AGENTS.md` 與 `.github/copilot-instructions.md`，因此 all-host 模式下 `.github/copilot-instructions.md` 應是 thin adapter：指向 `AGENTS.md` / `docs/`，只補 Copilot-specific routing、`.github/instructions`、hooks 或 agents 說明。
- Copilot-only 模式下，若未產 `AGENTS.md`，`.github/copilot-instructions.md` 可作為完整 project instruction file。

## 設定檔 schema 對照（Phase 2 用）

Claude 走 JSON、Codex 走 TOML。Copilot 有限定 supported keys 的 repository/local settings，但沒有 Claude-style repo permissions/sandbox parity；專案層強制點仍走 hook JSON。權限模型概念相近，但鍵名與落地位置不同：

> 已查證（2026-08-02，OpenAI Codex docs / GitHub Copilot docs）。Codex 的 `approval_policy` 值為 `"untrusted"` / `"on-request"` / `"never"` 或 granular 物件；`sandbox_mode` 值為 `"read-only"` / `"workspace-write"` / `"danger-full-access"`。
>
> **重要差異**：Copilot CLI 的 `.github/copilot/settings.json` 與 `.github/copilot/settings.local.json` 只接受官方列出的 repository keys，沒有專案層 sandbox/permissions parity。工具放行/封鎖走 `--allow-tool`/`--deny-tool` flag（per-session）、互動核准，或 `preToolUse` hook 回 `deny`。需要可 commit、跨 session 的專案 guard 時，仍以 `.github/hooks/*.json` 落地（見 `references/settings-templates/copilot/README.md`）。

| 概念 | Claude Code | Codex CLI | Copilot CLI |
|------|-------------|-----------|-------------|
| 免確認放行 | `permissions.allow[]` | `approval_policy`（如 `"on-request"`）+ permissions profile | `--allow-tool` flag（per-session，不持久化到 repo） |
| 一律封鎖 | `permissions.deny[]` | `PreToolUse` / `PermissionRequest` hook 攔截 `Bash` 指令並回 deny / non-zero exit | `.github/hooks/*.json` 的 `preToolUse` hook 回 `deny` |
| 沙箱開關 | `sandbox.enabled = true` | `sandbox_mode = "workspace-write"` | （CLI 內建沙箱，無 repo 設定鍵） |
| 沙箱網路 | `sandbox.network.allowLocalBinding` | `[sandbox_workspace_write]` `network_access = true` | （無 repo 設定鍵） |
| 網域白名單 | `sandbox.network.allowedDomains[]` | `[permissions.<name>.network.domains]` map（`{ "host" = "allow" }`）；是否套用 profile 需依當前 Codex docs / local config 確認 | `~/.copilot/settings.json` 的 `allowedUrls[]`（僅 URL 內容抓取，非沙箱網路）|
| 可寫根目錄 | （沙箱預設 workspace） | `[sandbox_workspace_write]` `writable_roots[]` | `trustedFolders` 由 Copilot CLI 自管；skill 不手動寫 |

範本與逐 stack worked example：
- Claude：`references/settings-templates/claude/*.json`（12 個正本）
- Codex：`references/settings-templates/codex/README.md`（TOML 轉換指南 + worked example）
- Copilot：`references/settings-templates/copilot/README.md`（以 `preToolUse` hook 落地的指南）

## 合併策略（Phase 2）

- **Claude（JSON）**：用 `scripts/merge-settings.py`，對 `allow`/`deny`/`allowedDomains` 聯集去重；`hooks` 的 wrapper metadata 全相同時才聯集內層 `hooks`，metadata 不同時保留獨立 wrapper，不覆蓋使用者既有鍵。
- **Codex（TOML）**：不進 Python 腳本（避免引入 `tomlkit` 依賴）。由執行中的 agent 用自身 Edit 工具，依本表指定的 TOML 區塊做增量合併，且**先顯示 diff 再寫入**。
- **Copilot**：增量更新 `.github/copilot/settings.json` 的 supported keys；個人 override 寫 `.github/copilot/settings.local.json` 並 gitignore。Claude-style deny/sandbox 轉成 `.github/hooks/*.json`，既有 hook 檔以新檔並存、不覆蓋。

## agents frontmatter 對照（Phase 6）

Claude 與 Copilot 共用同一批 `references/agents/*.md`，套用時調整 frontmatter：

| 欄位 | Claude Code | Copilot CLI |
|------|-------------|-------------|
| `name` | 必填 | 必填 |
| `description` | 必填 | 必填 |
| `tools` | 逗號分隔工具名 | canonical aliases 陣列或清單：`read`、`edit`、`search`、`execute`，需要時再加 `agent`、`web`、`todo`；依 `references/agents/copilot/README.md` 轉換 |
| `model` | `opus` / `sonnet` / `haiku` | Copilot 模型 id（跑 `copilot /model` 或看帳號設定取當前可用 id；模型 id 隨帳號與時間變動，勿沿用任何文件內的範例字串） |
| `target` | —（不需要） | 選填，指定適用範圍 |
| `user-invocable` | —（不需要） | 選填，是否可由使用者直接呼叫 |

Codex agents 為 TOML（custom agent 的 `developer_instructions` + optional model/config），格式差異大 → 用 `references/agents/codex/README.md` 轉換。Repo-specific agent 寫入 `.codex/agents/`；只有使用者明確要求全域 reuse 時才寫入 `~/.codex/agents/`。

## Phase 4–6 建議標記

- **Rules：**有 API routes 時建議 `api-design`；有 DB／SQL／data-access code 時建議 `db-access`；有 tests 時建議 `testing`；出現 auth、admin、secrets、payment-like env 或 sensitive config 時建議 `security`。
- **Hooks：**預設建議 `protect-files`；有 test script 時建議 `run-tests`；有 OpenAPI／Swagger／API-doc script 時建議 `auto-api-docs`；只有存在 formatter 或 lint tooling 時才建議 `auto-format`。`compact-reminder` 與 `notify` 仍須列出，供 session UX／長文件流程選用。
- **Agents：**一般 baseline 建議 `code-reviewer`；有 tests 時建議 `test-runner`；出現 auth、admin、secrets 或 payment-like surfaces 時建議 `security-auditor`。其餘 agents 依本輪 intent 與 repo evidence 標記，但 Codex 仍須顯示完整 catalog。
