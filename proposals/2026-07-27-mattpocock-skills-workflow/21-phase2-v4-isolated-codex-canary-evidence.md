# Phase 2 v4 isolated Codex canary evidence

> 觀測時區：Asia/Taipei。只驗證isolated v4 candidate；未部署live。

## Candidate and isolation

- Candidate branch：`codex/mattpocock-workflow-migration-v4`
- Canary-tested commit：`7e10627d4425d2ec71592aaa74f770b1eafe9e44`
- Candidate worktree：
  `/private/tmp/agents-worktrees/codex/mattpocock-workflow-migration-v4`
- Scratch HOME：`/private/tmp/codex-v4-canary-home.cVRFkc`
- Scratch CWD：`/private/tmp/codex-v4-canary-home.cVRFkc/empty`
- `CODEX_HOME`：`/Users/pochientsai/.codex`
- CLI：`codex-cli 0.145.0`
- Flags：`--ephemeral --sandbox read-only --skip-git-repo-check --json`

Local-only `codex debug prompt-input x` preflight：

```text
ROOT - `r1` = `/private/tmp/agents-worktrees/codex/mattpocock-workflow-migration-v4/skills`
COUNTS root=1 live_root=0 diagnosing-bugs=1 grilling=1 domain-modeling=1
codebase-design=1 tdd=1 mp-diagnose=0 mp-grill-with-docs=0
mp-improve-codebase-architecture=0 mp-tdd=0
ROUTING route-grill=1 route-architecture=1
```

## Zero-tool prompt 1

Prompt：

```text
只根據自動載入的本機 skill/instruction context，不使用工具：遇到「測試失敗，需要先重現並修正 regression」時，應先載入哪個 canonical workflow skill，再路由到哪個診斷 skill？只輸出兩個 skill names，依順序。
```

Actual：

```text
dev-workflow
diagnosing-bugs
```

Result：PASS。JSONL event stream只有`thread.started`、warnings、`turn.started`、
`agent_message`與`turn.completed`；tool call數為0。

## Zero-tool prompt 2

Prompt：

```text
只根據自動載入的本機 skill/instruction context，不使用工具：需求壓測、架構設計、TDD 分別路由到哪些 skills？另列出兩個必須由使用者顯式 prompt 才啟用的 Matt skills。只輸出 implicit 與 explicit skill names。
```

Actual：

```text
implicit: grilling, domain-modeling, codebase-design, tdd
explicit: /grill-with-docs, /improve-codebase-architecture
```

Result：PASS。四個implicit replacements與兩個explicit Matt routes全數吻合，
沒有任何`mp-*` route；tool call數為0。

## Postflight

2026-07-27 20:52 Asia/Taipei：

- `~/.agents`仍為`main`，
  `1779337af1c8de9920b6de99c36db2ba64ed8b70`，staged 0
- `~/.claude`仍為`main`，
  `971f3015517267c7e070dff31b1a68a7d4ea04c4`，staged 0
- `~/.claude/settings.json` SHA-256仍為
  `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- Candidate在寫入本evidence前為clean
- 未執行bootstrap、live deployment、push或PR

## Residual warnings

兩次Codex child process皆輸出：

- SessionEnd hook timeout被clamp為3秒
- skill descriptions因2% context budget而縮短

兩項warning均未造成tool call或route偏差，但deployment後canary仍應記錄並比較。

## Gate

v4 isolated Codex canary：PASS。下一步仍需使用者另行明示授權live
deployment；不得把本次canary授權解讀為deployment授權。
