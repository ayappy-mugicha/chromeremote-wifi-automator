# toggle_services_by_wifi.ps1
# ----------------------------------------------------
# 設定値は同フォルダ内の .env ファイルから読み込みます
# ----------------------------------------------------

# 1. 変数の初期化
$Services = @()
$LogPath = Join-Path $PSScriptRoot "wifi_monitor.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "[$timestamp] $Message"
}

# 2. .env ファイルから設定をロードする
$EnvFilePath = Join-Path $PSScriptRoot ".env"
$LegacyTargetSSID = ""

if (Test-Path $EnvFilePath) {
    Get-Content $EnvFilePath | ForEach-Object {
        $line = $_.Trim()
        # 空行やコメント行 (#) を除外して処理
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line -split '=', 2
            if ($parts.Length -eq 2) {
                $key = $parts[0].Trim()
                $val = $parts[1].Trim()
                # 引用符 (シングル/ダブルクォート) を除去
                $val = $val -replace '^["'']|["'']$'
                
                if ($key -eq "TARGET_SSID") {
                    $LegacyTargetSSID = $val
                } elseif ($key.StartsWith("SERVICE_")) {
                    $sName = $key.Substring(8).Trim()
                    $Services += [PSCustomObject]@{
                        Name = $sName
                        TargetSSID = $val
                    }
                }
            }
        }
    }
}

# レガシー互換性の処理 (TARGET_SSID が指定されていて、SERVICE_chromoting が無い場合)
$hasChromoting = $Services | Where-Object { $_.Name -eq "chromoting" }
if ($LegacyTargetSSID -and -not $hasChromoting) {
    $Services += [PSCustomObject]@{
        Name = "chromoting"
        TargetSSID = $LegacyTargetSSID
    }
}

if ($Services.Count -eq 0) {
    Write-Log "ERROR: .env ファイルにサービス設定（SERVICE_サービス名=SSID）が見つかりません。"
    exit
}

# 3. 現在の接続SSIDを取得
$wifiInfo = netsh wlan show interfaces
$ssidLine = $wifiInfo | Select-String -Pattern "^\s+SSID\s+:\s+(.*)"
$currentSSID = $null
if ($ssidLine) {
    $currentSSID = $ssidLine.Matches.Groups[1].Value.Trim()
}

# 4. 各サービスの制御処理
foreach ($svcConfig in $Services) {
    $serviceName = $svcConfig.Name
    $TargetSSID = $svcConfig.TargetSSID

    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Log "WARNING: サービス [$serviceName] がシステム内に見つかりません。スキップします。"
        continue
    }

    if ($null -ne $currentSSID) {
        # Wi-Fi接続中
        Write-Log "接続検知 - 現在のSSID: $currentSSID (サービス: $serviceName, 対象SSID: $TargetSSID)"

        if ($currentSSID -eq $TargetSSID) {
            # 対象SSIDに接続されたので、サービスを開始する
            if ($service.Status -ne "Running") {
                Write-Log "対象のWi-Fiに接続されたため、サービス [$serviceName] を開始します。"
                Start-Service -Name $serviceName -ErrorAction SilentlyContinue
            } else {
                Write-Log "サービス [$serviceName] はすでに実行中です。"
            }
        } else {
            # 対象外のSSIDなので、サービスを停止する
            if ($service.Status -ne "Stopped") {
                Write-Log "対象外のWi-Fi ($currentSSID) に接続されたため、サービス [$serviceName] を停止します。"
                Stop-Service -Name $serviceName -ErrorAction SilentlyContinue
            } else {
                Write-Log "サービス [$serviceName] はすでに停止しています。"
            }
        }
    } else {
        # Wi-Fi未接続なので、サービスを停止する
        Write-Log "接続検知 - Wi-Fiに接続されていません。"
        if ($service.Status -ne "Stopped") {
            Write-Log "サービス [$serviceName] を停止します。"
            Stop-Service -Name $serviceName -ErrorAction SilentlyContinue
        } else {
            Write-Log "サービス [$serviceName] はすでに停止しています。"
        }
    }
}
