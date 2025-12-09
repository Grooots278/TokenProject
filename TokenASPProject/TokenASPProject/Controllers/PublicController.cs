using Microsoft.AspNetCore.Mvc;

namespace TokenASPProject.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PublicController : ControllerBase
    {
        [HttpGet("info")]
        public IActionResult GetInfo()
        {
            return Ok(new
            {
                Application = "Защищенное API",
                Version = "1.0",
                Description = "API с JWT аутентификацией",
                Endpoints = new[]
                {
                    "POST /api/auth/login - Получить токен",
                    "POST /api/auth/logout - Выйти",
                    "GET /api/auth/validate - Проверить токен",
                    "GET /api/data/user-info - Данные пользователя",
                    "GET /api/data/admin-data - Админ данные (только Admin)",
                    "GET /api/data/stats - Статистика"
                }
            });
        }

        [HttpGet("health")]
        public IActionResult HealthCheck()
        {
            return Ok(new
            {
                Status = "Healthy",
                Timestamp = DateTime.UtcNow,
                Uptime = Environment.TickCount / 1000
            });
        }
    }
}
