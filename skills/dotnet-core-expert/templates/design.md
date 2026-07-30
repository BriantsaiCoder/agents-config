# design.md (架構設計範本)

## 概要
- 目的：描述系統高階架構、元件關係與資料流程
- 範圍：API 層、Service 層、Data 層、外部整合

---

## 架構圖（文字版）
- API (ASP.NET Core Web API)
  - Controllers
  - DTOs
- Application
  - Services
  - Interfaces
- Infrastructure
  - Repositories
  - EF Core DbContext
- External
  - Auth (Azure AD)
  - Storage (Blob)

---

## 介面契約 (API Contracts)
### 範例 Endpoint
`POST /api/v1/items`
Request:
```json
{
  "name": "string",
  "quantity": 1
}
```
Response: `201 Created` with Location header

---

## 資料模型 (Data Models)
- Item
  - Id (int, PK)
  - Name (nvarchar)
  - Quantity (int)
  - CreatedAt (datetimeoffset)

---

## 錯誤處理策略
- 使用 Problem Details (RFC7807)
- 不在生產中顯示堆疊資訊
- 自定義錯誤碼對應文件

---

## 非功能需求
- 可用性: 99.9%
- 延遲: API 95% < 200ms
- 安全: TLS 1.2+, OAuth2 / OpenID Connect

---

## 決策紀錄 (Decision Records)
- [Decision] 使用 EF Core vs Dapper: 選擇 EF Core（理由）

---

## 測試策略
- Unit tests: Service 層
- Integration tests: Controller + InMemory DB 或 Testcontainer
- E2E: Playwright 或 Postman collection
