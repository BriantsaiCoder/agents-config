# apple-calendar CLI reference

由 [SKILL.md](../SKILL.md) 管理；組指令或判讀輸出時載入。

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

標記欄會出現 `重複:每週`／`重複:每2週`／`全天`；重複事件的處理方式不同，見 [SKILL.md](../SKILL.md) 的「重複排程」。

## 典型流程

`S` 指向上面已確認的 scripts 絕對路徑。新增時第二個參數為分鐘數或結束時間；`--allday` 使用結束日期：

```bash
"$S/cal-add.sh" 2026-09-08T14:00 60 "部門週會" --loc "A棟會議室"
"$S/cal-add.sh" 2026-09-08T14:00 2026-09-08T15:30 "設計審查"
"$S/cal-add.sh" 2026-10-05 2026-10-07 "請假" --allday --cal 居家
"$S/cal-list.sh" --from 2026-09-08 --days 1 --cal 工作
```

先檢查完整 list 輸出，依標題、時間、行事曆與標記確認唯一目標。將該行完整 id 放入 `ID` 後才執行已授權操作；無匹配或多筆匹配時不得自動挑第一筆。不要用模糊比對加截斷把不確定性藏掉。

```bash
"$S/cal-edit.sh" "$ID" --start 2026-09-08T16:00 --end 2026-09-08T17:00 --loc "B棟會議室"
"$S/cal-list.sh" --from 2026-09-08 --days 1 --cal 工作
```

只帶要變更的欄位；改時間同時帶 start/end。重複事件共用 id，必須用 `--on` 指定場次：

```bash
"$S/cal-edit.sh" "$ID" --on 2026-09-21 --start 2026-09-21T15:00 --end 2026-09-21T16:00
"$S/cal-delete.sh" "$ID" --on 2026-09-21
```

預設只改該場；`--span future` 影響之後場次，從第一場刪等於整串（含單獨改過的場次），必須符合使用者授權。寫後獨立回讀所改日期；刪單場不以系列仍存在判斷失敗。
