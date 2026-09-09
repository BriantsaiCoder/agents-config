---
description: 'Use when turning ASP.NET Core Web API requirements into design.md and tasks.md, or when an approved design authorizes scaffolding the API and MSTest project.'
name: 'aspnet-api-architect'
---

# ASP.NET API Architect Skill

將 ASP.NET Core API 需求轉成可追蹤的設計、任務與可選 scaffold。預設以繁體中文輸出；目標 framework 依 repo 現況，greenfield 才預設 .NET 8。

## 邊界

本 skill 擁有「requirements → `design.md`／`tasks.md` → scaffold」的 orchestration，不重複維護一般規則：

若明示呼叫本 skill 卻要求一般 review、security 或 testing，只執行下列分流，不重新宣告 ownership：

- ASP.NET／C# implementation 與 review → `dotnet-core-best-practices`
- MSTest／unit／integration tests → `dotnet-testing-best-practices`
- focused vulnerability review → `shared-security-review`
- current Microsoft API、SDK、tutorial → `microsoft-docs`／`microsoft-code-reference`

## Workflow

1. **Discover** — 讀 repo instructions、solution/project、`Program.cs`、API contracts 與 `*requirements.md`。若只是文字需求，列出必要假設；不要捏造現有架構。
2. **Design** — 以 [`templates/design.md`](templates/design.md) 產生或更新設計：端點與 status codes、request/response schema、auth boundary、validation、persistence、error contract、observability、migration/rollback（若適用）。沿用 repo 既有文件位置；沒有慣例才用 `docs/specs/`。
3. **Decompose** — 以 [`templates/tasks.md`](templates/tasks.md) 建立 dependency-ordered tasks。每項包含 touched area、acceptance criteria、test evidence；高風險項目保留獨立 gate。
4. **Review gate** — 先呈現 unresolved decisions 與 trade-offs。需要使用者核准的 plan 依 shared `dev-workflow` S2 處理，不自行把文件核准擴張成 implementation。
5. **Scaffold when authorized** — 只在使用者明示要建立專案時執行最小 scaffold，名稱與路徑取自已核准設計：

   ```bash
   dotnet new webapi -n <ApiName> --framework net8.0
   dotnet new mstest -n <ApiName>.Tests --framework net8.0
   dotnet add <ApiName>.Tests/<ApiName>.Tests.csproj reference <ApiName>/<ApiName>.csproj
   ```

6. **Verify** — design-only 核對 endpoint／risk → task → acceptance criteria 與文件連結；有 scaffold／code 變更才跑 build 與 affected tests。環境缺失只將相依驗證標 `UNAVAILABLE`，不得宣稱該驗證通過。

## 完成條件

- `design.md` 的每個 endpoint／風險都有對應 task 或明確 non-goal。
- `tasks.md` 的每項工作都有驗收與驗證方法。
- 沒有覆寫既有文件、建立專案或改 code，除非使用者已授權該動作。
