#!/usr/bin/env bash
# [INT-10] 全域設定變更走 PR 路徑的規則守衛。
#
# 為什麼存在（2026-08-03）：整條 PR 路徑的每個環節本來就有規範——feature branch 在
# [INT-6]／SKILL.md「implement 在 current/main 上 commit 是禁止的」、Ready PR 在 [T1-8]、
# bot-review gate 在 references/review-triage.md、squash merge 在 [T0-9]、刪 branch 在
# references/ledgers.md:86。缺的是**入口的守門員**：沒有任何條文規定「什麼變更必須走上
# 這條路」。
#
# 後果不是理論的。[T0-9] 的觸發寫的是「merge 前」，而直接 push main 根本沒有 merge
# 動作，於是 tier0 最強的那道 gate 連同它唯一的獨立視角（bot review）可以被「不開 PR」
# 整條繞過，且不違反任何既有條文——2026-08-03 有四個全域設定 commit 就是這樣落地的：
# CI 全綠，bot review 從未產生。[INT-6] 那條 MUST NOT 管不到，因為它綁在「使用者顯式
# invoke implement」這個觸發條件上。
#
# 本測試守的是規則文字本身不被弱化，**不是** enforcement。Git-native pre-push 是
# client-side safety rail；條文必須明列未安裝、--no-verify 與 --mirror 隱式刪除的 ceiling。
#
# --selftest 對 fixture 驗兩個方向都真的會觸發。沒有它，反向斷言可以整段不執行而仍然回綠。
set -uo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd -P)}"

pass=0; fail=0
ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1" >&2; fail=$((fail + 1)); }

# [INT-10] 條文必須保有的規範性片段。分五類，缺任一類這條規則就失去它存在的理由。
# PATH_STEPS 用 `.*` 串連而非 `|`：alternation 只要命中任一步就通過，等於允許把其他四步
# 刪掉而守衛仍回綠。尤其 bot-review gate 是整條 [INT-10] 存在的理由——[T0-9] 被繞過就是
# 因為它——漏列它等於守衛守不到重點（PR #40 由 Copilot review 指出）。
PATH_STEPS='isolated branch.*Ready PR.*bot-review gate.*squash merge.*刪 branch'  # 路徑五步，全部且依序
PROHIBITION='MUST NOT 直接 push'                                       # 禁令本體
SCOPE='CLAUDE\.md|AGENTS\.md|copilot-instructions\.md|tier0|hooks|CI workflow'  # 適用範圍
CAPABILITY_SCOPE='plugin.*(install|enable|啟用).*MCP.*(install|enable|啟用).*credential.*tool'  # 新 capability surface
ESCAPE='使用者當下明示'                                                # 逃生門（無它則無法被覆寫）
HONESTY='pre-push.*未安裝.*沒有機械 enforcement.*--no-verify.*--mirror' # 不得升級為完整 enforcement 宣稱

check_kernel() {
  local file="$1" label="${2:-kernel}"
  if [ ! -r "$file" ]; then
    ng "${label}: kernel 不可讀（${file}）"
    return
  fi

  local line
  line=$(grep -E '^\- \[INT-10\]' "$file" | head -1)
  if [ -z "$line" ]; then
    ng "${label} 缺 [INT-10] 整條"
    return
  fi

  local miss=""
  printf '%s' "$line" | grep -Eq "$PATH_STEPS"  || miss="${miss} 路徑步驟"
  printf '%s' "$line" | grep -Eq "$PROHIBITION" || miss="${miss} 禁令(MUST-NOT-直接-push)"
  printf '%s' "$line" | grep -Eq "$SCOPE"       || miss="${miss} 適用範圍"
  printf '%s' "$line" | grep -Eq "$CAPABILITY_SCOPE" || miss="${miss} plugin/MCP-capability"
  printf '%s' "$line" | grep -Eq "$ESCAPE"      || miss="${miss} 例外條款"
  printf '%s' "$line" | grep -Eq "$HONESTY"     || miss="${miss} client-side-ceiling"

  if [ -n "$miss" ]; then
    ng "${label} [INT-10] 規範片段缺失:${miss}"
  else
    ok "${label} [INT-10] 五類規範片段齊備"
  fi

  # S6 必須把讀者導到 [INT-10]，否則規則寫了也沒人在收尾時看到。
  if sed -n '/^## S6 CLOSEOUT/,/^## /p' "$file" | grep -Fq '[INT-10]'; then
    ok "${label} S6 CLOSEOUT 指向 [INT-10]"
  else
    ng "${label} S6 CLOSEOUT 未指向 [INT-10]（收尾時讀不到路徑選擇規則）"
  fi
}

selftest() {
  local scratch rc=0
  scratch="$(mktemp -d)"

  cat > "${scratch}/good.md" <<'FIX'
## Always-on guards

- [INT-10] 全域設定與 security config 的變更 MUST 走 PR 路徑：isolated branch → Ready PR → bot-review gate → squash merge → 刪 branch；MUST NOT 直接 push 到 main／master。範圍：三 host 入口檔（`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.copilot/copilot-instructions.md`）、tier0、kernel 與其 references、hooks 與 permission settings、CI workflow，以及 plugin install／enable、MCP 啟用、新 credential 或 external tool capability。Git-native pre-push 是 client-side safety rail；未安裝時沒有機械 enforcement，--no-verify 可略過，且不保證 --mirror 的隱式刪除。例外：使用者當下明示直接推 main。

## S6 CLOSEOUT

- 路徑選擇依 [INT-10]。

## Host adapters
FIX

  sed 's/ → bot-review gate//'                         "${scratch}/good.md" > "${scratch}/no-botgate.md"
  sed 's/；MUST NOT 直接 push 到 main／master//'        "${scratch}/good.md" > "${scratch}/no-prohibition.md"
  sed 's/未安裝時沒有機械 enforcement/已完整強制/'       "${scratch}/good.md" > "${scratch}/overclaim.md"
  sed 's/例外：使用者當下明示直接推 main。//'           "${scratch}/good.md" > "${scratch}/no-escape.md"
  sed 's/，以及 plugin install／enable、MCP 啟用、新 credential 或 external tool capability//' "${scratch}/good.md" > "${scratch}/no-capability-scope.md"
  sed 's/plugin install／enable/plugin/'                 "${scratch}/good.md" > "${scratch}/no-plugin-action.md"
  sed 's/MCP 啟用/MCP/'                                  "${scratch}/good.md" > "${scratch}/no-mcp-action.md"
  grep -v '^- \[INT-10\]'                              "${scratch}/good.md" > "${scratch}/no-rule.md"
  sed 's/- 路徑選擇依 \[INT-10\]。/- 路徑選擇自行判斷。/' "${scratch}/good.md" > "${scratch}/no-s6-pointer.md"

  probe() {  # $1=fixture $2=pass|fail $3=說明
    local out
    out=$(KERNEL_OVERRIDE="$1" bash "${BASH_SOURCE[0]:-$0}" --one 2>&1)
    case "$2:${out}" in
      pass:*FAIL*) printf '  FAIL  selftest 正向誤報: %s\n' "$3" >&2; rc=1 ;;
      pass:*)      printf '  PASS  selftest 正向: %s\n' "$3" ;;
      fail:*FAIL*) printf '  PASS  selftest 反向確實觸發: %s\n' "$3" ;;
      fail:*)      printf '  FAIL  selftest 反向未觸發（斷言等於沒跑）: %s\n' "$3" >&2; rc=1 ;;
    esac
  }

  probe "${scratch}/good.md"           pass "完整 [INT-10]"
  probe "${scratch}/no-botgate.md"     fail "路徑掉了 bot-review gate（[INT-10] 存在的理由）"
  probe "${scratch}/no-prohibition.md" fail "禁令被拿掉"
  probe "${scratch}/overclaim.md"      fail "把 client-side safety rail 講成完整強制"
  probe "${scratch}/no-escape.md"      fail "例外條款被拿掉"
  probe "${scratch}/no-capability-scope.md" fail "plugin/MCP capability scope 被拿掉"
  probe "${scratch}/no-plugin-action.md" fail "plugin 缺 install/enable action"
  probe "${scratch}/no-mcp-action.md"    fail "MCP 缺 install/enable action"
  probe "${scratch}/no-rule.md"        fail "[INT-10] 整條消失"
  probe "${scratch}/no-s6-pointer.md"  fail "S6 失去指標"

  rm -rf "${scratch}"
  return ${rc}
}

case "${1:-}" in
  --selftest) selftest; exit $? ;;
  --one)      check_kernel "${KERNEL_OVERRIDE:?}" Fixture; [ "${fail}" -eq 0 ] || exit 1; exit 0 ;;
esac

check_kernel "${AGENTS}/skills/dev-workflow/SKILL.md"

printf '\n%d PASS / %d FAIL\n' "${pass}" "${fail}"
[ "${fail}" -eq 0 ]
