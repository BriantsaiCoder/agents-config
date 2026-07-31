<!-- tier: workflow-reference | consumed-by: claude,codex,copilot | parent: SKILL.md S5-2 | last-verified: 2026-07-31 -->

# Dirty working tree review package gate

在讀取任何 raw diff 前依序執行：

1. 只取得 metadata inventory：staged `git diff --cached --name-status`、unstaged `git diff --name-status`、untracked `git ls-files --others --exclude-standard`，以及 task 明列的 ignored candidate paths。
2. 依序執行 `gitleaks git --staged --redact`、`gitleaks git --pre-commit --redact`，以及 candidate paths 的 `gitleaks dir --redact`。
3. 任一 finding MUST 使 package assembly FAIL；命中的 raw file／hunk MUST omit，只保留 path、set／unset 與 redacted finding。
4. 全部掃描通過後才可讀取 staged `git diff --cached --` 與 unstaged `git diff --`；所有非敏感 untracked／ignored candidates 也 MUST 依下列大小／binary 規則納入 review package。
5. `.env*`、credentials、private keys、token stores 等 secret-bearing 內容 MUST NOT 傳全文。非敏感文字檔僅限 ≤256 KiB；binary 或超過 256 KiB 只傳 path、size、hash。

Evidence：三類 gitleaks exit code + package manifest。
