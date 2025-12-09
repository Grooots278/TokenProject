using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TokenASPProject.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class DataController : ControllerBase
    {
        [HttpGet("user-info")]
        public IActionResult GetUserInfo()
        {
            var username = User.Identity?.Name;
            var role = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;

            return Ok(new
            {
                Message = $"Привет, {username}!",
                Username = username,
                Role = role,
                Timestamp = DateTime.UtcNow,
                Data = new[] { "Запись 1", "Запись 2", "Запись 3" }
            });
        }

        [HttpGet("admin-data")]
        [Authorize(Roles = "Admin")]
        public IActionResult GetAdminData()
        {
            return Ok(new
            {
                Message = "Это административные данные",
                SecretInfo = "Доступно только администраторам",
                AccessLevel = "Administrator"
            });
        }

        [HttpGet("stats")]
        public IActionResult GetStats()
        {
            var username = User.Identity?.Name;

            return Ok(new
            {
                User = username,
                LastLogin = DateTime.UtcNow.AddHours(-1),
                TotalRequests = 42,
                ActiveSince = DateTime.UtcNow.AddDays(-7)
            });
        }
    }
}
