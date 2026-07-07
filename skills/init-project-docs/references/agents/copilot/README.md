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
| `tools` | `Read, Grep, Glob, Bash` 等 Claude tool 名 | 轉成 Copilot tool ids 陣列 |
| `model` | `opus` / `sonnet` | 改為目前 Copilot 帳號可用模型 id（例如 `claude-opus-4.7`、`gpt-5.5`、`claude-sonnet-4.6`） |
| `color` | 有 | 刪除 |
| `target` | — | 不確定時省略 |
| `user-invocable` | — | 不確定時省略 |

## tools 轉換建議

Copilot tool id 會隨 CLI / IDE surface 變動。套用前優先參考本機既有 `~/.copilot/agents/*.agent.md`、`/env` 或官方說明；不要把 Claude-only `Read`、`Grep`、`Glob`、`Bash` 原樣寫入 Copilot agent。

| Claude tool | Copilot tool ids 建議 |
|---|---|
| `Read` | `search`, `search/codebase` |
| `Grep` / `Glob` | `search`, `search/codebase`, `search/usages` |
| `Edit` / `Write` | `edit/editFiles` |
| `Bash` | `runCommands`, `execute/createAndRunTask` |
| 測試相關 | `runTests`, `execute/testFailure`, `findTestFiles` |
| 問題 / diff | `read/problems`, `search/changes` |
| Web / docs | `web/fetch`（若環境可用） |

建議保守產出：只列該 agent 真正需要的 Copilot tool ids。若無法確認某 tool id，省略該 tool 並在 summary 中列為需人工確認，而不是寫入 Claude tool 名。

## 套用步驟（SKILL.md Phase 6）

1. 對使用者多選勾選的每個 agent，讀 `../<name>.md`。
2. 解析 YAML frontmatter，刪除 `color`，將 `model` 與 `tools` 轉成 Copilot 格式。
3. 填入 body 佔位符：`{PROJECT_NAME}`、`{TECH_STACK}`、`{PROJECT_CONVENTIONS}`、`{SKILLS_TO_CALL}`。
4. 寫入 `.github/agents/<name>.agent.md`。
5. 驗證產出不含 Claude-only tools：`Read`、`Grep`、`Glob`、`Bash`。

## agent 清單與 tier

| agent | tier | 對應 Copilot 模型（建議） |
|---|---|---|
| code-reviewer / debug-expert / security-auditor / refactor-assistant | opus 級 | 帳號內最強模型 |
| doc-writer / test-runner / git-commit | sonnet 級 | 帳號內較快模型 |

> 模型名隨 Copilot 帳號可用清單而定；套用前以 `copilot help config`、`/model` 或目前 session 可用模型清單確認。
