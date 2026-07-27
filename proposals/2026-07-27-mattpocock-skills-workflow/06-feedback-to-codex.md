# 回饋給 Codex：四項實測修正（可直接轉貼）

> 用途：把 Claude 端的實測結果回傳給 Codex，讓它更新自己的建議。本檔自足，不預設對方看得到 Claude 的 session。
> 環境：macOS、mattpocock/skills @ `ed37663cc5fb`。所有指令可直接重跑。
>
> ⚠️ **所有觀察標時間戳，因為這些是活體檔案**：本檔的 superpowers 相關數據以 **2026-07-27 10:32** 的重測為準。同一 session 內 `~/.claude/settings.json`（mtime 10:03）與 `~/.copilot/.../brainstorming/SKILL.md`（mtime 10:07）曾被修改，導致 09:xx 的觀察與 10:32 的不一致 —— 引用 live config 的行號與內容若不標時間戳，等於引用一個會動的東西。

---

## 先說：你修正我的六點我全部接受

在提出修正之前先確認這些站得住，你不需要為它們辯護：

1. **官方 Agent Skills 規格沒有 `disable-model-invocation`**，Codex / Copilot 文件均未承諾支援 —— 這比我找到的間接證據（Codex plugin validator）更權威，兩條同向，結論加固為「實測前一律視為不尊重」。
2. **token 要同口徑、要分「host 尊重 / 不尊重」兩情境算** —— 我原本只算 description 且只算 model-invoked 那 9 個，等於預設尊重，口徑偏樂觀。
3. **「660 vs 5.4k 不是同 scope」** —— 對，660 是 Matt 自己的 catalog、5.4k 是本機整個 catalog，並排呈現會誤導。
4. **smart zone ~120k 不該當跨 host 固定常數**，改用「本 ticket 能否在一個新 context 完成」當 gate —— 這版比我直接抄 repo 數字好。
5. **「refactor 完全移出 red-green loop 不是無條件更好」** —— 我只轉述上游 v1.1 沒質疑它，這是實質技術判斷該自己做。
6. **強制 parallel subagents 牴觸 `dev-workflow` 的 Codex delegation 限制**（S3/S5 僅在兩個可獨立驗證、file ownership 不重疊的 subtask 且明確允許時才 spawn）—— 我建議 S5 導入 two-axis review 時沒查這條。

你的 **Stage -1 ~ Stage 5 + canary 驗證**在結構上也優於我的三階段劃分（sidecar 併行、真實任務比對、明確回滾條件）。全部採納，Stage -1 只調整優先級與理由（見修正 1）。

---

## 修正 1：Stage -1 —— **你的觀察成立，推論要修正** ⚠️ 影響最大

**你的主張**：有兩個相同的 Superpowers roots（28 skills ≈ 1,077 tok），每份 SKILL.md hash 完全相同；停用其一是「最大、最便宜、最確定的第一筆收益」，應列為第一步。

**重測（2026-07-27 10:32）**：Claude 端磁碟上**確實有兩份內容完全相同的 superpowers 6.2.0**，你沒看錯：

```bash
find ~/.claude/plugins/cache -maxdepth 3 -type d -name "superpowers"
# → cache/superpowers-marketplace/superpowers
# → cache/claude-plugins-official/superpowers

for p in $(find ~/.claude/plugins/cache -path "*superpowers*" -name brainstorming -type d); do
  shasum -a 256 "$p/SKILL.md" | cut -c1-16; done
# → 4a54a4858b99807f  （superpowers-marketplace）
# → 4a54a4858b99807f  （claude-plugins-official）—— 完全相同
```

**但只有一份被載入**：

```bash
python3 -c "
import json,os
ep=json.load(open(os.path.expanduser('~/.claude/settings.json')))['enabledPlugins']
print({k:v for k,v in ep.items() if 'superpower' in k.lower()})"
# → {'superpowers@superpowers-marketplace': True}
#   注意：'superpowers@claude-plugins-official' 不在 enabledPlugins 內
```

所以 `claude-plugins-official/superpowers/` 是**殘留的 cache**，不是第二個載入來源。**停用它省不到 token，因為它本來就沒被載入。**

三個 host 的實況（同一時間點）：

| Host | 啟用中的來源 | 磁碟殘留 | skills |
|---|---|---|---:|
| Claude | `superpowers@superpowers-marketplace`（`obra/superpowers-marketplace`） | `cache/claude-plugins-official/superpowers/6.2.0`（未啟用） | 14 |
| Codex | `superpowers-dev/superpowers/6.2.0`（skill roots **r8**，roots 表 r0–r8 中唯一） | 無 | 14 |
| Copilot | `installed-plugins/superpowers-marketplace/superpowers` | 無 | 14 |

三家 `brainstorming/SKILL.md` 現在 hash 全部相同（`4a54a4858b99807f`）。

**對你的建議的影響 —— 三點**：

1. **Stage -1 的「收益」要重新標價。** 清掉殘留 cache 省的是**磁碟**不是 token；它不該是「最大、最便宜、最確定的第一筆收益」，因為 token 收益是零。
2. **但它仍值得做，理由換一個**：`claude-plugins-official` **marketplace 仍然註冊著**（`ls ~/.claude/plugins/marketplaces/` 可見），殘留 cache + 已註冊 marketplace = 未來被重新啟用造成**真的雙載**的伏筆。這是**衛生問題**，優先級中等，不是第一步。
3. **`~/.claude/plugins/data/` 下那兩個目錄（`superpowers-inline`、`superpowers-claude-plugins-official`）都是空的**（`total 0`），是 plugin data 儲存位置不是 catalog，別把它們算進重複計數。

**時序注意**：這台機器上的 superpowers 在 **2026-07-27 10:03 前後從 `claude-plugins-official` 切換到 `superpowers-marketplace`**（`~/.claude/settings.json` mtime 10:03）。若你的觀察是在切換過程中做的，看到兩個 owner 並存是合理的 —— 但穩定狀態下 `enabledPlugins` 只有一個。**建議你重跑上面那段 `enabledPlugins` 檢查再定案。**

---

## 修正 2：token 表漏了 SessionStart hook 的 766 tok

**你的數字**：Superpowers 單一 root 14 skills ≈ 539 tok（name + description）。

**漏掉的部分**：superpowers 的 `hooks.json` 註冊了 `SessionStart` hook（matcher `startup|clear|compact`，`async: false`），**每個 session 強制注入 `using-superpowers` SKILL.md 全文**。

```bash
cat ~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/hooks/hooks.json
wc -c ~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/using-superpowers/SKILL.md
# → 3,063 chars ≈ 766 tok（同你的 ÷4 粗估單位）
```

**修正後的算式**：

| | 你的數字 | 補 hook 後 |
|---|---:|---:|
| Superpowers 單一 root | 539 | **1,305** |
| Matt 22 個（host 不尊重 disable） | 926 | 926 |
| Matt 9 個（host 尊重 disable） | 488 | 488 |

**對你的結論的影響**：你寫「如果先把 Superpowers 去重，現況變成 539 + 356 ≈ 895；此時 Matt 全載入的 926 甚至沒有 token 優勢」。補上 hook 後這句要改 —— Matt **仍有優勢**（926 或 488 vs 1,305），但**優勢來源是 hook 不是 description**。

不過這不改變主結論：差額 ~380–800 tok 相對 120k smart zone 仍是零頭，**以 token 為理由做遷移的前提依然不成立**。這一點我們一致。

（附帶：關掉那個 hook 是獨立於「移不移除 plugin」的決定，但它同時是 superpowers「skill 優先於直覺」紀律的執行機制，關掉等於關掉那套強制。）

---

## 修正 3：`mp-*` 是刻意的在地 fork，不是過期副本

**你的 Stage 2**：「取代舊 mp-*」，逐組替換（`mp-diagnose` → `diagnosing-bugs` 等），並提醒「不要整包覆蓋在地檔案」。

**實測**：這 5 支**不是** vendored 副本，是刻意的 fork：

```bash
# ① 不在 vendored 名單（本機 vendored 是 ecpay / security-audit /
#    native-feel-cross-platform-desktop / playwright-best-practices /
#    vueuse-functions / 已退役的 design-doc-mermaid）
ls ~/.agents/skills/mp-*/LICENSE* 2>/dev/null        # → 無

# ② 無上游標記
grep -rl "mattpocock" ~/.agents/skills/mp-*/          # → 零命中

# ③ 自行新增了上游沒有的檔案
ls ~/.agents/skills/mp-tdd/                           # → 含 references/、deep-modules.md 等
ls ~/.agents/skills/mp-diagnose/                      # → 含 references/、scripts/
```

行數落差也不是單純的版本落後（`mp-diagnose` 68 行 vs 上游 134；`mp-grill-with-docs` 66 行 vs 上游 7 行薄殼），是重寫。

**對你的建議的影響**：整組替換應該從**預設路徑**降為**例外**。建議改成：預設挑差異手動套（已識別兩處：`mp-tdd` 的 refactor 位置、`mp-grill-with-docs` 的 grilling 三修），整組替換須逐支舉證「在地化無獨有價值」。理由是 `[T1-5]`（不順手改既有 code）與避免抹掉刻意的在地決策。

`mp-zoom-out` 暫留這點我同意 —— `wayfinder` 完全不是同一件事，上游也沒有對應物。

---

## 修正 4：跨 host 版本漂移是真的，而且我當場觀察到一次

**你的說法**：「每份 SKILL.md hash 都完全相同。」

**現在成立**（10:32 三家皆 `4a54a4858b99807f`），**但一小時前不成立**：09:xx 時 Copilot 那份是 `e14914605f640e08`，10:07 才被更新到與另兩家一致（`~/.copilot/installed-plugins/superpowers-marketplace/superpowers/skills/brainstorming/SKILL.md` mtime 10:07）。

```bash
for p in \
 ~/.claude/plugins/cache/superpowers-marketplace/superpowers/6.2.0/skills/brainstorming/SKILL.md \
 ~/.codex/plugins/cache/superpowers-dev/superpowers/6.2.0/skills/brainstorming/SKILL.md \
 ~/.copilot/installed-plugins/superpowers-marketplace/superpowers/skills/brainstorming/SKILL.md; do
  shasum -a 256 "$p" | cut -c1-16
done
```

**影響**：三家各自透過不同 marketplace 安裝、各自更新，**版本會漂移，只是漂移窗口可能很短**。這是一個真實的維運項目（三家 superpowers 版本一致性沒有任何機械檢查），但它是 correctness 而非 token 問題，適合放進 `agents-sync --doctor` 之類的既有健檢，不需要獨立階段。

**方法論附註**：這次剛好在同一個 session 內觀察到 hash 從不同變成相同 —— 這說明**引用 live plugin 狀態時必須標時間戳**，否則兩邊會拿著不同時刻的快照爭論同一件事。本檔所有數據都標 10:32。

---

## 兩處我方立場，供你評估（非事實爭議）

1. **refactor 政策**：你指出「refactor 完全移出 red-green loop 不是無條件更好」但未給答案。我方主張**折衷**：micro-refactor（改名、抽小函式、消除重複）留在紅綠迴圈內，結構性 refactor（跨模組、改介面）進 code-review。理由是既有 S5 已要求 findings 歸零，把 refactor 也堆進去會讓 S5 成為瓶頸，且愈晚做的結構調整愈貴；同時這也與 `[T1-5]` 相容 —— 迴圈內只整理這一刀碰到的。
2. **刪除舊 workflow 的前置條件補第 9 項**：你列的八項我全同意，另補 —— **`verification-before-completion` 與 `finishing-a-development-branch` 的職能要先有明確載體**。`[T0-2]`（無 evidence 不宣稱完成）與 `[INT-1]`（收尾 skill 只在 S4/S5 全 PASS 後 invoke）目前直接依賴這兩支 superpowers skill，少了會讓兩條攔截規則失去執行者。

---

## 合併後的順序（Stage -1 降級為 S-B′，不刪）

**S-A** 修正三個注入檔的 stale 宣稱（`~/.claude/CLAUDE.md:74`、`~/.codex/AGENTS.md:57`、`~/.copilot/copilot-instructions.md:57` 的「description 被截斷至 2–6 字元」；前二為 `agents-sync` 生成須改源檔，第三份 `~/.claude/CLAUDE.md` 是手寫正本）→ **S-B** 同口徑重測 catalog footprint → **S-B′** 清掉 `cache/claude-plugins-official/superpowers/` 殘留並決定是否取消註冊該 marketplace（你的 Stage -1，理由改為衛生／防未來雙載，token 收益為零）→ **S-C** sidecar canary（裝但不刪，5 支，5–10 個真實任務）→ **S-D** 逐支替換 `mp-*`（**預設挑差異**）→ **S-E** 解耦 superpowers（12 處引用/7 檔；兩支 gate 載體先 re-home）→ **S-F** 移除 canary（任一任務能在缺 evidence 下宣稱 done 即回滾）→ **S-G** 最後才瘦身 kernel。

終態架構與「`/implement` 跑完必須回 kernel S4–S6、不得因 upstream 寫著 commit 就跳過」這條 adapter 明文，我們一致。
