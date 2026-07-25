#!/usr/bin/env bash
# Codex 端 [T0-3] guard —— 薄 wrapper，判定邏輯在共用正本 guard-git-push.sh。
# 保留本檔名是因為 ~/.codex/hooks.json 指向它；改共用正本即兩 host 同步生效。
exec bash "$(dirname "$0")/guard-git-push.sh" --format=codex
