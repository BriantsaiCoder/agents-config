# writing-great-skills — 落地後獨立複審（原版 vs `004d67a`）

第三輪。前兩輪的 findings 與 A/B 證據在 `02-writing-great-skills.md`；本文只寫**該文尚未涵蓋**的東西，
不重述其量測表與 verdict。

## Verdict：需要調教，但只有一項是必須的，且不動 skill payload

依證據層級分四級，這個分層本身就是結論：

| 級別 | 項目 | 理由 |
|---|---|---|
| **必須修** | F1，取「校正記錄」不取「復原」 | `vendored-forks.md` 對已部署 payload 做了機械可驗的不實聲明。取校正＝零 payload 變更、零指紋重算；取復原＝fork 第三次擴大，而 round 2 的取捨有 A/B 支持 |
| **值得順手** | F3 | 不需 canary：契約句被刪、依賴該契約的 pointer 留著，矛盾從兩檔內容即可證明，且字數不變 |
| **可修，屬推理層** | F2 | 4 words。誤路由是文本推理，**未經 canary 觀測**；驗證成本（隔離 HOME 的 host-CLI run）高於修法本身，故不以驗證來決定 |
| **不需動** | F4、F5 | F4 已定性為驗證缺口非回歸；F5 零行為影響，paired canary 顯示 primary-owner recall 無回歸 |

**接受 round 2 取捨的誠實揭露**：A/B fixture 植入的四個缺陷（模糊 description、body-only trigger、
broken relative reference、vague completion + duplication/no-op）沒有任何一個是「帶有可被 leading word
收斂的重述」，所以 imperative 被刪這件事 A/B 兩個方向都沒測到。接受 round 2 是一個有意識的判斷，
不是被證據背書的結論——與 F4 同類，同樣不構成回歸。

## 執行結果（third pass，2026-08-01）

| Finding | 狀態 | 落點 |
|---|---|---|
| F1 | **已執行**（校正記錄，未復原） | `vendored-forks.md` 兩塊 `Reconciliation (F1)`；決策行更新 |
| F3 | **已執行** | `SKILL.md:14` 契約句 + 13 個術語 bold；契約措辭改 "Every bold term **below**" 並自身不加粗，因其上方兩個 `REQUIRED` 標籤是 bold 但非 heading |
| F2 | **已執行**（超出本次授權，由既有 worktree 帶入） | `SKILL.md:10` 加 branch 限定；`cases.jsonl` 兩個配對 case；`tests/trigger-eval.sh` 三條斷言 |
| F5 | **已執行**（超出本次授權，同上） | description 補 `Agent Skill authoring.` |
| F4 | **未動**（如判定） | — |

附帶修正：`tests/matt-thin-workflow.sh:116,120` 兩條寫死措辭的斷言因 F2／F5 改動而 FAIL，已改為斷言
新措辭——順帶把 identity clause 與 RED gate 的 branch 限定變成 CI 斷言。

### 效力驗證：candidate vs 21:00 原版

同一個 16-line synthetic fixture（SHA-256 `1922d454…`，與 `02-writing-great-skills.md` 記錄逐位元組相同），
同一個 read-only review prompt，`codex exec --ephemeral -s read-only -c model_reasoning_effort=low`。

**第一次 A/B 無效**：`-C <fixture-root>` 不改變 skill 解析路徑，兩側都讀 live `~/.agents/skills`
（兩份 transcript 皆 `rg /Users/pochientsai/.agents/skills/...`）。改用隔離 `HOME`（`$root/home/.agents`
symlink 到各自版本、`.codex` symlink 保留 credential）後才真正分離，transcript 分別解析到
`.worktrees/fix/wgs-f2-f3-f5/…` 與 `wgs-snapshot/…`。

**n = 1 per side**（單次 low-effort sample，非 paired 多次）。

| 量測 | 21:00 原版 | candidate | 判定 |
|---|---|---|---|
| 核心 defect recall | 4/4 | 4/4 | 持平 |
| Scope（最終輸出） | 擴張成 folder Six-step audit（Vendored gate／Token cost／Stance bleed…） | 守在 single skill，12 列 Audit ledger | **candidate 勝** |
| Verdict 類型 | `DELETE`——lifecycle 裁決，屬 folder auditor 的職責 | `FAIL` + 逐列 `KEEP`／`CHANGE`／`N/A` + evidence | **candidate 勝** |
| Probe evidence | 有 | 有（`details_file_exit=1`） | 持平 |

**結論：candidate 效力 ≥ 原版**——但成立的理由不是分數差，n=1 撐不起那種宣稱。本文件
`02-writing-great-skills.md:93-94` 自己就拒絕從單次 sample 宣稱 routing 改善。這裡可以下判斷，
是因為兩項差異**結構性且可追溯到被改的文字**：scope 擴張對應被 trim 刪掉的 folder-audit 散文，
verdict 型別對應被加入的 `KEEP`／`CHANGE`／`N/A` output contract。兩者都不是邊際分數波動。

**框架修正**：原版的 `DELETE` 對這個 fixture 而言不是錯誤判斷，是**越界**判斷——lifecycle 裁決
屬 `auditing-skill-folder`。candidate 的勝點是 scope discipline 與 output contract，不是 correctness。

Result SHA-256（含絕對路徑，僅供同機重播比對）：candidate `08a50fd158ce37f569a0e159ef596c65d08183819a11bb8adb66c9d76a3969ea`、
原版 `153a63d74ee2bcce1b8c233093289ad4af7d23d6578e2c9276443526be74dadb`。

**偏離揭露**：candidate 的總結行用了 `Verdict: FAIL`，而 `SKILL.md:12` 的 output contract 只定義
`KEEP`／`CHANGE`／`N/A`。逐列 ledger 遵守契約，額外的總結標籤是契約外的加碼，非缺陷但如實記錄。

## 比較邊界（已驗證）

| 項目 | 值 | 驗證指令 |
|---|---|---|
| 原版 snapshot | `15f055d`（2026-07-31 20:51:39 +0800） | — |
| 該 snapshot 的 skill payload | 等同 `04d273b`（20:05:51），本路徑無差異 | `git diff 15f055d 04d273b -- skills/writing-great-skills/` → 空 |
| 當前版本 | `004d67a`（2026-08-01 11:35:37 +0800），worktree clean | `git status --short` |
| 部署副本 | `~/.claude/skills/writing-great-skills` 為 symlink，無第二份實體 | `readlink` |
| fork 指紋 | live tree `b58b27d78ee…` **＝** `vendored-forks.md` 記錄 | `vendored_tree_sha256` |
| `SKILL.md` 字數 | 427 / limit 500（餘裕 73），**含 frontmatter**（其中 50 words） | `count-words.sh skills`；`matt-thin-workflow.sh:128` 用 `LC_ALL=C wc -w` 全檔 |

三個獨立變更點：`387c5e2`（round 1，11 項調教）→ `004d67a`（round 2，結構精簡）。
以下 findings 多數來自 **round 2 相對 round 1** 的差異，前兩輪報告成文於 round 2 之前。

---

## F1 — round 2 靜默回退 round 1 的兩項已登記修正，fork 記錄仍宣稱它們 active

`vendored-forks.md` 的 `### Local changes` → **Body corrections** 表格每一列都是對當前 tree 的事實聲明。
逐列比對 `git diff 387c5e2..004d67a` 後，兩列不成立：

**(a) `SKILL.md` leading-word section「Moved the imperative up from GLOSSARY」**

round 2 刪除整個 Leading words 章節。祈使句 `Word a description with the leading words you actually use…`
回到只存在於 `GLOSSARY.md` 的按需檔——正是該列宣稱要修掉的狀態。

更實質的是方向反轉。原版 `SKILL.md` 獨有一條主動指令：

> Hunt for opportunities to refactor skills to use leading words. … Assume every skill is carrying
> restatements that leading words retire — go find them.

`grep -i "hunt for\|go find"` 對當前 `SKILL.md` 與 `GLOSSARY.md` 皆零命中。取而代之的是
`SKILL.md:41` 的許可閘：

> Use a leading word only when a canary shows that it improves invocation or execution.

從「預設每個 skill 都有可收斂的重述，去找出來」變成「沒有 canary 就別用」。這條是本 skill 相對其他
authoring 指南最原創的槓桿，現在預設關閉。

**(b) description「B3 診斷 branch trigger」**

round 1 的 description：`…when a skill fires unreliably, sprawls, repeats itself, or lets the agent stop early…`
round 2 刪除全部四個症狀詞，只留抽象的 `pruning`。而 `GLOSSARY.md` 仍完整保留 Sprawl / Sediment /
Duplication / No-Op / Premature Completion / Negation 六個 `_Failure mode._` 條目——B3 當初要修的正是
「這 13% 內容依其自己宣告的用途不可達」。

（表格第四列 rung 3「External reference → **Reference**, disclosed」也已被 round 2 整段改寫，該列同樣
失效，但歧義本身隨改寫消失，屬 stale 記錄非回歸。）

**處置（二選一，都要動 `vendored-forks.md`）**

1. 認可 round 2 的取捨 → 把 Body corrections 表更新為 round 2 實況，明標哪幾列已被 second pass 取代。
2. 判定為回歸 → 復原 leading-word imperative 與 description 的症狀詞，再重算 tree SHA。

無論選哪個，現況是 fork 記錄對已部署 payload 說了不實的話，且 `matt-thin-workflow.sh` 只驗 tree SHA
與四個錨點，不驗表格內容，所以這個漂移不會被 CI 抓到。

---

## F2 — `SKILL.md:10` 的閘門無條件語氣，而它落空的那個 branch 零測試覆蓋

```
L8   **REQUIRED PRECONDITION:** Unreliable invocation needs a preserved RED trigger canary. …
L10  **REQUIRED SUB-SKILL:** When no caller provides that RED, invoke `diagnosing-bugs` first.
L12  For a full behavioral authoring or pruning audit … For a scoped edit, cover only the named branch …
```

L8 自帶限定（`Unreliable invocation needs…`）。**L10 沒有**——`When no caller provides that RED` 對任何
沒帶 RED 的任務都成立，包含 description 首要 branch 列的五種純編輯。限定要到 L12 才出現，跨兩段。
依本 skill 自己的 Context Pointer 定義（wording 決定觸達的時機與可靠度），一個適用範圍延後兩段才解析
的閘門就是 variance bug。

**覆蓋缺口正好對齊這個歧義。** `skills/auditing-skill-folder/evals/cases.jsonl` 共 27 case，
`writing-great-skills` 只有 3 個：

| expect | id | 覆蓋 |
|---|---|---|
| quiet | `quiet-writing-skill-pre-red` | 無 RED 的失靈 skill → 不該 fire |
| fire | `fire-writing-skill-after-red` | Step 2c 給了 RED → 該 fire |
| quiet | `quiet-writing-great-skills-folder` | 整個資料夾稽核 → 不該 fire |

三個全在 RED／folder 邊界上。對照 `02-writing-great-skills.md:85-89` 跑的四個 routing scenario：
C（folder audit）與 pre/post-RED 邊界有 case，**A（edit one existing skill description/completion）
與 E（convert one existing skill to user-only metadata）零 case**——而這兩者正是 description 開頭列的
branch。使用者說「把這個 skill 從 model-invoked 改成 user-only」（無 misbehavior、無 RED），L10 會把它
推去 `diagnosing-bugs`，現有 eval 測不出來。

**修法**（餘裕 73 words，成本 +4）：

```
**REQUIRED SUB-SKILL:** For a misbehavior rewrite with no caller-supplied RED, invoke `diagnosing-bugs` first.
```

配 case 取 E 而非 A——A 的自然措辭（「agent 提早收工」）本身就是 misbehavior 症狀，對 RED 是否適用有歧義；
E 是純 metadata 轉換，無症狀，應無條件 fire：`fire-writing-skill-user-only`，prompt「Convert this skill
from model-invoked to user-only metadata.」expect `fire`，並在 `diagnosing-bugs` 側補對偶 `quiet` case。

---

## F3 — 術語導航訊號從 43 個掉到 4 個，`GLOSSARY` pointer 失去解析依據

| | 原版 | 當前 |
|---|---:|---:|
| `SKILL.md` 內 `**bold**` 標記 | 43 | 4 |
| 其中屬 GLOSSARY 條目者 | 大多數 | 2（`Model-invoked` / `User-invoked`；另 2 個是 `REQUIRED` 標籤） |

關鍵不在 bold 消失，而在**契約句被刪且無替代**。原版 `SKILL.md:8` 明文宣告對映：

> **Bold terms** are defined in [`GLOSSARY.md`](GLOSSARY.md); look them up there for the full meaning.

round 1（`387c5e2:10`）保留並強化了它。round 2 把契約句連同 43 個標記一起刪除，卻留下一個
**預設 agent 仍能辨識 heading** 的 pointer。

`GLOSSARY.md` 有 27 個 `###` 條目。當前 `SKILL.md:14` 的 pointer 是：

> Definitions and failure modes live in [`GLOSSARY.md`](GLOSSARY.md). Load only the headings the
> current branch needs…

但內文裡 `completion criteria` / `pruning` / `branch` / `reference` / `leading word` / `relevance` /
`duplication` / `no-op` / `router` / `steps` / `hierarchy` **11 個詞全部裸寫**。判斷哪些詞算 heading 的
責任被整個外包給猜測。`GLOSSARY.md` 內部反而仍大量使用 bold 交叉引用，兩檔的標記慣例現在不一致。

**修法**：對首次出現的 GLOSSARY 術語恢復 bold（11 處，`wc -w` 不變，零預算成本），pointer 改為
「Bold terms are `GLOSSARY.md` headings; load the ones the current branch needs.」

---

## F4 — 28 條 `_Avoid_:` 的移除已固化進 CI，但它保護的行為從未被任何 canary 量過

`tests/matt-thin-workflow.sh:135` 主動斷言其不存在：

```bash
! rg -q '^_Avoid_:' "$WRITING_GLOSSARY" ||
  fail 'writing-great-skills glossary still carries negation sediment'
```

判定理由是 negation sediment。但那些行約束的是**作者選同義詞**，不是 agent 的 runtime 行為——
Negation failure mode 講的是「用禁令 steering agent 會反效果」。而本 skill 的 Leading Word 條目主張術語靠
`repeated as a token, never as a sentence` 累積分散定義，同義詞紀律正是該機制的載體：`_Avoid_: consistency,
reliability` 存在的目的是讓 `predictability` 這個 token 不被稀釋。

**不宣稱這是已證實的回歸。** 陳述為驗證缺口：round 2 的 A/B 量的是 defect recall（4/4 兩側同分）與 scope
discipline，`cases.jsonl` 量的是路由；**沒有任何一項量測輸出是否使用 canonical 術語**。刪掉了一個機制，
而該機制對應的觀測從未存在。

**修法（若要補）**：不必回復 28 行。`GLOSSARY.md` 頂部單行「Use each heading's exact term; a synonym
dilutes the token.」——行首非 `_Avoid_:`，不會踩到現有斷言；再補一個術語一致性 eval case 才算真的把
觀測建起來。

---

## F5 — description 缺 identity，違反 `SKILL.md:27` 自己剛寫下的規則

`SKILL.md:27`：

> A model-invoked description states the skill's identity **and** one real trigger per branch.

當前 description 直接以 `Use when editing one existing Agent Skill's…` 開頭，無 identity 子句。
原版有（`Skill authoring guidance.`），round 1 也有（`Skill authoring.`），round 2 移除。

三選一：description 補回 `Agent Skill authoring.`（+3 words，**計入** 500 budget——`wc -w` 吃全檔，
frontmatter 現佔 50 words）；或把 L27 改成只要求 trigger；或明記為刻意豁免。現況是規則與範例互相打臉，
而這個 skill 的讀者正是拿它當範本的 authoring agent。

---

## 不建議動的兩項

**description 的 ownership 排除句**（`the host creator owns new-skill scaffolding, and the folder auditor
owns directory audits`）——doctrine 上站得住：Negation 條目要求禁令必須「pair it with the positive
target」，指名 owner 正是正向配對。真正該記錄的是效果：`02-writing-great-skills.md:87` 的 paired canary
顯示 Claude 在 case B（scaffold 新 skill）**兩側都誤選 WGS**。這個 clause 沒有買到它針對的碰撞修復。
歸類為「槓桿未動指標」，不是 doctrine 違規；要不要留取決於它在 Codex／Copilot 側是否有貢獻，而 paired
表顯示那兩家兩側本來就正確。

**`GLOSSARY.md` 按 axis 拆四檔**——反對。犧牲本 skill 明文教的 Co-location，換取會被整檔讀取抵銷的
token，並新增四個各自需要觸達條件的 pointer。當前 3,216 words 全載入沒有出現失敗徵兆。

---

## 建議執行順序

| # | 動作 | 檔案 | 風險 |
|---|---|---|---|
| 1 | F2 的 L10 限定 + 兩個 eval case | `SKILL.md`、`cases.jsonl` | 低，+4 words |
| 2 | F3 的 bold 恢復 + pointer 改寫 | `SKILL.md` | 低，字數不變 |
| 3 | F5 的 identity 子句 | `SKILL.md` frontmatter | 低 |
| 4 | F1 的取捨決定 + `vendored-forks.md` 校正 | `vendored-forks.md`（±`SKILL.md`） | 中，需重算 tree SHA |
| 5 | F4 的單行紀律 + 用詞 eval | `GLOSSARY.md`、`cases.jsonl` | 中，需確認不觸發現有斷言 |

1–3 改完 `SKILL.md` 一次重算指紋即可。4 若選「復原」則與 1–3 合併為同一次指紋更新。

**動手前先知道的兩個機械約束**（`tests/matt-thin-workflow.sh:135-138` 斷言「不存在」）：

- 復原 leading-word 段落時不可帶回 `_comprehensive_, _thorough_` 的措辭（L137 斷言）。
- F4 的單行紀律不可放在 `_Avoid_:` 開頭的行（L135 斷言以行首錨定，單行摘要不觸發）。

**一項成本，供決策用**：F1–F5 任一項落地都是這個 vendored fork 的**第三次擴大**。
`vendored-forks.md` 的 2026-07-31 決策原文寫「do not extend it」，此後已被擴大兩次。
