# Codex 收斂後最終建議：請 Claude Code 新 session Review

> 日期：2026-07-27  
> 性質：read-only migration proposal review  
> 目的：請 Claude Code 重新驗證 Codex 與 Claude 前兩輪意見收斂後的最終方案是否合理。  
> 限制：不要修改任何設定、skill、plugin、hook、generated host file 或 repo 檔案；所有 live config、plugin cache、skill listing 與 upstream 狀態都要附 Asia/Taipei 觀測時刻。

## 給新 session 的讀取順序

請依序完整讀取：

1. `/Users/pochientsai/.agents/proposals/2026-07-27-mattpocock-skills-workflow/08-codex-final-proposal.md`
   - Codex 原始 Phase 1–7、Phase 6 九項條件與完整職能對照。
2. `/Users/pochientsai/.agents/proposals/2026-07-27-mattpocock-skills-workflow/07-review-of-codex-final.md`
   - Claude 對原始建議的 review。
3. 本文件。
   - 已納入後續 live probes、Codex 對 Claude review 的回應與二次修正。

必要時再讀：

- `/Users/pochientsai/.agents/proposals/2026-07-27-mattpocock-skills-workflow/01-skills-inventory.md`
- `/Users/pochientsai/.agents/skills/dev-workflow/SKILL.md`
- `/Users/pochientsai/.agents/core/tier1-workflow.md`
- `/Users/pochientsai/.agents/skills/auditing-skill-folder/SKILL.md`
- `/Users/pochientsai/.agents/skills/auditing-skill-folder/step7-style-checks.md`

## 請 Claude Review 的要求

請逐項回答：

1. `同意`、`部分同意` 或 `不同意`。
2. 每個不同意項目必須附 live file/line、probe command 或 upstream source evidence。
3. 區分：
   - confirmed defect；
   - missing carrier；
   - migration risk；
   - conditional optimization；
   - naming／maintenance debt。
4. 不要只做 wording review；請檢查 routing、invocation、cross-skill reference、active discovery root、rollback 與三 host 可執行性。
5. 若建議修改本方案，請提供最小差異版本，不要重寫已收斂部分。

---

# 一、最終結論

導入 Matt Pocock stable 22，讓它取代 Superpowers 與四支舊 `mp-*` 的方法論／orchestration；保留精簡的全域 workflow kernel。

遷移原則：

- Kernel 決定能不能做、何時算完成。
- Matt skills 決定如何釐清、規劃、實作、診斷與 review。
- hooks／CI 負責不可依賴模型自律的機械 gate。
- `setup-matt-pocock-skills` 安裝但不自動執行。
- 四支 `mp-*` 的目標狀態仍是退休，但刪除前由遷移方逐支完成 file-level semantic diff。
- 完成 canary、semantic migration 與十項 Phase 6 gate 後，最後才逐 host 移除 Superpowers。

整體風險：**高**。

原因不是單一 skill 品質，而是同時涉及：

- 三 host routing；
- model-invoked collision；
- cross-skill references；
- active artifact paths；
- delegation／workspace isolation；
- plugin removal；
- rollback 與新 session inventory。

# 二、建議終態

```text
全域 workflow kernel
├── Tier 0 safety rules
├── routing / authorization
├── plan-first 與風險分級
├── red→green bugfix gate
├── delegation gate
├── worktree / workspace isolation
├── S4–S6 evidence / review / closeout
├── PR / CI / branch finishing
├── setup compatibility adapter
└── hooks / CI 機械攔截

Matt Pocock stable skills
├── needs / design
│   ├── grill-with-docs
│   ├── grilling
│   ├── domain-modeling
│   ├── codebase-design
│   └── prototype
├── planning / orchestration
│   ├── ask-matt
│   ├── to-spec
│   ├── to-tickets
│   ├── wayfinder
│   ├── implement
│   └── handoff
├── implementation discipline
│   ├── tdd
│   ├── diagnosing-bugs
│   └── resolving-merge-conflicts
├── review / maintenance
│   ├── code-review
│   ├── improve-codebase-architecture
│   ├── triage
│   └── research
├── productivity
│   ├── grill-me
│   ├── teach
│   └── writing-great-skills
└── installed but not auto-executed
    └── setup-matt-pocock-skills

本機保留
└── mp-zoom-out
```

安裝範圍：

| 範圍 | 決策 |
|---|---|
| `skills/engineering` 17 支 | 全部導入 |
| `skills/productivity` 5 支 | 全部導入 |
| Stable 合計 22 支 | 建議 |
| `in-progress`、`misc`、`personal`、`deprecated` | 不導入 |
| Installer 顯示的全部約 38 支 | 不建議 |

# 三、Superpowers 職能對照

| Superpowers 職能 | 新載體 |
|---|---|
| brainstorming | `grill-with-docs` + `grilling` |
| writing-plans | `to-spec` + `to-tickets` |
| executing-plans | `implement`，完成後必須回 kernel S4–S6 |
| test-driven-development | `tdd` + kernel red→green gate |
| systematic-debugging | `diagnosing-bugs` |
| requesting-code-review | `code-review` |
| receiving-code-review | kernel S5 technical triage |
| verification-before-completion | `[T0-2]` + S4–S6 |
| finishing-a-development-branch | kernel closeout + PR/CI rules |
| dispatching-parallel-agents | canonical S3 delegation gate + host adapters |
| subagent-driven-development | canonical delegation gate + ticket／implement workflow |
| using-git-worktrees | `[T1-10]` workspace isolation + S3 reference |
| writing-skills | user-invoked `writing-great-skills` + migrated local audit semantics |

核心論證不變：

> 真正可靠的 gate 應放在 kernel、hooks 與 CI，而不是寄放在另一套第三方長篇 skill prose 裡。

# 四、三個缺失載體的修正

## 4.1 Delegation policy

### 正確落點

`/Users/pochientsai/.agents/skills/dev-workflow/SKILL.md`

- 段落：`### S3 IMPLEMENT`
- 位置：現有 `ACTION` 內，作為三 host canonical gate。
- Host adapters 只保留工具名稱映射。

### 建議語義

- 至少有兩個可獨立驗證的 subtasks 才可 delegation。
- 有寫入時，file ownership 不得重疊。
- Read-only research 時，evidence scope 不得重疊。
- 使用者、repo 或更高層 instructions 必須允許 delegation。
- Subagent 回報不等於完成；主 context 必須重驗。
- 不符合條件時標 `SKIPPED` 並附理由，不做 smoke spawn。

這比只補 Claude adapter 更好，因為 delegation safety 是三 host 共通 invariant。

## 4.2 Workspace isolation

### 正確落點

1. `/Users/pochientsai/.agents/core/tier1-workflow.md`
   - 在 `[T1-9]` 後新增 `[T1-10] Workspace isolation`。
2. `/Users/pochientsai/.agents/skills/dev-workflow/SKILL.md`
   - `S3 IMPLEMENT ACTION` 的 branch step 引用 `[T1-10]`。

### 建議語義

- 只有獨占且沒有其他 session／host 使用的 checkout，才可原地切 branch。
- 共享 checkout、並行 task，或 branch switch 會改變其他 host 正在讀取的 symlink／config 時，必須使用獨立 worktree 或 clone。
- `~/.agents` 這類 live global source 禁止在 active checkout 切換實驗分支。
- 編輯前驗證 resolved path、repo root、branch 與 worktree ownership。
- 不要求所有小任務強制 worktree；只在 isolation trigger 命中時生效。

## 4.3 Writing／audit semantics

`writing-great-skills` 應承接「如何撰寫 skill」的職能，但不能把三處 `superpowers:writing-skills` 直接換字串後宣稱完成。

原因：

1. Matt 的 `writing-great-skills` 是 user-invoked；它明寫 user-invoked skill 不能由其他 skill 自動觸發。
2. 現有 `step7-style-checks.md` 混合：
   - Agent Skills specification；
   - Superpowers 特有格式；
   - 本機 house audit policy。
3. `Use when…` prefix、固定 sections、rationalization table、Red Flags、Iron Law 等規則，不全是 Matt 契約。

### 正確遷移

- `auditing-skill-folder/SKILL.md` 的「建立新 skill」指引：
  - 改成由使用者明確 invoke `writing-great-skills`。
- 移除 `REQUIRED BACKGROUND: superpowers:writing-skills`：
  - 不要換成另一個不可由 model 自動觸發的 REQUIRED BACKGROUND。
- `step7-style-checks.md` 每條規則逐項分類：
  - Agent Skills specification；
  - Matt `writing-great-skills` guidance；
  - 本機 house policy；
  - 不再成立、應刪除的 Superpowers-specific rule。

完成條件是 semantic migration，不是 grep 不到舊名稱。

# 五、`setup-matt-pocock-skills` 處理方式

## 決策

- 安裝。
- 不在全域遷移時自動執行。
- 不允許其他 skill 因缺 contract 而自行執行 setup。
- 缺 contract 時停止，提出 draft，取得使用者確認後才建立。

## 為何仍要安裝

至少以下 skills 會要求 setup context：

- `ask-matt`
- `code-review`
- `triage`
- `to-tickets`
- `to-spec`
- `wayfinder`

不安裝會使 cross-reference 懸空；直接執行則會：

- 修改 `AGENTS.md`／`CLAUDE.md`；
- 建立多份 `docs/agents/*.md`；
- 可能引入 `.scratch/`；
- 與既有 X1 persistence 並存。

## 最小 compatibility adapter

`dev-workflow` 增加一條三 host 共用規則：

> `setup-matt-pocock-skills` 可安裝但不得由 agent 自動執行。缺少 tracker contract 時停止並提出 draft；不得 fallback 到 `.scratch/`。Domain layout 由 X1 承接。

## 單一 repo contract

每個實際使用 Matt ticket workflow 的 repo，在使用者確認後建立：

```text
docs/agents/issue-tracker.md
```

至少包含：

1. Tracker 類型。
2. Publish／fetch／comment／close 操作。
3. 兩個 category roles：
   - `bug`
   - `enhancement`
4. 五個 state roles：
   - `needs-triage`
   - `needs-info`
   - `ready-for-agent`
   - `ready-for-human`
   - `wontfix`
5. PR 是否屬於 triage request surface。
6. Wayfinder 的：
   - map；
   - child；
   - blocking；
   - claim；
   - frontier；
   - resolve。
7. Spec／ticket canonical artifact 位置。
8. 明確禁止或允許 `.scratch/`；本機預設禁止。
9. Domain docs 由 X1 的 `CONTEXT.md`／`docs/adr/` 承接。

`docs/agents/domain.md` 可省略，除非 live Matt skill probe 證明仍有不可替代的 consumer。

# 六、X1 active path 中性化

目前 `dev-workflow` X1 仍使用：

```text
docs/superpowers/specs/
docs/superpowers/plans/
```

移除 Superpowers 前：

- 新產物改用中性的 canonical path。
- 舊文件保留原路徑並標 historical。
- 不為了清名稱而大量搬移歷史文件。
- 更新 active consumers、routing 與 X1 表。
- 完成 grep／deps-check，確定沒有 dangling active reference。

這屬 active governance coupling，不只是 cosmetic naming。

# 七、更新後 Phase 1–7

## Phase 1：建立 read-only baseline

風險：低。

- 記錄三 host plugin／skill inventory。
- 記錄 settings、plugin cache 與 skill listing 的觀測時刻。
- 列出所有 active `superpowers:`、`mp-*`、setup 與 cross-skill references。
- 記錄 Matt upstream commit。
- 分別量測 description 與 SessionStart 成本。
- 建立移除前 rollback inventory。
- 確認 source-of-truth 與 generated host files。

Exit：

- Baseline 可重現。
- 所有 live claims 有時間戳。
- 未修改任何設定或 plugin。

## Phase 2：Sidecar 安裝

風險：中。

- 導入 stable 22。
- 安裝但不執行 setup。
- 不刪 Superpowers。
- 不刪 `mp-*`。
- Matt upstream files 保持 immutable。
- 本機政策只放 kernel 或薄 adapter。
- 補 setup compatibility rule。

Rollback：

- 移除 Matt routing／sidecar。
- 舊 workflow 仍完整存在。

## Phase 3：切換 routing 與補載體

風險：高。

切換：

```text
mp-diagnose                      → diagnosing-bugs
mp-grill-with-docs               → grill-with-docs
mp-improve-codebase-architecture → improve-codebase-architecture
mp-tdd                           → tdd
```

同階段完成：

- Canonical S3 delegation gate。
- `[T1-10]` workspace isolation。
- Writing／audit semantic migration。
- Setup compatibility adapter。
- X1 active path 中性化。
- 更新 dev-workflow、host routing injection、cross-references 與 active Superpowers references。

Rollback：

- 還原 routing source-of-truth。
- 跑 `agents-sync`。
- 新 session 驗證舊 inventory 恢復。

## Phase 4：隔離 A/B Canary

風險：中。

### 4A：舊環境 baseline

- 使用現行 Superpowers + `mp-*` 跑代表性任務。
- 保存 routing、evidence、完成條件與輸出。

### 4B：Candidate canary

- 保留舊 skills 的可恢復副本。
- 將被替換的 model-invoked `mp-*` 移出 active discovery root。
- 啟用 Matt candidate routing。
- 重新開新 session。
- 跑相同任務類型。

### Coexistence probe

只保留一次刻意的 coexistence collision probe，用來確認：

- `mp-tdd` vs `tdd`；
- `mp-diagnose` vs `diagnosing-bugs`；
- 是否會雙重載入或不穩定 routing。

正式 canary 不讓兩套 model-invoked skills 長期競爭。

### 覆蓋任務

至少 5–10 個真實任務：

- 小型 feature。
- 中型 feature。
- 明確 bugfix。
- flaky／performance diagnosis。
- architecture review。
- 多 session spec／tickets。
- code review。
- PR／branch closeout。

### Trigger ledger

| 欄位 | 要求 |
|---|---|
| Intended skill | Routing 預期選哪支 |
| Actual skill | 實際讀取／觸發的 skill |
| Source | 本機、Matt upstream 或 fallback |
| Invocation | User-invoked、explicit routing 或 model auto-trigger |
| Collision | 是否兩支都載入／執行 |
| Result | PASS／FAIL／UNAVAILABLE |
| Evidence | Load path、宣告訊息或 host trace |

### 每次必查

- 未確認需求前不得改檔。
- Bugfix 先有 failing regression test。
- Test／build／lint evidence 完整。
- Standards + Spec review 都有結果。
- Evidence 不足時不能宣稱完成。
- `implement` 完成後回到 S4–S6。
- Ticket 可在乾淨 context 完成。
- Setup 沒有被自動執行。
- 沒有自行建立 `.scratch/`。
- Delegation 與 worktree gate 生效。

任一 routing winner 無法解釋、發生雙重執行，或 evidence 不足仍能宣稱 done，即不得進 Phase 5。

## Phase 5：逐支 semantic diff 後退休四支 `mp-*`

風險：中。

目標狀態：

- 退休 `mp-diagnose`。
- 退休 `mp-grill-with-docs`。
- 退休 `mp-improve-codebase-architecture`。
- 退休 `mp-tdd`。
- 保留 `mp-zoom-out`。

但 canary 通過不足以直接刪除。

每支先建立 parity ledger：

| 欄位 | 內容 |
|---|---|
| Local file | 本機檔案／script／reference |
| Upstream carrier | 對應 Matt skill／file |
| Byte status | identical／different／missing |
| Semantic status | duplicate／upstream-superset／local-unique |
| Action | retire／re-home／retain |
| Evidence | Hash／diff／引用位置 |

未解決的 `local-unique` 必須：

- 搬到正確 canonical carrier；或
- 明確保留舊 skill。

目前已重驗：

- `mp-diagnose/scripts/hitl-loop.template.sh` 與 upstream byte-identical。
- `mp-tdd/mocking.md` 與 upstream byte-identical。
- `mp-grill-with-docs/ADR-FORMAT.md` 與 upstream byte-identical。
- `mp-tdd/tests.md` 不是 byte-identical；本機版是 upstream 子集，上游多了 tautological-test 規則與範例。

退休優先採可回復 archive／git revert，不做無追蹤 hard deletion。

## Phase 6：移除 Superpowers

風險：高。

只有以下十項全部 PASS 才可逐 host 移除：

1. Active config、routing、X1 canonical paths 與 active docs 中的 `superpowers:`／Superpowers governance coupling 歸零；歷史文件可保留但必須明標 historical。
2. 四支 `mp-*` 均完成 file-level parity ledger；獨有內容已 re-home 或有明確保留決策。
3. `verification-before-completion` 已由 `[T0-2]` + S4–S6 承接。
4. Branch finishing／PR／CI closeout 已有明確載體。
5. Red→green bugfix gate 有真實任務證據。
6. `code-review` 同時完成 Standards 與 Spec 兩軸。
7. Workspace isolation policy 內容已核准並進入 source-of-truth。
8. `implement` 不會跳過 kernel closeout。
9. 三 host 的新 session inventory 與真實任務 canary 全部通過。
10. 三個原缺失載體已實際存在且可執行：
    - canonical S3 delegation gate 在 Claude、Codex、Copilot 均生效；
    - `[T1-10]` 已同步至三 host，並以 worktree probe 驗證；
    - writing／audit semantics 已完成遷移，沒有 dangling background reference，也沒有把 user-invoked skill 誤當 model-invoked dependency。

移除順序：

1. Claude。
2. 開新 session 驗證。
3. Codex。
4. 開新 session 驗證。
5. Copilot。
6. 開新 session 驗證。

任一 host 失敗即停止後續移除。

Rollback：

- 以 Phase 1 inventory 重裝相同版本 Superpowers。
- 恢復 routing source-of-truth。
- 跑同步與新 session inventory。
- 不跨 host 同時 rollback。

## Phase 7：最後瘦身 kernel

風險：中。

只刪已被 Matt skills 完整承接、且 canary 證明重複的 prose。

必留：

- Tier 0。
- Routing／authorization。
- Plan-first 與風險 gate。
- Delegation。
- Workspace isolation。
- Evidence／review／closeout。
- PR／CI。
- hooks 與機械 guard。
- Setup compatibility adapter。

# 八、最終決策表

| 決策 | 建議 |
|---|---|
| 導入 Matt stable 22 | 建議 |
| 安裝全部約 38 支 | 不建議 |
| 導入 `misc/` | 不建議 |
| 讓 Matt 取代安全 kernel | 不建議 |
| 讓 Matt 取代 workflow 方法論／orchestration | 建議 |
| 安裝 `setup-matt-pocock-skills` | 建議 |
| 自動執行 setup | 不建議 |
| 使用單一 compatibility contract | 建議 |
| 直接把 writing reference 換字串 | 不建議 |
| 做 writing／audit semantic migration | 建議 |
| 兩套 model-invoked skills 長期並存 canary | 不建議 |
| 隔離 A/B canary | 建議 |
| Canary 後直接刪四支 `mp-*` | 不建議 |
| Semantic diff 後退休四支 `mp-*` | 建議 |
| 保留 `mp-zoom-out` | 建議 |
| 移除 Superpowers | 建議，十項 gate 後逐 host |
| 以 token 節省為主要理由 | 不建議 |
| 以單一 upstream、降低重複維護為理由 | 建議 |

# 九、請 Claude 特別裁決的問題

請明確回答以下七題：

1. Delegation gate 放 canonical S3，而不是只補 Claude adapter，是否正確？
2. `[T1-10]` + S3 reference 是否足以承接 `using-git-worktrees`，還缺哪個 mechanical probe？
3. Writing／audit semantic migration 是否正確？是否仍需要任何可自動載入的 authoritative background carrier？
4. 單一 `docs/agents/issue-tracker.md` 是否足以承接 setup 契約？是否存在必須保留 `domain.md` 或 `triage-labels.md` 的 live consumer？
5. 隔離 A/B canary 是否優於長期 coexistence？Phase 3–5 的 rollback 是否仍完整？
6. 四支 `mp-*` 的 parity ledger 是否足以避免遺失本機獨有知識？
7. Phase 6 十項 gate 是否完整、可驗證且沒有互相循環？

若不同意，請提供最小修正，不要回退已收斂的核心架構：

> Matt 取代方法論／orchestration，kernel 保留治理與完成 gate，Superpowers 最後才移除。
