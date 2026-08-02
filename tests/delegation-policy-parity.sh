#!/usr/bin/env bash
# [INT-4] 的自主授權條件，與三個 host 入口檔的一致性。
#
# 為什麼存在（2026-08-02）：delegation 政策原本三家寫法不對稱到看不出來——kernel 有 9 處
# [INT-4]，~/.claude/CLAUDE.md 寫「未獲授權不使用 subagent」（blanket 禁令），
# ~/.codex/AGENTS.md 只提工具名沒有政策，~/.copilot/copilot-instructions.md **一條都沒有**。
# 沒有任何東西會在其中一家漂移時提醒你，而症狀是「同一個任務在三家跑出不同行為」，
# 幾乎不可能歸因回設定。同一天的 `58 cases` 事件是同一個形狀：文件寫的數字與實測差 2，
# 守護它的斷言只 grep 字串存在、不驗算真值，於是綠燈掛了不知多久。
#
# runner 沒有 ~/.claude / ~/.codex / ~/.copilot，host 副本那部分標 SKIP（非合規缺陷，
# 與 tests/hook-parity.sh 同慣例）；repo 正本的 kernel 斷言必跑。
#
# --selftest 對 fixture 驗「blanket 禁令偵測器真的會觸發」。沒有這段，反向斷言可以整段
# 不執行而仍然回綠——實測過的失效形狀（CI 缺 rg 時反向斷言靜默跳過）。
set -uo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd -P)}"
KERNEL="$AGENTS/skills/dev-workflow/SKILL.md"

pass=0; fail=0; skip=0
ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng()   { printf '  FAIL  %s\n' "$1" >&2; fail=$((fail + 1)); }
na()   { printf '  SKIP  %s\n' "$1"; skip=$((skip + 1)); }

# blanket 禁令 = 「不使用 / 不得使用 subagent（或子代理）」這類無條件封鎖。
# 條件式的「不符合才回到明示授權」不算——那正是本政策要的形狀，所以樣式必須夠窄。
BLANKET='(不|禁止)(使用|得使用|得用)[^。]{0,12}(subagent|子代理)|(subagent|子代理)[^。]{0,12}(一律|皆)(不|禁)'

has_blanket() { grep -Eq "$BLANKET" "$1"; }

if [ "${1:-}" = --selftest ]; then
  scratch="$(mktemp -d)"; trap 'rm -rf "$scratch"' EXIT
  printf '未獲授權時，不使用 subagent。\n' > "$scratch/blanket.md"
  printf '不符合四項條件才回到明示授權；符合即直接執行。\n' > "$scratch/conditional.md"
  has_blanket "$scratch/blanket.md" \
    && ok 'selftest: blanket 禁令會被偵測到' \
    || ng 'selftest: blanket 偵測器對已知 blanket 文字沒有觸發'
  has_blanket "$scratch/conditional.md" \
    && ng 'selftest: 條件式寫法被誤判為 blanket' \
    || ok 'selftest: 條件式寫法不誤判'
  printf '併發數 ≤ 2\n' > "$scratch/kernel-style.md"
  printf '併發 ≤2\n' > "$scratch/host-style.md"
  for f in kernel-style host-style; do
    grep -Eq '併發(數)?[[:space:]]*≤[[:space:]]*2' "$scratch/$f.md" \
      && ok "selftest: 上界摘要容忍 $f 排版" \
      || ng "selftest: 上界摘要對 $f 排版誤報"
  done
  grep -Eq '併發(數)?[[:space:]]*≤[[:space:]]*2' <(printf '併發數 ≤ 3\n') \
    && ng 'selftest: 上界 3 被誤判為合格' \
    || ok 'selftest: 上界非 2 時不通過'
  printf '%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skip"
  [ "$fail" -eq 0 ]
  exit
fi

# ── kernel 正本 ──────────────────────────────────────────────────────────
[ -r "$KERNEL" ] || { printf 'FAIL: kernel missing: %s\n' "$KERNEL" >&2; exit 1; }
int4="$(grep -F '[INT-4]' "$KERNEL" | head -1)"
[ -n "$int4" ] || { printf 'FAIL: [INT-4] not found in kernel\n' >&2; exit 1; }

# 四項條件的關鍵片段逐項在場——條件 (b) 是選言（read-only 或 寫入不重疊），兩邊各釘一段，
# 所以是 5 個片段對 4 個條件。整句 grep 會在任一項被刪掉時仍然通過，所以必須拆開驗。
for cond in '可獨立平行' 'read-only' '寫入 ownership 不重疊' '併發數 ≤ 2' 'main context 會重驗'; do
  case "$int4" in
    *"$cond"*) ok "[INT-4] 含條件：$cond" ;;
    *) ng "[INT-4] 缺條件：$cond" ;;
  esac
done

# 自主性：必須明說不用先問，否則條件寫了也會被讀成「還是問一下比較安全」。
case "$int4" in
  *'MUST NOT 為此停下發問'*) ok '[INT-4] 明示不得為 delegation 停下發問' ;;
  *) ng '[INT-4] 未明示不得為 delegation 停下發問' ;;
esac

# 放寬控制的同時，三條安全不變量必須留著。
for inv in '未獲授權標 SKIPPED' '回報不是完成證據' '迴避 S2 授權或 [T0-8] plan gate'; do
  if printf '%s' "$int4" | grep -Fq "$inv"; then
    ok "[INT-4] 保留不變量：$inv"
  else
    ng "[INT-4] 遺失不變量：$inv"
  fi
done

has_blanket "$KERNEL" && ng 'kernel 含 blanket subagent 禁令' || ok 'kernel 無 blanket 禁令'

# ── 三個 host 入口檔 ─────────────────────────────────────────────────────
check_host() {
  local label="$1" file="$2"
  if [ ! -r "$file" ]; then
    na "$label: 入口檔不在此環境（${file}）"
    return
  fi
  grep -Fq '[INT-4]' "$file" \
    && ok "$label 指向 [INT-4]" \
    || ng "$label 未指向 [INT-4]（三家會各自漂移）"
  # 排版容忍：kernel 寫「併發數 ≤ 2」，host 摘要寫「併發 ≤2」。釘死任一種都會讓另一種
  # 正確寫法誤報 FAIL（Copilot 於 PR #36 指出）。放寬「數」與空白，但仍要求關鍵詞與上界。
  grep -Eq '併發(數)?[[:space:]]*≤[[:space:]]*2' "$file" \
    && ok "$label 帶四項條件摘要" \
    || ng "$label 缺四項條件摘要"
  has_blanket "$file" \
    && ng "$label 仍含 blanket subagent 禁令" \
    || ok "$label 無 blanket 禁令"
}

check_host Claude  "${CLAUDE_INSTRUCTIONS:-$HOME/.claude/CLAUDE.md}"
check_host Codex   "${CODEX_INSTRUCTIONS:-$HOME/.codex/AGENTS.md}"
check_host Copilot "${COPILOT_INSTRUCTIONS:-$HOME/.copilot/copilot-instructions.md}"

printf '%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
