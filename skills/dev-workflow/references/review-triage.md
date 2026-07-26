<!-- tier: workflow | consumed-by: claude,codex,copilot | generated-from: proposals/2026-07-07-three-host-unification/03-workflow-layer.md | last-verified: 2026-07-07 -->

# review-triage — bot-review triage 合併規格

> S6 CLOSEOUT 的 Bot-review triage 引用本檔。合併兩條實戰教訓：異步等待（勿把延遲誤判為「無」）＋ thread-aware 逐條處理。
> 讀者是 AI 模型。squash merge 前 MUST 走完本檔全流程，四態皆 PASS 才允許 merge。

## 為何存在（不讀就會踩的雷）

- 綠 CI（`gh pr checks`）是**必要非充分**條件。bot review 是 `COMMENTED` / non-blocking state，**不計入** `gh pr checks`——只看 CI 綠燈就 merge 會整批漏接 findings（PR #34 因此漏 8 條）。
- Copilot review **異步產出**：開 PR 後通常 2–3 分鐘才提交。開 PR 當下查 `reviews` 為空是**延遲不是「無」**，據此斷言「此 repo 無 bot review」屬誤判。
- bot findings 是**子集不是全集**：改共用 / 高扇入函式的反模式時，bot 清單只覆蓋部分 caller（PR #36：Copilot 只點名 6 個 `ReadBig5File` 消費端中 4 個 deref-before-null，漏 2 個）。以 bot 清單為完整 = 收斂不全。

## G-TRIAGE 四態 gate

### ENTER
- S4 且 S5 兩者 EXIT 皆成立（[INT-1] 時機閘），PR 已開、準備 squash merge。

### ACTION

1. **等待異步 review**
   - 優先以 reviewer slug `copilot-pull-request-reviewer` 判定 Copilot review 是否已提交。
   - 開 Ready PR 後保持 task active；每次 push 都使前次結果失效，跑 `~/.agents/bin/pr-review-gate <n>` 對 current HEAD 重查。repo ruleset 無法啟用 Review new pushes 時，helper 會用 REST 自動 request / re-request。
   - 首查為空 → **等 2–3 分鐘重查**，勿立即斷言「無 review」。重查仍空且已逾合理視窗才記為真無。
   - slug／API 不可用時 MUST 標 UNAVAILABLE 並附 probe 證據；不得把「無 review」或人工目視降級成 PASS。

2. **thread-aware 逐條讀**
   - 逐個 review thread / comment 讀，**不跳讀、不抽樣**。每條標一結論：
     - **actionable 且技術正確** → 自動修 → 驗證（build / test / lint exit 0）→ push → 重新監控（推後 review 可能再產新 findings）→ resolve 該 thread。
     - **錯誤 / YAGNI / 不適用** → 附**技術理由**於 thread 回覆，不盲從。禁表演式同意、禁盲修。
   - 回饋處理紀律接 `superpowers:receiving-code-review`（採納或有據 pushback）。

3. **子集自核（改共用 / 高扇入函式時 MUST）**
   - 把 bot findings 當**起點子集**，不當完整清單。
   - 另跑 `deps-check` 或 grep 枚舉該函式**全部 caller**，逐一核對反模式是否都已修（見 SKILL.md「動高扇入共用檔前先列依賴方」）。
   - 例：改 `ReadBig5File` 的 deref-before-null 時，枚舉 6 個消費端全查，不止 bot 點名的 4 個。

### EXIT
- `pr-review-gate` 對 current PR head 回 PASS：latest Copilot review `commit_id == head.sha`、requested Copilot reviewer 已清除、unresolved Copilot review threads 為 0、CI 全綠、PR 為 open / ready / mergeable。
- 0 條未處理 actionable findings：actionable 者全 resolved，pushback 者全附技術理由回覆並 resolve。
- 改共用函式時，`deps-check` / grep 全 caller 核對完成且無殘留反模式。

### FAILURE
- finding 是 bug → 回 S3 且**先寫紅測**（[INT-2]），修完重走本 gate。
- 未等異步 review 就 merge / 只看 CI 綠燈就 merge / 以 bot 清單為完整 caller 集 → gate FAIL，撤回 merge 動作。

## 常用查詢

```bash
~/.agents/bin/pr-review-gate <n>                   # current HEAD 終態；必要時自動 request / re-request
gh pr checks <n>                                   # CI 綠燈（必要非充分）
gh api repos/{owner}/{repo}/pulls/<n>/comments     # 逐條 review comment
```
