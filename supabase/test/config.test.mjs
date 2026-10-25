import {test} from 'node:test';
import assert from 'node:assert/strict';
import {defaultsSnapshot,fields,applyChanges,changesBetween} from '../functions/_shared/config-schema.mjs';
test('all 136 shipped/defaulted leaves have metadata; edits preserve unknown non-Android settings',()=>{
  assert.equal(fields.length,136);
  const source=structuredClone(defaultsSnapshot);source.config.futureFlag={enabled:true};
  const config=applyChanges(source,[{path:'economy.androidEnergyV2.simpleBonus.reward',value:35}]);
  assert.equal(config.economy.androidEnergyV2.simpleBonus.reward,35);
  assert.equal(defaultsSnapshot.config.economy.androidEnergyV2.simpleBonus.reward,30);
  assert.deepEqual(config.futureFlag,{enabled:true});
  assert.equal(changesBetween(source.config,config).length,1);
});
test('server rejects unknown/readonly, duplicate, non-integer, out-of-range and invalid paired fields',()=>{
  for(const patch of [[{path:'__proto__.bad',value:true}],[{path:'economy.androidEnergyV2.packages.0.energy',value:999}],
    [{path:'player.size',value:20},{path:'player.size',value:30}],[{path:'economy.androidEnergyV2.baseAttemptCost',value:1.2}],
    [{path:'audio.musicVolume',value:5}],[{path:'enemies.angleMinDeg',value:150}],[{path:'field.colorHex',value:'javascript:alert(1)'}]])assert.throws(()=>applyChanges(defaultsSnapshot,patch),e=>e.code==='config_invalid');
});
test('derived duplicates follow editable canonical fields without changing immutable SKU contents',()=>{
  const config=applyChanges(defaultsSnapshot,[{path:'economy.androidEnergyV2.simpleBonus.initialEnergy',value:60},
    {path:'economy.androidEnergyV2.simpleBonus.videoReward',value:45}]);
  assert.equal(config.economy.androidEnergyV2.initialEnergy,60);assert.equal(config.economy.androidEnergyV2.rewards.ad,45);
  assert.equal(config.economy.androidEnergyV2.subscriptions[0].chargeHours,8);
  assert.deepEqual(config.economy.androidEnergyV2.packages,defaultsSnapshot.config.economy.androidEnergyV2.packages);
});
test('current admin UI exposes bonus in hours, hides retired batteries, keeps feedback reward',()=>{
  const period=fields.find(f=>f.path==='economy.androidEnergyV2.simpleBonus.periodSec');
  assert.equal(period.default/period.displayScale,8);assert.equal(period.displayUnit,'ч');
  for(const value of [1,901,28801])assert.throws(()=>applyChanges(defaultsSnapshot,[{path:period.path,value}]),e=>e.code==='config_invalid');
  assert.equal(applyChanges(defaultsSnapshot,[{path:period.path,value:43200}]).economy.androidEnergyV2.simpleBonus.periodSec,43200);
  for(const path of ['economy.androidEnergyV2.chargeHours','economy.androidEnergyV2.batteryCapacity']){
    const field=fields.find(f=>f.path===path);assert.equal(field.hidden,true);assert.equal(field.readOnly,true);
    assert.throws(()=>applyChanges(defaultsSnapshot,[{path,value:10}]),e=>e.code==='config_invalid');
  }
  const feedback=fields.find(f=>f.path==='economy.androidEnergyV2.rewards.feedback');assert.equal(feedback.hidden,false);assert.equal(feedback.default,50);
  for(const path of ['economy.androidEnergyV2.rewards.achievement','economy.androidEnergyV2.rewards.google','economy.androidEnergyV2.rewards.age','economy.earnSurviveSeconds','economy.earnRecordSeconds','economy.earnRisksInRun','game.timerHaptic','game.hudSpeedScaleMax','field.cornerRadius','field.maxSide'])assert.equal(fields.find(f=>f.path===path).hidden,true,path);
});

test('all editable fields have cross-language contract cases and ranges match runtime clamps',async()=>{
  const fs=await import('node:fs/promises');
  const cases=JSON.parse(await fs.readFile(new URL('../../test/fixtures/admin-config-cases.json',import.meta.url),'utf8'));
  assert.deepEqual(cases.map(c=>c.path),fields.filter(f=>!f.hidden).map(f=>f.path));
  for(const item of cases)assert.doesNotThrow(()=>applyChanges(defaultsSnapshot,[item]),item.path);
  for(const [path,value]of [['game.jumpScale',2],['game.jumpDurationSec',0.05],['field.brightness',0.1],['field.shadowBrightness',0.1],['game.idleSpeedMultiplier',1.5],['enemies.areaMultiplier',0.1],['economy.interstitialSessionFreeRounds',1],['economy.interstitialSessionGraceSec',10]]){
    assert.throws(()=>applyChanges(defaultsSnapshot,[{path,value}]),e=>e.code==='config_invalid',path);
  }
});
