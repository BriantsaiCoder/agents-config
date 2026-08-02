#!/usr/bin/env bash
# [INT-4] 的自主授權條件，與三個 host 入口檔的一致性。
#
# 為什麼存在（2026-08-02）：delegation 政策原本三家寫法不對稱到看不出來——kernel 有 9 處
# [INT-4]，~/.claude/CLAUDE.md 寫「未獲授權不使用 subagent」（blanket 禁令），
# ~/.codex/AGENTS.md 只提工具名沒有政策，~/.copilot/copilot-instructions.md **一條都沒有**。
# 沒有任何東西會在其中一家漂移時提醒你，而症狀是「同一個任務在三家跑出不同行為」，
# 幾乎不可能歸因回設定。
#
# host 半邊怎麼在 CI 跑（S5 finding C-1 修正）：runner 沒有 ~/.claude / ~/.codex /
# ~/.copilot，若直接讀真實路徑，三家判定會整段 SKIP——那正好是本測試唯一存在理由所在的
# 那一半。做法對齊 tests/hook-parity.sh：它面對同一個缺席問題的答案是**注入 fixture 讓
# 判定邏輯在 CI 跑完**（PARITY_COPIES），不是 SKIP。本檔的 seam 是三個
# {CLAUDE,CODEX,COPILOT}_INSTRUCTIONS 環境變數，ci.yml 用 --fixtures 驅動正反兩組。
# 不帶參數跑時才讀真實路徑，量的是「這台機器現在實際是什麼狀態」。
#
# 反向偵測為何以正向語彙為主（S5 finding W-1 修正）：第一版只列舉「不使用 subagent」這類
# 禁止句式，實測三種現實寫法在政策已被破壞的情況下仍全綠——英文句、「一律先詢問」、
# 「MUST NOT 使用」（前面沒有「不」）。列舉禁止寫法永遠追不上同義句；改為要求自主授權的
# **正向**語彙在場，再加一組先問語彙的反向偵測。
#
# --selftest 對 fixture 驗兩個方向都真的會觸發。沒有它，反向斷言可以整段不執行而仍然回綠。
set -uo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd -P)}"
KERNEL="$AGENTS/skills/dev-workflow/SKILL.md"

pass=0; fail=0; skip=0
ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng()   { printf '  FAIL  %s\n' "$1" >&2; fail=$((fail + 1)); }
na()   { printf '  SKIP  %s\n' "$1"; skip=$((skip + 1)); }

# 單一常數，kernel 與 host 共用（S5 finding N-4）。kernel 寫「併發數 ≤ 2」、host 摘要寫
# 「併發 ≤2」，兩處各自寫死會讓一邊改措辭時另一邊不紅。容忍「數」與空白，上界必須是 2。
BOUND_RE='併發(數)?[[:space:]]*≤[[:space:]]*2'

# 自主授權必須有的正向語彙：既說「自己判定」，也說「不必先問」。
AUTONOMY_RE='自主判定|自行判定'
NOASK_RE='不必先問|無須另問|MUST NOT 為此停下發問|不得為此停下發問'

# 先問語彙——政策被改回「每次問人」的各種寫法，含英文與同義動詞。
ASKFIRST_RE='先詢問|須經同意|需經同意|一律.*(先問|詢問)|未(經|獲).*(授權|同意).{0,60}(不得|不可|禁止|MUST NOT)|(不得|不可|禁止|MUST NOT).{0,60}(subagent|sub-agent|子代理|委派|delegate|開子|平行代理)|[Nn]ever use (sub-?agents?|delegation)|without.*(approval|permission)|ask.*(first|before).*(delegat|subagent)|禁用.*(subagent|子代理)|先取得.*(同意|授權)|必須.*(同意|授權).{0,20}才'

has_bound()    { grep -Eq "$BOUND_RE" "$1"; }
has_autonomy() { grep -Eq "$AUTONOMY_RE" "$1" && grep -Eq "$NOASK_RE" "$1"; }

# 先問語彙偵測必須逐行、且跳過同一行帶自主語彙的句子。正確的政策**本來就**含
# 「超出上界時 MUST 先取得授權」這種升級路徑——它與「一律先問」的差別不在詞彙而在
# 同一句是否同時宣告自主授權。不做這個排除，kernel 自己的升級條款就會被誤判成 blanket
# 禁令（實測 2026-08-02：加寬樣式後 kernel 立刻自我誤報）。
has_askfirst() {
  grep -Ev "$AUTONOMY_RE" "$1" | grep -Eq "$ASKFIRST_RE"
}

selftest() {
  local scratch; scratch="$(mktemp -d)"

  printf '併發數 ≤ 2\n' > "$scratch/kernel-style.md"
  printf '併發 ≤2\n'    > "$scratch/host-style.md"
  printf '併發數 ≤ 3\n' > "$scratch/wrong-bound.md"
  has_bound "$scratch/kernel-style.md" && ok '上界：容忍 kernel 排版' || ng '上界：kernel 排版誤報'
  has_bound "$scratch/host-style.md"   && ok '上界：容忍 host 排版'   || ng '上界：host 排版誤報'
  has_bound "$scratch/wrong-bound.md"  && ng '上界：3 被誤判為合格'   || ok '上界：非 2 時不通過'

  # 這三份是 S5 review 實測第一版會漏掉的現實寫法，全部必須被抓到。
  printf '本 host 一律先詢問使用者後才委派；未經同意不得啟動 task 工具\n' > "$scratch/f1.md"
  printf 'Never use subagents. Do not use sub-agents without explicit user approval.\n' > "$scratch/f2.md"
  printf '未獲使用者授權，MUST NOT 使用任何形式的 subagent\n' > "$scratch/f3.md"
  local i=1
  for f in f1 f2 f3; do
    has_askfirst "$scratch/$f.md" \
      && ok "先問語彙偵測：fixture $i 被抓到" \
      || ng "先問語彙偵測：fixture $i 漏掉（政策已破壞卻會綠）"
    i=$((i + 1))
  done

  printf 'Delegation 依 [INT-4] 四項條件自主判定（併發 ≤2），符合即直接執行不必先問。\n' > "$scratch/good.md"
  has_autonomy "$scratch/good.md" && ok '正向語彙：合格寫法通過' || ng '正向語彙：合格寫法被誤判'
  has_askfirst "$scratch/good.md" && ng '正向語彙：合格寫法被誤判為先問' || ok '正向語彙：不誤判為先問'
  printf 'Delegation 依 [INT-4]。\n' > "$scratch/thin.md"
  has_autonomy "$scratch/thin.md" && ng '正向語彙：只提 [INT-4] 就算過（太寬）' || ok '正向語彙：只提 [INT-4] 不足'

  rm -rf "$scratch"
}

check_host() {
  local label="$1" file="$2"
  if [ ! -r "$file" ]; then
    na "$label: 入口檔不在此環境（${file}）"
    return
  fi
  grep -Fq '[INT-4]' "$file" \
    && ok "$label 指向 [INT-4]" \
    || ng "$label 未指向 [INT-4]（三家會各自漂移）"
  has_bound "$file" \
    && ok "$label 帶併發上界" \
    || ng "$label 缺併發上界"
  has_autonomy "$file" \
    && ok "$label 有自主授權語彙" \
    || ng "$label 缺自主授權語彙（只指向 [INT-4] 不足以覆寫 host 自己的預設）"
  has_askfirst "$file" \
    && ng "$label 仍含先問／禁止 delegation 語彙" \
    || ok "$label 無先問語彙"
}

finish() {
  printf '%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skip"
  [ "$pass" -gt 0 ] || { printf 'FAIL 沒有任何檢查執行成功\n' >&2; exit 1; }
  [ "$fail" -eq 0 ]
  exit
}

case "${1:-}" in
  --selftest) selftest; finish ;;
  --fixtures)
    # CI 模式：注入合格與不合格的假 host 檔，讓 host 判定邏輯在沒有真實 host 目錄的
    # runner 上被真的執行。正向組必須全綠且無 SKIP，反向組必須紅——後者若沒紅，
    # 代表 host 半邊整段沒跑，而那正是本測試存在的理由。
    scratch="$(mktemp -d)"; trap 'rm -rf "$scratch"' EXIT
    printf 'Delegation 依 shared `dev-workflow` [INT-4] 的四項條件自主判定（可獨立平行 ∧ read-only 或寫入不重疊 ∧ 併發 ≤2 ∧ main context 重驗），符合即直接執行不必先問。\n' \
      > "$scratch/good.md"
    printf '未獲授權時，不使用 subagent。\n' > "$scratch/bad.md"

    echo "── fixture 正向組：三家皆合格 ──"
    CLAUDE_INSTRUCTIONS="$scratch/good.md" CODEX_INSTRUCTIONS="$scratch/good.md" \
      COPILOT_INSTRUCTIONS="$scratch/good.md" bash "$0" >"$scratch/pos.log" 2>&1
    pos_rc=$?
    [ "$pos_rc" -eq 0 ] && ok 'fixture 正向組：exit 0' || {
      sed 's/^/    /' "$scratch/pos.log"; ng "fixture 正向組應 exit 0，實得 $pos_rc"; }
    grep -q 'SKIP  Claude\|SKIP  Codex\|SKIP  Copilot' "$scratch/pos.log" \
      && ng 'fixture 正向組仍有 host SKIP —— host 判定沒被執行' \
      || ok 'fixture 正向組無 host SKIP —— host 判定確實執行'

    echo "── fixture 反向組：Claude 側被改回 blanket 禁令 ──"
    CLAUDE_INSTRUCTIONS="$scratch/bad.md" CODEX_INSTRUCTIONS="$scratch/good.md" \
      COPILOT_INSTRUCTIONS="$scratch/good.md" bash "$0" >"$scratch/neg.log" 2>&1
    neg_rc=$?
    grep -E '^  FAIL' "$scratch/neg.log" | sed 's/^/    /'
    [ "$neg_rc" -ne 0 ] \
      && ok 'fixture 反向組：政策被破壞時確實 exit 非 0' \
      || ng 'fixture 反向組應 exit 非 0 —— 閘對已破壞的政策沒有反應'
    finish
    ;;
esac

# ── kernel 正本 ──────────────────────────────────────────────────────────
[ -r "$KERNEL" ] || { printf 'FAIL: kernel missing: %s\n' "$KERNEL" >&2; exit 1; }
int4="$(grep -F '[INT-4]' "$KERNEL" | head -1)"
[ -n "$int4" ] || { printf 'FAIL: [INT-4] not found in kernel\n' >&2; exit 1; }
int4_file="$(mktemp)"; printf '%s\n' "$int4" > "$int4_file"
trap 'rm -f "$int4_file"' EXIT

# 三項授權條件的關鍵片段逐項在場——條件 (b) 是選言（read-only 或 寫入不重疊），兩邊各釘
# 一段，所以是 4 個片段對 3 個條件。整句 grep 會在任一項被刪掉時仍然通過，必須拆開驗。
# 無條件約束（S5 finding H1：第一版把這些降級成「條件」，於是寫入重疊與序列相依
# 變成明文可授權——舊規則從未開這條路。使用者要改的是「誰決定」不是「允許什麼」）。
for cond in '無條件約束' '可獨立平行' '寫入 ownership MUST 不重疊' 'MUST 重驗其回報' '累計 delegation ≤ 6'; do
  case "$int4" in
    *"$cond"*) ok "[INT-4] 含無條件約束／上界片段：$cond" ;;
    *) ng "[INT-4] 缺無條件約束／上界片段：$cond" ;;
  esac
done
case "$int4" in
  *'無條件約束不在可授權範圍內'*) ok '[INT-4] 明示無條件約束不可被授權繞過' ;;
  *) ng '[INT-4] 未擋住「取得授權就能寫入重疊／序列相依」的路徑' ;;
esac
has_bound "$int4_file" && ok '[INT-4] 含併發上界' || ng '[INT-4] 缺併發上界'

case "$int4" in
  *'MUST NOT 為此停下發問'*) ok '[INT-4] 明示不得為 delegation 停下發問' ;;
  *) ng '[INT-4] 未明示不得為 delegation 停下發問' ;;
esac

# 放寬控制的同時，四條安全不變量必須留著。
for inv in '未獲授權標 SKIPPED' '回報不是完成證據' '迴避 S2 授權或 [T0-8] plan gate' '依 [T0-5] 停下發問'; do
  if grep -Fq "$inv" "$int4_file"; then
    ok "[INT-4] 保留不變量：$inv"
  else
    ng "[INT-4] 遺失不變量：$inv"
  fi
done

# S5 兩軸的 read-only 限定不得再度脫落（S5 finding W-3：第一版改寫時它連同釘住它的
# 斷言一起消失，reviewer agent 因此可在無額外授權下取得寫入權）。
case "$int4" in
  *'read-only** review agents'*|*'read-only review agents'*) ok '[INT-4] S5 兩軸仍限定 read-only' ;;
  *) ng '[INT-4] S5 兩軸遺失 read-only 限定' ;;
esac

has_askfirst "$KERNEL" && ng 'kernel 含先問／禁止 delegation 語彙' || ok 'kernel 無先問語彙'

# ── 三個 host 入口檔 ─────────────────────────────────────────────────────
check_host Claude  "${CLAUDE_INSTRUCTIONS:-$HOME/.claude/CLAUDE.md}"
check_host Codex   "${CODEX_INSTRUCTIONS:-$HOME/.codex/AGENTS.md}"
check_host Copilot "${COPILOT_INSTRUCTIONS:-$HOME/.copilot/copilot-instructions.md}"

finish
