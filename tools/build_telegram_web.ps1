# Release Web build for Telegram Mini App (Canvas + JS, arcade only).
#
# Usage:
#   powershell -File tools/build_telegram_web.ps1

param([string]$Version = '', [switch]$LandingOnly, [switch]$LandingDesignOnly, [switch]$MobileApiOnly, [switch]$LegalOnly,
  [string]$MobileApiSourceDirectory = '', [string[]]$MobileApiFiles = @(),
  [string]$MobileApiExpectedHashesFile = '', [string[]]$MobileAdminFiles = @(),
  [switch]$LegalPrivacyOnly, [string]$LegalExpectedHashesFile = '',
  [string]$TelegramSourceDirectory = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$src = Join-Path $root 'telegram-web'
$out = Join-Path $root 'build\web'
$assetsSrc = Join-Path $root 'assets'
$webMeta = Join-Path $root 'web'
if (-not $Version) { $Version = (Get-Content -LiteralPath (Join-Path $src 'version.json') -Raw | ConvertFrom-Json).version }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must be major.minor.patch' }
$createdAt = [DateTime]::UtcNow
$timestamp = $createdAt.ToString('yyyyMMdd_HHmmss_fff')
$buildId = "v${Version}_$timestamp"
if ($TelegramSourceDirectory) {
  if ($LandingOnly -or $MobileApiOnly -or $LegalOnly) { throw 'Isolated Telegram source cannot be combined with other release modes' }
  $src = [System.IO.Path]::GetFullPath($TelegramSourceDirectory)
  $taskSourceRoot = [System.IO.Path]::GetFullPath((Join-Path $root 'tmp')) + [System.IO.Path]::DirectorySeparatorChar
  if (-not $src.StartsWith($taskSourceRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath (Join-Path $src 'index.html'))) { throw 'Expected an isolated Telegram source under workspace tmp/' }
  $out = Join-Path $root "build\telegram-$buildId"
}

# Add only the public policy resources; preserve the published landing and game.
if ($LegalOnly) {
  if ($LandingOnly -or $MobileApiOnly) { throw 'Choose one release mode' }
  $buildId = "legal-$buildId"
  $releaseDir = Join-Path $root "releases\$buildId"
  if (Test-Path -LiteralPath $releaseDir) { throw 'Legal release already exists' }
  $site = Join-Path $releaseDir 'site'
  New-Item -ItemType Directory -Path $site -Force | Out-Null
  $taskLegalPaths = if ($LegalPrivacyOnly) { @('privacy') } else { @('privacy','delete-account') }
  foreach ($name in $taskLegalPaths) {
    Copy-Item -LiteralPath (Join-Path $src "landing\$name") -Destination $site -Recurse
  }
  if (-not $LegalPrivacyOnly) { Copy-Item -LiteralPath (Join-Path $src 'landing\legal.css') -Destination $site }
  [ordered]@{version=$Version; buildId=$buildId; artifact='legal'; createdAt=$createdAt.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $site 'legal-release.json') -Encoding UTF8
  $files = @(Get-ChildItem -LiteralPath $site -File -Recurse | ForEach-Object {
    [ordered]@{path=$_.FullName.Substring($site.Length+1).Replace('\','/'); bytes=$_.Length; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
  })
  $taskLegalManifest = [ordered]@{version=$Version; buildId=$buildId; artifact='legal'; createdAt=$createdAt.ToString('o'); files=$files}
  if ($LegalExpectedHashesFile) { $taskLegalManifest.expectedBeforeHashes = Get-Content -Raw -LiteralPath $LegalExpectedHashesFile | ConvertFrom-Json }
  $taskLegalManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $releaseDir 'manifest.json') -Encoding UTF8
  Compress-Archive -Path (Join-Path $site '*') -DestinationPath (Join-Path $releaseDir "untouch-$buildId.zip")
  Write-Host "Legal release: $releaseDir"
  return
}

# Additive Android API release: keep the published Mini App and admin assets intact.
if ($MobileApiOnly) {
  $buildId = "mobile-api-$buildId"
  $releaseDir = Join-Path $root "releases\$buildId"
  if (Test-Path -LiteralPath $releaseDir) { throw 'Mobile API release already exists' }
  $site = Join-Path $releaseDir 'site'
  $api = Join-Path $site 'api'
  New-Item -ItemType Directory -Path $api -Force | Out-Null
  $taskApiSource = if ($MobileApiSourceDirectory) { (Resolve-Path -LiteralPath $MobileApiSourceDirectory).Path } else { Join-Path $src 'api' }
  $taskApiSelected = if ($MobileApiFiles.Count) { $MobileApiFiles } else { @('mobile.php','mobile_store.php','mobile_wallet.php','mobile_beta.php','mobile_identity.php','mobile_admin.php','mobile_google.php','mobile_play.php','mobile_play_notifications.php','mobile_play_rtdn.php','mobile_play_maintenance.php','mobile_config.example.php','scores.php','.htaccess') }
  foreach ($file in $taskApiSelected) {
    if ($file -notmatch '^[a-zA-Z0-9_.-]+$' -or $file -in @('mobile_config.php','db_config.php','bot_config.php')) { throw 'Invalid or protected mobile API file' }
    Copy-Item -LiteralPath (Join-Path $taskApiSource $file) -Destination $api
  }
  foreach ($taskAdminFile in $MobileAdminFiles) {
    if ($taskAdminFile -notin @('admin.js','index.html')) { throw 'Invalid mobile admin file' }
    $taskAdminOut = Join-Path $site 'admin'
    New-Item -ItemType Directory -Path $taskAdminOut -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskApiSource "admin/$taskAdminFile") -Destination $taskAdminOut
  }
  if (-not $MobileApiFiles.Count) {
    New-Item -ItemType Directory -Path (Join-Path $api 'vendor') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $src 'api\vendor\php-jwt') -Destination (Join-Path $api 'vendor') -Recurse
  }
  $identity = [ordered]@{version=$Version; buildId=$buildId; artifact='mobile-api'; createdAt=$createdAt.ToString('o')}
  $identity | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $api 'mobile-release.json') -Encoding UTF8
  $files = @(Get-ChildItem -LiteralPath $site -File -Recurse -Force | ForEach-Object {
    [ordered]@{path=$_.FullName.Substring($site.Length+1).Replace('\','/'); bytes=$_.Length; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
  })
  $taskApiManifest = [ordered]@{version=$Version; buildId=$buildId; artifact='mobile-api'; createdAt=$createdAt.ToString('o'); files=$files}
  if ($MobileApiExpectedHashesFile) {
    $taskApiManifest.expectedBeforeHashes = Get-Content -Raw -LiteralPath $MobileApiExpectedHashesFile | ConvertFrom-Json
  }
  $taskApiManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $releaseDir 'manifest.json') -Encoding UTF8
  $zip = Join-Path $releaseDir "untouch-$buildId.zip"
  Compress-Archive -Path (Join-Path $site '*') -DestinationPath $zip
  Write-Host "Mobile API release: $releaseDir"
  Write-Host "Archive: $zip"
  return
}

# Independent static landing for a separate hosting account. Never package game APIs.
if ($LandingOnly) {
  $landingReleaseDir = Join-Path $root "releases\landing-$buildId"
  if (Test-Path -LiteralPath $landingReleaseDir) { throw 'Landing release already exists' }
  $landingSite = Join-Path $landingReleaseDir 'site'
  New-Item -ItemType Directory -Path $landingSite -Force | Out-Null
  if ($LandingDesignOnly) {
    # Bounded visual update: retain published legal pages and historical assets.
    foreach ($taskLandingFile in @('index.html','demo.js','media.js','stores.js','neon.css','hero.css')) {
      Copy-Item -LiteralPath (Join-Path $src "landing/$taskLandingFile") -Destination $landingSite
    }
    New-Item -ItemType Directory -Path (Join-Path $landingSite 'assets') | Out-Null
    $taskAssetReferences = [regex]::Matches([IO.File]::ReadAllText((Join-Path $src 'landing/index.html')), 'assets/neon-[a-z0-9-]+\.webp') | ForEach-Object { $_.Value } | Select-Object -Unique
    foreach ($taskAssetReference in $taskAssetReferences) {
      Copy-Item -LiteralPath (Join-Path $src "landing/$taskAssetReference") -Destination (Join-Path $landingSite 'assets')
    }
    $taskDeliveryManifest = Join-Path $src 'landing/assets/delivery.json'
    if (Test-Path -LiteralPath $taskDeliveryManifest) {
      Copy-Item -LiteralPath $taskDeliveryManifest -Destination (Join-Path $landingSite 'assets')
      $taskDelivery = Get-Content -Raw -LiteralPath $taskDeliveryManifest | ConvertFrom-Json
      foreach ($taskImageProperty in $taskDelivery.PSObject.Properties) {
        foreach ($taskImagePart in $taskImageProperty.Value.parts) {
          $taskPartOutput = Join-Path $landingSite $taskImagePart
          New-Item -ItemType Directory -Path (Split-Path -Parent $taskPartOutput) -Force | Out-Null
          Copy-Item -LiteralPath (Join-Path $src "landing/$taskImagePart") -Destination $taskPartOutput
        }
      }
    }
    Copy-Item -LiteralPath (Join-Path $src 'landing/demo-engine') -Destination $landingSite -Recurse
  } else {
    Copy-Item -Path (Join-Path $src 'landing\*') -Destination $landingSite -Recurse
  }
  # Keep demo physics/rendering aligned with the current game, without economy or API.
  $landingEngine = Join-Path $landingSite 'demo-engine'
  New-Item -ItemType Directory -Path $landingEngine -Force | Out-Null
  if (-not $LandingDesignOnly) {
  foreach ($module in @('game-world.js','renderer.js','util.js')) { Copy-Item -LiteralPath (Join-Path $src "js\$module") -Destination $landingEngine -Force }
  $demoConfigSource = Get-Content (Join-Path $src 'config\gameplay-config.json') -Raw | ConvertFrom-Json
  $demoConfig = [ordered]@{}
  foreach ($section in @('theme','enemies','player','field','game')) { $demoConfig[$section] = $demoConfigSource.$section }
  ('export const config = ' + ($demoConfig | ConvertTo-Json -Depth 12) + ';') | Set-Content -LiteralPath (Join-Path $landingEngine 'config.js') -Encoding UTF8
  }
  Copy-Item -LiteralPath (Join-Path $webMeta 'favicon.png') -Destination $landingSite
  $landingIndex = Join-Path $landingSite 'index.html'
  $landingHtml = [System.IO.File]::ReadAllText($landingIndex, [System.Text.Encoding]::UTF8)
  $landingHtml = $landingHtml.Replace('../favicon.png', 'favicon.png').Replace('landing.css', "landing.css?v=$buildId").Replace('neon.css', "neon.css?v=$buildId").Replace('hero.css', "hero.css?v=$buildId").Replace('stores.js', "stores.js?v=$buildId").Replace('demo.js', "demo.js?v=$buildId")
  [System.IO.File]::WriteAllText($landingIndex, $landingHtml, [System.Text.Encoding]::UTF8)
  Get-ChildItem -LiteralPath $landingSite -Filter '*.js' -Recurse | ForEach-Object {
    $landingJs = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    $landingJs = $landingJs -replace "from '(\./[^']+?\.js)(\?v=[^']*)?'", "from '`$1?v=$buildId'"
    [System.IO.File]::WriteAllText($_.FullName, $landingJs, [System.Text.Encoding]::UTF8)
  }
  if ($LandingDesignOnly) {
    & python (Join-Path $root 'tools/build_landing_delivery.py') --site $landingSite --include-modules
    if ($LASTEXITCODE -ne 0) { throw 'Landing static delivery generation failed' }
  }
  $landingIdentity = [ordered]@{ version = $Version; buildId = $buildId; artifact = 'landing'; createdAt = $createdAt.ToString('o') }
  $landingIdentity | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $landingSite 'release.json') -Encoding UTF8
  $landingManifestFiles = @(Get-ChildItem -LiteralPath $landingSite -File -Recurse | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($landingSite.Length + 1).Replace('\', '/'); bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
  })
  [ordered]@{ version = $Version; buildId = $buildId; artifact = 'landing'; createdAt = $createdAt.ToString('o'); files = $landingManifestFiles } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $landingReleaseDir 'manifest.json') -Encoding UTF8
  $landingZip = Join-Path $landingReleaseDir "untouch-landing-$buildId.zip"
  Compress-Archive -Path (Join-Path $landingSite '*') -DestinationPath $landingZip
  Write-Host "Landing release: $landingReleaseDir"
  Write-Host "Landing archive: $landingZip"
  return
}

# Only these generated directories may be cleaned; verify before every build.
$expectedOut = [System.IO.Path]::GetFullPath((Join-Path $root $(if ($TelegramSourceDirectory) { "build\telegram-$buildId" } else { 'build\web' })))
if ([System.IO.Path]::GetFullPath($out) -ne $expectedOut) { throw 'Unexpected build output path' }

if (-not (Test-Path $src)) {
  Write-Error "Missing telegram-web/ folder"
}

Write-Host 'Building Telegram Canvas Web...'

try {
  if ($TelegramSourceDirectory -and (Test-Path -LiteralPath $out)) { throw 'Isolated build output already exists; never overwrite it' }
  if (Test-Path $out) { Remove-Item $out -Recurse -Force }
} catch { throw 'build\web is in use. Close its files and retry; a release must start clean.' }
New-Item -ItemType Directory -Force -Path $out | Out-Null

# Core app
Copy-Item -Path (Join-Path $src '*') -Destination $out -Recurse -Force

# Strip local server secrets and runtime state from the deployment package.
foreach ($name in @('bot_config.php', 'db_config.php', 'mobile_config.php', 'scores.json', 'scores_steps_v1.flag', 'rc_economy_cache.json', 'webhook_last.json', 'admin_guard.json', 'invite_photo_file_id.json')) {
  $excluded = [System.IO.Path]::GetFullPath((Join-Path $out "api\$name"))
  if (-not $excluded.StartsWith($expectedOut + [System.IO.Path]::DirectorySeparatorChar)) { throw 'Unexpected excluded path' }
  if (Test-Path -LiteralPath $excluded) { Remove-Item -LiteralPath $excluded -Force }
}

# Server publications are runtime data, never part of an FTP release.
$runtimeOut = [System.IO.Path]::GetFullPath((Join-Path $out 'api\config-data'))
if (-not $runtimeOut.StartsWith($expectedOut + [System.IO.Path]::DirectorySeparatorChar)) { throw 'Unexpected runtime output path' }
if ($TelegramSourceDirectory -and (Test-Path -LiteralPath $runtimeOut)) {
  if (@(Get-ChildItem -LiteralPath $runtimeOut -File -Recurse -Force | Where-Object { $_.Name -ne '.htaccess' }).Count) { throw 'Isolated Telegram source contains runtime publications' }
} elseif (Test-Path -LiteralPath $runtimeOut) { Remove-Item -LiteralPath $runtimeOut -Recurse -Force }
New-Item -ItemType Directory -Path $runtimeOut -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $src 'api\config-data\.htaccess') -Destination $runtimeOut -Force

# Dotfiles (.htaccess, etc.)
$htaccess = Join-Path $src '.htaccess'
if (Test-Path $htaccess) {
  Copy-Item -Path $htaccess -Destination $out -Force
}

# Cache-busting: stamp version on all assets
$assetVersion = $buildId
Write-Host "Stamping build: $buildId (UTC)"

$indexPath = Join-Path $out 'index.html'
if (Test-Path $indexPath) {
  $html = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
  $html = $html -replace 'app\.css(\?v=[^"''\s>]+)?', "app.css?v=$assetVersion"
  $html = $html -replace 'sheets\.css(\?v=[^"''\s>]+)?', "sheets.css?v=$assetVersion"
  $html = $html -replace 'ui-kit\.css(\?v=[^"''\s>]+)?', "ui-kit.css?v=$assetVersion"
  $html = $html -replace 'neon-home\.css(\?v=[^"''\s>]+)?', "neon-home.css?v=$assetVersion"
  $html = $html -replace 'neon-windows\.css(\?v=[^"''\s>]+)?', "neon-windows.css?v=$assetVersion"
  $html = $html -replace 'neon-lives\.css(\?v=[^"''\s>]+)?', "neon-lives.css?v=$assetVersion"
  $html = $html -replace 'neon-window-chrome\.js(\?v=[^"''\s>]+)?', "neon-window-chrome.js?v=$assetVersion"
  $html = $html -replace 'neon-shop\.css(\?v=[^"''\s>]+)?', "neon-shop.css?v=$assetVersion"
  $html = $html -replace 'neon-shop-packs\.css(\?v=[^"''\s>]+)?', "neon-shop-packs.css?v=$assetVersion"
  $html = $html -replace 'neon-shop-fit\.js(\?v=[^"''\s>]+)?', "neon-shop-fit.js?v=$assetVersion"
  $html = $html -replace 'neon-daily\.css(\?v=[^"''\s>]+)?', "neon-daily.css?v=$assetVersion"
  $html = $html -replace 'neon-plus\.css(\?v=[^"''\s>]+)?', "neon-plus.css?v=$assetVersion"
  $html = $html -replace 'neon-rent\.css(\?v=[^"''\s>]+)?', "neon-rent.css?v=$assetVersion"
  $html = $html -replace 'neon-earn\.css(\?v=[^"''\s>]+)?', "neon-earn.css?v=$assetVersion"
  $html = $html -replace 'neon-services-layout\.js(\?v=[^"''\s>]+)?', "neon-services-layout.js?v=$assetVersion"
  $html = $html -replace 'neon-result\.css(\?v=[^"''\s>]+)?', "neon-result.css?v=$assetVersion"
  $html = $html -replace 'neon-share\.css(\?v=[^"''\s>]+)?', "neon-share.css?v=$assetVersion"
  $html = $html -replace 'neon-result-fit\.js(\?v=[^"''\s>]+)?', "neon-result-fit.js?v=$assetVersion"
  $html = $html -replace 'neon-ranking\.css(\?v=[^"''\s>]+)?', "neon-ranking.css?v=$assetVersion"
  $html = $html -replace 'neon-player\.css(\?v=[^"''\s>]+)?', "neon-player.css?v=$assetVersion"
  $html = $html -replace 'neon-profile\.css(\?v=[^"''\s>]+)?', "neon-profile.css?v=$assetVersion"
  $html = $html -replace 'neon-profile-help\.css(\?v=[^"''\s>]+)?', "neon-profile-help.css?v=$assetVersion"
  $html = $html -replace 'neon-profile-layout\.js(\?v=[^"''\s>]+)?', "neon-profile-layout.js?v=$assetVersion"
  $html = $html -replace 'neon-messages\.css(\?v=[^"''\s>]+)?', "neon-messages.css?v=$assetVersion"
  $html = $html -replace 'neon-ranking-layout\.js(\?v=[^"''\s>]+)?', "neon-ranking-layout.js?v=$assetVersion"
  $html = $html -replace 'theme-light\.css(\?v=[^"''\s>]+)?', "theme-light.css?v=$assetVersion"
  $html = $html -replace 'energy\.css(\?v=[^"''\s>]+)?', "energy.css?v=$assetVersion"
  $html = $html -replace 'product\.css(\?v=[^"''\s>]+)?', "product.css?v=$assetVersion"
  $html = $html -replace 'main\.js(\?v=[^"''\s>]+)?', "main.js?v=$assetVersion"
  if ($TelegramSourceDirectory) {
    # Stamp new launcher resources as well as the existing app references.
    $html = [regex]::Replace($html, '((?:src|href)=["''](?!https?:|//)[^"'']+\.(?:js|css))(?:\?v=[^"'']*)?(["''])', {
      param($match)
      $match.Groups[1].Value + '?v=' + $assetVersion + $match.Groups[2].Value
    })
  }
  [System.IO.File]::WriteAllText($indexPath, $html, [System.Text.Encoding]::UTF8)
}

$adminIndexPath = Join-Path $out 'admin\index.html'
if (Test-Path $adminIndexPath) {
  $adminHtml = [System.IO.File]::ReadAllText($adminIndexPath, [System.Text.Encoding]::UTF8)
  $adminHtml = $adminHtml -replace 'admin\.css(\?v=[^"''\s>]+)?', "admin.css?v=$assetVersion"
  $adminHtml = $adminHtml -replace 'admin\.js(\?v=[^"''\s>]+)?', "admin.js?v=$assetVersion"
  $adminHtml = $adminHtml -replace 'monetize\.js(\?v=[^"''\s>]+)?', "monetize.js?v=$assetVersion"
  $adminHtml = $adminHtml -replace 'config-editor\.css(\?v=[^"''\s>]+)?', "config-editor.css?v=$assetVersion"
  [System.IO.File]::WriteAllText($adminIndexPath, $adminHtml, [System.Text.Encoding]::UTF8)
}

# Add version to ES module imports in build/web/js
$taskModulePaths = @((Join-Path $out 'js\*.js'))
if (Test-Path -LiteralPath (Join-Path $out 'admin')) { $taskModulePaths += (Join-Path $out 'admin\*.js') }
Get-ChildItem -Path $taskModulePaths | ForEach-Object {
  $js = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  $js = $js -replace "from '(\./[^']+?\.js)(\?v=[^']*)?'", "from '`$1?v=$assetVersion'"
  [System.IO.File]::WriteAllText($_.FullName, $js, [System.Text.Encoding]::UTF8)
}

# Game assets (sfx, branding)
$assetsOut = Join-Path $out 'assets'
New-Item -ItemType Directory -Force -Path $assetsOut | Out-Null
# Only runtime directories belong in a release; review catalogs stay local.
if (-not $TelegramSourceDirectory) { Get-ChildItem -LiteralPath $assetsSrc | Where-Object { $_.Name -in @('branding', 'config', 'floors', 'sfx') } | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $assetsOut -Recurse -Force
} }

# Icons / favicon from Flutter web template
if (-not $TelegramSourceDirectory) { foreach ($item in @('favicon.png', 'manifest.json', 'icons')) {
  $from = Join-Path $webMeta $item
  if (Test-Path $from) {
    Copy-Item -Path $from -Destination (Join-Path $out (Split-Path $item -Leaf)) -Recurse -Force
  }
} }

$releasesDir = Join-Path $root 'releases'
New-Item -ItemType Directory -Force -Path $releasesDir | Out-Null

$releaseDir = Join-Path $releasesDir $buildId
if (Test-Path -LiteralPath $releaseDir) { throw 'Build already exists; never overwrite a versioned release' }
New-Item -ItemType Directory -Path $releaseDir | Out-Null
$releaseSite = Join-Path $releaseDir 'site'

# Public build identity; configuration and player data are never embedded here.
$identity = [ordered]@{ version = $Version; buildId = $buildId; createdAt = $createdAt.ToString('o') }
if ($TelegramSourceDirectory) {
  $identity['artifact'] = 'telegram-native-launch'
  [ordered]@{version=$Version} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'version.json') -Encoding UTF8
}
$identity | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'release.json') -Encoding UTF8
Copy-Item -LiteralPath $out -Destination $releaseSite -Recurse
$fileManifest = @(Get-ChildItem -LiteralPath $releaseSite -File -Recurse -Force | ForEach-Object {
  [ordered]@{ path = $_.FullName.Substring($releaseSite.Length + 1).Replace('\', '/'); bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$gitRevision = (& git -c "safe.directory=$($root.Replace('\','/'))" rev-parse HEAD 2>$null)
$manifest = [ordered]@{ version = $Version; buildId = $buildId; createdAt = $createdAt.ToString('o'); gitRevision = $gitRevision; files = $fileManifest }
if ($TelegramSourceDirectory) { $manifest['artifact'] = 'telegram-native-launch' }
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $releaseDir 'manifest.json') -Encoding UTF8
$versionedZip = Join-Path $releaseDir "untouch-telegram-web-$buildId.zip"
$latestZip = Join-Path $releasesDir 'untouch-telegram-web.zip'

Write-Host "Creating versioned archive: $versionedZip"
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $versionedZip -Force
if ($TelegramSourceDirectory) {
  Write-Host "Isolated Telegram build: $releaseDir"
  Write-Host "Archive: $versionedZip"
  Write-Host 'Shared build/web, hosting and rolling release pointers preserved.'
  return
}
Copy-Item -Path $versionedZip -Destination $latestZip -Force
[ordered]@{ version = $Version; buildId = $buildId; releasePath = $releaseDir; archive = $versionedZip; archiveSha256 = (Get-FileHash -LiteralPath $versionedZip -Algorithm SHA256).Hash.ToLowerInvariant() } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $releasesDir 'latest.json') -Encoding UTF8

# FTP-папка: готовый сайт, который можно сразу перелить на хостинг
$ftpDir = Join-Path $root 'hosting'
if ([System.IO.Path]::GetFullPath($ftpDir) -ne [System.IO.Path]::GetFullPath((Join-Path $root 'hosting'))) { throw 'Unexpected hosting output path' }
if (Test-Path $ftpDir) { Remove-Item $ftpDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $ftpDir | Out-Null
Copy-Item -Path (Join-Path $out '*') -Destination $ftpDir -Recurse -Force
$htOut = Join-Path $out '.htaccess'
if (Test-Path $htOut) {
  Copy-Item -Path $htOut -Destination $ftpDir -Force
}
Copy-Item -LiteralPath (Join-Path $runtimeOut '.htaccess') -Destination (Join-Path $ftpDir 'api\config-data\.htaccess') -Force

Write-Host ''
Write-Host "Done: $out"
Write-Host "FTP folder:    $ftpDir"
Write-Host "Versioned Zip: $versionedZip"
Write-Host "Latest Zip:    $latestZip"
Write-Host "Release:       $releaseDir"
Write-Host "FTP: upload CONTENTS of build\web\ (or hosting\) to https://untouch.ballaball.xyz/"
Write-Host "Do not overwrite api/db_config.php or api/bot_config.php on the host"
Write-Host "Preserve api/config-data/ on the host: it contains admin publications"
Write-Host "See docs/TELEGRAM_WEBAPP.md"
