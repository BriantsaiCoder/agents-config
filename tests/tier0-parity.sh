#!/usr/bin/env bash
# 三份 FP:AGENTS-T0-2026Q3 檔案的 tier0 規範內容等價守衛。
#
# 為什麼存在（2026-08-03）：tier0 有三份實體——~/.claude/core/tier0-safety.md（Claude 靠
# @import 常駐）、~/.codex/AGENTS.md、~/.copilot/copilot-instructions.md（兩者無 import
# 機制，只能內嵌）。三份都蓋同一個 FP:AGENTS-T0-2026Q3 指紋宣稱同版，但沒有任何測試、
# hook、CI 或 bin/ 工具在驗證它們真的等價——agents-sync 只管 skills symlink，不碰入口檔，
# 2026-07-07 blueprint 描述的 dist/codex-AGENTS.md 生成流程從未實作。指紋成了假保證。
#
# 2026-08-04 的第二次 RED 顯示，單靠寬鬆 token 表會同時漏掉語意漂移與製造誤報：
#   [T0-1]/[T0-5]/[T0-7] Claude/Copilot 保留舊 blanket gate，Codex 已採 risk-based contract；
#   [T0-9] 三家未承接 shared review-triage 的 bot UNAVAILABLE fallback；
#   [T0-1] checker 把「file path」按空白拆成兩個 token，Codex 的合法「path」因此被誤報。
#
# 判準是規範內容，不是逐字相同。三份仍可保留 per-host 措辭，但每個以 `|` 分隔的 clause
# 必須完整存在，不能再按空白拆詞；selftest 另用正反 fixture 證明 autonomy exception、risk
# trigger、fallback outcome 與五要素缺一時都會 FAIL。
#
# 改 tier0 規則時 MUST 同步更新下方 REQUIRED 表，否則新規則的漂移不會被抓到。
#
# CI 沒有 ~/.claude / ~/.codex / ~/.copilot。對齊 tests/delegation-policy-parity.sh 的做法：
# 三個 {CLAUDE,CODEX,COPILOT}_TIER0 環境變數是 seam，ci.yml 用 --selftest 驅動正反兩組；
# 不帶參數跑時讀真實路徑，量的是「這台機器現在實際是什麼狀態」。
#
# --selftest 對 fixture 驗兩個方向都真的會觸發。沒有它，反向斷言可以整段不執行而仍然回綠。
set -uo pipefail

pass=0; fail=0; skip=0
ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng()   { printf '  FAIL  %s\n' "$1" >&2; fail=$((fail + 1)); }
na()   { printf '  SKIP  %s\n' "$1"; skip=$((skip + 1)); }

# 每列：規則 ID|完整 clause|完整 clause|...
# clause 以 grep -i -F 在規則行內比對；空白是 clause 的一部分，不得拆成鬆散 token。
# T0-5 的 material／實質 trigger 三家無共同子串（Claude／Copilot 用 Material、Codex 用 實質），
# grep -F 表達不了 OR，只靠 outcome／scope／risk 間接守住；別以為這個方向仍有 guard（2026-09-08）。
REQUIRED=$(cat <<'TABLE'
T0-1|Action／current-state claim|path／API／config key|live evidence|實際修改／執行 target|live probe|non-action citation／hypothetical
T0-2|evidence|done
T0-3|force-push|force-with-lease
T0-4|secret|set
T0-5|先查證|outcome／scope／risk|發問|假設／影響|僅停相依步驟|低風險|default|明示
T0-6|auth|payment|migration|大量刪除|crypto|multi-tenant|rate-limit|pipeline|rollback
T0-7|Online DB migration|compatibility／destructive risk|expand→dual-write→backfill→switch-reads→remove-legacy|destructive schema|additive／new-object|SKIPPED|consumer boundary
T0-8|plan-first|架構性|High-risk|external write|destructive／costly／credential／payment／deployment／migration|material scope expansion|風險未變即沿用|in-scope|local|reversible|Low／Medium-risk|session plan|第二次確認
T0-9|current HEAD|applicable CI PASS|0 unresolved actionable findings|UNAVAILABLE|independent read-only reviewer|review-triage
TABLE
)

# 抽出某檔案中某條規則的定義行（tier0 三份都是一條一行、規則 ID 在行首）。
# 必須錨定行首：正本的裁決鏈段落有「衝突條文引用一律用規則 ID（如 [T0-3]）」這種
# 舉例句，不錨定就會抓到它而不是規則本身，然後把整條規則誤報成 token 缺失。
rule_line() {
  grep -E "^\[$2\]" "$1" 2>/dev/null | head -1
}

check_host() {
  local label="$1" file="$2" missing_total=0
  if [ ! -r "$file" ]; then
    na "$label: tier0 檔不在此環境（${file}）"
    return
  fi
  if ! grep -Fq 'FP:AGENTS-T0-2026Q3' "$file"; then
    ng "$label 未蓋 FP:AGENTS-T0-2026Q3 指紋（${file}）"
    return
  fi

  local row rule line clause missing marker
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    rule=${row%%|*}
    line=$(rule_line "$file" "$rule")
    if [ -z "$line" ]; then
      ng "$label 缺整條規則: [$rule]"
      missing_total=$((missing_total + 1))
      continue
    fi
    missing=""
    while IFS= read -r clause; do
      printf '%s' "$line" | grep -Fqi -- "$clause" || missing="$missing [$clause]"
    done < <(printf '%s\n' "${row#*|}" | tr '|' '\n')
    for marker in '觸發：' '例外：' '驗證：'; do
      printf '%s' "$line" | grep -Fq -- "$marker" || missing="$missing [$marker]"
    done
    if [ -n "$missing" ]; then
      ng "$label [$rule] 規範 clause 缺失:$missing"
      missing_total=$((missing_total + 1))
    fi
  done <<< "$REQUIRED"

  [ "$missing_total" -eq 0 ] && ok "$label tier0 九條規範內容齊備"
}

# ── selftest：對 fixture 驗證正反兩個方向都真的會觸發 ──────────────
selftest() {
  # 本檔沒有 set -e：mktemp 失敗時 $scratch 會是空字串，下面的 fixture 就寫到 /good.md
  # 等絕對路徑，而斷言仍然照跑——失敗方向是假綠加上污染根目錄。必須顯式擋。
  local scratch; scratch="$(mktemp -d "${TMPDIR:-/tmp}/tier0-parity.XXXXXX")" ||
    { printf '  FAIL  selftest: 無法建立暫存目錄，正反向斷言完全未執行\n' >&2; return 1; }
  local rc=0

  # 正向 fixture：含 autonomy exception、risk trigger、review outcome 與五要素，應全數 PASS。
  cat > "$scratch/good.md" <<'FIX'
<!-- FP:AGENTS-T0-2026Q3 -->
[T0-1] Action／current-state claim 涉及 path／API／config key 時 MUST 有 live evidence；實際修改／執行 target 仍須 live probe。觸發：前述 action／claim。例外：non-action citation／hypothetical。驗證：read／list／schema probe 或例外標記。
[T0-2] MUST NOT 無 evidence 宣稱 done。觸發：完成宣稱。例外：無。驗證：命令與 exit code。
[T0-3] MUST NOT force-push main／master；非保護分支只用 --force-with-lease。觸發：force push。例外：無。驗證：hook。
[T0-4] MUST NOT 把 token／secret 印明文；遮罩為 set／unset。觸發：credential 輸出。例外：非敏感值。驗證：gitleaks。
[T0-5] Material ambiguity MUST 停下發問並列假設／影響；發問前先查證並做完不依賴答案的部分，僅停相依步驟；低風險可逆細節採 sensible default 並明示。觸發：多種合理解讀會改變 outcome／scope／risk。例外：低風險、可逆、無 material impact。驗證：default／impact 紀錄。
[T0-6] auth／payment／migration／大量刪除／crypto／multi-tenant／rate-limit／deployment pipeline 變更 MUST 附 rollback。觸發：diff 命中。例外：無。驗證：plan。
[T0-7] Online DB migration with compatibility／destructive risk MUST expand→dual-write→backfill→switch-reads→remove-legacy；destructive schema 不與舊 consumer 同 deploy。觸發：schema／data-contract risk。例外：additive／new-object 或停機 batch 可標 SKIPPED（理由）。驗證：phases／consumer boundary／rollback。
[T0-8] 使用者明示 plan-first、架構性／High-risk change，或 external write、destructive／costly／credential／payment／deployment／migration side effect 與 material scope expansion 未獲授權時 MUST 先出 plan 並取得確認，plan／核准涵蓋 exact action／scope 且風險未變即沿用；scope 清楚、in-scope、local、reversible 的 Low／Medium-risk change／build／fix 可直接實作並做 non-destructive verification，Medium 先留 session plan，不需第二次確認。觸發：將改檔或執行 side effect 且命中前述 protected gate。例外：無。驗證：protected gate 有 plan + 核准原句；direct path 有 user 原句 + risk／reversibility，Medium 另有 session plan。
[T0-9] Merge 前 MUST 在 current HEAD 有 applicable CI PASS 且 0 unresolved actionable findings；bot UNAVAILABLE 時依 review-triage 由 independent read-only reviewer fallback。觸發：merge。例外：無。驗證：current-head CI + review gate PASS。
FIX

  # 反向 fixtures：每種曾發生或最危險的語意漂移都必須真的觸發。
  sed 's/Action／current-state claim/任何引用/' \
    "$scratch/good.md" > "$scratch/blanket-t01.md"
  sed 's/例外：non-action citation／hypothetical。/例外：無。/' \
    "$scratch/good.md" > "$scratch/no-t01-exception.md"
  sed 's/，僅停相依步驟//' \
    "$scratch/good.md" > "$scratch/blanket-t05.md"
  sed 's/發問前先查證並做完/發問前做完/' \
    "$scratch/good.md" > "$scratch/no-t05-verify.md"
  sed 's/停下發問並列假設／影響；發問前/列假設／影響；/' \
    "$scratch/good.md" > "$scratch/no-t05-ask.md"
  sed 's/，plan／核准涵蓋 exact action／scope 且風險未變即沿用//' \
    "$scratch/good.md" > "$scratch/no-t08-reuse.md"
  sed 's/Online DB migration with compatibility／destructive risk/任何 DB migration/' \
    "$scratch/good.md" > "$scratch/blanket-t07.md"
  sed 's/例外：additive／new-object 或停機 batch 可標 SKIPPED（理由）。/例外：無。/' \
    "$scratch/good.md" > "$scratch/no-t07-skip.md"
  sed 's/scope 清楚、in-scope、local、reversible/scope 清楚、local、reversible/' \
    "$scratch/good.md" > "$scratch/drift-t08.md"
  sed 's/Low／Medium-risk/Low-risk/' \
    "$scratch/good.md" > "$scratch/no-medium-autonomy-t08.md"
  sed 's/架構性／High-risk change/架構性／中高風險 change/' \
    "$scratch/good.md" > "$scratch/blanket-medium-t08.md"
  sed 's/external write、destructive／costly／credential／payment／deployment／migration side effect 與 material scope expansion 未獲授權時/High-risk change 時/' \
    "$scratch/good.md" > "$scratch/no-protected-boundary-t08.md"
  sed 's/；bot UNAVAILABLE 時依 review-triage 由 independent read-only reviewer fallback//' \
    "$scratch/good.md" > "$scratch/no-t09-fallback.md"
  sed 's/ 且 0 unresolved actionable findings//' \
    "$scratch/good.md" > "$scratch/no-t09-outcome.md"
  grep -v '\[T0-6\]' "$scratch/good.md" > "$scratch/drop-t06.md"
  sed 's/觸發：merge。//' "$scratch/good.md" > "$scratch/no-trigger.md"
  grep -v 'FP:AGENTS-T0-2026Q3' "$scratch/good.md" > "$scratch/no-fp.md"

  probe() {  # $1=fixture $2=期望(pass|fail) $3=說明
    local out; out=$(CLAUDE_TIER0="$1" CODEX_TIER0="" COPILOT_TIER0="" \
      bash "${BASH_SOURCE[0]:-$0}" --one 2>&1)
    case "$2:$out" in
      pass:*FAIL*) printf '  FAIL  selftest 正向誤報: %s\n' "$3" >&2; rc=1 ;;
      pass:*)      printf '  PASS  selftest 正向: %s\n' "$3" ;;
      fail:*FAIL*) printf '  PASS  selftest 反向確實觸發: %s\n' "$3" ;;
      fail:*)      printf '  FAIL  selftest 反向未觸發（斷言等於沒跑）: %s\n' "$3" >&2; rc=1 ;;
    esac
  }

  probe "$scratch/good.md"             pass "完整 tier0"
  probe "$scratch/blanket-t01.md"      fail "[T0-1] 退回 blanket path probe"
  probe "$scratch/no-t01-exception.md" fail "[T0-1] 掉 non-action/hypothetical 例外"
  probe "$scratch/blanket-t05.md"      fail "[T0-5] 退回全停等答案（掉僅停相依步驟）"
  probe "$scratch/no-t05-verify.md"    fail "[T0-5] 掉發問前先查證"
  probe "$scratch/no-t05-ask.md"       fail "[T0-5] 掉發問本身"
  probe "$scratch/no-t08-reuse.md"     fail "[T0-8] 掉核准沿用（風險未變即沿用）"
  probe "$scratch/blanket-t07.md"      fail "[T0-7] 退回任何 migration 都跑五階段"
  probe "$scratch/no-t07-skip.md"      fail "[T0-7] 掉 additive/offline SKIPPED"
  probe "$scratch/drift-t08.md"        fail "[T0-8] 掉 in-scope"
  probe "$scratch/no-medium-autonomy-t08.md" fail "[T0-8] 掉 Medium 直接路徑"
  probe "$scratch/blanket-medium-t08.md" fail "[T0-8] 退回中高風險 blanket gate"
  probe "$scratch/no-protected-boundary-t08.md" fail "[T0-8] 掉 protected side-effect boundary"
  probe "$scratch/no-t09-fallback.md"  fail "[T0-9] 掉 bot UNAVAILABLE fallback"
  probe "$scratch/no-t09-outcome.md"   fail "[T0-9] 掉 0 actionable outcome"
  probe "$scratch/drop-t06.md"         fail "[T0-6] 整條消失"
  probe "$scratch/no-trigger.md"       fail "規則掉觸發要素"
  probe "$scratch/no-fp.md"            fail "FP 指紋被拔"

  rm -rf "$scratch"
  return $rc
}

case "${1:-}" in
  --selftest)
    selftest
    exit $?
    ;;
  --one)  # selftest 內部用：只驗 CLAUDE_TIER0 指到的單一檔案
    check_host Fixture "${CLAUDE_TIER0:?}"
    [ "$fail" -eq 0 ] || exit 1
    exit 0
    ;;
esac

check_host Claude  "${CLAUDE_TIER0:-$HOME/.claude/core/tier0-safety.md}"
check_host Codex   "${CODEX_TIER0:-$HOME/.codex/AGENTS.md}"
check_host Copilot "${COPILOT_TIER0:-$HOME/.copilot/copilot-instructions.md}"

printf '\n%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
