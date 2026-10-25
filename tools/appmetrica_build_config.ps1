# SDK keys stay in local DPAPI files. Callers must never print the returned config.
function Read-AppMetricaSdkKey([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw 'Local AppMetrica configuration is missing.' }
  if ([IO.Path]::GetExtension($Path) -eq '.bin') {
    Add-Type -AssemblyName System.Security
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($Path), $null, 'CurrentUser')
    $value = [Text.Encoding]::UTF8.GetString($bytes)
  } else {
    $secure = ConvertTo-SecureString ([IO.File]::ReadAllText($Path).Trim())
    $value = [Net.NetworkCredential]::new('', $secure).Password
  }
  $parsed = [Guid]::Empty
  if (-not [Guid]::TryParse($value, [ref]$parsed) -or $parsed -eq [Guid]::Empty) { throw 'Invalid local AppMetrica SDK configuration.' }
  return $value
}

function Get-AppMetricaBuildConfig {
  param(
    [bool]$StoreBuild = $false,
    [string]$KeyPath = '',
    [switch]$Disabled,
    [string]$ProductionKeyPath = 'D:/Codex/secrets/untouch-appmetrica-sdk-key.dpapi',
    [string]$QaKeyPath = 'D:/Codex/secrets/untouch-appmetrica-qa-key.bin'
  )
  if ($Disabled) { return @{Configured=$false; Environment='disabled'; ApiKey=$null; AppId=$null} }
  $expectedPath = if ($StoreBuild) { $ProductionKeyPath } else { $QaKeyPath }
  $expectedKey = Read-AppMetricaSdkKey $expectedPath
  $key = if ($KeyPath) { Read-AppMetricaSdkKey $KeyPath } else { $expectedKey }
  if ($key -ne $expectedKey) { throw 'AppMetrica key does not match the build destination. Google Play uses production; other builds use QA.' }
  return @{
    Configured=$true
    Environment=$(if ($StoreBuild) {'production'} else {'qa'})
    AppId=$(if ($StoreBuild) {6377692} else {6377701})
    ApiKey=$key
  }
}
