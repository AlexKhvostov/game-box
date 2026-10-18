<?php
// Helpers only. Entrypoint authenticates Pub/Sub before parsing any event.
function mobile_play_push_claims($jwt,$config,$keys) {
    $aud=$config['play_rtdn_audience']??''; $email=$config['play_rtdn_service_email']??'';
    if (!$aud || !$email) throw new MobileError('play_rtdn_not_configured',503);
    try {
        $trusted=[]; foreach ($keys as $id=>$cert) $trusted[$id]=new Firebase\JWT\Key($cert,'RS256');
        $claims=Firebase\JWT\JWT::decode($jwt,$trusted);
        if (($claims->aud??null)!==$aud || !in_array($claims->iss??'', ['accounts.google.com','https://accounts.google.com'],true) ||
            ($claims->email??null)!==$email || ($claims->email_verified??false)!==true || !isset($claims->exp)) throw new RuntimeException('claims');
    } catch (Throwable $error) { throw new MobileError('play_notification_unauthorized',401); }
}
function mobile_play_event($body,$config) {
    $envelope=json_decode($body,true);
    if (!is_array($envelope) || empty($config['play_rtdn_subscription']) ||
        ($envelope['subscription']??'')!==$config['play_rtdn_subscription']) throw new MobileError('play_notification_invalid');
    $encoded=$envelope['message']['data']??null;
    $event=is_string($encoded)?json_decode(base64_decode($encoded,true)?:'',true):null;
    if (!is_array($event) || ($event['packageName']??'')!==($config['play_package']??'')) throw new MobileError('play_notification_invalid');
    return $event;
}
function mobile_play_refresh_token(PDO $pdo,$token,$skuHint,$subscription,$now) {
    if (!is_string($token) || strlen($token)<10 || strlen($token)>4096) throw new MobileError('purchase_token_invalid');
    [$config,$service,$key,$base]=mobile_play_context();
    $query=$pdo->prepare('SELECT * FROM mobile_purchases WHERE token_hash=?'); $query->execute([hash('sha256',$token)]); $row=$query->fetch();
    if ($row) {
        $query=$pdo->prepare('SELECT * FROM mobile_players WHERE id=?'); $query->execute([$row['player_id']]);
        $player=$query->fetch(); $sku=$subscription&&$row['kind']==='energy_subscription'&&$skuHint?$skuHint:$row['product_id'];
    } else {
        // RTDN can arrive before the app's purchase stream, including when it is
        // closed. Bind only to the account hash verified by Google's API.
        $access=mobile_play_access($service);
        $data=mobile_play_http($base . ($subscription?'subscriptionsv2':'productsv2') . '/tokens/' . rawurlencode($token),'GET',null,$access);
        $owner=$subscription?($data['externalAccountIdentifiers']['obfuscatedExternalAccountId']??''):($data['obfuscatedExternalAccountId']??'');
        $sku=$subscription?mobile_play_subscription_hint($data):($data['productLineItem'][0]['productId']??'');
        if (!is_string($owner) || !preg_match('/^[a-f0-9]{64}$/D',$owner)) throw new MobileError('purchase_owner_invalid',403);
        $query=$pdo->prepare("SELECT * FROM mobile_players WHERE SHA2(CONCAT('android:',id),256)=?"); $query->execute([$owner]); $player=$query->fetch();
    }
    // Deleted profiles are not recreated from a payment event.
    if (!$player) return;
    if ($skuHint && $skuHint!==$sku) {
        // A subscription hint may still name the old DEFERRED product. The
        // owner-bound normalizer validates the exact Google relationship.
        if(!$subscription||!mobile_energy_product($sku))throw new MobileError('purchase_product_invalid');
        $sku=$skuHint;
    }
    // A verified new Energy SKU is the V2 marker when RTDN precedes the app.
    // The owner above came from Google's account hash, never from a request id.
    if(mobile_energy_product($sku))$player=mobile_energy_prepare($pdo,$player,$now,2);
    mobile_play_verify($pdo,$player,$sku,$token,$now);
}
function mobile_play_subscription_hint($data) {
    $lines=$data['lineItems']??[];
    if(!is_array($lines)||count($lines)<1||count($lines)>2)throw new MobileError('subscription_product_invalid');
    $ids=[];foreach($lines as $line){$id=$line['productId']??null;
      if(!is_string($id)||$id===''||isset($ids[$id]))throw new MobileError('subscription_product_invalid');
      $product=mobile_energy_product($id);
      if(count($lines)>1&&(!$product||$product['kind']!=='energy_subscription'))throw new MobileError('subscription_product_invalid');
      $ids[$id]=true;}
    $keys=array_keys($ids);sort($keys,SORT_STRING);return $keys[0];
}
function mobile_play_notification(PDO $pdo,$event,$now) {
    if (isset($event['testNotification'])) return;
    if (isset($event['subscriptionNotification'])) {
        mobile_play_refresh_token($pdo,$event['subscriptionNotification']['purchaseToken']??null,null,true,$now); return;
    }
    if (isset($event['oneTimeProductNotification'])) {
        $purchase=$event['oneTimeProductNotification'];
        // Canceled pending payments never granted an entitlement.
        if (($purchase['notificationType']??0)===2) return;
        mobile_play_refresh_token($pdo,$purchase['purchaseToken']??null,$purchase['sku']??null,false,$now); return;
    }
    if (isset($event['voidedPurchaseNotification'])) {
        $purchase=$event['voidedPurchaseNotification'];
        // Fetch current state, including refundableQuantity. Never subtract a
        // notification's quantity: duplicates and out-of-order delivery are normal.
        mobile_play_refresh_token($pdo,$purchase['purchaseToken']??null,null,($purchase['productType']??0)===1,$now); return;
    }
    // Unknown/new notification types need operator review, not silent success.
    throw new MobileError('play_notification_unsupported',503);
}

// Call from a private scheduler every 15 minutes for entitlement boundaries;
// overlapping 30-day refund windows are
// safe because each purchase stores a monotonic cumulative refunded quantity.
function mobile_play_reconcile(PDO $pdo,$now) {
    [$config,$service,$key,$base]=mobile_play_context(); $access=mobile_play_access($service); $next=null; $count=0;
    do {
        $params=['type'=>1,'includeQuantityBasedPartialRefund'=>'true','pageSelection.maxResults'=>1000];
        if ($next) $params['pageSelection.token']=$next;
        $result=mobile_play_http($base . 'voidedpurchases?' . http_build_query($params),'GET',null,$access);
        foreach ($result['voidedPurchases']??[] as $voided) {
            $query=$pdo->prepare('SELECT kind FROM mobile_purchases WHERE token_hash=?'); $query->execute([hash('sha256',$voided['purchaseToken'])]); $kind=$query->fetchColumn();
        if ($kind) { mobile_play_refresh_token($pdo,$voided['purchaseToken'],null,in_array($kind,['subscription','energy_subscription'],true),$now); $count++; }
        }
        $next=$result['tokenPagination']['nextPageToken']??null;
    } while ($next);
    $rows=$pdo->query("SELECT player_id,product_id,token_sealed FROM mobile_purchases WHERE kind IN ('subscription','energy_subscription')")->fetchAll();
    foreach ($rows as $row) {
        if (!empty((json_decode($row['token_sealed'],true)?:[])['apiRetired'])) continue;
        mobile_play_refresh_token($pdo,mobile_play_unseal($row['token_sealed'],$key),$row['product_id'],true,$now); $count++;
    }
    return $count;
}
