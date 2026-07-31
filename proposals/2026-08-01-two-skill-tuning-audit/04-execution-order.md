# 建議執行順序與落地程序

18 條發現全部未修。以下是建議順序、每條的落地成本、以及 `writing-great-skills` 這一組必須走的 override 程序。

---

## 落地程序：兩組不同

### 組一：`auditing-skill-folder`（A1–A7）— 直接改

自有 skill。改動需要：
- 若碰 `SKILL.md` / `step0-vendored-gate.md` / `scripts/check-vendored.sh` / `scripts/lib-vendored.sh` / `scripts/lint-descriptions.sh` 以外的檔（例如 `references/skill-standards.md`、`step1-verdict-guide.md`、`step7-style-checks.md`、`scripts/count-words.sh`），需在 `tests/matt-thin-workflow.sh` 的 allowlist 補登記
- 跑全套件 + `shellcheck -S error hooks/*.sh tests/*.sh bin/...`

### 組二：`writing-great-skills`（B1–B11）— 需要新的 fork 決策

現有 fork 記錄的範圍是 **"model invocation metadata only"**，且明寫 *do not extend it*。

- **B3（frontmatter description）落在現有範圍內** —— 它就是 invocation metadata。可在現有 record 上加註修訂，不需開新決策。
- **B1、B2、B4–B11 全部動到 body，超出現有範圍** —— 需要**新的**登記決策：

1. 對 pinned commit `ed37663cc5fbef691ddfecd080dff42f7e7e350d` 做 diff
2. 在 `vendored-forks.md` 的 `<!-- fork-index:begin/end -->` 區塊內，為 `writing-great-skills` 那一列增補或新增一列，寫明本次 local change
3. 在該檔 `## writing-great-skills` 段落加一條註明日期的決策，並更新 re-merge procedure（目前第 2 步只講「reapply only the frontmatter description, invocation flag removal, and Codex implicit policy」——body 改動落地後必須改寫這句，否則下次 re-merge 會靜默丟掉 B1/B2）
4. 重算 tree SHA-256（現值 `6d00cd49dd5038656fc226c1b81ed09915f8fc26047a00f0bc1aa386fdb7325b`）與 `invocation_manifest_sha256`
5. 跑 `tests/matt-thin-workflow.sh`、`tests/mattpocock-workflow.sh`、`tests/host-skill-resolver.sh`、`tests/vendored-detection.sh`

> **值得先確認的一件事：** B2（GLOSSARY:33 的「delete it」）是**上游的**缺陷，不是家規改壞的。修它等於永久 fork 一段 Matt 的原文。替代路徑是先向上游回報，若上游接受就靠 wholesale replacement 拿回來、完全不必 fork。B3 則相反——那段文字是家規自己在 commit `04d273b` 寫的，上游不知情，回報上游沒有意義。

---

## 建議順序

### 第一批：機械層，修了立刻有守衛

| # | 項目 | 為什麼先做 | 落地成本 |
|---|---|---|---|
| 1 | **A1** `count-words.sh` 加字元欄 | Step 1 是整個協定的第一道機械閘，現在對全部 5 個中文 skill 形同失效。加欄不換算法，英文行為 byte-identical | 中。需 allowlist 登記 + 新測試（比照 `tests/description-lint.sh` 的 fixture 手法，斷言中英文各自的門檻都會觸發） |
| 2 | **A2** 補文件化第五個訊號 | 54 個 VND 有 23 個目前用文件復現不出來；`aspnet-api-architect` 指向你自己的 repo 是最容易誤判的一個 | 低。純文件，`SKILL.md` 已在 allowlist，`step0-vendored-gate.md` 也已登記 |
| 3 | **A4** 死掉的兩個 tier | 與 A1 同一支腳本，一起改省一次驗證 | 低–中 |

### 第二批：`writing-great-skills` 的三條 HIGH

| # | 項目 | 為什麼 | 落地成本 |
|---|---|---|---|
| 4 | **B3** description | 落在現有 fork 範圍內，不需新決策。修完 Failure modes 那 13% 才可達，且 lint 從 `?` 變 `-` | 低 |
| 5 | **B2 + 伴隨編輯**（`GLOSSARY:33/45/97`、B9 `:27`、B10 `:57`） | 五處同一個假前提，必須同一 pass 一起改否則檔案以新方式自相矛盾。這是唯一一條會讓 agent 去刪必要 frontmatter 欄位的缺陷 | 高。需新 fork 決策；建議先評估回報上游 |
| 6 | **B1** 窮盡性門檻 | 它違反自己 doctrine 最直接的一次，且直接影響每次 invoke 的涵蓋範圍 | 高。需新 fork 決策 |

### 第三批：其餘

- **A3**（Technique/Pattern 無定義）、**A6**（路由少第二跳）、**A7**（無跨 skill collision step）——都是 `auditing-skill-folder`，可直接改，但 A7 是新增一整個 pass，工作量最大
- **A5**（owner/flag 對齊）——corpus 0 次發生，純硬化
- **B4–B8、B11**——`writing-great-skills` body，可與第 6 項併入同一次 fork 決策，省一次 SHA 重算與四支測試

---

## 三個一併處理更省的組合

1. **A1 + A4** 同一支 `count-words.sh`，一次 allowlist 登記、一次驗證。
2. **B2 + B9 + B10 + B4** 全是同一個「description 被刪掉」假前提的不同站點（`GLOSSARY:21/27/33/45/57/97` 六處），分開改必然漏。
3. **B1 + B4–B8 + B11** 全是 body 編輯，併成一次 fork 決策比分六次划算——尤其第 3、4 步（SHA 重算 + 四支測試）是固定成本。

---

## 已經做掉的（不在上述 18 條內）

| 項目 | 狀態 |
|---|---|
| 「flag gates execution, not assessment」規則 | 已寫入 `SKILL.md` Step 0 / Red Flags ×3 / Iron Law、`step0-vendored-gate.md` 兩新節、`check-vendored.sh` 輸出 |
| override 路徑文件化（原本 gate 只說「不行」不說「怎樣才行」） | 已寫入 `step0-vendored-gate.md` |
| `lint-descriptions.sh` zh-TW 分類 | 已上線，TRAP 側先落地，`tests/description-lint.sh` 22 cases 進 CI |

**副作用需留意：** 上述規則寫入讓 `auditing-skill-folder/SKILL.md` 從 661 → 908 words（limit 500）。它改動前就已 OVER，本次淨增 247。依 `step1-verdict-guide.md`，成因是「core principles + concepts，散文本來就密」→ 判定 Trim 而非 Externalize（程序細節已經 externalize 到 `step0-vendored-gate.md`）。這條與 A1 相關：字數超標的量測本身正是 A1 要修的那個。
