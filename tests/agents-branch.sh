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
#
# 用注入的假 git 觸發，不是靠 rm + mkdir 擺弄真實狀態。這個分支的前提是「remove 失敗，但目錄
# 已經沒了」——真實 git 不會那樣結束（實測踩到時是沙箱擋住 .git/worktrees/ 的刪除才造成），
# 拿 mkdir 把目錄建回來只會讓 remove 直接成功，測試整段空轉卻仍然 PASS。
# 假 git 只攔 worktree remove／list 兩個子命令，其餘一律轉給真 git。
FAKEBIN=$(mktemp -d "${TMPDIR:-/tmp}/agents-branch-fake.XXXXXX")
cat > "$FAKEBIN/git" <<'FAKE'
#!/usr/bin/env bash
set -u
# 攔截的兩個子命令都自己結束，不轉交真 git。轉交會讓真 git 的輸出與替身輸出交錯，測試結果
# 因此取決於緩衝與 exec 的時序（實測過：同一段程式在管線下時而命中時而不命中）。測試替身要
# 決定性，不要真實性。
if [[ "${1:-} ${2:-}" == "worktree remove" ]]; then
  rm -rf "$3"                                  # 目錄真的消失
  echo "fatal: 模擬 metadata 清理被擋" >&2
  exit 1                                       # 但回報失敗＝半完成
elif [[ "${1:-} ${2:-}" == "worktree list" ]]; then
  printf 'worktree %s\n' "${FAKE_STILL_REGISTERED:-}"
  exit 0
fi
exec /usr/bin/git "$@"                          # 其餘轉給真 git
FAKE
chmod +x "$FAKEBIN/git"

AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" codex/half-test >/dev/null
HALF="$WT_ROOT/codex/half-test"
out=$(PATH="$FAKEBIN:$PATH" FAKE_STILL_REGISTERED="$HALF" \
  AGENTS_HOME="$REPO" AGENTS_WORKTREE_ROOT="$WT_ROOT" \
  bash "$ROOT/bin/agents-branch" --done codex/half-test 2>&1) && \
  { echo "FAIL: 半完成情境不該回報成功"; exit 1; }
[ ! -d "$HALF" ] || { echo "FAIL: 假 git 未真的移除目錄，情境 B 沒被觸發"; exit 1; }
case "$out" in
  *'git worktree prune'*) ;;
  *) echo "FAIL: 半完成未指向 git worktree prune（實得：$out）"; exit 1 ;;
esac
# 鎖舊版那句誤導的原文「有未提交變更？」，不是裸字串「未提交變更」——新訊息裡有「非未提交
# 變更」這個否定句，裸字串會把正確的訊息判成失敗（本檔第一版正是這樣假紅的）。
case "$out" in
  *'有未提交變更？'*) echo "FAIL: 半完成情境不得歸因為未提交變更（實得：$out）"; exit 1 ;;
esac
rm -rf "$FAKEBIN"

echo "agents-branch isolated worktree PASS"
echo "agents-branch --done 失敗訊息 PASS"
