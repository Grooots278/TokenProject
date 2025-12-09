using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using TokenASPProject.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()  // Разрешить все источники
              .AllowAnyMethod()   // Разрешить все HTTP методы
              .AllowAnyHeader()   // Разрешить все заголовки
              .WithExposedHeaders("Authorization"); // Разрешаем заголовок Authorization
    });
});

// Добавляем сервисы
builder.Services.AddControllers();
builder.Services.AddMemoryCache(); // Добавляем MemoryCache

// Настройка JWT
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidateAudience = true,
            ValidAudience = builder.Configuration["Jwt:Audience"],
            ValidateLifetime = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"])),
            ValidateIssuerSigningKey = true,
            ClockSkew = TimeSpan.Zero
        };

        // Добавляем проверку отозванных токенов
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var cache = context.HttpContext.RequestServices
                    .GetRequiredService<IMemoryCache>(); // ← Исправлено здесь

                // Получаем токен из заголовка
                var authHeader = context.Request.Headers["Authorization"]
                    .FirstOrDefault();

                if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer "))
                    return;

                var token = authHeader.Substring("Bearer ".Length).Trim(); // ← Исправлено здесь

                // Проверяем, не отозван ли токен
                var isRevoked = cache.Get<bool?>($"revoked:{token}");
                if (isRevoked == true)
                {
                    context.Fail("Token has been revoked");
                }
            }
        };
    });

builder.Services.AddAuthorization();

// Регистрируем сервисы
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IUserService, UserService>();

var app = builder.Build();

app.UseCors("AllowAll");
// Добавляем middleware проверки приложения
app.UseMiddleware<TokenASPProject.Middleware.AppCheckMiddleware>();

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.Run();