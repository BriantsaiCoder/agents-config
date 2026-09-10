#!/usr/bin/env bash
# lint-descriptions.sh 分類回歸測試（英文 + zh-TW 雙語）。
#
# 為何存在：這支 linter 是 Step 2「description trap」的唯一機械判準，但在 2026-08-01 之前
# 它只認得英文——TRAP_RE 與 GOOD_RE 都是英文 pattern，任何 zh-TW description 只能落到 "?"
# （UNASSESSED），永遠不可能得到 YES。腳本自己的 SCOPE 註解記錄過一次失敗嘗試（2026-07-25
# 試著只教 GOOD_RE 中文，隨即回退）：只補 GOOD 側會把「必須人工讀」變成「靜默通過」，
# 讓偵測器對它存在的理由本身失明。
#
# 因此本測試的驗收條件寫死為方向性的，不接受「大致正確」：
#   1. TRAP 側必須先於 GOOD 側落地——至少一個真實 zh-TW description 得到 YES。
#   2. zh-TW 的 "?" 桶不可死掉——無 trigger 也無 workflow 的中文 description 仍須得 "?"。
#   3. 檢查順序 TRAP -> GOOD -> "?" 不可反轉：同時命中兩側者為 YES。
#   4. 新增的 zh-TW pattern 不得誤觸任何純英文 description。
#
# C locale 限制（本機實測 LC_CTYPE=C，grep 為 ugrep 7.5.0；CI 為 GNU grep）：
# 多位元組字元一律以「字面 token + | 交替」表示，絕不放進 [...]。負向字元類 [^...] 只放
# ASCII。case "no-multibyte-bracket" 把這條釘死。
#
# 用法：tests/description-lint.sh
# Exit: 0 = 全過。1 = 有 FAIL。
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
AGENTS="${AGENTS_HOME:-$(cd "$SELF_DIR/.." && pwd)}"
SCRIPT="$AGENTS/skills/auditing-skill-folder/scripts/lint-descriptions.sh"
[ -r "$SCRIPT" ] || { echo "找不到 lint-descriptions.sh：$SCRIPT" >&2; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n     期望=%s 實得=%s\n' "$1" "$2" "$3"; }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/description-lint.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT

CORPUS="$TMP/corpus"
mkdir -p "$CORPUS"

# mkdesc <name> <description-literal> — 建一個最小 fixture skill。
# description 以單引號 YAML scalar 包住，內含的單引號依 YAML 規則加倍。
mkdesc() {
  local name="$1" desc="$2" d="$CORPUS/$1"
  mkdir -p "$d"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$name"
    printf "description: '%s'\n" "${desc//\'/\'\'}"
    printf -- '---\n\n# %s\n' "$name"
  } > "$d/SKILL.md"
}

# mkraw <name> <full-SKILL.md-body> — 需要精確控制 frontmatter 時使用。
mkraw() {
  local d="$CORPUS/$1"
  mkdir -p "$d"
  printf '%s' "$2" > "$d/SKILL.md"
}

# ── fixtures：英文既有行為（回歸） ──────────────────────────────────────────
mkdesc en-good        'Use when writing or reviewing TypeScript generics and conditional types.'
mkdesc en-trap-then   'Scan a codebase for opportunities, then grill through the findings one by one.'
mkdesc en-trap-phase  'Runs the pipeline. Step 1 collects, step 2 verifies.'
mkdesc en-unassessed  'Manage NuGet packages in .NET projects and solutions.'
mkraw  en-no-desc     '---
name: en-no-desc
---

# en-no-desc
'
# 四箭頭形狀（歷史取樣自 vue-best-practices，2026-08-02 合併前），以逗號分隔。絕不可被鏈式箭頭 trap 命中。
mkdesc en-routing-arrows \
  'Use when writing or reviewing Vue 3 SFCs. Not: Pinia state->pinia, SSR->nuxt, browser composables->vueuse, runtime debugging->vue-debug.'
# 單一 S<digit> 是雲端術語，不是 phase enumeration。
mkdesc en-s3-bucket   'Use when configuring S3 bucket policies and lifecycle rules.'

# ── fixtures：zh-TW TRAP 側（每一個都必須 YES） ─────────────────────────────
mkdesc zh-trap-sphase '收到任何開發任務時先讀本檔。S0 route 到 skills，S2 處理授權，S4 驗證、S5 審查。'
mkdesc zh-trap-arrow  '輕量規格驅動開發（提案→實作→歸檔），適合單一 target file 的小需求。'
mkdesc zh-trap-implist 'ASP.NET Core Web API 架構師 skill — 規劃、撰寫文件、架構設計、審查、產生專案。'
mkdesc zh-trap-stepnum '本 skill 分三段執行：步驟 1 蒐集資料，步驟 2 產出報告。'
mkdesc zh-trap-seq     '先建立 worktree，然後執行測試，接著提交變更。'

# ── fixtures：zh-TW GOOD 側（必須 "-"） ────────────────────────────────────
mkdesc zh-good-when   '當使用者要求重構、改名或修改 public API 時，都必須先觸發此 skill。觸發關鍵字：重構、rename。'
mkdesc zh-good-after  '修復任何技術問題之後觸發的知識沉澱收尾流程。此 skill 不負責 debug 本身。'

# ── fixtures：zh-TW 既非 trap 亦非 trigger（"?" 桶必須仍活著） ──────────────
mkdesc zh-unassessed  '半導體測試資料的欄位對照表與代碼字典。'

# ── fixtures：檢查順序不變式（同時命中兩側 -> YES） ────────────────────────
mkdesc zh-both        '當使用者要求建置時觸發。步驟 1 編譯，步驟 2 部署。'

# ── fixtures：C locale 多位元組安全 ────────────────────────────────────────
# 全形逗號／句號／破折號密集，若任何 pattern 把多位元組字放進 [...]，位元組級否定
# 會讓這個 case 隨機命中或漏判。
mkdesc no-multibyte-bracket '這是一段純敘述，沒有任何觸發條件，也沒有工作流程；只有標點，、。！？（）「」。'

OUT=$(bash "$SCRIPT" "$CORPUS" 2>/dev/null)
flag_of() { printf '%s\n' "$OUT" | awk -v n="$1" '$3 == n { print $1; exit }'; }

echo "── 英文既有行為（不得回歸） ──"
check "en-good: 開頭 Use when -> -"                 "-"    "$(flag_of en-good)"
check "en-trap-then: ', then ' -> YES"              "YES"  "$(flag_of en-trap-then)"
check "en-trap-phase: 'Step 1' -> YES"              "YES"  "$(flag_of en-trap-phase)"
check "en-unassessed: 非 Use when 開頭 -> ?"         "?"    "$(flag_of en-unassessed)"
check "en-no-desc: 無 description -> MISS"          "MISS" "$(flag_of en-no-desc)"
check "en-routing-arrows: 逗號分隔箭頭不是鏈 -> -"   "-"    "$(flag_of en-routing-arrows)"
check "en-s3-bucket: 單一 S<digit> 不是 phase -> -"  "-"    "$(flag_of en-s3-bucket)"

echo "── zh-TW TRAP 側：必須先於 GOOD 側落地 ──"
check "zh-trap-sphase: S0/S2/S4 重複 phase 標號 -> YES"  "YES" "$(flag_of zh-trap-sphase)"
check "zh-trap-arrow: 鏈式箭頭 A→B→C -> YES"             "YES" "$(flag_of zh-trap-arrow)"
check "zh-trap-implist: 破折號後頓號祈使串列 -> YES"      "YES" "$(flag_of zh-trap-implist)"
check "zh-trap-stepnum: 步驟 N -> YES"                   "YES" "$(flag_of zh-trap-stepnum)"
check "zh-trap-seq: 先…然後…接著 -> YES"                 "YES" "$(flag_of zh-trap-seq)"

echo "── zh-TW GOOD 側 ──"
check "zh-good-when: 當使用者…時 -> -"        "-" "$(flag_of zh-good-when)"
check "zh-good-after: …之後觸發 -> -"          "-" "$(flag_of zh-good-after)"

echo "── zh-TW '?' 桶不可死掉 ──"
check "zh-unassessed: 無 trigger 無 workflow -> ?"  "?" "$(flag_of zh-unassessed)"
check "no-multibyte-bracket: 純標點敘述 -> ?"        "?" "$(flag_of no-multibyte-bracket)"

echo "── 檢查順序不變式 ──"
check "zh-both: TRAP 與 GOOD 同時命中 -> YES"  "YES" "$(flag_of zh-both)"

# ── 真實語料驗收 ───────────────────────────────────────────────────────────
# 這四個是 active corpus 的 live description 驗收標的。
# zh-TW 全部 "?" 代表偵測器對中文失明，全部 "-" 代表 TRAP 側沒 landing。
LIVE="$AGENTS/skills"
if [ -d "$LIVE" ] && [ -r "$LIVE/dev-workflow/SKILL.md" ]; then
  echo "── 真實語料：4 個 key live descriptions ──"
  OUT=$(bash "$SCRIPT" "$LIVE" 2>/dev/null)
  check "live dev-workflow: 開發任務時使用 trigger -> -"      "-" "$(flag_of dev-workflow)"
  check "live aspnet-api-architect: requirements trigger -> -"  "-" "$(flag_of aspnet-api-architect)"
  check "live deps-check: 未命中 heuristic -> ?"        "?"   "$(flag_of deps-check)"
  # The approved concise trigger uses 後 rather than the heuristic's 之後觸發.
  # '?' requests semantic assessment; zh-good-after above still guards the original pattern.
  check "live bug-fix-settlement: concise trigger outside heuristic -> ?" "?" "$(flag_of bug-fix-settlement)"
else
  echo "── 真實語料：SKIP（$LIVE 不存在，CI runner 無 live ~/.agents） ──"
fi

echo
echo "PASS=$PASS FAIL=$FAIL"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$PASS" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$FAIL" -eq 0 ]
