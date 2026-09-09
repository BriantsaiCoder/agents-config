---
name: apple-calendar
description: "查詢與管理本機 macOS Apple 行事曆事件，或排除呼叫端的 EventKit 存取問題時使用。Google Calendar connector 操作不在此範圍。"
---

<!-- tier: local-tool | consumed-by: claude,codex,copilot | backend: EventKit via JXA | last-verified: 2026-08-31 -->

# apple-calendar

以 EventKit（透過 `osascript -l JavaScript`）操作本機 Apple 行事曆。零安裝、零依賴，macOS 內建。

## 指令

腳本在本 skill 的 `scripts/` 下，**用絕對路徑呼叫即可，不依賴 PATH**（`S=~/.agents/skills/apple-calendar/scripts`）：

```bash
$S/cal.sh authorize   # 首次使用時觸發 macOS 完整存取權提示
$S/cal-list.sh   [--from YYYY-MM-DD] [--days N] [--cal 行事曆]
$S/cal-add.sh    <開始> <結束或分鐘數> <標題> [--cal 行事曆] [--loc 地點] [--allday]
                                             [--repeat daily|weekly|monthly|yearly]
                                             [--interval N] [--count N | --until YYYY-MM-DD]
$S/cal-edit.sh   <id> [--title T] [--start ISO] [--end ISO] [--loc L] [--cal 行事曆] [--on YYYY-MM-DD] [--span this|future]
$S/cal-delete.sh <id> [--on YYYY-MM-DD] [--span this|future]
$S/cal.sh calendars    # 列出行事曆與可寫性
$S/cal.sh selftest     # 純函式自檢，不碰資料也不需權限
```

主入口是 `scripts/cal.sh`（`cal.sh list`／`cal.sh add`／…）；`scripts/cal-list.sh`、`scripts/cal-add.sh`、`scripts/cal-edit.sh`、`scripts/cal-delete.sh` 是等價包裝，JXA 本體在 `scripts/cal.js`。

短指令安裝與 host/TCC 排錯由 [install-and-host-access.md](references/install-and-host-access.md) 管理；首次設定、換 host 或權限失敗時載入。


時間格式只吃 `YYYY-MM-DD` 或 `YYYY-MM-DDTHH:MM`（不含秒）；相對日期（「明天」「下週一」）由呼叫端換算成絕對日期後再傳入。

`list` 預設從今天起 7 天、涵蓋全部行事曆。`add` 預設寫入「工作」。

## 參數檢查

未知旗標、大小寫寫錯的旗標、超量位置參數一律**拒絕執行**，不會靜默忽略：

```
$ cal-add 2026-09-08T14:00 60 "X" --allDay --cal 居家
未知旗標 --allDay（add 可用: --cal --loc --allday --repeat --interval --count --until）

$ cal-add 2026-09-08T14:00 60 部門 週會
add 只接受 3 個位置參數，收到 4 個: "2026-09-08T14:00" "60" "部門" "週會"（含空白的參數要用引號包起來）
```

沒有白名單時 `--allDay` 會被當成具值旗標吃掉後面的 `--cal`，結果是「非全天 + 寫進預設行事曆 + 零警告」。參數檢查排在授權檢查之前，所以沙箱內也驗得到。

## 輸出格式

`cal-list`／`cal-add`／`cal-edit` 的事件行欄位固定：

```
時間 | 標題 | 行事曆 | 地點 | 標記 | id=…

2026-09-08 14:00-15:00 | 部門週會 | 工作 | A棟會議室 |  | id=<store>…:0215…
2026-09-08 15:00-17:00 | 產品會議 | 工作 |  | 重複:每週 | id=<store>…:032F…
2026-10-05~2026-10-07 全天 | 請假 | 居家 |  | 全天 | id=<store>…:6B6F…
```

分隔符是 ` | `，空欄位留空不補字（地點為空時是 `|  |`）。id 為完整 73 字元字串，上面為版面截短。

標記欄會出現 `重複:每週`／`重複:每2週`／`全天`。**動手改之前先看這一欄** —— 重複事件的處理方式不同（見下）。`edit`／`delete` 需要的 id 只能從這裡取得。

## 典型流程

**新增** —— 第二個參數是分鐘數或明確結束時間；`--allday` 時改成結束「日期」（傳分鐘數會被擋下）：

```bash
cal-add 2026-09-08T14:00 60 "部門週會" --loc "A棟會議室"
cal-add 2026-09-08T14:00 2026-09-08T15:30 "設計審查"
cal-add 2026-10-05 2026-10-07 "請假" --allday --cal 居家
```

**編輯／刪除一律先查再動。** 使用者說的是「9/8 的部門週會」而不是 id。先 `cal-list` 撈出來、確認標題與時間對得上，再帶 id 執行；**不要憑標題模糊比對就寫入**。查與改合併成單一指令可省下一次沙箱核准：

```bash
ID=$(cal-list --from 2026-09-08 --days 1 --cal 工作 | grep '部門週會' | head -1 | sed -n 's/.*id=//p')
cal-edit "$ID" --start 2026-09-08T16:00 --end 2026-09-08T17:00 --loc "B棟會議室"
```

上面的自動抓取只在標題唯一時才安全。有多筆相符時要先把候選列給使用者確認是哪一筆，不要靠 `head -1` 賭。`edit` 只帶要改的欄位，其餘保持原狀；改時間時 `--start` 與 `--end` 一起給。

**重複事件的 id 對每一場都相同**，必須用 `--on` 指定場次：

```bash
cal-edit "$ID" --on 2026-09-21 --start 2026-09-21T15:00 --end 2026-09-21T16:00  # 只改 9/21 那場
cal-delete "$ID" --on 2026-09-21                                                # 只刪 9/21 那場
cal-delete "$ID" --on 2026-09-07 --span future                                  # 從第一場刪 = 整串清除
```

從第一場下 `--span future` 等於刪掉整個系列，連先前被單獨改過的場次也一併移除。

## 重複排程

等間隔規則與月底日期語意見 [recurrence.md](references/recurrence.md)。新增重複事件或判讀 recurrence 時載入；編輯既有規則不受支援。


## 操作前提

除 authorize/selftest 外，CRUD 要求 fullAccess；權限不足或沙箱攔截不能解讀成「没有事件」。呼叫端/TCC 與 EventKit 執行條件由 [host access](references/install-and-host-access.md) 管理。

重複事件共用 id，edit/delete 必須指定 --on；預設僅該場次，--span future 才影響之後場次。所有寫入都要獨立回讀，刪單場查該日期，不以系列仍存在判斷失敗。


## 行事曆歸屬

`calx calendars` 會標出可寫性與帳號來源（`iCloud`／`Google`／`Subscribed`／`birthdays`）。訂閱行事曆與生日行事曆為唯讀，寫入會被明確拒絕。

**帳號來源決定會不會同步到手機。** 同一台機器上常常混著 iCloud 與 Google 的行事曆，名稱看不出差別 —— 只有寫進 iCloud 的事件才會出現在 iPhone 上。寫入前先跑一次 `calx calendars` 確認目標行事曆的歸屬，別靠名字猜。

## 維護本工具

修改 scripts 時載入 [maintainer-guide.md](references/maintainer-guide.md)：parseISO、JXA/store traps 與必要測試；一般行事曆操作不載入。
