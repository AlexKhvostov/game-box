param(
 [Parameter(Mandatory=$true)][ValidateSet('prepare','install_key','verify_key','catalog')][string]$Mode,
 [Parameter(Mandatory=$true)][string]$Directory,
 [switch]$AllowInstall
)
$ErrorActionPreference='Stop'
if($Mode -eq 'install_key' -and -not $AllowInstall){throw 'Installing the key requires -AllowInstall and root GO'}
$credential=Import-Clixml -LiteralPath (Join-Path $env:LOCALAPPDATA 'Untouch/ftp-credentials.xml')
$payload=@{host='ftp80.hostland.ru';port=21;user=$credential.UserName;password=$credential.GetNetworkCredential().Password}|ConvertTo-Json -Compress
$parameters=@((Join-Path $PSScriptRoot 'setup_play_verifier.py'),'--mode',$Mode,'--directory',$Directory)
if($AllowInstall){$parameters+='--allow-install'}
try{
 $payload | & C:/Python312/python.exe @parameters
 if($LASTEXITCODE -ne 0){throw 'Scoped Play setup stopped; inspect private receipts'}
}finally{$payload=$null;$credential=$null}
