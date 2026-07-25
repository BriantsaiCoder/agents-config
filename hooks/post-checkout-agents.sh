#!/usr/bin/env bash
# post-checkout 守護：離開 main 時警告「三家 host 讀到的東西已經不一致」。
# 安裝：bash hooks/install-hooks.sh
#
# 為什麼需要這個：~/.agents 是三家 host 的共用正本，但兩半的生效機制不同——
#   Claude       ~/.claude/skills/* 是 symlink 指回 ~/.agents/skills/
#                → 切分支的**那一瞬間**就變了，不需任何指令
#   Codex/Copilot ~/.codex/AGENTS.md、~/.copilot/copilot-instructions.md 是生成的部署檔
#                → 不動，直到有人跑 agents-sync
# 所以切分支不是「內容變舊」，而是三家進入**互相矛盾**的狀態，而 manifest 檢查仍會
# 顯示「相符」（它只證明部署檔沒被手改，證明不了對應哪個 commit）。
#
# 本 hook 只警告、不自動修。自動跑 agents-sync 會讓狀態變一致，但也讓「切到過時分支
# → 全域 agent 設定靜默回退」變得完全無聲——一致的錯比不一致的錯更難發現。
#
# 一律 exit 0：守護絕不阻斷 checkout。

[ "${3:-0}" = "1" ] || exit 0   # $3=1 才是分支切換（0 = 單檔 checkout）

# linked worktree 內保持靜音：那是建議的分支工作方式，沒有 host 讀 worktree 路徑。
gitdir="$(git rev-parse --git-dir 2>/dev/null)" || exit 0
common="$(git rev-parse --git-common-dir 2>/dev/null)" || exit 0
[ "$gitdir" = "$common" ] || exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || exit 0
[ "$branch" = "main" ] && exit 0
[ "$branch" = "HEAD" ] && exit 0   # detached（rebase / bisect 途中）不吵

cat >&2 <<EOF

⚠ agents-sync：目前在分支 ${branch}（非 main），而這是三家 host 實際讀取的工作目錄。

  Claude        已經在讀 ${branch} 的 skills（symlink 即時生效）
  Codex/Copilot 仍在讀上次部署的組裝體 —— 兩邊現在不一致

  對齊：  ~/.agents/bin/agents-sync            （部署檔跟上 ${branch}）
  還原：  git -C ~/.agents switch main && ~/.agents/bin/agents-sync
  查狀態：~/.agents/bin/agents-sync --doctor   （出處戳記那節會標 STALE）

  建議改用 worktree 做分支工作，讓 host 永遠只讀 main：
      ~/.agents/bin/agents-branch ${branch}

EOF
exit 0
