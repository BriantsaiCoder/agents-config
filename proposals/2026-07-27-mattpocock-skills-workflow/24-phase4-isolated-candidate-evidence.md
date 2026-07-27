# Phase 4 full cross-host A/B canary — isolated candidate evidence

> 日期：2026-07-27 Asia/Taipei
> 範圍：Master Roadmap M1，只完成 Phase 0、isolated arms、42-row corpus、local harness 與 SaaS budget gate。
> 結論：**STOP at SaaS prompt gate**。未送出 Claude、Codex 或 Copilot model prompt；未部署、未改 live plugin/config、未 push／PR、未查 upstream。

## 1. Gate 與風險

- 目前 Phase：M1 / Phase 4 isolated candidate。
- 風險：中。candidate 本身只在 isolated worktree 與 `/private/tmp`；後續 51 次 SaaS run 會建立 scratch fixture mutation，review 類另含固定 host review carrier。
- Implementation / research delegation：`SKIPPED`，依使用者明示。
- Phase 4 review carrier：本輪 `SKIPPED`；已列入 matrix 與精確預算，尚待明示授權。
- DCT build / E2E：`SKIPPED`；本 candidate 未修改 DCT runtime。

## 2. Phase 0 revalidation

### 2.1 Live boundary

觀測時刻：2026-07-27 21:35–21:36 CST；postflight：2026-07-27 21:51:28 CST。

| Repo | Branch / HEAD | 狀態 | 裁決 |
|---|---|---|---|
| `~/.agents` | `main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f` | ahead 33、staged 0、既有 6 個 untracked paths | 未修改、未 stage |
| `~/.claude` | `main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4` | `settings.json` dirty、staged 0 | 未修改 |
| `~/.codex` | `main` / `bd1195dbee85b405b959a387b59f64d5449ab581` | `AGENTS.md` dirty、staged 0 | 未修改 |
| `~/.copilot` | `main` / `4b47fee53c68644f1dbcd75136440c01fda09f9d` | `copilot-instructions.md` dirty、staged 0 | 未修改 |

Postflight fingerprints 與 preflight 相同：

| Carrier | SHA-256 |
|---|---|
| `~/.claude/settings.json` | `434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32` |
| `~/.codex/AGENTS.md` | `951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372` |
| `~/.claude/CLAUDE.md` | `db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7` |
| `~/.copilot/copilot-instructions.md` | `9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c` |

### 2.2 Existing evidence branches

- `codex/mattpocock-workflow-migration-v2`：`1014c669e17f3bb2d8e52d27f32b07752f14a84a`
- `codex/mattpocock-workflow-migration-v3`：`1779337af1c8de9920b6de99c36db2ba64ed8b70`
- `codex/mattpocock-workflow-migration-v4`：`36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- ancestry：`678ab6d → v2 → v3 → v4` 全部成立。
- 既有 v1/v2/v3/v4 worktrees 均保持 clean，未原地修改。

### 2.3 Rollback carriers 與 Arm A 唯一性

兩個 carrier 存在且可讀：

- `/Users/pochientsai/.agents-deployment-backups/20260727-193338-matt-v2`
- `/Users/pochientsai/.agents-deployment-backups/20260727-205915-matt-v4`

Arm A 以 pre-Matt commit `678ab6d3c13dcd14626617e6981ee33ad17d4e04c` 重建；不是目前 v4。

| Semantic identity | Git history hash | Backup hash | 結果 |
|---|---|---|---|
| Codex `AGENTS.md` | `f5434fcfaf7656e8be02bcfcc7098c4d0c5eb538e6a4c987c16b6beb65a16bce` | 同值 | PASS |
| Copilot instructions | `1aef9144af52cf185a11f605baae0078d9a1f9bacb49a27bee6cc2e392db28f6` | 同值 | PASS |
| Claude `CLAUDE.md`（Claude repo `20554ed`） | `a1c67cd5b8129a088d94abd286d84f5323b736a2365eb98425ac464fa27e4e47` | 同值 | PASS |

`678ab6d` 的 Matt stable skill 數量為 0；四支被替代 legacy wrapper 尚未帶 invocation-off metadata。history + backup 因此能唯一證明 Arm A。

### 2.4 Matt pin 與 payload

- `assessed_commit=ed37663cc5fbef691ddfecd080dff42f7e7e350d`
- lock SHA-256：`8de7d847f7d1a12d6e2272accad9fb774557782b5fd602b1ad4b5495a7f0c721`
- lock skills：22
- import commit `54b3aab4` 到 v4 的 22-skill payload drift：0
- upstream remote：未查詢，依 M1 scope。

### 2.5 Host identity 與 active state

| Host | Fixed executable / version | Canary model / effort / permission |
|---|---|---|
| Claude | `/Users/pochientsai/.local/bin/claude` / `2.1.220` | `claude-opus-5` / `xhigh` / `auto`、network denied |
| Codex | `/Users/pochientsai/.nvm/versions/node/v24.15.0/bin/codex` / `0.145.0` | `gpt-5.6-sol` / `high` / `workspace-write + on-request`、network denied |
| Copilot | `/Users/pochientsai/.local/bin/copilot` / `1.0.75` | `claude-opus-5` / `xhigh` / `interactive`、network denied |

`/opt/homebrew/bin/copilot` 亦為 `1.0.75`，但 matrix 固定使用 `~/.local/bin/copilot`。

Superpowers 逐 host 觀測：

- Claude：`superpowers@superpowers-marketplace` 6.2.0，enabled；14 skills。
- Codex：`superpowers@superpowers-dev` 6.2.0，enabled；14 skills。
- Copilot：settings key 為 true；inventory 含 14 Superpowers skills。
- Copilot inventory：150 skills、disabled 0、四支 legacy wrapper 皆可見；`dynamicRetrieval.skills` unset、`disabledSkills` unset / count 0。

## 3. Isolated arms

Candidate worktree：

`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`

Scratch carrier：

`/private/tmp/phase4-canary/arms-v2`

Deterministic fixture：

- source：`/private/tmp/phase4-canary/fixture-source`
- commit：`ed4ce6a0359cbe1abf4768e0faba1cd785490205`
- baseline regression：`tests/count-lines.sh` exit 1，原因是最後一行無 newline 的契約，不是 path/error 假紅。

### 3.1 Semantic diff

| Surface | Arm A | Arm B |
|---|---|---|
| Kernel source | `678ab6d` pre-Matt | v4 `36f8ff1` |
| Matt stable 22 | absent | present、lock payload unchanged |
| Legacy wrappers | 4 支 active model-invocable | 4 支移到 scratch `attic/phase4-legacy`；active root 0，`mp-zoom-out` 保留 |
| Superpowers | 三 host 6.2.0 payload carrier，各 14 skills | scratch plugin payload root absent |
| Routing | legacy `mp-*` + Superpowers enhancement/closeout | Matt replacements + thin-kernel action gates |
| Live mutation | none | none |

Arm A 的 plugin payload 以 read-only symlink 指向已驗證的三 host 6.2.0 cache；Arm B 沒有該 payload root。實際新 session inventory 仍是 SaaS execution gate 的 runtime acceptance criterion，不用 static contract 冒充 observation。

## 4. Canary corpus 與精確 SaaS budget

完整 machine-readable matrix：`23-phase4-canary-matrix.jsonl`。

每列包含完整 prompt、host、arm、class、fixture path、model、effort、permission、intended workflows、expected behavior、allowed tools、review carrier、預期檔案 mutation、acceptance criteria、run order、timeout、retry policy。

| Host | Top-level | Arm A review carrier | Arm B review carriers | Exact total |
|---|---:|---:|---:|---:|
| Claude | 14 | 1 | 2 | **17** |
| Codex | 14 | 1 | 2 | **17** |
| Copilot | 14 | 1 | 2 | **17** |
| **Total** | **42** | **3** | **6** | **51** |

按 class：feature、bugfix、diagnosis、architecture、closeout、missing-evidence 各 6；review 為 6 top-level + 9 nested = 15。retry budget 為 0；任何 retry 都須重新授權。

只有六列 review case 允許內建 carrier：

- Arm A：每 host 1 個 `requesting-code-review` carrier。
- Arm B：每 host 2 個 `code-review` Standards / Spec carriers。
- 其餘 36 個 top-level case 明確禁止 delegation。

Run order：

- Claude：A/B 交錯，1–14。
- Codex：B/A 交錯，15–28。
- Copilot：A/B 交錯，29–42。
- 每個 run 使用獨立 clone，不共用 mutation state；不使用真實專案或 remote PR。

## 5. Harness RED → GREEN

Harness：`bin/phase4-canary-harness`
Selftest：`tests/phase4-canary-harness.sh`

第一個 RED（harness 尚不存在）：

```text
8 PASS / 2 FAIL
FAIL real 42-row matrix is complete
FAIL valid synthetic result passes
```

第二個 RED 抓到 fixture 自己的 path error：

```text
10 PASS / 1 FAIL
FAIL fixture regression is red for the intended contract
```

Final self-review 再用四個 trust-boundary fixture 取得 RED：

```text
14 PASS / 4 FAIL
FAIL missing-evidence probe cannot complete even with prose evidence
FAIL network tool fails even when local tools are allowed
FAIL unbudgeted subagent fails
FAIL missing expected file mutation fails
```

修正後 GREEN：

```text
18 PASS / 0 FAIL
```

Synthetic false-green cases逐項會 FAIL：

- actual route 不等於 intended route
- legacy collision / double execution
- completed=true 但 evidence 為空，或 missing-evidence probe 帶著散文 evidence 仍宣稱完成
- Claude / Codex / Copilot raw event 中的 tool call
- network-capable tool，或非 review case 的未編列 subagent
- retry event 超出 0
- unexpected 或 missing expected file mutation
- Arm B inventory 仍含 Superpowers 或 legacy wrapper
- rollback fingerprint mismatch

Harness 不含任何 SaaS invocation command；因此 local selftest 不可能越過 prompt gate。

## 6. Local validation

| Gate | Result |
|---|---|
| Phase 4 harness | PASS — 18 / 0 |
| Matt workflow contracts | PASS — 54 / 0 |
| Legacy collision + selftest | PASS |
| Vendored detection | PASS — 33 / 0 |
| Version tripwire + selftest | PASS — 44 未命中 / 44 會觸發 |
| Git push guards | PASS — 68 / 0 + Codex 12 / 0 |
| Candidate `agents-sync --check` | PASS — lint；Codex 8425/10240B，Copilot 9165/10240B |
| Candidate pairing `--doctor` | PASS — isolated Claude stamp + Codex/Copilot manifest/body |
| Conformance | PASS — 17 / 0 |
| `bash -n` | PASS |
| `shellcheck` | UNAVAILABLE — binary 未安裝 |
| `git diff --check` | PASS |
| gitleaks candidate range | PASS — no leaks |
| targeted secret-pattern scan | PASS — 0 hit |
| DCT build / E2E | SKIPPED — runtime 未修改 |

新增檔案 bytes：

- harness：10,612B
- selftest：9,667B
- matrix：44,856B
- managed host body：0B 變更；budget 保持 Codex 8425B / Copilot 9165B。

## 7. Candidate repos / commits

### `~/.agents`

- branch：`codex/mattpocock-workflow-phase4-canary`
- base：`36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- candidate commits：
  - `63e43b5 test(workflow): 新增 Phase 4 canary harness`
  - `66d439d docs(workflow): 定義 Phase 4 A/B canary corpus`
  - `c097322 fix(workflow): 補齊 Arm A plugin payload carrier`
  - `29a4f7b docs(workflow): 記錄 Phase 4 isolated evidence`
  - `2909633 fix(workflow): 阻擋 canary harness 假綠`
  - 本檔的 final doc-only closeout commit
- push / PR：未執行。

### `~/.claude`

- tracked candidate：`SKIPPED`。不需要修改 Claude source；Arm A/B 使用 backup body + scratch `CLAUDE_CONFIG_DIR` carrier。
- branch / HEAD：維持 `main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- diff / commit range：空；既有 `settings.json` dirty fingerprint 未變。

## 8. Rollback

本輪未部署，正常 rollback 是停止並保留 evidence：

1. 不合併、不 push candidate branch。
2. scratch arms / fixture 可移至其他 `/private/tmp` 名稱或刪除；不影響 live。
3. 若需撤銷 candidate commit，使用 `git revert`，禁止 `reset --hard`。

後續取得 SaaS 授權後，每 host 每 run：

1. run 前保存 fixture snapshot、host inventory、plugin state 與 managed-body fingerprints。
2. run 後只 rollback scratch clone/config。
3. 對 expected fingerprint `cmp`；不符即該 host FAIL 並停止。
4. plugin isolation或讀回無法機械證明，該 host 標 `UNAVAILABLE`；不得改 live 設定繞過。
5. Copilot 沒有可重現 pinned 6.2.0 reinstall 時保持 installed + disabled，不做 uninstall。

## 9. Residual risks

1. 51 個 SaaS runs 尚未執行；目前不能給任何 host migration-safety PASS。
2. Scratch carrier 靜態隔離已證明；三 host 的 new-session inventory / runtime plugin isolation 必須在授權後逐 host 觀察，不能跨 host 外推。
3. Review carrier 是 9 個額外 SaaS runs；未取得明示授權前不得啟動。
4. `shellcheck` UNAVAILABLE；目前只有 `bash -n` + runnable selftest。
5. 本 corpus 只有每類每 arm 1 次，只能判 migration safety；不能宣稱能力改善。
6. retry budget 0；timeout、CLI failure 或 malformed output 都不自動重試。

## 10. Next gate

只接受含精確數量與 review carrier 授權的下一步，例如：

```text
執行 Phase 4 A/B canary；允許 51 次 SaaS runs：
Claude 17、Codex 17、Copilot 17；
允許 matrix 內明列的 9 個 host review carriers。
retry budget 維持 0。
```

未收到上述等價授權前，保持停止；不部署。
