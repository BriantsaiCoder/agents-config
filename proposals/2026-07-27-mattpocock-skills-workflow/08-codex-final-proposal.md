# Codex 最終建議（原文存檔）

> 來源：Codex 於 2026-07-27 約 12:32 提出的最終建議，由使用者轉貼。原樣保存，未編輯。
> 用途：讓新 session 的 Codex 能讀回自己的建議全文（Phase 4 檢查清單、Phase 6 九項條件、完整職能對照表），以便對 [07-review-of-codex-final.md](07-review-of-codex-final.md) 的四點修正做出回應。

---

最終建議是：

導入 Matt Pocock 的 stable 22 skills，讓它取代 Superpowers 的開發方法與 orchestration；但不要讓它取代你的全域安全 kernel。完成 canary 與職能補位後，移除 Superpowers、退休 4 支舊 mp-*，只保留 mp-zoom-out。

## 建議的終態架構

```
全域 workflow kernel（保留，縮薄）
├── Tier 0 safety rules
├── routing / authorization
├── plan-first 與風險分級
├── BUGFIX red→green gate
├── S4–S6 evidence / review / closeout
├── PR / CI / branch finishing
└── hooks / CI 機械攔截

Matt Pocock stable skills（新的主要工作方法）
├── grill-with-docs
├── grilling
├── domain-modeling
├── to-spec
├── to-tickets
├── implement
├── tdd
├── diagnosing-bugs
├── code-review
├── codebase-design
├── improve-codebase-architecture
├── wayfinder
├── triage
├── research
├── prototype
└── 其他 engineering + productivity stable skills

本機保留 skill
└── mp-zoom-out
```

也就是：

- Kernel 決定「能不能做、何時算完成」。
- Matt skills 決定「怎麼釐清、規劃、實作、診斷與 review」。
- hooks／CI 負責不可依賴模型自律的機械閘門。

## 安裝範圍

| 範圍 | 建議 |
|---|---|
| skills/engineering 17 支 | 全部導入 |
| skills/productivity 5 支 | 全部導入 |
| Stable 合計 22 支 | 建議 |
| in-progress、misc、personal、deprecated | 不導入 |
| Installer 顯示的全部約 38 支 | 不建議全部常駐 |

「完整安裝」應解讀為完整安裝 production-ready 的 22 支，而不是把 Matt 自己仍在實驗或準備刪除的技能一起變成全域依賴。

## Workflow 對照

### 小型或單 session 任務

```
grill-with-docs → implement → tdd → code-review
    → 回到本機 S4–S6 verification / closeout → commit / PR
```

關鍵 adapter 規則：Matt implement 即使準備 commit，也必須先回到全域 kernel 的 S4–S6；不能因為 upstream 寫著 commit 就跳過 evidence、review 或 closeout。

### 大型、多 session 任務

```
grill-with-docs → to-spec → to-tickets
    → 每個 ticket 使用乾淨 session → implement → S4–S6 closeout
```

Ticket 應以「能否在一個新 context 完成」切割，而不只是依複雜度分類。

### 特殊入口

| 情境 | Skill |
|---|---|
| 已知 issue／別人開的 ticket | triage |
| flaky、效能 regression、根因不明 | diagnosing-bugs |
| 巨型計畫、路徑仍在迷霧中 | wayfinder |
| architecture review | improve-codebase-architecture |
| interface／deep-module 設計 | codebase-design |
| 外部資料調查 | research |
| 需要快速實物釐清設計 | prototype |

## mp-* 最終處置

| 舊 skill | 新載體 | 最終處置 |
|---|---|---|
| mp-diagnose | diagnosing-bugs | 退休 |
| mp-grill-with-docs | grill-with-docs + grilling + domain-modeling | 退休 |
| mp-improve-codebase-architecture | improve-codebase-architecture + codebase-design | 退休 |
| mp-tdd | tdd | 退休 |
| mp-zoom-out | 無一對一對照組 | 保留 |

mp-tdd 原有的 refactor 折衷政策不必再保留成 skill，放進 kernel／dev-workflow 一句即可：

> Green 後允許本輪範圍內的 micro-refactor；跨模組、public interface 或結構性 refactor 延後至 code-review。

如此可移除 mp-tdd → superpowers:test-driven-development 的硬依賴。

## Superpowers 最終處置

我的最終建議是：可以完整移除，但只能在遷移最後移除。

主要職能對照：

| Superpowers 職能 | 新載體 |
|---|---|
| brainstorming | grill-with-docs + grilling |
| writing-plans | to-spec + to-tickets |
| executing-plans | implement |
| test-driven-development | tdd |
| systematic-debugging | diagnosing-bugs |
| requesting-code-review | code-review |
| verification-before-completion | 全域 [T0-2] + S4–S6 |
| finishing-a-development-branch | 全域 closeout + PR/CI rules |
| dispatching-parallel-agents | host 原生 delegation policy |
| using-git-worktrees | 全域 Git／branch policy |
| writing-skills | 現有 skill creation／audit 工具 |

Matt 沒有機械 gate 並不是阻止移除 Superpowers 的理由，因為真正可靠的 gate 本來就應放在 kernel、hooks 與 CI，而不是留在另一套長篇 skill prose 裡。

## 建議遷移順序

### Phase 1：建立正確基線

只讀量測：

- 記錄三個 host 現有 plugin／skill inventory。
- 列出所有 active superpowers: 與 mp-* 引用。
- 分別量測 description 與 SessionStart hook 成本。

修正已失真的 routing 說明時，必須改 source-of-truth 再同步，不能直接改 generated files。

磁碟殘留 cache 清理只是衛生項目，不是 token 優化，也不應是第一步。

### Phase 2：Sidecar 安裝

- 導入 stable 22 skills。
- 不刪 Superpowers。
- 不刪 mp-*。
- Matt upstream files 保持 immutable，不直接做本機魔改。
- 本機政策只放 kernel 或極薄 adapter。

不要把遷移收益建立在 disable-model-invocation 上；Claude、Codex、Copilot 對此欄位的支援不一致。

### Phase 3：切換 routing

按對照表更新：

```
mp-diagnose                      → diagnosing-bugs
mp-grill-with-docs               → grill-with-docs
mp-improve-codebase-architecture → improve-codebase-architecture
mp-tdd                           → tdd
```

並更新所有：dev-workflow、host routing 注入、skill cross-reference、Superpowers name references。

此時仍不刪舊技能，以便快速 rollback。

### Phase 4：Canary

建議至少跑 5–10 個真實任務，涵蓋：

- 小型 feature。
- 中型 feature。
- 明確 bugfix。
- flaky／perf diagnosis。
- architecture review。
- 多 session spec/tickets。
- code review。
- PR／branch closeout。

每次檢查：

- 是否未確認需求就開始改檔。
- bugfix 是否先有 failing regression test。
- 是否留下 test/build/lint evidence。
- 是否經過 Standards + Spec review。
- 是否能在缺 evidence 時錯誤宣稱完成。
- implement 是否會跳過 S4–S6。
- ticket 是否真的能在一個乾淨 context 完成。

任何一次可以在 evidence 不足時宣稱 done，都不應移除舊 workflow。

### Phase 5：退休舊 mp-*

Canary 通過後：

- 刪除四支已被取代的 mp-*。
- 保留 mp-zoom-out。
- 驗證 active routing 沒有 dangling reference。
- 新 session 確認 inventory 與 invocation 正常。

### Phase 6：移除 Superpowers

只有以下條件全部滿足才能移除：

1. Active config 中 superpowers: 引用歸零。
2. 四支 mp-* 已完成替換。
3. verification-before-completion 已由 [T0-2] + S4–S6 承接。
4. branch finishing／PR／CI closeout 已有明確載體。
5. red→green bugfix gate 可驗證。
6. code-review 同時檢查 Standards 與 Spec。
7. worktree／branch isolation 政策有新載體。
8. implement 不會跳過 kernel closeout。
9. 三個 host 的新 session inventory 與真實任務 canary 都通過。

移除應逐 host 進行；Claude、Codex、Copilot 的 plugin 狀態彼此獨立。

### Phase 7：最後才瘦身 kernel

確認 Matt workflow 穩定後，才刪除 kernel 中已被 Matt skills 完整承接的 prose。

仍保留：Tier 0、routing／authorization、風險與 plan gate、evidence／review／closeout、PR／CI、機械 hooks。

## 最終決策表

| 決策 | 最終建議 |
|---|---|
| 導入 Matt stable 22 | 建議 |
| 安裝全部約 38 支 | 不建議 |
| 讓 Matt 完整取代全域 kernel | 不建議 |
| 讓 Matt 取代 workflow orchestration | 建議 |
| 讓 Matt 取代 Superpowers 方法論 | 建議，canary 後 |
| 移除 Superpowers | 建議，放在最後 |
| 退休四支舊 mp-* | 建議 |
| 保留 mp-zoom-out | 建議 |
| 以 token 節省作為主要遷移理由 | 不建議 |
| 以單一 upstream、降低重複維護作為理由 | 建議 |

一句話收斂：

> 不要用 Matt repo 取代所有全域規則；用它取代 Superpowers 與四支舊 mp-* 的方法論部分，保留精簡 kernel 作為不可繞過的治理與完成閘門。
