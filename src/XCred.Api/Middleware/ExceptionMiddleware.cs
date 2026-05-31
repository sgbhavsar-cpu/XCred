using System.Text.Json;
using XCred.Core.DTOs.Common;
using XCred.Core.Exceptions;

namespace XCred.Api.Middleware;

public class ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception");
            await WriteErrorResponse(context, ex);
        }
    }

    private static async Task WriteErrorResponse(HttpContext context, Exception ex)
    {
        context.Response.ContentType = "application/json";

        var (statusCode, code, message) = ex switch
        {
            NotFoundException => (404, "NOT_FOUND", ex.Message),
            ForbiddenException => (403, "FORBIDDEN", ex.Message),
            ConflictException => (409, "CONFLICT", ex.Message),
            UnauthorizedException => (401, "UNAUTHORIZED", ex.Message),
            _ => (500, "INTERNAL_ERROR", "An unexpected error occurred.")
        };

        context.Response.StatusCode = statusCode;
        var response = ApiResponse<object>.Fail(code, message);
        await context.Response.WriteAsync(JsonSerializer.Serialize(response, JsonOptions));
    }
}
