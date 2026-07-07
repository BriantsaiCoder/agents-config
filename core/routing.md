<!-- tier: 1 | consumed-by: claude,codex,copilot | generated-from: core/routing.md | last-verified: 2026-07-07 -->
<!-- FP:ROUTING-2026Q3 -->

# 開發任務路由（薄層；workflow 正本在 dev-workflow skill）

- 任何開發任務：先讀 ~/.agents/skills/dev-workflow/SKILL.md 並照其 S0 決策表路由。描述含錯誤行為 / 測試失敗 / regression 的走 SKILL.md 的 BUGFIX 鏈；單檔 / ≤1 天小需求走 skill sdd。
- 逐名點名 skill（Codex 端 description 被截斷至 2–6 字元，路由靠點名不靠 description）：dev-workflow、sdd、deps-check、mp-grill-with-docs、mp-diagnose、bug-fix-settlement、frontend-release-verification、backend-release-verification、dependency-security-scan、design-doc-mermaid。

## 最高風險攔截（常駐，防新鮮 skill prose 搶贏路由，尤其 superpowers 終態鏈）

- [R-1] 收尾類 skill（如 finishing-a-development-branch）MUST NOT 在 S4/S5 全綠前 invoke。觸發：任務仍有 FAIL 或未跑的 verify / review gate。驗證：S4 與 S5 四態全 PASS 才放行。例外：無。
- [R-2] fix 之前 MUST 先有 failing regression test（紅→綠）；無可測 seam 須明確標記例外並附替代驗證。觸發：修 bug 的變更無先行紅測。驗證：紅燈輸出存在於證據。例外：無 seam（須標記）。
- [R-3] S2 ⏸ plan gate 在任何 auto / autopilot 模式下 MUST NOT 豁免。觸發：非 plan 模式且將改檔。驗證：改檔前有計畫產物＋引用用戶確認原句。例外：無。
