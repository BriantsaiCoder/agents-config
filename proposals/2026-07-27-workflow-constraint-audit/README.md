# 全域 workflow 約束稽核 — 對 Opus 5 是否過度限制

<!-- date: 2026-07-27 | executor: Claude Opus 5 | scope: ~/.claude/CLAUDE.md + core/tier0-2 + ~/.agents/skills/dev-workflow -->

## 結論（一句話）

**不是「限制太多」，是「同一條規則寫太多次」＋「儀式密度不隨任務規模縮放」。** 總量對 Opus 5 的 context 不構成瓶頸（常駐 ~2%），但重複與固定儀式產生真實摩擦。所有值得砍的項目都是 host-neutral（三主機同利），**不需要為 Opus 5 開特例** — 這點很重要，因為開特例會直接違反既定目標「三主機跑同一條 workflow」。

---

## 一、量測基線

| 項目 | 實測 | 佔 1M context |
|------|------|--------------|
| `~/.claude/CLAUDE.md` | 8,872 字元 | |
| `core/tier0+tier1+tier2` | 6,137 字元 | |
| 常駐規則小計 | **15,009 字元 ≈ 4.3K tokens** | 0.4% |
| skill description listing（本 session 可見約 180 支） | ~90K 字元 ≈ **26K tokens**（估） | 2.6% |
| `dev-workflow/SKILL.md`（按需 Read） | 14,120 字元 ≈ 4K tokens | 0.4% |
| `references/` 三檔（按需） | 16,113 字元 | |

→ **token 稅不是問題**。常駐總計約 30K tokens / 1M window。以「限制能力」為由砍規則，論據不成立。

## 二、workflow 實際執行率（非紙上談兵）

`~/.claude.json` → `skillUsage`（Skill 工具觸發計數，權威來源）：

| skill | 次數 | 判讀 |
|-------|------|------|
| `dependency-security-scan` | 36 | 高 |
| `backend-release-verification` | 32 | 高 |
| `superpowers:finishing-a-development-branch` | 32 | 高 |
| `superpowers:systematic-debugging` | 25 | 高 |
| `superpowers:writing-plans` / `brainstorming` / `TDD` | 21 / 20 / 19 | 高 |
| `bug-fix-settlement` | 12 | 中 |
| `deps-check` | 11 | 中 |
| `dev-workflow` | **1** | ← 量測假象，見下 |
| `sdd` | **0** | 真·從未觸發 |
| `superpowers:requesting-code-review` | **0** | S5 Claude enhancement 從未跑 |
| `superpowers:verification-before-completion` | **0** | 從未跑 |
| `mp-tdd` / `mp-diagnose` | 0 / 0 | escalation 未觸發（設計如此） |

**`dev-workflow`=1 與 `sdd`=0 都是量測假象**：CLAUDE.md 寫的是「先**讀** SKILL.md」不是 invoke，走 Read 路徑不計入 skillUsage。反證：

- `dev-workflow` — 近 30 天 transcript 出現 3,146 次，載入指紋 `FP:DEVWF` 出現 **175 次**（指紋正是為驗證 context 載入而設）。
- `sdd` — `SKILL.md:55` 把 LIGHT 定義為「session plan；核准後可按需持久化到 `sdd/<slug>/`」，是**路由層級指派**不是 skill invocation，任務可以路由 LIGHT 而永不 invoke `sdd`。實體反證：本專案 `.superpowers/sdd/`（gitignored）內有 `task-1` ～ `task-7` 的 brief/report 共 14 檔 + 12 份 review diff。

→ **LIGHT tier 有在跑，而且跑得很重。** 附帶發現：該目錄有 7 個 task，遠超 S0 第 4 列的「actionable tasks ≤3」上限 — LIGHT 的入口門檻實際沒被守住，或 HEAVY 的產物落進了 LIGHT 的路徑。這使錯配 2 更嚴重而非更輕。

## 三、四處真實錯配（皆 host-neutral，砍了三家同利）

### 錯配 1 — 同一約束寫 6–10 處（最大體積、零語意損失）

| 約束 | 出現位置 | 處數 |
|------|---------|------|
| plan-first | `[T0-8]` + `[INT-3]` + S0 表第 1 列 + S2 ACTION/EXIT/FAILURE + BUGFIX S2 + Copilot S2 強制令 | **9** |
| 紅測先行 | `[R-2]`(CLAUDE.md:82) + `[INT-2]` + S3/S5 FAILURE + BUGFIX S1/S3 + Preflight row 5 + review-triage:44 + reviewer-template:69 | **10** |
| rollback | `[T0-6]` + `[T1-2]` + Preflight row 8 + Closeout Residual risks | **8** |
| deps-check | `[T1-1]` + CLAUDE.md 協作守則 + S3 ACTION + S6 triage + review-triage:35,41 | **6** |

CLAUDE.md 開頭已定「正本 + ID 引用」的原則，但只在少數地方落實。**修法**：每條約束保留 1 個正本定義，其餘全部改為 `[T0-8]` 這樣的 ID 引用（一行），不重述內容。

### 錯配 2 — LIGHT/HEAVY 分層在 S2 之後蒸發（最強項目）

從 `SKILL.md:77-111` 逐字可證，不需 usage 數據：LIGHT tier 只減 S1（3 問）與 S2（≤3 tasks），**S3–S6 的 ACTION / EXIT / FAILURE 與 HEAVY 逐字相同**。一個單檔 bug fix 與一次 schema migration 付一樣的 16 欄位收尾（Preflight 8 + Closeout 6 + Postflight 2）。

「有一條輕量路徑、跑了、但 S2 之後省不到任何東西」比「沒人用輕量路徑」是更尖銳的缺陷 — 它讓分層的成本（多一組判定規則、多一套路徑）全付了，收益只兌現到 S2。這是「儀式與規模不成比例」的結構性根源。

**修法**：給 LIGHT 專屬收尾規格 — Closeout 6 欄壓成 3 欄（verification / diff self-review / residual risks），Preflight 只在開 PR 時要求且降為 4 欄（scope / tests / review / risks）。

### 錯配 3 — Preflight 與 Closeout 從未合併，4/16 欄位純重述

`ledgers.md:54` 自承 Closeout 是「收割 Codex override 原文」— 兩份 ledger 是**堆疊**而非**合併**的產物。重複欄位：

| Preflight row | Closeout row | 間隔 |
|--------------|-------------|------|
| 3 Diff self-review | Diff self-review | 同一次 PR 流程內數分鐘 |
| 4 Self-simplification | Self-simplification | 同上 |
| 6 Review gate | Review gate | 同上 |
| 8 Residual risks | Residual risks | 同上 |

**修法**：Closeout 對這 4 列改為「引用 Preflight 對應 row + 差異」，只在 PR 後有新資訊（CI 結果、bot review 處置）時才展開。

### 錯配 4 — `[T0-5]` 與 harness 預設互相對打（唯一「規則造成過度停頓」的實證）

- harness 系統提示：「做例行判斷自己來，只在不同解讀會導致**實質不同的工作**時才詢問」。
- `[T0-5]`：「模糊時 MUST 停下發問…觸發：需求有多種合理解讀且將改檔」。

`[T0-5]` 的觸發門檻低一階（「有多種解讀」vs「解讀差異導致實質不同結果」），會產生真實的過度詢問。其餘 tier0–2 與 harness 的重疊多屬無害備份，且對 Codex / Copilot 有承載作用（那兩家沒有這段 harness 提示），**不建議刪**；只有 `[T0-5]` 需要對齊門檻。

**修法**：`[T0-5]` 觸發條件改為「不同解讀會導致**實質不同的產出**」，與 harness 同階。

---

## 四、可能比散文更大的槓桿：`ultracode`

`~/.claude/settings.json`：`ultracode = true`、`effortLevel = "xhigh"`、`alwaysThinkingEnabled = true`。

ultracode 為 true 時的契約是「**每個實質任務都預設編排並執行 workflow**，token 成本不是限制」。若「感覺被限制太多」的體感來自「小任務也被放大成多階段編排」，那根源在這個開關，不在 tier0 的任何一段文字。

**歷史查證**：`git log -S'ultracode' -- settings.json` 只有單一 commit `0118be7`（`+"ultracode": true`），**從未被關閉又還原** → 這不是「已評估後決定保留」，是「設了之後沒重新評估」。建議重新評估成立。

⚠️ 本 session 未收到確認 ultracode 生效的 system-reminder，故只能斷言 settings 值為 true，無法斷言本 session 行為受其驅動。建議由用戶在互動 session 用 `/config` 確認實際狀態。

---

## 五、**不可動**的規則（每條可回溯到已記錄的真實失誤）

| 規則 | 保留理由（memory 佐證） |
|------|----------------------|
| `[INT-2]` / `[R-2]` 紅測先行 | 防「修了但沒證明修好」 |
| `[T0-2]` 無證據不宣稱完成 | 這是行為傾向問題，模型能力提升不改變它 |
| 「subagent 回報 ≠ 完成證據」(SKILL.md:80) | `[finding 帶佐證仍可能錯]` — apply agent 照抄把正確內容改壞 |
| bot-review 全 caller 枚舉 | `[bot review 覆蓋不完整]` — Copilot 只覆蓋反模式子集；PR #34 漏 8 條、#36 漏 2 caller |
| `[T1-1]` deps-check 先行 | 「改 A 壞 B」回歸最常見來源 |
| `[T0-3]` force-push 攔截 | 已機械化為 hook，prose 為 defense-in-depth |

這些不是「Opus 5 夠強所以可以略過」的候選 — 它們約束的是**行為傾向**（偷懶、樂觀宣稱、信任子代理回報），不是**能力**。能力上升不會讓這些傾向消失。

---

## 六、建議動作（依收益/風險排序）

### (A) workflow 規則層 — 三主機同利，可直接做

| # | 動作 | 收益 | 風險 |
|---|------|------|------|
| 1 | 去重：每條約束單一正本 + ID 引用 | 減 ~30% 規則體積、消除版本漂移 | 低 |
| 2 | LIGHT tier 專屬收尾（Closeout 6→3、Preflight 8→4）＋補回 ≤3 tasks 的入口守衛 | 小任務摩擦大降、讓分層的收益兌現到 S6 | 中（需守住證據底線） |
| 3 | Preflight/Closeout 重複 4 列改引用制 | 收尾字數減半 | 低 |
| 4 | `[T0-5]` 門檻對齊 harness（「解讀差異導致實質不同產出」才停） | 消除過度停頓 | ⚠️ **需用戶明示核准** |

**#4 的特別註記**：`tier0-safety.md` 的衝突裁決鏈自訂「repo 層對 tier0 只可**加嚴**不可**放鬆**；放鬆 tier0 只有 user 當下明示一途」。#4 是放寬 tier0 條文，依系統自身規則必須取得用戶明確同意，不能與 #1–#3（純去重、零語意變更）同批處理。

### (B) Claude-only 的 workflow 規則放寬 — **空**

沒有任何一條 workflow 規則需要「因為 Opus 5 能力強」而為 Claude 開特例。這是本次稽核最重要的結論：開特例會直接抵觸「三主機跑同一條 workflow」的既定目標，而所有實際值得砍的都是三家共同的重複與儀式。

### (C) harness 設定層（非 workflow 規則，Claude-only 且與規則無關）

| # | 動作 | 收益 |
|---|------|------|
| 5 | 重新評估 `ultracode = true` | 若體感摩擦來自「小任務被放大成多階段編排」，這是最大單一槓桿；且查證顯示它從未被重新評估過 |

---

## 附：本稽核用到的量測指令

```bash
# skill 觸發次數（權威來源，非 grep transcript）
python3 -c "import json,os; u=json.load(open(os.path.expanduser('~/.claude.json')))['skillUsage']; [print(v.get('usageCount',0), k) for k,v in sorted(u.items(), key=lambda kv:-kv[1].get('usageCount',0))]"

# workflow 實際載入次數（指紋法，補 skillUsage 對 Read 路徑的盲區）
find ~/.claude/projects -name '*.jsonl' -mtime -30 | xargs grep -o 'FP:DEVWF' | wc -l

# 規則重複盤點
grep -rEn 'T0-8|INT-3' ~/.claude/CLAUDE.md ~/.claude/core/*.md ~/.agents/skills/dev-workflow/{SKILL.md,references/*.md}
```
