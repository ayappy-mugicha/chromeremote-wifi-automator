# WiFi-based Service Controller (checkwifi)

特定のWi-Fi（自宅やオフィスなど）に接続しているときだけ指定したWindowsサービスを自動的に開始し、公共Wi-Fiや他のWi-Fiに接続しているとき、またはオフラインのときは自動的に停止するWindows向けのPowerShellスクリプトです。

安全性の低いネットワークに接続している際に、意図しないリモートアクセスを防ぐためのセキュリティ向上や、特定の環境でのみ実行したいサービスの管理を目的としています。

## 特徴
- **自動切り替え**: Wi-Fiの接続イベント（接続・切断・切り替え）を検知し、サービスごとに指定されたSSIDの場合のみ稼働させます。
- **複数サービス対応**: 異なるサービスに対し、それぞれ異なるSSIDを指定して個別に制御することができます。
- **タスクスケジューラ登録**: Windowsの起動時、およびWi-Fiの接続状態が変化したタイミングでバックグラウンド実行されるようにタスクを登録します。
- **ログ記録**: `wifi_monitor.log` に実行ログを出力し、動作状況を後から確認できます。

## 必要要件
- Windows OS
- 管理者権限（タスクスケジューラへのタスク登録に必要）

## ファイル構成
- [toggle_services_by_wifi.ps1](./toggle_services_by_wifi.ps1): Wi-Fiの接続状況を判定し、設定された各サービスを制御するスクリプト本体。
- [register_task.ps1](./register_task.ps1): `toggle_services_by_wifi.ps1` をタスクスケジューラに自動実行タスクとして登録するスクリプト。
- [.env.example](./.env.example): 制御するサービス名と許可するSSIDを設定するためのテンプレートファイル。
- `wifi_monitor.log`: 動作ログが出力されるファイル。

## セットアップ手順

### 1. リポジトリのクローン/ダウンロード
本リポジトリをローカルの任意の場所にダウンロードします。

### 2. 設定ファイルの作成
`.env.example` をコピーして、同一ディレクトリに `.env` を作成します。
```powershell
Copy-Item .env.example .env
```
`.env` ファイルを開き、制御したいサービス名と起動を許可するSSIDを設定します。
```env
# 形式: SERVICE_サービス名=許可するSSID
# 例: Chrome Remote Desktop を自宅のWiFiでのみ起動する
SERVICE_chromoting=MyHomeWiFi

# 例: 他のサービスをオフィスのWiFiでのみ起動する
# SERVICE_wuauserv=OfficeWiFi
```
※サービス名は、Windowsの「サービス」管理ツール（`services.msc`）や PowerShell の `Get-Service` で確認できる「サービス名（Service name）」を指定してください（表示名ではありません）。

### 3. タスクスケジューラへの登録
PowerShellを**管理者として実行**し、以下のコマンドを実行してタスクを登録します。

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process
.\register_task.ps1
```

これで、以下のトリガーでスクリプトが自動実行されるようになります：
1. PCの起動時
2. Wi-Fiの接続成功時 (イベントID: 8001)
3. Wi-Fiの切断/切り替え時 (イベントID: 8003)

### 4. 動作確認
正しく動作しているかは、同一フォルダに出力される `wifi_monitor.log` を確認してください。
設定したSSIDに接続されているときはサービスが開始し、それ以外のWi-Fiや未接続状態のときはサービスが停止します。

## アンインストール
登録したタスクを削除したい場合は、PowerShell（管理者権限）で以下のコマンドを実行してください。
```powershell
Unregister-ScheduledTask -TaskName "WiFi_Services_Control" -Confirm:$false
```
（古いバージョンをお使いだった場合は、旧タスク名 `WiFi_ChromeRemoteDesktop_Control` も同様に削除してください。）
