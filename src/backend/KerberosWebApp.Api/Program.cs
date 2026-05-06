using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.Negotiate;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
                               ForwardedHeaders.XForwardedHost |
                               ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
if (allowedOrigins.Length > 0)
{
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("Frontend", policy =>
        {
            policy.WithOrigins(allowedOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod()
                .AllowCredentials();
        });
    });
}

builder.Services.AddAuthentication(NegotiateDefaults.AuthenticationScheme)
    .AddNegotiate();

builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = options.DefaultPolicy;
});

var app = builder.Build();

app.UseForwardedHeaders();

if (allowedOrigins.Length > 0)
{
    app.UseCors("Frontend");
}

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health/live", () => Results.Ok(new { status = "live" }))
    .AllowAnonymous();

app.MapGet("/health/ready", () => Results.Ok(new
    {
        status = "ready",
        keytab = Environment.GetEnvironmentVariable("KRB5_KTNAME") ?? "default",
        krb5Config = Environment.GetEnvironmentVariable("KRB5_CONFIG") ?? "/etc/krb5.conf"
    }))
    .AllowAnonymous();

var api = app.MapGroup("/api").RequireAuthorization();

api.MapGet("/me", (ClaimsPrincipal user) =>
{
    var identity = user.Identity;
    return Results.Ok(new
    {
        name = identity?.Name,
        authenticationType = identity?.AuthenticationType,
        isAuthenticated = identity?.IsAuthenticated ?? false,
        claims = user.Claims
            .Select(claim => new { claim.Type, claim.Value })
            .OrderBy(claim => claim.Type)
    });
});

api.MapGet("/groups", (ClaimsPrincipal user) =>
{
    var groupClaims = user.Claims
        .Where(claim =>
            claim.Type == ClaimTypes.GroupSid ||
            claim.Type.EndsWith("/groupsid", StringComparison.OrdinalIgnoreCase) ||
            claim.Type.EndsWith("/group", StringComparison.OrdinalIgnoreCase) ||
            claim.Type.EndsWith("/role", StringComparison.OrdinalIgnoreCase))
        .Select(claim => claim.Value)
        .Distinct()
        .OrderBy(value => value);

    return Results.Ok(new { groups = groupClaims });
});

app.Run();
