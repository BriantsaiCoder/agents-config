# 00 — 機械掃描結果（step 1–2 + 依賴圖 + 使用數據）

> 2026-07-25 · 稽核對象 `~/.agents/skills/` 52 個個人 skill
> 本檔只放**可重跑驗證的機械事實**，判斷與建議在 `01-verdicts.md` / `02-recommendations.md`。

## 掃描範圍與前提

- 單一真實來源 = `~/.agents/skills/`（52 個）。`~/.claude/skills/` 下 52 項**全部是 symlink**指回前者，無獨立內容。
- 消費端三家：Claude Code、Codex CLI（`~/.codex/AGENTS.md`）、GitHub Copilot CLI（`~/.copilot/copilot-instructions.md`）。
- 另有 23 個 plugin 提供的 skill（superpowers / ponytail / hookify / code-review / …），**不在移除範圍**（移除等於卸載 plugin），但納入「功能重疊」判斷。

## Step 1 — Token 成本（`count-words.sh`）

超過 500 字上限者 8 個：

| 字數 | Skill |
|---|---|
| 5637 | ecpay |
| 3285 | agent-browser |
| 2399 | design-doc-mermaid |
| 1421 | init-project-docs |
| 1324 | security-audit |
| 1214 | dev-workflow |
| 900 | native-feel-cross-platform-desktop |
| 510 | mp-grill-with-docs |

其餘 44 個皆 ≤500 字（多數落在 320–500 區間）。

### 成本歸屬更正（重要）

skill 的**常駐成本只有 description 一行**；body 是 invoke 當下才載入。
- 52 個 description 合計 **21,748 字元**（含 name 行）→ 粗估 **6–8k token** 的 always-on 開銷。
- 單刪 `ecpay`（body 5637 字）省的是約 100 token，**不是 5637 字**。

→ **word count 是 Trim 訊號，不是 Delete 訊號。** 移除的真正收益是路由精準度，不是 token。

## Step 2 — Description trap（`lint-descriptions.sh`）

標記為 `?`（description 在描述 workflow 而非觸發條件，需讀本文確認）者 8 個：
`agent-browser`、`bug-fix-settlement`、`deps-check`、`design-doc-mermaid`、`dev-workflow`、`ecpay`、`sdd`、`security-audit`。

其中 `dev-workflow` 的 description 自己載明「routing 由三家注入層逐名點名觸發，不靠本 description」——屬**刻意設計**，非缺陷。

無 `MISS`（沒有缺 description 欄位的 skill）。

## A. 硬引用圖（skill 名被寫死在設定檔）

### A1. 四檔逐名點名（`.claude/CLAUDE.md` + `.agents/core/routing.md` + `.codex/AGENTS.md` + `.copilot/copilot-instructions.md`）

20 個：`dev-workflow`、`sdd`、`deps-check`、`mp-grill-with-docs`、`mp-diagnose`、`bug-fix-settlement`、`frontend-release-verification`、`backend-release-verification`、`dependency-security-scan`、`design-doc-mermaid`、`acquire-codebase-knowledge`、`agent-browser`、`auth-implementation-patterns`、`containerization`、`init-project-docs`、`security-audit`、`security-review`、`tailwind-v4-shadcn`、`vite`、`vitest`

→ 移除任一項需**四檔協調編輯**，且 `agents-sync` 的 lint1 會 FAIL（「routing 逐名點名 'X' 不存在於 skills/」）。

### A2. 僅 `.claude/CLAUDE.md` 點名（Claude 專屬層）

`mp-improve-codebase-architecture`、`mp-tdd`、`mp-zoom-out`

### A3. `.agents/rules/*.md` 點名

- `frontend-spa.md` → `nuxt`
- `testing.md` → `vite`、`vitest`
- `cookbook.md` → `deps-check`、`bug-fix-settlement`

### A4. 其他硬引用

| 引用者 | 被引用 skill |
|---|---|
| `.claude/settings.json` | `agent-browser`、`vite`、`vitest` |
| `.claude/commands/sdd.md` | `sdd` |
| `.claude/agents/security-auditor.md` | `security-audit` |
| `.agents/tests/conformance.sh` | `init-project-docs`（`references/hooks/protect-files.sh`） |
| `.agents/bin/agents-sync` | `dev-workflow`（可見度探針） |

### A5. Wildcard 引用（`*-best-practices` 全部 0 個硬引用，但受 pattern 保護）

- `core/routing.md:8`：「stack 實作 → 同名 `*-best-practices`」
- `dev-workflow/SKILL.md:80`（S3 IMPLEMENT）：「stack **`*-best-practices` skill MUST 套**」

→ `*-best-practices` 的 0 硬引用**不等於無引用**。刪除任一個 = 該 stack 的 canonical workflow S3 出現無法滿足的 MUST 條款。

## B. Skill 之間的內文互引（刪除造成 skill 內死連結）

`dev-workflow/SKILL.md` 引用：`acquire-codebase-knowledge`、`backend-release-verification`、`bug-fix-settlement`、`dependency-security-scan`、`deps-check`、`frontend-release-verification`、`mp-diagnose`、`mp-grill-with-docs`、`mp-improve-codebase-architecture`、`sdd`

高被引 skill（被引用檔案數）：

| Skill | 被引用檔數 | Skill | 被引用檔數 |
|---|---|---|---|
| vite | 50+ | dotnet-logging-best-practices | 5 |
| nuxt | 14 | security-audit | 5 |
| vitest | 13 | containerization | 4 |
| pinia | 9 | dapper-best-practices | 4 |
| react-best-practices | 6 | dotnet-core-best-practices | 4 |
| testing-library-react-best-practices | 6 | dotnet-framework-best-practices | 4 |
| | | jest-best-practices | 4 |

## C. 生成物連動（刪除的必要步驟）

`~/.agents/dist/skill-index.md` 是**機械生成的 52 名清單**，`agents-sync` 帶自檢：

```
[ "$idx_n" = "$skills_n" ] || die "skill-index 自檢失敗：index ${idx_n} 行 ≠ skills ${skills_n} 個"
```

另有 lint1 / lint1b：routing 點名或 core/hosts 反引號引用的 kebab token 若不存在於 `skills/` 即 FAIL（豁免清單 `NONSKILL` 內的名字除外）。

### 移除任一 skill 的完整流程（少一步就 lint 紅燈）

1. `git mv skills/X attic/`（**不是 `rm`**；`attic/codex-legacy-skills` 已有先例）
2. 從 `core/routing.md` / `.claude/CLAUDE.md` 移除點名（如有）
3. 從其他 skill 的 SKILL.md / references 移除交叉引用（如有）
4. 跑 `~/.agents/bin/agents-sync` 重生 `dist/{AGENTS.md,copilot-instructions.md,skill-index.md,manifest.tsv}`
5. 跑 `~/.agents/tests/conformance.sh` 確認四態綠
6. 重啟三家 host 確認 skill listing 不含死名

> ⚠️ 前置：`~/.agents` 目前有 **10 個未 commit 修改**（`core/routing.md`、`core/tier1-workflow.md`、`core/tier2-style.md`、`dist/*`、`hosts/*-delta.md`、`rules/testing.md`、`skills/mp-zoom-out/SKILL.md`）+ 2 個 `.bak-20260718-1346` 檔 + 未追蹤的 `proposals/2026-07-17-*`。動 skill 前應先 commit 或 stash，否則 rollback 會混在一起。

## D. 真實使用數據（Skill tool 實際調用）

來源：`~/.claude/projects/` 下 **6,505 個 session transcript**，2026-04-26 ~ 2026-07-25。

### D1. 有被調用的個人 skill（27 個）

| 次數 | Skill | 次數 | Skill |
|---|---|---|---|
| 48 | dapper-best-practices | 3 | agent-browser |
| 36 | dependency-security-scan | 3 | acquire-codebase-knowledge |
| 32 | backend-release-verification | 2 | mp-grill-with-docs |
| 26 | dotnet-core-best-practices | 2 | frontend-release-verification |
| 14 | mysql-best-practices | 2 | c-cpp-best-practices |
| 13 | bug-fix-settlement | 1 | typescript-best-practices |
| 11 | deps-check | 1 | security-review |
| 10 | auditing-skill-folder | 1 | react-best-practices |
| 7 | dotnet-logging-best-practices | 1 | postgresql-best-practices |
| 6 | dotnet-testing-best-practices | 1 | playwright-best-practices |
| 5 | init-project-docs | 1 | ef-core-best-practices |
| 3 | mp-zoom-out | 1 | dotnet-framework-best-practices |
| 3 | ecpay | 1 | dev-workflow |
| | | 1 | auth-implementation-patterns |

### D2. 調用次數 0 的個人 skill（25 個）

`containerization`、`css-ui-best-practices`、`design-doc-mermaid`、`dotnet-winforms-best-practices`、`ef6-best-practices`、`jest-best-practices`、`mp-diagnose`、`mp-improve-codebase-architecture`、`mp-tdd`、`native-feel-cross-platform-desktop`、`next-best-practices`、`nodejs-best-practices`、`nuxt`、`pinia`、`postgresql-optimization`、`react-router-framework-mode`、`sdd`、`security-audit`、`tailwind-v4-shadcn`、`testing-library-react-best-practices`、`vite`、`vitest`、`vue-best-practices`、`vue-debug-guides`、`vueuse-functions`

### D3. 數據的兩個已知偏差（勿誤讀）

1. **routing 規定「先讀 SKILL.md」的 skill 走 Read 不走 Skill tool** — `dev-workflow` 只有 1 次 Skill 調用，但被 336 個 session 的 transcript 提及路徑。0 調用 ≠ 沒被用。
2. **「transcript 提到路徑」的次數被稽核 session 汙染** — 歷次設定稽核會 `ls`/`grep` 全部 skill，導致每個 skill 都有 40–140 個 session 命中。此欄不可作為使用證據。

→ 可信訊號是 **D1/D2 的 Skill tool 調用數**；判斷刪除時要與「該 stack 這三個月是否真的動過」一起看（主力專案是 .NET 8 + MySQL + Dapper，前端 stack 這段期間近乎沒動 → 前端 skill 0 調用**同時反映低使用與低曝光**，不能單獨當作內容無價值的證據）。

## E. Codex 端路由缺陷（既有問題，非本次刪除理由）

`core/routing.md:7` 載明：「Codex 端 description 被截斷至 2–6 字元，路由靠點名不靠 description」。

→ `*-best-practices` 的 wildcard 路由（A5）在 Codex 上**沒有觸發管道**：description 不可讀，名字也不在逐名點名清單裡。
→ 這是**現有結構缺陷**，應以「補點名」或「Codex 專屬索引」修，不可用「Codex 上反正沒用」當刪除理由。

## F. Description 觸發詞碰撞（移除的真正收益面）

52 個 description 兩兩比對，Jaccard ≥ 0.10 者僅 **15 對**：

| 重疊度 | 配對 |
|---|---|
| 0.286 | ef-core-best-practices ↔ ef6-best-practices |
| 0.250 | postgresql-best-practices ↔ postgresql-optimization |
| 0.182 | jest-best-practices ↔ vitest |
| 0.150 | backend-release-verification ↔ frontend-release-verification |
| 0.149 | dapper-best-practices ↔ ef6-best-practices |
| 0.145 | mysql-best-practices ↔ postgresql-best-practices |
| 0.143 | vue-best-practices ↔ vue-debug-guides |
| 0.127 | pinia ↔ vue-best-practices |
| 0.125 | pinia ↔ testing-library-react-best-practices |
| 0.111 | vue-best-practices ↔ vueuse-functions |
| 0.111 | ef-core-best-practices ↔ mysql-best-practices |
| 0.111 | dapper-best-practices ↔ ef-core-best-practices |
| 0.105 | react-best-practices ↔ testing-library-react-best-practices |
| 0.104 | dotnet-core-best-practices ↔ dotnet-framework-best-practices |
| 0.102 | ef6-best-practices ↔ mysql-best-practices |

**結論：description 分化良好，路由互搶不嚴重。** 高重疊配對皆為刻意相鄰的姊妹 skill（且多數 description 內已互相標示分工，如 postgresql-best-practices 明寫「深度效能調校用 postgresql-optimization」）。

→ 這條證據**削弱**「為了觸發精準度而大量刪除」的論點。收益主要落在少數幾對，而非全庫。

## 重跑指令

```bash
# step1 / step2
bash ~/.claude/skills/auditing-skill-folder/scripts/count-words.sh ~/.agents/skills
bash ~/.claude/skills/auditing-skill-folder/scripts/lint-descriptions.sh ~/.agents/skills

# A. 硬引用（stdout only；勿經 $TMPDIR 中轉，沙箱會靜默丟資料）
for s in $(ls -1 ~/.agents/skills); do
  h=$(grep -rIl --exclude-dir=.git -e "$s" ~/.claude/CLAUDE.md ~/.agents/core ~/.agents/rules \
      ~/.agents/hosts ~/.claude/agents ~/.claude/commands ~/.claude/settings.json \
      ~/.codex ~/.copilot 2>/dev/null | grep -v '\.bak-' | tr '\n' ',')
  echo "$s | $h"
done

# D. 調用統計
grep -rhoE '"skill"[[:space:]]*:[[:space:]]*"[^"]+"' ~/.claude/projects/ \
  | sed 's/.*"\([^"]*\)"$/\1/' | sort | uniq -c | sort -rn
```
