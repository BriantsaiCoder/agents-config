<!-- tier: workflow-reference | consumed-by: claude,codex,copilot | referenced-from: dev-workflow/SKILL.md S6 CLOSEOUT | generated-from: proposals/2026-07-07-three-host-unification/03-workflow-layer.md + .codex/AGENTS.override.md（Mandatory Closeout Ledger 收割）| last-verified: 2026-07-07 -->

# ledgers.md — S6 CLOSEOUT 的 ledger 定義

> 讀者是 AI 模型。本檔是 `dev-workflow/SKILL.md` S6 CLOSEOUT 引用的 ledger 權威定義。
> 指紋（context 載入驗證用，勿刪）：FP:LEDGERS-2026Q3。

三種 ledger，時機與作用不同，勿混用：

| Ledger | 時機 | 落點 | 列數 | 阻擋作用 |
|--------|------|------|------|---------|
| **Preflight** | push / 開 PR **之前** | 寫進 PR body | 8 rows | 缺 row 或缺證據 → 不得 push / 開 PR |
| **Closeout** | 實作 / 開 PR / merge 後的**最終回覆** | 可見於回覆正文（非 PR 路徑亦必出） | 6 rows | 缺此 ledger → closeout 不完整 |
| **Postflight** | merge **之後** | 回覆一行帶過 | 2 項 | 無（收尾記錄） |

四態標記（全鏈通則，同 SKILL.md）：`PASS` / `FAIL` / `UNAVAILABLE`（須附 probe 失敗證據）/ `SKIPPED`（須附理由）。無證據不得標 PASS。

---

## 1. Preflight Ledger（8 rows，寫進 PR body）

每 row 斷言一件事 + 明列什麼算證據。任一 row 缺席或標 PASS 卻無證據 → 阻擋 push / 開 PR（[T0-2] 無 evidence 不得宣稱完成）。

| # | Row | 斷言什麼 | 什麼算證據 |
|---|-----|---------|-----------|
| 1 | **Scope** | 每行 diff 都可對應到本次需求 / task；無順手改的不相關格式 / 命名 | 引用 `sdd/<slug>/tasks.md`（或 plans doc）+ 一句自審：每個變更檔對得上哪條 task；無法追溯的順手改已移除或另開 task |
| 2 | **Git state** | 從乾淨 baseline 出發，工作在 `feat/` / `fix/` 分支（非 master）| 分支名 + 動手前 `git status` 為 clean 的紀錄；確認非 main / master（[T0-3]）|
| 3 | **Diff self-review** | 每行變更已逐行看過；無自己殘留的 debug / TODO / dead code（unused import / var / func）| `git diff` 走查摘要；自造 dead code 已清（pre-existing 只標不刪）|
| 4 | **Self-simplification** | S4 四檢核通過：無 unrequested abstraction、無新依賴、無單一使用點抽象層、無 speculative config | 四項逐一標記結果；有新依賴時附選型理由（原生 > 標準庫 > 既有模組 > 第三方 > 手寫）|
| 5 | **Tests evidence** | 測試已寫且跑綠；BUGFIX 另證紅測早於 fix（[INT-2]）| 確切測試指令 + exit code + 通過數；BUGFIX 附紅→綠的 commit 序（無 seam 須標例外理由）|
| 6 | **Review gate** | 已審查、記錄 reviewer 型別、actionable findings 全數處理 | reviewer 型別 + agent id（或 UNAVAILABLE 附 probe 失敗證據）+ finding 摘要；0 條未處理 actionable |
| 7 | **Security-release gates** | 會部署的變更已跑 `*-release-verification` + `dependency-security-scan`（正交必跑，非三選一）| 列出跑了哪些 gate + 結果；不部署則標 SKIPPED 附「本次不部署」理由 |
| 8 | **Residual risks** | 已知但接受的殘留風險已列舉；中高風險附 rollback | 風險清單（「無」是明述斷言不是留白）；中高風險變更附 rollback 註記（[T0-6]）|

### 範例（已填）

```
## Preflight Ledger

1. Scope — PASS：3 個變更檔皆對應 sdd/batch-insert-chunk/tasks.md 的 T1–T3；無不相關格式改動。
2. Git state — PASS：分支 fix/batch-insert-byte-chunk（非 master）；動手前 git status clean。
3. Diff self-review — PASS：git diff 逐行走查；移除臨時 Console.WriteLine 一處；無殘留 dead code。
4. Self-simplification — PASS：無新抽象／無新依賴／分塊邏輯僅 FileProcess 單處但為既有 caller 路徑非新增抽象層／無 speculative config。
5. Tests evidence — PASS：DOTNET_SYSTEM_NET_DISABLEIPV6=1 dotnet test ...Tests.csproj → exit 0，Passed! 398 個；BUGFIX 紅測 BatchInsert_ExceedsByteLimit_Splits 於修復前 commit（a1b2c3d）先紅。
6. Review gate — PASS：reviewer=dotnet-code-reviewer（agent id dcr-07）；2 findings 皆採納並修；0 未處理。
7. Security-release gates — PASS：backend-release-verification 綠；dependency-security-scan 無高危 CVE（NuGetAudit exit 0）。
8. Residual risks — 大 payload 分塊邊界仰賴 UTF-8 byte 量測，非字元；風險低。rollback：revert 單一 commit 即回原批次 INSERT 行為。
```

---

## 2. Closeout Ledger（收割 Codex override 原文，最終回覆必出）

實作 / 開 PR / merge 後的最終回覆 MUST 含可見的 `Closeout Ledger`，不可只說「做完了」。收割自 Codex override 的 Mandatory Closeout Ledger，六列各標 `PASS` / `FAIL` / `SKIPPED`（Review gate 的「不可用」對映四態的 `UNAVAILABLE` + probe 證據）+ 證據：

| Row | 內容 |
|-----|------|
| **Self-simplification** | PASS / FAIL / SKIPPED，附證據（四檢核結果）|
| **Diff self-review** | PASS / FAIL / SKIPPED，附證據（逐行走查摘要）|
| **Relevant verification** | 確切指令或工具檢查 + 結果摘要（build / test / lint 的指令 + exit code）|
| **Review gate** | reviewer 型別、agent id 或不可用理由、最終 finding 摘要 |
| **PR / CI / review status** | 適用時：PR 連結、CI 綠燈狀態、bot review 處理狀態 |
| **Residual risks** | 殘留風險（中高風險附 rollback）|

**規則：缺此 ledger → closeout 不完整。** 即使結論全 PASS、即使任務結論是「不需沉澱」，仍 MUST 明確輸出此 ledger 讓用戶看見已執行評估。

**呈現粒度（六項語意一律不得省略，省的只有版面）：**

- **展開完整六列表格**：中高風險、或任一項非 `PASS`、或不走 PR 路徑。
- **PR 路徑且全 PASS**：`Self-simplification`、`Diff self-review`、`Review gate`、`Residual risks` 四列與 PR body 的 Preflight Ledger（第 1 節）同源，此處以 `見 PR body 的 Preflight Ledger` 帶過即可（用固定段落名，不用 `#` 編號佔位符——那在 GitHub 語境會被讀成 issue／PR 編號，也容易被原樣輸出）；`Relevant verification` 與 `PR / CI / review status` 兩列 MUST 逐項展開——只有這兩列帶著 Preflight 當時還不存在的資訊（實際跑了什麼、CI 與 bot review 的最終狀態）。
- **低風險、單檔、不進 PR 且全 PASS**：可壓成單行，六項次序不變，例：
  `Closeout: simplification／self-review／verification／review／PR-status／risks — PASS，dotnet test exit 0 (398 passed)，無殘留風險`

理由：六列中有四列與 Preflight Ledger 逐欄重複，而 PR 路徑上讀者已在 PR body 看過同樣內容；整份重述會稀釋真正新增的那兩列。壓縮的是版面不是評估——任一項未評估仍是 closeout 不完整。

### 範例（已填）

```
## Closeout Ledger

- Self-simplification — PASS：無 unrequested abstraction／無新依賴／無單一使用點抽象層／無 speculative config。
- Diff self-review — PASS：git diff 逐行走查；無殘留 debug／dead code。
- Relevant verification — PASS：DOTNET_SYSTEM_NET_DISABLEIPV6=1 dotnet test → exit 0（Passed! 398）；dotnet build --configuration Release → exit 0。
- Review gate — PASS：reviewer=dotnet-code-reviewer（dcr-07）；2 findings 採納並修；0 未處理 actionable。
- PR / CI / review status — PR #64 已開；gh pr checks 全綠；Copilot review 異步產出 3 條，2 條採納 1 條附 technical reason pushback，thread 皆 resolve。
- Residual risks — 分塊邊界仰賴 byte 量測；風險低。rollback：revert 單 commit。
```

---

## 3. Postflight（merge 後，簡短）

merge 完成後，回覆一行帶過兩項：

1. **刪分支**：合併後刪除該 PR 分支（remote + 已併入的 local），squash merge 預設。
2. **BUGFIX settlement 指標**：若為 BUGFIX 鏈，MUST 已跑 `bug-fix-settlement` 並輸出評估摘要——沉澱去向（cookbook / memory / workflow）或明述「評估後不需沉澱」；非 BUGFIX 免此項。

### 範例（已填）

```
## Postflight
PR #64 squash merge 完成；已刪 remote + local fix/batch-insert-byte-chunk 分支。
BUGFIX settlement：根因（批次 INSERT 未依 byte 分塊致大 payload 逾 max_allowed_packet）已走 bug-fix-settlement，沉澱至 docs/cookbook/import/pitfalls.md 並更新 MOC.md。
```
