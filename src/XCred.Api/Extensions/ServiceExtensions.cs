using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;
using XCred.Infrastructure.Services;

namespace XCred.Api.Extensions;

public static class ServiceExtensions
{
    public static IServiceCollection AddDatabase(this IServiceCollection services, IConfiguration config)
    {
        // Defaults to SqlServer when the key is absent — every existing appsettings.json /
        // appsettings.Production.json has no Database:Provider key, so this preserves
        // today's behavior exactly for the IIS/SQL-Server installer path. Sqlite is the
        // portable/self-contained distribution's provider (see appsettings.Portable.json).
        var provider = config["Database:Provider"] ?? "SqlServer";
        if (provider.Equals("Sqlite", StringComparison.OrdinalIgnoreCase))
        {
            services.AddDbContext<AppDbContext, SqliteAppDbContext>(options =>
                options.UseSqlite(config.GetConnectionString("DefaultConnection"),
                    sqlite => sqlite.MigrationsAssembly("XCred.Infrastructure")));
        }
        else
        {
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(config.GetConnectionString("DefaultConnection"),
                    sql => sql.MigrationsAssembly("XCred.Infrastructure")));
        }
        return services;
    }

    public static IServiceCollection AddJwtAuthentication(this IServiceCollection services, IConfiguration config)
    {
        var secret = config["Jwt:Secret"] ?? throw new InvalidOperationException("Jwt:Secret not configured");

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
                    ValidateIssuer = true,
                    ValidIssuer = config["Jwt:Issuer"] ?? "xcred",
                    ValidateAudience = true,
                    ValidAudience = config["Jwt:Audience"] ?? "xcred",
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromSeconds(30)
                };
            });

        services.AddAuthorization();
        return services;
    }

    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<ITokenService, TokenService>();
        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IAppSettingService, AppSettingService>();
        services.AddScoped<IEmailService, EmailService>();
        return services;
    }
}
