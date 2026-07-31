#!/usr/bin/env bash
#
# bin/hook-parity-check 的回歸測試。全部用 fixture，不讀也不動真實 host 目錄——
# CI runner 上沒有 ~/.claude / ~/.codex，真實路徑在那裡必然缺席。
#
# 為什麼要有這支：CONVENTIONS 規則 9 —— 可機械化的檢查必須下沉為機械守護。
# parity 本身只能在本機比（CI 無 ~/.agents），但 parity 檢查器的「邏輯」可以在 CI 驗。
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
CHECK="$ROOT/bin/hook-parity-check"

pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

[ -x "$CHECK" ] ||
  { printf 'FAIL  bin/hook-parity-check 不可執行——呼叫端用 [ -x ] 判斷，非 executable 等於防線靜默失效\n'; exit 1; }
ok 'hook-parity-check 有 exec bit（呼叫端的 [ -x ] gate 才會成立）'

tmp=$(mktemp -d "${TMPDIR:-/tmp}/hook-parity.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/agents/hooks" "$tmp/hostA/hooks" "$tmp/hostB/hooks" "$tmp/absent"
printf '#!/usr/bin/env bash\n# [T0-3] fixture guard\nexit 0\n' > "$tmp/agents/hooks/guard-git-push.sh"
cp "$tmp/agents/hooks/guard-git-push.sh" "$tmp/hostA/hooks/guard-git-push.sh"
cp "$tmp/agents/hooks/guard-git-push.sh" "$tmp/hostB/hooks/guard-git-push.sh"

run() { AGENTS_HOME="$1" PARITY_COPIES="$2" bash "$CHECK" ${3:-} 2>&1; }
rc()  { AGENTS_HOME="$1" PARITY_COPIES="$2" bash "$CHECK" ${3:-} >/dev/null 2>&1; printf '%s' "$?"; }

both="$tmp/hostA/hooks/guard-git-push.sh $tmp/hostB/hooks/guard-git-push.sh"

# 1. 三份一致 → 無輸出、strict 回 0
[ -z "$(run "$tmp/agents" "$both")" ] && ok '一致時無輸出' || ng '一致時無輸出'
[ "$(rc "$tmp/agents" "$both" --strict)" = 0 ] && ok '一致時 strict 回 0' || ng '一致時 strict 回 0'

# 2. 一份漂移 → 報 drift、strict 回 1、非 strict 仍回 0（非阻擋）
printf '# drifted\n' >> "$tmp/hostB/hooks/guard-git-push.sh"
run "$tmp/agents" "$both" | grep -q '副本已漂移' && ok '漂移被偵測' || ng '漂移被偵測'
[ "$(rc "$tmp/agents" "$both" --strict)" = 1 ] && ok '漂移時 strict 回 1' || ng '漂移時 strict 回 1'
[ "$(rc "$tmp/agents" "$both")" = 0 ] && ok '漂移時非 strict 仍回 0（不阻擋 SessionStart）' || ng '漂移時非 strict 仍回 0'

# 3. host 目錄存在但 guard 缺失 → 算 drift（防線消失是最嚴重的漂移）
rm -f "$tmp/hostB/hooks/guard-git-push.sh"
run "$tmp/agents" "$both" | grep -q '副本缺失' && ok 'guard 缺失被偵測' || ng 'guard 缺失被偵測'
[ "$(rc "$tmp/agents" "$both" --strict)" = 1 ] && ok 'guard 缺失時 strict 回 1' || ng 'guard 缺失時 strict 回 1'

# 4. host root 存在但 hooks/ 整個消失 → 仍算 drift
rmdir "$tmp/hostB/hooks"
run "$tmp/agents" "$both" | grep -q '副本缺失' && ok 'hooks 目錄缺失被偵測' || ng 'hooks 目錄缺失被偵測'
[ "$(rc "$tmp/agents" "$both" --strict)" = 1 ] && ok 'hooks 目錄缺失時 strict 回 1' || ng 'hooks 目錄缺失時 strict 回 1'

# 5. host 目錄不存在 → 該 host 未安裝，合法跳過
absent="$tmp/hostA/hooks/guard-git-push.sh $tmp/uninstalled/hooks/guard-git-push.sh"
[ "$(rc "$tmp/agents" "$absent" --strict)" = 0 ] &&
  ok '未安裝的 host 不算漂移' || ng '未安裝的 host 不算漂移'

# 6. 正本不存在 → 必須報，不得靜默通過
run "$tmp/absent" "$both" | grep -q '正本不存在' && ok '正本缺失被偵測' || ng '正本缺失被偵測'
[ "$(rc "$tmp/absent" "$both" --strict)" = 1 ] && ok '正本缺失時 strict 回 1' || ng '正本缺失時 strict 回 1'

# 刻意不在此斷言呼叫端（~/.claude、~/.codex 的 drift-check.sh）是否以 [ -x ] 守護：
# 那是 host 擁有的檔案，~/.agents 的 test 不跨進去——與 tests/mattpocock-workflow.sh
# 移除 core/tier1-workflow.md 斷言的同一條 ownership 邊界。該斷言已下沉到各 host repo
# 自己的 test（~/.claude/tests/repo-integrity.sh、~/.codex 與 ~/.copilot 的
# tests/global-config-ownership.sh），CI 環境本來也讀不到那些檔。

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
