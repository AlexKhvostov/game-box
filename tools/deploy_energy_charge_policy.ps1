param(
 [ValidateSet('package','audit','backup','apply','activate','verify')][string]$Mode='audit',
 [string]$Directory='',
 [string]$Package='',
 [switch]$AllowWrite
)
$ErrorActionPreference='Stop'
$arguments=@((Join-Path $PSScriptRoot 'deploy_energy_charge_policy.py'),$Mode)
if($Mode -eq 'package') { & C:/Python312/python.exe @arguments; if($LASTEXITCODE -ne 0){throw 'Package preparation failed'}; return }
if(!$Directory -or !$Package){throw 'Explicit Directory and Package are required'}
$arguments+=@('--directory',$Directory,'--package',$Package)
if($AllowWrite){$arguments+='--allow-write'}
$credential=Import-Clixml -LiteralPath (Join-Path $env:LOCALAPPDATA 'Untouch/ftp-credentials.xml')
$payload=@{host='ftp80.hostland.ru';port=21;user=$credential.UserName;password=$credential.GetNetworkCredential().Password}|ConvertTo-Json -Compress
try{$payload|& C:/Python312/python.exe @arguments;if($LASTEXITCODE -ne 0){throw "Scoped charge-policy operation failed ($LASTEXITCODE)"}}
finally{$payload=$null;$credential=$null}
