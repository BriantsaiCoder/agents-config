<!-- tier: workflow-reference | consumed-by: claude,codex,copilot | parent: SKILL.md (S4 VERIFY) -->

# Evidence integrity

本檔補強 S4 verification evidence；不取代 S5、CI 或 bot review，也不授權新增 dependency 或測試基礎設施。結果沿用四態 `PASS`／`FAIL`／`SKIPPED`／`UNAVAILABLE`；未執行不得標 `PASS`。

## Verification scope

- Medium／High 留 before／after evidence。依 diff 判斷 integration／E2E／security 的適用性；host／repo 明定 required checks 不得略過。
- 不適用標 `SKIPPED`（理由）；工具／環境使適用檢查無法執行標 `UNAVAILABLE`（probe），不得改稱不適用。
- 適用 checks 通過後，僅新變更、失敗、未解疑慮或明定 gate 要求才擴大／重跑。

## Fresh final evidence

- 完成證據 MUST 來自最後一次影響行為的 edit 之後的一次 final verification pass；後續 behavior-affecting edit 使舊結果失效。
- Medium／High 或 PR MUST 記錄該 pass 的 exact source state 與 replay command；優先使用既有 repo-owned CI／gauntlet entry point，沒有時記錄實際依序執行的 exact commands，不為 gate 自造 infrastructure。
- Source state：clean tree 記 current HEAD；dirty tree 記 immutable HEAD 加上已通過 gitleaks 的完整 dirty review package content hash。

## Requirement and failure coverage

- 有正式 spec artifact、明列 acceptance criteria 或 behavior change 時，將每個 acceptance criterion 與 negative invariant 對到一個 test／probe／gate 及四態結果；不適用時標 `SKIPPED` 並附理由。
- High-risk change 先列具體 failure model，再把每個 failure mode 對到 task-specific catching layer 或理由化的 `SKIPPED`／`UNAVAILABLE`。Mutation、changed-line coverage、property 或 adversarial testing 只在能增加 evidence 時使用，不作 blanket requirement。

## Agent／workflow 效果比較

只有要宣稱模型、skill 或 workflow 調整改善品質／效率時才啟用；一般程式修改與純規則符合性檢查不因此新增 A/B gate。

- 執行前固定代表性任務、起始 source state、驗收標準、host／model／effort 與其他設定；baseline／candidate 每次只改一項，並記錄可重播的 prompt、commands 與兩組設定。模型本身為比較項時，其餘條件仍固定。
- 每次使用 fresh session 與獨立 fixture／worktree，避免前次答案、修改或記憶污染；worktree 只隔離檔案，不保證 host memory／global config 隔離，未能隔離的因素要明列。
- 優先重用目前適用的 runner、tests 與 artifact probes；task-specific 舊 harness 不硬套，也不為本契約新增平台或 dependency。Invocation canary 只證明有被呼叫，不等於任務品質。
- 分開記錄任務成功次數／執行次數、規則違反、人工介入、耗時，以及可取得的 token／成本。缺資料標 `UNAVAILABLE`（probe），不得當成零；失敗／重試不自動計為規則違反或人工介入。工具或環境失敗另列，不能靜默丟棄以提高成功率。
- 首輪只做小規模篩選（例如 bugfix、read-only 分析、review 各一例，A/B 各一次），有增益跡象才依預先列出的 runs／timeout／用量預算增加重複次數。所有失敗與重試都保留；首次成功與重試成功分開，禁止只報最好一次。
- 以實際行為測試／artifact 或事先定義的 review rubric 判成功；代理自評或 keyword 命中不能單獨證明品質。已知缺陷與規則違反另行裁決，較快或較省不得掩蓋它們。
- 小樣本僅支持初步結論；無可比 baseline 或未執行比較時，只能報有實際 probe 支持的符合性結果與預期效益；未驗證不得標符合性 PASS，也不能宣稱已改善。各 consuming host 分別記結果，不把單一 host 的證據外推。

方法參考：[ECC agent-eval](https://github.com/affaan-m/ECC/blob/5064474d4d762dc9640234a41617cccb79185cec/skills/agent-eval/SKILL.md) 與 [eval-harness](https://github.com/affaan-m/ECC/blob/5064474d4d762dc9640234a41617cccb79185cec/skills/eval-harness/SKILL.md)；僅吸收比較方法，授權與驗證 gates 仍由本 workflow 管理。

## Custom gate and new-test integrity

主詞是「新增或修改的 custom gate」與「新增的測試」；兩者失效模式相同——一個永遠不會紅的檢查跟沒有檢查等價，但看起來像有。

- 新增或修改的 custom gate／hook／lint／grep／script MUST fail closed：unreadable input、crash 或 unexpected exit 都不得被解讀為成功。
- 同一 gate MUST 以 known-bad negative control 證明會失敗，並以 clean positive control 證明會通過；輸入與 exit contract 要可重播且 deterministic。
- Gate 或 control MUST 在其 S4 ledger row 或 script 檔頭記一行「失效時偏差朝哪個方向」。只朝「更綠」偏的失效不會表現成紅燈，因此無法由 gate 自己的結果發現，MUST 另設可觀察的中止條件（偵測到前提失效即 hard fail，不得靜默降級）。
- High-risk change，或新增／修改 custom gate 時，若新增測試第一次執行就通過，MUST 判定它是 vacuous 還是行為早已存在：依 [test-gap-analysis](../../test-gap-analysis/SKILL.md) 的 mutation 程序（isolated copy、不得改動使用者的 active checkout、還原以 hash 比對證明）破壞它守護的實作一次。所選 mutant MUST 是**非等價**且合理預期會使該測試轉紅者。測試轉紅只證明它**非空洞**；是否另記為 pre-existing behavior 的 regression armor，取決於該實作是否先於此測試存在，MUST 各自認定，不得由轉紅逕行推論。未轉紅且 mutant 經確認非等價才判 vacuous，MUST 修正或刪除；無法確認 mutant 非等價時判 inconclusive，走 `SKIPPED`／`UNAVAILABLE`，MUST NOT 據此刪測試。未做此判定者不得標 `PASS`。本條受上節「不作 blanket requirement」限定，不擴及一般 change。
- Gate 只可宣稱實際檢查到的保護範圍。

## Test integrity

適用任何為使測試或 gate 轉綠而修改 test 檔的動作。改 test 以達成 GREEN 屬 behavior-affecting edit，本檔依 SKILL.md S4 的載入條件已在該情境載入，不另在 kernel 設指標。

- MUST NOT 為轉綠而弱化測試：放寬 assertion、加 skip／ignore、調高容差、刪除失敗測試。測試看似錯誤時 surface 成 spec 問題，不得就地埋掉。
- MUST NOT 在同一步同時修改 test 與 implementation 以達成 GREEN。改一邊、跑、再改另一邊；同步修改會把 correctness 重新定義成剛好符合當下的 bug。
- 驗證：assertion 變動對得到 spec／behavior 變更；改 test 與改 implementation 之間存在一次 run 的輸出（成對的 RED／GREEN 執行紀錄，而非事後自述）。
