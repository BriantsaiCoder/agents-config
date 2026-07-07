---
name: React State Management
---

# React State Management

## Table of Contents
- [useState vs useReducer](#usestate-vs-usereducer)
- [Context API](#context-api)
- [Zustand](#zustand)
- [Redux Toolkit](#redux-toolkit)
- [TanStack Query](#tanstack-query)
- [Decision Tree](#decision-tree)

---

## useState vs useReducer

### useState：適合簡單、獨立的狀態

```tsx
function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount((c) => c + 1)}>計數: {count}</button>;
}
```

### useReducer：適合複雜狀態邏輯、多個相關狀態值

當下一個狀態依賴多個條件，或多個 action 需要操作同一組狀態時使用。

```tsx
interface FormState {
  status: 'idle' | 'submitting' | 'success' | 'error';
  data: Record<string, string>;
  error: string | null;
}

type FormAction =
  | { type: 'FIELD_CHANGE'; field: string; value: string }
  | { type: 'SUBMIT' }
  | { type: 'SUCCESS' }
  | { type: 'ERROR'; error: string };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case 'FIELD_CHANGE':
      return { ...state, data: { ...state.data, [action.field]: action.value }, error: null };
    case 'SUBMIT':
      return { ...state, status: 'submitting', error: null };
    case 'SUCCESS':
      return { ...state, status: 'success' };
    case 'ERROR':
      return { ...state, status: 'error', error: action.error };
    default:
      return state;
  }
}

function RegistrationForm() {
  const [state, dispatch] = useReducer(formReducer, {
    status: 'idle',
    data: { name: '', email: '' },
    error: null,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    dispatch({ type: 'SUBMIT' });
    try {
      await api.register(state.data);
      dispatch({ type: 'SUCCESS' });
    } catch (err) {
      dispatch({ type: 'ERROR', error: (err as Error).message });
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        value={state.data.name}
        onChange={(e) => dispatch({ type: 'FIELD_CHANGE', field: 'name', value: e.target.value })}
      />
      {state.error && <p className="error">{state.error}</p>}
      <button disabled={state.status === 'submitting'}>送出</button>
    </form>
  );
}
```

**選擇準則**：狀態轉換有明確規則 -> useReducer；單一布林/字串值 -> useState。

---

## Context API

### 基本用法

適合**低頻變更**的全域狀態（主題、語系、當前使用者）。

```tsx
interface AuthContextValue {
  user: User | null;
  login: (credentials: Credentials) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

// 自訂 hook，確保只在 Provider 內使用
function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth 必須在 AuthProvider 內使用');
  return ctx;
}

function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);

  const login = async (credentials: Credentials) => {
    const user = await api.login(credentials);
    setUser(user);
  };
  const logout = () => { setUser(null); api.logout(); };

  // useMemo 避免每次 render 都產生新物件，導致所有 consumer 重新渲染
  const value = useMemo(() => ({ user, login, logout }), [user]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
```

### 效能陷阱與優化

Context 值變更時，**所有** consumer 都會重新渲染，即使它只用到部分欄位。

```tsx
// 問題：state 和 dispatch 綁在一起，dispatch 永遠不變卻跟著 state 重新渲染
// 解法：拆分 Context
const StateCtx = createContext<AppState | null>(null);
const DispatchCtx = createContext<React.Dispatch<AppAction> | null>(null);

function AppProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(appReducer, initialState);
  return (
    <DispatchCtx.Provider value={dispatch}>
      <StateCtx.Provider value={state}>{children}</StateCtx.Provider>
    </DispatchCtx.Provider>
  );
}

// 只需要 dispatch 的元件不會因 state 變更而重新渲染
function AddButton() {
  const dispatch = useContext(DispatchCtx)!;
  return <button onClick={() => dispatch({ type: 'ADD' })}>新增</button>;
}
```

---

## Zustand

輕量級狀態管理，無 Provider、無 boilerplate。適合中型應用的客戶端狀態。

### Store 建立與 Selector

```tsx
import { create } from 'zustand';

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  total: () => number;
}

const useCartStore = create<CartStore>((set, get) => ({
  items: [],
  addItem: (item) => set((state) => ({ items: [...state.items, item] })),
  removeItem: (id) => set((state) => ({ items: state.items.filter((i) => i.id !== id) })),
  total: () => get().items.reduce((sum, i) => sum + i.price * i.qty, 0),
}));

// Selector：只訂閱需要的欄位，避免不必要的重新渲染
function CartCount() {
  const count = useCartStore((s) => s.items.length); // 只在 length 變化時重新渲染
  return <span>購物車: {count}</span>;
}

function CartTotal() {
  const total = useCartStore((s) => s.total());
  return <span>總計: ${total}</span>;
}
```

### Middleware

```tsx
import { create } from 'zustand';
import { persist, devtools } from 'zustand/middleware';

const useSettingsStore = create<SettingsState>()(
  devtools(
    persist(
      (set) => ({
        theme: 'light' as const,
        locale: 'zh-TW',
        setTheme: (theme: 'light' | 'dark') => set({ theme }),
        setLocale: (locale: string) => set({ locale }),
      }),
      {
        name: 'app-settings', // localStorage key
        partialize: (state) => ({ theme: state.theme, locale: state.locale }), // 只持久化資料，不存函式
      }
    ),
    { name: 'SettingsStore' } // DevTools 顯示名稱
  )
);
```

### Zustand vs Redux

| 面向 | Zustand | Redux Toolkit |
|------|---------|---------------|
| Bundle 大小 | ~1KB | ~11KB |
| Boilerplate | 極少 | 中等（slice + store） |
| DevTools | 透過 middleware | 內建 |
| 非同步邏輯 | 直接在 action 中 | thunk / RTK Query |
| 適用規模 | 小到中型 | 中到大型 |

---

## Redux Toolkit

大型應用的標準選擇。RTK 大幅簡化了傳統 Redux 的樣板程式碼。

### Slice

```tsx
import { createSlice, type PayloadAction } from '@reduxjs/toolkit';

interface TodoState { items: Todo[]; filter: 'all' | 'active' | 'done'; }

const todoSlice = createSlice({
  name: 'todos',
  initialState: { items: [], filter: 'all' } as TodoState,
  reducers: {
    addTodo(state, action: PayloadAction<string>) {
      // Immer 讓你可以直接 mutate（內部會產生新物件）
      state.items.push({ id: crypto.randomUUID(), text: action.payload, done: false });
    },
    toggleTodo(state, action: PayloadAction<string>) {
      const todo = state.items.find((t) => t.id === action.payload);
      if (todo) todo.done = !todo.done;
    },
    setFilter(state, action: PayloadAction<TodoState['filter']>) {
      state.filter = action.payload;
    },
  },
});

export const { addTodo, toggleTodo, setFilter } = todoSlice.actions;
export default todoSlice.reducer;
```

### RTK Query

內建於 RTK 的資料擷取與快取方案，自動產生 hooks。

```tsx
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';

const api = createApi({
  baseQuery: fetchBaseQuery({ baseUrl: '/api' }),
  tagTypes: ['Product'],
  endpoints: (build) => ({
    getProducts: build.query<Product[], void>({
      query: () => '/products',
      providesTags: ['Product'],
    }),
    addProduct: build.mutation<Product, Partial<Product>>({
      query: (body) => ({ url: '/products', method: 'POST', body }),
      invalidatesTags: ['Product'], // mutation 成功後自動重新擷取
    }),
  }),
});

export const { useGetProductsQuery, useAddProductMutation } = api;
```

---

## TanStack Query

專注於**伺服器狀態**管理。自動處理快取、重新擷取、stale/fresh 機制。

### Query 與 Mutation

```tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

function UserProfile({ userId }: { userId: string }) {
  const { data, isLoading, error } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetch(`/api/users/${userId}`).then((r) => r.json()),
    staleTime: 5 * 60 * 1000, // 5 分鐘內視為 fresh，不會自動重新擷取
  });

  if (isLoading) return <Skeleton />;
  if (error) return <p>載入失敗</p>;
  return <h1>{data.name}</h1>;
}

function UpdateNameButton({ userId }: { userId: string }) {
  const queryClient = useQueryClient();
  const mutation = useMutation({
    mutationFn: (name: string) =>
      fetch(`/api/users/${userId}`, { method: 'PATCH', body: JSON.stringify({ name }) }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', userId] }); // 觸發重新擷取
    },
  });

  return <button onClick={() => mutation.mutate('新名稱')}>更新名稱</button>;
}
```

### Optimistic Updates

在伺服器回應前先更新 UI，失敗時 rollback。

```tsx
const mutation = useMutation({
  mutationFn: updateTodo,
  onMutate: async (newTodo) => {
    await queryClient.cancelQueries({ queryKey: ['todos'] });
    const previous = queryClient.getQueryData<Todo[]>(['todos']);
    queryClient.setQueryData<Todo[]>(['todos'], (old) =>
      old?.map((t) => (t.id === newTodo.id ? { ...t, ...newTodo } : t))
    );
    return { previous }; // 回傳 context 供 onError 使用
  },
  onError: (_err, _newTodo, context) => {
    queryClient.setQueryData(['todos'], context?.previous); // rollback
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['todos'] }); // 確保與伺服器同步
  },
});
```

### Infinite Query

```tsx
function InfiniteList() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
    queryKey: ['items'],
    queryFn: ({ pageParam }) => fetch(`/api/items?cursor=${pageParam}`).then((r) => r.json()),
    initialPageParam: '',
    getNextPageParam: (lastPage) => lastPage.nextCursor ?? undefined,
  });

  const allItems = data?.pages.flatMap((p) => p.items) ?? [];
  return (
    <div>
      {allItems.map((item) => <ItemCard key={item.id} item={item} />)}
      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          {isFetchingNextPage ? '載入中...' : '載入更多'}
        </button>
      )}
    </div>
  );
}
```

---

## Decision Tree

根據狀態的**擁有者**和**變更頻率**選擇方案：

| 狀態類型 | 建議方案 | 說明 |
|---------|---------|------|
| 元件內部 UI 狀態 | `useState` | 開關、輸入值、展開/收合 |
| 複雜元件邏輯 | `useReducer` | 表單、多步驟流程、狀態機 |
| 跨元件低頻狀態 | Context API | 主題、語系、認證 |
| 跨元件高頻狀態 | Zustand | 購物車、通知、即時 UI 狀態 |
| 大型應用全域狀態 | Redux Toolkit | 需要嚴格架構、時光旅行除錯 |
| 伺服器資料快取 | TanStack Query | API 資料擷取、快取、同步 |
| 表單狀態 | React Hook Form | 複雜表單驗證與效能 |
| URL 狀態 | Router params/search | 篩選、分頁、排序 |

**原則**：先用最簡單的方案，遇到瓶頸再升級。大多數應用只需要 `useState` + TanStack Query 即可涵蓋 90% 的需求。

## Jotai (Atomic State)

Atomic state management — granular updates with automatic dependency tracking.

```typescript
// atoms/userAtoms.ts
import { atom } from 'jotai'
import { atomWithStorage } from 'jotai/utils'

// Basic atom
export const userAtom = atom<User | null>(null)

// Derived atom (computed)
export const isAuthenticatedAtom = atom((get) => get(userAtom) \!== null)

// Atom with localStorage persistence
export const themeAtom = atomWithStorage<'light' | 'dark'>('theme', 'light')

// Async atom (Suspense-enabled)
export const userProfileAtom = atom(async (get) => {
  const user = get(userAtom)
  if (\!user) return null
  const response = await fetch(`/api/users/${user.id}/profile`)
  return response.json()
})

// Write-only atom (action)
export const logoutAtom = atom(null, (get, set) => {
  set(userAtom, null)
  localStorage.removeItem('token')
})

// Usage
function Profile() {
  const [user] = useAtom(userAtom)
  const [, logout] = useAtom(logoutAtom)
  const [profile] = useAtom(userProfileAtom)

  return (
    <Suspense fallback={<Skeleton />}>
      <ProfileContent profile={profile} onLogout={logout} />
    </Suspense>
  )
}
```

**When to choose Jotai:** atomic/granular updates, fine-grained subscription, Suspense-friendly async state, or when Redux/Zustand feel too heavy for your use case.

## Migration: Legacy Redux → Redux Toolkit

```typescript
// Before (legacy Redux)
const ADD_TODO = "ADD_TODO";
const addTodo = (text) => ({ type: ADD_TODO, payload: text });
function todosReducer(state = [], action) {
  switch (action.type) {
    case ADD_TODO:
      return [...state, { text: action.payload, completed: false }];
    default:
      return state;
  }
}

// After (Redux Toolkit with Immer)
const todosSlice = createSlice({
  name: "todos",
  initialState: [],
  reducers: {
    addTodo: (state, action: PayloadAction<string>) => {
      state.push({ text: action.payload, completed: false }); // Immer allows "mutations"
    },
  },
});
```

RTK eliminates action-type constants, manual immutability, and switch-case reducers via `createSlice` + Immer. Migration is incremental — wrap legacy `combineReducers` results inside `configureStore` and convert one slice at a time.
