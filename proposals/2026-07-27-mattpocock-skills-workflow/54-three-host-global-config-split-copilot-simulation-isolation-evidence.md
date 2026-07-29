# Three-host global-config split — Copilot simulation `cache_path` isolation evidence

日期：2026-07-29
範圍：candidate-only amendment；live/plugin/canary維持zero-write

## 1. Authorization

使用者明示：

> 核准 candidate-only Copilot simulation cache_path isolation amendment 與 RED→GREEN 驗證；不授權 live cutover、plugin mutation或6-run canary。

本輪沒有執行native plugin uninstall、SaaS、remote、push、PR、merge或6-run canary。

## 2. Root cause

Copilot restore carrier的`config.json`含18個absolute `installedPlugins[*].cache_path`。設定scratch `COPILOT_HOME`只改config/state root，不會改寫embedded paths；先前看似isolated的native simulation因此沿carrier path操作live Superpowers cache，後續live uninstall才回報plugin已不在registry-backed cache，並觸發coordinated rollback。

Carrier config另為JSONC：有2行full-line `//` comments，直接交給`jq`會parse fail。

## 3. Before／after gate semantics

| Gate | Before | After |
|---|---|---|
| Isolation claim | scratch `COPILOT_HOME`即視為isolated | embedded path、physical directory與live before／after state三者都PASS才可claim isolated |
| Config parse | 假設strict JSON | 只移除full-line `//` comments；其他non-JSON syntax fail-closed |
| `cache_path` | carrier absolute path未改寫 | 每個exact live-home prefix改為simulation-home prefix |
| Cache payload | 只解target carrier | 所有registered cache payload都dereferenced copy到scratch；禁止symlink／absolute reference |
| Live invariant | 未獨立驗 | plugin exact selector count與target cache manifest前後empty diff |
| Failure | simulation結果可能誤判 | 任一path／parse／manifest gate `FAIL`／`UNAVAILABLE`立即停止；不得執行live uninstall |

## 4. RED

新增`tests/copilot-plugin-simulation-isolation.sh`後、implementation前：

```text
FAIL: missing executable helper: .../bin/copilot-plugin-simulation-config
exit 1
```

加入真實JSONC fixture、parser amendment前：

```text
jq: parse error: Invalid numeric literal at line 1, column 3
copilot-plugin-simulation-config: every installedPlugins[*].cache_path must begin with the exact live home
exit 1
```

## 5. Minimal amendment

- 新增`bin/copilot-plugin-simulation-config`：
  - 只接受`<simulation-home>/config.json`；
  - 拒絕simulation/live home相同或互相nested；
  - 只移除JSONC full-line comments後交給`jq`；
  - 要求所有source paths屬於exact live root；
  - atomic mode 0600 rewrite；
  - 要求所有rewritten physical directories位於simulation root，攔截symlink escape。
- 新增單一behavior test，fixture只在`mktemp -d`內模擬cache deletion。
- 修訂Plan 48 §H3、§13.2與unique next gate。

## 6. GREEN

Behavior test：

```text
COPILOT_SIMULATION_CACHE_PATHS_REWRITTEN=1
PASS: Copilot plugin simulation cache_path isolation
exit 0
```

Fresh carrier rehearsal只做read-only live source copy與candidate helper；沒有呼叫native uninstall：

```text
COPILOT_SIMULATION_CACHE_PATHS_REWRITTEN=18
CARRIER_REHEARSAL=PASS
REGISTERED_CACHE_COUNT=18
LIVE_INVENTORY_BEFORE=1
LIVE_INVENTORY_AFTER=1
LIVE_CACHE_MANIFEST_DIFF=EMPTY
exit 0
```

## 7. Risk／rollback

- Helper刻意只支援目前觀察到的full-line-comment JSONC；若Copilot改用inline comments、trailing commas或不同registry schema，結果為`UNAVAILABLE`，不得自行放寬parser。
- Rehearsal必須materialize所有registered cache directories；缺任一路徑即fail-closed。
- 本candidate test證明path isolation與live invariant，不取代future transaction內的逐host native plugin-absence gate。
- Candidate rollback：revert本amendment commit。Live rollback：SKIPPED，因本輪沒有live write或plugin mutation。

## 8. Stop gate

Candidate GREEN後停止。新的live HEAD已含上次deployment／coordinated rollback commits；重新cutover前必須另行授權建立fresh post-failed-transaction baseline與new full rollback carrier。6-run canary仍未授權。

## 9. Candidate commit sequence

- RED：`5412545` — `test(workflow): [wip] 鎖定 Copilot 模擬隔離`
- GREEN：`f7c437d` — `fix(workflow): 隔離 Copilot 模擬快取路徑`

Evidence commit hash由post-commit read-only probe回報，避免self-reference。
