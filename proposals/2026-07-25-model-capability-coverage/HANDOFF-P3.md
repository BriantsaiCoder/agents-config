# P3 待辦 Handoff · 2026-07-25 **rev.2**

> 給新 session 的自足指令。**先讀本檔，不必重讀完整報告** —— 需要細節時再看同目錄的 `00-report.md`（§編號已標在各項）。
> 主力 stack：ASP.NET Core / .NET、Vue、React、TypeScript、Node.js

**rev.2 做了什麼**（rev.1 寫於 13:46，之後 19:53–21:20 有大量變動 + 官方發布新指引）：

1. 依 [Anthropic《The new rules of context engineering for Claude 5 generation models》](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models) 與 [《Prompting Claude Opus 5》](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5) 逐條重審全部 P3 項目。
2. 補上 rev.1 缺的**貫穿判準**（§1）：這套設定三家共用，blog 的規則只對 Opus 5 校準，套錯層會弱化 Codex / Copilot。
3. 補上 rev.1 缺的**成本模型**（§2）：rev.1 用「行數」當 context 成本，是錯的度量；換成 always-on / on-invoke / on-demand 三層實測後，P3-2 整項要重寫。
4. 逐項標狀態：**已完成 3 · 已過期 2 · 已修正 3 · 仍有效 9 · 新增 5**。狀態表見 §0。

---

## 0. 狀態總表

三個 config repo 皆已上遠端（全 PRIVATE）、`main` 皆與 origin 同步：

| Repo | rev.1 記載 | **實測 main（22:00）** | CI |
|---|---|---|---|
| `BriantsaiCoder/agents-config` (`~/.agents`) | `44bb642` | **`2a951a5`** | 5 檢查 |
| `BriantsaiCoder/dotclaude` (`~/.claude`) | `cbc8e20` | **`aa8ab81`**（+2 PR） | **無**（見 P3-8） |
| `BriantsaiCoder/dotcodex` (`~/.codex`) | `bd1195d` | `bd1195d` | 5 檢查 |

| 項 | 狀態 | 一句話 |
|---|---|---|
| P3-1 非主力 stack archive | 🟡 仍有效（判準補強） | 仍待你裁決「死 or 眠」；blog rule 3 不支持 archive，收益校正見 §2 |
| P3-2 skill 內部瘦身 | 🔴 **已過期，整項重寫** | 最大標的 design-doc-mermaid 已進 attic；殘餘命名標的僅約 0.7% 語料 → 見 P3-2 新版 |
| P3-3 `/plugin` 評估零用量 inline plugin | 🟠 **已修正**（方法有瑕疵） | 結論成立但驗證指令會回傳 32 個含 6 個誤判 + 4 個垃圾 key；真標的是 **22** 不是 15 |
| P3-4 ultracode + subagent 上限 | 🟠 **已修正** | 官方原文比 rev.1 更強；但「掃 skill 刪 self-check 散文」實測 **no-op（已乾淨）** |
| P3-5 `settings.json` 兩項選配 | 🟡 仍有效 | 併入 §5「只有你能做的事」 |
| P3-6 `stitch.env` rotate | 🟡 仍有效 | 未外洩，本機明文仍在 |
| P3-7 a–j 技術 follow-up | 🟡 仍有效（逐項實測狀態已標） | b 的敘述需修正；c 維持原判 |
| P3-8 `~/.claude` 無 CI | 🟡 仍有效 | 已確認仍無 `.github/workflows/` |
| P3-9 | ⚫ 不存在 | rev.1 §0 表格指向「見 P3-9」但全檔無此項 —— 該指向 P3-8 |
| CLAUDE.md rule 4 去重 | ✅ **已完成** | commit `feb7844`，10393B→9973B |
| CLAUDE.md rule 5 auto-memory | ✅ **已完成** | 同 commit，Self-Maintenance 已收斂為單一落點 |
| skill 52→51 | ✅ **已完成** | `design-doc-mermaid` → `~/.agents/attic/`（PR #5） |
| N1 rule 6「rich references」 | 🆕 新增 | blog 唯一「要加不要減」的規則；本庫幾乎沒做 |
| N2 `/doctor` 機械化 rightsizing | 🆕 新增 | CLI 2.1.220 已內建；**取代 P3-2 的手工稽核** |
| N3 ecpay SKILL.md 818 行 | 🆕 新增 | 全庫唯一真正的 progressive-disclosure 違反（次大 143 行） |
| N4 Opus 5 scope 擴張傾向 | 🆕 新增（已對齊） | `[T2-8]` 已覆蓋 —— 記錄為「已對齊」，不要重複加規則 |
| N5 Opus 5 回覆長度 | 🆕 新增 | `effort` 調不動可見輸出長度，只有明示 prompt 有效 |

**已結案、不要再議的結論**（rev.1 三條，全數維持）：

1. **51 個 skill、3 個 agent 全部不可移除** —— 五軸判準（機械執行／工具鏈存取／乾淨 context 獨立審查／家規程序／版本釘死事實），只有五軸全 FAIL 才算可移除，實測 0 個符合。判準見 memory `skill-removability-five-axes`。
   ⚠️ **與下表「52→51」不矛盾**：`design-doc-mermaid` 的移除**不走五軸** —— 它是 0 本地修改的誤 fork vendored skill，屬另一條獨立判準（memory `vendored-skills-no-local-restructure`，19:24–19:43 實測）。五軸的「0 個可移除」仍然成立。**blog 未動搖此結論**：blog 講的是「skill 內容怎麼寫」（輕量、漸進揭露、只放你／團隊特有的意見），不是「skill 該不該存在」，且明文說 skills 正是編碼團隊特有 opinion 的地方。
2. **`[T0-3]` force-push guard 已修**：五個破口 + 一個 fail-open 全關；單一正本 `~/.agents/hooks/guard-git-push.sh` + 兩薄 wrapper；68-case 雙格式測試已進 CI。
3. **用量數據的權威來源是 `~/.claude.json` 的 `skillUsage`**，不是 grep transcript。實測 31/51 觸發（61%），且被 corpus 汙染（87% 任務來自零前端的 .NET ETL 專案）—— **禁止用用量裁剪前端 skill**。

---

## 1. 貫穿全案的判準：Claude 5 的規則只能套在 Claude 層

**這是 rev.1 最大的缺口。** blog 的六條規則全部是對 Opus 5 / Fable 5 校準的，而本庫的常駐規則層是**三家共用同一份 bytes**：

```
~/.claude/core/tier0-safety.md    → symlink → ~/.agents/core/tier0-safety.md
~/.claude/core/tier1-workflow.md  → symlink → ~/.agents/core/tier1-workflow.md
~/.claude/core/tier2-style.md     → symlink → ~/.agents/core/tier2-style.md
```

三檔 frontmatter 皆為 `consumed-by: claude,codex,copilot`。為了 unhobble Claude 而砍共用層，等於同步弱化 GPT-5.x 兩家 —— 而 `core/routing.md:6` 自己記著 Codex 端的實測劣勢（「description 被截斷至 2–6 字元，路由靠點名不靠 description」）。

**先例已確立**：commit `feb7844`（20:17）做第一輪 Claude 5 對齊時，只改 `~/.claude/CLAUDE.md`，`~/.agents/core` 四檔**一字未改**，並在 commit body 明文寫下理由。rev.2 沿用同一判準。

### 層級對照表（動手前先查這張表）

| 層 | 檔 | 可否套 blog 規則 | 理由 |
|---|---|---|---|
| Claude 專屬常駐 | `~/.claude/CLAUDE.md` | ✅ 可 | 只有 Claude 讀；agents-sync 只量它的 bytes（`bin/agents-sync:195`），不生成它 |
| 三家共用常駐 | `~/.agents/core/tier0-2` | ❌ **不可** | symlink 同一份；放鬆會弱化 Codex / Copilot |
| 三家共用路由 | `~/.agents/core/routing.md` | ⚠️ 僅可去重，不可放寬 | 同上；`[R-1]`/`[R-2]` 是機械 gate 不是風格規則 |
| Host delta | `hosts/codex-delta.md`、`hosts/copilot-delta.md` | ✅ 各自 | 只影響該 host |
| Skill 本體 | `~/.agents/skills/**` | ✅ 可（rule 1/2/3 全適用） | 三家都讀，但 skill 是「按需載入的指引」，blog 的漸進揭露規則對三家都是淨益 |
| 機械層 | hooks / tests / CI / lint | ❌ 不適用 | blog 談的是 prompt 層；機械證據要求不是「請再檢查一次」 |

### 一個結構限制（新發現，動手前要知道）

`hosts/` 只有 `codex-delta.md` 與 `copilot-delta.md`，**沒有 `claude-delta.md`**。agents-sync 的 target 表（`bin/agents-sync:24-25`）也只組裝 codex / copilot 兩家。

推論：**Claude 端沒有「從共用層減項」的機制**。要為 Claude 單獨放鬆某條 tier0-2 規則，唯一途徑是在 `CLAUDE.md` 寫 override 條款 —— 而 `feb7844` 剛剛才刪掉一條失效的 override（Comment Policy 那條在覆蓋一個已不存在的系統 default）。加新 override 是逆著剛整理好的方向走。

→ **實務結論**：`core/tier0-2` 對 Claude 而言是「照單全收」。若日後真有一條規則明確在 Opus 5 上有害，正確做法是建 `hosts/claude-delta.md` 並讓 agents-sync 也組裝 Claude 端，而不是在 `CLAUDE.md` 疊 override。這是架構決策，需要你裁決，目前**不建議做**（沒有實證有害的條文）。

### 六條規則對本庫的適用結論

| blog 規則 | 對本庫 | 落點 |
|---|---|---|
| 1. 給判斷，不給規則 | ⚠️ **部分適用** | 只適用「風格類」規則。tier0 是安全紅線、`[R-1]`/`[R-2]` 是機械 gate，blog 的例子（"never write multi-line docstrings"）是風格規則，不能外推到安全層 |
| 2. 設計介面，不給範例 | ✅ 適用 skill 層 | `design-doc-mermaid` 的 6 個 example README 已進 attic，方向正確。殘餘見 P3-2 |
| 3. 漸進揭露 | ✅ **本庫已大致達成** | 實測見 §2：51 個 skill 的 SKILL.md 中位數約 50 行，內容都在 `references/`。唯一違反是 ecpay（N3） |
| 4. 不要重複自己 | ✅ **已完成（殘餘一處為刻意）** | `feb7844` 已刪 dev-workflow SKILL.md 已覆蓋的路由複述。實測 `CLAUDE.md` 手寫 `## Skill Routing`（4 行）與機械 routing stamp（13 行）的具名 skill **交集只有 `agent-browser` 一項**，且**不該消除** —— `hosts/copilot-delta.md` 明文「勿假設 `~/.claude/CLAUDE.md` 在 context」，機械段那條是給 Codex／Copilot 用的。rule 4 的「單一權威來源」在此與 §1 的三家約束衝突，取三家可用 |
| 5. auto-memory 取代手工 CLAUDE.md | ✅ **已完成** | 同 commit；Self-Maintenance 已改為「規則進常駐層，教訓進 auto memory 單一落點」 |
| 6. rich references 取代 simple specs | 🆕 **未做** | 唯一「要加不要減」的規則 → N1 |

---

## 2. context 成本三層模型（rev.1 用錯了度量）

rev.1 的 P3-2 以「~8-9k 行」當瘦身目標、以「行數」隱含 context 成本。**這是錯的** —— 而且正是 blog 警告的那種錯：漸進揭露的重點不是「總量少」，是「不需要的不進 context」。

### 實測（2026-07-25 22:00，51 個 skill）

| 層 | 何時進 context | 實測量 | 可否用「刪行」降低 |
|---|---|---|---|
| **always-on** | 每個 session 都在 | `description` frontmatter 合計 **18,968 字元 ≈ 4.7k token** | ✅ 只能靠**減少 skill 數**或縮短 description |
| **on-invoke** | 該 skill 被叫時 | `SKILL.md` 本體：ecpay **818 行**、dev-workflow 143、deps-check 120、init-project-docs 114 …中位數約 50 行 | ✅ 靠把內容推到 `references/` |
| **on-demand** | agent 主動去讀該檔時 | `references/` 等 —— 語料 102,467 行的絕大部分 | ❌ **刪它不省任何 context** |

**ecpay 一項就佔語料 37,352 行（36%）、91 個檔**。rev.1 的 P3-2 完全沒提到它。但依上表，**這 37k 行不是 context 成本** —— 它分散在 91 個檔、按需讀取。真正的問題只有一個：它的 `SKILL.md` 是 **818 行**，是次大者（`dev-workflow` 143 行）的 **5.7 倍**，一被 invoke 就整段進 context。那才是 rule 3 的違反 → 拆成 N3。

### rev.1 三個「最大宗」的實測校正

| rev.1 宣稱 | 實測 | 判定 |
|---|---|---|
| `design-doc-mermaid/` examples + assets ~7,500 行 | **已不在 `skills/`**（PR #5 移入 `~/.agents/attic/design-doc-mermaid/`） | 🔴 已過期，標的消失 |
| security-review ∩ security-audit 「~500 行重疊」 | `vuln-categories.md` 281 + `language-patterns.md` 221 vs `security-audit/ATTACK-CLASSES.md` **僅 107 行** → 重疊上限 107 行 | 🟠 數字誇大約 5 倍 |
| `mp-tdd` 5 個附檔 194 行 | 194 行 ✓（另有 `references/tracer-bullet.md` 99 行） | ✅ 正確 |

**殘餘命名標的合計 ≲ 700 行 / 102,467 行 = 0.7%，且全在 on-demand 層（省 0 context）。**

→ **P3-2 依原框架已無施作價值。** 新版見下。

---

## 3. 動手前必須知道的五個環境約束

**① sandbox 擋 agent 寫 `~/.claude` 的 gate 檔案**（防禦設計，非故障）

```
❌ ~/.claude/settings.json    operation not permitted
❌ ~/.claude/hooks/           operation not permitted
❌ ~/.claude/CLAUDE.md、~/.claude/agents/、~/.claude/rules/
✅ ~/.agents/**  ~/.codex/**  ~/.copilot/**  ~/.claude/.github/（不在 deny 清單）
```

→ 任何動 `settings.json` 或 `~/.claude/hooks/` 的項目，**只能產出指令讓使用者自己貼**（統一收在 §5）。

**② guard 會擋「只是提到」危險 payload 的指令**（刻意的 fail-closed）

比對對象是整個 command 字串，所以 commit message、PR 回覆、測試腳本只要含 `git push --force` 之類字樣就會被擋。**變通：用 `git commit -F <file>`、`gh api --input -`、或先用 Write 工具建檔再引用路徑。**
`MUST NOT` 為消除此誤擋而改成解析 shell —— 會開出引號規避路徑（已寫進 guard 標頭）。

**③ 在 `~/.agents` 切分支會即時換掉 Claude 讀到的 skills**

`~/.claude/skills/*` 與 `~/.claude/core/*` 都是指向 `~/.agents/**` 的 symlink。曾踩過：`git checkout main` 成功但 `git pull --ff-only` 失敗，工作區停在舊版，skill descriptions 整批靜默回退且無錯誤訊息。
→ **動完分支必用內容抽查驗證**（grep 具體字串），不能只看 `git status`。已有三層防護（worktree 工作流 + post-checkout hook + doctor 戳記，PR #7/#8/#9）。詳見 memory `agents-branch-switch-silently-swaps-skills`。

**④ 驗證用的 dry-run 也可能弄髒狀態**

`AGENTS_DEPLOY_ROOT=<temp> bash bin/agents-sync` 會改寫 `dist/manifest.tsv` 但**不更新 live host 檔** → `conformance.sh` 立刻掉到 11 PASS / 1 FAIL。正常部署（`bash bin/agents-sync`）即復原。

**⑤ 🆕 `/doctor` 等終端對話框指令在非互動 session 不可用**

`/doctor`、`/plugin`、`/permissions`、`/config`、`/agents`、`/hooks` 都會開互動式終端面板。agent session 跑不了，**只能由你在互動式 `claude` 終端執行**。這直接影響 N2 與 P3-3。

---

## 4. P3 待辦（逐項）

### P3-1 🟡 仍有效 · 需要你先裁決：非主力 stack 要不要可逆 archive

**候選**：`c-cpp-best-practices`、`dotnet-framework-best-practices`、`ef6-best-practices`、`dotnet-winforms-best-practices`、`native-feel-cross-platform-desktop`、`ecpay`

**兩方立場都成立，差別在一個你才知道的事實 —— 這些 stack 是「死」還是「眠」**：

- 若**真的永不再碰** → archive 合理（Codex 立場）
- 若只是**休眠** → 不該 archive。每個都有「編譯過、線上炸」的軸 4/5 證據：EF6 `.Include(x=>x.A.Select(...))` vs EF Core `.ThenInclude()` 模型必寫錯；.NET Framework R4「library 加 `ConfigureAwait(false)`、controller 不加」模型會壓平成「一律加」而弄壞需要 HttpContext 的 controller；WinForms .NET 9 `InvokeAsync` 同步 overload 吞掉內層 Task（編得過、靜默不執行）

**額外事實**：`DCT_data_import` 本身是 net462→net8 的遷移產物，legacy 面浮出時會用到 EF6 / .NET Framework。

**🆕 blog 對此項的裁決傾向：不支持 archive。** rule 3（漸進揭露）的整個論點就是「不需要時不進 context，所以留著不貴」。而軸 5（版本釘死事實）正是 blog 說 skill 該存在的理由 ——「編碼你／團隊／產品特有的知識與最佳實踐」。archive 只換到 always-on 層的 description token。

**收益校正（實測）**：6 個候選的 description 合計 **2,844 字元 ≈ 711 token**（c-cpp 485／winforms 548／native-feel 654／framework 460／ef6 369／ecpay 328），佔 always-on 18,968 字元的 **14%**。**Copilot 也原生載入 `~/.agents/skills`**（`agents-sync --doctor` 探針欄已驗證），所以是兩家 × 711；Codex 端為 UNVERIFIED。做它是為衛生，不是為 context。

**⛔ 不可比照辦理**：`pinia`。`rules/frontend-spa.md:21` 明文列為家規既定選型（「State 共用 > 3 處才引入 Zustand / Pinia」）。以「目前無 Vue 專案」裁掉它，正是 corpus 汙染推論換一身衣服。`next` / `nuxt` 條件式保留則合理（僅 SSR/SEO 場景）。

**做法**：`mv` 到 `~/.agents/backups/<date>-stack-archive/`（不要 `rm`，且 `backups/` 已 gitignore），然後 `bash ~/.agents/bin/agents-sync` 重生 skill-index。**CI 會擋** index 與 `skills/` 不一致，所以一定要跑 sync。
（`attic/` 亦可 —— `design-doc-mermaid` 走的是 `attic/`，兩者慣例需擇一統一，見 P3-7 k。）

---

### P3-2 🔴 已過期 · 重寫為「on-invoke 層瘦身」

**原框架作廢**：目標從「刪 8-9k 行通用教材」改為「**把 on-invoke 層壓到 100 行以內**」。理由見 §2 —— 刪 on-demand 層省 0 context。

**新標的（實測 SKILL.md 行數，唯一有 context 效益的層）**：

| skill | SKILL.md 行數 | 判定 |
|---|---|---|
| `ecpay` | **818** | 🔴 必改 → 見 N3 |
| `dev-workflow` | 143 | 🟡 可審 —— 但它是 workflow 正本，S0 決策表必須一次看全；建議**不動** |
| `deps-check` | 120 | 🟡 可審 |
| `init-project-docs` | 114 | 🟡 可審 |
| `react-router-framework-mode` | 108 | 🟡 可審 |
| 其餘 46 個 | ≤ 107，中位數約 50 | ✅ 已符合 rule 3 |

**Codex 提的四路分流仍然有效，但只在「該內容原本在 SKILL.md」時才有 context 收益**：

| 內容類型 | 去處 |
|---|---|
| 專案 house rules | 移到 `CLAUDE.md` / `rules/*.md` |
| 可機械驗證的規則 | 移到 hook / lint / test（`deps-check/SKILL.md:36` 已實證「hook 100% 觸發、skill 約 50%」） |
| 大量範例與通用教學 | 移到 `references/`（**不是刪** —— blog rule 2 說範例會限縮探索空間，但移走比刪掉安全） |
| **版本敏感資訊** | **保留**，但補 `last-verified` 戳（`reviewer-template.md:1` 已有此慣例） |

**注意**：軸 5（版本釘死）的段落**一律不動** —— 那正是模型愈強愈會寫錯的部分（Next 16 `proxy.ts`、Vitest 3 `projects`、Vite 8 `rolldownOptions`、EF6 vs EF Core、MySQL 8.0.16 前 `CHECK` 靜默丟棄）。

**先做 N2（`/doctor`）再做這項** —— 官方已把同一件事機械化，手工稽核應該只補 `/doctor` 沒覆蓋的部分。

**驗收**：`bash ~/.agents/bin/agents-sync --check` lint PASS + `~/.agents/tests/conformance.sh` 12 PASS。CI 會擋 dist 不同步。

---

### P3-3 🟠 已修正 · 需要互動式 session：`/plugin` 評估零用量 inline plugin

**結論仍成立**（這是唯一「移除真的能省 context」的地方，且與模型能力完全無關），**但 rev.1 的驗證指令會誤導下一個 session。**

實測 rev.1 那段 python 回傳 **32** 個 `@inline` 零用量 key，不是 15。拆解：

| 類別 | 數 | 內容 | 可否停用 |
|---|---|---|---|
| rev.1 列的真標的 | 15 | `anthropic-skills` `data` `marketing` `finance` `product-management` `operations` `pdf-viewer` `figma` `productivity` `design` `legal` `sp-global` `desktop-commander` `mongodb` `firecrawl` | ✅ 是標的 |
| 🆕 rev.1 漏列的真標的 | **7** | `clangd-lsp` `claude-code-setup` `commit-commands` `dotnet-msbuild` `feature-dev` `github` `ui-ux-pro-max` | ✅ 也是標的 |
| ⚠️ **誤判** | 6 | `chrome-devtools-mcp` `claude-md-management` `csharp-lsp` `frontend-design` `skill-creator` `typescript-lsp` | ❌ **不可停用** —— 各有一個 `@claude-plugins-official` 孿生 key 且 `enabledPlugins` 為 `true`，用量記在另一把 key 上 |
| 垃圾 key | 4 | `0.1.0` `0.2.0` `1.0.0` `da20c92503b2` | — 版號／hash 誤入 `pluginUsage` |

→ **真標的是 22 個，不是 15。** 且 `@inline` 零用量**不等於**未使用 —— 必須先排除有啟用孿生 key 的。

**修正後的驗證指令**（會自動排除孿生誤判與垃圾 key）：

```bash
python3 -c "
import json, os, re
d = json.load(open(os.path.expanduser('~/.claude.json')))
enabled = {k.split('@')[0] for k, v in json.load(open(os.path.expanduser('~/.claude/settings.json'))).get('enabledPlugins', {}).items() if v}
for k, v in sorted(d.get('pluginUsage', {}).items()):
    if v.get('usageCount', 0) or not k.endswith('@inline'): continue
    name = k.split('@')[0]
    if re.fullmatch(r'[0-9a-f.]+', name): continue          # 版號／hash 垃圾 key
    if name in enabled: continue                            # 用量記在 marketplace 孿生 key
    print(' ', name)
"
```

**為什麼不能改 `settings.json` 解決**：這 22 個都不在 `enabledPlugins`（22 項）也不在 `installed_plugins.json`（23 項）—— `@inline` 代表由 Claude Code 桌面版 binary 內建（實體在 `~/.local/share/claude/ClaudeCode.app`，磁碟上沒有 SKILL.md）。**只能在互動式 session 用 `/plugin` 確認能否停用。**

它們貢獻的 skill 條目數遠大於 51 個個人 skill 的 4.7k token（本 session 的 available-skills 清單裡，plugin skill 條目約 90+ 條）。

---

### P3-4 🟠 已修正 · `ultracode` + subagent 上限（Opus 5 的行為反轉）

**官方原文比 rev.1 的轉述更強、更具體。** [《Prompting Claude Opus 5》](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5) 三條直接相關：

1. **subagent**：「Claude Opus 5 delegates to subagents more readily than prior models」；「delegate **only** for large tasks that are genuinely independent and parallelizable」；「**do not use subagents to verify or double-check your own work**」；「**If one subagent can complete the task, use one rather than several, and keep spawn counts low**」。
   → rev.1 建議的「不超過 20 個平行 agent」**太寬鬆**。官方是「能一個就一個、盡量少開」。
2. **verification**：「If your prompt contains explicit verification instructions（"include a final verification step for any non-trivial task"、"use a subagent to verify"）, **remove them**: instructions like these cause over-verification on Claude Opus 5, and removing them **reduces wasted tokens with no loss in quality**」。
   → 與 blog 的「砍掉 Claude Code 系統提示 80% 而 coding eval 無可測退化」互相佐證。
3. **scope**：「Claude Opus 5 can also **expand the scope** of a task, adding steps that weren't requested」→ 見 N4。

`~/.claude/settings.json` 目前 `ultracode: true`、`alwaysThinkingEnabled: true`，每個實質任務預設走 workflow 多 agent 編排。**rev.1 那場 workflow 一次 1.59M token。**

**若 token 成本是考量，這是唯一有兩個數量級效果的旋鈕**（archive 6 個 skill 省 711 token 常駐；一場 workflow 1.59M）。

兩個選項：
- 關掉 `ultracode`，改為按需要求（需你改 `settings.json`，見 §5）
- 保留但加 subagent 節制條款。**落點必須是 `~/.claude/CLAUDE.md`，不是 `~/.agents/core/`** —— 依 §1 判準，這是 Opus 5 專屬的行為校正，Codex / Copilot 是 under-reach 需要鼓勵，套上去會反向弄壞它們。

建議條文（Claude 層，逐字可貼）：

```markdown
## Subagent 節制（Opus 5 專屬；Codex / Copilot 不適用）
- 派 subagent 只用於「大、真正獨立、可平行」的工作（如跨檔廣掃）。自己幾個 tool call 能做完的不派。
- 能一個 agent 做完就只開一個；平行數保持低位。
- MUST NOT 用 subagent 驗證或覆核自己的產出 —— 驗證屬主 loop（不影響 [T0-2] 的機械證據要求）。
```

**🟠 同批應做那條，實測是 no-op：** rev.1 要求「掃 `~/.agents/skills/` 刪 `double-check` / `re-verify` / `verify before responding` 類散文」。實測 grep（含中文 `再檢查` / `再次確認` / `自我檢查`）全庫僅 **6 檔命中，全是領域正當用法**：

- `ecpay`（4 檔）：`TransCode` → `RtnCode` 是綠界站內付 2.0 的**雙層錯誤結構協定**，不是自我檢查散文；「正式上線前須重新確認」是 SNAPSHOT 參數表的時效聲明
- `typescript-best-practices`：「compile-time check」，無關
- `auditing-skill-folder/SKILL.md:38`：「Last audit kept all, trust it → re-verify, don't recurse」是防遞歸信任的稽核判準

→ **prompt 層自我檢查散文本庫已乾淨，此條記為 no-op、不需施作。** 保留這筆負面結果，避免下一個 session 重掃。

**⛔ 不含** `dev-workflow` S4 的四態 gate 與 `[T0-2]` evidence 要求 —— 那是機械證據要求，不是「請再檢查一次」。官方要刪的是「請做最後驗證步驟」這種**無條件 prompt 層叮嚀**，不是「跑 test 並附輸出」這種可查證的產物要求。

**🆕 一個相關但獨立的觀察（superpowers）**：

- `superpowers` 實載 **6.2.0**。`using-superpowers/SKILL.md` 每個 session 由 plugin 自帶 hook 全文注入（`settings.json` 的 SessionStart 三條 hook 不含它），**62 行 / 3,063 B ≈ 766 token always-on**。
- 上游自己已在做 Claude 5 方向的瘦身：6.0.3 是 5,899 B → 6.2.0 是 3,063 B（**−48%**）。
- `verification-before-completion`（6.2.0 仍在，120 行）內容是「Rationalization Prevention」「Red Flags — STOP」「NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE」—— **形式上正是官方說要刪的那類**。但實測**本庫沒有任何 live 路由指向它**（全庫唯一引用在 `~/.agents/attic/AGENTS.md:79`，已進 attic）。
  → **判定：已 inert，不需行動。** 記錄下來，避免日後有人重新把它接進 `CLAUDE.md` 或 `core/routing.md`。
- superpowers 整個 plugin **不可停用**：`CLAUDE.md:19` 路由到 `systematic-debugging` / `test-driven-development`，`core/routing.md` 的 `[R-1]` 具名 `finishing-a-development-branch`，`dev-workflow/SKILL.md:73,125` 具名 5 個。且它是 vendored（memory `vendored-skills-no-local-restructure`），也不能就地改。
- 磁碟上有 4 個 cached 版本（5.1.0 / 6.0.3 / 6.1.1 / 6.2.0），只佔磁碟不佔 context。

---

### P3-5 🟡 仍有效 · `settings.json` 兩項選配

→ 已併入 §5。

---

### P3-6 🟡 仍有效 · `stitch.env` 明文 key rotate

`~/.codex/stitch.env` 內有明文 key（memory `three-host-config-audit-facts` 記著「stitch key 明文待 rotate」）。
**未外洩** —— gitleaks 掃 `~/.codex` 完整歷史 11 commits / 192KB 無洩漏，且該檔未被追蹤（`.gitignore` allowlist 模式）。CI 現有「追蹤面未擴大」檢查會擋它被誤加入版控。
但本機明文存在，rotate 仍應做。

---

### P3-7 🟡 仍有效 · 累積的技術 follow-up（狀態已逐項實測）

| # | 狀態 | 項目 | 位置 / 證據 |
|---|---|---|---|
| a | 🟡 仍開 | `postgresql-best-practices` 補 PG 18 原生 UUIDv7 | `references/schema-design.md:63` 仍寫「PostgreSQL does not natively generate UUIDv7」，而 `postgresql-optimization/references/performance.md:123` 寫「UUIDv7 (PG 18+)」。**不是相反建議，是 sibling 早於 PG 18**。補完後才談 archive |
| b | 🟠 **敘述需修正** | `typescript-best-practices` 補家規 | 「NEVER barrel exports」（`rules/typescript.md:10`）在 skill 內無對應條文 → **仍開**。但「React 側缺 `eslint-plugin-jsx-a11y`」**不準確** —— 實測 `init-project-docs/references/rules/frontend.md:12` 與 `next-best-practices/references/project-init.md:79` 都有；真正的缺口是 `react-best-practices` 自身沒有 |
| c | ✅ 維持原判 | `agent-browser/references/webgpu.md:63` 的 `node:22` | 刻意保留（上下文寫「Verified with both Chrome for Testing and Debian's chromium」，Node 22 仍在 LTS）。下次實測 WebGPU 路徑時一併驗 Node 24 |
| d | 🟡 仍開（仍 ASSERTED） | `tailwind-v4-shadcn/rules/tailwind-v4-shadcn.md:2` 的 `paths:` frontmatter 是否會被自動注入 | 檔案仍在、仍未實測。判為不會（inline 逗號串格式與 `rules/typescript.md:2-5` 的 block-sequence 不同，且位於 skill 子目錄）。verdict 兩種情況都是 KEEP，但本報告論旨含「假防線宣稱 = bug」，不該自留未測宣稱 |
| e | 🟡 仍開（已確認） | `~/.agents/hooks/drift-check.sh` 的 `doctor()` 加 routing stamp diff | 實測 `drift-check.sh` **無任何 `routing` 相關程式碼**；只驗 symlink 完整性與 core 三檔存在。agents-sync 註解自己記著「手動快照必 drift（實證 2026-07-08）」 |
| f | 🟡 仍開（已確認） | `~/.claude/hooks/audit-bash.sh` 改註冊 `PostToolUse` + 修 `~/.agents/CONVENTIONS.md:11` | 實測仍掛 `PreToolUse` + `async: true`，**依定義無法攔截**，且記錄的是「嘗試」非「執行」。`CONVENTIONS.md:11` 仍把它列為 `[T0-3]` 的驗證機制 = **假防線宣稱**。hook 註冊需改 `settings.json`（見 §5），CONVENTIONS.md agent 可改 |
| g | 🟡 仍開（已確認） | `autoMode.environment` 宣稱 PostgreSQL 與實況不符 | 實測 `environment[4]` 仍為「Preferred stacks: .NET 8 / ASP.NET Core, EF Core, **PostgreSQL**, Vite + React/Vue, Tailwind, Docker Compose」。7 個專案 PG **0 命中**，唯一有 DB 的是 MySQL（17 檔）。會讓 classifier 系統性偏斜（預設產 PG 語法、預設選 Npgsql）。需改 `settings.json`（見 §5） |
| h | 🟡 仍開 | `permissions.deny` 補 reader 清單 | 硬層只擋 `cat`/`grep`/`sed` 四個動詞；`autoMode.soft_deny` 已枚舉 11 個 reader，同步進硬層即可對齊。需改 `settings.json`（見 §5） |
| i | 🟡 仍開 | `permissions.allow` 清掉四條對應已停用 `github` plugin 的 mcp 規則 | 純衛生（`github@claude-plugins-official` 實測為 `false`）。需改 `settings.json`（見 §5） |
| j | 🟡 仍開 | `~/.codex/.github/workflows/ci.yml:33` 的註解含字面 `/Users/pochientsai` | 目前無害（CI 掃描範圍是 `hooks.json hooks/ agents/`，不含 `.github/`）。但**若日後擴大 CI scope 到全檔，這條會自我誤報** |
| k | 🆕 新增 | `attic/` 與 `backups/` 兩套「可逆移除」慣例並存 | `design-doc-mermaid` 走 `attic/`（PR #5），P3-1 的做法寫 `backups/`。兩者語意重疊，應擇一並寫進 `CONVENTIONS.md`，否則下一次 archive 會再猜一次 |

---

### P3-8 🟡 仍有效 · `~/.claude` 沒有 CI

實測 `dotclaude` repo 仍無 `.github/workflows/`（已有 2 個 merged PR，但零檢查）。它裝的是 `settings.json`、`hooks/`、`agents/`、`commands/`，其中 `settings.json` 是承載整個 permissions / sandbox / autoMode 機械層的檔案。

可加的檢查（agent **可**寫 `.github/`，那不在 sandbox deny 清單內）：
- `settings.json` JSON 合法 + `$schema` 存在
- `autoMode` 三段皆以 `"$defaults"` 開頭（**省略即整段取代不是疊加**，見 memory `claude-automode-defaults-and-async-hooks`）
- `permissions.deny` 條數不減少（防止有人悄悄放寬）
- `hooks/*.sh` shellcheck
- 無硬編碼家目錄（`~/.claude/hooks/` 已有 wrapper 用 `$HOME`）
- 🆕 `hooks` 內若出現 `async: true` 且事件為 `PreToolUse`，fail —— 直接把 P3-7 f 的假防線類型機械化

（rev.1 §0 表格寫「見 P3-9」是筆誤，該指向本項。）

---

### 🆕 N1 · blog rule 6：rich references 取代 simple specs

**唯一「要加不要減」的規則，本庫幾乎沒做。** 官方原話：references 可以是「HTML artifacts…detailed test suite[s], or a function in a different codebase…**Rubrics**」，理由是 code 提供高保真指令、Claude 5 處理複雜 reference 的能力足夠。

現況：`~/.agents/skills/**` 幾乎全是 markdown 散文。**唯一已是 rubric 形狀的是 `dev-workflow/references/reviewer-template.md`** —— 所以這是補缺口，不是從零開始。

三個具體機會（依價值排序）：

1. **`dev-workflow` S4 四態 gate → 可執行的 rubric 檔**。目前是散文描述「四態全 PASS 才放行」。改成一份結構化 rubric（每態的判定條件 + 證據形式 + FAIL 樣例），Claude 5 對 rubric 的遵循度優於散文，且能直接餵給 review subagent。
2. **`[T0-2]` evidence 要求 → 範例輸出而非規則描述**。「MUST NOT 無 evidence 宣稱 done」是規則；附一份「合格的驗證證據長什麼樣」的實際 test 輸出片段，是 reference。後者不需要 override 共用層（是**加**在 skill 側，不是改 `core/`）。
3. **版本釘死事實 → 可跑的最小 repro 而非文字警告**。例：`dotnet-winforms-best-practices` 的「.NET 9 `InvokeAsync` 同步 overload 吞掉內層 Task」目前是文字；一段 8 行可編譯的 repro 更難被模型讀錯。這條同時強化 P3-1 的「休眠不是死」論證。

**注意**：這項會**增加** on-demand 層行數。依 §2 的成本模型那是免費的（不進 context），但會讓「總行數」數字上升 —— 別把它誤讀成退步。

---

### 🆕 N2 · `/doctor` 已把 P3-2 機械化（先做這個）

blog 的唯一具體工具建議：「We've put these best practices in `claude doctor`; use the command **`/doctor`** in Claude Code to **rightsize your skills, and CLAUDE.md files**」。

**已驗證存在**：CLI **2.1.220** 的 binary 內含 `cli_skill_doctor` / `skill-doctor` 字串。

**必須由你在互動式終端跑**（見 §3 ⑤，agent session 開不了面板）：

```bash
claude
```

進去後執行 `/doctor`，針對這兩個目標：
- `~/.agents/skills/**`（51 個，經 `~/.claude/skills/*` symlink 可見）
- `~/.claude/CLAUDE.md`

**做完再回頭做 P3-2** —— 手工稽核只補 `/doctor` 沒覆蓋的部分，並把它的判定與 §2 的三層成本模型交叉比對（若 `/doctor` 也以總行數為度量，以 §2 為準）。

⚠️ **`/doctor` 的建議不可無條件照做**：它不知道 §1 的三家共用約束（會把 `~/.claude/core/*` 當 Claude 專屬檔），也不知道軸 5 版本釘死事實是刻意保留的。**任何指向 `core/tier0-2` 的瘦身建議一律拒絕**，理由見 §1。

---

### 🆕 N3 · `ecpay/SKILL.md` 818 行 —— 全庫唯一真正的 rule 3 違反

**事實**：`ecpay` 的 `SKILL.md` 是 818 行，次大者 `dev-workflow` 是 143 行（**5.7 倍**）。整個 skill 有 91 個檔 / 37,352 行，但只有 SKILL.md 這 818 行是 on-invoke 成本。

**這是 P3-2 該做的那一件事**，而 rev.1 完全沒提到。

**做法**：把 SKILL.md 收斂成「路由表 + 何時讀哪個 `guides/`」的薄層（目標 ≤ 100 行，與其餘 50 個 skill 一致），內容推進既有的 `guides/` / `docs/` / `references/`（那些檔已經存在，結構是現成的）。

**與 P3-1 的關係**：`ecpay` 同時是 P3-1 的 archive 候選。若你裁決 archive，N3 自動消失。**若不 archive，N3 必做** —— 它是本庫最大的單一 on-invoke 成本。建議先裁決 P3-1。

**另有 4 個檔是同一 skill 的跨 host 複本**（`SKILL_OPENAI.md` / `AGENTS.md` / `GEMINI.md` / `SKILL.md`），內容高度重疊。收斂時一併確認是否仍需四份。

---

### 🆕 N4 · Opus 5 的 scope 擴張傾向 —— 已對齊，不要重複加規則

官方：「Claude Opus 5 can also **expand the scope** of a task, adding steps that weren't requested or applying its own judgment about what the task should be. For narrow tasks, **constrain scope explicitly**」。

**本庫已覆蓋**：`core/tier2-style.md` 的 `[T2-8]`「Scope 外發現 MUST 分列 follow-up，未確認 MUST NOT 實作。觸發：旁支。例外：命中 [T0-1]–[T0-9] 立即提出。驗證：diff 無旁支且回覆分列。」

→ **記錄為「已對齊」。** 特意寫進來的理由：避免下一個 session 讀到官方那段後，在 `CLAUDE.md` 或 `core/` 再加一條同義規則 —— 那會直接違反 blog rule 4（不要重複自己），也違反 §1（不該動共用層）。

---

### 🆕 N5 · Opus 5 回覆長度：`effort` 調不動，只有明示 prompt 有效

官方：「Claude Opus 5's default user-facing responses run longer than prior Opus models'. The `effort` parameter controls **how much the model thinks** rather than **how much it says**: lowering effort can reduce thinking volume without reliably shortening the visible response. **To control response length, prompt for it explicitly**」。

**本庫現況**：`core/tier2-style.md` 的 `[T2-6]` 已要求 outcome-first、「首段有結論／結果／阻塞／問題，結尾非客套」—— 這約束了**結構**，沒約束**長度**。`settings.json` 有 `effortLevel` 鍵。

**判定**：低優先。若你實際覺得回覆偏長，落點是 `~/.claude/CLAUDE.md`（Opus 5 專屬，§1 判準），不是 `[T2-6]` —— Codex / Copilot 沒有這個傾向。**不建議現在做**：這是體感問題，等你確認確實困擾再處理，否則就是憑官方一句話加一條沒實證需求的規則。

---

## 5. 只有你能做的事（agent 寫不了 —— 統一收在這裡）

sandbox 擋 agent 寫 `~/.claude/settings.json` 與 `~/.claude/hooks/`（§3 ①），且終端對話框指令需互動式 session（§3 ⑤）。以下按價值排序。

### A. 互動式終端（開 `claude` 後執行）

```bash
claude
```

| 指令 | 目的 | 對應項 |
|---|---|---|
| `/doctor` | rightsize `~/.agents/skills/**` 與 `~/.claude/CLAUDE.md`（**先做這個**，再做 P3-2） | N2 |
| `/plugin` | 停用 22 個真零用量 `@inline` plugin（清單與修正後查詢見 P3-3） | P3-3 |

### B. `settings.json` 手動編輯

**價值最高（P3-4，兩個數量級）：**

```
"ultracode": true    →  false（或刪除）
```
關掉後改為按需在 prompt 裡明確要求 workflow 編排。理由：一場 workflow 1.59M token vs archive 6 個 skill 省 711 token。

**假防線修正（P3-7 f，最高正確性風險）：**

```
hooks.PreToolUse[matcher=Bash] 內的
  { "command": "~/.claude/hooks/audit-bash.sh", "timeout": 3, "async": true }
→ 移到 hooks.PostToolUse，並移除 "async": true
```
`async: true` 的 `PreToolUse` hook 依定義無法攔截，且記錄的是「嘗試」非「執行」。而 `~/.agents/CONVENTIONS.md:11` 正把它列為 `[T0-3]` 的驗證機制 = 假防線宣稱。（CONVENTIONS.md 那半邊 agent 可改，等你改完 hook 再一起做。）

**classifier 偏斜修正（P3-7 g）：**

```
autoMode.environment[4]
  "Preferred stacks: .NET 8 / ASP.NET Core, EF Core, PostgreSQL, Vite + React/Vue, Tailwind, Docker Compose."
→ 把 PostgreSQL 換成 MySQL
```
實測 7 個專案 PG 0 命中，唯一有 DB 的是 MySQL（17 檔）。留著會讓 classifier 預設產 PG 語法、預設選 Npgsql。

**defense-in-depth 選配（P3-5，hook 已是主防線）：**

```
:21   刪 "Bash(git push --force-with-lease *)",
      → 代價：force-with-lease 到 feature branch 會多一次確認
:284  刪 "skipDangerousModePermissionPrompt": true,
      → 與日常 git 無關，只在啟動 --dangerously-skip-permissions 前多一次確認
```

**`[T0-9]` merge gate 的機械對應物（P3-5 額外可選）：**

```
:23   "Bash(gh *)" → 收斂為唯讀子集
      gh pr view / gh pr checks / gh pr diff / gh api GET / gh issue view
```
目前 `[T0-9]`（綠 CI + 處理 bot review 才 merge）**沒有機械對應物**，`gh pr merge` 一句就繞過（`00-report.md` §3.2）。

**不動 allow 清單就能恢復軟層（P3-5）：**

```
autoMode.classifyAllShell: true     ← 實測目前未設定
```
讓所有 Bash allow rule 一律被排除出 classifier 短路路徑。原理見 `00-report.md` §3.1.1 的 binary 驗證。

**衛生（P3-7 h / i）：**

```
permissions.deny  ← 補齊 autoMode.soft_deny 已枚舉的 11 個 reader（硬層目前只擋 4 個動詞）
permissions.allow ← 刪 4 條對應已停用 github plugin 的 mcp 規則
```

### C. 其他

- **`~/.codex/stitch.env` 明文 key rotate**（P3-6）—— 未外洩，但本機明文仍在。

---

## 6. 每次動完必跑的驗收

```bash
~/.agents/tests/git-push-guard.sh          # 預期 68 PASS / 0 FAIL
~/.agents/tests/codex-git-push-guard.sh    # 預期 12 PASS / 0 FAIL
~/.agents/tests/conformance.sh             # 預期 12 PASS / 0 FAIL
bash ~/.agents/bin/agents-sync --check     # 預期 lint: PASS
bash ~/.agents/bin/agents-sync --doctor    # 預期 exit 0
```

動到 `~/.agents/core|hosts|rules|skills` 的正本後，**必須跑 `bash ~/.agents/bin/agents-sync`（不加 `--check`）重新部署**，否則 `conformance.sh` 的「manifest 相符」會紅。

**🆕 動到 skill 的 SKILL.md 後，額外量測 on-invoke 成本有沒有真的降**（P3-2 / N3 的驗收）：

```bash
for d in ~/.agents/skills/*/; do
  [ -f "$d/SKILL.md" ] && echo "$(wc -l < "$d/SKILL.md") $(basename "$d")"
done | sort -rn | head -10
```
目標：全部 ≤ 約 110 行（目前唯一超標者是 `ecpay` 818 行）。

---

## 7. 正本位置

| 文件 | 內容 |
|---|---|
| `~/.agents/proposals/2026-07-25-model-capability-coverage/00-report.md` | 完整稽核（94 findings、五軸判準、Copilot review 處理、CI 建置、事故紀錄）§1–§15。**⚠️ 早於本 rev.2**：P3-2 的標的清單、P3-3 的「15 個 plugin」、以及「行數＝context 成本」三處已分別被本檔 P3-2／P3-3／§2 取代；`§3.1.1`（classifier binary 驗證）與 `§3.2`（`gh pr merge` 繞過 `[T0-9]`）仍有效 |
| `~/.agents/proposals/2026-07-25-skill-audit/` | skill 層逐檔判決（Keep/Trim 的詞彙定義見 `02-recommendations.md:24`） |
| `~/.agents/proposals/2026-07-25-agent-audit/00-report.md` | agent 層 + 設定層 |
| memory `skill-removability-five-axes` | 五軸判準與兩個禁用推論 |
| memory `skill-usage-authoritative-source` | 用量權威來源與 `@inline` plugin 的性質 |
| memory `guard-git-push-refspec-bypass` | guard 的現行結構（改邏輯只改一處） |
| memory `agents-branch-switch-silently-swaps-skills` | 切分支換掉 skills 的陷阱 |
| memory `claude-automode-defaults-and-async-hooks` | `$defaults` 是取代不是疊加；async hook 不可攔截 |
| memory `vendored-skills-no-local-restructure` | vendored skill 不可原地改（superpowers 屬此類） |

### 本次引用的官方來源

| 來源 | 用在 |
|---|---|
| [The new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models) | §1 六規則對照、§2 成本模型、N1、N2 |
| [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5) | P3-4（subagent / verification）、N4（scope）、N5（長度） |
| [How and when to use subagents in Claude Code](https://claude.com/blog/subagents-in-claude-code) | P3-4 的派工判準 |

**⚠️ 引用時的一個界線**：blog 明文**沒有**涵蓋 subagent 編排、平行度、驗證迴圈機制與輸出長度 —— 那些全部來自《Prompting Claude Opus 5》。rev.1 的 P3-4 把兩者都記成「官方 prompting guidance」，容易讓人去 blog 找不到而誤判為過期。兩份文件要分開引用。
