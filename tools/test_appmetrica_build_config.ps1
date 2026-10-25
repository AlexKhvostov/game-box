$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'appmetrica_build_config.ps1')
$checks = 0
function Assert-Config($Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
  $script:checks++
}
function Assert-Rejected([scriptblock]$Action) {
  $rejected=$false
  try { & $Action | Out-Null } catch { $rejected=$true }
  Assert-Config $rejected 'Incorrect key/build destination was accepted.'
}
$qa = Get-AppMetricaBuildConfig
$prod = Get-AppMetricaBuildConfig -StoreBuild $true
Assert-Config ($qa.Environment -eq 'qa' -and $qa.AppId -eq 6377701) 'Default must be QA.'
Assert-Config ($prod.Environment -eq 'production' -and $prod.AppId -eq 6377692) 'Google Play must use production.'
Assert-Config ($qa.ApiKey -ne $prod.ApiKey) 'QA and production keys must differ.'
Assert-Rejected { Get-AppMetricaBuildConfig -KeyPath 'D:/Codex/secrets/untouch-appmetrica-sdk-key.dpapi' }
Assert-Rejected { Get-AppMetricaBuildConfig -StoreBuild $true -KeyPath 'D:/Codex/secrets/untouch-appmetrica-qa-key.bin' }
Assert-Rejected { Get-AppMetricaBuildConfig -KeyPath (Join-Path $PSScriptRoot 'missing-test-key.dpapi') }
$disabled = Get-AppMetricaBuildConfig -Disabled -QaKeyPath 'missing' -ProductionKeyPath 'missing'
Assert-Config (-not $disabled.Configured -and $null -eq $disabled.ApiKey) 'Explicit disable must not require keys.'
$phoneBuilder=Join-Path $PSScriptRoot 'build_phone_apk.ps1'
Assert-Rejected { & $phoneBuilder -PlayStore -TestTools }
Assert-Rejected { & $phoneBuilder -PlayStore -AppMetricaKeyPath 'D:/Codex/secrets/untouch-appmetrica-qa-key.bin' }
Assert-Rejected { & $phoneBuilder -AppMetricaKeyPath 'D:/Codex/secrets/untouch-appmetrica-sdk-key.dpapi' }
$analyticsBuilder=Join-Path $PSScriptRoot 'build_android_appmetrica.ps1'
Assert-Rejected { & $analyticsBuilder -Probe -PlayStore }
Assert-Rejected { & $analyticsBuilder -PlayStore -Mode profile }
foreach ($scriptFile in @('appmetrica_build_config.ps1','build_phone_apk.ps1','build_android_appmetrica.ps1')) {
  $parseErrors=$null; $tokens=$null
  [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $scriptFile),[ref]$tokens,[ref]$parseErrors) | Out-Null
  Assert-Config ($parseErrors.Count -eq 0) "PowerShell syntax error in $scriptFile"
}
$qa.ApiKey=$null; $prod.ApiKey=$null
Write-Output "AppMetrica build routing: $checks checks PASS; no key values logged."
