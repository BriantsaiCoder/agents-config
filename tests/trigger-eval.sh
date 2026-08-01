#!/usr/bin/env bash
# eval-triggers.sh（Step 2c）離線回歸測試 —— 95 個斷言，零 API 呼叫。
# （數字別跟 evals/cases.jsonl 的 27 個 case 混淆：那是要送給模型的評測題目，
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
# 形狀無關解析：同一個 tool_use 物件放在 top-level 事件裡也必須被認出。位置敏感的
# parser 在 envelope 改變時會讓每個 case 都判 quiet，而 result 事件照常抵達——
# 又一次「parser 停止解析卻回報全綠」。
cat > "$COPY/evals/toplevel-runner.sh" <<'SH'
#!/usr/bin/env sh
cat >/dev/null
printf '{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"skilleval:alpha"}}\n'
printf '{"type":"result","subtype":"success","is_error":false}\n'
SH
# name=Skill 但缺 input.skill 的 tool_use：jq 在 -r 下會把缺值印成字面 "null"，
# 若未過濾就會被當成一個叫做 null 的 skill 觸發——collision 列出現幽靈贏家、
# quiet 列出現幽靈違規。形狀無關解析讓 `..` 走訪更多物件，這風險反而變高。
cat > "$COPY/evals/nullskill-runner.sh" <<'SH'
#!/usr/bin/env sh
cat >/dev/null
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t0","name":"Skill","input":{}}]}}\n'
printf '{"type":"result","subtype":"success","is_error":false}\n'
SH
# 已認證過期但仍吐出 result 事件——2026-08-01 實測：subtype 是 "success" 而 is_error 為 true。
# 只檢查 result 事件存在的守衛會把整場 auth outage 讀成「skill 沒觸發」，quiet 全數假通過。
cat > "$COPY/evals/autherr-runner.sh" <<'SH'
#!/usr/bin/env sh
cat >/dev/null
printf '{"type":"result","subtype":"success","is_error":true,"result":"Failed to authenticate: OAuth session expired and could not be refreshed","terminal_reason":"api_error"}\n'
SH
cat > "$COPY/evals/spaced-runner.sh" <<'SH'
#!/usr/bin/env sh
cat >/dev/null
printf 'Reading additional input from stdin...\n'
printf '{"type": "result", "subtype": "success", "is_error": false}\n'
SH
cat > "$COPY/evals/runners.json" <<'J'
{
  "noiso":  {"format":"claude-stream-json","command":["/bin/echo","{\"type\":\"result\"}"]},
  "badiso": {"format":"claude-stream-json","command":["/bin/echo","--setting-sources","user"]},
  "autherr": {"format":"claude-stream-json","command":["{EVALS_DIR}/autherr-runner.sh","--setting-sources",""]},
  "nullskill": {"format":"claude-stream-json","command":["{EVALS_DIR}/nullskill-runner.sh","--setting-sources",""]},
  "toplevel": {"format":"claude-stream-json","command":["{EVALS_DIR}/toplevel-runner.sh","--setting-sources",""]},
  "spaced": {"format":"claude-stream-json","command":["{EVALS_DIR}/spaced-runner.sh","--setting-sources",""]},
  "mock":   {"format":"claude-stream-json","command":["{EVALS_DIR}/mock-runner.sh","{PLUGIN_DIR}"]}
}
J
chmod +x "$COPY/scripts/eval-triggers.sh" "$COPY/evals/mock-runner.sh" "$COPY/evals/spaced-runner.sh" \
         "$COPY/evals/toplevel-runner.sh" "$COPY/evals/nullskill-runner.sh" "$COPY/evals/autherr-runner.sh"

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
echo "== Copilot re-review（PR #17 第二輪）兩項修正的回歸 =="
# quiet 的語意是「目標 skill 完全沒 fire」，不是「目標沒贏」。只看第一個 tool_use 時，
# 模型先叫 beta、後叫 alpha 的 transcript 會讓 alpha 的 quiet case 得到
# 「PASS (other skill fired: beta)」——目標明明 fire 了卻算通過，正是本檔第 1 條
# 驗收條件所禁止的假通過，只是換了一個入口。
CASES9="$TMP/c9.jsonl"; MAP9="$TMP/m9.tsv"
cat > "$CASES9" <<'JSONL'
{"id":"t-quiet-fires-second","skill":"alpha","prompt":"BETATHENALPHA here","expect":"quiet"}
{"id":"t-quiet-truly-silent","skill":"alpha","prompt":"BETAONLY here","expect":"quiet"}
JSONL
printf 'BETATHENALPHA\tbeta,alpha\nBETAONLY\tbeta\n' > "$MAP9"
OUTE=$(run_eval "$CASES9" "$MAP9"); RCE=$?
has   "目標 skill 後手 fire 仍須 FAIL"        "$OUTE" "FAIL fired when it should not"
has   "FAIL 訊息點出是誰先贏了該回合"          "$OUTE" "after beta won the turn"
has   "目標真的沒 fire 才算 PASS"              "$OUTE" "PASS (other skill fired: beta)"
eq    "有假通過被抓到 → exit=1"                "1" "$RCE"
eq    "FP 計 1（非 TN=2）"                     "1" "$(printf '%s' "$OUTE" | grep -o 'FP=[0-9]*' | cut -d= -f2)"

# case id 不得成為路徑片段：含 '/' 的 id 會把 transcript 寫到 $TMP 之外或互相覆寫。
CANARY2="$TMP/canary2-must-survive"; : > "$CANARY2"
CASES10="$TMP/c10.jsonl"
cat > "$CASES10" <<'JSONL'
{"id":"../../evil","skill":"alpha","prompt":"ALPHAWORD go","expect":"fire"}
{"id":"dup/../dup","skill":"alpha","prompt":"ALPHAWORD go","expect":"fire"}
JSONL
OUTF=$(run_eval "$CASES10" "$MAP"); RCF=$?
eq    "含 '/' 的 id 仍能正常計分（檔名不再取自 id）" "0" "$RCF"
# 用摘要行斷言而非 grep：舊版寫 grep -c 'ALPHAWORD\|fire *fire'，其中 ALPHAWORD 根本
# 不會出現在輸出裡（那是 prompt 不是輸出），而 \| 是 GNU BRE 擴充，在嚴格的 grep 上會
# 被當字面值而永遠 0 命中——一條既多餘又不可攜的斷言。
has   "兩列都真的跑過而非互相覆寫"                   "$OUTF" "cases=2  pass=2"
[ -f "$CANARY2" ] && ok "含穿越字元的 id 未寫出 \$TMP 之外" \
                  || bad "含穿越字元的 id 未寫出 \$TMP 之外" "canary2 消失"

echo
echo "== Copilot 第三輪 review 四項修正的回歸 =="
# 護欄只檢查旗標存在是半套的：--setting-sources user 會載入本機設定卻仍通過檢查，
# 產出看似「隔離」的數字——正是這道護欄當初被加進來要防的那件事。
OUTG=$("$COPY/scripts/eval-triggers.sh" --runner badiso --cases "$CASES" --skills "$CORPUS" 2>&1); RCG=$?
has "非空的 --setting-sources 值必須被擋" "$OUTG" "non-empty value"
eq  "非空隔離值 exit=1"                    "1" "$RCG"

# 參數防呆：壞的呼叫要死在一行清楚訊息上，不可洩漏 shell 自己的診斷到表格裡。
OUTH=$("$SCRIPT" --runner mock --max-cases foo --cases "$CASES" --skills "$CORPUS" 2>&1); RCH=$?
has   "--max-cases 非數字 → 明確訊息"   "$OUTH" "must be a non-negative integer"
hasnt "不得洩漏 shell 的 integer 診斷"   "$OUTH" "integer expression expected"
eq    "--max-cases 非數字 exit=1"        "1" "$RCH"
OUTI=$("$SCRIPT" --cases "$CASES" --skills "$CORPUS" --runner 2>&1); RCI=$?
has   "旗標缺值 → requires a value"      "$OUTI" "requires a value"
eq    "旗標缺值 exit=1"                  "1" "$RCI"

# --jsonl 不可寫時必須死，否則整輪跑完、使用者卻拿不到機器可讀輸出而不自知。
OUTJ=$(run_eval "$CASES" "$MAP" --jsonl "$TMP/no-such-dir/out.jsonl"); RCJ=$?
has "--jsonl 路徑不可寫 → 明確拒跑" "$OUTJ" "cannot write --jsonl target"
eq  "--jsonl 不可寫 exit=1"          "1" "$RCJ"

# 註解裡的斷言數字不得再寫死（本輪就是因為 47→55 沒同步而被抓到）。
hasnt "allowlist 註解不得寫死過期的斷言數" \
      "$(cat "$AGENTS/tests/matt-thin-workflow.sh")" "47 條斷言"

echo
echo "== Copilot 第四輪 review：形狀無關解析 =="
# tool_use 物件放在 top-level 事件而非 assistant.message.content[] 裡也必須被認出。
# 位置敏感的 parser 在 envelope 改變時會讓每個 case 都判 quiet，而 result 事件照常
# 抵達——「parser 停止解析卻回報全綠」，與本檔第 1 條同一個失效模式。
CASES11="$TMP/c11.jsonl"
printf '%s\n' '{"id":"t-toplevel","skill":"alpha","prompt":"x","expect":"fire"}' > "$CASES11"
OUTK=$("$COPY/scripts/eval-triggers.sh" --runner toplevel --cases "$CASES11" --skills "$CORPUS" --isolate 2>&1); RCK=$?
hasnt "top-level tool_use 不得被當成沒觸發" "$OUTK" "FAIL no skill fired"
eq    "top-level 形狀可正常計分 exit=0"      "0" "$RCK"
has   "top-level 形狀計為 TP"                "$OUTK" "TP=1"

# 巢狀形狀（真實 emitter 的形狀）不得因為改成形狀無關而退化。
CASES12="$TMP/c12.jsonl"
printf '%s\n' '{"id":"t-nested-still-ok","skill":"alpha","prompt":"ALPHAWORD go","expect":"fire"}' > "$CASES12"
OUTL=$(run_eval "$CASES12" "$MAP"); RCL=$?
eq "巢狀形狀仍正常（無回歸）" "0" "$RCL"

# 文件不得再宣稱 ground truth 是 top-level——那正是本輪被抓到的不一致。
has "runners.json 明載實際為巢狀形狀" \
    "$(cat "$EVALS/runners.json")" "the tool_use is NESTED, not top-level"

echo
echo "== Copilot 第五輪 review 兩項修正的回歸 =="
# name=Skill 但缺 input.skill 時，jq -r 會印出字面 "null"。未過濾就會被當成一個叫
# null 的 skill 觸發：collision 列冒出幽靈贏家、quiet 列冒出幽靈違規。
CASES13="$TMP/c13.jsonl"
printf '%s\n' '{"id":"t-nullskill","skill":"alpha","prompt":"x","expect":"quiet"}' > "$CASES13"
OUTM=$("$COPY/scripts/eval-triggers.sh" --runner nullskill --cases "$CASES13" --skills "$CORPUS" --isolate 2>&1); RCM=$?
# 斷言鎖在「幽靈 skill 名」本身，不是裸字串 null——runner 名稱就叫 nullskill，
# 用裸字串會被自己的 fixture 名稱誤觸（第一版正是這樣假紅的）。
hasnt "不得出現名為 null 的幽靈贏家"        "$OUTM" "other skill fired: null"
hasnt "不得把 null 當成觸發的目標 skill"     "$OUTM" "skilleval:null"
has   "缺 input.skill 視為未觸發（quiet 通過）" "$OUTM" "TN=1"
eq    "缺 input.skill exit=0"                   "0" "$RCM"

# --runner 錯誤訊息必須取自 runners.json 而非寫死。複本樹裡有 toplevel/nullskill 這些
# 正本沒有的 runner：訊息若是衍生的就會提到它們，寫死的就不會。
OUTN=$("$COPY/scripts/eval-triggers.sh" --cases "$CASES" --skills "$CORPUS" 2>&1)
has   "--runner 清單取自 runners.json（提到 toplevel）" "$OUTN" "toplevel"
hasnt "--runner 清單不得寫死正本的 runner 名"           "$OUTN" "claude-baseline"
# 底線開頭的鍵是文件區塊，不是 runner，不得混進清單。
hasnt "文件用的底線鍵不得被當成 runner 列出" \
      "$("$SCRIPT" --cases "$CASES" --skills "$CORPUS" 2>&1)" "_codex_deliberately_absent"

echo
echo "== Copilot 第六輪 review：ACTUAL 欄語意 =="
# ACTUAL 必須回答與 EXPECT 同一個問題（目標 skill 有沒有觸發），否則正確 PASS 的 quiet 列
# 會印出 `quiet fire PASS` 這種自相矛盾的行，JSONL 的 actual 也會對下游說謊。
CASES14="$TMP/c14.jsonl"; JOUT2="$TMP/out2.jsonl"
cat > "$CASES14" <<'JSONL'
{"id":"t-quiet-other-wins","skill":"alpha","prompt":"BETAONLY here","expect":"quiet"}
{"id":"t-fire-lost","skill":"alpha","prompt":"BETAONLY here","expect":"fire"}
JSONL
OUTO=$(run_eval "$CASES14" "$MAP9" --jsonl "$JOUT2")
has   "quiet 因他人獲勝而 PASS 時 ACTUAL 須為 quiet" "$OUTO" "quiet   quiet   PASS (other skill fired: beta)"
hasnt "不得再出現 quiet/fire 自相矛盾的列"            "$OUTO" "quiet   fire    PASS"
has   "fire 輸掉 collision 時 ACTUAL 亦為 quiet"      "$OUTO" "fire    quiet   FAIL collision — won by beta"
eq    "JSONL 的 actual 對 quiet 列為 quiet" "quiet" \
      "$(jq -r 'select(.id=="t-quiet-other-wins") | .actual' "$JOUT2")"
eq    "JSONL 仍保留贏家資訊（未因此遺失）" "skilleval:beta" \
      "$(jq -r 'select(.id=="t-quiet-other-wins") | .winner' "$JOUT2")"

echo
echo "== 認證過期：吐得出 result 事件不等於跑成功 =="
# 2026-08-01 實測抓到的真缺陷。OAuth 過期時 claude 仍會吐 {"type":"result"}，且 subtype
# 竟是 "success"，只有 is_error 為 true。只檢查 result 事件「存在」的守衛會把整場 auth
# outage 讀成「skill 沒觸發」——三個 quiet case 拿到 TN 假通過，報表看起來乾淨。
# 這正是本檔第 1 條驗收條件要禁止的事，而守衛自己漏了它。
CASES15="$TMP/c15.jsonl"
cat > "$CASES15" <<'JSONL'
{"id":"t-auth-quiet","skill":"alpha","prompt":"x","expect":"quiet"}
{"id":"t-auth-fire","skill":"alpha","prompt":"x","expect":"fire"}
JSONL
OUTP=$("$COPY/scripts/eval-triggers.sh" --runner autherr --cases "$CASES15" --skills "$CORPUS" --isolate 2>&1); RCP=$?
hasnt "auth 過期不得讓 quiet 取得假通過"     "$OUTP" "PASS"
has   "auth 過期必須計為 ERR"                "$OUTP" "ERR"
has   "ERR 須轉述 emitter 自己的原因"        "$OUTP" "OAuth session expired"
has   "兩列皆未被量測"                       "$OUTP" "err=2"
has   "confusion 不得把假通過算進 TN"        "$OUTP" "TN=0"
eq    "auth 過期 exit=1（不是綠）"           "1" "$RCP"

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
  jq -e 'select(.id=="fire-diagnosing-skill-pre-red" and .skill=="diagnosing-bugs" and .expect=="fire")' "$REALCASES" >/dev/null &&
    ok "pre-RED 由 diagnosing-bugs fire" || bad "pre-RED 由 diagnosing-bugs fire" "case 缺失或 contract 漂移"
  jq -e 'select(.id=="quiet-writing-skill-pre-red" and .skill=="writing-great-skills" and .expect=="quiet")' "$REALCASES" >/dev/null &&
    ok "pre-RED 時 writing-great-skills quiet" || bad "pre-RED 時 writing-great-skills quiet" "case 缺失或 contract 漂移"
  pre_red_fire_prompt=$(jq -r 'select(.id=="fire-diagnosing-skill-pre-red") | .prompt' "$REALCASES")
  pre_red_quiet_prompt=$(jq -r 'select(.id=="quiet-writing-skill-pre-red") | .prompt' "$REALCASES")
  eq "pre-RED fire/quiet 使用同一 prompt" "$pre_red_fire_prompt" "$pre_red_quiet_prompt"
  jq -e 'select(.id=="fire-writing-skill-after-red" and .skill=="writing-great-skills" and .expect=="fire")' "$REALCASES" >/dev/null &&
    ok "post-RED 由 writing-great-skills fire" || bad "post-RED 由 writing-great-skills fire" "case 缺失或 contract 漂移"
  jq -e 'select(.id=="fire-auditing-skill-folder" and .skill=="auditing-skill-folder" and .expect=="fire")' "$REALCASES" >/dev/null &&
    ok "folder audit 由 auditing-skill-folder fire" || bad "folder audit 由 auditing-skill-folder fire" "case 缺失或 contract 漂移"
  jq -e 'select(.id=="quiet-writing-great-skills-folder" and .skill=="writing-great-skills" and .expect=="quiet")' "$REALCASES" >/dev/null &&
    ok "folder audit 時 writing-great-skills quiet" || bad "folder audit 時 writing-great-skills quiet" "case 缺失或 contract 漂移"
  folder_fire_prompt=$(jq -r 'select(.id=="fire-auditing-skill-folder") | .prompt' "$REALCASES")
  folder_quiet_prompt=$(jq -r 'select(.id=="quiet-writing-great-skills-folder") | .prompt' "$REALCASES")
  eq "folder fire/quiet 使用同一 prompt" "$folder_fire_prompt" "$folder_quiet_prompt"
else
  bad "cases.jsonl 存在" "$REALCASES 不存在"
fi

echo
printf '總計：PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
