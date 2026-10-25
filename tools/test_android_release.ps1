param(
  [string]$FlutterRoot='C:/Users/alexe/develop/flutter',
  [ValidateSet('off','demo','live')][string]$AdsMode='live',
  [string[]]$Tests=@()
)
$ErrorActionPreference='Stop'
$testProjectRoot=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$testFontSource=Join-Path $FlutterRoot 'bin/cache/artifacts/material_fonts'
$testFontRoot=Join-Path $testProjectRoot ('tmp/android-release-test-fonts-'+[DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fff'))
foreach($font in @('roboto-regular.ttf','roboto-bold.ttf','materialicons-regular.otf')){
  if(-not(Test-Path -LiteralPath (Join-Path $testFontSource $font))){throw "Missing Flutter test font: $font"}
}
[IO.Directory]::CreateDirectory($testFontRoot) | Out-Null
Copy-Item -LiteralPath (Join-Path $testFontSource 'roboto-regular.ttf') -Destination (Join-Path $testFontRoot 'Roboto-Regular.ttf')
Copy-Item -LiteralPath (Join-Path $testFontSource 'roboto-bold.ttf') -Destination (Join-Path $testFontRoot 'Roboto-Bold.ttf')
$previousRankingFonts=$env:RANKING_FONT_DIR
$previousRankingIcons=$env:RANKING_ICON_FONT
$env:RANKING_FONT_DIR=$testFontRoot
$env:RANKING_ICON_FONT=Join-Path $testFontSource 'materialicons-regular.otf'
$testArgs=@('test','--no-pub','--reporter','expanded')
if($AdsMode -eq 'demo'){$testArgs+='--dart-define=YANDEX_DEMO_ADS=true'}
if($AdsMode -eq 'live'){$testArgs+='--dart-define=YANDEX_LIVE_ADS=true'}
$testArgs+=$Tests
$testResult=1
Push-Location $testProjectRoot
try {
  Write-Output "ANDROID_TEST_MODE=$AdsMode; real Roboto and MaterialIcons loaded for layout tests"
  & (Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe') (Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot') @testArgs
  $testResult=$LASTEXITCODE
} finally {
  Pop-Location
  $env:RANKING_FONT_DIR=$previousRankingFonts
  $env:RANKING_ICON_FONT=$previousRankingIcons
}
exit $testResult
