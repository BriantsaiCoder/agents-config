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

has "[INT-4] canonical delegation gate" '^\- \[INT-4\]' skills/dev-workflow/SKILL.md
refs=$(grep -o '\[INT-4\]' "$ROOT/skills/dev-workflow/SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$refs" -ge 5 ] && ok "[INT-4] referenced across workflow" || ng "[INT-4] referenced across workflow"
has "[T1-10] points to agents-branch" '^\[T1-10\].*bin/agents-branch' core/tier1-workflow.md

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

has "model route: grilling + domain-modeling" 'grilling.*domain-modeling' core/routing.md
has "model route: codebase-design" 'codebase-design' core/routing.md
has "model route: diagnosing-bugs" 'diagnosing-bugs' core/routing.md
has "model route: tdd" '(^|[^[:alnum:]-])tdd([^[:alnum:]-]|$)' core/routing.md
has "explicit route: grill-with-docs" '/grill-with-docs' core/routing.md
has "explicit route: improve-codebase-architecture" '/improve-codebase-architecture' core/routing.md
lacks "active routing no longer names mp replacements" 'mp-(grill-with-docs|improve-codebase-architecture|diagnose|tdd)' core/routing.md

has "external issue or PR routes to triage" '外部.*issue.*PR.*`triage`' skills/dev-workflow/SKILL.md
has "grill-with-docs stays explicit" '明示.*`grill-with-docs`' skills/dev-workflow/SKILL.md
has "initially clear single-session work routes to implement" '需求已清楚.*單一 session.*`implement`' skills/dev-workflow/SKILL.md
has "single-session slice routes to implement" '單一 session.*`implement`' skills/dev-workflow/SKILL.md
has "missing canonical spec routes through to-spec" '無 canonical spec.*`to-spec`.*`to-tickets`' skills/dev-workflow/SKILL.md
has "existing spec skips duplicate to-spec" '已有完整 spec.*略過 `to-spec`.*`to-tickets`' skills/dev-workflow/SKILL.md
has "ticket implementation starts fresh" '每張 ticket.*fresh session.*isolated.*worktree' skills/dev-workflow/SKILL.md
has "handoff only bridges uncaptured context" '`handoff`.*未進入 spec.*ticket.*wayfinder map' skills/dev-workflow/SKILL.md

has "closeout is action-triggered" 'push.*open PR.*merge.*final closeout' skills/dev-workflow/SKILL.md
has "implement adapter enters branch" '`implement`.*(branch|worktree)' skills/dev-workflow/SKILL.md
has "implement adapter requires S4-S6" '`implement`.*S4.*S6' skills/dev-workflow/SKILL.md
has "S5 has Standards and Spec axes" 'Standards.*Spec' skills/dev-workflow/SKILL.md
has "S5 axes have four states" 'PASS.*FAIL.*SKIPPED.*UNAVAILABLE' skills/dev-workflow/SKILL.md
has "bugfix routes to diagnosing-bugs" 'diagnosing-bugs' skills/bug-fix-settlement/SKILL.md

for active in core/routing.md skills/dev-workflow/SKILL.md \
              skills/dev-workflow/references/review-triage.md \
              skills/bug-fix-settlement/SKILL.md; do
  lacks "no active Superpowers workflow ref: $active" \
    'superpowers:|finishing-a-development-branch|systematic-debugging|receiving-code-review' "$active"
done

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
