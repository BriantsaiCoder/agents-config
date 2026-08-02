# ~/.agents/skills 81 個 skill — Claude × Codex 對照與最終建議

2026-08-01。live inventory 81 個（已從 95 移除 14 個）。兩份獨立稽核逐項對照。

## 兩份的 verdict 分佈

| verdict | Claude | Codex |
|---|---:|---:|
| Keep | 44 | 32 |
| Trim | 20 | 29 |
| Collision | 12 | 14 |
| Split | 1 | 4 |
| Move | 0 | 2 |
| Move-to-host/repo-instructions | 2 | 0 |
| Delete | 2 | 0 |

**verdict 完全相同：43/81（53%）**。分歧 38 條的裁決見下表「最終」欄。

## 讀法

- **Claude** = 5 組實查 agent + 5 組對抗性複核（10 agent，136 萬 token）；`⟳` 表示複核推翻了第一輪判定。
- **Codex** = 獨立全量 review。它的報告明寫「所有 VND/VND* 的 Trim、Split 或原地改寫建議，實際執行時都必須走 recorded override」——**它從頭就正確理解 override 規則**，而 Claude 這側在彙總時把 override 讀成禁止，導致 8 條裁決被窄化。那 8 條已於 2026-08-01 21:00–22:00 用兩輪 workflow（12 agent）在正確前提下重評完畢，結論寫在本表「最終」欄。
- **最終** = 綜合裁決。依據：程序權威（`step1-verdict-guide.md` 的 Iron Law、`step0-vendored-gate.md` 的 override 條款）+ 實查證據強度。
- ✅ = 已執行（commit `663bce4`）。

## 逐項對照

| skill | Claude | Codex | 一致 | 最終建議 |
|---|---|---|:-:|---|
| `acquire-codebase-knowledge` | Keep | Keep | ✅ | 採納（兩份一致）：保留 evidence-backed repo map 與 intent/reality reconciliation |
| `agent-browser` | Trim | Keep | — | 取 Claude：LOW 依 step1-verdict-guide 的 Refactor 成因（body 內聯 CLI 輸出／旗標）壓縮 SKILL.md:44-51 與 :53-59 各為一行指標，把 EFF 619 拉回 500 內 |
| `ask-matt` | Move-to-host/repo-instructions | Trim | — | **external-integration-only** — **維持不改**，成本算清楚後更硬。fork 它會踩到一般 vendored fork 沒有的第六道成本：`tests/matt-thin-workflow.sh:299` 的 `rg -q '18 unmodified.*4 recorded forks'` 會 FAIL，必須同步改測試字面值 + `vendored-forks.md:128` 標題 + `:136` 的「18 entries … byte-for-byte upstream and immutable」。改動面積也不小：`/` 前綴散在 **52 個 site、21 個相異目標**，遍布 L17-78 全檔，比既有四個 Matt fork（diagnosing-bugs 一行、handoff +2 行、grilling 一段）大一到兩個數量級，而買到的只是一個前綴符號。缺口其實只有一句話：kernel 的 Host adapters 已逐 host 定義前綴（`:117`/`:123`/`:131`），[INT-7] 也已要求 S0 推薦 host-specific command——缺的是「**skill body 散文中出現的指令前綴一律以 Host adapters 為準**」這條規則。 |
| `aspnet-api-architect` | Collision | Collision | ✅ | **rewrite（實為 self-owned，非 fork）** — **結論翻轉，且推翻 `vendored-forks.md` 的記載**。該檔記它「provenance 未解、non-editable until a source repository and revision are verified」——實查證明沒有外部上游：GitHub 全站 code search 對 `aspnet-api-architect` 共 12 命中，**全部落在 BriantsaiCoder 自己的 repo**（agents-config 本體 + dotclaude 的 symlink），`github/awesome-copilot` 0 命中；`SKILL.md:149` 自述衍生自 `make-skill-template`（scaffolding meta-skill，不是被抄的來源）；全檔 zh-TW，與 corpus 內另四支 zh-TW skill（dev-workflow/sdd/deps-check/bug-fix-settlement，全自有）同批；lock 的 source_url 指回本 repo，revision `44c7fd0` 是使用者自己 2026-07-30 的批次匯入 commit。→ **它是 self-owned，改寫成本 0 override**。動作是 provenance 更正（刪兩份 lock 列 + 更新 vendored-forks.md 的 Unresolved 段）而非 fork-index 加列，之後直接改本體：修四處死路徑、刪與 canonical 重複的檢查清單與 MSTest 樣板、EFF 1067 壓回 500 內。caveat：code search 掃不到 private/已刪 repo。 |
| `auditing-skill-folder` | Keep | Keep | ✅ | 採納（兩份一致）：vendored gate、trigger collision、delete evidence 流程獨有 |
| `auth-implementation-patterns` | Keep | Collision | — | 取 Claude：MEDIUM 刪除 SKILL.md:56 尾句的「CLAUDE.md default: JWT in httpOnly cookie, public endpoints explicit, no tokens in l |
| `backend-release-verification` | Keep | Trim | — | 取 Claude：Keep 依據：496/500 未超標、description trigger-led、持有其他 skill 沒有的 backend 專屬最小 gate map（L26-36 Artifact/Build/Tests/D |
| `bug-fix-settlement` | Trim | Trim | ✅ | **已執行** — (1) 主要 Trim 成因（step1-verdict-guide.md:13，同一 pattern 多個範例）：L57-62、L86-93、L95-103 是同一個輸出區塊的三次渲染（評估模板 + |
| `c-cpp-best-practices` | Keep | Keep | ✅ | 採納（兩份一致）：ownership、ABI、RAII、sanitizer failure shields 有效 |
| `clarify` | Collision | Collision | ✅ | **remove** — 維持，但理由不是成本。override 便宜到不能再便宜——上游 `plugins/clarify/skills/clarify/` 已被 commit `1d8e16c`(2026-02-09) 整檔刪除（改名 `vague`），merge 成本 0；portability 修法只是 4 處小改。**它過不了的原因是買不到行為改變**：portability 從來不是唯一缺陷，trigger 才是。head-to-head 對 grilling——clarify 625 字 vs grilling 217 字，較重的檔案交付較窄的行為；grilling 無工具相依、已在 kernel 三處路由，clarify 路由掛零。修好 AskUserQuestion 不會讓它贏回那一格。**邊界**：移除不影響 [T0-5]，該規則自足於 tier0-safety.md、不指名任何 skill。 |
| `clean-code-dotnet` | Split | Collision | — | 取 Claude：把 SKILL.md:286-462 的 SOLID 全段外移（該內容已存在於 references/solid-principles.md），SKILL.md 僅留 5 條原則名 + 一行 cross-ref；Nami |
| `code-review` | Trim | Keep | — | 取 Claude：報告用，**override 不建議**。特別註記：Codex 提的兩個 Trim 理由已被 kernel 覆寫，不構成執行理由——L13 自動 setup 由 [INT-5] 擋下，WIP/dirty-tree 由 [ |
| `codebase-design` | Trim | Keep | — | 取 Claude：報告用，**override 不建議**。成因是重複示意而非散文冗長：兩張 ASCII 方塊圖（L34-52，19 行）只重述 L32/L44 已寫清楚的一句話，兩組 TypeScript 對照（L73-93）各只示範一 |
| `containerization` | Keep | Trim | — | 取 Claude：Keep：自有、EFF=473 未超標、是 corpus 內唯一的 Dockerfile 來源（含 .NET Framework + IIS Windows container 這個罕見組合），無替代者。 |
| `context7-mcp` | ⟳ Collision | Collision | ✅ | **已執行** — MEDIUM 補 Claude 側缺口：改 `~/.claude/CLAUDE.md` 的現有 bullet「文件查詢優先 MCP；Microsoft／Azure／.NET 用 microsoft-l |
| `csharp-developer` | Collision | Collision | ✅ | **remove** — 維持，但**理由從 duplication 換成 scope**。它獨有的是 `references/blazor.md`(556 行，全 corpus 唯一)、SignalR、MAUI——三者全在你宣告範圍之外，與 2026-08-01 已執行的 13 支移除同判準（純領域外、零本地修改）。其餘 reference 都有自有替代（Span<T>/AOT → security-performance.md；aspnet-core/entity-framework/modern-csharp → dotnet-core-best-practices 的三個 reference + ef-core-best-practices）。EFF 498 未超標不是保留理由，只說明它沒有第二個缺陷。 |
| `css-ui-best-practices` | ⟳ Keep | Trim | — | 取 Claude：刪除 SKILL.md L12（New → Tailwind v4）與 L13（Avoid runtime CSS-in-JS in new）——目的地已存在且三 host parity 已確認（~/.claude|.c |
| `dapper-best-practices` | Keep | Keep | ✅ | 採納（兩份一致）：transaction propagation、enumeration、N+1 規則明確 |
| `dependency-security-scan` | Keep | Keep | ✅ | 採納（兩份一致）：SBOM、四層掃描、exception expiry 契約有價值 |
| `deps-check` | ⟳ Trim | Trim | ✅ | **已執行** — 三件事一起做，缺一不可：(1) scripts/deps-check.sh:21-24 與 :147-152 改 fail-closed — 兩處 `exit 0` 改 `exit 2`，並在真正跑完 |
| `dev-workflow` | ⟳ Trim | Trim | ✅ | 採納（兩份一致）：保留 INT/S gates；host branches、沉積內容下沉 references |
| `diagnosing-bugs` | Trim | Keep | — | 取 Claude：報告用，**明確不建議 override**：本 skill 已是 VND*，現行 fork scope 僅限「add the missing Agent Skill trigger-failure branch」，字數 |
| `domain-modeling` | Trim | Keep | — | 取 Claude：報告用，**override 明確不划算**：僅超標 15 words（3%），換 byte-pinned upstream 的永久 merge conflict 完全不成比例。唯一可壓縮處是兩張目錄樹（L14-38）。 |
| `dotnet-core-best-practices` | Keep | Trim | — | 取 Claude：Keep 並確立為五件套收斂後的 canonical：唯一有實績（usage 26）、唯一 description 帶具體症狀、唯一未超標，且是本組唯一自有可編輯者——後續要補的內容都往這裡收。 |
| `dotnet-core-expert` | Collision | Collision | ✅ | **merge-then-remove** — 複核發現一個 provenance 新缺陷：LICENSE 不存在、in-tree marker 不存在、marker 掃描不涵蓋 `references/` → **lock 列是它 vendored 身分的唯一載體，刪列即抹除**。且按原方案執行會讓 `tests/matt-thin-workflow.sh` 三處 FAIL 而錯誤訊息只說計數不符、不指根因。唯一無替代的 `references/clean-architecture.md`(CQRS/MediatR) 屬 web/microservice 領域，非批次/桌面主力。 |
| `dotnet-find-bugs` | Collision | Split | — | **merge-then-remove** — 維持。兩個「重複」判斷逐條確認成立：runtime diagnostics 半邊只有 dotnet-counters/trace/dump 三支，保留者的症狀→工具對照表三支全在還多出 dotnet-gcdump、dotnet-stack、容器 minidump 環境變數；11 條 security 清單全數被 `security-review/references/workflow.md:46-84` 覆蓋且更細。唯一獨特是 `security-and-mapping.md:20-67` 的 per-changed-file attack-surface 模板（`grep -rn -i "attack surface|changed file|per-file"` 在 security-review/ 回 0 命中）。override step 1 機械上做不到——lock 指向本 repo 自己的第一份 snapshot，沒有會移動的上游。附帶：它 description 自稱「.NET 10 Debugging Strategist」，你的主力是 net8，版本宣稱本身就誤導。 |
| `dotnet-framework-best-practices` | Keep | Keep | ✅ | 採納（兩份一致）：System.Web/OWIN/EDMX legacy 邊界清楚 |
| `dotnet-logging-best-practices` | Keep | Trim | — | 取 Claude：Keep：自有、EFF=472 未超標、涵蓋 .NET 6+ 與 .NET Framework 兩條線（Serilog/NLog/log4net），且與 DCT 的「絕不印憑證」約束同軸。 |
| `dotnet-test` | ⟳ Delete | Move | — | **merge-then-remove** — **複核改判**（原判 remove 不 merge）。原方案用「>80% 是 foreign-repo 綁定，參數化等於重寫」壓掉 merge 選項——實測是錯的：`grep -rEc "PigeonPea|\./dotnet|console-app|shared-app|windows-app"` 逐檔加總 **50 行 / 全樹 1117 行 = 4.5%**。`references/run-benchmarks.md:83-313` 的 230 行是零綁定的可攜 BenchmarkDotNet 知識，且 corpus 內沒有任何一處有 baseline ratio 判讀、multimodal distribution 干擾警示或 Release-mode 失敗排除。三分之二的樹（unit-test、coverage）確實被 `dotnet-testing-best-practices/references/{cli,integration-testing}.md` 壓過，那部分 remove 站得住。上游 pigeon-pea `pushed_at` 2025-11-29，死了 8 個月。 |
| `dotnet-testing-best-practices` | Keep | Trim | — | 取 Claude：Keep：自有、EFF=487 未超標、description 觸發詞完整、與 dotnet-test 的關係是「它是留下來的那個」——dotnet-test 退場後的 ReportGenerator 與 Benchma |
| `dotnet-winforms-best-practices` | Trim | Trim | ✅ | 採納（兩份一致）：保留 Designer/UI-thread/GDI；移除 layout 偏好 |
| `ef-core-best-practices` | Keep | Trim | — | 取 Claude：Keep：自有、EFF=442 未超標、與 ef6-best-practices 的路由界線用 namespace 而非 TFM 判定（可機械驗證），無 collision。 |
| `ef6-best-practices` | Keep | Keep | ✅ | 採納（兩份一致）：EDMX/ObjectStateManager/legacy Include 行為獨有 |
| `frontend-release-verification` | Keep | Trim | — | 取 Claude：Keep 依據：488/500 未超標、description trigger-led、持有 backend 版沒有的前端 gate（L29-34 Static/Unit/Build/Browser-E2E/Visual |
| `grill-me` | Keep | Keep | ✅ | 採納（兩份一致）：薄、explicit user-only router |
| `grill-with-docs` | Keep | Keep | ✅ | 採納（兩份一致）：grilling＋domain-modeling composition 明確 |
| `grilling` | Keep | Keep | ✅ | 採納（兩份一致）：低風險前進、高風險停下與逐題確認程序有效 |
| `handoff` | Keep | Keep | ✅ | 採納（兩份一致）：canonical artifacts、redaction、next-session prompt 有價值 |
| `implement` | Keep | Trim | — | 取 Claude：Keep，且不採納 Codex 的 Trim。它主張的「不得自行 branch/commit」已由 kernel [INT-6] 逐字覆寫；為此改一個 70 words 的 byte-pinned 檔＝零收益換永久 me |
| `improve-codebase-architecture` | Trim | Split | — | 取 Claude：報告用，**override 不建議**。同時更正 Codex 的前提：本 skill 並沒有「強制寫檔進 repo」，L39 明寫寫到 $TMPDIR，Codex 的 Trim 理由事實錯誤。真正值得記的是 L27 的 |
| `init-project-docs` | ⟳ Trim | Trim | ✅ | 採納（兩份一致）：主檔縮成 routing/gates；host/stack catalog 下沉 |
| `jest-best-practices` | Keep | Keep | ✅ | 採納（兩份一致）：ESM mock order、flake triage 等內容具體 |
| `make-skill-template` | Collision | Move | — | **remove** — 維持，且用實證打掉兩條替代路線。先前的隱憂「remove 會讓 Copilot 失能」被推翻：**三個 host 各自都有原生 skill creator**——Claude 內建 skill-creator(usage 18) + 兩支 plugin creator；Codex 有 `~/.codex/skills/.system/{skill-creator,plugin-creator}`；Copilot 的 `copilot skill list --json` 回傳 `skill-creator`(enabled) 與 `microsoft-skill-creator`。(a) override 加 host scope = 把 Copilot 導向比它自家 plugin creator 更弱的一支，負價值，且 awesome-copilot 上游每日在動（pushed_at 2026-07-31），fork 要付反覆的 merge 成本。(b) external-integration 補 kernel routing = 把三個 host 都導向各自都有更好替代品的 skill。另有 foreign-repo 綁定：`SKILL.md:124` 的 `npm run skill:validate` 是 awesome-copilot 自己的指令，本機不存在。 |
| `microsoft-code-reference` | Keep | Collision | — | 取 Claude：Keep：扣除 microsoft-learn MCP server 自帶 instructions 後仍有實質獨有內容，EFF 419 未超標，與 microsoft-docs 無碰撞。VND，無需任何動作。不採 Co |
| `microsoft-docs` | Keep | Collision | — | **wholesale-replacement（有前置閘）** — **結論翻轉**。前一輪的「VND report-only 不可修」前提被證偽——上游 github/awesome-copilot HEAD（`822d0407de`, 2026-03-16）**自己已經修好工具表**（三列俱全，另附 Learn MCP 不可用時的 mslearn CLI 對照）。所以正確動作是 gate 明列合法的 wholesale replacement，不是 in-place 加一列。但**成本非零**：`tests/vendored-detection.sh:249-262` 對 vendored-skills.lock 每列檢 payload+tree SHA、`tests/matt-thin-workflow.sh:353-359` 另外對 stage-b2-skills.lock 檢 tree SHA，兩份 lock 都有它 → 2 份 lock × 3 個 hash 欄 + 2 支 suite。**且有前置閘**：新上游把 description 改成跨域研究 skill（'code examples across Azure, .NET, Aspire, VS Code, GitHub… with Context7 and Aspire MCP'），會 (i) 侵入 `microsoft-code-reference` 觸發域（兩側皆 pinned vendored，構成不可改的 collision）、(ii) **反轉 `context7-mcp` 現行 description 的箭頭**（就是 663bce4 剛加的那句）。唯一可動的槓桿在 house-owned 的 `context7-mcp` 那側，必須先解消再落地。 |
| `mp-zoom-out` | Keep | Keep | ✅ | 採納（兩份一致）：保留 pre-edit callers/callees map；不是 Matt skill |
| `mysql-best-practices` | Keep | Trim | — | 取 Claude：Keep：自有檔、EFF 410 未超標、hub-and-spoke 結構完整、12 條 Golden Rules 版本精確且 corpus 內無重複，無任何可執行的優化動作。不採 Codex 的 Trim。 |
| `native-feel-cross-platform-desktop` | ⟳ Trim | Keep | — | 取 Claude：LOW 純資訊回報：654 chars 為 corpus 最長 description（EFF 900 亦超標），但明確**不**提 Trim、**不**提 Delete。Keep 依據見 evidence。 |
| `next-best-practices` | Keep | Trim | — | 取 Claude：Keep：未超標（353/500，全群第二小），Codex 指的「固定 stack」不在 SKILL.md 主體、而是 reference 檔的目錄描述文字，非指令。 |
| `nodejs-best-practices` | Keep | Trim | — | 取 Claude：Keep：未超標（395/500），Codex 的 Trim 缺 OVER 前提；唯一被點名的 Pino 是括號內舉例，主張本體是 structured logging + correlation ID，不是純 stan |
| `nuget-manager` | ⟳ Delete | Trim | — | **remove** — 維持。override 在此是空操作——缺陷是「內容被超集覆蓋」，5 步只讓 fork 變成有記錄的決定，不會刪掉另一支自有檔裡的同一份內容。`dotnet-core-best-practices/references/configuration-hosting.md:554-610` 逐行涵蓋且反向多出 `dotnet list package --outdated/--vulnerable`、`dotnet nuget why`、`nuget.config auditSources`。**routing 補償已定價**：全 81 支只有它一支 description 含 NuGet/package 字樣，補償是改自有檔 `dotnet-core-best-practices:3` 把 `configuration binding` 換成 `NuGet/CPM package management`，實測 wc -w 498→499，仍在界內。 |
| `nuxt` | Collision | Trim | — | 取 Claude：在 nuxt description 尾端補負向路由（例：`runtime reactivity/hydration debugging → vue-debug-guides; component patterns →  |
| `pinia` | Keep | Trim | — | 取 Claude：Keep：未超標（457/500），Testing Decision Tree 是 corpus 內唯一覆蓋 createTestingPinia 四種模式的來源。 |
| `playwright-best-practices` | Keep | Collision | — | 取 Claude：Keep：EFF 374 未超標、description 以工具名自帶 disambiguator、browser 三角中唯一不碰撞的一支。VND，無需動作。不採 Codex 的 Collision。 |
| `postgresql-best-practices` | Keep | Keep | ✅ | 採納（兩份一致）：canonical PostgreSQL correctness/performance target |
| `postgresql-optimization` | Keep | Trim | — | **已執行** — HIGH 修正 SKILL.md:45 為 `CREATE INDEX CONCURRENTLY`、`DETACH PARTITION … CONCURRENTLY` (PG 14+)，並加註「`AT |
| `prototype` | Keep | Trim | — | 取 Claude：Keep，不採納 Codex 的 Trim。L26 的 commit 已被 kernel S6 L106 的一般 gate 約束，且目標是 throwaway branch 而非 main；未超標的 byte-pinne |
| `react-best-practices` | ⟳ Keep | Keep | ✅ | 採納（兩份一致）：trigger 與 React-specific failure shields 合理 |
| `react-router-framework-mode` | Keep | Keep | ✅ | 採納（兩份一致）：Framework Mode 專用邊界清楚 |
| `research` | Collision | Collision | ✅ | 採納（兩份一致）：current docs route Context7；寫 Markdown artifact 必須 opt-in |
| `resolving-merge-conflicts` | ⟳ Keep | Trim | — | 取 Claude：在三份 guard hook（~/.agents/hooks/guard-git-push.sh 與 ~/.claude、~/.codex 兩份實體複本）旁加一支同型 PreToolUse guard：偵測 .git/M |
| `sdd` | Trim | Trim | ✅ | 採納（兩份一致）：保留 proposal→implementation→archive gates；刪重複 workflow |
| `security-audit` | Collision | Collision | ✅ | **external-integration-only** — **維持不改**，但理由從「規則禁止」換成「override 路徑不存在」：它不在任何 lock 檔（三個 lock 全查皆無），VND 純由 LICENSE 產生，所以 override 步驟 1「diff against the pinned upstream commit」**無 pin 可 diff**。更硬的破口：只要在 fork-index 記一列，`vendored_flag` 就回 VND* 而非 VND，`tests/vendored-detection.sh` 的 corpus 迴圈只 match `case … in VND)`，它會從 actual 掉出而 `:236` 硬編碼的 expect_vnd 仍列它 → FAIL；若另加 lock 一列，再撞 `:248` 硬編碼的 `"12"`。單側修正已足夠且是三層覆蓋（663bce4 的 description + dev-workflow S0:49 三分路由 + tests 斷言記錄）。 |
| `security-review` | Collision | Collision | ✅ | **已執行** — 改 security-review 自己的 description（self-owned，Step 0 不擋）：刪掉裸的 "audit this"，並補上反向 disambiguator「whole- |
| `setup-matt-pocock-skills` | Trim | Trim | ✅ | 採納（兩份一致）：保留 maintenance/update path；刪重複 catalog/host 說明 |
| `tailwind-v4-shadcn` | Keep | Keep | ✅ | 採納（兩份一致）：專用 stack skill 邊界清楚 |
| `tdd` | ⟳ Trim | Keep | — | 取 Claude：修法落在 kernel，不動 tdd。於 dev-workflow 加一條比照 [INT-6] 形制的 [INT-9]：明文指出顯式走本 workflow 時，tdd:22 的「每個 seam 都須向使用者確認」由 [I |
| `teach` | Trim | Split | — | 取 Claude：報告用，**override 不建議**。同時否定 Codex 的 Split：teach 沒有 mandatory ordered procedure，不符 skill-standards mixed-type 判準， |
| `testing-library-react-best-practices` | Keep | Keep | ✅ | 採納（兩份一致）：RTL-specific query/user-flow rules 有獨特性 |
| `to-spec` | Trim | Trim | ✅ | 採納（兩份一致）：保留 specification entrypoint；共用 clarification route workflow |
| `to-tickets` | Trim | Trim | ✅ | 採納（兩份一致）：保留 ticket decomposition；移除重複 workflow prose |
| `triage` | Trim | Trim | ✅ | 採納（兩份一致）：縮成 routing decision；host syntax 下沉 adapter |
| `typescript-best-practices` | Keep | Keep | ✅ | 採納（兩份一致）：TypeScript-specific safety 與邊界合理 |
| `vite` | Keep | Keep | ✅ | 採納（兩份一致）：Vite config/build/debug trigger 明確 |
| `vitest` | Keep | Keep | ✅ | 採納（兩份一致）：Vitest-specific mocking/configuration failure shields |
| `vue-best-practices` | Move-to-host/repo-instructions | Keep | — | 取 Claude：刪除 Golden Rules 第 12 條（Naive UI default…），目的地已存在（~/.claude|.codex|.copilot/rules/frontend-spa.md:16「Vue SPA →  |
| `vue-debug-guides` | Keep | Keep | ✅ | 採納（兩份一致）：Vue runtime symptom diagnosis 有獨特性 |
| `vueuse-functions` | Keep | Keep | ✅ | 採納（兩份一致）：VueUse-specific 選型與 SSR guard 有價值 |
| `wayfinder` | ⟳ Trim | Split | — | 取 Claude：若要執行需標 `proposed override required`；建議先報告不動。Externalize 目標明確：map body template（L31-53）、ticket body template（L5 |
| `web-design-reviewer` | Collision | Collision | ✅ | **merge-then-remove（merge target 改為 frontend-release-verification）** — **複核大幅改寫 scope**。原方案要把巡檢迴圈搬進 `css-ui-best-practices`——但 css-ui 全檔沒有任何 browser workflow，掛進去等於在純 code-level CSS 規則 skill 裡開一條它不執行的流程。正確 target 是 `frontend-release-verification`（self-owned，已有 browser journey / viewport evidence / console-page-error 三件事）。**只搬 4 條真正無人覆蓋的 loop mechanics**：rendered 元素→原始碼反查、HMR reload 再截圖比對、單一 issue 3 次修復上限即詢問、styling method→edit target 對照。**明列 DO-NOT-COPY**：styled-components/Emotion 段已在 `react-best-practices/references/styling-and-ui.md:319-361`、Vue `:deep()` 已在 `vue-best-practices/references/styling-and-ui.md:23-40`（比上游深）、P1/P2/P3 會在 css-ui 造出第三套 severity 詞彙。**word-budget 硬約束**：FRV 488/500 只有 12 字 headroom，所有內容必須落在 `references/`，SKILL.md 只能加一行指標。 |
| `writing-great-skills` | Keep | Keep | ✅ | 採納（兩份一致）：authoring quality、trigger boundaries、progressive disclosure 有價值 |
