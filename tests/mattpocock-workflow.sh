#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
pass=0
fail=0

ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

has() {
  local label="$1" pattern="$2" file="$3"
  grep -qE "$pattern" "$ROOT/$file" 2>/dev/null && ok "$label" || ng "$label"
}

lacks() {
  local label="$1" pattern="$2" path="$3"
  if [ ! -e "$ROOT/$path" ]; then
    ng "$label"
  elif rg -q "$pattern" "$ROOT/$path"; then
    ng "$label"
  else
    ok "$label"
  fi
}

rule_has() {
  local label="$1" id="$2" pattern="$3"
  sed -n "/^\\- \\[$id\\]/p" "$ROOT/skills/dev-workflow/SKILL.md" |
    grep -qE "$pattern" &&
    ok "$label" ||
    ng "$label"
}

has "[INT-4] canonical delegation gate" '^\- \[INT-4\]' skills/dev-workflow/SKILL.md
refs=$(grep -o '\[INT-4\]' "$ROOT/skills/dev-workflow/SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$refs" -ge 5 ] && ok "[INT-4] referenced across workflow" || ng "[INT-4] referenced across workflow"
# 2026-07-30：原本驗 core/tier1-workflow.md 的 [T1-10] 條文，但 core/ 三家不讀且已退役。
# tier1 條文的 active 正本在各 host 自己的 core/ 底下，~/.agents 的 test 不該跨進 host
# 擁有的檔案（ownership 邊界）。拆成兩條：isolation 要求由 [INT-6] 承接，工具指向由
# Codex adapter 承接。只驗 'bin/agents-branch' 是不夠的——那條在 [INT-6] 被刪掉後仍會綠。
has "[INT-6] requires isolated worktree" '^\- \[INT-6\].*(isolated worktree|worktree)' skills/dev-workflow/SKILL.md
has "[T1-10] tooling points to agents-branch" 'bin/agents-branch' skills/dev-workflow/SKILL.md

has "house skill standards exists" '^# Skill standards' skills/auditing-skill-folder/references/skill-standards.md
lacks "audit no longer depends on superpowers:writing-skills" 'superpowers:writing-skills' skills/auditing-skill-folder

has "neutral specs path" 'docs/agents/specs/' skills/dev-workflow/SKILL.md
has "neutral plans path" 'docs/agents/plans/' skills/dev-workflow/SKILL.md
lacks "active X1 has no docs/superpowers path" 'docs/superpowers/' skills/dev-workflow/SKILL.md

contract=docs/agents/issue-tracker.md
for pattern in 'Status:' 'bug' 'enhancement' 'needs-triage' 'needs-info' \
               'ready-for-agent' 'ready-for-human' 'wontfix' \
               'research' 'prototype' 'grilling' 'task' 'CONTEXT.md' \
               'CONTEXT-MAP.md' 'docs/agents/specs/' 'docs/agents/plans/' \
               'sdd/<slug>/' '\.scratch/'; do
  has "issue-tracker contract: $pattern" "$pattern" "$contract"
done

has "setup requires explicit user invocation" 'setup-matt-pocock-skills.*使用者.*明示|使用者.*明示.*setup-matt-pocock-skills' skills/dev-workflow/SKILL.md
has "global issue-tracker fallback" '~/.agents/docs/agents/issue-tracker.md' skills/dev-workflow/SKILL.md
has "Copilot delegation uses task" '子代理 = `task` 工具' skills/dev-workflow/SKILL.md
has "Copilot hook state is current" 'Copilot.*hooks.*已配置' skills/dev-workflow/SKILL.md

ledger=proposals/2026-07-27-mattpocock-skills-workflow/15-superpowers-helper-ledger.md
for helper in sdd-workspace task-brief review-package find-polluter.sh start-server.sh stop-server.sh render-graphs.js; do
  has "helper ledger: $helper" "$helper" "$ledger"
done

# 2026-07-30：routing 斷言的掃描目標從 core/routing.md 改為 dev-workflow 的 S0 ROUTE 表。
# 理由：core/routing.md 三家 runtime 都不讀（Claude 只 @import ~/.claude/core/*，Codex 與
# Copilot 的 config 對 .agents/ 只引用 skills/），而本檔第 83 行的 for-active 迴圈卻把它
# 當 active——test 說 active、CONVENTIONS 規則 1 說歷史 evidence、runtime 不讀，三種互斥。
# 驗真正被讀的那份檔才是斷言的本意。core/ 已退役至 attic/core/。
has "model route: grilling + domain-modeling" 'grilling.*domain-modeling' skills/dev-workflow/SKILL.md
has "model route: codebase-design" 'codebase-design' skills/dev-workflow/SKILL.md
has "model route: diagnosing-bugs" 'diagnosing-bugs' skills/dev-workflow/SKILL.md
has "model route: tdd" '(^|[^[:alnum:]-])tdd([^[:alnum:]-]|$)' skills/dev-workflow/SKILL.md
has "single-skill authoring routes to writing-great-skills" '單一 skill.*建立.*修改.*`writing-great-skills`' skills/dev-workflow/SKILL.md
has "skill-folder lifecycle audit routes to auditing-skill-folder" 'skill folder.*keep.*trim.*delete.*migrate.*`auditing-skill-folder`' skills/dev-workflow/SKILL.md
has "single-skill trigger failure starts with diagnosing-bugs" '單一 skill.*trigger failure.*`diagnosing-bugs`.*RED' skills/dev-workflow/SKILL.md
lacks "audit no longer requests explicit writing-skill invocation" 'explicitly invoke `writing-great-skills`|明示.*`writing-great-skills`' skills/auditing-skill-folder/SKILL.md
# explicit route: grill-with-docs 由第 67 行的「明示.*`grill-with-docs`」涵蓋（措辭更精確），
# 不再重複斷言 —— S0 表用反引號而非斜線前綴，原本的 '/grill-with-docs' 在此不成立。
has "explicit route: improve-codebase-architecture" 'improve-codebase-architecture.*explicit-only' skills/dev-workflow/SKILL.md
lacks "active routing no longer names mp replacements" 'mp-(grill-with-docs|improve-codebase-architecture|diagnose|tdd)' skills/dev-workflow/SKILL.md

has "external issue or PR routes to triage" '外部.*issue.*PR.*`triage`' skills/dev-workflow/SKILL.md
has "grill-with-docs stays explicit" '明示.*`grill-with-docs`' skills/dev-workflow/SKILL.md
has "initially clear single-session work routes to implement" '需求已清楚.*單一 session.*`implement`' skills/dev-workflow/SKILL.md
has "single-session slice routes to implement" '單一 session.*`implement`' skills/dev-workflow/SKILL.md
has "missing canonical spec routes through to-spec" '無 canonical spec.*`to-spec`.*`to-tickets`' skills/dev-workflow/SKILL.md
has "existing spec skips duplicate to-spec" '已有完整 spec.*略過 `to-spec`.*`to-tickets`' skills/dev-workflow/SKILL.md
has "ticket implementation starts fresh" '每張 ticket.*fresh session.*isolated.*worktree' skills/dev-workflow/SKILL.md
has "session interruption routes to handoff" 'session 中斷.*`handoff`' skills/dev-workflow/SKILL.md
has "handoff only bridges uncaptured context" '`handoff`.*未進入 spec.*ticket.*wayfinder map' skills/dev-workflow/SKILL.md
has "explicit session switch recommends handoff" '使用者明示.*換 session.*交接.*另一個 agent.*`handoff`' skills/dev-workflow/SKILL.md
has "unfinished stop makes handoff the sole next action" 'blocker.*session 邊界.*工作未完成.*`handoff`.*唯一 next action' skills/dev-workflow/SKILL.md
has "canonical artifact suppresses duplicate handoff" '已有 canonical artifact.*只引用.*不重複' skills/dev-workflow/SKILL.md
has "compaction and completion do not trigger handoff" 'context compaction.*任務已完成.*內容很長.*MUST NOT.*`handoff`' skills/dev-workflow/SKILL.md

has "closeout is action-triggered" 'push.*open PR.*merge.*final closeout' skills/dev-workflow/SKILL.md
has "implement adapter enters branch" '`implement`.*(branch|worktree)' skills/dev-workflow/SKILL.md
has "implement adapter requires S4-S6" '`implement`.*S4.*S6' skills/dev-workflow/SKILL.md
has "S5 has Standards and Spec axes" 'Standards.*Spec' skills/dev-workflow/SKILL.md
has "S5 axes have four states" 'PASS.*FAIL.*SKIPPED.*UNAVAILABLE' skills/dev-workflow/SKILL.md
has "S5 dirty review includes staged and unstaged changes" 'staged.*`git diff --cached --`.*unstaged.*`git diff --`' skills/dev-workflow/SKILL.md
has "S5 dirty review includes untracked files" 'git ls-files --others --exclude-standard' skills/dev-workflow/SKILL.md
rule_has "S5 risk contract has five elements" S5-1 'MUST.*觸發：.*例外：.*驗證：'
rule_has "S5 package contract has five elements" S5-2 'MUST.*觸發：.*例外：.*驗證：'
rule_has "S5 dirty review inventories explicit ignored paths" S5-2 'task 明列.*ignored path.*metadata-only inventory'
rule_has "S5 package omits secret-bearing content" S5-2 'secret-bearing.*MUST NOT.*全文'
rule_has "S5 package limits secret evidence" S5-2 'path.*set/unset.*redacted finding'
rule_has "S5 package names common secret paths" S5-2 '\.env\*.*credentials.*private keys.*token stores'
rule_has "S5 package scans staged changes" S5-2 'gitleaks git --staged --redact'
rule_has "S5 package scans unstaged changes" S5-2 'gitleaks git --pre-commit --redact'
rule_has "S5 package scans untracked and ignored candidates" S5-2 'gitleaks dir --redact'
rule_has "S5 package inventories metadata before scans and raw diff" S5-2 'name-status.*gitleaks git --staged.*全部通過後.*git diff --cached --`'
rule_has "S5 finding blocks raw package assembly" S5-2 'finding.*MUST.*FAIL.*raw.*MUST.*omit'
rule_has "S5 package bounds binary and oversized files" S5-2 'binary.*256 KiB.*path.*size.*hash|256 KiB.*binary.*path.*size.*hash'
lacks "S5 package has no unconditional ignored-file content" 'ignored path 全文' skills/dev-workflow/SKILL.md
has "delegation is bounded by default" 'Delegation.*預設 1.*user.*repo.*higher instruction.*最多 2' skills/dev-workflow/SKILL.md
rule_has "S5 two read-only review agents are workflow-authorized" INT-4 'S5 `code-review`.*Standards／Spec.*恰好 2 個 read-only review agents.*視為 workflow 已授權'
rule_has "wayfinder fan-out stays within two per batch" INT-4 '`wayfinder` research fan-out.*每批最多 2 個.*超過須取得額外授權'
rule_has "existing public behavior seam is pre-confirmed" INT-2 '既有 public behavior seam 視為已確認.*只有新增 seam 才需.*確認'
rule_has "S5 medium and PR reviews run both axes" S5-1 '中高風險.*PR.*Standards.*Spec'
rule_has "S5 low-risk non-PR reviews may be skipped" S5-1 '低風險.*不進 PR.*SKIPPED'
has "global workflow and security config are never trivial" 'global workflow.*security.*config.*不得.*trivial' skills/dev-workflow/SKILL.md
has "skill changes require invocation canaries" 'Skill change.*frontmatter.*relative references.*positive/negative.*trigger canary' skills/dev-workflow/SKILL.md
has "Copilot effort is adaptive" '模型預設 effort.*high.*xhigh.*量測' skills/dev-workflow/SKILL.md
has "Copilot S5 handles dirty reviews" 'working tree dirty.*預設 1 個 `task`' skills/dev-workflow/SKILL.md
has "Copilot S5 handles clean reviews" 'clean.*fixed-point.*`code-review`' skills/dev-workflow/SKILL.md
lacks "S5 has no unconditional fixed fan-out" '固定 fan-out|S5.*同一 response.*兩個|Standards.*Spec.*各.*(一|1)個.*task' skills/dev-workflow/SKILL.md
has "host resolver derives the user-only count" 'expected_user_only_count=.*0' tests/host-skill-resolver.sh
lacks "host resolver has no hard-coded user-only count" '13/13|-eq 13' tests/host-skill-resolver.sh
has "host resolver compares complete skill directories" 'diff -qr.*skill_path.*AGENTS/skills' tests/host-skill-resolver.sh
has "CI runs the Stage B2 skill checkpoint" 'bash tests/matt-thin-workflow.sh' .github/workflows/ci.yml
resolver_fixture="$(mktemp -d "${TMPDIR:-/tmp}/host-resolver-fixture.XXXXXX")"
printf 'skill=missing-skill\n' > "$resolver_fixture/mattpocock-skills.lock"
resolver_output="$(
  AGENTS_HOME="$resolver_fixture" CLAUDE_SKILLS_ROOT="$resolver_fixture/no-claude" \
    bash "$ROOT/tests/host-skill-resolver.sh" 2>&1
)"
resolver_rc=$?
if [ "$resolver_rc" -ne 0 ] &&
   printf '%s\n' "$resolver_output" | rg -q 'Codex locked skill missing: missing-skill'; then
  ok "host resolver fails closed when a locked skill is missing"
else
  ng "host resolver fails closed when a locked skill is missing"
fi
rm -r -- "$resolver_fixture"
has "same-conversation compact is not a Matt handoff" 'same-conversation `/compact`.*MUST NOT.*`handoff`' skills/dev-workflow/SKILL.md
has "Codex native handoff does not invoke Matt handoff" 'Local/Worktree Handoff.*MUST NOT.*Matt `\$handoff`' skills/dev-workflow/SKILL.md
has "conflict analysis does not authorize mutation" '分析.*conflict.*不得.*resolve.*stage.*commit' skills/dev-workflow/SKILL.md
has "conflict resolution requires explicit user authorization" '明示.*解決 conflict.*`resolving-merge-conflicts`' skills/dev-workflow/SKILL.md

if command -v gitleaks >/dev/null 2>&1; then
  scan_fixture="$(mktemp -d "${TMPDIR:-/tmp}/matt-secret-fixture.XXXXXX")"
  printf 'ghp_%s%s\n' '123456789012345678' '901234567890123456' > "$scan_fixture/leak.txt"
  if gitleaks dir --redact --no-banner --no-color "$scan_fixture" >/dev/null 2>&1; then
    ng "gitleaks fixture blocks a review package"
  else
    ok "gitleaks fixture blocks a review package"
  fi
  rm -r -- "$scan_fixture"
else
  ng "gitleaks scanner is available"
fi

copilot_s5_count="$(
  sed -n '/^### Copilot$/,/^## References$/p' "$ROOT/skills/dev-workflow/SKILL.md" |
    rg -c '^- S5 '
)"
[ "$copilot_s5_count" = 1 ] &&
  ok "Copilot adapter has one canonical S5 directive" ||
  ng "Copilot adapter has one canonical S5 directive"
has "bugfix routes to diagnosing-bugs" 'diagnosing-bugs' skills/bug-fix-settlement/SKILL.md

for active in skills/dev-workflow/SKILL.md \
              skills/dev-workflow/references/review-triage.md \
              skills/bug-fix-settlement/SKILL.md; do
  lacks "no active Superpowers workflow ref: $active" \
    'superpowers:|finishing-a-development-branch|systematic-debugging|receiving-code-review' "$active"
done

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
