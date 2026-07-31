# ~/.agents — 三主機 shared skills data plane

> Claude、Codex、Copilot 共用 `skills/` 的 workflow 實作；各 host 自己擁有 global routing／governance control plane。

## Ownership

| Surface | Owner | Role |
|---|---|---|
| `~/.agents/skills/**` | `~/.agents` | 三家共用的 Matt Pocock skills 與本機 workflow skills |
| `~/.claude/CLAUDE.md`、`core/`、`rules/`、`hooks/` | `~/.claude` | Claude routing、governance 與 host adapter |
| `~/.codex/AGENTS.md`、`rules/`、`hooks/` | `~/.codex` | Codex routing、governance 與 host adapter |
| `~/.copilot/copilot-instructions.md`、`rules/`、`hooks/` | `~/.copilot` | Copilot routing、governance 與 host adapter |

`attic/core/`、`attic/rules/`、`attic/hosts/`、`attic/dist/` 只保留作 rollback／historical evidence（`git log --follow` 可追）。Root `hooks/` 服務本 repo 的 Git／CI 與 host-copy parity；它不是 host global-config source。`agents-sync` 也不再生成或部署 host config；active 面不得再出現 `core/`、`rules/`、`hosts/`、`dist/`，由 `tests/three-host-global-config-ownership.sh` 把關。

## Shared skills visibility

- Codex／Copilot 原生讀取 `~/.agents/skills`。
- Claude 的 `~/.claude/skills/*` 是 `../../.agents/skills/*` 相對 symlink。
- `~/.agents` live checkout 必須留在 `main`；在此切 branch 會同時改變三家看到的 shared skills。

```sh
~/.agents/bin/agents-sync --check      # 驗 shared skills source
~/.agents/bin/agents-sync --doctor     # 再驗已初始化的 Claude skill links
~/.agents/bin/agents-sync --bootstrap  # 只重建 Claude skill links
```

無參數、`--deploy`、`--only` 已退役並會 fail-loud；這些介面不讀寫任何 host global config。

## Branch work

使用 linked worktree，讓 live `~/.agents` 固定在 `main`：

```sh
~/.agents/bin/agents-branch <branch>
~/.agents/bin/agents-branch --list
~/.agents/bin/agents-branch --done <branch>
```

每台機器先執行一次 `bash hooks/install-hooks.sh`。`post-checkout` 只在 live checkout 離開 `main` 時警告 shared-skills drift；linked worktree 內保持安靜。

## Verification

```sh
bash tests/three-host-global-config-ownership.sh
AGENTS_HOME="$PWD" bash tests/agents-branch.sh
bash tests/conformance.sh
```

Host global config 由各 host repo 的 tests 驗證，不由本 repo 代驗或改寫。書寫規範見 [CONVENTIONS.md](CONVENTIONS.md)；ownership migration 設計見 `proposals/2026-07-27-mattpocock-skills-workflow/48-three-host-global-config-ownership-split-plan.md`。
