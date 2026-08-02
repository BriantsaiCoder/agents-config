# 執行狀態 — 2026-08-01

**17 條執行完成，1 條依建議跳過。** 全 15 支測試綠、shellcheck CLEAN。

---

## `auditing-skill-folder`（自有，直接改）

| # | 項目 | 狀態 | 落地方式 |
|---|---|---|---|
| A1 | `wc -w` 對中文失明 | ✅ | `count-words.sh` 改為 effective = `wc -w` + 3/5 × CJK 字元。無 CJK 的檔 effective 恆等於 `wc -w`——**90 個英文 skill 分類 0 變動**，6 個含中文的新標記 OVER |
| A2 | 第五個偵測訊號沒文件化 | ✅ | `step0-vendored-gate.md` 表格 + 「union of **five** signals」+ `aspnet-api-architect` 的自有 repo 案例；`SKILL.md` Step 0 同步 |
| A3 | Technique／Pattern 無定義 | ✅ | `references/skill-standards.md` 新增〈Step 5 type taxonomy〉：三型各一句判別問句 + corpus 實例，並給出可檢查的 mixed-type 判準 |
| A4 | 兩個死 tier | ✅ | 名稱樣式改為顯式 `ALWAYS_LOADED` 清單（`dev-workflow`，limit 200），刪掉 0 命中的 150 層 |
| A5 | `vendored_owner` scheme 不對齊 | ⏭️ **跳過** | corpus 0 次發生；另兩個空白分支是測試明確釘住的「誠實空白」邊界 |
| A6 | 路由丟第二跳 | ✅ | 單一 skill 工作改指向 canonical `../dev-workflow/SKILL.md`；兩跳 routing 只由該檔維護 |
| A7 | 無跨 skill collision step | ✅ | 新增 Step 2b（唯一比較 skill 之間的一步）+ Red Flags 一列 + Iron Law 納入 |

**順帶修掉的 doc rot**：`step0-vendored-gate.md` 與 `ci.yml` 都曾宣稱 `vendored-detection.sh` 是「33 cases」；目前為 **93**。

**副作用（如實記錄）**：`SKILL.md` 改動前為 661 words 且已 OVER；優化後仍超過 500-word default limit。Current count 以 `scripts/count-words.sh skills` 的輸出為準，不在狀態文件重複維護。再往下砍會碰到載重規則，故保留為後續獨立 pruning 題目。

---

## `writing-great-skills`（`VND*`，走登記 override）

11 條全部執行，**合併為單一 fork 決策**（固定成本只付一次）。

| # | 項目 | 檔案 | 狀態 |
|---|---|---|---|
| B1 | 無窮盡性門檻 | `SKILL.md` | ✅ 加上「每節都須產出 verdict」的完成判準 |
| B2 | 「delete it」假前提 | `GLOSSARY.md` ×4 + `SKILL.md` ×1 + 伴隨 ×2 = **6 站點同批** | ✅ 全改為「withhold from the agent；欄位保留」 |
| B3 | description 缺診斷 branch | frontmatter | ✅ 加診斷 trigger + reach clause |
| B4 | 持有 SKILL.md 結論且已漂移 | `GLOSSARY.md:21` | ✅ 刪除重複句 |
| B5 | 多 host 機制不完整 | `SKILL.md` | ✅ 補 `allow_implicit_invocation: false` |
| B6 | External reference 術語衝突 | `SKILL.md` | ✅ 第三階改名為「**Reference**, disclosed」 |
| B7 | pointer 無觸達條件 | `SKILL.md` | ✅ 加上何時逐字通讀的條件 |
| B8 | 祈使句放錯檔 | `SKILL.md` | ✅ 從 `GLOSSARY` 上移 |
| B9 | 假前提第三處 | `GLOSSARY.md:27` | ✅ 同 B2 批次 |
| B10 | 假前提第四處 | `GLOSSARY.md:57` | ✅ 同 B2 批次 |
| B11 | 無判準的 hedge | `SKILL.md` | ✅ 「where it matters」→「wherever the work sweeps a set」 |

### Fork 落地

- `vendored-forks.md` 新增 **2026-08-01 決策**，明寫「supersedes」前一版並將範圍從 invocation metadata 擴大到 body corrections，附逐項變更表
- tree SHA-256 `6d00cd49…` → **`231a72c153e3abc84f33512aa3f8af8f942da23283b85005ebb770030df3631a`**，已驗證實際＝紀錄
- re-merge procedure 改寫為兩層（invocation metadata + body corrections 逐列），並要求逐列比對新 upstream——**上游若已自行修正該列即丟棄不重貼**
- 記錄中明確標註 **B2 是上游缺陷**：若回報上游並被接受，該列應刪除並改以 wholesale replacement 取回，不再當 fork 背著
- 四支指名測試全綠：`matt-thin-workflow` / `mattpocock-workflow` / `host-skill-resolver` / `vendored-detection`

### 一個看起來像回歸、實際不是的現象

`writing-great-skills` 的 Step 2 lint 分數仍是 `?`。這是**兩道家規閘互斥**的必然結果：

- `tests/matt-thin-workflow.sh:96` 硬性要求 `^description: Skill authoring.*single skill`
- `lint-descriptions.sh` 的 `GOOD_RE` 錨定 `^Use when`

兩者不可能同時滿足。但 `references/skill-standards.md` 規則 2 明寫「**do not impose that house wording on vendored payload**」——所以 vendored skill 落在 `?`（UNASSESSED，人工讀）是**預期行為，不是缺陷**。裁決者也是基於 `SKILL.md:23`（「state what the skill is」是 description 的職責之一）刻意保留身分句、只壓到兩個字。

---

## 驗證

```
word-budget PASS   description-lint PASS   vendored-detection PASS   conformance PASS
mattpocock-workflow PASS   matt-thin-workflow PASS   host-skill-resolver PASS
pr-review-gate PASS   hook-parity PASS   version-tripwire PASS(+selftest)
agents-branch PASS   legacy-mp-collision PASS   git-push-guard PASS
claude-routing-collision --selftest PASS
shellcheck -S error （hooks/ tests/ bin/）CLEAN
```

新增測試 2 支、已接 CI：`tests/description-lint.sh`（22 cases）、`tests/word-budget.sh`（30 cases）。

`tests/matt-thin-workflow.sh` 的 allowlist 補登記 5 個檔：`references/skill-standards.md`、`scripts/check-vendored.sh`、`scripts/count-words.sh`、`scripts/lint-descriptions.sh`、`step0-vendored-gate.md`。

## Follow-up closeout

- `step0-vendored-gate.md` 改為以 `vendored-forks.md` 的現行 scope 為準，不再硬編碼已被 supersede 的 metadata-only 範圍；override 數量、case 數與 word tiers 的漂移字串已移除或同步。
- `auditing-skill-folder` 明確標示 Step 2b 是 semantic comparison，不再宣稱它是 mechanical check。
- Claude Code 2.1.220 真實 canary 在 95 個 candidate skills 同時載入下為 2/2 PASS：單一 skill authoring 問題由 `writing-great-skills` 勝出；whole-folder keep/trim/delete/migrate 問題由 `auditing-skill-folder` 勝出。無 retry、無錯誤 case。
- `tests/matt-thin-workflow.sh` 新增 scope、tier、五訊號與 linter language-contract regression checks。

## 歷史外部狀態（非建議／非待辦）

- 原調教已 commit 至 `main`；本文件以 `bc7dd87` 為 closeout baseline。
- B2 曾由 `BriantsaiCoder` 回報為 [`mattpocock/skills#714`](https://github.com/mattpocock/skills/issues/714)，並依使用者指示於 2026-08-02 關閉。此列只修正舊 closeout 的歷史事實；沒有待執行的 upstream follow-up。若 upstream 日後自行吸收，再依 `vendored-forks.md` 的 re-merge procedure 處理 local delta。
