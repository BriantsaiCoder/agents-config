#!/usr/bin/env bash
# [INT-4] 的自主 delegation 條件，與三個 host 入口檔的一致性。
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
DELEGATION_REF="$AGENTS/skills/dev-workflow/references/delegation.md"
HOST_ADAPTERS_REF="$AGENTS/skills/dev-workflow/references/host-adapters.md"

pass=0; fail=0; skip=0
ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng()   { printf '  FAIL  %s\n' "$1" >&2; fail=$((fail + 1)); }
na()   { printf '  SKIP  %s\n' "$1"; skip=$((skip + 1)); }

# shellcheck source=tests/lib/scan.sh
. "$AGENTS/tests/lib/scan.sh" ||
  { printf 'FAIL: scan helper missing: %s\n' "$AGENTS/tests/lib/scan.sh" >&2; exit 1; }
command -v scan_miss_f >/dev/null 2>&1 ||
  { printf 'FAIL: scan_miss_f unavailable after loading tests/lib/scan.sh\n' >&2; exit 1; }

# 固定數量／時機限制不得回流。host/runtime 的非數值容量敘述是技術事實，不屬於此類。
COUNT_RE='([0-9一二兩三四五六七八九十]+|[Oo]ne|[Tt]wo|[Tt]hree|[Ff]our|[Ff]ive|[Ss]ix|[Ss]even|[Ee]ight|[Nn]ine|[Tt]en)'
FIXED_LIMIT_RE="((併發(數)?|累計 delegation|單一 S 階段|同一 S 階段|parallel[[:space:]]+agents?|sub-?agents?([[:space:]]+(數量|count))?)[^。]{0,50}(≤|≥|<=|>=|<|>|最多|上限(為)?)[[:space:]]*${COUNT_RE}|(最多(使用)?|不得超過|上限(為)?)[^。]{0,20}${COUNT_RE}[[:space:]]*(個)?[[:space:]]*(sub-?agents?|agents?|tasks?)|(sub-?agents?|agents?|tasks?)(數量)?[^。]{0,20}(上限(為)?|最多|≤|≥|<=|>=|<|>)[[:space:]]*${COUNT_RE}|恰好[[:space:]]*${COUNT_RE}[[:space:]]*個[^。]{0,30}(agent|subagent)|每批[[:space:]]*${COUNT_RE}[[:space:]]*個|直接開[[:space:]]*${COUNT_RE}[[:space:]]*個|at[[:space:]]+most[[:space:]]+${COUNT_RE}[[:space:]]+(sub-?agents?|agents?|tasks?)|(S[0-9]+|每次|任何實質任務|所有實質任務)[^。]{0,60}(一律|必須|MUST|直接)[^。]{0,40}(spawn|啟動|委派|開啟|使用[^。]{0,12}(subagent|agent|task)))"

# 自主授權必須有的正向語彙：既說「自己判定」，也說「不必先問」。
AUTONOMY_RE='自主判定|自行判定'
NOASK_RE='不必先問|無須另問|MUST NOT 為此停下發問|不得為此停下發問'

# main-context 重驗不得被 host 入口檔否定。
#
# 為什麼存在（2026-08-04）：PR #7 依 Opus 5 官方指引在 ~/.claude/CLAUDE.md 加了「已委派就
# 不重做、不重推導其回報結論」，與 [INT-4] 的無條件約束「main context MUST 重驗其回報」
# 正面對撞——而 tier0 裁決鏈沒有任何術語能裁定 kernel 與 host delta 這一對，兩種讀法都
# 成立。官方原文就是 "Never redo the subagent's work and do not re-derive its findings"，
# 所以同類措辭還會再被加進來，靠人工逐條比對會漏（同一個 PR 抓到了與 [S5-3] 的衝突，
# 沒抓到這個）。本機第一手證據支持保留重驗：帶佐證的 finding 被 apply agent 照抄，仍會
# 把正確內容改壞。
#
# 判準是**受詞**不是動詞：不重跑探索過程、不重推導推理鏈 → 放行（那正是官方要省的成本）；
# 不核對它宣稱的回報／結論 → 擋（那是 [INT-4] 的不變量）。
#
# 間距用 `.{0,40}` 而非 `[^。；]{0,24}`：含多位元組字元的**否定字元類**判定隨 locale 改變。
# 實測（第一版就是這樣寫的，本檔 canary 可重現）：對「不重做其工作，回報結論直接採用。」
# 這種以 `，` 分隔的寫法，`[^。；]{0,24}` 在 `LC_ALL=C` 下**漏抓**、在 `en_US.UTF-8` 下正常。
# 於是同一份設定在 CI 與本機會得到相反判定，而漏抓的那邊是靜默的。`.` 沒有這個問題，
# 代價是失去句界限定。
#
# 量詞的計數單位同樣隨 locale 變（C 下位元組、UTF-8 下字元），所以 40 是浮動窗口而非固定
# 寬度；兩種 locale 下現有 fixture 判定一致，由下方 canary 逐一釘住。勿改回否定字元類。
NOVERIFY_RE='(不重做|不重驗|不再驗|不核對|不重新驗證|不必驗證|不重推導|[Nn]ever redo|[Dd]o not re-?derive).{0,40}(回報|結論|findings)'

# 先問語彙——政策被改回「每次問人」的各種寫法，含英文與同義動詞。
ASKFIRST_RE='先詢問|須經同意|需經同意|一律.*(先問|詢問)|未(經|獲).*(授權|同意).{0,60}(不得|不可|禁止|MUST NOT)|(不得|不可|禁止|MUST NOT).{0,60}(subagent|sub-agent|子代理|委派|delegate|開子|平行代理)|[Nn]ever use (sub-?agents?|delegation)|without.*(approval|permission)|ask.*(first|before).*(delegat|subagent)|禁用.*(subagent|子代理)|先取得.*(同意|授權)|必須.*(同意|授權).{0,20}才'

has_fixed_limit() { grep -Eq "$FIXED_LIMIT_RE" "$1"; }
has_autonomy()    { grep -Eq "$AUTONOMY_RE" "$1" && grep -Eq "$NOASK_RE" "$1"; }
has_noverify()    { grep -Eq "$NOVERIFY_RE" "$1"; }

# 先問語彙偵測逐行、且跳過同一行帶自主語彙的句子，避免「不必先問」被反向誤判。
has_askfirst() {
  grep -Ev "$AUTONOMY_RE" "$1" | grep -Eq "$ASKFIRST_RE"
}

selftest() {
  # 本檔沒有 set -e：mktemp 失敗時 $scratch 為空，fixture 會寫到 / 底下而斷言照跑。
  # 用 ng 而非只 return——finish 依 fail 計數決定 exit code，靜默 return 會變成假綠。
  local scratch; scratch="$(mktemp -d "${TMPDIR:-/tmp}/delegation-policy-parity.XXXXXX")" ||
    { ng 'selftest: 無法建立暫存目錄，正反向斷言完全未執行'; return 1; }

  printf '併發數 ≤ 2\n' > "$scratch/concurrency-limit.md"
  printf '同一 S 階段內累計 delegation ≤ 6\n' > "$scratch/stage-limit.md"
  printf 'S5 直接開 2 個 read-only task\n' > "$scratch/fixed-fanout.md"
  printf 'S5 一律啟動 subagent\n' > "$scratch/fixed-timing.md"
  printf '最多使用 2 個 subagent\n' > "$scratch/max-count.md"
  printf '最多使用兩個 subagent\n' > "$scratch/max-count-zh.md"
  printf 'subagent 上限 2\n' > "$scratch/subagent-cap.md"
  printf 'parallel agents <= 2\n' > "$scratch/parallel-cap.md"
  printf 'S5 must use at most two subagents\n' > "$scratch/english-max.md"
  printf '不得設定固定 fan-out\n' > "$scratch/negative-policy.md"
  printf '不設 user-authored 固定數量、併發或階段限制；host/runtime 容量仍適用。\n' > "$scratch/runtime-capacity.md"
  has_fixed_limit "$scratch/concurrency-limit.md" && ok '固定限制：併發上界被抓到' || ng '固定限制：漏掉併發上界'
  has_fixed_limit "$scratch/stage-limit.md" && ok '固定限制：階段累計上界被抓到' || ng '固定限制：漏掉階段累計上界'
  has_fixed_limit "$scratch/fixed-fanout.md" && ok '固定限制：固定 fan-out 被抓到' || ng '固定限制：漏掉固定 fan-out'
  has_fixed_limit "$scratch/fixed-timing.md" && ok '固定限制：強制使用時機被抓到' || ng '固定限制：漏掉強制使用時機'
  has_fixed_limit "$scratch/max-count.md" && ok '固定限制：最多使用 N 個被抓到' || ng '固定限制：漏掉最多使用 N 個'
  has_fixed_limit "$scratch/max-count-zh.md" && ok '固定限制：中文「兩個」被抓到' || ng '固定限制：漏掉中文「兩個」'
  has_fixed_limit "$scratch/subagent-cap.md" && ok '固定限制：subagent 上限被抓到' || ng '固定限制：漏掉 subagent 上限'
  has_fixed_limit "$scratch/parallel-cap.md" && ok '固定限制：parallel agents cap 被抓到' || ng '固定限制：漏掉 parallel agents cap'
  has_fixed_limit "$scratch/english-max.md" && ok '固定限制：英文拼字上界被抓到' || ng '固定限制：漏掉英文拼字上界'
  has_fixed_limit "$scratch/negative-policy.md" && ng '固定限制：誤判禁止固定 fan-out 的政策' || ok '固定限制：不誤判禁止固定 fan-out 的政策'
  has_fixed_limit "$scratch/runtime-capacity.md" && ng '固定限制：誤判非數值 runtime capacity' || ok '固定限制：不誤判 runtime capacity'

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

  # SKIP 偵測本身必須會命中，且不能只靠第一個 alternative——BRE/ERE 用錯時，
  # 「SKIP  Claude」會因為是字面前綴而假性命中，只有第二、三個才有鑑別力。
  printf 'SKIP  Copilot: 入口檔不在此環境\n' > "$scratch/skip.md"
  grep -qE 'SKIP  (Claude|Codex|Copilot)' "$scratch/skip.md" \
    && ok 'SKIP 偵測：非首個 alternative 也命中（alternation 真的生效）' \
    || ng 'SKIP 偵測：alternation 失效，正向組的 no-SKIP 斷言等於沒跑'
  printf '一切正常，沒有跳過任何檢查\n' > "$scratch/noskip.md"
  grep -qE 'SKIP  (Claude|Codex|Copilot)' "$scratch/noskip.md" \
    && ng 'SKIP 偵測：無 SKIP 的輸入被誤判' \
    || ok 'SKIP 偵測：無 SKIP 時不誤判'

  # 否定 main-context 重驗：RED 用 PR #7 的原句，GREEN 用收窄後的句子。兩者只差受詞，
  # 所以這組 fixture 同時釘住「會擋」與「不過度擋」——只留其中一邊等於沒有鑑別力。
  printf '已委派就不重做、不重推導其回報結論。\n' > "$scratch/noverify-pr7.md"
  printf '已委派就不重做其工作，回報結論直接採用。\n' > "$scratch/noverify-en.md"
  printf 'If you delegate, commit to it. Do not re-derive its findings once it reports back.\n' > "$scratch/noverify-official.md"
  has_noverify "$scratch/noverify-pr7.md" && ok '否定重驗：PR #7 原句被抓到' || ng '否定重驗：漏掉 PR #7 原句'
  has_noverify "$scratch/noverify-en.md" && ok '否定重驗：不重做+回報結論被抓到' || ng '否定重驗：漏掉不重做+回報結論'
  has_noverify "$scratch/noverify-official.md" && ok '否定重驗：官方英文原句被抓到' || ng '否定重驗：漏掉官方英文原句'
  printf '已委派就不重跑其探索過程、不重推導其推理鏈，但其宣稱的結果仍依 [INT-4] 由 main context 以證據核對。\n' > "$scratch/noverify-narrowed.md"
  has_noverify "$scratch/noverify-narrowed.md" && ng '否定重驗：誤判收窄後的合格寫法' || ok '否定重驗：不誤判收窄後的合格寫法'
  printf 'S5 以外不另派 subagent 做 verification；已委派就不重跑其探索過程。\n' > "$scratch/noverify-scope.md"
  has_noverify "$scratch/noverify-scope.md" && ng '否定重驗：誤判 delegation 收斂本身' || ok '否定重驗：不誤判 delegation 收斂本身'

  # locale 獨立性：量詞計數單位在 C 下是位元組、UTF-8 下是字元，而否定字元類的多位元組
  # 陷阱只在 C 下現形。只驗一種 locale 會得到「本機綠 runner 紅」或反過來的假保證——
  # 本 repo 已在 wc -w 上踩過同一課，tests/word-budget.sh 有對應的 locale canary。
  utf8_loc=$(locale -a 2>/dev/null | grep -iE '^(C\.UTF-?8|en_US\.UTF-?8)$' | head -1)
  if [ -n "$utf8_loc" ]; then
    for loc in C "$utf8_loc"; do
      ( LC_ALL="$loc"; export LC_ALL; has_noverify "$scratch/noverify-en.md" ) \
        && ok "locale 獨立[$loc]：逗號分隔的否定重驗仍被抓到" \
        || ng "locale 獨立[$loc]：漏抓逗號分隔（否定字元類陷阱回流）"
      ( LC_ALL="$loc"; export LC_ALL; has_noverify "$scratch/noverify-narrowed.md" ) \
        && ng "locale 獨立[$loc]：誤判收窄後的合格寫法" \
        || ok "locale 獨立[$loc]：不誤判收窄後的合格寫法"
    done
  else
    na 'locale 獨立：本環境無 UTF-8 locale，只涵蓋 C'
  fi

  printf 'Delegation 依 [INT-4] 自主判定是否、何時及使用多少 subagent，不設固定數量或階段限制，符合即直接執行不必先問。\n' > "$scratch/good.md"
  has_autonomy "$scratch/good.md" && ok '正向語彙：合格寫法通過' || ng '正向語彙：合格寫法被誤判'
  has_askfirst "$scratch/good.md" && ng '正向語彙：合格寫法被誤判為先問' || ok '正向語彙：不誤判為先問'
  has_fixed_limit "$scratch/good.md" && ng '正向語彙：合格寫法被誤判為固定限制' || ok '正向語彙：無固定限制'
  printf 'Delegation 依 [INT-4]。\n' > "$scratch/thin.md"
  has_autonomy "$scratch/thin.md" && ng '正向語彙：只提 [INT-4] 就算過（太寬）' || ok '正向語彙：只提 [INT-4] 不足'

  for _retired in \
    'Codex|Codex conditional implementation routing|Astra→Sol serial implementation routing|routing|forced_serial_absence' \
    'Claude|Claude conditional implementation routing|Fable→Opus serial implementation routing|routing-claude|claude_forced_serial_absence'; do
    _host=${_retired%%|*}; _rest=${_retired#*|}
    _clean_marker=${_rest%%|*}; _rest=${_rest#*|}
    _bad_marker=${_rest%%|*}; _rest=${_rest#*|}
    _fx=${_rest%%|*}; _prefix=${_rest#*|}
    printf '%s\n' "$_clean_marker" > "$scratch/$_fx-clean.md"
    printf '%s\n' "$_bad_marker" > "$scratch/$_fx-bad.md"
    scan_miss_f "$_bad_marker" "$scratch/$_fx-clean.md" \
      && ok "$_host forced serial absence：clean positive control 通過" \
      || ng "$_host forced serial absence：clean positive control 被拒"
    if scan_hit_f "$_bad_marker" "$scratch/$_fx-bad.md"; then
      ok "$_host forced serial absence：known-bad marker 已可信驗證"
      scan_miss_f "$_bad_marker" "$scratch/$_fx-bad.md" \
        && ng "$_host forced serial absence：known-bad marker 未被拒" \
        || ok "$_host forced serial absence：known-bad negative control 被拒"
    else
      ng "$_host forced serial absence：known-bad marker 缺失或掃描不可信"
    fi
    for _scan_shim_rc in 2 0; do
      assert_fails_closed "$_prefix" rg "$_scan_shim_rc" scan_verdict scan_miss_f \
        "$_bad_marker" "$scratch/$_fx-clean.md"
    done
  done

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
  has_fixed_limit "$file" \
    && ng "$label 仍含固定數量／時機限制" \
    || ok "$label 無固定數量／時機限制"
  has_autonomy "$file" \
    && ok "$label 有自主授權語彙" \
    || ng "$label 缺自主授權語彙（只指向 [INT-4] 不足以覆寫 host 自己的預設）"
  has_askfirst "$file" \
    && ng "$label 仍含先問／禁止 delegation 語彙" \
    || ok "$label 無先問語彙"
  has_noverify "$file" \
    && ng "$label 否定 main-context 重驗（撞 [INT-4] 無條件約束）" \
    || ok "$label 未否定 main-context 重驗"
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
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/delegation-policy-parity.XXXXXX")" ||
      { printf 'FAIL: 無法建立暫存目錄，fixture 未注入\n' >&2; exit 1; }
    trap 'rm -rf "$scratch"' EXIT
    printf 'Delegation 依 shared `dev-workflow` [INT-4]：無條件約束不變；AI 自主判定是否、何時及使用多少 subagent，不設固定數量／時機限制，直接執行不必先問。\n' \
      > "$scratch/good.md"
    printf '未獲授權時，不使用 subagent。\n' > "$scratch/bad.md"

    echo "── fixture 正向組：三家皆合格 ──"
    CLAUDE_INSTRUCTIONS="$scratch/good.md" CODEX_INSTRUCTIONS="$scratch/good.md" \
      COPILOT_INSTRUCTIONS="$scratch/good.md" bash "$0" >"$scratch/pos.log" 2>&1
    pos_rc=$?
    [ "$pos_rc" -eq 0 ] && ok 'fixture 正向組：exit 0' || {
      sed 's/^/    /' "$scratch/pos.log"; ng "fixture 正向組應 exit 0，實得 $pos_rc"; }
    # -E 不可省：BRE 的 \| 是 GNU 擴充，原生 BSD grep 會當字面字元，這條斷言就變成
    # 永遠不觸發而仍回綠——正是本 repo 反覆踩的失效型態。selftest 有一條專門釘住它。
    grep -qE 'SKIP  (Claude|Codex|Copilot)' "$scratch/pos.log" \
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
[ -r "$DELEGATION_REF" ] || { printf 'FAIL: delegation reference missing: %s\n' "$DELEGATION_REF" >&2; exit 1; }
[ -r "$HOST_ADAPTERS_REF" ] || { printf 'FAIL: host adapters missing: %s\n' "$HOST_ADAPTERS_REF" >&2; exit 1; }
int4="$(grep -F '[INT-4]' "$KERNEL" | head -1)"
[ -n "$int4" ] || { printf 'FAIL: [INT-4] not found in kernel\n' >&2; exit 1; }
printf '%s\n' "$int4" | grep -qE 'MUST.*觸發：.*例外：.*驗證：' || {
  printf 'FAIL: [INT-4] lost five-element rule contract\n' >&2; exit 1;
}
policy_file="$(mktemp "${TMPDIR:-/tmp}/delegation-policy-parity.XXXXXX")" ||
  { printf 'FAIL: cannot create policy scratch file\n' >&2; exit 1; }
{ printf '%s\n' "$int4"; cat "$DELEGATION_REF"; } > "$policy_file" || {
  rm -f "$policy_file"; printf 'FAIL: cannot assemble delegation policy\n' >&2; exit 1;
}
trap 'rm -f "$policy_file"' EXIT

# 逐片段驗，不逐條驗：整句 grep 會在任一項被刪掉時仍然通過，所以下列每個片段各自釘住
# [INT-4] 的一個承重點——無條件約束三項，以及由 AI 決定 delegation 的時機與數量。
# 為什麼釘無條件約束（S5 finding H1）：第一版把它們降級成「條件」，於是寫入重疊與序列
# 相依變成明文可授權——舊規則從未開這條路。使用者要改的是「誰決定」不是「允許什麼」。
for cond in '無條件約束' '可獨立平行' '寫入 ownership MUST 不重疊' 'MUST 重驗其回報' '何時委派、subagent 數量與是否平行 MUST 由 AI 自主判定'; do
  grep -Fq "$cond" "$policy_file" \
    && ok "[INT-4] 含核心片段：$cond" \
    || ng "[INT-4] 缺核心片段：$cond"
done
for exception_clause in \
  'Eligibility 例外只有' \
  'Codex context-isolation 例外不適用其他 host' \
  'same-work recursion is forbidden'; do
  grep -Fq "$exception_clause" "$DELEGATION_REF" \
    && ok "[INT-4] eligibility exception 含：$exception_clause" \
    || ng "[INT-4] eligibility exception 缺：$exception_clause"
done
# 每個例外 routing 片語只寫一次：delegation.md 要列出它，host-adapters.md 要定義它。
for routing_clause in 'Codex conditional implementation routing' 'Claude conditional implementation routing'; do
  grep -Fq "$routing_clause" "$DELEGATION_REF" \
    && ok "[INT-4] eligibility exception 含：$routing_clause" \
    || ng "[INT-4] eligibility exception 缺：$routing_clause"
  grep -Fq "$routing_clause" "$HOST_ADAPTERS_REF" \
    && ok "[INT-4] host adapter 定義：$routing_clause" \
    || ng "[INT-4] host adapter 缺少：$routing_clause"
done
# 退役的 forced serial 片語不得回流：delegation.md 與 host-adapters.md 都不能再出現。
for _retired in 'Codex|Astra→Sol serial implementation routing' 'Claude|Fable→Opus serial implementation routing'; do
  _host=${_retired%%|*}; _marker=${_retired#*|}
  if scan_miss_f "$_marker" "$DELEGATION_REF" && scan_miss_f "$_marker" "$HOST_ADAPTERS_REF"; then
    ok "[INT-4] $_host 已移除 forced serial routing"
  else
    ng "[INT-4] $_host 仍強制 ${_marker}，或掃描不可信"
  fi
done
grep -Fq 'bounded scope 的 large/noisy context 明確受益於 isolation' "$DELEGATION_REF" \
  && ok '[INT-4] Codex context isolation 限定為 bounded clear-benefit scope' \
  || ng '[INT-4] Codex context isolation 缺 bounded clear-benefit 限定'
grep -Fq '已完整規範、驗收可機械判定且預期不需回頭問設計的 packet' "$DELEGATION_REF" \
  && ok '[INT-4] Claude packet routing 限定為完整規範且可機械驗收' \
  || ng '[INT-4] Claude packet routing 缺完整規範／可機械驗收限定'
grep -Fq '無條件約束不在可授權範圍內' "$policy_file" \
  && ok '[INT-4] 明示無條件約束不可被授權繞過' \
  || ng '[INT-4] 未擋住「取得授權就能寫入重疊／序列相依」的路徑'
has_fixed_limit "$policy_file" && ng '[INT-4] 仍含固定數量／時機限制' || ok '[INT-4] 無固定數量／時機限制'

grep -Fq 'host/runtime 可用容量仍是技術上限' "$policy_file" \
  && ok '[INT-4] 保留 runtime 技術容量約束' \
  || ng '[INT-4] 未區分自主 policy 與 runtime 技術容量'

grep -Fq 'MUST NOT 為此停下發問' "$policy_file" \
  && ok '[INT-4] 明示不得為 delegation 停下發問' \
  || ng '[INT-4] 未明示不得為 delegation 停下發問'

# 放寬控制的同時，三條安全不變量必須留著。
for inv in '回報不是完成證據' '迴避 S2 授權或 [T0-8] plan gate' '依 [T0-5] 停下發問'; do
  if grep -Fq "$inv" "$policy_file"; then
    ok "[INT-4] 保留不變量：$inv"
  else
    ng "[INT-4] 遺失不變量：$inv"
  fi
done

# S5 review agent 的 read-only 限定不得再度脫落；是否使用及數量則由 AI 判定。
grep -Fq '如使用 review agents，MUST 為 read-only' "$policy_file" \
  && ok '[INT-4] S5 review agents 仍限定 read-only' \
  || ng '[INT-4] S5 review agents 遺失 read-only 限定'

has_askfirst "$policy_file" && ng 'kernel 含先問／禁止 delegation 語彙' || ok 'kernel 無先問語彙'

# ── 三個 host 入口檔 ─────────────────────────────────────────────────────
check_host Claude  "${CLAUDE_INSTRUCTIONS:-$HOME/.claude/CLAUDE.md}"
check_host Codex   "${CODEX_INSTRUCTIONS:-$HOME/.codex/AGENTS.md}"
check_host Copilot "${COPILOT_INSTRUCTIONS:-$HOME/.copilot/copilot-instructions.md}"

finish
