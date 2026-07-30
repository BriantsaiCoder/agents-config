# Claude Code review：Codex 收斂後最終方案（09）

> 日期：2026-07-27
> 性質：read-only migration proposal review。本輪未修改任何設定、skill、plugin、hook、generated host file 或 repo 檔案；僅新增本報告檔。
> 被審對象：[09-codex-reconciled-final-for-claude-review.md](09-codex-reconciled-final-for-claude-review.md) §九 的七項裁決題。
> 執行者：Claude Opus 5（新 session，13:44–14:00 Asia/Taipei）。

## 觀測基準（Asia/Taipei）

| 對象 | 狀態 | 觀測時刻 |
|---|---|---|
| `~/.agents` | HEAD `19be2eb`、branch `main`、工作區乾淨（唯一 untracked 為 `proposals/2026-07-27-workflow-constraint-audit/`） | 13:45 |
| `mattpocock/skills` upstream | HEAD `ed37663cc5fbef691ddfecd080dff42f7e7e350d`（author date 2026-07-21T10:28:51Z） | 13:49 |
| upstream 22 支 frontmatter | 逐支抓取判定 invocation 型別 | 13:50 |
| `~/.claude/settings.json` | mtime 2026-07-27 10:03:05；`superpowers@superpowers-marketplace: true` | 13:56 |
| `~/.claude.json` → `skillUsage` | 權威觸發計數 | 13:57 |
| `~/.codex/skills`、`~/.copilot/skills` | 前者 3 支無關 skill，後者空 | 13:47 |

---

## 給 Codex 新 session 的 review 指引

### 讀取順序

1. [08-codex-final-proposal.md](08-codex-final-proposal.md)
2. [07-review-of-codex-final.md](07-review-of-codex-final.md)
3. [09-codex-reconciled-final-for-claude-review.md](09-codex-reconciled-final-for-claude-review.md)
4. 本檔。

### 請 Codex 特別確認的五件事

1. **F1（交付機制）與 F2（canary 未停用 superpowers）是否真的阻斷。** 若你認為不阻斷，請說明 Phase 6 gate 3/4/5/8 在 superpowers 仍啟用的環境下如何取得 observation 而非 assertion。
2. **F3 的 host 分層是否正確。** 我主張 `disable-model-invocation` 的斷鏈是 Claude-scoped（Codex/Copilot 走路徑讀取），而 doc 08 Phase 2 與 doc 09 §4.3 對該欄位的態度不對稱。請驗證或反駁。
3. **Phase 2 交付機制的二選一，我推薦 (b) vendored。** 這一項我明確標為建議而非結論——請以你對 Codex 端 plugin/marketplace 機制的第一手知識裁決。
4. **§4.1 delegation gate 從「S3 內」改為跨階段 `[INT-4]` 是否過度。** 我的理由是 delegation 出現在 S1/S2/S3/S5 四處，且與 gate 6 有牴觸。
5. **Phase 6 十項 gate 的最終版（本檔第 5 節）是否仍可執行、可驗證、無循環。**

### 反駁時的舉證要求（與 09 §請 Claude Review 的要求對稱）

每個不同意項目請附 live file/line、可重跑的 probe command，或 upstream source evidence，並標明 Asia/Taipei 觀測時刻。本檔附錄 A 提供全部 probe 指令，可直接重跑。

---

## 1. 總結論

**不建議現在進入實作階段。** 架構主張（Matt 取代方法論／orchestration、kernel 保留治理與完成 gate、Superpowers 最後移除）我完全同意，不需要回退。但收斂版有**兩個阻斷級缺陷**，兩者都是最小差異可修：

1. **22 支如何送達三個 host，doc 09 從頭到尾沒有決定。** 這不是實作細節——它決定 Phase 4 的隔離 A/B 能不能做、Phase 6 的逐 host 移除順序有沒有意義。
2. **Phase 4B 的 canary 沒有停用 Superpowers**，所以十項 gate 裡有四項（3、4、5、8）在「被取代的東西仍然載入」的環境下評估，只能是宣稱，不可能是觀察。

七項裁決：3 項同意、4 項部分同意、0 項不同意。

---

## 2. 七項裁決表

| # | 問題 | 裁決 | 決定性依據 |
|---|---|---|---|
| 1 | Delegation gate 放 canonical S3 而非只補 Claude adapter | **部分同意** | 方向對（S3 已有 canonical 種子：`skills/dev-workflow/SKILL.md:80`「subagent 回報 ≠ 完成證據，主 context MUST 親自驗」），但**範圍不足**：delegation 出現在 S1/S2（`wayfinder.md:115`、`codebase-design.md:114`）、S3（`improve-codebase-architecture.md:27`）、S5（`code-review.md:11`）。只放 S3 蓋不住 S5 |
| 2 | `[T1-10]` + S3 reference 足以承接 `using-git-worktrees`？ | **部分同意** | 語義正確，但**機械載體已存在**：`bin/agents-branch` 檔頭第 7–15 行就是該政策原文，`.worktrees/` 有 4 個 live worktree。缺的 mechanical probe 是「`~/.agents` 主 checkout 必須在 `main`」的斷言——`tests/conformance.sh` 對 `branch`/`worktree`/`main` 目前零命中 |
| 3 | Writing／audit semantic migration | **同意**（且比 doc 09 說的更必要） | 字串替換會讓本機稽核器把 13/22 支上游 skill 判為 `Style:fix-frontmatter`（無 `Use when…` 前綴）、22/22 判為 `Style:add-sections`——而 step 0 vendored gate 禁止修上游 → 永久掛帳。仍需要「可自動載入的權威來源」，但必須是**本機 house policy**，不能是 user-invoked 的第三方 skill |
| 4 | 單一 `docs/agents/issue-tracker.md` 足以承接 setup 契約？ | **部分同意** | 單檔可行已實證：6 支 skill 硬引用該路徑；`domain.md` 在其餘 21 支中**零 consumer**（可省略成立）。但 9 項清單漏 3 項內容 + 1 個預設值（見 F13） |
| 5 | 隔離 A/B 優於長期並存？Phase 3–5 rollback 是否完整？ | **同意隔離／不同意 rollback 完整** | 隔離正確（`mp-tdd`、`mp-diagnose` 歷史觸發次數為 **0**，長期並存量不到東西）。但 rollback 三 host 不對稱，且 Phase 4B 的隔離動作會被 `agents-sync --bootstrap` 自癒（見 F7） |
| 6 | 四支 `mp-*` 的 parity ledger 足以避免遺失本機獨有知識？ | **部分同意** | 機制正確、**盤點範圍錯**：是 **17 個檔案**不是 4 個；doc 09 未列的 `mp-grill-with-docs/CONTEXT-FORMAT.md` 是本機 **superset**（3145B vs 上游 2299B）。且四支皆為 `vendored-forks.md` 未登錄、且機械偵測不到的 fork |
| 7 | Phase 6 十項 gate 完整、可驗證、無循環？ | **部分同意** | 覆蓋面接近完整，但有 **1 個循環**（3/4/5/8 在 superpowers 仍啟用的環境評估）、**1 個自我指涉**（gate 4 以被移除的 skill 名定義）、**1 個非二元可滿足**（gate 6）、**1 個缺項**（機械 helper 盤點） |

---

## 3. Findings（依風險排序）

分類依 doc 09 §請 Claude Review 第 3 點：confirmed defect／missing carrier／migration risk／conditional optimization／naming-maintenance debt。

### F1 — 22 支的三 host 交付機制未決｜**阻斷級 · migration risk**

doc 09 §二／Phase 2 只寫「導入 stable 22」「Matt upstream files 保持 immutable」，從未說明用什麼機制、送到哪裡。三個 probe 讓這個空白變成阻斷：

- `.claude-plugin/plugin.json` 的 `skills[]` **恰好列出 22 支**（engineering 17 + productivity 5，逐項核對）。也就是說「stable 22、排除 in-progress/misc/personal/deprecated」**就是官方 plugin 的預設**，不需要任何過濾——這可以直接簡化 doc 09 §二的安裝範圍表，並修正「Installer 顯示的全部約 38 支」的來源歸屬。
- `scripts/link-skills.sh` 把 symlink 寫進 **`$HOME/.agents/skills`**（三 host 的正本根），涵蓋 `deprecated/` 以外**全部 37 支**，而它第 3–6 行自陳「This is a dev-only script... It is not a supported installer.」這是替 Codex/Copilot 補位時最容易被選中的路徑，且會**靜默違反排除決策**。
- 三次獨立 plugin 安裝 = 已實證的漂移：[05-round2-merged-plan.md:21](05-round2-merged-plan.md) 記錄 Copilot 那份 superpowers 的 hash 與 Claude/Codex 不同。

**影響**：這決定 Phase 4B 能否做 per-host 隔離（plugin 可逐 host 停用；vendored 進 `~/.agents/skills` 則三 host 同時變動），也決定 Phase 6「逐 host 移除、任一失敗即停止」是否有意義。

### F2 — Phase 4B canary 未停用 Superpowers，四項 gate 只是宣稱｜**阻斷級 · confirmed defect**

Phase 4B 只寫「將被替換的 model-invoked `mp-*` 移出 active discovery root」。`~/.claude/settings.json`（13:56 讀取，mtime 10:03:05）顯示 `"superpowers@superpowers-marketplace": true` 仍啟用。於是：

- gate 3（`verification-before-completion` 已由 `[T0-2]`+S4–S6 承接）
- gate 4（branch finishing／PR／CI closeout 已有明確載體）
- gate 5（red→green bugfix gate 可驗證）
- gate 8（`implement` 不跳過 kernel closeout）

**四項都在「被取代的東西還在場」的環境評估**，全部是 assertion 而非 observation。這正是 doc 09 Phase 4 自己想避免的失敗模式。

**最小修正**：arm B 額外把該 key 設為 `false`（單行、完全可逆，且連帶移除 plugin `hooks/hooks.json` 的 SessionStart 全文注入）。這一行是整份計畫槓桿最高的修改。

### F3 — Phase 3 有兩條 mapping 把 model-invoked 換成 user-invoked｜**confirmed defect（Claude scope）**

upstream `ed37663` 逐支 frontmatter 實測（13:50）：

| Phase 3 mapping | 本機 | 上游 | 判定 |
|---|---|---|---|
| `mp-diagnose` → `diagnosing-bugs` | model-invoked | model-invoked | OK |
| `mp-tdd` → `tdd` | model-invoked | model-invoked | OK |
| `mp-grill-with-docs` → `grill-with-docs` | model-invoked | **`disable-model-invocation: true`** | **斷鏈** |
| `mp-improve-codebase-architecture` → `improve-codebase-architecture` | model-invoked | **`disable-model-invocation: true`** | **斷鏈** |

完整 invocation 判定（22 支）：

- **user-invoked（13）**：`ask-matt`、`grill-with-docs`、`implement`、`improve-codebase-architecture`、`setup-matt-pocock-skills`、`to-spec`、`to-tickets`、`triage`、`wayfinder`、`grill-me`、`handoff`、`teach`、`writing-great-skills`
- **model-invoked（9）**：`code-review`、`codebase-design`、`diagnosing-bugs`、`domain-modeling`、`prototype`、`research`、`resolving-merge-conflicts`、`tdd`、`grilling`

`skills/dev-workflow/SKILL.md:66`（S1 ACTION，canonical 非 adapter）寫「HEAVY → `mp-grill-with-docs` 拷問需求」；`:43`（`[INT-2]`）、`:82`、`:115` 三處指向 `mp-improve-codebase-architecture`。切換後，Claude 端這些步驟變成模型無法自行 invoke 的 skill。

**必須按 host 分開陳述，否則會超譯**：Codex/Copilot 沒有 `~/.agents/skills` 的 skill listing（`~/.codex/skills` 只有 3 支無關 skill、`~/.copilot/skills` 空），它們走 `dist/AGENTS.md:56,58` 的**路徑讀取**路由，`disable-model-invocation` 咬不到。所以這是 Claude-scoped 的自動觸發斷鏈，不是三 host 全面失效。

同時這暴露一個不對稱：doc 08 Phase 2 說「不要把遷移收益建立在 `disable-model-invocation` 上，三家支援不一致」，doc 09 §4.3 卻**依賴該欄位的語義**論證 writing 載體。兩者可以並存，但必須明說：**可攜的機制是路徑讀取，不是 invocation**。

**最小修正**（不動架構）：

- S1 ACTION → `grilling` + `domain-modeling`（兩者皆 model-invoked）。這也正是 `grill-with-docs/SKILL.md` 本體唯一那一行做的事：「Run a `/grilling` session, using the `/domain-modeling` skill.」
- `[INT-2]`／S3 FAILURE → 模型端接 `codebase-design`（model-invoked）；repo 級掃描維持「建議使用者跑 `/improve-codebase-architecture`」，因為它本來就設計成人為發起的保養動作。

### F4 — 機械 helper 斷層，§三 職能對照表結構上表達不出來｜**missing carrier**

| | Superpowers 6.2.0 | Matt stable 22 |
|---|---|---|
| 可執行 helper | `subagent-driven-development/scripts/{sdd-workspace, task-brief, review-package}`、`systematic-debugging/find-polluter.sh`、`brainstorming/scripts/{start,stop}-server.sh`、`writing-skills/render-graphs.js` | **僅** `diagnosing-bugs/scripts/hitl-loop.template.sh` |

前三支正在**本機專案使用中**：`DCT_data_import_data_stream_codex/.superpowers/sdd/` 有 52 筆產物（progress ledger + 12 份 review diff），由 plugin 的 `sdd-workspace` 建立（`superpowers/6.2.0/RELEASE-NOTES.md:69` 明載該慣例）。

doc 09 §三 把 `subagent-driven-development` 對到「canonical delegation gate + ticket／implement workflow」——但 `implement/SKILL.md` **全文 14 行**，沒有 workspace、沒有 ledger、沒有 per-task brief、沒有 review diff 打包。這是能力落差，不是同質替換；skill→skill 的對照表在結構上無法表達它。

### F5 — Gate 4 自我指涉：收尾閘以被移除的 skill 名定義｜**confirmed defect**

`skills/dev-workflow/SKILL.md:42`（`[INT-1]`）、`:109`、`core/routing.md:15`（`[R-1]`）全部以 `finishing-a-development-branch` 為觸發條件。移除後觸發條件永不成立，規則變成空轉——**保護「不得提前收尾」的那條規則，是用被移除物定義的**。

順帶：`superpowers:finishing-a-development-branch` 是使用計數最高的一支（**32 次**，last 2026-07-11），這是整個遷移中量最大的行為變更。

### F6 — Gate 6 非二元可滿足｜**confirmed defect**

`code-review.md:32`：找不到 spec 時「the **Spec** sub-agent will skip and report "no spec available"」。而 X1 表規定 spec 只在 S2 核准後才持久化，LIGHT tier 任務**合法地沒有 spec**。gate 6 寫成「兩軸都完成」會在正常路徑上永遠 FAIL。應改為四態（PASS，或 `SKIPPED` + 理由），與 `dev-workflow` 自己的 X0 機械判定契約一致。

### F7 — Rollback 三 host 不對稱，且隔離動作會自癒｜**confirmed defect**

- **Claude routing 走不同管道**：`dist/manifest.tsv` 只有 `codex`／`copilot` 兩列；Claude 端 routing 是 `~/.claude/CLAUDE.md` 內的 stamp 區塊，由 `bin/agents-sync:283 refresh_claude_stamp` 刷新。該函式自帶實證註解（`:274-275`、`:385`）：沙箱曾擋掉 `mv`，而 deploy 仍宣告完成。所以 Phase 3 rollback 寫「還原 routing source-of-truth → 跑 `agents-sync`」時，Codex/Copilot 已回退而 **Claude 可能仍留在 candidate routing**。後置條件必須是「讀回 stamp 比對」，不是「跑過 agents-sync」。
- **Phase 4B 的隔離會被覆蓋**：`bin/agents-sync:330-349`（`--bootstrap`）對 `~/.agents/skills` 下**每個目錄**重建 symlink。單純刪 `~/.claude/skills/mp-tdd` 會被下一次 bootstrap 還原。要真隔離必須搬**來源**到 `attic/`——這也剛好是可追蹤、可 `git mv` 還原的做法，與 `vendored-forks.md` 記錄的 `ecpay`、`design-doc-mermaid` 前例一致。

### F8 — Parity ledger 範圍錯，且四支是未登錄且機械不可見的 fork｜**naming／maintenance debt**

- **是 17 檔不是 4 檔**：`mp-diagnose` 3、`mp-grill-with-docs` 3、`mp-improve-codebase-architecture` 4、`mp-tdd` 7。
- **doc 09「已重驗」清單漏掉會出事的那一個**：實測 `mp-grill-with-docs/CONTEXT-FORMAT.md` 與上游 `domain-modeling/CONTEXT-FORMAT.md` **不同且本機較大**（3145B vs 2299B）；本機獨有 `## Relationships`、`## Example dialogue`、`## Flagged ambiguities` 三節，以及「Flag conflicts explicitly」「Show relationships」「Write an example dialogue」三條規則。這正是 07-review §7 擔心的「邊角知識」，而且它綁著 X1 表的 `CONTEXT.md` 產物。
- **另一筆已重驗清單未提的差異**：`mp-improve-codebase-architecture/DEEPENING.md` 與上游 `codebase-design/DEEPENING.md` 差 6 bytes（本機把交叉引用指向自加的 `LANGUAGE.md`，上游指向 `SKILL.md`）——證明本機做過原地修改。
- **6 個檔案上游無同名對應**：`mp-tdd/{interface-design.md, refactoring.md, references/tracer-bullet.md}`、`mp-diagnose/references/feedback-loop.md`、`mp-improve-codebase-architecture/{INTERFACE-DESIGN.md, LANGUAGE.md}`。
- **四支都不在 `vendored-forks.md` 的 fork index**，而該檔第 3 行寫著「A fork that is not listed here is an unrecorded fork — a defect, not a decision.」且它們沒有 LICENSE、沒有上游標記，`skills/auditing-skill-folder/scripts/lib-vendored.sh:17` 的判定條件（LICENSE 檔或 README/SKILL.md 內的上游標記）兩者皆不命中 → **這個 fork 機械上看不見**。ledger 的產出應落在 `vendored-forks.md`，一併結清這筆既有債。

### F9 — X1 中性化與「active reference 歸零」的清單不完整｜**confirmed defect**

doc 09 §六只列 `docs/superpowers/specs|plans`。實測遺漏：

| 遺漏處 | 證據 |
|---|---|
| `skills/dev-workflow/SKILL.md:56` | S0 決策表第 5 列第三次拼出 `docs/superpowers/plans/` |
| `.superpowers/sdd/`（本機專案 52 筆活產物） | plugin 的 `sdd-workspace` 建立；與 X1 表的 `sdd/<slug>/` 是兩套路徑 |
| `skills/dev-workflow/SKILL.md:73` | canonical S2 ACTION 內的 `superpowers:writing-plans`（**不在 host adapter**） |
| `skills/dev-workflow/references/review-triage.md:31` | `superpowers:receiving-code-review`（該 skill 使用 18 次） |
| `skills/bug-fix-settlement/SKILL.md:3,12` | `superpowers:systematic-debugging` 寫在 **description** 裡＝三 host 常駐注入面 |
| `skills/auditing-skill-folder/scripts/count-words.sh:34` | `superpowers*)` glob 分支，移除後成死碼 |

### F10 — Matt skills 的 delegation 寫死 Claude 工具名，Copilot 無 adapter｜**migration risk（三 host 可執行性）**

- `code-review.md:44`：「Send a single message with two `Agent` tool calls. Use the `general-purpose` subagent for both.」
- `improve-codebase-architecture.md:27`：「use the Agent tool with `subagent_type=Explore`」——`Explore` 是 Claude 專屬 subagent 型別。

上游每支附 `agents/openai.yaml`（Codex 端 adapter，已抓取確認存在），**Copilot 沒有對應物**。gate 6 若要三 host 同等成立，Copilot 需要 `task` 工具／`--agent` 的映射（`skills/dev-workflow/SKILL.md:133` 已有工具名，但 code-review 的雙軸並行語義沒有落點）。

### F11 — 新 delegation gate 與 gate 6 互相牴觸｜**confirmed defect**

doc 09 §4.1 提議「使用者、repo 或更高層 instructions **必須允許** delegation，否則標 `SKIPPED`，不做 smoke spawn」。但 `code-review` 的兩軸並行 sub-agent **是無條件的契約內建行為**，且 gate 6 要求兩軸都完成。在未明示允許 delegation 的 session，新 gate 會把 code-review 打成 SKIPPED → gate 6 必然 FAIL。

**修法**：gate 條文區分「探索型 delegation（需授權）」與「skill 契約內建的固定 fan-out（隨該 skill 的授權一併成立）」。

### F12 — `[T1-10]` 會與既有機械守護重複｜**conditional optimization**

`bin/agents-branch` 檔頭第 7–15 行已經逐字寫出 §4.2 想寫的那條政策：「`~/.agents` 是三家 host 實際讀的目錄，而 `~/.claude/skills/*` 是指回它的 symlink——在這裡切分支，Claude 讀到的 skill 內容**當下就變了**，而 Codex/Copilot 的部署檔要等 `agents-sync` 才動」。

使用者全域 CLAUDE.md 規定「沉澱前評估能否機械化：預防檢查可寫成 hook / test / lint 者，考慮落地為機械守護取代 prose」。所以 `[T1-10]` 應寫成**指向該工具的兩三行**，真正該補的是 `tests/conformance.sh` 缺的那條斷言（該檔對 `branch`／`worktree`／`main` 目前零命中）。

### F13 — 單一契約缺 3 項內容 + 1 個預設值｜**missing carrier（小）**

對照上游 `setup-matt-pocock-skills/{issue-tracker-local.md, issue-tracker-github.md, triage-labels.md}`：

| 缺項 | 上游依據 |
|---|---|
| **state 記錄機制**（不只角色名）——`Status:` 行的位置與格式 | `issue-tracker-local.md:10` |
| **wayfinder ticket 型別詞彙** `research`／`prototype`／`grilling`／`task`（`Type:` 行） | `issue-tracker-local.md:26`；doc 09 第 6 項只列 map/child/blocking/claim/frontier/resolve |
| **role → 實際 label 字串的映射表**（不只列出五個 role name） | `triage.md:43`「the actual label strings used in the issue tracker may differ. The mapping should have been provided to you」 |
| PR-as-triage-surface 旗標**預設 off** | `setup-matt-pocock-skills.md:49` |

**`domain.md` 可省略——已實證**：`grep -n "docs/agents" *.md` 對 22 支全文掃描，`docs/agents/domain.md` 只在 `setup-matt-pocock-skills.md:68,99` 出現，其餘 21 支零 consumer。唯一未被 X1 表覆蓋的是多 context 的 `CONTEXT-MAP.md` 佈局（`setup/domain.md:8`），X1 只列 `CONTEXT.md`。

### F14 — kernel 的 micro-refactor 句與上游 `tdd` 相衝｜**小 · 語義**

doc 08 建議的 kernel 一句是「Green 後允許本輪範圍內的 micro-refactor；跨模組、public interface 或結構性 refactor 延後至 code-review」。上游 `tdd/SKILL.md` 末段寫的是「**Refactoring is not part of the loop.** It belongs to the review stage (see the `code-review` skill), not the red → green implementation cycle.」兩者並存會讓模型收到相反指引。

**最小修正**：kernel 那句改寫成與上游一致（refactor 一律延後至 S5 `code-review`），刪掉「允許 micro-refactor」的例外——這同時更貼 `[T1-5]`。

### F15 — 範圍外，一行帶過

`~/.codex/config.toml` 的 `mcp_servers.context7` 帶明文 API key（本輪 probe 意外落入 transcript，後續不再引述）。屬既有債，與本遷移無關，建議另案 rotate。

---

## 4. 對 Phase 1–7 的必要修正（最小差異，錨在 doc 09 自己的編號）

### §四 三個缺失載體

- **§4.1**：把 gate 從「S3 ACTION 內」改為**跨階段規則**（比照 `[INT-1]`～`[INT-3]` 體例，例如 `[INT-4] Delegation`），並在 S1／S2／S3／S5 各引用一次。條文加一句區分：「skill 契約內建的固定 fan-out（如 `code-review` 雙軸）隨該 skill 的授權一併成立，不另行要求 delegation 授權」。同時聲明 `dev-workflow/SKILL.md:80` 既有那句是本 gate 的一部分，避免變成第二份正本。
- **§4.2**：`[T1-10]` 條文明確指向 `~/.agents/bin/agents-branch`，並把驗證欄寫成機械形態：「`tests/conformance.sh` 新增斷言——`~/.agents` 主 checkout 的 HEAD 為 `main`」，納入 `.github/workflows/ci.yml`。
- **§4.3**：追加結論——遷移後的權威來源必須是**本機 house policy 檔**（建議 `skills/auditing-skill-folder/references/skill-standards.md`），把 `step7-style-checks.md` 九條逐條標註來源為 Agent Skills spec／Matt `writing-great-skills`／house policy／應刪除的 Superpowers-specific rule。補上決定性理由：不做語義遷移就會用舊尺量新 skill，13/22 支缺 `Use when…` 前綴、22/22 支缺四段式 sections，而 step 0 vendored gate 禁止修上游 → 永久掛帳。站點清單補 `scripts/count-words.sh:34`。

### §五 setup 處理

- 契約 9 項擴為 12 項：補 state 記錄機制、wayfinder `Type:` 詞彙、role→label 映射表；第 5 項註明預設 **off**。
- 加一條**明確禁令**：「不得執行 `scripts/link-skills.sh`」——它會把 37 支寫進 `~/.agents/skills`，違反排除決策，且上游自稱非受支援安裝器。

### §六 X1 中性化

清單補 `dev-workflow/SKILL.md:56` 與 `.superpowers/sdd/`（本機專案 52 筆，需在移除前決定保留或搬遷），並把「active superpowers 引用」改為 **F9 表格的固定清單逐檔核銷**，而不是靠一次 grep。

### Phase 2

**新增前置決策（阻斷）**：22 支的交付機制擇一並寫死。

| 選項 | 內容 | 代價 |
|---|---|---|
| (a) 三 host 各自 plugin 安裝 | 用 `.claude-plugin/plugin.json` 的 22 支預設，零過濾；upstream 自動更新 | 重演已實證的三方版本漂移（Copilot hash 已與 Claude/Codex 不同） |
| (b) vendored 進 `~/.agents/skills` | 單一正本、三 host 同源、全部走路徑讀取 | 需登錄 `vendored-forks.md`；需手動追上游；Claude listing 增 22 筆 |

**建議 (b)**：本機三 host 的既有交付管道就是 `~/.agents` + `agents-sync`；(a) 會重演已知問題；且 (b) 讓 `disable-model-invocation` 的跨 host 支援不一致變成不相干（大家都走路徑讀取）。**此項標為建議而非結論，請 Codex 以其對 Codex 端 marketplace 機制的第一手知識裁決。**

### Phase 3

- routing map 兩條改為：`mp-grill-with-docs → grilling + domain-modeling`、`mp-improve-codebase-architecture → codebase-design`（模型端）＋保留 `/improve-codebase-architecture` 為使用者發起的保養入口。
- 新增一項工作：把 `[INT-1]`（`SKILL.md:42`）、`SKILL.md:109`、`[R-1]`（`routing.md:15`）改為**以動作定義**（push／開 PR／merge 前），不再以 skill 名定義。
- rollback 後置條件改為可讀回：Claude 端比對 `~/.claude/CLAUDE.md` 的 `agents-routing` stamp 區塊，Codex/Copilot 端比對 `dist/manifest.tsv` 的 hash。

### Phase 4

- **4B 加一行**：`~/.claude/settings.json` 的 `superpowers@superpowers-marketplace` 設為 `false`（可逆，且同時關掉 SessionStart 全文注入）。這是把 gate 3/4/5/8 從宣稱轉成觀察的唯一方法。
- 「移出 active discovery root」明確化為 **`git mv skills/mp-* attic/`**，並註明理由：`agents-sync --bootstrap` 會重建 symlink，刪 symlink 無效。
- Trigger ledger 增一欄 **Host**：三 host 的觸發機制不同（Claude 走 skill listing，Codex/Copilot 走路徑讀取），同一格不能混記。

### Phase 5

- ledger 範圍寫死 **17 個檔案**；「已重驗」清單補上 `CONTEXT-FORMAT.md = local-superset`（本機獨有 3 節 + 3 條規則）、`DEEPENING.md` 的 6-byte 原地修改，以及 6 個上游無對應檔。
- ledger 結論寫進 `vendored-forks.md` 的 fork index，一併結清「四支未登錄 fork」這筆既有債。
- 補一句 canary 的能力邊界：`mp-tdd`、`mp-diagnose` 歷史觸發 **0 次**，canary 對這兩支零證據力，退休依據只能是 ledger。

### Phase 6 / Phase 7

Phase 6 見第 5 節。Phase 7 「必留」清單追加**機械 helper 的 re-home 產物**（若決定保留 `sdd-workspace` 類能力）。

---

## 5. Phase 6 十項 gate 的最終版本

> 前提變更：以下所有「在 arm B 觀測」皆指 Phase 4B 已把 superpowers plugin 停用的候選環境。沒有這個前提，第 3、4、5、8 項在結構上無法被驗證。

1. **Active reference 歸零，逐檔核銷**：以固定清單（含 `dev-workflow/SKILL.md:22,23,56,73,125`、`references/review-triage.md:31`、`bug-fix-settlement/SKILL.md:3,12`、`auditing-skill-folder/SKILL.md:12,58`、`step7-style-checks.md:7`、`scripts/count-words.sh:34`、`core/routing.md:12,15`）逐項標記已遷移／已刪除；X1 canonical path 已中性化；`.superpowers/sdd/` 已有保留或搬遷決定；歷史文件保留原路徑並明標 historical。
2. **四支 `mp-*` 完成 17 檔 file-level parity ledger**，每檔標 byte／semantic status 與 action；所有 `local-unique`（至少含 `CONTEXT-FORMAT.md` 三節、`tracer-bullet.md`、`feedback-loop.md`、`INTERFACE-DESIGN.md`、`LANGUAGE.md`、`refactoring.md`）已 re-home 或有明確保留決策；結論寫入 `vendored-forks.md` fork index。
3. **`verification-before-completion` 的職能已由 `[T0-2]` + S4–S6 承接，並在 arm B 以真實任務觀測到**——不是宣稱。該 skill 歷史觸發 0 次，故必須以「缺 evidence 時是否仍能宣稱 done」的反向探針取證。
4. **收尾閘已改為以動作定義**：`[INT-1]`、`SKILL.md:109`、`[R-1]` 不再以 `finishing-a-development-branch` 為觸發條件；branch finishing／PR／CI closeout 在 arm B 完整跑過一次（該 skill 歷史 32 次觸發，為本次遷移量最大的行為變更）。
5. **red→green bugfix gate 在 arm B 有真實任務紅燈輸出**作為證據。
6. **`code-review` 兩軸各標四態**（PASS，或 `SKIPPED` + 理由——無 spec 時 Spec 軸合法跳過），且三 host 皆有可執行的並行 delegation 路徑（Claude `Agent`/`general-purpose`、Codex `agents/openai.yaml`、Copilot `task`／`--agent` 映射已補）。
7. **Workspace isolation**：`[T1-10]` 已進 source-of-truth 且指向既有的 `bin/agents-branch`；`tests/conformance.sh` 新增「`~/.agents` 主 checkout 在 `main`」斷言並在 CI 綠。
8. **`implement` 的收尾 commit 被 kernel adapter 攔下**（`implement/SKILL.md` 末行「Commit your work to the current branch.」），且在 arm B 觀測到它確實先回 S4–S6；adapter 另需補「先開 `feat/`／`fix/` 分支」（upstream 只說 current branch）。
9. **三 host 新 session inventory 與真實任務 canary 全部通過，且每 host 的 rollback 後置條件可機械讀回**：Claude 比對 `~/.claude/CLAUDE.md` 的 routing stamp 區塊，Codex/Copilot 比對 `dist/manifest.tsv` hash。任一 host 的後置條件讀不回即視為 rollback 未完成。
10. **交付機制與缺失載體同時成立**：22 支以**單一可稽核來源**送達三 host 且版本一致（Phase 2 決策的產物，並確認未使用 `scripts/link-skills.sh`）；delegation gate 覆蓋 S1–S5 而非僅 S3；writing／audit semantics 已本地化（無 dangling background reference、未把 user-invoked skill 誤當可自動載入的依賴）；**superpowers 的 6 支機械 helper 已逐支盤點**，仍需要者（至少 `sdd-workspace`／`task-brief`／`review-package`）已 re-home 或有明確放棄決策。

---

## 6. 是否建議進入實作階段

**No。**

理由只有兩條，且都是最小差異可修，不需要回退任何已收斂的架構：Phase 2 缺一個阻斷級決策（F1），Phase 4B 缺一行設定（F2）導致十項 gate 中有四項在結構上無法被驗證。其餘 13 項 findings 都可以在 Phase 3–5 執行中逐項吸收。

---

## 7. 最優先的 next action

**決定 22 支 skill 送達三個 host 的交付機制，並把它寫進 doc 09 的 Phase 2。**

在此之前 Phase 2 不能開始——它同時決定 Phase 4B 的隔離能不能逐 host 做、以及 Phase 6「逐 host 移除、任一失敗即停止」是否成立。兩個選項與代價已列於第 4 節 Phase 2。

---

## 附錄 A — 可重跑的 probe 指令

所有指令皆唯讀。執行時請重新記錄 Asia/Taipei 觀測時刻。

```bash
# A1 upstream HEAD 與 22 支 invocation 型別
SHA=$(curl -s https://api.github.com/repos/mattpocock/skills/commits/main | python3 -c "import json,sys;print(json.load(sys.stdin)['sha'])")
echo "$SHA"
for p in engineering/{ask-matt,code-review,codebase-design,diagnosing-bugs,domain-modeling,grill-with-docs,implement,improve-codebase-architecture,prototype,research,resolving-merge-conflicts,setup-matt-pocock-skills,tdd,to-spec,to-tickets,triage,wayfinder} \
         productivity/{grill-me,grilling,handoff,teach,writing-great-skills}; do
  n=$(basename "$p")
  if curl -s "https://raw.githubusercontent.com/mattpocock/skills/$SHA/skills/$p/SKILL.md" | grep -q "disable-model-invocation: true"; then
    printf "%-36s USER-INVOKED\n" "$n"; else printf "%-36s model-invoked\n" "$n"; fi
done
```

```bash
# A2 官方 plugin 只收 22 支；link-skills.sh 收 37 支
curl -s "https://raw.githubusercontent.com/mattpocock/skills/$SHA/.claude-plugin/plugin.json" | python3 -c "import json,sys;s=json.load(sys.stdin)['skills'];print(len(s));print('\n'.join(s))"
curl -s "https://raw.githubusercontent.com/mattpocock/skills/$SHA/scripts/link-skills.sh" | sed -n '1,20p'
```

```bash
# A3 本機 active superpowers 引用（排除 proposals/attic/backups）
cd ~/.agents && grep -rn "superpowers" --include="*.md" --include="*.sh" --include="*.json" . \
  | grep -v "^./proposals/" | grep -v "^./attic/" | grep -v "^./backups/"
```

```bash
# A4 三 host 的 skill 探索根
ls ~/.codex/skills; ls ~/.copilot/skills; cat ~/.agents/dist/manifest.tsv
grep -n "\.agents/skills" ~/.agents/dist/AGENTS.md
```

```bash
# A5 skillUsage 權威計數
python3 -c "
import json,datetime
d=json.load(open('$HOME/.claude.json'))['skillUsage']
for k,v in sorted(d.items(), key=lambda x:-x[1].get('usageCount',0)):
    if 'superpowers' in k or k.startswith('mp-'):
        t=v.get('lastUsedAt'); ts=datetime.datetime.fromtimestamp(t/1000).strftime('%Y-%m-%d') if t else '-'
        print(f\"{v.get('usageCount',0):5d}  {k:52s} last={ts}\")"
```

```bash
# A6 mp-* 對上游的 byte parity（17 檔全量）
for s in mp-diagnose mp-grill-with-docs mp-improve-codebase-architecture mp-tdd; do
  echo "=== $s"; find ~/.agents/skills/$s -type f | sort; done
# 逐檔 cmp 對應上游：diagnosing-bugs / domain-modeling / codebase-design / tdd
```

```bash
# A7 superpowers 機械 helper 盤點
SP=~/.claude/plugins/cache/superpowers-marketplace/superpowers/6.2.0
find "$SP" -type f \( -name "*.sh" -o -name "*.js" -o -perm +111 \) -not -path "*/tests/*"
ls ~/Downloads/coding_agent_project/DCT_data_import_data_stream_codex/.superpowers/sdd | wc -l
```

```bash
# A8 既有 worktree 機械載體與缺失斷言
sed -n '1,20p' ~/.agents/bin/agents-branch
grep -n "branch\|worktree\|main" ~/.agents/tests/conformance.sh   # 目前零命中
```

## 附錄 B — 本次實測的 parity 結果（17 檔中已比對的部分）

| 本機檔案 | 上游對應 | Byte status | 備註 |
|---|---|---|---|
| `mp-diagnose/scripts/hitl-loop.template.sh` | `diagnosing-bugs/scripts/hitl-loop.template.sh` | identical | doc 09 已列 |
| `mp-tdd/mocking.md` | `tdd/mocking.md` | identical | doc 09 已列 |
| `mp-grill-with-docs/ADR-FORMAT.md` | `domain-modeling/ADR-FORMAT.md` | identical | doc 09 已列 |
| `mp-tdd/tests.md` | `tdd/tests.md` | different（1640B vs 2214B） | 本機為子集，doc 09 已列 |
| `mp-grill-with-docs/CONTEXT-FORMAT.md` | `domain-modeling/CONTEXT-FORMAT.md` | **different（3145B vs 2299B）** | **本機 superset，doc 09 未列** |
| `mp-improve-codebase-architecture/DEEPENING.md` | `codebase-design/DEEPENING.md` | **different（差 6B）** | **原地修改交叉引用，doc 09 未列** |
| `mp-tdd/deep-modules.md` | `codebase-design/DEEPENING.md`（疑似） | different（1239B vs 2559B） | 需語義比對 |
| `mp-tdd/interface-design.md` | 無同名 | missing | local-unique 候選 |
| `mp-tdd/refactoring.md` | 無同名 | missing | 上游 v1.1 已把 refactor 移出 tdd |
| `mp-tdd/references/tracer-bullet.md` | 無同名 | missing | 語義可能落在 `to-tickets` |
| `mp-diagnose/references/feedback-loop.md` | 無同名 | missing | local-unique 候選 |
| `mp-improve-codebase-architecture/INTERFACE-DESIGN.md` | 無同名 | missing | local-unique 候選 |
| `mp-improve-codebase-architecture/LANGUAGE.md` | 無同名 | missing | local-unique 候選 |
| 其餘 4 支 `SKILL.md` | 各自對應 | 未比對 | ledger 待補 |
