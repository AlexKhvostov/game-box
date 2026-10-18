param(
  [ValidateSet('inspect', 'backup-landing', 'backup-game', 'finish-game-backup', 'prepare-game-deploy', 'deploy', 'commerce-test', 'energy-test', 'schema-test', 'mobile-test', 'mobile-migrate', 'migrate', 'webhook-setup', 'google-config-prepare', 'google-config-apply', 'ui-life-refund')][string]$Mode = 'inspect',
  [string]$RemoteRoot = '/',
  [string]$Release = '',
  [string]$CredentialPath = '',
  [string]$ResumeBackup = '',
  [string]$GoogleWebClientId = '',
  [string]$PreparedConfig = '',
  [string]$BackupLabel = '',
  [switch]$ChangedOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$credentialPath = $CredentialPath
if (-not $credentialPath) { $credentialPath = Join-Path $env:LOCALAPPDATA 'Untouch\ftp-credentials.xml' }
if (-not (Test-Path -LiteralPath $credentialPath)) { throw 'Missing locally encrypted FTP credentials' }
$credential = Import-Clixml -LiteralPath $credentialPath
$payload = @{ host = 'ftp80.hostland.ru'; port = 21; user = $credential.UserName; password = $credential.GetNetworkCredential().Password } | ConvertTo-Json -Compress
$arguments = @((Join-Path $PSScriptRoot 'telegram_ftp.py'), $Mode, '--root', $RemoteRoot)
if ($Mode -in @('google-config-prepare','google-config-apply')) {
  if (-not $GoogleWebClientId) { throw 'Google Web client ID is required' }
  $arguments += @('--google-web-client-id', $GoogleWebClientId)
  if ($PreparedConfig) { $arguments += @('--prepared-config', $PreparedConfig) }
}
if ($Mode -in @('deploy','backup-landing','backup-game','finish-game-backup','prepare-game-deploy')) {
  if ($Mode -in @('backup-landing','backup-game','finish-game-backup','prepare-game-deploy') -and -not $Release) { throw 'Specify a directory with -Release' }
  if (-not $Release) { $Release = (Get-Content -LiteralPath (Join-Path $root 'releases\latest.json') -Raw | ConvertFrom-Json).releasePath }
  $arguments += @('--release', $Release)
  if ($ResumeBackup) { $arguments += @('--resume-backup', $ResumeBackup) }
  if ($ChangedOnly) { $arguments += '--changed-only' }
}
if ($Mode -eq 'backup-game') {
  if ($BackupLabel -notmatch '^\d{4}-\d{2}-\d{2}$') { throw 'Specify the requested backup date YYYY-MM-DD' }
  $arguments += @('--backup-label', $BackupLabel)
}
if ($Mode -eq 'prepare-game-deploy' -and -not $ResumeBackup) { throw 'Specify a completed dated snapshot with -ResumeBackup' }
try {
  $payload | python @arguments
  if ($LASTEXITCODE -ne 0) { throw "FTP operation failed ($LASTEXITCODE)" }
} finally { $payload = $null; $credential = $null }
