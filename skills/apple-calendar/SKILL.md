---
name: apple-calendar
description: 查詢、新增、修改、刪除 macOS Apple 行事曆（Calendar.app／iCloud）事件時使用。使用者說「幫我加個行程」「我明天有什麼會」「把週會改到四點」「取消那個會議」「這週行事曆」時觸發。僅限本機 macOS 行事曆，Google Calendar 走另外的 MCP connector。
---

<!-- tier: local-tool | consumed-by: claude,codex,copilot | backend: EventKit via JXA | last-verified: 2026-08-30 -->

# apple-calendar

以 EventKit（透過 `osascript -l JavaScript`）操作本機 Apple 行事曆。零安裝、零依賴，macOS 內建。

## 指令

```bash
cal-list   [--from YYYY-MM-DD] [--days N] [--cal 行事曆]
cal-add    <開始> <結束或分鐘數> <標題> [--cal 行事曆] [--loc 地點] [--allday]
                                       [--repeat daily|weekly|monthly|yearly]
                                       [--interval N] [--count N | --until YYYY-MM-DD]
cal-edit   <id> [--title T] [--start ISO] [--end ISO] [--loc L] [--cal 行事曆] [--on YYYY-MM-DD] [--span this|future]
cal-delete <id> [--on YYYY-MM-DD] [--span this|future]
calx calendars    # 列出行事曆與可寫性
calx selftest     # 純函式自檢，不碰資料
```

主入口是 `calx`（`calx list`／`calx add`／…），`cal-*` 是等價包裝。**入口不叫 `cal`** —— 那是 macOS 內建的月曆指令，`/usr/bin/cal` 在 PATH 中排在 `~/bin` 之前，取這個名字會讓所有子命令被系統指令攔截（症狀是 `year 'selftest' not in range 1..9999`，且刪除指令會靜默不執行）。

時間格式只吃 `YYYY-MM-DD` 或 `YYYY-MM-DDTHH:MM`（不含秒）；相對日期（「明天」「下週一」）由呼叫端換算成絕對日期後再傳入。

`list` 預設從今天起 7 天、涵蓋全部行事曆。`add` 預設寫入「工作」。

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

```bash
cal-add 2026-09-07T10:00 60 "部門週會" --repeat weekly --count 12
cal-add 2026-09-08T14:00 90 "雙週檢討" --repeat weekly --interval 2 --count 4
cal-add 2026-09-09T08:00 30 "每日站會" --repeat daily --until 2026-09-13
```

`--interval` 是間隔倍數（每 N 週／月）。結束條件 `--count`（場次數）與 `--until`（截止日）擇一，都不給就是無限重複。`--until` 只給純日期時內部取當日 23:59:59，因此**包含**當天的場次 —— 直接用 00:00 會把當天排除。

**月底起始的 monthly 採 clamp（夾到當月最後一天），不是跳過也不是溢位。** 實測 10-31 起每月 5 場 → `10-31, 11-30, 12-31, 01-31, 02-28`。要排「每月最後一天結帳」這種行程，從月底日期起始即可，行為符合直覺。

只支援「每 N 天／週／月／年」這種等間隔規則。要「每週一三五」或「每月第二個星期二」得用 `EKRecurrenceRule` 的 `daysOfTheWeek`／`setPositions`，目前未實作。`cal-edit` 也不能修改既有事件的重複規則 —— 只能改該場次的標題／時間／地點；要換規則得刪掉整個系列重建。

## 三個必須知道的前提

**1. 權限不足會靜默回空，不會報錯。** EventKit 的 `writeOnly` 權限下，查詢回傳空集合而非錯誤 —— 呼叫端會誤判「當天沒事」而排入衝突行程。因此每個子命令開頭都硬性要求 `fullAccess`，不足即非零退出。

TCC 授權掛在 **responsible process**（也就是呼叫的 AI host）上，不是掛在腳本上。Claude Code 已授權不代表 Codex CLI 或 Copilot CLI 也有 —— 換 host 第一次使用要在「系統設定 → 隱私權與安全性 → 行事曆」放行該 app。實測 `swift script.swift` 直譯會被拒（無 bundle id），`osascript` 才通。

**2. 沙箱擋 EventKit，每次操作都需要停用沙箱。** 症狀不是權限錯誤，而是偽裝成 `-600「應用程式不在執行中」`、`open` 回 `procNotFound`、`pgrep` 回 `sysmond service not found`。這代表**每個 `cal-*`／`calx` 指令都會產生一次核准提示** —— 要做多步操作（查詢後修改、建立後確認）時把它們合併成單一 Bash 指令，不要拆成多次呼叫。

**3. 重複事件的所有場次共用同一個 id。** `cal-edit <id>` 不指定場次會動到**第一場**，不是使用者想改的那場。因此重複事件未給 `--on` 一律拒絕執行。指定 `--on` 後預設只影響該場次（`EKSpanThisEvent`）；`--span future` 才會動到該場次及之後所有場次。單獨改過的場次（detached occurrence）id 會多出 `/RID=…` 後綴，仍可直接餵回 `edit`／`delete`。

## 行事曆歸屬

`calx calendars` 會標出可寫性與帳號來源（`iCloud`／`Google`／`Subscribed`／`birthdays`）。訂閱行事曆與生日行事曆為唯讀，寫入會被明確拒絕。

**帳號來源決定會不會同步到手機。** 同一台機器上常常混著 iCloud 與 Google 的行事曆，名稱看不出差別 —— 只有寫進 iCloud 的事件才會出現在 iPhone 上。寫入前先跑一次 `calx calendars` 確認目標行事曆的歸屬，別靠名字猜。

## 設計約束（修改本工具前先讀）

- 日期一律走 `parseISO` → `NSDateComponents`，並回查確認未被靜默 normalize（`2026-02-30` 必須拒絕，不得推成 3/2）。格式化固定 `en_US_POSIX`，避開 zh-TW locale。
- 所有寫入後都要回讀驗證，不以 `saveEvent` 回 `true` 當作已寫入。
- 刪除的回讀驗證：指定 `--on` 時要查「那一天還有沒有這個事件」；重複事件刪一場後系列仍在，直接用 `eventWithIdentifier` 會誤判成刪除失敗。
- JXA 陷阱：`authorizationStatus` 回傳的是**字串**，`=== 3` 永遠 false，須 `Number()`；全天旗標的 setter 是 `allDay`，寫 `isAllDay` 會靜默不生效；讀 `NSError` out-param 用 `$()` + `isNil()`，用 `ObjC.castRefToObject` 會 segfault。
- 跨 store 實例操作會靜默失敗：用 store A 刪除從 store B 取得的事件不會生效也不報錯。

改動後跑 `calx selftest`（純函式，不碰資料），以及一輪 建立 → 用 `cal-list` 獨立回讀 → 刪除 → 全年掃描確認無殘留。
