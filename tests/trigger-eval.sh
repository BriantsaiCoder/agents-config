#!/usr/bin/env bash
# eval-triggers.sh（Step 2c）離線回歸測試 —— 47 個斷言，零 API 呼叫。
# （數字別跟 evals/cases.jsonl 的 23 個 case 混淆：那是要送給模型的評測題目，
#  這裡是評測腳本自身計分邏輯的斷言，兩者無對應關係。）
#
# 為何存在：Step 2c 是唯一會花真實 rate-limit 額度的稽核步驟，所以它的計分邏輯必須能在
# 不花錢的前提下被釘死。做法沿用 tests/description-lint.sh 的形狀：驅動「真正的」腳本跑
# fixture，而不是在測試裡重寫一份判斷邏輯——重寫過的判斷只證明測試自己自洽。
#
# 驗收條件寫死為方向性的，不接受「大致正確」：
#   1. 基礎設施失敗（runner 沒吐 result 事件）必須是 ERR，絕不可被計為 quiet 的 PASS。
#      這是本檔最重要的一條：把 auth 過期或 rate limit 耗盡讀成「skill 沒觸發」，會讓一次
#      斷網產出一份漂亮的全綠稽核報告。
#   2. disable-model-invocation: true 的 skill 期望 fire 時必須 SKIP，不得計為 FN。
#      該 key 只有 Claude 認；Codex 讀 agents/openai.yaml、Copilot 整個忽略，所以三家的同
#      一個 case 分數不同，不可被折進單一數字。
#   3. collision 失敗必須在輸出裡「指名」贏家，否則 Step 2b 只是換個地方講同一句空話。
#   4. mock runner 的結果一定要自帶警語，不可能被誤讀成稽核數字。
#   5. Write 工具建立的 .sh 沒有 exec bit（實測踩過），而 runner 是以陣列直接 exec 的，
#      少了 exec bit 會在真實執行時才炸。exec bit 由測試把關。
#
# 用法：tests/trigger-eval.sh
# Exit: 0 = 全過。1 = 有 FAIL。
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
AGENTS="${AGENTS_HOME:-$(cd "$SELF_DIR/.." && pwd)}"
SCRIPT="$AGENTS/skills/auditing-skill-folder/scripts/eval-triggers.sh"
EVALS="$AGENTS/skills/auditing-skill-folder/evals"
MOCK="$EVALS/mock-runner.sh"
[ -r "$SCRIPT" ] || { echo "找不到 eval-triggers.sh：$SCRIPT" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "本測試需要 jq" >&2; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n     %s\n' "$1" "$2"; }
# has <label> <haystack> <needle>
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "輸出未包含：$3" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1" "輸出不該包含：$3" ;; *) ok "$1" ;; esac; }
eq()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "期望=$2 實得=$3"; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/trigeval.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT

# ── fixture skills 語料 ───────────────────────────────────────────────────────
CORPUS="$TMP/skills"; mkdir -p "$CORPUS"
mkskill() { # mkskill <name> [extra-frontmatter-line]
  mkdir -p "$CORPUS/$1"
  { printf -- '---\nname: %s\ndescription: Use when the user mentions %s.\n' "$1" "$1"
    [ -n "${2:-}" ] && printf '%s\n' "$2"
    printf -- '---\n\n# %s\n' "$1"
  } > "$CORPUS/$1/SKILL.md"
}
mkskill alpha
mkskill beta
mkskill userinv 'disable-model-invocation: true'

# symlink 化的 skill：~/.claude/skills 的項目都是指回 ~/.agents/skills 的 symlink，
# 若 install_skill 用 cp -R 而非 cp -RL，複製進去的會是斷掉的 symlink，skill 等同消失。
REAL="$TMP/real-gamma"; mkdir -p "$REAL"
{ printf -- '---\nname: gamma\ndescription: Use when the user mentions gamma.\n---\n\n# gamma\n'; } > "$REAL/SKILL.md"
ln -s "$REAL" "$CORPUS/gamma"

# run_eval <cases-file> <map-file> [extra args...]
# 印出合併後的 stdout+stderr，並以「函式回傳碼」帶回 eval-triggers.sh 的 exit code。
# 不用共享變數：呼叫端是 OUT=$(run_eval ...)，那是子 shell，子 shell 裡設的變數回不到父層
# （第一版正是這樣壞的）。回傳碼會穿過 command substitution，所以呼叫端直接讀 $?。
run_eval() {
  local cases="$1" map="$2"; shift 2
  local out rc
  out=$(SKILLEVAL_MOCK_MAP="$map" "$SCRIPT" --runner mock --cases "$cases" --skills "$CORPUS" "$@" 2>&1)
  rc=$?
  printf '%s' "$out"
  return "$rc"
}

echo "== 前置：mock runner 可執行性 =="
[ -x "$MOCK" ] && ok "exec-bit：mock-runner.sh 有執行權限" \
               || bad "exec-bit：mock-runner.sh 有執行權限" "缺 exec bit，真實執行時才會炸（chmod +x）"
[ -x "$SCRIPT" ] && ok "exec-bit：eval-triggers.sh 有執行權限" \
                 || bad "exec-bit：eval-triggers.sh 有執行權限" "缺 exec bit"

echo
echo "== 計分核心 =="
CASES="$TMP/c1.jsonl"; MAP="$TMP/m1.tsv"
cat > "$CASES" <<'JSONL'
{"id":"t-fire-hit","skill":"alpha","prompt":"please do ALPHAWORD now","expect":"fire"}
{"id":"t-quiet-hit","skill":"alpha","prompt":"totally unrelated request","expect":"quiet"}
{"id":"t-fire-miss","skill":"alpha","prompt":"NOTHINGFIRES here","expect":"fire"}
{"id":"t-collision","skill":"alpha","prompt":"BETAWINS this one","expect":"fire"}
{"id":"t-quiet-violated","skill":"alpha","prompt":"ALPHAWORD sneaks in","expect":"quiet"}
JSONL
printf 'ALPHAWORD\talpha\nBETAWINS\tbeta\nNOTHINGFIRES\t\n' > "$MAP"
OUT=$(run_eval "$CASES" "$MAP"); RC1=$?

has  "fire 命中 → PASS"                "$OUT" "t-fire-hit"
has  "quiet 命中 → PASS"               "$OUT" "t-quiet-hit"
has  "fire 落空 → FAIL no skill fired" "$OUT" "FAIL no skill fired"
has  "collision → FAIL 並指名贏家"      "$OUT" "FAIL collision — won by beta"
has  "quiet 被違反 → FAIL"             "$OUT" "FAIL fired when it should not"
has  "confusion matrix 有輸出"          "$OUT" "confusion: TP=1"
has  "FN 計 2（落空 + collision）"      "$OUT" "FN=2"
has  "FP 計 1"                          "$OUT" "FP=1"
has  "TN 計 1"                          "$OUT" "TN=1"
has  "recall 有算"                      "$OUT" "recall    = 0.33"
has  "precision 有算"                   "$OUT" "precision = 0.50"
eq   "有 FAIL 時 exit=1"                "1" "$RC1"

echo
echo "== 不可妥協的失敗語意 =="
CASES2="$TMP/c2.jsonl"; MAP2="$TMP/m2.tsv"
cat > "$CASES2" <<'JSONL'
{"id":"t-infra-down","skill":"alpha","prompt":"DEADRUNNER prompt","expect":"quiet"}
JSONL
printf 'DEADRUNNER\t__NORESULT__\n' > "$MAP2"
OUT2=$(run_eval "$CASES2" "$MAP2"); RC2=$?
has   "runner 無 result → ERR"                  "$OUT2" "ERR runner produced no result event"
hasnt "runner 無 result 不得被計為 PASS"        "$OUT2" "PASS"
eq    "只有 ERR 也要 exit=1（不是綠）"           "1" "$RC2"
has   "ERR 明講未被量測"                        "$OUT2" "unmeasured, not passes"

echo
echo "== user-invoked-only 必須 SKIP 而非 FN =="
CASES3="$TMP/c3.jsonl"
printf '%s\n' '{"id":"t-userinv","skill":"userinv","prompt":"anything","expect":"fire"}' > "$CASES3"
OUT3=$(run_eval "$CASES3" "$MAP"); RC3=$?
has   "disable-model-invocation → SKIP"     "$OUT3" "SKIP user-invoked only"
hasnt "SKIP 不得計為 FAIL"                   "$OUT3" "FAIL"
eq    "全 SKIP 視為乾淨 exit=0"              "0" "$RC3"

echo
echo "== symlink skill 需 deref（cp -RL）=="
CASES4="$TMP/c4.jsonl"; MAP4="$TMP/m4.tsv"
printf '%s\n' '{"id":"t-symlink","skill":"gamma","prompt":"GAMMAWORD please","expect":"fire"}' > "$CASES4"
printf 'GAMMAWORD\tgamma\n' > "$MAP4"
OUT4=$(run_eval "$CASES4" "$MAP4"); RC4=$?
hasnt "symlink skill 不得被判定為 not found" "$OUT4" "ERR skill not found"
eq    "symlink skill 可正常計分 exit=0"       "0" "$RC4"

echo
echo "== 輸入防呆與截斷誠實度 =="
CASES5="$TMP/c5.jsonl"
cat > "$CASES5" <<'JSONL'
{"id":"t-bad-expect","skill":"alpha","prompt":"x","expect":"maybe"}
{"skill":"alpha","prompt":"no id","expect":"fire"}
{"id":"t-missing-skill","skill":"nosuchskill","prompt":"x","expect":"fire"}
JSONL
OUT5=$(run_eval "$CASES5" "$MAP")
has "expect 非法 → ERR"        "$OUT5" "ERR expect must be fire|quiet"
has "缺欄位 → ERR malformed"   "$OUT5" "ERR malformed case"
has "skill 不存在 → ERR"       "$OUT5" "ERR skill not found"

OUT6=$(run_eval "$CASES" "$MAP" --max-cases 2)
has "--max-cases 明講截斷"     "$OUT6" "TRUNCATED: 3 case(s) not run"

: > "$TMP/empty.jsonl"
OUT7=$(run_eval "$TMP/empty.jsonl" "$MAP"); RC7=$?
has "空 cases → SCANNED NOTHING" "$OUT7" "SCANNED NOTHING"
eq  "空 cases → exit=2"          "2" "$RC7"

echo
echo "== mock 警語與 runner 防呆 =="
has "mock 結果自帶警語" "$OUT3" "NOT an audit result"
OUT8=$("$SCRIPT" --cases "$CASES" --skills "$CORPUS" 2>&1); RC8=$?
has "缺 --runner 直接拒跑" "$OUT8" "--runner is required"
eq  "缺 --runner exit=1"   "1" "$RC8"
OUT9=$("$SCRIPT" --runner nosuchrunner --cases "$CASES" --skills "$CORPUS" 2>&1); RC9=$?
has "未定義 runner 直接拒跑" "$OUT9" "not defined in"
eq  "未定義 runner exit=1"   "1" "$RC9"

echo
echo "== --jsonl 輸出可被機器讀 =="
JOUT="$TMP/out.jsonl"
run_eval "$CASES" "$MAP" --jsonl "$JOUT" >/dev/null
if [ -s "$JOUT" ] && jq -e . "$JOUT" >/dev/null 2>&1; then
  eq "--jsonl 每個 case 一列" "5" "$(wc -l < "$JOUT" | tr -d ' ')"
  has "--jsonl 記錄 collision 贏家" "$(cat "$JOUT")" '"winner":"skilleval:beta"'
else
  bad "--jsonl 輸出為合法 JSONL" "檔案空白或 jq 解析失敗"
fi

echo
echo "== Copilot review（PR #17）五項修正的回歸 =="
# 需要一棵可改 runners.json 的複本樹：eval-triggers.sh 由自身路徑推導 EVALS_DIR，
# 不能只換 runners.json 而不搬腳本。
COPY="$TMP/copy"; mkdir -p "$COPY/scripts" "$COPY/evals"
cp "$SCRIPT" "$COPY/scripts/eval-triggers.sh"
cp "$MOCK" "$COPY/evals/mock-runner.sh"
# 前導雜訊 + 帶空白的 JSON：釘住 runner_failed 不得靠 grep 字面 "type":"result"，
# 也釘住 parser 不得用 jq -s（一行不合法就整份 parse 陪葬）。
cat > "$COPY/evals/spaced-runner.sh" <<'SH'
#!/usr/bin/env sh
cat >/dev/null
printf 'Reading additional input from stdin...\n'
printf '{"type": "result", "subtype": "success", "is_error": false}\n'
SH
cat > "$COPY/evals/runners.json" <<'J'
{
  "noiso":  {"format":"claude-stream-json","command":["/bin/echo","{\"type\":\"result\"}"]},
  "spaced": {"format":"claude-stream-json","command":["{EVALS_DIR}/spaced-runner.sh","--setting-sources",""]},
  "mock":   {"format":"claude-stream-json","command":["{EVALS_DIR}/mock-runner.sh","{PLUGIN_DIR}"]}
}
J
chmod +x "$COPY/scripts/eval-triggers.sh" "$COPY/evals/mock-runner.sh" "$COPY/evals/spaced-runner.sh"

OUTA=$("$COPY/scripts/eval-triggers.sh" --runner noiso --cases "$CASES" --skills "$CORPUS" 2>&1); RCA=$?
has "無 --setting-sources 的 runner 直接拒跑" "$OUTA" "has no --setting-sources"
eq  "拒跑 exit=1"                              "1" "$RCA"

CASES6="$TMP/c6.jsonl"
printf '%s\n' '{"id":"t-spaced","skill":"alpha","prompt":"anything","expect":"quiet"}' > "$CASES6"
OUTB=$("$COPY/scripts/eval-triggers.sh" --runner spaced --cases "$CASES6" --skills "$CORPUS" 2>&1); RCB=$?
hasnt "帶空白的 result 事件不得被誤判為 runner 失敗" "$OUTB" "ERR runner produced no result event"
hasnt "前導非 JSON 行不得讓整份 parse 失敗"          "$OUTB" "ERR runner"
eq    "spaced runner 正常計分 exit=0"                "0" "$RCB"

# 路徑穿越：install_skill 內含 rm -rf，名稱未驗證時 `../x` 會刪到 plugin 之外。
CANARY="$TMP/canary-must-survive"; : > "$CANARY"
CASES7="$TMP/c7.jsonl"
{ printf '%s\n' '{"id":"t-traversal","skill":"../../../../..'"$(printf '%s' "${TMP#/}")"'","prompt":"x","expect":"fire"}'
  printf '%s\n' '{"id":"t-dotdot","skill":"..","prompt":"x","expect":"fire"}'
  printf '%s\n' '{"id":"t-slash","skill":"alpha/../beta","prompt":"x","expect":"fire"}'
  printf '%s\n' '{"id":"t-dotfile","skill":".ssh","prompt":"x","expect":"fire"}'
} > "$CASES7"
OUTC=$(run_eval "$CASES7" "$MAP" --isolate)
eq "四個穿越型名稱全部被拒（ERR skill not found ×4）" "4" \
   "$(printf '%s' "$OUTC" | grep -c 'ERR skill not found')"
[ -f "$CANARY" ] && ok "plugin 目錄外的檔案未被刪除" \
                 || bad "plugin 目錄外的檔案未被刪除" "canary 被 rm -rf 掉了"

# 畸形 case：ERR 行必須是唯一的錯誤輸出，不得混入 jq 自己的 parse error。
CASES8="$TMP/c8.jsonl"; printf '%s\n' '{"id":"broken", not json at all' > "$CASES8"
OUTD=$(run_eval "$CASES8" "$MAP")
has   "畸形行仍報 ERR malformed case" "$OUTD" "ERR malformed case"
hasnt "畸形行不得噴出 jq 自身的錯誤訊息" "$OUTD" "jq: error"

echo
echo "== 真實 cases.jsonl 自身健檢 =="
REALCASES="$EVALS/cases.jsonl"
if [ -r "$REALCASES" ]; then
  if jq -e . "$REALCASES" >/dev/null 2>&1; then ok "cases.jsonl 每列都是合法 JSON"
  else bad "cases.jsonl 每列都是合法 JSON" "jq 解析失敗"; fi
  missing=""
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    [ -r "$AGENTS/skills/$s/SKILL.md" ] || missing="$missing $s"
  done < <(jq -r '.skill' "$REALCASES" 2>/dev/null | sort -u)
  [ -z "$missing" ] && ok "cases.jsonl 指涉的 skill 全部存在" \
                    || bad "cases.jsonl 指涉的 skill 全部存在" "找不到：$missing"
else
  bad "cases.jsonl 存在" "$REALCASES 不存在"
fi

echo
printf '總計：PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
