# Security & Performance

Reference for authentication, authorization, CORS, Data Protection, async patterns, response compression, IHttpClientFactory with resilience, memory optimization, and Native AOT. Read this when securing an ASP.NET Core application, optimizing throughput, or preparing for AOT deployment.

## Table of contents
- [Authentication](#authentication)
- [Authorization](#authorization)
- [CORS](#cors)
- [Data Protection API](#data-protection-api)
- [Async best practices](#async-best-practices)
- [Response compression](#response-compression)
- [IHttpClientFactory and resilience](#ihttpclientfactory-and-resilience)
- [Memory and performance](#memory-and-performance)
- [Cryptography](#cryptography)
- [Security headers](#security-headers)
- [Debugging and diagnostics](#debugging-and-diagnostics)
- [Native AOT compilation](#native-aot-compilation)

---

## Authentication

### JWT Bearer authentication

The most common scheme for API-only applications. The server validates a signed token on every request instead of maintaining session state.

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://login.example.com";
        options.Audience = "my-api";

        // For self-issued tokens without a discovery endpoint:
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = "https://login.example.com",
            ValidAudience = "my-api",
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:SigningKey"]!)),
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
```

Never hardcode the signing key. Load it from User Secrets (development) or a vault (production).

### Cookie authentication

Use cookies for server-rendered web applications (Razor Pages, MVC with views). The runtime manages encrypted cookies and sliding expiration automatically.

```csharp
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/account/login";
        options.AccessDeniedPath = "/account/access-denied";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        options.Cookie.SameSite = SameSiteMode.Strict;
    });
```

### ASP.NET Core Identity (.NET 8 Identity API endpoints)

.NET 8 added `MapIdentityApi<TUser>()` which exposes `/register`, `/login`, `/refresh`, `/confirmEmail`, and related endpoints out of the box — no controllers needed.

```csharp
builder.Services.AddIdentityApiEndpoints<ApplicationUser>()
    .AddEntityFrameworkStores<AppDbContext>();

var app = builder.Build();

app.MapIdentityApi<ApplicationUser>();  // maps /register, /login, /refresh, etc.
app.MapGet("/me", (ClaimsPrincipal user) => user.Identity?.Name)
    .RequireAuthorization();
```

For full Identity with roles, two-factor, and lockout, use `AddIdentity<TUser, TRole>()` instead of `AddIdentityApiEndpoints`.

### External auth providers (OAuth / OpenID Connect)

```csharp
builder.Services.AddAuthentication()
    .AddGoogle(options =>
    {
        options.ClientId = builder.Configuration["Auth:Google:ClientId"]!;
        options.ClientSecret = builder.Configuration["Auth:Google:ClientSecret"]!;
    })
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "my-app";
        options.ClientSecret = builder.Configuration["Auth:Oidc:ClientSecret"]!;
        options.ResponseType = "code";
        options.SaveTokens = true;
    });
```

### Custom authentication handler

Implement `AuthenticationHandler<TOptions>` when you need a scheme the framework does not provide (API key header, HMAC signature, etc.).

```csharp
public sealed class ApiKeyAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    private const string HeaderName = "X-Api-Key";

    public ApiKeyAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue(HeaderName, out var value))
            return Task.FromResult(AuthenticateResult.NoResult());

        // Validate the key against a store — never compare with == on raw strings.
        if (!IsValidKey(value!))
            return Task.FromResult(AuthenticateResult.Fail("Invalid API key"));

        var identity = new ClaimsIdentity(
            [new Claim(ClaimTypes.Name, "api-client")], Scheme.Name);
        return Task.FromResult(AuthenticateResult.Success(
            new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name)));
    }
}
```

---

## Authorization

### Policy-based authorization

Policies are the recommended way to express authorization rules. Define them in one place and apply declaratively.

```csharp
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("AdminOnly", policy => policy.RequireRole("Admin"))
    .AddPolicy("CanManageOrders", policy =>
        policy.RequireClaim("permission", "orders.manage"))
    .AddPolicy("MinAge", policy =>
        policy.RequireAssertion(ctx =>
        {
            var dob = ctx.User.FindFirstValue("date_of_birth");
            return dob is not null
                && DateOnly.Parse(dob).AddYears(18) <= DateOnly.FromDateTime(DateTime.UtcNow);
        }));
```

### Resource-based authorization

Use `IAuthorizationHandler` when the decision depends on the resource being accessed, not just the user's claims.

```csharp
public sealed class OrderOwnerRequirement : IAuthorizationRequirement;

public sealed class OrderOwnerHandler : AuthorizationHandler<OrderOwnerRequirement, Order>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        OrderOwnerRequirement requirement,
        Order resource)
    {
        if (context.User.FindFirstValue(ClaimTypes.NameIdentifier) == resource.OwnerId)
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}

// Registration
builder.Services.AddSingleton<IAuthorizationHandler, OrderOwnerHandler>();

// Usage in an endpoint
app.MapPut("/api/orders/{id}", async (
    int id,
    UpdateOrderDto dto,
    IAuthorizationService authService,
    IOrderRepository repo,
    ClaimsPrincipal user,
    CancellationToken ct) =>
{
    var order = await repo.GetByIdAsync(id, ct);
    if (order is null) return Results.NotFound();

    var result = await authService.AuthorizeAsync(user, order, new OrderOwnerRequirement());
    return result.Succeeded
        ? Results.Ok(await repo.UpdateAsync(order, dto, ct))
        : Results.Forbid();
});
```

### Applying authorization

```csharp
// Minimal API — per-endpoint or per-group
app.MapDelete("/api/orders/{id}", ...).RequireAuthorization("CanManageOrders");

var group = app.MapGroup("/api/admin").RequireAuthorization("AdminOnly");

// Controllers — attribute
[Authorize(Policy = "CanManageOrders")]
public IActionResult Delete(int id) { ... }

// Global fallback — require auth on all endpoints by default
builder.Services.AddAuthorizationBuilder()
    .SetFallbackPolicy(new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser().Build());
```

### Role vs claim vs policy — when to use which

- **Roles** — coarse-grained, group-level access (`Admin`, `Manager`). Simple but does not scale to fine-grained permissions.
- **Claims** — key-value pairs attached to the user (`permission:orders.manage`). More flexible than roles.
- **Policies** — compose roles, claims, and custom logic into named units. Always prefer policies over inline checks. They centralize rules, are testable, and appear in one registration block.

---

## CORS

### Named policies

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins("https://app.example.com", "https://staging.example.com")
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();   // needed for cookies / Authorization header
    });

    options.AddPolicy("OpenApi", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .WithMethods("GET");   // read-only, no credentials
    });
});

app.UseCors();   // must be between UseRouting() and UseAuthorization()
```

### Per-endpoint CORS

```csharp
app.MapGet("/api/public/status", () => "OK").RequireCors("OpenApi");
app.MapGroup("/api/orders").RequireCors("AllowFrontend");
```

### Common mistake: AllowAnyOrigin with AllowCredentials

The CORS spec forbids `Access-Control-Allow-Origin: *` together with `Access-Control-Allow-Credentials: true`. ASP.NET Core throws an `InvalidOperationException` at runtime if you try this. Always specify explicit origins when using `AllowCredentials()`.

---

## Data Protection API

The Data Protection API handles encryption and decryption of data that must survive round-trips (cookies, anti-forgery tokens, query string tokens). ASP.NET Core uses it internally for cookie authentication and anti-forgery.

### Basic usage

```csharp
public sealed class TokenService(IDataProtectionProvider provider)
{
    private readonly IDataProtector _protector =
        provider.CreateProtector("TokenService.v1");

    public string Protect(string plainText) => _protector.Protect(plainText);
    public string Unprotect(string protectedText) => _protector.Unprotect(protectedText);
}
```

### Time-limited protection

```csharp
var timeLimited = _protector.ToTimeLimitedDataProtector();
var token = timeLimited.Protect(userId, lifetime: TimeSpan.FromHours(24));

// Unprotect — throws CryptographicException if expired.
var original = timeLimited.Unprotect(token);
```

### Key persistence

By default, keys are stored in-memory (lost on restart) or in `%LOCALAPPDATA%` (single machine). For multi-instance deployments, persist keys to a shared store.

```csharp
// File system (simple, single-server)
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/dpkeys"))
    .SetApplicationName("MyApp");

// Azure Blob Storage
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(blobClient)
    .ProtectKeysWithAzureKeyVault(keyIdentifier, credential);

// Redis
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys");

// Entity Framework Core
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionDbContext>();
```

`SetApplicationName` is critical in multi-app environments — apps with different names cannot decrypt each other's payloads even if they share the same key ring.

---

## Async best practices

### async/await in ASP.NET Core

ASP.NET Core has no `SynchronizationContext`. This means:
- `ConfigureAwait(false)` is unnecessary (but harmless). Unlike ASP.NET on .NET Framework, there is no risk of deadlocking on `.Result` or `.Wait()` due to context capture. That said, avoid `.Result` and `.Wait()` entirely — they block a thread pool thread.
- Continuations run on the thread pool, so there is no "return to the original context" overhead.

### ValueTask vs Task

`ValueTask<T>` avoids an allocation when the result is already available synchronously (cache hit, buffered read). Use it in hot paths that often complete synchronously.

```csharp
// Good use of ValueTask — cache hit avoids Task allocation.
public ValueTask<Product?> GetByIdAsync(int id, CancellationToken ct)
{
    if (_cache.TryGetValue(id, out var cached))
        return ValueTask.FromResult<Product?>(cached);

    return new ValueTask<Product?>(LoadFromDatabaseAsync(id, ct));
}
```

Rules for `ValueTask`:
- Do not await it more than once.
- Do not use `.Result` or `.GetAwaiter().GetResult()` before it completes.
- Do not use `Task.WhenAll` with `ValueTask` — call `.AsTask()` first if needed.
- Default to `Task<T>` unless profiling shows the allocation matters.

### IAsyncDisposable

```csharp
await using var connection = new SqlConnection(connectionString);
await connection.OpenAsync(ct);

// connection is disposed asynchronously at end of scope.
```

### Avoiding async void

`async void` methods swallow exceptions and cannot be awaited. The only valid use is event handlers in UI frameworks. In ASP.NET Core, always return `Task` or `ValueTask`.

```csharp
// WRONG — exception crashes the process, caller cannot await.
async void ProcessOrder(Order order) { ... }

// CORRECT
async Task ProcessOrderAsync(Order order, CancellationToken ct) { ... }
```

### Channel<T> for producer-consumer

`Channel<T>` is a high-performance, thread-safe queue built into the runtime. Use it for background processing pipelines.

```csharp
// Registration
builder.Services.AddSingleton(Channel.CreateBounded<WorkItem>(new BoundedChannelOptions(1000)
{
    FullMode = BoundedChannelFullMode.Wait,
    SingleReader = true,
}));

// Producer (e.g., an API endpoint)
app.MapPost("/api/work", async (WorkItem item, Channel<WorkItem> channel, CancellationToken ct) =>
{
    await channel.Writer.WriteAsync(item, ct);
    return Results.Accepted();
});

// Consumer (BackgroundService)
public sealed class WorkProcessor(Channel<WorkItem> channel, ILogger<WorkProcessor> logger)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await foreach (var item in channel.Reader.ReadAllAsync(ct))
        {
            logger.LogInformation("Processing {ItemId}", item.Id);
            // process item
        }
    }
}
```

---

## Response compression

### Configuration

```csharp
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;  // opt-in; disabled by default for HTTPS due to CRIME/BREACH
    options.Providers.Add<BrotliCompressionProvider>();
    options.Providers.Add<GzipCompressionProvider>();
    options.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(
        ["application/json", "application/xml"]);
});

builder.Services.Configure<BrotliCompressionProviderOptions>(options =>
    options.Level = CompressionLevel.Fastest);

var app = builder.Build();

// Must be before UseStaticFiles and any middleware that writes the response body.
app.UseResponseCompression();
app.UseStaticFiles();
```

### When to compress vs when not to

Compress: text, JSON, HTML, SVG, CSS, JavaScript — anything text-based with high redundancy.

Do not compress: JPEG, PNG, WebP, MP4, ZIP, gzip — already compressed formats. Re-compressing wastes CPU for zero size reduction.

`EnableForHttps` is `false` by default because compression over HTTPS can leak information (CRIME/BREACH attacks). Enable it only if you understand the risk and your responses do not contain secrets mixed with user-controlled content.

---

## IHttpClientFactory and resilience

### Named and typed clients

```csharp
// Named client
builder.Services.AddHttpClient("payments", client =>
{
    client.BaseAddress = new Uri("https://api.payments.com/v2/");
    client.Timeout = TimeSpan.FromSeconds(10);
});

// Typed client — recommended for encapsulating a specific external service.
builder.Services.AddHttpClient<PaymentClient>(client =>
{
    client.BaseAddress = new Uri("https://api.payments.com/v2/");
});
```

### Handler pooling and DNS refresh

`IHttpClientFactory` pools `HttpMessageHandler` instances (default 2-minute lifetime). This avoids socket exhaustion while still respecting DNS changes. Adjust the lifetime if your upstream uses short DNS TTLs:

```csharp
builder.Services.AddHttpClient("payments")
    .SetHandlerLifetime(TimeSpan.FromMinutes(5));
```

### .NET 8 built-in resilience

.NET 8 ships `Microsoft.Extensions.Http.Resilience` which integrates Polly v8 directly into the HTTP pipeline.

```csharp
builder.Services.AddHttpClient("payments")
    .AddStandardResilienceHandler();
// Includes: retry (exponential backoff), circuit breaker, timeout, rate limiter, hedging.

// Customize specific strategies:
builder.Services.AddHttpClient("payments")
    .AddStandardResilienceHandler(options =>
    {
        options.Retry.MaxRetryAttempts = 3;
        options.Retry.Delay = TimeSpan.FromMilliseconds(500);
        options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(30);
        options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(5);
    });
```

### Custom Polly policies (pre-.NET 8 or advanced)

```csharp
builder.Services.AddHttpClient("legacy-service")
    .AddResilienceHandler("custom", pipeline =>
    {
        pipeline.AddRetry(new HttpRetryStrategyOptions
        {
            MaxRetryAttempts = 3,
            BackoffType = DelayBackoffType.Exponential,
            UseJitter = true,
            ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
                .HandleResult(r => r.StatusCode == HttpStatusCode.TooManyRequests),
        });
        pipeline.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
        {
            SamplingDuration = TimeSpan.FromSeconds(60),
            FailureRatio = 0.5,
            MinimumThroughput = 10,
        });
    });
```

### Delegating handlers for cross-cutting concerns

```csharp
public sealed class AuthTokenHandler(ITokenProvider tokens) : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        var token = await tokens.GetAccessTokenAsync(ct);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await base.SendAsync(request, ct);
    }
}

builder.Services.AddTransient<AuthTokenHandler>();
builder.Services.AddHttpClient("payments")
    .AddHttpMessageHandler<AuthTokenHandler>()
    .AddStandardResilienceHandler();
```

### Handling resilience exceptions in callers

When resilience pipelines are active, callers must handle two specific exception types that surface when the pipeline intervenes. Letting these bubble up unhandled results in generic 500 errors instead of meaningful responses.

```csharp
using Polly.CircuitBreaker;
using Polly.Timeout;

app.MapPost("/api/orders", async (
    CreateOrderDto dto,
    IPaymentClient paymentClient,
    CancellationToken ct) =>
{
    try
    {
        var result = await paymentClient.ChargeAsync(dto.Amount, ct);
        return Results.Ok(result);
    }
    catch (BrokenCircuitException)
    {
        // Circuit breaker is open — the downstream service has been failing
        return Results.Problem(
            title: "Payment service unavailable",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }
    catch (TimeoutRejectedException)
    {
        // Request exceeded the configured timeout
        return Results.Problem(
            title: "Payment service timeout",
            statusCode: StatusCodes.Status504GatewayTimeout);
    }
});
```

For Controller-based APIs, handle these in a global `IExceptionHandler` to avoid repeating catch blocks.

### Idempotency with retry policies

Retry policies automatically re-send failed requests. For non-idempotent operations (POST creating records, payment charges), the downstream service must support idempotency keys — otherwise retries can cause duplicate records or double charges.

```csharp
public async Task<PaymentResult> ChargeAsync(decimal amount, CancellationToken ct)
{
    using var request = new HttpRequestMessage(HttpMethod.Post, "charges")
    {
        Content = JsonContent.Create(new { Amount = amount })
    };

    // Idempotency key ensures retries do not create duplicate charges
    request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());

    var response = await _httpClient.SendAsync(request, ct);
    response.EnsureSuccessStatusCode();
    return await response.Content.ReadFromJsonAsync<PaymentResult>(ct)
        ?? throw new InvalidOperationException("Null payment response");
}
```

GET and DELETE are naturally idempotent. PUT is typically idempotent (replacing the full resource). POST and PATCH require explicit handling — either via an idempotency key header or by making the operation inherently idempotent at the database level (upsert with unique constraint).

---

## Memory and performance

### Span<T> and Memory<T>

`Span<T>` enables zero-allocation slicing of arrays, strings, and stack memory. Use it in parsing, formatting, and data transformation hot paths.

```csharp
// Zero-allocation CSV line parsing
static void ParseCsvLine(ReadOnlySpan<char> line)
{
    while (!line.IsEmpty)
    {
        int comma = line.IndexOf(',');
        ReadOnlySpan<char> field = comma >= 0 ? line[..comma] : line;

        ProcessField(field);

        line = comma >= 0 ? line[(comma + 1)..] : ReadOnlySpan<char>.Empty;
    }
}
```

`Memory<T>` is the heap-friendly sibling of `Span<T>` — use it when you need to store slices in fields or pass them to async methods (Span cannot be used in async contexts).

### ArrayPool<T> and MemoryPool<T>

Rent buffers from a shared pool instead of allocating new arrays on every call.

```csharp
byte[] buffer = ArrayPool<byte>.Shared.Rent(4096);
try
{
    int bytesRead = await stream.ReadAsync(buffer.AsMemory(0, 4096), ct);
    ProcessData(buffer.AsSpan(0, bytesRead));
}
finally
{
    ArrayPool<byte>.Shared.Return(buffer, clearArray: true);
}
```

### String handling

```csharp
// string.Create — allocate once, write directly into the buffer.
string result = string.Create(16, value, static (span, v) =>
{
    v.TryFormat(span, out _);
});

// StringBuilder — for multi-step concatenation in loops.
var sb = new StringBuilder(256);
foreach (var item in items)
    sb.Append(item.Name).Append(',');

// StringValues — used by ASP.NET Core headers, avoids allocations for 0-1 values.
StringValues headerValue = request.Headers["X-Custom"];
```

### Object pooling with ObjectPool<T>

```csharp
builder.Services.AddSingleton<ObjectPoolProvider, DefaultObjectPoolProvider>();
builder.Services.AddSingleton(sp =>
{
    var provider = sp.GetRequiredService<ObjectPoolProvider>();
    return provider.Create(new DefaultPooledObjectPolicy<StringBuilder>());
});

// Usage
public sealed class ReportGenerator(ObjectPool<StringBuilder> pool)
{
    public string Generate(IEnumerable<ReportLine> lines)
    {
        var sb = pool.Get();
        try
        {
            foreach (var line in lines)
                sb.AppendLine(line.ToString());
            return sb.ToString();
        }
        finally
        {
            pool.Return(sb);
        }
    }
}
```

### FrozenDictionary and FrozenSet (.NET 8+)

Optimized for read-heavy scenarios where the collection is built once and never modified. Lookup is faster than `Dictionary<TKey, TValue>` because the internal structure is optimized at creation time.

```csharp
// Build once at startup.
FrozenDictionary<string, int> countryCodeMap = new Dictionary<string, int>
{
    ["US"] = 1, ["GB"] = 44, ["JP"] = 81, ["TW"] = 886,
}.ToFrozenDictionary(StringComparer.OrdinalIgnoreCase);

// Use in hot path — faster lookups than Dictionary.
if (countryCodeMap.TryGetValue(code, out int dialCode))
    return dialCode;
```

Use `FrozenDictionary` / `FrozenSet` for lookup tables, feature flag sets, routing maps, or any collection that is populated at startup and read thousands of times per second.

---

## Cryptography

Use the `System.Security.Cryptography` primitives shipped with the runtime. Do not roll your own.

- **Hashing for integrity**: `SHA256` / `SHA384` / `SHA512`. Do not use `MD5` or `SHA1` — both are broken for collision resistance.
- **Password hashing**: never raw SHA. Use `Rfc2898DeriveBytes` (PBKDF2, pick `HashAlgorithmName.SHA256`, ≥100k iterations) or ASP.NET Core Identity's `PasswordHasher<T>` which wraps it.
- **Symmetric encryption**: prefer `AesGcm` (authenticated) over `AesManaged` / raw `Aes` with CBC. `AesGcm` gives you confidentiality + integrity in one primitive.
- **Randomness for security**: use `RandomNumberGenerator.GetBytes` / `GetInt32`. `System.Random` is not cryptographically secure — never use it for tokens, nonces, salts, or session IDs.
- **Constant-time comparisons**: use `CryptographicOperations.FixedTimeEquals` for comparing HMACs, tokens, and signatures. `==` on byte arrays leaks timing information.

```csharp
// Secure token
byte[] token = RandomNumberGenerator.GetBytes(32);

// AES-GCM round trip
byte[] key = RandomNumberGenerator.GetBytes(32);
byte[] nonce = RandomNumberGenerator.GetBytes(AesGcm.NonceByteSizes.MaxSize);
byte[] cipher = new byte[plain.Length];
byte[] tag = new byte[AesGcm.TagByteSizes.MaxSize];
using var aes = new AesGcm(key, tag.Length);
aes.Encrypt(nonce, plain, cipher, tag);
```

For long-lived signed tokens inside the app (not cross-system), prefer the Data Protection API (see above) which handles key rotation automatically.

---

## Security headers

ASP.NET Core ships `UseHsts` and `UseHttpsRedirection` but does not set CSP / X-Frame-Options / X-Content-Type-Options by default. Add a small middleware (or package such as `NetEscapades.AspNetCore.SecurityHeaders`) and wire it before `UseRouting`.

```csharp
app.Use(async (ctx, next) =>
{
    var h = ctx.Response.Headers;
    h.Append("X-Content-Type-Options", "nosniff");
    h.Append("X-Frame-Options", "DENY");
    h.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    h.Append("Content-Security-Policy",
        "default-src 'self'; script-src 'self'; object-src 'none'; frame-ancestors 'none';");
    await next();
});

app.UseHsts();              // only in non-dev
app.UseHttpsRedirection();
```

Tune CSP per app — the example above blocks inline scripts; SPAs using CDN assets need explicit `script-src` / `style-src` origins. Avoid `unsafe-inline` unless you have no alternative, and never use `unsafe-eval` in production.

For cloud deployments prefer **Managed Identity** (Azure) / IAM roles (AWS) over shipping long-lived keys in config — combines with Rule 9.

---

## Debugging and diagnostics

Use the `dotnet-*` global tools for live diagnosis. They attach to a running PID without modifying the app.

| Symptom | Tool | Command |
|---------|------|---------|
| High CPU / GC / throughput | `dotnet-counters` | `dotnet-counters monitor -p <PID> --counters System.Runtime` |
| Memory leak | `dotnet-gcdump` | `dotnet-gcdump collect -p <PID>` (take two, diff the heap) |
| Crash / hang | `dotnet-dump` | `dotnet-dump collect -p <PID>` then `analyze` + `pe`, `clrstack`, `dumpheap -stat`, `gcroot` |
| Slow request / hot path | `dotnet-trace` | `dotnet-trace collect -p <PID> --profile dotnet-common,dotnet-sampled-thread-time --duration 00:00:00:30 --format Speedscope` |
| Deadlock | `dotnet-stack` | `dotnet-stack report -p <PID>` — inspect blocked threads and the resource each is waiting on |

On an SDK-equipped development host, diagnostic tools can be installed with `dotnet tool install`. An SDK-less production host may instead need the appropriate standalone tool, such as `https://aka.ms/dotnet-dump/win-x64` (also `win-x86`, `win-arm64`, `linux-x64`, `linux-musl-x64`, `linux-arm64`). Installation is a separate machine change; probe what is already available and obtain authorization first.

### Automatic crash dumps (all platforms)

A service that restarts its own workers on failure destroys the crash scene: without dumps armed in advance, a crash leaves nothing behind. Arm them **before** the crash — these are environment variables read at process start, not a runtime switch.

```powershell
# Windows (PowerShell) — applies to this shell and processes launched from it
$env:DOTNET_DbgEnableMiniDump = "1"
$env:DOTNET_DbgMiniDumpType   = "3"                       # see table below
$env:DOTNET_DbgMiniDumpName   = "C:\dumps\%e_%p_%t.dmp"   # %e=exe %p=pid %h=host %t=epoch (.NET 5+)
$env:DOTNET_CreateDumpDiagnostics = "1"                   # log why dump creation itself failed
$env:DOTNET_CreateDumpLogToFile   = "C:\dumps\createdump.log"
```

For an existing Windows Service, persist these variables through that service's manager or deployment configuration, restart the service, and verify the dump directory is writable by the actual service identity. `$env:` alone does not update an already-running service.

```bash
# Linux / macOS
export DOTNET_DbgEnableMiniDump=1
export DOTNET_DbgMiniDumpType=3
export DOTNET_DbgMiniDumpName=/var/dumps/%e_%p_%t.dmp
```

These variables are **not Linux-only** — the runtime honours them on Windows, Linux, and macOS. The only platform exclusion is mobile (Android/iOS). Within the set, only `DOTNET_EnableCrashReport` (the JSON crash report) is unsupported on Windows.

| Value | Type | Size | Use when |
|---|---|---|---|
| 1 | `Mini` | Small | Stack traces only, minimal disk |
| 2 | `Heap` | Large | Need managed heap objects (**runtime default**) |
| 3 | `Triage` | Small | Same as Mini, with paths and passwords stripped — the safe default for a long-running service |
| 4 | `Full` | Largest | All memory including module images |

Three traps, each of which silently produces nothing or the wrong thing:

- **Create and verify the output directory before arming.** Confirm the crash process identity can write there. If no dump appears, `DOTNET_CreateDumpDiagnostics=1` writes diagnostics to that process's console; use `DOTNET_CreateDumpLogToFile` when durable logging is required.
- **The two collection paths have different defaults.** `DOTNET_DbgMiniDumpType` defaults to `2` (Heap); `dotnet-dump collect --type` defaults to `Full`. Never document them as one value.
- **`Full` on a 24/7 service is a disk-space decision.** Every crash writes the entire process memory. Pick `3` (Triage) unless heap contents are what you are actually chasing.

`DOTNET_DbgMiniDumpName` defaults to `/tmp/coredump.<pid>` — always set it explicitly on Windows, or the dump lands somewhere you will not look. The legacy `COMPlus_` prefix still works but `DOTNET_` is preferred on .NET 6+.

**Only single-file and Native AOT apps are restricted to `Full`.** Self-contained is *not* single-file: `PublishSelfContained=true` alone leaves all four types available. Check for `PublishSingleFile` before assuming the restriction applies.

### Windows trace collection: the admin split

**PerfView** ETW collection (`github.com/microsoft/perfview/releases`, standalone `.exe`) requires elevation; viewing an existing trace does not. On modern .NET, `dotnet-trace` is a lower-privilege alternative. On .NET Framework, PerfMon/.NET CLR counters and existing application telemetry can still provide lower-resolution triage, subject to local counter ACLs; full ETW collection may require an elevated operator. Dumps are another diagnostic path, not the only one.

```powershell
# Hang triage — /ThreadTime adds thread-level wait/block detail, which is what
# separates a livelock (threads burning CPU) from thread-pool starvation
# (threads blocked on a resource) from a true deadlock (threads waiting on each other).
PerfView /ThreadTime collect /BufferSizeMB:1024 /CircularMB:2048

# Long-running repro — circular buffer keeps only the last N MB, so the trigger
# must fire on the SYMPTOM, never on the recovery, or the interesting window is
# already overwritten by the time collection stops.
PerfView collect /StopOnPerfCounter:"Processor:% Processor Time:_Total>80" /BufferSizeMB:2048 /CircularMB:4096
PerfView collect /StopOnGCEvent /BufferSizeMB:2048 /CircularMB:4096
```

Add `/StartOn…` only when the start event is known to precede the stop event; otherwise omit it. For slow requests, do not pick a stop trigger blind — collect without one first and design the trigger from what the trace shows.

**Symbols are a precondition, not a detail.** `clrstack` and `dumpheap` resolve managed frames from metadata in the dump, but native frames, inlined methods, and line numbers need the *matching* binaries and PDBs — same build, same commit, same RID. A dump analysed against a different build yields plausible-looking frames that point at the wrong lines. Publish with `<DebugType>portable</DebugType>` and keep the PDBs for every artifact you might have to analyse; a stripped release build makes deep triage guesswork. When handing a dump to someone else, ship the PDBs with it. Redact secrets before sharing — a heap dump contains connection strings and tokens in cleartext.

Common leak patterns to watch for during triage: event handlers never unsubscribed, unbounded static collections, `HttpClient` created per request (Rule 3), captured closures holding large graphs alive, and `Timer` instances not disposed.

For micro-benchmarks (before/after a perf fix) use **BenchmarkDotNet** with `[MemoryDiagnoser]` and compare allocations as well as time. Run in Release configuration.

Primary sources (last verified 2026-08-05): Microsoft Learn on [crash dump environment variables](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/collect-dumps-crash), [`dotnet-dump`](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-dump), and [`dotnet-trace`](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-trace); Microsoft [PerfView repository](https://github.com/microsoft/perfview).

---

## Native AOT compilation

### Benefits

Native AOT compiles the application to native code ahead of time, eliminating the JIT compiler at runtime.

- **Faster startup** — no JIT warm-up. Typical startup drops from 200-500ms to 20-50ms.
- **Smaller footprint** — the trimmer removes unused code; a minimal API app can be under 15 MB.
- **No JIT dependency** — deploy a single self-contained binary without the .NET runtime.

### Limitations

Native AOT does not support features that rely on runtime code generation:
- Reflection-based serialization (default `System.Text.Json` without source generators).
- `Assembly.LoadFrom`, dynamic assembly loading.
- Runtime expression compilation (`Expression.Compile()`).
- Some third-party libraries that use reflection internally.

### Source generators for JSON serialization

Replace reflection-based JSON with compile-time source generators — required for AOT compatibility.

```csharp
[JsonSerializable(typeof(Order))]
[JsonSerializable(typeof(List<Order>))]
[JsonSerializable(typeof(CreateOrderDto))]
internal partial class AppJsonSerializerContext : JsonSerializerContext;

// Register in the application
builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.TypeInfoResolverChain.Add(AppJsonSerializerContext.Default));
```

### CreateSlimBuilder for AOT-friendly web apps

`CreateSlimBuilder` excludes features that are incompatible with AOT (e.g., the startup `IHostingStartup` hook, some logging providers). Use it when targeting AOT.

```csharp
var builder = WebApplication.CreateSlimBuilder(args);

builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.TypeInfoResolverChain.Add(AppJsonSerializerContext.Default));

var app = builder.Build();

app.MapGet("/api/orders/{id}", (int id) =>
    new Order(id, "Sample", 99.99m));

app.Run();
```

### Testing AOT compatibility

Add `PublishAot` to your `.csproj` and publish to validate that everything trims and compiles correctly. Run this in CI to catch regressions early.

```xml
<PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <PublishAot>true</PublishAot>
    <InvariantGlobalization>true</InvariantGlobalization>
</PropertyGroup>
```

```bash
dotnet publish -c Release -r linux-x64
```

AOT warnings appear as build warnings (`IL2XXX` trim warnings, `IL3XXX` AOT warnings). Treat them as errors in CI:

```xml
<PropertyGroup>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
</PropertyGroup>
```

If a library is not AOT-compatible, you will see trim warnings during publish. Either find an alternative library, use source generators, or exclude AOT for that project.

---

## OpenTelemetry for ASP.NET Core

Use this branch for ASP.NET Core on .NET 8+: OpenTelemetry traces, metrics, log export, service identity, or OTLP configuration. Plain `ILogger`/Serilog/NLog design stays in `dotnet-logging-best-practices`; runtime trace or dump collection stays in the runtime-diagnostics section above.

### Minimum setup

Keep packages in the repository's existing NuGet or Central Package Management policy. Select a current stable, target-compatible version and verify it; do not copy a documentation sample's historical version blindly.

| Need | Package |
|---|---|
| Hosted SDK | `OpenTelemetry.Extensions.Hosting` |
| OTLP export | `OpenTelemetry.Exporter.OpenTelemetryProtocol` |
| Incoming ASP.NET Core spans/metrics | `OpenTelemetry.Instrumentation.AspNetCore` |
| Outgoing `HttpClient` spans | `OpenTelemetry.Instrumentation.Http` |

Register only instrumentation the service uses. This cross-signal pattern keeps exporter configuration in one place:

```csharp
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var serviceName = builder.Configuration["OTEL_SERVICE_NAME"]
    ?? builder.Environment.ApplicationName;

builder.Logging.AddOpenTelemetry(logging =>
{
    logging.IncludeScopes = true;
});

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService(serviceName))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSource(Telemetry.SourceName))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddMeter(Telemetry.SourceName))
    .UseOtlpExporter();
```

Omit the logging block if logs stay on an existing sink. Define `ActivitySource` and `Meter` from the same stable `Telemetry.SourceName`; the strings passed to `AddSource` and `AddMeter` must match exactly. HTTP instrumentation propagates trace context automatically. Add manual propagation only at boundaries without supported instrumentation, such as a custom message envelope.

Call `UseOtlpExporter()` once for the configured signals. Do not combine it with signal-specific `AddOtlpExporter()` registrations. Verify this API against the installed package because OpenTelemetry evolves independently of .NET.

### Deployment and transport

- Set a stable `service.name`; add low-cardinality `service.namespace`, `service.version`, and environment identity when useful. Never use customer or tenant IDs as resource attributes.
- Configure `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_PROTOCOL`, timeout, and headers through deployment configuration. Inject auth headers from a secret store; never put credentials in source, committed appsettings, command arguments, or output.
- Match endpoint and protocol: gRPC commonly uses port 4317 and HTTP/protobuf 4318. For a remote production endpoint, require HTTPS with normal certificate validation; reserve cleartext HTTP for an explicitly trusted local/dev path.
- If the selected .NET 8+ exporter release supports mTLS, use its CA/client certificate environment settings and PEM files. Do not disable certificate validation as a workaround.
- Authenticate and restrict access to the Collector and backend. Telemetry can expose architecture and user data even when application payloads are excluded.

### Data and cardinality guard

OpenTelemetry cannot determine what is sensitive for the application. Inventory attributes emitted by every instrumentation library before production enablement.

- Default-deny PII, credentials, session tokens, auth headers, request/response bodies, query strings, SQL text, financial/health data, and detailed user behavior. Never put secrets or PII in baggage because it propagates across service boundaries.
- Prefer route templates, coarse outcome/status fields, and aggregate identifiers. Metric dimensions must be bounded; user, request, order, trace, or other unbounded IDs are not metric tags.
- Avoid collection at the source. As defense in depth, use Collector attributes/filter/redaction/transform processors with an allowlist before export or storage.
- Hashing a small or predictable identifier space is not anonymization. Confirm the result against the application's privacy and retention requirements.

### Completion checks

1. Build and run applicable tests with the repository's pinned package versions.
2. In a development-only Collector, Console exporter, or standalone Aspire Dashboard, generate one inbound request and one outbound `HttpClient` request. Confirm `service.name`, parent/child spans, expected metrics, and log `TraceId`/`SpanId` correlation.
3. Send synthetic secret/PII sentinel values through instrumented paths and confirm they are absent from exported attributes, logs, baggage, and backend search.
4. Exercise the real authenticated OTLP path without printing headers. For failure behavior, only in dev/staging point the test app at a disposable Collector or known-unreachable URI; never stop a shared or production Collector. Confirm request handling remains functional and inspect `OpenTelemetry-Exporter-OpenTelemetryProtocol` internal events for export failures or dropped batches.
5. Check sampling, attribute count/length, metric cardinality, exporter queue pressure, and backend ingestion cost against the production budget.

Primary sources (last verified 2026-08-05): Microsoft Learn [.NET observability with OpenTelemetry](https://learn.microsoft.com/dotnet/core/diagnostics/observability-with-otel) and [OTLP walkthrough](https://learn.microsoft.com/dotnet/core/diagnostics/observability-otlp-example); OpenTelemetry [.NET OTLP exporter](https://github.com/open-telemetry/opentelemetry-dotnet/tree/main/src/OpenTelemetry.Exporter.OpenTelemetryProtocol), [handling sensitive data](https://opentelemetry.io/docs/security/handling-sensitive-data/), and [Collector hosting security](https://opentelemetry.io/docs/security/hosting-best-practices/).
