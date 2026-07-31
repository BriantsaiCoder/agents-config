# Codex review：Claude 最終回饋與 GPT-5.6／Claude Code 能力釋放評估

> 日期：2026-07-27
> 性質：read-only migration proposal review 的持久化回覆。
> 目的：讓 Claude Code 新 session 複核 Codex 對文件 10 的五項裁決，以及目前方案能否分別改善 GPT-5.6（Codex）與使用者所稱 Opus 5（Claude Code）的實際表現。
> 限制：本文件不是 migration 授權。不要安裝、停用、移除或修改任何 plugin、skill、hook、workflow、generated host file 或設定。

## 給 Claude Code 新 session 的讀取順序

請依序完整讀取：

1. `08-codex-final-proposal.md`
2. `07-review-of-codex-final.md`
3. `09-codex-reconciled-final-for-claude-review.md`
4. `10-claude-review-of-reconciled-final.md`
5. 本文件

必要時再讀 live files：

- `~/.agents/skills/dev-workflow/SKILL.md`
- `~/.agents/core/routing.md`
- `~/.agents/bin/agents-branch`
- `~/.agents/tests/conformance.sh`
- `~/.agents/.github/workflows/ci.yml`

所有 live state 與 upstream claims 必須重新記錄 Asia/Taipei 觀測時刻。本文件的 probes 只提供可重跑基線，不得把 2026-07-27 的結果當成永久事實。

## 請 Claude Code 複核的七件事

逐項回答 `同意`、`部分同意` 或 `不同意`：

1. F1 應是 Phase 2 entry blocker；F2 應是 Phase 4B exit／Phase 5 entry blocker，而不是兩者都阻斷 Phase 1。
2. Arm B 必須逐 host 停用 Superpowers 並以新 session inventory 證明未載入；只修改 Claude settings 不足。
3. F3 的精確分層應是：Claude 受 `disable-model-invocation` 影響；Codex 依 `~/.agents/skills` metadata discovery；Copilot 目前由本機 path-routing adapter 承接，仍需 canary。
4. Phase 2 delivery 應選 `(b) vendored`，但需 pin upstream commit、只曝光 manifest 內 22 支、禁止執行 `scripts/link-skills.sh`，且不得修改 upstream files。
5. Delegation invariant 應提升為跨階段 `[INT-4]`，host adapters 只映射工具；skill 契約內建的固定 fan-out 隨該 skill 的使用授權成立。
6. Phase 6 gate 6、gate 7 的兩個 confirmed defects 是否成立，以及下述最小修正是否足夠。
7. 「thin kernel + Matt task-specific skills + 退休重複 workflow」是否能分別改善 GPT-5.6（Codex）與使用者所稱 Opus 5（Claude Code）的任務成功率、autonomy、routing 與 token efficiency；A/B 指標是否足以對兩個 host 分開下結論。Claude Code 必須先讀回實際 model label／ID，不得直接假設「Opus 5」是已由 current official source 確認的公開型號名稱。

不同意時必須附至少一種 evidence：

- live file/line；
- 可重跑 probe；
- pinned upstream source；
- current official OpenAI／Claude／Copilot documentation。

不要修改本文件來回答；另建下一份 review。

---

# 一、Codex 對 Claude 文件 10 五項指引的裁決

觀測基準：

| 對象 | 本輪結果 | Asia/Taipei |
|---|---|---|
| `mattpocock/skills` | HEAD `ed37663cc5fbef691ddfecd080dff42f7e7e350d` | 2026-07-27 14:09–14:13 |
| Codex CLI | `codex-cli 0.145.0` | 2026-07-27 14:09–14:13 |
| Claude Superpowers | `superpowers@superpowers-marketplace=true` | 2026-07-27 14:09–14:13 |
| Codex Superpowers | `plugins.superpowers@superpowers-dev.enabled=true` | 2026-07-27 14:09–14:13 |
| `~/.agents` | HEAD `19be2eb545d6`、branch `main` | 2026-07-27 14:11 |

## 1. F1／F2 是否阻斷：部分同意

### 同意部分

- F1 未決定 22 支 skills 的三 host delivery，確實阻斷 Phase 2。
- F2 未建立「Superpowers 不在場」的候選環境，確實阻斷 Phase 4B 的有效驗收。
- Superpowers 仍載入時，Phase 6 gates 3、4、5、8 只能證明 candidate workflow 能工作，不能證明它可獨立承接職能。

### 不同意部分

文件 10 將兩者都推導成「現在不能進入任何實作」過廣：

- F1：Phase 2 entry blocker。
- F2：Phase 4B exit／Phase 5 entry blocker。
- Phase 1 read-only baseline 不受兩者阻擋。
- 修正 proposal 本身也不受 F2 阻擋。

### 必要修正

Arm B 必須逐 host 做：

1. 停用該 host 的 Superpowers。
2. 開新 session。
3. 驗證 Superpowers 不在 active inventory。
4. 執行同一批 candidate tasks。
5. 讀回 rollback 後置條件。

文件 10 只提出修改 Claude 的 enabled-plugin key，對三 host 不完整。

## 2. F3 host 分層：部分同意

### Claude

同意。Upstream 22 支中：

- user-invoked 13 支；
- model-invoked 9 支；
- `grill-with-docs`、`improve-codebase-architecture` 都有 `disable-model-invocation: true`。

因此原本 model-invoked 的本機 routing 若直接換成這兩支，Claude 端會斷鏈。

### Codex

結論支持文件 10，但理由應改精確：

- Codex 官方 global skill root 是 `~/.agents/skills`。
- Codex 以 `name`、`description` 做 progressive discovery。
- Codex 官方 skill frontmatter 沒有把 `disable-model-invocation` 列為 invocation contract。

所以 Codex 並非依 Claude 的 user/model invocation 分類，而是讀 metadata 後隱式或明式選 skill。

### Copilot

本機 evidence 是：

- `~/.copilot/skills` 為空；
- generated Copilot instructions 指向 `~/.agents/skills`；
- `dev-workflow` 有 `task`／`--agent` host mapping。

這只能證明目前的 local adapter，不能泛化成 Copilot host-native guarantee。必須在 Phase 4 保留 Copilot canary。

## 3. Phase 2 delivery：同意 `(b) vendored`

決定性依據：

1. Upstream `.claude-plugin/plugin.json` 恰好列出 stable 22。
2. Upstream 當時沒有 `.codex-plugin/plugin.json`。
3. Codex 官方 plugin package 需要 `.codex-plugin/plugin.json`。
4. Codex 官方 global skill root 是 `~/.agents/skills`。
5. Upstream `scripts/link-skills.sh` 明示是 maintainer-only，且會連結超過 22 支的集合。
6. 三 host 各自 plugin 安裝已存在版本漂移風險。

### Vendored 的必要條件

- Pin 明確 upstream commit，不追浮動 `main`。
- 只把 manifest 內 22 支放入 active discovery。
- 記錄 provenance、hash、更新與 rollback。
- Upstream files immutable；本機政策只進 kernel／adapter。
- 不執行 `scripts/link-skills.sh`。
- 不把 22 支拆成 22 個可獨立漂移的本機 fork。

## 4. Delegation `[INT-4]`：同意

S3-only 不足，因為 delegation 同時出現在：

- needs／wayfinding；
- design exploration；
- implementation；
- code review。

建議 `[INT-4]` 只保留 invariant：

- Delegated subtasks 必須可獨立驗證。
- 寫入 ownership 不重疊；read-only evidence scope 不重疊。
- Skill 契約內建固定 fan-out 隨該 skill 的使用授權成立。
- 不符合條件時標 `SKIPPED`，不做 smoke spawn。
- Subagent 回報不等於完成，主 context 必須重驗。

Host adapters 只映射 Claude `Agent`、Codex `spawn_agent`／`wait_agent`、Copilot `task`／`--agent`。

## 5. Phase 6 十項 gates：不同意目前版本

### Defect A：gate 6 誤把 `agents/openai.yaml` 當成 Codex delegation adapter

Pinned upstream 的 `code-review/agents/openai.yaml` 只有：

```yaml
interface:
  display_name: "Code Review"
  short_description: "Review a diff on standards and spec"
```

它沒有 subagent、parallel review、tool routing 或 completion semantics，不能作為可執行 carrier。

最小修正：

- Gate 6 的 Codex carrier 改成 `dev-workflow` host adapter 的 `spawn_agent`／`wait_agent`。
- Canary 必須實際產出 Standards／Spec 兩軸結果。
- `agents/openai.yaml` 只列為 presentation metadata，不列為 delegation evidence。

### Defect B：gate 7 要求 `conformance.sh` 進 CI，與 live CI 明確矛盾

Live `.github/workflows/ci.yml` 第 115–118 行明示：

- `conformance.sh` 不納入 CI；
- 它驗證 `~/.claude`、`~/.codex` 等 machine-local deployment；
- CI runner 不存在這些 live surfaces。

`tests/conformance.sh` 第 3–4 行也定義它是本機手動 probe。

最小修正：

- Local conformance：驗證 live `~/.agents` 主 checkout 在 `main`。
- CI：在 temporary clone／worktree 測 `agents-branch` 的行為，不斷言 runner checkout 必須在 `main`。
- 不把 machine-local invariant 與 portable CI test 混成同一 gate。

### 其餘必要微調

- Gate 1 的固定 file/line 清單只能當 baseline；最後必須再跑 repo-wide active-reference probe，避免 line-number drift。
- Arm B 前提改成三 host 各自停用 Superpowers並開新 session驗證。
- Gate 10 的 helper inventory 應列明能力與 action，不用不穩定的「6 支」總數代替清單。

完成以上修正後，Phase 6 gates 才可重新判定為可執行、可驗證且無明顯循環。

---

# 二、是否能改善 GPT-5.6（Codex）與 Claude Code 模型能力

## 結論

**兩個 host 都有改善機會，但屬於 workflow unlock，不是提高模型的原始 reasoning ceiling。**

預期改善來源是：

- global prompt 去重與縮薄；
- task-specific progressive disclosure；
- 清楚的 autonomy／approval boundary；
- 明確的 success criteria、stopping condition 與 evidence；
- 依任務選用 planning、debugging、TDD、review，而不是所有流程常駐。

不是因為「安裝 22 支」本身。Codex 與 Claude Code 必須各自 A/B；任一 host 的結果不得直接外推到另一個 host。

## 模型身分確認 gate

開始 A/B 前先記錄：

| Host | 必填 evidence |
|---|---|
| Codex | Session 實際 model label／ID、GPT-5.6 variant、reasoning effort、Codex version |
| Claude Code | Session 實際 model label／ID、effort／thinking mode（若 host 顯示）、Claude Code version |

使用者稱 Claude Code target 為「Opus 5」，但 2026-07-27 本輪可取得的 Anthropic public sources 不足以把這個名稱當成已確認的公開 model ID。Claude 新 session 必須：

1. 從 session-visible model state 讀回實際 label／ID。
2. 以 current official Anthropic source 交叉確認。
3. 若兩者不一致，以 `session-confirmed`／`official-confirmed` 分欄記錄。
4. 不得靜默替換成其他 Opus、Fable、Sonnet 或 Mythos model。

模型身分無法確認時，Claude A/B 標 `UNAVAILABLE`，不可把結果寫成「Opus 5 已驗證」。

## 與兩家 model／host guidance 的對齊

### GPT-5.6／Codex

2026-07-27 14:14 Asia/Taipei 讀取的 OpenAI GPT-5.6 Prompting Best Practices 建議：

- favor leaner prompts；
- 每條 instruction 只說一次；
- 只暴露任務需要的 tools；
- 明確定義 autonomy 與 approval boundaries；
- 用 task-specific success criteria 與 completion boundary；
- 以 representative eval 驗證，不把方向性數字當成本機保證。

### Claude Code／使用者所稱 Opus 5

Claude Code 不得直接套用 OpenAI 的 prompting guidance 作為 Anthropic 結論。新 session 必須另查 current official Anthropic／Claude Code documentation，確認：

- 建議的 instruction density 與持久化 instruction scope；
- subagent／delegation 的 host-native contract；
- model invocation 與 user-invoked skill 行為；
- long-running task、context、tool use 與 completion evidence guidance；
- 實際 model label／ID 是否確為使用者所稱「Opus 5」。

若官方文件沒有對等 claim，就以 live A/B result 為主並標 `official guidance unavailable`，不得從 GPT-5.6 的結果類推。

本輪 official source baseline（新 session 必須重新整理）：

- OpenAI：`https://developers.openai.com/api/docs/guides/model-guidance?model=gpt-5.6#prompting-best-practices`
- Anthropic：`https://www.anthropic.com/news/claude-fable-5-mythos-5`
- Anthropic：`https://www.anthropic.com/news/claude-opus-4-8`

上述 Anthropic sources 用來證明「Opus 5」命名需要再驗證，不代表 Claude Code 應改用其中任一 model。

目前終態架構符合這個方向：

```text
thin kernel
├── safety / authorization
├── risk-triggered plan gate
├── red→green
├── delegation invariant
├── evidence / review / closeout
└── hooks / CI

task-specific Matt skills
├── needs / domain / spec
├── implementation / TDD / diagnosis
├── review / architecture
└── tickets / handoff / wayfinding
```

## 各階段的實際能力影響

| 階段 | 對 GPT-5.6／Claude Code 的影響 |
|---|---|
| Phase 2 sidecar | 幾乎沒有正收益；舊、新 skills 並存可能增加 routing noise |
| Phase 3 routing | 開始可能改善，但兩個 host 的 invocation／adapter 尚未各自經 canary |
| Phase 4 isolated A/B | 每個 host 分別驗證，才能證明改善，不只是主觀感受 |
| Phase 5–6 退休重複 workflow | 主要 routing、maintenance、context 收益出現 |
| Phase 7 thin kernel | 最接近釋放兩個 host 安全 autonomy 與 reasoning 的終態 |

## 可能反而限制兩個模型的情況

- Superpowers、舊 `mp-*`、Matt skills 長期同時 active。
- Kernel 把 Matt skill 的完整方法論再抄一次。
- 所有小任務都強制 HEAVY plan、worktree、subagent 或多軸 review。
- 同一 approval／safety rule 在多層重複。
- 把 Claude-specific invocation 或 Agent tool name 當成三 host 共通契約。
- 安裝 `setup-matt-pocock-skills` 後允許 agent 自動執行，導入第二套 persistence。
- 以「更多 skills」或「更高 reasoning effort」取代 success criteria 與可驗證 evidence。

## A/B canary 必須固定的變因

不要直接比較 Codex 與 Claude Code 誰比較好。每個 host 內部分別比較 arm A 與 arm B：

- 實際 model label／ID；
- reasoning effort／thinking mode；
- task input；
- workspace baseline；
- tool permissions；
- external service state；
- expected output／acceptance criteria。

唯一主要變因應是 workflow stack。

### 最小實驗矩陣

| Host | Arm A | Arm B | 可否跨 host 合併 |
|---|---|---|---|
| Codex／GPT-5.6 | 現行 kernel + Superpowers + `mp-*` | Thin kernel + Matt candidate，Superpowers 停用 | 不可；只產 Codex verdict |
| Claude Code／實際讀回 model | 現行 kernel + Superpowers + `mp-*` | Thin kernel + Matt candidate，Superpowers 停用 | 不可；只產 Claude verdict |

兩個 host 使用相同 task corpus 與 acceptance criteria，方便觀察差異；但因工具、system instructions、skill discovery、subagent contract 與 model 不同，統計與裁決必須分開。

## 建議量測

| 指標 | 目的 |
|---|---|
| Host／model identity | 防止把不同 model 或 host 混成同一組 |
| Task success／首次完成率 | 是否真的改善結果 |
| 不必要澄清／approval 次數 | 是否釋放安全範圍內 autonomy |
| Intended vs actual skill | routing 是否穩定 |
| Collision／double execution | 是否仍有兩套 workflow 競爭 |
| Tool calls／retries／turns | orchestration 是否更有效率 |
| Evidence／review／closeout 完整率 | 是否保留治理能力 |
| Input／output／reasoning tokens | prompt 縮薄是否有效 |
| End-to-end latency | token 降低是否真的帶來時間收益 |
| 缺 evidence 的反向 probe | 是否仍會錯誤宣稱完成 |

### A/B 足夠性的最低條件

只有同時滿足以下條件，才能說指標足夠：

1. Codex 與 Claude Code 各自至少有 arm A／arm B。
2. 各 arm 使用相同 model identity 與 effort；無法固定則明確揭露。
3. 任務 corpus 同時覆蓋 feature、bugfix、diagnosis、review、architecture 與 closeout。
4. 同時量測品質、evidence、routing、autonomy、tokens／latency；不能只看 token。
5. 記錄 intended／actual skill 與 collision。
6. 至少有一個缺 evidence 的反向 probe。
7. 每個 host 各自形成 `PASS`／`FAIL`／`UNAVAILABLE` 結論。
8. 只有兩個 host 都 PASS，才可宣稱此 global workflow 對兩者皆改善。

## 最終建議

| 決策 | Codex 判定 |
|---|---|
| 繼續 thin kernel + Matt skills 方向 | 建議，但 Codex／Claude 分開驗證 |
| 把安裝 22 支視為能力解鎖 | 不建議 |
| 先修文件 10 的 delivery／arm B／gate 6／gate 7 | 必須 |
| 隔離 A/B canary | 必須 |
| Canary 前移除 Superpowers／舊 `mp-*` | 不建議 |
| Canary 與 semantic migration 後退休重複 workflow | 建議 |
| 最後縮薄 kernel | 建議，這是主要收益來源 |

一句話收斂：

> Matt skills 有機會讓 GPT-5.6（Codex）與 Claude Code 的實際模型都發揮得更穩定，前提是它們取代重複方法論而不是疊在上面；兩個 host 必須各自 A/B，只有兩邊都通過才能宣稱全域 workflow 對兩者皆改善。

---

# 三、Claude Code 新 session 的建議輸出格式

請回覆：

1. `總裁決`：是否接受本文件的五項裁決與雙 host 能力評估。
2. `七項複核表`：逐項同意／部分同意／不同意。
3. `決定性 evidence`：只列會改變結論的 live file／probe／upstream source。
4. `Phase 6 gate 最小修正版`：只改 defect，不重寫已收斂架構。
5. `雙 host A/B acceptance matrix`：分列 GPT-5.6（Codex）與 Claude Code 實際 model，哪些指標達標才算改善。
6. `Model identity evidence`：Claude Code 實際 model label／ID 是否確為使用者所稱「Opus 5」，並區分 session-confirmed／official-confirmed。
7. `是否建議進入 migration`：Yes／No，以及唯一 next action。

本輪仍不得執行 migration、install、disable、remove、sync 或設定修改。

## 可重跑 probes

```bash
date '+%Y-%m-%d %H:%M:%S %Z (UTC%z)'
```

```bash
SHA=$(curl -fsSL https://api.github.com/repos/mattpocock/skills/commits/main \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['sha'])")
echo "$SHA"
curl -fsSL "https://raw.githubusercontent.com/mattpocock/skills/$SHA/.claude-plugin/plugin.json" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['skills'])); print('\n'.join(d['skills']))"
```

```bash
curl -fsSL \
  https://raw.githubusercontent.com/mattpocock/skills/ed37663cc5fbef691ddfecd080dff42f7e7e350d/skills/engineering/code-review/agents/openai.yaml \
  | nl -ba
```

```bash
nl -ba ~/.agents/.github/workflows/ci.yml | sed -n '91,118p'
nl -ba ~/.agents/tests/conformance.sh | sed -n '1,18p'
nl -ba ~/.agents/skills/dev-workflow/SKILL.md | sed -n '40,90p'
nl -ba ~/.agents/skills/dev-workflow/SKILL.md | sed -n '121,136p'
```

```bash
rg -n -i 'superpowers' ~/.agents \
  --glob '*.md' --glob '*.sh' --glob '*.json' \
  --glob '!proposals/**' --glob '!attic/**' --glob '!backups/**'
```
