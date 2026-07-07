# ASP.NET MVC 5 & Web API 2 — Controllers, Routing, Filters, and Content Negotiation

## Controller Design

### Thin Controllers

Controllers are entry points, not business logic containers. Delegate to injected services immediately.

```csharp
// Wrong — business logic in the controller
public class OrderController : ApiController
{
    public IHttpActionResult Post(CreateOrderDto dto)
    {
        if (dto.Quantity <= 0)
            return BadRequest("Quantity must be positive.");

        using (var ctx = new OrderContext())
        {
            var order = new Order { ProductId = dto.ProductId, Quantity = dto.Quantity };
            ctx.Orders.Add(order);
            ctx.SaveChanges();
            return Created($"api/orders/{order.Id}", order);
        }
    }
}

// Correct — controller delegates to a service
public class OrderController : ApiController
{
    private readonly IOrderService _orderService;

    public OrderController(IOrderService orderService)
    {
        _orderService = orderService;
    }

    public IHttpActionResult Post(CreateOrderDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var result = _orderService.Create(dto);
        return Created($"api/orders/{result.Id}", result);
    }
}
```

### MVC Controller vs ApiController

| Aspect | `Controller` (MVC 5) | `ApiController` (Web API 2) |
|--------|---------------------|-----------------------------|
| Namespace | `System.Web.Mvc` | `System.Web.Http` |
| Base return type | `ActionResult` | `IHttpActionResult` |
| Content negotiation | No — returns views or explicit `JsonResult` | Yes — serializes to JSON/XML based on `Accept` header |
| Model binding | `[Bind]`, form values, route data | `[FromBody]`, `[FromUri]` |
| Hosting | IIS only (System.Web pipeline) | IIS or OWIN self-host |
| Filter namespace | `System.Web.Mvc` filters | `System.Web.Http.Filters` filters |

Do not mix `System.Web.Mvc` and `System.Web.Http` namespaces in the same controller — they have
separate filter pipelines, model binders, and dependency resolvers.

### Return Types

```csharp
// MVC 5 — returns ActionResult
public class ProductController : Controller
{
    public ActionResult Index()
    {
        var products = _productService.GetAll();
        return View(products);
    }

    public ActionResult Details(int id)
    {
        var product = _productService.GetById(id);
        if (product == null)
            return HttpNotFound();

        return View(product);
    }

    [HttpPost]
    public ActionResult Create(ProductViewModel model)
    {
        if (!ModelState.IsValid)
            return View(model);

        _productService.Create(model);
        return RedirectToAction("Index");
    }
}

// Web API 2 — returns IHttpActionResult
public class ProductApiController : ApiController
{
    public IHttpActionResult Get()
    {
        var products = _productService.GetAll();
        return Ok(products);                    // 200
    }

    public IHttpActionResult Get(int id)
    {
        var product = _productService.GetById(id);
        if (product == null)
            return NotFound();                  // 404

        return Ok(product);                     // 200
    }

    public IHttpActionResult Post(CreateProductDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);       // 400

        var result = _productService.Create(dto);
        return Created($"api/products/{result.Id}", result); // 201
    }
}
```

### Async Actions

```csharp
// MVC 5 — async
public async Task<ActionResult> Index()
{
    var products = await _productService.GetAllAsync();
    return View(products);
}

// Web API 2 — async
public async Task<IHttpActionResult> Get(int id)
{
    var product = await _productService.GetByIdAsync(id);
    if (product == null)
        return NotFound();

    return Ok(product);
}
```

Always use `async` when calling I/O-bound operations (database, HTTP, file). Never mix `.Result`
or `.Wait()` with `async` — this causes deadlocks under `SynchronizationContext`.

---

## Routing

### Convention-Based Routing (RouteConfig.cs)

MVC 5 uses convention-based routing registered in `App_Start/RouteConfig.cs`:

```csharp
public class RouteConfig
{
    public static void RegisterRoutes(RouteCollection routes)
    {
        routes.IgnoreRoute("{resource}.axd/{*pathInfo}");

        routes.MapRoute(
            name: "Default",
            url: "{controller}/{action}/{id}",
            defaults: new { controller = "Home", action = "Index", id = UrlParameter.Optional }
        );
    }
}
```

Web API 2 convention routes go in `App_Start/WebApiConfig.cs`:

```csharp
public static class WebApiConfig
{
    public static void Register(HttpConfiguration config)
    {
        config.MapHttpAttributeRoutes(); // enable attribute routing first

        config.Routes.MapHttpRoute(
            name: "DefaultApi",
            routeTemplate: "api/{controller}/{id}",
            defaults: new { id = RouteParameter.Optional }
        );
    }
}
```

### Attribute Routing — Preferred for Web API 2

Attribute routing gives explicit control and is the recommended approach for Web API 2.

```csharp
[RoutePrefix("api/orders")]
public class OrderController : ApiController
{
    [HttpGet]
    [Route("")]                              // GET api/orders
    public IHttpActionResult GetAll() { ... }

    [HttpGet]
    [Route("{id:int}")]                      // GET api/orders/5
    public IHttpActionResult GetById(int id) { ... }

    [HttpGet]
    [Route("{id:int}/lines")]                // GET api/orders/5/lines
    public IHttpActionResult GetOrderLines(int id) { ... }

    [HttpPost]
    [Route("")]                              // POST api/orders
    public IHttpActionResult Create(CreateOrderDto dto) { ... }
}
```

### Route Constraints and Defaults

```csharp
// Inline constraints
[Route("{id:int:min(1)}")]                   // id must be int >= 1
[Route("{slug:alpha:maxlength(50)}")]        // slug must be alphabetic, max 50 chars
[Route("{date:datetime}")]                   // date must parse as DateTime

// Default values
[Route("{category=electronics}")]            // defaults to "electronics"
```

### Area Routing in MVC

Areas partition an MVC application into functional groups, each with its own controllers and views.

```csharp
// Areas/Admin/AdminAreaRegistration.cs
public class AdminAreaRegistration : AreaRegistration
{
    public override string AreaName => "Admin";

    public override void RegisterArea(AreaRegistrationContext context)
    {
        context.MapRoute(
            "Admin_default",
            "Admin/{controller}/{action}/{id}",
            new { action = "Index", id = UrlParameter.Optional }
        );
    }
}
```

Register areas before default routes in `Global.asax`:

```csharp
protected void Application_Start()
{
    AreaRegistration.RegisterAllAreas();    // must come first
    RouteConfig.RegisterRoutes(RouteTable.Routes);
}
```

---

## Model Binding & Validation

### Web API 2 — [FromBody] and [FromUri]

Web API 2 uses different sources depending on type complexity:

- **Simple types** (`int`, `string`, `DateTime`) bind from the **URI** (route or query string) by default.
- **Complex types** (objects) bind from the **request body** by default.

Use `[FromBody]` and `[FromUri]` to override defaults explicitly:

```csharp
// Complex type from body (default), simple type from URI (default)
public IHttpActionResult Search([FromUri] string category, [FromBody] SearchFilter filter)
{
    // category comes from ?category=electronics
    // filter is deserialized from request body JSON
}
```

**`[FromBody]` reads the body once.** Only one parameter can use `[FromBody]` per action.

### Data Annotations for Validation

```csharp
public class CreateOrderDto
{
    [Required(ErrorMessage = "Customer ID is required.")]
    public int CustomerId { get; set; }

    [Required]
    [StringLength(200, MinimumLength = 1)]
    public string Description { get; set; }

    [Range(1, 10000, ErrorMessage = "Quantity must be between 1 and 10,000.")]
    public int Quantity { get; set; }

    [EmailAddress]
    public string NotificationEmail { get; set; }
}
```

### ModelState.IsValid — Always Check

```csharp
// Web API 2
public IHttpActionResult Post(CreateOrderDto dto)
{
    if (!ModelState.IsValid)
        return BadRequest(ModelState); // returns 400 with validation errors

    var result = _orderService.Create(dto);
    return Created($"api/orders/{result.Id}", result);
}

// MVC 5
[HttpPost]
[ValidateAntiForgeryToken]
public ActionResult Create(CreateOrderDto dto)
{
    if (!ModelState.IsValid)
        return View(dto); // re-renders form with validation messages

    _orderService.Create(dto);
    return RedirectToAction("Index");
}
```

### Custom Validation Attributes

```csharp
public class FutureDateAttribute : ValidationAttribute
{
    protected override ValidationResult IsValid(object value, ValidationContext context)
    {
        if (value is DateTime date && date <= DateTime.UtcNow)
            return new ValidationResult("Date must be in the future.");

        return ValidationResult.Success;
    }
}

// Usage
public class ScheduleDto
{
    [Required]
    [FutureDate]
    public DateTime DeliveryDate { get; set; }
}
```

---

## Action Filters & Exception Handling

### ActionFilterAttribute Lifecycle

Filters execute in this order around an action:

1. `OnActionExecuting` — before the action method runs
2. **Action method executes**
3. `OnActionExecuted` — after the action method runs
4. `OnResultExecuting` — before the result (view/response) executes
5. **Result executes**
6. `OnResultExecuted` — after the result executes

```csharp
// MVC 5 action filter for performance logging
public class TimingFilterAttribute : ActionFilterAttribute
{
    public override void OnActionExecuting(ActionExecutingContext filterContext)
    {
        filterContext.HttpContext.Items["Stopwatch"] = Stopwatch.StartNew();
    }

    public override void OnActionExecuted(ActionExecutedContext filterContext)
    {
        var sw = (Stopwatch)filterContext.HttpContext.Items["Stopwatch"];
        sw.Stop();
        Debug.WriteLine($"{filterContext.ActionDescriptor.ActionName}: {sw.ElapsedMilliseconds}ms");
    }
}
```

### IAuthorizationFilter — Custom Auth Checks

Authorization filters run before action filters. Use them for custom permission checks.

```csharp
// Web API 2 authorization filter
public class RequireApiKeyAttribute : AuthorizationFilterAttribute
{
    public override void OnAuthorization(HttpActionContext actionContext)
    {
        if (!actionContext.Request.Headers.TryGetValues("X-Api-Key", out var values)
            || values.First() != ConfigurationManager.AppSettings["ApiKey"])
        {
            actionContext.Response = actionContext.Request.CreateResponse(
                HttpStatusCode.Unauthorized, "Invalid API key.");
        }
    }
}
```

### Exception Handling

**MVC 5** — use `IExceptionFilter` or the built-in `HandleErrorAttribute`:

```csharp
// Global.asax
protected void Application_Error(object sender, EventArgs e)
{
    var exception = Server.GetLastError();
    _logger.Error(exception, "Unhandled exception in MVC pipeline");
}
```

**Web API 2** — use `IExceptionHandler` and `IExceptionLogger`:

```csharp
// IExceptionLogger — runs for every unhandled exception; use for logging
public class GlobalExceptionLogger : ExceptionLogger
{
    public override void Log(ExceptionLoggerContext context)
    {
        _logger.Error(context.Exception, "Unhandled API exception: {Path}",
            context.Request.RequestUri);
    }
}

// IExceptionHandler — runs once; produces the final error response
public class GlobalExceptionHandler : ExceptionHandler
{
    public override void Handle(ExceptionHandlerContext context)
    {
        context.Result = new TextPlainErrorResult
        {
            Request = context.ExceptionContext.Request,
            Content = "An internal error occurred. Please contact support."
        };
    }
}

// Register in WebApiConfig.cs
config.Services.Replace(typeof(IExceptionHandler), new GlobalExceptionHandler());
config.Services.Add(typeof(IExceptionLogger), new GlobalExceptionLogger());
```

### Filter Registration

```csharp
// Global — applies to all actions
// MVC 5 (FilterConfig.cs)
filters.Add(new HandleErrorAttribute());

// Web API 2 (WebApiConfig.cs)
config.Filters.Add(new RequireApiKeyAttribute());

// Per-controller
[RequireApiKey]
public class SecureController : ApiController { ... }

// Per-action
public class MixedController : ApiController
{
    [RequireApiKey]
    public IHttpActionResult SensitiveAction() { ... }
}
```

### Order of Filter Execution

Filters execute in this order by type:
1. **Authorization filters** (`IAuthorizationFilter`)
2. **Action filters** (`IActionFilter`) — `OnActionExecuting` / `OnActionExecuted`
3. **Result filters** (`IResultFilter`) — MVC only
4. **Exception filters** (`IExceptionFilter`)

Within the same filter type, execution order is: Global → Controller → Action.

---

## Content Negotiation (Web API 2)

### Built-in Formatters

Web API 2 includes `JsonMediaTypeFormatter` (using Json.NET) and `XmlMediaTypeFormatter`.
The framework selects the formatter based on the `Accept` header.

### Configuring JSON Serialization

```csharp
// WebApiConfig.cs
public static void Register(HttpConfiguration config)
{
    var jsonSettings = config.Formatters.JsonFormatter.SerializerSettings;

    jsonSettings.ContractResolver = new CamelCasePropertyNamesContractResolver();
    jsonSettings.DateTimeZoneHandling = DateTimeZoneHandling.Utc;
    jsonSettings.NullValueHandling = NullValueHandling.Ignore;
    jsonSettings.ReferenceLoopHandling = ReferenceLoopHandling.Ignore;
    jsonSettings.Converters.Add(new StringEnumConverter());
}
```

### JSON-Only API — Remove XML Formatter

Most modern APIs serve JSON exclusively. Remove the XML formatter to avoid unexpected XML responses
when clients send `Accept: application/xml`:

```csharp
config.Formatters.Remove(config.Formatters.XmlFormatter);
```

### Custom MediaTypeFormatter

```csharp
public class CsvFormatter : MediaTypeFormatter
{
    public CsvFormatter()
    {
        SupportedMediaTypes.Add(new MediaTypeHeaderValue("text/csv"));
    }

    public override bool CanReadType(Type type) => false;

    public override bool CanWriteType(Type type) =>
        typeof(IEnumerable).IsAssignableFrom(type);

    public override async Task WriteToStreamAsync(Type type, object value,
        Stream writeStream, HttpContent content, TransportContext transportContext)
    {
        using (var writer = new StreamWriter(writeStream))
        {
            // Write CSV rows from the enumerable
            foreach (var item in (IEnumerable)value)
            {
                await writer.WriteLineAsync(FormatCsvRow(item));
            }
        }
    }
}

// Register in WebApiConfig.cs
config.Formatters.Add(new CsvFormatter());
```

---

## Bundling & Minification

### BundleConfig.cs Setup

```csharp
// App_Start/BundleConfig.cs
public class BundleConfig
{
    public static void RegisterBundles(BundleCollection bundles)
    {
        bundles.Add(new ScriptBundle("~/bundles/jquery")
            .Include("~/Scripts/jquery-{version}.js"));

        bundles.Add(new ScriptBundle("~/bundles/app")
            .Include("~/Scripts/site.js",
                     "~/Scripts/validation.js",
                     "~/Scripts/orders.js"));

        bundles.Add(new StyleBundle("~/Content/css")
            .Include("~/Content/bootstrap.css",
                     "~/Content/site.css"));
    }
}
```

Register in `Global.asax`:

```csharp
protected void Application_Start()
{
    BundleConfig.RegisterBundles(BundleTable.Bundles);
}
```

### Rendering in Views

```html
<!-- In _Layout.cshtml -->
<head>
    @Styles.Render("~/Content/css")
</head>
<body>
    @RenderBody()
    @Scripts.Render("~/bundles/jquery")
    @Scripts.Render("~/bundles/app")
</body>
```

### Debug vs Release Behavior

In **Debug** mode (`<compilation debug="true">`), bundling renders individual `<script>` and `<link>`
tags — making it easy to debug with source files.

In **Release** mode (`debug="false"`), bundling concatenates and minifies files into a single request
with a cache-busting query string.

Force bundling behavior regardless of debug mode:

```csharp
// In BundleConfig.cs or Application_Start
BundleTable.EnableOptimizations = true;  // force minification even in debug
BundleTable.EnableOptimizations = false; // force individual files even in release
```
