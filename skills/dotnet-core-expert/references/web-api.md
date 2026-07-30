---
title: ASP.NET Core Web API (Controllers) - 範例與規範
---

# ASP.NET Core Web API（Controllers） 範例與規範

本文件彙整常用範例、實作規範與最佳實務，供 `dotnet-core-expert` skill 在建立或審查 ASP.NET Core Web API（使用 Controllers）時參考。

**適用場景**：建立 RESTful API、採用 Clean Architecture、使用 Entity Framework Core、需 JWT 驗證或 OpenAPI 文件化。

## 目標要點
- 使用 .NET 8 與 C# 12 功能
- 啟用 nullable reference types
- 所有 I/O 使用 async/await
- 不直接暴露實體（Entity）於 API 回應，使用 DTO/record
- 統一錯誤處理（middleware）與日誌
- 使用 DI、分層與單一職責原則

## 命名與風格約定
- Controllers: `{Resource}Controller`（例如 `UsersController`）
- Action 方法: 描述性方法名稱（`GetUser`, `CreateOrder`）
- DTO: 使用 `record` 類型（不可變）
- 非同步方法後綴 `Async`（例如 `GetUsersAsync`）

## 範例：最小可用 Controller

```csharp
[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly ILogger<UsersController> _logger;

    public UsersController(IUserService userService, ILogger<UsersController> logger)
    {
        _userService = userService;
        _logger = logger;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<UserDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<UserDto>>> GetUsersAsync([FromQuery] UserQueryParameters parameters)
    {
        var users = await _userService.GetUsersAsync(parameters);
        return Ok(users);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserDto>> GetUserAsync(int id)
    {
        var user = await _userService.GetByIdAsync(id);
        if (user == null) return NotFound();
        return Ok(user);
    }

    [HttpPost]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<UserDto>> CreateUserAsync([FromBody] CreateUserRequest request)
    {
        var created = await _userService.CreateAsync(request);
        return CreatedAtAction(nameof(GetUserAsync), new { id = created.Id }, created);
    }
}
```

## DTO 與驗證範例

```csharp
public record UserDto(int Id, string Name, string Email);

public record CreateUserRequest
{
    [Required]
    [StringLength(100)]
    public string Name { get; init; }

    [Required]
    [EmailAddress]
    public string Email { get; init; }
}
```

建議使用 FluentValidation 或 DataAnnotations 於輸入層驗證，並在 Controller 或管線中統一回傳 400/422 格式。

## 分頁、排序與篩選（範例）

透過 query parameters 傳遞分頁資訊，Service 層負責資料存取與預防 N+1 問題。

```csharp
public class UserQueryParameters
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public string? Search { get; set; }
}

// Controller action 應回傳分頁元資料與資料集合
```

## 錯誤處理與問題詳述（Problem Details）

推薦使用 RFC 7807 的 Problem Details 格式，並建立全域例外中介軟體：

```csharp
app.UseExceptionHandler(new ExceptionHandlerOptions
{
    ExceptionHandler = async ctx =>
    {
        var ex = ctx.Features.Get<IExceptionHandlerFeature>()?.Error;
        ctx.Response.ContentType = "application/problem+json";
        ctx.Response.StatusCode = 500;
        var pd = new ProblemDetails
        {
            Title = "An unexpected error occurred.",
            Status = 500,
            Detail = ex?.Message
        };
        await ctx.Response.WriteAsJsonAsync(pd);
    }
});
```

勿在生產環境回傳內部例外堆疊；在日誌中紀錄詳細資訊並對外回傳通用訊息。

## 日誌（Logging）

- 使用 `ILogger<T>` 注入並寫入結構化日誌
- 在重要作業（認證、資料寫入、外部呼叫）紀錄足夠 context

```csharp
_logger.LogInformation("Creating user {Email}", request.Email);
```

## 安全性（Authentication & Authorization）

- 使用 `[Authorize]` 屬性保護需要驗證的端點
- 採用 JWT Bearer 或 ASP.NET Identity，並在 Startup/Program 設定權限政策
- 嚴格實作最小權限（principle of least privilege）

```csharp
[Authorize(Roles = "Admin")]
public async Task<IActionResult> DeleteUser(int id) { ... }
```

切勿在程式碼或 appsettings.json 中硬編碼密鑰；使用環境變數或 Key Vault 類服務。

## Model Binding 與來源標註

- 明確使用 `[FromBody]`, `[FromQuery]`, `[FromRoute]`, `[FromHeader]`，避免模型來源不明。

## API 版本管理

- 建議使用 URL 版本（`api/v1/...`）或 ASP.NET API Versioning 套件。

## OpenAPI / Swagger

- 在 `Program.cs` 中註冊 Swashbuckle，並為需要的 endpoints 加上 XML 註解與 `ProducesResponseType`。

## 測試（Integration with WebApplicationFactory）

使用 `WebApplicationFactory<TEntryPoint>` 進行整合測試，並使用測試用資料庫（InMemory / SQLite in-memory）與自動重置策略。

```csharp
public class UsersApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public UsersApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetUsers_ReturnsOk()
    {
        var res = await _client.GetAsync("/api/v1/users");
        res.EnsureSuccessStatusCode();
    }
}
```

## 效能與可擴充性建議
- 避免同步 I/O 與阻塞呼叫
- 使用投影（Select）而非載入整個實體（避免 ToList() 在 DB 層）
- 使用 `AsNoTracking()` 在唯讀查詢
- 使用快取（ResponseCaching、DistributedCache）在適用場合

## 檢查清單（Quick Checklist）
- [ ] 使用 DTO/record 回傳資料
- [ ] 所有 I/O 為 async
- [ ] 輸入驗證與防護（DataAnnotations/FluentValidation）
- [ ] 全域例外處理與 ProblemDetails
- [ ] 日誌與追蹤（ILogger + Application Insights）
- [ ] 不在程式碼中存放秘密
- [ ] Swagger/OpenAPI 可產生且有描述
- [ ] 有整合測試覆蓋關鍵路徑

## 參考連結
- Microsoft ASP.NET Core docs: https://learn.microsoft.com/aspnet/core/
- RFC 7807 Problem Details: https://datatracker.ietf.org/doc/html/rfc7807

---
更新紀錄：建立初版，包含 Controller 範例、DTO、驗證、錯誤處理、測試與最佳實務清單。
