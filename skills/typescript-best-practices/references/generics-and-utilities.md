---
name: Generics and Utility Types
---

# Generics & Utility Types

寫可重用泛型或需要進階型別操作時讀取此檔案。涵蓋 Generic patterns、所有內建 Utility Types、自訂 Utility Types、進階泛型設計模式。

## Table of Contents
- [Generic Patterns](#generic-patterns)
- [Generic Constraints (extends)](#generic-constraints-extends)
- [Default Type Parameters](#default-type-parameters)
- [Generic Inference Tips](#generic-inference-tips)
- [Built-in Utility Types: Object](#built-in-utility-types-object)
- [Built-in Utility Types: Function](#built-in-utility-types-function)
- [Built-in Utility Types: Promise and Filtering](#built-in-utility-types-promise-and-filtering)
- [Built-in Utility Types: String](#built-in-utility-types-string)
- [Custom Utility Types](#custom-utility-types)
- [Generic Function Patterns](#generic-function-patterns)
- [Anti-Patterns](#anti-patterns)

## Generic Patterns

泛型的目的是讓型別「隨輸入變化」。如果所有 call site 都傳同一型別，直接用該型別。

```typescript
// ✅ 回傳型別取決於輸入
function first<T>(arr: T[]): T | undefined {
  return arr[0];
}
const n = first([1, 2, 3]);  // number | undefined
const s = first(['a', 'b']); // string | undefined

// ✅ 兩個參數之間有關聯
function map<T, U>(arr: T[], fn: (item: T) => U): U[] {
  return arr.map(fn);
}

// ❌ 泛型沒有帶來任何好處 — 直接用 unknown
function badLog<T>(value: T): void { console.log(value); }
function goodLog(value: unknown): void { console.log(value); }
```

## Generic Constraints (extends)

用 `extends` 限制泛型的範圍，確保型別有需要的結構。

```typescript
// 確保有 length 屬性
function longest<T extends { length: number }>(a: T, b: T): T {
  return a.length >= b.length ? a : b;
}
longest('hello', 'hi');      // ✅ string has length
longest([1, 2], [1, 2, 3]);  // ✅ array has length
// longest(10, 20);           // ❌ number has no length

// Key 取決於 Object
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

// Record constraint — 確保是物件
function keys<T extends Record<string, unknown>>(obj: T): (keyof T)[] {
  return Object.keys(obj) as (keyof T)[];
}

// Function constraint
function memoize<T extends (...args: any[]) => any>(fn: T): T {
  const cache = new Map<string, ReturnType<T>>();
  return ((...args: Parameters<T>) => {
    const key = JSON.stringify(args);
    if (!cache.has(key)) cache.set(key, fn(...args));
    return cache.get(key)!;
  }) as T;
}
```

## Default Type Parameters

```typescript
// 提供合理預設值
type ApiResponse<T = unknown> = {
  data: T;
  status: number;
  timestamp: Date;
};

const raw: ApiResponse = { data: 'raw', status: 200, timestamp: new Date() };
const typed: ApiResponse<User> = { data: user, status: 200, timestamp: new Date() };

// 搭配 constraint
type Container<T extends HTMLElement = HTMLDivElement> = {
  element: T;
  children: Container<T>[];
};
```

## Generic Inference Tips

```typescript
// 把想推斷的參數放前面
function createPair<T, U>(first: T, second: U): [T, U] {
  return [first, second];
}
const pair = createPair('hello', 42); // [string, number]

// Helper function 輔助推斷（比直接標註好）
function defineConfig<T extends Record<string, unknown>>(config: T): T {
  return config;
}
const config = defineConfig({ port: 3000, host: 'localhost' });
// type: { port: number; host: string }

// satisfies 搭配泛型 — 檢查形狀但保留推斷
const routes = {
  home: { path: '/', exact: true },
  about: { path: '/about', exact: false },
} satisfies Record<string, { path: string; exact: boolean }>;
// routes.home.path 的型別是 '/'，不是 string
```

## Built-in Utility Types: Object

| Utility | 功能 | 使用場景 |
|---|---|---|
| `Partial<T>` | 所有 property 變 optional | Update payload |
| `Required<T>` | 所有 property 變 required | 確保完整性 |
| `Readonly<T>` | 所有 property 變 readonly | 防止意外修改 |
| `Pick<T, K>` | 只保留指定 keys | 建立子集 |
| `Omit<T, K>` | 移除指定 keys | 移除敏感欄位 |
| `Record<K, V>` | 建立 key-value 物件型別 | Map / lookup table |

```typescript
type User = { id: string; name: string; email: string; password: string };

// 實際使用
type PublicUser = Omit<User, 'password'>;
type UserUpdate = Partial<Pick<User, 'name' | 'email'>>;
type UserMap = Record<string, User>;
type ReadonlyUser = Readonly<User>;

// 組合使用
type CreateUserInput = Required<Omit<User, 'id'>>; // 不需要 id，其他必填
```

## Built-in Utility Types: Function

| Utility | 功能 |
|---|---|
| `ReturnType<T>` | 抽取函數回傳型別 |
| `Parameters<T>` | 抽取函數參數型別（tuple） |
| `ConstructorParameters<T>` | 抽取 constructor 參數 |
| `InstanceType<T>` | 抽取 class instance 型別 |
| `ThisParameterType<T>` | 抽取 `this` 參數型別 |

```typescript
function createUser(name: string, age: number): User {
  return { id: crypto.randomUUID(), name, age, email: '', password: '' };
}

type CreateUserArgs = Parameters<typeof createUser>;   // [string, number]
type CreateUserResult = ReturnType<typeof createUser>; // User

// ConstructorParameters
class HttpClient {
  constructor(public baseUrl: string, public timeout: number) {}
}
type HttpClientArgs = ConstructorParameters<typeof HttpClient>; // [string, number]
type HttpClientInstance = InstanceType<typeof HttpClient>;       // HttpClient
```

## Built-in Utility Types: Promise and Filtering

| Utility | 功能 |
|---|---|
| `Awaited<T>` | 遞迴 unwrap Promise |
| `NonNullable<T>` | 移除 `null \| undefined` |
| `Extract<T, U>` | 保留 T 中可 assign 給 U 的 member |
| `Exclude<T, U>` | 移除 T 中可 assign 給 U 的 member |

```typescript
// Awaited — 處理 async 函數
async function fetchUser(): Promise<User> { /* ... */ }
type FetchResult = Awaited<ReturnType<typeof fetchUser>>; // User
type Deep = Awaited<Promise<Promise<string>>>;            // string

// NonNullable
type MaybeUser = User | null | undefined;
type DefiniteUser = NonNullable<MaybeUser>; // User

// Extract / Exclude — 過濾 union members
type Event = 'click' | 'focus' | 'blur' | 'scroll';
type MouseEvent = Extract<Event, 'click' | 'scroll'>; // 'click' | 'scroll'
type NonMouse = Exclude<Event, 'click' | 'scroll'>;   // 'focus' | 'blur'

// 實用：從 discriminated union 抽取特定 variant
type Result = { type: 'ok'; value: string } | { type: 'err'; error: Error };
type OkResult = Extract<Result, { type: 'ok' }>; // { type: 'ok'; value: string }
```

## Built-in Utility Types: String

| Utility | 功能 |
|---|---|
| `Uppercase<T>` | `'hello'` → `'HELLO'` |
| `Lowercase<T>` | `'HELLO'` → `'hello'` |
| `Capitalize<T>` | `'hello'` → `'Hello'` |
| `Uncapitalize<T>` | `'Hello'` → `'hello'` |

```typescript
type EventHandler<T extends string> = `on${Capitalize<T>}`;
type ClickHandler = EventHandler<'click'>; // 'onClick'

type SCREAM<T extends string> = Uppercase<T>;
type Quiet = SCREAM<'hello world'>; // 'HELLO WORLD'
```

## Custom Utility Types

### DeepPartial — 遞迴 optional

```typescript
type DeepPartial<T> = T extends object
  ? { [K in keyof T]?: DeepPartial<T[K]> }
  : T;

type Config = { db: { host: string; port: number }; cache: { ttl: number } };
type ConfigPatch = DeepPartial<Config>;
// { db?: { host?: string; port?: number }; cache?: { ttl?: number } }
```

### DeepReadonly — 遞迴 readonly

```typescript
type DeepReadonly<T> = T extends (infer U)[]
  ? readonly DeepReadonly<U>[]
  : T extends object
    ? { readonly [K in keyof T]: DeepReadonly<T[K]> }
    : T;
```

### StrictOmit — 只允許 Omit 已存在的 key

```typescript
type StrictOmit<T, K extends keyof T> = Omit<T, K>;
// Omit<User, 'nonexistent'>       — 不報錯 ⚠️
// StrictOmit<User, 'nonexistent'> — 編譯錯誤 ✅
```

### RequireAtLeastOne — 至少一個 property 必填

```typescript
type RequireAtLeastOne<T, Keys extends keyof T = keyof T> =
  Pick<T, Exclude<keyof T, Keys>> &
  { [K in Keys]-?: Required<Pick<T, K>> & Partial<Pick<T, Exclude<Keys, K>>> }[Keys];

type SearchParams = RequireAtLeastOne<{
  name?: string;
  email?: string;
  phone?: string;
}>;
```

### MakeOptional / MakeRequired — 指定 keys 調整

```typescript
type MakeOptional<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;
type MakeRequired<T, K extends keyof T> = Omit<T, K> & Required<Pick<T, K>>;

type User = { id: string; name: string; bio?: string };
type CreateUser = MakeOptional<User, 'id'>;    // id 變 optional
type FullUser = MakeRequired<User, 'bio'>;     // bio 變 required
```

## Generic Function Patterns

### Type-safe Event Emitter

```typescript
type EventMap = {
  userCreated: { userId: string; name: string };
  orderPlaced: { orderId: string; total: number };
  error: { message: string; code: number };
};

class TypedEmitter<T extends Record<string, unknown>> {
  private handlers = new Map<keyof T, Set<(payload: any) => void>>();

  on<K extends keyof T>(event: K, handler: (payload: T[K]) => void): void {
    if (!this.handlers.has(event)) this.handlers.set(event, new Set());
    this.handlers.get(event)!.add(handler);
  }

  emit<K extends keyof T>(event: K, payload: T[K]): void {
    this.handlers.get(event)?.forEach(handler => handler(payload));
  }
}

const emitter = new TypedEmitter<EventMap>();
emitter.on('userCreated', (payload) => {
  console.log(payload.userId); // ✅ 完整型別推斷
});
// emitter.emit('userCreated', { wrong: true }); // ❌ 編譯錯誤
```

### Builder Pattern with Generics

```typescript
class RequestBuilder<
  TMethod extends string = never,
  TUrl extends string = never,
> {
  private config: Record<string, unknown> = {};

  method<M extends string>(m: M): RequestBuilder<M, TUrl> {
    this.config.method = m;
    return this as any;
  }

  url<U extends string>(u: U): RequestBuilder<TMethod, U> {
    this.config.url = u;
    return this as any;
  }

  // execute 只在 method 和 url 都設定後才可用
  execute(this: RequestBuilder<string, string>): Promise<Response> {
    return fetch(this.config.url as string, { method: this.config.method as string });
  }
}

const builder = new RequestBuilder();
// builder.execute();                        // ❌ 還沒設定 method 和 url
builder.method('GET').url('/api/users').execute(); // ✅
```

## Anti-Patterns

```typescript
// ❌ 泛型只出現一次 — 沒有在 input 和 output 之間建立關聯
function bad1<T>(x: T): string { return String(x); }

// ❌ 過度 constraint — 直接用具體型別更清楚
function bad2<T extends { id: string; name: string }>(user: T): string {
  return user.name;
}
// ✅
function good2(user: { id: string; name: string }): string {
  return user.name;
}

// ❌ 泛型嵌套太深 — 降低可讀性
type Bad3<A, B, C, D> = Map<A, Record<B, Array<[C, D]>>>;
// ✅ 拆成有意義的中間型別
type Pair<C, D> = [C, D];
type Grouped<B, C, D> = Record<B, Pair<C, D>[]>;
type Index<A, B, C, D> = Map<A, Grouped<B, C, D>>;

// ❌ 手動指定泛型參數 — 失去推斷的好處
const result = first<number>([1, 2, 3]);
// ✅ 讓 TS 推斷
const result2 = first([1, 2, 3]); // number | undefined
```
