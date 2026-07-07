---
name: Native CSS Features and CSS Modules Reference
---

# Native CSS Features and CSS Modules Reference

## Table of Contents

1. [CSS Nesting](#css-nesting)
2. [@layer Cascade Control](#layer-cascade-control)
3. [:has() Selector](#has-selector)
4. [Container Queries](#container-queries)
5. [@scope](#scope)
6. [CSS Custom Properties Advanced Patterns](#css-custom-properties-advanced-patterns)
7. [CSS Modules](#css-modules)
8. [PostCSS Configuration](#postcss-configuration)
9. [CSS Logical Properties](#css-logical-properties)

---

## CSS Nesting

原生 CSS nesting 已獲主流瀏覽器支援。`&` 代表父選擇器。

```css
/* 基本 nesting — & 可省略（當子選擇器以元素或類別開頭時） */
.card {
  padding: 1rem;
  border-radius: 0.5rem;

  & .title {
    font-size: 1.25rem;
    font-weight: 600;
  }

  & .body {
    color: #64748b;
    line-height: 1.6;
  }

  /* 偽類和偽元素 */
  &:hover {
    box-shadow: 0 4px 12px rgb(0 0 0 / 0.1);
  }

  &::before {
    content: "";
    display: block;
  }

  /* Media query nesting */
  @media (width >= 768px) {
    padding: 2rem;
  }

  /* 組合選擇器 — & 代表 .card */
  .sidebar & {
    padding: 0.5rem;
  }
}
```

注意：`@nest` 是早期草案語法，**已被移除**，目前標準只使用 `&`。

---

## @layer Cascade Control

`@layer` 控制樣式的優先順序，無論宣告位置。先宣告的 layer 優先權較低。

```css
/* 宣告 layer 順序（優先權由低到高） */
@layer reset, base, components, utilities;

@layer reset {
  *, *::before, *::after {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
}

@layer base {
  body {
    font-family: system-ui, sans-serif;
    line-height: 1.5;
    color: #1a1a2e;
  }

  a {
    color: inherit;
    text-decoration-thickness: 1px;
    text-underline-offset: 2px;
  }
}

@layer components {
  .btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-weight: 500;
    cursor: pointer;
  }

  .btn-primary {
    background: var(--color-primary);
    color: white;
  }
}

@layer utilities {
  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }
}
```

不在任何 layer 中的樣式具有**最高優先權**，可用於緊急覆蓋。

---

## :has() Selector

`:has()` 是「父選擇器」，根據子元素狀態選取父元素。瀏覽器支援已廣泛。

```css
/* 當 form 內有無效 input 時，顯示錯誤邊框 */
form:has(:invalid) {
  border: 2px solid #ef4444;
  padding: 1rem;
}

/* 當 .card 有圖片時，調整排版 */
.card:has(img) {
  display: grid;
  grid-template-rows: 200px 1fr;
}

.card:not(:has(img)) {
  padding: 2rem;
}

/* 當 checkbox 被勾選時，改變兄弟元素樣式 */
.todo-item:has(input:checked) .todo-text {
  text-decoration: line-through;
  opacity: 0.6;
}

/* 根據子元素數量調整 grid */
.grid:has(> :nth-child(4)) {
  grid-template-columns: repeat(2, 1fr);
}

.grid:has(> :nth-child(7)) {
  grid-template-columns: repeat(3, 1fr);
}

/* 表單欄位驗證狀態 */
.field:has(input:focus) label {
  color: var(--color-primary);
  transform: translateY(-2px);
}

.field:has(input:invalid:not(:placeholder-shown)) label {
  color: #ef4444;
}
```

---

## Container Queries

元件根據其容器大小（而非 viewport）調整樣式。

```css
/* 定義容器 */
.widget-container {
  container-type: inline-size;  /* 根據寬度查詢 */
  container-name: widget;       /* 具名容器（可選） */
}

/* 簡寫 */
.sidebar {
  container: sidebar / inline-size;
}

/* 根據容器寬度調整子元素 */
@container (min-width: 400px) {
  .widget-content {
    display: flex;
    gap: 1rem;
  }
}

@container (min-width: 700px) {
  .widget-content {
    gap: 2rem;
  }
  .widget-content .detail {
    font-size: 1.125rem;
  }
}

/* 使用具名容器 */
@container sidebar (max-width: 250px) {
  .nav-label {
    display: none;  /* sidebar 窄時隱藏文字，只顯示 icon */
  }
}

/* Container query units */
.responsive-text {
  font-size: clamp(0.875rem, 3cqi, 1.5rem); /* cqi = container query inline */
}
```

```html
<div class="widget-container">
  <article class="widget-content">
    <img src="thumb.jpg" alt="" />
    <div class="detail">
      <h3>標題</h3>
      <p>描述文字會根據容器寬度調整排版</p>
    </div>
  </article>
</div>
```

---

## @scope

`@scope` 限制樣式作用範圍，無需 JS 框架的 scoped styles。

```css
/* 基本 scope — 樣式只套用在 .card 內部 */
@scope (.card) {
  h2 {
    font-size: 1.25rem;
    margin-bottom: 0.5rem;
  }

  p {
    color: #64748b;
  }

  a {
    color: var(--color-primary);
  }
}

/* 上下限 scope — 只影響 .card 到 .card-footer 之間的內容 */
@scope (.card) to (.card-footer) {
  p {
    line-height: 1.8;
  }
}
```

---

## CSS Custom Properties Advanced Patterns

### 基礎 fallback 與計算

```css
:root {
  --spacing-unit: 0.25rem;
  --color-primary: #3b82f6;
  --color-primary-h: 217;
  --color-primary-s: 91%;
  --color-primary-l: 60%;
}

.box {
  /* fallback 值 */
  padding: var(--padding, 1rem);

  /* calc() 搭配 custom properties */
  margin-bottom: calc(var(--spacing-unit) * 6);    /* 1.5rem */

  /* 巢狀 var() */
  color: var(--text-color, var(--color-primary, blue));
}
```

### color-mix() 產生色彩變體

```css
.btn-primary {
  background: var(--color-primary);

  &:hover {
    /* 混合 20% 黑色 = 較深 */
    background: color-mix(in srgb, var(--color-primary) 80%, black);
  }

  &:active {
    background: color-mix(in srgb, var(--color-primary) 70%, black);
  }

  &:disabled {
    /* 混合 50% 白色 = 較淡 */
    background: color-mix(in srgb, var(--color-primary) 50%, white);
  }
}

/* 自動產生透明度變體 */
.overlay {
  background: color-mix(in srgb, var(--color-primary) 15%, transparent);
}
```

### @property 定義型別安全的 custom properties

```css
@property --gradient-angle {
  syntax: "<angle>";
  initial-value: 0deg;
  inherits: false;
}

@property --color-alpha {
  syntax: "<number>";
  initial-value: 1;
  inherits: true;
}

/* 搭配動畫（只有 @property 定義的才能做轉場動畫） */
.gradient-border {
  --gradient-angle: 0deg;
  border-image: linear-gradient(var(--gradient-angle), #3b82f6, #8b5cf6) 1;
  transition: --gradient-angle 0.5s ease;

  &:hover {
    --gradient-angle: 180deg;
  }
}
```

---

## CSS Modules

CSS Modules 自動產生唯一 class name，避免全域衝突。

### Vite 設定（內建支援）

```ts
// vite.config.ts
export default defineConfig({
  css: {
    modules: {
      localsConvention: "camelCaseOnly", // .my-class → styles.myClass
      generateScopedName: "[name]__[local]___[hash:base64:5]",
    },
  },
});
```

### 使用方式

```css
/* Button.module.css */
.root {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
}

.primary {
  composes: root;
  background: var(--color-primary);
  color: white;
}

.icon {
  width: 1.25rem;
  height: 1.25rem;
}

/* :global 跳脫 module scope */
.root :global(.external-lib-class) {
  margin: 0;
}
```

```tsx
// Button.tsx
import styles from "./Button.module.css";

export function Button({ variant = "primary", children }: ButtonProps) {
  return (
    <button className={styles[variant]}>
      {children}
    </button>
  );
}
```

### TypeScript Typed Modules

```ts
// css-modules.d.ts — 放在專案根目錄或 src/
declare module "*.module.css" {
  const classes: { readonly [key: string]: string };
  export default classes;
}
```

使用 `typed-css-modules` 工具產生精確型別：

```bash
npm install -D typed-css-modules
npx tcm src  # 產生 .module.css.d.ts 檔案
```

---

## PostCSS Configuration

```js
// postcss.config.js
export default {
  plugins: {
    "postcss-import": {},          // @import 解析
    "postcss-nesting": {},         // CSS nesting（若需支援舊瀏覽器）
    "autoprefixer": {},            // 自動加 vendor prefix
    "cssnano": {                   // 壓縮（僅 production）
      preset: ["default", { discardComments: { removeAll: true } }],
    },
  },
};
```

注意：若使用 Tailwind v4，不需要額外的 PostCSS nesting plugin。

---

## CSS Logical Properties

Logical properties 讓版面自動適應書寫方向（LTR/RTL），對國際化（i18n）至關重要。

```css
/* 物理屬性 → 邏輯屬性對照 */
.card {
  /* margin-left / margin-right → margin-inline */
  margin-inline: auto;

  /* padding-left → padding-inline-start */
  padding-inline-start: 1.5rem;
  padding-inline-end: 1.5rem;

  /* padding-top / padding-bottom → padding-block */
  padding-block: 1rem;

  /* width → inline-size, height → block-size */
  max-inline-size: 600px;

  /* border-left → border-inline-start */
  border-inline-start: 3px solid var(--color-primary);

  /* text-align: left → text-align: start */
  text-align: start;

  /* top, bottom → inset-block; left, right → inset-inline */
  inset-block-start: 0;
}

/* Flexbox / Grid 中的邏輯方向 */
.nav {
  display: flex;
  gap: 1rem;
  /* row → 沿 inline axis, column → 沿 block axis */
  flex-direction: row; /* 在 RTL 中自動反轉 */
}

/* 完整的 i18n-friendly 元件範例 */
.alert {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding-block: 0.75rem;
  padding-inline: 1rem;
  border-inline-start: 4px solid var(--alert-color, #3b82f6);
  border-radius: 0.25rem;
  margin-block-end: 1rem;
}
```
