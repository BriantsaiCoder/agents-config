# GitHub Copilot CLI — agents 套用指南

Copilot CLI 的自訂 agent 使用 Markdown + YAML frontmatter。套用 `references/agents/*.md` 時，不要直接複製 Claude Code frontmatter；Copilot 輸出需轉換為 Copilot CLI 的檔名與 tool id。

## 輸出位置

專案層 agent 寫入：

```text
.github/agents/<name>.agent.md
```

既有同名檔先顯示 diff，不覆蓋。不要修改 `../*.md` 正本，因為那些同時供 Claude Code 使用。

## frontmatter 轉換（Claude → Copilot）

| 欄位 | Claude 正本 | Copilot 產出 |
|---|---|---|
| `name` | 保留 | 保留；可含空白，建議與檔名語意一致 |
| `description` | 保留 | 保留 |
| `tools` | `Read, Grep, Glob, Bash` 等 Claude tool 名 | 轉成 Copilot canonical aliases 陣列 |
| `model` | `opus` / `sonnet` | 改為目前 Copilot 帳號可用模型 id（跑 `copilot /model` 或看帳號設定取得；模型 id 隨帳號與時間變動，勿沿用任何文件內的範例字串） |
| `color` | 有 | 刪除 |
| `target` | — | 不確定時省略 |
| `user-invocable` | — | 不確定時省略 |

## tools 轉換建議

Copilot CLI 的 canonical aliases 是 `execute`、`read`、`edit`、`search`、`agent`、`web`、`todo`。相容 aliases 不分大小寫，但產出統一用 canonical 小寫名稱，避免把 host-specific tool id 寫死。

| Claude tool | Copilot canonical alias |
|---|---|
| `Read` | `read` |
| `Grep` / `Glob` | `search` |
| `Edit` / `Write` | `edit` |
| `Bash` | `execute` |
| delegate / subagent | `agent` |
| Web / docs | `web` |
| task list | `todo` |

只列該 agent 真正需要的 aliases；MCP tools 則保留官方 namespaced tool id。無法確認時省略並在 summary 列為需人工確認。

## 套用步驟（SKILL.md Phase 6）

1. 對使用者多選勾選的每個 agent，讀 `../<name>.md`。
2. 解析 YAML frontmatter，刪除 `color`，將 `model` 與 `tools` 轉成 Copilot 格式。
3. 填入 body 佔位符：`{PROJECT_NAME}`、`{TECH_STACK}`、`{PROJECT_CONVENTIONS}`、`{SKILLS_TO_CALL}`。
4. 寫入 `.github/agents/<name>.agent.md`。
5. 驗證每個 `tools` 值都是 canonical alias 或已確認的 namespaced MCP tool id。

## agent 清單與 tier

| agent | tier | 對應 Copilot 模型（建議） |
|---|---|---|
| code-reviewer / debug-expert / security-auditor / refactor-assistant | opus 級 | 帳號內最強模型 |
| doc-writer / test-runner / git-commit | sonnet 級 | 帳號內較快模型 |

> 模型名隨 Copilot 帳號可用清單而定；套用前以 `copilot help config`、`/model` 或目前 session 可用模型清單確認。
