#!/usr/bin/env bash
# [INT-10] Git-native pre-push hook 回歸測試。
set -ufo pipefail

# Fixture 不得繼承 caller 的 global/system hooksPath 或其他 Git 設定。
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd -P)"
HOOK="${HOOK:-$ROOT/hooks/pre-push-global-config.sh}"
pass=0
fail=0

has_managed_artifact() {
  local home="$1" name hooks_dir
  for name in .agents .claude .codex .copilot; do
    hooks_dir="$home/$name/.git/hooks"
    if [ -e "$hooks_dir/pre-push" ] || [ -L "$hooks_dir/pre-push" ] \
       || [ -e "$hooks_dir/.pre-push-int10-managed" ] || [ -L "$hooks_dir/.pre-push-int10-managed" ]; then
      return 0
    fi
  done
  return 1
}

expect_deny() {
  local description="$1" input="$2" out rc
  out=$(printf '%s\n' "$input" | bash "$HOOK" origin example.invalid 2>&1)
  rc=$?
  if [ "$rc" -eq 1 ] && case "$out" in *'[INT-10]'*) true;; *) false;; esac; then
    printf '  PASS  deny  %s\n' "$description"
    pass=$((pass + 1))
  else
    printf '  FAIL  deny  %s (rc=%s) %s\n' "$description" "$rc" "${out:0:120}" >&2
    fail=$((fail + 1))
  fi
}

expect_allow() {
  local description="$1" input="$2" out rc
  out=$(printf '%s\n' "$input" | bash "$HOOK" origin example.invalid 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    printf '  PASS  allow %s\n' "$description"
    pass=$((pass + 1))
  else
    printf '  FAIL  allow %s (rc=%s) %s\n' "$description" "$rc" "${out:0:120}" >&2
    fail=$((fail + 1))
  fi
}

expect_deny '直接更新 main' \
  'refs/heads/feature 1111111111111111111111111111111111111111 refs/heads/main 2222222222222222222222222222222222222222'
expect_deny '直接更新 master' \
  'refs/heads/feature 1111111111111111111111111111111111111111 refs/heads/master 2222222222222222222222222222222222222222'
expect_deny '明示刪除 main' \
  '(delete) 0000000000000000000000000000000000000000 refs/heads/main 2222222222222222222222222222222222222222'
expect_deny '多 ref 中包含 main' \
  $'refs/heads/feature 1111111111111111111111111111111111111111 refs/heads/feature 2222222222222222222222222222222222222222\nrefs/heads/topic 3333333333333333333333333333333333333333 refs/heads/main 4444444444444444444444444444444444444444'
expect_allow 'feature branch' \
  'refs/heads/feature 1111111111111111111111111111111111111111 refs/heads/feature 2222222222222222222222222222222222222222'
eof_out=$(bash "$HOOK" origin example.invalid </dev/null 2>&1)
eof_rc=$?
if [ "$eof_rc" -eq 0 ] && [ -z "$eof_out" ]; then
  printf '  PASS  allow empty stdin EOF\n'
  pass=$((pass + 1))
else
  printf '  FAIL  allow empty stdin EOF (rc=%s) %s\n' "$eof_rc" "${eof_out:0:120}" >&2
  fail=$((fail + 1))
fi

help_out=$(bash "$ROOT/hooks/install-hooks.sh" --help 2>&1)
help_rc=$?
if [ "$help_rc" -eq 0 ] && grep -Fq '安裝步驟，不是自動生效的' <<< "$help_out"; then
  printf '  PASS  help  完整輸出開頭說明\n'
  pass=$((pass + 1))
else
  printf '  FAIL  help  開頭說明遭截斷 (rc=%s) %s\n' "$help_rc" "${help_out:0:120}" >&2
  fail=$((fail + 1))
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/prepushguard.XXXXXX")" || exit 1
trap 'rm -rf "$scratch"' EXIT
fixture="$scratch/source"
fake_home="$scratch/home"
mkdir -p "$fixture/hooks" "$fake_home"
git -C "$fixture" init -q
git -C "$fixture" config user.email test@example.invalid
git -C "$fixture" config user.name test
cp "$ROOT/hooks/install-hooks.sh" "$ROOT/hooks/pre-commit-agents.sh" \
   "$ROOT/hooks/post-checkout-agents.sh" "$HOOK" "$fixture/hooks/"
git -C "$fixture" add hooks || exit 1
git -C "$fixture" commit -q -m source || exit 1
git -C "$fixture" branch -M main
source_remote="$scratch/source-remote.git"
git init --bare -q "$source_remote" || exit 1
git --git-dir "$source_remote" symbolic-ref HEAD refs/heads/main
git -C "$fixture" remote add origin "$source_remote"
git -C "$fixture" push -q -u origin main || exit 1

mk_target_home() {
  local home="$1" name
  for name in .agents .claude .codex .copilot; do
    mkdir -p "$home/$name"
    git -C "$home/$name" init -q
  done
}

stamp_matches_hook() {
  local home="$1" name="$2" hook stamp expected
  hook="$home/$name/.git/hooks/pre-push"
  stamp="$home/$name/.git/hooks/.pre-push-int10-managed"
  [ -f "$hook" ] && [ -f "$stamp" ] || return 1
  expected="$(git -C "$fixture" hash-object --no-filters -- "$hook")" || return 1
  [ "$(< "$stamp")" = "$expected" ]
}

mk_target_home "$fake_home"

candidate_home="$scratch/candidate-home"
candidate_source="$scratch/candidate-source"
git clone -q "$fixture" "$candidate_source" || exit 1
git -C "$candidate_source" checkout -q -b feature
mk_target_home "$candidate_home"
candidate_out=$(HOME="$candidate_home" bash "$candidate_source/hooks/install-hooks.sh" --global-pre-push 2>&1)
candidate_rc=$?
if [ "$candidate_rc" -ne 0 ] && ! has_managed_artifact "$candidate_home"; then
  printf '  PASS  install  feature branch 拒絕部署\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  feature branch 拒絕部署 (rc=%s) %s\n' \
    "$candidate_rc" "${candidate_out:0:120}" >&2
  fail=$((fail + 1))
fi

dirty_home="$scratch/dirty-home"
mk_target_home "$dirty_home"
printf '# dirty candidate\n' >> "$fixture/hooks/pre-push-global-config.sh"
dirty_out=$(HOME="$dirty_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
dirty_rc=$?
git -C "$fixture" restore hooks/pre-push-global-config.sh
if [ "$dirty_rc" -ne 0 ] && ! has_managed_artifact "$dirty_home"; then
  printf '  PASS  install  dirty main 拒絕部署\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  dirty main 拒絕部署 (rc=%s) %s\n' \
    "$dirty_rc" "${dirty_out:0:120}" >&2
  fail=$((fail + 1))
fi

assume_home="$scratch/assume-unchanged-home"
mk_target_home "$assume_home"
git -C "$fixture" update-index --assume-unchanged hooks/pre-push-global-config.sh
printf '# hidden dirty payload\n' >> "$fixture/hooks/pre-push-global-config.sh"
assume_out=$(HOME="$assume_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
assume_rc=$?
git -C "$fixture" update-index --no-assume-unchanged hooks/pre-push-global-config.sh
git -C "$fixture" restore hooks/pre-push-global-config.sh
if [ "$assume_rc" -ne 0 ] && ! has_managed_artifact "$assume_home"; then
  printf '  PASS  install  assume-unchanged dirty payload 拒絕部署\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  assume-unchanged dirty payload 拒絕部署 (rc=%s) %s\n' \
    "$assume_rc" "${assume_out:0:120}" >&2
  fail=$((fail + 1))
fi

dirty_installer_home="$scratch/dirty-installer-home"
mk_target_home "$dirty_installer_home"
printf '# dirty installer\n' >> "$fixture/hooks/install-hooks.sh"
dirty_installer_out=$(HOME="$dirty_installer_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
dirty_installer_rc=$?
git -C "$fixture" restore hooks/install-hooks.sh
if [ "$dirty_installer_rc" -ne 0 ] && ! has_managed_artifact "$dirty_installer_home"; then
  printf '  PASS  install  dirty installer 拒絕部署\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  dirty installer 拒絕部署 (rc=%s) %s\n' \
    "$dirty_installer_rc" "${dirty_installer_out:0:120}" >&2
  fail=$((fail + 1))
fi

ahead_home="$scratch/ahead-home"
mk_target_home "$ahead_home"
git -C "$fixture" commit -q --allow-empty -m ahead || exit 1
ahead_out=$(HOME="$ahead_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
ahead_rc=$?
git -C "$fixture" reset -q --hard '@{upstream}'
if [ "$ahead_rc" -ne 0 ] && ! has_managed_artifact "$ahead_home"; then
  printf '  PASS  install  ahead main 拒絕部署\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  ahead main 拒絕部署 (rc=%s) %s\n' \
    "$ahead_rc" "${ahead_out:0:120}" >&2
  fail=$((fail + 1))
fi

nested_home="$scratch/nested-home"
mkdir -p "$nested_home"/{.agents,.claude,.codex,.copilot}
git -C "$nested_home" init -q
nested_out=$(HOME="$nested_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
nested_rc=$?
if [ "$nested_rc" -ne 0 ] && [ ! -e "$nested_home/.git/hooks/pre-push" ]; then
  printf '  PASS  install  上層 repo 不得冒充四個 target\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  上層 repo 不得冒充四個 target (rc=%s) %s\n' \
    "$nested_rc" "${nested_out:0:120}" >&2
  fail=$((fail + 1))
fi

custom_home="$scratch/custom-hooks-home"
mk_target_home "$custom_home"
custom_dir="$scratch/shared-hooks"
git -C "$custom_home/.claude" config core.hooksPath "$custom_dir"
custom_out=$(HOME="$custom_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
custom_rc=$?
if [ "$custom_rc" -ne 0 ] && ! has_managed_artifact "$custom_home" \
   && [ ! -e "$custom_dir/pre-push" ]; then
  printf '  PASS  install  自訂 core.hooksPath 拒絕且零寫入\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  自訂 core.hooksPath 拒絕且零寫入 (rc=%s) %s\n' \
    "$custom_rc" "${custom_out:0:120}" >&2
  fail=$((fail + 1))
fi

symlink_home="$scratch/symlink-hooks-home"
mk_target_home "$symlink_home"
shared_hooks="$scratch/shared-hooks"
mkdir -p "$shared_hooks"
mv "$symlink_home/.claude/.git/hooks" "$symlink_home/.claude/.git/hooks.original"
ln -s "$shared_hooks" "$symlink_home/.claude/.git/hooks"
symlink_out=$(HOME="$symlink_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
symlink_rc=$?
if [ "$symlink_rc" -ne 0 ] && ! has_managed_artifact "$symlink_home" \
   && [ ! -e "$shared_hooks/pre-push" ]; then
  printf '  PASS  install  symlink hooks dir 拒絕且零寫入\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  symlink hooks dir 拒絕且零寫入 (rc=%s) %s\n' \
    "$symlink_rc" "${symlink_out:0:120}" >&2
  fail=$((fail + 1))
fi

default_out=$(HOME="$fake_home" bash "$fixture/hooks/install-hooks.sh" 2>&1)
default_rc=$?
if [ "$default_rc" -eq 0 ] && ! has_managed_artifact "$fake_home"; then
  printf '  PASS  install  default mode 不跨 repo\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  default mode 不跨 repo (rc=%s) %s\n' \
    "$default_rc" "${default_out:0:120}" >&2
  fail=$((fail + 1))
fi

install_out=$(HOME="$fake_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
install_rc=$?
installed=1
for name in .agents .claude .codex .copilot; do
  dst="$fake_home/$name/.git/hooks/pre-push"
  [ -x "$dst" ] && cmp -s "$HOOK" "$dst" && stamp_matches_hook "$fake_home" "$name" \
    || installed=0
done
if [ "$install_rc" -eq 0 ] && [ "$installed" -eq 1 ]; then
  printf '  PASS  install  四個受 INT-10 保護的 repo\n'
  pass=$((pass + 1))
else
  printf '  FAIL  install  四個受 INT-10 保護的 repo (rc=%s) %s\n' \
    "$install_rc" "${install_out:0:120}" >&2
  fail=$((fail + 1))
fi

printf '# tampered managed hook\n' >> "$fake_home/.claude/.git/hooks/pre-push"
tamper_install_out=$(HOME="$fake_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
tamper_install_rc=$?
tamper_remove_out=$(HOME="$fake_home" bash "$fixture/hooks/install-hooks.sh" --remove-global-pre-push 2>&1)
tamper_remove_rc=$?
tamper_preserved=1
for name in .agents .claude .codex .copilot; do
  [ -e "$fake_home/$name/.git/hooks/pre-push" ] || tamper_preserved=0
done
if [ "$tamper_install_rc" -ne 0 ] && [ "$tamper_remove_rc" -ne 0 ] \
   && [ "$tamper_preserved" -eq 1 ] \
   && grep -Fq '# tampered managed hook' "$fake_home/.claude/.git/hooks/pre-push"; then
  printf '  PASS  preserve tampered managed hook 且零部分變更\n'
  pass=$((pass + 1))
else
  printf '  FAIL  preserve tampered managed hook (install_rc=%s remove_rc=%s) %s %s\n' \
    "$tamper_install_rc" "$tamper_remove_rc" "${tamper_install_out:0:80}" "${tamper_remove_out:0:80}" >&2
  fail=$((fail + 1))
fi
install -m 0755 "$fixture/hooks/pre-push-global-config.sh" "$fake_home/.claude/.git/hooks/pre-push"

rollback_home="$scratch/rollback-old-home"
mk_target_home "$rollback_home"
HOME="$rollback_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push >/dev/null 2>&1 || exit 1
git -C "$rollback_home/.claude" config core.hooksPath "$scratch/later-custom-hooks"

printf '# published v2\n' >> "$fixture/hooks/pre-push-global-config.sh"
git -C "$fixture" add hooks/pre-push-global-config.sh || exit 1
git -C "$fixture" commit -q -m v2 || exit 1
git -C "$fixture" push -q origin main || exit 1

upgrade_out=$(HOME="$fake_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
upgrade_rc=$?
upgraded=1
for name in .agents .claude .codex .copilot; do
  dst="$fake_home/$name/.git/hooks/pre-push"
  [ -x "$dst" ] && cmp -s "$fixture/hooks/pre-push-global-config.sh" "$dst" \
    && stamp_matches_hook "$fake_home" "$name" || upgraded=0
done
if [ "$upgrade_rc" -eq 0 ] && [ "$upgraded" -eq 1 ]; then
  printf '  PASS  upgrade 先前 managed pre-push 到 published v2\n'
  pass=$((pass + 1))
else
  printf '  FAIL  upgrade 先前 managed pre-push 到 published v2 (rc=%s) %s\n' \
    "$upgrade_rc" "${upgrade_out:0:120}" >&2
  fail=$((fail + 1))
fi

rollback_old_out=$(HOME="$rollback_home" bash "$fixture/hooks/install-hooks.sh" --remove-global-pre-push 2>&1)
rollback_old_rc=$?
rollback_old_removed=1
for name in .agents .claude .codex .copilot; do
  [ ! -e "$rollback_home/$name/.git/hooks/pre-push" ] \
    && [ ! -e "$rollback_home/$name/.git/hooks/.pre-push-int10-managed" ] || rollback_old_removed=0
done
if [ "$rollback_old_rc" -eq 0 ] && [ "$rollback_old_removed" -eq 1 ]; then
  printf '  PASS  remove   舊版 managed hook 且忽略後設 core.hooksPath\n'
  pass=$((pass + 1))
else
  printf '  FAIL  remove   舊版 managed hook 且忽略後設 core.hooksPath (rc=%s) %s\n' \
    "$rollback_old_rc" "${rollback_old_out:0:120}" >&2
  fail=$((fail + 1))
fi

# Git config 決定 refspec 時，pre-push 收到的仍是解析後 remote ref。
remote="$scratch/remote.git"
repo="$fake_home/.agents"
git init --bare -q "$remote" || exit 1
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name test
git -C "$repo" commit -q --allow-empty -m initial || exit 1
git -C "$repo" branch -M feature
git -C "$repo" remote add origin "$remote"
git -C "$repo" push -q origin HEAD:refs/heads/feature || exit 1
git -C "$repo" config remote.origin.push HEAD:refs/heads/main
push_out=$(git -C "$repo" push origin 2>&1)
push_rc=$?
if [ "$push_rc" -ne 0 ] && case "$push_out" in *'[INT-10]'*) true;; *) false;; esac \
   && ! git --git-dir "$remote" show-ref --verify --quiet refs/heads/main; then
  printf '  PASS  deny  config-derived main push\n'
  pass=$((pass + 1))
else
  printf '  FAIL  deny  config-derived main push (rc=%s) %s\n' \
    "$push_rc" "${push_out:0:120}" >&2
  fail=$((fail + 1))
fi

remove_out=$(HOME="$fake_home" bash "$fixture/hooks/install-hooks.sh" --remove-global-pre-push 2>&1)
remove_rc=$?
removed=1
for name in .agents .claude .codex .copilot; do
  [ ! -e "$fake_home/$name/.git/hooks/pre-push" ] \
    && [ ! -e "$fake_home/$name/.git/hooks/.pre-push-int10-managed" ] || removed=0
done
if [ "$remove_rc" -eq 0 ] && [ "$removed" -eq 1 ]; then
  printf '  PASS  remove   四個 managed pre-push\n'
  pass=$((pass + 1))
else
  printf '  FAIL  remove   四個 managed pre-push (rc=%s) %s\n' \
    "$remove_rc" "${remove_out:0:120}" >&2
  fail=$((fail + 1))
fi

foreign="$fake_home/.claude/.git/hooks/pre-push"
printf '#!/usr/bin/env bash\n# foreign hook\nexit 0\n' > "$foreign"
chmod +x "$foreign"
foreign_out=$(HOME="$fake_home" bash "$fixture/hooks/install-hooks.sh" --global-pre-push 2>&1)
foreign_rc=$?
foreign_leaked=0
for name in .agents .codex .copilot; do
  hooks_dir="$fake_home/$name/.git/hooks"
  if [ -e "$hooks_dir/pre-push" ] || [ -e "$hooks_dir/.pre-push-int10-managed" ]; then
    foreign_leaked=1
  fi
done
if [ "$foreign_rc" -ne 0 ] && grep -Fq '# foreign hook' "$foreign" \
   && [ "$foreign_leaked" -eq 0 ]; then
  printf '  PASS  preserve 非本工具管理的 pre-push 且零部分部署\n'
  pass=$((pass + 1))
else
  printf '  FAIL  preserve 非本工具管理的 pre-push 且零部分部署 (rc=%s) %s\n' \
    "$foreign_rc" "${foreign_out:0:120}" >&2
  fail=$((fail + 1))
fi

printf '\n%s PASS / %s FAIL\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
