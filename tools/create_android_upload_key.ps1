param(
  [string]$Directory = '',
  [string]$Keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
if (-not $Directory) { $Directory = Join-Path $repo '.private\android-signing' }
$destination = [IO.Path]::GetFullPath($Directory).TrimEnd('\')
if ($destination.StartsWith($repo + '\', [StringComparison]::OrdinalIgnoreCase) -or $destination -eq $repo) {
  if ($destination -ne (Join-Path $repo '.private\android-signing')) { throw 'Only .private/android-signing may contain signing material inside the project' }
  git -C $repo check-ignore --quiet --no-index .private/android-signing/signing.properties
  if ($LASTEXITCODE -ne 0) { throw 'Private signing directory must be ignored by Git' }
}
if (Test-Path -LiteralPath $destination) { throw 'Destination already exists; refusing to overwrite signing material' }
if (-not (Test-Path -LiteralPath $Keytool)) { throw 'Android Studio keytool is missing' }
New-Item -ItemType Directory -Path $destination | Out-Null
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
$acl.SetOwner($identity)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
Set-Acl -LiteralPath $destination -AclObject $acl
$bytes = New-Object byte[] 48
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$password = [Convert]::ToBase64String($bytes)
$secure = ConvertTo-SecureString $password -AsPlainText -Force
$secure | ConvertFrom-SecureString | Set-Content -LiteralPath (Join-Path $destination 'password.dpapi') -Encoding ascii
$keyPath = Join-Path $destination 'upload-keystore.jks'
try {
  $env:UNTOUCH_NEW_KEY_PASSWORD = $password
  & $Keytool -genkeypair -keystore $keyPath -storetype JKS -alias upload -keyalg RSA -keysize 4096 -validity 10000 -dname 'CN=Untouch Upload, OU=Android, O=Best4U' -storepass:env UNTOUCH_NEW_KEY_PASSWORD -keypass:env UNTOUCH_NEW_KEY_PASSWORD -noprompt
  if ($LASTEXITCODE -ne 0) { throw 'Key generation failed; preserve directory for inspection' }
  & $Keytool -exportcert -rfc -keystore $keyPath -alias upload -storepass:env UNTOUCH_NEW_KEY_PASSWORD -file (Join-Path $destination 'upload-certificate.pem')
  if ($LASTEXITCODE -ne 0) { throw 'Certificate export failed' }
  "storeFile=$($keyPath.Replace('\','/'))`nkeyAlias=upload`n" | Set-Content -LiteralPath (Join-Path $destination 'signing.properties') -Encoding ascii
  & $Keytool -list -v -keystore $keyPath -alias upload -storepass:env UNTOUCH_NEW_KEY_PASSWORD | Select-String 'SHA1:|SHA256:|Owner:|Valid from:'
  Write-Host "Upload key created: $destination"
  Write-Host 'Password is protected with Windows DPAPI for this Windows user. No plaintext password was written.'
} finally {
  $env:UNTOUCH_NEW_KEY_PASSWORD = $null
  $password = $null
  [Array]::Clear($bytes,0,$bytes.Length)
}
