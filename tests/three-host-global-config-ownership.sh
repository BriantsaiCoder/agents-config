#!/usr/bin/env bash
set -euo pipefail

AGENTS="${AGENTS_HOME:-$(cd "$(dirname "$0")/.." && pwd -P)}"
PLAN="$AGENTS/proposals/2026-07-27-mattpocock-skills-workflow/48-three-host-global-config-ownership-split-plan.md"

# 2026-08-08：由 fail-fast 改為累加彙總。原本 fail() 直接 exit 1，於是同時存在的多個違規
# 只會現形第一個——實測三個 FAIL 疊了數週，每修好一個才露出下一個（CAP-LOCAL-AUTONOMY
# anchor 漂移 → ~/.claude repo-integrity.sh 條文 pin → settings.json 控制面引用）。
# 本檔第 296 行附近的註解早就記錄過同一個教訓：前面先死，後面的 control-plane 斷言與
# UNAVAILABLE 分支從未被跑到。慣例對齊 tests/conformance.sh 與 ~/.claude/tests/repo-integrity.sh
# 的 ok()／bad()；收尾行「N PASS / M FAIL」是 bin/ci-local:242 唯一不會過期的條數來源。
pass=0
fail=0
unavailable=0
ok()  { printf '  PASS  %s\n' "$*"; pass=$((pass + 1)); }
# bad 必須 return 0：本檔開了 set -e，`X || bad '…'` 若回非零會讓整份在第一個違規處
# 中止，等於改回 fail-fast。
bad() { printf '  FAIL  %s\n' "$*" >&2; fail=$((fail + 1)); return 0; }
# die 只留給「留著也只會產生同一根因雜訊」的前置條件（plan 檔缺失、host 樹不存在、
# scratch 建不起來），不用於任何 drift 斷言。
die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
# 分節收斂：沒有新增 FAIL 才記一次 PASS，然後把水位推到現值。逐條 ok() 要動 56 個
# 呼叫點且每個都得再想一句標籤；分節讓「N PASS」代表「N 個檢查群完整通過」，
# 同時給收尾行一個不會恆為 0 的分子——0 PASS / 0 FAIL 是本 repo 反覆點名的假綠形狀。
_wm=0
sect() { [ "$fail" -eq "$_wm" ] && ok "$*"; _wm=$fail; }

skills_manifests_match() {
  local before="$1" after="$2" expected_metadata="$3" label="$4"
  local semantic_before="$scratch/$label-before.tsv"
  local semantic_after="$scratch/$label-after.tsv"
  local before_metadata after_metadata before_count after_count

  awk -F '	' 'NR == 1 || $1 != ".DS_Store"' "$before" > "$semantic_before"
  awk -F '	' 'NR == 1 || $1 != ".DS_Store"' "$after" > "$semantic_after"
  cmp -s "$semantic_before" "$semantic_after" || return 1

  before_metadata="$(awk -F '	' '$1 == ".DS_Store"' "$before")"
  after_metadata="$(awk -F '	' '$1 == ".DS_Store"' "$after")"
  before_count="$(awk -F '	' '$1 == ".DS_Store" { count++ } END { print count + 0 }' "$before")"
  after_count="$(awk -F '	' '$1 == ".DS_Store" { count++ } END { print count + 0 }' "$after")"
  if [ -n "$expected_metadata" ]; then
    [ "$before_count" -eq 1 ] && [ "$after_count" -eq 1 ] &&
      [ "$after_metadata" = "$expected_metadata" ] || return 1
  else
    [ "$before_count" -eq 0 ] && [ "$after_count" -eq 0 ] &&
      [ -z "$before_metadata" ] && [ -z "$after_metadata" ] || return 1
  fi
}

[ -f "$PLAN" ] || die "ownership plan missing: $PLAN"
rg -Fq '只將 exact relative path `.DS_Store` 從 semantic skills payload gate 分離' "$PLAN" ||
  bad 'Plan 48 does not separate only exact .DS_Store from semantic skills payload'
rg -Fq '禁止 `*.DS_Store`、hidden-file wildcard與directory-wide exclusion' "$PLAN" ||
  bad 'Plan 48 does not prohibit wildcard skills exclusions'
rg -Fq '不得把 pre-cutover `UNAVAILABLE` 改寫成 `PASS`' "$PLAN" ||
  bad 'Plan 48 rewrites unavailable runtime evidence'
rg -Fq 'runtime no-load只在cutover transaction內逐host驗證' "$PLAN" ||
  bad 'Plan 48 does not defer runtime no-load to the cutover transaction'
rg -Fq '依Claude → Codex → Copilot固定順序' "$PLAN" ||
  bad 'Plan 48 does not preserve the fixed host order'
rg -Fq '確認Superpowers absent為PASS後才可進下一host' "$PLAN" ||
  bad 'Plan 48 advances before per-host plugin absence passes'
rg -Fq '任一host FAIL／UNAVAILABLE立即停止後續writes／probes並執行coordinated rollback' "$PLAN" ||
  bad 'Plan 48 does not fail fast into coordinated rollback'
rg -Fq 'fixed 6-run canary仍需獨立明示授權' "$PLAN" ||
  bad 'Plan 48 does not keep SaaS canaries separately authorized'
rg -Fq '只從 skill-directory enumeration排除 exact top-level `skills/.claude` runtime directory' "$PLAN" ||
  bad 'Plan 48 does not define the exact skills/.claude runtime exclusion'
rg -Fq '禁止 hidden-directory wildcard' "$PLAN" ||
  bad 'Plan 48 does not prohibit wildcard runtime-directory exclusions'
rg -Fq '不得以 `.in_use` directory count = 0作為maintenance gate' "$PLAN" ||
  bad 'Plan 48 treats persistent .in_use directories as active locks'
rg -Fq 'Claude process count = 0、active marker-owner intersection = 0、兩個exact Superpowers trees open-handle count = 0' "$PLAN" ||
  bad 'Plan 48 does not define the active-owner maintenance gate'
rg -Fq '禁止刪除、清空或wildcard處理任何 `.in_use`' "$PLAN" ||
  bad 'Plan 48 permits destructive .in_use cleanup'
sect 'Plan 48 條文（13 條）'

if rg -q \
  'TARGETS=|\.codex/AGENTS\.md|\.copilot/copilot-instructions\.md|refresh_claude_stamp|assemble_body|render_target' \
  "$AGENTS/bin/agents-sync"; then
  bad 'agents-sync still owns host global config'
fi
sect 'agents-sync 不擁有 host global config'

# 2026-08-03：candidate 改為直接指向 live host 目錄。原本用 `resolve_worktree` 去找
# `codex/three-host-global-config-split-{claude,codex,copilot}` 三個分支的 worktree，
# 但那些 worktree 建在 `/private/tmp/*-worktrees/`，macOS 會定期清空該路徑——目錄一消失
# 這支測試就恆 FAIL（實測從 2026-07-29 掛到 08-03）。三個分支的內容（含回覆 capability）
# 早已進入各 host 的 main，分支已於 2026-08-03 存檔至 backups/branch-archive/ 後刪除，
# 所以拆分實驗的 candidate 就是 live 目錄本身。env 覆寫保留，供 CI 或沙箱指向別處。
CLAUDE_CANDIDATE="${CLAUDE_CANDIDATE:-$HOME/.claude}"
CODEX_CANDIDATE="${CODEX_CANDIDATE:-$HOME/.codex}"
COPILOT_CANDIDATE="${COPILOT_CANDIDATE:-$HOME/.copilot}"

for candidate in "$CLAUDE_CANDIDATE" "$CODEX_CANDIDATE" "$COPILOT_CANDIDATE"; do
  [ -d "$candidate" ] || die "host candidate missing: $candidate"
done

CLAUDE_INSTRUCTIONS="$CLAUDE_CANDIDATE/CLAUDE.md" \
  CODEX_INSTRUCTIONS="$CODEX_CANDIDATE/AGENTS.md" \
  COPILOT_INSTRUCTIONS="$COPILOT_CANDIDATE/copilot-instructions.md" \
  bash "$AGENTS/tests/three-host-capability-parity.sh" --check ||
  bad 'host candidates do not provide equivalent semantic capabilities'
sect '三家 semantic capability 等價'

# 2026-07-30：移除對 $AGENTS/core/tier2-style.md 的 SHA 比對。core/ 三家 runtime 都不讀
# （本檔的 control_plane_hits 反向斷言已禁止 host config 引用 .agents control plane），已退役至
# attic/core/。三家 active config 的回覆等價由 three-host-capability-parity.sh 依 semantic
# anchors 把關；下面只保留 Claude-owned tier2 source 與指紋的 materialization 驗證。
# 2026-08-03：由整檔 SHA 改為釘 [T2-6] 條文本體 + FP 指紋兩行。原值 677f78d8… 經逐 commit
# 追查共失效兩次，都只動檔頭、T2-6 一字未改：`077c703 docs(claude): 清除 tier0／tier2 退役
# pipeline header`（拿掉 generated-from:）→ 865fceac，再 `9b8d9bf fix(core): tier1／tier2 檔頭
# consumed-by 更正為 claude`（改 consumed-by 與 last-verified）→ 410dc112。整檔 SHA 會把
# 「重新驗證日期」這種無關編輯誤報成條文漂移，而每次重新驗證都必然觸發。
# 改釘條文本體後，整檔 SHA 原本順帶守住的 `FP:STYLE-T2-2026Q3` 指紋會失去唯一機械守衛
# （四個 repo 全庫 grep 確認無第二處），而 CONVENTIONS 規則 6 讓該指紋是 context-level 載入
# 驗證的憑據——故另加一條 FP 斷言補回，不回退成整檔 SHA。
expected_tier2_rule='[T2-6] 回覆 SHOULD outcome-first、無空泛前後文；決策列編號選項／推薦／取捨，單字或數字即為完整回答，推測標記，已決不列替案。觸發：所有回覆。例外：安全確認／[T0-5] 澄清可先問。驗證：首段有結論／結果／阻塞／問題，結尾非客套。'
claude_tier2_src="$CLAUDE_CANDIDATE/core/tier2-style.md"
[ -f "$claude_tier2_src" ] ||
  bad "Claude candidate lacks the T2-6 source file: $claude_tier2_src"
grep -Fqx -- "$expected_tier2_rule" "$claude_tier2_src" ||
  bad 'Claude candidate does not materialize exact current T2-6 source bytes'
grep -Fq -- '<!-- FP:STYLE-T2-2026Q3 -->' "$claude_tier2_src" ||
  bad 'Claude candidate lost the tier2 FP fingerprint (CONVENTIONS 規則 6)'
rg -Fq 'current T2-6只保留到三家host-local active config；不得恢復 `.agents` control-plane ownership' "$PLAN" ||
  bad 'Plan 48 does not preserve T2-6 under host-local ownership'
sect 'Claude tier2 T2-6 條文本體與 FP 指紋'

scratch="$(mktemp -d "${TMPDIR:-/tmp}/agents-ownership.XXXXXX")"
trap 'chmod -R u+rwX "$scratch" 2>/dev/null || true; rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home/.claude/skills" "$scratch/home/.codex" "$scratch/home/.copilot"

runtime_agents="$scratch/runtime-agents"
runtime_home="$scratch/runtime-home"
mkdir -p \
  "$runtime_agents/bin" \
  "$runtime_agents/skills/example-skill" \
  "$runtime_agents/skills/.claude/.cc-writes" \
  "$runtime_home/.claude/skills"
cp "$AGENTS/bin/agents-sync" "$runtime_agents/bin/agents-sync"
chmod 755 "$runtime_agents/bin/agents-sync"
printf '%s\n' '# example' > "$runtime_agents/skills/example-skill/SKILL.md"
HOME="$runtime_home" AGENTS_HOME="$runtime_agents" \
  "$runtime_agents/bin/agents-sync" --bootstrap >/dev/null 2>&1 ||
  bad 'agents-sync rejected exact skills/.claude runtime directory'
HOME="$runtime_home" AGENTS_HOME="$runtime_agents" \
  "$runtime_agents/bin/agents-sync" --doctor >/dev/null 2>&1 ||
  bad 'agents-sync doctor counted exact skills/.claude as a skill'
[ -L "$runtime_home/.claude/skills/example-skill" ] ||
  bad 'agents-sync did not bootstrap the real skill beside skills/.claude'
[ ! -e "$runtime_home/.claude/skills/.claude" ] ||
  bad 'agents-sync created a Claude link for skills/.claude'

mkdir -p "$runtime_agents/skills/.unexpected-runtime"
if HOME="$runtime_home" AGENTS_HOME="$runtime_agents" \
  "$runtime_agents/bin/agents-sync" --check >/dev/null 2>&1; then
  bad 'agents-sync excluded an unknown hidden directory'
fi
rm -rf "$runtime_agents/skills/.unexpected-runtime"
sect 'agents-sync 對 exact skills/.claude 的處置'

shadow_shared="$scratch/shared-skills-live-shape"
mkdir -p "$shadow_shared/.claude/.cc-writes"
for link in "$CLAUDE_CANDIDATE"/skills/*; do
  mkdir -p "$shadow_shared/$(basename "$link")"
done
# 2026-08-08：原本把 repo-integrity.sh 的任何非 0 退出都斷言成「inventory 把 skills/.claude
# 當 skill」，並把輸出丟進 /dev/null。那支測試有 66 條斷言，其中只有一條與 .claude 有關——
# 實測一次 dotclaude CLAUDE.md 條文漂移（無關 .claude）就被這行改寫成 .claude 的問題，整條
# 追查方向被帶偏。skills/.claude 專屬的覆蓋已在上方 126-135 行（bootstrap／doctor／不建 link），
# 這裡只需驗「shadow root 形狀下 repo-integrity 整體仍綠」，並把真正的 FAIL 行印出來。
integrity_log="$scratch/claude-repo-integrity.log"
if ! (
  cd "$CLAUDE_CANDIDATE"
  SHARED_SKILLS_ROOT="$shadow_shared" bash tests/repo-integrity.sh
) > "$integrity_log" 2>&1; then
  grep -F 'FAIL' "$integrity_log" >&2 || cat "$integrity_log" >&2
  bad 'Claude repo-integrity failed under the skills/.claude shadow root（上列為實際 FAIL 行）'
fi
sect 'Claude repo-integrity 在 shadow root 下整體仍綠'

for sentinel in \
  "$scratch/home/.claude/CLAUDE.md" \
  "$scratch/home/.codex/AGENTS.md" \
  "$scratch/home/.copilot/copilot-instructions.md"; do
  printf 'host-global-config-sentinel\n' > "$sentinel"
  chmod 000 "$sentinel"
done

sentinel_before="$scratch/sentinel-before.tsv"
sentinel_after="$scratch/sentinel-after.tsv"
for sentinel in \
  "$scratch/home/.claude/CLAUDE.md" \
  "$scratch/home/.codex/AGENTS.md" \
  "$scratch/home/.copilot/copilot-instructions.md"; do
  stat -f '%N	%z	%Lp' "$sentinel" >> "$sentinel_before"
done

for mode in --check --doctor --bootstrap; do
  HOME="$scratch/home" AGENTS_HOME="$AGENTS" "$AGENTS/bin/agents-sync" "$mode" >/dev/null 2>&1 ||
    bad "skills-only mode failed: $mode"
done
for mode in default --deploy --only; do
  case "$mode" in
    default)
      if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" >/dev/null 2>&1; then
        bad "retired interface did not fail loud: $mode"
      fi
      ;;
    --only)
      if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" --only codex >/dev/null 2>&1; then
        bad "retired interface did not fail loud: $mode"
      fi
      ;;
    *)
      if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
        "$AGENTS/bin/agents-sync" "$mode" >/dev/null 2>&1; then
        bad "retired interface did not fail loud: $mode"
      fi
      ;;
  esac
done

for sentinel in \
  "$scratch/home/.claude/CLAUDE.md" \
  "$scratch/home/.codex/AGENTS.md" \
  "$scratch/home/.copilot/copilot-instructions.md"; do
  stat -f '%N	%z	%Lp' "$sentinel" >> "$sentinel_after"
done
diff -u "$sentinel_before" "$sentinel_after" >/dev/null ||
  bad 'skills-only modes changed host global config metadata'
sect 'skills-only 模式不觸碰 host global config'

# 2026-08-03：`bin/agents-branch` 單點放行，`bin` 其餘路徑仍禁止。
#
# 衝突：`~/.codex/tests/global-config-ownership.sh` 反向斷言 AGENTS.md 必須含
# `~/.agents/bin/agents-branch`（fail 訊息 'verified agents-branch path missing'），而本條原本
# 禁止一切 `.agents/bin`——兩個 repo 的測試互相否定、永遠無法同時綠。使用者於 2026-08-03
# 裁定放寬 bin。但整個 `bin/` 放行過寬：該目錄還有 agents-sync，而本檔上方另有一條斷言明文
# 禁止 agents-sync 擁有 host global config——整包放行會讓 host config 引用 agents-sync 不再被
# 偵測。故只放行 [T1-10] 實際強制的那一個工具路徑，其餘七支仍在守備範圍。
#
# 2026-08-08：`bin/pr-review-gate` 同理單點放行。它與 agents-branch 同類——[T0-9] merge gate
# 實際強制執行的那一支工具，hard_deny 條文必須指名可執行路徑才可稽核（`~/.claude/settings.json`
# 自 PR #14 起即引用，一直被前面兩條先死的斷言遮住）。放行仍只列這兩個確切工具路徑，
# core／rules／hooks／hosts／dist 與 bin 其餘六支不變。
#
# allowlist 上限 2（2026-08-08）：整包放行 `bin/` 是上一段明確否決過的方案，而 allowlist 逐筆
# 長大就是慢動作版的整包放行——第三、第四筆各自都有「這支也是必要工具」的理由，加完就回到
# 被否決的狀態。上限不是鎖，是絆線：要加第三筆就得同時改這行並寫下為什麼，讓「悄悄多一筆」
# 變成「明確放寬一次」。
#
# 錨在完整工具名（2026-08-08 PR #67 review 實測）：純子字串排除會連 `pr-review-gate_v2`、
# `agents-branch-old` 這類近似路徑一起放行，與「只放行兩個確切工具路徑」自相矛盾。終止條件
# 用「不能延續工具名的字元」而非列舉標點，因為引用脈絡有 backtick、空白、JSON 引號等多種。
# `/` 算「可延續」（#67 review 第二輪）：兩支都是檔案不是目錄，`.agents/bin/agents-branch/x`
# 這種帶 path segment 的引用不是那個確切工具路徑，必須照樣被偵測。
#
# 用 grep 而非 rg：本條是「找到就 FAIL」的反向斷言，寫成 `if rg …; then fail` 時缺 rg 會讓
# 整段靜默跳過（rg 非 0 → if 不成立 → 假綠）。bin/ci-local 已記錄過這個事故類別。grep 是
# POSIX 必然存在。終止字元加入空白與全形句讀，否則 `~/.agents/core。` 這類 zh-TW 散文寫法
# 可規避偵測。
control_plane_allow=(agents-branch pr-review-gate)
[ "${#control_plane_allow[@]}" -le 2 ] ||
  bad "control-plane allowlist 超過 2 筆上限（要放寬請連同上方理由一起改）: ${control_plane_allow[*]}"
control_plane_allow_re="\\.agents/bin/($(IFS='|'; printf '%s' "${control_plane_allow[*]}"))([^A-Za-z0-9_./-]|$)"

# selftest：兩個方向都要驗。只驗「確切路徑被放行」會漏掉子字串過寬，只驗「近似路徑被擋」
# 會漏掉錨過頭讓真正的引用回頭 FAIL——那會讓整條斷言恆紅而被下一個人整段註解掉。
allow_selftest="$(printf '%s\n' \
  'x:1:~/.agents/bin/pr-review-gate reported STATE=PASS' \
  'x:2:`~/.agents/bin/agents-branch` 建立分支' |
  grep -vE "$control_plane_allow_re" || true)"
[ -z "$allow_selftest" ] ||
  bad "control-plane allowlist 未放行確切工具路徑: $allow_selftest"
deny_selftest="$({ printf '%s\n' \
  'x:1:~/.agents/bin/pr-review-gate_v2 x' \
  'x:2:~/.agents/bin/agents-branch-old x' \
  'x:3:~/.agents/bin/agents-sync x' \
  'x:4:~/.agents/bin/agents-branch/anything x' \
  'x:5:~/.agents/bin/pr-review-gate/README x' |
  grep -vE "$control_plane_allow_re" || true; } | wc -l | tr -d ' ')"
[ "$deny_selftest" -eq 5 ] ||
  bad "control-plane allowlist 把近似路徑當成確切工具放行（僅 $deny_selftest/5 仍被偵測）"
sect 'control-plane allowlist 上限與正反向 selftest'

control_plane_hits="$(
  grep -nE '\.agents/(core|rules|hooks|hosts|dist|bin)(/|`|$|[[:space:]]|，|。|、)' \
    "$CLAUDE_CANDIDATE/CLAUDE.md" \
    "$CLAUDE_CANDIDATE/settings.json" \
    "$CODEX_CANDIDATE/AGENTS.md" \
    "$CODEX_CANDIDATE/hooks.json" \
    "$COPILOT_CANDIDATE/copilot-instructions.md" 2>/dev/null |
    grep -vE "$control_plane_allow_re" || true
)"
[ -z "$control_plane_hits" ] ||
  bad "active host global config still references .agents control plane: $control_plane_hits"
sect 'host global config 未引用 .agents control plane'

for dir in core rules hooks; do
  if find "$CLAUDE_CANDIDATE/$dir" -maxdepth 1 -type l -print -quit | grep -q .; then
    bad "Claude $dir still contains symlink"
  fi
done
for link in "$CLAUDE_CANDIDATE"/skills/*; do
  [ -L "$link" ] || bad "Claude skill is not symlink: $link"
  expected="../../.agents/skills/$(basename "$link")"
  [ "$(readlink "$link")" = "$expected" ] || bad "Claude skill target changed: $link"
done
sect 'Claude core/rules/hooks 無 symlink、skill link 目標正確'

head -1 "$CODEX_CANDIDATE/AGENTS.md" | grep -q '^<!-- GENERATED by ~/.agents/bin/agents-sync' &&
  bad 'Codex generated banner still present'
head -1 "$COPILOT_CANDIDATE/copilot-instructions.md" | grep -q '^<!-- GENERATED by ~/.agents/bin/agents-sync' &&
  bad 'Copilot generated banner still present'
sect 'Codex／Copilot 無 generated banner'

for candidate in "$CODEX_CANDIDATE" "$COPILOT_CANDIDATE"; do
  for rule in cookbook cpp dotnet frontend-spa infra testing typescript winforms; do
    [ -f "$candidate/rules/$rule.md" ] || bad "local stack rule missing: $candidate/rules/$rule.md"
  done
done
sect 'Codex／Copilot local stack rules 齊備'

for retired in dist hosts; do
  if [ -e "$AGENTS/$retired" ]; then
    bad "retired generated surface reappeared: $AGENTS/$retired"
  fi
done

# manifest 的目標狀態是「存在且中性」：deploy 路徑退休後它本來就該是空的
# （分離時刻意清空）。因此存在性是硬要求，非空不是——內容檢查只在它被重新
# 填入時才有意義。
[ -f "$AGENTS/attic/dist/manifest.tsv" ] ||
  bad 'retired manifest missing: attic/dist/manifest.tsv'
if [ -s "$AGENTS/attic/dist/manifest.tsv" ] &&
  rg -q '\.codex/AGENTS\.md|\.copilot/copilot-instructions\.md' "$AGENTS/attic/dist/manifest.tsv"; then
  bad 'retired manifest still contains host global config'
fi
sect '退役 surface 未復活、attic manifest 中性'

skills_before="${OWNERSHIP_SKILLS_BEFORE:-/private/tmp/three-host-global-config-split-impl-skills-before.tsv}"
skills_after="${OWNERSHIP_SKILLS_AFTER:-/private/tmp/three-host-global-config-split-ownership-after.tsv}"
skills_metadata="${OWNERSHIP_DS_STORE_METADATA:-}"
# 2026-08-03：由硬 FAIL 改為 UNAVAILABLE（家規 Gate contract：`UNAVAILABLE`（附 probe
# evidence）——artifact 可證明不存在且可證明不可重建，正是該狀態的定義；`SKIPPED` 是「有
# 能力但選擇不跑」）。這兩份 manifest 是 2026-07-29 ownership-split 對當下機器狀態拍的一次性
# 快照，存在 /private/tmp、從未進版控（`git log --all` 對六個 manifest 檔名在四個 repo 全部
# 0 命中），macOS 清空該路徑後不可重建——快照的是「拆分前」的樹，不是任何 commit 的內容。
# 計畫書 §7.1 另明文禁止 rebaseline（「不得自行 rebaseline」）。硬 FAIL 只會讓整支測試恆紅、
# 連帶遮住它後面所有仍有效的斷言（實證：本次修復前，control-plane 衝突斷言與 tier2 stale
# SHA 斷言都因為前面先死而從未被跑到）。
#
# artifact 若存在，MUST 先驗它是不是「那一份」：計畫書 §7.1 記錄 before manifest 的
# SHA-256。沒有這道驗證時，把 env 指向任意檔案（連 README.md）都會讓 gate 回綠——
# 逃生口會變成橡皮圖章。比對函式 skills_manifests_match 本身由下方 fixture 自我測試守護。
authentic_skills_before_sha='f7a3595ed6cbe8ff691fc094438aaed48e0cb8fdaa04b3a87a4c1a1ba37da12b'
if [ -f "$skills_before" ] && [ -f "$skills_after" ]; then
  [ "$(shasum -a 256 "$skills_before" | awk '{ print $1 }')" = "$authentic_skills_before_sha" ] ||
    bad "ownership skills baseline is not the recorded 2026-07-29 snapshot: $skills_before"
  skills_manifests_match "$skills_before" "$skills_after" "$skills_metadata" candidate ||
    bad 'ownership semantic skills manifest changed'
  sect 'ownership skills manifest 與 2026-07-29 快照一致'
elif [ -n "${OWNERSHIP_SKILLS_BEFORE+set}${OWNERSHIP_SKILLS_AFTER+set}${OWNERSHIP_DS_STORE_METADATA+set}" ]; then
  # 用 `+set` 而非 `:-`：export 成空字串也算「呼叫者明確要求跑這個 gate」，不得降級。
  # 三個變數都要納入——OWNERSHIP_DS_STORE_METADATA 設定的是同一道 gate。
  bad "ownership skills manifest explicitly requested but missing: $skills_before / $skills_after"
  _wm=$fail
else
  printf 'UNAVAILABLE  ownership skills manifest：2026-07-29 一次性快照已隨 /private/tmp 清空、從未進版控、計畫書禁止 rebaseline。probe：ls %s → No such file。設 OWNERSHIP_SKILLS_BEFORE／OWNERSHIP_SKILLS_AFTER 指向真本（SHA-256 %s）可恢復。\n' \
    "$skills_before" "$authentic_skills_before_sha"
  unavailable=$((unavailable + 1))
fi

accepted_metadata=$'.DS_Store\tfile\tabac08d6445bcc8848a10a5e0e2a406629d2dea627e500c8e6006f720a647606\t57348\t644\t-'
fixture_before="$scratch/skills-before.tsv"
fixture_after="$scratch/skills-after.tsv"
fixture_drift="$scratch/skills-drift.tsv"
printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tstable\t1\t644\t-\n' \
  $'.DS_Store\tfile\tfe6954846fbf416c1071b408009723b4c65773d4a2ebed156e42ec05a7f293c0\t57348\t644\t-' \
  > "$fixture_before"
printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tstable\t1\t644\t-\n' \
  "$accepted_metadata" > "$fixture_after"
skills_manifests_match "$fixture_before" "$fixture_after" "$accepted_metadata" accepted ||
  bad 'exact .DS_Store reconciliation did not pass'

printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tstable\t1\t644\t-\n' \
  $'.DS_Store\tfile\tchanged\t57348\t644\t-' > "$fixture_drift"
if skills_manifests_match "$fixture_before" "$fixture_drift" "$accepted_metadata" metadata-drift; then
  bad 'changed .DS_Store metadata was accepted'
fi

printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tstable\t1\t644\t-\nnested/.DS_Store\tfile\tchanged\t1\t644\t-\n' \
  "$accepted_metadata" > "$fixture_drift"
if skills_manifests_match "$fixture_before" "$fixture_drift" "$accepted_metadata" nested-drift; then
  bad 'nested .DS_Store was excluded as a wildcard'
fi

printf 'path\ttype\tsha256\tsize\tmode\tsymlink_target\n%s\nskill/SKILL.md\tfile\tchanged\t1\t644\t-\n' \
  "$accepted_metadata" > "$fixture_drift"
if skills_manifests_match "$fixture_before" "$fixture_drift" "$accepted_metadata" semantic-drift; then
  bad 'semantic skills drift was accepted'
fi
sect '.DS_Store 對帳 fixture 自我測試（4 種漂移）'

# 2026-07-30：rules/ 退役至 attic/ 後，typescript.md 與 frontend-spa.md 從此清單移除。
# 它們原本被列為 carrier 是因為兩個 skill 內文引用了那兩條路徑；那兩處引用已改成不帶
# 路徑的「家規」措辭（規則內容本來就內聯在 skill 裡），carrier 不再有消費者。
# issue-tracker.md 保留——它是 [INT-5] fallback 的真消費者：Matt skill 先讀 repo 的
# docs/agents/issue-tracker.md，不存在才落到這裡。
carrier="$AGENTS/docs/agents/issue-tracker.md"
[ -f "$carrier" ] || bad "compatibility carrier missing: $carrier"
sect 'compatibility carrier 存在'

historical_before="${HISTORICAL_BEFORE:-/private/tmp/three-host-global-config-split-historical-before.tsv}"
historical_after="${HISTORICAL_AFTER:-/private/tmp/three-host-global-config-split-historical-after.tsv}"
# 2026-08-03：與上方 skills manifest 同一處置，理由相同（一次性 /private/tmp 快照、未進
# 版控、計畫書禁止 rebaseline）。artifact 存在時先驗 before manifest 是不是計畫書 §16 記錄
# 的那一份，否則逃生口等於橡皮圖章；明確設 env 時仍硬 FAIL，不得降級。
authentic_historical_before_sha='6b75b8a337f51b7bc94e53c59f3a15d65255f0f42eea0b50607c71a57c1593cf'
if [ -f "$historical_before" ] && [ -f "$historical_after" ]; then
  [ "$(shasum -a 256 "$historical_before" | awk '{ print $1 }')" = "$authentic_historical_before_sha" ] ||
    bad "historical baseline is not the recorded 2026-07-29 snapshot: $historical_before"
  diff -u "$historical_before" "$historical_after" >/dev/null || bad 'historical artifacts changed'
  sect 'historical artifacts 與 2026-07-29 快照一致'
elif [ -n "${HISTORICAL_BEFORE+set}${HISTORICAL_AFTER+set}" ]; then
  bad "historical manifest explicitly requested but missing: $historical_before / $historical_after"
  _wm=$fail
else
  printf 'UNAVAILABLE  historical artifacts：一次性快照不可重建（同上）。設 HISTORICAL_BEFORE／HISTORICAL_AFTER 指向真本（SHA-256 %s）可恢復。\n' \
    "$authentic_historical_before_sha"
  unavailable=$((unavailable + 1))
fi

live_before="${LIVE_BEFORE:-/private/tmp/three-host-global-config-split-live-before.tsv}"
live_after="${LIVE_AFTER:-/private/tmp/three-host-global-config-split-live-after.tsv}"
# 同上；before manifest 的權威 SHA 記於計畫書 §1.5。
authentic_live_before_sha='3426b877845913a2ebbc5c9f6cf3ac2876aa29f2df9a46171e6b475446897217'
if [ -f "$live_before" ] && [ -f "$live_after" ]; then
  [ "$(shasum -a 256 "$live_before" | awk '{ print $1 }')" = "$authentic_live_before_sha" ] ||
    bad "live baseline is not the recorded 2026-07-29 snapshot: $live_before"
  diff -u "$live_before" "$live_after" >/dev/null || bad 'live repo fingerprints changed'
  sect 'live repo fingerprints 與 2026-07-29 快照一致'
elif [ -n "${LIVE_BEFORE+set}${LIVE_AFTER+set}" ]; then
  bad "live fingerprint explicitly requested but missing: $live_before / $live_after"
  _wm=$fail
else
  printf 'UNAVAILABLE  live repo fingerprints：一次性快照不可重建（同上）。設 LIVE_BEFORE／LIVE_AFTER 指向真本（SHA-256 %s）可恢復。\n' \
    "$authentic_live_before_sha"
  unavailable=$((unavailable + 1))
fi

printf '\n%d PASS / %d FAIL / %d UNAVAILABLE\n' "$pass" "$fail" "$unavailable"
# 「至少跑到了」自證：所有分節都沒跑到時上面會印 0 PASS / 0 FAIL 卻 exit 0，正是
# bin/ci-local 檔頭點名的「永遠回綠的包裝器比沒有更糟」。只釘下限不釘固定條數——
# 把條數寫死實測漂移過兩次（版本絆線 28→45、guard parity 11→13），維護成本高於
# 它擋下的東西。
[ "$((pass + fail))" -gt 0 ] || die '沒有任何檢查群執行'
[ "$fail" -eq 0 ]
