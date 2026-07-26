---
name: Tailwind CSS v4 Reference
---

# Tailwind CSS v4 Reference

## Table of Contents

1. [Setup and Configuration](#setup-and-configuration)
2. [@theme Configuration](#theme-configuration)
3. [Design Token Integration](#design-token-integration)
4. [Responsive Breakpoints and Container Queries](#responsive-breakpoints-and-container-queries)
5. [Dark Mode](#dark-mode)
6. [Custom Plugins](#custom-plugins)
7. [@apply Usage](#apply-usage)
8. [Arbitrary Values and Important Modifier](#arbitrary-values-and-important-modifier)
9. [Integration with Component Libraries](#integration-with-component-libraries)

---

## Setup and Configuration

Tailwind v4 採用 CSS-first 設定方式，不再需要 `tailwind.config.js`。所有設定直接寫在 CSS 中。

```bash
# 安裝 Tailwind CSS v4
npm install tailwindcss @tailwindcss/vite

# 或使用 PostCSS
npm install tailwindcss @tailwindcss/postcss
```

```ts
// vite.config.ts — Vite plugin 方式（推薦）
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [tailwindcss()],
});
```

```css
/* app.css — 進入點，取代舊版 @tailwind directives */
@import "tailwindcss";
```

---

## @theme Configuration

`@theme` 取代了 `tailwind.config.js` 中的 `theme.extend`，直接在 CSS 中定義 design tokens。

```css
@import "tailwindcss";

@theme {
  /* 色彩系統 */
  --color-primary: #3b82f6;
  --color-primary-dark: #1d4ed8;
  --color-surface: #ffffff;
  --color-surface-dim: #f8fafc;

  /* 字型 */
  --font-sans: "Inter", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", monospace;

  /* 間距比例 */
  --spacing-18: 4.5rem;
  --spacing-128: 32rem;

  /* 圓角 */
  --radius-card: 0.75rem;
  --radius-button: 0.5rem;

  /* 陰影 */
  --shadow-card: 0 1px 3px rgb(0 0 0 / 0.1), 0 1px 2px rgb(0 0 0 / 0.06);

  /* 動畫 */
  --animate-slide-in: slide-in 0.3s ease-out;
}

@keyframes slide-in {
  from { transform: translateY(-10px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}
```

使用上述 token 的 HTML：

```html
<div class="bg-surface rounded-card shadow-card p-6">
  <h2 class="font-sans text-primary">標題</h2>
  <p class="animate-slide-in">內容會滑入顯示</p>
</div>
```

清除預設值（使用 `--color-*: initial` 可移除所有預設色彩）：

```css
@theme {
  --color-*: initial; /* 移除所有預設色彩，只保留自訂色彩 */
  --color-brand: #6366f1;
  --color-neutral: #64748b;
}
```

---

## Design Token Integration

Tailwind v4 的 `@theme` 值會自動輸出為 CSS custom properties，可在非 Tailwind 程式碼中直接使用。

```css
/* @theme 中定義的 --color-primary 可直接在任何 CSS 中使用 */
.legacy-component {
  border-color: var(--color-primary);
  background: color-mix(in srgb, var(--color-primary) 10%, transparent);
}
```

從外部來源匯入 design tokens：

```css
@import "tailwindcss";
@import "./design-tokens.css"; /* 來自設計工具（如 Figma Tokens）匯出的 CSS */

@theme {
  --color-primary: var(--figma-color-primary);
  --color-secondary: var(--figma-color-secondary);
}
```

---

## Responsive Breakpoints and Container Queries

### 自訂 Breakpoints

```css
@theme {
  --breakpoint-xs: 30rem;   /* 480px */
  --breakpoint-sm: 40rem;   /* 640px */
  --breakpoint-md: 48rem;   /* 768px */
  --breakpoint-lg: 64rem;   /* 1024px */
  --breakpoint-xl: 80rem;   /* 1280px */
  --breakpoint-2xl: 96rem;  /* 1536px */
}
```

### Container Queries

Container queries 讓元件根據「父容器寬度」而非「視窗寬度」來調整樣式。

```html
<!-- 標記容器 -->
<div class="@container">
  <!-- 根據容器寬度切換排版 -->
  <div class="flex flex-col @md:flex-row @lg:gap-8 gap-4">
    <img class="w-full @md:w-1/3 rounded-lg" src="..." alt="" />
    <div class="flex-1">
      <h3 class="text-lg @lg:text-xl font-semibold">產品名稱</h3>
      <p class="hidden @sm:block text-sm text-gray-600">描述文字</p>
    </div>
  </div>
</div>

<!-- 具名容器 -->
<div class="@container/sidebar">
  <nav class="@sm/sidebar:flex-row flex flex-col">
    <!-- sidebar 寬度 >= sm 時切換為水平排列 -->
  </nav>
</div>
```

---

## Dark Mode

### Class Strategy（推薦，可由使用者切換）

```css
@import "tailwindcss";

/* v4 中 dark mode 預設使用 media strategy，改用 class strategy 需明確指定 */
/* 定義自訂 variant 一律用 @custom-variant；@variant 只能在自訂 CSS 區塊內套用既有 variant */
@custom-variant dark (&:where(.dark, .dark *));
```

```html
<html class="dark">
  <body class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
    <button class="bg-primary dark:bg-primary-dark rounded-button px-4 py-2">
      按鈕
    </button>
  </body>
</html>
```

### Media Strategy（跟隨系統偏好）

```css
/* v4 預設行為即為 media strategy，無需額外設定 */
@import "tailwindcss";
```

### 搭配 CSS custom properties 的 dark mode 模式

```css
@theme {
  --color-bg: #ffffff;
  --color-text: #1a1a2e;
}

/* 在 dark variant 中覆蓋 token */
.dark {
  --color-bg: #0f172a;
  --color-text: #e2e8f0;
}
```

---

## Custom Plugins

v4 使用 CSS-based plugins 或 JS plugins（透過 `@plugin` directive）。

```css
/* 引用 JS plugin */
@plugin "@tailwindcss/typography";
@plugin "@tailwindcss/forms";
```

```js
// my-plugin.js — 自訂 plugin
export default function ({ addUtilities, addComponents, theme }) {
  addUtilities({
    ".text-balance": { "text-wrap": "balance" },
    ".text-pretty": { "text-wrap": "pretty" },
  });

  addComponents({
    ".btn-base": {
      padding: `${theme("spacing.2")} ${theme("spacing.4")}`,
      borderRadius: theme("borderRadius.md"),
      fontWeight: theme("fontWeight.semibold"),
      transition: "all 150ms ease",
    },
  });
}
```

```css
@plugin "./my-plugin.js";
```

---

## @apply Usage

`@apply` 應謹慎使用。適合用於：無法直接寫 utility class 的場景（如第三方元件樣式覆蓋）。

```css
/* 合理使用：覆蓋第三方元件的樣式 */
.third-party-datepicker .day-cell {
  @apply rounded-md px-2 py-1 text-sm hover:bg-primary/10;
}

/* 合理使用：需大量重複的基礎樣式 */
.prose h2 {
  @apply text-xl font-bold tracking-tight mt-8 mb-4;
}
```

**避免**將 `@apply` 用於元件樣式 — 應改用 React/Vue 元件封裝 utility classes：

```tsx
// 推薦：用元件封裝而非 @apply
function Badge({ children, variant = "default" }: BadgeProps) {
  const styles = {
    default: "bg-gray-100 text-gray-800",
    success: "bg-green-100 text-green-800",
    danger: "bg-red-100 text-red-800",
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${styles[variant]}`}>
      {children}
    </span>
  );
}
```

---

## Arbitrary Values and Important Modifier

```html
<!-- Arbitrary values：使用方括號指定任意值 -->
<div class="top-[117px] grid-cols-[1fr_2fr_1fr] bg-[#1da1f2]">
  <!-- 任意 CSS property -->
  <p class="[text-wrap:balance] [hyphens:auto]">段落文字</p>
</div>

<!-- Important modifier：使用 ! 前綴強制覆蓋 -->
<div class="!mt-0 sm:!p-4">
  <!-- 這會產生 margin-top: 0 !important -->
</div>

<!-- Arbitrary variants -->
<div class="[&>svg]:w-5 [&>svg]:h-5 [&>svg]:text-gray-500">
  <svg>...</svg>
</div>

<!-- 搭配 data attributes -->
<div class="data-[state=open]:bg-gray-100 data-[state=open]:shadow-lg">
  Dropdown content
</div>
```

---

## Integration with Component Libraries

### shadcn/ui (React + Tailwind)

```tsx
// shadcn/ui 的 cn() utility — 合併 Tailwind class 的標準做法
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// 使用範例：覆蓋 shadcn 元件樣式
import { Button } from "@/components/ui/button";

<Button className={cn("bg-primary hover:bg-primary-dark", className)}>
  送出
</Button>
```

### Headless UI (Vue + Tailwind)

```vue
<template>
  <Listbox v-model="selected">
    <ListboxButton
      class="relative w-full cursor-default rounded-lg bg-white py-2 pl-3 pr-10
             text-left shadow-md focus:outline-none focus-visible:ring-2
             focus-visible:ring-primary/75"
    >
      {{ selected.name }}
    </ListboxButton>

    <transition
      leave-active-class="transition duration-100 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <ListboxOptions
        class="absolute mt-1 max-h-60 w-full overflow-auto rounded-md
               bg-white py-1 text-base shadow-lg ring-1 ring-black/5"
      >
        <ListboxOption
          v-for="item in items"
          :key="item.id"
          :value="item"
          v-slot="{ active, selected: isSelected }"
          class="relative cursor-default select-none py-2 pl-10 pr-4"
          :class="{ 'bg-primary/10 text-primary-dark': active }"
        >
          <span :class="isSelected ? 'font-medium' : 'font-normal'">
            {{ item.name }}
          </span>
        </ListboxOption>
      </ListboxOptions>
    </transition>
  </Listbox>
</template>
```
