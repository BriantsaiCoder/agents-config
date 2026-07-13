<!-- tier: host | consumed-by: codex | generated-from: hosts/codex-delta.md | last-verified: 2026-07-13 -->
<!-- FP:CODEX-DELTA-2026Q3 -->

# Codex CLI 差異層（僅注入 ~/.codex/AGENTS.md；正本安全 / 工作流 / 路由見 tier0-2 + routing）

## Communication

- 預設使用 zh-TW 回覆，technical terms 保留 English；除非使用者明確要求其他語言。

## Closeout Ledger（正本引用）

實作 / PR / merge 後最終回應 MUST 含可見 `Closeout Ledger`（6 rows），欄位定義與範例見 `~/.agents/skills/dev-workflow/references/ledgers.md`（S6 EXIT 強制）；不可只說「已完成」。

## PR 監控（S6 之上的 codex 特有疊加：heartbeat）

Bot-review triage 與 merge gate 見 dev-workflow S6 step 3 + [T0-9]。PR 開啟期間用 heartbeat 監看至 terminal state 或合理 timeout；可行動的 CI／review 問題自動修復、驗證、push 後續監看。優先 `copilot-pull-request-reviewer`，fallback 須記錄。
