# 全域 skill 審查 × Fable 5.1／Opus 5 官方建議（2026-09-05）

方法：`auditing-skill-folder` Step 0–6（Step 2c／A/B canary 未跑，見 §7）＋官方 `claude-api` skill 的 `shared/prompt-audit.md`（Group 1–3）＋官方三頁：[Prompting Claude Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1)、[Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)、[Claude Code Skills](https://code.claude.com/docs/en/skills)。範圍：`~/.agents/skills` 75 支（Claude 經 `~/.claude/skills` symlink 載入）＋ 16 個 enabled plugin 的 skill。前一輪正本：`2026-08-02-skill-audit-closure`（76 支全 Keep）、`2026-08-22-opus5-prompt-audit`（常駐 prompt clean surface）。本報告只做 delta。逐支 ledger：[ledger.md](ledger.md)。

## 1. 結論

1. **官方要求「因模型升級而刪」的內容，在 skill 正文為零命中。** Opus 5 頁要刪的 verification／self-check scaffolding、Fable 5.1 頁要刪的 anti-formatting 與 update suppressor、prompt-audit Group 1 的 pressure language／think-step-by-step／STEP-N choreography，掃 75 支 SKILL.md 全部 0 命中（§2）。08-22 對常駐 prompt 的 clean-surface 結論延伸到 skill 層成立。
2. **真正的問題是 listing 預算溢位，不是內容過時。** 官方 skills 頁：listing 預算 = context window 的 1%（字元），溢位時 harness 從「最少用」的 skill 開始剝掉 description。`/skill-doctor` 實測 CLI session 剝了 9 支，本 desktop session（多了 claude.ai plugin 的 60+ 支）剝了 **17 支**，其中 `web-design-reviewer`、`shared-security-review`、`security-audit`、`tdd` 等是 kernel／rules 點名的 skill，現在對模型只剩名字（§3）。
3. **唯一可直接 Delete：`~/.agents/skills/diagram-design`**。19:15 才出現的 untracked 目錄，與 plugin `diagram-design@diagram-design` 2.6.12 的 skill **byte-identical**（`diff -rq` exit 0，3.2 MB／212 檔），造成同一 skill 列兩次；它的 SKILL.md 585 行也是全庫唯一超官方 500 行上限的，且 structural gate 的 45 個 MISSING relative reference 全部來自它（§4.1）。
4. 其餘 74 支依五軸與 Step 6 全部 Keep；「精簡」落在兩個 Claude-local、可逆、不動 shared tree 的槓桿：`skillOverrides: name-only`（17 支）與 description 去 enumeration（11 支 house-authored）（§4.2–4.3）。Plugin 層另有 2 個 disable 候選（§4.4）。

## 2. 官方建議 → 對 skill 的具體檢查 → 結果

| 來源 | 條文 | 掃描方式 | 命中 |
|---|---|---|---|
| Opus 5 頁 §Task scope and over-verification | 刪 "include a final verification step"、"use a subagent to verify" 類指令 | grep `double-check|re-verify|verify your work|subagent to verify|final verification step` | **0** |
| Opus 5 頁 §Self-correction | 刪 "double-check your answer" 類 re-check | 同上 | **0** |
| Opus 5 頁 §Controlling subagent spawning ↔ Fable 5.1 頁 §Let it delegate | 兩模型方向相反；kernel `delegation.md` 已裁定（09-05 計畫「不做」段） | 不重審 | n/a |
| Fable 5.1 頁 §Formatting | 刪 anti-formatting（never use bullets／no headers） | grep | **0**（2 個 false positive 在 diagram-design references，是圖表語意） |
| Fable 5.1 頁 §User-facing progress updates | 先刪 update suppressor（hold all findings／don't narrate） | grep | **0** |
| Fable 5.1 頁 §Prefer targeted edits／§Keep changes and tests to what the task asks | 屬 harness／CLAUDE.md 層，PR #53 已落地 surgical-edit 行 | 不重審 | n/a |
| prompt-audit 1a | caps `MUST/NEVER/ALWAYS/CRITICAL/IMPORTANT` 密度 ≥6／檔 | grep -c | **0** 支 |
| prompt-audit 1b | think step by step／`<scratchpad>`／plan before acting | grep | **0** |
| prompt-audit 1c | STEP-N choreography for judgment tasks | 抽讀 `dapper-best-practices`：Golden Rules + reference map，屬 reference 結構（keep list「structure for reference data」），非 choreography | **0** 需改 |
| prompt-audit Group 2 | trigger-case enumeration 只增不減、每 request 都繳稅 | grep `Apply even when|even when user just says` | **11** 支（§4.3） |
| prompt-audit Group 2 | SKILL.md 超 500 行（Claude Code 頁同一條） | wc -l | **1** 支：diagram-design 585 行 |
| Claude Code 頁 | description+when_to_use 上限 1,536 字元 | 量 | 0 支超（最長 test-gap-analysis 1,027） |
| Claude Code 頁 | listing 預算 1% context、溢位剝 description | `/skill-doctor` + 本 session listing | **溢位**（§3） |

## 3. Listing 預算實測

- 個人 model-invoked skill description 合計 **21,145 字元**；CLI 可見 plugin skill description 合計 **8,876 字元**；bundled skill 與 desktop 的 claude.ai plugin（engineering／product-management／design／anthropic-skills…）另計，本 session 目測 60+ 條。
- `claude -p "/skill-doctor"`（cwd `~`，CLI 2.1.259）：「30 skills loaded but never invoked」「20 plugin skills loaded but never invoked」；context 欄 `< 20` 的 9 支個人 skill 即被剝到 name-only：`security-audit`、`shared-security-review`、`speak-human-tw`、`tdd`、`test-gap-analysis`、`testing-library-react-best-practices`、`vite`、`vitest`、`web-design-reviewer`。
- 本 desktop session 系統提示的 skill 清單再多剝 8 支：`microsoft-docs`、`next-best-practices`、`nuxt`、`postgresql-optimization`、`prototype`、`react-router-framework-mode`、`research`、`tailwind-v4-shadcn`。17 支對照 `~/.claude.json` `skillUsage` **全部 0 用量**，與官方「從最少用剝起」一致。
- 目前 `settings.json` 無 `skillOverrides`、無 `skillListingBudgetFraction`；預算分配完全交給 harness 的最少用啟發式，**不可見、不受控**——corpus 一換（例如接前端案），被剝的會換一批而沒人知道。

## 4. 判決

### 4.1 Delete（1）

| Skill | 證據 | 刪法 |
|---|---|---|
| `~/.agents/skills/diagram-design` | `git status` `??`（untracked，git 從未見過）；`diff -rq` 對 `~/.claude/plugins/cache/diagram-design/diagram-design/2.6.12/skills/diagram-design` exit 0；mtime 2026-09-05 19:15；`vendored-skills.lock`／tests 零引用；`/skill-doctor` 列 `diagram-design ~260 tokens` 與 `diagram-design:diagram-design` 各一筆 | `/bin/rm -rf` 該目錄（沙箱 rm wrapper 會短路，用絕對路徑）→ `~/.agents/bin/agents-sync --bootstrap` prune `~/.claude/skills/diagram-design` symlink（該路徑在沙箱 deny 清單，需 unsandbox）。零資料損失：內容就是 plugin cache。 |

不是 Delete 但要回報給 plugin 上游：SKILL.md 585 行超官方 500 行；45 個 MISSING relative reference（`references/type-scatter.md`→`scripts/verify-bubble.py` 等）在 plugin 版同樣存在（byte-identical）。

### 4.2 `skillOverrides: name-only`（17，Claude-local，可逆）

依官方 skills 頁「set low-priority entries to name-only to free budget」。不動 `~/.agents` shared tree → 不觸 VND 約束、不影響 Codex／Copilot、不需 A/B。

| 組 | Skill | 為何安全 |
|---|---|---|
| A. kernel／rules 以名字 route（9） | `security-audit`、`shared-security-review`、`research`、`microsoft-docs`、`tdd`、`web-design-reviewer`、`nuxt`、`vite`、`vitest` | dev-workflow S0／INT-9、`rules/frontend-spa.md`、`rules/testing.md` 直接點名；description 本來就不是它們的觸發路徑，且現況已被剝 |
| B. 無任何 route、0 用量（8） | `next-best-practices`、`postgresql-optimization`、`prototype`、`react-router-framework-mode`、`speak-human-tw`、`tailwind-v4-shadcn`、`test-gap-analysis`、`testing-library-react-best-practices` | 現況已 name-only；顯式化只是把「harness 隨機決定」變成「已知決定」。這 8 支是未來 temp-disable A/B 的首選名單，但依五軸與 Step 6，**本輪不判 Delete** |

不建議改 `skillListingBudgetFraction` 到 0.02：desktop 的 claude.ai plugin 清單在 settings 之外，加預算會先餵給那 60+ 條。

### 4.3 Trim description（11 house-authored；2 VND 只回報）

prompt-audit Group 2「trigger-case enumeration」：`Apply even when user just says "…", "…", "…"` 子句 114–213 字元，每 request 都在 listing 裡；官方指示改成 intent 類別。保留 keep list #6：trigger 可帶 calibrated urgency，所以只砍例句清單、留 intent 名詞。

| Skill | desc | enumeration 子句 | 處置 |
|---|---:|---:|---|
| `next-best-practices` | 409 | 213 | Trim（同時列 4.2-B） |
| `auth-implementation-patterns` | 364 | 198 | Trim |
| `react-best-practices` | 420 | 198 | Trim |
| `react-router-framework-mode` | 433 | 197 | Trim（同時列 4.2-B） |
| `typescript-best-practices` | 420 | 174 | Trim |
| `containerization` | 336 | 154 | Trim |
| `dotnet-testing-best-practices` | 442 | 146 | Trim |
| `dapper-best-practices` | 370 | 141 | Trim |
| `mysql-best-practices` | 397 | 139 | Trim |
| `ef6-best-practices` | 380 | 126 | Trim |
| `ef-core-best-practices` | 369 | 114 | Trim |
| `test-gap-analysis`（VND\*） | 1,027 | — | 只回報：description 佔全庫最長，含 "DO NOT USE FOR" 段；改它會擴張已記錄 fork |
| `shared-security-review` | 535 | — | 只回報：三段 routed-away 句可縮，但 08-02 剛以 canary 校過，不動 |

估計回收 ≈1,650 字元（≈4%），效益是把 4.2 之外的常用 skill 留在預算內；每支改完跑 `eval-triggers.sh --runner claude` 的 positive／negative canary（S4 對 skill change 的規定）。VND 標記錯誤更正：這 11 支 `check-vendored.sh` 均為 `-`，屬 house-authored，可原地改。

### 4.4 Plugin 層（`/skill-doctor`「Plugins not used recently」）

| Plugin | 證據 | 建議 |
|---|---|---|
| `code-review@claude-plugins-official` | 1 個 command，用 3×、91 天前；內容是「follow these steps precisely → Haiku agent 1 → Haiku agent 2 …」的 choreography，正是 prompt-audit 1c 型；`/code-review ultra` 不在裡面（grep `ultra` 0）；CLAUDE.md:51 點名的 `code-review` 是個人版（17×、5 天前） | **Disable**（`/plugin`，可逆） |
| `chrome-devtools-mcp@claude-plugins-official` | 6 skill／1,481 字元（CLI plugin 中最大）全 0 用量、91 天未用；瀏覽器面已有 desktop 內建 Browser pane、`claude-in-chrome`、`playwright` plugin、個人 `agent-browser` 四層 | **Disable**（可逆；MCP tools 本就 deferred，主要省的是 skill listing） |
| `microsoft-docs@claude-plugins-official` | 3 skill／1,279 字元與個人 `microsoft-docs`＋`microsoft-code-reference`（VND，0 用量，dev-workflow S0 點名）**同名雙列**；但個人版 `compatibility:` 明寫依賴此 plugin 的 MCP server | **Keep plugin**；個人 pair 走 4.2-A name-only（`microsoft-code-reference` 也一併，理由相同）。`skillOverrides` 是否接受 `plugin:skill` 限定名，docs 與 `/skill-doctor` 說法相反（後者稱 plugin skill 不能單獨關），需實測 |
| `skill-creator`、`frontend-design`、`hookify`、`remember` | 各 1–5 skill、178–395 字元 | 不動：`skill-creator` 先前已被使用者否決（無本地替代）；`remember` 已在 09-05 backlog 歸 plugin 盤點；其餘量小 |
| `csharp-lsp`、`typescript-lsp`、`playwright`、`context7`、`security-guidance` | 0 skill（純 MCP／LSP） | 不在本題範圍 |

### 4.5 明確不動（防後續 apply 誤刪）

- **CLAUDE.md 直接或經 `@import`／rules／dev-workflow／agents 點名的 45 支**（ledger「全域設定引用」欄非 `—`）：`dev-workflow`（CLAUDE.md ×5）、`code-review`、`handoff`、`exec-briefing`（profile.md）、`deps-check`／`bug-fix-settlement`（cookbook）、`frontend-release-verification`／`web-design-reviewer`／`nuxt`／`vite`（frontend-spa）、`vitest`（testing）、dev-workflow S0／S4／S6／INT 條文的 33 支、三個 agent 定義點名的 7 支。刪任一支即 kernel 死連結。
- **12 支 user-only**（`ask-matt`、`grill-me`、`grill-with-docs`、`handoff`、`implement`、`improve-codebase-architecture`、`setup-matt-pocock-skills`、`teach`、`to-spec`、`to-tickets`、`triage`、`wayfinder`）：`/skill-doctor` context 欄 `-`，listing 零成本；Fable 5.1／Opus 5 的 verbosity 建議與它們無關。
- **Matt Pocock 與其他 VND 共 33 支**：只能整包換或整包移除，不原地 Trim；本輪無 Step 6 A/B 證據，不判 Delete。
- **ponytail SessionStart 注入（~3.5 KB prescriptive block）**：Fable 5.1 頁「舊 prescriptive prompt 要 A/B」的最大命中，但 09-05 D5 已決議由使用者 `/ponytail lite` 自行 A/B，不重提。
- `dotnet-*`／`ef-*`／`dapper`／`mysql` 等 .NET 主力 stack：用量 7–56，全部 Keep。

## 5. 全域 CLAUDE.md 引用圖

```
~/.claude/CLAUDE.md ──直接──▶ dev-workflow, code-review, /handoff, simplify(builtin), uiux-reviewer(agent)
   ├─@ profile.md ─────────▶ exec-briefing
   ├─rules/cookbook.md ────▶ deps-check, bug-fix-settlement
   ├─rules/frontend-spa.md ▶ frontend-release-verification, web-design-reviewer, nuxt, vite
   ├─rules/testing.md ─────▶ dev-workflow, vitest
   └─dev-workflow S0/S4/S6/INT ▶ triage grilling domain-modeling grill-with-docs to-spec to-tickets wayfinder
        handoff diagnosing-bugs code-review deps-check shared-security-review security-audit
        dependency-security-scan codebase-design acquire-codebase-knowledge init-project-docs research
        microsoft-docs microsoft-code-reference context7-mcp ui-ux-pro-max writing-for-agents
        auditing-skill-folder improve-codebase-architecture setup-matt-pocock-skills tdd implement
        frontend-release-verification backend-release-verification bug-fix-settlement resolving-merge-conflicts
~/.claude/agents/*.md ─────▶ agent-browser css-ui-best-practices dotnet-core/framework/testing-best-practices playwright-best-practices
```

未被任何一層點名（30 支）：stack reference skill 18 支（`auth-implementation-patterns`、`c-cpp`、`dapper`、`dotnet-logging`、`dotnet-winforms`、`ef-core`、`ef6`、`jest`、`mysql`、`next`、`nodejs`、`postgresql`×2、`react`、`react-router-framework-mode`、`testing-library-react`、`typescript`、`vue`），加 `apple-calendar`、`aspnet-api-architect`、`clean-code-dotnet`、`containerization`、`diagram-design`、`mp-zoom-out`、`prototype`、`speak-human-tw`、`tailwind-v4-shadcn`、`test-gap-analysis`、`teach`、`grill-me`。這些靠 description 觸發，所以 §3 的剝除對它們才是真傷害；也因此 4.2-B 選的是「已 0 用量且已被剝」的子集，不是整批。

## 6. 執行順序（待核准；全域 config 屬 [INT-10]）

1. 4.1：`/bin/rm -rf ~/.agents/skills/diagram-design` → unsandbox 跑 `~/.agents/bin/agents-sync --bootstrap` → `--doctor` 確認 symlink 數 75→74。無需 PR（untracked）。
2. 4.4：`/plugin` 關 `code-review@claude-plugins-official`、`chrome-devtools-mcp@claude-plugins-official`（settings.json `enabledPlugins` 會被 harness 寫回，屬 writeback，不視為 drift）。
3. 4.2：dotclaude 開 branch，`settings.json` 以 Edit 加 `skillOverrides`（18 鍵：17 支 + `microsoft-code-reference`）；`tests/repo-integrity.sh` 補一條 `jq -e '.skillOverrides | length >= 18'`；PR → bot gate → 使用者確認 merge（全域 config 逐次確認）。
4. 4.3：`~/.agents` 開 `agents-branch`，11 支 description 各一 commit，每支跑 `eval-triggers.sh` positive／negative canary；`agents-sync --check` 後 ff-only merge。
5. 實測 `skillOverrides` 對 `microsoft-docs:microsoft-docs` 限定名是否生效（headless `/skill-doctor` 看 context 欄），決定 microsoft 雙列最終走哪邊。

## 7. 未驗證與限制

- 未跑 Step 2c trigger eval 與 Step 6 temp-disable A/B；因此本報告沒有任何一支（diagram-design 除外）達到 Delete 門檻，這是方法論結果不是遺漏。
- `/skill-doctor` 數字來自 cwd `~` 的 headless session；本專案 session 的剝除清單是從系統提示清單反推，兩者一致但非同一次量測。
- Listing 預算的 1% 是官方 docs 敘述；binary 2.1.259 `strings` 找不到 `skillListingBudgetFraction`，估算（≈40K 字元）未由 binary 證實。
- `skillUsage` 只涵蓋 Claude；Codex／Copilot 無等價紀錄，4.2 的 0 用量不代表另兩 host 沒用（它們不受 `skillOverrides` 影響，所以不構成風險）。
- 結構 gate 的 `aspnet-api-architect` name 不符是引號（`name: 'aspnet-api-architect'`）造成的腳本假陽性，非缺陷。

## 8. 獨立回查（2026-09-05 20:41，另一 session；依 memory `audit-finding-with-evidence-still-wrong` 回查來源）

成立：§2 三組 grep 0 命中（重跑）、§4.1 `diff -rq` exit 0／untracked／584 行、§3 本 session 17 支 name-only 與 `skillUsage` 全 NEVER 對得上、§4.3 的 11 支 enumeration 名單、dev-workflow 點名 34 支、agents 點名 8 支。

更正三處：

1. **`nuxt`／`vite`／`vitest` 不是被 rules 以名字 route**。`rules/frontend-spa.md:4,7` 與 `rules/testing.md:11` 命中的是 `paths:` glob（`vite.config.*`／`nuxt.config.*`／`vitest.config.*`），不是 skill 名；跨 skill 引用 `nuxt`=0、`vite`=0。三支應歸 §4.2-B（靠 description 觸發、無 route），不是 4.2-A；對 description 觸發的 skill 明示 `name-only` 等於永久關掉 Claude 端觸發，比 harness 的最少用啟發式（會隨用量自動回升）更差，改列 A/B 候選而非直接 pin。同理 `research`（CLAUDE.md:19 是文件類型詞）、`prototype`（rules/dotnet.md:15 是普通詞）在 CLAUDE.md 層皆為 false positive；兩者的真實 route 分別是 dev-workflow（research 有）與無（prototype）。
2. **`chrome-devtools-mcp` plugin 被 `rules/frontend-spa.md:40-41` 點名分工**（「MCP 負責診斷、CI 負責把關」「不要用 chrome-devtools 做這兩類事」）。§4.4 的 Disable 若執行，須同步改該 rule，否則 rule 指向不存在的工具。
3. **prompt-audit 1a 的「0 支 ≥6」不精確**：`dev-workflow/SKILL.md` 有 23 `MUST` + 2 `MUST NOT`（無 NEVER／ALWAYS／CRITICAL／IMPORTANT），全為帶規則 ID 的 RFC-2119 normative 用法，非 pressure language；結論不變但數字要記對。

更正四（2026-09-05 23:30，第 3 級實作時）：§6 步驟 3 的「18 鍵：17 支 + `microsoft-code-reference`」與 `jq -e '.skillOverrides | length >= 18'` 已過期。依 §8 更正一，核准範圔縮為 7 支（`security-audit`、`shared-security-review`、`research`、`microsoft-docs`、`microsoft-code-reference`、`tdd`、`web-design-reviewer`），斷言改為逐鍵等值 `name-only`（不釘 map 長度，`/skills` 選單寫回的其他鍵不算 drift）。實作：dotclaude 分支 `chore/skill-overrides-name-only`。另記：`microsoft-docs`／`microsoft-code-reference` 的同名 plugin skill 不受 `skillOverrides` 影響（schema 註記），這兩鍵只覆蓋 user-level copy。

更正五（2026-09-05 第 4 級實作，S5 兩軸 FAIL 後）：§8 更正一寫「跨 skill 引用 nuxt=0、vite=0」是錯的——那次只算了 kernel／rules，沒查其他 skill 的 description。實查 `description:` 行：`vue-best-practices → nuxt`、`vitest → vite`、`vite → vitest`、`postgresql-best-practices → postgresql-optimization`、`css-ui-best-practices → tailwind-v4-shadcn`、`jest-best-practices → testing-library-react-best-practices`；再查 body：`react-best-practices` Companion Skills 點 `next-best-practices`／`react-router-framework-mode`，`ask-matt`／`wayfinder` 點 `prototype`；`test-gap-analysis` 有 kernel route（`dev-workflow/references/evidence-integrity.md`）。因此 §4.2-B「無任何 route」8 支中只有 `speak-human-tw` 成立。第 4 級最終分組：name-only 17 支（第 3 級 7 + test-gap-analysis + 上述 6 + 3），A/B `user-invocable-only` 僅 `speak-human-tw`，起日 2026-09-05、**決策日 2026-10-03**（刪 skill／恢復 on／延長三選一；判準與細節另見 session memory `skill-ab-hidden-2026-09-05`，本檔日期為權威）。更正一「pin name-only 比 heuristic 更差」的論點對有名字 route 的 skill不適用；對自身 description 仍是觸發路徑的 6+3 支，取捨（關掉自動回升、靠名字 route 補）已記錄並接受。方法教訓：判「有沒有 route」必須 grep description **與 body**，只看 description 會漏 handoff。
