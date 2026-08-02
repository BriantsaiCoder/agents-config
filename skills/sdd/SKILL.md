---
name: sdd
description: 適用於單一 target file、單一行為、≤3 個 actionable tasks 且未命中風險 gate 的小功能、明確 bug 或局部重構；需求模糊、跨模組、public API、schema 或 deployment pipeline 改走 dev-workflow。
---

# sdd — 輕量規格驅動開發

本 skill 只定義 proposal → implementation → optional archive 三階段；routing、authorization、risk、RED→GREEN 與 S4–S6 一律以 [dev-workflow](../dev-workflow/SKILL.md) 為準。

## 階段判定

本 skill 有三個階段：**提案 / 實作 / 選用歸檔**。ENTER 依 session 內可引用證據判定：

- 收到可執行的需求且尚未核准 plan → 進階段一。
- 使用者明確核准 session plan（引用原句）→ 進階段二。
- 使用者明確要求持久化／歸檔，且 repo 中有 `sdd/<slug>/` → 進階段三。

若需求有多種合理解讀且將改變檔案或行為，依 [T0-5] 攤開假設與影響後發問；不要把缺少「提案／實作」字樣本身當 blocker。

短名稱（slug）規則：英文、小寫、連字號連接（例 `add-todo`、`fix-login`）。

## 階段一：提案（ENTER：有需求、尚無核准 plan）

1. 幫這個需求取一個英文短名稱（slug）。
2. 判斷類型：新功能 / 修 bug / 重構（三選一）。
3. 先在 session proposal artifact 寫出：
   - `## 為什麼做`：這個需求想解決什麼問題
   - `## 要改什麼`：會新增或改動哪些行為（條列）
   - `## 影響範圍`：大概會碰到哪些檔案（新增的、要改的）
4. 在 host todo 或同一 session artifact 拆出可追蹤的小步驟：
   - 每條小到 1 小時內可做完。
   - 整份不超過 3 條；超過即退出 sdd，回 dev-workflow 重新 route。
5. 加入 `## 驗收條件`，用白話「情境」句描述「做完後應該長怎樣」，例：
   - 情境：當使用者點擊「新增」按鈕，就把輸入框的文字加到清單最下面
   - 情境：當輸入框是空的就按新增，就不新增，並提示「請先輸入內容」

把完整 proposal / plan 貼給使用者後**停下來等確認**。核准前不得為滿足 workflow 而寫 repo；核准後，僅在用戶／repo 要求或有跨 session、交接、稽核價值時，才把同內容持久化到 `sdd/<slug>/proposal.md` 與 `tasks.md`。

## 階段二：實作（ENTER：session plan artifact + 使用者核准原句）

1. 先讀核准的 session proposal / plan；若已持久化，再核對 `sdd/<slug>/proposal.md` 和 `tasks.md`。
2. 從上到下，一次只做一條 host todo 或 `- [ ]` 任務。做之前先看有沒有現成的東西可重用。
3. 做完一條、標 completed 之前，回頭核對任務和「驗收條件」；使用 host todo 時更新 tool state，使用 tasks file 時改成 `- [x]` 並重讀確認。
4. 每完成一條就簡短回報「第幾條完成」，再做下一條。
5. 做到一半發現規格漏了東西或方向不對，**停下來告訴使用者**，等決定，不要自己亂改規格、也不要硬幹。
6. 全部打勾後，宣稱完成前 MUST 通過 dev-workflow S4–S6 對應 gate，或逐項標 SKIPPED 附理由；然後告訴使用者「全部完成」並請驗收。

## 階段三：選用歸檔（ENTER：使用者要求歸檔且 `sdd/<slug>/` 存在）

1. 打開 `sdd/<slug>/tasks.md`，確認每條都是 `- [x]`。還有沒打勾的，先告訴使用者，不要直接歸檔。
2. 都完成後，用 `date +%F` 取今天日期（格式 YYYY-MM-DD），把整個 `sdd/<slug>/` 資料夾移動到 `sdd/archive/<今天日期>-<slug>/`（在 git repo 內用 `git mv`）。
3. 回報歸檔完成，並用一句話總結這次做了什麼，方便日後回查。

若本次只用 session artifact、未建立 `sdd/<slug>/`，本階段標 SKIPPED（理由：無持久化產物），不為了歸檔補造檔案。
