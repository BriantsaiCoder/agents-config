---
name: Config and Project Setup
---

# Config & Project Setup

設定 tsconfig.json、ESLint、Declaration Files、Monorepo 時讀取此檔案。涵蓋 strict mode 各 flag 詳解、module/moduleResolution 策略、paths aliases、ESLint 整合、.d.ts 撰寫、monorepo project references。

## TypeScript 版本現況（2026-07）

| 版本線 | 狀態 | 取得方式 |
|---|---|---|
| **7.0**（npm `latest`） | 2026-07-08 出貨。Go 原生重寫，`typescript` 套件直接安裝 Go 二進位，指令仍是 `tsc` | `npm i -D typescript` |
| **6.0** | 最後一版 JS 實作。7.0 的 breaking change 在此先以 deprecation 形式出現，建議先升 6.0 再升 7.0 | `npm i -D @typescript/typescript6`（指令 `tsc6`），可與 7.0 並存 |
| 5.x | 舊線。本檔標註 `TS 5.x+` 的 flag 在 6/7 仍有效，除非另行標示 |  |

新旗標：`--checkers`（type-checker worker 數）、`--builders`（project reference 平行建置）、`--singleThreaded`。

> **升 TS 7 前先確認 lint 鏈**：`typescript-eslint@8.65.0` 的 peer 上限是 `typescript >=4.8.4 <6.1.0`，與 TS 7 同裝會 `ERESOLVE`（實測）。lint 鏈跟上之前，升 TS 7 必須同時規劃 linter 路徑，不能只換 `typescript`。
>
> **TS 7 已移除的選項**：`baseUrl`（改把前綴寫進 `paths`）。本檔範例已對齊。

## Table of Contents
- [tsconfig.json: Strict Mode Breakdown](#tsconfigjson-strict-mode-breakdown)
- [tsconfig.json: Module and Resolution](#tsconfigjson-module-and-resolution)
- [tsconfig.json: Target Recommendations](#tsconfigjson-target-recommendations)
- [tsconfig.json: Paths Aliases](#tsconfigjson-paths-aliases)
- [Recommended tsconfig Bases](#recommended-tsconfig-bases)
- [Example tsconfig Configs](#example-tsconfig-configs)
- [ESLint + typescript-eslint Setup](#eslint--typescript-eslint-setup)
- [Declaration Files (.d.ts)](#declaration-files-dts)
- [Module Augmentation](#module-augmentation)
- [Monorepo TypeScript](#monorepo-typescript)

## tsconfig.json: Strict Mode Breakdown

`"strict": true` 開啟以下所有 flag。建議永遠開啟 strict，以下逐一說明每個 flag 的作用：

| Flag | 說明 |
|---|---|
| `strictNullChecks` | `null`/`undefined` 不再自動 assignable 給其他型別。**最重要的 flag** |
| `strictFunctionTypes` | 函數參數型別使用 contravariance 檢查（更安全） |
| `strictBindCallApply` | `bind`, `call`, `apply` 的參數會被正確檢查 |
| `strictPropertyInitialization` | Class properties 必須在 constructor 中初始化或標記 `!` |
| `noImplicitAny` | 禁止隱含的 `any` 型別 — 必須明確標註或讓 TS 推斷 |
| `noImplicitThis` | 禁止 `this` 的隱含 `any` 型別 |
| `alwaysStrict` | 每個檔案加入 `"use strict"` |
| `useUnknownInCatchVariables` | catch 的 error 變數型別為 `unknown` 而非 `any` |

### 額外建議開啟的 flag

```jsonc
{
  "compilerOptions": {
    "strict": true,
    // 額外型別安全 flags
    "noUncheckedIndexedAccess": true,   // obj[key] 回傳 T | undefined
    "noPropertyAccessFromIndexSignature": true, // 強制 bracket notation 存取 index signature
    "exactOptionalPropertyTypes": true, // 區分 undefined 和 missing
    "erasableSyntaxOnly": true,         // TS 5.8+：禁用無法純抹除的語法
    "noFallthroughCasesInSwitch": true  // switch case 必須 break/return
  }
}
```

`erasableSyntaxOnly`（TS 5.8+）會擋掉六類無法純抹除的語法：parameter properties、`<T>expr` 型別斷言、
非 ambient 的 `enum` / `const enum`、非 ambient 的 instantiated namespace、非 ambient 的 `import =` 與
`export =`。它把 Golden Rule 11（避免 `enum`）機械化，也是讓 `.ts` 直接餵給 Node 原生 type stripping 的前提。
既有專案若大量使用 NestJS 風格的 constructor parameter properties，一開會噴大量錯誤 — 屬於漸進式啟用的最後一階。

### 漸進式啟用（for legacy projects）

如果不能一次全開，按優先順序逐步啟用：

1. `strictNullChecks` — 影響最大，收益最高
2. `noImplicitAny` — 防止型別逃逸
3. `useUnknownInCatchVariables` — 低成本高收益
4. 其餘一起開

## tsconfig.json: Module and Resolution

### 現代專案建議

| 場景 | `module` | `moduleResolution` | 說明 |
|---|---|---|---|
| Node.js (ESM) | `NodeNext` | `NodeNext` | 支援 .mjs/.cjs，尊重 package.json `exports` |
| Node.js（TS 5.9+，鎖定語意） | `node20` | 省略（自動推導） | Node 20/22/24 語意的**固定快照**；TS 官方建議 5.9 之後改用此值 |
| Bundler (Vite/webpack) | `ESNext` | `Bundler` | Bundler 處理 resolution，TS 不需要嚴格檢查 |
| Library (同時支援 CJS/ESM) | `NodeNext` | `NodeNext` | 確保輸出的 .d.ts 對消費者正確 |

`nodenext` 與 `node20` 都支援 `require("esm")`；差別在 `nodenext` 是滾動目標，升 TS 版本就可能改變模組語意，
而 `node20` 不會漂移。需要可重現建置／鎖定模組語意的專案優先挑 `node20`（TS 5.9 以下沒有這個值，只能用 `NodeNext`）。

```jsonc
// Node.js ESM 專案
{
  "compilerOptions": {
    "module": "NodeNext",
    "moduleResolution": "NodeNext"
    // 必須在 import 中寫副檔名: import { foo } from './foo.js'
  }
}

// Vite / Next.js 前端專案
{
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowImportingTsExtensions": true, // 搭配 noEmit 使用
    "noEmit": true
  }
}
```

### moduleResolution 差異速查

| Resolution | `import './foo'` | `package.json exports` | 建議 |
|---|---|---|---|
| `node10` (舊) | 嘗試 .ts, .js, /index.ts | 忽略 | 不建議使用 |
| `NodeNext` | 必須寫 `./foo.js` | 尊重 | Node.js ESM 標準 |
| `Bundler` | `./foo` 可省副檔名 | 尊重 | Bundler 環境 |

### isolatedModules 與 verbatimModuleSyntax

```typescript
// isolatedModules: true — bundler 逐檔編譯時必須
// ❌ re-export 可能是型別
export { User } from './types';
// ✅ 明確標示
export type { User } from './types';

// verbatimModuleSyntax (TS 5.0+) — 取代 isolatedModules + importsNotUsedAsValues
import type { User } from './types';  // ✅ 型別 import
import { createUser } from './types'; // ✅ 值 import
```

### Barrel exports（`index.ts` re-export）

⛔ **家規禁用**（`~/.agents/rules/typescript.md`：「**NEVER** barrel exports（`index.ts` 重新匯出）」）。禁用的技術理由：

| 代價 | 說明 |
|---|---|
| 循環相依 | 同目錄模組彼此經 barrel 取用時形成 `a → index → b → index` 迴圈。TS 不報錯，runtime 拿到 `undefined`，症狀還常出現在無關的第三個檔案，極難定位 |
| 重編譯扇出 | IDE 自動 import 會挑路徑較短的 barrel，久了變成「每個檔案都依賴 index.ts，index.ts 又依賴每個檔案」。動任一葉節點就讓整個 barrel 的消費端重跑型別檢查，`tsc --watch` 與 HMR 隨檔案數線性變慢 |
| tree-shaking 不可靠 | `export *` 要求 bundler 逐一證明 re-export 無副作用才能剪除。只要套件沒正確宣告 `sideEffects: false`，或任一模組有 top-level 副作用，整串就被保留進 bundle |

正確做法是**直接從來源模組 import**：

```typescript
// ❌ src/utils/index.ts — barrel
export * from './format';
export * from './parse';
export * from './validate';

// 消費端：看似只取一個函式，實際牽動整個 barrel 的相依圖
import { formatDate } from '@/utils';

// ✅ 直接指到來源檔（路徑長一點，換到精確的相依邊）
import { formatDate } from '@/utils/format';
```

搭配後面的 `paths` aliases 時尤其要留意：alias 讓 `@/utils` 這種寫法看起來很整潔，但解析後仍是整個 `index.ts`。alias 應指到目錄（`@/*`），由呼叫端補完到來源檔。

## tsconfig.json: Target Recommendations

| 環境 | 建議 `target` | 說明 |
|---|---|---|
| Node.js 24（現行 Active LTS） | `ES2024` | `@tsconfig/node24` 的 base 值（`lib` 亦為 `ES2024`），搭配 `"module": "nodenext"` |
| Node.js 22（Maintenance LTS） | `ES2023` | TS 官方 Node-Target-Mapping 建議值；同時相容 Node 24 |
| Node.js 18 / 20 | — | **已 EOL**（18 於 2025-04、20 於 2026-04 結束支援），新專案勿以此為 target |
| 現代瀏覽器 | `ES2022` | 大多數瀏覽器都支援 |
| 需要舊瀏覽器支援 | `ES2017`-`ES2020` | 搭配 polyfill |
| Library | `ES2020` 或更低 | 依最低支援版本決定 |

`target` 影響 emit 的 JS 語法（是否 downlevel），也影響可用的 `lib`。

## tsconfig.json: Paths Aliases

```jsonc
{
  "compilerOptions": {
    // TS 7.0 已移除 baseUrl（TS 6.0 起 deprecated）——前綴直接寫進 paths，相對 tsconfig 所在目錄
    "paths": {
      "@/*": ["./src/*"],
      "@components/*": ["./src/components/*"],
      "@utils/*": ["./src/utils/*"],
      "@types/*": ["./src/types/*"]
    }
  }
}
```

tsconfig 的 `paths` 只告訴 TS 如何解析型別。Runtime resolution 需要在 bundler 也設定：

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@components': path.resolve(__dirname, './src/components'),
    },
  },
});
```

Node.js 專案可用 `tsx` 或 `tsconfig-paths`：

```bash
node --import tsx src/index.ts
# 或
node -r tsconfig-paths/register src/index.ts
```

## Recommended tsconfig Bases

社群維護的 tsconfig base packages，避免從零設定：

```jsonc
// Node.js 現行 Active LTS（24.x）專案
{ "extends": "@tsconfig/node24/tsconfig.json" }

// 最嚴格設定（學習或新專案推薦）
{ "extends": "@tsconfig/strictest/tsconfig.json" }

// Vite + React 專案
{ "extends": "@tsconfig/vite-react/tsconfig.json" }
```

安裝：`npm install -D @tsconfig/node24` 或 `@tsconfig/strictest`（Node 18 / 20 已 EOL，`@tsconfig/node18` /
`@tsconfig/node20` 勿再用於新專案；維護中的舊專案沿用即可，升級 runtime 時一併換 base）

### @tsconfig/strictest 包含什麼

除了 `strict: true`，還開啟：
- `noUncheckedIndexedAccess`
- `noFallthroughCasesInSwitch`
- `exactOptionalPropertyTypes`
- `noPropertyAccessFromIndexSignature`
- `forceConsistentCasingInFileNames`

推薦作為起點 — 如果某些規則太嚴格，逐一關閉並記錄原因。

## Example tsconfig Configs

### Node.js 24 Backend（Active LTS）

```jsonc
{
  "extends": "@tsconfig/node24/tsconfig.json",
  "compilerOptions": {
    "strict": true,
    "module": "NodeNext",        // TS 5.9+ 可改 "node20" 鎖定語意，moduleResolution 則省略
    "moduleResolution": "NodeNext",
    "target": "ES2024",
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noUncheckedIndexedAccess": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
```

### Vite + React Frontend

```jsonc
{
  "compilerOptions": {
    "strict": true,
    "target": "ES2022",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "react-jsx",
    "noEmit": true,
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "noUncheckedIndexedAccess": true,
    "paths": { "@/*": ["./src/*"] },
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*.ts", "src/**/*.tsx"],
  "exclude": ["node_modules"]
}
```

### Library (Dual CJS/ESM)

```jsonc
{
  "compilerOptions": {
    "strict": true,
    "target": "ES2020",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "skipLibCheck": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

## ESLint + typescript-eslint Setup

### Flat Config (ESLint 9+, recommended)

```typescript
// eslint.config.ts
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
      }],
      '@typescript-eslint/consistent-type-imports': ['error', {
        prefer: 'type-imports',
      }],
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-optional-chain': 'error',
      '@typescript-eslint/switch-exhaustiveness-check': 'error',
    },
  },
);
```

### 重要規則說明

| 規則 | 說明 |
|---|---|
| `no-floating-promises` | async 函數的回傳值必須被 await 或處理，防止靜默吞掉 error |
| `no-misused-promises` | 防止在非 async context 使用 Promise（常見於 event handler） |
| `consistent-type-imports` | 強制 `import type { Foo }` 語法，配合 `verbatimModuleSyntax` |
| `switch-exhaustiveness-check` | switch 必須涵蓋所有 union members |
| `prefer-nullish-coalescing` | 用 `??` 取代 `\|\|` 處理 null/undefined |
| `no-unsafe-assignment` | 偵測 `any` 擴散，防止 `any` 病毒式傳播 |
| `restrict-template-expressions` | 防止 template string 中出現 `[object Object]` |

### 自訂規則範例

```typescript
// 禁止特定 import
'no-restricted-imports': ['error', {
  patterns: [
    { group: ['lodash'], message: 'Use native methods or lodash-es' },
    { group: ['*.css'], message: 'Use CSS modules (*.module.css)' },
  ],
}],
```

### 替代方案：@antfu/eslint-config（all-in-one，含 formatter）

若不想自行拼接 typescript-eslint + stylistic + import rules，可用 Anthony Fu 的整合配置。特色：內建 formatter（不需 Prettier）、auto-detect TS/Vue、框架支援用 opt-in flag。

```js
// eslint.config.mjs
import antfu from '@antfu/eslint-config'

export default antfu({
  type: 'app',                          // 'lib' for libraries
  stylistic: { indent: 2, quotes: 'single' },
  typescript: true,                     // auto-detected
  react: true,                          // 需 @eslint-react/eslint-plugin eslint-plugin-react-hooks eslint-plugin-react-refresh
  vue: { a11y: true },                  // 需 eslint-plugin-vuejs-accessibility
  nextjs: true,                         // 需 @next/eslint-plugin-next
  ignores: ['**/fixtures', '**/dist'],
})
```

Trade-off vs 手動 flat config：
- Pros：零配置、formatter 內建、升級由 antfu 維護、single import
- Cons：風格是 antfu 的（單引號、無分號、sorted imports），團隊若有既有 style guide 需 override
- 搭配 `simple-git-hooks` + `lint-staged` 做 pre-commit lint；建議搭配 `eslint --fix` 完成格式化

## Declaration Files (.d.ts)

### 何時需要寫 .d.ts

1. **為無型別的 JS library 補型別** — 當 `@types/xxx` 不存在時
2. **宣告全域變數** — 如 `window.__APP_CONFIG__`
3. **擴充第三方型別** — module augmentation
4. **Library 發佈** — 通常 `declaration: true` 自動產生，不需手寫

### 為 JS module 補型別

```typescript
// types/untyped-lib.d.ts
declare module 'untyped-lib' {
  export function doSomething(input: string): Promise<Result>;
  export interface Result {
    status: 'ok' | 'error';
    data: unknown;
  }
}
```

### 宣告全域變數

```typescript
// types/global.d.ts
declare global {
  interface Window {
    __APP_CONFIG__: {
      apiUrl: string;
      featureFlags: Record<string, boolean>;
    };
  }
  type Nullable<T> = T | null;
}
export {}; // 必須有 export 才能讓 declare global 生效
```

### 宣告 Vite 環境變數型別

```typescript
// src/vite-env.d.ts
/// <reference types="vite/client" />
interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_APP_TITLE: string;
}
interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

### .d.ts vs .ts 的差異

- `.d.ts` 只有型別宣告，沒有 implementation — 不會被編譯成 JS
- 不要在 `.d.ts` 裡放 implementation（`const x = 5`）

## Module Augmentation

擴展已有 module 的型別，不需修改原始 .d.ts。

```typescript
// 擴展 express 的 Request
import 'express';
declare module 'express' {
  interface Request {
    userId?: string;
    tenantId?: string;
  }
}

// 擴展 MUI theme
import '@mui/material/styles';
declare module '@mui/material/styles' {
  interface Palette {
    neutral: Palette['primary'];
  }
  interface PaletteOptions {
    neutral?: PaletteOptions['primary'];
  }
}

// 擴展 Node.js process.env
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      DATABASE_URL: string;
      PORT: string;
      NODE_ENV: 'development' | 'production' | 'test';
    }
  }
}
export {};
```

## Monorepo TypeScript

### Project References (composite builds)

每個 package 有自己的 tsconfig.json，root 用 `references` 串接。

```jsonc
// packages/shared/tsconfig.json
{
  "compilerOptions": {
    "composite": true,        // 啟用 project references
    "declaration": true,      // composite 需要
    "declarationMap": true,   // 讓 IDE 跳到源碼
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*.ts"]
}

// packages/api/tsconfig.json
{
  "compilerOptions": {
    "composite": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "references": [
    { "path": "../shared" }  // 依賴 shared package
  ],
  "include": ["src/**/*.ts"]
}

// tsconfig.json (root)
{
  "files": [],
  "references": [
    { "path": "./packages/shared" },
    { "path": "./packages/api" },
    { "path": "./packages/web" }
  ]
}
```

### Build 指令

```bash
# 建置所有 packages（自動處理依賴順序）
tsc --build

# 只建置有變更的 packages（增量建置）
tsc --build --incremental

# 清除建置快取
tsc --build --clean
```

### 搭配 package manager workspaces

```jsonc
// package.json (root)
{
  "workspaces": ["packages/*"],
  "scripts": {
    "build": "tsc --build",
    "typecheck": "tsc --build --noEmit"
  }
}

// packages/api/package.json
{
  "name": "@myorg/api",
  "dependencies": {
    "@myorg/shared": "workspace:*"
  }
}
```

### composite 的關鍵限制

1. 必須開啟 `declaration: true`
2. `rootDir` 必須明確設定（通常是 `./src`）
3. 所有 source files 必須被 `include` 或 `files` 涵蓋
4. 不能用 `noEmit`（但可以用 `emitDeclarationOnly`）

### Monorepo 工具搭配

| 工具 | 角色 | 注意事項 |
|---|---|---|
| Turborepo | Task orchestration | 用 `tsc --build` 作為 build task |
| pnpm workspaces | Package management | `workspace:*` protocol 引用 internal packages |
| Nx | Task orchestration + caching | 有內建 TS project graph support |
