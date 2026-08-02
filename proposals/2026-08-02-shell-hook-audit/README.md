# Shell 腳本失敗模式與 hook exit code 語意稽核

2026-08-02。範圍：`bin/`、`tests/`、`hooks/`、`skills/**` 共 59 支 shell 腳本，
外加三份 host-local guard 副本。`attic/**` 為 CONVENTIONS 規則 11 的退役物，不在範圍。

**結論：沒有找到第二個 live fail-open。** 三項稽核 70 個 probe case 全數通過。
產出主要是機制知識與六條 follow-up，不是缺陷清單。

## 為何做這次稽核

PR #26 修掉一個 PreToolUse hook 的 fail-open：`protect-files.sh` 的
`hook_block "…：$f（…"` 因 `$var` 緊接非 ASCII 而在 `hook_block` 執行前就 abort，
hook 回 `exit 1` 而非代表 deny 的 `exit 2`，敏感檔案保護形同虛設。

它不是被測試抓到的，是被 `bin/ci-local` 一個「PASS 也印輸出」的小改動偶然帶出來的。
四層防線（shellcheck、執行路徑、ci-local、第一版守護）全部漏掉。這次稽核回答：
**同一類「阻擋路徑其實走不到」的缺陷，還有沒有第二個。**

## 方法

組織軸是**可達性**，不是風格一致性——#26 的教訓是同一個語法在 `tests/agents-branch.sh`
只是難看，在 `protect-files.sh` 就是安全漏洞，差別只在它坐在 deny 路徑上。

三條紀律，每一條在本次稽核中都真的擋下了一個錯誤結論：

1. **跑，不是讀。** 構造 deny 輸入、斷言實際 exit code 與輸出。
2. **每個結果都要有 positive control。** 差點產出一條假的安全 finding，見 §1.4。
3. **契約先於判斷。** exit code 不一致可能是不同 host 契約，先找契約寫在哪。
   稽核初期我正是跳過這步而誤報，見 §1.1。

---

## 1. Hook deny 路徑可達性 — 完成，0 finding

### 1.1 `guard-git-push.sh`（[T0-3] 執行者）

契約寫在檔頭「輸出契約依 host 分流」段（L15–17），不是靠推論：

```
claude — {"decision":"block"} → stderr，exit 2
codex  — {"hookSpecificOutput":{…permissionDecision:"deny"}} → stdout，exit 0
```

**codex 的 deny 就是 exit 0**，deny 資訊在 stdout JSON。稽核初期我用 exit code 判斷
codex 格式，得到「force push main 竟然 exit 0」的假警報——套錯契約。

**更關鍵的方法錯誤：一開始驗錯了對象。** `bin/hook-parity-check` 檔頭 L12–15 明載
「`~/.agents/hooks/` 底下的檔沒有任何 host 會執行」——三份是實體副本，各 host 跑
自己那份，沒有部署機制同步。驗正本不等於驗執行對象。

當前三份 sha256 一致（`3706b2b5c17d`），`hook-parity-check --strict` 回 0，所以結論
不受影響。但證據已補成直接對執行對象取得：

| 對象 | 結果 |
|---|---|
| `~/.agents/hooks/guard-git-push.sh`（正本，無 host 執行） | 16 PASS / 0 FAIL |
| `~/.claude/hooks/guard-git-push.sh`（Claude 實際執行） | 16 PASS / 0 FAIL |
| `~/.codex/hooks/guard-git-push.sh`（Codex 實際執行） | 16 PASS / 0 FAIL |

執行鏈也已確認：`~/.codex/hooks.json` 註冊 `guard-codex-git-push.sh`，後者
`exec bash "$(dirname "$0")/guard-git-push.sh" --format=codex` 指向同目錄副本；
`~/.claude/settings.json` 直接註冊 `~/.claude/hooks/guard-git-push.sh`。

case 涵蓋 deny（`--force` main／feature、`--force-with-lease` main、`--force-with-lease --all`）
與 positive control（一般 push、`push origin main`、`git status`、非保護分支的 lease force），
兩種 format 各 8 條。

**最強的 positive control 是意外得到的**：第一版探針寫成 inline 指令，被 live
PreToolUse guard 當場擋下——

```
{"decision":"block","reason":"[T0-3] 禁用非 lease force push（--force / -f / +refspec）。"}
```

guard 檔頭「已知且刻意的誤擋」段（L19 起）預告了這件事：比對對象是整個 command 字串，連
「只是提到」危險 payload 的指令也會被擋，且明文禁止為消除誤擋去解析 shell 語法
（false negative 對安全閘的代價遠高於 false positive）。正解是把文字移出 command
字串——探針因此寫成獨立檔案。

### 1.2 `guard-codex-git-push.sh` — 排除嫌疑

初看可疑：59 支腳本中僅 4 支無 `set`，它是其一，且完全沒有 `exit`，卻是 [T0-3]
執行者。實際全文 4 行，是 `exec` wrapper——`exec` 立刻取代 process，exit code 由
本尊決定，所以無 `set`、無 `exit` 都正確。已實測 `exec` 如實傳遞 exit 2。

### 1.3 `protect-files.sh`（#26 的修復對象）

修復後 15 cases 全 PASS：四種 host 情境（claude／codex／copilot／unknown）的 `.env`
都 `exit 2` 且有理由輸出；六個 pattern 都攔得到；五個一般檔案都放行。

稽核前假設 `HOOK_HOST=unknown` 可能沒有對應分支而 fail open。**假設被推翻**：
`case` 有 `*)` 預設分支且同樣 `exit 2`。probe 額外斷言 deny 時必須有理由輸出，
否則 host 收得到否決卻拿不到原因。

### 1.4 `pre-commit-agents.sh`

契約不同：這是 **git pre-commit hook**，exit 非 0 即阻擋，與 PreToolUse 的 `exit 2`
是兩套系統。`guard-git-push.sh` 用 2、本檔用 1 因此**不是不一致**。

`.bak` 阻擋 5 條全 PASS；positive control 特意含 `backup_plan.md`、`bakery.md`
（名字含 bak/backup 但不是 `.bak` 檔，必須放行），否則「全部 block」不具鑑別力。

gitleaks 接線改用 PATH 注入假 binary 驗四條分支：exit 1／2 → block，exit 0 → allow，
binary 缺席 → allow（檔頭 L24 明文：只警告，擋 `.bak` 仍生效）。

**一個差點成立的假 finding：** 第一版用真 secret fixture（AWS 官方文件的
`AKIAIOSFODNN7EXAMPLE`），hook 沒擋，看起來像漏接。實際是那組值在 gitleaks default
config 的 allowlist 內——fixture 無效，不是 hook 有問題。沒有 positive control 的話，
這份報告會多一條假的安全 finding。

---

## 2. `exit 0` 吞掉失敗的機制 — 完成，機制查明

#26 留下的未結案：`tests/agents-branch.sh` 有斷言真的失敗（走進 `*)` 分支），卻回
`exit 0`。當時 minimal repro 回 `exit 1`，機制不明。窮舉情境（bash 3.2.57）：

| 情境 | exit |
|---|---|
| `set -u` 壞展開在 top-level | 1（中止）|
| 壞展開在 function 內 | 1（中止）|
| 壞展開在 `case` body | 1（中止）|
| **壞展開在 subshell `( )`** | **0（繼續）** |
| **壞展開在命令替換 `$( )`** | **0（繼續）** |
| 壞展開 + `trap EXIT` | 1（trap 無影響）|
| **無 `pipefail`：pipeline 中段失敗** | **0** |
| 有 `pipefail`：同上 | 1 |
| **`set -eu` + 無 `pipefail`：pipeline 中段失敗** | **0** |

兩個結論：

1. **`tests/agents-branch.sh:45` 是 `out=$(run_done …)`——命令替換。** 這就是失敗被
   吞掉的機制。S5 Spec 軸推測是 `trap` 覆蓋 abort status，重驗**不成立**。
2. **`set -e` 對 pipeline 中段失敗無效**，除非同時有 `pipefail`。這是通則，不限本案。

### 補充：`$var` 緊接非 ASCII 是 locale-dependent 的

這件事 #26 的 commit message 與本報告初版都沒講。實測（bash 3.2.57）：

| locale | 行為 |
|---|---|
| `LC_ALL=C` | 不誤解析，缺陷不重現 |
| 未設 `LANG`／`LC_ALL` | 同 C，不重現 |
| `LC_ALL=en_US.UTF-8` | `unbound variable`，重現 |
| `LC_ALL=zh_TW.UTF-8` | 同上，重現 |

影響有兩面。好的一面：CI runner 若在 C locale 下跑，這類缺陷不會發作。壞的一面：
**開發機與 host 傳給 hook 的環境通常是 UTF-8**（本機 `LANG=en_US.UTF-8`），所以
它在真正會執行的地方會發作，卻可能在 CI 上靜默通過——`tests/conformance.sh` 的
語法守護不受 locale 影響，是目前唯一穩定的防線。

這也直接害到本次的回歸測試：第一版 protect 探針用 `env -i PATH HOME` 清環境，
連 locale 一起剝掉，於是對 #26 的缺陷完全是盲的。詳見下方「探針去向」。

`pipefail` 缺席分布：59 支中 12 支無（6× `set -u`、2× `set -uf`、4× 無 `set`）。
其中 4 支無 `set` 有三支是正確的（`exec` wrapper、被 `source` 的 library、
無 pipeline 的 hook）。

逐一檢視有 pipeline 的關鍵腳本後，**未發現失敗方向錯誤**：

- `hooks/guard-git-push.sh`：真正的 pipeline 只有 3 處（L62、L71、L126）。前兩處都在
  `if !` 條件或有 `|| CWD=""` 兜底，走 fail-closed。（初次以 `grep -cE '\|'` 計得 8 處
  是高估——`case` 的 pattern 分隔符被誤算，方法教訓記於此。）
- `bin/pr-review-gate`：每個 `gh api` 都有 `|| unavailable <reason>`，而
  `unavailable()` 內含 `exit 30`。分頁超限也擋（`has_next != false` → unavailable）。
  `STATE=PASS` 雖是 fallback，但抵達它必須通過前面所有 fail-closed 檢查。

---

## 3. exit code 契約與 hook-parity 覆蓋 — 完成

`tests/hook-parity.sh` 斷言的是**漂移偵測機制本身**（用 fixture 驗一致/漂移/缺失/
正本不存在四種情境下的 strict 回傳碼），不是「當前是否漂移」；後者由
`bin/hook-parity-check` 在 SessionStart 執行。兩者分工正確，不是缺口。

exit code 契約分三套，互不衝突：

| 系統 | block 語意 | 記載位置 |
|---|---|---|
| PreToolUse（Claude／Codex）| stderr + `exit 2` | `guard-git-push.sh` L15–17「輸出契約依 host 分流」|
| PreToolUse（Copilot）| stdout JSON + `exit 2` | `protect-files.sh` L26「依 host 發出否決訊號」|
| git pre-commit | 任何非 0 | **無明文**——見下 |

**第三套沒有寫下來。** `pre-commit-agents.sh` 檔頭只說「繞過（謹慎）：git commit
--no-verify」（L4），沒有一句話定義 exit code 語意；它靠的是 git 的通用約定。稽核
初期我引用 L4 當作契約出處，是錯的——那行講的是繞過方式不是契約。前兩套都有明文，
只有這套沒有，對讀者是不對稱的。列為 follow-up 5。

---

## Follow-up（本次稽核不實作）

1. **`tests/version-tripwire.sh` 的 `SCAN_DIR=skills` 讓 `hooks/`、`bin/`、`.github/`
   都不在版本絆線守備範圍。** 具體暴露：`pre-commit-agents.sh` 用
   `gitleaks protect --staged`，CI 用 `gitleaks git --staged`。實測 8.30.1 下 `protect`
   仍可用且無棄用訊息，**現在不是缺陷**；但它是上游舊介面，移除時沒有任何守護會提醒。
   擴大 `SCAN_DIR` 會讓 45 條 pattern 套到 `attic/ecpay/`，幾乎確定炸假陽性——
   需要的是排除清單設計，不是順手改。

2. **12 支腳本無 `pipefail`。** 本次未發現失敗方向錯誤，但那是逐一檢視得到的結論，
   沒有機械守護。新腳本加入時不會有人提醒。可考慮在 `tests/conformance.sh` 加一條
   「有 pipeline 的腳本必須有 pipefail」，但需先處理既有的 12 支。

3. **命令替換／subshell 內的 `set -u` 失敗會被吞掉**，這是 bash 語意不是缺陷，
   但 `tests/agents-branch.sh` 的斷言正是這樣被偽裝成綠燈的。可考慮在該類測試腳本
   收尾加 `[ "$pass" -gt 0 ]` 這類「至少跑到了」的自證斷言。

4. **Claude host-local 另有兩個未稽核的 hook**：`~/.claude/hooks/audit-bash.sh`、
   `~/.claude/hooks/guard-cookbook-orphan.sh`。它們不在 `~/.agents` repo 內，屬
   host-local 設定，本次範圍外。

5. **git pre-commit 的 exit code 契約沒有明文。** 另兩套 PreToolUse 契約都寫在各自
   檔頭，只有這套靠 git 的通用約定。`hooks/pre-commit-agents.sh` 檔頭補一行即可。

6. **CI 的 locale 未固定。** 承上「locale-dependent」一節：`ci.yml` 沒有設
   `LANG`／`LC_ALL`，runner 預設值變動會改變這類缺陷會不會在 CI 發作。要嘛明確
   釘一個 UTF-8 locale（讓 CI 與開發機一致），要嘛明確記載「CI 在 C locale，這類
   缺陷靠語法守護不靠行為測試」。目前是沒有立場，最糟的一種。

## 探針去向

兩支已納入回歸（本 commit）：

```
tests/guard-push-reachability.sh      48 cases（16 × repo 正本 + 兩份 host 副本）
tests/protect-files-reachability.sh   40 cases（20 × 兩種 locale）
```

其餘三支留在 session scratchpad，未入庫：`precommit-probe.sh`（10 cases）、
`precommit-gitleaks-probe.sh`（4 cases，PATH 注入法）、`setu-exit-probe.sh`（14 情境）。
它們驗到的行為多半已由既有測試涵蓋，或屬一次性的機制釐清。

### 移植過程中被 review 抓到的兩個缺陷

**1. 第一版 protect 測試對它存在的目的完全是盲的。** 用 `env -i PATH HOME` 清環境時
把 `LANG`／`LC_ALL` 一起剝掉，於是整支跑在 C locale 下。把 #26 的缺陷原樣放回去，
測試仍然 15 PASS。修正後兩種 locale 都跑，同一個缺陷版本變成 25 PASS / 15 FAIL。

**2. 兩支都有 mktemp 失敗即靜默全綠的路徑**（`out=$(mktemp) || return 1` 讓 probe
提前返回而不計數，最終印 0 PASS / 0 FAIL 卻 exit 0）。已加「至少跑到了」自證斷言。
一支為 fail-open 而寫的回歸測試自己 fail-open，正是 Follow-up 3 記的形狀。
