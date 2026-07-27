# Phase 3 v3 legacy collision candidate evidence

> 觀測時區：Asia/Taipei。candidate only；未授權 live deployment 或新 SaaS probe。

## Phase 0 — rollback baseline revalidation

- 2026-07-27 19:51–19:54：`~/.agents/main` 為
  `2381310fb3b4079ec51b562e0e45befeb5478d4b`；除 proposal untracked files 外無
  tracked dirty change。相對 `678ab6d3c13dcd14626617e6981ee33ad17d4e04`
  僅 generated provenance 不同，兩個 dist body 與 manifest semantic payload 相同。
- 同時段：`~/.claude/main` 為
  `0ec3427f807f186bcc6b23203fd5ff7245480d76`；tracked tree 等同
  `20554ed154029bb39b55edfb6b1188098fc2750a`。既有 dirty
  `settings.json` SHA-256 為
  `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`，
  本 candidate 不修改、stage 或 commit 該檔。
- rollback backup
  `/Users/pochientsai/.agents-deployment-backups/20260727-193338-matt-v2`
  存在；backup body 與 live rollback body 相同。
- v2 agents `1014c669e17f3bb2d8e52d27f32b07752f14a84a` 與 Claude
  `15194360a385c4f239a2a74d8e2cea501abf14ba` branches/worktrees 存在、
  clean，且 ancestry 回到各自 rollback baseline。v2 evidence 保留未修改。
- Superpowers 在 Codex、Claude、Copilot 均仍安裝；Phase 6 不在本次 scope。

## Collision mapping

| retired legacy model route | model-invocable replacement | manual explicit compatibility |
|---|---|---|
| `mp-diagnose` | `diagnosing-bugs` | legacy wrapper 保留，可手動 invoke |
| `mp-grill-with-docs` | `grilling` + `domain-modeling` | `/grill-with-docs` |
| `mp-improve-codebase-architecture` | `codebase-design` | `/improve-codebase-architecture` |
| `mp-tdd` | `tdd` | legacy wrapper 保留，可手動 invoke |

Mapping 由 proposal、`core/routing.md`、`skills/dev-workflow/SKILL.md`、四個 legacy
wrapper 與對應 Matt `SKILL.md` 逐項核對。`mp-zoom-out` 沒有 replacement，故不列入
retired guard 且維持 model-invocable。

## RED → GREEN

1. `fd2b437` 先加入 `tests/legacy-mp-collision.sh`。它檢查全部四個 mapping，
   並以 synthetic fixtures 逐一移除 wrapper metadata 或 replacement，確認 guard
   真的會紅。
2. 對完整 v2 inventory 執行時，四個 wrapper 都因缺少
   `disable-model-invocation: true` 而 FAIL；exit 1。
3. `171c054` 只在四個 wrapper frontmatter 加入
   `disable-model-invocation: true`，不刪除 wrapper、不改 Matt vendored payload。
4. GREEN：`PASS legacy mp collision guard: 4 wrappers / 4 mappings`；
   synthetic selftest 同時 PASS。
5. `f6dc0fe` 將 guard 接入 `agents-sync` lint、conformance 與 CI，避免 candidate
   或後續 sync 回歸。

## Isolated candidates

- agents：`codex/mattpocock-workflow-migration-v3`，由 live rollback
  `2381310f` 透過 `AGENTS_WORKTREE_ROOT=/private/tmp/agents-worktrees
  ~/.agents/bin/agents-branch` 建立。
- Claude：`codex/mattpocock-workflow-migration-v3`，由 live rollback
  `0ec3427f` 建立 isolated worktree。
- agents v2 Phase 1–3 commits 逐 commit replay；generated dist conflict 經
  `git diff --cc` 確認只屬 source provenance，再由 candidate generator 重生。
- Claude candidate 包含 neutral routing、managed stamp 及 22 個 version-controlled
  Matt skill symlinks；每個 target 為 `../../.agents/skills/<name>`。

## Verification

| Gate | Result |
|---|---|
| legacy collision selftest / real guard | PASS / PASS，4 wrappers、4 mappings |
| Matt workflow contracts | PASS，54 / 0 |
| vendored detection | PASS，33 / 0 |
| `agents-sync --check` with candidate Claude | PASS |
| scratch body / stamp / manifest equality | PASS / PASS / PASS |
| conformance candidate pairing | PASS，17 / 0 |
| version tripwire / selftest | PASS，44 clear；44 trigger / 0 stale |
| Codex / shared git push guard | PASS，12 / 0；68 / 0 |
| `bash -n` | PASS，11 changed shell files |
| `shellcheck` | UNAVAILABLE，本機無 executable；CI gate 保留 |
| byte budgets | Codex 8425 / 10240；Copilot 9165 / 10240；Claude context 14370 / 25600 |
| `git diff --check` | PASS，agents + Claude |
| vendored payload drift after import | PASS，22 / 22 unchanged |
| live deployment/settings fingerprints | PASS，conformance restore 後逐 hash 相同 |

未執行 `setup-matt-pocock-skills`、`scripts/link-skills.sh`、新 Copilot/Claude/Codex
SaaS probe、live deployment、Superpowers 移除或 Matt 新版自動偵測。

## Atomic deployment sequence

1. 再驗證兩個 live HEAD、dirty attribution、backup 與 deployment/settings
   fingerprints；任一不符即停止。
2. 先把 Claude main 推進到 neutral routing commit `a14ab27`，跑 unmanaged routing
   collision guard；失敗即 revert 該 commit。
3. 再把 agents main 推進完整 v3 range，逐 commit 驗證 lint、workflow contracts、
   vendored detection 與 collision guard；失敗即停止，不 bootstrap。
4. agents skills 已存在後，把 Claude main 推進 managed stamp `b180f19` 與 22 links
   `971f301`，驗證 stamp 與每個 tracked symlink target。
5. 只在上述全綠後執行一次 `agents-sync --bootstrap`，再跑 doctor、paired
   conformance、body/stamp/manifest equality、byte budgets 與 live fingerprints。
6. 僅在使用者另行回覆
   `部署v3 candidate；允許兩個Copilot零工具prompt`
   後，執行既定兩個 Copilot canary prompts。任一 explicit route 仍命中
   `mp-*` 即判定 candidate blocker，停止後續 phase。

## Rollback

- bootstrap 前：依相反順序 revert Claude links/stamp/neutral commits與 agents v3
  commits；不 reset、不 force-push、不碰 `settings.json`。
- bootstrap 後：先 revert candidate commits，再用
  `/Users/pochientsai/.agents-deployment-backups/20260727-193338-matt-v2`
  恢復三端 deployment body，重跑 bootstrap/doctor/conformance 與 hash probe。
- 任一 rollback 不移除 Superpowers，也不刪 legacy wrappers 或 v2/v3 evidence
  branches/worktrees。

## Residual risk

- `disable-model-invocation` metadata 是否足以讓 Copilot inventory 排除 legacy
  wrappers，仍須 deployment canary 的兩個已定義零工具 prompts 證實；本輪不消耗
  新 probe。
- 若 Copilot 不尊重 metadata，本 candidate 只回報 blocker；不自行擴大為 wrapper
  大量刪除或歸檔。
- Matt upstream 自動偵測刻意延後為 collision candidate 成功部署後的獨立
  candidate，避免 failure attribution 混雜。
