Write-Host "=== НАГРУЗОЧНЫЙ ТЕСТ API ===" -ForegroundColor Magenta
Write-Host "Проверка производительности при множестве пользователей`n" -ForegroundColor Yellow

$BaseUrl = "http://localhost:5261"
$Results = @()
$StartTime = Get-Date

# Функция для измерения времени
function Measure-Request {
    param($Url, $Method = "GET", $Headers = @{}, $Body = $null)
    
    $start = Get-Date
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.ContentType = "application/json"
            $params.Body = $Body
        }
        
        $response = Invoke-RestMethod @params
        $success = $true
        $statusCode = 200
    } catch {
        $success = $false
        $statusCode = $_.Exception.Response.StatusCode.value__
    }
    $end = Get-Date
    
    return @{
        Duration = ($end - $start).TotalMilliseconds
        Success = $success
        StatusCode = $statusCode
    }
}

# === 1. Тест публичных эндпоинтов ===
Write-Host "1. Тест публичных эндпоинтов (100 запросов)..." -ForegroundColor Cyan

$publicTimes = @()
for ($i = 1; $i -le 100; $i++) {
    $result = Measure-Request "$BaseUrl/api/public/info"
    $publicTimes += $result.Duration
    
    if ($i % 10 -eq 0) {
        Write-Host "  Запросов: $i" -ForegroundColor Gray
    }
}

$avgPublic = ($publicTimes | Measure-Object -Average).Average
Write-Host "  Среднее время: $([math]::Round($avgPublic, 2)) мс" -ForegroundColor Green

# === 2. Тест множественных пользователей ===
Write-Host "`n2. Тест 20 параллельных пользователей..." -ForegroundColor Cyan

$userTokens = @()
$users = 20

# Создаем пользователей
for ($i = 1; $i -le $users; $i++) {
    $body = @{
        username = "user1"
        password = "password1"
    } | ConvertTo-Json
    
    $result = Measure-Request "$BaseUrl/api/auth/login" "POST" @{"User-Agent"="LoadTest/1.0"} $body
    
    if ($result.Success) {
        $resp = Invoke-RestMethod "$BaseUrl/api/auth/login" -Method Post -Body $body -ContentType "application/json"
        $userTokens += $resp.Token
    }
}

Write-Host "  Успешно залогинено: $($userTokens.Count) пользователей" -ForegroundColor Green

# === 3. Параллельные запросы ===
Write-Host "`n3. 50 параллельных запросов к защищенным данным..." -ForegroundColor Cyan

$parallelResults = @()
$jobs = @()

for ($i = 0; $i -lt 50; $i++) {
    $token = $userTokens[$i % $userTokens.Count]
    
    $job = Start-Job -ScriptBlock {
        param($Url, $Token)
        
        $headers = @{
            "Authorization" = "Bearer $Token"
            "User-Agent" = "LoadTest/1.0"
        }
        
        $start = Get-Date
        try {
            $response = Invoke-RestMethod $Url -Method Get -Headers $headers -ErrorAction Stop
            $success = $true
            $statusCode = 200
        } catch {
            $success = $false
            $statusCode = $_.Exception.Response.StatusCode.value__
        }
        $end = Get-Date
        
        return @{
            Duration = ($end - $start).TotalMilliseconds
            Success = $success
            StatusCode = $statusCode
        }
    } -ArgumentList "$BaseUrl/api/data/user-info", $token
    
    $jobs += $job
}

# Ждем завершения всех jobs
$jobResults = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job

$successful = ($jobResults | Where-Object { $_.Success }).Count
$avgParallel = ($jobResults.Duration | Measure-Object -Average).Average

Write-Host "  Успешных запросов: $successful из 50" -ForegroundColor Green
Write-Host "  Среднее время: $([math]::Round($avgParallel, 2)) мс" -ForegroundColor Green

# === 4. Длительный тест (5 минут) ===
Write-Host "`n4. Длительный тест (30 секунд, 1 запрос в секунду)..." -ForegroundColor Cyan

$longTestResults = @()
$duration = 30  # секунд

for ($second = 1; $second -le $duration; $second++) {
    $token = $userTokens[0]
    $headers = @{"Authorization"="Bearer $token";"User-Agent"="LoadTest/1.0"}
    
    $result = Measure-Request "$BaseUrl/api/data/user-info" -Headers $headers
    $longTestResults += $result
    
    Write-Host "  Секунда $second/$duration : $([math]::Round($result.Duration, 2)) мс" -ForegroundColor Gray
    Start-Sleep -Seconds 1
}

# === 5. Logout всех пользователей ===
Write-Host "`n5. Logout всех пользователей..." -ForegroundColor Cyan

$logoutTimes = @()
foreach ($token in $userTokens) {
    $headers = @{"Authorization"="Bearer $token";"User-Agent"="LoadTest/1.0"}
    $result = Measure-Request "$BaseUrl/api/auth/logout" "POST" $headers
    $logoutTimes += $result.Duration
}

# === ИТОГИ ===
Write-Host "`n=== РЕЗУЛЬТАТЫ НАГРУЗОЧНОГО ТЕСТА ===" -ForegroundColor Cyan

$totalTime = (Get-Date) - $StartTime
$totalRequests = 100 + $userTokens.Count + 50 + $duration

Write-Host "Общее время теста: $([math]::Round($totalTime.TotalSeconds, 2)) секунд" -ForegroundColor White
Write-Host "Всего запросов: $totalRequests" -ForegroundColor White
Write-Host "Запросов в секунду: $([math]::Round($totalRequests / $totalTime.TotalSeconds, 2))" -ForegroundColor White

Write-Host "`nСреднее время ответа:" -ForegroundColor Yellow
Write-Host "  Публичные запросы: $([math]::Round($avgPublic, 2)) мс" -ForegroundColor Gray
Write-Host "  Параллельные запросы: $([math]::Round($avgParallel, 2)) мс" -ForegroundColor Gray
Write-Host "  Длительный тест: $([math]::Round(($longTestResults.Duration | Measure-Object -Average).Average, 2)) мс" -ForegroundColor Gray
Write-Host "  Logout: $([math]::Round(($logoutTimes | Measure-Object -Average).Average, 2)) мс" -ForegroundColor Gray

# Сохранение результатов
$results = @{
    TestDate = Get-Date
    TotalTimeSeconds = $totalTime.TotalSeconds
    TotalRequests = $totalRequests
    RequestsPerSecond = $totalRequests / $totalTime.TotalSeconds
    AverageResponseTimes = @{
        Public = $avgPublic
        Parallel = $avgParallel
        LongTest = ($longTestResults.Duration | Measure-Object -Average).Average
        Logout = ($logoutTimes | Measure-Object -Average).Average
    }
    UserCount = $users
    SuccessfulLogins = $userTokens.Count
}

$resultsFile = "load-test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$results | ConvertTo-Json -Depth 3 | Out-File $resultsFile

Write-Host "`nРезультаты сохранены в: $resultsFile" -ForegroundColor Green