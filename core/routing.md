<!-- tier: 1 | consumed-by: claude,codex,copilot | generated-from: core/routing.md | last-verified: 2026-07-13 -->
<!-- FP:ROUTING-2026Q3 -->

# 開發任務路由（薄層；workflow 正本在 dev-workflow skill）

- 任何開發任務：先讀 ~/.agents/skills/dev-workflow/SKILL.md 並照其 S0 決策表路由。描述含錯誤行為 / 測試失敗 / regression 的走 SKILL.md 的 BUGFIX 鏈；單一 target file、≤3 個 actionable tasks 且未命中風險攔截者走 skill sdd。
- 逐名點名 skill（Codex 端 description 被截斷至 2–6 字元，路由靠點名不靠 description）：dev-workflow、sdd、deps-check、mp-grill-with-docs、mp-diagnose、bug-fix-settlement、frontend-release-verification、backend-release-verification、dependency-security-scan、design-doc-mermaid。
- 通用路由（本體皆在 ~/.agents/skills/）：stack 實作 → 同名 `*-best-practices`；Auth → `auth-implementation-patterns`；Docker → `containerization`；Tailwind v4 → `tailwind-v4-shadcn`；新專案初始化 → `init-project-docs`；整庫上手 → `acquire-codebase-knowledge`。
- 工具鏈 / 專項（非 `*-best-practices` 命名，須逐名點名才可路由）：Vite 設定 / 建置 / 打包問題 → `vite`；Vitest 測試撰寫與設定 → `vitest`；安全稽核 / 威脅面盤點 → `security-audit`；PR 級安全審查 → `security-review`；瀏覽器探索式互動 → `agent-browser`。
- Stack 版本 pin / 細則按需讀 `~/.agents/rules/<stack>.md`（dotnet、typescript、frontend-spa、winforms、cpp、testing、infra、cookbook）。

## 最高風險攔截（常駐，防新鮮 skill prose 搶贏路由，尤其 superpowers 終態鏈）

- [R-1] 收尾類 skill（如 finishing-a-development-branch）MUST NOT 在 S4/S5 全綠前 invoke。觸發：任務仍有 FAIL 或未跑的 verify / review gate。驗證：S4 與 S5 四態全 PASS 才放行。例外：無。
- [R-2] fix 之前 MUST 先有 failing regression test（紅→綠）；無可測 seam 須明確標記例外並附替代驗證。觸發：修 bug 的變更無先行紅測。驗證：紅燈輸出存在於證據。例外：無 seam（須標記）。
