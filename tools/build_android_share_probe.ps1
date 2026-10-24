param([string]$FlutterRoot='C:/Users/alexe/develop/flutter')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$probeRoot=Join-Path $projectRoot ('tmp/android-share-probe-'+(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff'))
if(Test-Path -LiteralPath $probeRoot){throw 'Probe directory exists'}
New-Item -ItemType Directory -Path $probeRoot | Out-Null
foreach($folder in @('lib','assets')){Copy-Item -LiteralPath (Join-Path $projectRoot $folder) -Destination $probeRoot -Recurse}
& robocopy (Join-Path $projectRoot 'android') (Join-Path $probeRoot 'android') /E /XD build .gradle /XF key.properties /NFL /NDL /NJH /NJS /NP | Out-Null
if($LASTEXITCODE -gt 7){throw 'Android source copy failed'}
foreach($file in @('pubspec.yaml','pubspec.lock','analysis_options.yaml','l10n.yaml','.metadata')){Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $probeRoot}
New-Item -ItemType Directory -Path (Join-Path $probeRoot 'tools') | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'tools/android_share_probe.dart') -Destination (Join-Path $probeRoot 'tools')
$gradle=Join-Path $probeRoot 'android/app/build.gradle.kts'
$gradleText=[IO.File]::ReadAllText($gradle)
$applicationPattern='(?s)applicationId = if \(System.getenv\("UNTOUCH_UI_PROBE"\).*?\} else "com.best4u.untouch"'
if(-not [regex]::IsMatch($gradleText,$applicationPattern)){throw 'Unexpected Android applicationId'}
$gradleText=[regex]::Replace($gradleText,$applicationPattern,'applicationId = "com.best4u.untouch.uiprobe.share"')
$gradleText=$gradleText.Replace('require(privateSigningPath != null)','require(true)')
$gradleText=$gradleText.Replace('resValue("string", "app_name", phoneLabel)','resValue("string", "app_name", "Untouch Share QA")')
# Only the isolated UI probe skips R8. Dart still runs in release mode.
$gradleText=$gradleText.Replace('release {',"release {`n            isMinifyEnabled = false`n            isShrinkResources = false")
[IO.File]::WriteAllText($gradle,$gradleText)
$properties=Join-Path $probeRoot 'android/gradle.properties'
[IO.File]::WriteAllText($properties,[IO.File]::ReadAllText($properties).Replace('-Xmx2G','-Xmx1200m -XX:ActiveProcessorCount=2').Replace('org.gradle.workers.max=2','org.gradle.workers.max=1'))
$manifest=Join-Path $probeRoot 'android/app/src/main/AndroidManifest.xml'
[IO.File]::WriteAllText($manifest,[IO.File]::ReadAllText($manifest).Replace('<application','<application android:usesCleartextTraffic="true"').Replace('android:label="Untouch"','android:label="Untouch Share QA"'))
$dart=Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$flutter=Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'
$probePreviousSigning=$env:UNTOUCH_SIGNING_PROPERTIES
$env:UNTOUCH_SIGNING_PROPERTIES=$null
Push-Location $probeRoot
try {
  & $dart $flutter pub get --offline
  if($LASTEXITCODE -ne 0){throw 'Probe dependencies failed'}
  & $dart $flutter build apk --release --target-platform=android-arm64 --no-pub --target=tools/android_share_probe.dart --build-name=1.0.196 --build-number=197 --dart-define=APP_TARGET=mobile
  if($LASTEXITCODE -ne 0){throw 'Probe build failed'}
  Write-Output ('PROBE_APK='+ (Join-Path $probeRoot 'build/app/outputs/flutter-apk/app-release.apk'))
} finally {Pop-Location;$env:UNTOUCH_SIGNING_PROPERTIES=$probePreviousSigning}
