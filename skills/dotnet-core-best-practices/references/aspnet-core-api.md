# ASP.NET Core API Patterns

Reference for Minimal API vs Controllers, endpoint routing, model binding, filters, output caching, rate limiting, API versioning, and OpenAPI on .NET 8/10.

## Table of contents
- [Minimal API vs Controllers](#minimal-api-vs-controllers)
- [Endpoint routing](#endpoint-routing)
- [Model binding and validation](#model-binding-and-validation)
- [Filters and middleware](#filters-and-middleware)
- [Output caching](#output-caching)
- [Rate limiting](#rate-limiting)
- [API versioning](#api-versioning)
- [OpenAPI and Swagger](#openapi-and-swagger)

---

## Minimal API vs Controllers

### When to use which

| Factor | Minimal API | Controllers |
|--------|------------|-------------|
| Simple CRUD, few endpoints | Preferred | Works |
| Microservices, small APIs | Preferred | Overkill |
| Complex filter pipelines | Limited | Preferred |
| API versioning | Supported (.NET 7+) | Better tooling |
| Native AOT support | Better (.NET 8+) | Limited |

Both styles can coexist in the same project — useful for incremental migration or mixed complexity.

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();

app.MapGet("/health", () => Results.Ok("healthy"));   // Minimal API
app.MapControllers();                                   // Controllers
app.Run();
```

---

## Endpoint routing

### MapGet, MapPost, MapPut, MapDelete

```csharp
app.MapGet("/api/orders", async (IOrderService svc, CancellationToken ct) =>
    Results.Ok(await svc.GetAllAsync(ct)));

app.MapPost("/api/orders", async (CreateOrderDto dto, IOrderService svc, CancellationToken ct) =>
{
    var order = await svc.CreateAsync(dto, ct);
    return Results.Created($"/api/orders/{order.Id}", order);
});

app.MapPut("/api/orders/{id:int}", async (int id, UpdateOrderDto dto, IOrderService svc, CancellationToken ct) =>
{
    await svc.UpdateAsync(id, dto, ct);
    return Results.NoContent();
});

app.MapDelete("/api/orders/{id:int}", async (int id, IOrderService svc, CancellationToken ct) =>
{
    await svc.DeleteAsync(id, ct);
    return Results.NoContent();
});
```

### Route parameters and constraints

```csharp
app.MapGet("/api/users/{id:int}", ...);              // integer
app.MapGet("/api/users/{name:alpha}", ...);           // letters only
app.MapGet("/api/users/{id:int:min(1)}", ...);        // minimum value
app.MapGet("/api/items/{slug:length(3,50)}", ...);    // string length
app.MapGet("/api/orders/{date:datetime}", ...);       // DateTime
```

Common constraints: `int`, `long`, `guid`, `bool`, `decimal`, `double`, `alpha`, `minlength(n)`, `maxlength(n)`, `length(min,max)`, `min(n)`, `max(n)`, `range(min,max)`, `regex(pattern)`.

### Route groups (.NET 7+)

`MapGroup` organizes endpoints under a common prefix with shared configuration.

```csharp
var orders = app.MapGroup("/api/orders")
    .RequireAuthorization()
    .WithTags("Orders");

orders.MapGet("/", GetAllOrders);
orders.MapGet("/{id:int}", GetOrderById);
orders.MapPost("/", CreateOrder);
orders.MapDelete("/{id:int}", DeleteOrder);

// Nested groups
var admin = app.MapGroup("/api/admin").RequireAuthorization("AdminOnly");
admin.MapGroup("/orders").MapPost("/bulk-delete", BulkDeleteOrders);
```

### Endpoint metadata

```csharp
app.MapGet("/api/products", GetProducts)
    .WithName("GetProducts")
    .WithTags("Products")
    .Produces<List<ProductDto>>(200)
    .Produces(404)
    .RequireAuthorization("ReadProducts")
    .CacheOutput("ProductCache");
```

---

## Model binding and validation

### Automatic binding sources

```csharp
app.MapGet("/api/search", async (
    [FromQuery] string term,
    [FromHeader(Name = "X-Correlation-Id")] string correlationId,
    ISearchService svc,            // from DI (implicit)
    CancellationToken ct           // auto-bound
) => Results.Ok(await svc.SearchAsync(term, ct)));

app.MapPost("/api/orders", async (
    CreateOrderDto dto,            // complex type = from body (implicit)
    IOrderService svc,
    CancellationToken ct
) => Results.Created($"/api/orders/{dto.Id}", await svc.CreateAsync(dto, ct)));
```

### AsParameters for complex binding (.NET 7+)

Binds a type's properties from multiple sources without `[FromBody]`.

```csharp
public record GetOrdersRequest(
    [FromQuery] int Page,
    [FromQuery] int PageSize,
    [FromQuery] string? Status,
    [FromHeader(Name = "X-Tenant-Id")] string TenantId,
    IOrderService OrderService
);

app.MapGet("/api/orders", async ([AsParameters] GetOrdersRequest req, CancellationToken ct) =>
    Results.Ok(await req.OrderService.GetPagedAsync(req.Page, req.PageSize, req.Status, req.TenantId, ct)));
```

### FluentValidation integration

```csharp
public class CreateOrderValidator : AbstractValidator<CreateOrderDto>
{
    public CreateOrderValidator()
    {
        RuleFor(x => x.CustomerId).GreaterThan(0);
        RuleFor(x => x.Items).NotEmpty()
            .Must(items => items.Count <= 100).WithMessage("Max 100 items.");
        RuleForEach(x => x.Items).ChildRules(item =>
        {
            item.RuleFor(i => i.Quantity).GreaterThan(0);
            item.RuleFor(i => i.ProductId).NotEmpty();
        });
    }
}

builder.Services.AddScoped<IValidator<CreateOrderDto>, CreateOrderValidator>();
```

### Built-in validation (.NET 10+) — reach for this first

```csharp
// <PackageReference Include="Microsoft.Extensions.Validation" Version="10.0.1" />
builder.Services.AddValidation();   // discovers validatable types, wires the endpoint filter itself

// DataAnnotations / IValidatableObject on the bound type are enforced automatically; 400 on failure.
app.MapPost("/api/orders", CreateOrder);

// Opt a single endpoint out
app.MapPost("/api/internal/bulk", BulkImport).DisableValidation();
```

Shape the 400 body by registering an `IProblemDetailsService`.

### IEndpointFilter for validation (.NET 7–9, or FluentValidation rules on .NET 10+)

Centralizes validation so handlers stay focused on business logic. Hand-write this only when targeting pre-.NET 10, or when the rules go beyond what DataAnnotations can express.

```csharp
public class ValidationFilter<T>(IValidator<T> validator) : IEndpointFilter where T : class
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var model = context.Arguments.OfType<T>().FirstOrDefault();
        if (model is null) return Results.BadRequest("Request body is required.");

        var result = await validator.ValidateAsync(model);
        return result.IsValid ? await next(context) : Results.ValidationProblem(result.ToDictionary());
    }
}

app.MapPost("/api/orders", CreateOrder).AddEndpointFilter<ValidationFilter<CreateOrderDto>>();
```

### TypedResults for compile-time checking (.NET 7+)

```csharp
// Returns Results<Ok<Product>, NotFound> — compile-time checked, auto-documents OpenAPI.
app.MapGet("/api/products/{id}", Results<Ok<Product>, NotFound> (int id) =>
    id > 0 ? TypedResults.Ok(new Product(id)) : TypedResults.NotFound());
```

---

## Filters and middleware

### IEndpointFilter for Minimal API (.NET 7+)

```csharp
public class LoggingFilter(ILogger<LoggingFilter> logger) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var stopwatch = Stopwatch.StartNew();
        var result = await next(context);
        logger.LogInformation("Handled {Path} in {Elapsed}ms",
            context.HttpContext.Request.Path, stopwatch.ElapsedMilliseconds);
        return result;
    }
}

app.MapGroup("/api/orders").AddEndpointFilter<LoggingFilter>();
```

### Controller filters

```csharp
public class AuditFilter : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        // pre-processing
        var result = await next();
        // post-processing
    }
}

public class DomainExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is DomainException ex)
        {
            context.Result = new ObjectResult(new ProblemDetails
            {
                Status = 422, Title = "Domain rule violation", Detail = ex.Message
            }) { StatusCode = 422 };
            context.ExceptionHandled = true;
        }
    }
}

builder.Services.AddControllers(o => { o.Filters.Add<AuditFilter>(); o.Filters.Add<DomainExceptionFilter>(); });
```

### Middleware vs filters

| Concern | Middleware | Filters |
|---------|-----------|---------|
| Every request (logging, correlation ID) | Yes | No |
| Specific endpoints only | No | Yes |
| Needs model binding / endpoint metadata | No | Yes |
| Runs before routing | Yes | No |

### Custom middleware

```csharp
public class CorrelationIdMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var id = context.Request.Headers["X-Correlation-Id"].FirstOrDefault()
            ?? Guid.NewGuid().ToString("N");
        context.Response.Headers["X-Correlation-Id"] = id;
        using (context.RequestServices.GetRequiredService<ILogger<CorrelationIdMiddleware>>()
            .BeginScope(new Dictionary<string, object> { ["CorrelationId"] = id }))
        {
            await next(context);
        }
    }
}

app.UseMiddleware<CorrelationIdMiddleware>();  // before UseRouting
```

---

## Output caching

Output caching (.NET 7+) stores entire HTTP responses server-side and replays them, bypassing the handler. Distinct from response caching which uses HTTP headers for client/proxy caching.

```csharp
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(b => b.Expire(TimeSpan.FromSeconds(60)));
    options.AddPolicy("ProductCache", b => b
        .Expire(TimeSpan.FromMinutes(5))
        .SetVaryByQuery("category", "page")
        .Tag("products"));
    options.AddPolicy("ByUser", b => b
        .SetVaryByHeader("Authorization")
        .Expire(TimeSpan.FromMinutes(2)));
});

app.UseOutputCache();
app.MapGet("/api/products", GetProducts).CacheOutput("ProductCache");
```

### Cache invalidation with tags

```csharp
app.MapPost("/api/products", async (
    CreateProductDto dto, IProductService svc, IOutputCacheStore cache, CancellationToken ct) =>
{
    var product = await svc.CreateAsync(dto, ct);
    await cache.EvictByTagAsync("products", ct);  // invalidate all "products" entries
    return Results.Created($"/api/products/{product.Id}", product);
});
```

Policy methods: `Expire`, `SetVaryByQuery`, `SetVaryByHeader`, `SetVaryByRouteValue`, `Tag`, `NoCache`.

---

## Rate limiting

Built-in rate limiting (.NET 7+) with four algorithms: fixed window, sliding window, token bucket, concurrency.

```csharp
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("fixed", c =>
        { c.PermitLimit = 100; c.Window = TimeSpan.FromMinutes(1); });

    options.AddSlidingWindowLimiter("sliding", c =>
        { c.PermitLimit = 100; c.Window = TimeSpan.FromMinutes(1); c.SegmentsPerWindow = 4; });

    options.AddTokenBucketLimiter("token", c =>
        { c.TokenLimit = 50; c.ReplenishmentPeriod = TimeSpan.FromSeconds(10); c.TokensPerPeriod = 10; });

    options.AddConcurrencyLimiter("concurrent", c =>
        { c.PermitLimit = 10; c.QueueLimit = 5; });

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

app.UseRateLimiter();
app.MapGet("/api/search", SearchProducts).RequireRateLimiting("sliding");
app.MapGroup("/api/public").RequireRateLimiting("fixed");
```

### Custom partitioning (by user, by IP)

```csharp
options.AddPolicy("per-user", context =>
{
    var key = context.User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? context.Connection.RemoteIpAddress?.ToString() ?? "anonymous";
    return RateLimitPartition.GetFixedWindowLimiter(key,
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 60, Window = TimeSpan.FromMinutes(1) });
});
```

---

## API versioning

Uses `Asp.Versioning.Http` (Minimal API) or `Asp.Versioning.Mvc` (Controllers).

```csharp
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new QueryStringApiVersionReader("api-version"),
        new HeaderApiVersionReader("X-Api-Version"));
});
```

### URL path versioning

```csharp
// Minimal API
var v1 = app.NewVersionedApi().MapGroup("/api/v{version:apiVersion}/products");
v1.MapGet("/", GetProductsV1).HasApiVersion(1.0);
v1.MapGet("/", GetProductsV1Old).HasDeprecatedApiVersion(1.0);

// Controllers
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[ApiVersion("2.0")]
public class ProductsController : ControllerBase { ... }
```

Deprecation adds response headers: `api-supported-versions: 2.0`, `api-deprecated-versions: 1.0`.

---

## OpenAPI and Swagger

### Built-in OpenAPI (.NET 9+)

```csharp
builder.Services.AddOpenApi();
app.MapOpenApi();  // serves /openapi/v1.json
```

#### Document and schema transformers

```csharp
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer((document, context, ct) =>
    {
        document.Info.Contact = new() { Name = "API Team", Email = "api@example.com" };
        document.Servers = [new() { Url = "https://api.example.com" }];
        return Task.CompletedTask;
    });

    options.AddSchemaTransformer((schema, context, ct) =>
    {
        if (context.JsonTypeInfo.Type == typeof(DateTime))
            schema.Format = "date-time";
        return Task.CompletedTask;
    });
});
```

#### ProblemDetails for standard errors

```csharp
builder.Services.AddProblemDetails();
app.UseStatusCodePages();
app.UseExceptionHandler();

app.MapGet("/api/products/{id:int}", Results<Ok<Product>, ProblemHttpResult> (int id, IProductService svc) =>
    svc.Get(id) is { } p ? TypedResults.Ok(p)
        : TypedResults.Problem(statusCode: 404, title: "Product not found", detail: $"id={id}"));
```

Use `[Description("...")]` on DTO properties / record parameters to surface descriptions in OpenAPI schema.

### Swashbuckle for .NET 6/7/8

```csharp
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
    o.SwaggerDoc("v1", new OpenApiInfo { Title = "Orders API", Version = "v1" }));

if (app.Environment.IsDevelopment()) { app.UseSwagger(); app.UseSwaggerUI(); }
```

### Annotating Minimal API endpoints

```csharp
app.MapGet("/api/products/{id:int}", GetProduct)
    .WithName("GetProductById")
    .WithSummary("Get a product by ID")
    .WithDescription("Returns 404 if the product does not exist.")
    .WithTags("Products")
    .Produces<ProductDto>(200)
    .Produces(404);
```

### Per-endpoint OpenAPI metadata

.NET 10+ — `AddOpenApiOperationTransformer()`. `WithOpenApi()` still compiles but is deprecated (diagnostic `ASPDEPR002`):

```csharp
app.MapPost("/api/orders", CreateOrder)
    .AddOpenApiOperationTransformer((operation, context, ct) =>
    {
        operation.Summary = "Create a new order";
        operation.Responses["201"].Description = "Order created successfully";
        return Task.CompletedTask;
    });
```

.NET 8/9 — `WithOpenApi()`:

```csharp
app.MapPost("/api/orders", CreateOrder)
    .WithOpenApi(op =>
    {
        op.Summary = "Create a new order";
        op.Responses["201"].Description = "Order created successfully";
        return op;
    });
```

### Controller XML docs

Enable in `.csproj` with `<GenerateDocumentationFile>true</GenerateDocumentationFile>`, then configure Swashbuckle:

```csharp
builder.Services.AddSwaggerGen(o =>
    o.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory,
        $"{Assembly.GetExecutingAssembly().GetName().Name}.xml")));
```
