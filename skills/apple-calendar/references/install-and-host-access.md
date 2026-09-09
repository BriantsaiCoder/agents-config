# Install and host access

Bundled-reference links resolve from this file. Repository/output paths refer to the target workspace; script paths retain their stated skill-root location.

**選用：裝成短指令。** 本機已裝（`calx`／`cal-list`／`cal-add`／`cal-edit`／`cal-delete`），換機器要重跑：

```bash
ln -sfn ~/.agents/skills/apple-calendar/scripts/cal.sh ~/bin/calx
for s in add edit list delete; do
  ln -sfn ~/.agents/skills/apple-calendar/scripts/cal-$s.sh ~/bin/cal-$s
done
```

**短指令不可叫 `cal`** —— 那是 macOS 內建的月曆指令，`/usr/bin/cal` 在 PATH 中排在 `~/bin` 之前，取這個名字會讓所有子命令被系統指令攔截（症狀是 `year 'selftest' not in range 1..9999`，且刪除指令會靜默不執行）。磁碟檔名帶 `.sh` 是 repo 的 conformance 要求（`skills/` 下的可執行檔必須有腳本副檔名），與指令名無關。

## 三個必須知道的前提

**1. 權限不足會靜默回空，不會報錯。** EventKit 的 `writeOnly` 權限下，查詢回傳空集合而非錯誤 —— 呼叫端會誤判「當天沒事」而排入衝突行程。因此除 `authorize`／`selftest` 外，查詢與 CRUD 子命令都硬性要求 `fullAccess`，不足即非零退出。

TCC 授權掛在 **responsible process**（也就是呼叫的 AI host）上，不是掛在腳本上。Claude Code 已授權不代表 Codex CLI 或 Copilot CLI 也有。換 host 第一次使用時，在沙箱外執行 `calx authorize`，再於 macOS 提示中允許完整存取；系統設定的清單不能手動用「+」加入 app。若先前拒絕，才到「系統設定 → 隱私權與安全性 → 行事曆」重新開啟。實測 `swift script.swift` 直譯會被拒（無 bundle id），`osascript` 才通。

**2. 沙箱擋 EventKit，每次操作都需要停用沙箱。** 最常見的症狀是**授權狀態變成 `status=0 (notDetermined)`** —— 同一台機器、同一個 host，沙箱外回 3、沙箱內回 0，看起來像沒授權其實是沙箱攔截（工具會在 status=0 時提示這點，別急著去改系統設定）。其他症狀：`-600「應用程式不在執行中」`、`open` 回 `procNotFound`、`pgrep` 回 `sysmond service not found`。這代表**每個 `cal-*`／`calx` 指令都會產生一次核准提示** —— 要做多步操作（查詢後修改、建立後確認）時把它們合併成單一 Bash 指令，不要拆成多次呼叫。

**3. 重複事件的所有場次共用同一個 id。** `cal-edit <id>` 不指定場次會動到**第一場**，不是使用者想改的那場。因此重複事件未給 `--on` 一律拒絕執行。指定 `--on` 後預設只影響該場次（`EKSpanThisEvent`）；`--span future` 才會動到該場次及之後所有場次。單獨改過的場次（detached occurrence）id 會多出 `/RID=…` 後綴，仍可直接餵回 `edit`／`delete`。
