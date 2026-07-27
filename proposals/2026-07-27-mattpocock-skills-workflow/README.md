# mattpocock/skills 分析與遷移評估

**日期**：2026-07-27
**來源**：`github.com/mattpocock/skills` @ `main`（`pushed_at` 2026-07-23，189,547 stars）+ 兩支官方影片逐字稿
**觸發**：評估是否以此取代 `~/.agents/skills/dev-workflow` 全域 workflow

## 檔案

| 檔 | 內容 |
|----|------|
| [01-skills-inventory.md](01-skills-inventory.md) | engineering 17 + productivity 5 共 22 個 skill 逐項說明；user/model-invoked 分軸；v1.1 差異；兩處來源衝突裁決 |
| [02-workflow.md](02-workflow.md) | 官方建議 workflow 全貌（正本 = `ask-matt/SKILL.md`）；三條貫穿紀律；與 GSD/BMAD/Spec-Kit 的立場差異 |
| [03-migration.md](03-migration.md) | 三主機掛載實況實測；取代的得失清單；Stage 0/1/2 分階段方案 |
| [04-vs-codex-and-superpowers.md](04-vs-codex-and-superpowers.md) | 與 Codex 版建議的比較；**token 前提實測反駁**；取代 superpowers 的依賴盤點與執行順序；最終三項建議 |
| [05-round2-merged-plan.md](05-round2-merged-plan.md) | 第二輪：雙向修正各 4–6 點；合併後的 S-A ~ S-G 順序與終態架構。**§1 已被 10:32 重測修正，以 06 為準** |
| [06-feedback-to-codex.md](06-feedback-to-codex.md) | **可直接轉貼給 Codex 的回饋**：四項實測修正（附可重跑指令）+ 接受它六點 + 兩處立場。所有數據標 2026-07-27 10:32 時間戳 |
| [07-review-of-codex-final.md](07-review-of-codex-final.md) | Review Codex 最終建議：**立場改變（同意移除 superpowers）**；三個「已有載體」實測兩個不存在、一個循環；setup 矛盾的解法；逐項表態 |
| [08-codex-final-proposal.md](08-codex-final-proposal.md) | Codex 最終建議**原文存檔**（Phase 1–7、Phase 6 九項條件、完整職能對照表、最終決策表）。07 要搭配這份讀才自足 |
| **[06-final-recommendation.md](06-final-recommendation.md)** | **最終決策**：完整取代 = 否（3 條理由）；完整安裝 = 否，改選裝 8 支 + 併入 6 支 + 放棄 8 支（逐支清單與理由）；**plugin vs skills.sh 路線選擇** |
| [04-superpowers-feasibility.md](04-superpowers-feasibility.md) | 取代 superpowers 的可行性：token 假設實測推翻、`skillUsage` 調用量、功能缺口、耦合分類 |
| [05-vs-codex.md](05-vs-codex.md) | 與 Codex 建議的逐項比對（含實測裁決）；使用者實際問的替換情境 token 實算；逐支補位對映 |

## 合併後的最終方案（Stage 方案 × Codex 的 S-stage overlay）

兩份建議相容，合併成一張表：

| `dev-workflow` 階段 | 動作 | 來源 |
|---|---|---|
| **S0 ROUTE** | 保留現行決策表；**新增一列** WAYFINDER（大到單 session 裝不下**且路徑未明**），產出決策地圖後由 `to-spec` 併回 HEAVY。不要設成第二個 canonical router | 兩者共識 |
| **S1 NEEDS** | HEAVY 續走 `mp-grill-with-docs`，補 v1.1 grilling 三修（一次一題的理由、動手前確認閘、fact/decision 二分） | 我 |
| **S2 PLAN** | 單 session 用 session plan；跨 session 用 `to-spec` → `to-tickets`（vertical slice + blocking edges + wide-refactor 的 expand–migrate–contract） | Codex 表述較清楚 |
| **S3 IMPLEMENT** | 保留 branch / TDD / `deps-check` / stack rules。**新增容量軸**：task 除風險軸外加「塞得進一個乾淨 context window」；逼近 ~120k 不硬撐，`handoff` 換 session。`implement` 只當入口 wrapper，不得越過 gate | 兩者共識 |
| **S4 VERIFY** | **完全保留**，不動 | 兩者共識 |
| **S5 REVIEW** | 補上目前缺的方法：Standards（repo 標準 + Fowler 12 smell）+ Spec 兩軸**平行 sub-agent、不合併不重排**。作為 S5 的其中一個 reviewer，不取代 CI / bot review gate | 兩者共識 |
| **S6 CLOSEOUT** | **完全保留**，不動 | 兩者共識 |
| **跨 session** | 新增 `handoff` | Codex 標為最高 CP |
| **設計不確定性** | 新增 `prototype`（加 scope wrapper）、`research`（**加 read-only / write gate**） | Codex 的風險條件 |
| **不導入** | `setup-matt-pocock-skills`（撞既有 governance）、`ask-matt`（S0 已有更嚴格路由）、`triage`（除非真的採用 issue tracker workflow）、`resolving-merge-conflicts`（**除非剝掉 never-abort 的自動完成假設**） | Codex 的風險條件 |
| **superpowers** | **保留**，不取代（見 04）。可獨立檢視的是它的 SessionStart hook，不是整包換掉 | 兩者共識 |

## 一句話結論

**嫁接，不要取代。** 理由是 `dev-workflow` 的機械閘（X0 四形態 EXIT、四態 gate、ledger、`[T0-2]` 證據義務）在 Matt 全套裡**沒有任何載體**——他那套從頭到尾是 prose，`/implement` 只有 15 行、無 exit 條件、無證據義務。

真缺口只有四個，都能就地嫁接進既有 S 階段：smart zone 容量預算（S3）、依 context window 切票（S3）、兩軸平行 code review + Fowler 基線（S5）、`wayfinder` 多 session 迷霧探索（S0 新增一列）。

**三主機相容性不是障礙**（本評估過程中一度誤判，已實測推翻）：Codex 的 skill roots 表含 `r1 = ~/.agents/skills` 且 description 全文注入，Copilot 的 Personal 來源同樣涵蓋該目錄。

**取代 superpowers 不可行，且「省 token」的動機本身不成立**（[04](04-superpowers-feasibility.md)）：superpowers 14 支 desc = **465 tok**、mattpocock eng+prod 22 支 = **460 tok**，幾乎相同；差距只在 superpowers 的 SessionStart hook 額外注入 `using-superpowers` 全文（~766 tok），總計 ~2.7× 而非「遠小於」。真正的 token 大戶是本機 50 支的 **4,424 tok**（零個 user-invoked）。加上 superpowers 佔本機 skill 調用量 **28%**（177/628，mp-* 僅 8 次）、四支功能無對應物、兩處硬耦合。

**但使用者實際問的那個較小替換是可做的**（[05 §3.2](05-vs-codex.md)）：「用上游 skill 取代本機舊版 mp-*」的替換集是 **7 支**（5 個對應 + `grilling`／`domain-modeling`／`codebase-design` 三個薄殼實體；`mp-zoom-out` 無上游，保留），對比本機 mp-* 的 335 tok → **Claude 端 −101 tok、Codex/Copilot 端 −44 tok**，兩分支同號，不必等 `disable-model-invocation` 那個未定項驗完。

> **本目錄有併發寫入**：`04-superpowers-feasibility.md` 由另一個 session 於 09:11 寫入，`05-vs-codex.md` 由本 session 於 09:24 寫入。兩者結論一致、證據互補（04 有 `skillUsage` 與 hook 原始碼；05 有 Codex 建議比對與替換情境實算），已交叉引用而非合併覆蓋。

## 影片來源

| ID | 標題 | 用途 |
|----|------|------|
| `M6mYodf0dJM` | mattpocock/skills: A complete AI Coding workflow, end-to-end | 主流程完整演示（安裝 → setup → grill → to-spec → to-tickets → implement → code-review） |
| `A8mokin_YOs` | New Skills! v1.1 brings /wayfinder, /research, /implement, /to-spec, /to-tickets | v1.1 差異說明 |

逐字稿取得方式（沙箱可跑）：

```bash
python3 -m pip install --quiet --target "$TMPDIR/pylibs" youtube-transcript-api
```

（YouTube `timedtext` 端點直連回 0 bytes；`youtube-transcript-api` 可繞過。）

## 狀態

**尚未執行任何變更。** 本檔為分析與建議，`~/.agents/skills/` 與各 CLAUDE.md 皆未動。

相容性驗證已完成（[03-migration.md §2](03-migration.md)）：三家 loader 探針皆證實可讀 `~/.agents/skills` 的完整 description。**建議路徑 Stage 0 → Stage 1**，Stage 2 技術可行但不划算（丟掉全部機械閘）。

附帶挖出兩條 scope 外 follow-up，見 [03-migration.md §7](03-migration.md)：`agents-sync` 生成檔的 description-截斷舊宣稱 doc rot；50 個 skill 的 context load。
