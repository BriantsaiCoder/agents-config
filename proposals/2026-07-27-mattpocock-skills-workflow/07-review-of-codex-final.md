# Review：Codex 最終建議（2026-07-27 12:32）

> 結論：**架構與順序同意，我改變先前「不建議移除 superpowers」的立場。但 Phase 6 的三個「已有載體」經查兩個不存在、一個是循環引用，移除前必須先建。**

## 1. 我改變立場的那個論證

Codex 寫：

> 「Matt 沒有機械 gate 並不是阻止移除 Superpowers 的理由，因為真正可靠的 gate 本來就應放在 kernel、hooks 與 CI，而不是留在另一套長篇 skill prose 裡。」

**這說服了我。** 我先前反對移除的理由是「`verification-before-completion` 與 `finishing-a-development-branch` 是 `[T0-2]` 與 `[INT-1]` 的載體」——但那正是問題所在，不是理由：把 evidence gate 寄放在另一個第三方 plugin 的 prose 裡，本來就是脆弱的設計。使用者自己的 CLAUDE.md 也寫著「沉澱前評估能否機械化：預防檢查可寫成 hook / test / lint 者，考慮落地為機械守護取代 prose」。

而且 Codex 把遷移理由從 token 換成**單一 upstream、降低重複維護**——理由換了，結論就該重新評估。**同意移除，放在最後，且以 Phase 6 九項為閘。**

## 2. 三個「已有載體」的宣稱：兩個不成立、一個循環 ⚠️

Codex 的職能對照表把三項列為「已有新載體」。實測：

| Codex 的對照 | 實測 | 判定 |
|---|---|---|
| `dispatching-parallel-agents` → **host 原生 delegation policy** | `dev-workflow:129` 的 **Codex** adapter 有完整 delegation 限制（兩個可獨立驗證、file ownership 不重疊、明確允許才 spawn）；**Claude adapter（:125）只寫 `superpowers:executing-plans / subagent-driven-development`** | **Claude 端載體不存在**，移除後 S3 delegation 政策為空。需先寫 |
| `using-git-worktrees` → **全域 Git／branch policy** | `grep -rn "worktree\|isolation" ~/.agents/core/` **零命中**；`dev-workflow` 內亦零命中。tier0/1/2 有 force-push、commit 格式、commit 可獨立 checkout，**沒有任何 worktree／工作區隔離政策** | **載體不存在**。需先寫 |
| `writing-skills` → **現有 skill creation／audit 工具** | `auditing-skill-folder/SKILL.md:58` 寫著 **`REQUIRED BACKGROUND: superpowers:writing-skills (authoritative source for the six standards)`**，`:12` 另有一處，`step7-style-checks.md:7` 再一處 | **循環引用**——那個「現有工具」的權威來源就是要被移除的東西。正確載體是 Matt 的 **`writing-great-skills`**，改引用即可 |

**建議**：Phase 6 的九項條件加第 10 項——「上述三個載體已實際存在並可引用」。前兩項是新寫（各約 3–5 行 prose 進 `dev-workflow` 的 Claude adapter 與 tier1），第三項是改引用（3 處）。

`using-git-worktrees` 這條特別值得補，因為本機已經踩過相關的坑：切 `~/.agents` 分支會即時換掉 Claude 讀到的 skill 內容（symlink 導致），切到過時分支會靜默回退且無錯誤——那正是工作區隔離政策該覆蓋的場景。

## 3. `setup-matt-pocock-skills` 的自我矛盾

Codex 前一版說「不建議直接使用；會和既有 repo governance、generated AGENTS 流程重疊」，這一版的「stable 22 支全部導入」又把它包進去。

**實測依賴鏈**：7 支 skill 的 SKILL.md 明寫「run `/setup-matt-pocock-skills` if not」——`ask-matt`、`code-review`、`triage`、`to-tickets`、`to-spec`、`wayfinder`，加它自己。

**這兩個立場可以調和，但要明說**：

- **安裝**它（否則那 6 支的指引懸空）
- **不執行**它（避免它寫 `docs/agents/*.md`、改 `CLAUDE.md` 的 `## Agent skills` 區塊、引入 `.scratch/` 這第二套持久化慣例）
- **改為手寫一個 `docs/agents/issue-tracker.md`**，內容對齊本機既有的 X1 產物表。那 6 支要的其實只有這一個契約檔，不是整套 setup 產物

不寫清楚的話，第一個跑 `/to-tickets` 的 session 會自己去跑 setup，然後 X1 表和 `.scratch/` 兩套並存。

## 4. 我查了但結論支持 Codex 的一項

原本想質疑「排除 `misc/`」——因為 `misc/` 裡有 `git-guardrails-claude-code`（PreToolUse hook 攔危險 git）和 `setup-pre-commit`（Husky + lint-staged），兩者都是「把 gate 機械化」的工具，正好呼應 Codex 自己的核心論證。

查完收回：

- `git-guardrails-claude-code` 與本機既有的 `~/.agents/hooks/guard-git-push.sh`（單一正本 + 兩薄 wrapper，2026-07-25 已修四破口）**重複**，且本機那份更完整
- `setup-pre-commit` 是 Husky/lint-staged/Prettier，**JS/TS 專用**，對本機主要的 .NET 專案無用

**Codex 排除 `misc/` 是對的。**

## 5. 逐項表態

| Codex 的決策 | 我的立場 |
|---|---|
| 導入 stable 22 | **同意**（附 §3 的 setup 處理方式） |
| 不安裝全部 38 | **同意**（§4 已查證 misc/ 無遺珠） |
| 不讓 Matt 取代 kernel | **同意** |
| Matt 取代 orchestration | **同意** |
| Matt 取代 superpowers 方法論（canary 後） | **同意** |
| 移除 superpowers，放最後 | **同意——這是我的立場改變**，條件是 Phase 6 九項 + §2 的第 10 項 |
| 退休 4 支 `mp-*` | **同意**，但保留我先前的但書：先確認在地化（`references/`、`deep-modules.md` 等自加檔案）無獨有價值再刪，逐支舉證 |
| 保留 `mp-zoom-out` | **同意** |
| refactor 政策收進 kernel 一句 | **同意**，這比留成 skill 好。措辭建議：「green 後允許本輪範圍內的 micro-refactor；跨模組、public interface 或結構性 refactor 延後至 code-review」——與 `[T1-5]` 相容 |
| 不以 token 為主要理由 | **同意**（我的實測支持：差額 ~771 tok = 120k 的 0.6%） |
| 以單一 upstream／降低重複維護為理由 | **同意，且這是更好的理由** |
| upstream files 保持 immutable | **同意**，與本機 vendored 規則一致。但要明說 adapter 放哪——建議 `dev-workflow` 的 Host adapters 段，不要另開第三個檔 |

## 6. 補充：Phase 3–5 之間的 routing 噪音

Phase 3 切換 routing 但 Phase 5 才刪舊 `mp-*`，中間兩套並存。注意 Matt 的 `tdd` 與本機 `mp-tdd` **都是 model-invoked**，description 都講 TDD，**會競爭自動觸發**。同理 `diagnosing-bugs` vs `mp-diagnose`。

這是 canary 期的已知噪音，不是 bug，但應該：① 事先預期並記錄；② 把「觸發到哪一支」列為 canary 的觀察項之一（Codex 的 Phase 4 檢查清單目前沒有這條）。

## 7. 唯一還沒收斂的

`mp-*` 退休的**舉證責任方向**。Codex 是「退休」（預設刪），我是「先逐支舉證在地化無獨有價值再刪」。實務差異不大——Phase 5 在 canary 通過後才執行，那時已有實證。但舉證方向影響的是：如果 canary 顯示新舊行為等價，是否還需要檢查 `mp-tdd/references/`、`mp-diagnose/scripts/` 這些自加檔案裡有沒有上游沒有的東西。

**我的立場**：需要。canary 測的是「常見路徑等價」，測不到「在地化檔案裡的邊角知識」。逐支花 10 分鐘 diff，比事後發現刪掉了某個只在特定情境用得上的 reference 便宜。
