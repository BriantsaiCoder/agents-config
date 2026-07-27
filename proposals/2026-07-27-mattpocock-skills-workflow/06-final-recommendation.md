# 最終建議：完整取代？完整安裝？

> 2026-07-27。回答兩個明確問題，附裝/不裝逐支清單。

## Q1：完整安裝此 repo 取代 superpowers 及全域 workflow —— **不建議**

三條理由，每條都是實測而非偏好：

### 1. `[T0-2]` 與 `[INT-1]` 會失去載體

`verification-before-completion`（無 evidence 不得宣稱 done）與 `finishing-a-development-branch`（收尾 skill 只在 S4/S5 全 PASS 後 invoke）是 tier0 / 攔截規則**直接點名**的兩支 superpowers skill。Matt 全套 22 個**沒有任何對應物**。

移除它們 = 兩條規則變成沒有執行機制的散文。這不是「風格換一換」，是拆掉守門。

### 2. token 不構成理由（前提已被推翻）

| | 每 session 常駐 |
|---|---:|
| superpowers 單 root | ~539 tok（metadata）+ **766 tok**（SessionStart hook 強制注入 `using-superpowers` 全文） = **~1,305** |
| Matt 22 個（host 不尊重 `disable-model-invocation`） | ~926 |
| Matt 9 個 model-invoked（host 尊重） | ~488 |

省下 **380–817 tok/session**，相對 120k smart zone 是 **0.3–0.7%**。而本機 50 個 skill 自己就佔 ~4,424 tok——**真正的大戶跟這次遷移無關**。

用零頭的 token 收益，換掉會攔住你的 gate，不划算。

### 3. 14 支裡只有 2 支能乾淨替換

`systematic-debugging`→`diagnosing-bugs`、`writing-skills`→`writing-great-skills` 可以。其餘：**7 支退化或半缺、5 支無對應物**。而且 `mp-tdd` 與 `auditing-skill-folder` 把 superpowers 那支宣告為 **base / authoritative source**，自己只寫 delta——移除會讓這兩支變成殘篇。

**若仍要做**：順序見 04 §2.5 與 05 §4（S-A → S-G），核心是「先斷引用、gate 載體先 re-home、最後才翻 settings」。

---

## Q2：是否建議完整安裝此 repo 的 skill —— **不建議完整安裝，建議選裝 8 支 + 併入 6 支**

### 先決定路線：plugin 還是 skills.sh？

這一步比「裝哪些」更關鍵，因為兩條路線的能力不同：

| | **Claude plugin**（`/plugin install mattpocock-skills@mattpocock`） | **skills.sh**（`npx skills@latest add mattpocock/skills`） |
|---|---|---|
| 版本 | v1.2.0 | 同 repo |
| 可否挑選 | **不可**——`.claude-plugin/plugin.json` 的 `skills` 陣列寫死 22 支；且 `~/.claude/settings.json` 的粒度只到 `enabledPlugins`（plugin 名 → boolean），**無 per-skill disable 鍵**（對照組：superpowers 也是整包 14 支，settings 內無任何單支條目） | **可**——安裝器逐支勾選 |
| 可否修改 | 不可（訂閱模式，隨上游更新） | 可（copy 進來，fork 模式） |
| 三家覆蓋 | **僅 Claude**。ADR 0002 明載：`.codex-plugin/plugin.json` 的 `skills` 只接受**單一路徑字串**（陣列會被拒），無法表達 curated subset，因此 **Codex plugin 被 defer**；Copilot 亦無 | **三家皆可**（Agent-Skills 標準） |

**你的目標是三家跑同一條 workflow** → **plugin 路線與此目標互斥**。走 plugin 等於接受 Claude-only。

**建議走 skills.sh，裝進 `~/.agents/skills/`**（三家共用的 canonical root，Codex 以 `r1` 載入、Copilot 列為 Personal 來源，皆已實測）。代價是你成為 fork owner，要自己追上游——但你現有 5 個 `mp-*` 本來就已經是這個狀態。

### 不建議完整安裝的理由

1. **是疊加不是取代**。22 支裝進 `~/.agents/skills/` 會變成 50 + 22 = 72 支，常駐 metadata 從 ~4,424 漲到 ~5,350 tok（若 host 不尊重 `disable-model-invocation`，而 Codex/Copilot 應保守假設不尊重）。
2. **13 支是 user-invoked**，成本從 context 轉成**你的記憶負擔**——Matt 自己承認這點，解法是再裝一支 router（`ask-matt`）。你已經有 `dev-workflow` S0 這個更嚴格的 router，再加一個會變成兩個 canonical router 互搶。
3. **6 支與既有 skill 直接重疊**，並存會製造路由歧義。
4. **3 支與你的規則有實質衝突**（見下表）。

### 逐支清單

#### A. 建議新裝（8 支，本機無對應物）

| Skill | 型 | 為什麼 |
|---|---|---|
| `handoff` | U | 跨 session 橋，本機完全沒有。存 OS temp 而非工作區、引用不複製、遮罩敏感資訊——三條都合你的規範 |
| `to-tickets` | U | **容量軸切片**（一票 = 一個 context window）+ blocking edges + wide refactor 的 expand–migrate–contract。你的 LIGHT/HEAVY 是風險軸，缺這條。**消費端是誰**：因為不裝 `implement`（見 C 組），票由 **S3 直接讀取**——每票開乾淨 session、走既有 branch/TDD/`deps-check` 流程，再照常進 S4–S6。不要讓生產者沒有消費者 |
| `to-spec` | U | 跨 session planning artifact。用它時 X1 表要指定落點（**不要**用 Matt 的 `.scratch/`） |
| `wayfinder` | U | 多 session 迷霧探索，本機無對應（`mp-zoom-out` 不是同一件事）。**限超大型**，`ask-matt` 正本明說「絕不用在範圍清楚的 feature 上」 |
| `code-review` | M | two-axis（Standards + Spec）+ Fowler 12 smell 基線。你的 S5 目前**沒規定方法** |
| `grilling` | M | 核心原語，含 v1.1 三修（一次一題的理由、確認閘、fact/decision 二分）。本機 `mp-grill-with-docs` 是 pre-v1.1 |
| `research` | M | 背景 agent 查一手來源。**必須加 read-only gate**——不可自動寫 repo |
| `prototype` | M | logic / UI 兩分支的丟棄式原型。**必須加 scope gate** |

裝完後的 model-invoked 增量只有 4 支（`code-review`/`grilling`/`research`/`prototype`），常駐成本增加有限。

#### B. 併入既有（6 支，挑差異不新增檔）

| Skill | 併入 | 差異重點 |
|---|---|---|
| `tdd` | `mp-tdd` | **先決定 refactor 政策**：上游 v1.1 把 refactor 全移出紅綠迴圈。建議折衷——micro-refactor（改名、抽小函式、消重複）留迴圈內，結構性 refactor 進 review。全移出會讓 S5 變瓶頸 |
| `diagnosing-bugs` | `mp-diagnose` | 上游 134 行 vs 本機 68 行，另有 `hitl-loop.template.sh` |
| `grill-with-docs` | `mp-grill-with-docs` | 上游是 7 行薄殼，實體在 `grilling` + `domain-modeling` |
| `domain-modeling` | `mp-grill-with-docs` | 詞彙層，維護 `CONTEXT.md` + ADR |
| `codebase-design` | `mp-improve-codebase-architecture` | deep module 詞彙（module/interface/depth/seam/adapter/leverage/locality） |
| `improve-codebase-architecture` | 同名 mp- 版 | 上游多 `HTML-REPORT.md` |

**一律挑差異、不整包覆蓋**——這 5 個 `mp-*` 不在 vendored 名單、無上游標記、自加 `references/`，是刻意的在地 fork，整包重抓違反 `[T1-5]`。

#### C. 不裝（8 支）

| Skill | 為什麼不裝 |
|---|---|
| `setup-matt-pocock-skills` | 會寫 `docs/agents/*.md`、把 issue 放 `.scratch/`、並改 `CLAUDE.md` 的 `## Agent skills` 區塊——與你的 X1 產物表（`docs/superpowers/`、`sdd/<slug>/`、`docs/adr/`）**兩套並存**。兩份獨立建議一致反對 |
| `implement` | 15 行且結尾寫「commit your work to the current branch」——會誘導跳過 S4–S6。**這是整個嫁接方案唯一的破窗點**，不裝最乾淨；真要裝必須在 adapter 明文寫「跑完回 kernel S4–S6」 |
| `ask-matt` | 第二個 canonical router，與 `dev-workflow` S0 互搶。它的 flow map 可以參考，但不該當成必經 stage |
| `triage` | 只在真的採用 issue tracker workflow 才有價值。你目前沒有 |
| `resolving-merge-conflicts` | 「永不 `--abort`」與 tier0 的使用者授權/破壞性動作規則有張力。要裝得先剝掉那條 |
| `teach` | 教學工作區，與開發 workflow 無關 |
| `grill-me` | 全文一行 wrapper（`Run a /grilling session.`），有 `grill-with-docs` 就不需要 |
| `writing-great-skills` | 與 `superpowers:writing-skills` 重疊。**但注意這是一條 live 的硬依賴**：`auditing-skill-folder/SKILL.md:58` 寫著 `REQUIRED BACKGROUND: superpowers:writing-skills`（另 `:12` 與 `step7-style-checks.md:7` 也引用）。所以這支不是「未來選項」——它是 **S-E 解耦清單裡的指定替代品**，移除 superpowers 的同一批動作要同時補裝它並改寫那三處引用 |

### 淨結果（增量為實測，非估算）

- 新增 **8 支**（model-invoked 4 + user-invoked 4）
- 更新 **6 支**既有（不增檔）
- 放棄 **8 支**

常駐 metadata 增量（name+description 同 Codex 口徑，實測字元數）：

| Host | 計入 | 增量 |
|---|---|---:|
| **Claude**（尊重 `disable-model-invocation`） | 僅 4 支 model-invoked（`code-review` 428 / `research` 246 / `prototype` 188 / `grilling` 160 chars） | **+255 tok** |
| **Codex / Copilot**（保守假設不尊重） | 全 8 支（另加 `to-tickets` 257 / `wayfinder` 208 / `to-spec` 157 / `handoff` 93 chars） | **+434 tok** |

對照全裝 22 支的 +926 tok。`code-review` 的 description 是 repo 內最長的一支（428 chars），佔 Claude 端增量的 42%——但它補的是你 S5 完全沒有的方法，這筆值得。

---

## 執行順序（合併 05 §4，只列與本決策相關的）

1. **S-A 修正基線**（獨立於本決策，先做）：三個注入檔的 stale「description 截斷」宣稱改源檔重生成
2. **S-B 量測基線**：新 session 同口徑重測三家 catalog footprint
3. **S-C 選裝 A 組 8 支**到 `~/.agents/skills/`（走 skills.sh），sidecar 併行、不刪舊，用 5–10 個真實任務驗自動觸發與 gate 完整性
4. **S-D 逐支併入 B 組 6 支**（挑差異），每次一組 + canary
5. **superpowers 維持安裝**——除非 S-E/S-F 的前置條件（gate 載體 re-home）都完成，否則不移除

依 `[T0-8]`，以上任一步動手前需先出計畫並取得確認。本檔是分析，不是授權。
