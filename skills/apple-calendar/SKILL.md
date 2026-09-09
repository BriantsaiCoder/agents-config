---
name: apple-calendar
description: "查詢與管理本機 macOS Apple 行事曆事件，或排除呼叫端的 EventKit 存取問題時使用。Google Calendar connector 操作不在此範圍。"
---

<!-- tier: local-tool | consumed-by: claude,codex,copilot | backend: EventKit via JXA | last-verified: 2026-08-31 -->

# apple-calendar

以 EventKit（透過 `osascript -l JavaScript`）操作本機 Apple 行事曆。零安裝、零依賴，macOS 內建。

## 指令

腳本在本 skill 的 `scripts/` 下，主入口 `scripts/cal.sh`（`cal.sh list`／`add`／`edit`／`delete`／`calendars`／`selftest`），`scripts/cal-list.sh`、`scripts/cal-add.sh`、`scripts/cal-edit.sh`、`scripts/cal-delete.sh` 是等價包裝，JXA 本體在 `scripts/cal.js`；用絕對路徑呼叫，不依賴 PATH。完整旗標、參數檢查規則與輸出欄位見 [cli-reference.md](references/cli-reference.md)，組指令或判讀輸出時載入。

短指令安裝與 host/TCC 排錯由 [install-and-host-access.md](references/install-and-host-access.md) 管理；首次設定、換 host 或權限失敗時載入。

時間格式只吃 `YYYY-MM-DD` 或 `YYYY-MM-DDTHH:MM`（不含秒）；相對日期由呼叫端換算成絕對日期。`list` 預設從今天起 7 天、涵蓋全部行事曆；`add` 預設寫入「工作」。標記欄會出現 `重複:每週`／`全天`，**動手改之前先看這一欄**；`edit`／`delete` 需要的 id 只能從 `list` 輸出取得。

## 典型流程

新增／編輯／刪除的命令範例見 [CLI reference](references/cli-reference.md#典型流程)。編輯／刪除前列出全部相符事件，核對標題、時間、行事曆與標記；只有唯一目標且在授權範圍內才操作，多筆只暫停該筆並詢問。id 必須取自 list，不能截取第一筆賭目標。改時間同時給 `--start`／`--end`。

## 重複排程

等間隔規則與月底日期語意見 [recurrence.md](references/recurrence.md)。新增重複事件或判讀 recurrence 時載入；編輯既有規則不受支援。


## 操作前提

除 authorize/selftest 外，CRUD 要求 fullAccess；權限不足或沙箱攔截不能解讀成「没有事件」。呼叫端/TCC 與 EventKit 執行條件由 [host access](references/install-and-host-access.md) 管理。

重複事件共用 id，edit/delete 必須指定 --on；預設僅該場次，--span future 才影響之後場次。所有寫入都要獨立回讀，刪單場查該日期，不以系列仍存在判斷失敗。


## 行事曆歸屬

`cal.sh calendars` 會標出可寫性與帳號來源（`iCloud`／`Google`／`Subscribed`／`birthdays`）。訂閱行事曆與生日行事曆為唯讀，寫入會被明確拒絕。

首次選定目標或帳號／可寫性改變時，查 `cal.sh calendars` 核對歸屬；同 session 目標未變可沿用 evidence。跨裝置同步還取決於裝置帳號設定，不能只由行事曆名稱推論；寫後仍須獨立回讀。

## 維護本工具

修改 scripts 時載入 [maintainer-guide.md](references/maintainer-guide.md)：parseISO、JXA/store traps 與必要測試；一般行事曆操作不載入。
