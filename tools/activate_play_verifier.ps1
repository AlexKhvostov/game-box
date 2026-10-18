param([Parameter(Mandatory=$true)][ValidateSet('prepare','apply')][string]$Mode,
 [Parameter(Mandatory=$true)][string]$Directory,[switch]$AllowActivation)
$ErrorActionPreference='Stop'
if($Mode -eq 'apply' -and -not $AllowActivation){throw 'Explicit -AllowActivation and root GO required'}
$credential=Import-Clixml -LiteralPath (Join-Path $env:LOCALAPPDATA 'Untouch/ftp-credentials.xml')
$payload=@{host='ftp80.hostland.ru';port=21;user=$credential.UserName;password=$credential.GetNetworkCredential().Password}|ConvertTo-Json -Compress
$parameters=@((Join-Path $PSScriptRoot 'activate_play_verifier.py'),'--mode',$Mode,'--directory',$Directory)
if($AllowActivation){$parameters+='--allow-activation'}
try{$payload | & C:/Python312/python.exe @parameters;if($LASTEXITCODE -ne 0){throw 'Play activation stopped; inspect private receipts before retry'}}finally{$payload=$null;$credential=$null}
