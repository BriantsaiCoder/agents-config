#!/usr/bin/env bash
set -uo pipefail

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
  local label="$1" pattern="$2" path rc
  shift 2
  [ "$#" -gt 0 ] || { ng "$label"; return 1; }
  for path in "$@"; do
    [ -e "$ROOT/$path" ] || { ng "$label"; return 1; }
    rg -q "$pattern" "$ROOT/$path"
    rc=$?
    case "$rc" in
      0) ng "$label"; return 1 ;;
      1) ;;
      *) ng "$label"; return 1 ;;
    esac
  done
  ok "$label"
}

if (rg() { return 2; }; lacks "lacks helper scan error fixture" 'unused' skills/dev-workflow/SKILL.md) >/dev/null; then
  ng "lacks helper fails closed on scan errors"
else
  ok "lacks helper fails closed on scan errors"
fi

rule_has_in() {
  local label="$1" id="$2" pattern="$3" file="$4"
  sed -n "/^\\- \\[$id\\]/p" "$ROOT/$file" |
    grep -qE "$pattern" &&
    ok "$label" ||
    ng "$label"
}

rule_has() {
  rule_has_in "$1" "$2" "$3" skills/dev-workflow/SKILL.md
}

section_has() {
  local label="$1" section="$2" pattern="$3" file="$4"
  if awk -v heading="## $section" '
    $0 == heading { active=1; next }
    active && /^## / { exit }
    active { print }
  ' "$ROOT/$file" | grep -qE "$pattern"; then
    ok "$label"
  else
    ng "$label"
  fi
}

dirty_review=skills/dev-workflow/references/dirty-review-package.md
delegation_ref=skills/dev-workflow/references/delegation.md
host_adapters_ref=skills/dev-workflow/references/host-adapters.md
routing_continuations_ref=skills/dev-workflow/references/routing-continuations.md
authorization_matrix_ref=skills/dev-workflow/references/authorization-matrix.md
ledgers_ref=skills/dev-workflow/references/ledgers.md
evidence_integrity_ref=skills/dev-workflow/references/evidence-integrity.md
host_ownership_test=tests/three-host-global-config-ownership.sh
delivery_int6_pattern='預計納入 VCS.*新增／修改.*首次寫入前.*MUST.*branch／worktree.*非 main／master'
delivery_s2_pattern='寫入前.*MUST.*記.*Delivery Scope: Local-only／PR-closeout.*後者須核准.*否則.*Local-only'
delivery_s6_pattern='PR-closeout.*MUST.*commit.*push.*Ready PR.*current-head CI／bot gate PASS.*ledgers.*merge strategy.*branch cleanup.*才 final.*Local-only.*禁 external write'

delivery_contract_valid() {
  local file="$1" int6 s2 s6 rc
  [ -r "$file" ] || return 2
  int6="$(grep -E '^\- \[INT-6\]' "$file")"; rc=$?
  case "$rc" in 0) ;; 1) return 1 ;; *) return 2 ;; esac
  s2="$(awk '/^## S2 AUTHORIZE$/{on=1;next} on && /^## /{exit} on{print}' "$file")" || return 2
  s6="$(awk '/^## S6 CLOSEOUT$/{on=1;next} on && /^## /{exit} on{print}' "$file")" || return 2
  [[ "$int6" =~ $delivery_int6_pattern ]] &&
    [[ "$s2" =~ $delivery_s2_pattern ]] &&
    [[ "$s6" =~ $delivery_s6_pattern ]]
}

evidence_integrity_contract_valid() {
  local file="$1"
  [ -r "$file" ] || return 2
  grep -qE '^- 完成證據 MUST .*最後一次影響行為的 edit 之後.*final verification pass；後續 behavior-affecting edit 使舊結果失效。$' "$file" &&
    grep -qE '^- 新增或修改的 custom gate.* MUST fail closed：unreadable input、crash 或 unexpected exit 都不得被解讀為成功。$' "$file" &&
    grep -qE '^- 同一 gate MUST .*known-bad negative control.*失敗.*clean positive control.*通過；.*可重播.*deterministic。$' "$file"
}

has "[INT-4] canonical delegation gate" '^\- \[INT-4\]' skills/dev-workflow/SKILL.md
refs=$(grep -ho '\[INT-4\]' \
  "$ROOT/skills/dev-workflow/SKILL.md" \
  "$ROOT/$delegation_ref" \
  "$ROOT/$host_adapters_ref" 2>/dev/null | wc -l | tr -d ' ')
[ "$refs" -ge 5 ] && ok "[INT-4] referenced across workflow" || ng "[INT-4] referenced across workflow"
# 2026-07-30：原本驗 core/tier1-workflow.md 的 [T1-10] 條文，但 core/ 三家不讀且已退役。
# tier1 條文的 active 正本在各 host 自己的 core/ 底下，~/.agents 的 test 不該跨進 host
# 擁有的檔案（ownership 邊界）。拆成兩條：isolation 要求由 [INT-6] 承接，工具指向由
# Codex adapter 承接。只驗 'bin/agents-branch' 是不夠的——那條在 [INT-6] 被刪掉後仍會綠。
has "[INT-6] requires isolated worktree" '^\- \[INT-6\].*(isolated worktree|worktree)' skills/dev-workflow/SKILL.md
rule_has "[INT-6] covers new and modified VCS files before write" INT-6 "$delivery_int6_pattern"
has "[T1-10] tooling points to agents-branch" '~/\.agents/bin/agents-branch' "$host_adapters_ref"

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
has "global issue-tracker fallback" '~/\.agents/docs/agents/issue-tracker.md' skills/dev-workflow/SKILL.md
has "Copilot delegation uses task" '子代理 = `task` 工具' "$host_adapters_ref"
has "Copilot hook path is normative" 'Copilot.*Git guard MUST 位於' "$host_adapters_ref"

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
has "primary-source research routes to research" 'primary-source.*citable Markdown.*`research`' skills/dev-workflow/SKILL.md
has "provider-native official docs route before fallback" 'provider-native official docs.*Context7 fallback' skills/dev-workflow/SKILL.md
has "third-party current docs fall back to context7" 'third-party.*current.*`context7-mcp`' skills/dev-workflow/SKILL.md
has "context7 activation preserves provider-first gate" 'provider-native official docs.*(absent|UNAVAILABLE).*activate this skill' skills/context7-mcp/SKILL.md
lacks "Context7 is not the blanket docs owner" '所有 current docs.*Context7|current product docs.*一律.*context7' skills/dev-workflow/SKILL.md
lacks "shared kernel does not name a host-only OpenAI skill" '`openai-docs`' skills/dev-workflow/SKILL.md
lacks "Context7 fallback does not name a host-only OpenAI skill" '`openai-docs`' skills/context7-mcp/SKILL.md
has "context7 pre-authorizes only its two read-only tools" 'resolve-library-id.*query-docs.*pre-authorized' skills/context7-mcp/SKILL.md
has "context7 starts lazily without a separate prompt" 'lazily.*do not ask the user' skills/context7-mcp/SKILL.md
has "context7 permission failure stays fail-closed" 'fail closed.*UNAVAILABLE.*do not broaden' skills/context7-mcp/SKILL.md
has "Microsoft concepts route to microsoft-docs" 'Microsoft.*concepts.*tutorial.*config.*`microsoft-docs`' skills/dev-workflow/SKILL.md
has "Microsoft signatures route to code reference" 'API signature.*SDK sample.*`microsoft-code-reference`' skills/dev-workflow/SKILL.md
has "research stays inside delegation and persistence gates" 'Route 到 `research`.*background agent.*\[INT-4\].*Markdown.*S2 authorization' "$routing_continuations_ref"
has "high-fan-in changes route to deps-check" '高扇入.*`deps-check`.*callers' skills/dev-workflow/SKILL.md
has "focused security routes to shared-security-review" 'focused.*`shared-security-review`' skills/dev-workflow/SKILL.md
has "heavy security audit is explicit and artifact-aware" '明示.*artifacts.*`security-audit`' skills/dev-workflow/SKILL.md
has "security pipeline gates stay separate" 'SBOM.*`dependency-security-scan`' skills/dev-workflow/SKILL.md
has "bug settlement assessment stays mandatory" '強制.*評估|評估.*強制' skills/bug-fix-settlement/SKILL.md
has "bug settlement memory requires explicit request" 'Memory.*只有使用者明示' skills/bug-fix-settlement/SKILL.md
has "bug settlement persistence is target-authorized" 'Cookbook.*Workflow.*exact target|exact target.*Cookbook.*Workflow' skills/bug-fix-settlement/SKILL.md
lacks "bug settlement no longer equates recommendation with authorization" '一旦標記 ✅，Step 2 就必須完成對應寫入' skills/bug-fix-settlement/SKILL.md
has "backend release rollout routes to shared authorization gate" '`dev-workflow`.*\[T0-8\].*S2' skills/backend-release-verification/SKILL.md
has "container rollout routes to shared authorization gate" '`dev-workflow`.*\[T0-8\].*S2' skills/containerization/SKILL.md
lacks "backend release has no dead CLAUDE.md plan pointer" 'CLAUDE\.md.*Plan first' skills/backend-release-verification/SKILL.md
lacks "containerization has no dead CLAUDE.md plan pointer" 'CLAUDE\.md.*Plan first' skills/containerization/SKILL.md
has "single-skill behavioral authoring routes to writing-for-agents" '單一 skill.*behavior.*invocation.*description.*pruning.*`writing-for-agents`' skills/dev-workflow/SKILL.md
has "existing agent documents route to writing-for-agents" '既有 AGENTS\.md.*CLAUDE\.md.*pointed-at agent doc.*`writing-for-agents`' skills/dev-workflow/SKILL.md
has "project-doc initialization stays with init-project-docs" '初始化或整體 refresh.*`init-project-docs`' skills/dev-workflow/SKILL.md
has "skill scaffolding stays with the host creator" 'skill scaffolding.*host creator' skills/dev-workflow/SKILL.md
has "skill-folder lifecycle audit routes to auditing-skill-folder" 'skill folder.*keep.*trim.*delete.*migrate.*`auditing-skill-folder`' skills/dev-workflow/SKILL.md
has "skill audit loads VND continuation" 'skill audit／VND.*continuations' skills/dev-workflow/SKILL.md
has "single-skill trigger failure requires caller-compatible RED" '單一 skill.*trigger failure.*MUST.*preserved RED.*caller.*`diagnosing-bugs`.*Step 2c RED.*`writing-for-agents`' skills/dev-workflow/SKILL.md
lacks "audit no longer requests explicit writing-skill invocation" 'explicitly invoke `writing-for-agents`|明示.*`writing-for-agents`' skills/auditing-skill-folder/SKILL.md
has "writing-for-agents covers host and pointed-at instructions" 'AGENTS\.md.*CLAUDE\.md.*pointed-at agent doc' skills/writing-for-agents/SKILL.md
has "writing-for-agents requires canonical placement first" 'canonical placement is chosen' skills/writing-for-agents/SKILL.md
has "host policy writing returns to the shared authorization gate" 'Before writing a host policy file.*dev-workflow.*S2.*T0-8' skills/writing-for-agents/SKILL.md
# cd 進 $ROOT 再用相對路徑掃：`rg <absolute-path> --glob '!proposals/**'` 的 glob 只在 cwd
# 位於 $ROOT 之上時比得到，換個 cwd 執行同一支腳本，排除失效、proposals/ 的歷史命中會讓
# 這條誤 FAIL（2026-08-08 實測：worktree 內 281 PASS / 0 FAIL，git archive 到別處 280/1）。
# 方向是 fail-closed 不會放行，但「同一份 code 依執行目錄給不同結果」本身就不該留著。
# `|| exit 3` 而非 `&&`：cd 失敗時 subshell 回 1，與 rg 的「無命中」同碼，會在完全沒掃描
# 的情況下落進 ok 分支。回 3 讓下方的 `*) ng` 接住。
if (cd "$ROOT" || exit 3; rg --hidden -n 'writing-great-skills' . \
     --glob '!attic/**' --glob '!proposals/**' --glob '!tests/**' \
     --glob '!vendored-forks.md' --glob '!.git/**') >/dev/null 2>&1; then
  ng "active writing surfaces no longer use the retired name"
else
  active_retired_name_rc=$?
  case "$active_retired_name_rc" in
    1) ok "active writing surfaces no longer use the retired name" ;;
    *) ng "active writing surfaces retired-name scan completes" ;;
  esac
fi
[ ! -e "$ROOT/skills/writing-great-skills" ] && ok "retired writing skill directory is absent" || ng "retired writing skill directory is absent"
has "Codex metadata uses the new writing name" 'display_name: "Writing for Agents"' skills/writing-for-agents/agents/openai.yaml
has "Codex metadata covers generalized writing scope" 'short_description:.*skills.*agent-facing documents' skills/writing-for-agents/agents/openai.yaml
has "setup no longer names retired qa" 'Skills like `to-tickets`, `triage`, and `to-spec`' skills/setup-matt-pocock-skills/SKILL.md
lacks "setup has no retired qa dependency" '`qa`' skills/setup-matt-pocock-skills/SKILL.md
lacks "code-review uses spec terminology" 'PRD' skills/code-review/SKILL.md
lacks "to-spec uses spec terminology" 'PRD' skills/to-spec/SKILL.md
has "tdd points architecture vocabulary to codebase-design" 'shape of that interface.*`?/codebase-design`?.*vocabulary' skills/tdd/SKILL.md
has "logic prototype is a self-contained HTML file" 'single, self-contained HTML file' skills/prototype/LOGIC.md
has "logic prototype stays offline" 'no CDN.*network.*secret|offline.*CDN.*secret' skills/prototype/LOGIC.md
has "logic prototype uses synthetic non-sensitive fixtures" 'Fixture state uses synthetic, non-sensitive data' skills/prototype/LOGIC.md
has "logic prototype translates validated shape for non-JavaScript hosts" 'another language.*validated states.*transitions.*invariants.*native implementation' skills/prototype/LOGIC.md
has "prototype delivery returns to the shared authorization gate" 'delivery outside the local session.*dev-workflow.*authorization gate' skills/prototype/LOGIC.md
has "triage delegates cadence to grilling" 'canonical `/grilling` contract own question cadence' skills/triage/SKILL.md
lacks "triage does not duplicate grilling cadence" 'one question at a time|round of questions at a time' skills/triage/SKILL.md
lacks "wayfinder does not duplicate grilling cadence" 'one question at a time|round of questions at a time' skills/wayfinder/SKILL.md
lacks "grill-with-docs does not duplicate grilling cadence" 'one question at a time|round of questions at a time' skills/grill-with-docs/SKILL.md
lacks "ask-matt does not own a second phase-boundary file" 'PHASE-BOUNDARIES\.md' skills/ask-matt/SKILL.md
has "routing continuation owns phase-boundary choice" '[Pp]hase boundary.*Continue.*clear.*handoff.*subagent.*compact' skills/dev-workflow/references/routing-continuations.md
has "routing continuation avoids a hard token threshold" 'grilling.*to-spec.*to-tickets.*同一 context.*不設固定 token threshold' skills/dev-workflow/references/routing-continuations.md
has "mid-phase compaction routes through handoff" 'compact.*只在 phase boundary.*mid-phase.*handoff' skills/dev-workflow/references/routing-continuations.md
[ "$(grep -c '^skill=' "$ROOT/mattpocock-skills.lock")" -eq 22 ] && ok "Matt selected set contains 22 skills" || ng "Matt selected set contains 22 skills"
lacks "unselected Matt additions remain excluded" '^skill=(wizard|wait-what|to-questionnaire)$' mattpocock-skills.lock
# explicit route: grill-with-docs 由第 67 行的「明示.*`grill-with-docs`」涵蓋（措辭更精確），
# 不再重複斷言 —— S0 表用反引號而非斜線前綴，原本的 '/grill-with-docs' 在此不成立。
has "explicit route: improve-codebase-architecture" 'improve-codebase-architecture.*explicit-only' skills/dev-workflow/SKILL.md
lacks "active routing no longer names mp replacements" 'mp-(grill-with-docs|improve-codebase-architecture|diagnose|tdd)' skills/dev-workflow/SKILL.md

has "external issue or PR routes to triage" '外部.*issue.*PR.*`triage`' skills/dev-workflow/SKILL.md
has "grill-with-docs stays explicit" '明示.*`grill-with-docs`' skills/dev-workflow/SKILL.md
has "S2 routes mutations through the authorization matrix" 'mutation.*side effect.*authorization.*matrix|變更.*side effect.*authorization.*matrix' skills/dev-workflow/SKILL.md
section_has "S2 requires an explicit authorized delivery scope" "S2 AUTHORIZE" "$delivery_s2_pattern" skills/dev-workflow/SKILL.md
has "read-only requests stay outside implementation" 'Read-only.*不得擴成 implementation' "$authorization_matrix_ref"
has "clear change build fix directly authorizes local implementation" '明確.*change／build／fix.*in-scope local implementation.*non-destructive verification' "$authorization_matrix_ref"
lacks "clear work does not wait for implement invocation" '需求已清楚.*推薦.*`implement`|單一 session.*等待.*`implement`' skills/dev-workflow/SKILL.md "$routing_continuations_ref"
rule_has "Medium risk alone does not reopen authorization" INT-3 'Medium-risk.*MUST NOT.*第二次確認|MUST NOT.*Medium-risk.*第二次確認'
has "mechanical triggers set a non-overridable risk floor" 'mechanical trigger.*risk floor.*不得.*(自評|label).*降級' "$authorization_matrix_ref"
has "multiple triggers take the highest risk floor" '多個 trigger.*最高 risk floor' "$authorization_matrix_ref"
has "S2 keeps local reversible Medium autonomous" 'Medium-risk.*session plan.*不需第二次確認|Medium.*本身不是第二次授權 gate' "$authorization_matrix_ref"
has "S2 stops before High or protected boundaries" 'High.*protected boundary.*material scope expansion.*停|High.*material scope expansion.*protected boundary.*停' "$authorization_matrix_ref"
has "S2 asks only for material ambiguity" '只有會改變 outcome／scope／risk 的 material ambiguity 才停下發問' "$authorization_matrix_ref"
has "S2 keeps reversible defaults autonomous" '低風險.*可逆.*無 material impact.*sensible default.*default／impact' "$authorization_matrix_ref"
lacks "S2 does not restore blanket ask-before-edit" '有多種合理解讀且會改檔時.*停下發問' skills/dev-workflow/SKILL.md "$authorization_matrix_ref"
has "personal preferences stay on the reversible local track" 'Personal preference.*model.*effort.*verbosity.*UI.*local.*reversible' "$authorization_matrix_ref"
has "plugin and MCP capability expansion use the policy track" 'Policy.*plugin.*MCP.*credential.*permission.*tool capability.*INT-10' "$authorization_matrix_ref"
has "MCP command args and env changes stay on the policy track" 'MCP.*command／args／env.*Policy' "$authorization_matrix_ref"
has "weakening an existing control stays on the policy track" '刪除／停用／放寬.*hook.*sandbox.*permission.*Policy' "$authorization_matrix_ref"
has "local reversible excludes unbacked ignored deletion" 'local reversible.*VCS.*backup.*untracked／ignored.*不算' "$authorization_matrix_ref"
has "checkpoint commit is feature-branch-only after targeted S4" 'checkpoint.*(feature branch|worktree).*targeted S4.*PASS' "$authorization_matrix_ref"
has "checkpoint excludes sensitive and publication surfaces" 'checkpoint.*secrets.*permission.*sandbox.*hooks.*CI.*deployment.*migration.*push.*PR.*merge' "$authorization_matrix_ref"
has "checkpoint excludes global and security policy" 'checkpoint.*global／security policy' "$authorization_matrix_ref"
has "checkpoint cannot claim final completion" '不得宣稱 final done' "$authorization_matrix_ref"
has "checkpoint keeps the original cumulative baseline" 'Checkpoint 不重設 baseline.*未跑的 S5／CI／review.*原 baseline.*累積 diff' "$ledgers_ref"
has "checkpoint baseline is an immutable ancestor SHA" 'immutable baseline SHA.*merge-base.*--is-ancestor.*gate FAIL.*全套重驗' "$ledgers_ref"
has "checkpoint verification reuses repo-defined commands" 'checkpoint.*targeted S4.*repo／CI.*既有.*commands' "$authorization_matrix_ref"
has "checkpoint stages an explicit allowlist and scans it" 'checkpoint.*explicit path allowlist.*git add -A.*gitleaks.*--staged' "$authorization_matrix_ref"
has "checkpoint blocks foreign pre-staged paths without unstaging them" 'checkpoint 前.*git diff --cached --name-only.*allowlist 外.*停止.*不得.*unstage.*stage 後.*僅.*allowlist' "$authorization_matrix_ref"
has "credential-only operations do not inherit blanket T0-6 rollback" 'Credential-only.*T0-8.*INT-10.*T0-6.*不適用' "$authorization_matrix_ref"
has "T0-6 rollback remains on its exact categories" 'Auth.*payment.*migration.*大量刪除.*crypto.*multi-tenant.*rate-limit.*deployment pipeline.*T0-6.*rollback' "$authorization_matrix_ref"
has "S6 routes checkpoint commits through the matrix" 'checkpoint.*authorization-matrix' skills/dev-workflow/SKILL.md
has "ownership gate runs semantic parity against actual host candidates" 'three-host-capability-parity\.sh.*--check' "$host_ownership_test"
has "ownership gate maps the Claude candidate" 'CLAUDE_INSTRUCTIONS=.*CLAUDE_CANDIDATE.*CLAUDE\.md' "$host_ownership_test"
has "ownership gate maps the Codex candidate" 'CODEX_INSTRUCTIONS=.*CODEX_CANDIDATE.*AGENTS\.md' "$host_ownership_test"
has "ownership gate maps the Copilot candidate" 'COPILOT_INSTRUCTIONS=.*COPILOT_CANDIDATE.*copilot-instructions\.md' "$host_ownership_test"
has "missing canonical spec routes through to-spec" '無 canonical spec.*`to-spec`.*`to-tickets`' "$routing_continuations_ref"
has "existing spec skips duplicate to-spec" '已有完整 spec.*略過 `to-spec`.*`to-tickets`' "$routing_continuations_ref"
has "ticket implementation starts fresh" '每張 ticket.*fresh session.*isolated.*worktree' "$routing_continuations_ref"
has "session interruption routes to handoff" 'session 中斷.*`handoff`' skills/dev-workflow/SKILL.md
has "handoff only bridges uncaptured context" '`handoff`.*未進入 spec.*ticket.*wayfinder map' "$routing_continuations_ref"
has "explicit session switch recommends handoff" '使用者明示.*換 session.*交接.*另一個 agent.*`handoff`' "$routing_continuations_ref"
has "unfinished stop makes handoff the sole next action" 'blocker.*session 邊界.*工作未完成.*`handoff`.*唯一 next action' "$routing_continuations_ref"
has "canonical artifact suppresses duplicate handoff" '已有 canonical artifact.*只引用.*不重複' "$routing_continuations_ref"
has "compaction and completion do not trigger handoff" 'context compaction.*任務已完成.*內容很長.*MUST NOT.*`handoff`' "$routing_continuations_ref"

has "closeout is action-triggered" 'push.*open PR.*merge.*final closeout' skills/dev-workflow/SKILL.md
section_has "PR closeout requires the full terminal delivery path" "S6 CLOSEOUT" "$delivery_s6_pattern" skills/dev-workflow/SKILL.md
has "implement adapter enters branch" '`implement`.*(branch|worktree)' skills/dev-workflow/SKILL.md
has "implement adapter requires S4-S6" '`implement`.*S4.*S6' skills/dev-workflow/SKILL.md

delivery_fixture="$(mktemp -d "${TMPDIR:-/tmp}/delivery-contract.XXXXXX")" ||
  { ng 'delivery contract fixture: 無法建立暫存目錄'; exit 1; }
cp "$ROOT/skills/dev-workflow/SKILL.md" "$delivery_fixture/baseline.md" ||
  { ng 'delivery contract fixture: 無法複製 baseline'; exit 1; }
if delivery_contract_valid "$delivery_fixture/baseline.md"; then
  ok "delivery guard accepts its baseline fixture"
else
  ng "delivery guard accepts its baseline fixture"
fi
delivery_missing_rc=0
delivery_contract_valid "$delivery_fixture/missing.md" || delivery_missing_rc=$?
[ "$delivery_missing_rc" -gt 1 ] &&
  ok "delivery guard reports a missing fixture as validator error" ||
  ng "delivery guard reports a missing fixture as validator error"
delivery_case=0
delivery_mutation_rejected() {
  local label="$1" from="$2" to="$3" fixture rc=0
  delivery_case=$((delivery_case + 1))
  fixture="$delivery_fixture/$delivery_case.md"
  sed "s|$from|$to|" "$delivery_fixture/baseline.md" > "$fixture" ||
    { ng "$label (fixture mutation failed)"; return; }
  delivery_contract_valid "$fixture" || rc=$?
  case "$rc" in
    0) ng "$label" ;;
    1) ok "$label" ;;
    *) ng "$label (validator error rc=$rc)" ;;
  esac
}
delivery_mutation_rejected "delivery guard rejects existing-files-only scope" \
  '預計納入 VCS 的檔案新增／修改' '既有 tracked source 修改'
delivery_mutation_rejected "delivery guard rejects main/master writes" \
  'task branch／worktree（非 main／master）' 'main／master'
delivery_mutation_rejected "delivery guard rejects optional scope records" \
  '寫入前 MUST 記' '寫入前可不記'
delivery_mutation_rejected "delivery guard rejects unapproved PR closeout" \
  '後者須核准' '後者不須核准'
delivery_mutation_rejected "delivery guard rejects skipped current-head gate" \
  'current-head CI／bot gate PASS' 'current-head gate 可略過'
delivery_mutation_rejected "delivery guard preserves ledgers merge strategy" \
  '依 ledgers 選 merge strategy' '固定 squash merge'
delivery_mutation_rejected "delivery guard rejects early final" \
  'branch cleanup 才 final' 'merge 前即可 final，branch cleanup 可略過'
rm -r -- "$delivery_fixture"
has "S5 has Standards and Spec axes" 'Standards.*Spec' skills/dev-workflow/SKILL.md
has "S5 axes have four states" 'PASS.*FAIL.*SKIPPED.*UNAVAILABLE' skills/dev-workflow/SKILL.md
has "S5 dirty review includes staged and unstaged changes" 'staged.*`git diff --cached --`.*unstaged.*`git diff --`' "$dirty_review"
has "S5 dirty review includes untracked files" 'git ls-files --others --exclude-standard' "$dirty_review"
rule_has "S5 risk contract has five elements" S5-1 'MUST.*觸發：.*例外：.*驗證：'
rule_has "S5 package contract has five elements" S5-2 'MUST.*觸發：.*例外：.*驗證：'
has "S5 dirty review inventories explicit ignored paths" 'metadata inventory.*task 明列.*ignored' "$dirty_review"
has "S5 package omits secret-bearing content" 'secret-bearing.*MUST NOT.*全文' "$dirty_review"
has "S5 package limits secret evidence" 'path.*set／unset.*redacted finding' "$dirty_review"
has "S5 package names common secret paths" '\.env\*.*credentials.*private keys.*token stores' "$dirty_review"
has "S5 package scans staged changes" 'gitleaks git --staged --redact' "$dirty_review"
has "S5 package scans unstaged changes" 'gitleaks git --pre-commit --redact' "$dirty_review"
has "S5 package scans untracked and ignored candidates" 'gitleaks dir --redact' "$dirty_review"
has "S5 package scans before raw diff" '全部掃描通過後.*git diff --cached --`.*git diff --`' "$dirty_review"
has "S5 finding blocks raw package assembly" 'finding.*MUST.*FAIL.*raw.*MUST.*omit' "$dirty_review"
has "S5 package bounds binary and oversized files" 'binary.*256 KiB.*path.*size.*hash|256 KiB.*binary.*path.*size.*hash' "$dirty_review"
has "S5 package includes safe untracked candidates" '非敏感.*untracked.*ignored.*納入.*review package' "$dirty_review"
lacks "S5 package has no unconditional ignored-file content" 'ignored path 全文' "$dirty_review"
has "delegation changes who decides, not what is allowed" 'Delegation 的\*\*約束\*\*不變，改變的只有\*\*誰決定\*\*' "$delegation_ref"
has "delegation requires independently parallel scope" '任何 delegation 機制只在工作可獨立平行.*使用' "$delegation_ref"
has "delegation keeps its unconditional constraints" '無條件約束（不因任何授權而放寬）.*序列相依.*寫入 ownership MUST 不重疊.*MUST 重驗其回報' "$delegation_ref"
has "unconditional constraints are not purchasable with authorization" '無條件約束不在可授權範圍內.*即使取得授權也 MUST NOT 執行' "$delegation_ref"
has "AI decides delegation timing and count" '是否委派、何時委派、subagent 數量與是否平行 MUST 由 AI 自主判定' "$delegation_ref"
has "delegation has no user-authored fixed limits" '不得設定 user-authored 的固定數量、併發、累計或 S 階段限制' "$delegation_ref"
has "runtime capacity remains a technical bound" 'host/runtime 可用容量仍是技術上限' "$delegation_ref"
has "S5 review agents stay read-only while AI chooses usage" 'S5 Standards／Spec outcomes.*如使用 review agents，MUST 為 read-only，數量與批次由 AI 決定' "$delegation_ref"
has "downstream fixed choreography is advisory" '下游 skill 的固定 spawn 時機／數量一律由本條覆寫為 advisory choreography.*coverage、outcome 與 independence requirements 保留' "$delegation_ref"
rule_has "delegation cannot bypass authorization gates" INT-4 'MUST NOT 用 delegation 迴避 S2 授權或 \[T0-8\] plan gate'
rule_has "stable valuable seam requires RED" INT-2 'stable.*valuable.*seam.*failing regression test.*RED'
rule_has "unstable seam keeps same repro before after" INT-2 '否則.*同一.*repro.*before／after.*理由'
rule_has "INT-2 keeps the five-element rule contract" INT-2 '觸發：.*例外：.*驗證：'
lacks "bugfix no longer has unconditional RED" 'MUST 在 fix 前先有 failing regression test.*例外：無' skills/dev-workflow/SKILL.md
rule_has "kernel overrides upstream tdd seam and refactor rules" INT-9 'stable.*valuable.*\[tdd\]\(\.\./tdd/SKILL\.md\).*既有 public behavior seam.*新增 seam.*micro-refactor.*重跑.*覆寫'
rule_has "S5 medium and PR reviews run both axes" S5-1 '中高風險.*PR.*Standards.*Spec'
rule_has "S5 low-risk non-PR reviews may be skipped" S5-1 '低風險.*不進 PR.*SKIPPED'
has "reviewer template owns severity and confidence" '全部回報、下游過濾.*severity.*confidence|全部回報、下游過濾.*確信度' skills/dev-workflow/references/reviewer-template.md
has "reviewer template keeps axes separate" '單一 review 軸內.*跨軸不合併、不重排' skills/dev-workflow/references/reviewer-template.md
has "reviewer template carries the complete-report contract" '全部回報、下游過濾.*不設字數或條數上限.*確信度.*高／中／低' skills/dev-workflow/references/reviewer-template.md
# [S5-3] 要求 baseline 逐字進 Standards 軸的 reviewer prompt（2026-08-03 當時兩條、現為
# 五條），但在 2026-08-03 之前零測試守它——同日 reviewer-template.md 被編輯注入 [S5-4] 時，
# [S5-3] 的兩條仍被漏掉，單純是注意力都在 S5-4，沒有守衛擋。規則沒有機械守衛就會在下一次
# 編輯再漏一次。
# host-local review agent（~/.claude/agents/*.md、~/.codex/agents/*.toml）的同名注入由各
# host repo 的自檢負責，跨 repo 不可斷言。
# 比對兩條「全文」含 `→` 之後的動作句：只比對前半（「手刻標準庫或平台已提供的功能」）時，
# 把動作句裁掉仍會 PASS——守衛會再次 fail-open，且與 [S5-3] 驗證條款的「全文」不符。
has "reviewer template carries the Reinvented Stdlib baseline" 'Reinvented Stdlib.*手刻標準庫或平台已提供的功能 → 指名該 API 取代。' skills/dev-workflow/references/reviewer-template.md
has "reviewer template carries the Redundant Dependency baseline" 'Redundant Dependency.*為平台／既有模組已有的能力新增依賴 → 依選型階梯（原生 > 標準庫 > 既有模組 > 第三方 > 手寫）回退。' skills/dev-workflow/references/reviewer-template.md
has "code-review Standards baseline carries Reinvented Stdlib" 'Reinvented Stdlib.*手刻標準庫或平台已提供的功能 → 指名該 API 取代。' skills/code-review/SKILL.md
has "code-review Standards baseline carries Redundant Dependency" 'Redundant Dependency.*為平台／既有模組已有的能力新增依賴 → 依選型階梯（原生 > 標準庫 > 既有模組 > 第三方 > 手寫）回退。' skills/code-review/SKILL.md
# 2026-08-08：baseline 擴為五條，新三條同樣需要守衛。
has "reviewer template carries the Unused Local Reuse baseline" 'Unused Local Reuse.*→ 指名既有符號並改呼叫它。' skills/dev-workflow/references/reviewer-template.md
# 這條在兩個檔的定義刻意不同，pattern 不能共用：reviewer-template 沒有 Fowler 清單，它的
# 定義前半（只做轉發的中間層、為 spec 沒有的需求預留）是 Codex／Copilot 唯一的 Middle Man
# 與 Speculative Generality 載體。只釘共通的動作句時，把它換成 code-review 的窄版仍會 PASS。
has "reviewer template carries the Needless Indirection baseline" 'Needless Indirection.*只做轉發的中間層.*為 spec 沒有的需求.*→ 內聯回去' skills/dev-workflow/references/reviewer-template.md
has "reviewer template carries the Wrong Altitude baseline" 'Wrong Altitude.*→ 把該決策移回它該在的層。' skills/dev-workflow/references/reviewer-template.md
has "code-review Standards baseline carries Unused Local Reuse" 'Unused Local Reuse.*→ 指名既有符號並改呼叫它。' skills/code-review/SKILL.md
has "code-review Standards baseline carries Needless Indirection" 'Needless Indirection.*→ 內聯回去，等真的第二個使用點出現再抽。' skills/code-review/SKILL.md
has "code-review Standards baseline carries Wrong Altitude" 'Wrong Altitude.*→ 把該決策移回它該在的層。' skills/code-review/SKILL.md
# code-review 沒有優先序清單，reviewer-template 的優先序第 3、4 級（performance、
# correctness）在該路徑本來無落點——security 由 S0 route 到 shared-security-review、
# breaking changes 到 deps-check，只有這兩級無家可歸。upstream rebase 會靜默把 clause
# 掉回原狀，而症狀只是「review 不再報效能／不再報邊界條件」，沒人會發現。
has "code-review Standards brief carries the performance clause" 'performance regressions the diff introduces' skills/code-review/SKILL.md
has "code-review Standards brief carries the correctness clause" 'correctness defects — boundary conditions' skills/code-review/SKILL.md
# 設計註記 MUST 留在 prompt 區塊外：在區塊內時 Codex／Copilot 會把「不含 efficiency 維」
# 一起複製進 reviewer prompt，對 reviewer 讀起來就是「這一維不用看」。用標題 grep 證明不了
# 位置（整段搬到區塊之前也會 PASS），所以直接掃區塊內容。
#
# 兩個 marker 先各自釘住：sed range 靠它們定界，marker 被改名或刪掉時 range 產出 0 行、
# grep 找不到、直接落進 ok 分支回綠——守衛在自己的定界消失時 fail-open，而全庫唯一寫著
# 這兩個字串的地方就是下面這段檢查本身。range 非空也一併斷言，兩道都過才驗內容。
# stack 的 merge-commit 例外與 [INT-10] 的 squash 五步路徑（tests/pr-path-gate.sh 釘著）
# 直接對立，兩邊各自綠燈時矛盾無人察覺。釘住「例外指名 [INT-10] 為排除範圍」這件事本身。
has "ledgers scopes the merge-commit exception by parent PR" '父 PR 不在 \[INT-10\] 範圍.*MUST 用 merge commit 合併，不用 squash' "$ledgers_ref"
has "ledgers keeps INT-10 parents on the rebase path" '父 PR 在 \[INT-10\] 範圍.*所有子 PR 一律走 rebase 補救' "$ledgers_ref"
# apply pass 要釘兩處。只釘句首時，把「重新納入 S5」那整段後綴刪掉測試仍全綠——而那半句
# 才是 [S5-1] 不被繞過的保證；被靜默刪掉的症狀只是「S5 之後沒人動手改」或更糟的「一批
# code 沒進過 review」，兩者都不會有人發現。實測過。
section_has "Claude adapter binds simplify as the S5 apply pass" Claude 'MUST 跑 .simplify.*當 apply pass' "$host_adapters_ref"
has "simplify output re-enters S5" '重新納入 S5.*繞過 \[S5-1\]' "$host_adapters_ref"
has "shared simplification outcome has a canonical section" '^## S5 simplification apply outcome$' "$host_adapters_ref"
has "shared simplification outcome records changed or no-op" '結果 MUST 記為 `changed` 或 `no-op`' "$host_adapters_ref"
has "every changed simplification pass re-enters S4 and affected S5" '`changed` 回 S4 並把 affected diff 重新納入 S5' "$host_adapters_ref"
section_has "Codex maps the simplification outcome to an explicit apply pass" Codex '^\- S5 simplification mechanism = main-context explicit apply pass。$' "$host_adapters_ref"
section_has "Copilot maps the simplification outcome to an explicit apply pass" Copilot 'simplification mechanism = main-context explicit apply pass。$' "$host_adapters_ref"
common_simplification="$(sed -n '/^## S5 simplification apply outcome$/,/^## Claude$/p' "$ROOT/$host_adapters_ref" | sed '$d')"
if printf '%s\n' "$common_simplification" | rg -q 'Claude|Codex|Copilot'; then
  ng "shared simplification method stays host-neutral"
else
  ok "shared simplification method stays host-neutral"
fi
# 以下這批守衛的 pattern 一律釘「會翻轉的子句」，不釘引入語。教訓是同一個撰寫方法會換
# 外觀復發：未錨行首行尾 → 只釘句首 → 釘住錯誤引用 → 極性反轉。判準是「把這句改成相反
# 意思，pattern 還能不能命中」；每一條都做過這個反轉測試才留下。
#
# 實測：下面三條同時還原成前一版寫法，283 條測試全綠——而 reviewer-template 第 7 行一
# 還原，Claude 路徑就再次豁免掉整份 reference，沒有任何 FAIL。
has "reviewer-template exempts only the prompt block" '豁免的是 prompt 區塊本身.*本檔其餘各節對它們一樣有約束力' skills/dev-workflow/references/reviewer-template.md
# 釘 cell 尾的 `|`：`非 SKIPPED S5 review` 是修復前的錯誤字串 `非 SKIPPED S5 reviewer prompt`
# 的嚴格前綴，不釘邊界的話還原成那個 bug 一樣全綠（2026-08-08 實測，六條反向斷言裡唯獨
# 這條沒 FAIL）。
has "reviewer-template load-when covers all S5 review" 'references/reviewer-template.md` \| 非 SKIPPED S5 review \|' skills/dev-workflow/SKILL.md
has "Claude adapter binds the whole reviewer-template" '不豁免 `references/reviewer-template.md`.*其餘各節對 Claude 一樣有約束力' "$host_adapters_ref"
has "Preflight row 6 points at the resolved definition" 'reviewer-template.md` 的「回饋處理」' "$ledgers_ref"
# row 6 的載入證據：引用 baseline 五條中至少兩條的標題。
#
# 這一版是四輪 S5 收斂後的形狀，前三版都用「在 reviewer-template 檔頭放一個識別碼、要求
# ledger 引用它」，三輪各被打掉一次，而且是同一個病的三個層次：
#   1. 識別碼被逐字印在 ledgers.md 的 row 6 與範例裡 → 照抄那格即可，開檔數零。
#   2. 改成只寫格式後，同檔檔頭的兄弟指紋提供了季度，一次代換仍可湊出值。
#   3. 加上不可推導的尾碼後，引入它的那顆 commit 在 message 裡逐字寫了值——而 row 2／row 6
#      要 baseline SHA 與 range，填 ledger 的人本來就得跑 `git log`。
# 根因不是實作沒寫好，是機制選錯：識別碼與它要證明的事（讀過那一節）之間沒有必然關係，
# 於是每堵一條旁路就長出下一條。改驗 contract 本身之後這整類問題消失——標題外流等於
# contract 外流，正是要的結果，所以沒有洩漏面、不必輪替、不需要負向守衛。
#
# 錨 `^| 6 |`：不錨的話把 row 6 的要求整段刪掉、另在檔尾留一句含同樣詞的散文，斷言仍全綠
# （S5 實測）。兩項拆成兩條而非 `A.*B` 串接，否則日後把證據項重排就無故轉紅。
# 範例是「照抄來源」，缺什麼就會被整批複製到每個 PR body。這兩行原本只存在於 host 的
# hook 裡，ledgers.md 從頭到尾沒出現過（`grep -c 'S5 Standards:'` = 0），於是照抄範例
# 產出的 body 會被機械檢查擋下，而 deny 訊息連不回它剛照抄的那份文件。
#
# 必須 range-scope 到 Preflight 那一節：file-global 的 grep 在「把兩行搬進 Closeout 範例」
# 這種合理的整理改動下仍全綠（S5 實測），而真正會變成 PR body 的區塊已經沒有它們。
# 不用既有的 section_has——ledgers.md 的 fenced 範例裡本來就有 `## Preflight Ledger`，
# 那支 helper 掃到 `^## ` 就停，範例永遠落在 scope 外。
#
# 狀態值收成四態 alternation 而非釘死某一個：釘死的話，範例改用別的狀態（完全合法）
# 就無故轉紅。本文的 placeholder `S5 Standards: <PASS|FAIL|…>` 不會誤命中——`<` 卡在中間。
preflight_section="$(sed -n '/^## 1\. Preflight Ledger/,/^## 2\. Closeout Ledger/p' "$ledgers_ref")"
for _axis in Standards Spec; do
  if printf '%s\n' "$preflight_section" | grep -qE "^S5 ${_axis}: (PASS|FAIL|SKIPPED|UNAVAILABLE)"; then
    ok "Preflight example carries the ${_axis} axis line"
  else
    ng "Preflight example carries the ${_axis} axis line"
  fi
done
has "Preflight row 6 requires the review range" '^\| 6 \|.*審查對象 range' "$ledgers_ref"
has "Preflight row 6 requires quoting two baseline titles" \
  '^\| 6 \|.*baseline 五條中至少兩條的標題' "$ledgers_ref"
# Closeout 的 Review gate 列帶著同一套證據項，同樣要有守衛——否則那兩項在非 PR 路徑上
# 被整段刪掉，上面兩條錨 `^| 6 |` 的斷言不可能命中（S5 實測：整段刪掉仍全綠）。
# 同樣拆兩條：串接版在證據項對調順序時會無故轉紅（S5 實測 REORDER → 0）。
has "Closeout Review gate requires the review range" \
  '^\| \*\*Review gate\*\* \|.*審查對象 range' "$ledgers_ref"
has "Closeout Review gate requires the baseline titles" \
  '^\| \*\*Review gate\*\* \|.*baseline 五條中兩條的逐字標題' "$ledgers_ref"
# cascade 子句掛在只釘句首的斷言後面，整段刪掉仍全綠（實測）——同一支檔上面才寫過這個教訓。
has "ledgers explains the cascade cost" '三層以上的 stack 不能逐層各判各的' "$ledgers_ref"
# review-triage 引用的是這個標題的逐字形式，改名會靜默斷鏈。
has "stacked PR section heading is stable" '^## Stacked PR 的 diff scoping' "$ledgers_ref"
# 錨定整行：同檔「怎麼用」第 1 步的說明文字裡就引用了這兩個 marker 字串，不錨行首行尾的
# 話 has 會命中那句描述、sed range 也會從那行起算——marker 本身被改名依然全綠。
has "reviewer prompt block has an opening marker" '^── reviewer prompt 開始 ──$' skills/dev-workflow/references/reviewer-template.md
has "reviewer prompt block has a closing marker" '^── reviewer prompt 結束 ──$' skills/dev-workflow/references/reviewer-template.md
prompt_block="$(sed -n '/^── reviewer prompt 開始 ──$/,/^── reviewer prompt 結束 ──$/p' \
  "$ROOT/skills/dev-workflow/references/reviewer-template.md")"
# 數行而不是只檢查 -z：sed 的 range 一定含兩個 marker 行，所以把 prompt 內容整段清空
# 之後 `-z` 仍不成立，守衛會比它自稱的弱。> 2 行才代表 marker 之間真的有東西。
prompt_lines=0
[ -n "$prompt_block" ] && prompt_lines="$(printf '%s\n' "$prompt_block" | wc -l | tr -d ' ')"
if [ "$prompt_lines" -le 2 ]; then
  ng "reviewer prompt block is non-empty"
  # range 空或只剩 marker 時 design-notes 這條無從判定。明確標 FAIL 而非略過——略過會讓
  # 總條數隨檔案狀態浮動，看起來像「少跑了一條」而不是「守衛失去依據」。
  ng "baseline design notes live outside the reviewer prompt"
elif printf '%s' "$prompt_block" | grep -q '設計註記'; then
  ok "reviewer prompt block is non-empty"
  ng "baseline design notes live outside the reviewer prompt"
else
  ok "reviewer prompt block is non-empty"
  ok "baseline design notes live outside the reviewer prompt"
fi
# B 層（2026-08-03）：兩條「放寬」型修正，各自要有守衛——放寬比收緊更需要，因為退回舊
# 版本不會有人察覺，只會表現為「又開始整份重跑／整份重述」。
#
# B1 Gate contract：verification 依風險擴張，不因一顆低風險 commit 無條件全量重跑；
# current-head CI/review 仍由 PR gate fail-closed。
has "S4 defines low medium high risk tiers" 'Low.*Medium.*High' skills/dev-workflow/SKILL.md
has "S4 expands targeted affected full by risk" 'targeted.*affected.*full CI|targeted.*affected.*full suite' skills/dev-workflow/SKILL.md
lacks "S4 no longer always reruns everything" 'S4 MUST 全跑|Build／test／lint 與 task-specific probes 全跑' skills/dev-workflow/SKILL.md
has "S4 routes all evidence-integrity triggers" 'Behavior-affecting edit.*正式 spec artifact／明列 acceptance criteria.*Medium／High／PR.*新增／修改 custom gate.*evidence-integrity\.md' skills/dev-workflow/SKILL.md
has "medium high and PR evidence binds source and replay" 'Medium／High 或 PR.*source state.*replay command' "$evidence_integrity_ref"
has "dirty and clean source states are exact" 'clean tree.*current HEAD.*dirty tree.*immutable HEAD.*dirty review package.*hash' "$evidence_integrity_ref"
has "formal acceptance mapping covers negative invariants" '正式 spec artifact.*明列 acceptance criteria.*behavior change.*acceptance criterion.*negative invariant.*test／probe／gate' "$evidence_integrity_ref"
has "high risk failure models map to catching layers" 'High-risk.*failure model.*catching layer' "$evidence_integrity_ref"
has "ledger records fresh source-bound replay evidence" 'Tests evidence.*final verification pass.*source state.*replay command' "$ledgers_ref"
has "Preflight verification records high-risk failure coverage" 'Tests evidence.*High-risk.*failure model.*catching layer' "$ledgers_ref"
has "Closeout verification records high-risk failure coverage" 'Relevant verification.*High-risk.*failure model.*catching layer' "$ledgers_ref"
residual_failure_pattern='^\| (8 \| )?\*\*Residual risks\*\*.*failure model'
lacks "Residual risks does not own failure coverage" "$residual_failure_pattern" "$ledgers_ref"
printf '| 8 | **Residual risks** | bad failure model owner |\n' | grep -qE "$residual_failure_pattern" &&
  ok "Residual risks guard catches its Preflight negative control" ||
  ng "Residual risks guard catches its Preflight negative control"

evidence_fixture="$(mktemp -d -- "${TMPDIR:-/tmp}/evidence-integrity.XXXXXX")" ||
  { ng 'evidence integrity fixture: 無法建立暫存目錄'; exit 1; }
cp -- "$ROOT/$evidence_integrity_ref" "$evidence_fixture/good.md" ||
  { ng 'evidence integrity fixture: 無法複製 baseline'; exit 1; }
if evidence_integrity_contract_valid "$evidence_fixture/good.md"; then
  ok "evidence integrity accepts the clean positive control"
else
  ng "evidence integrity accepts the clean positive control"
fi
sed -- 's/MUST fail closed/MUST NOT fail closed/' "$evidence_fixture/good.md" > "$evidence_fixture/known-bad.md" ||
  { ng 'evidence integrity fixture: 無法產生 known-bad control'; exit 1; }
evidence_bad_rc=0
evidence_integrity_contract_valid "$evidence_fixture/known-bad.md" || evidence_bad_rc=$?
case "$evidence_bad_rc" in
  0) ng "evidence integrity rejects the known-bad negative control" ;;
  1) ok "evidence integrity rejects the known-bad negative control" ;;
  *) ng "evidence integrity rejects the known-bad negative control (validator error rc=$evidence_bad_rc)" ;;
esac
evidence_missing_rc=0
evidence_integrity_contract_valid "$evidence_fixture/missing.md" || evidence_missing_rc=$?
[ "$evidence_missing_rc" -gt 1 ] &&
  ok "evidence integrity reports unreadable input as validator error" ||
  ng "evidence integrity reports unreadable input as validator error"
rm -r -- "$evidence_fixture"
has "applicable E2E records a repo-defined isolation boundary" 'Tests evidence.*E2E.*repo-defined isolation boundary.*cleanup' "$ledgers_ref"
has "missing E2E or isolation mechanism is explicit SKIPPED" '無 E2E.*isolation mechanism.*SKIPPED.*理由' "$ledgers_ref"
has "Preflight records isolated E2E or a reasoned skip" 'Tests evidence.*isolation boundary.*SKIPPED' "$ledgers_ref"
has "E2E gate does not require speculative infrastructure" 'E2E.*不得只為 gate 新造測試基礎設施' "$ledgers_ref"
has "current-head PR gates remain whole" 'current `head\.sha`.*CI.*review|current HEAD.*CI.*review' skills/dev-workflow/references/review-triage.md
has "quota fallback requires exact zero-step evidence" 'PASS_NO_CI ci=BILLING_QUOTA.*0 steps.*job was not started.*payments have failed' skills/dev-workflow/references/review-triage.md
has "quota fallback reminds then continues" 'MUST 提醒使用者.*提醒不是停止點.*直接往下' skills/dev-workflow/references/review-triage.md
has "quota fallback keeps hosted CI unavailable" 'Hosted CI 保持 `UNAVAILABLE`.*MUST NOT 改寫成 PASS' skills/dev-workflow/references/review-triage.md
has "quota fallback requires current-head local and independent gates" 'current `head\.sha`.*full local CI-equivalent.*Standards \+ Spec independent review PASS.*0 unresolved' skills/dev-workflow/references/review-triage.md
has "billing review cannot masquerade as current" 'Billing failure.*review 標 `UNAVAILABLE`.*MUST NOT 當 `CURRENT`' skills/dev-workflow/references/review-triage.md
has "non-quota CI failures stay blocked" '任一 failed job 跑過 step.*訊息不符.*其他 failure.*probe 不完整.*`FAIL_CI`.*不得 fallback' skills/dev-workflow/references/review-triage.md
quota_section=$(sed -n '/^2\. \*\*Actions billing／quota/,/^3\. \*\*Bot unavailable/p' "$ROOT/skills/dev-workflow/references/review-triage.md")
if printf '%s\n' "$quota_section" | rg -q '^\s*- Hosted CI (是|視為|改寫成|標記為) `?PASS'; then
  ng "quota section forbids hosted CI affirmative PASS"
else
  ok "quota section forbids hosted CI affirmative PASS"
fi
if printf '%s\n' "$quota_section" | rg -q '提醒(後)?(就是|是|成為)停止點|提醒後.*(停止|等待)|等待使用者確認'; then
  ng "quota reminder cannot become a stop gate"
else
  ok "quota reminder cannot become a stop gate"
fi
if printf '%s\n' "$quota_section" | rg -q '^\s*- Billing failure.*(是|視為|標為|當成) `?CURRENT'; then
  ng "quota section forbids billing review affirmative CURRENT"
else
  ok "quota section forbids billing review affirmative CURRENT"
fi

has "bot fallback is independent and read-only" 'independent read-only reviewer.*current `head\.sha`' skills/dev-workflow/references/review-triage.md
has "bot transient states cannot fallback" 'REQUESTED.*WAIT_REVIEW.*MUST NOT fallback' skills/dev-workflow/references/review-triage.md
has "bot findings and CI states cannot fallback" 'FINDINGS.*WAIT_CI.*FAIL_CI.*WAIT_READY.*不得 fallback' skills/dev-workflow/references/review-triage.md
has "bot fallback requires current-head CI" 'fallback.*current.*CI.*PASS' skills/dev-workflow/references/review-triage.md
has "push invalidates bot fallback" '每次 push.*fallback.*失效' skills/dev-workflow/references/review-triage.md
has "bot fallback rejects incomplete PR and thread probes" 'repo_probe_failed.*pr_probe_failed.*head.*thread probe' skills/dev-workflow/references/review-triage.md
has "bot fallback rejects incomplete reviewer probes" 'review_probe_failed.*requested_reviewer_probe_failed.*不得 fallback' skills/dev-workflow/references/review-triage.md
# 允許側同樣要釘：它被靜默收窄過一次（3f524fe 把類別判準換成單一 reason 名，使
# review_request_failed 失去出口），而當時沒有任何斷言會轉紅。三條各釘一件事，都寫成
# 無序的獨立 grep 而非有序 regex——同一支 branch 已經有前科：排除側那條因為禁令從名單
# 後方移到前方就斷了，而那是合法改寫。
has "bot fallback allow side stays categorical" '判準是類別（bot capability' skills/dev-workflow/references/review-triage.md
has "bot fallback allow side names both known shapes" 'review_actions_billing_or_quota' skills/dev-workflow/references/review-triage.md
has "bot fallback allow side gates request failures on exact status" '只有 404 與 422 成立' skills/dev-workflow/references/review-triage.md
# 消歧句（讀不到 vs 送不出去）同樣要釘：ablation 顯示整句刪掉時套件全綠，而它正是
# 「換一個 reason 名就再犯」那個結構缺陷的修正。
has "bot fallback disambiguates read vs send failures" '我們這一側讀不到' skills/dev-workflow/references/review-triage.md
has "bot fallback requires open ready mergeable PR" 'fallback 前.*open.*ready.*mergeable PR' skills/dev-workflow/references/review-triage.md
has "bot fallback cannot use author self-review" 'independent read-only reviewer.*不得由 PR 作者自審' skills/dev-workflow/references/review-triage.md
has "bot helper cannot manufacture fallback PASS" 'manual evidence branch.*pr-review-gate.*UNAVAILABLE.*不得.*PASS' skills/dev-workflow/references/review-triage.md
has "bot UNAVAILABLE remains visible under fallback" 'bot 狀態仍記 `UNAVAILABLE`.*不得偽裝成 PASS' skills/dev-workflow/references/review-triage.md

has "ledger records conditional RED or same-repro evidence" 'stable.*valuable.*RED.*否則.*repro.*before／after.*理由' skills/dev-workflow/references/ledgers.md
has "reviewer bug findings preserve conditional RED" 'stable.*valuable.*RED.*否則.*同一 repro.*before／after.*理由' skills/dev-workflow/references/reviewer-template.md
has "S5 bug findings preserve conditional RED" 'bug finding.*stable.*valuable.*RED.*否則.*repro.*before／after.*理由' skills/dev-workflow/SKILL.md
has "PR bug findings preserve conditional RED" 'finding 是 bug.*\[INT-2\].*RED.*同一 repro before／after' skills/dev-workflow/references/review-triage.md
lacks "no review path restores blanket RED" 'bug finding 先補 RED test|先寫紅測' skills/dev-workflow/SKILL.md skills/dev-workflow/references/review-triage.md
has "bot fixes use the applicable S4 tier" 'actionable.*自動修.*S4 risk tier.*exit code' skills/dev-workflow/references/review-triage.md

# B2 Closeout Ledger：六列有四列與 Preflight Ledger 逐欄重複，PR 路徑上讀者已在 PR body
# 看過。壓縮的是版面不是評估——這條斷言釘住「六項語意不得省略」，否則下一次會被讀成
# 「PR 路徑可以少評估四項」。
has "closeout ledger keeps all six rows semantically" '六項語意一律不得省略' skills/dev-workflow/references/ledgers.md
has "closeout ledger expands the two Preflight-absent rows" 'Relevant verification.*PR / CI / review status.*MUST 逐項展開' skills/dev-workflow/references/ledgers.md
has "closeout ledger cites a stable section not a placeholder" '見 PR body 的 Preflight Ledger' skills/dev-workflow/references/ledgers.md

# B2b 呈現壓縮的兩個界線（2026-08-04）。Opus 5 與 GPT-5.6 Sol 兩份官方指引同時命中 ledger：
# 前者說 delete your verification scaffolding，後者說刪 repeated process instructions that
# do not change behavior。壓的是版面不是評估，所以兩條斷言各釘一邊——「語意不得省略」擋
# 收斂被讀成減少評估，「MUST 合併為單行／一列」擋規則被讀回逐列各寫一行。
#
# Closeout 那條原本寫「四列…此處以『見 PR body』帶過即可」，語意含糊到可以讀成四列各寫
# 一行指向同一處——實測就是這樣被執行的，四行各說一次「見 PR body」，而那正是要壓掉的重複。
has "closeout collapses the four same-source rows into one line" '四列.*MUST 合併為單行' skills/dev-workflow/references/ledgers.md
has "preflight ledger keeps all eight rows semantically" '八項語意一律不得省略' skills/dev-workflow/references/ledgers.md
has "preflight collapses the two self-attested rows when clean" 'Diff self-review.*Self-simplification.*MUST 合併為一列' skills/dev-workflow/references/ledgers.md
has "preflight compression yields to any row with real content" '任一列非 PASS.*MUST 獨立展開' skills/dev-workflow/references/ledgers.md

# A2（2026-08-03）：shared-security-review Step 6 原本叫同一個 agent 在回報前 discard 自己的
# finding，與 [S5-4] 的 recall 論證相同——但 [S5-4] 的覆寫清單沒有列這個檔、觸發條件也是
# 「組裝 prompt」而非同 agent 自我過濾，所以管不到它。改寫成 Confidence + Disposition 標記後
# 若無守衛，下一次編輯會再退回 discard——這正是本批要修的根因，不能自己重蹈。
has "security review Step 6 records instead of discarding" 'record, do not delete' skills/shared-security-review/references/workflow.md
has "security review keeps a false-positive disposition" 'not-exploitable' skills/shared-security-review/references/workflow.md
has "security report card carries a Verdict slot" 'Verdict: exploitable / mitigated-upstream / not-exploitable' skills/shared-security-review/references/report-format.md
has "global workflow and security config are never trivial" 'global workflow.*security.*config.*不得.*trivial' skills/dev-workflow/SKILL.md
has "skill changes require invocation canaries" 'Skill change.*frontmatter.*relative references.*positive/negative.*trigger canary' skills/dev-workflow/SKILL.md
has "references declare load conditions" 'Load when' skills/dev-workflow/SKILL.md
lacks "kernel does not inline reviewer baselines" 'Reinvented Stdlib|Redundant Dependency|Unused Local Reuse|Needless Indirection|Wrong Altitude' skills/dev-workflow/SKILL.md
has "Copilot effort is adaptive" '模型預設 effort.*high.*xhigh.*量測' "$host_adapters_ref"
has "Copilot S5 delegates dirty reviews adaptively" 'working tree dirty 時，依 \[INT-4\] 由 AI 自主決定是否、何時及使用多少 read-only `task`' "$host_adapters_ref"
has "Copilot S5 handles clean reviews" 'clean.*fixed-point.*`code-review`' "$host_adapters_ref"
lacks "delegation has no fixed numeric or stage fan-out" '併發(數)?[[:space:]]*≤[[:space:]]*[0-9]+|累計 delegation[[:space:]]*≤[[:space:]]*[0-9]+|恰好[[:space:]]*[0-9]+[[:space:]]*個.*agent|每批[[:space:]]*[0-9]+[[:space:]]*個|直接開[[:space:]]*[0-9]+[[:space:]]*個|固定 fan-out' skills/dev-workflow/SKILL.md "$delegation_ref" "$host_adapters_ref"
has "host resolver derives the user-only count" 'expected_user_only_count=.*0' tests/host-skill-resolver.sh
lacks "host resolver has no hard-coded user-only count" '13/13|-eq 13' tests/host-skill-resolver.sh
has "host resolver compares complete skill directories" 'diff -qr.*skill_path.*AGENTS/skills' tests/host-skill-resolver.sh
has "Ponytail host parity has a portable selftest" '^case .*--selftest|--selftest.*selftest' tests/ponytail-host-parity.sh
has "Ponytail host parity checks full mode" 'ponytail-active.*full|mode.*full' tests/ponytail-host-parity.sh
has "Ponytail host parity checks enabled plugin state" 'enabledPlugins.*ponytail@ponytail' tests/ponytail-host-parity.sh
has "Ponytail host parity reads the canonical capability mapping" 'host-adapters\.md' tests/ponytail-host-parity.sh
has "Ponytail host parity selects the CAP-PONYTAIL row" 'CAP-PONYTAIL' tests/ponytail-host-parity.sh
has "Ponytail host parity calls the Codex runtime inventory" 'codex plugin list --json' tests/ponytail-host-parity.sh
has "Ponytail host parity resolves the Codex plugin id" 'pluginId == .ponytail@ponytail.' tests/ponytail-host-parity.sh
has "Ponytail host parity requires Codex installed and enabled" '\.installed == true and \.enabled == true' tests/ponytail-host-parity.sh
has "Ponytail host parity binds Codex cache to runtime version" 'cache/ponytail/ponytail/\$codex_runtime_version' tests/ponytail-host-parity.sh
has "Ponytail host parity rejects unpaired Codex config override" 'custom CODEX_CONFIG_ROOT requires CODEX_PLUGIN_LIST_JSON' tests/ponytail-host-parity.sh
lacks "Ponytail host parity cannot override the runtime-selected Codex root" 'CODEX_PONYTAIL_ROOT' tests/ponytail-host-parity.sh
has "Ponytail host parity splits multi-clause anchors" 'clause=\$\{rest%%\^\*\}' tests/ponytail-host-parity.sh
has "Ponytail host parity compares clauses literally" 'parts\[i\] == wanted' tests/ponytail-host-parity.sh
has "Ponytail host parity compares effective skill bytes" 'cmp -s.*claude.*codex|cmp -s.*CODEX.*COPILOT' tests/ponytail-host-parity.sh
has "CI exercises Ponytail host parity selftest" 'tests/ponytail-host-parity\.sh --selftest' .github/workflows/ci.yml
has "CI installs the ripgrep test dependency" \
  '^[[:space:]]*run:[[:space:]]*sudo apt-get update && sudo apt-get install -y ripgrep[[:space:]]*$' \
  .github/workflows/ci.yml
has "CI pins the gitleaks test dependency" \
  '^[[:space:]]+GITLEAKS_VERSION:[[:space:]]*8\.30\.1[[:space:]]*$' \
  .github/workflows/ci.yml
has "CI verifies the gitleaks archive" \
  '^[[:space:]]+GITLEAKS_SHA256:[[:space:]]*551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb[[:space:]]*$' \
  .github/workflows/ci.yml
has "CI downloads gitleaks from the official release" \
  '^[[:space:]]*curl -fsSLO "https://github\.com/gitleaks/gitleaks/releases/download/v\$\{GITLEAKS_VERSION\}/\$\{archive\}"[[:space:]]*$' \
  .github/workflows/ci.yml
has "CI checks the gitleaks archive before extraction" \
  '^[[:space:]]*echo "\$\{GITLEAKS_SHA256\}  \$\{archive\}" \| sha256sum -c -[[:space:]]*$' \
  .github/workflows/ci.yml
has "CI runs the Stage B2 skill checkpoint" 'bash tests/matt-thin-workflow.sh' .github/workflows/ci.yml
lacks "Stage B2 test has no local-only commit dependency" \
  'B2_SKILLS_BASE|7080450715c0e5f264e19ab60a48da9c4437c0af|/private/tmp/three-host-global-config-split-wrapper-parity\.tsv' \
  tests/matt-thin-workflow.sh
# 本檔沒有 set -e：mktemp 失敗時 fixture 路徑會落到 / 底下而斷言照跑。
resolver_fixture="$(mktemp -d "${TMPDIR:-/tmp}/host-resolver-fixture.XXXXXX")" ||
  { ng 'host resolver fixture: 無法建立暫存目錄，斷言未執行'; exit 1; }
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
has "same-conversation compact is not a Matt handoff" 'same-conversation `/compact`.*MUST NOT.*`handoff`' "$routing_continuations_ref"
has "Codex native handoff does not invoke Matt handoff" 'Local/Worktree Handoff.*MUST NOT.*Matt `\$handoff`' "$host_adapters_ref"
has "Matt command prefix defers to the host adapter" 'Matt skill body.*`/skill-name`.*實際.*host adapter' "$host_adapters_ref"
has "conflict analysis does not authorize mutation" '分析.*conflict.*不得.*resolve.*stage.*commit' skills/dev-workflow/SKILL.md
has "conflict resolution requires explicit user authorization" '明示.*解決 conflict.*`resolving-merge-conflicts`' skills/dev-workflow/SKILL.md
has "conflict staging stays within authorized resolved files" '`resolving-merge-conflicts`.*只 stage.*授權 scope.*MUST NOT `git add -A`' skills/dev-workflow/SKILL.md
has "unsafe conflict resolution may abort after confirmation" '必要意圖.*merge goal.*使用者確認.*abort.*上游' skills/dev-workflow/SKILL.md
lacks "no dangling T1-11" '\[T1-11\]' skills/dev-workflow/SKILL.md
lacks "kernel does not duplicate PR command" 'pr-review-gate' skills/dev-workflow/SKILL.md
has "review triage owns exact PR command" '~/\.agents/bin/pr-review-gate' skills/dev-workflow/references/review-triage.md

if command -v gitleaks >/dev/null 2>&1; then
  scan_fixture="$(mktemp -d "${TMPDIR:-/tmp}/matt-secret-fixture.XXXXXX")" ||
    { ng 'gitleaks fixture: 無法建立暫存目錄，斷言未執行'; exit 1; }
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
  sed -n '/^## Copilot$/,$p' "$ROOT/$host_adapters_ref" |
    rg -c '^- S5 '
)"
[ "$copilot_s5_count" = 1 ] &&
  ok "Copilot adapter has one canonical S5 directive" ||
  ng "Copilot adapter has one canonical S5 directive"
has "bugfix routes to diagnosing-bugs" 'diagnosing-bugs' skills/bug-fix-settlement/SKILL.md

for active in skills/dev-workflow/SKILL.md \
              "$delegation_ref" \
              "$host_adapters_ref" \
              "$routing_continuations_ref" \
              skills/dev-workflow/references/review-triage.md \
              skills/dev-workflow/references/dirty-review-package.md \
              skills/bug-fix-settlement/SKILL.md; do
  lacks "no active Superpowers workflow ref: $active" \
    'superpowers:|finishing-a-development-branch|systematic-debugging|receiving-code-review' "$active"
done

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]
