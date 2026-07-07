# NLog and log4net Guide

## NLog Configuration Deep Dive

### XML Configuration (NLog.config)

```xml
<?xml version="1.0" encoding="utf-8" ?>
<nlog xmlns="http://www.nlog-project.org/schemas/NLog.xsd"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      autoReload="true"
      internalLogLevel="Warn"
      internalLogFile="logs/nlog-internal.log"
      throwConfigExceptions="true">

  <variable name="appName" value="MyApplication" />
  <variable name="logDir" value="${basedir}/logs" />

  <targets async="true">
    <!-- File target with daily rolling -->
    <target xsi:type="File"
            name="fileTarget"
            fileName="${logDir}/${appName}-${shortdate}.log"
            layout="${longdate} [${level:uppercase=true:padding=-5}] [${logger:shortName=true}] ${message}${onexception:inner=${newline}${exception:format=tostring}}"
            archiveAboveSize="52428800"
            maxArchiveFiles="30"
            concurrentWrites="true"
            keepFileOpen="true"
            encoding="utf-8" />

    <!-- Console target -->
    <target xsi:type="ColoredConsole"
            name="consoleTarget"
            layout="${longdate} [${level:uppercase=true}] ${message}${onexception:inner=${newline}${exception:format=tostring}}" />

    <!-- Database target -->
    <target xsi:type="Database"
            name="dbTarget"
            dbProvider="System.Data.SqlClient"
            connectionString="${var:connectionString}">
      <commandText>
        INSERT INTO Logs (Timestamp, Level, Logger, Message, Exception, MachineName)
        VALUES (@timestamp, @level, @logger, @message, @exception, @machineName)
      </commandText>
      <parameter name="@timestamp" layout="${longdate}" />
      <parameter name="@level" layout="${level}" />
      <parameter name="@logger" layout="${logger}" />
      <parameter name="@message" layout="${message}" />
      <parameter name="@exception" layout="${exception:format=tostring}" />
      <parameter name="@machineName" layout="${machinename}" />
    </target>

    <!-- Network target (TCP/UDP) -->
    <target xsi:type="Network"
            name="networkTarget"
            address="tcp://logserver:4560"
            layout="${longdate}|${level}|${logger}|${message}|${exception:format=tostring}"
            keepConnection="true" />

    <!-- Mail target -->
    <target xsi:type="Mail"
            name="mailTarget"
            smtpServer="smtp.company.com"
            from="alerts@company.com"
            to="dev-team@company.com"
            subject="${appName} - ${level} - ${message}"
            layout="${longdate} ${level} ${logger}${newline}${message}${newline}${exception:format=tostring}"
            smtpAuthentication="Basic"
            smtpUserName="${var:smtpUser}"
            smtpPassword="${var:smtpPass}" />
  </targets>

  <rules>
    <!-- All loggers, Information and above, go to file -->
    <logger name="*" minlevel="Info" writeTo="fileTarget" />

    <!-- Microsoft loggers only Warning and above -->
    <logger name="Microsoft.*" maxlevel="Info" final="true" />
    <logger name="Microsoft.*" minlevel="Warn" writeTo="fileTarget" />

    <!-- Specific namespace to database -->
    <logger name="MyApp.Audit.*" minlevel="Info" writeTo="dbTarget" />

    <!-- Fatal errors trigger email -->
    <logger name="*" level="Fatal" writeTo="mailTarget" />

    <!-- Console in development -->
    <logger name="*" minlevel="Debug" writeTo="consoleTarget" />
  </rules>
</nlog>
```

### Layout Renderers Reference

Common layout renderers:

| Renderer | Description |
|----------|------------|
| `${longdate}` | `2026-04-06 14:30:15.1234` |
| `${shortdate}` | `2026-04-06` |
| `${date:format=HH\:mm\:ss}` | Custom date format |
| `${level}` | Log level name |
| `${level:uppercase=true:padding=-5}` | `INFO ` (padded, uppercase) |
| `${logger}` | Full logger name (namespace.class) |
| `${logger:shortName=true}` | Class name only |
| `${message}` | Log message |
| `${exception:format=tostring}` | Full exception with stack trace |
| `${exception:format=message}` | Exception message only |
| `${machinename}` | Machine name |
| `${processid}` | Process ID |
| `${threadid}` | Thread ID |
| `${aspnet-request-url}` | ASP.NET request URL |
| `${aspnet-mvc-controller}` | MVC controller name |
| `${callsite}` | Calling method (expensive -- use sparingly) |
| `${newline}` | Platform newline |
| `${var:name}` | NLog variable value |

### Custom Layout Renderer

```csharp
[LayoutRenderer("correlation-id")]
public class CorrelationIdLayoutRenderer : LayoutRenderer
{
    protected override void Append(StringBuilder builder, LogEventInfo logEvent)
    {
        var httpContext = HttpContext.Current;  // .NET Framework
        // or use IHttpContextAccessor in .NET 6+
        var correlationId = httpContext?.Request.Headers["X-Correlation-ID"]
            ?? Guid.NewGuid().ToString();
        builder.Append(correlationId);
    }
}

// Registration (call before NLog configuration loads)
LayoutRenderer.Register<CorrelationIdLayoutRenderer>("correlation-id");
```

### JsonLayout for Structured Output

```xml
<target xsi:type="File" name="jsonFile" fileName="${logDir}/app.json">
  <layout xsi:type="JsonLayout" includeEventProperties="true" includeScopeProperties="true">
    <attribute name="timestamp" layout="${longdate}" />
    <attribute name="level" layout="${level}" />
    <attribute name="logger" layout="${logger}" />
    <attribute name="message" layout="${message}" />
    <attribute name="exception" layout="${exception:format=tostring}"
               encode="false" />
    <attribute name="machineName" layout="${machinename}" />
    <attribute name="threadId" layout="${threadid}" />
  </layout>
</target>
```

### Rules: Filtering and Routing

The `final` attribute stops rule processing for matching loggers:

```xml
<!-- Suppress all Microsoft logs below Warning: the final attribute prevents further rules -->
<logger name="Microsoft.*" maxlevel="Info" final="true" />

<!-- Level range filter -->
<logger name="*" minlevel="Debug" maxlevel="Info" writeTo="debugFile" />
<logger name="*" minlevel="Warn" writeTo="errorFile" />

<!-- Specific level only -->
<logger name="*" level="Error" writeTo="errorAlerts" />
```

### Async Wrappers and Buffering

```xml
<!-- Wrap all targets in async -->
<targets async="true">
  <!-- targets here -->
</targets>

<!-- Or wrap individual targets -->
<targets>
  <target xsi:type="AsyncWrapper" name="asyncFile"
          queueLimit="10000"
          overflowAction="Discard"
          batchSize="200">
    <target xsi:type="File" name="file" fileName="${logDir}/app.log" />
  </target>

  <target xsi:type="BufferingWrapper" name="bufferedDb"
          bufferSize="100"
          flushTimeout="5000">
    <target xsi:type="Database" name="db" ... />
  </target>

  <!-- Retry wrapper for transient failures -->
  <target xsi:type="RetryingWrapper" name="retryNetwork"
          retryCount="3"
          retryDelayMilliseconds="1000">
    <target xsi:type="Network" name="net" address="tcp://logserver:4560" />
  </target>
</targets>
```

### Variable Substitution

```xml
<nlog>
  <variable name="appName" value="OrderService" />
  <variable name="logDir" value="${basedir}/logs" />
  <variable name="detailedLayout"
            value="${longdate} [${level:uppercase=true:padding=-5}] [${appName}] ${message}" />

  <targets>
    <target xsi:type="File" name="file" fileName="${logDir}/${appName}.log"
            layout="${detailedLayout}" />
  </targets>
</nlog>
```

Variables can also be set at runtime:

```csharp
LogManager.Configuration.Variables["connectionString"] = actualConnString;
```

### Auto-Reload

```xml
<nlog autoReload="true">
```

When `autoReload="true"`, NLog watches NLog.config for changes and reloads automatically. Works in both .NET Framework and .NET 6+. In .NET 6+ with `appsettings.json` configuration, use `reloadOnChange: true` in the configuration builder.

### Internal Logging for Troubleshooting

```xml
<nlog internalLogLevel="Debug"
      internalLogFile="logs/nlog-internal.log"
      internalLogToConsole="true"
      throwConfigExceptions="true">
```

Or set programmatically:

```csharp
NLog.Common.InternalLogger.LogLevel = NLog.LogLevel.Debug;
NLog.Common.InternalLogger.LogFile = "nlog-internal.log";
NLog.Common.InternalLogger.LogToConsole = true;
```

### NLog with .NET 6+ (appsettings.json)

```json
{
  "NLog": {
    "autoReload": true,
    "throwConfigExceptions": true,
    "internalLogLevel": "Warn",
    "targets": {
      "async": true,
      "console": {
        "type": "Console",
        "layout": "${longdate} [${level:uppercase=true}] ${message}${exception:format=tostring}"
      },
      "file": {
        "type": "File",
        "fileName": "${basedir}/logs/app-${shortdate}.log",
        "layout": "${longdate} [${level}] ${logger} ${message}${exception:format=tostring}"
      }
    },
    "rules": [
      { "logger": "Microsoft.*", "maxLevel": "Info", "final": true },
      { "logger": "*", "minLevel": "Info", "writeTo": "console,file" }
    ]
  }
}
```

```csharp
// Program.cs
using NLog.Web;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Host.UseNLog();
```

---

## log4net Configuration

### XML Configuration (log4net.config)

```xml
<?xml version="1.0" encoding="utf-8" ?>
<log4net>
  <!-- Console Appender -->
  <appender name="ConsoleAppender" type="log4net.Appender.ConsoleAppender">
    <layout type="log4net.Layout.PatternLayout">
      <conversionPattern value="%date [%thread] %-5level %logger - %message%newline" />
    </layout>
  </appender>

  <!-- Rolling File Appender -->
  <appender name="RollingFileAppender" type="log4net.Appender.RollingFileAppender">
    <file value="logs/app.log" />
    <appendToFile value="true" />
    <rollingStyle value="Composite" />
    <datePattern value="yyyyMMdd" />
    <maxSizeRollBackups value="30" />
    <maximumFileSize value="50MB" />
    <staticLogFileName value="true" />
    <layout type="log4net.Layout.PatternLayout">
      <conversionPattern value="%date{yyyy-MM-dd HH:mm:ss.fff} [%thread] %-5level %logger{1} - %message%newline%exception" />
    </layout>
  </appender>

  <!-- ADO.NET Appender (Database) -->
  <appender name="AdoNetAppender" type="log4net.Appender.AdoNetAppender">
    <bufferSize value="100" />
    <connectionType value="System.Data.SqlClient.SqlConnection, System.Data" />
    <connectionString value="Data Source=.;Initial Catalog=Logging;Integrated Security=True" />
    <commandText value="INSERT INTO Logs (Date, Thread, Level, Logger, Message, Exception)
                         VALUES (@date, @thread, @level, @logger, @message, @exception)" />
    <parameter>
      <parameterName value="@date" />
      <dbType value="DateTime" />
      <layout type="log4net.Layout.RawTimeStampLayout" />
    </parameter>
    <parameter>
      <parameterName value="@thread" />
      <dbType value="String" />
      <size value="255" />
      <layout type="log4net.Layout.PatternLayout" value="%thread" />
    </parameter>
    <parameter>
      <parameterName value="@level" />
      <dbType value="String" />
      <size value="50" />
      <layout type="log4net.Layout.PatternLayout" value="%level" />
    </parameter>
    <parameter>
      <parameterName value="@logger" />
      <dbType value="String" />
      <size value="255" />
      <layout type="log4net.Layout.PatternLayout" value="%logger" />
    </parameter>
    <parameter>
      <parameterName value="@message" />
      <dbType value="String" />
      <size value="4000" />
      <layout type="log4net.Layout.PatternLayout" value="%message" />
    </parameter>
    <parameter>
      <parameterName value="@exception" />
      <dbType value="String" />
      <size value="4000" />
      <layout type="log4net.Layout.PatternLayout" value="%exception" />
    </parameter>
  </appender>

  <!-- Filters -->
  <appender name="FilteredAppender" type="log4net.Appender.RollingFileAppender">
    <file value="logs/errors-only.log" />
    <appendToFile value="true" />
    <filter type="log4net.Filter.LevelRangeFilter">
      <levelMin value="ERROR" />
      <levelMax value="FATAL" />
    </filter>
    <filter type="log4net.Filter.DenyAll" />
    <layout type="log4net.Layout.PatternLayout">
      <conversionPattern value="%date %-5level %logger - %message%newline%exception" />
    </layout>
  </appender>

  <appender name="StringFilteredAppender" type="log4net.Appender.FileAppender">
    <file value="logs/payment.log" />
    <filter type="log4net.Filter.StringMatchFilter">
      <stringToMatch value="Payment" />
    </filter>
    <filter type="log4net.Filter.DenyAll" />
    <layout type="log4net.Layout.PatternLayout">
      <conversionPattern value="%date %-5level %message%newline" />
    </layout>
  </appender>

  <!-- Root logger -->
  <root>
    <level value="INFO" />
    <appender-ref ref="ConsoleAppender" />
    <appender-ref ref="RollingFileAppender" />
  </root>

  <!-- Logger hierarchy -->
  <logger name="MyApp.DataAccess" additivity="false">
    <level value="WARN" />
    <appender-ref ref="RollingFileAppender" />
  </logger>

  <logger name="MyApp.Audit">
    <level value="INFO" />
    <appender-ref ref="AdoNetAppender" />
  </logger>
</log4net>
```

### PatternLayout Format Strings

| Pattern | Description |
|---------|------------|
| `%date` or `%d` | Timestamp (default format) |
| `%date{yyyy-MM-dd HH:mm:ss.fff}` | Custom date format |
| `%level` or `%p` | Log level |
| `%-5level` | Left-aligned, 5-char padded level |
| `%logger` or `%c` | Full logger name |
| `%logger{1}` | Short logger name (class only) |
| `%message` or `%m` | Log message |
| `%exception` | Exception details |
| `%newline` or `%n` | Platform newline |
| `%thread` or `%t` | Thread name |
| `%property{key}` | Context property value |
| `%stacktrace` | Stack trace |

### XmlConfigurator Setup

```csharp
// .NET Framework -- in AssemblyInfo.cs
[assembly: log4net.Config.XmlConfigurator(ConfigFile = "log4net.config", Watch = true)]

// Or programmatically
var logConfig = new FileInfo("log4net.config");
log4net.Config.XmlConfigurator.ConfigureAndWatch(logConfig);

// Usage
private static readonly ILog _log = LogManager.GetLogger(typeof(MyClass));
_log.Info("Application started");
_log.Error("Operation failed", exception);
```

### log4net in .NET 6+ (Limited Support)

log4net has limited .NET 6+ support. The `Microsoft.Extensions.Logging.Log4Net.AspNetCore` adapter bridges it:

```csharp
builder.Logging.AddLog4Net("log4net.config");
```

Note: log4net is in maintenance mode. For new .NET 6+ projects, Serilog or NLog are preferred.

---

## Migration Guide

### NLog to Serilog Mapping

| NLog Concept | Serilog Equivalent |
|---|---|
| Target | Sink |
| Layout | OutputTemplate |
| Layout Renderer | Enricher + template token |
| Rule | MinimumLevel.Override / Filter |
| `${message}` | `{Message:lj}` |
| `${exception:format=tostring}` | `{Exception}` |
| `${longdate}` | `{Timestamp:yyyy-MM-dd HH:mm:ss.fff}` |
| `${level}` | `{Level}` |
| `${logger}` | `{SourceContext}` |
| AsyncWrapper | `WriteTo.Async()` |
| BufferingWrapper | Built into batching sinks |
| `LogManager.GetCurrentClassLogger()` | `Log.ForContext<T>()` or DI `ILogger<T>` |

NLog config:
```xml
<target xsi:type="File" name="file" fileName="logs/app-${shortdate}.log"
        layout="${longdate} [${level}] ${logger} - ${message}${exception:format=tostring}" />
<rules>
  <logger name="Microsoft.*" maxlevel="Info" final="true" />
  <logger name="*" minlevel="Info" writeTo="file" />
</rules>
```

Serilog equivalent:
```csharp
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .WriteTo.File("logs/app-.log",
        rollingInterval: RollingInterval.Day,
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] {SourceContext} - {Message:lj}{NewLine}{Exception}")
    .CreateLogger();
```

### log4net to Serilog Mapping

| log4net Concept | Serilog Equivalent |
|---|---|
| Appender | Sink |
| PatternLayout | OutputTemplate |
| LevelRangeFilter | `.Filter.ByIncludingOnly()` / MinimumLevel |
| StringMatchFilter | Serilog.Expressions filter |
| `%date` | `{Timestamp}` |
| `%level` | `{Level}` |
| `%logger` | `{SourceContext}` |
| `%message` | `{Message:lj}` |
| `%exception` | `{Exception}` |
| `LogManager.GetLogger(typeof(T))` | `Log.ForContext<T>()` or DI `ILogger<T>` |
| Root logger + logger hierarchy | MinimumLevel + Override |

### NLog to Microsoft.Extensions.Logging

NLog integrates directly via `NLog.Extensions.Logging`:

```csharp
// .NET 6+
builder.Logging.ClearProviders();
builder.Host.UseNLog();

// Code uses standard ILogger<T> -- no NLog API references in business code
public class OrderService
{
    private readonly ILogger<OrderService> _logger;

    public OrderService(ILogger<OrderService> logger)
    {
        _logger = logger;
    }

    public void Process()
    {
        _logger.LogInformation("Processing order {OrderId}", orderId);
        // NLog receives this via the MEL provider bridge
    }
}
```

NLog rules in NLog.config continue to control routing and filtering. The MEL `LogLevel` maps to NLog levels:

| MEL LogLevel | NLog LogLevel |
|---|---|
| Trace | Trace |
| Debug | Debug |
| Information | Info |
| Warning | Warn |
| Error | Error |
| Critical | Fatal |

### Gradual Migration Strategy

When migrating from NLog/log4net to Serilog, avoid a big-bang rewrite. Follow this staged approach:

**Phase 1: Add Serilog alongside existing framework**

```csharp
// Install Serilog and configure it to write to the same destinations
// Keep NLog/log4net running for existing code
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/serilog-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();
```

**Phase 2: Bridge via Microsoft.Extensions.Logging**

```csharp
// Use MEL as the abstraction layer -- both frameworks can feed it
builder.Logging.ClearProviders();
builder.Host.UseSerilog();  // New code uses Serilog via MEL

// Legacy code using ILog/NLog.ILogger still works through its own provider
```

**Phase 3: Migrate business code to ILogger<T>**

```csharp
// Replace direct NLog/log4net calls with MEL ILogger<T>
// Before (NLog):
private static readonly NLog.Logger _logger = NLog.LogManager.GetCurrentClassLogger();
_logger.Info("Order {0} processed", orderId);

// After (MEL with Serilog backend):
private readonly ILogger<OrderService> _logger;
_logger.LogInformation("Order {OrderId} processed", orderId);
```

**Phase 4: Remove legacy framework**

Once all code uses `ILogger<T>`, remove the NLog/log4net packages and configuration files.

Key considerations during migration:
- Keep both log outputs active during transition to verify parity.
- Structured property names may differ (`{0}` positional in NLog vs `{OrderId}` named in Serilog).
- NLog `final="true"` rules map to Serilog `MinimumLevel.Override` -- verify suppression behavior matches.
- log4net `additivity="false"` maps to isolated sub-loggers in Serilog.
- Test that log levels map correctly (NLog `Warn` = MEL `Warning`, NLog `Fatal` = MEL `Critical`).

### .NET Framework vs .NET 6+ Differences

**NLog:**
- .NET Framework: NLog.config auto-discovered from bin directory. Use `NLog.Web` for ASP.NET integration.
- .NET 6+: Use `NLog.Web.AspNetCore`. Supports appsettings.json configuration via `NLog.Extensions.Logging`.

**log4net:**
- .NET Framework: Full support. `XmlConfigurator` with `Watch=true` for auto-reload.
- .NET 6+: Limited. Use `Microsoft.Extensions.Logging.Log4Net.AspNetCore` adapter. No new features expected.

**General recommendation:**
- .NET Framework legacy apps: Keep existing NLog/log4net if stable; migrate only if there is a compelling reason.
- New .NET 6+ projects: Use Serilog or NLog. Both have excellent MEL integration.
- Greenfield: Serilog is the most popular choice for structured logging in modern .NET.
