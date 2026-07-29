#!/usr/bin/env bash
# Shared-skills drift warning. Host global config is checked by each host repo.

out="$("$HOME/.agents/bin/agents-sync" --doctor 2>&1)"
[ "$?" -eq 0 ] ||
  printf 'shared skills：偵測到 source／Claude skill-link 異常——\n%s\n' "$out" >&2

# [T0-3] guard 三份副本的一致性；邏輯在 bin/hook-parity-check（見該檔說明為何
# 不放本目錄）。注意本檔沒有任何 host 會執行——三家跑自己目錄下的 drift-check.sh，
# 那兩份各自呼叫同一支 bin/hook-parity-check。本行只讓本檔與它們保持同構。
# 存在性檢查是必要的：host 副本可能比這支 helper 先部署（本次即是），缺檔時
# 靜默跳過，不得讓 SessionStart 噴錯。
if [ -x "$HOME/.agents/bin/hook-parity-check" ]; then
  bash "$HOME/.agents/bin/hook-parity-check" || true
fi

exit 0
