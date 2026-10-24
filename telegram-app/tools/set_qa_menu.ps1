param([string]$Origin='', [switch]$Restore, [switch]$ForOnlyStartedChat)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module -Name (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
$taskSecret=$null;$taskClient=$null;$taskBackup=Join-Path $taskRoot '.private/telegram-port/menu-before-native-qa.json'
$taskStage='decrypt';$taskCandidateCount=$null
if($ForOnlyStartedChat){$taskBackup=Join-Path $taskRoot '.private/telegram-port/chat-menu-before-native-qa.json'}
try{
  if(-not $Restore -and $Origin -notmatch '^https://(?:[A-Za-z0-9-]+\.trycloudflare\.com|[a-f0-9]+\.lhr\.life)$'){throw 'origin_invalid'}
  $taskSecret=ConvertTo-SecureString -String ([IO.File]::ReadAllText((Join-Path $taskRoot '.private/telegram-port/testuntouch_bot.token.dpapi')))
  $taskCredential=New-Object System.Management.Automation.PSCredential ('testuntouch_bot',$taskSecret);$taskToken=$taskCredential.GetNetworkCredential().Password
  $taskClient=New-Object Net.Http.HttpClient;$taskClient.Timeout=[TimeSpan]::FromSeconds(15)
  $taskMe=$taskClient.GetStringAsync("https://api.telegram.org/bot$taskToken/getMe").GetAwaiter().GetResult()|ConvertFrom-Json
  if(-not $taskMe.ok -or $taskMe.result.username -ine 'testuntouch_bot'){throw 'wrong_bot'}
  $taskChatId=$null
  if($ForOnlyStartedChat -and -not $Restore){
    $taskStage='getUpdates'
    $taskUpdates=$taskClient.GetStringAsync("https://api.telegram.org/bot$taskToken/getUpdates?limit=100&timeout=0").GetAwaiter().GetResult()|ConvertFrom-Json
    $taskChats=@($taskUpdates.result|Where-Object{$_.message.chat.type -eq 'private' -and $_.message.from.id -eq $_.message.chat.id -and $_.message.text -match '^/start(?:\s|$)'}|ForEach-Object{$_.message.chat.id}|Select-Object -Unique)
    $taskStage='qa_account_select';$taskCandidateCount=$taskChats.Count
    if(-not $taskUpdates.ok -or $taskChats.Count -ne 1){throw 'qa_account_ambiguous'}
    $taskChatId=$taskChats[0];$taskUpdates=$null;$taskChats=$null
  }
  if($Restore){
    $taskSaved=Get-Content -Raw -LiteralPath $taskBackup|ConvertFrom-Json
    if($ForOnlyStartedChat){$taskChatId=$taskSaved.chatId;$taskMenu=$taskSaved.menu}else{$taskMenu=$taskSaved}
  }
  else{
    if(-not(Test-Path -LiteralPath $taskBackup)){
      $taskSuffix=if($taskChatId){"?chat_id=$taskChatId"}else{''}
      $taskPrevious=$taskClient.GetStringAsync("https://api.telegram.org/bot$taskToken/getChatMenuButton$taskSuffix").GetAwaiter().GetResult()|ConvertFrom-Json
      if(-not $taskPrevious.ok){throw 'menu_unavailable'}
      if($ForOnlyStartedChat){
        $taskOldMenu=if($taskPrevious.result.type -eq 'web_app' -and $taskPrevious.result.web_app.url -eq $Origin){@{type='default'}}else{$taskPrevious.result}
        @{chatId=$taskChatId;menu=$taskOldMenu}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $taskBackup -Encoding utf8
      }else{$taskPrevious.result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $taskBackup -Encoding utf8}
    }
    $taskMenu=@{type='web_app';text='Untouch QA';web_app=@{url=$Origin}}
  }
  $taskBody=@{menu_button=$taskMenu};if($taskChatId){$taskBody.chat_id=$taskChatId};$taskJson=$taskBody|ConvertTo-Json -Depth 8 -Compress
  $taskContent=New-Object Net.Http.StringContent ($taskJson,[Text.Encoding]::UTF8,'application/json')
  try{$taskReply=$taskClient.PostAsync("https://api.telegram.org/bot$taskToken/setChatMenuButton",$taskContent).GetAwaiter().GetResult();$taskResult=$taskReply.Content.ReadAsStringAsync().GetAwaiter().GetResult()|ConvertFrom-Json}finally{$taskContent.Dispose()}
  if(-not $taskResult.ok){throw 'menu_update_failed'}
  [ordered]@{ok=$true;username=$taskMe.result.username;menuType=$taskMenu.type;restored=[bool]$Restore;messagesSent=$false;paymentsCalled=$false}|ConvertTo-Json
}catch{[ordered]@{ok=$false;error='qa_menu_update_failed';stage=$taskStage;candidateCount=$taskCandidateCount;secretDisplayed=$false}|ConvertTo-Json;exit 1}
finally{if($taskClient){$taskClient.Dispose()};if($taskSecret){$taskSecret.Dispose()};$taskToken=$null;$taskCredential=$null}
