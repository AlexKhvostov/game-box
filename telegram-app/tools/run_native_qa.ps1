param([Parameter(Mandatory=$true)][string]$Site,[Parameter(Mandatory=$true)][string]$Origin)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module -Name (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
$taskSecret=$null
try{
  $taskSecret=ConvertTo-SecureString -String ([IO.File]::ReadAllText((Join-Path $taskRoot '.private/telegram-port/testuntouch_bot.token.dpapi')))
  $taskCredential=New-Object System.Management.Automation.PSCredential ('testuntouch_bot',$taskSecret)
  $env:UNTOUCH_QA_BOT_TOKEN=$taskCredential.GetNetworkCredential().Password
  $env:UNTOUCH_QA_SITE=[IO.Path]::GetFullPath($Site);$env:UNTOUCH_QA_ORIGIN=$Origin
  & (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe') (Join-Path $PSScriptRoot 'serve_native_qa.mjs')
}finally{Remove-Item Env:UNTOUCH_QA_BOT_TOKEN -ErrorAction SilentlyContinue;Remove-Item Env:UNTOUCH_QA_SITE -ErrorAction SilentlyContinue;Remove-Item Env:UNTOUCH_QA_ORIGIN -ErrorAction SilentlyContinue;$taskCredential=$null;if($taskSecret){$taskSecret.Dispose()}}
