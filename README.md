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
~/.agents/bin/agents-branch --done <branch>     # 收 worktree，分支保留
~/.agents/bin/agents-branch --merged <branch>   # PR 合併後：worktree + local + remote
```

PR 合併後用 `--merged` 而不是 `gh pr merge --delete-branch`：後者在 worktree 流程下必定失敗（local 分支被 worktree 佔用，gh 中止後連 remote 也不刪）。`--merged` 會先用 `gh` 確認 PR 為 `MERGED`，確認不了就拒絕。

每台機器先執行一次 `bash hooks/install-hooks.sh`。`post-checkout` 只在 live checkout 離開 `main` 時警告 shared-skills drift；linked worktree 內保持安靜。

`~/.agents` 與三個 host global-config repo 的 `[INT-10]` safety rail 另以明示模式安裝：

```sh
bash hooks/install-hooks.sh --global-pre-push
```

安裝與升級只接受已同步 `origin/main` 的部署檔；installer 與 hook 的實際 bytes 都必須等於 `HEAD`。

`pre-push` 只檢查 Git 已解析的 remote ref，任一目標為 `refs/heads/main` 或 `refs/heads/master` 即拒絕整批 push。這是 client-side safety rail，不是不可繞過的 security boundary：未安裝時不生效，`--no-verify` 或改寫 `core.hooksPath` 可略過；Git 2.55.0 實測 `--mirror` 的隱式刪除可能不出現在 hook stdin。使用者當下明示直接 push 才可使用 bypass。

Installer 以 sidecar hash 辨識先前管理的版本，因此可安全升級或 rollback；內容與 managed hash 都不符的既有 hook 一律拒絕覆寫或刪除。Rollback 會移除原 default hooks 目錄中的 managed hook，即使之後另設 `core.hooksPath`：

```sh
bash hooks/install-hooks.sh --remove-global-pre-push
```

## Verification

```sh
bash tests/three-host-global-config-ownership.sh
AGENTS_HOME="$PWD" bash tests/agents-branch.sh
bash tests/conformance.sh
```

Host global config 由各 host repo 的 tests 驗證，不由本 repo 代驗或改寫。書寫規範見 [CONVENTIONS.md](CONVENTIONS.md)；ownership migration 設計見 `proposals/2026-07-27-mattpocock-skills-workflow/48-three-host-global-config-ownership-split-plan.md`。
