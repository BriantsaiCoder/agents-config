---
name: Type System Fundamentals
---

# Type System Fundamentals

寫新型別或解釋型別系統時讀取此檔案。涵蓋型別推斷、Union/Intersection、Literal Types、Template Literal Types、Conditional Types、Mapped Types、Index Access Types。

## Table of Contents
- [型別推斷 Best Practices](#型別推斷-best-practices)
- [Union Types](#union-types)
- [Intersection Types](#intersection-types)
- [Literal Types and const Assertions](#literal-types-and-const-assertions)
- [Template Literal Types](#template-literal-types)
- [Conditional Types](#conditional-types)
- [Mapped Types](#mapped-types)
- [Index Access Types](#index-access-types)

## 型別推斷 Best Practices

TypeScript 的推斷引擎非常強大。核心原則：**公開邊界標註、內部邏輯推斷**。

### 讓 TS 推斷的場景

```typescript
// 變數賦值 — 推斷為 number
const count = items.length;

// Array method chains — 推斷為 string[]
const names = users.map(u => u.name);

// Object literals — 推斷為 { id: string; name: string }
const user = { id: '123', name: 'Alice' };

// Callback 參數 — 從 context 推斷
const doubled = [1, 2, 3].map(n => n * 2); // n 是 number
```

### 必須明確標註的場景

```typescript
// 公開 API 的函數回傳值 — 防止意外改變 contract
export function getUser(id: string): User | null {
  // ...
}

// 空陣列初始化 — TS 無法推斷元素型別
const items: User[] = [];

// 複雜表達式的中間結果 — 增加可讀性
const filtered: ActiveUser[] = users.filter(isActive).map(toActiveUser);

// 物件 literal 搭配 satisfies — 保留推斷又檢查結構
const config = {
  port: 3000,
  host: 'localhost',
} satisfies ServerConfig;
```

### 過度標註的反面教材

```typescript
// ❌ Bad — 冗餘且脆弱，改型別要改兩處
const name: string = user.name;
const age: number = user.age;
const items: Array<string> = ['a', 'b', 'c'];
```

## Union Types

Union (`|`) 表示「其中之一」。使用前必須 narrow 到具體型別。

```typescript
type StringOrNumber = string | number;

function format(value: StringOrNumber): string {
  if (typeof value === 'string') {
    return value.toUpperCase(); // TS 知道是 string
  }
  return value.toFixed(2); // TS 知道是 number
}
```

### Union 的常見陷阱

```typescript
// ❌ 沒有 narrow 就存取 member-specific property
function bad(value: string | number) {
  return value.toUpperCase(); // Error: Property 'toUpperCase' does not exist on type 'number'
}

// ❌ 用 optional fields 替代 union — 允許不合法狀態
type BadState = { data?: User; error?: Error }; // data 和 error 可以同時存在

// ✅ Discriminated union — 狀態明確
type GoodState =
  | { status: 'success'; data: User }
  | { status: 'error'; error: Error }
  | { status: 'loading' };
```

## Intersection Types

Intersection (`&`) 表示「同時是」。合併多個型別的所有 properties。

```typescript
type WithId = { id: string };
type WithTimestamps = { createdAt: Date; updatedAt: Date };

// User 同時有 id, name, createdAt, updatedAt
type User = WithId & WithTimestamps & { name: string };
```

### 注意事項

```typescript
// 兩個型別有同名 property 但型別衝突 → 結果是 never
type A = { x: string };
type B = { x: number };
type C = A & B; // C['x'] 是 string & number → never

// ✅ 用 interface extends 取代，會在定義時就報錯
interface Base { x: string }
// interface Derived extends Base { x: number } // Error at definition time
```

## Literal Types and const Assertions

Literal types 把值本身當作型別，比 `string`/`number` 更精確。

```typescript
// let 推斷為 string；const 推斷為 literal
let status = 'active';     // type: string
const status2 = 'active';  // type: 'active'

// as const 強制 literal 推斷
const config = {
  mode: 'production' as const, // type: 'production'
  port: 3000 as const,         // type: 3000
};

// 整個物件 as const — 所有 properties 變成 readonly literal
const CONFIG = {
  mode: 'production',
  port: 3000,
  features: ['auth', 'logging'],
} as const;
// type: { readonly mode: 'production'; readonly port: 3000; readonly features: readonly ['auth', 'logging'] }

// 從 as const 陣列提取 union type
const ROLES = ['admin', 'user', 'guest'] as const;
type Role = (typeof ROLES)[number]; // 'admin' | 'user' | 'guest'
```

### satisfies + as const 組合技

```typescript
// 檢查結構正確性，同時保留 literal 型別
const routes = {
  home: '/',
  about: '/about',
  user: '/user/:id',
} as const satisfies Record<string, string>;

type RouteName = keyof typeof routes; // 'home' | 'about' | 'user'
type RoutePath = (typeof routes)[RouteName]; // '/' | '/about' | '/user/:id'
```

## Template Literal Types

從 string literal 組合出新型別。適合 event names、route paths、CSS 等。

```typescript
// 基本組合 — 產生所有排列
type EventName = `on${Capitalize<'click' | 'focus' | 'blur'>}`;
// 'onClick' | 'onFocus' | 'onBlur'

type HTTPMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';
type APIRoute = '/users' | '/orders';
type Endpoint = `${HTTPMethod} ${APIRoute}`;
// 'GET /users' | 'GET /orders' | 'POST /users' | ... (8 combinations)
```

### 從 string 抽取部分（搭配 infer）

```typescript
type ExtractParam<T extends string> =
  T extends `${string}:${infer Param}/${infer Rest}`
    ? Param | ExtractParam<Rest>
    : T extends `${string}:${infer Param}`
      ? Param
      : never;

type Params = ExtractParam<'/users/:userId/posts/:postId'>;
// 'userId' | 'postId'
```

### 實用：建構 CSS unit 型別

```typescript
type CSSUnit = 'px' | 'rem' | 'em' | '%' | 'vh' | 'vw';
type CSSValue = `${number}${CSSUnit}` | 'auto' | '0';

function setWidth(value: CSSValue) { /* ... */ }
setWidth('100px');  // ✅
setWidth('2rem');   // ✅
// setWidth('abc'); // ❌
```

## Conditional Types

`T extends U ? X : Y` — 型別層面的三元運算。

```typescript
// 基本形式
type IsString<T> = T extends string ? true : false;
type A = IsString<'hello'>; // true
type B = IsString<42>;      // false
```

### Distributive behavior

Union 的每個 member 分別套用 conditional type：

```typescript
type ToArray<T> = T extends unknown ? T[] : never;
type C = ToArray<string | number>; // string[] | number[]

// 避免 distribute — 用 tuple 包起來
type ToArrayNonDist<T> = [T] extends [unknown] ? T[] : never;
type D = ToArrayNonDist<string | number>; // (string | number)[]
```

### infer keyword

在 conditional type 中「捕獲」子型別。只能在 `extends` 的右邊使用。

```typescript
// 抽取函數的回傳型別（ReturnType 的實作）
type MyReturnType<T> = T extends (...args: any[]) => infer R ? R : never;

// 抽取 Promise 的內層型別（遞迴 unwrap）
type UnwrapPromise<T> = T extends Promise<infer U> ? UnwrapPromise<U> : T;
type E = UnwrapPromise<Promise<Promise<string>>>; // string

// 抽取陣列元素型別
type ElementOf<T> = T extends (infer E)[] ? E : never;
type F = ElementOf<string[]>; // string

// 抽取物件 value 型別
type ValueOf<T> = T extends Record<string, infer V> ? V : never;
```

## Mapped Types

從現有型別產生新型別，逐一轉換每個 property。

```typescript
// 把所有 property 變成 optional（Partial 的實作）
type MyPartial<T> = { [K in keyof T]?: T[K] };

// 把所有 property 變成 readonly
type MyReadonly<T> = { readonly [K in keyof T]: T[K] };

// 重新 map key 名稱（key remapping, TS 4.1+）
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K]
};
type UserGetters = Getters<{ name: string; age: number }>;
// { getName: () => string; getAge: () => number }

// 過濾 property — 只保留 string 型別的 properties
type OnlyStrings<T> = {
  [K in keyof T as T[K] extends string ? K : never]: T[K]
};
```

### Mapped type modifiers

```typescript
// 移除 modifier 用 -
type Mutable<T> = { -readonly [K in keyof T]: T[K] };  // 移除 readonly
type MyRequired<T> = { [K in keyof T]-?: T[K] };        // 移除 optional
```

### 實用組合：把特定 keys 變 optional

```typescript
type PartialBy<T, K extends keyof T> =
  Omit<T, K> & Partial<Pick<T, K>>;

type User = { id: string; name: string; email: string };
type CreateUser = PartialBy<User, 'id'>; // id 變 optional
```

## Index Access Types

用 key 存取型別的 property 型別。

```typescript
type User = { id: string; name: string; age: number };

type UserId = User['id'];              // string
type NameOrAge = User['name' | 'age']; // string | number
type AllValues = User[keyof User];     // string | number
```

### 搭配陣列

```typescript
const roles = ['admin', 'user', 'guest'] as const;
type Role = (typeof roles)[number]; // 'admin' | 'user' | 'guest'
```

### 深層存取

```typescript
type Order = { user: { address: { city: string } } };
type City = Order['user']['address']['city']; // string
```

### 從 as const 物件提取型別

```typescript
const STATUS = {
  Active: 'active',
  Inactive: 'inactive',
  Pending: 'pending',
} as const;

type StatusKey = keyof typeof STATUS;               // 'Active' | 'Inactive' | 'Pending'
type StatusValue = (typeof STATUS)[keyof typeof STATUS]; // 'active' | 'inactive' | 'pending'
```

### 搭配 generic constraint

```typescript
// 確保 key 存在於物件中
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

const user = { id: '1', name: 'Alice', age: 30 };
const name = getProperty(user, 'name'); // string
// getProperty(user, 'invalid');        // ❌ 編譯錯誤
```
