---
name: bug-fix-settlement
description: 修復任何技術問題（bug、測試失敗、build 失敗、非預期行為、效能問題）之後觸發的「知識沉澱」收尾流程。負責判斷這次修復的根因是否值得沉澱、沉澱到哪裡（cookbook / memory / workflow），並強制輸出評估摘要。此 skill 不負責 debug 本身——除錯紀律走 `diagnosing-bugs`，此 skill 接在它後面做收尾。**不可在修完 bug 後直接結束回覆**，即使結論是「不需要沉澱」，也必須明確輸出摘要讓使用者看見已執行評估。
---

# Bug Fix Settlement — 修復後的知識沉澱

## 定位

此 skill 是除錯流程的**收尾**，不是除錯本身。

- **找根因、紀律化修復** → `diagnosing-bugs`（feedback loop → reproduce → root cause → fix → regression test）
- **修完之後** → 本 skill：判斷根因是否值得沉澱、寫入正確位置、輸出評估摘要

`diagnosing-bugs` 結束時手上應有一份根因結論（是什麼錯了、為什麼錯、是否有通用性）。本 skill 拿這份結論做沉澱判斷。

## 觸發時機

任何技術問題**修復完成後**觸發，不限於使用者主動回報：

- bug、測試失敗（紅字 / assertion error）、build / 編譯失敗
- 功能跑起來但結果不對的非預期行為
- 明顯的效能退化
- 修了 A 壞了 B 之類的隱性耦合
- 處理屬於 bug 類的 GitHub issue 完成後

### 不觸發的情況

- 純 typo、拼字錯誤
- 單純 import path 錯誤（IDE / tsc / 編譯器會指出）
- 設定檔格式錯誤
- 還在開發中、本來就沒完成的功能

## Step 1：評估是否值得沉澱

Cookbook 只收「程式碼、型別、測試、依賴關係**看不出來**」的知識。能被機械工具抓到的東西不該寫——那些會隨程式腐爛，而機械工具不會。Cookbook 的完整定位與結構見**你所在 host 的 rules 目錄**下的 `cookbook.md`（Claude `~/.claude/rules/`、Codex `~/.codex/rules/`、Copilot `~/.copilot/rules/`；三 host 皆有該檔）。

**沉澱前的三問判準**（任何一題答「是」就不寫 cookbook）：

1. **tsc / 編譯器 / eslint 會抓到嗎？** — 例如「改 signature 要同步更新呼叫端」。會抓 → 不寫，型別就是文件。
2. **grep import 或 deps-check 看得出關係嗎？** — 例如「改 OrderService 要同步 CheckoutHandler」。看得出 → 不寫，靠依賴檢查。
3. **測試會失敗嗎？** — 例如「CalculateTotal 應排除已取消的訂單項」。會失敗 → 不寫，測試就是契約。

**三問判準是「路由器」不是「否決權」**。答「是」代表這個知識該由機械工具守護（補型別、加 lint rule、補測試），Step 3 必須告訴使用者知識的去處，不是說「不寫」就結束。

**值得沉澱的，只有機械工具抓不到的隱性知識：**

- **跨時序 / 跨 runtime 的隱性耦合**：事件順序、debounce、race condition、DI 生命週期陷阱
- **外部 library / framework 的陷阱**：某 API 在特定環境行為不同、吃到特殊輸入會崩
- **隱性資料契約**：UI 必須同步某個 constant 清單，但沒有型別連結
- **程式碼看不出 why 的業務規則**：感測器離線 30 分鐘顯示 `--`（業務端定的，非技術限制）
- **領域特有的計算邏輯**：良率計算要排除暖機數據
- **架構決策的 why**：為什麼用 A 不用 B（不寫進去會一直被重新質疑）

輸出評估結果：

```
沉澱評估：
- Cookbook：✅ 建議寫入（原因：...）/ ❌ 不需要（原因：...）
- Memory：✅ 建議寫入（原因：...）/ ❌ 不需要（原因：...）
- Workflow：✅ 建議寫入（原因：...）/ ❌ 不需要（原因：...）
```

| 沉澱目標 | 什麼時候寫入 | 範例 |
|----------|------------|------|
| **Cookbook**（`docs/cookbook/`，隨 git） | 專案特定、機械工具抓不到的隱性知識 | Dashboard 模組需各自包 ErrorBoundary，否則一處 API 錯誤白屏整頁 |
| **Memory**（auto memory，feedback 類型） | 跨專案通用的開發回饋 | 使用者偏好的確認粒度 |
| **Workflow**（host 的 command 目錄或 skill） | 流程缺陷導致的錯誤 | 某 command 階段缺完成度檢查 |

可同時建議多個目標。**✅ 是 assessment result，不是寫入授權**。

## Step 2：取得授權後寫入

評估是強制步驟；持久化是另一個 authorization boundary：

- **Cookbook 與 Workflow** 都需使用者核准 exact target/path；若當下請求已明示要把修復知識寫入該目標，即視為已授權。
- **Memory** 只有使用者明示「記住」或「保存到 memory」才可寫入。
- 未取得授權時不寫檔，在 Step 3 列出建議目標、路徑與待授權狀態。

**Cookbook（已授權時）**：用 Glob 找 `docs/cookbook/**/*.md`，依修改的模組找對應檔案；業務邏輯寫 `business-rules.md`、踩坑寫 `pitfalls.md`、架構決策寫 `architecture/`。資料夾 / 檔案不存在就建立。寫入格式（問題 → 原因 → ✅正確做法 / ❌錯誤做法）與分類規則見你所在 host 的 `rules/cookbook.md`。

**Memory（已授權時）**：在 auto memory 目錄建 `feedback_*.md`，含 **Why**（為什麼會犯錯）與 **How to apply**（未來怎麼避免），更新 `MEMORY.md` 索引。

**Workflow（已授權時）**：在對應 command / skill 加入檢查項，說明在哪個階段攔截此類錯誤。

## Step 3：無條件輸出評估摘要

**強制步驟，不可跳過**。不論寫或不寫都要輸出，讓使用者看到 skill 已執行完整流程。靜默結束 = 使用者以為 skill 沒觸發，正是此 skill 要避免的失敗模式。

**情境 A：已授權且有寫入**

```
📝 錯誤學習已記錄：
- Cookbook: docs/cookbook/orders/pitfalls.md（新增 DI scoped 生命週期陷阱）
- Memory: 無需更新
- Workflow: 無需更新
```

**情境 B：不需要寫入**（說明原因 + 建議替代動作）

```
📝 錯誤學習評估：
- Cookbook: ❌ 不寫（原因：屬型別契約，編譯器已能守護）
- Memory: ❌ 不寫（原因：專案特定，不適合跨專案 feedback）
- Workflow: ❌ 不寫
- 建議替代動作：在 CalculateTotal() 補上 return type，編譯器會直接擋下呼叫端型別不匹配
```

若評估建議沉澱但尚未取得授權，沿用情境 B 的格式，將該項標為「⏳ 待授權」並列出預計寫入的 exact target/path。

「建議替代動作」是 Step 3 的核心——cookbook 不寫，就一定要告訴使用者「那該做什麼」：補型別 / type guard、加 lint rule、補單元 / E2E 測試、提醒跑 deps-check，或「純 typo / 一次性環境錯，無需動作」。

只有當「以上皆不適用」且「下次可能再犯」時，才寫入 cookbook。寫入過多會讓 cookbook 腐爛、沒人讀。寧缺勿濫。
