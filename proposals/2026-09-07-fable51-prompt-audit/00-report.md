# Fable 5.1 prompt audit：全域 CLAUDE.md 與 shared skills（2026-09-07）

方法：官方 [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) 與 [Prompting Claude Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1) 兩頁（當日 WebFetch）＋ claude-api skill 的 `shared/prompt-audit.md` 四組 pattern 與 `shared/model-migration.md` Fable 5.1 兩節。範圍：`~/.claude/CLAUDE.md` 與其 @import、`~/.claude/rules`、`~/.agents/skills` 75 支 SKILL.md 與 dev-workflow 10 個 references、ponytail SessionStart 注入。目標：`claude-fable-5-1` 跑在 Claude Code 2.1.260。前一輪正本：`2026-08-22-opus5-prompt-audit`（常駐 prompt）、`2026-09-05-skill-review-fable51-opus5`（skill 層）；本報告只做 delta。

使用者原句：「根據prompting-best-practices審核我升級到Fable 5.1之後全域CLAUDE.md、SKILL要做那些調整? 先列出來，等待我做決定。」→「A1~A6全部依照你建議的實作」→「兩個都 merge」→「把 D skills/sdd 也 commit 掉」→「好，刪掉 commands/sdd.md」→「兩個 follow-up 也一起清掉」。

## 1. 結論

1. **官方要求「因模型升級而刪」的 pattern，常駐 prompt 與 75 支 SKILL.md 仍零命中**（update suppressor、anti-formatting、think-step-by-step、numeric cap、self-check scaffolding 五組 grep 全 0；pressure language 只有 dev-workflow 的 RFC-2119 用法，09-05 §8 已裁定）。08-22 與 09-05 的 clean-surface 結論延續。
2. **真正的 delta 是 harness 與 CLAUDE.md 的重疊面。** Claude Code 對 Fable 5.1 已注入官方四段（autonomy、Delivering work、Writing for the user、progress line），其中 Writing for the user 明文禁 arrow chains、要求平行項目用清單。CLAUDE.md 有 5 行是替舊模型寫的輸出格式約束，與 harness 對撞：數字上限（1f）、箭頭鏈格式（prompt 格式滲入輸出）、無 provenance 的禁用語尾巴（1e）。
3. **ponytail 4.9.0 SessionStart 注入的 Output 節是 1f 全套**（at most three short lines、explanation shorter than code、`[code] → skipped` pattern）。官方明寫 Fable 5.1 上這類 block「can suppress structure the content needs. Remove it」。09-05 D5 決議用 `/ponytail lite` A/B，但查 plugin `filterSkillBodyForMode` 只過濾 intensity 表，Output 節每個 level 都注入，lite 解不掉。落點選 CLAUDE.md：plugin 檔不可改、CLAUDE.md 在裁決鏈上高於通用慣例。
4. **明確不動**：驗證指令（[T0-2]、S4、evidence-integrity、Preflight ledger）。best practices「Ask Claude to self-check… Claude Opus 5 is the exception」；Fable 5.1 遷移指引「keep it when migrating」。09-05 sol-astra 那批依 GPT-6 指引精簡 Codex 的改動不能鏡像到 Claude。Delegation 現況正確（delegation.md 交 AI 自主判定、harness Agent 預設背景執行）；ultracode=false 的 09-05 方案 C 維持。
5. **S5 抓到審核漏洞**：A5 提案「刪 kernel 的 R-1／R-2 殼子」與 `CONVENTIONS.md` §3「規則 ID 永不回收、刪除時留殼標記」衝突，審核時 grep 漏掉 repo 根的 CONVENTIONS.md。兩軸同時抓到，改為搬移不刪除。

## 2. 審核 findings

| # | 位置 | pattern | 處置 | 信心 |
|---|---|---|---|---|
| A1 | CLAUDE.md:13「散文步驟給編號，上限 5 項」 | prompt-audit 1f 數字上限（官方例即 at most five bullets） | rewrite：「超出本回合要做的切現在做／之後做」 | Medium |
| A2 | CLAUDE.md:15、17 箭頭鏈 `做了什麼 → 現在什麼能用 → 用什麼指令驗`、`位置 → 原因 → 修法` | best practices「match your prompt style to the desired output」；harness 禁 arrow chains | rewrite：「依序寫…」 | Medium |
| A3 | CLAUDE.md:14、17「禁一些工作、不用太久」「禁糟糕、似乎有問題」 | best practices「tell what to do instead of what not to do」；1e 無 provenance banned-phrase list | remove 尾巴，正向規則保留 | Medium |
| A4a | CLAUDE.md:7 | ponytail Output 節 1f 全套；官方 Fable 5.1「remove anti-formatting」 | add：「ponytail Output 節的行數上限與箭頭 pattern 不約束 final message」 | Medium-High |
| A5 | dev-workflow/SKILL.md:30 `[R-1 DEPRECATED→INT-1 2026-07] [R-2 DEPRECATED→INT-2 2026-07]` | Group 2 history narrative；R-1／R-2 零 live 引用 | 原提案 remove；S5 後改為搬到 CONVENTIONS.md §3（見 §3） | Medium |
| A6 | host-adapters.md:18-20 兩段（Accepted divergence 2026-09-06、2026-09-07 核准調整「上述為歷史決定」） | 1d migration-relative phrasing；Codex cutover 已完成（`~/.codex/AGENTS.md:19`） | 合併為一段現在式，指向 CAP-PONYTAIL 表列，留座標（#120、#121） | Medium |

Low／flag，不動：CLAUDE.md:16「送出前刪」與 harness「stop when the content stops」重複但一致（keep-list 8）；reviewer-template.md:94、163 與 host-adapters.md:15、17、45 的事故敘事（author note，影響小）；官方 [TUNE]「A/B with prior-model scaffolding removed」在 Claude 側從未跑（09-05 §7 自陳），grep 零命中所以無候選，不為跑而跑。

順帶（settings）：modelSettings 把 Fable 5.1 釘 xhigh，09-05 決議與官方「capability-sensitive 才升 xhigh」一致，不重提；Fable 5.1 新增注意：xhigh 寫長文件會在 thinking 先打整份草稿再輸出一次，落檔類 session 用 `/effort high`。

## 3. 實作與 review

| PR | 內容 | merge SHA | S5 |
|---|---|---|---|
| dotclaude [#62](https://github.com/BriantsaiCoder/dotclaude/pull/62) | A1–A4a；CLAUDE.md 4720 → 4697 B（軟閘 4750） | `0bd6993` | 第 1 輪 Standards／Spec 各一：無 issue，Spec 1 nitpick（spec 檔「六條禁用片語」vs 守衛 10 條，spec 側）。simplify 4 角度：採「其」→「ponytail」；不採「不寫抽象摘要」刪除、:17 對齊 tier2。第 2 輪合併兩軸 PASS |
| agents-config [#125](https://github.com/BriantsaiCoder/agents-config/pull/125) | A5、A6 | `317538a` | 第 1 輪兩軸 FAIL：CONVENTIONS.md §3 衝突（同一 issue 兩軸同抓）；Standards suggestion 缺座標；Spec nitpick 措辭。修法：殼標記搬到 §3、斷言改指、加反向斷言「kernel 不得帶 DEPRECATED→」、§3 補落點句。simplify：段落改指表列、刪重述、CONVENTIONS 句縮短並收窄到已 guard 的 kernel、刪測試註解。第 2 輪 PASS，1 suggestion（主詞限定 shared kernel／references）採納 |
| dotclaude [#63](https://github.com/BriantsaiCoder/dotclaude/pull/63) | commit pre-existing `D skills/sdd`（目標已歸檔 attic） | `37af76e` | PASS；reviewer 確認 repo-integrity §5 shared-source 斷言在刪除前必紅 |
| dotclaude [#64](https://github.com/BriantsaiCoder/dotclaude/pull/64) | 刪 `commands/sdd.md`（sol-astra Group A 遷移 caller 漏掉的最後一個 `/sdd` 入口；三家皆已無 sdd 入口） | `06556c9` | PASS；question：執行者報「118 PASS」與 live 120 不符 → 重跑確認 120，118 是停沙箱時兩條依賴沙箱的檢查沒跑 |
| dotclaude [#65](https://github.com/BriantsaiCoder/dotclaude/pull/65) | README 結構樹去 `commands/`；Copilot 第 1 輪 1 inline finding → 補一行「目前不存在、`.gitignore` 仍保留 `!commands/`」；第 2 輪 1 suppressed 措辭 nit → 附理由 pushback | `5dc7031` | PASS |
| dotclaude [#66](https://github.com/BriantsaiCoder/dotclaude/pull/66) | follow-up：tier2 [T2-7]、[T2-9] 退役成殼 `[… DEPRECATED→CLAUDE.md#Defaults 2026-09]`（正本 CLAUDE.md，tier1／2 無 host 載入）；repo-integrity 新增「注入檔（CLAUDE.md、tier0）不帶 DEPRECATED→」斷言，rc≥2 走 FAIL | `2e89301` | PASS；3 nitpick 採 2（殼目標去空白、變數改名），[T2-7] 語意部分承接屬既存 drift 不動 |
| agents-config [#126](https://github.com/BriantsaiCoder/agents-config/pull/126) | follow-up：CONVENTIONS §12 重疊規則限定為常駐 tier0，補例外「[T2-6] 由 ownership 測試釘住不退役」；host-adapters「meaning 欄不參與語意斷言」上移到 consumer 段 | `cbc892b` | 第 1 輪 Standards FAIL（§12「例外：無」與 ownership 測試釘 [T2-6] 相衝）→ 補例外後 PASS |

Copilot review 七個 PR 皆「Approval recommended」（#65 第 1 輪 Changes recommended）。請求方式：`pr-review-gate` 的 REST 仍是 no-op，全部改走 GraphQL `requestReviews(botIds:)`。

**撤回一項**：agents-config `tests/matt-thin-workflow.sh:901` allowlist 的 `skills/sdd/SKILL.md` 被 reviewer 判為死 pattern，實測拿掉即紅：該測試用 `git diff --name-only $WORKFLOW_BASE -- skills` 列變動檔，被刪除的檔也在清單裡。worktree 與 local branch 清掉，未 push。

## 4. 驗證

- dotclaude：每個 PR `bash tests/repo-integrity.sh` 沙箱內 120 PASS／0 FAIL；三支 parity 測試（`ponytail-host-parity` 14/0/0、`three-host-capability-parity` 3/0/0、`tier0-parity`）對改後 live CLAUDE.md 全綠；禁用片語清單零命中；`git diff --check` 0；gitleaks staged／pre-commit no leaks。
- agents-config：`bin/ci-local` 27 PASS／0 FAIL、local-only 4 PASS；`conformance.sh` 73/0（含 CONVENTIONS「13 條」標題數）；新增兩條斷言在 scratch 複本做 mutation：kernel 追加 `[R-9 DEPRECATED→INT-9 2026-09]` → 紅、CONVENTIONS.md 移除殼標記行 → 紅、positive 綠。
- follow-up PR：dotclaude repo-integrity 121 PASS／0 FAIL，新斷言 3 個 control（clean 綠、CLAUDE.md 注入殼標記紅、tier0 chmod 000 → rc=2 紅）；ownership 測試 [T2-6] PASS；agents-config ci-local 27 PASS、conformance 73/0、ponytail-parity 14/0/0。
- 全部 PR：current-head CI PASS、`pr-review-gate` STATE=PASS、unresolved 0、suppressed 逐條處置。

## 5. 決策紀錄

| 決策 | 內容 |
|---|---|
| A1–A6 全部依建議實作 | 使用者核准 |
| A4 三選一 | a. CLAUDE.md scoping 句（採）；b. 關 SessionStart 注入；c. 不動 |
| A5 §3 處置 | 搬移而非刪除，§3 補一句落點；替代 revert A5 或改寫 §3。使用者 merge #125 即核准 |
| #62、#125 merge | 使用者逐次確認（全域 config） |
| `D skills/sdd`、`commands/sdd.md`、README 行 | 使用者逐項核准；`commands/sdd.md` 刪而非改指 attic（改指會讓 Claude 單獨保有退役流程） |
| Follow-up 三項 | 使用者核准兩個 PR（#66、#126）：正本是被載入的 CLAUDE.md，tier2 [T2-7]／[T2-9] 退役成殼；§12 限定 tier0；meaning 欄說明上移。tier 檔反向 guard 依 YAGNI 改為守「注入檔不帶殼標記」，落在 dotclaude repo-integrity |

## 6. 未做與 follow-up

- [T2-7] 的語意只部分落在 CLAUDE.md:17（evidence 由 [T0-1]／[T0-2] 承接、next step 由 :13 承接，「原因未明時列下一診斷動作」在單步任務無明文）；既存 drift，CLAUDE.md 距軟閘 53 B，不補字。
- 官方 [TUNE] A/B 與 Step 7 行為探針未跑；本次全部改動的效果由 reviewer 語意核對與機械守衛承擔，不是量測。
- `.gitignore` 的 `!commands/` allowlist 保留（dormant）；`~/.claude/commands` 目錄現不存在。

## 7. 教訓

- **審核刪除項前先查 `CONVENTIONS.md`**：§3 留殼、§9 座標、§12 CLAUDE.md 不與 tier 重疊。已寫入 session memory `prompt-audit-check-conventions-shell-policy`。
- **「死 pattern」要用測試的枚舉方式驗**，不是看路徑存不存在；diff-based 清單含刪除檔。
- **dotclaude 的 `gh pr merge --delete-branch` 要停沙箱跑**：沙箱內 fetch 撞 cert.pem，留下 main 停舊 commit、改動變成未提交修改的半套狀態；#62 用 `git reset --mixed origin/main` 補救（先驗證 working tree 與 origin/main 逐 byte 相同）。
- 沙箱內外 `repo-integrity.sh` 的 PASS 數差 2（停沙箱時兩條依賴沙箱的檢查不跑），報數字前先確認執行環境。

## 8. 第二輪 delta（2026-09-07 21:47 起，另一 session 重跑同句請求）

範圍補上一輪未列的三個面：`~/.claude/templates/`、`~/.claude/agents/`、host-adapters Claude 節；skill 層以阿拉伯數字、拼字數字（`at most (one|…|ten) (lines|words|…)`）、中文量詞三組 pattern 重掃。**更正 §1 第 1 點**：「numeric cap grep 全 0」只跑了阿拉伯數字那組——`handoff/SKILL.md:18` 的「at most four lines」是本地 fork `332acdb`（2026-07-31）加的數字上限，拼字數字漏掃。

| # | 位置 | pattern | 處置 | PR |
|---|---|---|---|---|
| D1 | `~/.claude/templates/compact.md` | keep-list #11 re-baseline：對齊 Fable 5.1 遷移指引的 compaction summarization prompt 六類保留項與兩種聲音權重 | rewrite：補 問題／未採用方案／使用者原句 三欄與「只輸出文字不呼叫工具」「使用者原句與識別項逐字、其他貼近原文、推理只留結論」 | dotclaude [#67](https://github.com/BriantsaiCoder/dotclaude/pull/67)（`1f5e5f7`） |
| D2 | `~/.claude/agents/uiux-reviewer.md` 前置檢查 | Group 4 harness drift：2.1.260 的 MCP tools deferred，原文「工具不存在即停止」把 deferred 誤判成未安裝 | rewrite 三步：deferred 先依 server instruction 載入 core set、無條件呼叫 `tabs_context_mcp`、失敗才標 `UNAVAILABLE`（probe）並結束；刪硬寫 tool id（Group 3） | dotclaude #67 |
| D3 | `skills/handoff/SKILL.md:18` | 1f 數字上限 | remove；`vendored-forks.md` index row 與 `## handoff` 決策節同步，加 Extension (2026-09-07) 段 | agents-config [#128](https://github.com/BriantsaiCoder/agents-config/pull/128)（`7b4ca00`） |
| D4 | `dev-workflow/references/delegation.md:7` | Fable 5.1「give the reason, not just the request」；Codex adapter #124 已有，Claude／Copilot 缺 | add host-neutral 一段（目標與用途、working directory／可修改範圍、已決事項與限制、必要文件、驗收方式；背景先摘要），為 Codex 版超集 | agents-config #128 |

Flag 不動：ponytail 注入「leaves ONE runnable check」與 Fable 5.1 test-sprawl 指引相反（CLAUDE.md:7 只擋覆寫 [INT-2]）；`tier1-workflow.md` 無 host 載入、語意已由 harness Delivering work 與 ledgers row 1／3 承接；uiux-reviewer 只認 claude-in-chrome（desktop Browser pane 等效能力）；`improve-codebase-architecture/HTML-REPORT.md:52`「≤6 words」屬上游卡片格式釘；`agents/code-reviewer.md:11`「Run git diff」與 reviewer-template 精確 source state 實務不衝突。

S5：兩 repo 各兩輪兩軸，reviewer 審 detached-worktree snapshot。第一輪兩 repo 皆抓到同類缺口——agents-config 兩軸同抓 `vendored-forks.md` 底部 `## handoff` 決策節仍把四行上限列為 must-survive（執行者只改了 index row）；dotclaude 抓 select 清單與 harness core set 不一致、compact 保真度句兩處。simplify 四角度 apply pass 各 `changed` 一顆 commit（刪硬寫 tool id、清單成超集、紀錄去重）。第二輪抓到 simplify 誤加的 proposals 座標（本檔 §2 無 handoff 決策）。Copilot：#67 一條「ToolSearch 未在 repo 定義」有據駁回（harness 內建工具名）；#128「Approval recommended」，0 thread；兩 PR `pr-review-gate` 皆 `STATE=PASS suppressed=0`。

Follow-up：`host-adapters.md:54-55` Codex 委派條文收斂為 Codex-only delta 並改指 delegation.md（同批改 `tests/mattpocock-workflow.sh:533` regex）；`~/.claude/README.md:13` 仍標 compact.md 為 cross-session handoff 模板；deferred≠absent 的 probe 規則可上移 dev-workflow Gate contract（`playwright-best-practices/references/mcp-workflow.md` 同型曝險）；compact.md 的 問題／使用者原句 兩欄與 Claude Code 內建 compact summarizer 重疊，可改走 `/compact <instructions>`；uiux-reviewer 是否接受 `mcp__Claude_Browser__*` 等效 provider。

教訓：收到同句稽核請求先查 proposals 當日正本，只做 delta（session memory `audit-rerun-check-proposals-first`）；引用 proposals 座標前 grep 該節真含此決策；VND\* fork 的紀錄有 index row 與決策節兩處。
