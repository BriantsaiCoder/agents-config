# Phase 4 v2 Stage 1 fresh rerun — Copilot result-contract fail-fast evidence

> 日期：2026-07-28 Asia/Taipei
> 範圍：Master Roadmap M1 / Phase 4 v2 / Stage 1 fresh rerun。
> 結論：**Claude A/B 與 Codex A/B 皆 PASS；第 5 列 Copilot A 的 structured result contract malformed，且 raw artifact gitleaks FAIL，依 fail-fast 立即停止。未 retry、未執行 Copilot B 或任何 Stage 2 row。**

## 1. Authorization and isolated baseline

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- 使用者指定起始 HEAD：`62a793d3810c8279673cb6febc12a9f7ccab59f2`
- 起始 HEAD / clean / live fingerprints：SaaS 前全部 exact-match PASS
- fresh exact-match exception commit：`5437098193f3006ebc9c8999583be7c52440f838`
- fresh exception SHA-256：`58fc01b7917bc3d7473cc30aea4a6f043281ae2cccf5202530618d533eee950f`
- fresh scratch：`/private/tmp/phase4-canary-v2`
- deterministic fixture commit：`ed4ce6a0359cbe1abf4768e0faba1cd785490205`

本輪授權為 top-level SaaS runs 6、review carriers 0、retry 0，固定順序：

1. Claude A
2. Claude B
3. Codex A
4. Codex B
5. Copilot A
6. Copilot B

任一 row FAIL / UNAVAILABLE 必須停止；未用 budget 不得挪用。

## 2. Fresh Stage-1-only exception

Companion contract：

`36-phase4-v2-stage1-fresh-rerun-live-baseline-exception.json`

唯一例外：

- exact path：`/Users/pochientsai/.agents/proposals/2026-07-28-skill-writing-audit/_population.md`
- Git status：`??`
- SHA-256：`db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17`
- size：`2348` bytes
- match policy：`present-and-exact`
- wildcard / directory-wide exclusion：0
- Stage 2 use：禁止

本 contract 在本次 Stage 1 fail-fast closeout 後失效。未來 rerun 不得直接沿用。

## 3. Read-only preflight

| Gate | Result |
|---|---|
| Candidate path / branch / starting HEAD / clean | PASS |
| Live `~/.agents` branch / HEAD / exact 7-path attribution | PASS |
| Live `~/.claude` branch / HEAD / existing dirty attribution | PASS |
| `_population.md` path / status / SHA-256 / size | PASS — exact |
| Claude settings / policy fingerprints | PASS |
| Codex AGENTS fingerprint | PASS |
| Copilot instructions fingerprint | PASS |
| Three rollback carriers | PASS — present, readable, expected modes |
| Host versions | PASS — Claude 2.1.220、Codex 0.145.0、Copilot 1.0.75 |
| Credential carriers | PASS — Claude / Codex / Copilot 均為 set；未輸出值 |
| Fresh scratch | PASS — 6 cases、6 plans、0 attempts、0 nested runs、0 retries |
| Fixture / Arm A-B runtime policy isolation | PASS |
| ShellCheck / `bash -n` | PASS — 4 scripts |
| Result schema / exception JSON | PASS |
| Matrix validator | PASS — 42 top-level + 9 review carriers |
| Phase 4 harness | PASS — `30 PASS / 0 FAIL` |
| Launcher plans | PASS — `5 PASS / 0 FAIL` |
| `tests/agents-branch.sh` | PASS |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision normal / selftest | PASS |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire normal / selftest | PASS — 44 / 44 |
| Git push guards | PASS — `68 PASS / 0 FAIL` + `12 PASS / 0 FAIL` |
| `git diff --check` | PASS |
| gitleaks candidate range | PASS |

DCT build / MySQL E2E：SKIPPED；本輪未修改 DCT runtime、schema或 importer。

## 4. Executed rows

| Order | Row | Process | Route telemetry | Mutation | Validation | Verdict |
|---:|---|---|---|---:|---|---|
| 1 | `claude-a-architecture` | exit 0；timeout false；156,971 ms | selected `mp-improve-codebase-architecture`；supporting 0；1 event | 0 | harness / credential scan / gitleaks PASS | **PASS** |
| 2 | `claude-b-architecture` | exit 0；timeout false；186,831 ms | selected `codebase-design`；supporting `dev-workflow`；2 events | 0 | harness / credential scan / gitleaks PASS | **PASS** |
| 3 | `codex-a-architecture` | exit 0；timeout false；175,708 ms | selected `mp-improve-codebase-architecture`；4 allowlisted supporting routes；5 events | 0 | harness / credential scan / gitleaks PASS | **PASS** |
| 4 | `codex-b-architecture` | exit 0；timeout false；138,338 ms | selected `codebase-design`；supporting `dev-workflow`、`deps-check`；3 events | 0 | harness / credential scan / gitleaks PASS | **PASS** |
| 5 | `copilot-a-architecture` | exit 0；timeout false；214,204 ms | required structured telemetry absent | 0 | structured result malformed；gitleaks FAIL | **FAIL** |

前四列另通過：

- expected / actual / rollback fingerprint equality
- fixture Git status與diff為空
- retry 0
- carrier 0
- forbidden live-path / network / delegation checks
- Arm B inventory與route isolation

## 5. Copilot A fail-fast finding

Copilot A process成功結束，但 final payload不是 Phase 4 v2 result schema：

- 缺少 required top-level `completed`
- 缺少 required top-level `route_telemetry`
- 缺少 required top-level `evidence`
- 缺少 required top-level `summary`
- structured result候選數：0
- harness：`NOT RUN`；不得以 malformed payload偽造 PASS

Artifact security checks：

- process-only GitHub token exact-value match：0
- artifact gitleaks：**FAIL**
- rule：`generic-api-key`
- findings：8
- findings location：`events.raw.jsonl`
- finding values：未輸出、未寫入 candidate evidence

Fixture before / after / rollback fingerprints仍完全一致，Git mutation為0。

Outer orchestration另有一項constraint violation：解析 fenced payload時，`jq` error diagnostic曾把 raw model content展開至tool output。該內容未寫入candidate evidence；後續改為只輸出boolean metadata。即使exact token scan為0，此項仍記為 **FAIL**，不得淡化。

本授權禁止修改schema、launcher、harness或workflow追求綠燈，因此未修復、未retry。

## 6. Budget and fail-fast stop

| Host | Authorized | Attempts | PASS | FAIL | Unexecuted |
|---|---:|---:|---:|---:|---:|
| Claude | 2 | 2 | 2 | 0 | 0 |
| Codex | 2 | 2 | 2 | 0 | 0 |
| Copilot | 2 | 1 | 0 | 1 | 1 |
| **Total** | **6** | **5** | **4** | **1** | **1** |

- Review carriers：0
- Retries：0
- `copilot-b-architecture` attempt evidence：absent
- Stage 2 attempts：0

Per-host verdict：

- Claude：**PASS** — 2/2
- Codex：**PASS** — 2/2
- Copilot：**FAIL** — A malformed / artifact gitleaks FAIL；B未執行

不得合併宣稱三host migration-safety PASS，也不得宣稱能力提升。

## 7. Scratch preservation and live postflight

歷史 attempts皆保留、未覆寫：

- `/private/tmp/phase4-canary-v2-stage1-first-run-20260728-061738`：2
- `/private/tmp/phase4-canary-v2-prior-20260728-071319`：1
- `/private/tmp/phase4-canary-v2-schema-fail-20260728-185848`：3

本輪 fresh scratch attempts：5。歷史與本輪 budget未合併。

Live postflight：

- `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- `~/.agents` status：既有6 paths + exact `_population.md`，無additional drift
- `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- `~/.claude` status：既有 `M settings.json`
- Claude settings：`434fbd716edec5efb664c329a67f824977760d1f38188264143cbc0de6928a32`
- Claude policy：`db27550842ada6e8be6bc23fee63611a3d7b22df5dbf23ebb5f4eba081335ee7`
- Codex AGENTS：`951e0273c77f0d8f5dae3b5b5d42354da38b900853782e69791ee4c9180a8372`
- Copilot instructions：`9d8dd2bae8674f9d03bbe22f372e36612fbf54ed65f003f5276479312fe0ea3c`

沒有live config、plugin、fixture或DCT mutation；不需執行rollback。

## 8. Roadmap status and next gate

- M0 — COMPLETE
- M1 — CURRENT / FAILED：Stage 1停在Copilot result-contract與artifact-security boundary
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

唯一 next gate：**M1 Copilot result-contract / artifact evidence remediation decision gate**。

未取得新的remediation授權前：

- 不修改schema、launcher、harness或workflow
- 不重跑Copilot A
- 不執行Copilot B
- 不新增或挪用SaaS budget
- 不執行任何Stage 2 row

## Closeout Ledger

- Self-simplification — PASS：沿用既有launcher、runner與harness；candidate只新增fresh exception與本evidence。
- Diff self-review — PASS：未修改schema、matrix、launcher、harness、workflow或live config；raw artifacts未進repo。
- Relevant verification — PASS：5個process metadata、4個harness PASS、1個fail-fast record、0 mutation、0 retry、0 carrier與live postflight均有機械證據。
- Review gate — SKIPPED：使用者明示review carriers 0且禁止額外model reviewer／subagent。
- PR / CI / review status — SKIPPED：未push、未開PR、未merge；本輪只建立local evidence commit。
- Residual risks — Copilot required result contract未成立；raw artifact有8個gitleaks findings；一次parser diagnostic違反raw-output constraint；Copilot B與Stage 2未執行。
