# .NET Framework 4.x — Architecture & Dependency Injection

## Project Structure & Layering

A well-structured .NET Framework solution separates concerns into distinct projects (assemblies).
Assembly references flow inward: outer layers reference inner layers, never the reverse. Interface
definitions live in inner layers; implementations live in outer/infrastructure layers.

Recommended solution layout:

```
MyApp.sln
├── MyApp.Web/                    # Presentation — MVC 5 / Web API 2 controllers, views, filters
│   ├── Controllers/
│   ├── Views/
│   ├── App_Start/                # RouteConfig, BundleConfig, WebApiConfig, DI bootstrapping
│   ├── Global.asax               # Application lifecycle
│   └── Startup.cs                # OWIN startup (if using OWIN)
│
├── MyApp.Application/            # Application/Service layer — orchestration, DTOs, use cases
│   ├── Interfaces/               # IOrderService, INotificationService
│   ├── Services/                 # OrderService, NotificationService implementations
│   └── Dtos/                     # Data transfer objects for boundary crossing
│
├── MyApp.Domain/                 # Domain layer — entities, value objects, domain interfaces
│   ├── Entities/                 # Order, Customer, Product
│   ├── ValueObjects/             # Money, Address
│   └── Interfaces/               # IOrderRepository, IUnitOfWork
│
└── MyApp.Infrastructure/         # Infrastructure — EF6 DbContext, repositories, external services
    ├── Data/                     # OrderContext, EF configurations, migrations
    ├── Repositories/             # OrderRepository : IOrderRepository
    └── ExternalServices/         # EmailGateway, PaymentGateway
```

**Key rules:**

- `MyApp.Domain` references nothing else (no project references, minimal NuGet packages).
- `MyApp.Application` references `MyApp.Domain`.
- `MyApp.Infrastructure` references `MyApp.Domain` (to implement its interfaces).
- `MyApp.Web` references `MyApp.Application`, `MyApp.Domain`, and `MyApp.Infrastructure`.

The web project is the only one that sees all layers because it hosts the Composition Root.

---

## DI Container Setup

.NET Framework has no built-in dependency injection. The three most common third-party containers are
Unity, Autofac, and Ninject. Each follows the same principle: register abstractions to implementations
in one place, then let the container resolve the entire object graph.

### Unity

Install: `Unity.Mvc5` and `Unity.WebAPI` NuGet packages.

```csharp
using Unity;
using Unity.Lifetime;

public static class UnityConfig
{
    public static IUnityContainer RegisterComponents()
    {
        var container = new UnityContainer();

        // Transient — new instance every time (default)
        container.RegisterType<IOrderService, OrderService>(
            new TransientLifetimeManager());

        // Per-request — one instance per HTTP request, disposed at request end
        container.RegisterType<IOrderRepository, OrderRepository>(
            new PerRequestLifetimeManager());

        // Per-request for DbContext — critical for consistent reads/writes within a request
        container.RegisterType<OrderContext>(
            new PerRequestLifetimeManager());

        // Singleton — one instance for the application lifetime
        container.RegisterType<IConfigService, ConfigService>(
            new ContainerControlledLifetimeManager());

        // Hierarchical — one instance per child container (useful for scoped work)
        container.RegisterType<IUnitOfWork, UnitOfWork>(
            new HierarchicalLifetimeManager());

        return container;
    }
}
```

### Autofac

Install: `Autofac.Mvc5` and `Autofac.WebApi2` NuGet packages.

```csharp
using Autofac;
using Autofac.Integration.Mvc;
using Autofac.Integration.WebApi;

public static class AutofacConfig
{
    public static IContainer RegisterComponents()
    {
        var builder = new ContainerBuilder();

        // Register MVC controllers
        builder.RegisterControllers(typeof(MvcApplication).Assembly);

        // Register Web API controllers
        builder.RegisterApiControllers(typeof(MvcApplication).Assembly);

        // Per-request — tied to HTTP request lifetime, auto-disposed
        builder.RegisterType<OrderRepository>()
            .As<IOrderRepository>()
            .InstancePerRequest();

        builder.RegisterType<OrderContext>()
            .AsSelf()
            .InstancePerRequest();

        // Per-lifetime-scope — one instance per scope (useful in background tasks)
        builder.RegisterType<UnitOfWork>()
            .As<IUnitOfWork>()
            .InstancePerLifetimeScope();

        // Singleton — shared across all requests for the app lifetime
        builder.RegisterType<ConfigService>()
            .As<IConfigService>()
            .SingleInstance();

        // Transient — new instance per resolution (default)
        builder.RegisterType<OrderService>()
            .As<IOrderService>()
            .InstancePerDependency();

        // Module-based registration for large projects
        builder.RegisterModule<InfrastructureModule>();

        return builder.Build();
    }
}

// Autofac modules keep registrations organized by layer
public class InfrastructureModule : Module
{
    protected override void Load(ContainerBuilder builder)
    {
        builder.RegisterType<EmailGateway>().As<IEmailGateway>().SingleInstance();
        builder.RegisterType<PaymentGateway>().As<IPaymentGateway>().InstancePerRequest();
    }
}
```

### Ninject

Install: `Ninject.MVC5` and `Ninject.Web.WebApi` NuGet packages.

```csharp
using Ninject;
using Ninject.Web.Common;

public static class NinjectConfig
{
    public static StandardKernel CreateKernel()
    {
        var kernel = new StandardKernel();

        // Per-request — scoped to the HTTP request
        kernel.Bind<IOrderRepository>().To<OrderRepository>().InRequestScope();
        kernel.Bind<OrderContext>().ToSelf().InRequestScope();

        // Singleton — one instance for the application lifetime
        kernel.Bind<IConfigService>().To<ConfigService>().InSingletonScope();

        // Transient — new instance each time (default)
        kernel.Bind<IOrderService>().To<OrderService>().InTransientScope();

        return kernel;
    }
}
```

---

## Composition Root Pattern

The Composition Root is the single location where the entire object graph is wired together. It runs
once at application startup and is the only place that knows about the DI container. All other code
receives dependencies through constructor injection and has no awareness of the container.

**Why it matters:** A single wiring point makes dependency graphs explicit, catches missing
registrations at startup rather than at runtime, and keeps the container from leaking into
business logic.

### Global.asax — Application_Start

```csharp
public class MvcApplication : HttpApplication
{
    protected void Application_Start()
    {
        // Standard ASP.NET setup
        AreaRegistration.RegisterAllAreas();
        FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
        RouteConfig.RegisterRoutes(RouteTable.Routes);
        BundleConfig.RegisterBundles(BundleTable.Bundles);

        // --- Composition Root: Unity example ---
        var container = UnityConfig.RegisterComponents();

        // Wire to MVC
        DependencyResolver.SetResolver(new UnityDependencyResolver(container));

        // Wire to Web API
        GlobalConfiguration.Configuration.DependencyResolver =
            new UnityDependencyResolver(container);
    }
}
```

### OWIN Startup Class

When using OWIN/Katana, configure the container in the `Startup` class. This decouples initialization
from `System.Web` and makes the application more testable.

```csharp
using Owin;
using Autofac;
using Autofac.Integration.Mvc;
using Autofac.Integration.WebApi;

[assembly: OwinStartup(typeof(MyApp.Web.Startup))]

public class Startup
{
    public void Configuration(IAppBuilder app)
    {
        var container = AutofacConfig.RegisterComponents();

        // Wire to MVC
        DependencyResolver.SetResolver(new AutofacDependencyResolver(container));

        // Wire to Web API
        var httpConfig = new HttpConfiguration();
        httpConfig.DependencyResolver = new AutofacWebApiDependencyResolver(container);
        WebApiConfig.Register(httpConfig);

        // Register OWIN middleware
        app.UseAutofacMiddleware(container);
        app.UseAutofacMvc();
        app.UseWebApi(httpConfig);
    }
}
```

### Web API IDependencyResolver / IDependencyScope

Web API uses its own `IDependencyResolver` interface (in `System.Web.Http.Dependencies`), separate
from MVC's `System.Web.Mvc.IDependencyResolver`. Each container's integration package provides both.
The key method is `BeginScope()`, which creates a child scope per request so that per-request
registrations are properly isolated and disposed.

```csharp
// Custom IDependencyResolver for Unity (simplified — use Unity.WebAPI package in practice)
public class UnityDependencyResolver : IDependencyResolver
{
    private readonly IUnityContainer _container;

    public UnityDependencyResolver(IUnityContainer container)
    {
        _container = container;
    }

    public IDependencyScope BeginScope()
    {
        // Child container ensures per-request lifetime isolation
        var child = _container.CreateChildContainer();
        return new UnityDependencyScope(child);
    }

    public object GetService(Type serviceType)
    {
        try { return _container.Resolve(serviceType); }
        catch (ResolutionFailedException) { return null; }
    }

    public IEnumerable<object> GetServices(Type serviceType)
    {
        try { return _container.ResolveAll(serviceType); }
        catch (ResolutionFailedException) { return Enumerable.Empty<object>(); }
    }

    public void Dispose() => _container.Dispose();
}
```

---

## Service Locator Anti-Pattern

The Service Locator pattern calls `container.Resolve<T>()` from inside business logic instead of
receiving dependencies through the constructor. This is an anti-pattern for three reasons:

1. **Hidden dependencies.** The class signature does not reveal what it needs. You must read the
   entire implementation to discover its dependencies.
2. **Runtime failures.** Missing registrations cause exceptions at the point of use, not at startup.
   Constructor injection surfaces missing registrations immediately when the container builds the graph.
3. **Hard to test.** Tests must set up a container or mock the service locator itself, rather than
   simply passing in test doubles through the constructor.

### Recognizing the Anti-Pattern

```csharp
// Service Locator — WRONG
public class OrderService
{
    public void PlaceOrder(OrderDto dto)
    {
        // Dependencies are hidden — discovered only by reading the method body
        var repo = DependencyResolver.Current.GetService<IOrderRepository>();
        var emailSvc = DependencyResolver.Current.GetService<IEmailService>();
        var validator = DependencyResolver.Current.GetService<IOrderValidator>();

        validator.Validate(dto);
        var order = repo.Save(MapToEntity(dto));
        emailSvc.SendConfirmation(order);
    }
}
```

### Refactored to Constructor Injection

```csharp
// Constructor injection — CORRECT
public class OrderService : IOrderService
{
    private readonly IOrderRepository _repo;
    private readonly IEmailService _emailSvc;
    private readonly IOrderValidator _validator;

    public OrderService(
        IOrderRepository repo,
        IEmailService emailSvc,
        IOrderValidator validator)
    {
        _repo = repo;
        _emailSvc = emailSvc;
        _validator = validator;
    }

    public void PlaceOrder(OrderDto dto)
    {
        _validator.Validate(dto);
        var order = _repo.Save(MapToEntity(dto));
        _emailSvc.SendConfirmation(order);
    }
}
```

### When Factories Are Acceptable

Sometimes the implementation to use is not known until runtime (e.g., the payment gateway depends on
the customer's region). In these cases, inject a factory — not the container.

```csharp
// Factory interface — lives in the Application or Domain layer
public interface IPaymentGatewayFactory
{
    IPaymentGateway Create(string region);
}

// Factory implementation — lives in Infrastructure, registered in the container
public class PaymentGatewayFactory : IPaymentGatewayFactory
{
    public IPaymentGateway Create(string region)
    {
        switch (region)
        {
            case "US": return new StripeGateway();
            case "EU": return new AdyenGateway();
            default:   return new DefaultGateway();
        }
    }
}

// Service uses the factory — no container reference anywhere
public class CheckoutService
{
    private readonly IPaymentGatewayFactory _gatewayFactory;

    public CheckoutService(IPaymentGatewayFactory gatewayFactory)
    {
        _gatewayFactory = gatewayFactory;
    }

    public void Checkout(Order order)
    {
        var gateway = _gatewayFactory.Create(order.Customer.Region);
        gateway.Charge(order.Total);
    }
}
```

---

## Lifetime Management

Choosing the right lifetime for each registration prevents memory leaks, data corruption, and
subtle concurrency bugs. The three fundamental lifetimes are per-request, singleton, and transient.

### Per-Request Scope

Use for: `DbContext`, `IUnitOfWork`, repositories, anything that holds request-specific state.

*Why:* A `DbContext` scoped to the request ensures all repositories within the same request share
the same context, change tracker, and transaction boundary. The context is disposed at request end.

| Container | Registration |
|-----------|-------------|
| Unity     | `new PerRequestLifetimeManager()` |
| Autofac   | `.InstancePerRequest()` |
| Ninject   | `.InRequestScope()` |

### Singleton

Use for: `HttpClient` wrappers, configuration readers, caches, thread-safe stateless services.

*Why:* A single instance avoids repeated initialization and (for `HttpClient`) prevents socket
exhaustion. The object must be thread-safe because it is shared across all requests.

| Container | Registration |
|-----------|-------------|
| Unity     | `new ContainerControlledLifetimeManager()` |
| Autofac   | `.SingleInstance()` |
| Ninject   | `.InSingletonScope()` |

### Transient

Use for: stateless services, validators, mappers — anything with no shared state.

*Why:* Each consumer gets its own instance, eliminating any risk of shared mutable state.
This is the safest default but has slightly higher allocation cost than singleton.

| Container | Registration |
|-----------|-------------|
| Unity     | `new TransientLifetimeManager()` (default) |
| Autofac   | `.InstancePerDependency()` (default) |
| Ninject   | `.InTransientScope()` (default) |

### Common Lifetime Mistakes

**Captive dependency (singleton holding a scoped reference):**

```csharp
// WRONG — singleton OrderCache holds per-request OrderContext
// The OrderContext is created once and reused across all requests
container.RegisterType<IOrderCache, OrderCache>(
    new ContainerControlledLifetimeManager());  // singleton

container.RegisterType<OrderContext>(
    new PerRequestLifetimeManager());            // per-request

public class OrderCache : IOrderCache
{
    private readonly OrderContext _ctx; // injected once, stale after first request

    public OrderCache(OrderContext ctx) { _ctx = ctx; }
}
```

The `OrderContext` is resolved once when the singleton is created and then held forever. After the
first request ends, the context is disposed but the singleton still references it, causing
`ObjectDisposedException` on subsequent requests.

**Fix:** Either make `OrderCache` per-request, or inject `Func<OrderContext>` (Autofac supports this
natively) so the singleton can create a fresh context when needed.

**Manually disposing container-managed objects:**

```csharp
// WRONG — the container manages the DbContext lifetime
public class OrderService
{
    private readonly OrderContext _ctx;

    public OrderService(OrderContext ctx) { _ctx = ctx; }

    public void Save(Order order)
    {
        _ctx.Orders.Add(order);
        _ctx.SaveChanges();
        _ctx.Dispose(); // other services sharing this context will fail
    }
}
```

Never call `Dispose()` on objects managed by the container. The container disposes them at the end
of their configured lifetime scope. Manual disposal breaks other consumers that share the same
scoped instance.
