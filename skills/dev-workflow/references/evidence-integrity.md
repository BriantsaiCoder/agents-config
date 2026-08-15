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

主詞是「新增或修改的 custom gate」與「新增的測試」；兩者失效模式相同——一個永遠不會紅的檢查跟沒有檢查等價，但看起來像有。

- 新增或修改的 custom gate／hook／lint／grep／script MUST fail closed：unreadable input、crash 或 unexpected exit 都不得被解讀為成功。
- 同一 gate MUST 以 known-bad negative control 證明會失敗，並以 clean positive control 證明會通過；輸入與 exit contract 要可重播且 deterministic。
- Gate 或 control MUST 在其 S4 ledger row 或 script 檔頭記一行「失效時偏差朝哪個方向」。只朝「更綠」偏的失效不會表現成紅燈，因此無法由 gate 自己的結果發現，MUST 另設可觀察的中止條件（偵測到前提失效即 hard fail，不得靜默降級）。
- High-risk change，或新增／修改 custom gate 時，若新增測試第一次執行就通過，MUST 判定它是 vacuous 還是行為早已存在：依 [test-gap-analysis](../../test-gap-analysis/SKILL.md) 的 mutation 程序（isolated copy、不得改動使用者的 active checkout、還原以 hash 比對證明）破壞它守護的實作一次。所選 mutant MUST 是**非等價**且合理預期會使該測試轉紅者。測試轉紅記為 pre-existing behavior 的 regression armor；未轉紅且 mutant 經確認非等價才判 vacuous，MUST 修正或刪除；無法確認 mutant 非等價時判 inconclusive，走 `SKIPPED`／`UNAVAILABLE`，MUST NOT 據此刪測試。未做此判定者不得標 `PASS`。本條受上節「不作 blanket requirement」限定，不擴及一般 change。
- Gate 只可宣稱實際檢查到的保護範圍。

## Test integrity

適用任何為使測試或 gate 轉綠而修改 test 檔的動作。改 test 以達成 GREEN 屬 behavior-affecting edit，本檔依 SKILL.md S4 的載入條件已在該情境載入，不另在 kernel 設指標。

- MUST NOT 為轉綠而弱化測試：放寬 assertion、加 skip／ignore、調高容差、刪除失敗測試。測試看似錯誤時 surface 成 spec 問題，不得就地埋掉。
- MUST NOT 在同一步同時修改 test 與 implementation 以達成 GREEN。改一邊、跑、再改另一邊；同步修改會把 correctness 重新定義成剛好符合當下的 bug。
- 驗證：assertion 變動對得到 spec／behavior 變更；改 test 與改 implementation 之間存在一次 run 的輸出（成對的 RED／GREEN 執行紀錄，而非事後自述）。
