# Release Web build for Telegram Mini App (Canvas + JS, arcade only).
#
# Usage:
#   powershell -File tools/build_telegram_web.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$src = Join-Path $root 'telegram-web'
$out = Join-Path $root 'build\web'
$assetsSrc = Join-Path $root 'assets'
$webMeta = Join-Path $root 'web'

if (-not (Test-Path $src)) {
  Write-Error "Missing telegram-web/ folder"
}

Write-Host 'Building Telegram Canvas Web...'

try {
  if (Test-Path $out) { Remove-Item $out -Recurse -Force }
} catch {
  Write-Host "build\web is in use, overlaying files instead of a clean wipe"
}
New-Item -ItemType Directory -Force -Path $out | Out-Null

# Core app
Copy-Item -Path (Join-Path $src '*') -Destination $out -Recurse -Force

# Dotfiles (.htaccess, etc.)
$htaccess = Join-Path $src '.htaccess'
if (Test-Path $htaccess) {
  Copy-Item -Path $htaccess -Destination $out -Force
}

# Cache-busting: stamp version on all assets
$version = Get-Date -Format "yyyyMMdd_HHmmss"
Write-Host "Stamping build version: $version"

$indexPath = Join-Path $out 'index.html'
if (Test-Path $indexPath) {
  $html = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
  $html = $html -replace 'app\.css(\?v=[^"''\s>]+)?', "app.css?v=$version"
  $html = $html -replace 'sheets\.css(\?v=[^"''\s>]+)?', "sheets.css?v=$version"
  $html = $html -replace 'main\.js(\?v=[^"''\s>]+)?', "main.js?v=$version"
  [System.IO.File]::WriteAllText($indexPath, $html, [System.Text.Encoding]::UTF8)
}

# Add version to ES module imports in build/web/js
Get-ChildItem -Path (Join-Path $out 'js\*.js') | ForEach-Object {
  $js = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  $js = $js -replace "from '(\./[^']+?\.js)(\?v=[^']*)?'", "from '`$1?v=$version'"
  [System.IO.File]::WriteAllText($_.FullName, $js, [System.Text.Encoding]::UTF8)
}

# Game assets (sfx, branding)
$assetsOut = Join-Path $out 'assets'
New-Item -ItemType Directory -Force -Path $assetsOut | Out-Null
Copy-Item -Path (Join-Path $assetsSrc '*') -Destination $assetsOut -Recurse -Force

# Icons / favicon from Flutter web template
foreach ($item in @('favicon.png', 'manifest.json', 'icons')) {
  $from = Join-Path $webMeta $item
  if (Test-Path $from) {
    Copy-Item -Path $from -Destination (Join-Path $out (Split-Path $item -Leaf)) -Recurse -Force
  }
}

$releasesDir = Join-Path $root 'releases'
New-Item -ItemType Directory -Force -Path $releasesDir | Out-Null

$versionedZip = Join-Path $releasesDir "untouch-telegram-web-v$version.zip"
$latestZip = Join-Path $releasesDir 'untouch-telegram-web.zip'

Write-Host "Creating versioned archive: $versionedZip"
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $versionedZip -Force
Copy-Item -Path $versionedZip -Destination $latestZip -Force

# FTP-папка: готовый сайт, который можно сразу перелить на хостинг
$ftpDir = Join-Path $root 'hosting'
if (Test-Path $ftpDir) { Remove-Item $ftpDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $ftpDir | Out-Null
Copy-Item -Path (Join-Path $out '*') -Destination $ftpDir -Recurse -Force
$htOut = Join-Path $out '.htaccess'
if (Test-Path $htOut) {
  Copy-Item -Path $htOut -Destination $ftpDir -Force
}

Write-Host ''
Write-Host "Done: $out"
Write-Host "FTP folder:    $ftpDir"
Write-Host "Versioned Zip: $versionedZip"
Write-Host "Latest Zip:    $latestZip"
Write-Host "FTP: upload CONTENTS of build\web\ (or hosting\) to https://untouch.ballaball.xyz/"
Write-Host "Do not overwrite api/db_config.php or api/bot_config.php on the host"
Write-Host "See docs/TELEGRAM_WEBAPP.md"
