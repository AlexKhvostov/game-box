param([string]$Source = 'D:\Codex\secrets\untouch-google-play')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $root '.private\android-signing'
if (Test-Path -LiteralPath $destination) { throw 'Destination already exists; refusing to overwrite' }
foreach ($name in @('upload-keystore.jks','password.dpapi','upload-certificate.pem','signing.properties')) {
  if (-not (Test-Path -LiteralPath (Join-Path $Source $name))) { throw "Missing source file: $name" }
}
git -C $root check-ignore --quiet --no-index .private/android-signing/signing.properties
if ($LASTEXITCODE -ne 0) { throw 'Private directory must be ignored before copying' }
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = [Security.AccessControl.DirectorySecurity]::new()
$acl.SetAccessRuleProtection($true,$false)
$acl.SetOwner($identity)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
Set-Acl -LiteralPath $destination -AclObject $acl
foreach ($name in @('upload-keystore.jks','password.dpapi','upload-certificate.pem')) {
  $from = Join-Path $Source $name
  $to = Join-Path $destination $name
  Copy-Item -LiteralPath $from -Destination $to
  if ((Get-FileHash -LiteralPath $from).Hash -ne (Get-FileHash -LiteralPath $to).Hash) { throw "Copy mismatch: $name" }
}
$key = Join-Path $destination 'upload-keystore.jks'
"storeFile=$($key.Replace('\','/'))`nkeyAlias=upload`n" | Set-Content -LiteralPath (Join-Path $destination 'signing.properties') -Encoding ascii
try {
  $secure = ConvertTo-SecureString (Get-Content -Raw -LiteralPath (Join-Path $destination 'password.dpapi')).Trim()
  $env:UNTOUCH_VERIFY_KEY_PASSWORD = [Net.NetworkCredential]::new('',$secure).Password
  & 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe' -list -v -keystore $key -alias upload -storepass:env UNTOUCH_VERIFY_KEY_PASSWORD | Select-String 'SHA1:|SHA256:'
  if ($LASTEXITCODE -ne 0) { throw 'Copied keystore verification failed' }
} finally { $env:UNTOUCH_VERIFY_KEY_PASSWORD = $null; $secure = $null }
Write-Host "Verified signing directory: $destination"
Write-Host 'Original retained; Windows-bound password still requires a portable protected backup.'
