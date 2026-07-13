<!-- tier: 2 | consumed-by: claude,codex,copilot | generated-from: core/tier2-style.md | last-verified: 2026-07-13 -->
<!-- FP:STYLE-T2-2026Q3 -->

# tier2 風格（host 間差異可接受；只靠 git diff 巡檢，發現實害才升 tier）

[T2-1] 修改既有 code MUST 沿用該檔風格。觸發：編輯既有檔。驗證：diff 無無關格式或命名變更。
[T2-2] Commit／PR title MUST 用 Conventional Commits zh-TW，英 ≤72／中 ≤30 字；branch 用標準 type 前綴。觸發：commit、PR 或開分支。驗證：前綴與字數。
[T2-3] Public API MUST 有 .NET XML doc 或 TS JSDoc，含用途、param、return、throws。觸發：新增或修改 exported symbol。驗證：docstring 完整。
[T2-4] 註解 MUST NOT 改寫 code 或留對話 context；可能困惑時才寫 WHY。觸發：寫或改註解。驗證：無 what-paraphrase 或對話殘留。
[T2-5] 中文 MUST 用台灣慣用詞；技術名詞與識別字除外。觸發：中文散文或文件。驗證：依 `CONVENTIONS.md` grep 禁用詞 = 0。
