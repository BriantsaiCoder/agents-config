# chaseai-yt/grill-me-codex — 對全域設定與 workflow 的價值評估

日期：2026-08-01（14:57 複驗更正）｜ 評估對象：`https://github.com/chaseai-yt/grill-me-codex`（MIT，930★）
版本基準：HEAD `fe37a70`，最後 commit **2026-07-08**（初稿誤記 07-31，已更正；上游 `git ls-remote` 確認無新 commit）
評估者環境：codex-cli 0.146.0、`openai-codex` plugin 1.0.4（已啟用）、`~/.agents` thin-kernel workflow

---

## 0. 一句話結論

**協定有價值，實作沒有。** repo 的 4 個 skill 中，2 個（`grill-me-codex`、`grill-with-docs-codex`）與本機 pinned Matt 集合重複、且破三 host parity；另 2 個（`codex-review`、`codex-build`）填補真實缺口，但其手刻 bash 在本機是**降級**——官方 `codex-companion.mjs` 已封裝更好的機制。應抽協定自建，不可 `cp -r skills/*`。

---

## 1. repo 內容（實測）

| Skill | 組成 | 原創性 |
|---|---|---|
| `grill-me-codex` | Matt `grill-me` Act 1 + Codex 迭代 plan review Act 2 | Act 1 = Matt (MIT)，Act 2 = Chase AI |
| `grill-with-docs-codex` | 同上 + CONTEXT.md / ADR-FORMAT | 同上 |
| `codex-review` | 只有 Act 2（plan 的多輪 adversarial review） | Chase AI 原創 |
| `codex-build` | Codex 寫 code、Claude 審 diff（role-flip） | 改編自 steipete `codex-first` |

Act 2 協定核心：`PLAN.md` + `PLAN-REVIEW-LOG.md` 兩產物、`VERDICT: APPROVED/REVISE` token、resume 同 session 讓 Codex 記得前輪批評、`MAX_ROUNDS` 上限、deadlock 不假裝收斂、Claude 為最終仲裁者。

Act 3 協定核心：clean-tree gate → 契約式 prompt（GOAL/SPEC/KEY PATHS/CONSTRAINTS/NON-GOALS/PROOF/OUTPUT）→ Claude 讀全 diff 並自跑 proof（Codex 報告只是 advisory）→ bounded fix rounds → human 簽核 → Claude 寫 commit（Codex 永不 commit）。

---

## 2. 決定性發現：機制層已被官方 plugin 覆蓋且做得更好

`~/.claude/plugins/cache/openai-codex/codex/1.0.4/scripts/codex-companion.mjs`（1027 行）實測：

| 面向 | repo 手刻 bash | 官方 companion |
|---|---|---|
| 呼叫方式 | `codex exec ... \| grep '"type":"thread.started"'` | app-server protocol（`lib/app-server.mjs` + broker） |
| sandbox | 靠人記得下 `-s` / `-c sandbox_mode` | `codex-companion.mjs:411` review 路徑硬編碼 `sandbox: "read-only"`；`:488` task 路徑 `write ? "workspace-write" : "read-only"` |
| session 續接 | 自己 parse `thread_id`、自己傳 | `resumeThreadId` / `--resume-last`，`:467-491` 內建 thread 追蹤 |
| 背景執行 | 靠 Bash tool `run_in_background` | 內建 job-control（`lib/job-control.mjs`、`tracked-jobs.mjs`） |
| 輸出 | `-o /tmp/file` 再讀 | structured output + JSON schema 驗證（`review-output.schema.json`） |
| stderr 噪音 | `2>/dev/null` 硬吞（會一併吞掉真錯誤） | 分離 stdout/stderr 回傳 |

**結論**：在本機採用 repo 的 bash = 繞過已封裝、已測、有維護的 wrapper，改用無人維護的 shell 字串。`2>/dev/null` 尤其危險——它把 auth/model 失敗與 cosmetic 噪音一起吞掉。

### 但機制覆蓋 ≠ 協定覆蓋

官方 `codex-companion.mjs:355-450` 的 `executeReviewRun` 是**單發**（一次 `runAppServerTurn`，無迴圈），對象是 **code / diff**（`resolveReviewTarget` 取 working-tree / branch / `--base`），不是 plan 檔。`executeTaskRun` 有 `--resume-last`，但那是「繼續上次任務」，不是「帶著上輪批評重審同一份 plan 直到收斂」。

---

## 3. 缺口驗證（robust，非 `grep -r`）

依 `grep-recursive-false-negative-claude-tree` 教訓，改用 `find | xargs grep`：

```
~/.agents 主 tree（排除 .worktrees）:
  'codex exec'                       → tests/codex-git-push-guard.sh（無關）+ 2 份 2026-07 proposals（歷史文件）
  'PLAN-REVIEW-LOG|codex-build|codex-review' → 只在 2026-07-27 proposals（歷史文件）
~/.claude/skills                     → 0 命中
```

**live skills 中零命中。** 缺口成立：

1. **跨模型 plan-level review 不存在。** S5 只有 Standards / Spec 兩軸，兩軸都是同一顆 Claude 的 subagent——結構性回音室。S0 route 表沒有任何「送外部模型審 plan」的路由。
2. **write-capable 外部代理沒有驗證協定。** `codex:rescue` 是 forwarder，`codex-cli-runtime/SKILL.md:41-42` 明文禁止 Claude 做任何跟進：「Do not inspect the repository… Return the stdout of the `task` command exactly as-is.」預設還是 `--write`（`:24`）。也就是：**外部模型可以寫檔，而本機沒有任何強制的 diff 自審協定**。這是 `codex-build` 最有價值的一塊。

---

## 4. 與 house workflow 的衝突（原樣引入即 bypass）

| 衝突 | 條文 | 說明 |
|---|---|---|
| `codex-build` 收尾＝「proof 過 + diff 讀過 → Commit?」 | **S5 / [INT-1]** | 跳過 Standards／Spec 兩軸、跳過 `references/ledgers.md` 的 Preflight／Closeout、不填 `PASS/FAIL/SKIPPED/UNAVAILABLE` |
| `codex-build` 適用範圍含 "bug fixes with a known repro"，但流程無 RED→GREEN | **[INT-2]** | 直接違反「fix 前先有 failing regression test」 |
| `codex-review` 的「human sign-off 後才寫 code」 | **S2 / [T0-8] / [INT-3]** | 與 plan gate 是兩套語彙的同一個閘 → 產生兩個競爭核准點 |
| Codex 是外部 CLI process，非 subagent | **[INT-4] 條文缺口** | 「預設 1 個、最多 2 個」是否涵蓋外部 process 未定義；write-capable 外部 process 風險高於 read-only subagent，應否需獨立授權亦未定義 |
| `--yolo` / `--dangerously-bypass-approvals-and-sandbox` | **[T0-6]** | 但 repo 的 **clean-tree gate 恰好就是 [T0-6] 要的 rollback 策略**——這點對 repo 有利，是它比官方 `codex:rescue` 嚴謹之處 |

**這是「為何要自建而非 vendored 原樣使用」的正解**：任何把它綁進 dev-workflow gate contract 的動作就是編輯第三方 skill，就是 fork。

---

## 5. 治理分類（兩類，處置不同）

依 `vendored-forks.md` 開頭規則：禁的是**原地編輯**，wholesale vendoring 合法。

**類 A — 不引入：`grill-me-codex` / `grill-with-docs-codex`**
- Act 1 與 pinned Matt 22 集合的 `grilling` / `grill-me` / `grill-with-docs` **內容重複**，違反本年度持續進行的去重工作。
- repo 只出 Claude 形態，**無 `agents/openai.yaml`** → 破三 host parity（結論由 repo 檔案樹直接支撐，不引用任何未自查的本機計數）。
- 本機 `grilling` 已是 recorded fork（opt-in 預設授權段落），引入第三方變體會製造第二個真理來源。

**類 B — 協定可用、實作不可用：`codex-review` / `codex-build`**
- Chase AI 原創 MIT，無 Matt 內容 → wholesale vendored **是乾淨的**，不是 fork 問題。
- 但第 4 節的綁定需求把它推向自建：要接 S4/S5/S6 gate、要 [INT-2] RED→GREEN、要三 host parity，就必須改，改就是 fork。

---

## 6. 環境假設（不可照抄 repo 預設）

| 項目 | 本機實測 | 影響 |
|---|---|---|
| `codex --version` | 0.146.0 ✓（repo 要求 ≥0.130，其驗證基準為 0.137） | 通過 |
| `codex exec resume` 無 `-s/--sandbox` | **0.146 實測仍成立**（`--help` 完整 options 無 `-s`，僅 `-c`） | repo 的核心安全提醒在本機**確實 load-bearing**——若走手刻 bash |
| `sandbox_mode` | `"workspace-write"`（非 `danger-full-access`，但仍可寫檔） | resume 繼承即可寫檔 → 上一列的提醒有實效 |
| `model` | `"gpt-5.6-sol"`（已 pin，非 `-codex` 變體） | repo 的「別 pin」是指別 pin `gpt-5.x-codex` 變體；本機 config 預設可用。但 repo 的「Round 1 前 echo 模型」變得更必要 |
| `model_reasoning_effort` | `"ultra"` | ⚠️ 配 `MAX_ROUNDS=5` 的成本／延遲未知。**建議 `rounds=2` 起步實測一輪再定預設** |
| `approval_policy` | `"on-request"` | ⚠️ repo 假設 `never` 或不詢問的 sandbox；`on-request` 在非互動 `codex exec` 下的行為**未驗證**。標待驗，非阻擋 |
| stop-review-gate | 未啟用（opt-in，需 `codex:setup` toggle；無 state 檔） | 現況沒有跨模型 review 在自動跑 |

**注意**：若改走官方 companion（建議做法），`sandbox` 由 companion 硬編碼（`:411` review 路徑 `read-only`；`:488` task 路徑 `write ? "workspace-write" : "read-only"`，14:57 複驗仍在），上表第 2、3 列的坑**不存在**——這是採 companion 而非手刻 bash 的又一理由。

### 6.1 repo 的兩個操作陷阱：對本機**不適用**（14:57 新驗）

repo 記錄兩個 `codex exec` 陷阱：(a) `codex exec` 除 prompt arg 外**仍讀 stdin**，非 TTY 驅動下無 `< /dev/null` 會靜默 hang 在 ~0% CPU；(b) Bash tool 預設 2 分鐘 timeout 會腰斬真實 review，需 600s 上限。

實測本機 plugin 目錄（`~/.claude/plugins/cache/openai-codex/codex/1.0.4/`）：

```
find <plugin> -type f \( -name '*.md' -o -name '*.mjs' -o -name '*.js' -o -name '*.json' \) | xargs grep -ln 'codex exec'   → 0 命中
find <plugin> -type f | xargs grep -ln '/dev/null'                                                                          → 0 命中
codex-cli-runtime/SKILL.md:12 → node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task "<raw arguments>"
```

本機**從不 shell `codex exec`**，走 app-server protocol。兩個陷阱皆為 repo 手刻 bash 路徑專屬，**不適用於本機現有呼叫路徑**，也不構成須記入 memory 的通用知識。僅在**未來若有人繞過 companion 直接下 `codex exec`** 時才復活——這反過來成為「禁止手刻 bash」的第三個理由。

---

## 7. 建議（分級，待核准後執行）

> **執行狀態（14:57 查核）：P1／P2／P3 全數未執行。**
> `ls ~/.agents/skills/ | grep -iE 'cross-model|plan-review|external-agent|codex'` → 無命中；
> `grep -oE '\[INT-[0-9]+\]' ~/.agents/skills/dev-workflow/SKILL.md` → 止於 `[INT-8]`，無 `[INT-9]`、無「write-capable 外部代理」條文。
> 本節仍是提案，不是既成事實。

### P1 — 值得做：新建 house skill `cross-model-plan-review`

抽 `codex-review` 的**協定**，機制走官方 companion。

**成本說明（14:57 複驗更正，初稿低估）**：初稿聲稱「不需要新機制，只需加一層契約」。實測不成立——

| 實測 | 行號 | 意涵 |
|---|---|---|
| CLI `booleanOptions` 只有 `--resume-last` / `--resume` | `:735` `:747` | **無** `--resume-thread <id>`；`valueOptions`（`:734`）僅 `model/effort/cwd/prompt-file` |
| `resumeThreadId` 純內部推導 | `:467-475` | 由 `resolveLatestTrackedTaskThread(workspaceRoot)` 取「本 repo 最新 tracked thread」，caller 不可指定 |
| `buildTaskRequest` 無 `resumeThreadId` 欄位 | `:601-608` | 確認無隱藏傳入路徑 |
| **但** `executeTaskRun` 回傳 `threadId` | `:510` `:518` | 契約層拿得到 thread identity → 可做斷言 |

**修正後的成本**：resume-last 在「迴圈期間獨占 codex」的前提下確實會指回同一 thread，但那是**隱式狀態**——期間若有任何其他 codex job（並行 `rescue`、stop-review-gate）產生更新的 thread，latest 會漂移，**靜默接錯 session 且不報錯**。因此 P1 必須自帶一層 **thread-identity 斷言**：首輪記下回傳的 `threadId`，其後每輪 resume 後比對，不符即中止並攤開。

這仍比「自建迴圈」便宜得多（沿用 companion 的 app-server、sandbox 硬編碼、job-control），但**不是零機制**。該斷言本身即安全控制，不是額外負擔。

- 產物契約沿用：`PLAN.md` + `PLAN-REVIEW-LOG.md`（後者是真正的資產——分歧的完整記錄）。
- 收斂契約沿用：`VERDICT` token、`MAX_ROUNDS` 上限、deadlock 明確攤開不假裝收斂、Claude 為最終仲裁者且拒絕理由必須落 log。
- 機制改走 `codex-companion.mjs`（read-only 已硬編碼），**不要**手刻 `codex exec`。
- 接線：S0 route 新增一列（觸發條件＝schema／auth／payment／migration／concurrency 等高風險 plan）；核准點與 S2 [T0-8] **合併為同一個**，不另設。
- 三 host：附 `agents/openai.yaml`。Codex host 上角色反轉（Codex 為 builder，reviewer 應改指 Claude 或標 SKIPPED），此點需明確決策。
- 起始參數：`rounds=2`（非 repo 預設 5），實測成本後再調。

### P2 — 值得做：write-capable 外部代理的驗證協定（house-owned）

缺口是「外部代理寫完檔沒人驗」，不是「缺一個委派工具」。

**落點必須是 house-owned。** `codex:rescue` 與 `codex-cli-runtime/SKILL.md` 位於 `~/.claude/plugins/cache/openai-codex/codex/1.0.4/`——plugin 所有、第三方、**下次版本升級即被覆寫**。在那裡編輯同時違反 vendored gate 且會自我抹除。兩個合法落點，需擇一：

- **(a)** `~/.agents/skills/dev-workflow/SKILL.md` 加一條治理 clause（S4 內，或新增 [INT-9]），管轄**任何** write-capable 外部代理的產出；或
- **(b)** `~/.agents/skills/` 新建 house skill，由 S0 route 在 rescue handoff 前後導向。

協定內容（無論落點）：

- clean-tree gate（＝[T0-6] rollback）
- Claude 必讀全 diff、必自跑 proof（外部代理報告一律 advisory）
- bounded fix rounds，超過即收回自己做
- 收尾接 S4 → S5 → S6，**不是** repo 的「Commit?」單問
- BUGFIX 路徑強制 [INT-2] RED→GREEN

### P3 — 條文缺口（範圍比初稿窄）：main context 直呼外部 CLI

`codex:codex-rescue` 已註冊為 **Agent type**（Tools: Bash），經 Agent tool 呼叫時就是 subagent，[INT-4] 末句已綁定：「Subagent 回報不是完成證據，main context MUST 重驗」。**那不是缺口，是既有規則。**

真正未定義的是更窄的一種：main context 直接 `Bash(node codex-companion.mjs task --write …)` 或 `codex exec`——不經 Agent tool，因而完全繞過 [INT-4]。

這使 **P2 從「新政策」降級為「conformance 修補」**：[INT-4] 早已要求 main context 重驗，P2 只是把「重驗長什麼樣」寫成可稽核的協定。

### 不做

- 不 `cp -r skills/*` 到任何 skill 目錄。
- 不引入 `grill-me-codex` / `grill-with-docs-codex`（第 5 節類 A）。
- 不採用 repo 的手刻 `codex exec` bash（第 2 節）。

---

## 8. 驗證方式（執行時）

- 官方 companion 的 read-only 硬編碼：`grep -n 'sandbox' codex-companion.mjs` → 行 411 / 488
- 缺口聲明：`find ~/.agents -type f -not -path '*/.git/*' -not -path '*/.worktrees/*' -print0 | xargs -0 grep -ln 'codex exec'`
- resume 無 `-s`：`codex exec resume --help`
- 新 skill 落地後：`tests/vendored-detection.sh`、`tests/matt-thin-workflow.sh`、positive/negative trigger canary
