# Copilot CLI 設定範本 — 為何不用 Claude-style settings 範本

Claude 的 `.claude/settings.json` 用 `permissions.allow/deny` + `sandbox.network.allowedDomains` 做專案層的工具放行與沙箱網路控制。Copilot CLI 有 `.github/copilot/settings.json` 與個人 override `.github/copilot/settings.local.json`，但只接受官方限定的 supported keys，**沒有對等的專案 permissions/sandbox schema**：

- `.github/copilot/settings.json` 可 commit；`.github/copilot/settings.local.json` 必須 gitignore，兩者都只寫官方 supported keys。
- `~/.copilot/settings.json` 屬於 home dir 使用者設定，不是可攜的專案 permissions/sandbox policy。
- 工具放行/封鎖走 `--allow-tool` / `--deny-tool` flag(per-session,不持久化到 repo)或互動式核准。
- `trustedFolders` 由 CLI 自管,不該手動寫。

因此 Copilot host 的 Phase 2 先增量更新 `.github/copilot/settings.json`／`.github/copilot/settings.local.json` 中官方支援的 keys；Claude-style `deny`／sandbox mapping 才改以 `.github/hooks/*.json` 的 `preToolUse` hook 落地。

## Claude settings → Copilot 產物對照

| Claude `<stack>.json` 區塊 | Copilot 對等產物 |
|---|---|
| `permissions.deny[]`（如 `Bash(dotnet nuget push *)`、`docker rm *`） | `.github/hooks/guard-commands.json` —— `preToolUse` hook，不依賴固定 matcher；腳本從 stdin payload 解析 command 並對 stdout 寫 `{"decision":"deny"}` |
| `permissions.allow[]`（套件快取讀寫路徑） | 不需要——Copilot 對 workspace 內讀寫不需額外放行 |
| `sandbox.network.allowedDomains[]` | 無對等專案設定;若使用者要全域放行 URL 抓取,可在 `~/.copilot/settings.json` 加 `allowedUrls`,但這非沙箱網路、且屬全域 → 僅作為「告知使用者」的建議,不自動寫 |
| `sandbox.enabled` / `autoAllowBashIfSandboxed` | Copilot CLI 內建沙箱,無 repo 設定鍵 → 略過 |

結論：Phase 2 可能同時更新 supported settings 與 guard hook；只有各 stack `claude/<stack>.json` 的 `deny` 清單（含 `docker-addon.json`）會合併成一份指令黑名單。

## Worked example — `.github/hooks/guard-commands.json`

對 dotnet stack(`deny` = `Bash(dotnet nuget push *)`)+ docker addon:

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "command": ".github/hooks/scripts/guard-commands.sh"
      }
    ]
  }
}
```

`guard-commands.sh` 應沿用 `references/hooks/protect-files.sh` 的 input shim 思路：讀取 stdin JSON，優先用 `jq -r '.tool_input.command // .command // empty'` 解析 command；解析不到 command 時直接 allow。不要使用 `matcher: "shell"`，因為 Copilot runtime 的 tool id 版本敏感，固定 matcher 可能讓 hook 完全不觸發。

## 各 stack 的指令黑名單

取自對應 `../claude/<stack>.json` 的 `permissions.deny`:

| stack | 封鎖指令 |
|---|---|
| dotnet-*（webapi/console/worker/winforms/library/framework） | `dotnet nuget push` |
| nodejs-express / frontend | `npm publish` |
| rust | `cargo publish` |
| python / go | （無 deny → 不需 guard hook） |
| docker-addon（疊加） | `docker rm`、`docker rmi`、`docker system prune`、`docker volume rm` |

## hook 事件名

Copilot `.github/hooks/*.json` 的 `hooks` 物件用 **camelCase** 事件鍵(`preToolUse`、`postToolUse`、`sessionStart`、`preCompact`、`notification`、`agentStop` 等);payload 內的 `hook_event_name` 才是 PascalCase。詳見 `references/host-matrix.md`。
