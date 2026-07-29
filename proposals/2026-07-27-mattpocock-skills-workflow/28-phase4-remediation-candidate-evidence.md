# Phase 4 remediation candidate — v2 Stage 1 budget gate

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 migration-safety remediation。
> 結論：**local gates PASS；STOP at Phase 4 v2 Stage 1 budget gate。未執行 SaaS、未改 live config、未進 Phase 5。**

## 1. Scope and baseline

- isolated worktree：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- remediation baseline：`c1300126bf8d0e60660c81282178655f6ab40031`
- 只改：
  - route accounting / result telemetry
  - Claude launch plan
  - Codex external review carrier / nested-sandbox compatibility
  - v2 staged matrix 與 local regression gates
- 明確未做：
  - Claude / Codex / Copilot model prompt：`0`
  - review carrier：`0`
  - retry：`0`
  - live deployment / push / PR / merge：`0`
  - live config / plugin / Matt vendored payload：`0` 變更
  - Phase 5：未進入

風險為中：`verify-result` 是 Phase 4 共用 acceptance point，錯誤會影響 42 rows。Rollback 是只 revert 本 isolated branch 的 remediation commits；live 不需 rollback。

## 2. Root causes and v2 contract

舊 contract 把「task-selected workflow」與「router / bootstrap / dependency / verification helper」放進同一個 flat `actual_workflows` 做 exact equality，造成必要 bootstrap 被誤判為 route collision；三 host 又沒有一致的 invocation event shape。

v2 改為：

- `selected_workflows`：必須與 matrix 的 substantive route 完全相等。
- `supporting_workflows`：只能是該 row 明列的 tight allowlist。
  - Arm A：`dev-workflow`、`deps-check`、`superpowers:using-superpowers`、`superpowers:verification-before-completion`，若本身已是 selected 就自 allowlist 移除。
  - Arm B：`dev-workflow`、`deps-check`，若已 selected 就移除。
- `events`：每個 selected / supporting workflow 恰有一個有序 event；重複、遺漏、未列入 supporting、summary/event 不一致都 FAIL。
- Arm B：任何 `superpowers:` 或 `mp-` route 仍直接 FAIL。
- raw tool event：若引用 matrix 明列的 live read prefix，直接 FAIL；Claude deny rules 之外再有 evaluator defense-in-depth。
- v1 歷史 matrix / result contract 保持相容，不重寫既有 Phase 4 evidence。

Result schema：`26-phase4-v2-result-schema.json`。

## 3. Host launcher remediation

### Claude

`bin/phase4-canary-launcher plan` 只產生 JSON argv plan，不執行 process：

- scratch `HOME` / `CLAUDE_CONFIG_DIR` / `TMPDIR`
- valid `{"mcpServers":{}}` + `--strict-mcp-config`
- inline result schema移除 `$schema`
- missing-evidence 使用 `--tools ""`，不暴露 `Skill`
- review 才暴露 `Agent`
- Read / Glob / Grep / Edit / Write / Bash deny rules覆蓋 live `.agents`、`.claude`、`.codex`、`.copilot`
- network-capable tools / commands deny

### Codex

- top-level `codex exec` 固定 `--disable multi_agent`，不再依賴未註冊 parent thread。
- review carriers 改為獨立 external `codex exec`：
  - Arm A：`review`
  - Arm B：`standards`、`spec`
- carrier 使用 `read-only` sandbox，top-level依 mutation contract 選 `read-only` / `workspace-write`。
- 不使用 `--dangerously-bypass-approvals-and-sandbox`。
- plan 明列 `requires_outer_unsandboxed=true`：outer orchestrator 不得再套一層會拒絕 inner `sandbox-exec` 的 sandbox；Codex CLI 本身的 sandbox仍保留。
- 每個成功 external carrier才可發出一個 `phase4.external_carrier` event template，計入原 matrix nested SaaS budget。
- Codex review prompt 明確禁止 top-level再建立內建 subagent，並要求重驗 external carrier output。

### Copilot

本輪不改 carrier模式；launcher只把同一 v2 route/result contract與 scratch/network bounds套用到 plan。Review仍是內建 `task`，missing-evidence仍為空 tool inventory。

Launcher沒有 execute subcommand；這是本輪 budget gate 的機械防線。取得精確 Stage 1 授權後，outer orchestrator才可逐 row消費 argv plan，且不得翻譯成較寬權限。

## 4. RED → GREEN evidence

| Cycle | RED | GREEN |
|---|---|---|
| v2 route accounting | harness `23 PASS / 1 FAIL`：合法 selected + allowed supporting 被 v1 exact route拒絕 | harness v2 route cases全綠 |
| host launcher / staged matrix | launcher `1 PASS / 3 FAIL`：Claude、Codex、Stage budget均未實作 | launcher `5 PASS / 0 FAIL` |
| live absolute path guard | harness `25 PASS / 1 FAIL`：允許 Read 時 live `.agents` tool event未被拒絕 | harness final `26 PASS / 0 FAIL` |
| ShellCheck | ShellCheck 0.11.0：SC2016 × 5、SC2054 × 1、SC2015 × 2，exit 1 | 同一 4-file scan 0 findings，exit 0；behavior suites仍為 26 / 0、5 / 0 |

False-green coverage包括：wrong selected route、unallowed supporting route、missing selected、duplicate invocation、event/summary mismatch、Arm B forbidden route、external carrier count、live absolute path、missing evidence、raw tool call、network、retry、mutation與rollback fingerprint。

## 5. v2 staged matrix and budget

Matrix：`27-phase4-v2-canary-matrix.jsonl`，42 top-level rows仍完整覆蓋 3 hosts × 2 arms × 7 classes；9 review carriers全保留，retry budget仍為 0。

| Stage | Rows | Claude | Codex | Copilot | Review carriers | SaaS runs |
|---|---:|---:|---:|---:|---:|---:|
| Stage 1 | 6 read-only architecture rows | 2 | 2 | 2 | 0 | **6** |
| Stage 2 | 36 remaining top-level rows | 15 | 15 | 15 | 9（已含在每 host 15） | **45** |
| Total | 42 top-level | 17 | 17 | 17 | 9 | **51** |

Stage 1選 architecture A/B，因為它們：

- read-only
- expected mutations = 0
- review carriers = 0
- 可先驗三 host route telemetry、Claude preflight及 Codex outer/inner sandbox boundary

Stage 1任一 host FAIL / UNAVAILABLE 即停止，不自動進 Stage 2，不挪用 Stage 2 budget補跑。

## 6. Local gates

| Gate | Result |
|---|---|
| Phase 4 harness | PASS — `26 PASS / 0 FAIL` |
| Launcher plans | PASS — `5 PASS / 0 FAIL`；42 / 42 plans bounded |
| Matrix validator | PASS — 42 top-level + 9 carriers；Stage 1 = 6 / 0 carriers |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision | PASS — 4 wrappers / 4 mappings |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire | PASS — 44 未命中；selftest 44 會觸發 |
| Git push guards | PASS — 68 / 0 + Codex 12 / 0 |
| `agents-branch` isolation | PASS |
| Scratch `agents-sync --check` | PASS — lint；Codex 8425 / 10240B，Copilot 9165 / 10240B |
| Scratch `agents-sync --doctor` | PASS — Claude stamp、manifest、origin stamps |
| Scratch conformance | PASS — `17 PASS / 0 FAIL` |
| `bash -n` / JSON parse / `git diff --check` | PASS |
| gitleaks candidate range | PASS — no leaks |
| targeted secret assignment scan | PASS — 0 hit |
| `shellcheck` | PASS — ShellCheck 0.11.0，4 scripts，0 findings |
| DCT build / E2E | SKIPPED — 本輪不改 DCT runtime |

Scratch conformance首輪為 16 / 1，原因是 scratch HOME 未帶入 Codex `default.rules`，exec-policy probe回報 missing file；補齊同一 read-only fixture後重跑 17 / 0。這不是 candidate code重試，也沒有 SaaS或 live mutation。

Host CLI local preflight：

- Claude Code `2.1.220`
- Codex CLI `0.145.0`
- GitHub Copilot CLI `1.0.75`

## 7. Candidate commits and file sizes

Code commits：

- `45b1501 fix(workflow): 修正 Phase 4 路由計帳`
- `b6c8a13 fix(workflow): 修正 Phase 4 host launcher`
- `593b6ae fix(workflow): 阻擋 canary 讀取 live path`
- `469c483 docs(workflow): 記錄 Phase 4 remediation gate`
- `4d3d565 fix(workflow): 清除 Phase 4 ShellCheck findings`

主要檔案 bytes（final doc commit前量測）：

- `bin/phase4-canary-harness`：16,044B
- `bin/phase4-canary-launcher`：10,138B
- `tests/phase4-canary-harness.sh`：15,818B
- `tests/phase4-canary-launcher.sh`：5,611B
- `26-phase4-v2-result-schema.json`：1,943B
- `27-phase4-v2-canary-matrix.jsonl`：64,810B

Managed host body為 0B diff；Codex / Copilot常駐預算不變。

## 8. Live postflight and rollback

2026-07-28 05:28:25 CST read-only postflight：

- live `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- 既有 6 個 untracked proposal paths原樣存在
- live `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- 既有 `settings.json` dirty原樣存在
- fingerprints未變：
  - Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
  - Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
  - Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`

Rollback：

1. 不 push / merge isolated branch。
2. 需要撤銷時逐一 `git revert` remediation commits；禁止 `reset --hard`。
3. Stage 1取得授權後，每 row仍須 before / after / rollback fingerprint；失配即該 host FAIL並停止。

## 9. Residual risks and settlement

1. 尚未執行任何 v2 SaaS row，三 host目前都沒有新的 migration-safety verdict。
2. Claude permission-rule與 structured-output runtime compatibility要到 Stage 1才有真實 host evidence；raw-event live-path guard會把 fallback讀取判 FAIL。
3. Codex plan要求 outer parent不再加第二層 sandbox；若執行面無法滿足，Codex標 UNAVAILABLE，不以 bypass flag繞過。
4. route telemetry是新的 cross-host result contract；Stage 1若有 malformed或不可觀測 event即 FAIL，不修改 contract追結果。
5. 既有 conformance 的 tdd-agent Rails probe在兩個檔案都不存在時會 vacuous PASS；屬 pre-existing scope 外 finding，本輪未修。

錯誤學習評估：

- Cookbook：不寫；ShellCheck與既有 behavior tests已能機械守護。
- Memory：不寫；使用者未要求修改 memory，且這是本 candidate特定契約。
- Workflow：不另寫；本輪本身就是 workflow harness / launcher修復。
- 替代動作：保留 ShellCheck、RED→GREEN cases、Stage 1 fail-fast與 exact budget gate。

## 10. Master Roadmap status

- M0 — COMPLETE：Phase 3 v4 deployment / collision canaries
- M1 — CURRENT：Phase 4 v2，停在 Stage 1 budget gate
- M2 — PENDING：Phase 5 legacy parity / retirement
- M3 — PENDING：Phase 6 Superpowers retirement
- M4 — PENDING：upstream detection candidate
- M5 — PENDING：Phase 7 thin-kernel trim

不得由本 gate自動進 Stage 2、Phase 5或任何後續 milestone。

## 11. Next gate

只接受以下等價的精確授權：

```text
執行 Phase 4 v2 Stage 1；允許 6 次 SaaS runs：
Claude 2、Codex 2、Copilot 2；
review carriers 0；
retry budget 維持 0。
```

未收到授權前，launcher保持 plan-only，不執行任何 host command。

## Closeout Ledger

- Self-simplification — PASS：沿用既有 harness + jq / Bash；無新 dependency、factory、config framework或未使用抽象。
- Diff self-review — PASS：逐行檢查 route / launcher / matrix與 ShellCheck修補；intentional generated literals只做精準 suppression。
- Relevant verification — PASS：本檔第 6 節 gates；ShellCheck 0 findings、Phase 4 26 / 0、launcher 5 / 0、conformance 17 / 0。
- Review gate — UNAVAILABLE：使用者明示不執行 SaaS，未啟動 model reviewer；primary context完成 self-review，0 未處理 in-scope finding。
- PR / CI / review status — SKIPPED：明示不 push、不開 PR、不 merge；local branch only。
- Residual risks — 本檔第 9 節；rollback為 revert isolated commits，Stage 1任一 host失敗即停止。
