#!/usr/bin/env bash
# 三份 FP:AGENTS-T0-2026Q3 檔案的 tier0 規範內容等價守衛。
#
# 為什麼存在（2026-08-03）：tier0 有三份實體——~/.claude/core/tier0-safety.md（Claude 靠
# @import 常駐）、~/.codex/AGENTS.md、~/.copilot/copilot-instructions.md（兩者無 import
# 機制，只能內嵌）。三份都蓋同一個 FP:AGENTS-T0-2026Q3 指紋宣稱同版，但沒有任何測試、
# hook、CI 或 bin/ 工具在驗證它們真的等價——agents-sync 只管 skills symlink，不碰入口檔，
# 2026-07-07 blueprint 描述的 dist/codex-AGENTS.md 生成流程從未實作。指紋成了假保證。
#
# 實測到的後果（本測試建立當下即為 RED）：
#   [T0-8] Codex/Copilot 側掉了 in-scope 限定詞——正本「其餘明確的 in-scope change 可直接
#          實作」變成「其他明確 change 可直接實作」，scope 外的變更也落入免 plan 區，與
#          [T2-8]（scope 外只能列 follow-up）直接衝突。這是唯一方向為「放寬」的漂移。
#   [T0-9] 掉了「bot 異步產出，開 PR 當下為空是延遲不是無」，少了它會把「還沒跑出來」
#          誤判成「沒有 bot review」而過早 merge。
#
# 判準是規範內容，不是逐字相同。三份是各自撰寫的 per-host renderings，措辭本來就系統性
# 不同（rg↔grep、probe↔探針、consumer↔消費端、Codex/Copilot 額外要求 exit code），逐字
# 比對只會製造雜訊。所以只斷言每條規則的**規範性 token** 三份都在：觸發類別、MUST 的動作
# 邊界、防誤判的關鍵限定詞。措辭差異放行，加嚴放行（tier0 裁決鏈明定「只可加嚴不可放鬆」）。
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

# 每列：規則 ID|token|token|...
# token 以 grep -i -F 在該規則所在行內比對，故只放跨 host 共通的字面片段——
# 不放措辭會變的詞（如「消費端」對上「consumer」），只放規範性的那些。
REQUIRED=$(cat <<'TABLE'
T0-1|file path|config key
T0-2|evidence|done
T0-3|force-push|force-with-lease
T0-4|secret|set
T0-5|停下發問|假設
T0-6|auth|payment|migration|大量刪除|crypto|multi-tenant|rate-limit|pipeline|rollback
T0-7|expand|dual-write|backfill|switch-reads|remove-legacy
T0-8|in-scope|plan|中高風險
T0-9|CI|bot review|延遲不是無
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

  local row rule line tok missing
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
    for tok in $(printf '%s' "${row#*|}" | tr '|' '\n'); do
      printf '%s' "$line" | grep -Fqi -- "$tok" || missing="$missing $tok"
    done
    if [ -n "$missing" ]; then
      ng "$label [$rule] 規範 token 缺失:$missing"
      missing_total=$((missing_total + 1))
    fi
  done <<< "$REQUIRED"

  [ "$missing_total" -eq 0 ] && ok "$label tier0 九條規範內容齊備"
}

# ── selftest：對 fixture 驗證正反兩個方向都真的會觸發 ──────────────
selftest() {
  local scratch; scratch="$(mktemp -d)"
  local rc=0

  # 正向 fixture：照抄正本語意，應全數 PASS。
  cat > "$scratch/good.md" <<'FIX'
<!-- FP:AGENTS-T0-2026Q3 -->
[T0-1] MUST NOT 假設未驗證的 file path／API／config key。
[T0-2] MUST NOT 無 evidence 宣稱 done。
[T0-3] MUST NOT force-push main／master；非保護分支只用 --force-with-lease。
[T0-4] MUST NOT 把 token／secret 印明文；遮罩為 set／unset。
[T0-5] 模糊時 MUST 停下發問並列假設與影響。
[T0-6] auth／payment／migration／大量刪除／crypto／multi-tenant／rate-limit／deployment pipeline 變更 MUST 附 rollback。
[T0-7] DB migration MUST expand→dual-write→backfill→switch-reads→remove-legacy。
[T0-8] Plan-first 明示或架構性／中高風險變更 MUST 先出 plan；其餘明確的 in-scope change 可直接實作。
[T0-9] Merge 前 MUST 綠 CI 且處理 bot review（bot 異步產出，開 PR 當下為空是延遲不是無）。
FIX

  # 反向 fixture 一：[T0-8] 掉 in-scope（實測到的那個放寬）。
  sed 's/其餘明確的 in-scope change 可直接實作/其他明確 change 可直接實作/' \
    "$scratch/good.md" > "$scratch/drift-t08.md"
  # 反向 fixture 二：[T0-9] 掉 bot 異步註記。
  sed 's/（bot 異步產出，開 PR 當下為空是延遲不是無）//' \
    "$scratch/good.md" > "$scratch/drift-t09.md"
  # 反向 fixture 三：整條規則消失。
  grep -v '\[T0-6\]' "$scratch/good.md" > "$scratch/drop-t06.md"
  # 反向 fixture 四：指紋被拔掉。
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

  probe "$scratch/good.md"      pass "完整 tier0"
  probe "$scratch/drift-t08.md" fail "[T0-8] 掉 in-scope"
  probe "$scratch/drift-t09.md" fail "[T0-9] 掉 bot 異步註記"
  probe "$scratch/drop-t06.md"  fail "[T0-6] 整條消失"
  probe "$scratch/no-fp.md"     fail "FP 指紋被拔"

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
