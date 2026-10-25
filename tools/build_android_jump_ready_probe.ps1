param([string]$FlutterRoot='C:/Users/alexe/develop/flutter')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$probeRoot=Join-Path $projectRoot ('tmp/android-jump-ready-probe-'+(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff'))
if(Test-Path -LiteralPath $probeRoot){throw 'Probe directory exists'}
New-Item -ItemType Directory -Path $probeRoot | Out-Null
foreach($folder in @('lib','assets')){Copy-Item -LiteralPath (Join-Path $projectRoot $folder) -Destination $probeRoot -Recurse}
& robocopy (Join-Path $projectRoot 'android') (Join-Path $probeRoot 'android') /E /XD build .gradle /XF key.properties /NFL /NDL /NJH /NJS /NP | Out-Null
if($LASTEXITCODE -gt 7){throw 'Android source copy failed'}
foreach($file in @('pubspec.yaml','pubspec.lock','analysis_options.yaml','l10n.yaml','.metadata')){Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $probeRoot}
New-Item -ItemType Directory -Path (Join-Path $probeRoot 'tools') | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'tools/android_jump_ready_probe.dart') -Destination (Join-Path $probeRoot 'tools')
$gradle=Join-Path $probeRoot 'android/app/build.gradle.kts'
$gradleText=[IO.File]::ReadAllText($gradle)
$applicationPattern='(?s)applicationId = if \(System.getenv\("UNTOUCH_UI_PROBE"\).*?\} else "com.best4u.untouch"'
if(-not [regex]::IsMatch($gradleText,$applicationPattern)){throw 'Unexpected Android applicationId'}
[IO.File]::WriteAllText($gradle,[regex]::Replace($gradleText,$applicationPattern,'applicationId = "com.best4u.untouch.uiprobe.jumpready"'))
[IO.File]::WriteAllText($gradle,[IO.File]::ReadAllText($gradle).Replace('"Untouch ${flutter.versionCode}"','"QA${flutter.versionCode} Untouch · Прыжок"'))
# The original broad bundle-task guard also matches plugin bundle tasks in an
# unsigned APK build. Only this disposable, isolated copy uses debug signing.
[IO.File]::WriteAllText($gradle,[IO.File]::ReadAllText($gradle).Replace('require(privateSigningPath != null)','require(true)'))
$manifest=Join-Path $probeRoot 'android/app/src/main/AndroidManifest.xml'
[IO.File]::WriteAllText($manifest,[IO.File]::ReadAllText($manifest).Replace('<application','<application android:usesCleartextTraffic="true"'))
$gradleProperties=Join-Path $probeRoot 'android/gradle.properties'
[IO.File]::WriteAllText($gradleProperties,[IO.File]::ReadAllText($gradleProperties).Replace('-Xmx2G','-Xmx1536m').Replace('org.gradle.workers.max=2','org.gradle.workers.max=1'))
$dart=Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$flutter=Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'
Push-Location $probeRoot
try {
  & $dart $flutter pub get --offline
  if($LASTEXITCODE -ne 0){throw 'Probe dependencies failed'}
  & $dart $flutter build apk --release --no-pub --target-platform=android-arm64 --target=tools/android_jump_ready_probe.dart --build-name=1.0.199 --build-number=200 --dart-define=APP_TARGET=mobile --dart-define=ANDROID_HELMET_PROBE=true
  if($LASTEXITCODE -ne 0){throw 'Probe build failed'}
  Write-Output ('PROBE_APK='+ (Join-Path $probeRoot 'build/app/outputs/flutter-apk/app-release.apk'))
} finally {Pop-Location}
