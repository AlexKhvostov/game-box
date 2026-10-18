<?php
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../telegram-web/api/tg_common.php';
require_once __DIR__.'/../telegram-web/api/mobile_store.php';
require_once __DIR__.'/../telegram-web/api/mobile_wallet.php';
require_once __DIR__.'/../telegram-web/api/mobile_invites.php';
require_once __DIR__.'/../telegram-web/api/mobile_energy_feedback.php';
try {
    $options=getopt('',['apply','deliver','prefix:']);$prefix=$options['prefix']??'';
    [$pdo]=tg_connect_pdo();if(!$pdo)throw new RuntimeException();
    if(isset($options['apply'])){mobile_energy_migrate_schema($pdo,$prefix);mobile_invites_migrate($pdo,$prefix);}
    $delivered=0;
    if(isset($options['deliver']))$delivered=mobile_energy_deliver_feedback($pdo,function($to,$subject,$body){
      return mail($to,'=?UTF-8?B?'.base64_encode($subject).'?=',$body,"MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8");
    },(int)round(microtime(true)*1000),$prefix);
    echo json_encode(['ok'=>true,'schemaApplied'=>isset($options['apply']),'delivered'=>$delivered]).PHP_EOL;
}catch(Throwable $e){fwrite(STDERR,'Energy maintenance failed: '.get_class($e).PHP_EOL);exit(1);}
