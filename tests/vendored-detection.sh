#!/usr/bin/env bash
# vendored_flag / vendored_owner / fork_recorded 回歸測試。
#
# 為何存在：lib-vendored.sh 是「可否原地編輯第三方 skill」的唯一機械判準，但 2026-07-25 前
# tests/ 對它零覆蓋。當天用手工審查抓到兩個 false negative（agent-browser、tailwind-v4-shadcn），
# 而那正是這個 gate 存在就是要免除的人工步驟——其中一個的漏判已經導致一次未察覺的 in-place edit。
#
# false negative 是危險方向：一個假的 "-" 授權你去改別人的 skill；一個假的 VND 只成本一次人工確認。
# 因此每個 case 的斷言方向都寫死，不接受「大致正確」。
#
# 用法：tests/vendored-detection.sh
# Exit: 0 = 全過。1 = 有 FAIL。
set -uo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
AGENTS="${AGENTS_HOME:-$(cd "$SELF_DIR/.." && pwd)}"
LIB="$AGENTS/skills/auditing-skill-folder/scripts/lib-vendored.sh"
[ -r "$LIB" ] || { echo "找不到 lib-vendored.sh：$LIB" >&2; exit 1; }
# shellcheck source=../skills/auditing-skill-folder/scripts/lib-vendored.sh
. "$LIB"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n     期望=%s 實得=%s\n' "$1" "$2" "$3"; }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

# mkskill <name> -> 建一個最小 skill 目錄並印出路徑
mkskill() {
  local d="$TMP/$1"
  mkdir -p "$d"
  printf -- '---\nname: %s\ndescription: test fixture\n---\n\n# %s\n' "$1" "$1" > "$d/SKILL.md"
  printf '%s' "$d"
}

echo "── vendored_flag：每種 provenance 形式 ──"

d=$(mkskill self-owned)
check "無任何 provenance -> -" "-" "$(vendored_flag "$d")"

d=$(mkskill has-license); printf 'Copyright (c) 2026 Test Corp.\n' > "$d/LICENSE"
check "LICENSE 存在 -> VND" "VND" "$(vendored_flag "$d")"

d=$(mkskill has-license-md); : > "$d/LICENSE.md"
check "LICENSE.md 存在 -> VND" "VND" "$(vendored_flag "$d")"

d=$(mkskill readme-marketplace)
printf '# x\n\nAvailable on the Skilz Marketplace: https://skilz.example.invalid/x\n' > "$d/README.md"
check "README 含 marketplace 字樣 -> VND" "VND" "$(vendored_flag "$d")"

d=$(mkskill skill-github-url)
printf -- '---\nname: x\n---\n\nSee https://github.com/someone/awesome-skills for updates.\n' > "$d/SKILL.md"
check "SKILL.md 含 github skill repo URL -> VND" "VND" "$(vendored_flag "$d")"

# 2026-07-25 新增：tailwind-v4-shadcn 的唯一 provenance 就在這個檔，之前完全不被讀。
d=$(mkskill plugin-manifest); mkdir -p "$d/.claude-plugin"
printf '{ "name": "x", "repository": "https://github.com/someone/claude-skills" }\n' \
  > "$d/.claude-plugin/plugin.json"
check ".claude-plugin/plugin.json 含 repository -> VND" "VND" "$(vendored_flag "$d")"

# 2026-07-25 新增：agent-browser 的標記在 frontmatter 之後的 HTML comment，且是 pipe 分隔的第 4 欄。
d=$(mkskill html-comment-marker)
printf -- '---\nname: x\ndescription: y\n---\n\n<!-- tier: w | consumed-by: a,b | upstream: some CLI | last-verified: 2026-07-25 -->\n\n# x\n' \
  > "$d/SKILL.md"
check "post-frontmatter HTML comment 內 pipe 分隔的 upstream: -> VND" "VND" "$(vendored_flag "$d")"

d=$(mkskill frontmatter-upstream)
printf -- '---\nname: x\nupstream: https://example.invalid/x\n---\n\n# x\n' > "$d/SKILL.md"
check "frontmatter 內 upstream: -> VND（明確宣告外來，非 probable）" "VND" "$(vendored_flag "$d")"

d=$(mkskill frontmatter-homepage)
printf -- '---\nname: x\nhomepage: https://example.invalid/x\n---\n\n# x\n' > "$d/SKILL.md"
check "frontmatter 內 homepage: -> vnd?（可能是自家連結）" "vnd?" "$(vendored_flag "$d")"

d=$(mkskill frontmatter-source)
printf -- '---\nname: x\nsource: https://example.invalid/x\n---\n\n# x\n' > "$d/SKILL.md"
check "frontmatter 內 source: -> vnd?" "vnd?" "$(vendored_flag "$d")"

d=$(mkskill lock-listed)
LOCK="$TMP/mattpocock-skills.lock"
printf 'source_url=https://github.com/example/skills.git\nskill=lock-listed\n' > "$LOCK"
MATTPOCOCK_SKILLS_LOCK="$LOCK"
export MATTPOCOCK_SKILLS_LOCK
check "root lock 列出的 skill -> VND" "VND" "$(vendored_flag "$d")"
check "root lock 的 source_url -> owner" "https://github.com/example/skills.git" "$(vendored_owner "$d")"
unset MATTPOCOCK_SKILLS_LOCK

d=$(mkskill generic-lock-listed)
GENERIC_LOCK="$TMP/vendored-skills.lock"
printf '# skill\tsource_url\tassessed_revision\tpayload_sha256\ttree_sha256\n%s\t%s\t%s\t%s\t%s\n' \
  generic-lock-listed https://github.com/example/skills.git deadbeef \
  0123456789abcdef fedcba9876543210 \
  > "$GENERIC_LOCK"
VENDORED_SKILLS_LOCK="$GENERIC_LOCK"
export VENDORED_SKILLS_LOCK
check "generic provenance lock 列出的 skill -> VND" "VND" "$(vendored_flag "$d")"
check "generic provenance lock 的 source_url -> owner" \
  "https://github.com/example/skills.git" "$(vendored_owner "$d")"
unset VENDORED_SKILLS_LOCK

check "目錄不存在 -> ERR" "ERR" "$(vendored_flag "$TMP/does-not-exist")"

d="$TMP/no-skill-md"; mkdir -p "$d"
check "目錄存在但無 SKILL.md -> ERR" "ERR" "$(vendored_flag "$d")"

echo
echo "── vendored_tree_sha256：內容、mode、symlink 都必須受保護 ──"

d=$(mkskill tree-hash)
tree_hash_before="$(vendored_tree_sha256 "$d")"
chmod +x "$d/SKILL.md"
tree_hash_executable="$(vendored_tree_sha256 "$d")"
[ "$tree_hash_before" != "$tree_hash_executable" ] &&
  ok "executable bit 變更 -> tree SHA 變更" ||
  bad "executable bit 變更" "different SHA" "$tree_hash_executable"
chmod -x "$d/SKILL.md"
ln -s first-target "$d/link"
tree_hash_first_link="$(vendored_tree_sha256 "$d")"
ln -snf second-target "$d/link"
tree_hash_second_link="$(vendored_tree_sha256 "$d")"
[ "$tree_hash_first_link" != "$tree_hash_second_link" ] &&
  ok "symlink target 變更 -> tree SHA 變更" ||
  bad "symlink target 變更" "different SHA" "$tree_hash_second_link"
ln -s "$d" "$TMP/tree-hash-root-link"
if vendored_tree_sha256 "$TMP/tree-hash-root-link" >/dev/null 2>&1; then
  bad "skill root 換成 symlink" "rejected" "accepted"
else
  ok "skill root 換成 symlink -> rejected"
fi

# 指紋必須是「已提交 payload 的屬性」，不是「工作機環境的屬性」。
# 2026-08-01 CI 實測：Claude Code 對 skill 寫檔時會在該資料夾建立 .claude/.cc-writes
# （空目錄、已被 .gitignore 排除）。舊版 find 把它算進 manifest，於是本機算出的
# tree SHA 永遠對不上 CI 的乾淨 checkout——matt-thin-workflow 報
# "writing-great-skills tree differs from the recorded fork fingerprint"，
# 而本機同一支測試是綠的。當時 13 個 skill 資料夾已帶有這個產物。
d=$(mkskill tree-hash-scratch)
tree_hash_clean="$(vendored_tree_sha256 "$d")"
mkdir -p "$d/.claude/.cc-writes"
tree_hash_scratch="$(vendored_tree_sha256 "$d")"
check "harness scratch .claude/ 不改變 tree SHA" "$tree_hash_clean" "$tree_hash_scratch"
# 但 .claude 以外的新增內容仍必須改變指紋——排除範圍不得擴散。
printf 'x\n' > "$d/extra.md"
tree_hash_extra="$(vendored_tree_sha256 "$d")"
[ "$tree_hash_clean" != "$tree_hash_extra" ] &&
  ok "非 .claude 的新增檔仍改變 tree SHA" ||
  bad "非 .claude 的新增檔仍改變 tree SHA" "different SHA" "$tree_hash_extra"

echo
echo "── vendored_flag：不可誤判（false positive 防線）──"

# prose 提到 upstream 但無冒號，不得命中；這是 dotnet-core-best-practices 的真實句型。
d=$(mkskill prose-upstream)
printf -- '---\nname: x\n---\n\nNote: if your upstream uses short DNS TTLs, pin the resolver.\n' > "$d/SKILL.md"
check "散文中的 upstream（無冒號）-> -" "-" "$(vendored_flag "$d")"

d=$(mkskill readme-exists-only)
printf '# x\n\nJust documentation, no provenance.\n' > "$d/README.md"
check "README 只是存在、無 provenance 內容 -> -" "-" "$(vendored_flag "$d")"

echo
echo "── vendored_owner：必須與 vendored_flag 同步歸屬 ──"

d=$(mkskill owner-license); printf 'Copyright (c) 2026 Someone Inc.\n' > "$d/LICENSE"
check "LICENSE copyright 行" "2026 Someone Inc." "$(vendored_owner "$d")"

d=$(mkskill owner-plugin); mkdir -p "$d/.claude-plugin"
printf '{ "repository": "https://github.com/someone/claude-skills" }\n' > "$d/.claude-plugin/plugin.json"
check "plugin.json 的 repository URL" "https://github.com/someone/claude-skills" "$(vendored_owner "$d")"

d=$(mkskill owner-comment)
printf -- '---\nname: x\n---\n\n<!-- tier: w | upstream: some CLI thing | last-verified: 2026-07-25 -->\n' \
  > "$d/SKILL.md"
check "HTML comment 內 upstream 值（尾端 pipe 段與 --> 需剝除）" "some CLI thing" "$(vendored_owner "$d")"

# 已知邊界：provenance 訊號存在但不帶可歸屬資訊時，OWNER 欄會是空的。這是誠實的空白
# （沒有東西可印），不是漏抓——flag 仍然是 VND，gate 照樣生效。
d=$(mkskill vnd-without-owner); : > "$d/LICENSE"
check "空 LICENSE -> 仍 VND" "VND" "$(vendored_flag "$d")"
check "空 LICENSE -> owner 為空（已知邊界，非缺陷）" "" "$(vendored_owner "$d")"

# 其餘每個判 VND 的 fixture 都必須能歸屬，否則報表會出現「偵測到但無法歸屬」的半殘列。
echo
for name in has-license readme-marketplace skill-github-url plugin-manifest html-comment-marker frontmatter-upstream; do
  d="$TMP/$name"
  if [ "$(vendored_flag "$d")" = "VND" ] && [ -z "$(vendored_owner "$d")" ]; then
    bad "VND 但 owner 為空：$name" "非空 owner" "(空)"
  else
    ok "VND 且 owner 非空：$name"
  fi
done

echo
echo "── fork_recorded：查找必須限定在 fork-index 區間內 ──"

FORKS="$TMP/vendored-forks.md"
cat > "$FORKS" <<'EOF'
# Vendored forks

<!-- fork-index:begin -->

| Skill | Upstream | Status |
|---|---|---|
| `recorded-one` | example | Active |

<!-- fork-index:end -->

## Some other section

| `not-a-fork` | this row is documentation, not an index entry | x |
EOF

VENDORED_FORKS="$FORKS"
export VENDORED_FORKS

fork_recorded recorded-one && ok "區間內的列 -> 判為已記錄" || bad "區間內的列" "recorded" "not recorded"
# 2026-07-25 的實際回歸：說明用表格把 agent-browser 誤升為 VND*。
fork_recorded not-a-fork && bad "區間外同格式的列" "NOT recorded" "recorded" || ok "區間外同格式的列 -> 不判為已記錄"
fork_recorded never-mentioned && bad "完全未提及" "NOT recorded" "recorded" || ok "完全未提及 -> 不判為已記錄"

printf '# no markers here\n\n| `orphan` | x | y |\n' > "$TMP/no-markers.md"
VENDORED_FORKS="$TMP/no-markers.md"
fork_recorded orphan && bad "無 marker 的檔案（須 fail closed）" "NOT recorded" "recorded" \
  || ok "無 marker 的檔案 -> fail closed，不判為已記錄"
unset VENDORED_FORKS

echo
echo "── 真實 corpus：修復後的分類必須完全符合已知事實 ──"

if [ -d "$AGENTS/skills" ]; then
  # 這是刻意的 tripwire,不是待維護的清單:新增或退役任何 skill 都會讓這條紅燈,直到有人
  # 回來更新它。那正是要的行為——「悄悄多了一個 vendored skill」本來就該被攔下來人工確認。
  # 與 CI 的「skill-index 與 skills/ 一致」不同:那條比對兩個生成產物,這條釘死已知事實。
  expect_vnd="agent-browser native-feel-cross-platform-desktop playwright-best-practices security-audit tailwind-v4-shadcn vueuse-functions"
  if [ -r "$AGENTS/stage-b2-skills.lock" ]; then
    stage_b2_vnd="$(awk -F '\t' '$0 !~ /^#/ { print $1 }' "$AGENTS/stage-b2-skills.lock" | paste -sd ' ' -)"
    expect_vnd="$expect_vnd $stage_b2_vnd"
  fi
  if [ -r "$AGENTS/mattpocock-skills.lock" ]; then
    locked=$(sed -n 's/^skill=//p' "$AGENTS/mattpocock-skills.lock")
    check "Matt lock 的 skill 數量" "22" "$(printf '%s\n' "$locked" | grep -c .)"
    expect_vnd="$expect_vnd $(printf '%s\n' "$locked" | tr '\n' ' ' | sed 's/ $//')"
  fi
  if [ -r "$AGENTS/vendored-skills.lock" ]; then
    generic_count=$(grep -vc '^#' "$AGENTS/vendored-skills.lock")
    check "generic provenance lock 的 skill 數量" "12" "$generic_count"
    while IFS=$'\t' read -r skill source revision expected_payload_sha expected_tree_sha; do
      case "$skill" in \#*|"") continue ;; esac
      actual_payload_sha=$(
        cd "$AGENTS/skills/$skill" &&
          find . -type f -print0 |
          LC_ALL=C sort -z |
          xargs -0 shasum -a 256 |
          shasum -a 256 |
          awk '{ print $1 }'
      )
      check "generic provenance lock 的 payload SHA：$skill" \
        "$expected_payload_sha" "$actual_payload_sha"
      actual_tree_sha="$(vendored_tree_sha256 "$AGENTS/skills/$skill")"
      check "generic provenance lock 的 tree SHA：$skill" \
        "$expected_tree_sha" "$actual_tree_sha"
      [[ "$revision" =~ ^[a-f0-9]{40}$ ]] ||
        bad "generic provenance lock 的 revision：$skill" "40-char SHA" "$revision"
      [ -n "$source" ] ||
        bad "generic provenance lock 的 source_url：$skill" "非空" "(空)"
    done < "$AGENTS/vendored-skills.lock"
  fi
  actual=""
  for sd in "$AGENTS"/skills/*/; do
    [ -f "$sd/SKILL.md" ] || continue
    case "$(vendored_flag "${sd%/}")" in
      VND) actual="$actual $(basename "${sd%/}")" ;;
    esac
  done
  actual=$(echo "$actual" | tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ' | sed 's/ $//')
  expected=$(echo "$expect_vnd" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')
  check "skills/ 的 VND 集合" "$expected" "$actual"
else
  echo "  SKIP  找不到 $AGENTS/skills"
fi

echo
echo "$PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ]
