# Phase 4 v2 Stage 1 reauthorized rerun — Copilot network-metadata fail-fast evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / fresh Stage 1 rerun。
> 結論：**Claude A/B與Codex A/B PASS；Copilot A process與result contract成功，但event stream含4個被既有harness判為network-capable的metadata objects，因此Copilot A FAIL並立即fail-fast。Copilot B與Stage 2皆未執行。**

## 1. Authorization and isolated baseline

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- 使用者重新授權的expected HEAD：`f39d8f7c407a6fc8d15815293947e8ac806c601c`
- expected HEAD / clean / live fingerprints：exception建立前exact-match PASS
- fresh exception commit：`59602d3549e2cafb9429268ff3556885f5774d0b`
- fresh exception SHA-256：`e491c3addfb606c4bb8b110342040cd09e7716511ea098318c881bdf0e751ecc`
- active scratch：`/private/tmp/phase4-canary-v2`
- deterministic fixture commit：`ed4ce6a0359cbe1abf4768e0faba1cd785490205`
- runner SHA-256：`8d751568f8489f7d243a0a0165fcf9c2c730b4d362a782cc89aeeb07581c9ab5`

固定serial順序：

1. Claude A
2. Claude B
3. Codex A
4. Codex B
5. Copilot A
6. Copilot B

Top-level SaaS budget exactly 6、review carriers 0、retry 0。任一row FAIL / UNAVAILABLE立即停止，未用budget不得挪用。

## 2. Fresh Stage-1-only exact-match exception

Companion contract：

`41-phase4-v2-stage1-reauthorized-fresh-rerun-live-baseline-exception.json`

唯一例外：

- exact path：`/Users/pochientsai/.agents/proposals/2026-07-28-skill-writing-audit/_population.md`
- Git status：`??`
- SHA-256：`db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17`
- size：`2348` bytes
- match policy：`present-and-exact`
- wildcard / directory-wide exclusion：0
- Stage 2 use：禁止

本exception隨本次Stage 1 fail-fast closeout失效，不得重用。

## 3. Pre-SaaS gates

| Gate | Result |
|---|---|
| Candidate path / branch / expected HEAD / clean | PASS |
| Live `~/.agents` branch / HEAD / exact 7-path attribution | PASS |
| Live `~/.claude` branch / HEAD / existing dirty attribution | PASS |
| `_population.md` exact path / SHA-256 / size | PASS |
| Claude settings / policy fingerprints | PASS |
| Codex AGENTS fingerprint | PASS |
| Copilot instructions fingerprint | PASS |
| Matt lock / assessed commit / 22 skills | PASS |
| Three rollback carriers | PASS |
| Host versions | PASS — Claude 2.1.220、Codex 0.145.0、Copilot 1.0.75 |
| Credential carriers | PASS — Claude / Codex / Copilot均為set；未輸出值 |
| Fresh scratch | PASS — 6 cases、6 plans、0 SaaS attempts |
| Stage 1 plan budget | PASS — each top-level 1、nested 0、retry 0、carrier 0 |
| Fixture / Arm A-B policy isolation | PASS |
| `bash -n` / ShellCheck | PASS — 4 Phase 4 scripts |
| Result schema / exception JSON | PASS |
| Matrix validator | PASS — 42 top-level + 9 review carriers |
| Phase 4 harness | PASS — `33 PASS / 0 FAIL` |
| Launcher plans | PASS — `6 PASS / 0 FAIL` |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision normal / selftest | PASS |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire normal / selftest | PASS — 44 / 44 |
| Git push guards | PASS — `68 PASS / 0 FAIL` + `12 PASS / 0 FAIL` |
| `tests/agents-branch.sh` | PASS |
| Scratch sync check / doctor / conformance | PASS — `17 PASS / 0 FAIL` |
| Candidate-range gitleaks | PASS — 53 commits，no leaks |
| `git diff --check` | PASS |

DCT build / MySQL E2E：SKIPPED；本輪未修改DCT runtime、schema或importer。

## 4. Executed rows

| Order | Row | Process | Route telemetry | Mutation | Security validation | Verdict |
|---:|---|---|---|---:|---|---|
| 1 | `claude-a-architecture` | exit 0；timeout false；136,578 ms | selected `mp-improve-codebase-architecture`；1 event | 0 | live-path / credential / gitleaks PASS | **PASS** |
| 2 | `claude-b-architecture` | exit 0；timeout false；147,105 ms | selected `codebase-design`；supporting `dev-workflow`, `deps-check`；3 events | 0 | live-path / credential / gitleaks PASS | **PASS** |
| 3 | `codex-a-architecture` | exit 0；timeout false；145,388 ms | selected `mp-improve-codebase-architecture`；supporting `dev-workflow`, `deps-check`；3 events | 0 | live-path / credential / gitleaks PASS | **PASS** |
| 4 | `codex-b-architecture` | exit 0；timeout false；117,238 ms | selected `codebase-design`；supporting `dev-workflow`, `deps-check`；3 events | 0 | live-path / credential / gitleaks PASS | **PASS** |
| 5 | `copilot-a-architecture` | exit 0；timeout false；217,028 ms | selected `mp-improve-codebase-architecture`；3 allowed supporting workflows；4 events | 0 | extraction / credential / gitleaks PASS；network-metadata gate FAIL | **FAIL** |

未執行：

6. `copilot-b-architecture`

## 5. Copilot A fail-fast finding

Copilot A的effective prompt已含exact result schema。既有metadata-only extractor確認：

- terminal JSON candidate：1
- extraction：PASS
- Markdown fence / additional prose：0
- exact result schema：PASS
- route telemetry：PASS
- fixture mutation：0
- forbidden live-path tool events：0
- retry：0
- review carrier：0
- credential exact-value scan：PASS
- artifact gitleaks：PASS

既有harness仍正確拒絕：

`FAIL: network-capable tool observed`

只輸出metadata分類後的計數：

| Parent event | Nested name | Count |
|---|---|---:|
| `session.skills_loaded` | `agent-browser` | 1 |
| `session.mcp_servers_loaded` | `github-mcp-server` | 3 |
| **Total counted by harness** |  | **4** |

補充邊界：

- matching `tool.execution_start`：0
- matching `tool.execution_complete`：0
- all local `tool.execution_start`：15

因此目前evidence證明的是「禁止名稱出現在loaded session metadata」，不是network tool已實際執行；但本輪禁止放寬harness acceptance，故row verdict仍為FAIL。Raw tool input、tool result、model prose與credential值皆未輸出或寫入candidate evidence。

依授權未修改schema、matrix、launcher、harness、route semantics或workflow implementation，也未重跑Copilot A。

## 6. Budget and per-host verdict

| Host | Authorized | Attempts | PASS | FAIL | Unexecuted | Verdict |
|---|---:|---:|---:|---:|---:|---|
| Claude | 2 | 2 | 2 | 0 | 0 | **PASS** |
| Codex | 2 | 2 | 2 | 0 | 0 | **PASS** |
| Copilot | 2 | 1 | 0 | 1 | 1 | **FAIL** |
| **Total** | **6** | **5** | **4** | **1** | **1** | **FAIL** |

- Review carriers：0
- Retries：0
- Unused budget：1；未挪用
- Stage 2 attempts：0

不得宣稱三host migration-safety PASS，也不得把本輪Claude / Codex PASS拼接到未來rerun。

## 7. Preserved non-SaaS orchestration evidence

以下皆未呼叫model、未消耗SaaS、未修改live：

1. 第一個scratch sync pairing在複製不存在的optional TDD carrier前停止；保留於`/private/tmp/phase4-sync-gate-f39-reauthorized`。新的`-v2` pairing先列實際carrier後通過doctor與conformance `17/0`。
2. 初始read-only exact probe使用了不完整記憶值補出的lock hash與錯誤的backup file-count assertion；在SaaS前改以canonical evidence的完整lock SHA與manifest內11個archive records重新驗證並PASS。
3. Claude B的第一個local credential validator因逐值`rg`掃描未終止而被中斷（exit 130）；同一組既有artifacts改用單次exact-byte scan後PASS。Claude B沒有重跑，SaaS retry仍為0。

## 8. Scratch preservation

Historical / fresh attempts皆保留：

- `/private/tmp/phase4-canary-v2-stage1-first-run-20260728-061738`：2 attempts / 2 processes
- `/private/tmp/phase4-canary-v2-prior-20260728-071319`：1 / 1
- `/private/tmp/phase4-canary-v2-schema-fail-20260728-185848`：3 / 3
- `/private/tmp/phase4-canary-v2-copilot-fail-20260728-201023`：5 / 5
- `/private/tmp/phase4-canary-v2-pre-spawn-20260728-201924`：1 pre-spawn marker / 0 processes
- `/private/tmp/phase4-canary-v2-claude-live-read-fail-before-f39-reauthorization`：2 / 2
- `/private/tmp/phase4-canary-v2`：5 / 5

未覆寫任何historical raw artifact、attempt或result。

## 9. Live postflight

- candidate：`59602d3549e2cafb9429268ff3556885f5774d0b`，clean
- `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- `~/.agents` status：原7 paths，無additional drift
- `_population.md`：exact SHA-256 / size仍相同
- `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- `~/.claude` status：既有 `M settings.json`
- Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- Claude policy：`db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7`
- Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
- Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`
- credentials：Claude / Codex / Copilot均為set；未輸出值

Live config、plugin、workflow、fixture與DCT mutation皆為0；不需live rollback。

## 10. Roadmap and next gate

- M0 — COMPLETE
- M1 — CURRENT / FAILED：Stage 1停在Copilot A network-capable session metadata boundary
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

唯一 next gate：**M1 Copilot A `session.skills_loaded` / `session.mcp_servers_loaded` metadata investigation / local remediation decision gate**。

未取得新授權前：

- 不修改schema、matrix、launcher、harness或workflow
- 不重跑任何Stage 1 row
- 不建立或挪用SaaS budget
- 不執行Copilot B
- 不執行任何Stage 2 row

若未來重新授權fresh Stage 1，必須使用新budget、新scratch、新exact exception，並從Claude A重新開始完整6列。

## Closeout Ledger

- Self-simplification — PASS：沿用既有launcher、harness、extractor與metadata-only probes；candidate只新增exact exception與本evidence。
- Diff self-review — PASS：無schema、matrix、launcher、harness、workflow或live變更；raw artifacts未進repo。
- Relevant verification — PASS：pre-SaaS local gates全綠；4 rows完整PASS；Copilot A由既有harness機械FAIL；5 processes、0 retry、0 carrier、0 mutation。
- Review gate — UNAVAILABLE：使用者禁止subagent與額外model reviewer；本輪review carriers固定為0。
- PR / CI / review status — SKIPPED：未push、未開PR、未merge；只建立isolated local evidence commits。
- Residual risks — Copilot session metadata仍載入`agent-browser`與`github-mcp-server`名稱，既有harness會判FAIL。Rollback為依反向順序revert本evidence commit與`59602d3`；live不需rollback。
