#!/usr/bin/env bash
# 快速偵測專案技術棧，輸出 JSON 摘要。
# 用法：./detect-stack.sh [project_root]
# 輸出欄位：primary, languages, dotnet, node, orm, test, docker, monorepo,
#           settings_template（stack 名，如 dotnet-webapi）, settings_addons
#
# 註：settings_template 只回「stack 名」，不含 host 維度。SKILL.md Phase 2
#     依 Phase 0.5 偵測到的 host 組路徑：Claude → settings-templates/claude/<stack>.json；
#     Codex / Copilot → 各自 references/settings-templates/<host>/README.md 指南。

set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

# ---- 基本偵測 ----
has() { [[ -n "$(find . -maxdepth 4 -name "$1" -not -path './node_modules/*' -not -path './bin/*' -not -path './obj/*' 2>/dev/null | head -1)" ]]; }
has_any() { for pat in "$@"; do has "$pat" && return 0; done; return 1; }

DOTNET=false; NODE=false; PYTHON=false; GO=false; RUST=false
has_any "*.csproj" "*.sln" && DOTNET=true
has "package.json" && NODE=true
has_any "pyproject.toml" "requirements.txt" "setup.py" && PYTHON=true
has "go.mod" && GO=true
has "Cargo.toml" && RUST=true

# ---- 主要語言判定 ----
PRIMARY="unknown"
if $DOTNET; then PRIMARY="dotnet"
elif $NODE; then PRIMARY="nodejs"
elif $PYTHON; then PRIMARY="python"
elif $GO; then PRIMARY="go"
elif $RUST; then PRIMARY="rust"
fi

# ---- .NET 細節 ----
DOTNET_KIND="none"; DOTNET_TFM=""
if $DOTNET; then
  CSPROJ=$(find . -maxdepth 4 -name "*.csproj" -not -path './bin/*' -not -path './obj/*' | head -1)
  if [[ -n "$CSPROJ" ]]; then
    if grep -q "Microsoft.NET.Sdk.Web" "$CSPROJ" 2>/dev/null; then DOTNET_KIND="webapi"
    elif grep -q "Microsoft.NET.Sdk.Worker" "$CSPROJ" 2>/dev/null; then DOTNET_KIND="worker"
    elif grep -q "OutputType.*WinExe" "$CSPROJ" 2>/dev/null; then DOTNET_KIND="winforms"
    elif grep -q "OutputType.*Exe" "$CSPROJ" 2>/dev/null; then DOTNET_KIND="console"
    else DOTNET_KIND="library"
    fi
    DOTNET_TFM=$(grep -oE '<TargetFramework[s]?>[^<]+' "$CSPROJ" 2>/dev/null | head -1 | sed 's/<TargetFramework[s]*>//')
  fi
fi

# ---- Node 細節 ----
NODE_KIND="none"
if $NODE && [[ -f package.json ]]; then
  if grep -q '"next"' package.json 2>/dev/null; then NODE_KIND="next"
  elif grep -q '"nuxt"' package.json 2>/dev/null; then NODE_KIND="nuxt"
  elif grep -q '"vite"' package.json 2>/dev/null; then NODE_KIND="vite-spa"
  elif grep -q '"express"\|"fastify"\|"koa"' package.json 2>/dev/null; then NODE_KIND="express"
  elif grep -q '"react"' package.json 2>/dev/null; then NODE_KIND="react"
  elif grep -q '"vue"' package.json 2>/dev/null; then NODE_KIND="vue"
  else NODE_KIND="generic"
  fi
fi

# ---- ORM / Test ----
ORM="none"
$DOTNET && grep -rq "Microsoft.EntityFrameworkCore" . --include="*.csproj" 2>/dev/null && ORM="ef-core"
$DOTNET && grep -rq "EntityFramework<\|EntityFramework \"" . --include="*.csproj" 2>/dev/null && ORM="ef6"
$DOTNET && grep -rq "Dapper" . --include="*.csproj" 2>/dev/null && [[ "$ORM" == "none" ]] && ORM="dapper"
$NODE && grep -q '"prisma"' package.json 2>/dev/null && ORM="prisma"
$NODE && grep -q '"typeorm"' package.json 2>/dev/null && [[ "$ORM" == "none" ]] && ORM="typeorm"
$PYTHON && grep -q "sqlalchemy" requirements.txt pyproject.toml 2>/dev/null && ORM="sqlalchemy"

TEST="none"
$DOTNET && grep -rq "xunit\|XUnit" . --include="*.csproj" 2>/dev/null && TEST="xunit"
$DOTNET && grep -rq "NUnit" . --include="*.csproj" 2>/dev/null && [[ "$TEST" == "none" ]] && TEST="nunit"
$NODE && grep -q '"vitest"' package.json 2>/dev/null && TEST="vitest"
$NODE && grep -q '"jest"' package.json 2>/dev/null && [[ "$TEST" == "none" ]] && TEST="jest"
$PYTHON && has "pytest.ini" && TEST="pytest"
$PYTHON && grep -q "pytest" requirements.txt pyproject.toml 2>/dev/null && [[ "$TEST" == "none" ]] && TEST="pytest"

# ---- Docker / Monorepo ----
DOCKER=false
has_any "Dockerfile" "docker-compose.yml" "docker-compose.yaml" "compose.yml" && DOCKER=true

MONOREPO=false
if $NODE && [[ -f package.json ]]; then
  grep -q '"workspaces"' package.json 2>/dev/null && MONOREPO=true
fi
has "pnpm-workspace.yaml" && MONOREPO=true
has "lerna.json" && MONOREPO=true
has "turbo.json" && MONOREPO=true

# ---- Settings 範本對應 ----
# 對應 references/settings-templates/ 下的檔名（不含 .json）。
SETTINGS_TEMPLATE="none"
case "$PRIMARY" in
  dotnet)
    if [[ "$DOTNET_TFM" == net4* ]]; then
      # net4xx TFM 一律視為 .NET Framework，不分 kind
      SETTINGS_TEMPLATE="dotnet-framework"
    else
      case "$DOTNET_KIND" in
        webapi)   SETTINGS_TEMPLATE="dotnet-webapi" ;;
        worker)   SETTINGS_TEMPLATE="dotnet-worker" ;;
        winforms) SETTINGS_TEMPLATE="dotnet-winforms" ;;
        library)  SETTINGS_TEMPLATE="dotnet-library" ;;
        *)        SETTINGS_TEMPLATE="dotnet-console" ;;
      esac
    fi
    ;;
  nodejs)
    case "$NODE_KIND" in
      next|nuxt|vite-spa|react|vue) SETTINGS_TEMPLATE="frontend" ;;
      *)                            SETTINGS_TEMPLATE="nodejs-express" ;;
    esac
    ;;
  python) SETTINGS_TEMPLATE="python" ;;
  go)     SETTINGS_TEMPLATE="go" ;;
  rust)   SETTINGS_TEMPLATE="rust" ;;
esac

# docker-addon 為疊加範本，與主範本並用
SETTINGS_ADDONS="[]"
$DOCKER && SETTINGS_ADDONS='["docker-addon"]'

# ---- Output ----
printf '{\n'
printf '  "primary": "%s",\n' "$PRIMARY"
printf '  "languages": { "dotnet": %s, "nodejs": %s, "python": %s, "go": %s, "rust": %s },\n' "$DOTNET" "$NODE" "$PYTHON" "$GO" "$RUST"
printf '  "dotnet": { "kind": "%s", "tfm": "%s" },\n' "$DOTNET_KIND" "$DOTNET_TFM"
printf '  "node": { "kind": "%s" },\n' "$NODE_KIND"
printf '  "orm": "%s",\n' "$ORM"
printf '  "test": "%s",\n' "$TEST"
printf '  "docker": %s,\n' "$DOCKER"
printf '  "monorepo": %s,\n' "$MONOREPO"
printf '  "settings_template": "%s",\n' "$SETTINGS_TEMPLATE"
printf '  "settings_addons": %s\n' "$SETTINGS_ADDONS"
printf '}\n'
