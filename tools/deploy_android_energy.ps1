param(
  [ValidateSet('audit','prepare','maintenance','public-verify')][string]$Mode = 'audit',
  [string]$Directory = '.private/android-live-activation-20261015',
  [ValidateSet('inspect','backup','schema','activate','verify','rehearsal')][string]$Action = 'inspect',
  [string]$ExpectedRevision = '',
  [string]$ExpectedNonAndroidHash = ''
)
$ErrorActionPreference = 'Stop'
$credential = Import-Clixml -LiteralPath (Join-Path $env:LOCALAPPDATA 'Untouch/ftp-credentials.xml')
$payload = @{host='ftp80.hostland.ru';port=21;user=$credential.UserName;password=$credential.GetNetworkCredential().Password} | ConvertTo-Json -Compress
try {
  $arguments = @((Join-Path $PSScriptRoot 'deploy_android_energy.py'),$Mode,'--directory',$Directory)
  if ($Mode -eq 'maintenance') {
    $arguments += @('--action',$Action)
    if ($ExpectedRevision) { $arguments += @('--expected-revision',$ExpectedRevision) }
    if ($ExpectedNonAndroidHash) { $arguments += @('--expected-non-android-hash',$ExpectedNonAndroidHash) }
  }
  $payload | & 'C:/Python312/python.exe' @arguments
  if ($LASTEXITCODE -ne 0) { throw "Android server operation failed ($LASTEXITCODE)" }
} finally { $payload=$null; $credential=$null }
