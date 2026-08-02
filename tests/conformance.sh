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

# 缺檔時 SKIP 不 FAIL：$AGENTS 可能是還沒有這支 test 的舊 checkout（本分支 merge 前的
# live ~/.agents 就是），那不是合規缺陷。存在則必須通過。
if [ ! -x "$AGENTS/tests/hook-parity.sh" ]; then
  skip_check "[T0-3] guard parity checker 不在 $AGENTS/tests/"
elif "$AGENTS/tests/hook-parity.sh" >/dev/null 2>&1; then
  ok "[T0-3] guard parity checker"
else
  ng "[T0-3] guard parity checker"
fi

printf '\n%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skipped"
[ "$fail" -eq 0 ]
