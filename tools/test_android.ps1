param(
  [string]$FlutterRoot = 'C:\Users\alexe\develop\flutter',
  [string[]]$TestPaths = @('test'),
  [string]$LogPath = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location -LiteralPath $root
$flutter = Join-Path $FlutterRoot 'bin/flutter.bat'
$icons = Join-Path $FlutterRoot 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
if (-not (Test-Path -LiteralPath $flutter)) { throw 'Set -FlutterRoot to the Flutter SDK directory.' }
if (-not (Test-Path -LiteralPath $icons)) { throw 'Flutter material font artifact is missing; run flutter precache first.' }
$priorFonts=$env:RANKING_FONT_DIR; $priorIcons=$env:RANKING_ICON_FONT
try {
  $env:RANKING_FONT_DIR=Join-Path $root 'test/fixtures/fonts'
  $env:RANKING_ICON_FONT=$icons
  if ($LogPath) {
    & $flutter test --no-pub @TestPaths --reporter expanded *> $LogPath
  } else {
    & $flutter test --no-pub @TestPaths --reporter expanded
  }
  $code=$LASTEXITCODE
} finally {
  $env:RANKING_FONT_DIR=$priorFonts; $env:RANKING_ICON_FONT=$priorIcons
}
exit $code
