---
name: deps-check
description: 修改高扇入共用檔、public/exported API 或 signature 前，用 deps-check 列出 callers。重構、refactor、改名、rename、刪除、remove、搬移、move 或 extract 時觸發；支援 TypeScript／JavaScript 與 C#／.NET。純新增檔、private/local symbol、樣式文案或測試檔本身可跳過。
---

# deps-check

## Step 1：取得 fan-in evidence

編輯前執行：

```bash
bash ~/.agents/skills/deps-check/scripts/deps-check.sh <file-path>
```

只把 exit `0` 視為已執行或明確不適用。exit `2` 代表 UNKNOWN（路徑／project root／C# type 無法解析），必須停止並修正 target，或用 symbol／member `rg` 補足；exit `1` 是用法錯誤。偵測 mechanics 以 [script](scripts/deps-check.sh) 為準。

**完成條件：**保存 exit code；每個被改動的 public/exported target 都有 caller 清單或有證據的「不適用」。UNKNOWN 不得解讀為零依賴。

## Step 2：判讀 callers

- `0` heuristic matches：再查 re-export、dynamic import、reflection、DI／string registration。
- `1+` callers：逐一讀取並記錄受影響 contract；高 fan-in 時一併回報 impact 與必要的拆分／compatibility shim 選項。

腳本結果是 heuristic，不是安全證明；C# 同名型別、public member 與 runtime wiring 需人工過濾。

**完成條件：**所有 caller 與非靜態依賴風險都有 disposition；authorization 依 [dev-workflow](../dev-workflow/SKILL.md) S2 判定，caller 數量不另設確認 gate。新發現的 risk／material scope expansion 仍回 S2。

## Step 3：修改與驗證

依 caller ledger 做最小改動；發現新 dependency 時重跑 script 或 `rg`。完成後執行 repo 的 targeted tests 與 type/build gate（TS/JS 通常為 `npx tsc --noEmit`；.NET 為 `dotnet build`，以 repo 指令優先）。

**完成條件：**caller ledger 全數處理，targeted tests 與 type/build gate exit `0`；失敗則回 implementation，不可宣稱完成。
