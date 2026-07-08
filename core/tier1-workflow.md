<!-- tier: 1 | consumed-by: claude,codex,copilot | generated-from: core/tier1-workflow.md | last-verified: 2026-07-08 -->
<!-- FP:WORKFLOW-T1-2026Q3 -->

# tier1 工作流紀律（容忍一個 session 延遲；正本規則見 dev-workflow skill）

[T1-1] 改高扇入共用檔（改名 / 改 signature / 搬檔 / 改 public API）前 MUST 先列依賴方。觸發：編輯被多處 import 或呼叫的檔。例外：無。驗證：deps-check 或 grep caller 清單在證據中。
[T1-2] 計畫 MUST 標風險等級（低 / 中 / 高）；中、高附 rollback 策略 + 加強驗證。觸發：進 plan mode 輸出計畫。例外：無。驗證：計畫含風險等級欄；中高含 rollback 段（與 [T0-6] 疊加）。
[T1-3] 每個 commit MUST 能獨立 checkout build 通過（reproducible commit）。觸發：拆分 commit。例外：feature branch 的 `[wip]` 探索 commit。驗證：commit 粒度不留 transient broken state。
[T1-4] 中 / 高風險變更 MUST 附 before/after 基線對照（API response / query count / 輸出樣本）。觸發：diff 命中中高風險類。例外：無。驗證：證據含改動前後對照。
[T1-5] 自我簡化只動當前正在寫的新 code，MUST NOT 順手改既有 code 的格式 / 命名 / 註解。觸發：交付前簡化 pass。例外：任務明確要求重構既有 code。驗證：diff 僅落在本次新增 / 修改行。
[T1-6] 自己變更造成的 dead code（unused import / var / func）MUST 清除；pre-existing dead code 提及但不刪。觸發：變更後產生未使用符號。例外：pre-existing（須用戶確認才刪）。驗證：無新增未使用符號。
[T1-7] 選型 MUST 依序由上往下找：原生（語言 / 框架 / 平台內建）> 標準函式庫 = repo 既有模組 > 成熟第三方套件 > 手寫。觸發：引入新依賴或自寫 ≥50 行可由內建取代者。例外：前面層級皆無合適方案。驗證：選型理由在 PR / 計畫可追溯。
