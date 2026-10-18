param([string]$Directory='.private/play-server-setup-20261015-inspect1')
$ErrorActionPreference='Stop'
$credential=Import-Clixml -LiteralPath (Join-Path $env:LOCALAPPDATA 'Untouch/ftp-credentials.xml')
$payload=@{host='ftp80.hostland.ru';port=21;user=$credential.UserName;password=$credential.GetNetworkCredential().Password}|ConvertTo-Json -Compress
try{
 $payload | & C:/Python312/python.exe (Join-Path $PSScriptRoot 'prepare_play_private_storage.py') --directory $Directory
 if($LASTEXITCODE -ne 0){throw 'Read-only Play storage inspection failed'}
}finally{$payload=$null;$credential=$null}
