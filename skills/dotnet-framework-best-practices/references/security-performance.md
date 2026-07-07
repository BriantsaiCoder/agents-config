# .NET Framework 4.x — Security & Performance Patterns

## Authentication

### Forms Authentication (Legacy)

Forms Authentication is the original ASP.NET authentication mechanism. It issues an encrypted cookie
after successful login and validates it on subsequent requests.

```xml
<!-- Web.config -->
<system.web>
  <authentication mode="Forms">
    <forms loginUrl="~/Account/Login"
           timeout="30"
           slidingExpiration="true"
           cookieName=".MyAppAuth"
           requireSSL="true"
           protection="All" />
  </authentication>
  <authorization>
    <deny users="?" />
  </authorization>
</system.web>
```

```csharp
// Login action
[HttpPost]
[AllowAnonymous]
[ValidateAntiForgeryToken]
public ActionResult Login(LoginViewModel model, string returnUrl)
{
    if (!ModelState.IsValid)
        return View(model);

    if (_authService.ValidateCredentials(model.Username, model.Password))
    {
        FormsAuthentication.SetAuthCookie(model.Username, model.RememberMe);
        return RedirectToLocal(returnUrl);
    }

    ModelState.AddModelError("", "Invalid username or password.");
    return View(model);
}

// Logout
public ActionResult Logout()
{
    FormsAuthentication.SignOut();
    return RedirectToAction("Login");
}
```

Prefer OWIN Cookie Authentication over Forms Authentication for new development. Forms Authentication
is tightly coupled to `System.Web` and cannot be used in self-hosted scenarios.

---

### OWIN Cookie Authentication

OWIN/Katana decouples authentication from `System.Web`. This is the recommended approach for MVC 5
and Web API 2 applications.

```csharp
// Startup.cs (OWIN)
public class Startup
{
    public void Configuration(IAppBuilder app)
    {
        app.UseCookieAuthentication(new CookieAuthenticationOptions
        {
            AuthenticationType = DefaultAuthenticationTypes.ApplicationCookie,
            LoginPath = new PathString("/Account/Login"),
            ExpireTimeSpan = TimeSpan.FromMinutes(30),
            SlidingExpiration = true,
            CookieHttpOnly = true,
            CookieSecure = CookieSecureOption.Always,
            CookieName = ".MyApp.Auth"
        });
    }
}
```

```csharp
// Sign-in using OWIN context
var authManager = HttpContext.GetOwinContext().Authentication;
var identity = new ClaimsIdentity(
    new[] {
        new Claim(ClaimTypes.Name, user.Username),
        new Claim(ClaimTypes.Role, user.Role)
    },
    DefaultAuthenticationTypes.ApplicationCookie);

authManager.SignIn(new AuthenticationProperties { IsPersistent = rememberMe }, identity);

// Sign-out
authManager.SignOut(DefaultAuthenticationTypes.ApplicationCookie);
```

---

### OWIN OAuth / JWT Bearer Tokens

For Web API 2 endpoints consumed by SPAs or mobile clients, use bearer token authentication.

```csharp
// Startup.cs
public void Configuration(IAppBuilder app)
{
    app.UseOAuthBearerAuthentication(new OAuthBearerAuthenticationOptions
    {
        AccessTokenFormat = new JwtFormat(
            new TokenValidationParameters
            {
                ValidAudience = "https://myapp.example.com",
                ValidIssuer = "https://auth.example.com",
                IssuerSigningKey = new SymmetricSecurityKey(
                    Convert.FromBase64String(ConfigurationManager.AppSettings["JwtSecret"]))
            },
            new OpenIdConnectCachingSecurityTokenProvider("https://auth.example.com/.well-known/openid-configuration"))
    });
}
```

For a simpler self-issued token setup with `OAuthAuthorizationServerOptions`:

```csharp
app.UseOAuthAuthorizationServer(new OAuthAuthorizationServerOptions
{
    TokenEndpointPath = new PathString("/token"),
    Provider = new ApplicationOAuthProvider(),
    AccessTokenExpireTimeSpan = TimeSpan.FromMinutes(30),
    AllowInsecureHttp = false // always false in production
});

app.UseOAuthBearerAuthentication(new OAuthBearerAuthenticationOptions());
```

---

### Windows Authentication (Intranet)

For intranet applications where all users are on an Active Directory domain:

```xml
<!-- Web.config -->
<system.web>
  <authentication mode="Windows" />
  <authorization>
    <deny users="?" />
  </authorization>
</system.web>
```

```csharp
// Access the authenticated Windows identity
[Authorize(Roles = "DOMAIN\\Managers")]
public ActionResult AdminPanel()
{
    var identity = (WindowsIdentity)User.Identity;
    var username = identity.Name; // DOMAIN\username
    return View();
}
```

Requires IIS configuration: disable Anonymous Authentication, enable Windows Authentication in the
site's Authentication settings.

---

### ASP.NET Identity with .NET Framework

ASP.NET Identity (v2.x) is the membership system designed for MVC 5 / Web API 2. It replaces the
legacy `Membership` and `SimpleMembership` providers.

```csharp
// Startup.Auth.cs
app.CreatePerOwinContext(ApplicationDbContext.Create);
app.CreatePerOwinContext<ApplicationUserManager>(ApplicationUserManager.Create);
app.CreatePerOwinContext<ApplicationSignInManager>(ApplicationSignInManager.Create);

app.UseCookieAuthentication(new CookieAuthenticationOptions
{
    AuthenticationType = DefaultAuthenticationTypes.ApplicationCookie,
    LoginPath = new PathString("/Account/Login"),
    Provider = new CookieAuthenticationProvider
    {
        OnValidateIdentity = SecurityStampValidator
            .OnValidateIdentity<ApplicationUserManager, ApplicationUser>(
                validateInterval: TimeSpan.FromMinutes(15),
                regenerateIdentity: (manager, user) => user.GenerateUserIdentityAsync(manager))
    }
});
```

Key points:
- `SecurityStampValidator` invalidates cookies when the user's security stamp changes (password reset, role change).
- Register `UserManager` and `SignInManager` per OWIN context — not as singletons.
- Store password hashes only; never log or serialize `PasswordHash` values.

---

## CSRF Protection

### MVC Views and Controllers

Every form that performs a state-changing action must include an anti-forgery token.

```html
<!-- In the Razor view -->
@using (Html.BeginForm("Create", "Order", FormMethod.Post))
{
    @Html.AntiForgeryToken()
    <!-- form fields -->
    <button type="submit">Create Order</button>
}
```

```csharp
[HttpPost]
[ValidateAntiForgeryToken]
public ActionResult Create(OrderViewModel model)
{
    if (!ModelState.IsValid)
        return View(model);

    _orderService.Create(model);
    return RedirectToAction("Index");
}
```

### CSRF for Web API 2 with Cookie Authentication

Web API 2 does not include `[ValidateAntiForgeryToken]`. When using cookie authentication with
API endpoints (common in SPAs), implement custom validation:

```csharp
public class ValidateAntiForgeryTokenAttribute : ActionFilterAttribute
{
    public override void OnActionExecuting(HttpActionContext actionContext)
    {
        var headers = actionContext.Request.Headers;
        var cookieToken = actionContext.Request.Headers.GetCookies()
            .SelectMany(c => c.Cookies)
            .FirstOrDefault(c => c.Name == AntiForgeryConfig.CookieName)?.Value;

        string formToken;
        if (!headers.TryGetValues("X-XSRF-TOKEN", out var values))
            throw new HttpResponseException(HttpStatusCode.Forbidden);

        formToken = values.FirstOrDefault();
        AntiForgery.Validate(cookieToken, formToken);
    }
}
```

```javascript
// Client-side: read cookie and send as header
var token = document.cookie.match(/__RequestVerificationToken=([^;]+)/)[1];
fetch('/api/orders', {
    method: 'POST',
    headers: { 'X-XSRF-TOKEN': token, 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
});
```

### AntiForgeryConfig Settings

```csharp
// Global.asax Application_Start or OWIN Startup
AntiForgeryConfig.UniqueClaimTypeIdentifier = ClaimTypes.NameIdentifier;
AntiForgeryConfig.CookieName = "__AppAF";
AntiForgeryConfig.RequireSsl = true;
```

Set `UniqueClaimTypeIdentifier` when using claims-based identity to avoid the
`"A claim of type '...' was not present"` exception.

---

## Input Validation & XSS Prevention

### Request Validation

ASP.NET request validation rejects input containing HTML/script tags by default. Do not disable it
globally. Use targeted exceptions only when necessary.

```csharp
// Disable for a specific action parameter (MVC)
[HttpPost]
[ValidateInput(false)] // use sparingly — only when accepting rich HTML
public ActionResult SaveContent(string htmlContent)
{
    var sanitized = _htmlSanitizer.Sanitize(htmlContent);
    _contentService.Save(sanitized);
    return RedirectToAction("Index");
}
```

### AllowHtml Attribute

Prefer `[AllowHtml]` on individual model properties over `[ValidateInput(false)]` on the entire action.

```csharp
public class ArticleViewModel
{
    [Required]
    public string Title { get; set; }

    [AllowHtml] // only this property accepts HTML
    public string Body { get; set; }
}
```

### Output Encoding

Always encode output. Razor (`@variable`) encodes by default. Use `@Html.Raw()` only for
pre-sanitized content.

```csharp
// Encode explicitly when building strings in code-behind
var safeValue = HttpUtility.HtmlEncode(userInput);

// For JavaScript contexts
var safeJs = HttpUtility.JavaScriptStringEncode(userInput);

// AntiXSS library (Microsoft.Security.Application) for richer encoding
var encoded = Encoder.HtmlEncode(userInput);
```

### Content Security Policy

Add CSP headers to prevent inline script execution:

```csharp
// In a global action filter or OWIN middleware
public class SecurityHeadersFilter : ActionFilterAttribute
{
    public override void OnResultExecuting(ResultExecutingContext filterContext)
    {
        var response = filterContext.HttpContext.Response;
        response.Headers.Add("Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'");
        response.Headers.Add("X-Content-Type-Options", "nosniff");
        response.Headers.Add("X-Frame-Options", "DENY");
    }
}
```

---

## CORS Configuration

### Web API 2 with Microsoft.AspNet.WebApi.Cors

Install the `Microsoft.AspNet.WebApi.Cors` NuGet package. Enable CORS in `WebApiConfig`.

```csharp
// WebApiConfig.cs
public static void Register(HttpConfiguration config)
{
    config.EnableCors(); // enables [EnableCors] attribute usage
    config.MapHttpAttributeRoutes();
}
```

```csharp
// Per-controller or per-action
[EnableCors(origins: "https://app.example.com", headers: "*", methods: "GET,POST")]
public class OrdersController : ApiController
{
    // actions inherit the CORS policy
}

// Override for a specific action
[EnableCors(origins: "https://admin.example.com", headers: "*", methods: "*")]
public IHttpActionResult GetAdmin() { ... }

// Disable CORS for a specific action
[DisableCors]
public IHttpActionResult GetInternal() { ... }
```

### Global CORS Policy

```csharp
// WebApiConfig.cs — apply policy to all controllers
var corsPolicy = new EnableCorsAttribute(
    origins: "https://app.example.com,https://admin.example.com",
    headers: "*",
    methods: "GET,POST,PUT,DELETE")
{
    SupportsCredentials = true // required for cookie/auth header pass-through
};

config.EnableCors(corsPolicy);
```

**Never use `origins: "*"` with `SupportsCredentials = true`.** Browsers reject this combination.
Always list explicit origins when credentials are involved.

---

## Output Caching

### OutputCache Attribute

```csharp
// Cache for 60 seconds, vary by id parameter
[OutputCache(Duration = 60, VaryByParam = "id")]
public ActionResult Details(int id)
{
    var order = _orderService.GetOrder(id);
    return View(order);
}

// Cache on server only (not in browser or proxy)
[OutputCache(Duration = 300, VaryByParam = "none", Location = OutputCacheLocation.Server)]
public ActionResult Dashboard()
{
    return View(_dashboardService.GetSummary());
}

// Vary by custom function (e.g., user role)
[OutputCache(Duration = 120, VaryByCustom = "UserRole")]
public ActionResult RoleDashboard() { ... }
```

```csharp
// Global.asax — implement VaryByCustom
public override string GetVaryByCustomString(HttpContext context, string custom)
{
    if (custom == "UserRole")
        return context.User.IsInRole("Admin") ? "Admin" : "User";

    return base.GetVaryByCustomString(context, custom);
}
```

### Cache Profiles in Web.config

```xml
<system.web>
  <caching>
    <outputCacheSettings>
      <outputCacheProfiles>
        <add name="Short" duration="60" varyByParam="none" />
        <add name="Long" duration="3600" varyByParam="id" location="Server" />
      </outputCacheProfiles>
    </outputCacheSettings>
  </caching>
</system.web>
```

```csharp
[OutputCache(CacheProfile = "Long")]
public ActionResult Details(int id) { ... }
```

### Donut Caching with Html.RenderAction

Cache the outer page but render a dynamic child action:

```csharp
// Parent action — cached
[OutputCache(Duration = 300, VaryByParam = "none")]
public ActionResult Index()
{
    return View(_contentService.GetHomePage());
}

// Child action — not cached (or cached separately)
[ChildActionOnly]
public ActionResult UserGreeting()
{
    return PartialView("_UserGreeting", User.Identity.Name);
}
```

```html
<!-- In Index.cshtml — this call is not cached even though the parent is -->
@{ Html.RenderAction("UserGreeting", "Home"); }
```

### MemoryCache for Application-Level Caching

```csharp
private static readonly MemoryCache _cache = MemoryCache.Default;

public List<Category> GetCategories()
{
    const string key = "AllCategories";
    var cached = _cache.Get(key) as List<Category>;
    if (cached != null)
        return cached;

    var categories = _repository.GetAllCategories();
    _cache.Set(key, categories, new CacheItemPolicy
    {
        AbsoluteExpiration = DateTimeOffset.UtcNow.AddMinutes(10)
    });

    return categories;
}
```

Do not use `HttpRuntime.Cache` in new code; `MemoryCache` (from `System.Runtime.Caching`) is the
modern replacement and works outside of `System.Web`.

---

## Async Patterns & Thread Management

### Async/Await in the ASP.NET Pipeline

ASP.NET on .NET Framework uses a `SynchronizationContext` that captures the request context. This
means `await` resumes on the original request thread unless told otherwise.

```csharp
// Correct — async all the way from controller to data access
public async Task<ActionResult> Index()
{
    var orders = await _orderService.GetPendingOrdersAsync();
    return View(orders);
}
```

### ConfigureAwait(false) in Library Code

Service and repository code that does not need `HttpContext` should use `ConfigureAwait(false)`.

```csharp
// In a service class — no HttpContext dependency
public async Task<List<Order>> GetPendingOrdersAsync(CancellationToken ct = default)
{
    var data = await _repository.QueryPendingAsync(ct).ConfigureAwait(false);
    var enriched = await _enrichmentService.EnrichAsync(data, ct).ConfigureAwait(false);
    return enriched;
}
```

### Avoiding SynchronizationContext Deadlocks

The classic .NET Framework deadlock occurs when synchronous code blocks on an async method:

```csharp
// DEADLOCK — .Result blocks the request thread; the continuation needs that same thread
public ActionResult Bad()
{
    var data = _service.GetDataAsync().Result; // deadlock
    return View(data);
}
```

Solutions (in order of preference):
1. Make the caller `async` — `async Task<ActionResult>`.
2. If stuck in a sync call chain, use `Task.Run(() => _service.GetDataAsync()).Result` — but
   this burns a thread pool thread and should be a last resort.
3. Ensure all library code uses `ConfigureAwait(false)` to reduce (but not eliminate) risk.

### Thread Pool Starvation

Each synchronous blocking call (`Task.Wait()`, `Task.Result`, `Thread.Sleep`) holds a thread pool
thread hostage. Under load, the thread pool cannot grow fast enough, causing request queuing and
timeouts. Monitor with `ThreadPool.GetAvailableThreads()` during load testing.

### Task.Run in ASP.NET

Avoid `Task.Run` in ASP.NET request processing. It queues work to the thread pool without the
request's `SynchronizationContext`, meaning `HttpContext.Current` is null inside the delegate.
It also consumes an additional thread, worsening pool pressure under load.

```csharp
// Wrong — unnecessary thread switch; HttpContext unavailable inside
public async Task<ActionResult> Bad()
{
    var result = await Task.Run(() => _service.ComputeExpensive());
    return View(result);
}

// Correct — if ComputeExpensive is CPU-bound, run it directly
public ActionResult Better()
{
    var result = _service.ComputeExpensive();
    return View(result);
}
```

---

## HttpClient Management

### The Socket Exhaustion Problem

Each `new HttpClient()` creates a new `ServicePoint` and connection pool. Disposing it does not
immediately close sockets — they linger in `TIME_WAIT` for up to 240 seconds. Under load, this
exhausts ephemeral ports.

### Static Instance Pattern

```csharp
public class ExternalApiClient
{
    // Shared across all requests — thread-safe for concurrent calls
    private static readonly HttpClient _client = new HttpClient
    {
        BaseAddress = new Uri("https://api.example.com/"),
        Timeout = TimeSpan.FromSeconds(30)
    };

    static ExternalApiClient()
    {
        _client.DefaultRequestHeaders.Accept.Add(
            new MediaTypeWithQualityHeaderValue("application/json"));
    }

    public async Task<OrderDto> GetOrderAsync(int id, CancellationToken ct)
    {
        var response = await _client.GetAsync($"orders/{id}", ct).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsAsync<OrderDto>(ct).ConfigureAwait(false);
    }
}
```

### DNS Change Handling

A static `HttpClient` caches DNS resolutions indefinitely. When backend services change IP addresses
(common with load balancers, blue/green deploys), the client continues connecting to stale IPs.

```csharp
// Set DNS refresh timeout — call once at application startup
ServicePointManager.DnsRefreshTimeout = (int)TimeSpan.FromMinutes(2).TotalMilliseconds;

// Or per-endpoint
var sp = ServicePointManager.FindServicePoint(new Uri("https://api.example.com"));
sp.ConnectionLeaseTimeout = (int)TimeSpan.FromMinutes(2).TotalMilliseconds;
```

`ConnectionLeaseTimeout` forces connections to be recycled periodically, picking up DNS changes.

### Connection Limit Configuration

The default `ServicePointManager.DefaultConnectionLimit` is 2 per endpoint, which is far too low
for server applications making concurrent outbound calls.

```csharp
// Global.asax Application_Start or OWIN Startup
ServicePointManager.DefaultConnectionLimit = 100; // or Environment.ProcessorCount * 12

// Per-endpoint override
var sp = ServicePointManager.FindServicePoint(new Uri("https://api.example.com"));
sp.ConnectionLimit = 50;
```

---

## Session State

### Provider Comparison

| Provider | Speed | Scalability | Survives Recycle | Web Farm |
|----------|-------|-------------|-----------------|----------|
| `InProc` | Fastest | Single server | No | No |
| `StateServer` | Fast | Multi-server | Yes | Yes |
| `SQLServer` | Moderate | Multi-server | Yes | Yes |
| Redis (custom) | Fast | Multi-server | Yes | Yes |

```xml
<!-- InProc (default) -->
<sessionState mode="InProc" timeout="20" />

<!-- State Server -->
<sessionState mode="StateServer" stateConnectionString="tcpip=server:42424" timeout="20" />

<!-- SQL Server -->
<sessionState mode="SQLServer" sqlConnectionString="Server=.;Database=ASPState;Integrated Security=true"
              timeout="20" />
```

For Redis, use the `Microsoft.Web.RedisSessionStateProvider` NuGet package:

```xml
<sessionState mode="Custom" customProvider="RedisSessionProvider">
  <providers>
    <add name="RedisSessionProvider"
         type="Microsoft.Web.Redis.RedisSessionStateProvider"
         host="redis.example.com"
         port="6380"
         ssl="true"
         accessKey="your-key" />
  </providers>
</sessionState>
```

### Session-less Controllers

Disable session state on controllers that do not need it to avoid the session lock bottleneck.
ASP.NET serializes requests from the same session when session state is enabled.

```csharp
// MVC — disable session for the entire controller
[SessionState(SessionStateBehavior.Disabled)]
public class ApiDataController : Controller
{
    // No session lock — requests from the same user can execute concurrently
}

// Read-only session (no lock contention for reads)
[SessionState(SessionStateBehavior.ReadOnly)]
public class DashboardController : Controller { }
```

For Web API 2, session is disabled by default. Do not enable it — use token-based auth and
application-level caching (`MemoryCache` or distributed cache) instead.

### ViewState Minimization (Web Forms)

If the codebase includes Web Forms pages, minimize ViewState to reduce page size and server
processing.

```aspx
<%-- Disable ViewState per control --%>
<asp:GridView ID="gvOrders" runat="server" EnableViewState="false" />

<%-- Disable ViewState per page --%>
<%@ Page EnableViewState="false" %>
```

```xml
<!-- Disable ViewState globally in Web.config -->
<pages enableViewState="false" />
```

Only re-enable ViewState on controls that require it for postback behavior (editable grids,
form wizards). For read-only data display, ViewState adds no value.
