#!/usr/bin/env bash
# DEPRECATED shim：改用 hooks/install-hooks.sh（同時裝 pre-commit + post-checkout）。
#
# 本檔不再自行實作安裝，直接委派——重複實作路徑邏輯就會漂移，而且它已經漂移過一次：
# 舊版自己拼 "$(git rev-parse --show-toplevel)/.git/hooks"，在 linked worktree 裡
# .git 是**檔案**不是目錄，mkdir 報 "Not a directory" 並在 set -e 下死掉；使用者會
# 以為裝好了其實沒裝。正確做法是問 git（`--git-path hooks`），已在 install-hooks.sh
# 實作為單一正本。
#
# 副作用（刻意）：本檔現在會**一併安裝 post-checkout**（分支漂移警告）。只裝
# pre-commit 會漏掉那道守護。
set -euo pipefail

printf 'note: install-pre-commit.sh 已由 install-hooks.sh 取代，改為委派執行（會一併裝 post-checkout）\n' >&2
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/install-hooks.sh" "$@"
