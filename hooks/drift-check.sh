#!/usr/bin/env bash
# Shared-skills drift warning. Host global config is checked by each host repo.
#
# 本檔沒有 host 會執行。Claude／Codex 跑各自目錄下的同名檔；Copilot 沒有同名 hook。探針：
# `jq -r '.hooks.SessionStart[].hooks[].command // empty' ~/.claude/settings.json` → `bash ~/.claude/hooks/drift-check.sh`
# `jq -r '.hooks.SessionStart[].hooks[].command // empty' ~/.codex/hooks.json` → `bash "$HOME/.codex/hooks/drift-check.sh"`
# `test ! -e ~/.copilot/hooks/drift-check.sh` → exit 0。故 [T0-3] parity 檢查刻意不寫在這裡：
# Claude／Codex 的 host-local drift-check.sh 各自呼叫 bin/hook-parity-check，
# `rg -n 'bin/hook-parity-check' ~/.claude/hooks/drift-check.sh ~/.codex/hooks/drift-check.sh` → 兩個路徑皆至少一行命中。
# 在這裡再加一份呼叫只會變成第三份會漂移的副本——正是那支 helper 要治的問題。
# 邏輯與回歸測試：bin/hook-parity-check、tests/hook-parity.sh。

out="$("$HOME/.agents/bin/agents-sync" --doctor 2>&1)"
[ "$?" -eq 0 ] ||
  printf 'shared skills：偵測到 source／Claude skill-link 異常——\n%s\n' "$out" >&2

exit 0
