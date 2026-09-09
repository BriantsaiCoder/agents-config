# Recurrence rules

Bundled-reference links resolve from this file. Repository/output paths refer to the target workspace; script paths retain their stated skill-root location.

## 重複排程

```bash
cal-add 2026-09-07T10:00 60 "部門週會" --repeat weekly --count 12
cal-add 2026-09-08T14:00 90 "雙週檢討" --repeat weekly --interval 2 --count 4
cal-add 2026-09-09T08:00 30 "每日站會" --repeat daily --until 2026-09-13
```

`--interval` 是間隔倍數（每 N 週／月）。結束條件 `--count`（場次數）與 `--until`（截止日）擇一，都不給就是無限重複。`--until` 只給純日期時內部取當日 23:59:59，因此**包含**當天的場次 —— 直接用 00:00 會把當天排除。

**月底起始的 monthly 採 clamp（夾到當月最後一天），不是跳過也不是溢位。** 實測 10-31 起每月 5 場 → `10-31, 11-30, 12-31, 01-31, 02-28`。要排「每月最後一天結帳」這種行程，從月底日期起始即可，行為符合直覺。

只支援「每 N 天／週／月／年」這種等間隔規則。要「每週一三五」或「每月第二個星期二」得用 `EKRecurrenceRule` 的 `daysOfTheWeek`／`setPositions`，目前未實作。`cal-edit` 也不能修改既有事件的重複規則 —— 只能改該場次的標題／時間／地點；要換規則得刪掉整個系列重建。
