<!-- tier: workflow-reference | consumed-by: claude,codex,copilot | parent: SKILL.md (S4 VERIFY) -->

# Evidence integrity

本檔補強 S4 verification evidence；不取代 S5、CI 或 bot review，也不授權新增 dependency 或測試基礎設施。結果沿用四態 `PASS`／`FAIL`／`SKIPPED`／`UNAVAILABLE`；未執行不得標 `PASS`。

## Fresh final evidence

- 完成證據 MUST 來自最後一次影響行為的 edit 之後的一次 final verification pass；後續 behavior-affecting edit 使舊結果失效。
- Medium／High 或 PR MUST 記錄該 pass 的 exact source state 與 replay command；優先使用既有 repo-owned CI／gauntlet entry point，沒有時記錄實際依序執行的 exact commands，不為 gate 自造 infrastructure。
- Source state：clean tree 記 current HEAD；dirty tree 記 immutable HEAD 加上已通過 gitleaks 的完整 dirty review package content hash。

## Requirement and failure coverage

- 有正式 spec artifact、明列 acceptance criteria 或 behavior change 時，將每個 acceptance criterion 與 negative invariant 對到一個 test／probe／gate 及四態結果；不適用時標 `SKIPPED` 並附理由。
- High-risk change 先列具體 failure model，再把每個 failure mode 對到 task-specific catching layer 或理由化的 `SKIPPED`／`UNAVAILABLE`。Mutation、changed-line coverage、property 或 adversarial testing 只在能增加 evidence 時使用，不作 blanket requirement。

## Custom gate integrity

- 新增或修改的 custom gate／hook／lint／grep／script MUST fail closed：unreadable input、crash 或 unexpected exit 都不得被解讀為成功。
- 同一 gate MUST 以 known-bad negative control 證明會失敗，並以 clean positive control 證明會通過；輸入與 exit contract 要可重播且 deterministic。
- Gate 只可宣稱實際檢查到的保護範圍。
