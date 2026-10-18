param(
  [switch]$NoBump,
  [switch]$AppBundle,
  [switch]$PlayStore,
  [switch]$GooglePlayBilling,
  [switch]$DemoAds,
  [switch]$LiveAds,
  [switch]$TestTools,
  [switch]$GameplayDebug,
  [switch]$TestServicePreview,
  [switch]$ProductionRelease,
  [string]$GoogleWebClientId = '',
  [string]$SigningDirectory = '',
  [string]$FlutterRoot = 'C:\Users\alexe\develop\flutter'
)
$ErrorActionPreference = 'Stop'
if ($DemoAds -and $LiveAds) { throw 'Choose either DemoAds or LiveAds, not both' }
if ($ProductionRelease -and ($TestServicePreview -or $TestTools -or $GameplayDebug -or $DemoAds)) {
  throw 'Production release cannot contain free test grants, preview services, debug tools or demo ads'
}
if ($TestTools -and ($AppBundle -or $GooglePlayBilling -or $DemoAds -or $LiveAds)) {
  throw 'Test wallet APK cannot enable AAB, real billing or ads'
}
if ($env:UNTOUCH_UI_PROBE -eq 'true') { throw 'Disable the isolated UI probe before building a user release' }
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root
if (-not $SigningDirectory -and -not $env:UNTOUCH_SIGNING_PROPERTIES -and (Test-Path -LiteralPath (Join-Path $root '.private\android-signing\signing.properties'))) {
  $SigningDirectory = Join-Path $root '.private\android-signing'
}
# A previous invocation leaves the properties path set, but clears its password.
# Reload DPAPI for APK/AAB calls in the same PowerShell session.
if (-not $SigningDirectory -and $env:UNTOUCH_SIGNING_PROPERTIES) {
  $signingParent = Split-Path -Parent $env:UNTOUCH_SIGNING_PROPERTIES
  if (Test-Path -LiteralPath (Join-Path $signingParent 'password.dpapi')) {
    $SigningDirectory = $signingParent
  }
}
if ($SigningDirectory) {
  $env:UNTOUCH_SIGNING_PROPERTIES = Join-Path $SigningDirectory 'signing.properties'
  if (-not (Test-Path -LiteralPath $env:UNTOUCH_SIGNING_PROPERTIES)) { throw 'Signing properties are missing' }
}
if ($GoogleWebClientId -and $GoogleWebClientId -notmatch '^[a-zA-Z0-9.-]+\.apps\.googleusercontent\.com$') { throw 'Invalid Google web OAuth client ID' }
if ($GooglePlayBilling -and -not $GoogleWebClientId) { throw 'Billing release requires configured profile recovery' }
if ($AppBundle -and -not $env:UNTOUCH_SIGNING_PROPERTIES) { throw 'Store AAB requires private release signing properties' }
$pubspec = Join-Path $root 'pubspec.yaml'
$text = [IO.File]::ReadAllText($pubspec)
$pattern = '(?m)^version:[ \t]*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*\r?$'
if ($text -notmatch $pattern) { throw 'version: X.Y.Z+N not found' }
$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$code = [int]$Matches[4]
if (-not $NoBump) { $patch++; $code++ }
$version = "$major.$minor.$patch"
$fullVersion = "$version+$code"
if (-not $NoBump) {
  $text = [regex]::Replace($text, $pattern, "version: $fullVersion")
  [IO.File]::WriteAllText($pubspec, $text, (New-Object Text.UTF8Encoding $false))
}
$dart = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$flutter = Join-Path $FlutterRoot 'bin\cache\flutter_tools.snapshot'
if (-not (Test-Path -LiteralPath $dart) -or -not (Test-Path -LiteralPath $flutter)) {
  throw 'Installed Flutter SDK is missing'
}
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff')
$buildId = "android-v${version}_${stamp}"
$outDir = Join-Path $root "releases\$buildId"
if (Test-Path -LiteralPath $outDir) { throw 'Build folder already exists' }
$kind = if ($AppBundle) { 'appbundle' } else { 'apk' }
$buildArgs = @($flutter,'build',$kind,'--release','--no-pub','--dart-define=APP_TARGET=mobile')
$buildArgs += "--dart-define=TEST_TOOLS=$($TestTools.IsPresent.ToString().ToLowerInvariant())"
$buildArgs += "--dart-define=GAMEPLAY_DEBUG=$($GameplayDebug.IsPresent.ToString().ToLowerInvariant())"
$buildArgs += "--dart-define=TEST_SERVICE_PREVIEW=$($TestServicePreview.IsPresent.ToString().ToLowerInvariant())"
$buildArgs += "--dart-define=YANDEX_DEMO_ADS=$($DemoAds.IsPresent.ToString().ToLowerInvariant())"
$buildArgs += "--dart-define=YANDEX_LIVE_ADS=$($LiveAds.IsPresent.ToString().ToLowerInvariant())"
if ($GoogleWebClientId) { $buildArgs += "--dart-define=GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId" }
if ($GooglePlayBilling) { $buildArgs += '--dart-define=GOOGLE_PLAY_BILLING=true' }
$priorPlayBuild = $env:UNTOUCH_PLAY_BUILD
try {
  $env:UNTOUCH_PLAY_BUILD = $(if ($AppBundle -or $PlayStore) { 'true' } else { 'false' })
  if ($SigningDirectory) {
    $protected = Get-Content -Raw -LiteralPath (Join-Path $SigningDirectory 'password.dpapi')
    $secure = ConvertTo-SecureString $protected.Trim()
    $env:UNTOUCH_SIGNING_PASSWORD = [Net.NetworkCredential]::new('', $secure).Password
  }
  & $dart @buildArgs
  if ($LASTEXITCODE -ne 0) { throw "Android $kind build failed: $LASTEXITCODE" }
} finally {
  $env:UNTOUCH_PLAY_BUILD = $priorPlayBuild
  if ($SigningDirectory) { $env:UNTOUCH_SIGNING_PASSWORD = $null }
}
$extension = if ($AppBundle) { 'aab' } else { 'apk' }
$src = if ($AppBundle) { Join-Path $root 'build\app\outputs\bundle\release\app-release.aab' } else { Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk' }
if (-not (Test-Path -LiteralPath $src)) { throw 'APK output is missing' }
New-Item -ItemType Directory -Path $outDir | Out-Null
$privacyManifest = Join-Path $root 'build\app\intermediates\merged_manifests\release\processReleaseManifest\AndroidManifest.xml'
& (Join-Path $root 'tools\verify_android_ads_manifest.ps1') -ManifestPath $privacyManifest |
  Set-Content -LiteralPath (Join-Path $outDir 'ads-manifest-check.json') -Encoding UTF8
$dest = Join-Path $outDir "Untouch-$fullVersion.$extension"
Copy-Item -LiteralPath $src -Destination $dest
$configPath = if ($TestTools) { 'assets\config\published-gameplay.json' } else { 'assets\config\android-firebase.json' }
$config = Get-Content -Raw -LiteralPath (Join-Path $root $configPath) | ConvertFrom-Json
$manifest = [ordered]@{
  buildId=$buildId; versionName=$version; versionCode=$code
  package='com.best4u.untouch'; target='mobile-arcade'
  applicationLabel=$(if ($AppBundle -or $PlayStore) { 'untouch' } else { "Untouch $code" })
  playStoreBuild=[bool]($AppBundle -or $PlayStore)
  sha256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
  configRevision=$config.revision; adMode=$(if ($LiveAds) {'yandex-publisher-units-adult-session-opt-in'} elseif ($DemoAds) {'yandex-demo-adult-session-opt-in-internal-only'} else {'off'}); signing=$(if ($env:UNTOUCH_SIGNING_PROPERTIES) {'private-release-key'} else {'development-debug-key'})
  yandexLiveAds=$LiveAds.IsPresent
  yandexRewardedUnit=$(if ($LiveAds) {'R-M-20184253-1'} elseif ($DemoAds) {'demo-rewarded-yandex'} else {$null})
  yandexInterstitialUnit=$(if ($LiveAds) {'R-M-20184253-2'} elseif ($DemoAds) {'demo-interstitial-yandex'} else {$null})
  audiencePolicy='game-and-autoscore-all-ages-ads18plus-session-opt-in'; advertisingIdPermission=$false
  googleIdentityConfigured=[bool]$GoogleWebClientId; googlePlayBilling=[bool]$GooglePlayBilling
  published=$false; deviceTested=$false
  testTools=$TestTools.IsPresent; walletMode=$(if ($TestTools) {'isolated-local-test'} else {'server-profile'})
  backend=$(if ($TestTools) {'isolated-local-test'} else {'supabase-android-v1'})
  supabaseProject=$(if ($TestTools) {$null} else {'exinizzxqtjnysgibide'})
  firebaseProject=$(if ($TestTools) {$null} else {'game-box-b30d4'})
  remoteConfigKey=$(if ($TestTools) {$null} else {'android_config_v1'})
  cloudDeploymentVerified=$false
  gameplayDebug=$GameplayDebug.IsPresent
  testServicePreview=$TestServicePreview.IsPresent
  productionRelease=$ProductionRelease.IsPresent
  limitations=@('Physical Android acceptance pending', 'Google Play publication of this build pending', 'Commercial Yandex ads depend on app moderation; Play purchases need separate device verification')
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'build.json') -Encoding UTF8
Write-Host "Artifact: $dest"
Write-Host "SHA256: $($manifest.sha256)"
