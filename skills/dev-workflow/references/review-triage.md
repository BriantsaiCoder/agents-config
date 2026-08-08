<!-- tier: workflow | consumed-by: claude,codex,copilot | generated-from: proposals/2026-07-07-three-host-unification/03-workflow-layer.md | last-verified: 2026-08-04 -->

# review-triage — bot-review triage 合併規格

> S6 CLOSEOUT 的 Bot-review triage 引用本檔。合併兩條實戰教訓：異步等待（勿把延遲誤判為「無」）＋ thread-aware 逐條處理。
> 讀者是 AI 模型。squash merge 前 MUST 走完本檔全流程，四態皆 PASS 才允許 merge。

## 為何存在（不讀就會踩的雷）

- 綠 CI（`gh pr checks`）是**必要非充分**條件。bot review 是 `COMMENTED` / non-blocking state，**不計入** `gh pr checks`——只看 CI 綠燈就 merge 會整批漏接 findings（PR #34 因此漏 8 條）。
- Copilot review **異步產出**：開 PR 後通常 2–3 分鐘才提交。開 PR 當下查 `reviews` 為空是**延遲不是「無」**，據此斷言「此 repo 無 bot review」屬誤判。
- **Suppressed comments 不產生 thread，也不計入 `unresolved`**：Copilot 會把部分 finding 收進 review body 的 `Suppressed comments (N)` 摺疊區。那些不是 review thread，`pr-review-gate` 的 `unresolved` 看不到它們，於是 `STATE=PASS` 與「沒有 finding」不是同一件事。2026-08-08 一輪跨四 repo 的守衛修正實測：六條 finding 有四條在該區塊，gate 在同一輪回過三次 `PASS`，每次都有未修的 fail-open（agents-config #71、dotclaude #23）。
- bot findings 是**子集不是全集**：改共用 / 高扇入函式的反模式時，bot 清單只覆蓋部分 caller（PR #36：Copilot 只點名 6 個 `ReadBig5File` 消費端中 4 個 deref-before-null，漏 2 個）。以 bot 清單為完整 = 收斂不全。

## G-TRIAGE 四態 gate

### ENTER
- S4 且 S5 兩者 EXIT 皆成立（[INT-1] 時機閘），PR 已開、準備 squash merge。

### ACTION

Current `head.sha` 的 CI 與 review 都是 whole-head gate；舊 head 的結果不得沿用。

1. **等待異步 review**
   - 優先以 reviewer slug `copilot-pull-request-reviewer` 判定 Copilot review 是否已提交。
   - 開 Ready PR 後保持 task active；每次 push 都使前次結果失效，跑 `~/.agents/bin/pr-review-gate <n>` 對 current HEAD 重查。repo ruleset 無法啟用 Review new pushes 時，helper 會用 REST 自動 request / re-request。
   - 首查為空 → **等 2–3 分鐘重查**，勿立即斷言「無 review」。重查仍空且已逾合理視窗才記為真無。
   - slug／API 不可用時 MUST 標 UNAVAILABLE 並附 probe 證據；不得把「無 review」或人工目視降級成 bot PASS。

2. **Bot unavailable 的 independent fallback**
   - 這是 manual evidence branch；`pr-review-gate` 保持 `UNAVAILABLE` 且不得替 fallback 回 PASS。
   - `STATE=REQUESTED`／`WAIT_REVIEW` 是 transient state，MUST NOT fallback；`FINDINGS`、`WAIT_CI`、`FAIL_CI`、`WAIT_READY` 也不得 fallback。
   - fallback 只適用於 bot reviewer capability／request 經合理等待與 retry 後仍為 `UNAVAILABLE`；`repo_probe_failed`、`pr_probe_failed`、`review_probe_failed`、`requested_reviewer_probe_failed`、head 無法確認、thread probe／pagination 不完整都不得 fallback。
   - fallback 前 MUST 獨立確認 open／ready／mergeable PR、current head 與 CI PASS，再由 independent read-only reviewer 審 current `head.sha` 的完整 diff；記錄 reviewer identity、SHA、findings 與處理結果，不得由 PR 作者自審頂替。
   - 每次 push 都使 bot 與 fallback review 失效；新 head 必須重跑 current-head CI 與獨立 review。
   - bot 狀態仍記 `UNAVAILABLE`，不得偽裝成 PASS；只有 fallback 的 current-head CI PASS、independent review PASS 且 0 未處理 actionable findings，整體 Review gate 才可 PASS。

3. **thread-aware 逐條讀**
   - 逐個 review thread / comment 讀，**不跳讀、不抽樣**。每條標一結論：
     - **actionable 且技術正確** → 自動修 → 依 S4 risk tier 驗證並記 exit code → push → 重新監控（推後 review 可能再產新 findings）→ resolve 該 thread。
     - **錯誤 / YAGNI / 不適用** → 附**技術理由**於 thread 回覆，不盲從。禁表演式同意、禁盲修。
   - 回饋依 S5 技術 triage：逐條採納或附 evidence pushback，不表演式同意。
   - **`suppressed` 非 0 時 MUST 讀 review body 的 `Suppressed comments` 區塊**，逐條與 thread 同等 triage。該區塊沒有 resolve 機制，處置寫在 PR comment 而非 thread；因此 gate 不能也不會替你判斷它是否處理完。

4. **子集自核（改共用 / 高扇入函式時 MUST）**
   - 把 bot findings 當**起點子集**，不當完整清單。
   - 另跑 `deps-check` 或 grep 枚舉該函式**全部 caller**，逐一核對反模式是否都已修（見 SKILL.md「動高扇入共用檔前先列依賴方」）。
   - 例：改 `ReadBig5File` 的 deref-before-null 時，枚舉 6 個消費端全查，不止 bot 點名的 4 個。

### EXIT
- Primary path：`pr-review-gate` 對 current PR head 回 PASS；latest Copilot review `commit_id == head.sha`、requested Copilot reviewer 已清除、unresolved Copilot review threads 為 0、CI 全綠。
- Fallback path：bot capability 的 `UNAVAILABLE` probe、current `head.sha` 的 CI PASS 與 independent read-only review PASS 均有 evidence，且 push 後已全部重跑。
- 兩條 path 都要求 PR 為 open／ready／mergeable。
- 0 條未處理 actionable findings：actionable 者全 resolved，pushback 者全附技術理由回覆並 resolve。
- `pr-review-gate` 輸出的 `suppressed=N` 若非 0，該 N 條均已讀過並各有處置（修正或附技術理由的 pushback），處置記錄在 PR comment。gate 不阻擋此項——suppressed 無 resolve 機制，拿它當 blocking 條件會永久死鎖——所以這條的驗證是人工的。
- 改共用函式時，`deps-check` / grep 全 caller 核對完成且無殘留反模式。

### FAILURE
- finding 是 bug → 回 S3；由 [INT-2] 決定 RED 或同一 repro before／after，修完重走本 gate。
- 未等異步 review就 merge／在 transient state fallback／只看 CI 綠燈就 merge／以 bot 清單為完整 caller 集 → gate FAIL，撤回 merge 動作。
- 見 `suppressed=N`（N 非 0）卻未讀該區塊就 merge → gate FAIL。`STATE=PASS` 不是「沒有 finding」的證據，只是「沒有未解決的 thread」。

## 常用查詢

```bash
~/.agents/bin/pr-review-gate <n>                   # current HEAD 終態；必要時自動 request / re-request
gh pr checks <n>                                   # CI 綠燈（必要非充分）
gh api repos/{owner}/{repo}/pulls/<n>/comments     # 逐條 review comment（不含 suppressed）

# suppressed comments 的全文——不會出現在上面那支，也不計入 gate 的 unresolved
gh api repos/{owner}/{repo}/pulls/<n>/reviews \
  --jq '[.[] | select(.user.login | ascii_downcase | contains("copilot"))]
    | sort_by(.submitted_at) | last | .body' | sed -n '/Suppressed/,$p'
```
