param(
  [string]$FlutterRoot = 'C:/Users/alexe/develop/flutter',
  [ValidateSet('apk','appbundle')][string]$Artifact = 'apk',
  [ValidateSet('release','profile')][string]$Mode = 'release',
  [int]$BuildNumber = 0,
  [string]$BuildName = '',
  [switch]$Probe,
  [switch]$PlayStore,
  [string]$ExistingProbeRoot,
  [string]$KeyPath = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if ([IO.File]::ReadAllText((Join-Path $root 'pubspec.yaml')) -notmatch '(?m)^version:\s*([^+\s]+)\+(\d+)') { throw 'Project version is missing.' }
if (-not $BuildName) { $BuildName = $Matches[1] }
if (-not $BuildNumber) { $BuildNumber = [int]$Matches[2] }
. (Join-Path $root 'tools/appmetrica_build_config.ps1')
$storeAnalytics = [bool]($PlayStore -or $Artifact -eq 'appbundle')
if ($Probe -and $storeAnalytics) { throw 'An isolated probe cannot be a Google Play build.' }
if ($storeAnalytics -and ($Mode -ne 'release' -or $env:UNTOUCH_UI_PROBE -eq 'true')) { throw 'Google Play analytics requires a regular release build.' }
$analyticsConfig = Get-AppMetricaBuildConfig -StoreBuild $storeAnalytics -KeyPath $KeyPath
$sdkKey = $analyticsConfig.ApiKey
# A private define file prevents command lines/logs from containing SDK keys.
$privateDir = Join-Path $env:TEMP ('untouch-analytics-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($privateDir) | Out-Null
$definesPath = Join-Path $privateDir 'defines.json'
$defines = @{
  APP_TARGET='mobile'; APPMETRICA_API_KEY=$sdkKey
  APPMETRICA_ENV=$analyticsConfig.Environment
}
if ($Probe) {
  $defines['ANDROID_BRAKE_PROBE']='true'
  $defines['ANDROID_BRAKE_AUTOMATION']='true'
  $probeRoot = if ($ExistingProbeRoot) { [IO.Path]::GetFullPath($ExistingProbeRoot) } else { Join-Path $root ('tmp/appmetrica-probe-' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fff')) }
  $allowed = [IO.Path]::GetFullPath((Join-Path $root 'tmp')) + [IO.Path]::DirectorySeparatorChar
  if (-not $probeRoot.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'QA copy must stay inside this workspace tmp folder.' }
  [IO.Directory]::CreateDirectory($probeRoot) | Out-Null
  foreach ($folder in @('lib','assets')) { & robocopy (Join-Path $root $folder) (Join-Path $probeRoot $folder) /E /NFL /NDL /NJH /NJS /NP | Out-Null; if ($LASTEXITCODE -gt 7) { throw 'QA source copy failed.' } }
  & robocopy (Join-Path $root 'android') (Join-Path $probeRoot 'android') /E /XD build .gradle /XF key.properties /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -gt 7) { throw 'QA source copy failed.' }
  foreach ($file in @('pubspec.yaml','pubspec.lock','analysis_options.yaml','l10n.yaml','.metadata')) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $probeRoot
  }
  [IO.Directory]::CreateDirectory((Join-Path $probeRoot 'tools')) | Out-Null
  foreach ($file in @('appmetrica_probe.dart','android_brake_probe.dart')) {
    Copy-Item -LiteralPath (Join-Path $root "tools/$file") -Destination (Join-Path $probeRoot 'tools')
  }
  $gradlePath=Join-Path $probeRoot 'android/app/build.gradle.kts'
  $gradle=[IO.File]::ReadAllText($gradlePath)
  $pattern='(?s)applicationId = if \(System.getenv\("UNTOUCH_UI_PROBE"\).*?\} else "com.best4u.untouch"'
  if (-not [regex]::IsMatch($gradle,$pattern)) { throw 'Unexpected applicationId configuration.' }
  $gradle=[regex]::Replace($gradle,$pattern,'applicationId = "com.best4u.untouch.uiprobe.analytics"')
  $gradle=$gradle.Replace('require(privateSigningPath != null)','require(true)')
  [IO.File]::WriteAllText($gradlePath,$gradle)
  $manifestPath=Join-Path $probeRoot 'android/app/src/main/AndroidManifest.xml'
  [IO.File]::WriteAllText($manifestPath,[IO.File]::ReadAllText($manifestPath).Replace('<application','<application android:usesCleartextTraffic="true"'))
  $root=$probeRoot
}
[IO.File]::WriteAllText($definesPath,($defines | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$sdkKey=$null; $defines=$null; $analyticsConfig.ApiKey=$null
$dart=Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$flutter=Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'
$previousProbeSetting=$env:UNTOUCH_UI_PROBE
if ($Probe) { $env:UNTOUCH_UI_PROBE='true' }
Push-Location $root
try {
  & $dart $flutter pub get --offline
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
  $buildArgs=@('build',$Artifact,"--$Mode",'--no-pub',"--build-name=$BuildName","--build-number=$BuildNumber","--dart-define-from-file=$definesPath")
  if ($Probe) { $buildArgs += '--target=tools/appmetrica_probe.dart' }
  & $dart $flutter @buildArgs
  if ($LASTEXITCODE -ne 0) { throw 'Android analytics build failed.' }
  Write-Output "ANDROID_ANALYTICS_BUILD_ROOT=$root"
} finally {
  Pop-Location
  $env:UNTOUCH_UI_PROBE=$previousProbeSetting
  # Only this invocation's exact temporary file is removed, never a user file.
  if (Test-Path -LiteralPath $definesPath) { Remove-Item -LiteralPath $definesPath }
}
