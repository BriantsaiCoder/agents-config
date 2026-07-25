#!/usr/bin/env bash
# 安裝本 repo 的 git hooks 到 .git/hooks/（不變動 git config）。
# 新機器 clone 後執行：bash hooks/install-hooks.sh
#
# 安裝的 hook：
#   pre-commit    ← hooks/pre-commit-agents.sh
#   post-checkout ← hooks/post-checkout-agents.sh（離開 main 時警告三家 host 不一致）
#
# 注意：hooks 存在 .git/hooks/ 而 .git 不進版控，所以這是**每台機器各自要跑一次**的
# 安裝步驟，不是自動生效的。linked worktree 共用 common dir 的 hooks，無需重裝。
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
mkdir -p "$REPO_ROOT/.git/hooks"

install_one() {
  local src="$REPO_ROOT/hooks/$1" dst="$REPO_ROOT/.git/hooks/$2"
  [ -f "$src" ] || { echo "錯誤：找不到 $src" >&2; return 1; }
  cp "$src" "$dst"
  chmod +x "$dst"
  echo "已安裝 $2 → $dst"
}

install_one pre-commit-agents.sh    pre-commit
install_one post-checkout-agents.sh post-checkout
