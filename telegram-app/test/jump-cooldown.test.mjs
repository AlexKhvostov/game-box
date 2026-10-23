import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import '../public/kernel/android-world.js';
import '../../supabase/functions/_shared/android-replay.generated.mjs';
import {defaults,hash,validatePolicy} from '../../supabase/functions/_shared/core/policy.mjs';
import {fields,applyChanges,ConfigInputError} from '../../supabase/functions/_shared/config-schema.mjs';
const call=body=>JSON.parse(globalThis.untouchKernel(JSON.stringify(body)));
test('admin permits zero and fractional short cooldowns while preserving historical snapshots',()=>{
 const field=fields.find(f=>f.path==='game.jumpCooldownSec');assert.deepEqual([field.min,field.max,field.step],[0,20,.1]);
 for(const sec of [0,.1,.25,1,2,10,20]){
  const config=applyChanges(defaults,[{path:field.path,value:sec}]);
  assert.equal(config.game.jumpCooldownSec,sec);validatePolicy({ok:true,config,revision:hash(config)});
 }
 for(const sec of [-1,20.1,Infinity,NaN])assert.throws(()=>applyChanges(defaults,[{path:field.path,value:sec}]),ConfigInputError);
 for(const sec of [30,60]){
  const config=structuredClone(defaults.config);config.game.jumpCooldownSec=sec;
  const old={ok:true,config,revision:hash(config)};validatePolicy(old);
  const changed=applyChanges(old,[{path:'audio.musicVolume',value:.4}]);assert.equal(changed.game.jumpCooldownSec,sec);
 }
});
test('guarded kernel override and current world share exact reviewed physics source',()=>{
 const root=new URL('../../',import.meta.url),baseline=JSON.parse(fs.readFileSync(new URL('docs/release-evidence/telegram-port/P0/baseline.json',root)));
 const override=JSON.parse(fs.readFileSync(new URL('../tools/kernel/jump-cooldown-zero-v1.json',import.meta.url)));
 const frozen=fs.readFileSync(new URL(baseline.privateSnapshot+'/'+override.file,root),'utf8').replaceAll('\r\n','\n');
 assert.equal(frozen.split(override.before).length,2);
 let extended=frozen.replace(override.before,override.after);const pace=JSON.parse(fs.readFileSync(new URL('../tools/kernel/enemy-pace-v2.json',import.meta.url)));for(const patch of pace.patches){assert.equal(extended.split(patch.before).length,2);extended=extended.replace(patch.before,patch.after);}assert.equal(extended,fs.readFileSync(new URL(override.file,root),'utf8').replaceAll('\r\n','\n'));
 const manifest=JSON.parse(fs.readFileSync(new URL('../public/kernel/manifest.json',import.meta.url)));
 assert.equal(manifest.gameplayOverrides[0].worldSha256,crypto.createHash('sha256').update(frozen.replace(override.before,override.after)).digest('hex'));
});
test('zero and short cooldowns accept jumps once per flight and every complete proof replays on the server',()=>{
 for(const seconds of [0,.1,.5,1,2,10,20,30,60])for(let seed=0;seed<8;seed++){
  const config=structuredClone(defaults.config);config.game.jumpCooldownSec=seconds;
  const requestId=hash(`jump-${seconds}-${seed}`),hadJump=true,hadHelmet=seed%2===0;
  let s=call({op:'create',config,requestId,hadJump,hadHelmet});assert.equal(s.jumpCount,0);s=call({op:'start'});
  let before=s.jumpCount;s=call({op:'jump'});assert.equal(s.jumpCount,before+1);assert.equal(s.jumpCooldownMs,seconds*1000);
  const count=s.jumpCount;s=call({op:'jump'});assert.equal(s.jumpCount,count,'Mid-air request is ignored even with zero cooldown');
  for(let frame=0;frame<10000&&!s.dead;frame++){
   if(frame%2===0)s=call({op:'jump'});
   if(frame%3===0)s=call({op:'move',dx:Math.sin(frame*.37+seed)*14,dy:Math.cos(frame*.21+seed)*13});
   if(s.dead)break;s=call({op:'tick',ms:16});
  }
  assert.equal(s.dead,true,`completed ${seconds}/${seed}`);
  const proof=call({op:'proof'}).proof;
  assert.equal(proof.events.filter(e=>e[0]===2).length,s.jumpCount);
  const replay=JSON.parse(globalThis.untouchReplay(JSON.stringify({config,requestId,hadJump,hadHelmet,proof})));
  assert.deepEqual(replay,{ok:true,timeMs:s.timeMs,runDistance:s.runDistance,riskCount:s.riskCount},`${seconds}/${seed}`);
 }
});
