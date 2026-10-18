param(
 [ValidateSet('audit','backup','apply','activate','verify')][string]$Mode='audit',
 [Parameter(Mandatory=$true)][string]$Directory,
 [Parameter(Mandatory=$true)][string]$Package,
 [switch]$AllowWrite
)
$ErrorActionPreference='Stop'
$arguments=@((Join-Path $PSScriptRoot 'deploy_simple_energy.py'),$Mode,'--directory',$Directory,'--package',$Package)
if($AllowWrite){$arguments+='--allow-write'}
$credential=Import-Clixml -LiteralPath (Join-Path $env:LOCALAPPDATA 'Untouch/ftp-credentials.xml')
$payload=@{host='ftp80.hostland.ru';port=21;user=$credential.UserName;password=$credential.GetNetworkCredential().Password}|ConvertTo-Json -Compress
try{$payload|& C:/Python312/python.exe @arguments;if($LASTEXITCODE -ne 0){throw "Android bonus operation failed ($LASTEXITCODE)"}}
finally{$payload=$null;$credential=$null}
