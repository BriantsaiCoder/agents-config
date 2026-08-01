#!/usr/bin/env bash
# Step 2c — Trigger accuracy eval；Step 2 的 BEHAVIOURAL 對應。
#
# Step 2（lint-descriptions.sh）以 regex 從 description 推測是否具備 trigger；這只是 proxy。
# 此 script 使用 realistic prompt 量測 skill 是否 fire，以及應 quiet 時是否保持 quiet。
#
# 此 script 也讓 Step 2b（trigger collision）可實際量測；原 Step 2b 需人工跨列判斷兩個
# descriptions 是否占用同一 trigger space。
# Collision arm 會提供所有 corpus skills，transcript 會指出 WINNER，讓 collision 可被觀察。
# UNVERIFIED: current Claude CLI loading semantics。2026-08-01 probe 在兩個 arms 都觀察到 built-ins。
#
# 使用方式：
#   eval-triggers.sh --runner claude [--cases FILE] [--skills DIR] [--max-cases N] [--isolate] [--jsonl OUT]
#
#   --runner NAME   必填，刻意不提供 default。'claude' 會消耗 rate-limit budget；'mock' 只回傳
#                   canned data，不得視為 audit result；任一 default 都可能造成靜默誤判。
#   --isolate       只提供 target skill corpus；built-ins 仍可能載入。此模式量測 recall，
#                   不含 supplied-skill collision pressure。Default 提供所有 corpus skills，
#                   只有此 arm 可觀察 supplied-skill collision。
#   --max-cases N   執行 N 個 cases 後停止並列出 skipped；截斷結果不得回報 full coverage。
#
# Exit：0 = 所有 cases 符合 expectation；1 = 至少一個 mismatch；2 = 未執行任何 case。
#
# SCOPE：只量測哪個 skill fire，不量測 skill body 的 output quality；後者使用獨立 rubric。
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd) || exit 1
SKILL_ROOT=$(cd "$SELF_DIR/.." && pwd)
EVALS_DIR="$SKILL_ROOT/evals"
PLUGIN_NAME="skilleval"

RUNNER=""
CASES="$EVALS_DIR/cases.jsonl"
SKILLS_DIR="${AGENTS_HOME:-$HOME/.agents}/skills"
MAX_CASES=0
ISOLATE=0
JSONL_OUT=""

die() { printf 'eval-triggers: %s\n' "$*" >&2; exit 1; }
need_val() { [ "$#" -ge 2 ] || die "$1 requires a value"; }

while [ $# -gt 0 ]; do
  case "$1" in
    # shift 前先驗證，缺值時只輸出一行可解析錯誤。
    --runner)    need_val "$@"; RUNNER="$2"; shift 2 ;;
    --cases)     need_val "$@"; CASES="$2"; shift 2 ;;
    --skills)    need_val "$@"; SKILLS_DIR="$2"; shift 2 ;;
    --max-cases) need_val "$@"
                 case "$2" in ''|*[!0-9]*) die "--max-cases must be a non-negative integer, got: $2" ;; esac
                 MAX_CASES="$2"; shift 2 ;;
    --jsonl)     need_val "$@"; JSONL_OUT="$2"; shift 2 ;;
    --isolate)   ISOLATE=1; shift ;;
    -h|--help)   awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
    *)           die "unknown argument: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq is required (used by 5 existing tests/ scripts; brew install jq)"

RUNNERS_JSON="$EVALS_DIR/runners.json"
[ -r "$RUNNERS_JSON" ] || die "runners.json not found: $RUNNERS_JSON"

# Runner 名稱取自 config；底線開頭的 key 是文件。
runner_names() { jq -r 'keys[] | select(startswith("_") | not)' "$RUNNERS_JSON" 2>/dev/null | paste -sd'|' -; }
[ -n "$RUNNER" ] ||
  die "--runner is required ($(runner_names)). No default: a live runner spends rate limit and mock returns canned data, so defaulting to either is a way to be silently wrong."
[ -r "$CASES" ]  || die "cases file not found: $CASES"
[ -d "$SKILLS_DIR" ] || die "skills dir not found: $SKILLS_DIR"
jq -e --arg r "$RUNNER" 'has($r)' "$RUNNERS_JSON" >/dev/null 2>&1 ||
  die "runner '$RUNNER' not defined in $RUNNERS_JSON"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/skilleval.XXXXXX") || die "mktemp failed"
trap 'rm -rf "$TMP"' EXIT
PLUGIN_DIR="$TMP/plugin"
mkdir -p "$PLUGIN_DIR/.claude-plugin" "$PLUGIN_DIR/skills" || die "mkdir failed under $TMP"
printf '{"name":"%s","version":"0.0.1","description":"throwaway plugin for trigger eval"}\n' \
  "$PLUGIN_NAME" > "$PLUGIN_DIR/.claude-plugin/plugin.json"

# read_frontmatter_bool <skill.md> <key> -> "true" | "false"
# Only the frontmatter block is scanned: a body line saying "disable-model-invocation" is prose.
read_frontmatter_bool() {
  awk -v key="$2" '
    NR==1 && /^---[[:space:]]*$/ { fm=1; next }
    fm==0 { exit }
    /^---[[:space:]]*$/ { exit }
    $0 ~ "^" key ":[[:space:]]*true[[:space:]]*$" { print "true"; exit }
  ' "$1" 2>/dev/null | grep -q true && echo true || echo false
}

# install_skill <name> — 將一個 skill 複製到暫用 plugin。
# 僅解析 top-level skill symlink；skill 內部 symlink 可能越界複製，必須拒絕。
# 名稱須在受保護的 rm -rf 前驗證，避免 case 資料離開暫用 plugin。
install_skill() {
  local name="$1" src internal_link
  case "$name" in
    ''|.|..|*/*|*'\'*|.*) return 2 ;;
  esac
  src="$SKILLS_DIR/$name"
  [ -r "$src/SKILL.md" ] || return 1
  src=$(cd "$src" 2>/dev/null && pwd -P) || return 1
  internal_link=$(find "$src" -type l -print -quit 2>/dev/null) || return 1
  [ -z "$internal_link" ] || return 1
  rm -rf "${PLUGIN_DIR:?}/skills/${name:?}"
  cp -R "$src" "$PLUGIN_DIR/skills/$name" 2>/dev/null || return 1
  return 0
}

install_all_skills() {
  local d n
  installed=0
  for d in "$SKILLS_DIR"/*/; do
    n=$(basename "$d")
    if ! install_skill "$n"; then
      printf 'ERR collision arm 無法安裝 skill: %s\n' "$n" >&2
      return 1
    fi
    installed=$((installed + 1))
  done
}

# 解析 runner command 並替換 placeholders。
# 使用 read loop 以相容沒有 mapfile 的 macOS bash 3.2。
RUNNER_CMD=()
while IFS= read -r _arg; do
  RUNNER_CMD+=("$_arg")
done < <(jq -r --arg r "$RUNNER" --arg p "$PLUGIN_DIR" --arg e "$EVALS_DIR" \
  '.[$r].command[] | gsub("\\{PLUGIN_DIR\\}"; $p) | gsub("\\{EVALS_DIR\\}"; $e)' "$RUNNERS_JSON")
[ "${#RUNNER_CMD[@]}" -gt 0 ] || die "runner '$RUNNER' has an empty command array"

# Live runner contract 要求 `--setting-sources ''`；current CLI semantics 的
# `UNVERIFIED:` boundary 記錄於 runners.json。Mock 不呼叫 model，因此豁免。
if [ "$RUNNER" != "mock" ]; then
  _iso=0; _seen=0; _n=${#RUNNER_CMD[@]}; _i=0
  while [ "$_i" -lt "$_n" ]; do
    if [ "${RUNNER_CMD[$_i]}" = "--setting-sources" ]; then
      _seen=1
      _j=$((_i + 1))
      [ "$_j" -lt "$_n" ] && [ -z "${RUNNER_CMD[$_j]}" ] && _iso=1
    fi
    _i=$((_i + 1))
  done
  if [ "$_seen" -eq 0 ]; then
    die "runner '$RUNNER' 缺少 --setting-sources：isolation contract 要求明確的空字串"
  elif [ "$_iso" -eq 0 ]; then
    die "runner '$RUNNER' 的 --setting-sources 為非空值：isolation contract 只允許 \"\""
  fi
fi

# skill_calls <stream-file> -> 依序逐行輸出該 turn 的所有 Skill invocation。
# 逐行解析，避免 banner 讓整個 stream 失效；遞迴讀取不同 envelope shapes，避免有 valid
# result 卻漏掉 tool call 時被誤判 quiet。缺少 input.skill 的值須丟棄，避免 jq 的 `null`
# 成為不存在的 winner。
skill_calls() {
  jq -R -r 'fromjson? | .. | objects
            | select(.type? == "tool_use" and .name? == "Skill")
            | .input?.skill? // empty' \
    "$1" 2>/dev/null
}

runner_failed() {
  # 沒有 result 或任何 is_error=true 都是 infrastructure failure，不得計為 quiet。
  # 必須解析所有 result，避免較早的 success 遮蔽後續 auth/rate-limit failure。
  _res=$(jq -R -r 'fromjson? | select(.type=="result")
                   | if (.is_error == true) then "err" else "ok" end' "$1" 2>/dev/null)
  [ -n "$_res" ] || return 0
  printf '%s\n' "$_res" | grep -qx err
}

# runner_error_reason <stream-file> -> ERR row 的 emitter 說明。
runner_error_reason() {
  jq -R -r 'fromjson? | select(.type=="result" and .is_error == true) | .result? // empty' \
    "$1" 2>/dev/null | head -1 | cut -c1-80
}

printf '%-26s %-30s %-7s %-7s %s\n' "CASE" "TARGET SKILL" "EXPECT" "ACTUAL" "RESULT"
printf '%-26s %-30s %-7s %-7s %s\n' "----" "------------" "------" "------" "------"

total=0; pass=0; fail=0; skipped=0; errored=0; truncated=0
tp=0; fp=0; fn=0; tn=0
# 計分前拒絕不可寫的 JSONL target；缺少要求的 output 不得算 success。
[ -n "$JSONL_OUT" ] && { : > "$JSONL_OUT" 2>/dev/null || die "cannot write --jsonl target: $JSONL_OUT"; }

emit_jsonl() {
  [ -n "$JSONL_OUT" ] || return 0
  jq -cn --arg id "$1" --arg skill "$2" --arg expect "$3" --arg actual "$4" \
    --arg won "$5" --arg status "$6" --arg verdict "$7" --arg runner "$RUNNER" \
    '{id:$id,skill:$skill,expect:$expect,actual:$actual,winner:$won,status:$status,verdict:$verdict,runner:$runner}' \
    >> "$JSONL_OUT" || die "無法 append --jsonl target: $JSONL_OUT"
}

if [ "$ISOLATE" -eq 0 ]; then
  installed=0
  install_all_skills || exit 1
  printf '# arm=collision  skills loaded=%s  runner=%s\n' "$installed" "$RUNNER"
else
  printf '# arm=isolate  (one skill per case)  runner=%s\n' "$RUNNER"
fi

while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in \#*) continue ;; esac

  # 隱藏 jq diagnostics；malformed row 僅輸出一行穩定的 ERR。
  id=$(printf '%s' "$line"     | jq -r '.id // empty'     2>/dev/null)
  skill=$(printf '%s' "$line"  | jq -r '.skill // empty'  2>/dev/null)
  prompt=$(printf '%s' "$line" | jq -r '.prompt // empty' 2>/dev/null)
  expect=$(printf '%s' "$line" | jq -r '.expect // empty' 2>/dev/null)
  [ -n "$id" ] && [ -n "$skill" ] && [ -n "$prompt" ] && [ -n "$expect" ] || {
    printf '%-26s %-30s %-7s %-7s %s\n' "${id:-(no id)}" "${skill:-?}" "-" "-" "ERR malformed case"
    emit_jsonl "${id:-(no id)}" "${skill:-?}" "-" "-" "" "ERR" "ERR malformed case"
    errored=$((errored + 1)); continue; }
  case "$expect" in fire|quiet) ;; *)
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR expect must be fire|quiet"
    emit_jsonl "$id" "$skill" "$expect" "-" "" "ERR" "ERR expect must be fire|quiet"
    errored=$((errored + 1)); continue ;;
  esac

  if [ "$MAX_CASES" -gt 0 ] && [ "$total" -ge "$MAX_CASES" ]; then
    truncated=$((truncated + 1)); continue
  fi
  total=$((total + 1))

  if [ "$ISOLATE" -eq 1 ]; then
    rm -rf "${PLUGIN_DIR:?}/skills"; mkdir -p "$PLUGIN_DIR/skills"
    install_skill "$skill" || {
      printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR skill not found"
      emit_jsonl "$id" "$skill" "$expect" "-" "" "ERR" "ERR skill not found"
      errored=$((errored + 1)); continue; }
  elif [ ! -r "$PLUGIN_DIR/skills/$skill/SKILL.md" ]; then
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR skill not found"
    emit_jsonl "$id" "$skill" "$expect" "-" "" "ERR" "ERR skill not found"
    errored=$((errored + 1)); continue
  fi

  # User-invoked-only skill 不會 auto-fire；回報 SKIP，避免 false FN。
  if [ "$expect" = "fire" ] &&
     [ "$(read_frontmatter_bool "$PLUGIN_DIR/skills/$skill/SKILL.md" "disable-model-invocation")" = "true" ]; then
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "n/a" "SKIP user-invoked only"
    emit_jsonl "$id" "$skill" "$expect" "n/a" "" "SKIP" "SKIP user-invoked only"
    skipped=$((skipped + 1)); continue
  fi

  # 位置而非 case id 決定路徑；每個 case 使用獨立 cwd，避免共用 auto-memory namespace。
  RUN_CWD="$TMP/cwd.$total"
  mkdir -p "$RUN_CWD" || die "無法建立目錄: $RUN_CWD"
  stream="$TMP/stream.$total.jsonl"
  runner_rc=0
  printf '%s' "$prompt" | (cd "$RUN_CWD" && "${RUNNER_CMD[@]}") > "$stream" 2>"$TMP/err.$total" || runner_rc=$?

  if [ "$runner_rc" -ne 0 ]; then
    why=$(runner_error_reason "$stream")
    [ -n "$why" ] || why="runner 的 exit status 為 $runner_rc"
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR $why"
    emit_jsonl "$id" "$skill" "$expect" "-" "" "ERR" "ERR $why"
    errored=$((errored + 1)); continue
  fi

  if runner_failed "$stream"; then
    why=$(runner_error_reason "$stream")
    [ -n "$why" ] || why="runner produced no result event"
    printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "-" "ERR $why"
    emit_jsonl "$id" "$skill" "$expect" "-" "" "ERR" "ERR $why"
    errored=$((errored + 1)); continue
  fi

  # Winner 與 target-fired state 共用同一份 parsed call list。
  calls=$(skill_calls "$stream")

  # 第一個 call 是 trigger winner，collision 以此判定。
  won=$(printf '%s\n' "$calls" | head -1)

  # ACTUAL 表示 target 是否曾在 turn 內 fire；winner 另記第一個 call。
  target_fired=1   # shell truth：1 = no，0 = yes
  printf '%s\n' "$calls" | grep -Fxq "$PLUGIN_NAME:$skill" && target_fired=0
  actual="quiet"; [ "$target_fired" -eq 0 ] && actual="fire"

  if [ "$expect" = "fire" ]; then
    if [ "$won" = "$PLUGIN_NAME:$skill" ]; then
      verdict="PASS"; pass=$((pass + 1)); tp=$((tp + 1))
    elif [ -n "$won" ]; then
      verdict="FAIL collision — won by ${won#"$PLUGIN_NAME":}"; fail=$((fail + 1)); fn=$((fn + 1))
    else
      verdict="FAIL no skill fired"; fail=$((fail + 1)); fn=$((fn + 1))
    fi
  else
    # Quiet 要求 target 在整個 turn 都不得出現；只看 first winner 可能漏掉後續 target call。
    # Fire case 仍以第一個 call 揭露 collision。
    if [ "$target_fired" -eq 0 ]; then
      verdict="FAIL fired when it should not"
      [ "$won" != "$PLUGIN_NAME:$skill" ] &&
        verdict="FAIL fired when it should not (after ${won#"$PLUGIN_NAME":} won the turn)"
      fail=$((fail + 1)); fp=$((fp + 1))
    else
      verdict="PASS"; pass=$((pass + 1)); tn=$((tn + 1))
      [ -n "$won" ] && verdict="PASS (other skill fired: ${won#"$PLUGIN_NAME":})"
    fi
  fi

  printf '%-26s %-30s %-7s %-7s %s\n' "$id" "$skill" "$expect" "$actual" "$verdict"
  emit_jsonl "$id" "$skill" "$expect" "$actual" "$won" "${verdict%% *}" "$verdict"
done < "$CASES"

echo
if [ "$total" -eq 0 ]; then
  echo "SCANNED NOTHING: no usable case in '$CASES'. This is NOT a clean eval." >&2
  exit 2
fi

printf 'cases=%s  pass=%s  fail=%s  skipped=%s  err=%s\n' "$total" "$pass" "$fail" "$skipped" "$errored"
printf 'confusion: TP=%s (fired as intended)  FN=%s (missed trigger)  FP=%s (fired unbidden)  TN=%s (stayed quiet)\n' \
  "$tp" "$fn" "$fp" "$tn"
[ $((tp + fn)) -gt 0 ] && awk -v tp="$tp" -v fn="$fn" 'BEGIN{printf "recall    = %.2f  (of prompts that SHOULD fire it, how many did)\n", tp/(tp+fn)}'
[ $((tp + fp)) -gt 0 ] && awk -v tp="$tp" -v fp="$fp" 'BEGIN{printf "precision = %.2f  (of the times it fired, how many were wanted)\n", tp/(tp+fp)}'
[ "$truncated" -gt 0 ] && printf 'TRUNCATED: %s case(s) not run because --max-cases=%s. Coverage is partial.\n' \
  "$truncated" "$MAX_CASES"
[ "$RUNNER" = "mock" ] && echo 'RUNNER=mock: canned data. Valid for testing this script, NOT an audit result.'
[ "$errored" -gt 0 ] && echo "NOTE: $errored case(s) errored — those are unmeasured, not passes." >&2

[ "$fail" -eq 0 ] && [ "$errored" -eq 0 ] && exit 0
exit 1
