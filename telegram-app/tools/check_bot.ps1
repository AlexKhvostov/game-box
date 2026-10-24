param()
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module -Name (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
$taskProtectedPath=Join-Path $taskRoot '.private/telegram-port/testuntouch_bot.token.dpapi'
$taskSecret=$null;$taskClient=$null
$taskStage='decrypt'
try{
  $taskSecret=ConvertTo-SecureString -String ([IO.File]::ReadAllText($taskProtectedPath))
  $taskCredential=New-Object System.Management.Automation.PSCredential ('testuntouch_bot',$taskSecret)
  $taskToken=$taskCredential.GetNetworkCredential().Password
  $taskStage='token_format';if($taskToken -notmatch '^\d+:[A-Za-z0-9_-]+$'){throw 'invalid'}
  $taskClient=New-Object Net.Http.HttpClient
  $taskClient.Timeout=[TimeSpan]::FromSeconds(15)
  $taskStage='getMe';$taskMe=$taskClient.GetStringAsync("https://api.telegram.org/bot$taskToken/getMe").GetAwaiter().GetResult()|ConvertFrom-Json
  $taskStage='bot_identity';if(-not $taskMe.ok -or $taskMe.result.username -ine 'testuntouch_bot'){throw 'wrong_bot'}
  $taskStage='getChatMenuButton';$taskMenu=$taskClient.GetStringAsync("https://api.telegram.org/bot$taskToken/getChatMenuButton").GetAwaiter().GetResult()|ConvertFrom-Json
  [ordered]@{ok=$true;username=$taskMe.result.username;isBot=$taskMe.result.is_bot;hasMainWebApp=$taskMe.result.has_main_web_app;menuType=$taskMenu.result.type;menuOrigin=if($taskMenu.result.web_app.url){([Uri]$taskMenu.result.web_app.url).GetLeftPart([UriPartial]::Authority)}else{$null};readOnly=$true;paymentsCalled=$false}|ConvertTo-Json
}catch{[ordered]@{ok=$false;error='bot_check_failed';stage=$taskStage;username=if($taskStage -eq 'bot_identity'){$taskMe.result.username}else{$null};exceptionType=$_.Exception.GetType().Name;secretDisplayed=$false}|ConvertTo-Json;exit 1}
finally{if($taskClient){$taskClient.Dispose()};if($taskSecret){$taskSecret.Dispose()};$taskToken=$null;$taskCredential=$null}
