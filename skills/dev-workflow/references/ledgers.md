<!-- tier: workflow-reference | consumed-by: claude,codex,copilot | referenced-from: dev-workflow/SKILL.md S6 CLOSEOUT | generated-from: proposals/2026-07-07-three-host-unification/03-workflow-layer.md + .codex/AGENTS.override.md（closeout evidence policy）| last-verified: 2026-09-05 -->

# ledgers.md — S6 CLOSEOUT 的 ledger 定義

> 讀者是 AI 模型。本檔是 `dev-workflow/SKILL.md` S6 CLOSEOUT 引用的 ledger 權威定義。
> 指紋（context 載入驗證用，勿刪）：FP:LEDGERS-2026Q3。

三種 ledger，時機與作用不同，勿混用：

| Ledger | 時機 | 落點 | 列數 | 阻擋作用 |
|--------|------|------|------|---------|
| **Preflight** | push / 開 PR **之前** | 寫進 PR body | 8 rows | 缺 row 或缺證據 → 不得 push / 開 PR |
| **Closeout** | 實作 / 開 PR / merge 後的**最終回覆** | 可見於回覆正文 | 依結果 | 缺 outcome、必要驗證或未解風險 → closeout 不完整 |
| **Postflight** | merge **之後** | 回覆一行帶過 | 2 項 | 無（收尾記錄） |

四態標記（全鏈通則，同 SKILL.md）：`PASS` / `FAIL` / `UNAVAILABLE`（須附 probe 失敗證據）/ `SKIPPED`（須附理由）。無證據不得標 PASS。

## Closeout 後的新 commit

- Checkpoint 不重設 baseline，也不使未跑的 S5／CI／review 變成 PASS；publication 一律以原 baseline 到 current HEAD 的累積 diff 判定。
- 第一次 checkpoint 前在 Preflight ledger 記錄 immutable baseline SHA（target merge-base）；publication 先用 `git merge-base --is-ancestor <baseline> HEAD` 驗證，失敗即 gate FAIL，重新確認 target merge-base 後跑全套重驗。
- `git merge-base <PR 的 baseRefOid> HEAD` MUST 等於記錄的 baseline SHA——用 base 的實際 commit SHA（`gh pr view <n> --json baseRefOid`），不是分支名：本地的 `main` ref 與 GitHub 上的 base commit 可能不同，拿分支名算出來的 merge-base 驗的是另一件事。S5 審查範圍即 `git diff <baseline>..HEAD`。不相等時 GitHub 呈現的 diff 會含入 baseline 之前的 commit，「這個 PR 的 diff」就有兩種讀法——要嘛同一份 code 被重複審，要嘛因為「看起來審過了」被略過。比對 merge-base 而非 base 本身：base 換了但祖先鏈仍含 baseline 時（PR 被 retarget 到已含前一批變更的 main）range 其實沒變，比對 base 會誤報。用分支名指稱起點則對不回去：分支會被 force-push 更新，也會在 merge 後依 Postflight 刪除。
- S4 依 `git diff --name-only <前次 closeout SHA>..HEAD` 的累積影響重新判 risk tier 並重跑適用 checks；不得因新 commit 很小而降低整體風險。
- S5 只重審該 diff 觸及的檔案與其 transitive impact；未觸及範圍可沿用前次 findings 並註明 baseline SHA，範圍不得由 reviewer 任意縮小。
- S6 更新 user-facing closeout；未受影響的完整 evidence 留在 Preflight/session artifact 並可引用 baseline SHA。Current-head CI／review 結果一律失效並依 `review-triage.md` 重查。

---

## Stacked PR 的 diff scoping

一次交付拆成多個相依 PR 時（P2 建在 P1 之上），「Closeout 後的新 commit」的 base↔baseline 一致性有兩個 stack 特有的破法。

- merge 順序由 stack 底部往上，P2 的 `--base` 指 P1 的分支。
- **merge 方法由父 PR 決定，不由自己決定**：P2 的 baseline 存亡取決於 P1 怎麼被 merge——P1 一旦 squash，P2 的 merge-base 就退回 P1 之前，P2 自己屬於哪個範圍完全不影響這件事。所以判準看父 PR：
  - 父 PR 不在 [INT-10] 範圍（一般 product code）→ 父 PR MUST 用 merge commit 合併，不用 squash。這是對 Postflight「squash merge 預設」的具名例外。merge commit 讓父 PR 的 commit 真的落在 main 的祖先鏈上，retarget 後 `merge-base` 自動仍等於原 baseline，零補救；squash 則使那些 commit 從未進入 main，GitHub retarget 後呈現的 diff 會把父 PR 的變更整份帶回來，正是「Closeout 後的新 commit」要防的事改由 retarget 造成。
  - 父 PR 在 [INT-10] 範圍（全域／security config，含本 repo 的 kernel 與 references）→ 該條把 squash merge 釘進五步路徑，不得以本節豁免，其所有子 PR 一律走 rebase 補救，即使子 PR 自己不在 [INT-10] 範圍內。混合 stack 沒有中間狀態：stack 上只要有一層是全域 config，它以上的每一層都得付。上層付的是**父分支被改寫的 cascade**（P1 squash → P2 rebase → P2 被 force-push → P3 的 base 歷史跟著變），與 P2 自己用什麼 merge 方法無關——所以三層以上的 stack 不能逐層各判各的。
  - rebase 補救的內容：每次 merge 後 MUST rebase 到 main、重記 baseline SHA 再重驗。rebase 若內容中性（無 conflict resolution、無新 commit），S5 findings 沿用前次並註明原 baseline SHA；但 HEAD SHA 已變，CI 與 bot review 依「Closeout 後的新 commit」一律失效，MUST 於新 head 重查——每層 stack 因此多一輪 CI。不想付這個成本就別把全域 config 拆成 stack。
- retarget 後 MUST 實查一次 `gh pr view <n> --json baseRefOid --jq .baseRefOid`，確認 `merge-base(base, HEAD)` 仍等於記錄的 baseline——retarget 不動 HEAD，「Closeout 後的新 commit」的 `git merge-base --is-ancestor` 在 base 被換掉時仍為真，單靠它會回假 PASS。這是人工驗證項：`bin/pr-review-gate` 目前不取 base，stack 若成為常態，應把 `baseRefOid` 併進該 gate 既有的 `--json` 清單，而不是讓這條停留在散文。

---

## 1. Preflight Ledger（8 rows，寫進 PR body）

每 row 斷言一件事 + 明列什麼算證據。任一 row 缺席或標 PASS 卻無證據、**或缺下方兩軸狀態行** → 阻擋 push / 開 PR（[T0-2] 無 evidence 不得宣稱完成）。

八列之外，PR body MUST 另含 [S5-1] 兩軸的結論各一行，且**狀態值與軸名同一行**：

```
S5 Standards: <PASS|FAIL|SKIPPED（理由）|UNAVAILABLE（probe）>
S5 Spec: <同上>
```

寫在哪一節不拘（下方範例放在開頭），但這兩行是 row 6 的前提——沒有它們，「已審查」根本還沒宣告。host 側的機械檢查見 `host-adapters.md`。

| # | Row | 斷言什麼 | 什麼算證據 |
|---|-----|---------|-----------|
| 1 | **Scope** | 每行 diff 都可對應到本次需求 / task；無順手改的不相關格式 / 命名 | 引用 `sdd/<slug>/tasks.md`（或 plans doc）+ 一句自審：每個變更檔對得上哪條 task；無法追溯的順手改已移除或另開 task |
| 2 | **Git state** | 從乾淨 baseline 出發，工作在 `feat/` / `fix/` 分支（非 master）| 分支名 + 動手前 `git status` 為 clean 的紀錄；確認非 main / master（[T0-3]）；**immutable baseline SHA**（＝ target merge-base，「Closeout 後的新 commit」那節要求記錄的那顆，row 6 的 range 起點也取它）|
| 3 | **Diff self-review** | 每行變更已逐行看過；無自己殘留的 debug / TODO / dead code（unused import / var / func）| `git diff` 走查摘要；自造 dead code 已清（pre-existing 只標不刪）|
| 4 | **Self-simplification** | S4 四檢核與 S5 simplification apply outcome 通過：無 unrequested abstraction、無新依賴、無單一使用點抽象層、無 speculative config | 四項逐一標記 + apply outcome `changed`／`no-op`；有新依賴時附選型理由（原生 > 標準庫 > 既有模組 > 第三方 > 手寫）|
| 5 | **Tests evidence** | 適用的 risk-tier verification 已跑綠；BUGFIX 依 [INT-2] 證 RED→GREEN 或同一 repro before／after | 確切測試／repro 指令 + exit code + 通過數；Medium／High 或 PR 的 final verification pass 另綁 exact source state 與 replay command；High-risk 附 failure model 與 catching layer mapping；applicable E2E 附 repo-defined isolation boundary／cleanup evidence，無 E2E 或 isolation mechanism 則 `SKIPPED` 附理由且不得只為 gate 新造測試基礎設施；stable／valuable seam 附 RED→GREEN 順序，否則附同一 repro before／after 與不採 RED 的理由 |
| 6 | **Review gate** | 已審查、記錄 reviewer 型別、actionable findings 全數處理 | reviewer 型別 + agent id（或 UNAVAILABLE 附 probe 失敗證據）+ finding 摘要 + 審查對象 range `<baseline SHA>..<head SHA>`（baseline 同 row 2；head 取 findings 全數處理後的 HEAD——修 findings 那幾顆 commit 未再經審查時 MUST 明述，否則 range 看起來比實際被審過的範圍大）+ **逐字引用 `reviewer-template.md` 的 over-engineering baseline 五條中至少兩條的標題**（引得出＝真的讀到那一節；驗的是 contract 本身而非旁邊的識別碼，所以不隨季度輪替，也不怕被轉述——標題外流等於 contract 外流，那正是要的結果。弱訊號不是證明）；0 條未處理 actionable（「處理」的定義見 `reviewer-template.md` 的「回饋處理」）|
| 7 | **Security-release gates** | 會部署的變更已跑 `*-release-verification` + `dependency-security-scan`（正交必跑，非三選一）| 列出跑了哪些 gate + 結果；不部署則標 SKIPPED 附「本次不部署」理由 |
| 8 | **Residual risks** | 已知但接受的殘留風險已列舉；中高風險附 rollback | 風險清單（「無」是明述斷言不是留白）；中高風險變更附 rollback 註記（[T0-6]）|

**呈現粒度（八項語意一律不得省略，省的只有版面）：**

- 預設逐列展開。
- `Diff self-review` 與 `Self-simplification` 兩列，在**都是 PASS 且都沒有可報告內容**時（沒清掉 debug／dead code、沒新增抽象或依賴、沒有選型取捨）MUST 合併為一列，例：
  `3+4. Diff self-review／Self-simplification — PASS：逐行走查無殘留 debug／dead code；無 unrequested abstraction／新依賴／單一使用點抽象層／speculative config。`
- 任一列非 PASS，或有實際內容可報（清掉了什麼、加了什麼依賴、做了什麼取捨）→ 該列 MUST 獨立展開，理由與證據寫在該列。

理由：這兩列是八列中僅有的自我宣告，無獨立視角（`[S5-3]` 條文已明述），實際防護由 S5 review 與 bot review 承擔。壓縮的是版面不是評估——有任何實質內容時壓縮條件即不成立。

### 範例（已填）

```
## S5 兩軸

S5 Standards: PASS
S5 Spec: PASS：對照 sdd/batch-insert-chunk/proposal.md 逐條確認，無偏離

## Preflight Ledger

1. Scope — PASS：3 個變更檔皆對應 sdd/batch-insert-chunk/tasks.md 的 T1–T3；無不相關格式改動。
2. Git state — PASS：分支 fix/batch-insert-byte-chunk（非 master）；動手前 git status clean；immutable baseline SHA 0d9c8b7（= 開分支時的 origin/main）。
3. Diff self-review — PASS：git diff 逐行走查；移除臨時 Console.WriteLine 一處；無殘留 dead code。
4. Self-simplification — PASS：無新抽象／無新依賴／分塊邏輯僅 FileProcess 單處但為既有 caller 路徑非新增抽象層／無 speculative config。
5. Tests evidence — PASS：DOTNET_SYSTEM_NET_DISABLEIPV6=1 dotnet test ...Tests.csproj → exit 0，Passed! 398 個；BUGFIX 紅測 BatchInsert_ExceedsByteLimit_Splits 於修復前 commit（a1b2c3d）先紅。
6. Review gate — PASS：reviewer=dotnet-code-reviewer（agent id dcr-07）；審查對象 range 0d9c8b7..e4f5a6b（head 是修完 2 條 findings 後的 HEAD，非 row 5 那顆 pre-fix commit；修 findings 的 e4f5a6b 已回頭再審一輪）；送出的 prompt 含 baseline 五條，其中 Reinvented Stdlib 與 Wrong Altitude 兩條逐字引用於此；2 findings 皆採納並修；0 未處理。
7. Security-release gates — PASS：backend-release-verification 綠；dependency-security-scan 無高危 CVE（NuGetAudit exit 0）。
8. Residual risks — 大 payload 分塊邊界仰賴 UTF-8 byte 量測，非字元；風險低。rollback：revert 單一 commit 即回原批次 INSERT 行為。
```

---

## 2. User-facing closeout

完整 audit evidence 留在 Preflight ledger、session artifact 或 PR checks；最終回覆不重複固定六列。Closeout MUST：

1. 先說 outcome，以及未完成／被阻擋的 scope。
2. 只列足以支持 outcome 的 final verification；PR 路徑附連結與 current-head CI／review 狀態。
3. 明列仍會影響使用者決策的 residual risk；中高風險附 rollback。沒有殘留風險時不為格式硬加一列。

Relevant verification 在 High-risk 任務 MUST 包含 failure model 與 catching layer mapping。

任一 gate 為 `FAIL`／`UNAVAILABLE`、使用者要求 audit，或 evidence 不在可存取 artifact 時，展開相關證據與四態結果。其餘情況引用 Preflight/session artifact，不重述 self-simplification、diff self-review 或 reviewer metadata。

### 範例（PR、全 PASS）

```
已完成 <outcome>，PR <url>；current-head CI 與 bot review PASS，0 unresolved actionable findings。

驗證：<final source state> 執行 <replay command>，exit 0。殘留風險：<risk + rollback>。
```

---

## 3. Postflight（merge 後，簡短）

merge 完成後，回覆一行帶過兩項：

1. **刪分支**：合併後刪除該 PR 分支（remote + 已併入的 local），squash merge 預設（stack 的具名例外見「Stacked PR 的 diff scoping」）。
2. **BUGFIX settlement 指標**：若為 BUGFIX 鏈，MUST 已跑 `bug-fix-settlement` 並輸出評估摘要——沉澱去向（cookbook / memory / workflow）或明述「評估後不需沉澱」；非 BUGFIX 免此項。

### 範例（已填）

```
## Postflight
PR #64 squash merge 完成；已刪 remote + local fix/batch-insert-byte-chunk 分支。
BUGFIX settlement：根因（批次 INSERT 未依 byte 分塊致大 payload 逾 max_allowed_packet）已走 bug-fix-settlement，沉澱至 docs/cookbook/import/pitfalls.md 並更新 MOC.md。
```
