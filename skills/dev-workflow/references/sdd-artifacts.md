# Optional SDD artifacts

沿用既有 `sdd/<slug>/`，或使用者／repo 要求 SDD 產物、跨-session 交接或歸檔時載入。授權只依 dev-workflow S2；此 reference 不另設 proposal／implementation 核准流程。

- Session 記行為、影響檔案、情境式驗收條件與 tasks；通過各項驗收後才標完成。
- 需要持久化時沿用 `sdd/<slug>/proposal.md` 與 `tasks.md`，slug 使用英文小寫與連字號；先核對既有內容，不覆蓋尚未完成的工作。
- 使用者明示歸檔時，確認 `tasks.md` 每項皆為 `- [x]`，未完成則停止並回報；用 `date +%F` 取得日期，確認目的地不存在後移至 `sdd/archive/<日期>-<slug>/`（tracked files 用 `git mv`），回報新路徑與摘要。其他檔案／子目錄一併保留。
- 沒有持久化產物則歸檔標 `SKIPPED`，不補造檔案；交付仍須通過 dev-workflow S4–S6 適用 gates。
