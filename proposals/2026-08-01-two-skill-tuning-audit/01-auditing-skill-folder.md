# auditing-skill-folder — 7 條成立發現

自有 skill（`vendored_flag` = `-`），findings 可直接提出具體修改。
所有數據均經 main context 獨立回查，代理原始數字若有出入，以本檔為準。

---

## A1 [HIGH] `count-words.sh` 對中文失明 — `scripts/count-words.sh:38`

```bash
wc=$(wc -w <"$f" 2>/dev/null | tr -d ' ')
```

Step 1 唯一的機械量測是 `wc -w`，按空白切詞。中文沒有詞間空白。

**複驗數據（main context）：**

純中文段落 40 字 / 120 bytes → `wc -w` = **1**。40:1 失真。

但真實 `SKILL.md` 是中英夾雜，稀釋後的落差是每「詞」字元數：

| skill | words | chars | chars/word |
|---|---|---|---|
| `deps-check` | 331 | 3114 | **9.4** |
| `bug-fix-settlement` | 369 | 3276 | **8.9** |
| `sdd` | 285 | 2501 | **8.8** |
| `dev-workflow` | 1026 | 8671 | **8.5** |
| `typescript-best-practices` | 466 | 3508 | 7.5 |
| `react-best-practices` | 460 | 3319 | 7.2 |

→ 中文重的 skill 被低估約 **20%**。

**代理原報告宣稱 55%（用 byte 算），對抗驗證已駁回並改為 3.5%（按字元的 corpus 級倒置幅度）。本檔採用複驗值。**

**具體後果：** CJK-heavy skill 的字數與英文 skill 不可比，共用同一條 500 limit，因此 Step 1 的 OVER gate 對它們形同不存在——永遠不會被路由到 `step1-verdict-guide.md`。live corpus 上實際的排序倒置只有一組：`aspnet-api-architect`（431 words / 4178 chars，未標記）低於 `auditing-skill-folder`（661 words / 4038 chars，標 OVER）。

**建議修法——加不是換：**

保留 `wc -w`（英文行為 byte-identical），並列加字元欄：

```bash
chars=$(LC_ALL=en_US.UTF-8 wc -m <"$f" | tr -d ' ')
```

字元預算 ~3000 / 1200 / 900（對應 500 / 200 / 150，按英文約 6–7 字元/詞）。**任一超標即 OVER**，兩欄都印，讓稽核者看見是哪個觸發的。

> 這條與 `lint-descriptions.sh` 是同一病灶的兩半：後者 2026-08-01 已取得 zh-TW 支援，前者完全沒有多位元組處理。

---

## A2 [HIGH] 文件說「四訊號聯集」，實際有五個 — `step0-vendored-gate.md:19`、`SKILL.md:16`

`lib-vendored.sh:105` **第一個**檢查的是 `vendored-skills.lock`（優先於其他所有訊號），而這個檔在整個 skill 的散文裡**一次都沒出現**——只以路徑常數存在於 `lib-vendored.sh:30`。

**複驗數據（main context）：**

```
54 個 VND 中，僅靠 vendored-skills.lock 判定 = 23 個
                  另有其他訊號              =  3 個（其餘 28 個非 lock 路徑）
```

那 23 個 flag 用 skill 自己的文件**完全復現不出來**（無 LICENSE、無 provenance marker、無 `upstream:`、不在 `mattpocock-skills.lock`）。

**最尖銳的案例：**

```
aspnet-api-architect
  flag  = VND
  owner = https://github.com/BriantsaiCoder/agents-config/tree/44c7fd07.../skills/aspnet-api-architect
```

**OWNER 是使用者自己的 repo。** 稽核者很容易據此判斷「偵測器壞了、這是自有的」然後下 Trim/Split，正好是 gate 存在要防的那個 in-place edit。唯一能澄清的是 `vendored-forks.md` 的 "Unresolved Stage B2 provenance" 段，而 skill 沒有任何檔指向那裡。

**建議修法：**
1. `step0-vendored-gate.md:19` 的「union of four signals」改五，表格（:9）與 `SKILL.md:16` 各補一列：repo-root `vendored-skills.lock` 的精確 tab-separated basename 記錄 → `VND`，第 2 欄 `source_url` 渲染為 OWNER。
2. 明確標註：**recorded source 可能就是本 repo**，provenance 未解者見 `vendored-forks.md`。
3. 「0 false positives」的宣稱要在確認 `tests/vendored-detection.sh` 覆蓋 lock 路徑後才重述（驗證者已確認有覆蓋，91/91 通過）。

---

## A3 [MEDIUM] Step 5 的分類法沒有定義 — `SKILL.md:30`

```
| 5 | Type clarity | Read | Technique / Pattern / Reference; flag mixed-type → propose split |
```

全資料夾 grep：`Technique` 只出現在 `SKILL.md:30` 與 `:42`，兩處都不是定義；`Pattern` 作為型別只出現在 `:30`。宣告的家規權威 `references/skill-standards.md` 完全沒提這兩詞。外部引用的 `writing-great-skills/GLOSSARY.md` 只定義 `Reference`(:89) 與 `Steps`(:85)，**沒有 Technique / Pattern 這一階**。

**後果：** 稽核者必須自己發明分類法，而 `SKILL.md:42` 同時推他一把（「混型才是常見缺陷，不是缺型別」）。`tdd` 算 Technique 還是 Pattern、因此混型與否，從文本無法裁決——但 Split 是 Iron Law 六個 verdict 之一，且 Step 5 漏做要重來。

**建議修法（二擇一）：**
- 在 `references/skill-standards.md` 給三型各一句判別語 + 一個 corpus 實例，`SKILL.md:30` 指過去；或
- 若分類法本質不可檢查，把 Step 5 的觸發條件換成可檢查的（例如「SKILL.md 同時含有序程序與沒有任何步驟消費的扁平規則集」），並刪掉 Technique / Pattern / Reference 標籤。

---

## A4 [MEDIUM] 三個字數預算有兩個匹配 0 個 skill — `scripts/count-words.sh:32-36`

```bash
case "$name" in
  using-*|getting-started*) limit=150 ;;
  *-core|*-rules)           limit=200 ;;
  *)                        limit=500 ;;
esac
```

`~/.agents/skills` 95 個、`~/.claude/skills` 95 個，**兩個 tier 各匹配 0 個**。它們是不可達的死分支——按這個 skill 自己的 no-op 判準就是 no-op，也正是它自己 `step7-style-checks.md:15` 要標的（`Style:fix-information-hierarchy`）。

**驗證者砍掉的兩項支撐（本檔不採用）：**
- ✗「`dev-workflow` 無預算」：它 1026 words 在 500 limit 下照樣 OVER，沒有 verdict 改變。tier 差異只在 201–500 字的常駐 skill 才有意義，而 corpus 中無此例。
- ✗「命名慣例已過時（core/ rules/ 已退役）」：`attic/core`、`attic/rules` 是 `~/.agents/` 下的目錄，與 skill basename 是不同命名空間。

**建議修法：** 把 tier 改綁 corpus 真的帶得動的常駐訊號（frontmatter `tier:` 鍵，或腳本旁的 allowlist 檔），而非目錄名；在該標記存在前，`SKILL.md:26` 只陳述唯一會觸發的那條 limit。並加一個 `tests/` case 斷言「每個宣告的 tier 至少有一個 corpus skill 落在上面」，避免再次靜默死亡。

---

## A5 [MEDIUM→LOW] `vendored_owner()` 與 `vendored_flag()` 不對齊 — `lib-vendored.sh:245`

檔頭第 3 行宣稱兩者「lookup-for-lookup 對齊」。實際上：

| | flag（:136） | owner（:245） |
|---|---|---|
| github repo 參照 | `github\.com/<o>/<r>skill` **不要求 scheme** | 硬性要求 `https?://` |

只有無 scheme repo 參照當唯一 provenance 的 skill，會 flag 成 `VND` 但 OWNER 空白（已用 fixture 驗證）。

**驗證者降級理由：** 現行 95 個 corpus **0 次發生**，屬潛在硬化項；且 `marketplace` / `install this skill` 兩分支印空白是 `tests/vendored-detection.sh:161-165` 明確釘住的「誠實空白」邊界，不是契約違反。

**建議修法：** 把 scheme 改為選用（`(https?://)?`），並在 `check-vendored.sh:32` 加終端守衛——VND/VND* row 的 owner 為空時印 `(VND, unattributable — investigate)`，讓空白結構上不可能被誤讀成乾淨 row。

---

## A6 [MEDIUM] 觸發失敗的路由只寫了第一跳 — `SKILL.md:12`

現行：

> **Not for:** ... debugging one skill's single trigger (route to `diagnosing-bugs`)

家規原文（`dev-workflow/SKILL.md:54`）：

> 單一 skill trigger failure ｜ `diagnosing-bugs` 建 RED canary；**需要改寫時續接 `writing-great-skills`**

第二跳被丟掉了。因為本 skill 是 model-invoked、且描述自稱處理「skill trigger rate feels low」，它會在 `dev-workflow` 不在 context 時直接觸發；接著交給 `diagnosing-bugs`——那支能正確建 RED canary，但**它的 body 完全沒有 description、leading word、pointer wording 的內容**，改寫的權威從此到不了。

已確認第二跳不在 `step0-vendored-gate.md`、`step1-verdict-guide.md`、`step7-style-checks.md` 任一處。

**次要且獨立：** 同一條路由規則現在有兩個真實來源，而且**已經漂移了**。

**建議修法：** 改為指向 `dev-workflow` 的路由表（`skills/dev-workflow/SKILL.md:49-55`），讓路由規則回到單一真實來源；或至少補完兩跳。

---

## A7 [MEDIUM] 描述承諾跨 skill 症狀，協定卻只逐一評分 — `SKILL.md:3`

description 宣稱適用於「when skill trigger rate feels low」，但 Steps 1–6 加 Step 7 **每一步都是孤立地評一個 skill**——沒有任何一步把 description 互相比對。因此 trigger collision 不可能出現在任何 verdict 裡。

已確認不存在於：`SKILL.md` 步驟、Red Flags 表、`step0-vendored-gate.md`、`step1-verdict-guide.md`、`step7-style-checks.md`、`references/skill-standards.md`。最接近的 `step1-verdict-guide.md:11` 管的是 body workflow 重疊，不是 description trigger space。

被稽核的資料夾裡就有現成案例：`writing-great-skills` 與 `make-skill-template`。

**建議修法：** Step 2 擴充（或加 Step 2b）為對 lint 表的跨 skill pass——把 model-invoked description 依宣稱的 trigger space 分群，任兩個宣稱同一 trigger 且無區辨語者記為 Collision。並補 Red Flags 一列：

```
| "每個 description 單獨看都沒問題" | Collision 逐一看不見——要把 description 互相比對，不只比對規則 |
```
