#!/usr/bin/env bash
# Shared-skills drift warning. Host global config is checked by each host repo.
#
# 本檔沒有任何 host 會執行——三家跑的是自己目錄下的同名檔（探針：
# `jq -r '.hooks.SessionStart[].hooks[].command' ~/.codex/hooks.json` → $HOME/.codex/…；
# `~/.claude/settings.json` 的 SessionStart 同理）。所以 [T0-3] guard 的 parity 檢查
# 刻意不寫在這裡：那兩份 host-local drift-check.sh 各自呼叫 bin/hook-parity-check，
# 在這裡再加一份呼叫只會變成第三份會漂移的副本——正是那支 helper 要治的問題。
# 邏輯與回歸測試：bin/hook-parity-check、tests/hook-parity.sh。

out="$("$HOME/.agents/bin/agents-sync" --doctor 2>&1)"
[ "$?" -eq 0 ] ||
  printf 'shared skills：偵測到 source／Claude skill-link 異常——\n%s\n' "$out" >&2

exit 0
