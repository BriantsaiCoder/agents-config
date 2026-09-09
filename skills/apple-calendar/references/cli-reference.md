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
