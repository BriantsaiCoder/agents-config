---
name: bug-fix-settlement
description: "Bug、build 或效能問題修復且已有 regression evidence 後，評估是否需保存根因知識；排除 typo、格式與未完成功能。"
---

# Bug Fix Settlement

這是 bugfix 的知識收尾，不是 debug 流程。輸入必須包含已驗證的 root cause 與 regression evidence；缺少時先回 `diagnosing-bugs`。

## Step 1：判斷知識去處

逐一檢查：compiler／lint 能抓嗎、`grep`／`deps-check` 能找到嗎、regression test 能守住嗎？答「是」就選該 mechanical guard，不複製成易腐化文件。只有工具看不出的 runtime 時序、外部 API 陷阱、隱性資料／業務契約或 architecture why 才考慮沉澱。

評估 Cookbook、Memory、Workflow 各自是否需要保存及理由；不寫 Cookbook 時確認替代 guard（type、lint、test 或 deps-check）。依 Step 3 決定回覆詳略；有知識保存建議，或需要分類例／輸出格式時，必讀 [settlement guide](references/settlement-guide.md)。

**完成條件：**三個目標皆有 verdict、理由與可執行的替代 guard（若適用）。這個評估是強制步驟；`建議` 不等於寫入授權。

## Step 2：跨 authorization boundary

- Cookbook 與 Workflow 寫入依 shared `dev-workflow` S2：既有核准已涵蓋 exact target/path、內容範圍與副作用時直接完成；新 target、全域 policy 或 scope expansion 未涵蓋時才確認相依寫入。
- Memory 只有使用者明示「記住」或「保存到 memory」才可寫入，並遵守目前 host 的 memory contract。
- 未授權時保持 read-only，記錄 `待授權` 與預計 path。

**完成條件：**每個實際寫入都有可追溯的既有授權 evidence，未涵蓋項目維持待授權；不得以 assessment 取代 authorization。

## Step 3：輸出收尾摘要

三者皆不需要時，以一句說明無需保存及替代 guard，或「一次性問題，無需動作」。有建議／待授權／已寫入項目才展開相關項目與理由；已寫入者列 exact path 與內容摘要，待授權者列 proposed path。依 host 回覆格式呈現，不強制固定標題或三列模板。

**完成條件：**使用者能從摘要確認評估結果、實際寫入與尚待授權項目；不可靜默結束。
