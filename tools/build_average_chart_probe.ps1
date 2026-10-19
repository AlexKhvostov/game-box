param([string]$FlutterRoot='C:/Users/alexe/develop/flutter',[int]$QaVersion=198,[string]$BuildName='1.0.187')
$ErrorActionPreference='Stop'
$chartProject=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$chartProbe=Join-Path $chartProject ('tmp/average-chart-probe-'+(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff'))
if(Test-Path -LiteralPath $chartProbe){throw 'Probe directory exists'}
New-Item -ItemType Directory -Path $chartProbe | Out-Null
foreach($folder in @('lib','assets')){Copy-Item -LiteralPath (Join-Path $chartProject $folder) -Destination $chartProbe -Recurse}
& robocopy (Join-Path $chartProject 'android') (Join-Path $chartProbe 'android') /E /XD build .gradle /XF key.properties /NFL /NDL /NJH /NJS /NP | Out-Null
if($LASTEXITCODE -gt 7){throw 'Android source copy failed'}
foreach($file in @('pubspec.yaml','pubspec.lock','analysis_options.yaml','l10n.yaml','.metadata')){Copy-Item -LiteralPath (Join-Path $chartProject $file) -Destination $chartProbe}
New-Item -ItemType Directory -Path (Join-Path $chartProbe 'tools') | Out-Null
Copy-Item -LiteralPath (Join-Path $chartProject 'tools/average_chart_probe.dart') -Destination (Join-Path $chartProbe 'tools')
$chartGradle=Join-Path $chartProbe 'android/app/build.gradle.kts'
$chartText=[IO.File]::ReadAllText($chartGradle)
$chartPattern='(?s)applicationId = if \(System.getenv\("UNTOUCH_UI_PROBE"\).*?\} else "com.best4u.untouch"'
if(-not [regex]::IsMatch($chartText,$chartPattern)){throw 'Unexpected Android applicationId'}
# Disposable UI-only copy: no accounts, billing, ad or production API calls.
$chartText=[regex]::Replace($chartText,$chartPattern,'applicationId = "com.best4u.untouch.uiprobe.averagechart"')
[IO.File]::WriteAllText($chartGradle,$chartText.Replace('require(privateSigningPath != null)','require(true)'))
$chartDart=Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$chartFlutter=Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'
$chartPriorProbe=$env:UNTOUCH_UI_PROBE
$chartPriorSigning=$env:UNTOUCH_SIGNING_PROPERTIES
Push-Location $chartProbe
try {
  $env:UNTOUCH_UI_PROBE='true';$env:UNTOUCH_SIGNING_PROPERTIES=$null
  & $chartDart $chartFlutter pub get --offline
  if($LASTEXITCODE -ne 0){throw 'Probe dependencies failed'}
  & $chartDart $chartFlutter build apk --release --no-pub --target=tools/average_chart_probe.dart --build-number=$QaVersion --build-name=$BuildName --dart-define=APP_TARGET=mobile
  if($LASTEXITCODE -ne 0){throw 'Probe build failed'}
  Write-Output ('PROBE_APK='+ (Join-Path $chartProbe 'build/app/outputs/flutter-apk/app-release.apk'))
} finally {
  Pop-Location;$env:UNTOUCH_UI_PROBE=$chartPriorProbe;$env:UNTOUCH_SIGNING_PROPERTIES=$chartPriorSigning
}
