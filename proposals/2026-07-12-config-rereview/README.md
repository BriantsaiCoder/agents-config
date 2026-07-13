# 2026-07-12 三主機設定全面重審（re-review）

> **讀者是 AI 模型**。本提案是 2026-07-06/07/08/10/11 多輪審計之後的全面重審：以前次結論為基準做 regression check + 找新問題。狀態：**FINDINGS + 建議，未執行**（實際修復須用戶批准，[T0-8]）。

## 結論一句話

前四輪修復**零回歸**（conformance 10/10、$defaults、guard、遮罩、no-clobber 全部健在），但重審找出 **48 條 confirmed findings（P1×4）+ 6 條 critic gaps（P1×1）**，且其中大半收斂到**兩個系統性根因**：機械守護落地無「三家 parity」制度步驟、規則「驗證：」欄與可執行探針全面脫鉤。修單條 finding 不修這兩個根因，下次審計還會長出同型清單。

## 方法（可重跑）

- Workflow `wf_b640f194-398`（56 agents、0 error）：7 維度 finder（entry-layer / hooks-guards / sync-tooling / skills-layer / agents-governance / prior-findings-regression / institutional-quality）→ barrier 去重 → per-finding skeptic 對抗驗證（結果 0 條 REFUTED、7 條 DOWNGRADED、部分子主張被修正）→ completeness critic（補 6 gaps）。
- 全程唯讀。conformance.sh 探針之暫移/還原 `~/.codex/AGENTS.md` 與 audit log append 屬該腳本設計內行為，執行前已讀原始碼確認可還原。

## 檔案地圖

| 檔 | 內容 |
|----|------|
| `01-findings.md` | 48 findings + 6 gaps 正本，每條附可重跑探針（回應 GOV-3 持久化義務） |
| `02-recommendations.md` | 分批修復計畫（Batch A–E + 不做清單），含風險等級與 rollback |
| `03-norm-candidates.md` | 規範候選最終版（ID 已重編去衝突）：T0-10、T1-8、CONVENTIONS 14–19、lint8–10、GOV-1–5 |
| `STATUS-draft.md` | proposals/ 狀態總表草稿（批准後 mv 至 `proposals/STATUS.md`，回應 META-2） |

## 對前輪審計的重大事實更新（讀舊文件前必知）

1. **「Codex 端 skill description 被截斷至 2–6 字元」已失效**：codex-cli 0.144.0 實測（`codex debug prompt-input`）52 條 description 全文注入。該 stale 宣稱散布 9 處（core/routing.md、hosts/codex-delta.md、dist×2、三家部署檔、DCT 專案 CLAUDE.md、Claude auto-memory），連帶「description 寫壞也無所謂」的假設不再成立。見 01 SKILL-01。
2. **「stitch 雙 key」主張被推翻**：`~/.claude.json`、`~/.codex/stitch.env`、`.backup` 三處 sha256 前 8 碼同為 `5c957e66`，是同一把 key。殘留問題是 `~/.claude.json` 內仍有明文（07-10 修復只涵蓋 config.toml 半邊）。見 01 F-R1。
3. **FP 指紋在 Claude host 的 HTML comment 載體被剝離**：`claude -p` 實測探針恆回 NONE，對照組復誦 [T0-3] 成功——本體有載入、comment 沒進 context。「三家 FP 活體測試」07-08 曾綠燈，但 07-10 部署後未重跑。見 01 INJ-2、F-R5。
