---
name: bug-fix-settlement
description: 修復 bug、測試或 build 失敗、非預期行為、效能退化或 bug 類 issue 之後觸發的知識收尾。評估根因應進 Cookbook、Memory 或 Workflow，並輸出摘要；除錯本身走 `diagnosing-bugs`。純 typo、單純 path／格式錯誤與尚未完成的功能不觸發。
---

# Bug Fix Settlement

這是 bugfix 的知識收尾，不是 debug 流程。輸入必須包含已驗證的 root cause 與 regression evidence；缺少時先回 `diagnosing-bugs`。

## Step 1：判斷知識去處

逐一檢查：compiler／lint 能抓嗎、`grep`／`deps-check` 能找到嗎、regression test 能守住嗎？答「是」就選該 mechanical guard，不複製成易腐化文件。只有工具看不出的 runtime 時序、外部 API 陷阱、隱性資料／業務契約或 architecture why 才考慮沉澱。

對 Cookbook、Memory、Workflow 各標 `建議`／`不需要`，並寫一行理由；不寫 Cookbook 時列出替代 guard（type、lint、test 或 deps-check）。需要分類例或輸出格式時讀 [settlement guide](references/settlement-guide.md)。

**完成條件：**三個目標皆有 verdict、理由與可執行的替代 guard（若適用）。這個評估是強制步驟；`建議` 不等於寫入授權。

## Step 2：跨 authorization boundary

- Cookbook 與 Workflow 都需使用者核准 exact target/path；本輪已明示該目標才視為授權。
- Memory 只有使用者明示「記住」或「保存到 memory」才可寫入，並遵守目前 host 的 memory contract。
- 未授權時保持 read-only，記錄 `待授權` 與預計 path。

**完成條件：**每個建議寫入都有當輪授權 evidence，或明確維持待授權；不得以 assessment 取代 authorization。

## Step 3：輸出收尾摘要

無條件輸出 `📝 錯誤學習評估`，逐列 Cookbook／Memory／Workflow 的結果。已寫入者列 exact path 與內容；待授權者列 proposed path；都不寫時列替代 guard 或「一次性問題，無需動作」。

**完成條件：**使用者能從摘要確認評估結果、實際寫入與尚待授權項目；不可靜默結束。
