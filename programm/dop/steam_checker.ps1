# Изменение политики выполнения скриптов
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force


# Встроенный API-ключ Steam
$steamApiKey = "F53590A7A0F255B385553811B97BF36D"

$steamid_list = @()
$personaname_list = @()
$vacbanned_list = @()
$errorList = @()

$content = Get-Content -Path "C:\Program Files (x86)\Steam\config\loginusers.vdf" -Encoding Default
$inUser = $false
$currentSteamID = $null
$currentPersonaName = $null

foreach ($line in $content) {
    if ($line -match '"users"') {
        $inUser = $true
    } elseif ($line -match '^\s*"(\d+)"') {
        $currentSteamID = $Matches[1]
        # Проверка на исключение определенного SteamID
        if ($currentSteamID -ne "76561199760202576") {
            $steamid_list += $currentSteamID
        }
    } elseif ($line -match '^\s*"PersonaName"\s*"([^"]*)"') {
        $currentPersonaName = $Matches[1]
        $personaname_list += $currentPersonaName
    } elseif ($line -match '^\s*}') {
        $currentSteamID = $null
        $currentPersonaName = $null
    }
}

Write-Host "Количество найденных SteamID: $($steamid_list.Count)"
Write-Host "Количество найденных PersonaName: $($personaname_list.Count)"

$groupSize = 10 # Размер группы SteamID
$totalGroups = [Math]::Ceiling($steamid_list.Count / $groupSize)

$errorOutputFile = "steam_api_errors.txt"
if (Test-Path -Path $errorOutputFile) {
    Remove-Item -Path $errorOutputFile
}

$totalRequestCount = 0
$maxRequestsPerMinute = 100 # Ограничение скорости запросов

for ($i = 0; $i -lt $totalGroups; $i++) {
    $startIndex = $i * $groupSize
    $endIndex = [Math]::Min(($i + 1) * $groupSize, $steamid_list.Count)
    $currentGroup = $steamid_list[$startIndex..($endIndex - 1)]

    Write-Host "Обработка группы SteamID: $($startIndex + 1) - $endIndex"

    $maxRetries = 3 # Максимальное количество повторных попыток
    $retryDelay = 3 # Начальная задержка между повторными попытками в секундах

    for ($j = 0; $j -lt $currentGroup.Count; $j++) {
        $steamid = $currentGroup[$j]
        $personaname = $personaname_list[$startIndex + $j]

        $retryCount = 0
        $success = $false

        do {
            try {
                $response = Invoke-WebRequest -Uri "https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key=$steamApiKey&steamids=$steamid" -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    $responseData = $response.Content | ConvertFrom-Json
                    if ($responseData.players[0].VACBanned) {
                        $vacbanned_list += $steamid
                        Write-Host "$steamid ($personaname) - VAC-BANNED" -ForegroundColor Red
                    }
                    else {
                        Write-Host "$steamid ($personaname) - Не забанен" -ForegroundColor Green
                    }
                    $success = $true
                    $totalRequestCount++
                }
                elseif ($response.StatusCode -eq 429) {
                    # Обработка ошибки "429 Слишком много запросов"
                    Write-Host "Превышен лимит запросов Steam API. Повторная попытка через $retryDelay секунд..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $retryDelay
                    $retryCount++

                    $retryDelay *= 2 # Экспоненциальный интервал между повторными попытками
                }
                else {
                    Write-Host "Ошибка при запросе данных для SteamID: $steamid. Код ответа: $($response.StatusCode)" -ForegroundColor Red
                    $errorList += $steamid

                    $success = $true
                }
            }
            catch [System.Net.WebException] {
                $errorMessage = $_.Exception.Message
                Write-Host "Ошибка при запросе данных для SteamID: $steamid" -ForegroundColor Red
                Write-Host "Ошибка: $errorMessage" -ForegroundColor Red
                $errorList += $steamid

                $success = $true
            }

            if (-not $success -and $retryCount -lt $maxRetries) {
                Write-Host "Ошибка при запросе данных для SteamID: $steamid. Повторная попытка через $retryDelay секунд..." -ForegroundColor Yellow
                Start-Sleep -Seconds $retryDelay
                $retryDelay *= 2 # Экспоненциальный интервал между повторными попытками
                $retryCount++
            }
            else {
                $success = $true
            }

            if ($totalRequestCount -ge $maxRequestsPerMinute) {
                Write-Host "Превышен лимит запросов Steam API за минуту. Ждем 60 секунд перед продолжением..." -ForegroundColor Yellow
                Start-Sleep -Seconds 60
                $totalRequestCount = 0
            }
        } while (-not $success)
    }
}

# Не закрывать PowerShell после выполнения скрипта
Write-Host "Нажмите Enter, чтобы закрыть окно..."
[Console]::ReadLine() | Out-Null
