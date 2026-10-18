param(
    [string]$AvdName = 'Untouch_API_36',
    [string]$SdkPath = "$env:LOCALAPPDATA\Android\Sdk"
)

$ErrorActionPreference = 'Stop'
$emulatorPath = Join-Path $SdkPath 'emulator\emulator.exe'
if (-not (Test-Path -LiteralPath $emulatorPath)) {
    throw 'Android Emulator is not installed in the selected SDK.'
}
$avds = @(& $emulatorPath -list-avds)
if ($LASTEXITCODE -ne 0 -or $AvdName -notin $avds) {
    throw "Virtual device '$AvdName' is missing. Create it in Android Studio Device Manager."
}
Start-Process -FilePath $emulatorPath -ArgumentList @('-avd', $AvdName, '-gpu', 'auto') -WindowStyle Hidden
Write-Host "Starting Android virtual device: $AvdName"
