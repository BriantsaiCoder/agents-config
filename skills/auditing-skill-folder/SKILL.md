---
name: auditing-skill-folder
description: "Audit a skill directory for trigger clarity, routing overlap, content placement, and evidence-backed keep/trim/split decisions."
---

# 稽核 Skill 資料夾

先做結構檢查，再判斷內容。單一 skill 改走 [`../dev-workflow/SKILL.md`](../dev-workflow/SKILL.md)。

## 必要流程

完成條件：Step 0 → Portable structural gate；每個 skill 完成 Steps 1–6；每個資料夾完成一次 Step 2b。缺任一結果即重跑。

### Step 0 — Vendored gate

執行 `scripts/check-vendored.sh <folder>`；每列記錄 `VND`、`VND*`、`vnd?`、`ERR` 或 `-`。所有 skill 都須評分並保留真實 assessment verdict。`ERR` 視為 `VND`；原地修改附 `proposed override required`，整體移除或替換仍合法。詳細規則見 [`step0-vendored-gate.md`](step0-vendored-gate.md)。

### Portable structural gate（必要）

依 [`references/skill-standards.md`](references/skill-standards.md) 驗證目錄與 `name` 一致、frontmatter 含有效 `name`／`description`；執行 `scripts/check-relative-references.sh <folder>` 驗證 relative references。回報缺陷；Step 0 constraint 另行套用。

### Steps 1–6

| # | 檢查 | 方法與結果 |
|---|---|---|
| 1 | Token cost | `scripts/count-words.sh <folder>`；超額列依 [`step1-verdict-guide.md`](step1-verdict-guide.md) 判斷。 |
| 2 | Description trap | `scripts/lint-descriptions.sh <folder>`；區分 trigger-led description 與 workflow summary。 |
| 2b | Trigger collision | 跨列比較 Step 2；model-invoked trigger space 重疊且無 disambiguator 即 `Collision`。 |
| 3 | Stance bleed | 純 user/team stance 移至 host/repo instructions。 |
| 4 | Mechanical-only | lint、hook 或 regex 可強制的行為移至 deterministic enforcement。 |
| 5 | Type clarity | 依 standards 分為 Technique、Pattern 或 Reference；只有 defined mixed type 才提議 `Split`。 |
| 6 | Delete evidence | 排除重複、不相關與 no-op prose 後，盤點 behavior-changing unique policies、guards、procedures。只有盤點為空、current primary docs 取代 reference value，且 reversible temp-disable A/B canary 無品質、安全、routing 或 workflow regression，才列為 `Delete` 候選。只用 temporary corpus/plugin；live shared-skill change 須另取得各 host 授權，並在每個 consuming host 記錄 `PASS`／`FAIL`／`UNAVAILABLE`。 |

### Step 2c — Optional trigger accuracy

Rate-limit 成本合理時才執行 `scripts/eval-triggers.sh --runner claude` 並讀取 [`step2c-trigger-eval.md`](step2c-trigger-eval.md)。記錄含 host/result 的 `RUN` 或 `SKIPPED(reason)`；各 host 分別附 evidence 回報 `PASS`／`FAIL`／`UNAVAILABLE`。Step 2c 不影響必要完成條件。

純 style 檢查維持 optional：[`step7-style-checks.md`](step7-style-checks.md)。

## 報告契約

每個 skill 須列出 vendored flag、structural result、Steps 1–6 results，以及一個 verdict：`Keep`、`Trim`、`Move-to-host/repo-instructions`、`Convert-to-deterministic-enforcement`、`Split`、`Delete` 或 `Collision`。每個資料夾記錄一次 Step 2b。Vendored constraint 只附加於 verdict，不取代 assessment 或降低 severity。
