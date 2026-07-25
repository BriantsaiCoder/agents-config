#!/bin/bash
# Pre-commit 守門（~/.agents）：阻擋 .bak 誤 commit（CONVENTIONS 11）+ gitleaks 明文 secret 掃描。
# 安裝：bash hooks/install-hooks.sh
# 繞過（謹慎）：git commit --no-verify

set -euo pipefail

RED='\033[0;31m'; YEL='\033[1;33m'; NC='\033[0m'
fail() { echo -e "${RED}[pre-commit] $*${NC}" >&2; }
warn() { echo -e "${YEL}[pre-commit] $*${NC}" >&2; }

errors=0
staged=$(git diff --cached --name-only --diff-filter=ACMR)
[[ -z "$staged" ]] && exit 0

# 1. .bak / .backup 阻擋（版控取代 .bak；要歷史用 git，不用副本檔）
while IFS= read -r f; do
  if [[ "$f" =~ \.bak(\.|-|$)|\.backup(\.|$) ]]; then
    fail "禁 .bak 類檔案進版控（CONVENTIONS 11）: $f"
    errors=$((errors + 1))
  fi
done <<< "$staged"

# 2. gitleaks staged 掃描（repo 有 .gitleaks.toml 才帶 --config，否則用內建 default；binary 缺失只警告不擋——擋 .bak 仍生效）
if command -v gitleaks >/dev/null 2>&1; then
  gl_cfg="$(git rev-parse --show-toplevel)/.gitleaks.toml"
  gl_args=(protect --staged --no-banner)
  [[ -f "$gl_cfg" ]] && gl_args+=(--config "$gl_cfg")
  if ! gitleaks "${gl_args[@]}" >/dev/null 2>&1; then
    fail "gitleaks 偵測到 staged 變更含疑似 secret（跑 gitleaks protect --staged -v 看細節，勿貼值）"
    errors=$((errors + 1))
  fi
else
  warn "gitleaks 未安裝，secret 掃描跳過（brew install gitleaks）"
fi

if (( errors > 0 )); then
  fail "共 $errors 項阻擋。修正後重試，或（確認安全後）git commit --no-verify"
  exit 1
fi
exit 0
