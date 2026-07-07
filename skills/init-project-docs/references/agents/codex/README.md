# Codex CLI — agents 轉換指南

Codex 的自訂 agent 為 TOML，放 `.codex/agents/<name>.toml`（project-scoped）或 `~/.codex/agents/<name>.toml`（personal/global）。格式與 Claude/Copilot 的 MD+YAML 差異大 → **不**沿用 `.md`，改由 SKILL.md Phase 6 套用時依本指南把每個 `../<name>.md` 轉成 TOML。**不**提供 7 個逐 agent 實體檔——body 與 `.md` 正本相同，逐檔複製易腐化。

> Schema 已查證（2026-05，OpenAI Codex 官方 docs）。套用前建議以本機 `codex` 版本 docs 比對，鍵名隨版本可能微調。

## 轉換規則（Claude `.md` → Codex `.toml`）

| Claude `.md` | Codex `.toml` |
|---|---|
| frontmatter `name` | `name = "..."` |
| frontmatter `description` | `description = "..."` |
| frontmatter `model`（`opus`/`sonnet`） | optional `model = "..."` —— 改為 Codex 可用模型名；不確定時省略並繼承 parent session |
| frontmatter `tools`（逗號分隔） | 無穩定對等 → 刪除；用 `developer_instructions` 約束 read-only / edit behavior |
| frontmatter `color` | 無對等 → 刪除 |
| body（frontmatter 以下全文） | `developer_instructions = '''...'''`（TOML 多行**字面**字串，不處理跳脫） |

body 內的 `{PROJECT_NAME}`、`{TECH_STACK}`、`{PROJECT_CONVENTIONS}`、`{SKILLS_TO_CALL}` 佔位符由 Phase 6 以 Phase 0 偵測結果填入，與 host 無關。

> body 含大量 backtick 與 Markdown → 用 `'''...'''`（literal）而非 `"""..."""`（basic），避免反斜線被當跳脫。

> Host leak guard：若原 `.md` body 提到 `.claude/rules/`、`CLAUDE.md`、或 Claude-only tool names，轉 Codex 時改成 host-neutral wording（例如「依 target host 的 rules/instruction files」）或指向 `AGENTS.md` / `.codex/*`。

## Worked example — code-reviewer

`../code-reviewer.md`（frontmatter `name/description/model: opus/color/tools: Read, Grep, Glob, Bash`）轉成 `.codex/agents/code-reviewer.toml`：

```toml
name = "code-reviewer"
description = "審查變更的程式碼品質、安全性與專案規範一致性。用於 PR review、push 前自檢、或大段修改後的驗證。"
model = "<codex-strong-model>"   # opus 級 → 帳號內最強模型

developer_instructions = '''
你是 `{PROJECT_NAME}` 專案的程式碼審查員。技術棧為 {TECH_STACK}。

## 審查流程
...（原 .md body 全文，佔位符已填入）...
'''
```

## agent 清單與 tier

| agent | tier | tools |
|---|---|---|
| code-reviewer | opus | Read, Grep, Glob, Bash |
| debug-expert | opus | Read, Edit, Bash, Grep |
| security-auditor | opus | Read, Grep, Glob, Bash |
| refactor-assistant | opus | Read, Edit, Grep, Glob |
| doc-writer | sonnet | Read, Write, Edit |
| test-runner | sonnet | Bash, Read, Grep |
| git-commit | sonnet | Bash, Read, Grep |

## 套用步驟（SKILL.md Phase 6）

1. 對使用者多選勾選的每個 agent，讀 `../<name>.md`。
2. 依上表轉換 frontmatter、填入 body 佔位符、包成 `developer_instructions = '''...'''`。
3. 預設寫入 `.codex/agents/<name>.toml`；只有使用者明確要求全域 reuse 時才寫入 `~/.codex/agents/<name>.toml`。既有同名檔先顯示 diff、不覆蓋。
4. 寫入後以 `python3 -c "import tomllib; tomllib.load(open('<file>','rb'))"` 驗 TOML 合法。

> Codex 無 path-scoped rules；rules 內容改併入 `AGENTS.md`（見 SKILL.md Phase 4 與 `references/rules/`）。
