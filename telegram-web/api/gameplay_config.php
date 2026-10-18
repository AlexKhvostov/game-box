<?php
require_once __DIR__.'/mobile_energy.php';
// Shared configuration for the Mini App, payment catalogue, and admin editor.
// Runtime publications are deliberately separate from deployed defaults.
function gameplay_defaults() {
    $raw = @file_get_contents(dirname(__DIR__) . '/config/gameplay-config.json');
    $config = json_decode((string)$raw, true);
    if (!is_array($config) || empty($config['economy'])) throw new RuntimeException('Базовая конфигурация недоступна');
    if(!isset($config['economy']['androidEnergyV2']))$config['economy']['androidEnergyV2']=mobile_energy_defaults();
    return $config;
}

function gameplay_store_dir() {
    return __DIR__ . '/config-data';
}

function gameplay_snapshot_base() {
    $file = gameplay_store_dir() . '/published.json';
    if (is_file($file)) {
        $snapshot = json_decode((string)@file_get_contents($file), true);
        if (!is_array($snapshot) || !isset($snapshot['config'], $snapshot['revision'])) {
            throw new RuntimeException('Опубликованная конфигурация повреждена');
        }
        // Add the new energy block to older publications without replacing
        // previously edited settings or merging numeric catalogue arrays.
        $defaults = gameplay_defaults()['economy'];
        if(!isset($snapshot['config']['economy']['androidEnergyV2']))$snapshot['config']['economy']['androidEnergyV2']=$defaults['androidEnergyV2']??mobile_energy_defaults();
        foreach (['interstitialSessionGraceSec', 'interstitialSessionFreeRounds'] as $key) {
            if (!array_key_exists($key, $snapshot['config']['economy'])) $snapshot['config']['economy'][$key] = $defaults[$key];
        }
        $energy = $defaults['energy'] ?? [];
        if (!$energy) {
            // Rollback to the original lives/crystals client. Keep the saved
            // publication and server energy history intact, but disable the
            // later energy model in the effective configuration.
            unset($snapshot['config']['economy']['energy']);
            return $snapshot;
        }
        $snapshot['config']['economy']['energy'] = array_replace($energy, $snapshot['config']['economy']['energy'] ?? []);
        foreach ($snapshot['config']['economy']['starsShop']['packs'] as &$pack) {
            if (!isset($pack['energy'])) $pack['energy'] = (int)$pack['crystals'] * (int)$snapshot['config']['economy']['energy']['legacyCrystalEnergy'];
        }
        unset($pack);
        return $snapshot;
    }
    $config = gameplay_defaults();
    return [
        'config' => $config,
        'revision' => hash('sha256', json_encode($config, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)),
        'updatedAt' => null,
        'source' => 'defaults',
    ];
}

function gameplay_schema() {
    $schema = json_decode((string)@file_get_contents(dirname(__DIR__) . '/admin/config-schema.json'), true);
    if (!is_array($schema) || empty($schema['groups'])) throw new RuntimeException('Схема редактора недоступна');
    return $schema;
}

function gameplay_value_at($config, $path, &$found) {
    $value = $config;
    foreach (explode('.', $path) as $part) {
        if (!is_array($value) || !array_key_exists($part, $value)) {
            $found = false;
            return null;
        }
        $value = $value[$part];
    }
    $found = true;
    return $value;
}

function gameplay_validate_value($value, $rule, $path, &$errors, $found = true) {
    if (!$found && !empty($rule['optional'])) return;
    if (!$found) { $errors[$path] = 'Обязательное поле'; return; }
    if ($value === null && !empty($rule['nullable'])) return;
    $type = $rule['type'];
    if ($type === 'number') {
        if ((!is_int($value) && !is_float($value)) || !is_finite((float)$value)) {
            $errors[$path] = 'Нужно число';
        } elseif ($value < $rule['min'] || $value > $rule['max']) {
            $errors[$path] = 'Допустимо от ' . $rule['min'] . ' до ' . $rule['max'];
        } elseif (($rule['step'] ?? 1) == 1 && floor($value) != $value) {
            $errors[$path] = 'Нужно целое число';
        }
    } elseif ($type === 'boolean') {
        if (!is_bool($value)) $errors[$path] = 'Нужен переключатель true / false';
    } elseif ($type === 'string') {
        if (!is_string($value)) { $errors[$path] = 'Нужна строка'; return; }
        $length = function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value);
        if ($length < ($rule['minLength'] ?? 0) || $length > ($rule['maxLength'] ?? 128)) $errors[$path] = 'Проверьте длину строки';
        if (isset($rule['choices']) && !in_array($value, $rule['choices'], true)) $errors[$path] = 'Выберите значение из списка';
        $patterns = [
            'color' => '/^#[0-9a-fA-F]{6}$/D',
            'identifier' => '/^[a-zA-Z0-9_-]{1,64}$/D',
            'digits' => '/^[0-9]*$/D',
            'rewardedId' => '/^[0-9]*$/D',
            'interstitialId' => '/^(?:int-[0-9]+)?$/D',
        ];
        $format = $rule['format'] ?? '';
        if (isset($patterns[$format]) && !preg_match($patterns[$format], $value)) $errors[$path] = 'Неверный формат';
    } elseif ($type === 'array') {
        if (!is_array($value) || array_values($value) !== $value) { $errors[$path] = 'Нужен список'; return; }
        if (count($value) < $rule['minItems'] || count($value) > $rule['maxItems']) $errors[$path] = 'Количество строк: от ' . $rule['minItems'] . ' до ' . $rule['maxItems'];
        $ids = [];
        foreach ($value as $i => $item) {
            gameplay_validate_value($item, $rule['items'], $path . '.' . $i, $errors);
            if (is_array($item) && isset($item['id']) && is_string($item['id'])) {
                if (isset($ids[$item['id']])) $errors[$path . '.' . $i . '.id'] = 'ID должен быть уникальным';
                $ids[$item['id']] = true;
            }
        }
    } elseif ($type === 'object') {
        if (!is_array($value)) { $errors[$path] = 'Нужен объект'; return; }
        foreach ($rule['fields'] as $key => $field) {
            gameplay_validate_value($value[$key] ?? null, $field, $path . '.' . $key, $errors, array_key_exists($key, $value));
        }
    }
}

function gameplay_validate($config) {
    $errors = [];
    if (!is_array($config)) return ['config' => 'Нужен JSON-объект'];
    foreach (gameplay_schema()['groups'] as $group) {
        foreach ($group['fields'] as $field) {
            $value = gameplay_value_at($config, $field['path'], $found);
            gameplay_validate_value($value, $field, $field['path'], $errors, $found);
        }
    }
    if ($errors) return $errors;
    $android=$config['economy']['androidEnergyV2']??null;
    if(is_array($android)) {
      if(isset($android['simpleBonus'])&&($bonusError=mobile_bonus_validation_error($android['simpleBonus'])))$errors['economy.androidEnergyV2.simpleBonus']=$bonusError;
      $policyError=mobile_energy_policy_change_error($android);
      if($policyError)$errors['economy.androidEnergyV2.chargePolicy']=$policyError;
      $seen=[];
      foreach($android['packages']??[] as $i=>$offer) {
        $sku=$offer['productId']??'';$product=mobile_energy_product($sku);
        if(!$product||$product['kind']!=='energy'||(int)($offer['energy']??0)!==$product['amount'])$errors['economy.androidEnergyV2.packages.'.$i.'.productId']='Нужен подготовленный неизменяемый SKU с таким количеством энергии';
        if(isset($seen[$sku]))$errors['economy.androidEnergyV2.packages.'.$i.'.productId']='SKU должен быть уникальным';$seen[$sku]=true;
      }
      $seen=[];
      foreach($android['subscriptions']??[] as $i=>$offer) {
        $sku=$offer['productId']??'';$product=mobile_energy_product($sku);
        if(!$product||$product['kind']!=='energy_subscription'||(int)($offer['batteryCount']??0)!==$product['batteryCount']||
          (int)($offer['capacity']??0)!==(int)$product['batteryCapacity']||(float)($offer['chargeHours']??0)!==(float)$product['chargeHours']||
          ($offer['basePlanId']??'')!==$product['basePlanId']||(int)($offer['periodDays']??0)!==7)$errors['economy.androidEnergyV2.subscriptions.'.$i.'.productId']='Условия должны совпадать с подготовленным недельным SKU';
        if(isset($seen[$sku]))$errors['economy.androidEnergyV2.subscriptions.'.$i.'.productId']='SKU должен быть уникальным';$seen[$sku]=true;
      }
    }
    if (!empty($config['economy']['energy']) && $config['economy']['energy']['initial'] > $config['economy']['energy']['cap']) $errors['economy.energy.initial'] = 'Стартовая энергия не может превышать лимит';
    foreach ([['angleMinDeg', 'angleMaxDeg'], ['speedMin', 'speedMax'], ['accelMin', 'accelMax']] as $pair) {
        if ($config['enemies'][$pair[0]] > $config['enemies'][$pair[1]]) $errors['enemies.' . $pair[1]] = 'Максимум не может быть меньше минимума';
    }
    $plusId = $config['economy']['starsShop']['plus']['id'];
    foreach ($config['economy']['starsShop']['packs'] as $pack) {
        if ($pack['id'] === $plusId) $errors['economy.starsShop.plus.id'] = 'ID Plus совпадает с ID пакета';
    }
    $side = $config['field']['maxSide'];
    $area = $config['player']['size'] ** 2 * $config['enemies']['areaMultiplier'];
    foreach ($config['enemies']['aspects'] as $i => $aspect) {
        if (sqrt($area * $aspect) >= $side - 24 || sqrt($area / $aspect) >= $side - 24) {
            $errors['enemies.aspects.' . $i] = 'Враг слишком большой для поля: уменьшите размер или площадь';
        }
    }
    return $errors;
}

function gameplay_publish($config, $expectedRevision) {
    $errors = gameplay_validate($config);
    if ($errors) return ['ok' => false, 'status' => 422, 'error' => 'Исправьте параметры', 'errors' => $errors];
    $encoded = json_encode($config, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    if ($encoded === false || strlen($encoded) > 262144) return ['ok' => false, 'status' => 422, 'error' => 'JSON слишком большой или содержит неверные данные'];
    $dir = gameplay_store_dir();
    if (!is_dir($dir) && !@mkdir($dir, 0755, true) && !is_dir($dir)) throw new RuntimeException('Не удалось создать каталог конфигурации');
    $lock = @fopen($dir . '/publish.lock', 'c');
    if (!$lock || !flock($lock, LOCK_EX)) throw new RuntimeException('Не удалось заблокировать конфигурацию');
    $temp = null;
    try {
        $current = gameplay_snapshot();
        if (!is_string($expectedRevision) || !hash_equals($current['revision'], $expectedRevision)) {
            return ['ok' => false, 'status' => 409, 'error' => 'Настройки изменены в другой вкладке. Экспортируйте черновик и загрузите актуальную версию.'];
        }
        $policyError=mobile_energy_policy_change_error($config['economy']['androidEnergyV2']??[],$current['config']['economy']['androidEnergyV2']??[]);
        if($policyError)return ['ok'=>false,'status'=>422,'error'=>$policyError,'errors'=>['economy.androidEnergyV2.chargePolicy'=>$policyError]];
        $snapshot = [
            'config' => $config,
            // Include a nonce so A -> B -> A is still a different publication.
            'revision' => hash('sha256', $encoded . random_bytes(16)),
            'updatedAt' => gmdate('c'),
            'source' => 'admin',
        ];
        $temp = tempnam($dir, 'publish-');
        $bytes = json_encode($snapshot, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
        if (!$temp || file_put_contents($temp, $bytes) !== strlen($bytes)) throw new RuntimeException('Не удалось записать конфигурацию');
        @chmod($temp, 0644);
        if (!@rename($temp, $dir . '/published.json')) throw new RuntimeException('Не удалось опубликовать конфигурацию');
        $temp = null;
        return ['ok' => true] + $snapshot;
    } finally {
        if ($temp && is_file($temp)) @unlink($temp);
        flock($lock, LOCK_UN);
        fclose($lock);
    }
}

require_once __DIR__.'/mobile_pace.php';
function gameplay_snapshot() {
    $snapshot=gameplay_snapshot_base();
    $snapshot['config']['mobileEnemies']=mobile_pace_read()['config'];
    return $snapshot;
}
