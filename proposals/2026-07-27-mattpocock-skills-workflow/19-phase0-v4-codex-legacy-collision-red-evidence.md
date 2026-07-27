# Phase 0 v4 Codex legacy collision RED evidence

> 觀測時區：Asia/Taipei。isolated candidate；本階段只有 Phase 0 與 RED，
> 未授權 fix、live deployment 或新 SaaS probe。

## Phase 0 — live 與 evidence revalidation

- 2026-07-27 20:28–20:35：
  - `~/.agents/main` =
    `1779337af1c8de9920b6de99c36db2ba64ed8b70`，tracked clean；既有
    proposal/audit untracked files未修改或納入 candidate。
  - `~/.claude/main` =
    `971f3015517267c7e070dff31b1a68a7d4ea04c4`；僅既有 dirty
    `settings.json`，staged count = 0。
  - `settings.json` SHA-256 =
    `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`，
    mode `-rw-r--r--`，size 10647，mtime
    `2026-07-27T10:03:05+0800`。
- agents/Claude v2、v3 branches與四個 evidence worktrees皆存在且clean。
  v2 heads是後續 rollback/live v3歷史的 ancestors；v3 heads等於目前live heads。
- rollback backups `20260727-193338-matt-v2` 與
  `20260727-201712-matt-v3` 皆存在。
- Superpowers 6.2.0仍存在於Codex、Claude與Copilot；Phase 6不在scope。
- `agents-sync --check`、`agents-sync --doctor`、Claude collision guard、
  Matt workflow contracts皆PASS；現有legacy guard為4 wrappers / 4 mappings PASS。
- v4建立前，branch/worktree皆不存在。v4由目前live v3 HEAD透過：

  ```sh
  AGENTS_WORKTREE_ROOT=/private/tmp/agents-worktrees \
    ~/.agents/bin/agents-branch codex/mattpocock-workflow-migration-v4
  ```

  建於
  `/private/tmp/agents-worktrees/codex/mattpocock-workflow-migration-v4`。
  `~/.agents`維持`main`；Claude未建立v4 worktree，因本階段不改Claude surface。

## Mapping revalidation

| retired legacy wrapper | implicit replacement | explicit/manual compatibility |
|---|---|---|
| `mp-diagnose` | `diagnosing-bugs` | legacy wrapper |
| `mp-grill-with-docs` | `grilling` + `domain-modeling` | `/grill-with-docs` |
| `mp-improve-codebase-architecture` | `codebase-design` | `/improve-codebase-architecture` |
| `mp-tdd` | `tdd` | legacy wrapper |

Mapping由`core/routing.md`、`skills/dev-workflow/SKILL.md`、四個legacy
wrappers及其replacement skills重新核對；`mp-zoom-out`仍無replacement，不列入。

## Reproduction 與 contract

Codex CLI 0.145.0以fresh `--ephemeral --sandbox read-only --json` context，
同一explicit routing prompt連續兩次回覆：

```text
implicit: grilling, domain-modeling, codebase-design, tdd
explicit: mp-grill-with-docs, mp-improve-codebase-architecture
```

兩次event stream皆無tool-call event。Claude 2.1.220以tools disabled的fresh
session回覆canonical explicit routes，故問題限定為Codex inventory/policy。

Fresh Codex manual說明：

- Codex initial skill list含skill name、description與path；超過2% context budget時
  先縮短description。
- Codex的host-native invocation policy位於`agents/openai.yaml`：
  `policy.allow_implicit_invocation: false`會禁止implicit invocation，同時保留
  explicit `$skill`。

四個legacy wrappers目前只有`SKILL.md`的
`disable-model-invocation: true`，都缺少Codex-native policy；fresh
`codex debug prompt-input`仍列出它們。現有guard因此對Codex形成false green。

## RED regression

`tests/legacy-mp-collision.sh`沿用單一4-row mapping來源，新增：

1. 每個retired wrapper必須具有
   `agents/openai.yaml` →
   `policy.allow_implicit_invocation: false`。
2. Synthetic fixture為四個wrapper建立正確policy後應PASS。
3. Synthetic fixture逐一把policy改為`true`；guard若未FAIL則selftest失敗。

Synthetic selftest：

```text
PASS  legacy mp collision selftest
```

真實v4 tree連跑兩次均為exit 1：

```text
FAIL  legacy wrapper lacks Codex invocation-off policy: mp-diagnose
FAIL  legacy wrapper lacks Codex invocation-off policy: mp-grill-with-docs
FAIL  legacy wrapper lacks Codex invocation-off policy: mp-improve-codebase-architecture
FAIL  legacy wrapper lacks Codex invocation-off policy: mp-tdd
RED exit codes: 1 1
```

Live v3原test仍PASS，證明RED只存在isolated v4 candidate。

以candidate root重跑既有lint carrier亦為RED：

```sh
AGENTS_HOME="$PWD" \
  CLAUDE_GLOBAL_FILE=/Users/pochientsai/.claude/CLAUDE.md \
  ./bin/agents-sync --check
```

輸出`[lint9 FAIL]`且exit 1。未設定`AGENTS_HOME`時工具按設計驗證live
`~/.agents`，不可當成candidate結果。

## Stop gate

- 本階段不加入任何`agents/openai.yaml`，不修改routing或generated dist。
- 不執行`agents-sync --bootstrap`、`setup-matt-pocock-skills`、
  `scripts/link-skills.sh`或SaaS prompt。
- Codex-native policy是必要條件，不自行宣稱足以保證model輸出；未來GREEN後仍須
  fresh Codex zero-tool canary。
- 下一階段需使用者另行授權才可加入最小fix並跑GREEN。

## Rollback

此candidate未部署。放棄時只需移除v4 worktree/branch；live v3、Claude
`settings.json`、v2/v3 evidence與Superpowers均不需變更。
