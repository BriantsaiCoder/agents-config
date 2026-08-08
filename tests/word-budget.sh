#!/usr/bin/env bash
# count-words.sh 字數預算回歸測試。
#
# 為何存在（2026-08-01 稽核 A1 / A4）：
#
# A1 — Step 1 唯一的機械量測是 `wc -w`，它按空白切詞，而中文沒有詞間空白。實測：一段
# 40 字 / 120 bytes 的純中文只算 1 個 word。後果不是「數字略小」而是「這道閘對整類 skill
# 失效」——CJK-heavy 的 skill 與英文 skill 共用同一條 limit 卻不可比，永遠不會被路由到
# step1-verdict-guide.md。修法是 ADD 不是 REPLACE：保留 wc -w，另計 CJK 字元，兩者相加
# 成為 effective。無 CJK 的檔 cjk=0，effective 恆等於 wc -w，**英文行為完全不變**——
# case "english-unchanged" 與真實語料斷言把這條釘死。
#
# A4 — 三個宣告的 tier 有兩個（using-*/getting-started* = 150、*-core/*-rules = 200）
# 在退役前的 ~/.agents/skills 與 ~/.claude/skills 各 81 個 skill 中匹配 0 個，是不可達的死分支；
# 2026-08-02 active corpus 為 77 個。
# 死分支會安靜地永遠不觸發，比沒有 tier 更糟，因為它製造「有分級」的錯覺。
# case "every-tier-has-a-member" 是防復發守衛：任何 tier 若在真實語料上 0 命中即 FAIL。
#
# 可攜性：CJK 計數刻意用 `LC_ALL=C tr` 做位元組級篩選，不依賴任何 UTF-8 locale。
# 實測 LC_ALL 未設時 `wc -m` 回傳位元組數（12 而非 4），而 CI runner 未必產生
# en_US.UTF-8。位元組法在 BSD 與 GNU 上結果相同。case "locale-independent" 守這條。
#
# 用法：tests/word-budget.sh
# Exit: 0 = 全過。1 = 有 FAIL。
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
AGENTS="${AGENTS_HOME:-$(cd "$SELF_DIR/.." && pwd)}"
SCRIPT="$AGENTS/skills/auditing-skill-folder/scripts/count-words.sh"
[ -r "$SCRIPT" ] || { echo "找不到 count-words.sh：$SCRIPT" >&2; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n     期望=%s 實得=%s\n' "$1" "$2" "$3"; }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/word-budget.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
CORPUS="$TMP/corpus"
mkdir -p "$CORPUS"

# mkbody <name> <body-text> — 建一個最小 fixture skill。
mkbody() {
  local d="$CORPUS/$1"
  mkdir -p "$d"
  { printf -- '---\nname: %s\ndescription: fixture\n---\n\n' "$1"; printf '%s\n' "$2"; } > "$d/SKILL.md"
}

# repeat <unit> <times>
repeat() { local i=0 out=""; while [ "$i" -lt "$2" ]; do out="$out$1"; i=$((i+1)); done; printf '%s' "$out"; }

# 英文：120 個 word，遠低於 500。
mkbody english-small "$(repeat 'alpha bravo charlie delta ' 30)"
# 英文：600 個 word，超過 500。
mkbody english-big "$(repeat 'alpha bravo charlie delta ' 150)"
# 純中文無空白：960 字，換算後超過 500 預算。wc -w 只會算 1。
mkbody chinese-big "$(repeat '本檔為測試用中文內容並無實際語意' 60)"
# 純中文但字數少：128 字，應在預算內。
mkbody chinese-small "$(repeat '本檔為測試用中文內容並無實際語意' 8)"
# 中英夾雜：700 CJK 字 + 200 英文 word。
mkbody mixed-big "$(repeat '本檔說明 alpha bravo 的設定方式與注意事項 charlie delta ' 50)"

run() { bash "$SCRIPT" "$CORPUS" 2>/dev/null; }
OUT=$(run)
# 欄位：EFF WORDS CJK OVER VND SKILL
field() { printf '%s\n' "$OUT" | awk -v n="$1" -v c="$2" '$6 == n { print $c; exit }'; }
eff_of()   { field "$1" 1; }
words_of() { field "$1" 2; }
cjk_of()   { field "$1" 3; }
over_of()  { field "$1" 4; }

echo "── A1：無 CJK 的檔行為完全不變 ──"
check "english-small: cjk=0"                "0"   "$(cjk_of english-small)"
check "english-small: effective == wc -w"   "$(words_of english-small)" "$(eff_of english-small)"
check "english-small: 未超標"                "-"   "$(over_of english-small)"
check "english-big: cjk=0"                  "0"   "$(cjk_of english-big)"
check "english-big: effective == wc -w"     "$(words_of english-big)" "$(eff_of english-big)"
check "english-big: 超標"                    "YES" "$(over_of english-big)"

echo "── A1：純中文不再塌成 1 個 word ──"
# 原始缺陷的直接證據：960 字的中文 body 對 wc -w 只貢獻 1 個 word。fixture 的 frontmatter
# （--- / name: / chinese-big / description: / fixture / ---）另貢獻 6 個，故總數應遠低於 20。
[ "$(words_of chinese-big)" -lt 20 ] \
  && ok "chinese-big: wc -w 仍極小（$(words_of chinese-big)），960 字中文只貢獻 1 個 word" \
  || bad "chinese-big: wc -w < 20（原始缺陷的證據）" "<20" "$(words_of chinese-big)"
[ "$(cjk_of chinese-big)" -ge 900 ] \
  && ok "chinese-big: CJK 計數 >= 900（實得 $(cjk_of chinese-big)）" \
  || bad "chinese-big: CJK 計數 >= 900" ">=900" "$(cjk_of chinese-big)"
check "chinese-big: 超標（修正前為 '-'）"       "YES" "$(over_of chinese-big)"
check "chinese-small: 仍在預算內"               "-"   "$(over_of chinese-small)"

echo "── A1：中英夾雜 ──"
[ "$(eff_of mixed-big)" -gt "$(words_of mixed-big)" ] \
  && ok "mixed-big: effective > wc -w" \
  || bad "mixed-big: effective > wc -w" ">$(words_of mixed-big)" "$(eff_of mixed-big)"
check "mixed-big: 超標" "YES" "$(over_of mixed-big)"

echo "── A1：不依賴任何 UTF-8 locale ──"
# 逐欄比對，不只比 EFF。2026-08-01 CI 實測：只釘 CJK 那半不夠——EFF 是總和，
# 任何一項對 locale 敏感就會讓整體漂移。GNU coreutils 的 `wc -w` 在 UTF-8 locale 下用
# iswspace() 斷詞、在 C locale 下逐位元組，對無空白的 zh-TW 檔兩者差 1（583 vs 582）。
# macOS BSD wc 兩種 locale 都回 7，所以本機看不到，只有 GNU runner 會炸。
for col in 1 2 3; do
  case "$col" in 1) label=EFF ;; 2) label=WORDS ;; 3) label=CJK ;; esac
  a=$(LC_ALL=C           bash "$SCRIPT" "$CORPUS" 2>/dev/null | awk -v c="$col" '$6=="chinese-big"{print $c}')
  b=$(LC_ALL=en_US.UTF-8 bash "$SCRIPT" "$CORPUS" 2>/dev/null | awk -v c="$col" '$6=="chinese-big"{print $c}')
  d=$(LC_ALL= LANG=      bash "$SCRIPT" "$CORPUS" 2>/dev/null | awk -v c="$col" '$6=="chinese-big"{print $c}')
  check "locale-independent[$label]: C 與 en_US.UTF-8 一致" "$a" "$b"
  check "locale-independent[$label]: locale 全空時亦一致"    "$a" "$d"
done

echo "── A4：宣告的 tier 都必須有真實成員 ──"
LIVE="$AGENTS/skills"
if [ -d "$LIVE" ] && [ -r "$LIVE/dev-workflow/SKILL.md" ]; then
  OUT=$(bash "$SCRIPT" "$LIVE" 2>/dev/null)
  # 從輸出末尾的 (limit=N) 收集所有實際觸發過的 limit。
  seen=$(printf '%s\n' "$OUT" | sed -n 's/.*(limit=\([0-9]*\)).*/\1/p' | sort -u)
  declared=$(sed -n 's/^# *DECLARED-TIERS: *//p' "$SCRIPT" | tr ',' '\n' | tr -d ' ' | grep -E '^[0-9]+$' | sort -u)
  [ -n "$declared" ] || bad "count-words.sh 需有 '# DECLARED-TIERS:' 註記供本測試比對" "非空" "空"
  for t in $declared; do
    if printf '%s\n' "$seen" | grep -Fxq "$t"; then
      ok "tier $t 在真實語料上有成員"
    else
      bad "tier $t 在真實語料上有成員（死分支會安靜地永不觸發）" "有成員" "0 命中"
    fi
  done
  echo "── A4：常駐 skill 落在緊預算 ──"
  dw=$(printf '%s\n' "$OUT" | awk '$6=="dev-workflow"{print $0}' | sed -n 's/.*(limit=\([0-9]*\)).*/\1/p')
  [ -n "$dw" ] && [ "$dw" -lt 500 ] \
    && ok "dev-workflow 使用緊預算 limit=$dw" \
    || bad "dev-workflow 使用緊預算 (<500)" "<500" "${dw:-無}"

  echo "── A1：真實語料，5 個 zh-TW skill 都必須被量到 ──"
  for s in sdd deps-check bug-fix-settlement aspnet-api-architect dev-workflow; do
    e=$(printf '%s\n' "$OUT" | awk -v n="$s" '$6==n{print $1}')
    w=$(printf '%s\n' "$OUT" | awk -v n="$s" '$6==n{print $2}')
    if [ -n "$e" ] && [ -n "$w" ] && [ "$e" -gt "$w" ]; then
      ok "$s: effective($e) > wc -w($w)"
    else
      bad "$s: effective > wc -w" ">$w" "${e:-無}"
    fi
  done

  echo "── A1：英文 skill 分類不得改變 ──"
  for s in typescript-best-practices react-best-practices vue-best-practices nuxt; do
    cj=$(printf '%s\n' "$OUT" | awk -v n="$s" '$6==n{print $3}')
    check "$s: cjk=0，分類不受影響" "0" "${cj:-缺}"
  done
else
  echo "── 真實語料：SKIP（$LIVE 不存在） ──"
fi

echo
echo "PASS=$PASS FAIL=$FAIL"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$PASS" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$FAIL" -eq 0 ]
