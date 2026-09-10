---
name: React Performance Optimization
---

# React Performance Optimization

## Table of Contents
- [React Compiler](#react-compiler)
- [React.memo](#reactmemo)
- [useMemo and useCallback](#usememo-and-usecallback)
- [React DevTools Profiler](#react-devtools-profiler)
- [Code Splitting](#code-splitting)
- [React Server Components](#react-server-components)
- [Concurrent Features](#concurrent-features)
- [Virtualization](#virtualization)
- [Image Optimization](#image-optimization)

---

## React Compiler

Memoization 決策依 [root Golden Rule 6](../SKILL.md#golden-rules)：先確認 compiler 設定與量測結果，保留 identity-sensitive contracts；只有 evidence 或已要求的 modernization 才新增／移除 `memo`、`useMemo`、`useCallback`。啟用 compiler 本身不構成刪除既有 memo 的理由。

若既有 lint 設定的 `preserve-manual-memoization` 回報問題，先診斷依賴與 identity contract，再依 root 的 evidence 條件修正；不以直接刪除 memo 作預設。下例僅供已選用此 plugin／preset 的專案參考。

```js
// eslint.config.js（eslint-plugin-react-hooks v6+，recommended 預設走 flat config）
import reactHooks from 'eslint-plugin-react-hooks';
import { defineConfig } from 'eslint/config';

export default defineConfig([reactHooks.configs.flat.recommended]);
// 舊版 .eslintrc 走 recommended-legacy preset
```

以下手動 memo 範例只在量測或 identity contract 需要時採用；有無啟用 compiler，都沿用 root 的判斷條件。

---

## React.memo

用 `React.memo` 包裝元件，在 props 未變更時跳過重新渲染。

### 有效的場景

父元件頻繁渲染，但子元件的 props 穩定不變。

```tsx
interface ExpensiveListProps {
  items: Item[];
  onSelect: (id: string) => void;
}

const ExpensiveList = React.memo(function ExpensiveList({ items, onSelect }: ExpensiveListProps) {
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id} onClick={() => onSelect(item.id)}>{item.name}</li>
      ))}
    </ul>
  );
});
```

### 無效的常見錯誤

每次渲染都傳入新的物件/陣列/函式參考，導致 memo 永遠失效。

```tsx
// 錯誤：每次都產生新的 style 物件，memo 無效
<ExpensiveList items={items} style={{ padding: 10 }} />

// 正確：將穩定的物件提到外層或用 useMemo
const listStyle = useMemo(() => ({ padding: 10 }), []);
<ExpensiveList items={items} style={listStyle} />
```

### 自訂比較函式

預設使用 shallow compare。需要深度比較時可傳入第二個參數（謹慎使用，比較本身也有成本）。

```tsx
const Chart = React.memo(ChartComponent, (prev, next) => {
  return prev.data.length === next.data.length && prev.data.every((d, i) => d.value === next.data[i].value);
});
```

---

## useMemo and useCallback

### useMemo：快取計算結果

適用於**高成本計算**或需要**穩定參考**的物件。

```tsx
function ProductList({ products, query }: { products: Product[]; query: string }) {
  // 只在 products 或 query 變更時重新過濾
  const filtered = useMemo(
    () => products.filter((p) => p.name.toLowerCase().includes(query.toLowerCase())),
    [products, query]
  );

  return <ul>{filtered.map((p) => <ProductCard key={p.id} product={p} />)}</ul>;
}
```

### useCallback：快取函式參考

主要搭配 `React.memo` 子元件使用，確保傳下去的 callback 參考穩定。

```tsx
function Parent() {
  const [count, setCount] = useState(0);
  const [name, setName] = useState('');

  // 沒有 useCallback 的話，每次 Parent 渲染都會產生新函式，導致 MemoChild 重新渲染
  const handleClick = useCallback(() => {
    console.log('clicked');
  }, []);

  return (
    <>
      <input value={name} onChange={(e) => setName(e.target.value)} />
      <MemoChild onClick={handleClick} />
      <p>{count}</p>
    </>
  );
}

const MemoChild = React.memo(function MemoChild({ onClick }: { onClick: () => void }) {
  console.log('MemoChild rendered'); // 只在 onClick 參考變更時才會印出
  return <button onClick={onClick}>按我</button>;
});
```

### 何時不需要

- 計算成本很低（簡單的字串拼接、布林判斷）
- 子元件沒有用 `React.memo`
- 值只在當前元件使用且不傳給子元件

**原則**：先量測，再優化。不要預防性地到處加 useMemo/useCallback。

---

## React DevTools Profiler

### 使用方式

1. 安裝 React DevTools 瀏覽器擴充套件
2. 開啟 DevTools -> Profiler 面板
3. 點擊「Record」，操作 UI，再點擊「Stop」

### 閱讀 Flame Chart

- **每個長條**代表一個元件的渲染
- **寬度**代表渲染耗時（越寬越慢）
- **顏色**：黃色/橘色表示慢，藍色表示快，灰色表示未渲染
- **「Why did this render?」**（設定中開啟）顯示重新渲染的原因：props changed / state changed / parent rendered

### 常見問題模式

```
識別方式 -> 解法
────────────────────────────
灰色以外的元件在不該渲染時渲染 -> React.memo
同一元件反覆出現長條 -> useMemo/useCallback 穩定 props
某個元件的長條特別寬 -> 拆分元件 / 虛擬化 / lazy load
```

---

## Code Splitting

### Route-Based Splitting（最常見）

每個路由獨立 chunk，使用者只載入當前頁面的程式碼。

```tsx
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

const Home = lazy(() => import('./pages/Home'));
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));

function App() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}
```

### Component-Based Splitting

大型元件（圖表、編輯器、地圖）按需載入。

```tsx
const MarkdownEditor = lazy(() => import('./components/MarkdownEditor'));

function PostForm() {
  const [showEditor, setShowEditor] = useState(false);
  return (
    <div>
      <button onClick={() => setShowEditor(true)}>開啟編輯器</button>
      {showEditor && (
        <Suspense fallback={<div>載入編輯器...</div>}>
          <MarkdownEditor />
        </Suspense>
      )}
    </div>
  );
}
```

### Preload 技巧

在使用者可能需要之前提前載入。

```tsx
const Settings = lazy(() => import('./pages/Settings'));

// hover 時預載入
<Link to="/settings" onMouseEnter={() => import('./pages/Settings')}>
  設定
</Link>
```

---

## React Server Components

RSC 在伺服器端執行，不傳送 JavaScript 到客戶端。適用於靜態內容與資料擷取。

### 架構原則

```
Server Component（預設）: 資料擷取、存取後端、靜態 UI
    |
    v
Client Component（'use client'）: 互動、事件處理、useState/useEffect
```

### 使用時機

```tsx
// app/page.tsx - Server Component（預設），直接 await 資料
export default async function ProductPage({ params }: { params: { id: string } }) {
  const product = await db.product.findUnique({ where: { id: params.id } });
  return (
    <article>
      <h1>{product.name}</h1>
      <p>{product.description}</p>
      <AddToCartButton productId={product.id} /> {/* Client Component */}
    </article>
  );
}

// components/AddToCartButton.tsx - 需要互動，標記為 Client Component
'use client';
export function AddToCartButton({ productId }: { productId: string }) {
  const [added, setAdded] = useState(false);
  return <button onClick={() => { addToCart(productId); setAdded(true); }}>{added ? '已加入' : '加入購物車'}</button>;
}
```

### 關鍵限制

- Server Component 不能使用 useState、useEffect、事件處理
- Client Component 不能直接 import Server Component（可透過 children 傳入）
- 從 Server 傳給 Client 的 props 必須可序列化（不能傳函式）

---

## Concurrent Features

### useTransition

將低優先度的狀態更新標記為 transition，不阻擋使用者輸入。

```tsx
function SearchPage() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Item[]>([]);
  const [isPending, startTransition] = useTransition();

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setQuery(e.target.value); // 高優先度：立即更新輸入框
    startTransition(() => {
      setResults(filterItems(e.target.value)); // 低優先度：可被中斷
    });
  };

  return (
    <div>
      <input value={query} onChange={handleChange} />
      {isPending && <Spinner />}
      <ResultList items={results} />
    </div>
  );
}
```

### useDeferredValue

延遲更新某個值，類似 debounce 但由 React 排程控制。

```tsx
function SearchResults({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query);
  const isStale = query !== deferredQuery;

  const results = useMemo(() => filterExpensiveList(deferredQuery), [deferredQuery]);

  return (
    <div style={{ opacity: isStale ? 0.6 : 1 }}>
      {results.map((r) => <ResultCard key={r.id} result={r} />)}
    </div>
  );
}
```

### Activity（React 19.2+）

把暫時不顯示的子樹設為 `hidden`，React 會保留其 state 並以低優先度預先 render，切回時不需重新載入。取代「卸載後再重建」或手動保存 state 的做法。

```tsx
import { Activity } from 'react';

<Activity mode={tab === 'details' ? 'visible' : 'hidden'}>
  <Details id={id} />
</Activity>
```

注意：`hidden` 期間 state 保留但 effect 會被卸載，切回 `visible` 才重新掛載；同頁的 ViewTransition / addTransitionType 目前僅在 canary/experimental，勿用於 production。

---

## Virtualization

長列表只渲染可視區域內的項目，大幅降低 DOM 節點數。

### TanStack Virtual

```tsx
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50, // 每個項目預估高度 (px)
    overscan: 5, // 可視區域外多渲染 5 個項目，減少空白閃爍
  });

  return (
    <div ref={parentRef} style={{ height: '600px', overflow: 'auto' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map((virtualRow) => (
          <div
            key={virtualRow.key}
            style={{
              position: 'absolute',
              top: 0,
              transform: `translateY(${virtualRow.start}px)`,
              height: `${virtualRow.size}px`,
              width: '100%',
            }}
          >
            {items[virtualRow.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}
```

**效果**：10,000 筆資料的列表，DOM 中只有約 20-30 個節點。

---

## Image Optimization

### Next.js Image Component

自動處理 lazy loading、尺寸優化、WebP/AVIF 格式轉換。

```tsx
import Image from 'next/image';

// 固定尺寸（已知寬高）
<Image src="/hero.jpg" width={1200} height={600} alt="主視覺" priority />

// 填滿容器（響應式）
<div className="relative h-64 w-full">
  <Image src="/banner.jpg" fill className="object-cover" alt="橫幅" sizes="100vw" />
</div>
```

### 原生 HTML 最佳做法

不使用框架時的基本優化。

```tsx
function OptimizedImage({ src, alt }: { src: string; alt: string }) {
  return (
    <picture>
      <source srcSet={`${src}.avif`} type="image/avif" />
      <source srcSet={`${src}.webp`} type="image/webp" />
      <img
        src={`${src}.jpg`}
        alt={alt}
        loading="lazy"           // 瀏覽器原生 lazy loading
        decoding="async"         // 不阻擋主線程解碼
        width={800}
        height={400}             // 明確設定寬高避免 layout shift
      />
    </picture>
  );
}
```

### Responsive srcSet

```tsx
<img
  srcSet="/img/hero-400.jpg 400w, /img/hero-800.jpg 800w, /img/hero-1200.jpg 1200w"
  sizes="(max-width: 600px) 400px, (max-width: 1024px) 800px, 1200px"
  src="/img/hero-800.jpg"
  alt="響應式圖片"
  loading="lazy"
/>
```

**效能檢查清單**：
1. 首屏圖片加 `priority`（Next.js）或移除 `loading="lazy"`
2. 所有圖片設定明確的 `width` / `height` 或使用 `aspect-ratio`
3. 提供 WebP/AVIF 格式
4. 使用 `sizes` 告訴瀏覽器實際顯示尺寸
