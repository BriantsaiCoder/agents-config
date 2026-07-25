#!/bin/bash
# DEPRECATED：改用 hooks/install-hooks.sh（同時裝 pre-commit + post-checkout）。
# 本檔保留是因為 hooks/pre-commit-agents.sh 的註解指向它；只裝 pre-commit 會漏掉
# post-checkout 的分支漂移警告。
# 新機器 clone 後執行：bash hooks/install-hooks.sh

set -euo pipefail
printf 'note: install-pre-commit.sh 已由 install-hooks.sh 取代（後者另裝 post-checkout）\n' >&2

REPO_ROOT="$(git rev-parse --show-toplevel)"
SRC="$REPO_ROOT/hooks/pre-commit-agents.sh"
DST="$REPO_ROOT/.git/hooks/pre-commit"

[[ -f "$SRC" ]] || { echo "錯誤：找不到 $SRC" >&2; exit 1; }
mkdir -p "$REPO_ROOT/.git/hooks"
cp "$SRC" "$DST"
chmod +x "$DST"
echo "已安裝 pre-commit hook → $DST"
