using Epfo.Grievance.Application;
using Epfo.Grievance.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using System.Text.Json;

namespace Epfo.Grievance.Api;

public static class DependencyInjection
{
    public static IServiceCollection AddEpfoServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<EpfoDbContext>(options => options.UseSqlServer(configuration.GetConnectionString("EpfoGrievance")));
        services.AddScoped<ICaseService, CaseService>(); services.AddScoped<IJointDeclarationService, JointDeclarationService>(); services.AddScoped<IAuthService, AuthService>(); services.AddScoped<IUserService, UserService>(); services.AddScoped<IPasswordHasher<Epfo.Grievance.Domain.User>, PasswordHasher<Epfo.Grievance.Domain.User>>();
        var key=configuration["Jwt:Key"] ?? throw new InvalidOperationException("Configure Jwt:Key using user secrets or an environment variable.");
        if (Encoding.UTF8.GetByteCount(key) < 32)
            throw new InvalidOperationException("Jwt:Key must contain at least 32 bytes for HS256. Configure it using user secrets or the Jwt__Key environment variable.");
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new() { ValidateIssuer=true, ValidateAudience=true, ValidateLifetime=true, ValidateIssuerSigningKey=true, ClockSkew=TimeSpan.Zero, ValidIssuer=configuration["Jwt:Issuer"], ValidAudience=configuration["Jwt:Audience"], IssuerSigningKey=new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)) };
            options.Events = new JwtBearerEvents
            {
                OnChallenge = async context => { context.HandleResponse(); context.Response.StatusCode=StatusCodes.Status401Unauthorized; context.Response.ContentType="application/json"; await context.Response.WriteAsync(JsonSerializer.Serialize(new { message="Your session has expired. Please sign in again." })); },
                OnForbidden = async context => { context.Response.StatusCode=StatusCodes.Status403Forbidden; context.Response.ContentType="application/json"; await context.Response.WriteAsync(JsonSerializer.Serialize(new { message="You are not authorized to access this resource." })); }
            };
        });
        return services;
    }
}




