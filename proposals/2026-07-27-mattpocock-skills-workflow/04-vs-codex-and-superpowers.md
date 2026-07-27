# 兩份建議比較 + 取代 superpowers 的可行性分析

> 2026-07-27。對照對象：Codex 對同一問題的建議。所有數字為本機實測。

## 0. 先處理決定性前提：token 假設

使用者的前提是「mattpocock workflow 佔的 token 遠小於 superpowers」。**方向對，量級錯。**

實測（每回合成本 = description；SKILL.md 全文只在 invoke 時才載入，不是常駐）：

| 套件 | skills | model-invoked | 每回合 description | SessionStart 強制注入 | **每 session 常駐合計** |
|---|---:|---:|---:|---|---:|
| **superpowers 6.2.0**（live） | 14 | **14**（零個 user-invoked） | 1,861 chars ≈ **465 tok** | `using-superpowers` **全文 3,063 chars ≈ 766 tok**（`hooks.json` SessionStart，`async: false`） | **≈ 1,231 tok** |
| **mattpocock eng+prod** | 22 | **9**（13 個 user-invoked） | 1,842 chars ≈ **460 tok** | 無 | **≈ 460 tok** |
| **本機 `~/.agents/skills`** | 50 | **50**（零個 user-invoked） | 17,697 chars ≈ **4,424 tok** | 無 | **≈ 4,424 tok** |

三個結論，都與直覺相反：

1. **description 成本兩者幾乎相同（465 vs 460 tok）。** mattpocock 用 22 個 skill 達成與 superpowers 14 個相同的常駐成本——靠的是 13 個 `disable-model-invocation`，不是 skill 寫得比較短。
2. **真正的差額來自 SessionStart hook**：superpowers 每個 session 強制注入 `using-superpowers` 全文 ≈ 766 tok。換掉 superpowers 實際省下的是 **~771 tok/session**，相對 120k smart zone 是 **0.6%**。這不是「遠小於」，是零頭。
3. **真正的 token 大戶是你自己的 50 個 skill（4,424 tok，是 superpowers 全部成本的 3.6 倍）**，且全數 model-invoked。這跟 superpowers 換不換完全無關。

**而且方向可能相反**：mattpocock 那 22 個若全裝，是**疊加**在現有 50 個之上（`~/.agents/skills` 與 plugin 是不同載入路徑），常駐成本變 4,424 + 460 = **4,884 tok**，不減反增——除非同時把重疊的本機 skill 退役。

**量測的誤差方向（對結論有利，故列出）**：腳本只算 description 字元，實際成本另含每筆的 name / 短路徑 / 格式 scaffolding。mattpocock 是 **22 筆** entry、superpowers 是 **14 筆**，這層 overhead **對 mattpocock 更不利**。所以 460-vs-465 是下界，誤差把 mattpocock 往上推。Matt 自己在影片講的「38 skills = 660 tok」與此同一數量級，可交叉驗證。

> **以 token 為理由做這次遷移，前提不成立。** 若目標真的是省 context，最划算的單項是把 50 個本機 skill 裡的編排型改成 `disable-model-invocation`（見 03-migration §6）——但那條的三家適用性也有限制，見 §3 註。

## 1. 兩份建議的比較

### 共識（兩邊獨立得到同一結論，可信度高）

- **不要整套取代 `dev-workflow`**，它才是 canonical workflow，不是 superpowers plugin
- Matt 的覆蓋範圍是 **S1–S3 + 部分 S5**，S0 / S4 / S6 無對應物
- 保留現有 gate / verification / release governance
- 選擇性導入：`handoff`、`prototype`、`research`、`to-tickets`、`wayfinder`、two-axis `code-review`
- `setup-matt-pocock-skills` 不要用（與既有 governance 衝突）

**兩份建議在主結論上沒有分歧。** 差異在覆蓋面與證據強度。

### Codex 版的優點（我漏掉的）

| 項目 | 內容 | 評價 |
|---|---|---|
| **superpowers 依賴盤點** | 指出 `dev-workflow`、`mp-tdd`、`bug-fix-settlement`、`routing.md` 都硬引用 `superpowers:*`，直接 uninstall 會留下失效引用 | **實測成立**：12 處引用、跨 7 個檔案（`dev-workflow/SKILL.md:73,125`、`references/review-triage.md:31`、`mp-tdd/SKILL.md:3,10,60` + `references/tracer-bullet.md:3`、`auditing-skill-folder` ×3、`bug-fix-settlement/SKILL.md:3,12`）。**這是我完全沒查的角度** |
| **逐 skill 採納判斷** | 17+5 個各給「建議／不建議／有條件」與理由 | 比我的四缺口清單更可操作 |
| **安全性 caveat** | 指出 `resolving-merge-conflicts` 的「never abort」不應凌駕使用者授權；`research` 的 background agent 不該自動寫 repo | 我沒注意到這兩處與 tier0 的張力，**這是真的補強** |
| **skill 長度稽核** | 「17 個中 12 個超過 500 words」 | **實測成立**（12/17） |
| **repo HEAD 標註** | `ed37663cc5fb...` | **實測成立**（與上游 main 同 SHA） |

### 我這版的優點（Codex 漏掉的）

| 項目 | 內容 |
|---|---|
| **三主機 loader 實測** | Codex 完全沒碰這題。我一度誤判又推翻，最終確認 Codex 端 `r1 = ~/.agents/skills` 全文注入、Copilot Personal 來源涵蓋該目錄——這決定了「model-invoked 半邊能不能用」 |
| **token 量化** | 兩份建議都在談 context，但只有實測能證明使用者的前提不成立（上面 §0） |
| **`mp-*` 的 fork 性質** | 實測**不在 vendored 名單**、無上游標記 → 是刻意的在地 fork，所以**不能整包重抓**（違反 `[T1-5]`），只能挑差異。Codex 說「假設用 repo skill 取代舊版 mp-*」這個前提本身有風險 |
| **v1.1 的具體 delta** | `mp-tdd` 仍帶 `refactoring.md` 而上游已把 refactor 移出紅綠迴圈；grilling 三修的具體內容 |
| **來源衝突裁決** | wayfinder 預設地位在影片與 repo 之間有矛盾（repo 為準）；M6mYodf0dJM 逐字稿有一句把多 session 分支講反 |

### Codex 版的瑕疵

1. **`superpowers@superpowers-dev 6.2.0`** — marketplace 名錯了，實際是 `superpowers@claude-plugins-official`（`~/.claude/settings.json:170`）。版本 6.2.0 正確。
2. **「disable-model-invocation 的 user skills 不會造成相同程度的每-turn context cost」** — 方向對，但沒給數字，因此沒發現「兩者常駐成本幾乎相同」這個推翻使用者前提的事實。
3. **未驗證 Codex/Copilot 是否尊重 `disable-model-invocation`** — 這決定省下的 context 是三家還是只有 Claude 端。
4. 把 `domain-modeling` / `codebase-design` 判為「已被 mp-* 涵蓋」，但沒說明本機版是否含上游 v1.1 的內容（實測本機 5 個 `mp-*` 全是 pre-v1.1）。

## 2. 取代 superpowers 的可行性

### 硬依賴：12 處引用，7 個檔案

```
dev-workflow/SKILL.md:73      superpowers:writing-plans          （S2 enhancement）
dev-workflow/SKILL.md:125     brainstorming / executing-plans /
                              subagent-driven-development /
                              requesting-code-review /
                              finishing-a-development-branch      （S2/S3/S5/S6 Claude adapter）
dev-workflow/references/review-triage.md:31   receiving-code-review
mp-tdd/SKILL.md:3,10,60 + references/tracer-bullet.md:3   test-driven-development（宣告為 base）
auditing-skill-folder/SKILL.md:12,58 + step7-style-checks.md:7    writing-skills（宣告為 authoritative source）
bug-fix-settlement/SKILL.md:3,12    systematic-debugging
```

`mp-tdd` 與 `auditing-skill-folder` 不只是「提到」——它們把 superpowers 那支宣告為 **base / authoritative source**，自己只寫 delta。移除 superpowers 會讓這兩支變成殘篇。

### 功能對應：14 支裡只有 3 支有 mattpocock 對應物

| superpowers 6.2.0 | mattpocock 對應 | 移除後 |
|---|---|---|
| `test-driven-development` | `tdd` | ⚠️ 語意**不同**：superpowers 是 red-green-**refactor**，Matt v1.1 已把 refactor 移出迴圈。`mp-tdd` 建在前者之上，換底座會改變語意 |
| `systematic-debugging` | `diagnosing-bugs` | ✅ 可替換（`bug-fix-settlement` 的引用要改） |
| `writing-skills` | `writing-great-skills` | ✅ 可替換（`auditing-skill-folder` 的引用要改） |
| `requesting-code-review` / `receiving-code-review` | `code-review`（只覆蓋「發起」，**不覆蓋「接收回饋的紀律」**） | ⚠️ 半缺 |
| `brainstorming` | `grilling`（近似但非等價） | ⚠️ 近似 |
| `writing-plans` | `to-spec` + `to-tickets`（產物形狀不同：Matt 寫進 tracker，superpowers 寫 plan file） | ⚠️ 形狀不同 |
| `executing-plans` | `implement`（15 行 vs superpowers 的完整流程） | ⚠️ 大幅退化 |
| `subagent-driven-development` | — | ❌ **無** |
| `dispatching-parallel-agents` | — | ❌ **無** |
| `verification-before-completion` | — | ❌ **無**（且這支正對應 `[T0-2]`） |
| `finishing-a-development-branch` | — | ❌ **無**（`[INT-1]` 直接點名它） |
| `using-git-worktrees` | — | ❌ **無** |
| `using-superpowers` | `ask-matt`（router，但 Matt 版不含「skill 優先於直覺」那套強制語言） | ⚠️ 性質不同 |

**淨結果：14 支裡 2 支可乾淨替換（`systematic-debugging`、`writing-skills`）、7 支退化或半缺、5 支無對應物**，其中 `verification-before-completion` 與 `finishing-a-development-branch` 分別被 `[T0-2]` 與 `[INT-1]` 直接依賴。

### 判定

**不建議移除 superpowers。** 換得的 ~771 tok/session（0.6% smart zone）不足以支付：12 處引用改寫 + 5 支無對應物 + `mp-tdd` 底座語意變動 + `[INT-1]`/`[T0-2]` 的載體消失。

若真要降 superpowers 成本，有一個**零風險的局部手段**：SessionStart hook 注入的 766 tok 是 `hooks.json` 的 `SessionStart` matcher `startup|clear|compact` 造成的。要不要保留那個 hook 是獨立於「移不移除 plugin」的決定——但注意它同時是 superpowers「skill 優先」紀律的執行機制，關掉等於關掉那套強制。

## 2.5 若仍決定移除 superpowers：執行順序

上面的判定是建議，不是否決。若使用者權衡後仍要執行，按此順序做——**每一步結束時系統都處於可用狀態**，沒有中途破窗：

1. **先斷引用，後拔 plugin。** 改寫 7 個檔案的 12 處引用，plugin 保持安裝。這一步單獨做完全安全，且可獨立回退。做完跑 `grep -rn "superpowers:" ~/.agents/skills/` 應回 0。
2. **`verification-before-completion` 與 `finishing-a-development-branch` 必須先安置好新家。** `[T0-2]`（無 evidence 不得宣稱 done）與 `[INT-1]`（收尾 skill 只在 S4/S5 全 PASS 後 invoke）直接點名它們。**先 re-home 再移除**，否則會出現「gate 存在但無載體」的空窗。選項：內聯進 `dev-workflow` S4/S6、或把這兩支單獨 vendored 保留。
3. **`mp-tdd` 換底座是語意決定，不是機械替換。** superpowers 是 red-green-**refactor**，Matt v1.1 把 refactor 移出迴圈到 code-review。**先決定要哪種語意**，再改 `mp-tdd/SKILL.md:3,10,60` 與 `references/tracer-bullet.md:3`。兩種都自洽，但混用會讓 refactor 時機無主。
4. **五支無對應物逐一裁決**：`using-git-worktrees`、`subagent-driven-development`、`dispatching-parallel-agents` 損失面較小（可接受損失或內聯）；另兩支見第 2 點。裁決結果寫進 `dev-workflow` 的 Claude adapter 段，不要留空引用。
5. **最後**才把 `~/.claude/settings.json:170` 的 `"superpowers@claude-plugins-official"` 翻為 `false`。
6. **驗收三項**：`grep -rn "superpowers:" ~/.agents/skills/` = 0；`agents-sync --check` 綠（記憶：dry-run 先看將寫入什麼）；三家 loader 探針重跑（`codex debug prompt-input` / `copilot skill list` / Claude skill listing）確認無斷鏈。

**回滾點**：步驟 1–4 都只改 `~/.agents`（已 git 化，可 revert）；步驟 5 是單一 boolean，翻回即復原。真正不可逆的只有「刪掉被 re-home 的內容」，所以第 2 步務必用複製而非搬移。

## 3. 最終建議

三件事，按 CP 值排序，彼此獨立：

| # | 動作 | 成本 | 收益 |
|---|---|---|---|
| **1** | **本機 50 個 skill 導入 user/model 二分**——編排型（`dev-workflow`、`sdd`、`deps-check`、`init-project-docs`、`acquire-codebase-knowledge` 等）標 `disable-model-invocation`，紀律型維持 model-invoked | 小（改 frontmatter） | **Claude 端**最大單項 context 節省；Codex 端見下註 |
| **2** | **Matt overlay 嫁接進 S1–S3 + S5**（兩份建議的交集）：S1 `wayfinder`（超大型才切）、S2–S3 `to-spec`/`to-tickets` + smart zone 預算、S5 two-axis review、跨 session `handoff`、設計不確定時 `prototype`/`research` | 中 | 補齊四個真缺口，gate 不動 |
| **3** | **`mp-*` 挑差異手動套 v1.1**（非整包重抓）：`mp-tdd` 的 refactor 位置、`mp-grill-with-docs` 的 grilling 三修 | 小 | 消除已知落差 |

**註（建議 #1 的三家適用性，2026-07-27 實測）**：

- **Claude**：支援 `disable-model-invocation: true`（本 session 的 skill listing 行為即證據）
- **Codex**：**其 plugin validator 明確要求該欄位必須為 false**——`~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py:447-453` 對 `disable-model-invocation not in (None, False)` 直接 `errors.append(... must be false)`。這是**間接證據**（validator 管的是 plugin 打包，`~/.agents/skills` 走的是 skill root `r1` 路徑，未直接驗），但方向很清楚：**Codex 的 skill model 裡沒有 user-invoked 這個概念**，別指望 Codex 端省到 context
- **Copilot**：仍未定。先前查到的 `superpowers-marketplace/.../RELEASE-NOTES.md:717` 講的是 Claude slash command，不是 Copilot 支援聲明

**因此建議 #1 的收益應按「Claude 端有效」估**，不是三家全省。Claude 是主力 host，這條仍是三項裡 CP 值最高的，但別按 4,424 tok × 3 家估。若日後要在 Codex 端也省，得走另一條路（減少 skill 數量或縮短 description），不是這個欄位。

**不做**：移除 superpowers（§2；若仍要做見 §2.5 的順序）、整套取代 `dev-workflow`（03-migration）、`setup-matt-pocock-skills`（兩份建議一致反對）。

導入 Matt skill 時採 Codex 提的兩個 caveat：`resolving-merge-conflicts` 的「never abort」與 `research` 的自動寫檔，都要被 tier0 授權規則包住，不得凌駕。

依 `[T0-8]`，上述任一項動手前都要先出計畫並取得確認——本檔是分析，不是授權。
