using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;
using Serilog;
using XCred.Api.Extensions;
using XCred.Api.Middleware;
using XCred.Infrastructure.Data;
using XCred.Infrastructure.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .ReadFrom.Configuration(ctx.Configuration)
    .WriteTo.Console()
    .WriteTo.File("logs/xcred-.log", rollingInterval: RollingInterval.Day));

builder.Services.AddControllers();
builder.Services.AddOpenApi();

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
