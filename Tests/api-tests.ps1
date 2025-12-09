
## **3. PowerShell тесты:**

**Создайте папку `Tests/` и добавьте файлы:**

### **`Tests/api-tests.ps1`** - Полный тест API
```powershell
Write-Host "=== ПОЛНЫЙ ТЕСТ ASP.NET API ===" -ForegroundColor Cyan
Write-Host "Автор: $(whoami)" -ForegroundColor Gray
Write-Host "Дата: $(Get-Date)" -ForegroundColor Gray
Write-Host "`n"

$BaseUrl = "http://localhost:5261"
$TestResults = @()

function Test-Endpoint {
    param($Name, $Url, $Method = "GET", $Body = $null, $Headers = @{}, $ExpectedCode = 200)
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
            ContentType = "application/json"
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = $Body
        }
        
        $response = Invoke-RestMethod @params
        $success = $true
        $message = "Успешно"
        
        Write-Host "  ✓ $Name" -ForegroundColor Green
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $success = $statusCode -eq $ExpectedCode
        $message = "Код: $statusCode"
        
        if ($success) {
            Write-Host "  ✓ $Name (ожидаемый $ExpectedCode)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $Name (получен $statusCode, ожидался $ExpectedCode)" -ForegroundColor Red
        }
    }
    
    $TestResults += [PSCustomObject]@{
        Test = $Name
        Success = $success
        Message = $message
        Timestamp = Get-Date
    }
    
    return $success
}

# === ТЕСТ 1: Проверка сервера ===
Write-Host "1. Проверка сервера..." -ForegroundColor Yellow
Test-Endpoint "Публичный эндпоинт /info" "$BaseUrl/api/public/info"
Test-Endpoint "Проверка здоровья /health" "$BaseUrl/api/public/health"

# === ТЕСТ 2: Авторизация ===
Write-Host "`n2. Тест авторизации..." -ForegroundColor Yellow

# Тестовые пользователи
$users = @(
    @{Username = "user1"; Password = "password1"; Role = "User"},
    @{Username = "user2"; Password = "password2"; Role = "User"},
    @{Username = "admin"; Password = "admin123"; Role = "Admin"}
)

$tokens = @{}

foreach ($user in $users) {
    $body = @{
        username = $user.Username
        password = $user.Password
    } | ConvertTo-Json
    
    $testName = "Логин пользователя $($user.Username)"
    
    if (Test-Endpoint $testName "$BaseUrl/api/auth/login" "POST" $body -ExpectedCode 200) {
        $resp = Invoke-RestMethod "$BaseUrl/api/auth/login" -Method Post -Body $body -ContentType "application/json"
        $tokens[$user.Username] = $resp.Token
        Write-Host "    Токен получен: $($resp.Token.Substring(0,20))..." -ForegroundColor Gray
    }
}

# === ТЕСТ 3: Защищенные эндпоинты ===
Write-Host "`n3. Тест защищенных эндпоинтов..." -ForegroundColor Yellow

foreach ($user in $users) {
    $token = $tokens[$user.Username]
    if ($token) {
        $headers = @{
            "Authorization" = "Bearer $token"
            "User-Agent" = "PowerShell-Test/1.0"
        }
        
        Write-Host "  Пользователь: $($user.Username) ($($user.Role))" -ForegroundColor Cyan
        
        # User info
        Test-Endpoint "  Данные пользователя" "$BaseUrl/api/data/user-info" "GET" -Headers $headers
        
        # Stats
        Test-Endpoint "  Статистика" "$BaseUrl/api/data/stats" "GET" -Headers $headers
        
        # Admin data
        if ($user.Role -eq "Admin") {
            Test-Endpoint "  Админ данные" "$BaseUrl/api/data/admin-data" "GET" -Headers $headers
        } else {
            Test-Endpoint "  Админ данные (должна быть 403)" "$BaseUrl/api/data/admin-data" "GET" -Headers $headers -ExpectedCode 403
        }
    }
}

# === ТЕСТ 4: Logout ===
Write-Host "`n4. Тест logout..." -ForegroundColor Yellow

foreach ($user in @("user1", "admin")) {
    $token = $tokens[$user]
    if ($token) {
        $headers = @{
            "Authorization" = "Bearer $token"
            "User-Agent" = "PowerShell-Test/1.0"
        }
        
        Test-Endpoint "Logout $user" "$BaseUrl/api/auth/logout" "POST" -Headers $headers
        
        # Проверка что токен не работает после logout
        Start-Sleep -Milliseconds 500
        Test-Endpoint "  Проверка после logout" "$BaseUrl/api/data/user-info" "GET" -Headers $headers -ExpectedCode 401
    }
}

# === ТЕСТ 5: Validate endpoint ===
Write-Host "`n5. Тест validate..." -ForegroundColor Yellow

# Новый логин для теста validate
$body = @{username="user1";password="password1"} | ConvertTo-Json
$resp = Invoke-RestMethod "$BaseUrl/api/auth/login" -Method Post -Body $body -ContentType "application/json"
$token = $resp.Token
$headers = @{"Authorization"="Bearer $token";"User-Agent"="PowerShell-Test/1.0"}

Test-Endpoint "Validate токена" "$BaseUrl/api/auth/validate" "GET" -Headers $headers

# === ИТОГИ ===
Write-Host "`n=== РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ ===" -ForegroundColor Cyan

$total = $TestResults.Count
$passed = ($TestResults | Where-Object { $_.Success }).Count
$failed = $total - $passed

Write-Host "Всего тестов: $total" -ForegroundColor White
Write-Host "Пройдено: $passed" -ForegroundColor Green
Write-Host "Провалено: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })

if ($failed -gt 0) {
    Write-Host "`nПроваленные тесты:" -ForegroundColor Red
    $TestResults | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  ✗ $($_.Test): $($_.Message)" -ForegroundColor Red
    }
}

# Сохранение результатов в файл
$resultsFile = "test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$TestResults | ConvertTo-Json | Out-File $resultsFile
Write-Host "`nРезультаты сохранены в: $resultsFile" -ForegroundColor Gray