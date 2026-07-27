# Phase 3 v4 live deployment and Codex canary evidence

> 觀測時區：Asia/Taipei。2026-07-27完成v4 live deployment；只變更
> `~/.agents/main`，未修改Claude、Copilot、Superpowers或既有dirty/untracked
> changes。

## Preflight and rollback carrier

- Live agents：`main@1779337af1c8de9920b6de99c36db2ba64ed8b70`
- Candidate：
  `codex/mattpocock-workflow-migration-v4@29534f9a03b768210133ed51a85958a997c4ee6c`
- Candidate是live HEAD的直系後代，worktree clean。
- Live agents既有6個untracked paths與v4變更path交集為0。
- Live Claude：
  `main@971f3015517267c7e070dff31b1a68a7d4ea04c4`
- `~/.claude/settings.json`既有dirty fingerprint：
  `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- 新rollback carrier：
  `/Users/pochientsai/.agents-deployment-backups/20260727-205915-matt-v4`
  - `agents.bundle`含pre-deploy main與v4 candidate兩個refs及完整歷史
  - `AGENTS.md`、`CLAUDE.md`、`copilot-instructions.md`均已快照

## Security and release gates

- `gitleaks git --log-opts='--all'`：91 commits，0 leaks
- v4 commit range secret scan：4 commits，0 leaks
- `gitleaks dir`的224項均為既有`attic/ecpay`公開測試向量，
  rule皆為`generic-api-key`；與v4變更檔交集為0，未視為新secret finding
- Dependency manifest changes：0
- Container changes：0
- Dependency/container/SBOM gates：N/A，本次只部署skill metadata、regression
  guard與evidence

## Deployment

只執行一次live mutation：

```text
git -C /Users/pochientsai/.agents merge --ff-only \
  codex/mattpocock-workflow-migration-v4
```

結果：

```text
Updating 1779337..29534f9
Fast-forward
deployed_branch=main
deployed_head=29534f9a03b768210133ed51a85958a997c4ee6c
staged_count=0
```

未執行`agents-sync --bootstrap`，因v4未改deployment body source；部署後三家body
與pre-deploy backup byte-identical。

## Post-deployment verification

| Gate | Result |
|---|---|
| legacy collision selftest / live guard | PASS / PASS，4 wrappers / 4 mappings |
| Matt workflow contracts | 54 PASS / 0 FAIL |
| vendored detection | 33 PASS / 0 FAIL |
| version tripwire / selftest | 44 clear；44 trigger / 0 stale |
| Codex / shared push guards | 12 PASS / 0 FAIL；68 PASS / 0 FAIL |
| `agents-sync --check` / `--doctor` | PASS / PASS |
| live conformance | 17 PASS / 0 FAIL |
| Codex / Copilot byte budgets | 8425 / 10240；9165 / 10240 |
| `bash -n` / `git diff --check` | PASS / PASS |
| `shellcheck` | UNAVAILABLE；本機無executable |
| deployment body equality | PASS；三家與pre-deploy backup相同 |

Live local-only inventory：

```text
ROOT - `r1` = `/Users/pochientsai/.agents/skills`
COUNTS root=1 candidate_root=0 diagnosing-bugs=1 grilling=1
domain-modeling=1 codebase-design=1 tdd=1 mp-diagnose=0
mp-grill-with-docs=0 mp-improve-codebase-architecture=0 mp-tdd=0
ROUTING route-grill=1 route-architecture=1
```

## Live zero-tool Codex canaries

Prompt 1 actual：

```text
dev-workflow
diagnosing-bugs
```

Result：PASS；tool call數為0。

Prompt 2 actual：

```text
implicit: grilling, domain-modeling, codebase-design, tdd
explicit: grill-with-docs, improve-codebase-architecture
```

Result：PASS；四個implicit replacements與兩個Matt explicit skills全數正確，
沒有任何`mp-*`，tool call數為0。相較expected sample，model未在explicit names
前顯示`/`；canary prompt要求skill names，且既定stop condition是錯route或回
`mp-*`，因此這是presentation deviation，不是collision failure。

兩次prompt皆出現既知非阻塞warning：

- SessionEnd hook timeout被clamp為3秒
- skill descriptions因2% context budget而縮短

## Postflight and rollback

- Live agents既有6個untracked paths完整保留，staged 0。
- Live Claude HEAD與`settings.json` fingerprint未變。
- 未push、未開PR、未修改Claude/Copilot/Superpowers。

若後續發現v4 blocker：

1. 依反向順序revert v4 commits，不reset、不force-push main。
2. 若deployment body發生漂移，以
   `/Users/pochientsai/.agents-deployment-backups/20260727-205915-matt-v4`
   恢復三家body。
3. 重跑collision guard、`agents-sync --check/--doctor`、conformance與body
   fingerprints。
