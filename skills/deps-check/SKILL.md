---
name: deps-check
description: 動到高扇入共用檔案前，必定先跑 deps-check 列出依賴方——不跑就動刀是「改 A 壞 B」回歸最常見的來源。當使用者要求重構、改名、刪除、修改 public API、改 function/method signature、搬移檔案，或 Claude 自己判斷要改到共用檔案時，都必須先觸發此 skill。支援 TypeScript/JavaScript（前端 + Node.js 後端）與 C#/.NET（後端）。觸發關鍵字：重構、refactor、改名、rename、刪掉、remove、修改簽名、改 API、搬檔案、move、抽出去、extract。只有純新增檔、private/local symbol、樣式文案、測試檔自己可以跳過。
---

# deps-check — 編輯前的依賴查詢

## 為什麼需要

「改 A 壞 B」最常見的成因是編輯者不知道還有誰依賴 A。型別檢查（tsc / 編譯器）和測試能抓大部分回歸，但前提是：

1. 你知道要去跑測試
2. 測試覆蓋到了那個依賴路徑

在真正動刀之前先花幾秒確認「誰依賴我」，能把事後除錯省成事前決策。

## 觸發時機

自動觸發以下情境：

- 要修改 `src/lib/`、`src/services/`、`src/utils/`、`src/hooks/`、共用元件，或 .NET 的 Service / Repository / 共用 model 等**被多處引用**的檔案
- 要改名、刪除、搬移某個檔案或 exported / public symbol
- 要修改 exported function 或 public method 的 signature / return type
- 使用者說「重構」、「refactor」、「改 API」、「把這個抽出去」

**不需要觸發**的情境：

- 純新增檔案（還沒人依賴）
- 只改 private / local symbol，沒動對外介面
- 單純的樣式調整、文案改動
- 測試檔案自己

## 執行流程

### Step 1：跑腳本

呼叫 `~/.agents/skills/deps-check/scripts/deps-check.sh <file-path>`。

支援兩種檔案，依副檔名自動分流：

**TypeScript / JavaScript**（`.ts` `.tsx` `.js` `.jsx` `.mts` `.cts`）—— 涵蓋 React/Vue 前端與 Node.js 後端：

1. 往上找到最近的 `package.json` 當專案根
2. 若專案已安裝 `madge`，優先用 `madge --reverse` 列出依賴方
3. 否則 fallback 到 `grep`，搜尋 `src/`、`app/`、`lib/`、`test/` 等常見目錄下的 import / require 語句

**C# / .NET**（`.cs`）—— 涵蓋 .NET 後端：

1. 往上找到最近的 `.sln`（無則最近的 `.csproj` 目錄）當搜尋根
2. 抽出 target 檔宣告的 public / internal 型別名（class / interface / record / struct / enum）
3. 用 `grep -w` 在 solution 內所有 `.cs` 搜尋這些型別名的引用，排除 `bin/`、`obj/` 與 target 檔自己

> .NET 模式是「型別名 grep」啟發式，**不解析 namespace、不做語意分析**。跨 namespace 同名型別可能誤判，輸出需人工判讀過濾。若改的是 public 成員（method / property）而非整個型別，腳本只能定位到型別層級，必要時自行再 grep 成員名。

非 TS/JS/C# 檔案會直接略過，不中斷流程。

### Step 2：判讀輸出

**前置條件：只有腳本 exit 0 時本表才適用。** exit 2 代表「未執行扇入分析」（檔案不存在、找不到 package.json／.sln／.csproj、C# 檔未宣告 public/internal 型別），此時輸出為空**不等於**零依賴——一律當 UNKNOWN 停下，手動確認路徑或改用成員名 grep。exit 1 是用法錯誤。

根據依賴方數量決定策略：

| 依賴數 | 策略 |
|--------|------|
| 0（且 exit 0） | **0 個 heuristic match，不等於安全**。確認 target 不經反射／DI 字串註冊／dynamic import 被使用後才進行 |
| 1-3 | Read 每個依賴方，確認改動不會破壞它們 |
| 4+ | 回報使用者影響範圍，確認是否要拆成多步驟，或加 deprecation shim |

### Step 3：回報

在動手前先用一兩句話告知使用者影響範圍，例如：

> `OrderService.cs` 的 `OrderService` 被 8 個檔案引用，其中 `OrderController`、`CheckoutHandler` 用到 `CalculateTotal()`。我要改的是 `CalculateTotal` 的回傳型別，這兩個檔案需要同步更新。要繼續嗎？

### Step 4：動手改

確認後才開始編輯。編輯過程中若發現新的依賴關係（動態 import、re-export、反射、DI 容器註冊），再補跑一次腳本或手動 grep。

### Step 5：收尾驗證

改完後跑型別檢查 / 編譯，確認沒造成新的跨檔錯誤：

```bash
# TS/JS
npx tsc --noEmit

# .NET
dotnet build
```

有錯誤就回頭修，確定乾淨才視為改動完成。deps-check 告訴你**要看哪些檔**，編譯驗證你**有沒有改對**——兩步都走完才算閉環。

## 和其他機制的關係

- **型別檢查 / 編譯器**：deps-check 是**事前**告訴你要看哪些檔案，tsc / `dotnet build` 是**事後**驗證你有沒有改對。兩者互補。
- **bug-fix-settlement**：如果 deps-check 沒抓到某個隱性耦合（透過事件、全域狀態、DI、反射），事後觸發 bug-fix-settlement 沉澱評估時，應把這個隱性耦合寫進 cookbook 或 memory，下次就能提前提醒。
- **code review**：review 階段會再次檢查跨檔案影響，但此時改動已完成。deps-check 是為了讓 review 聚焦在品質而非回歸。

## Hook 模式（可選）

也可以把腳本掛在 PreToolUse hook 上，在 Edit / Write 前自動執行。範例 `.claude/settings.json`：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.agents/skills/deps-check/scripts/deps-check.sh \"$CLAUDE_TOOL_INPUT_file_path\"",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

Hook 模式適合「強制每次都跑」；skill 模式適合「AI 自行判斷時機」。兩種用同一支腳本。

腳本的 exit code 就是 hook 的閘：`0` 放行（分析完成，或副檔名不適用）、`2` 阻擋並把 stderr 回饋給 model（分析未執行）、`1` 用法錯誤。因此路徑打錯、找不到 package.json／.sln／.csproj，或 C# 檔完全沒宣告型別時，hook 會擋下 Edit 而不是靜默放行——這是 fail-closed 的設計，不要在 hook command 後面加 `|| true`。注意 `partial class Foo` 仍會被型別名 regex 抽出 `Foo`，走的是正常分析路徑而非 exit 2。
