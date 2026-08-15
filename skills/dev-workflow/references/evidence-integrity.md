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

## Custom gate and new-test integrity

本節主詞是「新增或修改的 custom gate」與「新增的測試」——兩者的失效模式相同：一個永遠不會紅的檢查，跟沒有檢查等價，但看起來像有。

- 新增或修改的 custom gate／hook／lint／grep／script MUST fail closed：unreadable input、crash 或 unexpected exit 都不得被解讀為成功。
- 同一 gate MUST 以 known-bad negative control 證明會失敗，並以 clean positive control 證明會通過；輸入與 exit contract 要可重播且 deterministic。
- 新增測試若第一次執行就通過，MUST 先以一次性 throwaway mutant 破壞它守護的實作、觀察該測試轉紅、再還原，才可計入 evidence；未經此證明者標 `unverified`，不得標 `PASS`。手刻 assert harness（無 test framework 的「新測試從未紅過」提示）尤其適用。
- Gate 或 control 的設計 MUST 說明它自己壞掉時偏差朝哪個方向。只會朝「更綠」偏的失效永遠不會表現成紅燈，因此不能靠 gate 本身的結果發現，必須另設可觀察的中止條件（偵測到前提失效即 hard fail，而非靜靜降級）。
- Gate 只可宣稱實際檢查到的保護範圍。
