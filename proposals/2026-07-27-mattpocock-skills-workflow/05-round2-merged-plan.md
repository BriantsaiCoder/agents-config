# 第二輪：Codex 修正案的驗證與合併計畫

> 2026-07-27。對照 Codex 的 Stage -1 ~ Stage 5 修正案。所有數字為本機實測。

## 1. Stage -1「先去除重複 superpowers」— ⚠️ 本節已被 10:32 重測修正

> **更正（2026-07-27 10:32）**：本節原判定「前提不成立、三家各一份」。重測後修正為 **Codex 的觀察成立、推論需修正** —— Claude 端磁碟上**確實有兩份 hash 相同的 superpowers 6.2.0**（`cache/superpowers-marketplace/` 與 `cache/claude-plugins-official/`），但 `enabledPlugins` 只啟用前者，後者是殘留 cache，**停用它 token 收益為零**。
>
> 差異來源：`~/.claude/settings.json` 在本 session 期間（mtime **10:03**）從 `superpowers@claude-plugins-official` 切換到 `superpowers@superpowers-marketplace`，`~/.copilot/.../brainstorming/SKILL.md`（mtime **10:07**）亦被更新使三家 hash 趨同。下方 09:xx 的觀察是切換前的快照。
>
> **正確版本見 [06-feedback-to-codex.md](06-feedback-to-codex.md) 修正 1 與修正 4。** 本節保留作為「引用 live config 未標時間戳會出什麼錯」的紀錄。

Codex 主張這是「最大、最便宜、最確定的第一筆收益」：兩份完全相同的 superpowers catalog（28 skills ≈ 1,077 tok），停用一個即省 ~539 tok。

**實測推翻。** 那兩份**分屬不同 host 的 plugin 系統**，不是同一 catalog 內的重複載入：

| Host | 安裝來源 | skills | `brainstorming/SKILL.md` sha256 前 16 碼 |
|---|---|---:|---|
| **Claude** | `superpowers@claude-plugins-official` (`settings.json:170`) | 14 | `4a54a4858b99807f` |
| **Codex** | `superpowers-dev/superpowers/6.2.0`（skill roots **r8**） | 14 | `4a54a4858b99807f`（**與 Claude 端相同**） |
| **Copilot** | `superpowers-marketplace/superpowers` | 14 | `e14914605f640e08`（**不同**，疑似版本不同步） |

關鍵證據：

- Claude 端 `settings.json` 只有**一行** superpowers；本 session 的 skill listing 是 **14 個、單一 `superpowers:` prefix、無重複**（loader 直接輸出，最硬的證據）
- Codex 端 skill roots 表 r0–r8 中**只有 r8 一個** superpowers root（`grep -o "cache/[a-z-]*/superpowers"` 唯一命中）
- `~/.claude/plugins/data/` 那兩個目錄（`superpowers-inline`、`superpowers-claude-plugins-official`）**都是空的**（`total 0`），是 plugin 的 data 儲存位置，不是 catalog
- `~/.claude/plugins/cache/.../superpowers/` 下的 4 個版本目錄（5.1.0 / 6.0.3 / 6.1.1 / **6.2.0**）是版本快取，只有 6.2.0 被載入

**Claude 讀 `~/.claude/plugins/`，Codex 讀 `~/.codex/plugins/`，兩者不互通。任何單一 session 只載入一份。** 停用其中一個 = 讓那個 host 失去 superpowers，不是去重。

**但 Codex 挖到一件真的、我沒查到的事**：兩家用**不同的 marketplace**（`claude-plugins-official` vs `superpowers-dev`）安裝同一個 plugin，而 Copilot 那份 hash 還不一樣。這是**版本漂移風險**（三個 marketplace 各自更新，現在同為 6.2.0 只是巧合），是維運問題，不是 token 問題。值得記一筆，但不是「最大收益」。

## 2. Codex 修正我的六點 — 全部成立，接受

| # | Codex 的修正 | 我原本的問題 |
|---|---|---|
| 1 | **官方 Agent Skills 規格只定義 name/description/license/compatibility/metadata/allowed-tools，沒有 `disable-model-invocation`；Codex 與 Copilot 文件均未承諾支援** | 比我的 `validate_plugin.py` 間接證據更權威。**兩條證據同向**，結論加固：Codex/Copilot 在實測前一律視為不尊重 |
| 2 | **token 要同口徑 A/B**，且要分「host 尊重 / 不尊重」兩情境算 | 我只算 description、只算 model-invoked 那 9 個（等於預設尊重）。Codex 的 name+description 雙情境算法更嚴謹 |
| 3 | **「660 vs 5.4k 不是同 scope」** | 對。660 是 Matt 自己的 catalog、5.4k 是本機**整個** catalog。我在報告內有分列，但並排呈現易誤導 |
| 4 | **smart zone ~120k 不該當跨 host 固定常數**，該用「本 ticket 能否在一個新 context 完成」當 gate | 我直接把 repo 的數字當成通則。Codex 這版是對的——數字會隨模型與 host 變動，行為判準才穩 |
| 5 | **「refactor 完全移出 red-green loop 不是無條件更好」**，可能把小整理累積成 review 期的大改 | 我只轉述上游 v1.1 的變更，沒質疑它。這是實質技術判斷，該做決定而非照抄 |
| 6 | **強制 parallel subagents 不符合 `dev-workflow` 的 Codex delegation 限制**（S3/S5 僅在兩個可獨立驗證、file ownership 不重疊的 subtask 且明確允許時才 spawn） | 我建議 S5 導入 two-axis 時沒檢查這條。應改為「可平行才平行，否則兩次獨立 pass」 |

Codex 的 **Stage -1 ~ Stage 5 + canary 驗證**在結構上也優於我的三階段：先 sidecar 併行、以 5–10 個真實任務比對新舊、每次只換一組、任一任務能在缺 evidence 下宣稱 done 即回滾。**採納**（去掉不成立的 Stage -1）。

## 3. 我修正 Codex 的四點

| # | 我的修正 | 影響 |
|---|---|---|
| 1 | **Stage -1 前提不成立**（§1） | 移除它的「第一筆收益」，順序要重排 |
| 2 | **Codex 的 token 表漏了 SessionStart hook 的 766 tok** — superpowers `hooks.json` 每個 session 強制注入 `using-superpowers` 全文 3,063 chars（`async: false`，matcher `startup\|clear\|compact`） | 修正後：superpowers 單 root 真實成本 ≈ **539 + 766 = 1,305 tok**，而非 539。所以 Codex 的結論「若先去重，Matt 全載入 926 甚至沒有 token 優勢」**要改**——Matt 仍有優勢（926 或 488 vs 1,305），只是**優勢來自 hook 不是 description** |
| 3 | **`mp-*` 是刻意的在地 fork，不是過期副本** — 不在 vendored 名單（6 個是 ecpay / security-audit / native-feel / playwright / vueuse / 已退役的 design-doc-mermaid）、`grep -rl mattpocock ~/.agents/skills/mp-*/` 零命中、且自加 `references/` | Codex 的 Stage 2「取代舊 mp-*」若整包覆蓋會抹掉在地化（違反 `[T1-5]`）。它自己有提「不要整包覆蓋」，但把整組替換列為預設路徑——應反過來，**預設挑差異**，整組替換要逐支舉證在地化無獨有價值 |
| 4 | **Copilot 端那份 superpowers hash 與另兩家不同** | Codex 說「每份 SKILL.md hash 都完全相同」——對 Claude/Codex 兩份成立，對 Copilot 不成立。若真要處理版本一致性，Copilot 那份才是漂移的那個 |

## 4. 合併後的順序（兩份建議的交集 + 各自修正）

原 Codex 的 Stage -1 刪除，其餘保留並補入我的修正：

| 階段 | 動作 | 為什麼在這個位置 |
|---|---|---|
| **S-A 修正基線** | 三個注入檔的 stale 宣稱（`~/.claude/CLAUDE.md:74`、`~/.codex/AGENTS.md:57`、`~/.copilot/copilot-instructions.md:57` 的「description 被截斷至 2–6 字元」）改**源檔**再重生成 | Codex 說得對：這是 **correctness 修正不是 token 優化**。routing 策略目前建立在已推翻的假設上。零爭議、可立即做 |
| **S-B 量測基線** | 開新 session 用同口徑重測三家 catalog footprint（name+description，分尊重/不尊重兩情境） | 後面每一步的收益都要對照這條基線；沒有它就只能猜 |
| **S-C sidecar canary** | 裝 Matt upstream **但不刪舊**，挑 `grilling` / `domain-modeling` / `tdd` / `diagnosing-bugs` / `code-review` 五支，用 5–10 個真實任務比對：自動觸發是否正確、是否漏紅測、是否漏 S4–S6、footprint、slash command 記憶負擔 | Codex 的設計，直接採用。基準 commit `ed37663cc5fb` |
| **S-D 逐支替換 `mp-*`** | **預設挑差異**（`mp-tdd` 的 refactor 位置、`mp-grill-with-docs` 的 grilling 三修）；整組替換須逐支舉證在地化無獨有價值。順序 `mp-diagnose` → `mp-tdd` → `mp-grill-with-docs` → `mp-improve-codebase-architecture`；`mp-zoom-out` 暫留（`wayfinder` 完全不是同一件事） | 合併我的「挑差異」與 Codex 的「逐組 + canary」 |
| **S-E 解耦 superpowers** | 改寫 12 處引用（7 檔）為 capability 名或 Matt skill。**`verification-before-completion` 與 `finishing-a-development-branch` 先 re-home 再說**——`[T0-2]` 與 `[INT-1]` 直接點名它們 | 我的 04 §2.5 步驟 1–2 |
| **S-F 移除 superpowers canary** | 停用 plugin，三家開新 session 跑五種代表任務（feature / bugfix / HEAVY plan / review / closeout）。**任一任務能在缺 evidence 下宣稱 done 即回滾** | Codex 的驗收條件，比我的 grep 檢查強 |
| **S-G 最後才瘦身 kernel** | `dev-workflow` 瘦成 S0 routing + S2 授權 + S4–S6 機械 gate；重複於 Matt skill 的 grilling/TDD/debug/review prose 移除 | 兩份一致：只有在同等 gate 已下沉到 hooks / pre-commit / CI 之後才能刪 |

**終態**（Codex 的表述，我同意）：

```
精簡的 global workflow kernel（S0 routing / S2 授權 / S4–S6 evidence gate）
  ├─ Matt user-invoked orchestration（grill-with-docs / wayfinder / to-spec / to-tickets / implement / triage）
  ├─ Matt model-invoked disciplines（grilling / domain-modeling / codebase-design / tdd / diagnosing-bugs / code-review）
  └─ hooks / pre-commit / CI 的機械守門
```

**必須明文寫進 adapter 的一條**：Matt 的 `/implement` 在跑完 TDD 與 code-review 後**回到 kernel 的 S4–S6**，不得因為 upstream SKILL.md 寫著「commit your work」就跳過 verification 與 closeout。這是整個嫁接方案唯一的破窗點。

## 5. 對「是否用 Matt 取代全域 workflow」的最終回答

**不取代，拆層。** 兩份建議在這點完全一致。

刪除舊完整 workflow 的前置條件（Codex 列的八項，我全部同意，另補第 9 項）：

1. T0/T1 有唯一正本
2. S2 confirmation 可被檢查
3. 紅測先於 fix 有可驗證證據
4. build/test/lint 有 exit code
5. review findings 歸零
6. closeout ledger 不可跳過
7. 新 commit 使舊 closeout 失效
8. 三家 host adapter 都已驗證
9. **（補）`verification-before-completion` 與 `finishing-a-development-branch` 的職能已有明確載體** — `[T0-2]` 與 `[INT-1]` 目前直接依賴這兩支 superpowers skill，它們不在 Codex 的八項裡，但少了會直接讓兩條攔截規則失效

否則「完整取代」只是把 prose 變短，卻把守門刪掉。
