#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

REPO="$TMP/agents"
WT_ROOT="$TMP/worktrees"
git init -q -b main "$REPO"
git -C "$REPO" config user.name test
git -C "$REPO" config user.email test@example.invalid
printf 'baseline\n' > "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -qm baseline
head=$(git -C "$REPO" rev-parse HEAD)

AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" codex/isolation-test >/dev/null

[ "$(git -C "$REPO" branch --show-current)" = main ]
[ "$(git -C "$REPO" rev-parse HEAD)" = "$head" ]
WT="$WT_ROOT/codex/isolation-test"
[ "$(git -C "$WT" branch --show-current)" = codex/isolation-test ]
[ "$(git -C "$WT" rev-parse HEAD)" = "$head" ]

AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" --done codex/isolation-test >/dev/null
[ ! -d "$WT" ]

# ── --done 的失敗訊息：依「實際留下什麼」分辨後果，不寫死猜測 ──
# 舊版對所有失敗都印同一句「有未提交變更？加 --force」。2026-08-01 實測踩到的真因是沙箱擋住
# .git/worktrees/ 的刪除，目錄其實已移除成功——歸因錯誤（與變更無關），且暗示什麼都沒發生
# （實際已半完成）。正確的下一步是 git worktree prune，不是 --force。
run_done() {
  AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
    bash "$ROOT/bin/agents-branch" --done "$1" 2>&1
}

# 情境 A：目錄仍在（未提交變更）→ 必須轉述 git 原因，且不得宣稱已移除。
AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" codex/dirty-test >/dev/null
printf 'uncommitted\n' > "$WT_ROOT/codex/dirty-test/scratch.txt"
git -C "$WT_ROOT/codex/dirty-test" add scratch.txt
out=$(run_done codex/dirty-test) && { echo "FAIL: 髒 worktree 竟然成功移除"; exit 1; }
case "$out" in
  *'git worktree remove 回報失敗'*) ;;
  *) echo "FAIL: 未轉述 git 的失敗（實得：$out）"; exit 1 ;;
esac
case "$out" in
  *'worktree 目錄仍在'*) ;;
  *) echo "FAIL: 未指出目錄仍在（實得：$out）"; exit 1 ;;
esac
[ -d "$WT_ROOT/codex/dirty-test" ] || { echo "FAIL: 失敗後目錄不該消失"; exit 1; }

# 情境 B：目錄已消失但登記仍在（半完成）→ 必須指向 git worktree prune，
# 且**不得**把原因說成未提交變更。
AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" codex/half-test >/dev/null
rm -rf "$WT_ROOT/codex/half-test"
mkdir -p "$WT_ROOT/codex/half-test"   # 讓 -d 檢查通過，模擬「登記還在、內容已毀」
out=$(run_done codex/half-test) || true
case "$out" in
  *'未提交變更'*) echo "FAIL: 半完成情境不得歸因為未提交變更（實得：$out）"; exit 1 ;;
esac

echo "agents-branch isolated worktree PASS"
echo "agents-branch --done 失敗訊息 PASS"
