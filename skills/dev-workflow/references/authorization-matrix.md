<!-- tier: workflow-reference | consumed-by: claude,codex,copilot -->

# Authorization matrix

本檔擁有 mutation／side effect 的授權分類；首次進 S2，或 path、command class、branch target、effect／風險改變時載入。context 中已核對且未變的分類可重用。先由 path、command class、branch target 與 effect 判定 mechanical trigger；mechanical trigger 設定不可覆寫的 risk floor，不得由 AI 自評或 risk label 降級；多個 trigger 同時命中時取最高 risk floor。

| Action／effect | Risk floor | 既有授權與 gate |
|---|---|---|
| Read-only answer／review／diagnosis | Low | 可直接 probe；不得擴成 implementation。 |
| In-scope local reversible edit／build／test | Low／Medium | 明確 change／build／fix 原句授權 in-scope local implementation 與 non-destructive verification；Medium-risk 留 session plan，不需第二次確認。 |
| Personal preference：model／effort／verbosity／UI，且不新增 capability | Low／Medium | 走 local reversible track；temp copy／parse／diff／rollback／canary，不強迫 hosted PR。 |
| Policy／capability：plugin／MCP install／enable、新 credential／permission／network／external tool capability；另含 tier rules、authorization、hooks、sandbox、CI、secret transport、cross-host routing | High | 依 [INT-10] 走 policy track；同一設定檔可同時含兩種 track，逐 effect 分類。 |
| External write／publish | High | 未在原核准 scope 時停在 [T0-8]；push／PR／merge 另依 [INT-1]。 |
| Credential-only add／rotate | High | 依 [T0-8] 與 [INT-10]；未同時命中 [T0-6] 類別時，T0-6 rollback 不適用。 |
| Auth、payment、migration、大量刪除、crypto、multi-tenant、rate-limit、deployment pipeline | High | 依 [T0-6] 附 rollback；migration 另依 [T0-7]。 |
| 其他 destructive action | High | 依 [T0-8] 停在 protected gate，列 exact target 與可復原方式。 |

`local reversible` 表示 tracked change 可由 VCS 回復，或 machine-local config 已有 temp backup／rollback；未備份的 untracked／ignored 刪除不算 reversible。MCP install／enable／add／update，或修改 command／args／env，均屬 Policy。刪除／停用／放寬既有 hook、sandbox、permission 或其他 control 也屬 Policy，不因 diff 是刪除而降級。Secret-bearing 內容進 chat／transcript 視為 egress，依 [T0-4] 禁止。

High、protected boundary 或 material scope expansion 在 S2 先核對 exact action／scope 與既有 plan／核准；已涵蓋且風險與副作用未變時不重問，仍完成適用 gates。缺少適用 plan／核准或發生實質變更才停在相依步驟，續做已授權的獨立工作；不得把「先分析／等確認」當成 implementation 授權。只有會改變 outcome／scope／risk 的 material ambiguity 才停下發問。低風險、可逆、無 material impact 採 sensible default 並記 default／impact。

## Local verification loop

已確認使用 disposable fixtures、無 production access／未授權外部 effect 的 local checks，可直接執行、修復本次變更造成的失敗並重跑 affected checks。隔離性或資料保留需求未知時只停相依測試，先核對 repo test contract；此規則不宣稱所有 repo 的測試都可拋棄資料。

## Local checkpoint commit

checkpoint 只可在非 main／master 的 feature branch／isolated worktree，且 targeted S4 PASS 後建立；不得宣稱 final done。checkpoint 的 targeted S4 必須使用 repo／CI 既有 commands，不逐 turn 自造 gate。checkpoint 只 stage explicit path allowlist，MUST NOT 用 `git add -A`；stage 後跑 `gitleaks git --staged --redact`。checkpoint MUST NOT 包含 secrets、permission／sandbox、hooks、CI、deployment、migration、global／security policy，也不得 push、開 PR 或 merge。最終 publication 仍以原 baseline 到 current HEAD 的累積 diff 重跑適用 S4／S5／CI／review。

checkpoint 前先以 `git diff --cached --name-only` inventory index；發現 allowlist 外既有 staged path 即停止，不得擅自 unstage。explicit stage 後再驗 staged path set 僅含 allowlist，才可跑 gitleaks 與 commit。
