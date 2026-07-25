# ~/.agents — 三主機 AI 共用設定正本層

> **讀者是 AI 模型**（Claude / Codex GPT / Copilot），不是人。本層是三家 CLI 協作設定的**單一真實來源**：規則寫一次、由 `bin/agents-sync` 生成部署到各 host，任何一處手改都會被 no-clobber 守護擋回正本。

## 這是什麼

Claude Code、Codex CLI、Copilot CLI 三家過去各有一份設定，各自漂移（其一曾假載入完整 Hard Rules 達一個月無人察覺）。本層把「共用規則正本 + 生成部署 + drift 守護」收斂到一個 git repo：

- `core/` — 共用規則正本（**檔 = 同步強度單位**）：`tier0-safety.md`（安全紅線，三家 100% 常駐）、`tier1-workflow.md`（工作流紀律）、`tier2-style.md`（風格）、`routing.md`（dev-workflow 路由）。
- `rules/` — stack pin 正本（`~/.claude/rules` 遷入，PIN 區塊供抽取）。
- `skills/` — 三家共用 skill 正本（Codex / Copilot 原生載入；Claude 靠相對 symlink）。
- `hosts/` — 各 host 差異層：`codex-delta.md`、`copilot-delta.md`。
- `hooks/` — 共用 hook script 正本。
- `bin/agents-sync` — 生成器 + lint + drift 守護（`--check` / `--bootstrap` / `--doctor`）。
- `dist/` — 生成產物（**進版控**供 drift diff）。
- `attic/` — 退役歸檔（git 可考古）。
- `CONVENTIONS.md` — AI 讀者書寫規範 13 條（agents-sync lint 機械強制其中子集）。

## tier 定義（同步強度隨 tier 遞減）

| tier | 內容 | 守護強度 |
|------|------|----------|
| tier0 | 安全紅線（違反屬 bug） | 100% live；SessionStart drift 巡檢告警（drift-check.sh，告警不自動再生）+ no-clobber + gitleaks |
| tier1 | 工作流紀律 | 同管線；容忍最多一個 session 延遲 |
| tier2 | 風格 | host 間差異可接受；只靠 git diff 巡檢，發現實害才升 tier |

## 各 host 消費面

- **Claude**：`~/.claude/CLAUDE.md` 頂部 `@import ~/.agents/core/*`（原生機制，零生成、不可能 drift）；`~/.claude/rules/*` 與 `skills/*` 為相對 symlink。
- **Codex**：`~/.codex/AGENTS.md` = agents-sync 組裝部署（override 已退役，回歸 boring default 載入）。
- **Copilot**：`~/.copilot/copilot-instructions.md` = agents-sync 組裝部署（唯一目標，見 TARGETS；整檔原樣注入）。

## 再生 / 巡檢指令

```sh
~/.agents/bin/agents-sync --check      # dry-run：驗 lint + 印將寫入的 diff，不部署
~/.agents/bin/agents-sync              # 生成 + 部署三家（no-clobber 守護）
~/.agents/bin/agents-sync --bootstrap  # 新機一鍵重建全部相對 symlink + 部署三家
~/.agents/bin/agents-sync --doctor     # 巡檢：斷鏈 0、manifest 相符、override 不存在、三家 FP 探針
~/.agents/tests/conformance.sh         # 安全修復綠態探針集：手動跑；改 guard / hook / settings / core 後必跑（不掛 SessionStart）
```

改規則只改 `core/` `hosts/` `rules/` 正本，重跑 agents-sync；**MUST NOT 手改 `dist/` 或各 host 部署檔**（有 no-clobber banner）。書寫規範見 [CONVENTIONS.md](CONVENTIONS.md)，設計理由見 `proposals/2026-07-07-three-host-unification/`。

## 分支工作：用 worktree，別在 `~/.agents` 切分支

`~/.agents` 是三家 host **實際讀取**的目錄，而兩半的生效機制不同：

| 消費端 | 機制 | 切分支時 |
|---|---|---|
| Claude | `~/.claude/skills/*` 是指回 `~/.agents/skills/` 的 symlink | **當下就變**，不需任何指令 |
| Codex / Copilot | `~/.codex/AGENTS.md`、`~/.copilot/copilot-instructions.md` 是生成的部署檔 | 不動，直到跑 `agents-sync` |

所以在這裡切分支不是「內容變舊」，而是**三家進入互相矛盾的狀態**——而 `manifest 相符` 仍會顯示綠燈（它只證明部署檔沒被手改，證明不了對應哪個 commit）。

```sh
~/.agents/bin/agents-branch <branch>        # 在 .worktrees/<branch> 開工，~/.agents 留在 main
~/.agents/bin/agents-branch --list
~/.agents/bin/agents-branch --done <branch> # 收工（分支保留）
```

三道守護（**每台機器要先跑一次 `bash hooks/install-hooks.sh`**，hooks 不進版控）：

1. `post-checkout` — 在 `~/.agents` 切離 main 時警告；linked worktree 內靜音（那是預期做法）
2. `agents-sync --doctor` 的**出處戳記**節 — 比對部署檔 banner 的 `@<sha>` 與當前 HEAD，不符標 `STALE`
3. `hooks/drift-check.sh`（SessionStart）— 每次開 session 跑 doctor，把上面那條自動曝光

刻意**不**自動跑 `agents-sync`：那會讓狀態變一致，但也讓「切到過時分支 → 全域 agent 設定靜默回退」變得完全無聲。一致的錯比不一致的錯更難發現。
