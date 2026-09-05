#!/usr/bin/env bash
# eval-triggers.sh（Step 2c）離線回歸測試，零 API 呼叫。
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
#      此 runner 只量測 Claude frontmatter；Codex／Copilot 未量測，不可折進同一數字。
#   3. collision 失敗必須在輸出裡「指名」贏家，否則 Step 2b 只是換個地方講同一句空話。
#   4. mock runner 的結果一定要自帶警語，不可能被誤讀成稽核數字。
#   5. runner 是以陣列直接 exec；fixture .sh 的 exec bit 必須由測試把關。
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

# symlink 化的 skill：top-level symlink 須先解析到實體目錄；skill 內部 symlink 則拒絕。
# 若直接 cp -R top-level symlink，複製進去的會是斷掉的 symlink，skill 等同消失。
REAL="$TMP/real-gamma"; mkdir -p "$REAL"
{ printf -- '---\nname: gamma\ndescription: Use when the user mentions gamma.\n---\n\n# gamma\n'; } > "$REAL/SKILL.md"
ln -s "$REAL" "$CORPUS/gamma"

# run_eval <cases-file> <map-file> [extra args...]
# 印出合併後的 stdout+stderr，並以「函式回傳碼」帶回 eval-triggers.sh 的 exit code。
# 不用共享變數：OUT=$(run_eval ...) 會進子 shell；回傳碼則能由呼叫端直接讀 $?。
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
echo "== collision arm 載入必須是 atomic =="
BROKEN_CORPUS="$TMP/broken-skills"
cp -RL "$CORPUS" "$BROKEN_CORPUS"
mkdir -p "$BROKEN_CORPUS/broken"
{ printf -- '---\nname: broken\ndescription: Use when broken.\n---\n\n# broken\n'; } \
  > "$BROKEN_CORPUS/broken/SKILL.md"
ln -s loop "$BROKEN_CORPUS/broken/loop"
CASES_BROKEN="$TMP/c-broken.jsonl"
printf '%s\n' '{"id":"t-broken-corpus","skill":"alpha","prompt":"ALPHAWORD","expect":"fire"}' \
  > "$CASES_BROKEN"
OUT_BROKEN=$(SKILLEVAL_MOCK_MAP="$MAP" "$SCRIPT" --runner mock --cases "$CASES_BROKEN" \
  --skills "$BROKEN_CORPUS" 2>&1); RC_BROKEN=$?
has   "任一 top-level skill 安裝失敗 → 整輪 ERR" "$OUT_BROKEN" "ERR collision arm 無法安裝 skill: broken"
hasnt "載入不完整不得繼續計分"                 "$OUT_BROKEN" "PASS"
eq    "載入不完整 exit=1"                       "1" "$RC_BROKEN"

echo
echo "== user-invoked-only 必須 SKIP 而非 FN =="
CASES3="$TMP/c3.jsonl"
printf '%s\n' '{"id":"t-userinv","skill":"userinv","prompt":"anything","expect":"fire"}' > "$CASES3"
OUT3=$(run_eval "$CASES3" "$MAP"); RC3=$?
has   "disable-model-invocation → SKIP"     "$OUT3" "SKIP user-invoked only"
hasnt "SKIP 不得計為 FAIL"                   "$OUT3" "FAIL"
eq    "全 SKIP 視為乾淨 exit=0"              "0" "$RC3"

echo
echo "== top-level symlink skill 需解析 =="
CASES4="$TMP/c4.jsonl"; MAP4="$TMP/m4.tsv"
printf '%s\n' '{"id":"t-symlink","skill":"gamma","prompt":"GAMMAWORD please","expect":"fire"}' > "$CASES4"
printf 'GAMMAWORD\tgamma\n' > "$MAP4"
OUT4=$(run_eval "$CASES4" "$MAP4"); RC4=$?
hasnt "symlink skill 不得被判定為 not found" "$OUT4" "ERR skill not found"
eq    "symlink skill 可正常計分 exit=0"       "0" "$RC4"

echo
echo "== skill 內部 symlink 不得離開 skill root =="
INTERNAL_LINK_CORPUS="$TMP/internal-link-skills"
cp -RL "$CORPUS" "$INTERNAL_LINK_CORPUS"
mkdir -p "$INTERNAL_LINK_CORPUS/escape" "$TMP/outside-skill"
{ printf -- '---\nname: escape\ndescription: Use when escape.\n---\n\n# escape\n'; } \
  > "$INTERNAL_LINK_CORPUS/escape/SKILL.md"
: > "$TMP/outside-skill/must-not-copy"
ln -s "$TMP/outside-skill" "$INTERNAL_LINK_CORPUS/escape/external"
CASES_INTERNAL_LINK="$TMP/c-internal-link.jsonl"
printf '%s\n' '{"id":"t-internal-link","skill":"alpha","prompt":"ALPHAWORD","expect":"fire"}' \
  > "$CASES_INTERNAL_LINK"
OUT_INTERNAL_LINK=$(SKILLEVAL_MOCK_MAP="$MAP" "$SCRIPT" --runner mock \
  --cases "$CASES_INTERNAL_LINK" --skills "$INTERNAL_LINK_CORPUS" 2>&1); RC_INTERNAL_LINK=$?
has   "內部 symlink → corpus 安裝失敗" "$OUT_INTERNAL_LINK" \
  "ERR collision arm 無法安裝 skill: escape"
hasnt "內部 symlink 不得繼續計分" "$OUT_INTERNAL_LINK" "PASS"
eq    "內部 symlink exit=1" "1" "$RC_INTERNAL_LINK"

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
  eq "--jsonl 明列 FAIL status" "FAIL" \
    "$(jq -r 'select(.id=="t-fire-miss") | .status' "$JOUT")"
else
  bad "--jsonl 輸出為合法 JSONL" "檔案空白或 jq 解析失敗"
fi

CASES_JSON_ALL="$TMP/c-json-all.jsonl"; JOUT_ALL="$TMP/out-all.jsonl"
cat > "$CASES_JSON_ALL" <<'JSONL'
{"id":"json-pass","skill":"alpha","prompt":"unrelated","expect":"quiet"}
{"id":"json-skip","skill":"userinv","prompt":"anything","expect":"fire"}
{"id":"json-err","skill":"nosuchskill","prompt":"anything","expect":"fire"}
JSONL
run_eval "$CASES_JSON_ALL" "$MAP" --jsonl "$JOUT_ALL" >/dev/null
eq "--jsonl 保留 PASS／SKIP／ERR 每一列" "3" "$(wc -l < "$JOUT_ALL" | tr -d ' ')"
eq "--jsonl 明列 PASS status" "PASS" "$(jq -r 'select(.id=="json-pass") | .status' "$JOUT_ALL")"
eq "--jsonl 明列 SKIP status" "SKIP" "$(jq -r 'select(.id=="json-skip") | .status' "$JOUT_ALL")"
eq "--jsonl 明列 ERR status"  "ERR"  "$(jq -r 'select(.id=="json-err") | .status' "$JOUT_ALL")"

echo
echo "== runner isolation 與 stream parser =="
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
# 認證錯誤仍可能吐出 subtype=success 的 result；is_error=true 才是失敗訊號。
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
cat > "$COPY/evals/nonzero-runner.sh" <<'SH'
#!/usr/bin/env sh
cat >/dev/null
printf '{"type":"result","subtype":"success","is_error":false}\n'
exit 7
SH
cat > "$COPY/evals/late-error-runner.sh" <<'SH'
#!/usr/bin/env sh
cat >/dev/null
printf '{"type":"result","subtype":"success","is_error":false}\n'
printf '{"type":"result","subtype":"success","is_error":true,"result":"late runner failure"}\n'
SH
cat > "$COPY/evals/fresh-cwd-runner.sh" <<'SH'
#!/usr/bin/env sh
cat >/dev/null
if [ -e .case-marker ]; then
  printf '{"type":"result","subtype":"success","is_error":true,"result":"cwd reused across cases"}\n'
else
  : > .case-marker
  printf '{"type":"result","subtype":"success","is_error":false}\n'
fi
SH
cat > "$COPY/evals/runners.json" <<'J'
{
  "noiso":  {"format":"claude-stream-json","command":["/bin/echo","{\"type\":\"result\"}"]},
  "badiso": {"format":"claude-stream-json","command":["/bin/echo","--setting-sources","user"]},
  "autherr": {"format":"claude-stream-json","command":["{EVALS_DIR}/autherr-runner.sh","--setting-sources",""]},
  "nullskill": {"format":"claude-stream-json","command":["{EVALS_DIR}/nullskill-runner.sh","--setting-sources",""]},
  "toplevel": {"format":"claude-stream-json","command":["{EVALS_DIR}/toplevel-runner.sh","--setting-sources",""]},
  "spaced": {"format":"claude-stream-json","command":["{EVALS_DIR}/spaced-runner.sh","--setting-sources",""]},
  "nonzero": {"format":"claude-stream-json","command":["{EVALS_DIR}/nonzero-runner.sh","--setting-sources",""]},
  "lateerr": {"format":"claude-stream-json","command":["{EVALS_DIR}/late-error-runner.sh","--setting-sources",""]},
  "freshcwd": {"format":"claude-stream-json","command":["{EVALS_DIR}/fresh-cwd-runner.sh","--setting-sources",""]},
  "mock":   {"format":"claude-stream-json","command":["{EVALS_DIR}/mock-runner.sh","{PLUGIN_DIR}"]}
}
J
chmod +x "$COPY/scripts/eval-triggers.sh" "$COPY/evals/mock-runner.sh" "$COPY/evals/spaced-runner.sh" \
         "$COPY/evals/toplevel-runner.sh" "$COPY/evals/nullskill-runner.sh" "$COPY/evals/autherr-runner.sh" \
         "$COPY/evals/nonzero-runner.sh" "$COPY/evals/late-error-runner.sh" \
         "$COPY/evals/fresh-cwd-runner.sh"

OUTA=$("$COPY/scripts/eval-triggers.sh" --runner noiso --cases "$CASES" --skills "$CORPUS" 2>&1); RCA=$?
has "無 --setting-sources 的 runner 直接拒跑" "$OUTA" "缺少 --setting-sources"
eq  "拒跑 exit=1"                              "1" "$RCA"

CASES6="$TMP/c6.jsonl"
printf '%s\n' '{"id":"t-spaced","skill":"alpha","prompt":"anything","expect":"quiet"}' > "$CASES6"
OUTB=$("$COPY/scripts/eval-triggers.sh" --runner spaced --cases "$CASES6" --skills "$CORPUS" 2>&1); RCB=$?
hasnt "帶空白的 result 事件不得被誤判為 runner 失敗" "$OUTB" "ERR runner produced no result event"
hasnt "前導非 JSON 行不得讓整份 parse 失敗"          "$OUTB" "ERR runner"
eq    "spaced runner 正常計分 exit=0"                "0" "$RCB"

CASES_FRESH_CWD="$TMP/c-fresh-cwd.jsonl"
cat > "$CASES_FRESH_CWD" <<'JSONL'
{"id":"t-fresh-cwd-1","skill":"alpha","prompt":"anything","expect":"quiet"}
{"id":"t-fresh-cwd-2","skill":"alpha","prompt":"anything","expect":"quiet"}
JSONL
OUT_FRESH_CWD=$("$COPY/scripts/eval-triggers.sh" --runner freshcwd --cases "$CASES_FRESH_CWD" \
  --skills "$CORPUS" --isolate 2>&1); RC_FRESH_CWD=$?
hasnt "每個 case 的 cwd 不得重用" "$OUT_FRESH_CWD" "ERR cwd reused across cases"
has   "兩個 case 都在獨立 cwd 完成" "$OUT_FRESH_CWD" "cases=2  pass=2"
eq    "per-case fresh cwd exit=0" "0" "$RC_FRESH_CWD"

CASES_NONZERO="$TMP/c-nonzero.jsonl"
printf '%s\n' '{"id":"t-nonzero","skill":"alpha","prompt":"anything","expect":"quiet"}' > "$CASES_NONZERO"
OUT_NONZERO=$("$COPY/scripts/eval-triggers.sh" --runner nonzero --cases "$CASES_NONZERO" \
  --skills "$CORPUS" --isolate 2>&1); RC_NONZERO=$?
has   "runner non-zero 即使有 healthy result 仍為 ERR" "$OUT_NONZERO" "ERR runner 的 exit status 為 7"
hasnt "runner non-zero 不得計為 PASS"                 "$OUT_NONZERO" "PASS"
eq    "runner non-zero exit=1"                        "1" "$RC_NONZERO"

CASES_LATEERR="$TMP/c-lateerr.jsonl"
printf '%s\n' '{"id":"t-lateerr","skill":"alpha","prompt":"anything","expect":"quiet"}' > "$CASES_LATEERR"
OUT_LATEERR=$("$COPY/scripts/eval-triggers.sh" --runner lateerr --cases "$CASES_LATEERR" \
  --skills "$CORPUS" --isolate 2>&1); RC_LATEERR=$?
has   "後續 result error 不得被先前 success 遮蔽" "$OUT_LATEERR" "ERR late runner failure"
hasnt "後續 result error 不得計為 PASS"          "$OUT_LATEERR" "PASS"
eq    "後續 result error exit=1"                  "1" "$RC_LATEERR"

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
echo "== quiet 全 transcript 與安全檔名 =="
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
echo "== CLI guardrails =="
HELP_OUT=$("$SCRIPT" --help 2>&1); HELP_RC=$?
has   "--help 顯示使用方式"             "$HELP_OUT" "使用方式："
hasnt "--help 不得洩漏 shell options"   "$HELP_OUT" "set -uo pipefail"
hasnt "--help 不得洩漏 executable source" "$HELP_OUT" "SELF_DIR="
eq    "--help exit=0"                    "0" "$HELP_RC"

# UNVERIFIED: current Claude CLI loading semantics；2026-08-01 probe 曾觀察到
# --setting-sources user 讀取本機設定。此測試只釘住 local guard 同時檢查 flag 與 value。
OUTG=$("$COPY/scripts/eval-triggers.sh" --runner badiso --cases "$CASES" --skills "$CORPUS" 2>&1); RCG=$?
has "非空的 --setting-sources 值必須被擋" "$OUTG" "--setting-sources 為非空值"
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

# 註解裡的斷言數字不得寫死，避免測試新增後文件漂移。
hasnt "allowlist 註解不得寫死過期的斷言數" \
      "$(cat "$AGENTS/tests/matt-thin-workflow.sh")" "47 條斷言"

echo
echo "== stream shape compatibility =="
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
run_eval "$CASES12" "$MAP" >/dev/null; RCL=$?
eq "巢狀形狀仍正常（無回歸）" "0" "$RCL"

# 文件與 parser 必須承認真實 emitter 的巢狀形狀。
has "runners.json 明載實際為巢狀形狀" \
    "$(cat "$EVALS/runners.json")" "tool_use 形狀是 NESTED"

echo
echo "== missing skill names 與 runner discovery =="
# name=Skill 但缺 input.skill 時，jq -r 會印出字面 "null"。未過濾就會被當成一個叫
# null 的 skill 觸發：collision 列冒出幽靈贏家、quiet 列冒出幽靈違規。
CASES13="$TMP/c13.jsonl"
printf '%s\n' '{"id":"t-nullskill","skill":"alpha","prompt":"x","expect":"quiet"}' > "$CASES13"
OUTM=$("$COPY/scripts/eval-triggers.sh" --runner nullskill --cases "$CASES13" --skills "$CORPUS" --isolate 2>&1); RCM=$?
# 斷言鎖在「幽靈 skill 名」本身；裸字串 null 會被 fixture 名稱 nullskill 誤觸。
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
echo "== ACTUAL 欄語意 =="
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
# OAuth 過期仍可能吐 subtype=success 的 result；is_error=true 時不得計分。
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
  jq -e 'select(.id=="quiet-writing-skill-pre-red" and .skill=="writing-for-agents" and .expect=="quiet")' "$REALCASES" >/dev/null &&
    ok "pre-RED 時 writing-for-agents quiet" || bad "pre-RED 時 writing-for-agents quiet" "case 缺失或 contract 漂移"
  pre_red_fire_prompt=$(jq -r 'select(.id=="fire-diagnosing-skill-pre-red") | .prompt' "$REALCASES")
  pre_red_quiet_prompt=$(jq -r 'select(.id=="quiet-writing-skill-pre-red") | .prompt' "$REALCASES")
  eq "pre-RED fire/quiet 使用同一 prompt" "$pre_red_fire_prompt" "$pre_red_quiet_prompt"
  jq -e 'select(.id=="fire-diagnosing-agents-doc-pre-red" and .skill=="diagnosing-bugs" and .expect=="fire")' "$REALCASES" >/dev/null &&
    ok "agent doc pre-RED 由 diagnosing-bugs fire" || bad "agent doc pre-RED 由 diagnosing-bugs fire" "case 缺失或 contract 漂移"
  jq -e 'select(.id=="quiet-writing-agents-doc-pre-red" and .skill=="writing-for-agents" and .expect=="quiet")' "$REALCASES" >/dev/null &&
    ok "agent doc pre-RED 時 writing-for-agents quiet" || bad "agent doc pre-RED 時 writing-for-agents quiet" "case 缺失或 contract 漂移"
  agent_doc_pre_red_fire=$(jq -r 'select(.id=="fire-diagnosing-agents-doc-pre-red") | .prompt' "$REALCASES")
  agent_doc_pre_red_quiet=$(jq -r 'select(.id=="quiet-writing-agents-doc-pre-red") | .prompt' "$REALCASES")
  eq "agent doc pre-RED fire/quiet 使用同一 prompt" "$agent_doc_pre_red_fire" "$agent_doc_pre_red_quiet"
  jq -e 'select(.id=="fire-writing-skill-after-red" and .skill=="writing-for-agents" and .expect=="fire")' "$REALCASES" >/dev/null &&
    ok "post-RED 由 writing-for-agents fire" || bad "post-RED 由 writing-for-agents fire" "case 缺失或 contract 漂移"
  jq -e 'select(.id=="fire-auditing-skill-folder" and .skill=="auditing-skill-folder" and .expect=="fire")' "$REALCASES" >/dev/null &&
    ok "folder audit 由 auditing-skill-folder fire" || bad "folder audit 由 auditing-skill-folder fire" "case 缺失或 contract 漂移"
  jq -e 'select(.id=="quiet-writing-for-agents-folder" and .skill=="writing-for-agents" and .expect=="quiet")' "$REALCASES" >/dev/null &&
    ok "folder audit 時 writing-for-agents quiet" || bad "folder audit 時 writing-for-agents quiet" "case 缺失或 contract 漂移"
  folder_fire_prompt=$(jq -r 'select(.id=="fire-auditing-skill-folder") | .prompt' "$REALCASES")
  folder_quiet_prompt=$(jq -r 'select(.id=="quiet-writing-for-agents-folder") | .prompt' "$REALCASES")
  eq "folder fire/quiet 使用同一 prompt" "$folder_fire_prompt" "$folder_quiet_prompt"
  jq -e 'select(.id=="fire-writing-skill-user-only" and .skill=="writing-for-agents" and .expect=="fire")' "$REALCASES" >/dev/null &&
    ok "純 metadata 編輯由 writing-for-agents fire" || bad "純 metadata 編輯由 writing-for-agents fire" "case 缺失或 contract 漂移"
  for generalized_suffix in agents-md claude-md pointed-doc; do
    generalized_fire="fire-writing-$generalized_suffix"
    generalized_quiet="quiet-init-project-docs-writing-$generalized_suffix"
    jq -e --arg id "$generalized_fire" 'select(.id==$id and .skill=="writing-for-agents" and .expect=="fire")' "$REALCASES" >/dev/null &&
      ok "writing-for-agents generalized fire: $generalized_suffix" ||
      bad "writing-for-agents generalized fire: $generalized_suffix" "case 缺失或 contract 漂移"
    jq -e --arg id "$generalized_quiet" 'select(.id==$id and .skill=="init-project-docs" and .expect=="quiet")' "$REALCASES" >/dev/null &&
      ok "init-project-docs generalized quiet: $generalized_suffix" ||
      bad "init-project-docs generalized quiet: $generalized_suffix" "case 缺失或 contract 漂移"
    generalized_fire_prompt=$(jq -r --arg id "$generalized_fire" 'select(.id==$id) | .prompt' "$REALCASES")
    generalized_quiet_prompt=$(jq -r --arg id "$generalized_quiet" 'select(.id==$id) | .prompt' "$REALCASES")
    eq "generalized fire/quiet 使用同一 prompt: $generalized_suffix" "$generalized_fire_prompt" "$generalized_quiet_prompt"
  done
  jq -e 'select(.id=="quiet-diagnosing-skill-user-only" and .skill=="diagnosing-bugs" and .expect=="quiet")' "$REALCASES" >/dev/null &&
    ok "純 metadata 編輯時 diagnosing-bugs quiet" || bad "純 metadata 編輯時 diagnosing-bugs quiet" "case 缺失或 contract 漂移"
  user_only_fire_prompt=$(jq -r 'select(.id=="fire-writing-skill-user-only") | .prompt' "$REALCASES")
  user_only_quiet_prompt=$(jq -r 'select(.id=="quiet-diagnosing-skill-user-only") | .prompt' "$REALCASES")
  eq "user-only fire/quiet 使用同一 prompt" "$user_only_fire_prompt" "$user_only_quiet_prompt"
  # 2026-09-05 stack skill owner 對：quiet 與 fire 共用同一 prompt，任一側改 prompt 即靜默拆散配對，
  # 兩側各自 PASS。fire 側 prompt 為空表示 id 漂移，quiet 側 expect 被翻成 fire 則 owner 語意失效，同樣算壞。
  for owner_pair in fire-dapper:quiet-ef-core-dapper fire-ef-core-migration:quiet-dapper-efcore \
      fire-ef-core-migration:quiet-ef6-efcore-migration fire-ef6-lazy-n1:quiet-ef-core-ef6-edmx \
      fire-rr-redirect-action:quiet-next-rr-redirect-action fire-next-double-render:quiet-rr-next-app-router \
      collision-rtl-wins:quiet-react-rtl-query fire-rr-protected-route:quiet-auth-rr-protected-route; do
    owner_fire=${owner_pair%%:*}; owner_quiet=${owner_pair#*:}
    owner_fire_prompt=$(jq -r --arg id "$owner_fire" 'select(.id==$id) | .prompt' "$REALCASES")
    owner_quiet_prompt=$(jq -r --arg id "$owner_quiet" 'select(.id==$id) | .prompt' "$REALCASES")
    [ -n "$owner_fire_prompt" ] && ok "owner 對 fire 側存在: $owner_fire" || bad "owner 對 fire 側存在: $owner_fire" "id 缺失"
    jq -e --arg id "$owner_quiet" 'select(.id==$id and .expect=="quiet")' "$REALCASES" >/dev/null &&
      ok "owner 對 quiet 側極性: $owner_quiet" || bad "owner 對 quiet 側極性: $owner_quiet" "id 缺失或 expect 非 quiet"
    eq "owner 對 fire/quiet 使用同一 prompt: $owner_quiet" "$owner_fire_prompt" "$owner_quiet_prompt"
  done
else
  bad "cases.jsonl 存在" "$REALCASES 不存在"
fi

echo
printf '總計：PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$PASS" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$FAIL" -eq 0 ] || exit 1
