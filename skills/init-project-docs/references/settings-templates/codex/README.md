# Codex CLI 設定範本 — TOML 轉換指南

Codex 用 `.codex/config.toml`（專案）/ `~/.codex/config.toml`（全域），格式為 TOML。本指南把 `../claude/<stack>.json` 的 Claude 設定翻成等價的 Codex TOML。**不**提供逐 stack 實體檔——12 個 stack 只差網域清單,逐檔複製易腐化;改由 SKILL.md Phase 2 套用時依本指南即時轉換。

> Schema 已查證（2026-05，OpenAI Codex 官方 docs）。套用前仍建議以本機 `codex` 版本的 docs 比對，鍵名隨版本可能微調。

## 對照規則

| Claude `<stack>.json` | Codex `config.toml` |
|---|---|
| `sandbox.enabled: true` | `sandbox_mode = "workspace-write"` |
| `sandbox.autoAllowBashIfSandboxed: true` | `approval_policy = "on-request"`（沙箱內仍會在需要時請求） |
| `sandbox.network.allowedDomains[]` | `[permissions.<name>.network.domains]` 的 `"host" = "allow"` 條目 |
| `sandbox.network.allowLocalBinding` | `[sandbox_workspace_write]` `network_access = true`（含本機綁定） |
| `permissions.allow[]`（套件快取讀寫路徑） | Codex `workspace-write` 沙箱預設可寫 workspace；額外路徑用 `[sandbox_workspace_write] writable_roots` 或 `[permissions.<name>.filesystem]` |
| `permissions.deny[]`（如 `Bash(dotnet nuget push *)`） | Codex permissions profile 無指令層 deny → 改用 `PreToolUse` / `PermissionRequest` hook 攔截 `Bash` 工具輸入（見 `references/hooks/codex/`） |

## Worked example — dotnet-webapi

`../claude/dotnet-webapi.json` 的 `allowedDomains` 為 `api.nuget.org`、`*.nuget.org`、`localhost:*`,`deny` 為 `Bash(dotnet nuget push *)`。Codex `.codex/config.toml` 的基礎設定:

```toml
sandbox_mode = "workspace-write"
approval_policy = "on-request"

[sandbox_workspace_write]
network_access = true
```

若目前 Codex docs / local config 已使用 named permissions profile，再加入下列 profile 片段；不要自行發明未驗證的 profile activation key：

```toml
[permissions.init-project-docs.filesystem]
":project_roots" = { "." = "write", "**/*.env" = "none" }

[permissions.init-project-docs.network]
enabled = true
mode = "limited"

[permissions.init-project-docs.network.domains]
"api.nuget.org" = "allow"
"*.nuget.org" = "allow"
```

`localhost:*` 由 `network_access = true` + `mode = "limited"` 涵蓋本機連線，不需列入 `domains`。`Bash(dotnet nuget push *)` 的封鎖見 hooks 階段的自訂 `PreToolUse` / `PermissionRequest` hook。

## 各 stack 的 `domains` 清單

直接取自對應 `../claude/<stack>.json` 的 `sandbox.network.allowedDomains`(去掉 `localhost:*`),逐筆轉成 `"host" = "allow"`:

| stack | domains |
|---|---|
| dotnet-webapi / dotnet-console / dotnet-worker / dotnet-winforms / dotnet-library / dotnet-framework | `api.nuget.org`、`*.nuget.org` |
| nodejs-express | `registry.npmjs.org`、`*.npmjs.org`、`registry.yarnpkg.com`、`cdn.jsdelivr.net` |
| frontend | `registry.npmjs.org`、`*.npmjs.org`、`registry.yarnpkg.com`、`cdn.jsdelivr.net`、`cdnjs.cloudflare.com`、`unpkg.com` |
| python | `pypi.org`、`files.pythonhosted.org` |
| go | `proxy.golang.org`、`sum.golang.org`、`*.golang.org`、`github.com`、`*.github.com`、`*.githubusercontent.com` |
| rust | `crates.io`、`index.crates.io`、`static.crates.io`、`github.com`、`*.github.com` |

> 以對應 `claude/<stack>.json` 為準——本表若與 JSON 不一致,信 JSON。

## docker-addon

`docker-addon.json` 只含 `deny`（`docker rm/rmi/system prune/volume rm`）。Codex 無指令層 deny → 偵測到 Docker 時，於 `references/hooks/codex/` 加一支 `PreToolUse` 或 `PermissionRequest` hook，`matcher = "^Bash$"`，腳本解析 `tool_input.command` 並阻擋 `docker rm`、`docker rmi`、`docker system prune`、`docker volume rm`。

## 合併原則

Codex TOML **不**走 `scripts/merge-settings.py`。SKILL.md Phase 2 指示 agent 用自身 Edit 工具，對既有 `config.toml` 做增量合併：`domains` 表聯集去重、`writable_roots` 聯集、不覆蓋使用者既有鍵，且**先顯示 diff 再寫入**。寫入後用 `python3 -c "import tomllib; tomllib.load(open('.codex/config.toml','rb'))"` 驗 TOML。
