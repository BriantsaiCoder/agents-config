#!/usr/bin/env bash
# 把 apple-calendar 的 selftest 接進 bin/ci-local 的 local-only gate。
#
# 為什麼存在（2026-08-31）：cal.sh selftest 的 34 條斷言原本只有人工打指令才跑得到，
# 改壞 parseISO／parseFlags／validateRecurrence 不會有任何東西變紅——這個 skill 的
# 三個防呆（授權硬閘、旗標白名單、重複事件定址）全都靠那些純函式。
#
# 為什麼不進 ci.yml：GitHub runner 是 ubuntu，沒有 osascript。ci-local 會把
# 「tests/*.sh 而未被 ci.yml 引用者」自動歸為 local-only gate 並實際執行
# （bin/ci-local 的 excluded_by 分支），這支正好符合，不需要額外註冊。
#
# selftest 本身是純函式、不碰行事曆資料、也不需要 EventKit 權限，所以在沙箱內
# 與未授權的機器上都能跑完（授權狀態只當 info 印出，不影響 exit code）。
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
SKILLS_DIR="${SKILLS_ROOT:-$ROOT/skills}"
SKILL="$SKILLS_DIR/apple-calendar"

[ "$#" -eq 0 ] || {
  printf 'usage: %s\n' "$0" >&2
  exit 2
}

fail=0
checked=0

# 結構：主入口、JXA 本體與四個子命令包裝都要在 scripts/ 下，且 .sh 要可執行。
# 放 scripts/ 是 payload 慣例——SKILL.md 用反引號引用 scripts/… 時，
# tests/relative-references.sh 才會把它們納入存在性檢查。
for f in cal.sh cal.js cal-add.sh cal-edit.sh cal-list.sh cal-delete.sh; do
  checked=$((checked + 1))
  if [ ! -f "$SKILL/scripts/$f" ]; then
    printf 'FAIL  missing payload: scripts/%s\n' "$f" >&2
    fail=$((fail + 1))
    continue
  fi
  case "$f" in
    *.sh)
      [ -x "$SKILL/scripts/$f" ] || {
        printf 'FAIL  not executable: scripts/%s\n' "$f" >&2
        fail=$((fail + 1))
      }
      ;;
  esac
done

# 主入口不得叫 cal——/usr/bin/cal 是 macOS 內建月曆指令，安裝成 ~/bin/cal 會讓
# 所有子命令被系統指令攔截，且刪除指令靜默不執行。
checked=$((checked + 1))
[ ! -e "$SKILL/scripts/cal" ] || {
  printf 'FAIL  scripts/cal collides with /usr/bin/cal; entry point must not be named cal\n' >&2
  fail=$((fail + 1))
}

if ! command -v osascript >/dev/null 2>&1; then
  [ "$fail" -eq 0 ] || exit 1
  printf 'SKIP  apple-calendar selftest: osascript 不可用（非 macOS host）；%d 項結構檢查已通過\n' "$checked"
  exit 0
fi

checked=$((checked + 1))
if ! selftest_out=$("$SKILL/scripts/cal.sh" selftest 2>&1); then
  printf 'FAIL  cal.sh selftest 非零退出\n%s\n' "$selftest_out" >&2
  fail=$((fail + 1))
elif ! printf '%s\n' "$selftest_out" | grep -q '^SELFTEST PASS$'; then
  printf 'FAIL  cal.sh selftest 未回報 SELFTEST PASS\n%s\n' "$selftest_out" >&2
  fail=$((fail + 1))
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS  apple-calendar: %d 項結構檢查 + cal.sh selftest\n' "$checked"
