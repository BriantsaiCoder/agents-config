# tasks.md (實作計畫範本)

## 目標
- 概要: 實作 Items API 基本 CRUD，包含驗證與單元測試
- 成功準則: 所有單元測試通過、API 文件更新

---

## 任務列表
- [ ] Task 1: Scaffold ASP.NET Core Web API
  - Owner: @dev
  - Est: 1 day
  - DependsOn: none
- [ ] Task 2: 設計資料模型與 DbContext
  - Owner: @dev
  - Est: 0.5 day
  - DependsOn: Task 1
- [ ] Task 3: 實作 ItemsService 與 Repository
  - Owner: @dev
  - Est: 1 day
  - DependsOn: Task 2
- [ ] Task 4: 建立 Controller 與 DTOs
  - Owner: @dev
  - Est: 0.5 day
  - DependsOn: Task 3
- [ ] Task 5: 撰寫單元測試 (MSTest)
  - Owner: @qa
  - Est: 1 day
  - DependsOn: Task 3, Task 4
- [ ] Task 6: 整合測試與 CI pipeline
  - Owner: @devops
  - Est: 1 day
  - DependsOn: Task 5

---

## 交付物
- `docs/specs/requirements.md`
- `docs/specs/design.md`
- `docs/specs/tasks.md`
- API 專案原型
- 測試結果報告

---

## 風險與緩解
- 風險: 依賴外部 Auth 服務造成驗證問題
  - 緩解: 使用本地 stub/Mock 在 PoC 階段

---

## 進度追蹤
- 更新格式：每個任務包含 Owner / Est / DependsOn / Status / Notes
