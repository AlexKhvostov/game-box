<?php
// Local CLI only. Input secrets stay in pipes/memory; no SQL or Google writes.
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
ini_set('display_errors','0');
require_once __DIR__.'/../telegram-web/api/mobile_store.php';
require_once __DIR__.'/../telegram-web/api/mobile_google.php';
require_once __DIR__.'/../telegram-web/api/mobile_play.php';
function ppa_rows($snapshot,$name){
 foreach($snapshot['tables']??[] as $table)if(($table['name']??'')===$name){
  $rows=[];foreach($table['rowsBase64'] as $cells){$row=[];foreach($table['columns'] as $index=>$column)$row[$column]=$cells[$index]===null?null:base64_decode($cells[$index],true);$rows[]=$row;}return [$rows,$table['createSql']];
 }throw new RuntimeException();
}
function ppa_google_fact($row,$metadata,$data,$context=[]){
 $subscription=$row['kind']==='energy_subscription';$owner=hash('sha256','android:'.$row['player_id']);
 $actual=$subscription?($data['externalAccountIdentifiers']['obfuscatedExternalAccountId']??''):($data['obfuscatedExternalAccountId']??'');
 $fact=['ownerMatchesLedger'=>is_string($actual)&&hash_equals($owner,$actual),
  'acknowledgementState'=>$data['acknowledgementState']??null,'googleReadOnlyVerified'=>true];
 if($subscription){
  $lines=array_values(array_filter($data['lineItems']??[],function($line)use($row){return($line['productId']??'')===$row['product_id'];}));
  $fact['googleTestPurchase']=array_key_exists('testPurchase',$data);$fact['subscriptionState']=$data['subscriptionState']??null;
  $fact['productMatchesLedger']=count($lines)===1&&count($data['lineItems']??[])===1;
  $fact['weeklyBasePlanMatches']=count($lines)===1&&($lines[0]['offerDetails']['basePlanId']??'')==='weekly';
  $expiry=count($lines)===1?(int)(strtotime($lines[0]['expiryTime']??'')?:0)*1000:0;
  $fact['googleExpiresAt']=$expiry;$fact['ledgerExpiryMatches']=$expiry===(int)$row['expires_at'];
  $linked=$data['linkedPurchaseToken']??null;$storedLinked=$metadata['energyEntitlement']['linkedTokenHash']??null;
  $fact['googleLinkedPurchasePresent']=is_string($linked)&&$linked!=='';$fact['storedLinkedPurchasePresent']=is_string($storedLinked)&&$storedLinked!=='';
  $fact['linkedPurchaseMatchesStored']=$fact['googleLinkedPurchasePresent']&&$fact['storedLinkedPurchasePresent']?hash_equals($storedLinked,hash('sha256',$linked)):null;
  $period=count($lines)===1?($lines[0]['latestSuccessfulOrderId']??$data['latestOrderId']??null):null;
  $fact['googlePeriodMatchesStored']=is_string($period)&&is_string($metadata['energyEntitlement']['periodId']??null)?hash_equals($metadata['energyEntitlement']['periodId'],$period):null;
  $fact['googleRenewalBeyondLedger']=$expiry>(int)$row['expires_at'];
  $fact['googleLineItems']=array_map(function($line){return ['productId'=>$line['productId']??null,'basePlanId'=>$line['offerDetails']['basePlanId']??null,
    'expiresAt'=>(int)(strtotime($line['expiryTime']??'')?:0)*1000,'deferredTargetProductId'=>$line['deferredItemReplacement']['productId']??null,
    'replacementMode'=>$line['itemReplacement']['replacementMode']??null];},$data['lineItems']??[]);
  $context+=['storedProductId'=>$row['product_id'],'storedMetadata'=>$metadata];
  try{$ent=mobile_play_energy_subscription($data,'android:'.$row['player_id'],$row['product_id'],mobile_energy_product($row['product_id']),(int)round(microtime(true)*1000),$context);
    $fact['normalizationAccepted']=true;$fact['normalizedLedgerProductId']=$ent['ledgerProductId'];$fact['normalizedEffectiveProductId']=$ent['effectiveProductId'];
    $fact['normalizedBatteryCount']=$ent['effectiveTerms']['batteryCount'];$fact['normalizedExpiresAt']=$ent['expiresAt'];
    $fact['normalizedDeferredPhase']=$ent['deferredChain']['phase']??null;$fact['normalizedCutoverAt']=$ent['deferredChain']['cutoverAt']??null;
    $fact['normalizedAckProductId']=$ent['ackProductId'];$fact['normalizedPeriodMatchesStored']=($metadata['energyEntitlement']['periodId']??null)===$ent['periodId'];
  }catch(MobileError$e){$fact['normalizationAccepted']=false;$fact['normalizationError']=$e->getMessage();}
 }else{
  $line=$data['productLineItem'][0]??[];$offer=$line['productOfferDetails']??[];
  $fact['googleTestPurchase']=($data['testPurchaseContext']['fopType']??'')==='TEST';
  $fact['purchaseState']=$data['purchaseStateContext']['purchaseState']??null;
  $fact['productMatchesLedger']=count($data['productLineItem']??[])===1&&($line['productId']??'')===$row['product_id'];
  $fact['quantityMatchesLedger']=(int)($offer['quantity']??0)===(int)($metadata['grantQuantity']??0);
  $fact['consumptionState']=$offer['consumptionState']??null;
 }
 return $fact;
}
if(defined('PPA_HELPERS_ONLY'))return;
try{
 $input=json_decode(stream_get_contents(STDIN),true,512,JSON_THROW_ON_ERROR);$snapshot=$input['snapshot'];
 if(($snapshot['format']??'')!=='android-energy-db-v1')throw new RuntimeException();
 [$purchases,$ddl]=ppa_rows($snapshot,'mobile_purchases');[$players]=ppa_rows($snapshot,'mobile_players');
 $owners=array_column($players,null,'id');$sku=$input['productId']??'';
 if(!is_string($sku)||!preg_match('/^energy_(?:100|250|500|1000|batteries_[25])_v[1-9][0-9]*$/D',$sku))throw new RuntimeException();
 $selected=array_values(array_filter($purchases,function($row)use($sku){return$row['product_id']===$sku&&in_array($row['kind'],['energy','energy_subscription'],true);}));
 $currentOnly=($input['currentSubscriptionOnly']??false)===true;
 if($currentOnly){if(!str_starts_with($sku,'energy_batteries_'))throw new RuntimeException();
  $selected=array_values(array_filter($selected,function($row)use($owners){$w=json_decode($owners[$row['player_id']]['wallet_json']??'{}',true)?:[];return is_string($w['energySubscription']['tokenHash']??null)&&hash_equals($row['token_hash'],$w['energySubscription']['tokenHash']);}));}
 if(count($selected)>25)throw new RuntimeException();
 $google=($input['googleGet']??false)===true;$key=base64_decode($input['tokenKeyBase64']??'',true);
 if($google&&(!is_string($key)||strlen($key)!==32))throw new RuntimeException();
 $access=$google?mobile_play_access($input['serviceAccount']):null;$reports=[];
 foreach($selected as $row){
  $metadata=json_decode($row['token_sealed'],true);if(!is_array($metadata))throw new RuntimeException();
  $units=(int)($metadata['grantQuantity']??0);$amount=(int)($metadata['grantAmount']??0);$refunds=(int)($metadata['refundedQuantity']??0);
  $ownerWallet=json_decode($owners[$row['player_id']]['wallet_json']??'{}',true)?:[];$subscription=$ownerWallet['energySubscription']??null;
  $report=['productId'=>$sku,'kind'=>$row['kind'],'ledgerRowsForToken'=>count(array_filter($purchases,function($r)use($row){return$r['token_hash']===$row['token_hash'];})),
   'ledgerOwnerExists'=>isset($owners[$row['player_id']]),'grantPerUnit'=>$amount,'quantity'=>$units,'refundedQuantity'=>$refunds,
   'recordedNetGrant'=>$amount*max(0,$units-$refunds),'immutableTermsPresent'=>isset($metadata['energyProductTerms']),
   'ledgerExpiresAt'=>(int)$row['expires_at'],'googleChecked'=>false,
   'walletEnergy'=>(int)($ownerWallet['energy']??0),'walletBatteryCount'=>count($ownerWallet['batteries']??[]),
   'walletSubscriptionPresent'=>is_array($subscription),'walletSubscriptionProductId'=>$subscription['productId']??null,
   'walletSubscriptionBatteryCount'=>(int)($subscription['batteryCount']??0),'walletSubscriptionExpiresAt'=>(int)($subscription['expiresAt']??0),
   'walletSubscriptionAwaitingReconciliation'=>!empty($subscription['awaitingReconciliation']),
   'walletSubscriptionTokenMatchesLedger'=>is_array($subscription)&&is_string($subscription['tokenHash']??null)&&hash_equals($row['token_hash'],$subscription['tokenHash']),
   'immutableBatteryCount'=>(int)($metadata['energyProductTerms']['batteryCount']??0),'storedEntitlementState'=>$metadata['energyEntitlement']['state']??null,
   'baseChargeHours'=>$metadata['energyProductTerms']['chargeHours']??null,'promisedChargeHours'=>$metadata['energyPromisedTerms']['chargeHours']??null,
   'walletEffectiveChargeHours'=>isset($subscription['durationMs'])?$subscription['durationMs']/3600000:null,
   'storedDeferredPhase'=>$metadata['energyDeferredChain']['phase']??null,'storedDeferredCutoverAt'=>$metadata['energyDeferredChain']['cutoverAt']??null];
  if($google){
   $token=mobile_play_unseal($row['token_sealed'],$key);$report['tokenHashVerified']=hash_equals($row['token_hash'],hash('sha256',$token));
   if(!$report['tokenHashVerified'])throw new RuntimeException();
   $url='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.best4u.untouch/purchases/'.($row['kind']==='energy_subscription'?'subscriptionsv2':'productsv2').'/tokens/'.rawurlencode($token);
   $data=mobile_play_http($url,'GET',null,$access);$context=[];$linked=$data['linkedPurchaseToken']??null;
   if(is_string($linked)&&$linked!==''){foreach($purchases as$old){if(hash_equals($old['token_hash'],hash('sha256',$linked))){if((int)$old['player_id']!==(int)$row['player_id'])throw new RuntimeException();$context=['linkedProductId'=>$old['product_id'],'linkedMetadata'=>json_decode($old['token_sealed'],true)?:[]];break;}}}
   $report=array_merge($report,ppa_google_fact($row,$metadata,$data,$context));$report['googleChecked']=true;
   unset($token,$data);
  }$reports[]=$report;
 }
 echo json_encode(['ok'=>true,'readOnly'=>true,'capturedAtUtc'=>$snapshot['capturedAtUtc']??null,'productId'=>$sku,'purchaseRows'=>count($reports),
  'tokenPrimaryKeyPresent'=>(bool)preg_match('/PRIMARY KEY\s*\(\s*`token_hash`\s*\)/i',$ddl),
  'idempotencyLimit'=>'Unique token ledger observed; repeated delivery requires separate client replay and before/after observation.',
  'googlePurchaseRequests'=>0,'googleGetRequests'=>$google?count($reports):0,'currentSubscriptionOnly'=>$currentOnly,'reports'=>$reports],JSON_UNESCAPED_SLASHES).PHP_EOL;
}catch(Throwable $error){fwrite(STDERR,"Read-only purchase audit failed; no private details printed.\n");exit(1);}
