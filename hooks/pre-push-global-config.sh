#!/usr/bin/env bash
# [INT-10] Git 已解析 remote ref 後，拒絕直接更新受保護 repo 的 main/master。
set -u

while IFS=' ' read -r _local_ref _local_oid remote_ref _remote_oid; do
  case "$remote_ref" in
    refs/heads/main|refs/heads/master)
      printf '[INT-10] 拒絕直接 push %s；請改走 Ready PR 與 bot-review gate。\n' "$remote_ref" >&2
      exit 1
      ;;
  esac
done

exit 0
