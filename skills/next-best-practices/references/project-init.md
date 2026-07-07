# Next.js 15 Project Init Scaffold

新專案起手式。其他 `*.md` 講「寫 Next.js code 的 best practice」；本檔講「新專案第一天怎麼開」。

## 1. Create + Install

```bash
# App Router + TS + Tailwind v4 + src/ + @/* alias
npx create-next-app@latest my-app \
  --typescript --tailwind --app --eslint \
  --src-dir --import-alias "@/*" --use-npm
cd my-app

# UI（shadcn CLI 產 Tailwind + CSS vars）
npx shadcn@latest init
npx shadcn@latest add button card input form label dialog dropdown-menu table

# State + data + forms
npm i zustand @tanstack/react-query @tanstack/react-query-devtools
npm i react-hook-form @hookform/resolvers zod lucide-react
```

可選：Drizzle ORM（`drizzle-orm` + `drizzle-kit`）、Better Auth、`tailwindcss-animate`。

## 2. Directory Layout（feature-based）

```
src/
├── app/                  # App Router（(marketing) / (app) 等 route groups）
├── components/
│   ├── ui/               # shadcn CLI 產出
│   └── [feature]/        # 依 feature 切，別照元件類型切
├── lib/
│   ├── utils.ts          # cn()
│   ├── validations/      # Zod schemas
│   └── api/              # TanStack Query hooks + fetcher
├── stores/               # Zustand
└── types/
```

## 3. TanStack Query Provider

```tsx
// src/app/providers.tsx
"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => new QueryClient({
    defaultOptions: {
      queries: { staleTime: 60_000, refetchOnWindowFocus: false },
    },
  }));
  return (
    <QueryClientProvider client={client}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

掛到 `src/app/layout.tsx` 的 `<body>` 外層。**務必設 `staleTime`**；預設 0 會讓每次 mount refetch。

## 4. State 職責分工

- **Server state**（API 資料、分頁、cache）→ TanStack Query，**不要塞 Zustand**。
- **Client state**（cart、UI 偏好、跨 3+ 元件共用） → Zustand。
- **Local state**（單一元件） → `useState`。

Zustand 範例（持久化 cart）：`create()(persist((set) => ({...}), { name: "cart" }))`.

## 5. Recommended Settings

`tsconfig.json`：`"strict": true`、`"noUncheckedIndexedAccess": true`、`"verbatimModuleSyntax": true`.

ESLint：開 `eslint-plugin-jsx-a11y`。

## 6. Verification Gate（必過）

```bash
npm run lint   # 目標 0 errors
npm run build  # 目標 Compiled successfully
```

常見錯誤：client hook 用在 server component → 檔頭加 `"use client"`；`@/` 解不到 → 檢查 `tsconfig.json` `paths`；型別對不上 → 補型別或 optional chain。

## 7. Don't

- 新專案不用 Pages Router（App Router only）。
- API data 不塞 Zustand（用 TanStack Query）。
- Client component 本體不要 `async function`（用 hook 抓資料）。
- Secrets 不加 `NEXT_PUBLIC_` 前綴（會打包到 bundle）。
