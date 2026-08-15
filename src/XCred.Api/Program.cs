using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;
using Serilog;
using XCred.Api.Extensions;
using XCred.Api.Middleware;
using XCred.Infrastructure.Data;
using XCred.Infrastructure.Services;

var builder = WebApplication.CreateBuilder(args);

// Anchored at AppContext.BaseDirectory, not a bare relative path — a Windows Service
// (Install-Service.ps1) launches with CWD=System32, not the app's own folder, so a
// relative path here would otherwise write logs somewhere unexpected (or fail outright on
// permissions). IIS in-process hosting's CWD is already the site's own bin path, so this
// resolves to the same place there as before.
builder.Host.UseSerilog((ctx, lc) => lc
    .ReadFrom.Configuration(ctx.Configuration)
    .WriteTo.Console()
    .WriteTo.File(Path.Combine(AppContext.BaseDirectory, "logs", "xcred-.log"), rollingInterval: RollingInterval.Day));

builder.Services.AddControllers();
builder.Services.AddOpenApi();

var isSqlite = string.Equals(builder.Configuration["Database:Provider"], "Sqlite", StringComparison.OrdinalIgnoreCase);

if (isSqlite)
{
    // A relative "Data Source" can't safely depend on the process's current working
    // directory — Start-XCred.bat sets CWD to the app's own folder, but a Windows Service
    // (Install-Service.ps1) launches with CWD=System32 instead. Anchor it at the exe's own
    // directory (stable for both launch methods, including single-file publish) instead of
    // trusting the CWD.
    const string connectionKey = "ConnectionStrings:DefaultConnection";
    const string dataSourcePrefix = "Data Source=";
    var rawConnection = builder.Configuration[connectionKey];
    if (rawConnection != null && rawConnection.StartsWith(dataSourcePrefix, StringComparison.OrdinalIgnoreCase))
    {
        var path = rawConnection[dataSourcePrefix.Length..];
        if (!Path.IsPathRooted(path))
        {
            var absolutePath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, path));
            Directory.CreateDirectory(Path.GetDirectoryName(absolutePath)!);
            builder.Configuration[connectionKey] = dataSourcePrefix + absolutePath;
        }
    }
}

if (string.IsNullOrEmpty(builder.Configuration["Jwt:Secret"]))
{
    // The IIS installer patches a real secret into appsettings.Production.json as an
    // explicit install step (Setup-XCred.ps1's PageSecurity) — the portable distribution has
    // no installer to do that, so generate one on first boot and persist it locally, reusing
    // it on every subsequent boot so restarts don't invalidate every session.
    var secretPath = Path.Combine(AppContext.BaseDirectory, "data", "jwt-secret.txt");
    Directory.CreateDirectory(Path.GetDirectoryName(secretPath)!);
    string secret;
    if (File.Exists(secretPath))
    {
        secret = await File.ReadAllTextAsync(secretPath);
    }
    else
    {
        secret = Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(64));
        await File.WriteAllTextAsync(secretPath, secret);
    }
    builder.Configuration["Jwt:Secret"] = secret;
}

builder.Services.AddDatabase(builder.Configuration);
builder.Services.AddJwtAuthentication(builder.Configuration);
builder.Services.AddApplicationServices();
builder.Services.AddHostedService<ExpiryNotificationService>();

builder.Services.AddCors(options =>
    options.AddPolicy("FrontendPolicy", policy =>
        policy.WithOrigins(builder.Configuration["AllowedOrigins"]?.Split(',') ?? ["http://localhost:5173"])
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials()));

builder.WebHost.ConfigureKestrel(k => k.Limits.MaxRequestBodySize = 15 * 1024 * 1024);

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
}

// Lets the installer apply/verify the schema as its own explicit step (with
// output captured in the install log) instead of only finding out about a
// migration failure when it silently crashes the site on the first request.
if (args.Contains("--migrate-only"))
    return;

app.UseMiddleware<ExceptionMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

// Disabled only for the plain-HTTP Docker test harness (docker-compose.yml), which has no
// HTTPS endpoint to redirect to. Production (IIS) deployments keep this enabled by default.
if (!builder.Configuration.GetValue<bool>("DisableHttpsRedirection"))
    app.UseHttpsRedirection();

app.UseCors("FrontendPolicy");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

if (!app.Environment.IsDevelopment())
{
    app.UseDefaultFiles();
    app.UseStaticFiles();
    app.MapFallbackToFile("index.html");
}

app.Run();
