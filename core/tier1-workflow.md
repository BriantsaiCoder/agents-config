<!-- tier: 1 | consumed-by: claude,codex,copilot | generated-from: core/tier1-workflow.md | last-verified: 2026-07-13 -->
<!-- FP:WORKFLOW-T1-2026Q3 -->

# tier1 工作流紀律（容忍一個 session 延遲；正本規則見 dev-workflow skill）

[T1-1] 改高扇入共用檔、名稱、signature、位置或 public API 前 MUST 列依賴方。觸發：編輯共用介面。驗證：deps-check 或 grep 證據。
[T1-2] 計畫 MUST 標低／中／高風險；中、高附 rollback、加強驗證，並與 [T0-6] 疊加。觸發：輸出計畫。驗證：風險與 rollback 欄。
[T1-3] 除 feature branch 的 `[wip]` 探索外，每個 commit MUST 可獨立 checkout 且 build 通過。觸發：拆 commit。驗證：無 transient broken state。
[T1-4] 中、高風險變更 MUST 附 before/after 基線。觸發：中、高風險 diff。驗證：API response、query count 或輸出樣本。
[T1-5] 除非任務明確要求重構，MUST NOT 順手改既有 code 的格式、命名或註解。觸發：交付前簡化。驗證：diff 無無關變更。
[T1-6] MUST 清除自己造成的 dead code；pre-existing 只提及，取得用戶確認才刪。觸發：產生 unused symbol。驗證：無新增 dead code。
[T1-7] 選型 MUST 依序為原生 > 標準函式庫／repo 既有模組 > 成熟第三方 > 手寫。觸發：新增依賴或手寫 ≥50 行。驗證：記錄選型理由。
