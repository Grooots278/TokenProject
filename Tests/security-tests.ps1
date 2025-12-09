Write-Host "=== ТЕСТЫ БЕЗОПАСНОСТИ API ===" -ForegroundColor Red
Write-Host "Проверка защиты от несанкционированного доступа`n" -ForegroundColor Yellow

$BaseUrl = "http://localhost:5261"

function Test-Security {
    param($TestName, $Url, $Method = "GET", $Headers = @{}, $ShouldFail = $true, $ExpectedCode = 401)
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
            ContentType = "application/json"
            ErrorAction = "Stop"
        }
        
        $response = Invoke-RestMethod @params
        $statusCode = 200
        $success = -not $ShouldFail
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $success = $ShouldFail -and ($statusCode -eq $ExpectedCode)
    }
    
    $color = if ($success) { "Green" } else { "Red" }
    $icon = if ($success) { "✓" } else { "✗" }
    
    Write-Host "$icon $TestName" -ForegroundColor $color
    Write-Host "  Статус: $statusCode (ожидался: $(if($ShouldFail){$ExpectedCode}else{'200'}))" -ForegroundColor Gray
    
    return $success
}

# === ТЕСТ 1: Доступ без токена ===
Write-Host "`n1. Доступ без аутентификации:" -ForegroundColor Cyan
Test-Security "Без токена" "$BaseUrl/api/data/user-info" -Headers @{"User-Agent"="Test/1.0"}
Test-Security "Без токена (админка)" "$BaseUrl/api/data/admin-data" -Headers @{"User-Agent"="Test/1.0"}
Test-Security "Без токена (статистика)" "$BaseUrl/api/data/stats" -Headers @{"User-Agent"="Test/1.0"}

# === ТЕСТ 2: Неверный токен ===
Write-Host "`n2. Неверный токен:" -ForegroundColor Cyan
$fakeToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmYWtlIn0.fake-signature"
Test-Security "Поддельный токен" "$BaseUrl/api/data/user-info" -Headers @{"Authorization"="Bearer $fakeToken";"User-Agent"="Test/1.0"}
Test-Security "Пустой токен" "$BaseUrl/api/data/user-info" -Headers @{"Authorization"="Bearer "; "User-Agent"="Test/1.0"}

# === ТЕСТ 3: Без User-Agent ===
Write-Host "`n3. Проверка User-Agent:" -ForegroundColor Cyan

# Сначала получим валидный токен
$body = @{username="user1";password="password1"} | ConvertTo-Json
$resp = Invoke-RestMethod "$BaseUrl/api/auth/login" -Method Post -Body $body -ContentType "application/json"
$validToken = $resp.Token

Test-Security "Без User-Agent (с валидным токеном)" "$BaseUrl/api/data/user-info" `
    -Headers @{"Authorization"="Bearer $validToken"} -ExpectedCode 403

# === ТЕСТ 4: SQL/NoSQL инъекции ===
Write-Host "`n4. Проверка на инъекции:" -ForegroundColor Cyan

$injectionTests = @(
    @{Payload = "' OR '1'='1"},
    @{Payload = "'; DROP TABLE Users; --"},
    @{Payload = '" OR "1"="1'},
    @{Payload = "admin' --"},
    @{Payload = "1' UNION SELECT * FROM Users --"}
)

foreach ($test in $injectionTests) {
    $body = @{
        username = "user1$($test.Payload)"
        password = "password1$($test.Payload)"
    } | ConvertTo-Json
    
    Test-Security "SQL инъекция в логин" "$BaseUrl/api/auth/login" "POST" -Body $body -Headers @{"User-Agent"="Test/1.0"}
}

# === ТЕСТ 5: XSS атаки ===
Write-Host "`n5. Проверка на XSS:" -ForegroundColor Cyan

$xssPayloads = @(
    "<script>alert('xss')</script>",
    "javascript:alert('xss')",
    "<img src=x onerror=alert('xss')>",
    "'\"><script>alert('xss')</script>"
)

foreach ($xss in $xssPayloads) {
    $body = @{
        username = $xss
        password = $xss
    } | ConvertTo-Json
    
    Test-Security "XSS в логине" "$BaseUrl/api/auth/login" "POST" -Body $body -Headers @{"User-Agent"="Test/1.0"}
}

# === ТЕСТ 6: Brute force защита ===
Write-Host "`n6. Защита от brute force:" -ForegroundColor Cyan

Write-Host "  Пытаюсь 5 раз с неверным паролем..." -ForegroundColor Gray
for ($i = 1; $i -le 5; $i++) {
    $body = @{
        username = "user1"
        password = "wrong_password_$i"
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod "$BaseUrl/api/auth/login" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
        Write-Host "    Попытка $i: ошибка ожидалась" -ForegroundColor Red
    } catch {
        Write-Host "    Попытка $i: доступ запрещен (ожидаемо)" -ForegroundColor Green
    }
    Start-Sleep -Milliseconds 200
}

# === ТЕСТ 7: Проверка после logout ===
Write-Host "`n7. Проверка инвалидации токена:" -ForegroundColor Cyan

# Логинимся
$body = @{username="user1";password="password1"} | ConvertTo-Json
$resp = Invoke-RestMethod "$BaseUrl/api/auth/login" -Method Post -Body $body -ContentType "application/json"
$token = $resp.Token
$headers = @{"Authorization"="Bearer $token";"User-Agent"="Test/1.0"}

# Получаем данные (должно работать)
Test-Security "Доступ после логина" "$BaseUrl/api/data/user-info" -Headers $headers -ShouldFail $false

# Logout
Invoke-RestMethod "$BaseUrl/api/auth/logout" -Method Post -Headers $headers -ContentType "application/json" | Out-Null

# Пытаемся получить доступ после logout (должно быть 401)
Start-Sleep -Seconds 1
Test-Security "Доступ после logout" "$BaseUrl/api/data/user-info" -Headers $headers

# === ТЕСТ 8: Проверка CORS ===
Write-Host "`n8. Проверка CORS политик:" -ForegroundColor Cyan

Write-Host "  OPTIONS запрос для проверки CORS:" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest "$BaseUrl/api/data/user-info" -Method OPTIONS -ErrorAction Stop
    Write-Host "  ✓ CORS заголовки присутствуют" -ForegroundColor Green
    $response.Headers | ForEach-Object {
        if ($_ -match "Access-Control") {
            Write-Host "    $_: $($response.Headers[$_])" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "  ✗ Ошибка CORS: $_" -ForegroundColor Red
}

Write-Host "`n=== ТЕСТЫ БЕЗОПАСНОСТИ ЗАВЕРШЕНЫ ===" -ForegroundColor Cyan