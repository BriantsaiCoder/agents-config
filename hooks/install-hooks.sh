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

# hooks 目錄一律問 git，不要自己拼 "$(git rev-parse --show-toplevel)/.git/hooks"：
# 在 linked worktree 裡 .git 是**檔案**不是目錄（內容為 gitdir 指標），自己拼的路徑
# 會讓 mkdir 報 "Not a directory" 並在 set -e 下直接死掉。
# `--git-path hooks` 兩種情形都對，且在 worktree 內回傳共用的 common dir hooks
# （實測：worktree 內回傳 ~/.agents/.git/hooks，正是 git 實際會執行的位置）。
HOOKS_DIR="$(cd "$(git rev-parse --show-toplevel)" && git rev-parse --git-path hooks)"
SRC_DIR="$(git rev-parse --show-toplevel)/hooks"
mkdir -p "$HOOKS_DIR"

install_one() {
  local src="$SRC_DIR/$1" dst="$HOOKS_DIR/$2"
  [ -f "$src" ] || { echo "錯誤：找不到 $src" >&2; return 1; }
  cp "$src" "$dst"
  chmod +x "$dst"
  echo "已安裝 $2 → $dst"
}

install_one pre-commit-agents.sh    pre-commit
install_one post-checkout-agents.sh post-checkout
