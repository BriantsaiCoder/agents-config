# Maintainer guide

Bundled-reference links resolve from this file. Repository/output paths refer to the target workspace; script paths retain their stated skill-root location.

## 設計約束（修改本工具前先讀）

- 日期一律走 `parseISO` → `NSDateComponents`，並回查確認未被靜默 normalize（`2026-02-30` 必須拒絕，不得推成 3/2）。格式化固定 `en_US_POSIX`，避開 zh-TW locale。
- 所有寫入後都要回讀驗證，不以 `saveEvent` 回 `true` 當作已寫入。
- 刪除的回讀驗證：指定 `--on` 時要查「那一天還有沒有這個事件」；重複事件刪一場後系列仍在，直接用 `eventWithIdentifier` 會誤判成刪除失敗。
- JXA 陷阱：`authorizationStatus` 回傳的是**字串**，`=== 3` 永遠 false，須 `Number()`；全天旗標的 setter 是 `allDay`，寫 `isAllDay` 會靜默不生效；讀 `NSError` out-param 用 `$()` + `isNil()`，用 `ObjC.castRefToObject` 會 segfault。
- 跨 store 實例操作會靜默失敗：用 store A 刪除從 store B 取得的事件不會生效也不報錯。

改動後跑 `tests/apple-calendar.sh`（會驗 `scripts/` 下的 payload 完整性並執行 selftest），
以及一輪 建立 → 用 `cal-list` 獨立回讀 → 刪除 → 全年掃描確認無殘留。
`bin/ci-local` 會把這支測試當 local-only gate 自動跑（GitHub runner 沒有 osascript）。
