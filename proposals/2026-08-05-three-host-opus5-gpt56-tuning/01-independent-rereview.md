# 獨立複核 + 補審：Opus 5／GPT-5.6 三 host 調教

日期：2026-08-05 07:15｜審查者：Copilot CLI（claude-opus-5）｜對象：[00-report.md](00-report.md) 與其審查標的
定位：**不重寫**既有報告。複核其前提、補其自陳未涵蓋的三塊、提出它整份缺席的一類 finding。

> **狀態**：這是供 [02-adjudication.md](02-adjudication.md) 裁決的歷史 reviewer input。被後續裁決退回或未由
> host PR 落地的建議不得當成 current requirement；採取動作前必須重驗 live config。

## 複核結論

`00-report.md` 的 F1–F9 我獨立驗過關鍵前提，**成立**。特別是 F1：

```
~/.copilot/settings.json → "model": "claude-opus-5", "stayInAutopilot": true
```

本次審查由 Copilot CLI 自身執行，其 model identity 即 `claude-opus-5`——F1 為第一人稱證據，非推論。

**三家實際分布：2× Opus 5（Claude Code、Copilot CLI）+ 1× GPT-5.6（Codex）。**

這個事實比既有報告用它的方式更重要：它把「Anthropic 對 Opus 4.5+ overtriggering 的警告」從單一 host 議題升級為**三分之二表面積**的議題——而既有報告整份沒有這一類 finding。以下 N1、N2 即補此缺口。

---

## N1 — aggressive MUST 語言在 2/3 host 上製造 overtrigger（既有報告零覆蓋）

[Anthropic Prompting best practices：Tool use](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices#tool-use) 說明 Opus 4.5／4.6 若沿用為解決 undertrigger 而寫的 aggressive tool／skill 指令，可能改成 overtrigger；建議回到正常、正向的 trigger 語言。把這點外推到 Opus 5 是本報告的推論，後續裁決另行檢驗。

實測每 host 載入量：

| Host | 模型 | 常駐 MUST | + kernel | 合計 |
|---|---|---|---|---|
| Claude Code | **Opus 5** | 28 | 23 | **51** |
| Copilot CLI | **Opus 5** | 11 | 23 | **34** |
| Codex | GPT-5.6 | 11 | 23 | 34 |

Claude 側 51 個 MUST/MUST NOT 全數命中 Opus 5 的 over-responsiveness。這與既有報告的 F2 是**不同軸**：F2 談語意重複（同一規則講四遍），N1 談**語氣強度**（每一遍都用最高強度祈使句）。兩者相乘才是實際的保守偏誤。

**建議**：
- `tier0` 9 條 **保留 MUST**——真紅線，overtrigger 是可接受代價。
- `tier1`（12）／`tier2`（6）／kernel（23）**降為直述句**，語意一字不動。
  例：`[T1-5] 除非任務明確要求重構，MUST NOT 順手改既有 code 的格式、命名或註解`
  → `只改任務範圍內的 code；格式與命名沿用該檔既有風格。`
- 目標：51 → 9（Claude）、34 → 9（Copilot）。

### N1-a — 阻擋 N1 的真正障礙：測試把字面 `MUST` 寫死了（本次最關鍵發現）

初稿我把 N1 標為「純措辭變更、極低風險」。**這個宣稱是錯的，實測推翻**：

```bash
$ cd ~/.agents/tests && grep -nE "MUST" *.sh | grep -E "rg -q|has |rule_has|grep" | grep -v tier0-parity
29
   3 delegation-policy-parity.sh
   3 matt-thin-workflow.sh
  22 mattpocock-workflow.sh
   1 pr-path-gate.sh
```

**29 條測試斷言對 kernel 做字面 `MUST` 比對**，例如：

```bash
matt-thin-workflow.sh:277   rg -q '\[INT-7\].*disable-model-invocation.*MUST NOT.*自動 invoke' "$KERNEL"
matt-thin-workflow.sh:384   rg -q 'MUST NOT 放鬆.*(MUST|無條件約束)'
mattpocock-workflow.sh:144  rule_has INT-3 'Medium-risk.*MUST NOT.*第二次確認|MUST NOT.*Medium-risk.*第二次確認'
mattpocock-workflow.sh:167  rule_has S5-1 'MUST.*觸發：.*例外：.*驗證：'
```

`tier0-parity.sh` 另以 `grep -i -F` 比對完整 clause（含 `MUST NOT 無 evidence 宣稱 done`），但 N1 保留 tier0 的 MUST，該檔不受影響。

**這是「為什麼會綁手綁腳」的結構性答案，兩份報告都沒抓到**：

> 每一條加上 MUST 的規則都會被補一條測試斷言 → 該措辭從此不可逆 →
> 語氣只能單向變強，永遠無法依官方建議調弱 → **ratchet（棘輪）**。

既有報告的 F2（語意重複）談的是同一件事在**空間**上擴散；N1-a 談的是它在**時間**上鎖死。不解 N1-a，往後每次審查都只能砍字數（PR #52–#55 正是如此），碰不到語氣。

**修正後的評估**：N1 不是極低風險，是 **Medium**——kernel／tier1／tier2 措辭與 29 條斷言必須**同一個 PR 內協同修改**，否則 CI 紅。

**修正後的建議**：測試斷言改為比對**語意錨點**而非強度詞。
```bash
# 現行（鎖死語氣）
rule_has INT-3 'Medium-risk.*MUST NOT.*第二次確認'
# 建議（只鎖語意）
rule_has INT-3 'Medium-risk.*(MUST NOT|不得|不會|非).*第二次確認'
```
先改測試放寬比對（獨立 PR，零行為變更），再改措辭。兩段式落地，任一段可單獨 revert。

---

## N2 — 11 個 skill description 帶反-undertrigger 句，在 Opus 5 上反轉為 overtrigger

既有報告把「71 個 skill 的 routing 表是否過載」列入未涵蓋，理由是 08-01／08-02 已各審一次。但那兩次審查早於 F1 確立「Copilot 也是 Opus 5」，且審的是 routing 表，不是 **description 的觸發語氣**。

實測：71 個 skill description 常駐 24,466 chars（median 347、max 586），其中 **11 個**帶明確的反-undertrigger 句：

```
Apply even when user just says "add a test for X", "run the tests", "this test is flaky",
"benchmark this method", or "we need integration tests".        ← dotnet-testing-best-practices

Apply even when user just says "containerize this app", "make the image smaller" ...  ← containerization
Apply even when user just says "add a Dapper query" ...                              ← dapper-best-practices
Apply even when user just says "add login", "protect this endpoint" ...              ← auth-implementation-patterns
```

這些句子是為了**修 undertriggering** 而寫的——正是官方點名「these models may now overtrigger」的那一類。在 Opus 5 上，使用者說「跑一下測試」就可能拉進整份 `dotnet-testing-best-practices`，這**就是綁手綁腳的直接機制**：不是規則擋你，是無關程序被載進來改變了行為。

**建議**：
1. 對這 11 個 skill 刪除 `Apply even when...` 句（保留 `Use when...`——官方認可的正向形式，71 個全部已採用，這點是對的）。
2. 借 `auditing-skill-folder` 跑一輪，把 description 壓到 ≤200 chars。24,466 → ~14,000，省約 2.6K tokens/turn。
3. 刪除後**必須跑 trigger canary**（kernel S4 已要求 model-invoked skill 跑 positive/negative canary），確認沒有掉回 undertrigger。這是唯一有回歸風險的一項。

---

## N3 — Codex `AGENTS.md` §Current documentation 與 kernel S0 ROUTE 重複（補既有報告未涵蓋 #1）

逐條掃 `~/.codex/AGENTS.md`（4476B）對照 GPT-5.6 的 single-owner／no-duplication guidance，只找到**一處**跨檔重複：

| 位置 | 內容 |
|---|---|
| `AGENTS.md:42` | `Microsoft／Azure／.NET：concepts → microsoft-docs；API／SDK → microsoft-code-reference。Third-party → provider-native；absent／UNAVAILABLE 才 context7-mcp` |
| `dev-workflow SKILL.md:54-55` | 同語意兩列 |

而 `~/.copilot/copilot-instructions.md` 對文件路由 **0 次提及**，完全依賴 kernel——**Copilot 才是正確形狀，Codex 是離群值**。

`AGENTS.md:42` 只有兩處是 host-unique：`OpenAI／Codex → openai-docs`，與末句負向觸發條件（`Refactor／new script／business-logic debug／review／general concept 不觸發`）。

**建議**：`AGENTS.md:42` 縮為一行，只留 host-unique 部分：
```
OpenAI／Codex 文件 → `openai-docs`；其餘文件路由見 kernel S0。
```
省 ~330B，且 `AGENTS.md` 無 byte gate 壓力（Copilot 的 54B headroom 問題不適用）。

其餘條文（優先序鏈、tier0 九條、adapter 五點）逐條檢查後**無跨檔重複**——`AGENTS.md:23` 明文寫「本檔不重複」，實際執行到位。這一項既有報告的擔心可以結案。

---

## 對既有報告的一點修正：F9 的「不構成能力損失」低估了

F9 量到 Copilot 常駐 62k tokens/呼叫，判定「Opus 5 有 1M context，62k 佔 6%，不構成能力損失；代價在 credits 與 latency」。

**context 佔比的算術正確，但結論漏了 adherence 這一項。** [Claude Code memory guidance](https://code.claude.com/docs/en/memory) 以 200 行作為每份 `CLAUDE.md` 的建議上限，理由同時包含 context 與 instruction adherence；[OpenAI lean-prompt guidance](https://developers.openai.com/api/docs/guides/latest-model#favor-leaner-prompts) 也記錄過精簡重複 prompt 後 eval、token 與成本同時改善的 internal coding-agent sample，並要求用自己的 representative eval 驗證。

也就是說 62k 不是純粹的 credits／latency 成本，它同時稀釋每一條規則的遵循率——包含 tier0 那 9 條你**最想要被遵循**的。這反過來說明 N1／N2 的瘦身不只是省錢：它讓紅線更被聽見。

F9 的量測本身很有價值（三家唯一的硬數字基線），建議保留作為 N2 的 before/after 量尺。

---

## 合併後的優先序

既有報告的 F1–F9 與本文 N1–N3 正交，可合併排程：

| 序 | 項目 | 來源 | 風險 | 預期效果 |
|---|---|---|---|---|
| 1 | **N1-a 測試斷言改語意錨點**（29 條） | 本文 | 低（零行為變更） | 解鎖 ratchet，是 N1 的前置 |
| 2 | **N1 語氣降級**（MUST 51→9） | 本文 | 中（需 N1-a 先行） | 直接解 Opus 5 過度保守 |
| 3 | **F2 核准語意收斂**（保留 autopilot 條款） | 00-report | 低 | 解「不必要的核准暫停」 |
| 4 | **N2 skill description 瘦身 + canary** | 本文 | 中（需 canary） | 解無關 skill 誤觸發 |
| 5 | **F3 ledger 依 risk tier 分級** | 00-report | 低 | 解低風險路徑的 16 欄 scaffolding |
| 6 | **N3 Codex 文件路由去重** | 本文 | 極低 | −330B |
| 7 | **F5 dev-certs 對撞** | 00-report | 極低 | 消死條文 |
| — | F4 effort sweep、F7 memory 修正 | 00-report | — | 量測／紀錄，不進 PR |

**N1-a 排第一**：它是唯一的結構性解鎖項，零行為變更、可獨立 revert，且不做它 N1 就做不了。做完 N1-a 之後 N1／F2 都變成單純的措辭工作。

## 落地

全部落在 `[INT-10]` 範圍 → isolated branch → Ready PR → bot-review gate → squash merge。
建議切 PR：`agents-tests`（N1-a，先行）／`agents-config`（N1 kernel + F2 + F3 + N2）／`dotclaude`（N1 tier1/tier2 + F5）／`dotcodex`（N3）。

**rollback**：全為設定／測試文字變更，`git revert` 單一 squash commit 即回原狀；N1-a 與 N1 分屬兩 PR，可獨立回退；N2 若 canary 掉回 undertrigger，單獨 revert description 變更即可。

## 未涵蓋

- kernel S0 ROUTE 26 列本身是否過載——與 N2 相鄰但未量測。
- Claude Code 側常駐 context 基線（無等價 log 管道，F9 已註記）。
- N1-a 的 29 條斷言逐條改寫方案——本文只給模式，未逐條produce diff。
