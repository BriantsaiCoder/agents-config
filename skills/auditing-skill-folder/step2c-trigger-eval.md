# Step 2c — Trigger accuracy eval

只有執行 optional Step 2c 時才讀取本檔。

## 量測內容

Step 2 是 regex proxy。Step 2c 驗證 realistic prompt 是否真的 invoke target skill；只量測 invocation，不量測 output quality。

UNVERIFIED: current Claude CLI 是否依 runner 設定載入 supplied skills 與 built-ins。Collision arm 會將所有 supplied skills 提供給 `--plugin-dir`；`--isolate` 只提供 target。2026-08-01 probe 曾在兩個 arm 觀察到 built-ins。Isolate 通過而 collision 失敗時，修正 disambiguation。Isolate 中的 `FAIL no skill fired` 指向 description 問題；具名 built-in winner 仍屬 collision。

2026-08-01 的 historical evidence 載入 95 個 skills，並通過 6/6 documented routing-pair cases。五次執行中，第四次發現 OAuth session 過期；舊 guard 會把它誤判為 quiet case 通過，第五次在重新認證後通過。這些執行早於目前 scorer 變更，不是 current baseline。Scorer、parser、runner 或相關 description 變更後須重新量測。

## Run

```sh
scripts/eval-triggers.sh --runner claude                  # 所有 skills，含 collision pressure
scripts/eval-triggers.sh --runner claude --isolate        # isolate arm：只提供 target corpus
scripts/eval-triggers.sh --runner claude --max-cases 5    # 有上限的 iteration
scripts/eval-triggers.sh --runner mock                    # canned offline data
```

刻意不提供 default runner：Claude 會消耗 rate limit，mock output 也永遠不是 audit result。

| Signal | 意義 |
|---|---|
| `FAIL collision — won by X` | 另一個 skill 贏得 prompt。 |
| `FAIL no skill fired` | Target 未達 invocation threshold。 |
| `FAIL fired when it should not` | Trigger 過寬。 |
| `SKIP user-invoked only` | Frontmatter 刻意停用 model invocation。 |
| `ERR ...` | 未量測；不納入 recall 與 precision。 |
| `TRUNCATED` | Coverage 不完整；不得回報 full-suite result。 |

## Isolation 與成本

Runner flags 與附日期的 isolation rationale 位於 `evals/runners.json`。UNVERIFIED: current Claude CLI isolation semantics；2026-08-01 probe 曾觀察到空的 `CLAUDE_CONFIG_DIR` 與 `--bare` 使 OAuth 失敗，且兩個 arm 都列出 built-ins。Current run 若出現具名 built-in winner，判為 collision。

每個 case 消耗一個 model turn。用 `jq -s length evals/cases.jsonl` 取得目前 case 數後編列預算，或使用 `--max-cases`。

## Claude-only 邊界

此 runner 只提供 Claude evidence。2026-08-01 Codex probe 未發現可指出 invoked skill 的 event，因此 Codex scorer 沒有 ground truth；Copilot invocation policy 也未量測。除非存在 host-specific observable，否則將這些 hosts 回報為 `UNAVAILABLE`。不得把 Claude pass 外推到其他 hosts。

## 新增 cases

在 `evals/cases.jsonl` 每列加入一個 JSON object：`{id, skill, prompt, expect: "fire"|"quiet", why}`。每個 `fire` case 都須搭配同一 description 所隱含的 `quiet` case。`tests/trigger-eval.sh` 會驗證 referenced skills 仍存在。
