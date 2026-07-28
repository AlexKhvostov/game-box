# Release APK with versioned filename (keeps older builds).
# Example: releases/Untouch-1.0.3.apk
#
# Usage:
#   powershell -File tools/build_phone_apk.ps1
#   powershell -File tools/build_phone_apk.ps1 -NoBump

param(
  [switch]$NoBump
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$pubspec = Join-Path $root 'pubspec.yaml'
$text = Get-Content -Raw -Path $pubspec
if ($text -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
  throw 'version: X.Y.Z+N not found in pubspec.yaml'
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = [int]$Matches[4]

if (-not $NoBump) {
  $patch++
  $build++
  $newVersion = "$major.$minor.$patch+$build"
  $text = [regex]::Replace(
    $text,
    '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$',
    "version: $newVersion"
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($pubspec, $text, $utf8NoBom)
  Write-Host "Version -> $newVersion"
} else {
  $newVersion = "$major.$minor.$patch+$build"
  Write-Host "Version (no bump): $newVersion"
}

$name = "$major.$minor.$patch"
Write-Host 'flutter build apk --release ...'
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$src = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
$outDir = Join-Path $root 'releases'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$dest = Join-Path $outDir "Untouch-$name.apk"
if (Test-Path $dest) {
  $dest = Join-Path $outDir "Untouch-$name+$build.apk"
}

Copy-Item -Path $src -Destination $dest -Force
$sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
Write-Host ''
Write-Host "Done: $dest ($sizeMb MB)"
Write-Host "versionName=$name  versionCode=$build"
