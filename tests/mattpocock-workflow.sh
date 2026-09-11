#!/usr/bin/env bash
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
pass=0
fail=0

ok() { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

# 掃描器不在就先出聲。沒有這條的話，rg 缺席時三百多條斷言各印一行歸因錯誤的 FAIL，
# 沒有任何一行說得出「ripgrep 不在」。形狀沿用同檔的 gitleaks preflight。
if command -v rg >/dev/null 2>&1; then
  ok "ripgrep scanner is available"
else
  ng "ripgrep scanner is available"
fi

# 掃描器 rc 三態的共用判別。正本在 tests/lib/scan.sh（issue #97 把它提出來，因為
# conformance.sh 需要同一份判別——複製第二份正是 PR #96 的 S5 Standards R2 點名要避免的）。
# 全檔唯一的**共用**掃描判別；另有三處自建 rc 判別，理由各自寫在原地：allow_names
# 那處 `rg -o`（提取不是判別）、`rg --hidden` 那處（要 --hidden 與 --glob）、
# delivery_contract_valid（POSIX ERE，見該處註解）。
# shellcheck source=tests/lib/scan.sh
. "$ROOT/tests/lib/scan.sh" ||
  { printf '  FAIL  掃描判別 lib 缺席（tests/lib/scan.sh）\n'; exit 1; }
# source 成功不代表函式在：空檔或被截斷的 lib 同樣 rc=0，而 `scan_hit: command not found`
# 的 rc=127 會讓 negative control 全部印綠（實測清空 lib -> 8 條 control 全 PASS）。
command -v rg_hits >/dev/null 2>&1 ||
  { printf '  FAIL  掃描判別 lib 未定義 rg_hits（tests/lib/scan.sh 可能被截斷）\n'; exit 1; }

# rc 語意：掃描可信時 return 0，不可信時 ng 並 return 1。注意這**不是**「不論 ok／ng
# 都 return 0」——lacks() 在斷言失敗（pattern 真的命中）時也 return 1，所以 rc 單獨
# 分不出「掃描壞了」與「斷言沒過」。要分辨的是印出來的判定，不是 rc。
has() {
  local label="$1" pattern="$2" file="$3" n
  n=$(rg_hits "$pattern" "$ROOT/$file") || { ng "$label"; return 1; }
  if [ "$n" -gt 0 ]; then ok "$label"; else ng "$label"; fi
}

# 檔案不存在不另外先驗（原 `[ -e ]`）：rg_hits 對它回 rc=2，與「掃描不可信」逐字同果。
lacks() {
  local label="$1" pattern="$2" path n
  shift 2
  [ "$#" -gt 0 ] || { ng "$label"; return 1; }
  for path in "$@"; do
    n=$(rg_hits "$pattern" "$ROOT/$path") || { ng "$label"; return 1; }
    [ "$n" -eq 0 ] || { ng "$label"; return 1; }
  done
  ok "$label"
}

# has()／lacks() 的姊妹，掃已由 sed／awk 抽出的區塊字串而不是檔案。沒有這兩支的話，
# 「取 block 再判」在檔內會是兩個函式化、六個 inline 展開的半吊子狀態：那六處是
# top-level 陳述式，沒有函式作用域，被迫共用同一個暫存變數名並靠執行順序而非作用域
# 隔離；排除側語意日後要調（例如把「掃描不可信」與「真的沒命中」分成兩種 FAIL 訊息）
# 得同步改六處，漏改一處沒有任何斷言會抓到。
block_has() {
  local label="$1" pattern="$2" block="$3" n
  n=$(printf '%s\n' "$block" | rg_hits "$pattern") || { ng "$label"; return 1; }
  if [ "$n" -gt 0 ]; then ok "$label"; else ng "$label"; fi
}

block_lacks() {
  local label="$1" pattern="$2" block="$3" n
  # 空 block 對排除側讀起來就是「乾淨」——而 sed／awk 的 range marker 被改名時抽出的
  # 正是空字串。四個呼叫端全在排除側，這一行一次關掉四處。區塊定界本身仍在 #93 的 E 類。
  [ -n "$block" ] || { ng "$label"; return 1; }
  n=$(printf '%s\n' "$block" | rg_hits "$pattern") || { ng "$label"; return 1; }
  if [ "$n" -eq 0 ]; then ok "$label"; else ng "$label"; fi
}

# 區塊先落地成變數再判，pipe 兩端的 rc 才不會被吃掉。本 issue 的範圍是掃描器 rc，
# 不含 sed／awk 的區塊定界 fail-open（標題被改寫時抽出空內容 → ng，方向對但歸因錯；
# 區塊「漲大」那個方向記在 #93 的 E 類）。
rule_has_in() {
  local label="$1" id="$2" pattern="$3" file="$4" block
  block=$(sed -n "/^\\- \\[$id\\]/p" "$ROOT/$file") || { ng "$label"; return 1; }
  block_has "$label" "$pattern" "$block"
}

rule_has() {
  rule_has_in "$1" "$2" "$3" skills/dev-workflow/SKILL.md
}

section_has() {
  local label="$1" section="$2" pattern="$3" file="$4" block
  block=$(awk -v heading="## $section" '
    $0 == heading { active=1; next }
    active && /^## / { exit }
    active { print }
  ' "$ROOT/$file") || { ng "$label"; return 1; }
  block_has "$label" "$pattern" "$block"
}

# 六支走 rg_hits 的 helper 共用同一份 fixture 骨架。分開手寫的話，日後要調整這個
# 形狀——例如新增第三種 rc case——得改六個地方，漏改一處沒有任何斷言會抓到。
# 每支兩條 negative control 加一條 clean positive control（evidence-integrity.md 要求
# 成對）。第二條（掃描器說成功卻交不出行）才是相對舊 `grep -qE … && ok || ng` 的增量：
# 第一條 rc=2 舊版也會 ng，只是把成因說成「沒命中」。
# 探測路徑一律用必定存在、必定命中的 target + pattern：shim 沒生效時 fixture 不會因為
# 別的理由變綠，理由完全不是以為的那個（7d824af 的教訓）。lacks 的方向相反，silent
# success 對它更兇（交不出行看起來就是「沒命中＝乾淨」），所以它的探測 pattern 用一個
# 保證不存在的 sentinel，而不是「現在剛好不存在」的普通字。
lacks_sentinel='THIS_STRING_MUST_NOT_EXIST_IN_THE_SKILL'
# assert_fails_closed 的正本在 tests/lib/scan.sh。第二個參數是 **shim 目標**
# （`rg`／`find`）：寫死 rg 的話，不是用 rg 的判別（例如 find_count）就補不了 control。
# 前一版在這裡留了一份舊簽名的本地定義，它會**覆蓋掉** source 進來的那支——
# 「搬進共用檔」只加了新的沒刪舊的，等於兩份判別並存。
for _shim_rc in 2 0; do
  assert_fails_closed has         rg "$_shim_rc" has         "fixture" 'rg_hits' tests/mattpocock-workflow.sh
  assert_fails_closed lacks       rg "$_shim_rc" lacks       "fixture" "$lacks_sentinel" skills/dev-workflow/SKILL.md
  assert_fails_closed block_has   rg "$_shim_rc" block_has   "fixture" 'probe' 'probe line'
  assert_fails_closed block_lacks rg "$_shim_rc" block_lacks "fixture" "$lacks_sentinel" 'probe line'
  # 直接呼叫 rule_has_in 而非 wrapper rule_has：後者寫死 file 參數，會漏掉「非預設
  # file」那條路徑。
  assert_fails_closed rule_has_in rg "$_shim_rc" rule_has_in "fixture" 'INT-4' 'delegation' skills/dev-workflow/SKILL.md
  assert_fails_closed section_has rg "$_shim_rc" section_has "fixture" 'S4 VERIFY' 'Risk' skills/dev-workflow/SKILL.md
done
has "has accepts its clean positive control" 'rg_hits' tests/mattpocock-workflow.sh
lacks "lacks accepts its clean positive control" "$lacks_sentinel" skills/dev-workflow/SKILL.md
block_has "block_has accepts its clean positive control" 'probe' 'probe line'
block_lacks "block_lacks accepts its clean positive control" "$lacks_sentinel" 'probe line'
rule_has_in "rule_has_in accepts its clean positive control" 'INT-4' 'delegation' skills/dev-workflow/SKILL.md
section_has "section_has accepts its clean positive control" 'S4 VERIFY' 'Risk' skills/dev-workflow/SKILL.md
# lacks 的另一半：pattern 真的存在時必須判 FAIL。shim fixture 只盯 rc 通道，clean
# positive 只盯「不存在時放行」——把迴圈裡的 `[ "$n" -eq 0 ] || …` 整行刪掉，33 個
# 呼叫端全綠而零訊號。這條是那個退化的唯一守衛。
case "$(lacks "fixture" 'rg_hits' tests/mattpocock-workflow.sh 2>&1)" in
  *"  FAIL  "*) ok "lacks rejects its known-bad control" ;;
  *)            ng "lacks rejects its known-bad control" ;;
esac

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
model_difference_not_trigger='Model difference 本身 MUST NOT 觸發 delegation'
same_work_recursion_forbidden='same-work recursion is forbidden'
routine_failures_with_owner='routine implementation／test failures.*current implementation owner.*diagnose.*fix.*retest.*owned scope'
split_reannounce_on_owner_change='實作者或委派範圍變更時 MUST 更新通報'

# 這支維持 grep -E（POSIX ERE）而非 rg_hits：它本來就有正確的 rc 三態（見下方 case），
# 換掉只會多一次方言轉換而不增加保護。全檔僅此一處與 rg 的 Rust regex 不同 dialect，
# 在兩區之間搬 pattern 時要留意 `\d`／`\s`／lazy quantifier 的語意差。
delivery_contract_valid() {
  local file="$1" int6 s2 s6 rc
  [ -r "$file" ] || return 2
  int6="$(grep -E '^\- \[INT-6\]' "$file")"; rc=$?
  # rc=0 卻交不出內容 = 掃描器自相矛盾，與 rg_hits 同一格。沒有這一格的話，grep 靜默
  # 成功時下方七條排除側 negative control 會在完全沒掃描的情況下變綠（rc=1 被呼叫端
  # 讀成「已正確拒絕」）。同檔對 evidence_integrity_contract_valid 立的規矩就是這條。
  case "$rc" in 0) [ -n "$int6" ] || return 2 ;; 1) return 1 ;; *) return 2 ;; esac
  s2="$(awk '/^## S2 AUTHORIZE$/{on=1;next} on && /^## /{exit} on{print}' "$file")" || return 2
  s6="$(awk '/^## S6 CLOSEOUT$/{on=1;next} on && /^## /{exit} on{print}' "$file")" || return 2
  [[ "$int6" =~ $delivery_int6_pattern ]] &&
    [[ "$s2" =~ $delivery_s2_pattern ]] &&
    [[ "$s6" =~ $delivery_s6_pattern ]]
}

# 呼叫端逐字區分 rc 0／1／>1（見下方三條 fixture），所以掃描不可信 MUST 以 2 傳出去，
# 不得塌成 1 —— 1 是「條文真的不在」。
evidence_integrity_contract_valid() {
  local file="$1" pattern n
  [ -r "$file" ] || return 2
  for pattern in \
    '^- 完成證據 MUST .*最後一次影響行為的 edit 之後.*final verification pass；後續 behavior-affecting edit 使舊結果失效。$' \
    '^- 新增或修改的 custom gate.* MUST fail closed：unreadable input、crash 或 unexpected exit 都不得被解讀為成功。$' \
    '^- 同一 gate MUST .*known-bad negative control.*失敗.*clean positive control.*通過；.*可重播.*deterministic。$'
  do
    n=$(rg_hits "$pattern" "$file") || return 2
    [ "$n" -gt 0 ] || return 1
  done
}

has "[INT-4] canonical delegation gate" '^\- \[INT-4\]' skills/dev-workflow/SKILL.md
# 這處數的是**出現次數**（同一行出現兩次 `[INT-4]` 要算兩次），而 rg_hits 用 `-c`
# 數的是命中**行數**，語意不同，換過去會改變斷言——與 allow_names 那處 `rg -o` 同類，
# 不套 rg_hits。門檻是正向的「≥5」，掃描器壞掉時空輸出讓 wc -l 得 0，天然 fail-closed
# （已實測 grep 的兩種故障下皆 FAIL）。
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
section_has "Codex handles unavailable tools" Codex '工具未提供時以文字列 session plan／進度' "$host_adapters_ref"
section_has "Codex fallback preserves approval" Codex '不得模擬工具呼叫或略過 protected gate 核准' "$host_adapters_ref"
section_has "Codex Plan Mode is host-controlled" Codex 'Plan Mode（僅 host／user 可切換）' "$host_adapters_ref"
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
has "substantial research reports route to research" 'substantial.*background research report.*`research`.*provider API/docs.*docs owner' skills/dev-workflow/SKILL.md
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
has "empty settlement reports one sentence" '皆不需要.*一句.*替代 guard' skills/bug-fix-settlement/SKILL.md
lacks "settlement does not impose a fixed report" '無條件輸出' skills/bug-fix-settlement/SKILL.md
has "implementation tests use the shared verification scope" 'dev-workflow.*S4.*evidence-integrity' skills/implement/SKILL.md
lacks "implementation does not mandate repeated or full-suite tests" 'Run typechecking regularly|full test suite once at the end' skills/implement/SKILL.md
has "diagnosis continues bounded read-only work without a repro" 'Continue read-only investigation.*unverified' skills/diagnosing-bugs/SKILL.md
has "diagnosis cannot claim an unverified cause or fix" 'Do not claim.*root cause.*fix.*confirmed' skills/diagnosing-bugs/SKILL.md
lacks "diagnosis does not forbid reading code to form hypotheses" 'Do \*\*not\*\* proceed to hypothesise without a loop|No red-capable command, no Phase 2' skills/diagnosing-bugs/SKILL.md
lacks "diagnosis does not invent a fixed hypothesis count" 'Generate \*\*3–5 ranked hypotheses\*\*' skills/diagnosing-bugs/SKILL.md
has "vendored continuation defers to the recorded override contract" 'step0-vendored-gate.md.*recorded override' "$routing_continuations_ref"
has "bug settlement memory requires explicit request" 'Memory.*只有使用者明示' skills/bug-fix-settlement/SKILL.md
has "bug settlement persistence is target-authorized" 'Cookbook.*Workflow.*exact target|exact target.*Cookbook.*Workflow' skills/bug-fix-settlement/SKILL.md
lacks "bug settlement no longer equates recommendation with authorization" '一旦標記 ✅，Step 2 就必須完成對應寫入' skills/bug-fix-settlement/SKILL.md
has "backend release rollout routes to shared authorization gate" '`dev-workflow`.*\[T0-8\].*S2' skills/backend-release-verification/SKILL.md
has "container rollout routes to shared authorization gate" '`dev-workflow`.*\[T0-8\].*S2' skills/containerization/SKILL.md
lacks "backend release has no dead CLAUDE.md plan pointer" 'CLAUDE\.md.*Plan first' skills/backend-release-verification/SKILL.md
lacks "containerization has no dead CLAUDE.md plan pointer" 'CLAUDE\.md.*Plan first' skills/containerization/SKILL.md
has "single-skill behavioral authoring routes to writing-for-agents" '既有 skill.*behavior.*trigger.*authoring.*`writing-for-agents`' skills/dev-workflow/SKILL.md
has "existing agent documents route to writing-for-agents" 'AGENTS\.md.*CLAUDE\.md.*agent doc.*`writing-for-agents`' skills/dev-workflow/SKILL.md
has "project-doc initialization stays with init-project-docs" '初始化或整體 refresh.*`init-project-docs`' skills/dev-workflow/SKILL.md
has "skill scaffolding stays with the host creator" '新 skill.*host creator' skills/dev-workflow/SKILL.md
has "skill-folder lifecycle audit routes to auditing-skill-folder" 'skill folder.*keep.*trim.*delete.*migrate.*`auditing-skill-folder`' skills/dev-workflow/SKILL.md
has "skill audit loads VND continuation" 'skill audit／VND.*continuations' skills/dev-workflow/SKILL.md
has "single-skill trigger failure requires caller-compatible RED" '單一 skill.*trigger failure.*MUST.*preserved RED.*caller.*`diagnosing-bugs`.*Step 2c RED.*`writing-for-agents`' skills/dev-workflow/SKILL.md
lacks "audit no longer requests explicit writing-skill invocation" 'explicitly invoke `writing-for-agents`|明示.*`writing-for-agents`' skills/auditing-skill-folder/SKILL.md
has "writing-for-agents covers host and pointed-at instructions" 'AGENTS\.md.*CLAUDE\.md.*agent-facing document' skills/writing-for-agents/SKILL.md
has "writing-for-agents requires canonical placement first" 'canonical owner is known' skills/writing-for-agents/SKILL.md
has "host policy writing returns to the shared authorization gate" 'Before writing a host policy file.*dev-workflow.*S2.*T0-8' skills/writing-for-agents/SKILL.md
# cd 進 $ROOT 再用相對路徑掃：`rg <absolute-path> --glob '!proposals/**'` 的 glob 只在 cwd
# 位於 $ROOT 之上時比得到，換個 cwd 執行同一支腳本，排除失效、proposals/ 的歷史命中會讓
# 這條誤 FAIL（2026-08-08 實測：worktree 內 281 PASS / 0 FAIL，git archive 到別處 280/1）。
# 方向是 fail-closed 不會放行，但「同一份 code 依執行目錄給不同結果」本身就不該留著。
# `|| exit 3` 而非 `&&`：cd 失敗時 subshell 回 1，與 rg 的「無命中」同碼，會在完全沒掃描
# 的情況下落進 ok 分支。回 3 讓下方的 `*) ng` 接住。
if (cd "$ROOT" || exit 3; rg --hidden -n 'writing-great-skills' . \
     --glob '!attic/**' --glob '!proposals/**' --glob '!tests/**' \
     --glob '!vendored-forks.md' --glob '!.git/**' \
     --glob '!docs/skill-overrides/2026-09-10-shared/**') >/dev/null 2>&1; then
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
has "setup no longer names retired qa" 'Skills like `to-tickets`, `triage`, and `to-spec`' skills/setup-matt-pocock-skills/references/setup-options.md
lacks "setup has no retired qa dependency" '`qa`' skills/setup-matt-pocock-skills/SKILL.md
lacks "code-review uses spec terminology" 'PRD' skills/code-review/SKILL.md
lacks "to-spec uses spec terminology" 'PRD' skills/to-spec/SKILL.md
has "tdd points architecture vocabulary to codebase-design" 'shape of that interface.*`?/codebase-design`?.*vocabulary' skills/tdd/SKILL.md
has "logic prototype is a self-contained HTML file" 'single, self-contained HTML file' skills/prototype/LOGIC.md
has "logic prototype stays offline" 'no CDN.*network.*secret|offline.*CDN.*secret' skills/prototype/LOGIC.md
has "logic prototype uses synthetic non-sensitive fixtures" 'Fixture state uses synthetic, non-sensitive data' skills/prototype/LOGIC.md
has "logic prototype translates validated shape for non-JavaScript hosts" 'another language.*validated states.*transitions.*invariants.*native implementation' skills/prototype/LOGIC.md
has "prototype delivery returns to the shared authorization gate" 'delivery outside the local session.*dev-workflow.*authorization gate' skills/prototype/LOGIC.md
has "triage delegates cadence to grilling" 'canonical `/grilling` contract own question cadence' skills/triage/references/issue-triage.md
lacks "triage does not duplicate grilling cadence" 'one question at a time|round of questions at a time' skills/triage/SKILL.md
lacks "wayfinder does not duplicate grilling cadence" 'one question at a time|round of questions at a time' skills/wayfinder/SKILL.md
lacks "grill-with-docs does not duplicate grilling cadence" 'one question at a time|round of questions at a time' skills/grill-with-docs/SKILL.md
lacks "ask-matt does not own a second phase-boundary file" 'PHASE-BOUNDARIES\.md' skills/ask-matt/SKILL.md
has "routing continuation owns phase-boundary choice" '[Pp]hase boundary.*Continue.*clear.*handoff.*subagent.*compact' skills/dev-workflow/references/routing-continuations.md
has "routing continuation avoids a hard token threshold" 'grilling.*to-spec.*to-tickets.*同一 context.*不設固定 token threshold' skills/dev-workflow/references/routing-continuations.md
has "mid-phase compaction routes through handoff" 'compact.*只在 phase boundary.*mid-phase.*handoff' skills/dev-workflow/references/routing-continuations.md
# 原本是 `[ "$(grep -c …)" -eq 22 ]`：掃描器壞掉時靠空字串進 `[` 觸發
# `integer expression expected` 才 fail-closed——本檔 allow_names 的沿革註解逐字說過
# `980d2c2` 那版 `grep -c` 沒做三態就是這個毛病。既然 rg_hits 已在，收掉。
if skill_count=$(rg_hits '^skill=' "$ROOT/mattpocock-skills.lock") && [ "$skill_count" -eq 22 ]; then
  ok "Matt selected set contains 22 skills"
else
  ng "Matt selected set contains 22 skills"
fi
lacks "unselected Matt additions remain excluded" '^skill=(wizard|wait-what|to-questionnaire)$' mattpocock-skills.lock
# explicit route: grill-with-docs 由第 67 行的「明示.*`grill-with-docs`」涵蓋（措辭更精確），
# 不再重複斷言 —— S0 表用反引號而非斜線前綴，原本的 '/grill-with-docs' 在此不成立。
has "explicit route: improve-codebase-architecture" 'improve-codebase-architecture.*explicit-only' skills/dev-workflow/SKILL.md
lacks "active routing no longer names mp replacements" 'mp-(grill-with-docs|improve-codebase-architecture|diagnose|tdd)' skills/dev-workflow/SKILL.md

has "external issue or PR routes to triage" '外部.*issue.*PR.*`triage`' skills/dev-workflow/SKILL.md
has "grill-with-docs stays explicit" '明示.*`grill-with-docs`' skills/dev-workflow/SKILL.md
has "S2 routes mutations through the authorization matrix" 'Matrix.*mutation.*side effect.*mechanical trigger.*risk floor' skills/dev-workflow/SKILL.md
section_has "S2 requires an explicit authorized delivery scope" "S2 AUTHORIZE" "$delivery_s2_pattern" skills/dev-workflow/SKILL.md
has "read-only requests stay outside implementation" 'Read-only.*不得擴成 implementation' "$authorization_matrix_ref"
has "clear change build fix directly authorizes local implementation" '明確.*change／build／fix.*in-scope local implementation.*non-destructive verification' "$authorization_matrix_ref"
lacks "clear work does not wait for implement invocation" '需求已清楚.*推薦.*`implement`|單一 session.*等待.*`implement`' skills/dev-workflow/SKILL.md "$routing_continuations_ref"
rule_has "Medium risk alone does not reopen authorization" INT-3 'Medium-risk.*MUST NOT.*第二次確認|MUST NOT.*Medium-risk.*第二次確認'
has "mechanical triggers set a non-overridable risk floor" 'mechanical trigger.*risk floor.*不得.*(自評|label).*降級' "$authorization_matrix_ref"
has "multiple triggers take the highest risk floor" '多個 trigger.*最高 risk floor' "$authorization_matrix_ref"
has "S2 keeps local reversible Medium autonomous" 'Medium-risk.*session plan.*不需第二次確認|Medium.*本身不是第二次授權 gate' "$authorization_matrix_ref"
has "S2 stops before High or protected boundaries" 'High.*protected boundary.*material scope expansion.*停|High.*material scope expansion.*protected boundary.*停' "$authorization_matrix_ref"
has "S2 reuses exact approval without reopening the same gate" 'exact action／scope.*既有.*核准.*不.*重問' "$authorization_matrix_ref"
rule_has "in-scope necessary findings are completed" INT-8 'scope 內必要修正.*直接完成'
rule_has "only expanded findings wait for authorization" INT-8 '超出.*scope.*follow-up.*未核准不得做'
rule_has "skill-caused stops carry provenance" INT-8 '因 skill.*MUST 附已讀 SKILL\.md 連結.*原句.*適用理由.*明文／推論'
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
has "delegation keeps independently parallel scope as the default" 'Host adapter 明定的 eligibility 例外以外，任何 delegation 機制只在工作可獨立平行.*使用' "$delegation_ref"
has "delegation scopes context isolation to Codex" 'Codex conditional implementation routing.*bounded scope.*large/noisy context.*isolation' "$delegation_ref"
has "delegation scopes packet routing to Claude" 'Claude conditional implementation routing.*已完整規範.*機械判定.*packet.*implementer' "$delegation_ref"
has "delegation keeps Codex context isolation out of other hosts" 'Codex context-isolation 例外不適用其他 host' "$delegation_ref"
lacks "delegation removes retired Codex forced serial routing" 'Astra→Sol serial implementation routing' "$delegation_ref" "$host_adapters_ref"
lacks "delegation removes retired Claude forced serial routing" 'Fable→Opus serial implementation routing' "$delegation_ref" "$host_adapters_ref"
has "delegation forbids same-work recursion" "$same_work_recursion_forbidden" "$delegation_ref"
has "delegation keeps its unconditional constraints" '無條件約束（不因任何授權而放寬）.*序列相依.*寫入 ownership MUST 不重疊.*MUST 重驗其回報' "$delegation_ref"
has "unconditional constraints are not purchasable with authorization" '無條件約束不在可授權範圍內.*即使取得授權也 MUST NOT 執行' "$delegation_ref"
has "AI decides delegation timing and count" '是否委派、何時委派、subagent 數量與是否平行 MUST 由 AI 自主判定' "$delegation_ref"
has "delegation has no default fixed limits beyond explicit user limits" '除使用者明示的本次 scope、數量或成本限制外，不預設固定數量、併發、累計或 S 階段 quota' "$delegation_ref"
has "runtime capacity remains a technical bound" 'host/runtime 可用容量仍是技術上限' "$delegation_ref"
has "S5 review agents stay read-only while AI chooses usage" 'S5 Standards／Spec outcomes.*如使用 review agents，MUST 為 read-only，數量與批次由 AI 決定' "$delegation_ref"
has "downstream fixed choreography is advisory" '下游 skill 的固定 spawn 時機／數量一律由本條覆寫為 advisory choreography.*coverage、outcome 與 independence requirements 保留' "$delegation_ref"
has "delegation messages carry the complete task contract" '委派訊息 MUST 交代目標與用途.*working directory／可修改範圍.*已決事項與限制.*必要文件.*驗收方式.*必要背景 MUST 先摘要進訊息，不靠子代理自行推斷（子代理預設不繼承父對話）' "$delegation_ref"
rule_has "delegation cannot bypass authorization gates" INT-4 'MUST NOT 用 delegation 迴避 S2 授權或 \[T0-8\] plan gate'
rule_has "stable valuable seam requires RED" INT-2 'stable.*valuable.*seam.*failing regression test.*RED'
rule_has "unstable seam keeps same repro before after" INT-2 '否則.*同一.*repro.*before／after.*理由'
rule_has "INT-2 keeps the five-element rule contract" INT-2 '觸發：.*例外：.*驗證：'
lacks "bugfix no longer has unconditional RED" 'MUST 在 fix 前先有 failing regression test.*例外：無' skills/dev-workflow/SKILL.md
rule_has "kernel overrides upstream tdd seam and refactor rules" INT-9 'stable.*valuable.*\[tdd\]\(\.\./tdd/SKILL\.md\).*既有 public behavior seam.*新 seam.*micro-refactor.*重跑.*覆寫'
# Static instruction contracts only; Sol/Astra behavior is measured separately.
lacks "small tasks no longer route to retired sdd" '^\|.*`sdd`' skills/dev-workflow/SKILL.md
has "small tasks keep session acceptance criteria" '單檔.*≤3.*session.*情境式驗收條件' skills/dev-workflow/SKILL.md
lacks "tdd does not reconfirm every existing seam" 'Before writing any test.*confirm them with the user|Ask: "What.s the public interface' skills/tdd/SKILL.md
has "tdd delegates seam and refactor gates to workflow" 'dev-workflow.*INT-2.*INT-9' skills/tdd/SKILL.md
lacks "tdd does not ban all green refactoring" 'Refactoring is not part of the loop' skills/tdd/SKILL.md
lacks "four callers do not create an approval gate" '4\+.*取得使用者確認' skills/deps-check/SKILL.md
has "deps-check uses canonical scope authorization" 'dev-workflow.*S2' skills/deps-check/SKILL.md
has "deps-check preserves unknown dependency evidence" 'UNKNOWN 不得解讀為零依賴' skills/deps-check/SKILL.md
[ ! -e "$ROOT/skills/sdd" ] && [ -f "$ROOT/attic/sdd/SKILL.md" ] \
  && ok "sdd is reversibly archived outside skill discovery" \
  || ng "sdd is reversibly archived outside skill discovery"
has "optional SDD archive requires all tasks complete" '每項.*- \[x\].*未完成' skills/dev-workflow/references/sdd-artifacts.md
has "optional SDD archive does not invent missing artifacts" '沒有持久化產物.*SKIPPED.*不補造' skills/dev-workflow/references/sdd-artifacts.md
lacks "trigger corpus has no retired sdd target" '"skill"[[:space:]]*:[[:space:]]*"sdd"' skills/auditing-skill-folder/evals/cases.jsonl
rule_has "S5 medium and PR reviews run both axes" S5-1 '中高風險.*PR.*Standards.*Spec'
rule_has "S5 low-risk non-PR reviews may be skipped" S5-1 '低風險.*不進 PR.*SKIPPED'
has "code-review loads canonical reviewer contract" 'Read the entire.*canonical reviewer-template.*reviewer-template.md' skills/code-review/references/review-dispatch.md
has "code-review Standards receives the full canonical prompt" 'Standards.*complete canonical marked reviewer prompt block.*performance/correctness' skills/code-review/references/review-dispatch.md
has "code-review both axes receive the common finding contract" 'Both axes.*actionable/no-word-or-count-cap/caller-side-triage' skills/code-review/references/review-dispatch.md
has "reviewer template owns actionable severity and confidence" 'evidence-first actionable review.*確信度' skills/dev-workflow/references/reviewer-template.md
has "reviewer template keeps axes separate" '單一 review 軸內.*跨軸不合併、不重排' skills/dev-workflow/references/reviewer-template.md
has "reviewer template rejects output caps and style-only noise" '不設字數或條數上限.*不為湊數加入純 style preference' skills/dev-workflow/references/reviewer-template.md
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
# 2026-08-08：baseline 擴為五條，新三條同樣需要守衛。
has "reviewer template carries the Unused Local Reuse baseline" 'Unused Local Reuse.*→ 指名既有符號並改呼叫它。' skills/dev-workflow/references/reviewer-template.md
# Canonical Needless Indirection includes forwarding layers and speculative hooks;
# preserve those clauses, not only the shared inline action sentence.
has "reviewer template carries the Needless Indirection baseline" 'Needless Indirection.*只做轉發的中間層.*為 spec 沒有的需求.*→ 內聯回去' skills/dev-workflow/references/reviewer-template.md
has "reviewer template carries the Wrong Altitude baseline" 'Wrong Altitude.*→ 把該決策移回它該在的層。' skills/dev-workflow/references/reviewer-template.md
# code-review dispatches the full canonical prompt; no duplicated five-item/performance/correctness prose.
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
section_has "Codex keeps Astra as coordinator" Codex 'gpt-6-astra.*`~/\.codex/config\.toml`.*`model_reasoning_effort`.*Plan Mode.*`plan_mode_reasoning_effort`' "$host_adapters_ref"
section_has "Codex keeps decisions and final evidence with Astra" Codex 'Astra owns investigation.*architecture.*decisions.*final evidence.*independent read-only S5 review.*final user response' "$host_adapters_ref"
section_has "Codex permits Astra to implement authorized scope end to end" Codex 'Astra MAY implement 已授權 scope end-to-end' "$host_adapters_ref"
section_has "Codex autonomously selects direct work or implementer delegation" Codex 'Astra MUST 自主判定 direct work 或 implementer delegation.*不需為 model routing 另問使用者' "$host_adapters_ref"
section_has "Codex defaults small or tightly dependent work to Astra unless delegation helps" Codex 'small 或 tightly dependent task.*Astra SHOULD 直接完成.*除非下列 delegation benefit 成立' "$host_adapters_ref"
section_has "Codex delegates materially beneficial parallel work" Codex '工作可獨立平行.*實質改善品質或 wall-clock time.*SHOULD delegate' "$host_adapters_ref"
section_has "Codex permits bounded context isolation" Codex 'bounded scope.*large/noisy context.*isolation.*MAY delegate' "$host_adapters_ref"
section_has "Codex does not delegate solely for a model difference" Codex "$model_difference_not_trigger" "$host_adapters_ref"
section_has "Codex retains the Sol implementer as an optional implementation role" Codex '需要 delegation 時.*configured `implementer`.*gpt-5\.6-sol.*定義在 `~/\.codex/agents/implementer\.toml`' "$host_adapters_ref"
section_has "Codex forbids implementer recursion" Codex "$same_work_recursion_forbidden" "$host_adapters_ref"
section_has "Codex announces the implementation split before starting" Codex '實作分工通報.*Astra MUST 在開始.*已授權實作前.*告知實作者.*Sol implementer.*負責範圍與選擇原因' "$host_adapters_ref"
section_has "Codex re-announces when the implementation owner changes" Codex "$split_reannounce_on_owner_change" "$host_adapters_ref"
section_has "Codex constrains unavailable-implementer takeover" Codex 'implementer unavailable.*Astra MAY 接手.*既有授權.*runtime permission.*tool capability.*MUST NOT bypass denied tools.*sandbox.*\[T0-8\].*independent read-only S5 review' "$host_adapters_ref"
section_has "Codex requires Astra to reverify implementer evidence" Codex 'implementer report is not completion evidence.*Astra MUST reverify' "$host_adapters_ref"
section_has "Codex keeps routine failures with the implementation owner" Codex "$routine_failures_with_owner" "$host_adapters_ref"
section_has "Codex returns delegated invalid design premises to Astra" Codex 'delegated implementer.*invalid design premise.*stop dependent writes.*return evidence to Astra.*decision.*authorization' "$host_adapters_ref"
section_has "Codex defaults new subagents to no inherited turns" Codex '建立新子代理時.*MUST 預設.*`fork_turns="none"`' "$host_adapters_ref"
section_has "Codex delegation messages defer to the shared contract" Codex '委派訊息內容與背景摘要依.*delegation\.md' "$host_adapters_ref"
section_has "Codex escalates inherited context only when summaries are insufficient" Codex '摘要不足時才繼承必要的近期 turns.*完整父對話不可省略.*`fork_turns="all"`' "$host_adapters_ref"
section_has "Codex reuses the original agent for same-task follow-up" Codex '同一任務的修正與重測 MUST 優先.*follow-up.*原代理.*只有原代理不可用.*新的獨立任務.*建立新代理' "$host_adapters_ref"
section_has "Codex maps simplification edits to the active implementation owner" Codex '^\- S5 simplification mechanism = Astra decides disposition; active implementation owner applies authorized edits, then S4/S5 reverify。$' "$host_adapters_ref"
section_has "Claude maps uiux-reviewer as the visual review agent" Claude '前端視覺 review agent = `uiux-reviewer`（Claude-only）' "$host_adapters_ref"
section_has "Claude derives the coordinator role from configured settings" Claude 'Claude main role = `~/\.claude/settings\.json` 的 configured `model` 與 `effortLevel`.*plan mode' "$host_adapters_ref"
section_has "Claude keeps decisions and final evidence with the main agent" Claude 'Claude main owns investigation.*architecture.*decisions.*final evidence.*independent read-only S5 review.*final user response' "$host_adapters_ref"
section_has "Claude permits the main agent to implement authorized scope end to end" Claude 'Claude main MAY implement 已授權 scope end-to-end' "$host_adapters_ref"
section_has "Claude autonomously selects direct work or implementer delegation" Claude 'Claude main MUST 自主判定 direct work 或 implementer delegation.*不需為 model routing 另問使用者' "$host_adapters_ref"
section_has "Claude defaults small or tightly dependent work to the main agent unless delegation helps" Claude 'small 或 tightly dependent task.*Claude main SHOULD 直接完成.*除非下列 delegation benefit 成立' "$host_adapters_ref"
section_has "Claude may delegate fully specified mechanically verifiable packets" Claude 'packet 已完整規範.*委派訊息已滿足 delegation\.md 的訊息契約.*驗收可機械判定.*不需回頭問設計.*MAY delegate' "$host_adapters_ref"
section_has "Claude does not delegate solely for a model difference" Claude "$model_difference_not_trigger" "$host_adapters_ref"
section_has "Claude retains the Opus implementer as an optional implementation role" Claude '需要 delegation 時交給 configured `implementer` agent.*claude-opus-5.*定義在 `~/\.claude/agents/implementer\.md`' "$host_adapters_ref"
section_has "Claude forbids implementer recursion" Claude "$same_work_recursion_forbidden" "$host_adapters_ref"
section_has "Claude constrains unavailable-implementer takeover" Claude 'implementer unavailable.*Claude main MAY 接手.*既有授權.*runtime permission.*tool capability.*MUST NOT bypass denied tools.*sandbox.*\[T0-8\].*independent read-only S5 review' "$host_adapters_ref"
section_has "Claude requires the main agent to reverify implementer evidence" Claude 'implementer report is not completion evidence.*Claude main MUST reverify' "$host_adapters_ref"
section_has "Claude keeps routine failures with the implementation owner" Claude "$routine_failures_with_owner" "$host_adapters_ref"
section_has "Claude returns delegated invalid design premises to the main agent" Claude 'delegated implementer.*invalid design premise.*stop dependent writes.*return evidence to Claude main.*decision.*authorization' "$host_adapters_ref"
section_has "Claude reuses the original implementer for same-scope follow-up" Claude 'host 有 `SendMessage` 時 MUST 優先.*續用原 implementer.*只有.*原代理不可用.*host 無 `SendMessage`.*新的獨立任務這三種情形之一.*建立新代理' "$host_adapters_ref"
section_has "Claude requires a re-sent packet to carry the previous round" Claude '為同一 scope 建立新代理時.*delegation\.md.*MUST 標註前一輪的 changed files 與失敗項.*MUST NOT 逐字重貼' "$host_adapters_ref"
section_has "Claude defaults new subagents to no inherited parent context" Claude 'MUST 預設不繼承父對話（不用 `subagent_type: "fork"`）' "$host_adapters_ref"
section_has "Claude forbids fork as a substitute for implementer delegation" Claude 'MUST NOT 用 fork 取代委派給 configured `implementer`' "$host_adapters_ref"
section_has "Claude confines fork to indispensable full parent context" Claude '只有完整父對話不可省略時才用 fork' "$host_adapters_ref"
section_has "Claude announces the implementation split before starting" Claude '實作分工通報.*MUST 在開始.*已授權實作前.*告知實作者.*configured `implementer`.*負責範圍與選擇原因' "$host_adapters_ref"
section_has "Claude re-announces when the implementation owner changes" Claude "$split_reannounce_on_owner_change" "$host_adapters_ref"
section_has "Claude maps simplification edits to the active implementation owner" Claude '^\- S5 simplification mechanism = Claude main decides disposition; active implementation owner applies authorized edits, then S4/S5 reverify。$' "$host_adapters_ref"
section_has "Copilot maps the simplification outcome to an explicit apply pass" Copilot '^\- S5 simplification mechanism = main-context explicit apply pass。$' "$host_adapters_ref"
common_simplification="$(sed -n '/^## S5 simplification apply outcome$/,/^## Claude$/p' "$ROOT/$host_adapters_ref" | sed '$d')"
block_lacks "shared simplification method stays host-neutral" 'Claude|Codex|Copilot' "$common_simplification"
# 以下這批守衛的 pattern 一律釘「會翻轉的子句」，不釘引入語。教訓是同一個撰寫方法會換
# 外觀復發：未錨行首行尾 → 只釘句首 → 釘住錯誤引用 → 極性反轉。判準是「把這句改成相反
# 意思，pattern 還能不能命中」；每一條都做過這個反轉測試才留下。
#
# 實測：下面三條同時還原成前一版寫法，整套仍全綠——而 reviewer-template 第 7 行一
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
preflight_section="$(sed -n '/^## 1\. Preflight Ledger/,/^## 2\. User-facing closeout/p' "$ROOT/$ledgers_ref")"
for _axis in Standards Spec; do
  block_has "Preflight example carries the ${_axis} axis line" \
    "^S5 ${_axis}: (PASS|FAIL|SKIPPED|UNAVAILABLE)" "$preflight_section"
done
has "Preflight row 6 requires the review range" '^\| 6 \|.*審查對象 range' "$ledgers_ref"
has "Preflight row 6 requires quoting two baseline titles" \
  '^\| 6 \|.*baseline 五條中至少兩條的標題' "$ledgers_ref"
# Closeout 引用完整 evidence 的 canonical artifact，而不是複製 reviewer metadata。
has "Closeout keeps detailed evidence in its canonical artifact" \
  '完整 audit evidence 留在 Preflight ledger、session artifact 或 PR checks' "$ledgers_ref"
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
if [ -n "$prompt_block" ]; then
  prompt_lines="$(printf '%s\n' "$prompt_block" | wc -l | tr -d ' ')"
  # wc 靜默失敗（exit 0 無輸出）時 prompt_lines 是空字串，`[ "" -le 2 ]` 報錯回 rc=2，
  # if 判偽 → 整段檢查被跳過、兩條斷言都變綠。-1 讓它落進「區塊太短」那格。
  case "$prompt_lines" in ''|*[!0-9]*) prompt_lines=-1 ;; esac
fi
if [ "$prompt_lines" -le 2 ]; then
  ng "reviewer prompt block is non-empty"
  # range 空或只剩 marker 時 design-notes 這條無從判定。明確標 FAIL 而非略過——略過會讓
  # 總條數隨檔案狀態浮動，看起來像「少跑了一條」而不是「守衛失去依據」。
  ng "baseline design notes live outside the reviewer prompt"
elif ! _notes_hits=$(printf '%s\n' "$prompt_block" | rg_hits '設計註記'); then
  # 掃描不可信：兩條都無從判定，一律 ng（沿用上一分支的理由）。
  ng "reviewer prompt block is non-empty"
  ng "baseline design notes live outside the reviewer prompt"
elif [ "$_notes_hits" -gt 0 ]; then
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
# 只驗 policy clauses；不宣稱模型 runtime 行為。若 clause 被刪，缺檢查會朝假綠偏。
section_has "S4 keeps full CI and scopes integration E2E security" 'S4 VERIFY' 'High=full CI-equivalent\+適用 integration/E2E/security' skills/dev-workflow/SKILL.md
section_has "verification scope preserves medium high before after evidence" 'Verification scope' 'Medium／High.*before／after' "$evidence_integrity_ref"
section_has "verification scope preserves repository required checks" 'Verification scope' 'repo 明定 required checks 不得略過' "$evidence_integrity_ref"
section_has "inapplicable checks require a reasoned skip" 'Verification scope' '不適用.*SKIPPED.*理由' "$evidence_integrity_ref"
section_has "blocked applicable checks are unavailable not inapplicable" 'Verification scope' '工具／環境.*適用檢查.*UNAVAILABLE.*probe.*不得.*不適用' "$evidence_integrity_ref"
section_has "verification repeats only for a new reason or required gate" 'Verification scope' '僅新變更、失敗、未解疑慮或明定 gate 要求才擴大／重跑' "$evidence_integrity_ref"
has "medium high and PR evidence binds source and replay" 'Medium／High 或 PR.*source state.*replay command' "$evidence_integrity_ref"
has "dirty and clean source states are exact" 'clean tree.*current HEAD.*dirty tree.*immutable HEAD.*dirty review package.*hash' "$evidence_integrity_ref"
has "formal acceptance mapping covers negative invariants" '正式 spec artifact.*明列 acceptance criteria.*behavior change.*acceptance criterion.*negative invariant.*test／probe／gate' "$evidence_integrity_ref"
has "high risk failure models map to catching layers" 'High-risk.*failure model.*catching layer' "$evidence_integrity_ref"
has "ledger records fresh source-bound replay evidence" 'Tests evidence.*final verification pass.*source state.*replay command' "$ledgers_ref"
has "Preflight verification records high-risk failure coverage" 'Tests evidence.*High-risk.*failure model.*catching layer' "$ledgers_ref"
has "Closeout verification records high-risk failure coverage" 'Relevant verification.*High-risk.*failure model.*catching layer' "$ledgers_ref"
residual_failure_pattern='^\| (8 \| )?\*\*Residual risks\*\*.*failure model'
lacks "Residual risks does not own failure coverage" "$residual_failure_pattern" "$ledgers_ref"
block_has "Residual risks guard catches its Preflight negative control" \
  "$residual_failure_pattern" '| 8 | **Residual risks** | bad failure model owner |'

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
# 掃描器故障那條路徑（rg_hits -> return 2）本來沒有任何控制項。該函式的註解逐字承諾
# 「掃描不可信 MUST 以 2 傳出去，不得塌成 1」——把 `|| return 2` 改成 `|| return 1`，
# known-bad 那條會從 `*) ng` 轉成 `1) ok`，掃描器故障被讀成「條文真的不在＝守衛正常」。
# 這兩條是那個承諾的唯一守衛。
for _shim_rc in 2 0; do
  case "$_shim_rc" in
    2) _eic_why='the scanner errors' ;;
    *) _eic_why='the scanner exits 0 with no output' ;;
  esac
  _eic_rc=0
  (rg() { return "$_shim_rc"; }; evidence_integrity_contract_valid "$evidence_fixture/good.md") || _eic_rc=$?
  if [ "$_eic_rc" -gt 1 ]; then
    ok "evidence integrity reports a validator error when $_eic_why"
  else
    ng "evidence integrity reports a validator error when $_eic_why"
  fi
done
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
block_lacks "quota section forbids hosted CI affirmative PASS" '^\s*- Hosted CI (是|視為|改寫成|標記為) `?PASS' "$quota_section"
block_lacks "quota reminder cannot become a stop gate" '提醒(後)?(就是|是|成為)停止點|提醒後.*(停止|等待)|等待使用者確認' "$quota_section"
block_lacks "quota section forbids billing review affirmative CURRENT" '^\s*- Billing failure.*(是|視為|標為|當成) `?CURRENT' "$quota_section"

has "bot fallback is independent and read-only" 'independent read-only reviewer.*current `head\.sha`' skills/dev-workflow/references/review-triage.md
has "bot transient states cannot fallback" 'REQUESTED.*WAIT_REVIEW.*MUST NOT fallback' skills/dev-workflow/references/review-triage.md
has "bot findings and CI states cannot fallback" 'FINDINGS.*WAIT_CI.*FAIL_CI.*WAIT_READY.*不得 fallback' skills/dev-workflow/references/review-triage.md
has "bot fallback requires current-head CI" 'fallback.*current.*CI.*PASS' skills/dev-workflow/references/review-triage.md
has "push invalidates bot fallback" '每次 push.*fallback.*失效' skills/dev-workflow/references/review-triage.md
has "bot fallback rejects incomplete PR and thread probes" 'repo_probe_failed.*pr_probe_failed.*head.*thread probe' skills/dev-workflow/references/review-triage.md
has "bot fallback rejects incomplete reviewer probes" 'review_probe_failed.*requested_reviewer_probe_failed.*不得 fallback' skills/dev-workflow/references/review-triage.md
has "bot fallback requires open ready mergeable PR" 'fallback 前.*open.*ready.*mergeable PR' skills/dev-workflow/references/review-triage.md
has "bot fallback cannot use author self-review" 'independent read-only reviewer.*不得由 PR 作者自審' skills/dev-workflow/references/review-triage.md
has "bot helper cannot manufacture fallback PASS" 'manual evidence branch.*pr-review-gate.*UNAVAILABLE.*不得.*PASS' skills/dev-workflow/references/review-triage.md
has "bot UNAVAILABLE remains visible under fallback" 'bot 狀態仍記 `UNAVAILABLE`.*不得偽裝成 PASS' skills/dev-workflow/references/review-triage.md

# fallback 允許側的極性。這三條的覆蓋面是**窄的**：實測擋不住的寫法逐條記在 issue #93，
# 這裡不複述那份清單——PR #92 的 R2 有六條 findings 就是在挑這段摘要的錯（高估、低估、
# 分類錯各有）。摘要靠人維護，#93 的每一條都有實測記錄。
review_triage_ref=skills/dev-workflow/references/review-triage.md
allow_rc=0
allow_line=$(rg -e '^[[:space:]]*- \*\*允許 fallback 的 reason 窮舉為一個\*\*' "$ROOT/$review_triage_ref") || allow_rc=$?
# 實際判準是「反引號內整段為 [a-z][a-z_]*」，不是「有沒有用反引號」——`*_foo`、`FOO`、
# `foo2`、`foo-bar` 都用 ASCII 反引號而都不算數（#93 D 類）。
names_rc=0
allow_names=$(printf '%s' "$allow_line" | rg -o -r '$1' -e '`([a-z][a-z_]*)`' | sort -u) || names_rc=$?
# 行數用 shell 參數展開判，不外呼 grep -c：少一個外部工具就少一種「工具缺席」失效面。
# `980d2c2` 那一版用 `grep -c` 且沒做三態，grep 缺席時空字串進 [ -ne ] 會報 integer expression
# expected 並回 2，elif 鏈跳過這一格、真違規被判 PASS（PR #92 Standards S7 實測）。
if [ "$allow_rc" -ge 2 ] || [ "$names_rc" -ge 2 ]; then
  ng "fallback allow side is a closed set (rg 掃描失敗 rc=${allow_rc}/${names_rc}，工具問題非程式碼變更)"
elif [ "$allow_rc" -ne 0 ]; then
  ng "fallback allow side is a closed set (找不到允許側錨點——被改寫過？)"
# rc=0 卻無輸出＝掃描器自相矛盾（說有命中卻交不出行），不是「檔案裡沒有」。沒有這一格，
# 空字串會穿過下面的多行檢查、落到集合比對而報成「集合是 []」——掃描器故障被說成內容
# 違規，看的人會去改文件而不是修工具。兩次呼叫併成一格：同一支 rg 壞掉時兩者同時為真，
# 分開寫的話先觸發的那格會把成因歸給下游那次呼叫（PR #92 Standards R4 實測）。names 那半
# 必須帶 names_rc -eq 0——rc=1 是「這一行真的沒有反引號 reason 名」，那是真違規，要走下面
# 的集合比對報「集合是 []」。
elif [ -z "$allow_line" ] || { [ "$names_rc" -eq 0 ] && [ -z "$allow_names" ]; }; then
  ng "fallback allow side is a closed set (rg 回 rc=0 卻交不出行——掃描器異常，非程式碼變更)"
elif [ "$allow_line" != "${allow_line%%$'\n'*}" ]; then
  ng "fallback allow side is a closed set (允許側錨點命中多行，應為 1)"
elif [ "$allow_names" != "review_actions_billing_or_quota" ]; then
  # 集合可能多行，壓成單行再進 label——否則 FAIL 那一行會被換行截斷，看不到第二個名字。
  allow_names_1line=$(printf '%s' "$allow_names" | tr '\n' '/')
  ng "fallback allow side is a closed set (允許側出現的 reason 集合是 [${allow_names_1line}])"
else
  ok "fallback allow side is a closed set"
fi

# 排除側開頭的前綴逐字釘住。它擋的是「除 A 與 B 外」這一種措辭，不擋那個類別：前綴之後
# 沒有結束錨點，粗體收尾後追加例外句照樣綠（#93 C 類）。
has "fallback exclude side carves out the billing reason by name" \
  '^[[:space:]]*- \*\*除 `review_actions_billing_or_quota` 外，helper 回的任何 `UNAVAILABLE` 一律不得 fallback\*\*' \
  "$review_triage_ref"
# 診斷用，非防護：允許側已窮舉，刪掉這一句不會 fail-open。
has "request failures are named on the exclude side" \
  'review_request_failed.*MUST 修 helper 或 retry' \
  "$review_triage_ref"

has "ledger records conditional RED or same-repro evidence" 'stable.*valuable.*RED.*否則.*repro.*before／after.*理由' skills/dev-workflow/references/ledgers.md
has "reviewer bug findings preserve conditional RED" 'stable.*valuable.*RED.*否則.*同一 repro.*before／after.*理由' skills/dev-workflow/references/reviewer-template.md
has "S5 bug findings preserve conditional RED" 'bug finding.*stable.*valuable.*RED.*否則.*repro.*before／after.*理由' skills/dev-workflow/SKILL.md
has "PR bug findings preserve conditional RED" 'finding 是 bug.*\[INT-2\].*RED.*同一 repro before／after' skills/dev-workflow/references/review-triage.md
lacks "no review path restores blanket RED" 'bug finding 先補 RED test|先寫紅測' skills/dev-workflow/SKILL.md skills/dev-workflow/references/review-triage.md
has "bot fixes use the applicable S4 tier" 'actionable.*自動修.*S4 risk tier.*exit code' skills/dev-workflow/references/review-triage.md

# B2 user-facing closeout：保留決策所需結果與 evidence，不複製 Preflight scaffolding。
has "closeout leads with outcome and incomplete scope" '先說 outcome.*未完成／被阻擋的 scope' "$ledgers_ref"
has "closeout preserves final verification and PR state" 'final verification.*PR 路徑.*current-head CI／review' "$ledgers_ref"
has "closeout surfaces decision-relevant risk and rollback" 'residual risk.*中高風險附 rollback' "$ledgers_ref"
has "closeout expands failures and unavailable evidence" 'gate 為 `FAIL`／`UNAVAILABLE`.*展開相關證據' "$ledgers_ref"
has "closeout avoids duplicating preflight-only detail" '不重述 self-simplification、diff self-review 或 reviewer metadata' "$ledgers_ref"

# B2b Preflight 自身仍可做低風險呈現壓縮，完整 evidence 不變。
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

# 2026-09-11 approved shared audit remediation. These assertions are intentionally kept in the
# existing cross-skill contract gate: each one failed against the accepted baseline before its
# owner document/script was changed, so the dangerous direction is false-green regression.
has "delegation preserves user-authored run limits" \
  '除使用者明示的本次 scope、數量或成本限制外' \
  skills/dev-workflow/references/delegation.md
has "codebase focus mode changes only authorized focus docs" \
  '只更新授權的 focus 文件.*非 focus 文件保持既有狀態.*不補.*TODO' \
  skills/acquire-codebase-knowledge/SKILL.md
has "codebase read-only mode writes no docs" \
  'Read-only.*session.*不建立文件' \
  skills/acquire-codebase-knowledge/SKILL.md
has "codebase full map owns the seven-doc contract" \
  'Full map.*七份文件' \
  skills/acquire-codebase-knowledge/SKILL.md
has "codebase focus and read-only scans stay on stdout unless persistence is authorized" \
  'Focus.*read-only.*stdout.*--output.*authorized' \
  skills/acquire-codebase-knowledge/SKILL.md
has "codebase Phase 3 seven-doc generation is full-map only" \
  'Phase 3.*Full map only' \
  skills/acquire-codebase-knowledge/SKILL.md
focus_scan_fixture="$(mktemp -d "${TMPDIR:-/tmp}/codebase-focus-scan.XXXXXX")" ||
  { ng 'focus scan fixture: 無法建立暫存目錄'; exit 1; }
printf '%s\n' '{"name":"focus-fixture"}' > "$focus_scan_fixture/package.json"
if (cd "$focus_scan_fixture" &&
    PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT/skills/acquire-codebase-knowledge/scripts/scan.py" > scan.stdout) &&
   [ -s "$focus_scan_fixture/scan.stdout" ] &&
   [ ! -e "$focus_scan_fixture/docs" ]; then
  ok "codebase stdout focus scan creates no docs or scan artifact"
else
  ng "codebase stdout focus scan creates no docs or scan artifact"
fi
rm -r -- "$focus_scan_fixture"
for severity_skill in \
  skills/dotnet-framework-best-practices/SKILL.md \
  skills/dotnet-logging-best-practices/SKILL.md; do
  has "impact-based review severity: $severity_skill" \
    'severity.*caller.*可達性.*資料.*安全.*可用性' "$severity_skill"
done
lacks "review signals do not hard-code inflated severity" \
  '^\| High \| Deps `new`-ed|^\| Critical \| Exceptions swallowed|^\| High \| Interpolation vs message templates' \
  skills/dotnet-framework-best-practices/SKILL.md \
  skills/dotnet-logging-best-practices/SKILL.md
has "ask-matt research defers delegation and output ownership" \
  'delegation.*INT-4.*輸出位置.*S2' \
  skills/ask-matt/references/engineering-flows.md
lacks "ask-matt does not force a background report" \
  'delegate reading legwork|leaves a cited Markdown file in the repo' \
  skills/ask-matt/references/engineering-flows.md

if PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT/skills/init-project-docs/scripts/merge-settings.py" <<'PY'
import copy
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("merge_settings", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

a = {"type": "command", "command": "a"}
b = {"type": "command", "command": "b", "timeout": 20}
c = {"type": "command", "command": "c"}
existing = {
    "PostToolUse": [{"matcher": "Edit|Write", "hooks": [a], "wrapperMeta": {"owner": "user"}}],
    "UnknownEvent": [{"opaque": [1, 2]}],
}
template = {
    "PostToolUse": [
        {"matcher": "Edit|Write", "hooks": [a, b], "wrapperMeta": {"owner": "user"}},
        {"matcher": "Edit|Write", "hooks": [c], "wrapperMeta": {"owner": "template"}},
    ]
}
before_existing = copy.deepcopy(existing)
before_template = copy.deepcopy(template)
merged = module.merge_hooks(existing, template)

assert merged["PostToolUse"] == [
    {"matcher": "Edit|Write", "hooks": [a, b], "wrapperMeta": {"owner": "user"}},
    {"matcher": "Edit|Write", "hooks": [c], "wrapperMeta": {"owner": "template"}},
]
assert merged["UnknownEvent"] == [{"opaque": [1, 2]}]
assert module.merge_hooks(merged, template) == merged
assert existing == before_existing
assert template == before_template
PY
then
  ok "merge-settings preserves overlapping hooks, metadata, inputs, and idempotence"
else
  ng "merge-settings preserves overlapping hooks, metadata, inputs, and idempotence"
fi

hook_fixture="$(mktemp -d "${TMPDIR:-/tmp}/run-tests-hook.XXXXXX")" ||
  { ng 'run-tests hook fixture: 無法建立暫存目錄'; exit 1; }
mkdir -p "$hook_fixture/tmp"
printf 'current\n' > "$hook_fixture/current.cs"
printf 'other\n' > "$hook_fixture/failing.cs"
printf 'plain\n' > "$hook_fixture/unconfigured.cs"
printf 'codex\n' > "$hook_fixture/codex.cs"
printf 'copilot-path\n' > "$hook_fixture/copilot-path.cs"
printf 'copilot-file-path\n' > "$hook_fixture/copilot-file-path.cs"
printf 'pipeline\n' > "$hook_fixture/pipeline.cs"
hook_input() { printf '{"tool_input":{"file_path":"%s"}}\n' "$1"; }
hook_pass="$(hook_input "$hook_fixture/current.cs" | \
  TMPDIR="$hook_fixture/tmp" \
  AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = current' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_pass_rc=$?
hook_skip="$(hook_input "$hook_fixture/current.cs" | \
  TMPDIR="$hook_fixture/tmp" \
  AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = current' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_skip_rc=$?
hook_fail="$(hook_input "$hook_fixture/failing.cs" | \
  TMPDIR="$hook_fixture/tmp" AGENT_TEST_COMMAND=false \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_fail_rc=$?
hook_not_run="$(hook_input "$hook_fixture/unconfigured.cs" | \
  TMPDIR="$hook_fixture/tmp" \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_not_run_rc=$?
if [ "$hook_pass_rc" -eq 0 ] && [[ "$hook_pass" == *PASSED* ]] &&
   [ "$hook_skip_rc" -eq 0 ] && [[ "$hook_skip" == *SKIPPED* ]] &&
   [ "$hook_fail_rc" -eq 0 ] && [[ "$hook_fail" == *FAILED* ]] &&
   [ "$hook_not_run_rc" -eq 0 ] && [[ "$hook_not_run" == *NOT_RUN* ]]; then
  ok "run-tests hook reports current-command pass, debounce skip, failure, and no config"
else
  ng "run-tests hook reports current-command pass, debounce skip, failure, and no config"
fi

mkdir -p "$hook_fixture/stat-bin"
cat > "$hook_fixture/stat-bin/stat" <<'SH'
#!/usr/bin/env bash
case "${STAT_FIXTURE_STYLE:-}:$1:$2" in
  gnu:-c:%Y|bsd:-f:%m)
    date +%s
    ;;
  gnu:-f:%m)
    printf '  File: "%s"\nBlocks: Total: 1 Free: 1\n' "$3"
    exit 1
    ;;
  bsd:-c:%Y)
    printf 'stat: illegal option -- c\n' >&2
    exit 1
    ;;
  *)
    exit 2
    ;;
esac
SH
chmod +x "$hook_fixture/stat-bin/stat"
printf 'gnu\n' > "$hook_fixture/gnu-stat.cs"
printf 'bsd\n' > "$hook_fixture/bsd-stat.cs"
hook_gnu_pass="$(hook_input "$hook_fixture/gnu-stat.cs" | \
  PATH="$hook_fixture/stat-bin:$PATH" STAT_FIXTURE_STYLE=gnu TMPDIR="$hook_fixture/tmp" \
  AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = gnu' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_gnu_skip="$(hook_input "$hook_fixture/gnu-stat.cs" | \
  PATH="$hook_fixture/stat-bin:$PATH" STAT_FIXTURE_STYLE=gnu TMPDIR="$hook_fixture/tmp" \
  AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = gnu' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_bsd_pass="$(hook_input "$hook_fixture/bsd-stat.cs" | \
  PATH="$hook_fixture/stat-bin:$PATH" STAT_FIXTURE_STYLE=bsd TMPDIR="$hook_fixture/tmp" \
  AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = bsd' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_bsd_skip="$(hook_input "$hook_fixture/bsd-stat.cs" | \
  PATH="$hook_fixture/stat-bin:$PATH" STAT_FIXTURE_STYLE=bsd TMPDIR="$hook_fixture/tmp" \
  AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = bsd' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
if [[ "$hook_gnu_pass" == *PASSED* ]] && [[ "$hook_gnu_skip" == *SKIPPED* ]] &&
   [[ "$hook_bsd_pass" == *PASSED* ]] && [[ "$hook_bsd_skip" == *SKIPPED* ]]; then
  ok "run-tests hook debounce supports GNU and BSD stat output contracts"
else
  ng "run-tests hook debounce supports GNU and BSD stat output contracts"
fi

hook_codex="$(printf '{"tool_input":{"path":"%s"}}\n' "$hook_fixture/codex.cs" | \
  TMPDIR="$hook_fixture/tmp" AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = codex' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_copilot_path="$(printf '{"toolArgs":{"path":"%s"}}\n' "$hook_fixture/copilot-path.cs" | \
  TMPDIR="$hook_fixture/tmp" AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = copilot-path' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
hook_copilot_file_path="$(printf '{"toolArgs":{"file_path":"%s"}}\n' "$hook_fixture/copilot-file-path.cs" | \
  TMPDIR="$hook_fixture/tmp" AGENT_TEST_COMMAND='test "$(cat "$AGENT_TEST_FILE")" = copilot-file-path' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
if [[ "$hook_codex" == *PASSED* ]] &&
   [[ "$hook_copilot_path" == *PASSED* ]] &&
   [[ "$hook_copilot_file_path" == *PASSED* ]]; then
  ok "run-tests hook accepts Claude Codex and Copilot target shapes"
else
  ng "run-tests hook accepts Claude Codex and Copilot target shapes"
fi

pipeline_output="$(printf '{"tool_input":{"file_path":"%s"}}\n' "$hook_fixture/pipeline.cs" | \
  TMPDIR="$hook_fixture/tmp" AGENT_TEST_COMMAND='false | cat' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
if [[ "$pipeline_output" == *FAILED* ]] && [[ "$pipeline_output" != *PASSED* ]]; then
  ok "run-tests hook propagates an earlier pipeline failure"
else
  ng "run-tests hook propagates an earlier pipeline failure"
fi

missing_marker="$hook_fixture/should-not-run"
missing_target_output="$(printf '{"toolArgs":{"path":"%s"}}\n' "$hook_fixture/missing.cs" | \
  TMPDIR="$hook_fixture/tmp" TEST_SENTINEL="$missing_marker" \
  AGENT_TEST_COMMAND='touch "$TEST_SENTINEL"' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
no_target_output="$(printf '%s\n' '{}' | \
  TMPDIR="$hook_fixture/tmp" TEST_SENTINEL="$missing_marker" \
  AGENT_TEST_COMMAND='touch "$TEST_SENTINEL"' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
invalid_json_output="$(printf '%s\n' '{' | \
  TMPDIR="$hook_fixture/tmp" TEST_SENTINEL="$missing_marker" \
  AGENT_TEST_COMMAND='touch "$TEST_SENTINEL"' \
  bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
mkdir -p "$hook_fixture/no-jq-bin"
ln -s /bin/cat "$hook_fixture/no-jq-bin/cat"
missing_jq_output="$(printf '{"tool_input":{"file_path":"%s"}}\n' "$hook_fixture/current.cs" | \
  PATH="$hook_fixture/no-jq-bin" TMPDIR="$hook_fixture/tmp" AGENT_TEST_COMMAND=true \
  /bin/bash "$ROOT/skills/init-project-docs/references/hooks/run-tests.sh" 2>&1)"
if [[ "$missing_target_output" == *NOT_RUN* ]] &&
   [[ "$no_target_output" == *NOT_RUN* ]] &&
   [[ "$invalid_json_output" == *NOT_RUN* ]] &&
   [[ "$missing_jq_output" == *NOT_RUN* ]] &&
   [ ! -e "$missing_marker" ]; then
  ok "run-tests hook reports unusable missing invalid and unparseable targets"
else
  ng "run-tests hook reports unusable missing invalid and unparseable targets"
fi
rm -r -- "$hook_fixture"
lacks "run-tests hook does not guess runner or stale assembly" \
  'vitest run|dotnet test.*--no-build' \
  skills/init-project-docs/references/hooks/run-tests.sh

has "Vite documents external outDir warning and ownership gate" \
  'outDir.*root 外.*預設不清空.*warning.*目錄完全由本次 build 擁有.*授權' \
  skills/vite/SKILL.md
has "Vite plugin order distinguishes enforce grouping from hook order" \
  'enforce.*pre.*post.*hook.*order.*bundler' \
  skills/vite/SKILL.md
has "Vitest entrypoint separates cleanup responsibilities" \
  'call history.*spy.*timer.*env.*references/vitest-deep\.md' \
  skills/vitest/SKILL.md
has "Vitest deep reference defines all cleanup APIs" \
  'clearAllMocks.*clearMocks.*call history.*restoreAllMocks.*restoreMocks.*useRealTimers.*unstubAllEnvs' \
  skills/vitest/references/vitest-deep.md
has "Vitest coverage autoUpdate only raises thresholds" \
  'autoUpdate.*coverage 改善.*提高.*不.*降' \
  skills/vitest/references/vitest-deep.md
lacks "Vitest restoreMocks does not claim after-test timing" \
  'restoreMocks:[^\n]*Restore after each test' \
  skills/vitest/references/features-mocking.md

for color_doc in \
  skills/tailwind-v4-shadcn/SKILL.md \
  skills/tailwind-v4-shadcn/references/architecture.md \
  skills/tailwind-v4-shadcn/references/common-gotchas.md \
  skills/tailwind-v4-shadcn/rules/tailwind-v4-shadcn.md \
  skills/tailwind-v4-shadcn/templates/index.css; do
  has "Tailwind preserves valid project color formats: $color_doc" \
    'oklch.*hsl.*var' "$color_doc"
done
lacks "Tailwind does not require HSL migration" \
  'All color values must use hsl|All colors have `hsl\(\)` wrapper|hsl\(\) wrapper required|Use `hsl\(\)` wrapper on all color values|Define color variables with `hsl' \
  skills/tailwind-v4-shadcn/SKILL.md \
  skills/tailwind-v4-shadcn/references/architecture.md \
  skills/tailwind-v4-shadcn/references/common-gotchas.md \
  skills/tailwind-v4-shadcn/rules/tailwind-v4-shadcn.md \
  skills/tailwind-v4-shadcn/templates/index.css

has "security ledger defers finding verdicts to workflow Step 6" \
  'Verdict.*Confidence.*severity.*workflow.*Step 6.*coverage' \
  skills/shared-security-review/references/changed-file-attack-surface.md
has "security report supports actual patch states" \
  'proposed-only.*applied-and-verified.*blocked' \
  skills/shared-security-review/references/report-format.md
has "security history scan requires redacted scanner output" \
  'secret scanner.*commit.*path.*line.*set/unset.*redacted' \
  skills/shared-security-review/references/report-format.md
lacks "security report does not hard-code an unapplied state or raw patch history" \
  'Nothing has been changed yet|Apply this patch\?|git log --all -p' \
  skills/shared-security-review/references/report-format.md

scan_fixture="$(mktemp -d "${TMPDIR:-/tmp}/codebase-scan.XXXXXX")" ||
  { ng 'codebase scan fixture: 無法建立暫存目錄'; exit 1; }
printf '%s\n' \
  'API_TOKEN=S11_ENV_VALUE_DO_NOT_PRINT' \
  'EMPTY=' \
  'export EXPORTED="S11_QUOTED_VALUE_DO_NOT_PRINT"' \
  'MULTILINE=S11_FIRST_LINE_DO_NOT_PRINT\' \
  'S11_CONTINUATION_DO_NOT_PRINT' \
  'BROKEN S11_UNPARSED_DO_NOT_PRINT' \
  'PRIVATE_KEY="first' \
  'S11_MULTILINE_ENV_KEY_DO_NOT_PRINT=' \
  'last"' \
  "UNCLOSED_SECRET='first" \
  'S11_UNCLOSED_ENV_KEY_DO_NOT_PRINT=' > "$scan_fixture/.env.defaults"
printf '%s\n' \
  '{"name":"fixture","token":"S11_TODO_BYPASS_VALUE_DO_NOT_PRINT","description":"TODO: update documentation",' \
  '"repository":"https://user:S11_URL_USERINFO_DO_NOT_PRINT@example.invalid/repo"}' \
  > "$scan_fixture/package.json"
printf '%s\n' \
  'signing.password=S11_GRADLE_FIRST_DO_NOT_PRINT S11_GRADLE_SECOND_DO_NOT_PRINT' \
  > "$scan_fixture/gradle.properties"
for fixture_line in $(seq 2 79); do
  printf 'safe.key.%s=value\n' "$fixture_line" >> "$scan_fixture/gradle.properties"
done
printf '%s\n' \
  'publish.password="""S11_BOUNDARY_START_DO_NOT_PRINT' \
  'S11_BOUNDARY_END_DO_NOT_PRINT"""' >> "$scan_fixture/gradle.properties"
printf '%s\n' \
  '[project]' \
  'name = "fixture"' \
  'password = """S11_TOML_FIRST_DO_NOT_PRINT' \
  'S11_TOML_SECOND_DO_NOT_PRINT' \
  '"""' > "$scan_fixture/pyproject.toml"
scan_stdout="$(cd "$scan_fixture" &&
  python3 "$ROOT/skills/acquire-codebase-knowledge/scripts/scan.py" 2>&1)"
scan_stdout_rc=$?
if [ "$scan_stdout_rc" -eq 0 ] &&
   (cd "$scan_fixture" &&
    python3 "$ROOT/skills/acquire-codebase-knowledge/scripts/scan.py" --output scan.txt \
      >/dev/null 2>&1) &&
   [[ "$scan_stdout" == *'API_TOKEN: set (line 1)'* ]] &&
   [[ "$scan_stdout" == *'[REDACTED]'* ]] &&
   [[ "$scan_stdout" != *S11_ENV* ]] &&
   [[ "$scan_stdout" != *S11_QUOTED* ]] &&
   [[ "$scan_stdout" != *S11_FIRST* ]] &&
   [[ "$scan_stdout" != *S11_CONTINUATION* ]] &&
   [[ "$scan_stdout" != *S11_UNPARSED* ]] &&
   [[ "$scan_stdout" != *S11_MANIFEST* ]] &&
   [[ "$scan_stdout" != *S11_URL* ]] &&
   [[ "$scan_stdout" != *S11_MULTILINE_ENV* ]] &&
   [[ "$scan_stdout" != *S11_UNCLOSED_ENV* ]] &&
   [[ "$scan_stdout" != *S11_TODO_BYPASS* ]] &&
   [[ "$scan_stdout" != *S11_GRADLE* ]] &&
   [[ "$scan_stdout" != *S11_BOUNDARY* ]] &&
   [[ "$scan_stdout" != *S11_TOML* ]] &&
   [[ "$scan_stdout" == *'PRIVATE_KEY: set (line 7)'* ]] &&
   [[ "$scan_stdout" == *'UNCLOSED_SECRET: set (line 10)'* ]] &&
   [[ "$scan_stdout" == *'UNTERMINATED quoted value redacted (line 10)'* ]] &&
   [[ "$scan_stdout" == *'package.json:1: TODO'* ]] &&
   rg -q 'API_TOKEN.*set.*line 1' "$scan_fixture/scan.txt" &&
   rg -q 'EMPTY.*unset.*line 2' "$scan_fixture/scan.txt" &&
   rg -q 'EXPORTED.*set.*line 3' "$scan_fixture/scan.txt" &&
   rg -q 'UNPARSED.*redacted' "$scan_fixture/scan.txt" &&
   rg -q '\[REDACTED\]' "$scan_fixture/scan.txt" &&
   ! rg -q 'S11_(ENV|QUOTED|FIRST|CONTINUATION|UNPARSED|MANIFEST|URL|MULTILINE|UNCLOSED|TODO_BYPASS|GRADLE|BOUNDARY|TOML)' "$scan_fixture/scan.txt"; then
  ok "codebase scanner redacts multiline env manifest boundaries and TODO summaries"
else
  ng "codebase scanner redacts multiline env manifest boundaries and TODO summaries"
fi
rm -r -- "$scan_fixture"

if PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT/skills/acquire-codebase-knowledge/scripts/scan.py" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile

scanner = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix="codebase-env-quotes-") as directory:
    fixture = Path(directory)
    lines = [
        "BACKTICK=`first", "S11_BACKTICK_VALUE=", "last`",
        "EMPTY= # comment", 'EMPTY_DOUBLE="" # comment',
        "EMPTY_SINGLE='' # comment", "EMPTY_BACKTICK=`` # comment",
        'HASH_DOUBLE="#" # comment', "HASH_SINGLE='#' # comment",
        "HASH_BACKTICK=`#` # comment", "SPACE=' ' # comment",
        "PLAIN=value # comment", "UNCLOSED=`first", "S11_UNCLOSED_BACKTICK_VALUE=",
    ]
    (fixture / ".env.defaults").write_text("\n".join(lines) + "\n")
    # The preview boundary must never restart key parsing inside a logical value.
    boundary = ["# filler"] * 78 + ["BOUNDARY=`first", "S11_BOUNDARY_BACKTICK_VALUE=", "last`"]
    (fixture / ".env.sample").write_text("\n".join(boundary) + "\n")
    report = fixture / "scan.txt"
    for options in ([], ["--output", str(report)]):
        result = subprocess.run([sys.executable, str(scanner), *options],
                                cwd=fixture, text=True, capture_output=True)
        assert result.returncode == 0, "scanner failed"
        output = report.read_text() if options else result.stdout
        assert "S11_" not in output, "logical value escaped summary"
        for key, line in (("EMPTY", 4), ("EMPTY_DOUBLE", 5),
                          ("EMPTY_SINGLE", 6), ("EMPTY_BACKTICK", 7)):
            assert f"{key}: unset (line {line})" in output, f"wrong empty state: {key}"
        for key, line in (("BACKTICK", 1), ("HASH_DOUBLE", 8),
                          ("HASH_SINGLE", 9), ("HASH_BACKTICK", 10),
                          ("SPACE", 11), ("PLAIN", 12), ("UNCLOSED", 13)):
            assert f"{key}: set (line {line})" in output, f"wrong nonempty state: {key}"
        for line in (13, 79):
            assert f"UNTERMINATED quoted value redacted (line {line})" in output
PY
then
  ok "codebase scanner handles backtick values and comments in both output modes"
else
  ng "codebase scanner handles backtick values and comments in both output modes"
fi

for vue_doc in \
  skills/vue-best-practices/SKILL.md \
  skills/vue-best-practices/references/rules-expanded.md; do
  has "Vue emit guidance covers typing and listener fallthrough: $vue_doc" \
    '型別|Typed.*listener fallthrough.*runtime no-op|runtime.*no-op.*listener' "$vue_doc"
  lacks "Vue emit guidance does not claim silent no-op: $vue_doc" \
    'Undeclared emit = silent no-op|undeclared emit is a silent no-op' "$vue_doc"
done

# Opus 5 prompt-compatibility audit (official guidance reviewed 2026-09-11): keep
# task-specific security independence and repository gates, while removing generic fixed fan-out,
# nested context-offload, and a duplicate final verifier fleet.
has "security audit routes agent use through shared INT-4" \
  '[Dd]elegation.*dev-workflow.*INT-4|dev-workflow.*INT-4.*[Dd]elegation' \
  skills/security-audit/SKILL.md
has "security audit preserves independent adversarial validation" \
  'Phase 3.*independent.*validat|independent.*Phase 3.*validat' \
  skills/security-audit/SKILL.md
lacks "security audit has no unconditional or numeric agent fleet" \
  'Launch \*\*multiple|launch \*\*multiple|3-4 agents|8-12\+|one `research` agent per confirmed finding|YOU CAN SPAWN SUB-AGENTS|fresh agents verify every factual claim' \
  skills/security-audit
lacks "security audit removes duplicate Phase 6 verifier fleet" \
  'Phase 6|six-phase|six phases' \
  skills/security-audit
has "security audit completes candidate record before independent validation" \
  'Before independent validation.*complete candidate record.*report-schema\.json' \
  skills/security-audit/VALIDATION-AND-REPORTING.md
has "security audit validator covers all substantive output fields" \
  'validator.*trace.*conditions.*execution.*payloads.*remediation.*code_changes.*severity.*confidence' \
  skills/security-audit/VALIDATION-AND-REPORTING.md
has "security audit sends substantive corrections to the same validator" \
  'substantive.*same validator.*structural' \
  skills/security-audit/VALIDATION-AND-REPORTING.md
has "security audit Phase 5 only serializes validated content" \
  'Phase 5.*serializ.*validated Phase 3 record.*MUST NOT.*new factual.*remediation' \
  skills/security-audit/VALIDATION-AND-REPORTING.md
has "security hunters return complete candidate inputs" \
  'candidate packet.*trace.*conditions.*execution.*remediation.*severity' \
  skills/security-audit/HUNTING.md
lacks "security README no longer names removed phases" \
  'Phases 3–6' \
  skills/security-audit/README.md
has "design-it-twice uses main context plus conditional INT-4 delegation" \
  'main context.*at least two.*INT-4.*sub-agent|at least two.*main context.*INT-4.*sub-agent' \
  skills/codebase-design/DESIGN-IT-TWICE.md
lacks "design-it-twice has no fixed 3-agent floor" \
  'Spawn 3\+ sub-agents|Agent 3:|Agent 4 \(if applicable\)' \
  skills/codebase-design/DESIGN-IT-TWICE.md
lacks "architecture deepening pointer does not force parallel agents" \
  'parallel sub-agent pattern' \
  skills/improve-codebase-architecture/SKILL.md
has "wayfinder research delegation is conditional" \
  'research tickets.*INT-4.*substantial.*independent|INT-4.*research tickets.*substantial.*independent' \
  skills/wayfinder/references/chart-map.md
lacks "wayfinder does not spawn one agent per research ticket" \
  'For each `research` ticket.*spin up' \
  skills/wayfinder/references/chart-map.md

lacks "active and archived skill prompts do not suppress thinking" \
  'do not think|don.t think|without thinking|disable (your )?reasoning' \
  skills attic
has "global workflow and security config are never trivial" 'global workflow.*security.*config.*不得.*trivial' skills/dev-workflow/SKILL.md
has "skill changes require invocation canaries" 'Skill change.*frontmatter.*relative references.*positive/negative.*trigger canary' skills/dev-workflow/SKILL.md
has "references declare load conditions" 'Load when' skills/dev-workflow/SKILL.md
lacks "kernel does not inline reviewer baselines" 'Reinvented Stdlib|Redundant Dependency|Unused Local Reuse|Needless Indirection|Wrong Altitude' skills/dev-workflow/SKILL.md
has "Copilot effort is adaptive" '模型預設 effort.*high.*xhigh.*量測' "$host_adapters_ref"
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
has "Ponytail host parity checks each approved payload hash" '\[ "\$actual" = "\$expected" \]' tests/ponytail-host-parity.sh
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
   _resolver_hits=$(printf '%s\n' "$resolver_output" | rg_hits 'Codex locked skill missing: missing-skill') &&
   [ "$_resolver_hits" -gt 0 ]; then
  ok "host resolver fails closed when a locked skill is missing"
else
  ng "host resolver fails closed when a locked skill is missing"
fi
rm -r -- "$resolver_fixture"
has "same-conversation compact is not a Matt handoff" 'same-conversation `/compact`.*MUST NOT.*`handoff`' "$routing_continuations_ref"
has "Codex native handoff does not invoke Matt handoff" 'Local/Worktree Handoff.*MUST NOT.*Matt `\$handoff`' "$host_adapters_ref"
has "Matt command prefix defers to the host adapter" 'Matt skill body.*`/skill-name`.*實際.*host adapter' "$host_adapters_ref"
section_has "S6 loads scoped closeout operations" 'S6 CLOSEOUT' 'MUST.*references/ledgers.md#closeout-operations.*分析不授權 mutation' skills/dev-workflow/SKILL.md
has "conflict analysis does not authorize mutation" '分析.*conflict.*不得.*resolve.*stage.*commit' "$ledgers_ref"
has "conflict resolution requires explicit user authorization" '明示.*解決 conflict.*`resolving-merge-conflicts`' "$ledgers_ref"
has "conflict staging stays within authorized resolved files" '`resolving-merge-conflicts`.*只 stage.*授權 scope.*MUST NOT `git add -A`' "$ledgers_ref"
has "unsafe conflict resolution may abort after confirmation" '必要意圖.*merge goal.*使用者確認.*abort.*上游' "$ledgers_ref"
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

copilot_section="$(sed -n '/^## Copilot$/,$p' "$ROOT/$host_adapters_ref")"
if copilot_s5_count=$(printf '%s\n' "$copilot_section" | rg_hits '^- S5 ') &&
   [ "$copilot_s5_count" -eq 1 ]; then
  ok "Copilot adapter has one canonical S5 directive"
else
  ng "Copilot adapter has one canonical S5 directive"
fi
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


# 2026-09-09: moved contracts must remain discoverable from the skill entrypoints.
# Failure bias is false-green if only the reference is checked; require each live route too.
has "setup routes its options" 'references/setup-options\.md' skills/setup-matt-pocock-skills/SKILL.md
has "triage routes issue cadence" 'references/issue-triage\.md' skills/triage/SKILL.md
has "code review routes dispatch contract" 'references/review-dispatch\.md' skills/code-review/SKILL.md

printf '\n%d PASS / %d FAIL\n' "$pass" "$fail"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]
