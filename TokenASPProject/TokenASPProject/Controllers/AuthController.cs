using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using TokenASPProject.Models;
using TokenASPProject.Services;

namespace TokenASPProject.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController :ControllerBase
    {
        private readonly ITokenService _tokenService;
        private readonly IUserService _userService;
        private readonly IMemoryCache _cache;
        private readonly ILogger<AuthController> _logger;

        public AuthController(
            ITokenService tokenService,
            IUserService userService,
            IMemoryCache cache,
            ILogger<AuthController> logger)
        {
            _tokenService = tokenService;
            _userService = userService;
            _cache = cache;
            _logger = logger;
        }

        [HttpPost("login")]
        [AllowAnonymous]
        public IActionResult Login([FromBody] AuthRequest request)
        {
            var user = _userService.Authenticate(request.Username, request.Password);
            if (user == null)
            {
                _logger.LogWarning("Failed login attempt for user {Username}", request.Username);
                return Unauthorized(new { message = "Неверный логин или пароль" });
            }

            // Генерируем токен
            var token = _tokenService.GenerateToken(user.Username, user.Role);

            // Сохраняем в кэше что токен активен
            _cache.Set($"active:{token}", true, TimeSpan.FromHours(8));

            // Также сохраняем связь пользователь-токен
            _cache.Set($"user_token:{user.Username}", token, TimeSpan.FromHours(8));

            _logger.LogInformation("User {Username} logged in successfully", user.Username);

            return Ok(new
            {
                Token = token,
                ExpiresAt = DateTime.UtcNow.AddHours(8),
                Username = user.Username,
                Role = user.Role
            });
        }

        [HttpPost("logout")]
        [Authorize]
        public IActionResult Logout()
        {
            var username = User.Identity?.Name;
            var token = HttpContext.Request.Headers["Authorization"]
                .FirstOrDefault()?.Replace("Bearer ", "");

            if (!string.IsNullOrEmpty(token))
            {
                // Помечаем токен как отозванный
                _cache.Set($"revoked:{token}", true, TimeSpan.FromHours(8));

                // Удаляем из активных
                _cache.Remove($"active:{token}");

                _logger.LogInformation("User {Username} logged out", username);
            }

            return Ok(new { message = "Выход выполнен успешно" });
        }

        [HttpGet("validate")]
        [Authorize]
        public IActionResult ValidateToken()
        {
            var username = User.Identity?.Name;
            var token = HttpContext.Request.Headers["Authorization"]
                .FirstOrDefault()?.Replace("Bearer ", "");

            if (string.IsNullOrEmpty(token))
                return Ok(new { IsValid = false, Message = "Токен отсутствует" });

            // Проверяем три условия:
            // 1. Не отозван ли
            // 2. Активен ли
            // 3. Есть ли связь с пользователем
            var isRevoked = _cache.Get<bool>($"revoked:{token}");
            var isActive = _cache.Get<bool>($"active:{token}");
            var userToken = _cache.Get<string>($"user_token:{username}");

            var isValid = !isRevoked && isActive && userToken == token;

            return Ok(new
            {
                IsValid = isValid,
                Username = username,
                Message = isValid ? "Токен действителен" : "Токен недействителен"
            });
        }
    }
}
