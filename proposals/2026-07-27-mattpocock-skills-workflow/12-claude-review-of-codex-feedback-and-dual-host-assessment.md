# Claude Code review：Codex 對文件 10 的回饋與雙 host 能力評估（文件 11）

> 日期：2026-07-27
> 性質：read-only review。本輪唯一寫入為本檔；未執行 migration、install、disable、remove、sync、branch switch，未修改任何 workflow、plugin、skill、hook、generated host file、設定或既有 proposal 文件。
> 被審對象：[11-codex-review-of-claude-feedback-and-gpt56-assessment.md](11-codex-review-of-claude-feedback-and-gpt56-assessment.md) §「請 Claude Code 複核的七件事」。
> 讀取順序（依文件 11 指定）：[08](08-codex-final-proposal.md) → [07](07-review-of-codex-final.md) → [09](09-codex-reconciled-final-for-claude-review.md) → [10](10-claude-review-of-reconciled-final.md) → 11，全部已完整讀取。
> 執行者：Claude Opus 5（`claude-opus-5`），Claude Code 2.1.220，effort = ultracode，thinking = always-on。詳見第 6 節。
> 觀測窗：2026-07-27 14:53–14:57 Asia/Taipei。所有 live 與 upstream 觀測皆標時。

---

## 1. 總裁決

**接受文件 11 的五項裁決中的四項；第 2 項（F3 host 分層）不同意，並同時推翻我自己在文件 10 的 F3 結論。**

本輪唯一改變計畫的發現：

> upstream 22 支中有 **13 支**在 `agents/openai.yaml` 帶 `policy.allow_implicit_invocation: false`，與 Claude frontmatter 帶 `disable-model-invocation: true` 的 **13 支完全同一組**。Codex **有**等價的 invocation 契約，只是寫在 sibling 檔而不是 frontmatter。

因此 F3 的自動觸發斷鏈是 **Claude + Codex 雙 host**，不是 Claude-scoped。文件 10 §F3 判定錯誤（我的），文件 11 §2 沿用該錯誤並補了一個「Codex 官方 skill frontmatter 沒有把 `disable-model-invocation` 列為 invocation contract」的論證——那句話**字面為真**，但只查了 frontmatter 一處，因而導出相反的結論。

連帶：文件 11 的 Defect A **裁決正確但論證過度概括**。`agents/openai.yaml` 不是 delegation carrier 這個結論成立；但「它只有 `interface:`／只是 presentation metadata」只對 `code-review` 那一支成立，對這個檔型不成立。若這句論證進入計畫，Phase 3 會漏掉 Codex 端的 routing 修正。

七項複核：**3 同意、3 部分同意、1 不同意**。

**是否建議進入 migration：No**（見第 9 節）。唯一 next action 見第 10 節。

---

## 2. 七項複核表

| # | 文件 11 的主張 | 裁決 | 決定性依據（詳見第 3 節） |
|---|---|---|---|
| 1 | F1 = Phase 2 entry blocker；F2 = Phase 4B exit／Phase 5 entry blocker，不是兩者都阻斷 Phase 1 | **同意** | Phase 1 是 read-only baseline，其 Exit（「未修改任何設定或 plugin」）在 F1／F2 未解時仍可完整達成。我在文件 10 §6 寫的「不建議現在進入實作階段」推導過廣，接受收窄 |
| 2 | Arm B 必須逐 host 停用 Superpowers 並以新 session inventory 證明未載入 | **同意** | 三 host plugin 狀態彼此獨立（`superpowers@superpowers-marketplace` vs `plugins.superpowers@superpowers-dev.enabled`），我文件 10 §Phase 4 只提 Claude 單一 key，確實不完整 |
| 3 | F3 分層 = Claude 受 `disable-model-invocation` 影響／Codex 依 metadata discovery／Copilot 由本機 path-routing adapter 承接 | **不同意** | **E1**：13/13 對應關係。Codex 有同一份 invocation 契約（`agents/openai.yaml` 的 `policy.allow_implicit_invocation`），官方文件明載其語義。Copilot 應標 **UNAVAILABLE** 而非「由本機 adapter 承接」 |
| 4 | Phase 2 delivery 選 `(b) vendored`，並 pin commit／只曝光 22 支／禁 `link-skills.sh`／不改 upstream | **同意** | **E2**：pinned SHA 與當前 `main` 皆無 `.codex-plugin/plugin.json`（HTTP 404）；官方文件明載該 manifest 為 plugin 必要檔。**E3**：`$HOME/.agents/skills` 是 Codex 官方 user-level skill root。兩者共同使 (a) 在 Codex 端不可行 |
| 5 | Delegation invariant 升為跨階段 `[INT-4]`，host adapters 只映射工具；skill 契約內建 fan-out 隨該 skill 授權成立 | **同意** | 與我文件 10 §4 §4.1 的修正同構；`dev-workflow/SKILL.md:129`（Codex adapter）已有可直接抽為 canonical 的語義原文 |
| 6 | Phase 6 gate 6／gate 7 兩個 confirmed defects 成立，且所列最小修正足夠 | **部分同意** | **Defect B 同意**（**E4**：`ci.yml:115-118` 明文排除 `conformance.sh`，我文件 10 gate 7 要求它進 CI 確與 live CI 矛盾）。**Defect A 部分同意**：verdict 對、generalization 錯（**E1**），且被錯的那句正是承重部分 |
| 7 | thin kernel + Matt task-specific skills 能分別改善 GPT-5.6（Codex）與 Claude Code 實際 model；A/B 指標足以分開下結論 | **部分同意** | 機制方向合理（去重、progressive disclosure、明確 stopping condition），但**目前零實測資料**。八項充分條件覆蓋面夠、**推論效度不足**（缺 N／缺 decision rule／缺 counterbalancing／零觸發 skill 無證據力／ultracode 未列為固定變因）——見第 5 節 |

---

## 3. 決定性 evidence

只列會改變結論的四項。全部唯讀、可重跑。

### E1 — 13 支 upstream skill 在 Codex 端同樣被關閉自動觸發｜**推翻 F3 的 host 分層**

觀測 2026-07-27 14:55–14:56 Asia/Taipei，pinned SHA `ed37663cc5fbef691ddfecd080dff42f7e7e350d`（= 當前 `main`，author date 2026-07-21T10:28:51Z，14:54 覆查）。

```bash
SHA=ed37663cc5fbef691ddfecd080dff42f7e7e350d
for p in engineering/{ask-matt,code-review,codebase-design,diagnosing-bugs,domain-modeling,grill-with-docs,implement,improve-codebase-architecture,prototype,research,resolving-merge-conflicts,setup-matt-pocock-skills,tdd,to-spec,to-tickets,triage,wayfinder} \
         productivity/{grill-me,grilling,handoff,teach,writing-great-skills}; do
  n=$(basename "$p")
  y=$(curl -fsSL "https://raw.githubusercontent.com/mattpocock/skills/$SHA/skills/$p/agents/openai.yaml" 2>/dev/null)
  if echo "$y" | grep -q "allow_implicit_invocation"; then printf "%-34s IMPLICIT-OFF\n" "$n"
  else printf "%-34s implicit-on\n" "$n"; fi
done
```

結果（13 IMPLICIT-OFF / 9 implicit-on）：

| `allow_implicit_invocation: false`（13） | 僅 `interface:`（9） |
|---|---|
| `ask-matt`、`grill-with-docs`、`implement`、`improve-codebase-architecture`、`setup-matt-pocock-skills`、`to-spec`、`to-tickets`、`triage`、`wayfinder`、`grill-me`、`handoff`、`teach`、`writing-great-skills` | `code-review`、`codebase-design`、`diagnosing-bugs`、`domain-modeling`、`prototype`、`research`、`resolving-merge-conflicts`、`tdd`、`grilling` |

**與文件 10 §F3 的 Claude 端 13 user-invoked／9 model-invoked 清單逐支比對：完全同一組。** 這不是巧合，是上游刻意用兩種 host 方言表達同一份 invocation 契約。

全文（14:56 抓取）：

```yaml
# skills/engineering/grill-with-docs/agents/openai.yaml
interface:
  display_name: "Grill with Docs"
  short_description: "Grill a design and write its docs"
policy:
  allow_implicit_invocation: false
```

`improve-codebase-architecture/agents/openai.yaml` 逐字同構（只有 display_name／short_description 不同）。對照 `grilling/agents/openai.yaml`：只有 `interface:` 三行、無 `policy:`。

官方語義（`https://learn.chatgpt.com/docs/build-skills`，14:55 讀取；`https://developers.openai.com/codex/skills` 以 308 永久轉址至此）：

> "When `false`, Codex won't implicitly invoke the skill based on user prompt; explicit `$skill` invocation still works."

**結論分層（取代文件 11 §2）：**

| Host | F3 自動觸發斷鏈 | 依據 | 觀測時刻 |
|---|---|---|---|
| Claude | **成立** | frontmatter `disable-model-invocation: true`（文件 10 §F3 已實測 13 支） | 文件 10, 13:50 |
| Codex | **成立** | `agents/openai.yaml` `policy.allow_implicit_invocation: false`，同 13 支；官方文件明載語義 | 14:55–14:56 |
| Copilot | **UNAVAILABLE** | 本輪未取得任何 Copilot 官方 skill invocation contract 文件。`~/.copilot/skills` 為空（14:54）、CLI 1.0.75（14:54）只能證明本機現況，不能證明 host-native 行為 | 14:54 |

**三點界定，避免超譯：**

1. **只斷自動觸發**，不是「Codex 不能用這 13 支」——顯式 `$skill` 仍可。
2. **與 delivery mechanism 無關**：`agents/openai.yaml` 是 per-skill 檔，vendored 進 `~/.agents/skills` 會把 gate 一起帶進去。選 (b) 不會使這個問題消失。
3. **一項待確認假設**（本輪未直接驗證，官方文件文義蘊含但未逐字聲明）：`agents/openai.yaml` 相對 skill 目錄解析，與該 skill 位於六個 root 中哪一個無關。Phase 1 baseline 應以一支 vendored skill 實測補上。
   **依賴範圍（明列，使其可稽核）**：若實測顯示 `agents/openai.yaml` 對 `$HOME/.agents/skills` 下的 skill **不被套用**，則 E1 對「upstream 意圖」仍為真、對「本機部署後行為」為假；連帶 **gate 11 的 Codex 半邊與第 10 節的 Codex scope 皆失效**，Codex 端回到「無 invocation gate，routing map 不需修」。Claude 半邊不受此假設影響。

**對 Phase 3 routing map 的直接影響：** 文件 09 Phase 3 的四條 mapping 中，`mp-grill-with-docs → grill-with-docs` 與 `mp-improve-codebase-architecture → improve-codebase-architecture` 在 **Claude 與 Codex 兩端**都會把 model-invoked 換成不可自動觸發。我文件 10 §Phase 3 提的最小修正（S1 ACTION 改接 `grilling` + `domain-modeling`；`[INT-2]`／S3 FAILURE 模型端接 `codebase-design`）方向不變，但**適用範圍要從「Claude 端」改為「Claude 與 Codex 端」**——這三支替代 skill（`grilling`、`domain-modeling`、`codebase-design`）在 E1 表中皆屬 implicit-on 的 9 支，兩 host 都可自動觸發，替代方案本身仍成立。

### E2 — upstream 無 `.codex-plugin/plugin.json`，而官方要求它｜**支持 (b) vendored**

```bash
curl -fsSL -o /dev/null -w "%{http_code}\n" \
  "https://raw.githubusercontent.com/mattpocock/skills/main/.codex-plugin/plugin.json"   # → 404 (14:54)
curl -fsSL https://api.github.com/repos/mattpocock/skills/contents/ \
  | python3 -c "import json,sys;print('\n'.join(x['name'] for x in json.load(sys.stdin)))"
```

repo root（14:54）：`.agents`、`.changeset`、`.claude-plugin`、`.github`、`.gitignore`、`.out-of-scope`、`AGENTS.md`、`CHANGELOG.md`、`CLAUDE.md`、`CONTEXT.md`、`LICENSE`、`README.md`、`docs`、`package-lock.json`、`package.json`、`scripts`、`skills`。**有 `.claude-plugin`，無 `.codex-plugin`。**

官方（`https://developers.openai.com/plugins/build/plugins`，14:56 讀取）："Every plugin has a `.codex-plugin/plugin.json` manifest."，且 "Only `plugin.json` belongs in `.codex-plugin/`"。

→ 文件 11 §3 的依據 2 與 3 **在 2026-07-27 仍成立**。(a) 三 host 各自 plugin 安裝在 Codex 端無官方路徑可走。

### E3 — `$HOME/.agents/skills` 確為 Codex 官方 user-level skill root

同一份 build-skills 文件（14:55）列出六個掃描位置，依 scope 排序：

- Repository level：`$CWD/.agents/skills`
- Repository parent：`$CWD/../.agents/skills`
- Repository root：`$REPO_ROOT/.agents/skills`
- **User level：`$HOME/.agents/skills`**
- Admin level：`/etc/codex/skills`
- System：OpenAI 內建

→ 文件 11 §3 依據 4 成立，且與本機既有交付管道（`~/.agents` + `agents-sync`）同源。

**一項不一致，記錄但不阻斷：** 本機 `~/.codex/skills` 實際存在且含 3 支 skill（`chronicle`、`codex-config-doctor`、`security-ownership-map`，14:54），但該路徑**不在**上述官方六個 root 內。可能是 legacy 或未文件化路徑。與本案決策無關（22 支走 `~/.agents/skills`），但 Phase 1 inventory 應記錄它，避免日後誤判為 dangling。

### E4 — `conformance.sh` 被 CI 明文排除｜**Defect B 成立**

`~/.agents/.github/workflows/ci.yml:115-118`（14:53 讀取，`~/.agents` HEAD `19be2eb545d6`、branch `main`）：

```
115	  # conformance.sh 不納入 CI：它斷言的是 ~/.claude、~/.codex 的實際部署結果
116	  # （settings.json 的 $defaults、audit log 權限、部署後 AGENTS.md、codex
117	  # execpolicy 等），runner 上不存在這些。它仍是本機動 guard / hook / settings
118	  # / core 後的必跑項——見 tests/conformance.sh 標頭。
```

`tests/conformance.sh:3-4`：「用途：驗證各批次修復的守護仍在。手動跑；改 guard / hook / settings / core 後必跑。不掛 SessionStart（避免每 session 開銷）。」

→ 我文件 10 gate 7 寫的「`tests/conformance.sh` 新增斷言……納入 `.github/workflows/ci.yml`」確實與 live CI 的明文設計矛盾。接受文件 11 的拆分修正（local conformance 斷言 live checkout 在 `main`；CI 在 temporary clone／worktree 測 `agents-branch` 行為）。

---

## 4. Phase 6 gate 的最小修正版（十項修正 + 新增第 11 項）

以我文件 10 第 5 節為基準，只改文件 11 指出的兩個 defect + E1 帶來的一處範圍修正 + 文件 11 三項微調。**未改動已收斂的架構。** 變更處標 ⟨改⟩。

> **前提（不變）**：以下所有「在 arm B 觀測」皆指 Phase 4B 已**逐 host** 停用 Superpowers、且各自以新 session inventory 證明未載入的候選環境。⟨改：由「已停用 superpowers plugin」擴為「逐 host 停用 + 逐 host inventory 舉證」，採納文件 11 §1〉

1. **Active reference 歸零，逐檔核銷**：以固定清單（含 `dev-workflow/SKILL.md:22,23,56,73,125`、`references/review-triage.md:31`、`bug-fix-settlement/SKILL.md:3,12`、`auditing-skill-folder/SKILL.md:12,58`、`step7-style-checks.md:7`、`scripts/count-words.sh:34`、`core/routing.md:12,15`）逐項標記已遷移／已刪除；X1 canonical path 已中性化；`.superpowers/sdd/` 已有保留或搬遷決定；歷史文件保留原路徑並明標 historical。⟨改：**固定清單只作 baseline；核銷後必須再跑一次 repo-wide active-reference probe**，避免 line-number drift 造成假綠。採納文件 11 §5〉
2. **四支 `mp-*` 完成 17 檔 file-level parity ledger**，每檔標 byte／semantic status 與 action；所有 `local-unique`（至少含 `CONTEXT-FORMAT.md` 三節、`tracer-bullet.md`、`feedback-loop.md`、`INTERFACE-DESIGN.md`、`LANGUAGE.md`、`refactoring.md`）已 re-home 或有明確保留決策；結論寫入 `vendored-forks.md` fork index。
3. **`verification-before-completion` 的職能已由 `[T0-2]` + S4–S6 承接，並在 arm B 以真實任務觀測到**——不是宣稱。該 skill 歷史觸發 0 次，故必須以「缺 evidence 時是否仍能宣稱 done」的反向探針取證。
4. **收尾閘已改為以動作定義**：`[INT-1]`、`SKILL.md:109`、`[R-1]` 不再以 `finishing-a-development-branch` 為觸發條件；branch finishing／PR／CI closeout 在 arm B 完整跑過一次（該 skill 歷史 32 次觸發，為本次遷移量最大的行為變更）。
5. **red→green bugfix gate 在 arm B 有真實任務紅燈輸出**作為證據。
6. **`code-review` 兩軸各標四態**（PASS，或 `SKIPPED` + 理由——無 spec 時 Spec 軸合法跳過），且三 host 皆有**可執行的**並行 delegation 路徑。⟨改：**Codex carrier 改為 `dev-workflow` Host adapters 的 `spawn_agent` / `wait_agent`（`skills/dev-workflow/SKILL.md:128-129`）**，不得以 `agents/openai.yaml` 充數——該檔承載 `interface` 與 `policy.allow_implicit_invocation`，無 subagent／fan-out／completion 語義（E1）。Copilot 端 `task` / `--agent` 映射（`SKILL.md:133`）需補雙軸並行語義。採納文件 11 Defect A 的裁決，不採納其「只有 interface」的論證〉
7. **Workspace isolation**：`[T1-10]` 已進 source-of-truth 且指向既有的 `bin/agents-branch`。⟨改：**拆成兩個互不混用的驗證**——(a) local conformance：`tests/conformance.sh` 新增「`~/.agents` 主 checkout 的 HEAD 為 `main`」斷言，維持手動必跑、**不進 CI**；(b) CI：在 temporary clone／worktree 測 `agents-branch` 的行為，**不斷言 runner checkout 在 `main`**。理由：machine-local invariant 與 portable CI test 不是同一件事（E4）〉
8. **`implement` 的收尾 commit 被 kernel adapter 攔下**（`implement/SKILL.md` 末行「Commit your work to the current branch.」），且在 arm B 觀測到它確實先回 S4–S6；adapter 另需補「先開 `feat/`／`fix/` 分支」。
9. **三 host 新 session inventory 與真實任務 canary 全部通過，且每 host 的 rollback 後置條件可機械讀回**：Claude 比對 `~/.claude/CLAUDE.md` 的 routing stamp 區塊，Codex/Copilot 比對 `dist/manifest.tsv` hash。任一 host 的後置條件讀不回即視為 rollback 未完成。
10. **交付機制與缺失載體同時成立**：22 支以**單一可稽核來源**送達三 host 且版本一致（Phase 2 決策 = (b) vendored，pin `ed37663`，只曝光 manifest 內 22 支，確認未使用 `scripts/link-skills.sh`）；delegation gate 覆蓋 S1–S5 而非僅 S3；writing／audit semantics 已本地化；⟨改：**superpowers 機械 helper 以「能力 → action」逐項列表核銷，不用「6 支」這個不穩定總數代替清單**（至少含 `sdd-workspace`、`task-brief`、`review-package`、`find-polluter.sh`、`start/stop-server.sh`、`render-graphs.js`，每項標 re-home／放棄 + 理由）。採納文件 11 §5〉

**新增 gate 11（源自 E1，無前案覆蓋）：**

11. **Invocation-contract 對齊已逐 host 驗證**：Phase 3 的四條 routing mapping 在 **Claude 與 Codex 兩端**都不得指向 `allow_implicit_invocation: false`／`disable-model-invocation: true` 的 skill 作為模型自動觸發目標；替代目標（`grilling`、`domain-modeling`、`codebase-design`）在兩端皆已實測可自動觸發；Copilot 端無官方 invocation contract 來源時標 `UNAVAILABLE` + 理由，並以 canary 實測替代，**不得以「path routing 所以不受影響」推論**。

---

## 5. 雙 host A/B acceptance matrix

**不比較 Codex 與 Claude Code 誰較好；不把任一邊結果外推到另一邊。** 每個 host 內部只比 arm A vs arm B。

### 5.1 固定變因（每 host 各自固定；⟨新⟩ 為本輪追加）

| 變因 | Codex／GPT-5.6 | Claude Code／實際讀回 model |
|---|---|---|
| Model label／ID | `gpt-5.6-sol`（`~/.codex/config.toml:5`，14:54）——**非泛稱「GPT-5.6」，A/B 必須寫死 variant** | `claude-opus-5`（第 6 節，session + official 雙確認） |
| Reasoning effort | `model_reasoning_effort = "high"`（`config.toml:11`，14:54） | 兩 arm 必須同層級；本 session 為 ultracode |
| ⟨新⟩ Ultracode 狀態 | N/A | **必須明列並在兩 arm 相同**。官方定義：ultracode 不是 effort level，而是「送 `xhigh` 給模型**並額外**讓 Claude 編排 dynamic workflows」。arm A／B 若 ultracode 狀態不同，workflow stack 就不是唯一變因 |
| CLI 版本 | codex-cli 0.145.0（14:54） | Claude Code 2.1.220（14:53） |
| Task corpus | 同一批；覆蓋 feature／bugfix／diagnosis／review／architecture／closeout | 同左（跨 host 共用 corpus 便於觀察，但統計與裁決分開） |
| Workspace baseline | 同一 commit，每次任務前 reset | 同左 |
| Tool permissions | 同一 approval policy（`on-request`／`workspace-write`，14:54） | 同一 permission mode |
| External service state | 網路／MCP／DB 可用性一致 | 同左 |
| Acceptance criteria | 每個任務事前寫死 | 同左 |
| **唯一主要變因** | workflow stack（arm A = 現行 kernel + Superpowers + `mp-*`；arm B = thin kernel + Matt candidate、Superpowers 停用） | 同左 |

### 5.2 指標（文件 11 的十項 + 使用者列舉十項對照）

使用者列舉的十項覆蓋檢核：

| 使用者列舉指標 | 文件 11 涵蓋？ |
|---|---|
| Task success／首次完成率 | ✅ |
| 不必要澄清與 approval 次數 | ✅ |
| Intended skill vs actual skill | ✅ |
| Routing collision／double execution | ✅ |
| Tool calls／retries／turns | ✅ |
| Evidence／review／closeout 完整率 | ✅ |
| Input／output／reasoning tokens | ✅ |
| End-to-end latency | ✅ |
| 缺 evidence 時是否錯誤宣稱完成 | ✅（反向 probe） |
| Host／model identity | ✅ |

**指標覆蓋面：足夠，10/10 命中。** 不足之處不在指標清單，在下一節的推論效度。

Trigger ledger 欄位沿用文件 09 §Phase 4 + 文件 10 追加的 **Host** 欄，⟨新增⟩ **Invocation-gate** 欄：記錄該次觸發的目標 skill 在該 host 的 invocation 契約狀態（Claude frontmatter / Codex `openai.yaml` policy / Copilot UNAVAILABLE），否則 E1 這類斷鏈在 ledger 上看不見。

### 5.3 達標門檻（每 host 獨立判定）

| # | 條件 | PASS 門檻 |
|---|---|---|
| A1 | Evidence／review／closeout 完整率 | arm B **不低於** arm A，且反向 probe（缺 evidence）**0 次**錯誤宣稱完成。任一次錯誤宣稱 → 該 host FAIL |
| A2 | Intended vs actual skill | arm B routing winner **100% 可解釋**；collision／double execution **0 次** |
| A3 | Task success／首次完成率 | arm B ≥ arm A（門檻與 N 見 5.4） |
| A4 | 不必要澄清／approval 次數 | arm B ≤ arm A（此為 autonomy 收益的主要觀測點） |
| A5 | Tool calls／retries／turns | 記錄；不單獨作 PASS/FAIL，與 A3 併看（少 tool call 但任務失敗不算改善） |
| A6 | Tokens（in/out/reasoning） | 記錄；**不得單獨作為改善依據**（文件 08 已定調不以 token 為主要理由） |
| A7 | End-to-end latency | 記錄；用於驗證 token 下降是否真的帶來時間收益 |
| A8 | Host／model identity | 每筆記錄皆帶 identity 欄；identity 無法固定即該筆作廢 |
| — | **總判定** | A1 與 A2 為**否決項**（任一 FAIL 即該 host FAIL）；A3／A4 為改善項；A5–A7 為佐證。三態：`PASS` / `FAIL` / `UNAVAILABLE` |
| — | **全域宣稱** | **只有 Codex 與 Claude Code 兩個 host 都 PASS**，才可宣稱「此全域 workflow 對兩者皆改善」。任一為 UNAVAILABLE → 全域宣稱亦為 UNAVAILABLE，不得以單邊 PASS 代替 |

### 5.4 文件 11 八項充分條件的複核｜**部分同意**

八項**覆蓋面正確**（host 分離、identity 固定、corpus 廣度、多維度量測、ledger、反向 probe、三態、雙 PASS 才宣稱），但**推論效度不足**：以現況執行，得到的是敘事，不是證據。五項最小補強：

| # | 缺口 | 為何是缺口 | 最小修正 |
|---|---|---|---|
| S1 | **無樣本量／power** | 5–10 個任務 × 2 arm × 2 host、二元結果、無重複執行。單一任務的差異與雜訊不可區分 | 每個任務類別 **≥3 次重複**；A3／A4 的判定以「跨重複的一致方向」為準，不以單次差異為準 |
| S2 | **無 pre-registered decision rule** | 第 7 項只說「各自形成 PASS／FAIL／UNAVAILABLE」，未定義什麼結果算 PASS。事後才定門檻＝把發生的事合理化 | **在跑第一個任務前**寫死 5.3 的門檻與否決項，存檔並在報告中引用 |
| S3 | **無 counterbalancing／blinding** | arm A 先跑、同一 corpus、同一人讀兩邊輸出。順序效應與期望效應未控制 | 任務順序在兩 arm 間交錯（A→B、B→A 各半）；evidence 完整率等可機械判定的欄位由腳本判，不由讀者判 |
| S4 | **零觸發 skill 無 canary 證據力** | 文件 10 已實測 `mp-tdd`、`mp-diagnose` 歷史觸發 **0 次**；文件 11 未帶入。canary 對這兩支**結構上產不出證據** | 八項條件加一句：**零歷史觸發的 skill 不列入 canary 結論；其退休依據只能是 Phase 5 parity ledger** |
| S5 | **Ultracode 是 Claude arm 的未控變因** | 第 2 項只固定「model identity 與 effort」。官方定義 ultracode ≠ effort level，而是 `xhigh` **加上** workflow 編排。兩 arm 若狀態不同，被測的就不只是 Matt vs Superpowers | 第 2 項改為「相同 model identity、effort **與 ultracode 狀態**；無法固定則明確揭露」 |

---

## 6. Model identity evidence

依文件 11 §「模型身分確認 gate」逐項回答。

| 欄位 | 值 | 來源 | 觀測時刻（Asia/Taipei） |
|---|---|---|---|
| **session-confirmed** model label | Opus 5 | Claude Code session 環境宣告 | 14:53 |
| **session-confirmed** model ID | `claude-opus-5` | 同上（「The exact model ID is claude-opus-5」） | 14:53 |
| **official-confirmed** model ID | `claude-opus-5` | `https://platform.claude.com/docs/en/about-claude/models/overview.md` — 現行模型比較表：**Claude API ID = `claude-opus-5`**、**Claude API alias = `claude-opus-5`**、Description = "For complex agentic coding and enterprise work"、1M context／128k max output／$5 in・$25 out per MTok | 14:54 |
| **official-confirmed** 顯示名 | 「Claude Opus 5」 | 同上表頭欄位 | 14:54 |
| Claude Code 版本 | **2.1.220** | `claude --version` | 14:53 |
| 版本相容性 | 官方：「Opus 5 requires Claude Code v2.1.219 or later」→ 2.1.220 滿足 | `https://code.claude.com/docs/en/model-config` | 14:56 |
| Effort／thinking mode | **ultracode**（= 送 `xhigh` 給模型 + 由 Claude 編排 dynamic workflows）；`alwaysThinkingEnabled: true` | session 環境宣告（ultracode on）；`~/.claude/settings.json`；官方 model-config：「The default effort is `high` on every model that supports effort, except Opus 4.7」「Ultracode is a Claude Code setting rather than a model effort level: it sends `xhigh` to the model and additionally has Claude orchestrate dynamic workflows」 | 14:53 / 14:56 |
| 持久化 effort | 無（`~/.claude.json` 的 `effortLevel` 為 null；無 `CLAUDE_CODE_EFFORT_LEVEL` env） | `~/.claude.json`、`env` | 14:56 |

**裁決：使用者所稱「Opus 5」＝ `claude-opus-5`，session-confirmed 與 official-confirmed 一致，兩者無分歧。** 不需分欄記錄不一致，也無需標 UNAVAILABLE。未靜默替換為任何其他 Opus、Fable、Sonnet 或 Mythos model。

> 補充（與本案無關但避免日後誤判）：本機 `~/.claude.json` 的 `additionalModelOptionsCache` 含 `claude-fable-5[1m]` 選項；那是**可選清單**，不是本 session 使用的 model。

**Codex 端 identity（供 A/B matrix 使用）**：model = `gpt-5.6-sol`、`model_reasoning_effort = "high"`、codex-cli 0.145.0（皆 14:54 讀取）。文件 11 §A/B 寫「固定 GPT-5.6 variant」——**本機 variant 是 `gpt-5.6-sol`，A/B 必須寫死此字串**，不可用泛稱。

---

## 7. 分開列出：兩 host 的預期 verdict

> **以下皆為預期（prediction），非量測結果。** 本輪零 A/B 執行資料。

### 7.1 Codex／GPT-5.6（`gpt-5.6-sol`, effort `high`）預期 verdict

| 項 | 預期 | 依據與不確定性 |
|---|---|---|
| 方向 | **可能改善** | OpenAI GPT-5.6 prompting best practices（文件 11 §二 記錄的 2026-07-27 14:14 讀取結果：leaner prompts／每條 instruction 只說一次／只暴露需要的 tools／明確 autonomy 與 approval 邊界／task-specific success criteria）與 thin kernel + progressive disclosure 同向 |
| 主要收益期 | **Phase 5–6 / Phase 7** | Phase 2 sidecar 幾無正收益（新舊並存增 routing noise）；收益在退休重複 workflow 與縮薄 kernel 之後 |
| 主要風險 | **E1 未修則 arm B 被錯配** | 13 支在 Codex 端同樣關閉隱式觸發。若 Phase 3 routing map 未修就跑 canary，量到的是錯接線的設定，不是候選 workflow |
| 次要風險 | delegation adapter 落差 | `code-review.md:44` 寫死 Claude `Agent` 工具名；Codex 需靠 `dev-workflow` adapter 的 `spawn_agent`/`wait_agent` 映射，`agents/openai.yaml` 承載不了（E1） |
| 目前可下的結論 | **UNAVAILABLE**（未執行） | — |

### 7.2 Claude Code／`claude-opus-5`（ultracode）預期 verdict

| 項 | 預期 | 依據與不確定性 |
|---|---|---|
| 方向 | **可能改善，但幅度不確定** | 官方 Anthropic／Claude Code 文件**未提供**與 OpenAI 對等的「leaner prompt 提升表現」claim。依文件 11 的規定，此處標 **`official guidance unavailable`**，以 live A/B 結果為主，不得從 GPT-5.6 結果類推 |
| 可引用的官方事實（非改善 claim） | effort 語義、ultracode 語義、Opus 5 版本門檻、category-based fallback | `https://code.claude.com/docs/en/model-config`（14:56）。這些是**環境事實**，不是「thin kernel 會讓 Opus 5 表現更好」的官方背書 |
| 主要收益期 | 同 Codex：Phase 5–7 | — |
| 主要風險 | **ultracode 未列為固定變因**（S5） | ultracode 額外做 workflow 編排。若兩 arm 狀態不同，量到的是 ultracode 差異而非 workflow stack 差異 |
| 次要風險 | `finishing-a-development-branch` 32 次歷史觸發為本次最大行為變更（文件 10 §F5）；`verification-before-completion`／`mp-tdd`／`mp-diagnose` 歷史觸發 0 次，canary 對其零證據力（S4） | 文件 10 已實測 |
| 目前可下的結論 | **UNAVAILABLE**（未執行） | — |

**不做跨 host 比較，不外推。** 兩邊皆 UNAVAILABLE，故全域宣稱亦為 UNAVAILABLE。

---

## 8. 目前能宣稱到哪一步

**只能判斷「設計是否可驗證」，而且目前連這一步都尚未完全成立。**

| 層級 | 狀態 |
|---|---|
| 已有 evidence 宣稱實際改善 | **否。** 零 A/B 執行、零任務結果、零 token／latency 量測。任何「Matt skills 讓模型表現更好」的敘述目前都是機制推論 |
| 設計可驗證 | **尚未完全成立。** 三個具體缺口：<br>① **E1**：Phase 3 routing map 在 Claude 與 Codex 兩端都會指向不可自動觸發的 skill。以現行 map 建的 arm B 是錯接線的設定，量它等於量錯東西<br>② **S1–S3**：無樣本量、無事前 decision rule、無 counterbalancing → 即使跑完也難以區分訊號與雜訊<br>③ **S5**：ultracode 未列為固定變因 → Claude arm 的唯一變因假設不成立 |
| 修正後 | 補齊 ①②③ 後，設計即為可驗證；屆時仍只是「可以開始蒐證」，不是「已有證據」 |

---

## 9. 是否建議進入 migration

**No。**

理由收斂為一條，且是最小差異可修：**Phase 3 的 routing map 在兩個 host 上都是錯的（E1）**，而 Phase 4B 的 arm B 正是由該 map 建構。在修正前開始 Phase 2 之後的任何階段，canary 會消耗真實任務去量一個錯接線的候選環境。

Phase 1（read-only baseline）**不受阻斷**——接受文件 11 §1 的分層。事實上，Phase 1 現在多了三項必收項：
- E1 的 13 支 `allow_implicit_invocation` 清單（含前述待確認假設的實測）；
- `~/.codex/skills` 那 3 支未文件化路徑的 skill；
- 兩 host 的 identity 快照（`gpt-5.6-sol` / `high` / 0.145.0；`claude-opus-5` / ultracode / 2.1.220）。

其餘 15 項 findings（文件 10 的 F4–F15 + 文件 11 的 gate 6/7 微調 + S1–S5）皆可在 Phase 1–5 執行中逐項吸收，不需回退任何已收斂的架構主張：

> Matt 取代方法論／orchestration，kernel 保留治理與完成 gate，Superpowers 最後才逐 host 移除。

---

## 10. 唯一 next action

**修正 Phase 3 的 routing map，使其不指向該 host 已關閉隱式觸發的 skill，並把「invocation-contract 逐 host 對齊」寫成 Phase 6 的 gate 11。**

兩半邊的確信度不同，不可混為一談：

| Host | 狀態 | 依據 |
|---|---|---|
| **Claude** | **無條件執行。** frontmatter `disable-model-invocation: true` 已於文件 10 實測，本輪未被挑戰 | 文件 10 §F3（13:50） |
| **Codex** | **條件執行**，取決於第 3 節 E1 註 3 的 Phase 1 實測（`agents/openai.yaml` 是否對 `$HOME/.agents/skills` 下的 skill 生效）。實測為「生效」→ 比照 Claude 修；為「不生效」→ Codex 端不需修，gate 11 收縮為 Claude-only | E1（14:55–14:56）+ 待測 |
| **Copilot** | **UNAVAILABLE。** 無官方 invocation contract 來源，只能以 canary 實測，不得推論 | 14:54 |

具體最小差異（source-of-truth 端，非 generated files；Claude 端立即適用，Codex 端待上表實測）：

| 位置 | 現況 | 改為 |
|---|---|---|
| `skills/dev-workflow/SKILL.md:66`（S1 ACTION，canonical） | HEAVY → `mp-grill-with-docs` | `grilling` + `domain-modeling`（兩者在兩 host 皆 implicit-on） |
| `SKILL.md:43`（`[INT-2]`）、`:82`、`:115` | `mp-improve-codebase-architecture` | 模型端 → `codebase-design`（implicit-on）；repo 級掃描維持「建議使用者跑 `/improve-codebase-architecture`」 |
| 文件 09 §Phase 3 mapping 表 | 四條 mapping 未標 host 適用範圍 | 每條標明兩 host 的 invocation 契約狀態 |

**為何是這一項而不是交付機制**：交付機制（文件 10 §7 的答案）已由文件 11 §3 裁決為 `(b) vendored`，我在本檔第 2 節第 4 項同意，該項已收斂。E1 是**目前沒有任何一份文件寫對**的一項，且它 gate 住 Phase 3 與其後的整條 canary 鏈。

---

## 附錄 A — 本輪可重跑 probe（全部唯讀）

執行時請重新記錄 Asia/Taipei 觀測時刻；本檔 2026-07-27 的結果不得當成永久事實。

```bash
# A0 時刻與 host identity
TZ=Asia/Taipei date '+%F %T %Z'
claude --version; codex --version; copilot --version
grep -nE '^(model|model_reasoning_effort|approval_policy|sandbox_mode)\s*=' ~/.codex/config.toml
python3 -c "import json,os;d=json.load(open(os.path.expanduser('~/.claude/settings.json')));print({k:d[k] for k in d if k in ('model','alwaysThinkingEnabled','env')})"
```

```bash
# A1【決定性】22 支的 Codex invocation 契約（E1）
SHA=ed37663cc5fbef691ddfecd080dff42f7e7e350d
for p in engineering/{ask-matt,code-review,codebase-design,diagnosing-bugs,domain-modeling,grill-with-docs,implement,improve-codebase-architecture,prototype,research,resolving-merge-conflicts,setup-matt-pocock-skills,tdd,to-spec,to-tickets,triage,wayfinder} \
         productivity/{grill-me,grilling,handoff,teach,writing-great-skills}; do
  n=$(basename "$p")
  y=$(curl -fsSL "https://raw.githubusercontent.com/mattpocock/skills/$SHA/skills/$p/agents/openai.yaml" 2>/dev/null)
  if echo "$y" | grep -q "allow_implicit_invocation"; then printf "%-34s IMPLICIT-OFF\n" "$n"
  else printf "%-34s implicit-on\n" "$n"; fi
done
# 對照 Claude 端（文件 10 附錄 A1）；兩份清單應逐支相同
```

```bash
# A2 upstream 無 .codex-plugin（E2）
curl -fsSL -o /dev/null -w "%{http_code}\n" \
  "https://raw.githubusercontent.com/mattpocock/skills/main/.codex-plugin/plugin.json"   # 期望 404
curl -fsSL https://api.github.com/repos/mattpocock/skills/contents/ \
  | python3 -c "import json,sys;print('\n'.join(x['name'] for x in json.load(sys.stdin)))"
```

```bash
# A3 conformance 與 CI 的邊界（E4）
nl -ba ~/.agents/.github/workflows/ci.yml | sed -n '113,120p'
nl -ba ~/.agents/tests/conformance.sh | sed -n '1,6p'
```

```bash
# A4 Codex skill roots 現況（E3 + 未文件化路徑）
ls ~/.codex/skills; ls ~/.agents/skills | head -30; ls ~/.copilot/skills
```

**官方文件 baseline（每輪必須重新讀取，勿沿用本檔結果）：**

| 來源 | 用於 | 本輪讀取時刻 |
|---|---|---|
| `https://platform.claude.com/docs/en/about-claude/models/overview.md` | `claude-opus-5` official-confirmed | 14:54 |
| `https://code.claude.com/docs/en/model-config` | Claude Code effort／ultracode／版本門檻 | 14:56 |
| `https://learn.chatgpt.com/docs/build-skills`（`https://developers.openai.com/codex/skills` 308 轉址至此） | Codex skill roots + `allow_implicit_invocation` 語義 | 14:55 |
| `https://developers.openai.com/plugins/build/plugins` | `.codex-plugin/plugin.json` 必要性 | 14:56 |
| `https://developers.openai.com/api/docs/guides/model-guidance?model=gpt-5.6#prompting-best-practices` | GPT-5.6 prompting guidance | 文件 11 記錄 14:14；**本輪未重讀，引用時標為文件 11 的二手記錄** |
| Copilot skill invocation contract | Copilot 分層 | **UNAVAILABLE — 本輪未取得任何官方來源** |
