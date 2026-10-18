<?php
// Pure operator guard tests. Never connects to a host or database.
$source=file_get_contents(__DIR__.'/simple_energy_live_operator.php');
$start=strpos($source,'class SbOperatorError');$end=strpos($source,'$pdo=null;',$start);
if($start===false||$end===false)throw new RuntimeException('Operator helper boundary missing');
eval(substr($source,$start,$end-$start));
$checks=0;
function check_operator($ok){global$checks;if(!$ok)throw new RuntimeException('Operator test failed');$checks++;}
function expect_operator_error($fn,$error){try{$fn();}catch(SbOperatorError$e){check_operator($e->getMessage()===$error);return;}throw new RuntimeException('Guard accepted unsafe input');}
$config=['economy'=>['androidEnergyV2'=>['enabled'=>true,'chargePolicy'=>['version'=>1,'effectiveAt'=>100,'chargeHours'=>8],
    'packages'=>[['productId'=>'energy_100_v1','energy'=>100]],'subscriptions'=>[['productId'=>'energy_batteries_2_v1']]],
    'telegramTokens'=>123],'player'=>['size'=>23]];
$snapshot=['config'=>$config,'revision'=>'unchanged-file-revision'];
$hash=hash('sha256',sb_json(sb_without_policy($config)));
$candidate=sb_candidate($snapshot,$snapshot['revision'],$hash);
check_operator(sb_without_policy($candidate)===$config);
check_operator($candidate['economy']['androidEnergyV2']['simpleBonus']===sb_policy());
check_operator(sb_policy()['reward']===30&&sb_policy()['periodSec']===28800);
check_operator(sb_policy()['tier2Reward']===60&&sb_policy()['tier5Reward']===150);
check_operator(sb_policy()['initialEnergy']===50&&sb_policy()['videoReward']===40&&sb_policy()['inviterReward']===60);
expect_operator_error(fn()=>sb_candidate($snapshot,'stale-revision',$hash),'publication_changed');
expect_operator_error(fn()=>sb_candidate($snapshot,$snapshot['revision'],str_repeat('0',64)),'unrelated_config_changed');
$disabled=$snapshot;$disabled['config']['economy']['androidEnergyV2']['enabled']=false;
expect_operator_error(fn()=>sb_candidate($disabled,$disabled['revision'],hash('sha256',sb_json(sb_without_policy($disabled['config'])))),'energy_v2_required');
$changed=$snapshot;$changed['config']['economy']['telegramTokens']++;
expect_operator_error(fn()=>sb_candidate($changed,$changed['revision'],$hash),'unrelated_config_changed');
$existing=$snapshot;$existing['config']['economy']['androidEnergyV2']['simpleBonus']=sb_policy();
check_operator(sb_candidate($existing,$existing['revision'],$hash)===$existing['config']);
check_operator(count(sb_paths())===7&&array_key_first(sb_paths())==='api/mobile_energy_bonus.php'&&array_key_last(sb_paths())==='api/mobile.php');
expect_operator_error(fn()=>sb_files([]),'file_scope_invalid');
echo json_encode(['ok'=>true,'checks'=>$checks,'network'=>false,'database'=>false])."\n";
