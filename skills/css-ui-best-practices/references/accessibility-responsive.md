---
name: Accessibility and Responsive Design Reference
---

# Accessibility and Responsive Design Reference

## Table of Contents

1. [WCAG 2.2 AA Quick Checklist](#wcag-22-aa-quick-checklist)
2. [Color Contrast](#color-contrast)
3. [Keyboard Navigation Patterns](#keyboard-navigation-patterns)
4. [ARIA Quick Reference](#aria-quick-reference)
5. [Screen Reader Testing Basics](#screen-reader-testing-basics)
6. [Responsive Design Patterns](#responsive-design-patterns)
7. [Core Web Vitals CSS Impact](#core-web-vitals-css-impact)

---

## WCAG 2.2 AA Quick Checklist

### Perceivable（可感知）

- [ ] 所有非文字內容提供替代文字（`alt`, `aria-label`）
- [ ] 影片提供字幕；音訊提供逐字稿
- [ ] 色彩對比：一般文字 >= 4.5:1，大文字 >= 3:1
- [ ] 不僅以色彩傳達資訊（搭配圖示、文字、pattern）
- [ ] 頁面可放大至 200% 不遺失內容
- [ ] 文字間距可調整而不破版（1.5x 行高、2x 段距）

### Operable（可操作）

- [ ] 所有功能可透過鍵盤操作
- [ ] 無鍵盤陷阱（keyboard trap）
- [ ] 提供 skip link 跳過重複導覽
- [ ] Focus 順序合乎邏輯（DOM order = visual order）
- [ ] Focus indicator 清晰可見
- [ ] 可暫停、停止自動播放內容
- [ ] 拖放操作提供替代方式（WCAG 2.2 新增）

### Understandable（可理解）

- [ ] 頁面語言標示（`<html lang="zh-Hant">`）
- [ ] 表單欄位有明確 label
- [ ] 錯誤訊息明確指出問題並建議修正方式
- [ ] 導覽方式一致

### Robust（穩健）

- [ ] HTML 語法正確、無重複 ID
- [ ] 使用語意化標籤（`<nav>`, `<main>`, `<article>` 等）
- [ ] 自訂元件提供正確的 ARIA role 和狀態

---

## Color Contrast

### 工具

- **Chrome DevTools**: Elements panel > Styles > 點擊色彩值 > 顯示對比資訊
- **axe DevTools**: 瀏覽器擴充功能，自動偵測對比問題
- **Lighthouse**: Accessibility audit 包含對比檢查

### 使用 color-mix() 建立無障礙色板

```css
:root {
  --brand: #6366f1;

  /* 自動產生符合對比的文字色 — 混合足夠比例的黑/白 */
  --brand-on-light: color-mix(in srgb, var(--brand) 80%, black);  /* >= 4.5:1 on white */
  --brand-on-dark: color-mix(in srgb, var(--brand) 60%, white);   /* >= 4.5:1 on dark bg */

  /* 背景變體 */
  --brand-surface: color-mix(in srgb, var(--brand) 8%, white);    /* 淡背景 */
  --brand-muted: color-mix(in srgb, var(--brand) 25%, white);     /* 中等背景 */
}

/* 確保 focus ring 的對比度 */
:focus-visible {
  outline: 3px solid var(--brand);
  outline-offset: 2px;
  /* 至少 3:1 對比，對非文字元素適用 */
}
```

### 修正常見問題

```css
/* 問題：placeholder 文字對比不足 */
input::placeholder {
  color: #9ca3af; /* >= 4.5:1 on white */
  opacity: 1;     /* Firefox 預設降低 opacity */
}

/* 問題：disabled 狀態對比不足 */
button:disabled {
  color: #6b7280;            /* 不要用太淡的灰 */
  background: #e5e7eb;
  cursor: not-allowed;
}
```

---

## Keyboard Navigation Patterns

### Focus Trap（Modal / Dialog）

Modal 開啟時，focus 必須被限制在 modal 內部。

```html
<dialog id="modal" aria-labelledby="modal-title">
  <h2 id="modal-title">確認刪除</h2>
  <p>此操作無法復原。</p>
  <div class="modal-actions">
    <button id="cancel-btn">取消</button>
    <button id="confirm-btn" autofocus>確認刪除</button>
  </div>
</dialog>
```

```css
/* <dialog> 原生支援 focus trap，優先使用 */
dialog {
  max-width: min(90vw, 500px);
  padding: 2rem;
  border: none;
  border-radius: 0.75rem;
  box-shadow: 0 25px 50px rgb(0 0 0 / 0.25);
}

dialog::backdrop {
  background: rgb(0 0 0 / 0.5);
  backdrop-filter: blur(4px);
}
```

```js
// 原生 <dialog> 自動處理 focus trap
const modal = document.getElementById("modal");
modal.showModal(); // focus trap 自動啟用
modal.close();     // focus 自動回到觸發元素
```

### Roving Tabindex（Toolbar / Menu）

群組內只有一個元素在 tab 順序中，方向鍵在群組內移動。

```html
<div role="toolbar" aria-label="文字格式">
  <button role="radio" tabindex="0" aria-checked="false">粗體</button>
  <button role="radio" tabindex="-1" aria-checked="false">斜體</button>
  <button role="radio" tabindex="-1" aria-checked="false">底線</button>
</div>
```

```js
// Roving tabindex 邏輯
toolbar.addEventListener("keydown", (e) => {
  const buttons = [...toolbar.querySelectorAll("button")];
  const current = buttons.indexOf(document.activeElement);

  let next;
  if (e.key === "ArrowRight") next = (current + 1) % buttons.length;
  if (e.key === "ArrowLeft") next = (current - 1 + buttons.length) % buttons.length;

  if (next !== undefined) {
    buttons[current].tabIndex = -1;
    buttons[next].tabIndex = 0;
    buttons[next].focus();
  }
});
```

### Skip Link

```html
<a href="#main-content" class="skip-link">跳到主要內容</a>
<nav><!-- 導覽列 --></nav>
<main id="main-content" tabindex="-1"><!-- 主要內容 --></main>
```

```css
.skip-link {
  position: absolute;
  top: -100%;
  left: 1rem;
  z-index: 9999;
  padding: 0.75rem 1.5rem;
  background: var(--color-primary);
  color: white;
  border-radius: 0 0 0.5rem 0.5rem;
  font-weight: 600;
  text-decoration: none;
}

.skip-link:focus {
  top: 0;
}
```

---

## ARIA Quick Reference

### Landmark Roles

```html
<header role="banner">        <!-- 頁首，<header> 在 <body> 直接子層自動有此 role -->
<nav role="navigation">        <!-- 導覽 -->
<main role="main">             <!-- 主要內容 -->
<aside role="complementary">   <!-- 側邊欄 -->
<footer role="contentinfo">    <!-- 頁尾 -->
<form role="search">           <!-- 搜尋區域（WCAG 2.2 推薦用 <search> 元素） -->
```

### Live Regions

```html
<!-- 禮貌通知（等螢幕閱讀器唸完目前內容） -->
<div aria-live="polite" aria-atomic="true">
  已儲存成功
</div>

<!-- 緊急通知（立即插播） -->
<div role="alert">
  連線已中斷，請檢查網路
</div>

<!-- 狀態訊息 -->
<div role="status">
  搜尋到 42 筆結果
</div>
```

### 常用 States / Properties

```html
<!-- 展開/收合 -->
<button aria-expanded="false" aria-controls="panel-1">詳細資訊</button>
<div id="panel-1" hidden>面板內容</div>

<!-- 選取狀態 -->
<li role="option" aria-selected="true">選項 A</li>

<!-- 切換按鈕 -->
<button aria-pressed="false">靜音</button>

<!-- 載入中 -->
<div aria-busy="true" aria-live="polite">載入中...</div>

<!-- 錯誤關聯 -->
<input aria-invalid="true" aria-describedby="email-error" />
<p id="email-error" role="alert">請輸入有效的 Email</p>
```

---

## Screen Reader Testing Basics

### VoiceOver (macOS)

| 操作 | 快捷鍵 |
|------|---------|
| 開啟/關閉 | `Cmd + F5` |
| 下一個元素 | `Ctrl + Option + Right` |
| 上一個元素 | `Ctrl + Option + Left` |
| 啟動元素 | `Ctrl + Option + Space` |
| 開啟 Rotor（結構導覽） | `Ctrl + Option + U` |
| Heading 導覽 | Rotor 中選 Headings，用上下鍵 |

### NVDA (Windows) 基本操作

| 操作 | 快捷鍵 |
|------|---------|
| 開啟 | `Ctrl + Alt + N` |
| 停止朗讀 | `Ctrl` |
| 下一個 Heading | `H` |
| 下一個 Landmark | `D` |
| 表單模式切換 | `Enter` / `Esc` |
| 元素清單 | `NVDA + F7` |

測試重點：確認所有互動元素可被朗讀、操作，且狀態變化有通知。

---

## Responsive Design Patterns

### Fluid Typography（clamp）

```css
:root {
  /* clamp(最小值, 偏好值, 最大值) */
  --text-sm: clamp(0.8rem, 0.17vw + 0.76rem, 0.89rem);
  --text-base: clamp(1rem, 0.34vw + 0.91rem, 1.19rem);
  --text-lg: clamp(1.25rem, 0.61vw + 1.1rem, 1.58rem);
  --text-xl: clamp(1.56rem, 1vw + 1.31rem, 2.11rem);
  --text-2xl: clamp(1.95rem, 1.56vw + 1.56rem, 2.81rem);
}

h1 { font-size: var(--text-2xl); }
h2 { font-size: var(--text-xl); }
h3 { font-size: var(--text-lg); }
body { font-size: var(--text-base); }
small { font-size: var(--text-sm); }
```

### Container Queries for Components

```css
.product-card-wrapper {
  container: product / inline-size;
}

.product-card {
  display: grid;
  gap: 1rem;
  padding: 1rem;
}

/* 小容器：垂直排列 */
@container product (max-width: 299px) {
  .product-card {
    grid-template-columns: 1fr;
    text-align: center;
  }
  .product-card img {
    max-width: 200px;
    margin-inline: auto;
  }
}

/* 中容器：水平排列 */
@container product (min-width: 300px) {
  .product-card {
    grid-template-columns: 120px 1fr;
    align-items: start;
  }
}

/* 大容器：更寬鬆的排版 */
@container product (min-width: 500px) {
  .product-card {
    grid-template-columns: 200px 1fr;
    gap: 2rem;
    padding: 2rem;
  }
}
```

### Responsive Images

```html
<!-- srcset + sizes：讓瀏覽器選擇最佳圖片 -->
<img
  src="hero-800.jpg"
  srcset="hero-400.jpg 400w, hero-800.jpg 800w, hero-1200.jpg 1200w"
  sizes="(max-width: 600px) 100vw, (max-width: 1200px) 50vw, 600px"
  alt="產品展示圖"
  loading="lazy"
  decoding="async"
/>

<!-- <picture>：根據條件切換不同圖片 -->
<picture>
  <source media="(min-width: 1024px)" srcset="hero-desktop.avif" type="image/avif" />
  <source media="(min-width: 1024px)" srcset="hero-desktop.webp" type="image/webp" />
  <source media="(min-width: 640px)" srcset="hero-tablet.webp" type="image/webp" />
  <img src="hero-mobile.jpg" alt="首頁主視覺" width="800" height="450" />
</picture>
```

---

## Core Web Vitals CSS Impact

### CLS (Cumulative Layout Shift)

避免版面位移的 CSS 技巧。

```css
/* 圖片/影片預留空間 */
img, video {
  max-width: 100%;
  height: auto;
  aspect-ratio: 16 / 9; /* 預留正確比例空間，防止載入時跳動 */
}

/* 廣告/embed 預留空間 */
.ad-slot {
  min-height: 250px;
  aspect-ratio: 300 / 250;
  background: #f1f5f9;
}

/* 字型載入防跳動 */
@font-face {
  font-family: "CustomFont";
  src: url("/fonts/custom.woff2") format("woff2");
  font-display: swap;              /* 先用 fallback，載入後替換 */
  size-adjust: 105%;               /* 調整 fallback 字型大小以減少位移 */
  ascent-override: 90%;
  descent-override: 20%;
  line-gap-override: 0%;
}

/* 骨架屏防止空白跳動 */
.skeleton {
  background: linear-gradient(
    90deg,
    #e2e8f0 25%,
    #f1f5f9 50%,
    #e2e8f0 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: 0.25rem;
}

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

### LCP (Largest Contentful Paint)

```html
<!-- 預載關鍵 CSS -->
<link rel="preload" href="/fonts/custom.woff2" as="font" type="font/woff2" crossorigin />
<link rel="preload" href="/hero.webp" as="image" fetchpriority="high" />

<!-- 內聯 critical CSS（首屏所需的最小 CSS） -->
<style>
  /* 只放首屏渲染所需的樣式 */
  body { margin: 0; font-family: system-ui; }
  .hero { min-height: 60vh; }
</style>

<!-- 非關鍵 CSS 延後載入 -->
<link rel="stylesheet" href="/styles.css" media="print" onload="this.media='all'" />
```

### INP (Interaction to Next Paint)

```css
/* 使用 transform/opacity 做動畫 — 不觸發 layout/paint */
.drawer {
  transform: translateX(-100%);
  transition: transform 0.3s ease;
  will-change: transform;       /* 提示瀏覽器提前準備合成層 */
}

.drawer.open {
  transform: translateX(0);
}

/* 避免：觸發 layout 的屬性做動畫 */
/* BAD: transition: width, height, top, left, margin, padding */

/* content-visibility 延遲渲染螢幕外內容 */
.below-fold-section {
  content-visibility: auto;
  contain-intrinsic-size: 0 500px; /* 預估高度，避免滾動跳動 */
}

/* 減少動畫對效能的影響 */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### Performance Checklist

- [ ] 圖片設定 `width`/`height` 或 `aspect-ratio` 防止 CLS
- [ ] 字型使用 `font-display: swap` + `size-adjust`
- [ ] LCP 圖片加上 `fetchpriority="high"` 和 `preload`
- [ ] 動畫僅使用 `transform` 和 `opacity`
- [ ] 長頁面使用 `content-visibility: auto`
- [ ] 支援 `prefers-reduced-motion` 使用者偏好
- [ ] Critical CSS 內聯，其餘延後載入
- [ ] 避免 `@import` 串聯載入（改用 bundler 處理）
