param(
  [string]$FlutterRoot='C:/Users/alexe/develop/flutter',
  [ValidateSet('android-arm64','android-x64','android-arm64,android-x64')][string]$TargetPlatform='android-arm64',
  [switch]$BottomBanner,
  [int]$BuildNumber=0
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$versionText=[IO.File]::ReadAllText((Join-Path $projectRoot 'pubspec.yaml'))
if($versionText -notmatch '(?m)^version:\s*([^+\s]+)\+(\d+)'){throw 'Project version missing'}
$probeBuildName=$Matches[1];$probeBuildNumber=$Matches[2]
if($BottomBanner){$probeBuildNumber=([int]$probeBuildNumber+1).ToString()}
if($BuildNumber -gt 0){$probeBuildNumber=$BuildNumber.ToString()}
$probeRoot=Join-Path $projectRoot ('tmp/android-automatic-ads-probe-'+(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff'))
if(Test-Path -LiteralPath $probeRoot){throw 'Probe directory exists'}
New-Item -ItemType Directory -Path $probeRoot | Out-Null
foreach($folder in @('lib','assets')){Copy-Item -LiteralPath (Join-Path $projectRoot $folder) -Destination $probeRoot -Recurse}
& robocopy (Join-Path $projectRoot 'android') (Join-Path $probeRoot 'android') /E /XD build .gradle /XF key.properties /NFL /NDL /NJH /NJS /NP | Out-Null
if($LASTEXITCODE -gt 7){throw 'Android source copy failed'}
foreach($file in @('pubspec.yaml','pubspec.lock','analysis_options.yaml','l10n.yaml','.metadata')){Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $probeRoot}
New-Item -ItemType Directory -Path (Join-Path $probeRoot 'tools') | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'tools/android_automatic_ads_probe.dart') -Destination (Join-Path $probeRoot 'tools')
Copy-Item -LiteralPath (Join-Path $projectRoot 'tools/ad_formats_rc_probe.dart') -Destination (Join-Path $probeRoot 'tools')
$gradle=Join-Path $probeRoot 'android/app/build.gradle.kts'
$gradleText=[IO.File]::ReadAllText($gradle)
$applicationPattern='(?s)applicationId = if \(System.getenv\("UNTOUCH_UI_PROBE"\).*?\} else "com.best4u.untouch"'
if(-not [regex]::IsMatch($gradleText,$applicationPattern)){throw 'Unexpected Android applicationId'}
$gradleText=[regex]::Replace($gradleText,$applicationPattern,'applicationId = "com.best4u.untouch.uiprobe.ads"')
if($BottomBanner){$gradleText=$gradleText.Replace('com.best4u.untouch.uiprobe.ads','com.best4u.untouch.uiprobe.banner')}
$gradleText=$gradleText.Replace('require(privateSigningPath != null)','require(true)')
$gradleText=$gradleText.Replace('resValue("string", "app_name", phoneLabel)',('resValue("string", "app_name", "QA'+$probeBuildNumber+' Untouch Ads")'))
if($BottomBanner){$gradleText=$gradleText.Replace('Untouch Ads','Untouch Banner')}
# Only the isolated UI probe skips R8. Dart still runs in release mode.
$gradleText=$gradleText.Replace('release {',"release {`n            isMinifyEnabled = false`n            isShrinkResources = false")
[IO.File]::WriteAllText($gradle,$gradleText)
$properties=Join-Path $probeRoot 'android/gradle.properties'
[IO.File]::WriteAllText($properties,[IO.File]::ReadAllText($properties).Replace('-Xmx2G','-Xmx1200m -XX:ActiveProcessorCount=2').Replace('org.gradle.workers.max=2','org.gradle.workers.max=1'))
$manifest=Join-Path $probeRoot 'android/app/src/main/AndroidManifest.xml'
[IO.File]::WriteAllText($manifest,[IO.File]::ReadAllText($manifest).Replace('<application','<application android:usesCleartextTraffic="true"').Replace('android:label="Untouch"','android:label="QA208 Untouch Ads"'))
$dart=Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$flutter=Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'
$probePreviousSigning=$env:UNTOUCH_SIGNING_PROPERTIES
$env:UNTOUCH_SIGNING_PROPERTIES=$null
Push-Location $probeRoot
try {
  & $dart $flutter pub get --offline
  if($LASTEXITCODE -ne 0){throw 'Probe dependencies failed'}
  $extraDefines=@()
  if($BottomBanner){$extraDefines += '--dart-define=ANDROID_BANNER_PROBE=true'}
  & $dart $flutter build apk --release "--target-platform=$TargetPlatform" --no-pub --target=tools/android_automatic_ads_probe.dart "--build-name=$probeBuildName" "--build-number=$probeBuildNumber" --dart-define=APP_TARGET=mobile --dart-define=YANDEX_DEMO_ADS=true @extraDefines
  if($LASTEXITCODE -ne 0){throw 'Probe build failed'}
  Write-Output ('PROBE_APK='+ (Join-Path $probeRoot 'build/app/outputs/flutter-apk/app-release.apk'))
} finally {Pop-Location;$env:UNTOUCH_SIGNING_PROPERTIES=$probePreviousSigning}
