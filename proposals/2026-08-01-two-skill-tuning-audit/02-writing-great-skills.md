# writing-great-skills — 11 條調教提案

`VND*`（mattpocock/skills @ `ed37663`），現有 fork 範圍僅「model invocation metadata only」。
**判斷不受 provenance 影響**；provenance 只決定落地程序（見 `04-execution-order.md`）。

裁決者退回 25 條中的 13 條。以下 11 條為存活者，關鍵 4 條經 main context 獨立複驗。

---

## 總體判斷

> 需要調教，但幅度不大，而且集中在三處而非散佈全檔。資訊階層、granularity、leading words 三節基本不需要動。

---

## B1 [HIGH] 全檔沒有窮盡性門檻——而它自己說這是缺陷 — `SKILL.md:6`

**這條是它違反自己 doctrine 最直接的一次。**

- `SKILL.md:34` 自稱「_This skill is all reference._」
- `SKILL.md:37`：「since 'every rule applied' binds flat reference just as 'every step done' binds a sequence」
- `GLOSSARY.md:139`：demand 軸「is _not_ step-bound... which is how a skill with no steps still carries an exhaustiveness bar」

它主張「無步驟的 skill 仍須帶窮盡性門檻」，然後自己沒有帶。六節裡只有兩節帶 demand（Pruning 的 "Check every line" / "hunt no-ops sentence by sentence"，Leading words 的 "go find them"）；Invocation、Writing the description、Information hierarchy、When to split **四節零 demand**。

**具體失敗：** 被叫去「整理一下這個 skill」時，agent 讀完 Invocation、改完 frontmatter、回報完成，從不執行 no-op sweep、也不獵 leading word——正是 `GLOSSARY.md:145` 自己預測的「thin legwork under an unmet demand」。涵蓋範圍變成「prompt 剛好提到哪一節」，那正是這個 skill 存在要消除的變異。

**提議（在 :6 之後加一段）：**

```markdown
Every rule below applies to the skill in hand. You are done when each section has produced a
verdict: the **invocation** chosen, the **description**'s **branches** listed, every piece's rung
on the ladder fixed, every line put through **relevance**, **duplication** and **no-op**, every
restatement tried against a **leading word**, and each **failure mode** ruled in or out.
```

錨在 :6 而非 :8，避免與 B7 的 pointer 修改衝突。

---

## B2 [HIGH] GLOSSARY 給的操作與 repo 實況相反 — `GLOSSARY.md:33`

**現行：**
> Its mere presence _is_ the invocation axis: keep it and the skill is model-invoked (and reachable by other skills); **delete it** and the skill is **user-invoked**, reachable only by the human.

**但 `SKILL.md:15` 說：**
> Mechanics: set `disable-model-invocation: true`; the `description` **becomes human-facing** — a one-line summary, trigger lists stripped.

**欄位是保留的。GLOSSARY 說刪掉。**

而 `SKILL.md:8` 正是那句把 agent 導去 GLOSSARY「查完整意義」的指令——所以照這個 skill 自己的導航走的 agent，拿到的是錯的操作，會去刪一個必要的 frontmatter 欄位。

**複驗數據（main context）：**

```
frontmatter 帶 disable-model-invocation: true 的 skill = 12 個
其中保留 description: 欄位的                          = 12 個  ← 全部
```

（代理原報告說 13 個並列入 `dev-workflow`——那是錯的，`dev-workflow` 只在 body 提到那個 key，frontmatter 沒設。本檔採用複驗值 12。）

**提議：**

```markdown
Whether the agent can see it _is_ the invocation axis: expose it and the skill is model-invoked
(and reachable by other skills); withhold it — the field stays, `disable-model-invocation: true`
keeps it out of the agent's reach — and the skill is **user-invoked**, invocable only by the human.
```

**同一 pass 必須一併改的伴隨編輯**（否則檔案會以新的方式自相矛盾）：
- `GLOSSARY:45`「escape by having no description」→「escape by keeping their description out of the agent's reach」
- `GLOSSARY:97`「since neither has a description」→「since the agent sees neither one's description」
- `GLOSSARY:27`（見 B9）、`GLOSSARY:57`（見 B10）

---

## B3 [HIGH] description 少了一整條 branch 的 trigger — `frontmatter:3`

**現行：**
```yaml
description: Skill authoring guidance. Use when creating or editing a single skill, including
  invocation, descriptions, information hierarchy, completion criteria, and pruning.
```

**兩個對照它自己 doctrine 的缺陷：**

**(a) 診斷 branch 完全沒有 trigger。** `SKILL.md:73-75` 明確開了第二條 branch：

```
## Failure modes

Use these to diagnose issues the user may be having with the skill.
```

（已 main context 複驗存在。）但 description 對此零觸發詞——「我的 skill 都不會觸發」「agent 老是做一半就停」什麼都對不上，佔全檔 13% 的 Failure modes 節**依它自己宣告的用途是不可達的**。

**(b) 沒有 reach clause。** `SKILL.md:27` 明確保留了這個位置（"plus any 'when another skill needs…' reach clause"），而且確有 caller：`dev-workflow/SKILL.md:52` 與 `:54`、`auditing-skill-folder/SKILL.md:12`。

**提議：**
```yaml
description: Skill authoring. Use when creating, editing, or pruning a single skill or its
  description; when a skill fires unreliably, sprawls, repeats itself, or lets the agent stop
  early; or when another skill routes a single-skill edit here.
```

尾端那串節名被換掉，因為 `GLOSSARY:125` 定義 branch 是「a case the skill handles」，不是標題——沒有人會把需求講成「information hierarchy」。

**裁決者刻意否決了三個 lens 都提的「砍掉身分句」**：`SKILL.md:23` 把「state what the skill is」列為 description 的明確職責之一，整句砍掉是超譯它自己的規則。改為壓到兩個字（`Skill authoring.`）。`a single skill` 保留，那是對 `auditing-skill-folder` 的邊界。

---

## B4 [MEDIUM] GLOSSARY 持有 SKILL.md 的操作結論，且已漂移 — `GLOSSARY.md:21`

**現行末句：**
> Pick model-invocation only when the agent must reach the skill on its own; if it never fires except by hand, drop the description and pay no context load.

**`SKILL.md:17`：**
> Pick model-invocation only when the agent must reach the skill on its own, **or another skill must**.

GLOSSARY 的副本**掉了「or another skill must」**。透過 GLOSSARY 取得規則的 agent 會套用較窄的判準，把 description 從一個確實有其他 skill 需要觸達的 skill 上剝掉。

**提議：** 刪掉整句。Model-Invoked 條目結束在「...reference needed by several skills lives in one place.」（一刪修兩缺陷：漂移的副本 + 第四處 "drop the description" 假前提。）

---

## B5 [MEDIUM] user-invoked 的機制對多 host 資料夾不完整 — `SKILL.md:15`

**複驗數據（main context）：**

```
user-invoked 且帶 agents/openai.yaml 的 skill = 12 個
其中同時設 allow_implicit_invocation: false   = 12 個  ← 全部
（ask-matt / grill-me / grill-with-docs / handoff / implement /
 improve-codebase-architecture / setup-matt-pocock-skills / teach /
 to-spec / to-tickets / triage / wayfinder）
```

只設 `disable-model-invocation: true` 在帶 per-host 政策檔的資料夾裡是不夠的——**而這個 skill 自己的資料夾就帶著一個**（`writing-great-skills/agents/openai.yaml`，且現值是 `allow_implicit_invocation: true`）。

**提議：**
> Mechanics: set `disable-model-invocation: true`, and flip every other per-host invocation key the folder carries (e.g. `allow_implicit_invocation: false` in `agents/openai.yaml`) or the skill stays model-invoked on that host. The `description` field stays; it becomes human-facing — a one-line summary, trigger lists stripped.

---

## B6 [MEDIUM] 一個粗體詞解析出兩個意思 — `SKILL.md:35`

第三階名為 **External reference**，但 `GLOSSARY:97` 把 External Reference 定義為「lives **outside the skill system** — a plain file, no description, no steps, **not invocable**」——這個定義**排除了該階自己舉的例子**（`GLOSSARY.md` 這個 sibling 檔）。

`SKILL.md:8` 承諾粗體詞解析成一個意思。這裡解析成兩個。

**提議：**
```markdown
3. **Reference**, disclosed — pushed out of `SKILL.md` into a separate file, reached by a
   **context pointer**, loaded only when the pointer fires; a sibling like `GLOSSARY.md` is still
   part of the skill. Pushed out of the skill system entirely it becomes **external reference**,
   which any skill can point at.
```
（這也讓階名與 `GLOSSARY:73-77` 自己列的三階名稱一致。）

---

## B7 [MEDIUM] 唯一的 context pointer 沒有編碼任何條件 — `SKILL.md:8`

**現行：**
> **Bold terms** are defined in [`GLOSSARY.md`](GLOSSARY.md); look them up there for the full meaning.

依它自己的定義（`GLOSSARY:39`），pointer 的措辭「decides _when_ the agent reaches — and _how reliably_」。「look them up there for the full meaning」**沒有指出任何 when**。而 GLOSSARY 為診斷 branch 攜帶了 SKILL.md 完全沒有的必要材料。

**提議：**
> **Bold terms** are defined in [`GLOSSARY.md`](GLOSSARY.md). Look up single terms while authoring; read the file end to end before diagnosing a skill that misbehaves or auditing one for pruning.

---

## B8 [MEDIUM] 這一節唯一要產出的祈使句，放在按需檔而非常駐檔 — `SKILL.md:64`

祈使句只活在 on-demand 檔（`GLOSSARY:133`「Word a description with the leading words you actually use when you want the skill」，`GLOSSARY:63` 有回聲），而 SKILL.md 只承載它的**理由**，且近乎逐字重複。SKILL.md 從頭到尾沒有陳述過那個祈使句。階層剛好倒置。

**提議：**
> It serves predictability twice. In the body it anchors _execution_: the agent reaches for the same behaviour every time the word appears. In the description it anchors _invocation_: word a description with the leading words you actually use when you want the skill — one that lives only in the skill's own vocabulary fires unreliably.

---

## B9 [MEDIUM] 假前提的第三處 — `GLOSSARY.md:27`

User-Invoked 條目：「A skill with its **description** stripped」「Because it has no description」。兩處都讀作「把欄位移除」，與 `SKILL.md:15` 矛盾，且對這個 tree 的 12 個 user-invoked skill 全部為假。

**這是作者要把 skill 轉成 user-invoked 時最可能打開的那一條。**

**提議：**
> A skill with its **description** withheld from the agent — invisible in the agent's index and invocable only by the human typing its name (user-_only_, where **model-invoked** is user-_and-agent_). Trades agent-discoverability for zero **context load**. Because the agent never sees it, no other skill can fire it.

---

## B10 [LOW] 同一機制在同一檔第四次陳述 — `GLOSSARY.md:57`

Router Skill：「It can only hint, never fire them: user-invoked skills have no **description**, so nothing but the human can reach them.」

因果子句是同一機制在一個檔案裡的第四次陳述（`:27`、`:57`、`:97`，並在 `:21` 反向），其歸屬地是三十行上方的 User-Invoked 條目；而 Router Skill 的開頭字就是「A **user-invoked** skill」，`GLOSSARY:7` 的粗體詞承諾已經讓它繼承該性質。同時它也是假前提的第四處。

**提議：** 縮為「It can only hint, never fire them.」

---

## B11 [LOW] 一個沒有判準的 hedge — `SKILL.md:33`

「Make it _checkable_ ... and, **where it matters**, _exhaustive_」——「where it matters」交給 agent 一個沒有測試方法的決定，而未解 hedge 的預設解法是跳過較難的那一半。替 review skill 寫 criterion 時，agent 判斷窮盡性「不重要」，交出「produce a change list」——正是這句自己舉出來當失敗範例的弱形式。

**提議：** 「where it matters」→「wherever the work sweeps a set」

---

## 被退回的 13 條（摘要，供對照）

| 類別 | 條數 | 統一退回理由 |
|---|---|---|
| duplication 群（axis glosses、sharpen-first、flat peer-set、sediment、"that tension is the whole decision"） | 5 | 全部**確認是 duplication**，但每條 10–15 字且兩份副本目前一致，沒有任何一次執行會分歧。維護漂移是所有 duplication 的通用成本，不是這一條造成的具體錯誤行為 |
| dangling bold（`**collapse**`、`**positive**`） | 2 | 窮盡檢查推翻：SKILL.md 有 11 個、GLOSSARY 有 12 個粗體詞沒有對應標題，多數明顯是強調或 bullet 起頭。粗體在此已是多義的，修兩處還原不了任何慣例 |
| 假前提的衍生子句（`GLOSSARY:45`、`:97`） | 2 | 正確但非獨立發現——它們不規定操作、不陳述規則，已折進 B2 當伴隨編輯 |
| no-op 判定過嚴 | 4 | 例如 `SKILL.md:17` 第二句不是純重述（它點出替代方案與其收益）；`SKILL.md:81` 的 no-op 範例是讓診斷 bullet 免查表的關鍵，是示範不是重述 |
