#!/usr/bin/env bash
# Shared-skills conformance. Host global config belongs to host-local tests.
set -uo pipefail

AGENTS="${AGENTS_HOME:-$HOME/.agents}"
pass=0
fail=0
skipped=0

ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
skip_check() { printf '  SKIP  %s\n' "$1"; skipped=$((skipped + 1)); }

if AGENTS_HOME="$AGENTS" "$AGENTS/bin/agents-sync" --check >/dev/null 2>&1; then
  ok "shared skills source"
else
  ng "shared skills source"
fi

skill_name_mismatches=0
while IFS= read -r skill_file; do
  directory_name="$(basename "$(dirname "$skill_file")")"
  frontmatter_name="$(
    awk '
      NR == 1 && $0 == "---" { frontmatter=1; next }
      frontmatter && $0 == "---" { exit }
      frontmatter && /^name:[[:space:]]*/ {
        sub(/^name:[[:space:]]*/, "")
        print
        exit
      }
    ' "$skill_file"
  )"
  frontmatter_name="${frontmatter_name#\'}"
  frontmatter_name="${frontmatter_name%\'}"
  frontmatter_name="${frontmatter_name#\"}"
  frontmatter_name="${frontmatter_name%\"}"
  [ "$frontmatter_name" = "$directory_name" ] ||
    skill_name_mismatches=$((skill_name_mismatches + 1))
done < <(find "$AGENTS/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | sort)
[ "$skill_name_mismatches" -eq 0 ] &&
  ok "skill frontmatter names match directories" ||
  ng "skill frontmatter／directory mismatches: $skill_name_mismatches"

relative_ref_check="$AGENTS/skills/auditing-skill-folder/scripts/check-relative-references.sh"
relative_ref_test="$AGENTS/tests/relative-references.sh"
if [ -x "$relative_ref_test" ] && "$relative_ref_test" >/dev/null 2>&1; then
  ok "relative-reference checker regressions"
else
  ng "relative-reference checker regressions"
fi
if [ -x "$relative_ref_check" ] && "$relative_ref_check" "$AGENTS/skills" >/dev/null 2>&1; then
  ok "skill relative references resolve"
else
  ng "skill relative references contain missing targets"
fi

context7_skill="$AGENTS/skills/context7-mcp/SKILL.md"
if [ -f "$context7_skill" ] &&
   rg -q 'resolve-library-id' "$context7_skill" &&
   rg -q 'query-docs' "$context7_skill"; then
  ok "Context7 canonical procedure"
else
  ng "Context7 canonical procedure missing"
fi

cache_count="$(
  find "$AGENTS/skills" \
    \( -type d -name __pycache__ -o -type f \( -name '*.pyc' -o -name '*.pyo' \) \) |
    wc -l | tr -d ' '
)"
[ "$cache_count" -eq 0 ] &&
  ok "shared skills contain no Python cache artifacts" ||
  ng "Python cache artifacts under shared skills: $cache_count"

bad_exec_count="$(
  find "$AGENTS/skills" -type f -perm -111 \
    ! -name '*.sh' ! -name '*.py' ! -name '*.ps1' \
    ! -name '*.js' ! -name '*.cjs' ! -name '*.fsx' |
    wc -l | tr -d ' '
)"
[ "$bad_exec_count" -eq 0 ] &&
  ok "only shared skill scripts are executable" ||
  ng "non-script executable files under shared skills: $bad_exec_count"

if rg -Fq '[ ! -L "$AGENTS/skills/video-downloader" ]' \
  "$AGENTS/tests/matt-thin-workflow.sh"; then
  ok "retired skill identity rejects broken symlinks"
else
  ng "retired skill identity can miss a broken symlink"
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/agents-conformance.XXXXXX")"
trap 'chmod -R u+rwX "$scratch" 2>/dev/null || true; rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home/.claude/skills"

if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
  "$AGENTS/bin/agents-sync" --bootstrap >/dev/null 2>&1 &&
  HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
  "$AGENTS/bin/agents-sync" --doctor >/dev/null 2>&1; then
  source_count="$(
    find "$AGENTS/skills" -mindepth 1 -maxdepth 1 -type d \
      ! -path "$AGENTS/skills/.claude" | wc -l | tr -d ' '
  )"
  link_count="$(find "$scratch/home/.claude/skills" -mindepth 1 -maxdepth 1 -type l | wc -l | tr -d ' ')"
  [ "$source_count" = "$link_count" ] &&
    ok "Claude skill-link bootstrap: $link_count" ||
    ng "Claude skill-link count $link_count != source $source_count"
else
  ng "Claude skill-link bootstrap／doctor"
fi

retired_fail=0
for mode in default --deploy --only; do
  case "$mode" in
    default)
      HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" >/dev/null 2>&1 &&
        retired_fail=1
      ;;
    --only)
      HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" --only codex >/dev/null 2>&1 &&
        retired_fail=1
      ;;
    *)
      HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" "$mode" >/dev/null 2>&1 &&
        retired_fail=1
      ;;
  esac
done
[ "$retired_fail" -eq 0 ] &&
  ok "retired host-deploy interfaces fail-loud" ||
  ng "retired host-deploy interface still succeeds"

protect_files="$AGENTS/skills/init-project-docs/references/hooks/protect-files.sh"
printf '%s' '{"tool_name":"apply_patch","tool_input":{"patch":"*** Begin Patch\\n*** Update File: .env\\n@@\\n-A\\n+B\\n*** End Patch"}}' |
  env CLAUDECODE=1 bash "$protect_files" >/dev/null 2>&1
rc=$?
[ "$rc" -ne 0 ] &&
  ok "protect-files apply_patch(.env) fail-closed" ||
  ng "protect-files apply_patch(.env) allowed"

init_docs="$AGENTS/skills/init-project-docs/SKILL.md"
catalog_index="$AGENTS/skills/init-project-docs/references/README.md"
host_matrix="$AGENTS/skills/init-project-docs/references/host-matrix.md"
codex_hooks="$AGENTS/skills/init-project-docs/references/hooks/codex/README.md"
copilot_agents="$AGENTS/skills/init-project-docs/references/agents/copilot/README.md"
copilot_settings="$AGENTS/skills/init-project-docs/references/settings-templates/copilot/README.md"

if rg -Fq '`.github/copilot/settings.json`' "$host_matrix" &&
   rg -Fq '`.github/copilot/settings.local.json`' "$host_matrix" &&
   rg -Fq '`.github/copilot/settings.json`' "$catalog_index" &&
   rg -Fq '`.github/copilot/settings.local.json`' "$catalog_index"; then
  ok "init-project-docs knows Copilot repository／local settings"
else
  ng "init-project-docs Copilot repository／local settings are stale"
fi

if rg -Fq 'startup\|resume\|clear\|compact' "$host_matrix" &&
   rg -Fq 'startup|resume|clear|compact' "$codex_hooks"; then
  ok "init-project-docs Codex SessionStart sources are current"
else
  ng "init-project-docs Codex SessionStart misses compact"
fi

copilot_aliases_current=1
for alias in read edit search execute; do
  rg -Fq "\`$alias\`" "$copilot_agents" || copilot_aliases_current=0
done
if [ "$copilot_aliases_current" -eq 1 ] &&
   ! rg -q 'search/codebase|edit/editFiles|runCommands|execute/createAndRunTask' "$copilot_agents"; then
  ok "init-project-docs Copilot agent aliases are canonical"
else
  ng "init-project-docs Copilot agent aliases are stale"
fi

if ! rg -Fq 'Codex recommendation markers:' "$init_docs" &&
   rg -Fq '## Phase 4–6 建議標記' "$host_matrix"; then
  ok "init-project-docs host markers have one owner"
else
  ng "init-project-docs host markers are duplicated or misplaced"
fi

if rg -Fq 'references/README.md' "$init_docs" &&
   rg -q '^- \[ \]' "$init_docs"; then
  ok "init-project-docs uses shared catalogs and validation checklist"
else
  ng "init-project-docs catalog／validation hierarchy is incomplete"
fi

if rg -Fq '`.github/copilot/settings.json`' "$copilot_settings" &&
   rg -q '限定|supported keys' "$copilot_settings" &&
   rg -Fq 'Phase 2 先增量更新' "$copilot_settings" &&
   ! rg -Fq 'Phase 2 實際只產' "$copilot_settings"; then
  ok "init-project-docs Copilot settings boundary is current"
else
  ng "init-project-docs Copilot settings boundary is stale"
fi

if rg -Fq '先讀取共用的 stack/template catalog' "$init_docs" &&
   rg -Fq '## Phase 4–6 建議標記' "$host_matrix"; then
  ok "init-project-docs new workflow prose is zh-TW"
else
  ng "init-project-docs new workflow prose is not zh-TW"
fi

claimed="$(sed -n '1p' "$AGENTS/CONVENTIONS.md" | grep -oE '[0-9]+ 條' | grep -oE '[0-9]+' | head -1)"
actual="$(grep -c '^## [0-9]' "$AGENTS/CONVENTIONS.md")"
[ -n "$claimed" ] && [ "$claimed" = "$actual" ] &&
  ok "CONVENTIONS count $claimed" ||
  ng "CONVENTIONS claimed ${claimed:-none}, actual $actual"

if git -C "$HOME/.agents" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  live_branch="$(git -C "$HOME/.agents" branch --show-current 2>/dev/null || true)"
  [ "$live_branch" = main ] &&
    ok "live ~/.agents checkout is main" ||
    ng "live ~/.agents checkout is ${live_branch:-unknown}"
else
  skip_check "live ~/.agents checkout unavailable"
fi

ci_workflow="$AGENTS/.github/workflows/ci.yml"
if [ -f "$ci_workflow" ] &&
  ! grep -Eq 'AGENTS_DEPLOY_ROOT|dist/(skill-index\.md|AGENTS\.md|copilot-instructions\.md)|bin/agents-sync[[:space:]]+(--deploy|--only)' "$ci_workflow"; then
  ok "CI uses shared-skills contract"
else
  ng "CI still consumes retired agents-sync deployment"
fi

if bash -n "$AGENTS"/bin/* "$AGENTS"/hooks/*.sh "$AGENTS"/tests/*.sh; then
  ok "shared shell syntax"
else
  ng "shared shell syntax"
fi

if "$AGENTS/tests/legacy-mp-collision.sh" >/dev/null 2>&1; then
  ok "legacy mp collision guard"
else
  ng "legacy mp collision guard"
fi

# CONVENTIONS 規則 11 的 ~/.agents 一側，下沉自 prose（規則 9）。必須用 find 不得用
# ls + glob：後者在 zsh 下 nomatch 中止即回 0＝假合規。
# 三個排除都對應規則 11 的明文例外，不是便宜行事：
#   -not -name '.*'        app 自管的 runtime state 備份（如 .codex-global-state.json.bak）
#   -not -path '*/attic/*' 規則 11 允許既有 .bak「掃 secret 後刪除或歸檔 attic/」
#   -not -path '*/backups/*' backups/ 就是規則 11 明訂的操作前快照區
bak_count="$(find "$AGENTS" -name '*.bak*' \
  -not -path '*/.git/*' -not -path '*/attic/*' -not -path '*/backups/*' \
  -not -name '.*' 2>/dev/null | wc -l | tr -d ' ')"
[ "$bak_count" = 0 ] &&
  ok "no manual .bak under ~/.agents" ||
  ng "manual .bak found under ~/.agents: $bak_count"

# $var 緊接非 ASCII 時 bash 會把後續 byte 吃進變數名，set -u 下變成
# "out?: unbound variable"。2026-08-02 實測 15 個字元（）（「」，。：；、？！　─ ” ’）
# 全部命中，不限於全形括號——這個 repo 的 shell 腳本以 zh-TW 寫訊息，是高頻寫法。
#
# 為何不能靠 shellcheck：它的 parser 把「變數後直接接全形字元」讀成變數加文字，與
# bash 實際行為不同，-S style 也是 0 訊息，CI 的 shellcheck step 永遠不會紅（同日實測）。
# 本註解刻意不寫出該字面寫法，否則會被下面這條 rg 抓到自己。
#
# 危險方向是靜默：這類寫法多半落在失敗分支，平時不觸發；一旦觸發，set -u 會用
# unbound variable 取代該印的診斷訊息——剛好在最需要診斷時把它吃掉。實例：
# protect-files.sh 的 hook_block 因此在 exit 2（deny）之前就 abort，敏感檔案保護
# fail open（實測 exit 1 而非 2，2026-08-02 修復）。
#
# 缺 rg 是 FAIL 不是 SKIP：bin/ci-local 檔頭記著這個 repo 踩過的教訓——「缺工具的
# 失敗方向是假綠，比報錯危險」。本檔其餘 rg 呼叫也都沒有保護，SKIP 會在同一支腳本
# 裡對同一個工具擺出兩套標準。
VARNAME_PAT='\$[a-zA-Z_][a-zA-Z0-9_]*\P{ASCII}'
if ! command -v rg >/dev/null 2>&1; then
  ng "shell 變數名檢查需要 rg，但 rg 不可用（缺工具的失敗方向是假綠）"
else
  # canary：pattern 寫壞就永遠是綠的。fixture 同時驗正向抓得到與反向不誤報，且與
  # 實掃共用同一個 VARNAME_PAT，改壞 pattern 這裡會先紅。fixture 用 mktemp 不放 tests/：
  # 後者會被下面的實掃掃到。全形字元用 printf octal 組出來，不寫字面，同理。
  canary_dir="$(mktemp -d)" || canary_dir=""
  if [ -n "$canary_dir" ]; then
    fw="$(printf '\357\274\211')"
    printf 'echo "x$v%sy"\n' "$fw" > "$canary_dir/bad.sh"
    printf 'echo "x${v}%sy"\n' "$fw" > "$canary_dir/good.sh"
    canary_bad="$(rg -cP "$VARNAME_PAT" "$canary_dir/bad.sh" 2>/dev/null || echo 0)"
    canary_good="$(rg -cP "$VARNAME_PAT" "$canary_dir/good.sh" 2>/dev/null || echo 0)"
    rm -rf "$canary_dir"
    if [ "$canary_bad" = 1 ] && [ "$canary_good" = 0 ]; then
      ok "shell 變數名 pattern canary"
    else
      ng "shell 變數名 pattern canary 失效（bad=$canary_bad 應 1、good=$canary_good 應 0）"
    fi
  else
    ng "shell 變數名 pattern canary 無法建立 fixture"
  fi

  # 掃 repo 內所有放 shell 腳本的目錄。skills/ 有 21 支，第一版漏掉——PASS 訊息因此
  # 在說謊，直到 2026-08-02 的 review 抓出 protect-files.sh 的 fail-open。
  # attic/ 是 CONVENTIONS 規則 11 的退役物，不掃。
  varname_hits="$(rg -cP "$VARNAME_PAT" \
    "$AGENTS/bin" "$AGENTS/tests" "$AGENTS/hooks" "$AGENTS/skills" 2>/dev/null |
    awk -F: '{s+=$2} END{print s+0}')"
  [ "$varname_hits" = 0 ] &&
    ok "shell 變數名後未緊接非 ASCII" ||
    ng "shell 變數名後緊接非 ASCII（bash 會吃進變數名，須改 \${var}）：$varname_hits 處"
fi

# 缺檔時 SKIP 不 FAIL：$AGENTS 可能是還沒有這支 test 的舊 checkout（本分支 merge 前的
# live ~/.agents 就是），那不是合規缺陷。存在則必須通過。
if [ ! -x "$AGENTS/tests/hook-parity.sh" ]; then
  skip_check "[T0-3] guard parity checker 不在 $AGENTS/tests/"
elif "$AGENTS/tests/hook-parity.sh" >/dev/null 2>&1; then
  ok "[T0-3] guard parity checker"
else
  ng "[T0-3] guard parity checker"
fi

# CI step 名稱不得複述 case 數（CONVENTIONS 規則 9 的下沉）。
# 為何必須是機械守護而不是 prose：這條規則的內容就是「沒有守護的數字會靜默漂移」，
# 用一段註解去執行它，等於犯它描述的錯。實測已漂移兩次——版本絆線名稱停在 28 而
# 實際 45（9b645c5 更正），guard parity 停在 11 而實際 13（本次發現）。兩次都靜默
# 通過，因為沒有任何東西在條數變動時提醒你改名稱。條數由各測試腳本的收尾行自報。
CI_YML="$AGENTS/.github/workflows/ci.yml"
COUNT_IN_NAME='^[[:space:]]+- name:.*[0-9]+ ?(cases|條|斷言)'
if [ ! -f "$CI_YML" ]; then
  skip_check "CI step 名稱不含 case 數（$CI_YML 不存在）"
elif ! grep -qE "$COUNT_IN_NAME" "$CI_YML"; then
  ok "CI step 名稱不含 case 數"
else
  ng "CI step 名稱複述 case 數（會靜默漂移）：$(grep -cE "$COUNT_IN_NAME" "$CI_YML") 處"
fi

printf '\n%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skipped"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]
