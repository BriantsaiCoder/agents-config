# Three-host global-config split — Claude `.in_use` active-owner amendment evidence

> 日期：2026-07-29 Asia/Taipei
> Scope：candidate-only maintenance gate amendment；不含live cutover、plugin mutation、canary、SaaS、remote、push、PR或merge。
> Risk：HIGH。

## 1. Authorization and fixed point

使用者明示：

> 核准 candidate-only maintenance .in_use active-owner amendment 與 RED→GREEN 驗證；不授權 live cutover、plugin mutation 或 canary

Shared candidate fixed point：`0887741218fef4ea6efc619dcc04059a540ec1b2`。

| Commit | Purpose |
|---|---|
| `e2fa378cb0164236e1ae12aa31700d54c924ecdd` | RED contract：禁止以persistent directory count判定active lock |
| `0543c6673500ea1d1addc122c166b2b570e0cdcc` | Minimal GREEN：Plan 48改用active-owner maintenance gate |

本文件commit hash由post-commit evidence回報，避免self-reference。

## 2. Root cause and amended semantics

舊判定把`~/.claude/plugins/cache/**/.in_use` directory存在等同active runtime。Fresh read-only probe證明這些directory是跨plugin／version持久marker container，退出Claude後仍保留歷史PID markers。

| Gate | Before | After |
|---|---|---|
| Claude process | 未獨立要求 | process count = 0 |
| `.in_use` | directory count = 0 | directory count只作metadata；active marker-owner intersection = 0 |
| Superpowers trees | 未獨立要求 | 兩個exact trees open-handle count = 0 |
| Unknown marker／probe | blocker語意不明 | `UNAVAILABLE`；fail-fast |
| Stale markers | 可能要求刪除 | 保持byte／path／mode；禁止刪除、清空或wildcard |

Active owner以marker filename PID為第一層，非空JSON另驗`pid`一致；`procStart`存在時用於排除PID reuse。PID存在但缺少可比對的`procStart`、格式不合法或process probe不可用一律`UNAVAILABLE`。

## 3. Fresh read-only evidence

| Probe | Result |
|---|---|
| Claude process count | 0 |
| `.in_use` directories | 76 |
| marker files | 589 |
| empty markers | 84 |
| JSON markers | 505 |
| JSON filename／payload PID mismatch | 0 |
| unique historical marker PIDs | 58 |
| live marker-owner intersections | 0 |
| `claude-plugins-official/superpowers/6.2.0` open handles | 0 |
| `superpowers-marketplace/superpowers/6.2.0` open handles | 0 |

沒有讀取或輸出credential值；marker內容只解析`pid`／`procStart` schema與一致性，沒有輸出payload。

## 4. RED → GREEN

RED at `e2fa378`：

```text
FAIL: Plan 48 treats persistent .in_use directories as active locks
```

GREEN at `0543c66`：

```text
PASS: three-host global-config ownership contract
```

Regression同時鎖定：

- 不得以`.in_use` directory count = 0作gate；
- process、active owner、兩個exact tree open handles三條件；
- 禁止刪除、清空或wildcard處理`.in_use`。

## 5. Candidate verification

| Gate | Result |
|---|---|
| Shared ownership contract | PASS |
| Shared conformance | 9 PASS / 0 FAIL / 0 SKIP |
| Matt thin workflow | PASS |
| Matt workflow contracts | 54 PASS / 0 FAIL |
| Legacy `mp-*` retirement | PASS |
| Claude candidate integrity | 19 PASS / 0 FAIL |
| Codex candidate ownership | PASS |
| Copilot candidate ownership | PASS |
| Modified shell Bash syntax／ShellCheck error severity | PASS |
| Amendment `git diff --check` | PASS |
| Markdown heading／placeholder scan | PASS |
| Gitleaks `--redact=100` | PASS；153 commits scanned，no leaks |
| Fresh post-rollback live baseline | exact PASS |
| Fresh shared-skills baseline | exact PASS |
| Fresh historical baseline | exact PASS |

第一次shared conformance與Claude integrity invocation誤用live default root，分別得到`7 PASS / 2 FAIL`與`18 PASS / 4 FAIL`；改用既有candidate override seam `AGENTS_HOME`／`SHARED_SKILLS_ROOT`後全綠。沒有為此修改code或baseline。

DCT build／test／MySQL E2E：SKIPPED；本次只改machine-local workflow plan、contract test與evidence。

## 6. Review and settlement

| Axis | Verdict | Evidence |
|---|---|---|
| Standards | PASS | diff限於既有contract test與Plan 48；無新dependency、wildcard或destructive cleanup |
| Spec | PASS | process 0、active-owner 0、exact handles 0、fail-fast與authorization boundary全覆蓋 |
| Formal fan-out | UNAVAILABLE | Plan 48禁止subagent；sequential two-axis review，0 actionable findings |

錯誤學習由本contract test與Plan 48機械守護；不另寫cookbook、memory或shared workflow。

## Closeout Ledger

| Row | Verdict | Evidence |
|---|---|---|
| Scope | PASS | shared candidate only；live/plugin/canary zero mutation |
| RED → GREEN | PASS | `e2fa378` RED → `0543c66` GREEN |
| S4 Verify | PASS | shared＋三host＋security＋baseline gates全綠 |
| S5 Standards | PASS with deviation | sequential PASS；formal fan-out UNAVAILABLE |
| S5 Spec | PASS | active-owner amendment requirements exact |
| S6 Closeout | PASS for candidate only | no push、PR、merge、SaaS或remote action |

## 7. Unique next gate

本evidence commit與post-commit revalidation完成後停止。唯一下一gate：

> 使用者另行明示授權coordinated live cutover與三家Superpowers實際退休。

Maintenance window後的fixed 6-run canary仍需獨立明示授權。
