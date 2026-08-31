#!/bin/bash
# 解析 symlink 到實際檔案位置。不用 readlink -f —— 那是 GNU 擴充，
# 舊版 macOS 的 BSD readlink 沒有，而這個 repo 會同步到別台機器。
self="${BASH_SOURCE[0]:-$0}"
while [ -L "$self" ]; do
  link=$(readlink "$self")
  case $link in /*) self=$link ;; *) self=$(dirname "$self")/$link ;; esac
done
DIR=$(cd "$(dirname "$self")" && pwd -P)
exec "$DIR/cal.sh" list "$@"
