param([Parameter(Mandatory=$true)][string]$ManifestPath)
$ErrorActionPreference = 'Stop'
[xml]$manifest = Get-Content -LiteralPath $ManifestPath -Raw
$android = 'http://schemas.android.com/apk/res/android'
$deniedPermissions = @(
  'com.google.android.gms.permission.AD_ID',
  'android.permission.ACCESS_ADSERVICES_AD_ID',
  'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
  'android.permission.ACCESS_ADSERVICES_TOPICS',
  'com.google.android.providers.gsf.permission.READ_GSERVICES',
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION'
)
$permissions = @($manifest.manifest.'uses-permission' | ForEach-Object { $_.GetAttribute('name', $android) })
foreach ($name in $deniedPermissions) {
  if ($name -in $permissions) { throw "Disallowed permission: $name" }
}
$providers = @($manifest.manifest.application.provider | ForEach-Object { $_.GetAttribute('name', $android) })
foreach ($name in @(
  'com.yandex.mobile.ads.core.initializer.YandexAdsInitializeProvider',
  'io.appmetrica.analytics.internal.PreloadInfoContentProvider',
  'com.google.firebase.provider.FirebaseInitProvider'
)) {
  if ($name -in $providers) { throw "Automatic startup provider: $name" }
}
$required = @{
  'com.yandex.mobile.ads.AUTOMATIC_SDK_INITIALIZATION' = 'false'
  'firebase_analytics_collection_deactivated' = 'true'
}
foreach ($entry in $required.GetEnumerator()) {
  $nodes = @($manifest.manifest.application.'meta-data' | Where-Object { $_.GetAttribute('name', $android) -eq $entry.Key })
  if ($nodes.Count -ne 1 -or $nodes[0].GetAttribute('value', $android) -ne $entry.Value) {
    throw "Privacy metadata missing or wrong: $($entry.Key)"
  }
}
[ordered]@{
  passed = $true
  package = $manifest.manifest.package
  version = $manifest.manifest.GetAttribute('versionName', $android)
  permissions = $permissions
  providers = $providers
  yandexAutomaticInitialization = $false
  firebaseCollectionDeactivated = $true
} | ConvertTo-Json -Depth 4
