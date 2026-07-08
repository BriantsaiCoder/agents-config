<!-- tier: host | consumed-by: codex | generated-from: hosts/codex-delta.md | last-verified: 2026-07-08 -->
<!-- FP:CODEX-DELTA-2026Q3 -->

# Codex CLI 差異層（僅注入 ~/.codex/AGENTS.md；正本安全 / 工作流 / 路由見 tier0-2 + routing）

## Communication

- 預設使用 zh-TW 回覆，technical terms 保留 English；除非使用者明確要求其他語言。

## Closeout Ledger（正本引用）

實作 / PR / merge 後最終回應 MUST 含可見 `Closeout Ledger`（6 rows），欄位定義與範例見 `~/.agents/skills/dev-workflow/references/ledgers.md`（S6 EXIT 強制）；不可只說「已完成」。

## PR 監控（S6 之上的 codex 特有疊加：heartbeat）

Bot-review triage 與 merge gate 正本見 dev-workflow S6 step 3 + [T0-9]。Codex 特有疊加：PR 仍開著則建立 heartbeat 持續監看 CI 與 review 至 terminal state / 明確不可用 / 合理 timeout；CI 失敗或 review 意見技術有效且可行動 → 自動修復、驗證、push、重新監看至 PR 關閉或 merge。優先 reviewer slug `copilot-pull-request-reviewer`，不可用則用 repo 支援的對等 slug 並記錄 fallback。

## Codex 端事實（路由靠點名）

- Codex 無 config import 機制，`AGENTS.md` 為唯一注入層（`AGENTS.override.md` 存在時整檔取代——終局遷移後 override 已退役，回歸 boring default 載入）。
- Codex 端 skill description 被截斷至 2–6 字元（metadata budget）；skill 路由靠 routing.md 逐名點名，不靠 description。
