#!/bin/bash
# Apple 行事曆 CRUD（EventKit / JXA 後端）
# osascript 把 throw 的訊息包成 "<path>: execution error: Error: Error: <訊息> (-2700)"，此處剝除外層。
# 用 fd 交換而非 process substitution：`2> >(sed …)` 需要 /dev/fd，沙箱會擋
# （症狀是 "/dev/fd/62: Operation not permitted"，且 redirection 失敗即不執行 osascript，
#  連不需要任何權限的 selftest 都跑不了）。
set -uo pipefail

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

{ osascript -l JavaScript "$DIR/cal.js" "$@" 2>&1 1>&3 3>&- \
    | sed -e 's/^.*execution error: Error: \(Error: \)\{0,1\}//' -e 's/ (-[0-9]\{1,\})$//' >&2
  exit "${PIPESTATUS[0]}"
} 3>&1
