<?php
// READ-ONLY ONE-SHOT TEMPLATE: no mkdir, key upload, private config or DB access.
ini_set('display_errors','0');header('Content-Type: application/json');header('Cache-Control: no-store, private');header('X-Robots-Tag: noindex, nofollow');
$ppsToken='__TOKEN__';$ppsExpiry=(int)'__EXPIRES__';
if(($_SERVER['REQUEST_METHOD']??'')!=='POST'||!preg_match('/^[a-f0-9]{64}$/D',$ppsToken)||!is_string($_SERVER['HTTP_X_UNTOUCH_TEST']??null)||
 !hash_equals($ppsToken,$_SERVER['HTTP_X_UNTOUCH_TEST'])){http_response_code(404);echo '{}';exit;}
if(time()>$ppsExpiry||$ppsExpiry>time()+1800){http_response_code(410);echo '{"ok":false,"error":"probe_expired"}';exit;}
function pps_outside($path,$root){return $path!==$root&&strpos($path,$root.DIRECTORY_SEPARATOR)!==0;}
try {
 $document=realpath($_SERVER['DOCUMENT_ROOT']??'');$site=realpath(dirname(__DIR__));
 if(!$document||!$site)throw new RuntimeException();
 $parent=realpath(dirname($site));if(!$parent||$parent===DIRECTORY_SEPARATOR)throw new RuntimeException();
 $container=$parent.'/.untouch-private';$candidate=$container.'/play';
 $symlink=is_link($container)||is_link($candidate);
 if(is_dir($candidate))$candidate=realpath($candidate);
 elseif(is_dir($container)){$resolved=realpath($container);$symlink=$symlink||$resolved!==$container;$candidate=$resolved.'/play';}
 $outsideDocument=pps_outside($candidate,$document);$outsideSite=pps_outside($candidate,$site);
 $exists=is_dir($candidate);$writable=$exists?is_writable($candidate):(is_dir($container)?is_writable($container):is_writable($parent));
 echo json_encode(['ok'=>true,'readOnly'=>true,'documentRoot'=>$document,'actualSiteRoot'=>$site,'candidateParent'=>$parent,
   'candidateDirectory'=>$candidate,'candidateExists'=>$exists,'candidateWritable'=>$writable,'symlinkRejected'=>$symlink,
   'outsideDocumentRoot'=>$outsideDocument,'outsideActualSiteRoot'=>$outsideSite,
   'openBasedirConfigured'=>(string)ini_get('open_basedir')!=='',
   'safeCandidate'=>$outsideDocument&&$outsideSite&&$writable&&!$symlink,
   'keyRead'=>false,'keyTransferred'=>false,'directoriesCreated'=>false,'privateConfigChanged'=>false],JSON_UNESCAPED_SLASHES);
}catch(Throwable $error){http_response_code(503);echo '{"ok":false,"error":"storage_probe_unavailable"}';}
