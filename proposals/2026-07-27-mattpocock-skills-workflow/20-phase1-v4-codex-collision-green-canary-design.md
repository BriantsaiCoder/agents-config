# Phase 1 v4 Codex collision GREEN and isolated canary design

> 觀測時區：Asia/Taipei。isolated candidate；未授權live deployment或Codex
> SaaS prompt。

## Minimal fix

RED commit：

`102c4314bb7e9eb4b9d417aca3ce1e5fa7a9e65a`

GREEN commit：

`013da6d` `fix(codex): 關閉 legacy wrapper 隱式觸發`

只為四個retired wrappers各新增同一份2-line Codex-native metadata：

```yaml
policy:
  allow_implicit_invocation: false
```

修改範圍：

- `skills/mp-diagnose/agents/openai.yaml`
- `skills/mp-grill-with-docs/agents/openai.yaml`
- `skills/mp-improve-codebase-architecture/agents/openai.yaml`
- `skills/mp-tdd/agents/openai.yaml`

未修改legacy `SKILL.md`、Matt vendored payload、routing、generated dist、Claude或
Copilot surface。依fresh Codex manual，此policy關閉implicit invocation並保留
explicit `$skill` invocation。

## RED → GREEN

同一regression seam在fix前後輸出：

```text
RED
FAIL  legacy wrapper lacks Codex invocation-off policy: mp-diagnose
FAIL  legacy wrapper lacks Codex invocation-off policy: mp-grill-with-docs
FAIL  legacy wrapper lacks Codex invocation-off policy: mp-improve-codebase-architecture
FAIL  legacy wrapper lacks Codex invocation-off policy: mp-tdd

GREEN
PASS  legacy mp collision guard: 4 wrappers / 4 mappings
```

Synthetic selftest維持PASS；candidate
`AGENTS_HOME="$PWD" CLAUDE_GLOBAL_FILE=/Users/pochientsai/.claude/CLAUDE.md
./bin/agents-sync --check`由`[lint9 FAIL]`變為PASS。

## Verification

| Gate | Result |
|---|---|
| legacy collision selftest / real guard | PASS / PASS，4 wrappers / 4 mappings |
| Matt workflow contracts | 54 PASS / 0 FAIL |
| vendored detection | 33 PASS / 0 FAIL |
| version tripwire / selftest | 44 clear；44 trigger / 0 stale |
| Codex / shared git push guard | 12 / 0；68 / 0 |
| candidate `agents-sync --check` / `--doctor` | PASS / PASS |
| paired conformance | 17 PASS / 0 FAIL |
| Codex / Copilot byte budgets | 8425 / 10240；9165 / 10240 |
| `bash -n` / `git diff --check` | PASS / PASS |
| shellcheck | UNAVAILABLE；本機無executable |
| vendored payload | unchanged |

Conformance前後fingerprints相同：

- Codex body：
  `951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
- Claude body：
  `db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7`
- Claude settings：
  `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`

## Isolated Codex canary design

### Goal

在不切換live `~/.agents/main`、不bootstrap、不寫live skill tree的前提下，讓fresh
Codex只把v4 worktree視為user skill root。

### Environment

1. 建立`/private/tmp/codex-v4-canary-home.XXXXXX`。
2. 在其中建立`.agents/skills` symlink，target固定為：

   `/private/tmp/agents-worktrees/codex/mattpocock-workflow-migration-v4/skills`

3. 執行Codex child process時，將其`HOME`設為scratch home；`CODEX_HOME`仍指向
   `/Users/pochientsai/.codex`以重用既有auth/config。
4. CWD使用scratch home內的empty directory，避免repo-local skills加入inventory。
5. 固定`codex-cli 0.145.0`、`--ephemeral`、`--sandbox read-only`、
   `--skip-git-repo-check`、`--json`。

### Static preflight

先執行local-only `codex debug prompt-input x`，不呼叫model。必須同時成立：

- `r1` =
  `/private/tmp/agents-worktrees/codex/mattpocock-workflow-migration-v4/skills`
- live `/Users/pochientsai/.agents/skills`不是skill root
- `diagnosing-bugs`、`grilling`、`domain-modeling`、`codebase-design`、`tdd`
  各有一個skill entry
- `mp-diagnose`、`mp-grill-with-docs`、
  `mp-improve-codebase-architecture`、`mp-tdd` skill entries皆為0
- `/grill-with-docs`與`/improve-codebase-architecture`仍存在generated routing body

2026-07-27 20:44實跑static preflight已PASS；`r1`解析到v4 worktree，四個legacy
entries為0。這只證明隔離與inventory，不取代model canary。

### Zero-tool prompts

只有取得使用者另行授權後才執行。

Prompt 1：

```text
只根據自動載入的本機 skill/instruction context，不使用工具：遇到「測試失敗，需要先重現並修正 regression」時，應先載入哪個 canonical workflow skill，再路由到哪個診斷 skill？只輸出兩個 skill names，依順序。
```

Expected：

```text
dev-workflow
diagnosing-bugs
```

Prompt 2：

```text
只根據自動載入的本機 skill/instruction context，不使用工具：需求壓測、架構設計、TDD 分別路由到哪些 skills？另列出兩個必須由使用者顯式 prompt 才啟用的 Matt skills。只輸出 implicit 與 explicit skill names。
```

Expected：

```text
implicit: grilling + domain-modeling, codebase-design, tdd
explicit: /grill-with-docs, /improve-codebase-architecture
```

### Stop conditions

任一條成立即FAIL，不得部署：

- static preflight出現live user skill root或任一retired wrapper entry
- event stream出現tool call
- Prompt 1未回`dev-workflow`→`diagnosing-bugs`
- Prompt 2任何implicit route錯誤
- Prompt 2 explicit route回任何`mp-*`
- candidate/live HEAD、deployment body或Claude settings fingerprint發生非預期變更

## Rollback

Candidate未部署。撤回GREEN只需revert `013da6d`；RED commit與evidence可保留。
不得reset live main、修改Claude settings或移除Superpowers。
