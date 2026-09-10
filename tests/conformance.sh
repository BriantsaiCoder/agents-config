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

# 掃描器 rc 三態的共用判別（issue #97）。原本全檔用 `rg -q` / `grep -q`，那是單一 bit：
# 一支壞掉卻 exit 0 的掃描器直接讓斷言變 PASS。實測本檔**至少** 8 條這樣的斷言
# ——8 是差分量測法（比較兩種故障下 verdict 不同的條數）可見的下界；兩種故障都印
# PASS 的那一類該方法看不見，兩軸 review 另外用逐條 mutation 找到更多。不寫定值。
# 用腳本自身的位置而非 ${AGENTS}：本檔的 host-facing 檢查刻意讀 ${AGENTS}（預設 ~/.agents），
# 但**共用判別必須來自受審 tree**，否則在 worktree／複本上跑的是 main 的那一份。
# shellcheck source=tests/lib/scan.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/lib/scan.sh" ||
  { printf '  FAIL  掃描判別 lib 缺席（tests/lib/scan.sh）\n'; exit 1; }
# source 成功不代表函式在：空檔或被截斷的 lib 同樣 rc=0，而 `scan_hit: command not found`
# 的 rc=127 會讓 negative control 全部印綠（實測清空 lib -> 8 條 control 全 PASS）。
command -v rg_hits >/dev/null 2>&1 ||
  { printf '  FAIL  掃描判別 lib 未定義 rg_hits（tests/lib/scan.sh 可能被截斷）\n'; exit 1; }

# negative control 驗的是**印出來的判定**，不只是 rc：本 issue 的症狀就是「印出 PASS」，
# 而 ok／ng 都 return 0，helper 的 rc 只承載「掃描可不可信」。純 rc 版連
# `ok "$1"; return 1` 這種假 helper 都會放行（PR #96 的 S5 R2 實測）。
# 探測組合一律選「真 rg 下會 PASS」的，否則 shim 沒生效時 fixture 也會綠、理由卻不對。
# 掃描器不在就先出聲：沒有這條的話 rg 缺席時三十幾條斷言各印一行歸因錯誤的結果，
# 沒有一行說得出「ripgrep 不在」。形狀沿用姊妹檔 mattpocock-workflow.sh。
if command -v rg >/dev/null 2>&1; then
  ok "ripgrep scanner is available"
else
  ng "ripgrep scanner is available"
fi

# control fixture 用受審 tree 裡的 lib 而不是 ${AGENTS}/CONVENTIONS.md：後者是 live
# host 檔，positive control 的綠不該取決於它裡面有沒有某個字（同上方的原則）。
# 不用本檔自己：sentinel 的字面就寫在下面的 control 裡，掃自己會命中，
# 那個探針就不再是「保證不存在」。
# find_list／find_count 的正本在 tests/lib/scan.sh（與 rg_hits 同一類判別）。
# 全檔只留一條 EXIT trap：前一版另起了一條 `trap 'rm -f "$find_errfile"' EXIT`，
# 被下方 $scratch 那條**覆蓋掉**（bash 的 EXIT trap 只留最後一條），errfile 每跑一次
# 就洩漏一個到 TMPDIR。errfile 改放 ${scratch}，跟著同一條 trap 清掉。
scratch="$(mktemp -d "${TMPDIR:-/tmp}/agents-conformance.XXXXXX")"
trap 'chmod -R u+rwX "$scratch" 2>/dev/null || true; rm -rf "$scratch"' EXIT
find_errfile="$scratch/find.err"

# find 的 silent-success 從 rc 偵測不到，所以配 canary。**canary 要用與實掃相同的
# predicate**：前一版的 canary 查的是 `-type d`，而它要保護的三條站點查的是
# `-name '*.pyc'`／`-perm -111`／`-name '*.bak*'`——predicate 層級壞掉時 canary 不會紅，
# 而且它守的那條（skill-link）本來就有 source/link 交叉比對，是五條裡唯一不需要它的。
# 改成建 fixture 植入三種已知違規，用同一組 predicate 正向驗抓得到。
# 形狀沿用同檔 varname canary。**它只擋 find 整支壞掉，擋不住局部失敗**（某個子目錄
# 讀不到時 find 仍回部分結果，那條由 find_list 的 stderr 檢查接住）。
find_canary_dir="$scratch/find-canary"
mkdir -p "$find_canary_dir/pkg/__pycache__"
: > "$find_canary_dir/pkg/mod.pyc"
: > "$find_canary_dir/note.bak"
: > "$find_canary_dir/runme"
chmod +x "$find_canary_dir/runme"
find_canary_fail=""
if ! find_canary_n=$(find_count "$find_errfile" "$find_canary_dir" \
     \( -type d -name __pycache__ -o -type f \( -name '*.pyc' -o -name '*.pyo' \) \)) ||
   [ "$find_canary_n" -lt 2 ]; then
  find_canary_fail="$find_canary_fail cache"
fi
if ! find_canary_n=$(find_count "$find_errfile" "$find_canary_dir" -type f -perm -111 \
     ! -name '*.sh' ! -name '*.py' ! -name '*.ps1' \
     ! -name '*.js' ! -name '*.cjs' ! -name '*.fsx') ||
   [ "$find_canary_n" -lt 1 ]; then
  find_canary_fail="$find_canary_fail exec"
fi
if ! find_canary_n=$(find_count "$find_errfile" "$find_canary_dir" -name '*.bak*' -not -name '.*') ||
   [ "$find_canary_n" -lt 1 ]; then
  find_canary_fail="$find_canary_fail bak"
fi
if [ -z "$find_canary_fail" ]; then
  ok "find canary：三組實掃 predicate 都抓得到植入的違規"
else
  ng "find canary：predicate 抓不到植入的違規（${find_canary_fail}）——下方計數站點的 0 不算數"
fi

# find_count 的 negative control（evidence-integrity.md 要求成對）。
# **只有 rc=2 這一格**：find 回 rc=0 + 空輸出是合法的 0（目錄真的沒有那種檔），
# find_count 必須把它當成可信的 0 而不是「不可信」——那一格由上面的 canary 承擔，
# 兩者是互補不是重複。硬加 rc=0 的 negative control 會要求 find_count 對合法輸入回錯。
assert_fails_closed find_count find 2 scan_verdict \
  find_count "$find_errfile" "$find_canary_dir" -name '*.bak*'
# 捕捉輸出而不是 `>/dev/null`：這兩支 helper 的 rc=0 只說「掃描可信」，
# 把輸出丟掉的話 control 在「筆數 0／沒有命中行」時照樣 PASS，等於沒驗到它真的有交出
# 東西（Copilot review 抓到）。fixture 裡植了 note.bak，所以正解是 >=1。
if _cp_out=$(find_count "$find_errfile" "$find_canary_dir" -name '*.bak*') &&
   [ "$_cp_out" -ge 1 ]; then
  ok "find_count accepts its clean positive control"
else
  ng "find_count accepts its clean positive control"
fi

scan_probe_file="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/lib/scan.sh"
for _scan_shim_rc in 2 0; do
  assert_fails_closed scan_hit    rg "$_scan_shim_rc" scan_verdict scan_hit    'rg_hits' "$scan_probe_file"
  assert_fails_closed scan_hit_f  rg "$_scan_shim_rc" scan_verdict scan_hit_f  'rg_hits' "$scan_probe_file"
  # 反向的兩支不能寫成 `! scan_hit`——掃描不可信時 scan_hit 回非 0，`!` 反轉成 true
  # 就把違規放行了。探測 pattern 用保證不存在的 sentinel。
  assert_fails_closed scan_miss   rg "$_scan_shim_rc" scan_verdict scan_miss   'THIS_MUST_NOT_EXIST_XYZZY' "$scan_probe_file"
  assert_fails_closed scan_miss_f rg "$_scan_shim_rc" scan_verdict scan_miss_f 'THIS_MUST_NOT_EXIST_XYZZY' "$scan_probe_file"
done
# clean positive control（evidence-integrity.md 要求成對）
scan_hit    'rg_hits' "$scan_probe_file" && ok "scan_hit accepts its clean positive control" \
  || ng "scan_hit accepts its clean positive control"
scan_hit_f  'rg_hits' "$scan_probe_file" && ok "scan_hit_f accepts its clean positive control" \
  || ng "scan_hit_f accepts its clean positive control"
scan_miss   'THIS_MUST_NOT_EXIST_XYZZY' "$scan_probe_file" && ok "scan_miss accepts its clean positive control" \
  || ng "scan_miss accepts its clean positive control"
# known-bad control：helper 本身退化（例如拿掉計數判定）時必須有東西轉紅。
# 只有 negative control 的話，把 scan_hit 改成「可信時恆真」十條控制項照樣全綠。
scan_hit 'THIS_MUST_NOT_EXIST_XYZZY' "$scan_probe_file" &&
  ng "scan_hit rejects its known-bad control" ||
  ok "scan_hit rejects its known-bad control"
scan_miss 'rg_hits' "$scan_probe_file" &&
  ng "scan_miss rejects its known-bad control" ||
  ok "scan_miss rejects its known-bad control"
scan_miss_f 'THIS_MUST_NOT_EXIST_XYZZY' "$scan_probe_file" && ok "scan_miss_f accepts its clean positive control" \
  || ng "scan_miss_f accepts its clean positive control"

# 測試計數宣稱的 lint（issue #89 第 2 項）。擋兩種句式，都是**套件總分**——每加一條
# 斷言就過期一次。實例：`c9e5ea1` 寫進一句帶當時總分（283）的「全綠」宣稱，到
# `49c5c5d` 移除時實際已是 375——`git log -S` 兩筆，腐爛一次、被觀察到過期兩次。
# 這段刻意不逐字引用那句：引用了本 lint 就會掃到自己（實測踩到），同 lacks_sentinel 的
# 手法。一支主旨是「別寫不可驗證數字」的 lint，自己的註解也不該放沒有座標的次數。
# (1)「N …全綠」族：**沒有座標例外**，這種句子的資訊量本來就在「全綠」不在「N」。
# (2) 註解行的非零「N PASS」：同行帶 issue 編號／SHA／ISO 日期就豁免。整條豁免的舊理由
#     （「機械上分不開」）被量測否證——tests/ 內 23 筆分桶後裸宣稱為 0，兩道過濾就分乾淨。
#     誤報仍是真風險（#93 的教訓：被誤擋的守門遲早被關），所以豁免用的是本 repo 既有慣例。
# 掃**受審 tree** 而不是 ${AGENTS}：註解內容 lint 屬源碼層判別，本檔檔頭已立過這個界線
# （host-facing 檢查讀 ${AGENTS}，源碼層判別讀受審 tree）。掃 ${AGENTS} 的話本機執行會
# 因為 main 上的殘留而紅，與開發者當前 tree 無關。
# 逐檔掃而不是掃目錄：rg_hits 帶 --no-ignore（那是為 scan_miss 的 under-scan 加的），
# 在這種「命中即違規」的 hit 側會把 .gitignore 掉的檔也算進去——一個 `sed -i.bak` 留下的
# 編輯器備份就能誤擋，而長期被誤擋的守門遲早被關掉。
#
# **兩條 pattern，不是一條**：
#  (1) 「N 條測試全綠」那一族。第一版釘的是字面拼法（半形空格 + 條 + 測試|斷言 + 全綠），
#      14 種注入只擋下 2 種——量詞、動詞、空格寬度任一換掉就逃逸。放寬成句式類別。
#      這一族沒有座標例外：句子的資訊量在「全綠」不在 N。
#  (2) 註解行裡的非零「N PASS」。第一版整條豁免，理由寫「機械上分不開」——**那個理由
#      被量測否證**：tests/ 內 23 筆分桶後，程式碼 4、`0 PASS / 0 FAIL` 樣板 16、
#      帶座標的歷史記錄 3，裸宣稱 0。兩道過濾（限註解行 + 非零；排除同行帶 #n／SHA／
#      ISO 日期）今天的誤報率就是 0。座標豁免用的正是本 repo 既有的慣例。
# target 含 bin/：issue #89 的動機案例就在 bin/pr-review-gate，只掃 tests/ 等於漏掉源頭。
count_claim_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
count_claim_bad=""
count_claim_unscannable=""
count_claim_scan() {  # count_claim_scan <file>
  local f="$1" n lines line
  # (1) 「N …全綠」族，無座標例外
  if ! n=$(rg_hits '[0-9]+ *[條個支]? *(測試|斷言)? *(全綠|皆綠|全部綠|全部通過|測試通過|斷言通過)' "$f"); then
    count_claim_unscannable="$count_claim_unscannable $f"
    return
  fi
  [ "$n" -gt 0 ] && count_claim_bad="$count_claim_bad $f(全綠族)"
  # (2) 註解行的非零 N PASS，同行無座標才算違規
  if ! lines=$(rg_lines '^[[:space:]]*#.*[1-9][0-9]* PASS' "$f"); then
    count_claim_unscannable="$count_claim_unscannable $f"
    return
  fi
  while [ -n "$lines" ]; do
    line=${lines%%$'\n'*}
    if [ -n "$line" ]; then
      # 座標判定走 rg_matches 而不是 `! … | rg -q`：後者在 rg rc>=2 時會判成「有座標」
      # 而豁免，掃描器一壞 lint 就靜默放行。這支 lint 的主旨正是擋這種 fail-open。
      rg_matches '#[0-9]+|[0-9a-f]{7,}|20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$line"
      case "$?" in
        0) ;;                                                              # 帶座標，豁免
        1) count_claim_bad="$count_claim_bad $f(裸 N PASS)" ;;
        *) count_claim_unscannable="$count_claim_unscannable $f"; return ;;
      esac
    fi
    if [ "$lines" = "$line" ]; then lines=; else lines=${lines#*$'\n'}; fi
  done
}
for count_claim_file in "$count_claim_root"/tests/*.sh "$count_claim_root"/tests/lib/*.sh \
  "$count_claim_root"/bin/*; do
  [ -f "$count_claim_file" ] || continue
  case "$count_claim_file" in *.bak*) continue ;; esac
  count_claim_scan "$count_claim_file"
done
if [ -n "$count_claim_unscannable" ]; then
  ng "套件總分 lint 掃描不可信：$count_claim_unscannable"
elif [ -z "$count_claim_bad" ]; then
  ok "測試與 bin 的註解未寫死套件總分"
else
  ng "註解寫死了套件總分（改成不含計數或加座標）：$count_claim_bad"
fi

# 計數宣稱 lint 的 control。fixture 放 $scratch 而不是 tests/ 底下——放那裡會被 lint
# 自己掃到。known-bad 用 14 種注入裡逃過第一版的其中兩種，證明放寬後的 pattern 抓得到。
count_claim_fixture="$scratch/count-claim"
mkdir -p "$count_claim_fixture"
# fixture 內容用組合而不是字面：完整字面寫在本檔裡的話，lint 掃自己就會命中
# （放寬 pattern 之後實測踩到）。同 lacks_sentinel 的手法。
count_claim_kw='測試'
printf '# 共 375 條%s通過\n' "$count_claim_kw" > "$count_claim_fixture/bad1.sh"
printf '# 實測 89 %s / 0 FAIL\n' PASS > "$count_claim_fixture/bad2.sh"
printf '# 實測 89 %s / 0 FAIL（PR #100）\n' PASS > "$count_claim_fixture/good.sh"
count_claim_probe() {  # count_claim_probe <file> -> 0=判為違規
  local saved_bad="$count_claim_bad" verdict=1
  count_claim_bad=""
  count_claim_scan "$1"
  [ -n "$count_claim_bad" ] && verdict=0
  count_claim_bad="$saved_bad"
  return "$verdict"
}
count_claim_probe "$count_claim_fixture/bad1.sh" &&
  ok "計數 lint 抓得到「共 N 條測試通過」（第一版逃逸的句式）" ||
  ng "計數 lint 抓得到「共 N 條測試通過」（第一版逃逸的句式）"
count_claim_probe "$count_claim_fixture/bad2.sh" &&
  ok "計數 lint 抓得到裸的 N PASS 註解" ||
  ng "計數 lint 抓得到裸的 N PASS 註解"
count_claim_probe "$count_claim_fixture/good.sh" &&
  ng "計數 lint 對帶座標的 N PASS 誤報" ||
  ok "計數 lint 對帶座標的 N PASS 不誤報"

# rg_matches 的控制項，兩格都要：它內部用 `rg -c`（見 scan.sh），rc=0 一定伴隨筆數，
# 所以「rc=0 但無輸出」是自相矛盾的故障、必須 fail-closed——與 rg_hits 同一格。
# （前一版註解沿用了 `rg -q` 的語義寫「rc=0 依定義就是命中、沒有靜默成功」，
# 那在改用 -c 之後就不成立了；Copilot review 抓到。）
assert_fails_closed rg_matches rg 2 scan_verdict rg_matches 'PR #100' '見 PR #100'
assert_fails_closed rg_matches rg 0 scan_verdict rg_matches 'PR #100' '見 PR #100'
if rg_matches 'PR #100' '見 PR #100'; then
  ok "rg_matches accepts its clean positive control"
else
  ng "rg_matches accepts its clean positive control"
fi
rg_matches 'PR #100' '沒有座標的一行'
[ "$?" -eq 1 ] &&
  ok "rg_matches rejects its known-bad control" ||
  ng "rg_matches rejects its known-bad control"

# 第三格：rg 回 rc=0 但筆數 0。`assert_fails_closed` 的 shim 只能控 rc（回 0 時無輸出），
# 蓋不到「有輸出但輸出是 0」，所以另寫一支 shim。只驗「是數字」的話 0 會被當成命中。
( rg() { printf '0\n'; return 0; }; rg_matches 'PR #100' '見 PR #100' )
[ "$?" -eq 2 ] &&
  ok "rg_matches fails closed when rg exits 0 with a zero count" ||
  ng "rg_matches fails closed when rg exits 0 with a zero count"

# rg_lines 的控制項。rc=0 但無輸出同樣自相矛盾（rg 無命中回 rc=1）；印空字串的話
# 呼叫端會當成「沒有命中行」而繼續。
for _rgl_shim_rc in 2 0; do
  assert_fails_closed rg_lines rg "$_rgl_shim_rc" scan_verdict \
    rg_lines '^[[:space:]]*#' "$count_claim_fixture/good.sh"
done
if _cp_out=$(rg_lines '^[[:space:]]*#' "$count_claim_fixture/good.sh") &&
   [ -n "$_cp_out" ]; then
  ok "rg_lines accepts its clean positive control"
else
  ng "rg_lines accepts its clean positive control"
fi

# 座標判定的掃描器故障必須讓該檔進 unscannable，不得靜默豁免。用 subshell 隔離 shim
# 與全域累加器：這條驗的是 count_claim_scan 的分派，不是 rg_matches 本身。
if ( rg_matches() { return 2; }
     count_claim_bad=""
     count_claim_unscannable=""
     count_claim_scan "$count_claim_fixture/bad2.sh"
     [ -n "$count_claim_unscannable" ] && [ -z "$count_claim_bad" ] ); then
  ok "計數 lint 在座標判定的掃描器故障時判不可信（不靜默豁免）"
else
  ng "計數 lint 在座標判定的掃描器故障時判不可信（不靜默豁免）"
fi

if AGENTS_HOME="$AGENTS" "$AGENTS/bin/agents-sync" --check >/dev/null 2>&1; then
  ok "shared skills source"
else
  ng "shared skills source"
fi

# 第六個同型站點。原本是 `done < <(find … | sort)`：find 靜默回空 -> while 一次都不跑
# -> mismatches 維持 0 -> PASS，而 `| sort` 讓 rc 連 pipefail 都看不到。**它比另外五條更糟**
# ——那五條至少在 find rc=2 時會紅，這條連 rc=2 都綠。
if ! skill_file_list=$(find_list "$find_errfile" "$AGENTS/skills" -mindepth 2 -maxdepth 2 \
     -name SKILL.md -type f); then
  ng "skill frontmatter 掃描不可信（find 失敗或有讀不到的路徑）"
  skill_file_list=""
  skill_scan_ok=0
elif [ -z "$skill_file_list" ]; then
  ng "skill frontmatter 掃描回空——skills/ 不可能沒有 SKILL.md"
  skill_scan_ok=0
else
  skill_scan_ok=1
fi
skill_name_mismatches=0
while IFS= read -r skill_file; do
  [ -n "$skill_file" ] || continue
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
done <<EOF
$skill_file_list
EOF
if [ "$skill_scan_ok" -eq 1 ] && [ "$skill_name_mismatches" -eq 0 ]; then
  ok "skill frontmatter names match directories"
elif [ "$skill_scan_ok" -eq 1 ]; then
  ng "skill frontmatter／directory mismatches: $skill_name_mismatches"
fi

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
   scan_hit 'resolve-library-id' "$context7_skill" &&
   scan_hit 'query-docs' "$context7_skill"; then
  ok "Context7 canonical procedure"
else
  ng "Context7 canonical procedure missing"
fi

if ! cache_count=$(find_count "$find_errfile" "$AGENTS/skills" \
  \( -type d -name __pycache__ -o -type f \( -name '*.pyc' -o -name '*.pyo' \) \)); then
  ng "Python cache 掃描不可信（find 失敗或有讀不到的路徑）"
elif [ "$cache_count" -eq 0 ]; then
  ok "shared skills contain no Python cache artifacts"
else
  ng "Python cache artifacts under shared skills: $cache_count"
fi

if ! bad_exec_count=$(find_count "$find_errfile" "$AGENTS/skills" -type f -perm -111 \
  ! -name '*.sh' ! -name '*.py' ! -name '*.ps1' \
  ! -name '*.js' ! -name '*.cjs' ! -name '*.fsx'); then
  ng "可執行檔掃描不可信（find 失敗或有讀不到的路徑）"
elif [ "$bad_exec_count" -eq 0 ]; then
  ok "only shared skill scripts are executable"
else
  ng "non-script executable files under shared skills: $bad_exec_count"
fi

if scan_hit_f '[ ! -L "$AGENTS/skills/video-downloader" ]' \
  "$AGENTS/tests/matt-thin-workflow.sh"; then
  ok "retired skill identity rejects broken symlinks"
else
  ng "retired skill identity can miss a broken symlink"
fi

mkdir -p "$scratch/home/.claude/skills"

if HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
  "$AGENTS/bin/agents-sync" --bootstrap >/dev/null 2>&1 &&
  HOME="$scratch/home" AGENTS_HOME="$AGENTS" \
  "$AGENTS/bin/agents-sync" --doctor >/dev/null 2>&1; then
  # 兩個計數都靠 find。工具壞掉時 `find | wc -l` 兩邊都被補成 `"0"`（不是空字串），
  # 所以**換掉比較運算子救不了**——`=` 與 `-eq` 對兩個 "0" 一樣判相等。真正修掉它的是
  # find_count 把「工具壞了」與「真的是 0」分開，判別必須在比較之前。
  if ! source_count=$(find_count "$find_errfile" "$AGENTS/skills" -mindepth 1 -maxdepth 1 -type d \
       ! -path "$AGENTS/skills/.claude"); then
    ng "skill-link 來源計數不可信（find 失敗或有讀不到的路徑）"
  elif ! link_count=$(find_count "$find_errfile" "$scratch/home/.claude/skills" -mindepth 1 -maxdepth 1 -type l); then
    ng "skill-link 連結計數不可信（find 失敗或有讀不到的路徑）"
  elif [ "$source_count" -eq "$link_count" ]; then
    ok "Claude skill-link bootstrap: $link_count"
  else
    ng "Claude skill-link count $link_count != source $source_count"
  fi
else
  ng "Claude skill-link bootstrap／doctor"
fi

# Antigravity 使用 temp HOME 驗真實 CLI；只看 link count 會讓錯誤目標假綠。
agy_home="$scratch/antigravity-home"
agy_source="$agy_home/.agents"
agy_roots=("$agy_home/.gemini/config/skills" "$agy_home/.gemini/antigravity-cli/skills")
mkdir -p "$agy_source/skills/alpha" "$agy_source/skills/beta"
printf '%s\n' '# alpha' > "$agy_source/skills/alpha/SKILL.md"
printf '%s\n' '# beta' > "$agy_source/skills/beta/SKILL.md"
agy_sync() {
  HOME="$agy_home" AGENTS_HOME="$agy_source" "$AGENTS/bin/agents-sync" "$@" \
    > "$scratch/antigravity-sync.log" 2>&1
}
if agy_sync --bootstrap && [ ! -e "$agy_home/.gemini" ]; then
  ok "default bootstrap remains Claude-only"
else
  ng "default bootstrap remains Claude-only"
fi
agy_valid=1
agy_sync --bootstrap-antigravity || agy_valid=0
for agy_dir in "${agy_roots[@]}"; do
  for agy_name in alpha beta; do
    [ -L "$agy_dir/$agy_name" ] &&
      [ "$agy_dir/$agy_name" -ef "$agy_source/skills/$agy_name" ] || agy_valid=0
  done
done
agy_sync --doctor || agy_valid=0
[ "$agy_valid" -eq 1 ] && ok "explicit Antigravity bootstrap covers both roots" ||
  ng "explicit Antigravity bootstrap covers both roots"

agy_valid=1
for agy_dir in "${agy_roots[@]}"; do
  mkdir -p "$agy_dir"
  ln -sfn "$agy_source/skills/beta" "$agy_dir/alpha"
  if agy_sync --doctor; then agy_valid=0; fi
  ln -sfn "$agy_source/skills/alpha" "$agy_dir/alpha"
done
[ "$agy_valid" -eq 1 ] && ok "Antigravity doctor rejects same-count wrong targets" ||
  ng "Antigravity doctor rejects same-count wrong targets"

agy_valid=1
for agy_dir in "${agy_roots[@]}"; do
  ln -sfn '../../../.agents/skills/alpha' "$agy_dir/alpha"
done
agy_sync --bootstrap-antigravity && agy_sync --doctor || agy_valid=0
for agy_dir in "${agy_roots[@]}"; do
  [ "$(readlink "$agy_dir/alpha")" = '../../../.agents/skills/alpha' ] &&
    [ "$(readlink "$agy_dir/beta")" = "$agy_source/skills/beta" ] || agy_valid=0
done
[ "$agy_valid" -eq 1 ] && ok "Antigravity preserves valid absolute and relative links" ||
  ng "Antigravity preserves valid absolute and relative links"

agy_valid=1
for agy_dir in "${agy_roots[@]}"; do
  ln -sfn "$agy_source/skills/alpha/" "$agy_dir/alpha"
  ln -sfn '../../../.agents/skills/./beta' "$agy_dir/beta"
done
agy_sync --bootstrap-antigravity && agy_sync --doctor || agy_valid=0
for agy_dir in "${agy_roots[@]}"; do
  [ "$(readlink "$agy_dir/alpha")" = "$agy_source/skills/alpha/" ] &&
    [ "$(readlink "$agy_dir/beta")" = '../../../.agents/skills/./beta' ] || agy_valid=0
done
[ "$agy_valid" -eq 1 ] && ok "Antigravity accepts equivalent shared target spellings" ||
  ng "Antigravity accepts equivalent shared target spellings"

mkdir -p "$scratch/host-owned-skill"
printf '%s\n' '# host owned' > "$scratch/host-owned-skill/SKILL.md"
agy_valid=1
for agy_dir in "${agy_roots[@]}"; do
  rm -f "$agy_dir/alpha" "$agy_dir/beta"
  ln -s "$scratch/host-owned-skill" "$agy_dir/alpha"
  mkdir -p "$agy_dir/beta"
  printf '%s\n' '# local beta' > "$agy_dir/beta/SKILL.md"
done
agy_sync --bootstrap-antigravity && agy_sync --doctor || agy_valid=0
for agy_dir in "${agy_roots[@]}"; do
  [ "$(readlink "$agy_dir/alpha")" = "$scratch/host-owned-skill" ] &&
    [ ! -L "$agy_dir/beta" ] &&
    [ "$(cat "$agy_dir/beta/SKILL.md")" = '# local beta' ] || agy_valid=0
done
[ "$agy_valid" -eq 1 ] && ok "Antigravity preserves host-owned skills and links" ||
  ng "Antigravity preserves host-owned skills and links"

agy_valid=1
for agy_dir in "${agy_roots[@]}"; do
  rm -f "$agy_dir/alpha"
  printf '%s\n' 'keep local file' > "$agy_dir/alpha"
  if agy_sync --bootstrap-antigravity; then
    agy_valid=0
  elif ! grep -Fq 'refusing' "$scratch/antigravity-sync.log"; then
    agy_valid=0
  fi
  [ -f "$agy_dir/alpha" ] && [ ! -L "$agy_dir/alpha" ] &&
    [ "$(cat "$agy_dir/alpha")" = 'keep local file' ] || agy_valid=0
  rm -f "$agy_dir/alpha"
  ln -s "$agy_source/skills/alpha" "$agy_dir/alpha"
done
[ "$agy_valid" -eq 1 ] && ok "Antigravity refuses conflicting non-skill paths" ||
  ng "Antigravity refuses conflicting non-skill paths"

agy_valid=1
for agy_dir in "${agy_roots[@]}"; do
  ln -s "$agy_source/skills/retired" "$agy_dir/retired"
  ln -s "$scratch/host-owned-skill" "$agy_dir/foreign"
done
agy_sync --bootstrap-antigravity || agy_valid=0
for agy_dir in "${agy_roots[@]}"; do
  [ ! -L "$agy_dir/retired" ] && [ -L "$agy_dir/foreign" ] || agy_valid=0
  rm -f "$agy_dir/alpha"
  if agy_sync --doctor; then agy_valid=0; fi
  ln -s "$agy_source/skills/alpha" "$agy_dir/alpha"
done
[ "$agy_valid" -eq 1 ] && ok "Antigravity prunes only owned stale links and detects missing links" ||
  ng "Antigravity prunes only owned stale links and detects missing links"

rm -f "$agy_home/.claude/skills/alpha" "${agy_roots[0]}/alpha" "${agy_roots[1]}/alpha"
if agy_sync --all && [ -L "$agy_home/.claude/skills/alpha" ] &&
   [ -L "${agy_roots[0]}/alpha" ] && [ -L "${agy_roots[1]}/alpha" ]; then
  ok "explicit all bootstraps Claude and both Antigravity roots"
else
  ng "explicit all bootstraps Claude and both Antigravity roots"
fi

mv "${agy_roots[1]}" "$scratch/saved-cli-skills"
ln -s "$scratch/saved-cli-skills" "${agy_roots[1]}"
rm -f "${agy_roots[0]}/alpha"
if agy_sync --bootstrap-antigravity ||
   ! grep -Fq 'destination root' "$scratch/antigravity-sync.log" ||
   [ -e "${agy_roots[0]}/alpha" ] || [ -L "${agy_roots[0]}/alpha" ]; then
  ng "Antigravity preflights both roots before writing"
else
  ok "Antigravity preflights both roots before writing"
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

if scan_hit_f '`.github/copilot/settings.json`' "$host_matrix" &&
   scan_hit_f '`.github/copilot/settings.local.json`' "$host_matrix" &&
   scan_hit_f '`.github/copilot/settings.json`' "$catalog_index" &&
   scan_hit_f '`.github/copilot/settings.local.json`' "$catalog_index"; then
  ok "init-project-docs knows Copilot repository／local settings"
else
  ng "init-project-docs Copilot repository／local settings are stale"
fi

if scan_hit_f 'startup\|resume\|clear\|compact' "$host_matrix" &&
   scan_hit_f 'startup|resume|clear|compact' "$codex_hooks"; then
  ok "init-project-docs Codex SessionStart sources are current"
else
  ng "init-project-docs Codex SessionStart misses compact"
fi

copilot_aliases_current=1
for alias in read edit search execute; do
  scan_hit_f "\`$alias\`" "$copilot_agents" || copilot_aliases_current=0
done
if [ "$copilot_aliases_current" -eq 1 ] &&
   scan_miss 'search/codebase|edit/editFiles|runCommands|execute/createAndRunTask' "$copilot_agents"; then
  ok "init-project-docs Copilot agent aliases are canonical"
else
  ng "init-project-docs Copilot agent aliases are stale"
fi

if scan_miss_f 'Codex recommendation markers:' "$init_docs" &&
   scan_hit_f '## Phase 4–6 建議標記' "$host_matrix"; then
  ok "init-project-docs host markers have one owner"
else
  ng "init-project-docs host markers are duplicated or misplaced"
fi

if scan_hit_f 'references/README.md' "$init_docs" &&
   scan_hit '^- \[ \]' "$init_docs"; then
  ok "init-project-docs uses shared catalogs and validation checklist"
else
  ng "init-project-docs catalog／validation hierarchy is incomplete"
fi

if scan_hit_f '`.github/copilot/settings.json`' "$copilot_settings" &&
   scan_hit '限定|supported keys' "$copilot_settings" &&
   scan_hit_f 'Phase 2 先增量更新' "$copilot_settings" &&
   scan_miss_f 'Phase 2 實際只產' "$copilot_settings"; then
  ok "init-project-docs Copilot settings boundary is current"
else
  ng "init-project-docs Copilot settings boundary is stale"
fi

if scan_hit_f 'references/README.md#conditional-setup-routing' "$init_docs" &&
   scan_hit_f '先讀取共用的 stack/template catalog' "$catalog_index" &&
   scan_hit_f '## Phase 4–6 建議標記' "$host_matrix"; then
  ok "init-project-docs new workflow prose is zh-TW"
else
  ng "init-project-docs new workflow prose is not zh-TW"
fi

# Failure direction: a missing scope distinction makes host-neutral docs silently inherit a
# confirmation gate, or makes an already-authorized host scope ask again. Pin both owners.
if scan_hit_f 'Host scope gate 僅適用 host-specific instructions、config、hooks、agents' "$init_docs" &&
   scan_hit_f 'host-neutral README／architecture 記 `N/A`' "$init_docs" &&
   scan_hit_f '已由 user/session 明確授權的 target hosts 直接沿用' "$init_docs" &&
   scan_hit_f 'host-specific output scope' "$host_matrix" &&
   scan_hit_f 'host-neutral README／architecture' "$host_matrix" &&
   scan_hit_f '已授權的 target hosts' "$host_matrix"; then
  ok "init-project-docs scopes host confirmation without re-asking authorized work"
else
  ng "init-project-docs host confirmation scope is over-broad or drops prior authorization"
fi

claimed="$(sed -n '1p' "$AGENTS/CONVENTIONS.md" | grep -oE '[0-9]+ 條' | grep -oE '[0-9]+' | head -1)"
actual="$(grep -c '^## [0-9]' "$AGENTS/CONVENTIONS.md")"
[ -n "$claimed" ] && [ "$claimed" = "$actual" ] &&
  ok "CONVENTIONS count $claimed" ||
  ng "CONVENTIONS claimed ${claimed:-none}, actual $actual"

# 規則 6 的 FP 用途區分（2026-08-03）。原文只寫「每個常駐注入檔…用途：context 級載入
# 驗證」，讀起來像「有 FP ⇒ 該檔會被注入」；同日稽核據此把 tier1／tier2 帶 FP 卻不注入
# 判成 doc-rot，但那是第二種用途（非注入正本的 byte-level drift sentinel）且已有 grep
# 斷言守著。普世宣稱本身才是 rot 來源，所以修的是條文不是檔頭——這兩條擋它被改回去。
if scan_hit_f 'byte-level drift sentinel' "$AGENTS/CONVENTIONS.md"; then
  ok "CONVENTIONS 規則 6 保留 FP 的第二種用途"
else
  ng "CONVENTIONS 規則 6 的 FP 用途區分被移除"
fi
if scan_hit_f '進 context 的問 AI，不進 context 的用 grep' "$AGENTS/CONVENTIONS.md"; then
  ok "CONVENTIONS 規則 6 保留 FP 驗證方式判準"
else
  ng "CONVENTIONS 規則 6 的 FP 驗證判準被移除"
fi

# 規則 12 標題不得再叫「常駐面」：四個檔裡 tier1／tier2 不進 context，
# ~/.claude/tests/repo-integrity.sh 有斷言擋著它們被 @-import。
# 用 scan_miss 而不是 `if scan_hit; then ng; else ok`：後者在掃描不可信時走 else 印
# PASS——與 `! scan_hit` 是同一個陷阱，只是倒過來寫。
if scan_miss '^## 12\..*常駐面' "$AGENTS/CONVENTIONS.md"; then
  ok "CONVENTIONS 規則 12 標題未誤稱常駐面"
else
  ng "CONVENTIONS 規則 12 標題退回「常駐面」（tier1／tier2 並不常駐）"
fi

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
  scan_miss 'AGENTS_DEPLOY_ROOT|dist/(skill-index\.md|AGENTS\.md|copilot-instructions\.md)|bin/agents-sync[[:space:]]+(--deploy|--only)' "$ci_workflow"; then
  ok "CI uses shared-skills contract"
else
  ng "CI still consumes retired agents-sync deployment"
fi

# tests/lib/*.sh 要單獨列：單層 glob 不遞迴，被所有測試 source 的共用檔會落在閘外。
if bash -n "$AGENTS"/bin/* "$AGENTS"/hooks/*.sh "$AGENTS"/tests/*.sh "$AGENTS"/tests/lib/*.sh; then
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
if ! bak_count=$(find_count "$find_errfile" "$AGENTS" -name '*.bak*' \
  -not -path '*/.git/*' -not -path '*/attic/*' -not -path '*/backups/*' \
  -not -name '.*'); then
  ng ".bak 掃描不可信（find 失敗或有讀不到的路徑）：$(head -1 "$find_errfile" 2>/dev/null)"
elif [ "$bak_count" -eq 0 ]; then
  ok "no manual .bak under ~/.agents"
else
  ng "manual .bak found under ~/.agents: $bak_count"
fi

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
  canary_dir="$(mktemp -d "${TMPDIR:-/tmp}/conformance.XXXXXX")" || canary_dir=""
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
  # 四棵樹逐一掃，各自驗 rc **與 stderr**。整批一次掃再 `| awk '{s+=$2}'` 的話有兩層
  # fail-open：pipe 讓 rc 變成 awk 的、`s+0` 把「完全沒有輸出」變成 0 判 ok；而且
  # **rc 偵測不到局部失敗**——任一棵樹裡有一個檔讀不到（權限、broken symlink），該檔的
  # 命中就靜默歸零而 rg 仍回 rc=0。實測把一支真違規檔 chmod 000：守護從 FAIL 變 PASS，
  # 旁邊的 canary 照樣綠（canary 只擋「掃描器整支壞掉」，擋不住局部失敗）。
  # 不走 rg_hits 是因為這裡需要 -P（PCRE2 的 \P{ASCII}）與 stderr 檢查，兩者都在
  # 共用判別的契約之外；同理不能只靠 rc。
  varname_hits=0
  varname_unscannable=
  varname_errfile="$scratch/varname.err"
  for varname_dir in "$AGENTS/bin" "$AGENTS/tests" "$AGENTS/hooks" "$AGENTS/skills"; do
    varname_out="$(rg -cP "$VARNAME_PAT" "$varname_dir" 2>"$varname_errfile")"
    varname_rc=$?
    if [ -s "$varname_errfile" ] || [ "$varname_rc" -gt 1 ]; then
      varname_unscannable="$varname_unscannable $varname_dir"
      continue
    fi
    case "$varname_rc" in
      1) continue ;;                                   # 這棵樹沒有命中
      0) ;;
      *) varname_unscannable="$varname_unscannable $varname_dir"; continue ;;
    esac
    varname_sum="$(printf '%s\n' "$varname_out" | awk -F: '{s+=$2} END{print s+0}')"
    case "$varname_sum" in
      ''|*[!0-9]*) varname_unscannable="$varname_unscannable $varname_dir" ;;
      0) varname_unscannable="$varname_unscannable $varname_dir" ;;  # rc=0 卻算不出正數＝自相矛盾
      *) varname_hits=$((varname_hits + varname_sum)) ;;
    esac
  done
  if [ -n "$varname_unscannable" ]; then
    ng "shell 變數名掃描不可信（掃不動或輸出對不上）：$varname_unscannable"
  elif [ "$varname_hits" = 0 ]; then
    ok "shell 變數名後未緊接非 ASCII"
  else
    ng "shell 變數名後緊接非 ASCII（bash 會吃進變數名，須改 \${var}）：$varname_hits 處"
  fi
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

# 有 pipeline 的 bash 腳本必須有 pipefail（2026-08-02 稽核 Follow-up 2 的機械守護）。
#
# 為何是機械守護：稽核當時逐一檢視 12 支無 pipefail 的腳本得出「沒有失敗方向錯誤」，
# 但那是人工結論，新腳本加入時沒有東西會提醒。follow-up 明寫要兩部分——處理既有的，
# 以及加這條守護；只做前者等於留下一個靠人記的不變量。
#
# 三類豁免，每類都有具體理由，不是便宜行事：
#   1. POSIX sh（shebang 為 sh 而非 bash）——pipefail 不是 POSIX，dash 直接
#      「set: Illegal option -o pipefail」中止。本次實測踩到：對 evals/mock-runner.sh
#      加了 pipefail，macOS 因 /bin/sh 是 bash 3.2 而全綠，ubuntu 的 dash 會讓
#      Step 2c 從 PASS=122 掉到 PASS=97 FAIL=25。
#   2. 被 source 的 library——不該設全域 set，正確做法是在需要的 subshell 內設
#      （lib-vendored.sh 就是這樣）。
#   3. tests/phase4-canary-harness.sh——被 matt-thin-workflow.sh 用 git diff --quiet
#      鎖定為歷史產物，不得變更。
#
# 「有 pipeline」的判準刻意窄：只認 `| <常見過濾器>`，不認 case pattern 的 |、|| 與
#  字串裡的 |。寧可漏報也不要因誤判而擋住無關的變更。
PIPE_USE='\| *(grep|awk|sed|sort|head|tail|tr|wc|jq|rg|cut|xargs|comm|uniq)'
pipefail_missing=""
pipefail_unscannable=""
# 第七個同型站點（與 skill frontmatter 那條同形）。原本是
# `done <<EOF` / `$(find … 2>/dev/null)` / `EOF`：find 靜默回空時 heredoc 只剩一個空行，
# 迴圈跑一次拿到空檔名，`head -1 ""` 失敗才把它收進 unscannable——**是意外轉紅**，
# 報的理由還是錯的（「有掃不動的檔」而不是「find 壞了」），而 `2>/dev/null` 正好把
# 唯一的真訊號吞掉。改走同一支 find_list：rc 與 stderr 都驗，空清單另行判死。
if ! pipefail_file_list=$(find_list "$find_errfile" "$AGENTS/bin" "$AGENTS/tests" \
     "$AGENTS/hooks" "$AGENTS/skills" -type f); then
  pipefail_scan_ok=0
elif [ -z "$pipefail_file_list" ]; then
  pipefail_scan_ok=2
else
  pipefail_scan_ok=1
fi
while IFS= read -r sh_file; do
  [ -n "$sh_file" ] || continue
  # 三格過濾器都要分開 rc=1（真的不符合，跳過）與 rc>=2／靜默成功（掃描不可信，
  # 不得跳過）。寫成 `|| continue` 的話掃描器一壞就 continue，整個檔被略過——實測
  # 545 個檔全部被跳過、守護只印一句 PASS。方向與「多檢查偏嚴」相反，是少檢查到 0。
  # 先把第一行落地並接住 head 的 rc：`head -1 f 2>/dev/null | scan_hit …` 在檔案讀不到時
  # 靜默輸出空字串，scan_hit 判「不是 bash」-> continue，該檔既被略過又不進
  # pipefail_unscannable——仍是 fail-open（Copilot review 抓到）。
  sh_shebang=$(head -1 "$sh_file" 2>/dev/null) ||
    { pipefail_unscannable="$pipefail_unscannable $sh_file"; continue; }
  printf '%s\n' "$sh_shebang" | scan_hit '^#!.*(bash)$'
  case "$?" in
    0) ;;                                                                   # 是 bash 腳本
    1) continue ;;                                                          # 豁免 1：不是
    *) pipefail_unscannable="$pipefail_unscannable $sh_file" ; continue ;;  # 掃描不可信
  esac
  case "$sh_file" in
    */lib-vendored.sh) continue ;;                                          # 豁免 2
    */phase4-canary-harness.sh) continue ;;                                 # 豁免 3
  esac
  scan_hit "$PIPE_USE" "$sh_file"
  case "$?" in
    0) ;;                                                                   # 有 pipeline
    1) continue ;;                                                          # 沒有，不適用
    *) pipefail_unscannable="$pipefail_unscannable $sh_file" ; continue ;;
  esac
  # 只認真正的設定行，不認註解或字串裡的 pipefail。第一版用裸 grep -q 'pipefail'，
  # 於是把 `set -u` 加一行「# 這裡刻意不設 pipefail」就能讓守護 PASS——一支專門抓
  # 假綠的守護自己就是假綠（2026-08-02 實測，Copilot review 抓到）。
  # `&& continue`：掃描不可信時 scan_hit 回非 0，不 continue，該檔落進 missing 清單
  # ——方向正確（fail-closed），但成因會被說成「缺 pipefail」。上面兩格已經把
  # 不可信的檔另外收進 pipefail_unscannable，這一格維持原樣即可。
  scan_hit '^[[:space:]]*set[[:space:]]+[^#]*pipefail' "$sh_file" && continue
  pipefail_missing="$pipefail_missing $sh_file"
done <<EOF
$pipefail_file_list
EOF
if [ "$pipefail_scan_ok" -eq 0 ]; then
  ng "pipefail 守護的檔案清單不可信（find 失敗或有讀不到的路徑）：$(head -1 "$find_errfile" 2>/dev/null)"
elif [ "$pipefail_scan_ok" -eq 2 ]; then
  ng "pipefail 守護的檔案清單回空——bin／tests／hooks／skills 不可能一個檔都沒有"
elif [ -n "$pipefail_unscannable" ]; then
  # 掃不動的檔不能靜默不算：那正是這支守護要防的「假綠」。
  ng "pipefail 守護有掃不動的檔（掃描器不可信）：$pipefail_unscannable"
elif [ -z "$pipefail_missing" ]; then
  ok "有 pipeline 的 bash 腳本都有 pipefail"
else
  ng "有 pipeline 但缺 pipefail：$(printf '%s' "$pipefail_missing" | tr ' ' '\n' | grep -c .) 支——$pipefail_missing"
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
elif scan_miss "$COUNT_IN_NAME" "$CI_YML"; then
  ok "CI step 名稱不含 case 數"
else
  ng "CI step 名稱複述 case 數（會靜默漂移）：$(grep -cE "$COUNT_IN_NAME" "$CI_YML") 處"
fi

printf '\n%d PASS / %d FAIL / %d SKIP\n' "$pass" "$fail" "$skipped"
# 「至少跑到了」自證：probe 全數提前 return 時上面會印 0 PASS / 0 FAIL 卻 exit 0，
# 那是本測試自己的 fail-open（2026-08-02 稽核 Follow-up 3）。
[ "$pass" -gt 0 ] || { printf 'FAIL  沒有任何檢查執行成功\n'; exit 1; }
[ "$fail" -eq 0 ]
