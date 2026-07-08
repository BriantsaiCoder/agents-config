<!-- tier: 2 | consumed-by: claude,codex,copilot | generated-from: core/tier2-style.md | last-verified: 2026-07-08 -->
<!-- FP:STYLE-T2-2026Q3 -->

# tier2 風格（host 間差異可接受；只靠 git diff 巡檢，發現實害才升 tier）

[T2-1] 修改既有 code MUST 沿用該檔風格（縮排 / 命名 / 註解寫法 / pattern），即使個人偏好不同。觸發：編輯既有檔。例外：無。驗證：diff 不含無關格式 / 命名變更。
[T2-2] Commit 與 PR title MUST 用 Conventional Commits zh-TW（`feat(api): 新增 xxx`）；第一行英 ≤72 / 中 ≤30 字；branch 用 `feat/` `fix/` `chore/` `refactor/`。觸發：commit 或開分支。例外：無。驗證：commit message 前綴 + 字數。
[T2-3] Public API（exported function / class / type）MUST 寫 docstring（.NET XML doc / TS JSDoc，含用途 / param / return / throws）。觸發：新增或改 exported 符號。例外：無。驗證：exported 符號有 docstring。
[T2-4] 註解 MUST NOT 寫 what-paraphrase 或對話 context（例「fixed in PR X」「used by Y flow」）；WHY 註解判準放寬到「兩年經驗工程師可能困惑」即寫。觸發：寫或改註解。例外：無。驗證：註解不含 PR 編號 / flow 名等對話殘留。
[T2-5] 台灣慣用詞 MUST 一律使用；禁「創建」（用建立）、「質量」（用品質）、「視圖」（用檢視表）；完整對照見 CONVENTIONS.md 附錄 A。觸發：產出中文散文 / 文件。例外：技術名詞與識別字保留原文。驗證：grep 禁用詞 = 0。
