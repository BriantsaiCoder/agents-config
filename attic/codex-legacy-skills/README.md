<!-- status: archived | archived-at: 2026-07-08 | source: ~/.codex/skills/ | finding: F10 (proposals/2026-07-08-post-unification-audit) -->

# codex-legacy-skills — ~/.codex/skills/ 清點歸檔紀錄

> 讀者是 AI 模型。F10：`~/.codex/skills/` 在 agents-sync 視野外，殘留物無人巡檢。本檔記錄 2026-07-08 清點的完整處置決策，後續巡檢以此為基準。

## 歸檔（移入本目錄）

| skill | 原因 |
|---|---|
| `migrate-to-codex` | 一次性遷移工具，三家統一層（~/.agents）建成後任務已完成；19 檔含過時的遷移指引，留在 live 目錄會誤導 Codex 路由 |

## 就地刪除

| 項目 | 原因 |
|---|---|
| `codex-primary-runtime/` | 空目錄（0 檔），無內容可歸檔 |

## 保留於 ~/.codex/skills/（勿再重複清查）

| skill | 保留原因 |
|---|---|
| `architecture-html-doc` | **仍在役**：dev-workflow SKILL.md 宣告其「退役轉衍生物」角色——產出物由 ARCHITECTURE.md Mermaid 衍生，skill 本體仍被引用。勿歸檔 |
| `chronicle` | 第三方（Chronicle app）功能性 skill，提供 screen viewing；歸檔會破壞該 app 整合。out-of-scope |
| `codex-dynamic-workflows` | Codex 專屬 workflow 機制，live 使用中 |
| `pdf`、`playwright` | 功能性工具 skill，跨任務通用 |
| `security-ownership-map` | live 使用中 |

## 制度教訓

- host 專屬 skill 目錄（`~/.codex/skills/`、`~/.copilot/…`）不在 agents-sync 部署管線內，屬「手寫層」——清點週期併入 CONVENTIONS 巡檢，或在 `agents-sync --doctor` 加提示句（已於 2026-07-08 doctor 擴充中實作）。
- 歸檔優於刪除：本目錄保留完整原始檔，rollback = `mv` 回去。
