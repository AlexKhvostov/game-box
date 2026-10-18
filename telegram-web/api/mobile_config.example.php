<?php
// Configure mobile_config.php privately on the host; never ship a real key in an APK/release.
return [
    'google_web_client_id' => '',
    'play_service_account_path' => '', // Absolute path outside the public website.
    'play_package' => 'com.best4u.untouch',
    'play_token_key' => '', // Base64 of 32 random bytes, independent of service account key.
    // Temporary free Energy V2 grants: explicitly disable before production.
    // Also requires mobile-closed-test.enabled=on and real Play billing absent.
    // This switch does not enable the legacy beta crystal grant.
    'play_products' => [
        'pack_s' => ['kind'=>'crystals','amount'=>30],
        'pack_m' => ['kind'=>'crystals','amount'=>80],
        'pack_l' => ['kind'=>'crystals','amount'=>200],
        'pack_xl' => ['kind'=>'crystals','amount'=>500],
        'plus_weekly' => ['kind'=>'subscription'],
    ],
    // Energy V2 built-in immutable products: energy_100_v1/250/500/1000,
    // energy_batteries_2_v1 and energy_batteries_5_v1 (base plan: weekly).
    // Prepare a NEW SKU revision in Play before publishing it to Android's
    // public catalog. Never redefine terms of an already offered SKU here.
    'energy_products' => [
        // 'energy_100_v2'=>['kind'=>'energy','amount'=>100,'revision'=>'v2'],
        // 'energy_batteries_5_v2'=>['kind'=>'energy_subscription','batteryCount'=>5,
        //   'basePlanId'=>'weekly','batteryCapacity'=>20,'chargeHours'=>12,'revision'=>'v2'],
    ],
    'play_rtdn_audience' => '', // Exact HTTPS push endpoint configured in Pub/Sub.
    'play_rtdn_service_email' => '', // Dedicated Pub/Sub push identity (not Play publisher).
    'play_rtdn_subscription' => '', // projects/<project>/subscriptions/<subscription>.
];
