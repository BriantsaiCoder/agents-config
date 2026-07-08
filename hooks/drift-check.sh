#!/usr/bin/env bash
# SessionStart drift 守護：跑 agents-sync --doctor（偵測部署檔漂移 / override 復活 / skills 斷鏈）。
# 無漂移時完全安靜（避免每 session 洗版造成告警疲勞）；偵測到才把完整 doctor 輸出丟 stderr。
# 一律 exit 0：守護只告警、絕不阻斷 session 啟動。
out="$("$HOME/.agents/bin/agents-sync" --doctor 2>&1)"
[ "$?" -eq 0 ] || printf 'agents-sync：偵測到設定漂移（正本 ~/.agents 與部署檔不一致）——\n%s\n' "$out" >&2
exit 0
