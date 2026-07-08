<!-- tier: host | consumed-by: codex | generated-from: hosts/codex-delta.md | last-verified: 2026-07-08 -->
<!-- FP:CODEX-DELTA-2026Q3 -->

# Codex CLI 差異層（僅注入 ~/.codex/AGENTS.md；正本安全 / 工作流 / 路由見 tier0-2 + routing）

## Communication

- 預設使用 zh-TW 回覆，technical terms 保留 English；除非使用者明確要求其他語言。

## Mandatory Closeout Ledger

每次 implementation / PR 建立 / merge / squash merge 後，最終回應 MUST 含可見的 `Closeout Ledger`；不可只說「已完成」。缺此 ledger = closeout 報告不完整。必列欄位：

- Self-simplification：PASS / FAIL / SKIPPED + evidence。
- Diff self-review：PASS / FAIL / SKIPPED + evidence。
- Relevant verification：確切命令或工具檢查 + 結果摘要。
- Review gate：reviewer 類型、agent id 或 unavailable 原因、最終 finding 摘要。
- PR / CI / review status（適用時）。
- Residual risks。

## Mandatory PR Copilot Review Monitoring

每個 GitHub PR，repo 支援時 MUST 請求 Copilot review（優先 reviewer slug `copilot-pull-request-reviewer`；不可用則用 repo 支援的對等 slug 並記錄 fallback）。建立 / 更新 PR 後持續監看 CI 與 review 狀態，直到 checks 達 terminal state 且自動 review 出現 / 明確不可用 / 合理 timeout。PR 仍開著則建立 heartbeat 持續監看至關閉或 merge。CI 失敗或 Copilot / review 意見技術有效且可行動 → 自動修復、驗證、push、重新監看至 PR 關閉。

## Codex 端事實（路由靠點名）

- Codex 無 config import 機制，`AGENTS.md` 為唯一注入層（`AGENTS.override.md` 存在時整檔取代——終局遷移後 override 已退役，回歸 boring default 載入）。
- Codex 端 skill description 被截斷至 2–6 字元（metadata budget）；skill 路由靠 routing.md 逐名點名，不靠 description。
