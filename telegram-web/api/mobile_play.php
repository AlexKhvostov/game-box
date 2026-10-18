<?php
require_once __DIR__ . '/mobile_energy.php';
function mobile_play_http($url,$method='GET',$data=null,$accessToken=null) {
    $curl=curl_init($url); $headers=['Accept: application/json'];
    if ($accessToken) $headers[]='Authorization: Bearer ' . $accessToken;
    if ($data!==null) $headers[]='Content-Type: application/json';
    curl_setopt_array($curl,[CURLOPT_CUSTOMREQUEST=>$method,CURLOPT_HTTPHEADER=>$headers,CURLOPT_RETURNTRANSFER=>true,CURLOPT_CONNECTTIMEOUT=>3,CURLOPT_TIMEOUT=>12]);
    if ($data!==null) curl_setopt($curl,CURLOPT_POSTFIELDS,json_encode($data));
    $body=curl_exec($curl); $status=curl_getinfo($curl,CURLINFO_HTTP_CODE); curl_close($curl);
    if ($status===410) throw new MobileError('play_purchase_gone',410);
    if ($status<200 || $status>=300) throw new MobileError('play_verification_unavailable',503);
    $decoded=json_decode($body?:'{}',true);
    if (!is_array($decoded)) throw new MobileError('play_verification_unavailable',503);
    return $decoded;
}
function mobile_play_context() {
    $config=mobile_private_config();
    $path=realpath($config['play_service_account_path']??'');
    $public=realpath(!empty($_SERVER['DOCUMENT_ROOT'])?$_SERVER['DOCUMENT_ROOT']:dirname(__DIR__));
    if (!$path || !$public || $path===$public || strpos($path,$public . DIRECTORY_SEPARATOR)===0) throw new MobileError('play_not_configured',503);
    $service=json_decode(@file_get_contents($path)?:'',true);
    if (empty($service['private_key']) || empty($service['client_email'])) throw new MobileError('play_not_configured',503);
    $package=$config['play_package']??'';
    if (!is_string($package) || !preg_match('/^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/D',$package)) throw new MobileError('play_not_configured',503);
    // Independent key survives service account rotation. Keep it outside Git.
    $key=base64_decode($config['play_token_key']??'',true);
    if ($key===false || strlen($key)!==32) throw new MobileError('play_storage_not_configured',503);
    return [$config,$service,$key,'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' . rawurlencode($package) . '/purchases/'];
}
function mobile_play_product_v2($data,$owner,$sku) {
    if (!hash_equals(hash('sha256',$owner),(string)($data['obfuscatedExternalAccountId']??''))) throw new MobileError('purchase_owner_invalid',403);
    $state=$data['purchaseStateContext']['purchaseState']??'';
    if (!in_array($state,['PURCHASED','CANCELLED'],true)) throw new MobileError('purchase_not_completed',409);
    $lines=$data['productLineItem']??[];
    if (count($lines)!==1 || ($lines[0]['productId']??'')!==$sku) throw new MobileError('purchase_product_invalid');
    $offer=$lines[0]['productOfferDetails']??[];
    $quantity=$offer['quantity']??1; $remaining=$offer['refundableQuantity']??null;
    if (!is_int($quantity) || $quantity<1 || $quantity>1000 || !is_int($remaining) || $remaining<0 || $remaining>$quantity) throw new MobileError('purchase_quantity_invalid');
    return [$quantity,$state==='CANCELLED'?$quantity:$quantity-$remaining,$offer['consumptionState']??''];
}
function mobile_play_access($service) {
    $now=time();
    $assertion=Firebase\JWT\JWT::encode(['iss'=>$service['client_email'],'scope'=>'https://www.googleapis.com/auth/androidpublisher',
      'aud'=>'https://oauth2.googleapis.com/token','iat'=>$now,'exp'=>$now+3600],$service['private_key'],'RS256');
    $curl=curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($curl,[CURLOPT_POST=>true,CURLOPT_RETURNTRANSFER=>true,CURLOPT_CONNECTTIMEOUT=>3,CURLOPT_TIMEOUT=>12,
      CURLOPT_POSTFIELDS=>http_build_query(['grant_type'=>'urn:ietf:params:oauth:grant-type:jwt-bearer','assertion'=>$assertion])]);
    $body=curl_exec($curl); $status=curl_getinfo($curl,CURLINFO_HTTP_CODE); curl_close($curl); $data=json_decode($body?:'',true);
    if ($status!==200 || empty($data['access_token'])) throw new MobileError('play_not_configured',503);
    return $data['access_token'];
}
function mobile_play_product($data,$owner) {
    if (($data['purchaseState']??-1)!==0) throw new MobileError('purchase_not_completed',409);
    if (!isset($data['obfuscatedExternalAccountId']) || !hash_equals(hash('sha256',$owner),$data['obfuscatedExternalAccountId'])) throw new MobileError('purchase_owner_invalid',403);
    $quantity=(int)($data['quantity']??1);
    if ($quantity<1 || $quantity>1000) throw new MobileError('purchase_quantity_invalid');
    return $quantity;
}
function mobile_play_subscription($data,$owner,$sku,$now) {
    $external=$data['externalAccountIdentifiers']['obfuscatedExternalAccountId']??'';
    if (!is_string($external) || !hash_equals(hash('sha256',$owner),$external)) throw new MobileError('purchase_owner_invalid',403);
    $expiry=0; foreach (($data['lineItems']??[]) as $line) if (($line['productId']??'')===$sku) $expiry=max($expiry,(int)(strtotime($line['expiryTime']??'')?:0)*1000);
    if (!$expiry) throw new MobileError('subscription_product_invalid');
    if (!in_array($data['subscriptionState']??'',['SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED'],true)) return 0;
    return $expiry>$now?$expiry:0;
}
function mobile_play_energy_context(PDO $pdo,$player,$token,$data,$prefix='') {
    $table=mobile_table('mobile_purchases',$prefix);$q=$pdo->prepare("SELECT * FROM $table WHERE token_hash=?");$q->execute([hash('sha256',$token)]);$stored=$q->fetch();
    if($stored&&(int)$stored['player_id']!==(int)$player['id'])throw new MobileError('purchase_owner_invalid',403);
    $context=['storedProductId'=>$stored['product_id']??null,'storedMetadata'=>$stored?(json_decode($stored['token_sealed'],true)?:[]):[]];
    $linked=$data['linkedPurchaseToken']??null;
    if(is_string($linked)&&$linked!=='') {
      if(hash_equals(hash('sha256',$token),hash('sha256',$linked)))throw new MobileError('subscription_product_invalid');
      $q->execute([hash('sha256',$linked)]);$old=$q->fetch();
      if($old){if((int)$old['player_id']!==(int)$player['id'])throw new MobileError('purchase_owner_invalid',403);
        if($old['kind']!=='energy_subscription')throw new MobileError('subscription_product_invalid');
        $context['linkedProductId']=$old['product_id'];$context['linkedMetadata']=json_decode($old['token_sealed'],true)?:[];}
    }
    return $context;
}
function mobile_play_subscription_time($value,$required=false) {
    if($value===null||$value===''){if($required)throw new MobileError('subscription_period_invalid');return 0;}
    if(!is_string($value)||($seconds=strtotime($value))===false||$seconds<=0)throw new MobileError('subscription_period_invalid');
    return (int)$seconds*1000;
}
function mobile_play_energy_subscription($data,$owner,$sku,$product,$now,$context=[]) {
    $external=$data['externalAccountIdentifiers']['obfuscatedExternalAccountId']??'';
    if(!is_string($external)||!hash_equals(hash('sha256',$owner),$external))throw new MobileError('purchase_owner_invalid',403);
    $all=$data['lineItems']??[];
    if(!is_array($all)||count($all)<1||count($all)>2)throw new MobileError('subscription_product_invalid');
    $lines=[];$products=[];$ends=[];
    foreach($all as $line){
      $id=$line['productId']??null;$terms=is_string($id)?mobile_energy_product($id):null;
      if(!$terms||$terms['kind']!=='energy_subscription'||isset($lines[$id]))throw new MobileError('subscription_product_invalid');
      if(($line['offerDetails']['basePlanId']??'')!==$terms['basePlanId'])throw new MobileError('subscription_plan_invalid');
      $lines[$id]=$line;$products[$id]=$terms;$ends[$id]=mobile_play_subscription_time($line['expiryTime']??null);
    }
    $metadata=$context['storedMetadata']??[];$previous=$metadata['energyDeferredChain']??($metadata['energyEntitlement']['deferredChain']??null);
    $linked=is_string($data['linkedPurchaseToken']??null)&&$data['linkedPurchaseToken']!==''?hash('sha256',$data['linkedPurchaseToken']):null;
    $from=null;$target=null;$cutover=0;$phase=null;
    if(count($lines)===2){
      if(!$linked)throw new MobileError('subscription_product_invalid');
      foreach($lines as $id=>$line)if(isset($line['deferredItemReplacement'])){
        if($from!==null)throw new MobileError('subscription_product_invalid');
        $from=$id;$target=$line['deferredItemReplacement']['productId']??null;
      }
      if($from!==null){
        if(!is_string($target)||$target===$from||!isset($lines[$target])||!$ends[$from]||$ends[$target]!==0)throw new MobileError('subscription_product_invalid');
        $cutover=$ends[$from];$phase='pending';
      }else{
        $ids=array_keys($lines);usort($ids,function($a,$b)use($ends){return$ends[$a]<=>$ends[$b];});[$from,$target]=$ids;
        if(!$ends[$from]||$ends[$target]<=$ends[$from]||$ends[$from]>$now)throw new MobileError('subscription_product_invalid');
        $replacement=$lines[$target]['itemReplacement']??[];
        $explicit=($replacement['productId']??'')===$from&&($replacement['replacementMode']??'')==='DEFERRED'&&($replacement['basePlanId']??'weekly')==='weekly';
        $persisted=is_array($previous)&&($previous['fromProductId']??'')===$from&&($previous['targetProductId']??'')===$target&&($previous['linkedTokenHash']??null)===$linked;
        $oldLedger=($context['linkedProductId']??null)===$from;
        if(!$explicit&&!$persisted&&!$oldLedger)throw new MobileError('subscription_product_invalid');
        $cutover=$ends[$from];$phase='active';
      }
      // This app sells one subscription, never a bundle of unrelated items.
      if($products[$from]['batteryCount']!==5||$products[$target]['batteryCount']!==2)throw new MobileError('subscription_product_invalid');
      if(!in_array($sku,[$from,$target],true))throw new MobileError('subscription_product_invalid');
      if(isset($context['linkedProductId'])&&$context['linkedProductId']!==$from)throw new MobileError('subscription_product_invalid');
    }else{
      $target=array_key_first($lines);
      if(isset($lines[$target]['deferredItemReplacement'])&&!isset($data['canceledStateContext']['replacementCancellation']))throw new MobileError('subscription_product_invalid');
      if($sku!==$target){
        $proved=is_array($previous)&&($previous['fromProductId']??'')===$sku&&($previous['targetProductId']??'')===$target;
        $replacement=$lines[$target]['itemReplacement']??[];
        $proved=$proved||($linked&&($context['linkedProductId']??null)===$sku&&($replacement['replacementMode']??'DEFERRED')==='DEFERRED');
        if(!$proved)throw new MobileError('subscription_product_invalid');
      }
      if(is_array($previous)&&($previous['targetProductId']??'')===$target){$from=$previous['fromProductId'];$cutover=(int)$previous['cutoverAt'];$phase='active';}
    }
    $ledgerTerms=$products[$target];
    if(($context['storedProductId']??null)===$target&&isset($metadata['energyProductTerms']))$ledgerTerms=$metadata['energyProductTerms'];
    $effective=$phase==='pending'?$from:$target;$terms=$ledgerTerms;
    $promised=$metadata['energyPromisedTerms']??$ledgerTerms;
    if($effective!==$target){
      $terms=$previous['fromTerms']??null;
      if(!$terms&&($context['linkedProductId']??null)===$from)$terms=$context['linkedMetadata']['energyProductTerms']??null;
      $terms=$terms??$products[$from];
      $promised=$previous['fromPromisedTerms']??($context['linkedMetadata']['energyPromisedTerms']??$terms);
    }
    $expiry=$ends[$effective];$started=mobile_play_subscription_time($data['startTime']??null,true);
    if(!$expiry||!$started)throw new MobileError('subscription_period_invalid');
    $state=$data['subscriptionState']??'';
    if($state==='SUBSCRIPTION_STATE_PENDING')throw new MobileError('purchase_not_completed',409);
    $valid=in_array($state,['SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED'],true);
    $result=['expiresAt'=>$valid?$expiry:min($expiry,$now),'startedAt'=>$started,
      'periodId'=>(string)($lines[$effective]['latestSuccessfulOrderId']??$data['latestOrderId']??($effective.':'.$expiry)),
      'linkedTokenHash'=>$linked,'basePlanId'=>'weekly','state'=>$state,'endConfirmed'=>!$valid||($state==='SUBSCRIPTION_STATE_CANCELED'&&$expiry<=$now),
      'ledgerProductId'=>$target,'ledgerTerms'=>$ledgerTerms,'effectiveProductId'=>$effective,'effectiveTerms'=>$terms,'effectivePromisedTerms'=>$promised,'ackProductId'=>$effective];
    if($phase!==null){
      $fromTerms=$previous['fromTerms']??($context['linkedMetadata']['energyProductTerms']??($products[$from]??mobile_energy_product($from)));
      $fromPromised=$previous['fromPromisedTerms']??($context['linkedMetadata']['energyPromisedTerms']??$fromTerms);
      $result['deferredChain']=['fromProductId'=>$from,'targetProductId'=>$target,'cutoverAt'=>$cutover,'phase'=>$phase,'linkedTokenHash'=>$linked??($previous['linkedTokenHash']??null),'fromTerms'=>$fromTerms,'fromPromisedTerms'=>$fromPromised];
      if($phase==='active')$result['transitionAt']=$cutover;
    }
    // Google can expire the replaced token before delivering its new token.
    // Retain the last verified paid boundary/cycles, frozen after that boundary,
    // until the owner presents the linked replacement. Never invent a new end.
    $oldEntitlement=$metadata['energyEntitlement']??null;
    if(count($lines)===1&&isset($data['canceledStateContext']['replacementCancellation'])&&
      ($context['storedProductId']??null)===$target&&is_array($oldEntitlement)&&empty($oldEntitlement['endConfirmed'])&&!empty($oldEntitlement['expiresAt'])){
      $result['expiresAt']=(int)$oldEntitlement['expiresAt'];$result['periodId']=$oldEntitlement['periodId'];
      $result['endConfirmed']=false;$result['replacementAwaitingToken']=true;
    }
    return $result;
}
function mobile_play_seal($token,$key) {
    $iv=random_bytes(12); $tag=''; $cipher=openssl_encrypt($token,'aes-256-gcm',$key,OPENSSL_RAW_DATA,$iv,$tag);
    if ($cipher===false) throw new MobileError('play_storage_unavailable',503);
    return json_encode(['iv'=>base64_encode($iv),'tag'=>base64_encode($tag),'data'=>base64_encode($cipher)]);
}
function mobile_play_unseal($sealed,$key) {
    $data=json_decode($sealed,true);
    if (!is_array($data)) throw new MobileError('play_storage_unavailable',503);
    $token=openssl_decrypt(base64_decode($data['data'],true),'aes-256-gcm',$key,OPENSSL_RAW_DATA,
      base64_decode($data['iv'],true),base64_decode($data['tag'],true));
    if ($token===false) throw new MobileError('play_storage_unavailable',503);
    return $token;
}
function mobile_play_subscription_ack_url($base,$sku,$token,$entitlement=null) {
    return $base.'subscriptions/'.rawurlencode($entitlement['ackProductId']??$sku).'/tokens/'.rawurlencode($token).':acknowledge';
}
// Refresh stored subscriptions at startup/restore, including cancellations and holds.
function mobile_play_sync(PDO $pdo,$player,$now) {
    $query=$pdo->prepare("SELECT product_id,token_sealed FROM mobile_purchases WHERE player_id=? AND kind IN ('subscription','energy_subscription')");
    $query->execute([$player['id']]); $rows=$query->fetchAll();
    if (!$rows) return mobile_profile($player);
    [$config,$service,$key]=mobile_play_context();
    foreach ($rows as $row) {
      if (!empty((json_decode($row['token_sealed'],true)?:[])['apiRetired'])) continue;
      $token=mobile_play_unseal($row['token_sealed'],$key);
      $profile=mobile_play_verify($pdo,$player,$row['product_id'],$token,$now);
    }
    return $profile??mobile_profile($player);
}
function mobile_play_apply(PDO $pdo,$player,$token,$sku,$product,$quantity,$expiry,$sealed,$now,$prefix='',$refunded=0,$entitlement=null) {
    $players=mobile_table('mobile_players',$prefix); $purchases=mobile_table('mobile_purchases',$prefix); $hash=hash('sha256',$token);
    $pdo->beginTransaction();
    try {
      $query=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE"); $query->execute([$player['id']]); $current=$query->fetch();
      if (!$current) throw new MobileError('unauthorized',401);
      $query=$pdo->prepare("SELECT * FROM $purchases WHERE token_hash=? FOR UPDATE"); $query->execute([$hash]); $existing=$query->fetch();
      if ($existing && ((int)$existing['player_id']!==(int)$player['id'] || $existing['product_id']!==$sku)) throw new MobileError('purchase_owner_invalid',403);
      $kind=$product['kind']; $wallet=mobile_wallet($current,tg_load_economy());
      // Store immutable grant terms and cumulative refund count alongside the
      // encrypted token. No schema change; old ledgers require explicit migration.
      $metadata=json_decode($existing?$existing['token_sealed']:$sealed,true)?:[];
      if($existing&&isset($metadata['energyProductTerms'])&&in_array($kind,['energy','energy_subscription'],true))$product=$metadata['energyProductTerms'];
      $promisedTerms=$existing?($metadata['energyPromisedTerms']??$product):mobile_energy_effective_terms($product,mobile_energy_config(null,$now),$now);
      $purchasePolicy=$metadata['energyPurchaseChargePolicy']??(!$existing?mobile_energy_charge_policy(mobile_energy_config(null,$now),$now):null);
      $previousEntitlement=$metadata['energyEntitlement']??null;
      $previousChain=$metadata['energyDeferredChain']??($previousEntitlement['deferredChain']??null);
      if($existing&&$kind==='energy_subscription'&&($previousChain['phase']??null)==='active'&&
        ($entitlement['deferredChain']['phase']??null)==='pending'){$pdo->commit();return mobile_profile($current);}
      if($existing&&$kind==='energy_subscription'&&$entitlement&&$previousEntitlement&&
        $entitlement['periodId']!==$previousEntitlement['periodId']&&(int)$entitlement['expiresAt']<(int)$previousEntitlement['expiresAt']) {
        $pdo->commit();return mobile_profile($current);
      }
      if ($existing && in_array($kind,['crystals','energy'],true) && !isset($metadata['grantAmount'])) throw new MobileError('play_ledger_migration_required',503);
      $amount=$existing?(int)($metadata['grantAmount']??0):max(0,(int)($product['amount']??0));
      $units=$existing?(int)($metadata['grantQuantity']??$quantity):$quantity;
      if ($quantity!==$units || $refunded<0 || $refunded>$units) throw new MobileError('purchase_quantity_invalid');
      $priorRefund=(int)($metadata['refundedQuantity']??0);
      $refunded=max($priorRefund,$refunded);
      $metadata=json_decode($sealed,true)?:[];
      $metadata['grantAmount']=$amount; $metadata['grantQuantity']=$units; $metadata['refundedQuantity']=$refunded;
      if(in_array($kind,['energy','energy_subscription'],true))$metadata['energyProductTerms']=$product;
      if($kind==='energy_subscription'){$metadata['energyPromisedTerms']=$promisedTerms;if($purchasePolicy)$metadata['energyPurchaseChargePolicy']=$purchasePolicy;}
      if($entitlement)$metadata['energyEntitlement']=$entitlement;
      if(isset($entitlement['deferredChain']))$metadata['energyDeferredChain']=$entitlement['deferredChain'];
      elseif($previousChain)$metadata['energyDeferredChain']=$previousChain;
      $sealed=json_encode($metadata);
      if (!$existing) {
        $pdo->prepare("INSERT INTO $purchases (token_hash,player_id,product_id,kind,token_sealed,expires_at,created_at) VALUES (?,?,?,?,?,?,?)")->execute([$hash,$player['id'],$sku,$kind,$sealed,$expiry,$now]);
        if ($kind==='crystals') {if(mobile_energy_is_v2($wallet))$wallet['energy']+=2*$amount*($units-$refunded);else $wallet['tokens']+=$amount*($units-$refunded);}
        elseif($kind==='energy') {if(!mobile_energy_is_v2($wallet))throw new MobileError('update_required',409);$wallet['energy']+=$amount*($units-$refunded);}
      } elseif (in_array($kind,['subscription','energy_subscription'],true)) {
        $pdo->prepare("UPDATE $purchases SET expires_at=?,token_sealed=? WHERE token_hash=?")->execute([$expiry,$sealed,$hash]);
      }
      if ($existing && in_array($kind,['crystals','energy'],true) && $refunded>$priorRefund) {
        // A refund never creates negative currency or a cash debt for a child.
        $field=mobile_energy_is_v2($wallet)?'energy':'tokens';$factor=$kind==='crystals'&&$field==='energy'?2:1;
        $wallet[$field]=max(0,$wallet[$field]-$factor*$amount*($refunded-$priorRefund));
        $pdo->prepare("UPDATE $purchases SET token_sealed=? WHERE token_hash=?")->execute([$sealed,$hash]);
      }
      if ($kind==='subscription') {
        $query=$pdo->prepare("SELECT MAX(expires_at) FROM $purchases WHERE player_id=? AND kind='subscription'"); $query->execute([$player['id']]); $wallet['plusUntil']=(int)$query->fetchColumn();
      }
      if($kind==='energy_subscription') {
        if(!mobile_energy_is_v2($wallet)||!is_array($entitlement))throw new MobileError('subscription_period_invalid');
        $energyConfig=mobile_energy_config(null,$now);mobile_energy_expire($wallet,$now,$energyConfig);
        $active=$wallet['energySubscription']??null;
        $isCurrent=$active&&hash_equals($active['tokenHash'],$hash);
        $canReplace=$active&&isset($entitlement['linkedTokenHash'])&&hash_equals($active['tokenHash'],$entitlement['linkedTokenHash']);
        // An old token/old RTDN cannot restore or disable its replacement.
        $retired=in_array($hash,$wallet['energyRetiredTokens']??[],true);
        if(!$retired&&(!$active||$isCurrent||$canReplace)) {
          if($isCurrent&&(int)$entitlement['expiresAt']<(int)$active['expiresAt']&&$entitlement['periodId']!==$active['periodId']) {
            // Stale renewal response: do not shorten a newer validated period.
          } elseif($expiry>$now||(($entitlement['deferredChain']['phase']??null)==='pending'&&empty($entitlement['endConfirmed']))||!empty($entitlement['replacementAwaitingToken'])) {
            if($canReplace){$wallet['energyRetiredTokens'][]=$active['tokenHash'];}
            if(!empty($entitlement['linkedTokenHash'])&&!hash_equals($hash,$entitlement['linkedTokenHash']))$wallet['energyRetiredTokens'][]=$entitlement['linkedTokenHash'];
            if(isset($wallet['energyRetiredTokens']))$wallet['energyRetiredTokens']=array_values(array_unique($wallet['energyRetiredTokens']));
            $originalEffective=$entitlement['effectiveTerms']??$product;
            $effective=mobile_energy_effective_terms($originalEffective,$energyConfig,$now);$effectiveSku=$entitlement['effectiveProductId']??$sku;
            $effectivePromise=$entitlement['effectivePromisedTerms']??$promisedTerms;
            $effective['chargeHours']=min((float)$effective['chargeHours'],(float)$effectivePromise['chargeHours']);
            $terms=$energyConfig;$terms['batteryCapacity']=$effective['batteryCapacity'];$terms['chargeHours']=$effective['chargeHours'];$terms['revision']=$effective['revision'];
            if($active&&(int)$active['expiresAt']<=$now&&(int)$entitlement['startedAt']>(int)$active['expiresAt']) {
              // A validated later start proves a real gap. Do not produce
              // energy through an unpaid interval as if it were a renewal.
              mobile_energy_transition($wallet,1,$active['expiresAt'],$active['periodId'],$energyConfig,$now);
            }
            $transitionAt=isset($entitlement['transitionAt'])?(int)$entitlement['transitionAt']:$now;
            mobile_energy_transition($wallet,$effective['batteryCount'],$transitionAt,$entitlement['periodId'],$terms,$now);
            $wallet['energySubscription']=['tokenHash'=>$hash,'productId'=>$effectiveSku,'batteryCount'=>(int)$effective['batteryCount'],
              'expiresAt'=>(int)$expiry,'startedAt'=>(int)$entitlement['startedAt'],'periodId'=>$entitlement['periodId'],
              'capacity'=>$terms['batteryCapacity'],'durationMs'=>(int)round($terms['chargeHours']*3600000),'revision'=>$product['revision'],
              'originalDurationMs'=>(int)round($originalEffective['chargeHours']*3600000),
              'promisedDurationMs'=>(int)round($effectivePromise['chargeHours']*3600000),
              'state'=>$entitlement['state']??'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
            if(isset($entitlement['deferredChain'])){
              $wallet['energySubscription']['ledgerProductId']=$sku;
              $wallet['energySubscription']['deferredChain']=$entitlement['deferredChain'];
            }
            if(!empty($entitlement['replacementAwaitingToken']))$wallet['energySubscription']['replacementAwaitingToken']=true;
          } elseif($isCurrent&&($entitlement['endConfirmed']??true)) {
            mobile_energy_transition($wallet,1,$entitlement['expiresAt'],$entitlement['periodId'],$energyConfig,$now);
            $wallet['energySubscription']=null;
          }
        } elseif(!$retired&&!$existing&&$active)throw new MobileError('subscription_conflict',409);
      }
      if (!$existing || in_array($kind,['subscription','energy_subscription'],true) || $refunded>$priorRefund) { mobile_wallet_write($pdo,$player['id'],$wallet,$prefix); $current['wallet_json']=json_encode($wallet); $current['wallet_version']++; }
      $pdo->commit(); return mobile_profile($current);
    } catch(Throwable $error) { if ($pdo->inTransaction()) $pdo->rollBack(); throw $error; }
}
function mobile_play_verify(PDO $pdo,$player,$sku,$token,$now) {
    [$config,$service,$key,$base]=mobile_play_context(); $product=mobile_energy_product($sku)??($config['play_products'][$sku]??null);
    if (!$product || !in_array($product['kind']??'',['crystals','subscription','energy','energy_subscription'],true)) throw new MobileError('play_product_unavailable',503);
    if (!is_string($token) || strlen($token)<10 || strlen($token)>4096) throw new MobileError('purchase_token_invalid');
    $lock='play:' . substr(hash('sha256',$token),0,59);
    $query=$pdo->prepare('SELECT GET_LOCK(?,1)'); $query->execute([$lock]);
    if ((int)$query->fetchColumn()!==1) throw new MobileError('play_verification_busy',503);
    try {
    $access=mobile_play_access($service);
    $owner='android:' . $player['id']; $quantity=1; $expiry=0; $refunded=0; $retired=false;$entitlement=null;
    if (in_array($product['kind'],['crystals','energy'],true)) {
      $url=$base . 'products/' . rawurlencode($sku) . '/tokens/' . rawurlencode($token);
      $data=mobile_play_http($base . 'productsv2/tokens/' . rawurlencode($token),'GET',null,$access);
      [$quantity,$refunded,$consumption]=mobile_play_product_v2($data,$owner,$sku);
    } else {
      try {
        $data=mobile_play_http($base . 'subscriptionsv2/tokens/' . rawurlencode($token),'GET',null,$access);
        if($product['kind']==='energy_subscription'){
          $context=mobile_play_energy_context($pdo,$player,$token,$data);
          $entitlement=mobile_play_energy_subscription($data,$owner,$sku,$product,$now,$context);$expiry=$entitlement['expiresAt'];
          $sku=$entitlement['ledgerProductId'];$product=$entitlement['ledgerTerms'];
        }
        else $expiry=mobile_play_subscription($data,$owner,$sku,$now);
      } catch (MobileError $error) {
        if ($error->getMessage()!=='play_purchase_gone') throw $error;
        // Google stops returning old expired subscriptions. Only retire a token
        // already bound to this player; arbitrary 410 tokens cannot create rows.
        $query=$pdo->prepare('SELECT player_id,product_id,expires_at,token_sealed FROM mobile_purchases WHERE token_hash=?'); $query->execute([hash('sha256',$token)]); $old=$query->fetch();
        if (!$old || (int)$old['player_id']!==(int)$player['id'] || $old['product_id']!==$sku) throw new MobileError('purchase_owner_invalid',403);
        $data=[]; $retired=true;
        if($product['kind']==='energy_subscription') {
          $stored=json_decode($old['token_sealed'],true)?:[];$oldEntitlement=$stored['energyEntitlement']??[];
          $expiry=min($now,(int)$old['expires_at']);
          $entitlement=['expiresAt'=>$expiry,'startedAt'=>(int)($oldEntitlement['startedAt']??0),
            'periodId'=>$oldEntitlement['periodId']??('retired:'.hash('sha256',$token)),'linkedTokenHash'=>null,'endConfirmed'=>true];
        }
      }
    }
    $sealed=mobile_play_seal($token,$key);
    if ($retired) { $envelope=json_decode($sealed,true); $envelope['apiRetired']=true; $sealed=json_encode($envelope); }
    // Persist the verified entitlement before acknowledging/consuming. If the
    // DB fails, Play must still report the unconsumed purchase on restoration.
    // A failed Google completion is retried; the unique token ledger prevents
    // a retry from crediting the wallet twice.
    $profile=mobile_play_apply($pdo,$player,$token,$sku,$product,$quantity,$expiry,$sealed,$now,'',$refunded,$entitlement);
    if (in_array($product['kind'],['crystals','energy'],true) && $refunded<$quantity && $consumption==='CONSUMPTION_STATE_YET_TO_BE_CONSUMED')
      mobile_play_http($url . ':consume','POST',(object)[],$access);
    elseif (in_array($product['kind'],['subscription','energy_subscription'],true) && $expiry && empty($entitlement['replacementAwaitingToken']) && ($data['acknowledgementState']??'')==='ACKNOWLEDGEMENT_STATE_PENDING')
      mobile_play_http(mobile_play_subscription_ack_url($base,$sku,$token,$entitlement),'POST',(object)[],$access);
    return $profile;
    } finally { $pdo->prepare('SELECT RELEASE_LOCK(?)')->execute([$lock]); }
}
