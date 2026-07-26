---
name: React Component Patterns
---

# React Component Patterns

## Table of Contents
- [Function Component Structure](#function-component-structure)
- [Props Patterns](#props-patterns)
- [Custom Hooks Patterns](#custom-hooks-patterns)
- [Error Boundary](#error-boundary)
- [forwardRef + useImperativeHandle](#forwardref--useimperativehandle)
- [React.lazy + Suspense](#reactlazy--suspense)

---

## Function Component Structure

建議的元件結構順序：型別定義 -> hook 呼叫 -> 衍生狀態 -> 事件處理 -> 提早返回 -> JSX。

```tsx
// types 放在元件外部或獨立檔案
interface UserCardProps {
  userId: string;
  variant?: 'compact' | 'full';
  onSelect?: (id: string) => void;
}

export function UserCard({ userId, variant = 'full', onSelect }: UserCardProps) {
  // 1. hooks（所有 hook 必須在最上層，不可放在條件式中）
  const { data: user, isLoading } = useUser(userId);
  const [isExpanded, setIsExpanded] = useState(false);

  // 2. 衍生狀態（從 props/state 計算而來，不需額外 state）
  const displayName = user ? `${user.firstName} ${user.lastName}` : '';
  const isCompact = variant === 'compact';

  // 3. 事件處理函式
  const handleClick = () => onSelect?.(userId);

  // 4. 提早返回（loading / error / empty 狀態）
  if (isLoading) return <Skeleton />;
  if (!user) return null;

  // 5. JSX
  return (
    <article className="user-card" onClick={handleClick}>
      <h3>{displayName}</h3>
      {!isCompact && <p>{user.bio}</p>}
    </article>
  );
}
```

---

## Props Patterns

### Children Pattern

`children` 是最基本的組合模式，用於包裝型元件。

```tsx
interface CardProps {
  children: React.ReactNode;
  title?: string;
}

function Card({ children, title }: CardProps) {
  return (
    <div className="card">
      {title && <h2>{title}</h2>}
      <div className="card-body">{children}</div>
    </div>
  );
}
```

### Render Props

將渲染邏輯透過函式 prop 委派給呼叫者，適合需要共享內部狀態的場景。

```tsx
interface MouseTrackerProps {
  render: (position: { x: number; y: number }) => React.ReactNode;
}

function MouseTracker({ render }: MouseTrackerProps) {
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const handleMove = (e: React.MouseEvent) => setPos({ x: e.clientX, y: e.clientY });
  return <div onMouseMove={handleMove}>{render(pos)}</div>;
}

// 使用方式
<MouseTracker render={({ x, y }) => <span>座標: {x}, {y}</span>} />
```

### Compound Components

多個元件共享隱式狀態，對外提供乾淨的 API。常見於 Tabs、Accordion、Select。

```tsx
const TabsContext = createContext<{
  activeIndex: number;
  setActiveIndex: (i: number) => void;
} | null>(null);

function Tabs({ children, defaultIndex = 0 }: { children: React.ReactNode; defaultIndex?: number }) {
  const [activeIndex, setActiveIndex] = useState(defaultIndex);
  return (
    <TabsContext.Provider value={{ activeIndex, setActiveIndex }}>
      <div className="tabs">{children}</div>
    </TabsContext.Provider>
  );
}

function TabList({ children }: { children: React.ReactNode }) {
  return <div role="tablist">{children}</div>;
}

function Tab({ index, children }: { index: number; children: React.ReactNode }) {
  const ctx = useContext(TabsContext)!;
  return (
    <button role="tab" aria-selected={ctx.activeIndex === index} onClick={() => ctx.setActiveIndex(index)}>
      {children}
    </button>
  );
}

function TabPanel({ index, children }: { index: number; children: React.ReactNode }) {
  const ctx = useContext(TabsContext)!;
  return ctx.activeIndex === index ? <div role="tabpanel">{children}</div> : null;
}

// 掛載子元件到命名空間
Tabs.List = TabList;
Tabs.Tab = Tab;
Tabs.Panel = TabPanel;

// 使用方式 - API 乾淨、語意清楚
<Tabs defaultIndex={0}>
  <Tabs.List>
    <Tabs.Tab index={0}>總覽</Tabs.Tab>
    <Tabs.Tab index={1}>設定</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panel index={0}>總覽內容</Tabs.Panel>
  <Tabs.Panel index={1}>設定內容</Tabs.Panel>
</Tabs>
```

### Polymorphic Components

透過 `as` prop 讓元件渲染為任意 HTML 元素或其他元件，保留型別安全。

```tsx
type PolymorphicProps<E extends React.ElementType> = {
  as?: E;
  children: React.ReactNode;
} & Omit<React.ComponentPropsWithoutRef<E>, 'as' | 'children'>;

function Text<E extends React.ElementType = 'span'>({ as, children, ...props }: PolymorphicProps<E>) {
  const Component = as || 'span';
  return <Component {...props}>{children}</Component>;
}

// 使用方式：型別會根據 as 推導
<Text as="h1" className="title">標題</Text>
<Text as="a" href="/about">連結</Text>
<Text>預設為 span</Text>
```

---

## Custom Hooks Patterns

### Data Fetching Hook

封裝 API 請求邏輯，回傳 data / loading / error 三態。

```tsx
function useFetch<T>(url: string) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const controller = new AbortController();
    setIsLoading(true);
    fetch(url, { signal: controller.signal })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then(setData)
      .catch((err) => { if (err.name !== 'AbortError') setError(err); })
      .finally(() => setIsLoading(false));
    return () => controller.abort(); // cleanup 防止 race condition
  }, [url]);

  return { data, error, isLoading };
}
```

### Form Hook

管理表單欄位、驗證、提交狀態。

```tsx
function useForm<T extends Record<string, string>>(initialValues: T) {
  const [values, setValues] = useState(initialValues);
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleChange = (field: keyof T) => (e: React.ChangeEvent<HTMLInputElement>) => {
    setValues((prev) => ({ ...prev, [field]: e.target.value }));
    setErrors((prev) => ({ ...prev, [field]: undefined })); // 輸入時清除錯誤
  };

  const handleSubmit = (validate: (v: T) => typeof errors, onSubmit: (v: T) => Promise<void>) =>
    async (e: React.FormEvent) => {
      e.preventDefault();
      const validationErrors = validate(values);
      setErrors(validationErrors);
      if (Object.keys(validationErrors).length > 0) return;
      setIsSubmitting(true);
      try { await onSubmit(values); }
      finally { setIsSubmitting(false); }
    };

  return { values, errors, isSubmitting, handleChange, handleSubmit };
}
```

### Intersection Observer Hook

偵測元素是否進入可視區域，適用於 lazy load 和無限捲動。

```tsx
function useIntersection(options?: IntersectionObserverInit) {
  const ref = useRef<HTMLElement | null>(null);
  const [isIntersecting, setIsIntersecting] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new IntersectionObserver(([entry]) => {
      setIsIntersecting(entry.isIntersecting);
    }, options);
    observer.observe(el);
    return () => observer.disconnect();
  }, [options]);

  return { ref, isIntersecting };
}

// 使用方式
function LazyImage({ src, alt }: { src: string; alt: string }) {
  const { ref, isIntersecting } = useIntersection({ threshold: 0.1 });
  return <div ref={ref}>{isIntersecting && <img src={src} alt={alt} />}</div>;
}
```

---

## Error Boundary

### Class-Based（React 內建方式）

Error Boundary 必須使用 class component，因為 `getDerivedStateFromError` 沒有 hook 對應。

```tsx
interface ErrorBoundaryState { hasError: boolean; error: Error | null; }

class ErrorBoundary extends React.Component<
  { children: React.ReactNode; fallback?: React.ReactNode },
  ErrorBoundaryState
> {
  state: ErrorBoundaryState = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error('ErrorBoundary caught:', error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? <p>發生錯誤，請重新整理頁面。</p>;
    }
    return this.props.children;
  }
}
```

### react-error-boundary 套件（推薦）

提供 hook API、reset 機制和更彈性的 fallback。

```tsx
import { ErrorBoundary } from 'react-error-boundary';

function ErrorFallback({ error, resetErrorBoundary }: { error: Error; resetErrorBoundary: () => void }) {
  return (
    <div role="alert">
      <p>出了點問題：{error.message}</p>
      <button onClick={resetErrorBoundary}>重試</button>
    </div>
  );
}

// 使用方式：onReset 可用來清除導致錯誤的狀態
<ErrorBoundary FallbackComponent={ErrorFallback} onReset={() => queryClient.clear()}>
  <App />
</ErrorBoundary>
```

---

## React 19 Patterns（若目標為 React 19+）

React 19 對幾個常見 API 做了破壞性更新，新專案優先採用；維護中的 18 專案保留既有寫法。

### ref 作為一般 prop（取代 forwardRef）

```tsx
type ButtonProps = {
  ref?: React.Ref<HTMLButtonElement>;
} & React.ComponentPropsWithoutRef<'button'>;

function Button({ ref, children, ...props }: ButtonProps) {
  return <button ref={ref} {...props}>{children}</button>;
}
```

### useActionState（取代 useFormState）

搭配 `<form action={formAction}>` 管理 pending、error、result。

```tsx
import { useActionState } from 'react';

type FormState = { errors?: string[]; success?: boolean };

function Form() {
  const [state, formAction, isPending] = useActionState(submitAction, {});
  return <form action={formAction}>...</form>;
}
```

### use()：讀取 Promise / Context

可在條件式內使用（不同於 useContext），並能 unwrap 由 Server 傳入的 Promise，配合 Suspense 邊界。

```tsx
'use client';
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise); // suspend 直到 resolve
  return <div>{user.name}</div>;
}
```

注意：傳給 `use()` 的 Promise 不要在父層先 await，否則失去 streaming 的價值。

---

## forwardRef + useImperativeHandle

讓父元件透過 ref 呼叫子元件的命令式方法。常用於 focus、scroll、動畫控制。

版本分界：`useImperativeHandle` 兩版都照用；差別只在要不要 `forwardRef` 包裹。React 19 起 `ref` 已是一般 prop，`forwardRef` 被 deprecate（未移除，18 專案仍合法）。

```tsx
interface InputHandle {
  focus: () => void;
  clear: () => void;
}
```

### React 19+：ref 為一般 prop，不需 forwardRef

```tsx
function FancyInput({ ref, label }: { ref?: React.Ref<InputHandle>; label: string }) {
  const inputRef = useRef<HTMLInputElement>(null);

  useImperativeHandle(ref, () => ({
    focus: () => inputRef.current?.focus(),
    clear: () => { if (inputRef.current) inputRef.current.value = ''; },
  }));

  return <label>{label}<input ref={inputRef} /></label>;
}
```

### React 18：forwardRef 包裹（維護中的專案沿用）

```tsx
const FancyInput = forwardRef<InputHandle, { label: string }>(({ label }, ref) => {
  const inputRef = useRef<HTMLInputElement>(null);

  useImperativeHandle(ref, () => ({
    focus: () => inputRef.current?.focus(),
    clear: () => { if (inputRef.current) inputRef.current.value = ''; },
  }));

  return <label>{label}<input ref={inputRef} /></label>;
});
```

### 父元件使用（兩版相同）

```tsx
function Form() {
  const inputRef = useRef<InputHandle>(null);
  return (
    <>
      <FancyInput ref={inputRef} label="名稱" />
      <button onClick={() => inputRef.current?.focus()}>聚焦</button>
      <button onClick={() => inputRef.current?.clear()}>清除</button>
    </>
  );
}
```

---

## React.lazy + Suspense

動態載入元件，減少初始 bundle 大小。搭配 Suspense 顯示載入狀態。

```tsx
// 路由層級的 code splitting（最常見）
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));

function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}

// 元件層級的 code splitting（大型元件按需載入）
const HeavyChart = lazy(() => import('./components/HeavyChart'));

function AnalyticsPage() {
  const [showChart, setShowChart] = useState(false);
  return (
    <div>
      <button onClick={() => setShowChart(true)}>顯示圖表</button>
      {showChart && (
        <Suspense fallback={<div>載入圖表中...</div>}>
          <HeavyChart />
        </Suspense>
      )}
    </div>
  );
}
```

### Named Export 的 lazy 載入

`React.lazy` 僅支援 default export。若需 named export，使用中間模組重新匯出。

```tsx
// 方法：在 import 時轉換
const MyComponent = lazy(() =>
  import('./components').then((mod) => ({ default: mod.MyComponent }))
);
```
