namespace TokenASPProject.Middleware
{
    public class AppCheckMiddleware
    {
        private readonly RequestDelegate _next;

        public AppCheckMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            // Пропускаем публичные эндпоинты
            if (context.Request.Path.StartsWithSegments("/api/public") ||
                context.Request.Path.StartsWithSegments("/api/auth/login") ||
                context.Request.Path.StartsWithSegments("/api/auth/validate"))
            {
                await _next(context);
                return;
            }

            // Для защищенных эндпоинтов проверяем User-Agent
            if (context.Request.Path.StartsWithSegments("/api/data"))
            {
                var userAgent = context.Request.Headers.UserAgent.ToString();

                // Простая проверка - приложение должно отправлять User-Agent
                if (string.IsNullOrEmpty(userAgent))
                {
                    context.Response.StatusCode = StatusCodes.Status403Forbidden;
                    await context.Response.WriteAsync("Доступ только через приложение");
                    return;
                }
            }

            await _next(context);
        }
    }
}
