# Phase 4 v2 — Copilot result-contract / artifact-evidence local remediation

> 日期：2026-07-28 Asia/Taipei  
> 範圍：Master Roadmap M1 / Phase 4 v2 / Copilot local remediation。  
> 結論：**Copilot result prompt、deterministic extraction與 artifact gitleaks boundary已完成 RED → GREEN；SaaS新增0、live mutation 0、Stage 1與Stage 2 rows皆未執行。**

## 1. Authorization, baseline, and risk

- isolated candidate：`/private/tmp/agents-worktrees/codex/mattpocock-workflow-phase4-canary`
- branch：`codex/mattpocock-workflow-phase4-canary`
- 使用者指定起始 HEAD：`cd99a17a821816721e094ddf3fa1b1e50c38d550`
- 起始 candidate：exact HEAD / clean PASS
- code HEAD（本 evidence前）：`17e61f38292179718d1fecf95d6b0df7baeaec9d`
- 授權：只修 launcher、harness、`.gitleaks.toml`與必要 regression tests / evidence
- 明確禁止：SaaS、subagent、額外 model reviewer、live deployment、Stage 1 row、Stage 2 row

風險為高：launcher與harness是42-row共用路徑，`.gitleaks.toml`也供pre-commit使用。Rollback為依反向順序revert本 evidence commit、`17e61f3`與`ec0b030`；live從未變更，不需live rollback。

## 2. Fail-fast preflight

| Gate | Result |
|---|---|
| Candidate path / branch / HEAD / clean | PASS |
| Live `~/.agents` branch / HEAD / exact 7 paths | PASS — `main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f` |
| Live `~/.claude` branch / HEAD / existing dirty attribution | PASS — `main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`；只有既有 `M settings.json` |
| `_population.md` exact path / SHA-256 / size | PASS — `db3dc99b88e6ffc44ba931458cae5a51e3eb6fa47122cd2ab34814263dedff17` / `2348` bytes |
| Claude settings / policy fingerprints | PASS — `434fbd…a32` / `db2755…ee7` |
| Codex AGENTS fingerprint | PASS — `951e02…372` |
| Copilot instructions fingerprint | PASS — `9d8dd2…ea3c` |
| Historical attempts | PASS — `2 / 1 / 3` |
| Latest fresh attempts | PASS — `5`；未新增、未覆寫 |

前次 `36-phase4-v2-stage1-fresh-rerun-live-baseline-exception.json`已隨失敗 closeout失效，本 remediation未沿用或建立新 exception。

## 3. Root cause and dependency boundary

1. Claude與Codex各有 CLI schema enforcement；Copilot 1.0.75只有 `--output-format`，沒有 result-schema flag。原 launcher只把 route accounting contract放進 Copilot prompt，模型遂把 route欄位誤當完整 output envelope。
2. Copilot final content需從 vendor JSONL的 terminal `assistant.message.data.content`擷取；先前外部 ad-hoc `fromjson`錯誤曾把 raw payload帶進 diagnostic。
3. Copilot A的8個 redacted gitleaks findings全是 `generic-api-key`對 exact `apiCallId` vendor metadata的命中；process credential exact-value match為0。

Dependency scan：

- `bin/phase4-canary-launcher plan`的正式 regression caller集中於`tests/phase4-canary-launcher.sh`。
- `bin/phase4-canary-harness`的 public commands集中於`tests/phase4-canary-harness.sh`與 Phase 4 evidence。
- `.gitleaks.toml`另由`hooks/pre-commit-agents.sh`使用。
- result schema、matrix、route semantics與`verify-result` acceptance皆未修改。

## 4. Minimal remediation

### Copilot prompt

Copilot branch把既有 compact result schema原樣嵌入 effective prompt，要求：

- exactly one JSON object
- matching the existing schema
- no Markdown fence
- no extra prose

Claude與Codex command不變；schema檔本身不變。

### Deterministic extraction

`phase4-canary-harness extract-copilot-result EVENTS OUT`：

- 只接受exactly one non-empty terminal `assistant.message`且tool requests為0
- 所有中間raw candidate只存在mode 0700 temp dir
- 只接受直接可解析的JSON object；fence不被寬容接受
- 所有parser stderr被抑制，失敗只輸出固定metadata訊息
- refuse overwrite；成功輸出沿用mode 0600
- extraction不取代既有`verify-result` acceptance

### Artifact gitleaks

- 既有deprecated `[allowlist]`機械升級成等價`[[allowlists]]`
- 新增`targetRules = ["generic-api-key"]`
- `regexTarget = "match"`
- 只允許exact token `apiCallId`
- 不disable rule、不排除artifact path、不新增wildcard
- `apiKey`近鄰synthetic fixture仍必須FAIL
- future row的process credential exact-value scan仍由launcher `credential_env` contract保留

Commits：

- `ec0b030` — `test(workflow): [wip] 鎖定 Copilot evidence 契約`
- `17e61f3` — `fix(workflow): 修正 Copilot evidence 契約`

## 5. RED → GREEN

| Slice | RED | GREEN |
|---|---|---|
| Copilot exact schema prompt | launcher `5 PASS / 1 FAIL` | launcher `6 PASS / 0 FAIL` |
| terminal extraction + no raw diagnostic | harness `30 PASS / 2 FAIL` | harness `32 PASS / 0 FAIL` |
| exact `apiCallId` rule scope | harness `32 PASS / 1 FAIL` | harness `33 PASS / 0 FAIL` |

Preserved Copilot A artifact local replay：

- extraction：exit 1，固定訊息`FAIL: Copilot terminal result is not a JSON object`
- raw payload字串出現在diagnostic：0
- gitleaks：exit 0，findings 0
- 原Stage 1 Copilot A verdict仍是FAIL；歷史artifact與evidence未被改寫

## 6. Local verification

| Gate | Result |
|---|---|
| `bash -n` | PASS — 4 Phase 4 scripts |
| ShellCheck 0.11.0 | PASS — 4 scripts，0 findings |
| Result schema parse / unchanged | PASS |
| Matrix unchanged / validator | PASS — 42 top-level + 9 review carriers |
| Phase 4 harness | PASS — `33 PASS / 0 FAIL` |
| Launcher plans | PASS — `6 PASS / 0 FAIL`；42 / 42 bounded |
| Matt workflow contracts | PASS — `54 PASS / 0 FAIL` |
| Legacy collision normal / selftest | PASS — 4 wrappers / 4 mappings |
| Vendored detection | PASS — `33 PASS / 0 FAIL` |
| Version tripwire normal / selftest | PASS — 44 / 44 |
| Git push guards | PASS — `68 PASS / 0 FAIL` + `12 PASS / 0 FAIL` |
| `tests/agents-branch.sh` | PASS |
| Scratch `agents-sync --check` | PASS — Codex 8425 / 10240B；Copilot 9165 / 10240B |
| Scratch `agents-sync --doctor` | PASS |
| Scratch conformance | PASS — `17 PASS / 0 FAIL` |
| Modified-file gitleaks | PASS — 5 / 5 |
| Candidate-range gitleaks | PASS — 27 commits，no leaks |
| Preserved Copilot raw artifact gitleaks | PASS — 0 findings |
| Targeted secret-assignment scan | PASS — 0 hit |
| `git diff --check` | PASS |
| DCT build / MySQL E2E | SKIPPED — 未修改DCT runtime、schema或importer |

Scratch pairing首輪因未放入Claude policy carrier而為doctor FAIL / conformance `15 PASS / 2 FAIL`；補齊同一read-only carrier後在全新scratch重跑為doctor PASS / `17 PASS / 0 FAIL`。兩輪都沒有SaaS或live mutation。

`gitleaks dir .`另重現既有`attic/ecpay`公開測試向量224項，與本次5個變更檔交集為0；未擴大allowlist。本次正式gate沿用candidate-range、modified-file與exact artifact scans。

Formal Standards / Spec model review為 **UNAVAILABLE**：使用者明示禁止subagent與額外model reviewer。Primary context逐行self-review，0條未處理in-scope finding。

## 7. Budget and preservation

- SaaS budget：authorized `0` / consumed `0`
- review carriers：0
- retries：0
- Stage 1 attempts：0
- Stage 2 attempts：0
- historical attempt directories：保留2 / 1 / 3
- latest fresh scratch attempts：保留5
- schema / matrix / old result artifacts：未修改

## 8. Live postflight

- `~/.agents`：`main` / `36f8ff1dc208be531f52216dd33f2f32aec62e0f`
- `~/.agents` status：原7 paths，無additional drift
- `_population.md`：exact SHA-256 / size仍相同
- `~/.claude`：`main` / `971f3015517267c7e070dff31b1a68a7d4ea04c4`
- Claude settings / policy、Codex AGENTS、Copilot instructions fingerprints：全部與preflight相同
- live config / plugin / workflow / DCT mutation：0

## 9. Roadmap and next gate

- M0 — COMPLETE
- M1 — CURRENT：Copilot local remediation complete；停在新的Stage 1 budget gate
- M2 — PENDING
- M3 — PENDING
- M4 — PENDING
- M5 — PENDING

下一步若獲新授權：

1. 以本 evidence後final candidate HEAD重新做exact preflight。
2. 前次exception不可重用；只有`_population.md` exact path / SHA-256 / size仍相同時，才能建立新的Stage-1-only exact-match candidate exception。
3. 使用全新scratch，重新從Claude A開始完整6列；不得拼接舊PASS或只補Copilot A/B。
4. 固定serial、retry 0、carrier 0、任一FAIL / UNAVAILABLE立即停止。
5. 六列全PASS後仍只停在Stage 2 budget gate；Stage 2需另行授權。

本 evidence不授權任何Stage 1或Stage 2 execution。

## 10. Preflight Ledger

1. Scope — PASS：5個code/test/config檔與本evidence皆逐項對應使用者四條remediation scope；無schema、matrix、route或live變更。
2. Git state — PASS：由clean `cd99a17`開始；isolated branch `codex/mattpocock-workflow-phase4-canary`，非main。
3. Diff self-review — PASS：逐行檢查116 insertions / 2 deletions；無debug、TODO或dead code。
4. Self-simplification — PASS：沿用既有launcher、harness、jq與gitleaks；無新dependency、抽象層或speculative config。
5. Tests evidence — PASS：第5、6節；RED commit `ec0b030`早於GREEN commit `17e61f3`。
6. Review gate — UNAVAILABLE：禁止subagent / model reviewer；primary self-review 0 unresolved finding。
7. Security-release gates — SKIPPED：candidate-only且本輪不部署；gitleaks與targeted secret scans另列PASS。
8. Residual risks — Copilot prompt compliance仍需fresh SaaS證明；rollback為反向revert本輪commits，live不需rollback。

## Closeout Ledger

- Self-simplification — PASS：沒有新dependency、parser abstraction、wildcard exception或schema fork。
- Diff self-review — PASS：變更只在launcher、harness、gitleaks與必要tests/evidence；0未處理finding。
- Relevant verification — PASS：RED `5/1`、`30/2`、`32/1` → GREEN launcher `6/0`、harness `33/0`；其餘local gates見第6節。
- Review gate — UNAVAILABLE：使用者禁止額外model reviewer / subagent；primary self-review完成。
- PR / CI / review status — SKIPPED：未push、未開PR、未merge；只建立isolated local commits。
- Residual risks — local contract無法取代fresh Copilot runtime證據；任何新Stage 1仍須新budget、新scratch、新exact exception與完整6列。Rollback為revert本輪commits。

## Error-learning settlement

- Cookbook：不寫；三個root causes已由regression與public harness command機械守護。
- Memory：不寫；使用者未要求更新memory。
- Workflow：不另寫；修復點本身就是Phase 4 workflow launcher / harness / security contract。
- 替代動作：保留RED commit、strict extractor、rule-scoped allowlist、candidate-range scan與fresh Stage 1 fail-fast gate。
