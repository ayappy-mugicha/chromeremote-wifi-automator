# register_task.ps1
# タスクスケジューラにWi-Fi監視タスクを登録するスクリプト

# 管理者権限チェック
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "このスクリプトは管理者権限で実行する必要があります。PowerShellを「管理者として実行」して再度お試しください。"
    exit
}

# 1. Wi-Fiイベントログの有効化 (念のため)
wevtutil sl Microsoft-Windows-WLAN-AutoConfig/Operational /e:true

# 2. 古いタスクのクリーンアップ (移行処理)
$OldTaskName = "WiFi_ChromeRemoteDesktop_Control"
if (Get-ScheduledTask -TaskName $OldTaskName -ErrorAction SilentlyContinue) {
    Write-Host "古いタスク '$OldTaskName' が存在するため削除します。"
    Unregister-ScheduledTask -TaskName $OldTaskName -Confirm:$false -ErrorAction SilentlyContinue
}

# 3. タスク情報の定義
$ScriptPath = Join-Path $PSScriptRoot "toggle_services_by_wifi.ps1"
$TaskName = "WiFi_Services_Control"

# タスク定義のXMLを生成 (「PC起動時」および「Wi-Fi接続/切断時」に起動するトリガーを定義)
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>SYSTEM</Author>
    <URI>\$TaskName</URI>
  </RegistrationInfo>
  <Triggers>
    <!-- 1. PC起動時 (スタートアップ) トリガー -->
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
    <!-- 2. Wi-Fi接続成功時 (イベントID 8001) トリガー -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;&lt;Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;*[System[EventID=8001]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <!-- 3. Wi-Fi切断/切り替え時 (イベントID 8003) トリガー -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;&lt;Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational"&gt;*[System[EventID=8003]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>PowerShell.exe</Command>
      <Arguments>-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$ScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# タスクを登録 (XMLからインポート)
Register-ScheduledTask -TaskName $TaskName -Xml $taskXml -Force

Write-Host "タスクスケジューラにタスク '$TaskName' を正常に更新登録しました。"
Write-Host "これにより、PC起動時およびWi-Fi接続変更時に自動的にスクリプトが実行されます。"
