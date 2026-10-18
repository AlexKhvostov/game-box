<?php
function mobile_pace_validate($config) {
    if(!is_array($config))throw new InvalidArgumentException('Нужны параметры скорости');
    foreach(['startSpeedSteps'=>[0.01,250],'accelerationSteps'=>[0,50]] as $key=>$range){
      $v=$config[$key]??null;if(!is_int($v)&&!is_float($v))throw new InvalidArgumentException('Параметр должен быть числом');
      if(!is_finite((float)$v)||$v<$range[0]||$v>$range[1])throw new InvalidArgumentException('Параметр вне допустимого диапазона');
    }
    return ['startSpeedSteps'=>(float)$config['startSpeedSteps'],'accelerationSteps'=>(float)$config['accelerationSteps']];
}
function mobile_pace_read($directory=null) {
    $directory=$directory??(__DIR__.'/config-data');$file=$directory.'/mobile-pace.json';
    $config=['startSpeedSteps'=>34.72,'accelerationSteps'=>4.63];
    if(is_file($file))$config=mobile_pace_validate(json_decode(file_get_contents($file),true));
    return ['config'=>$config,'revision'=>hash('sha256',json_encode($config,JSON_PRESERVE_ZERO_FRACTION))];
}
function mobile_pace_save($config,$revision,$directory=null) {
    $config=mobile_pace_validate($config);$directory=$directory??(__DIR__.'/config-data');
    if(!is_dir($directory)&&!mkdir($directory,0755,true))throw new RuntimeException('Каталог недоступен');
    $lock=fopen($directory.'/mobile-pace.lock','c');if(!$lock||!flock($lock,LOCK_EX))throw new RuntimeException('Настройки заняты');
    $temp=null;
    try{
      $current=mobile_pace_read($directory);
      if(!is_string($revision)||!hash_equals($current['revision'],$revision))throw new RuntimeException('Настройки уже изменились. Загрузите их заново.');
      $temp=tempnam($directory,'mobile-pace-');
      if(file_put_contents($temp,json_encode($config,JSON_PRESERVE_ZERO_FRACTION),LOCK_EX)===false||!rename($temp,$directory.'/mobile-pace.json'))throw new RuntimeException('Не удалось сохранить');
      $temp=null;return mobile_pace_read($directory);
    }finally{if($temp!==null&&is_file($temp))unlink($temp);flock($lock,LOCK_UN);fclose($lock);}
}
