import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import '../public/kernel/android-world.js';
import {androidRoundProof} from '../../supabase/functions/_shared/android-replay.mjs';
import {fields,applyChanges,getValue,defaultsSnapshot} from '../../supabase/functions/_shared/config-schema.mjs';
import {enemyPaceDefaults,enemyPaceRanges} from '../../supabase/functions/_shared/enemy-pace-config.mjs';
import {validatePolicy,hash} from '../../supabase/functions/_shared/core/policy.mjs';
import {createEngine} from '../../supabase/functions/_shared/core/engine.mjs';
import {testDatabase} from '../../supabase/test/database.mjs';
import {PostgresStore} from '../../supabase/functions/_shared/postgres-store.mjs';
const base=JSON.parse(fs.readFileSync(new URL('../src/generated/android-config.json',import.meta.url))).config;
const call=input=>{const result=JSON.parse(globalThis.untouchKernel(JSON.stringify(input)));assert.equal(result.ok,true,JSON.stringify(input));return result;};
const speed=x=>70*((x+3)**.2-1);
function create(patch={},seed='brake-clock'){const config=structuredClone(base);Object.assign(config.game,{startInvulnSec:30},patch.game);if(patch.enemyPace)config.enemyPace=patch.enemyPace;call({op:'create',proofVersion:2,config,requestId:seed,hadJump:patch.hadJump===true});return {config,start:call({op:'start'})};}
function advance(ms){let s;for(let left=ms;left>0;){const dt=Math.min(50,left);s=call({op:'tick',ms:dt});left-=dt;}return s;}
test('curve, automatic six-second brake, smooth canonical velocity and repeated cycles',()=>{
 const {start}=create();assert.ok(Math.abs(start.brake.speed-speed(0))<1e-9);assert.equal(start.brake.charge,0);
 assert.equal(advance(5950).brake.presses,0);const pressed=advance(50);assert.equal(pressed.brake.presses,1);assert.equal(pressed.timeMs,6000);assert.equal(pressed.brake.effectiveSec,0);assert.equal(pressed.brake.charge,0);assert.ok(Math.abs(pressed.brake.targetSpeed-speed(0))<1e-8);assert.ok(pressed.brake.speed>pressed.brake.targetSpeed);
 const halfway=advance(100);assert.ok(halfway.brake.speed<pressed.brake.speed);assert.ok(halfway.brake.speed>halfway.brake.targetSpeed);
 const settled=advance(100);assert.ok(Math.abs(settled.brake.speed-settled.brake.targetSpeed)<1e-9);
 const repeated=advance(18000);assert.equal(repeated.brake.presses,4);assert.ok(Math.abs(repeated.brake.effectiveSec-.2)<1e-8);assert.equal(repeated.timeMs,24200);
});
test('late collection carries delay; crossing the pad activates; no remote or premature press',()=>{
 create();call({op:'move',dx:-100,dy:0});const ready=advance(9000);assert.equal(ready.brake.presses,0);assert.equal(ready.brake.ready,true);assert.ok(Math.abs(ready.brake.targetSpeed-speed(9.001))<1e-7);
 const cross=call({op:'move',dx:200,dy:0});assert.equal(cross.brake.presses,1);assert.ok(Math.abs(cross.brake.effectiveSec-3.001)<1e-7);
 call({op:'move',dx:-100,dy:0});const next=advance(6000);assert.equal(next.brake.presses,2);assert.ok(Math.abs(next.brake.effectiveSec-3.001)<1e-7);
});
test('new parameters round-trip through common admin schema and actual compiled curve/timers',()=>{
 const values={initialSpeed:8,growthMultiplier:60,growthExponent:.25,startSmoothingSec:4,initialCompensation:.8,brakeCooldownSec:7,brakeFirstReadySec:5,brakeRewindSec:4};
 const config=applyChanges(defaultsSnapshot,Object.entries(values).map(([k,value])=>({path:'enemyPace.'+k,value})));
 for(const [k,v]of Object.entries(values)){const f=fields.find(f=>f.path==='enemyPace.'+k);assert.equal(f.hidden,false);assert.equal(getValue(config,f.path),v);}
 assert.equal(validatePolicy({ok:true,config,revision:hash(config)}).config.enemyPace.growthMultiplier,60);
 const s=create({enemyPace:config.enemyPace}).start;assert.ok(Math.abs(s.brake.speed-(8+60*(4**.25-.8)))<1e-9);assert.equal(advance(5000).brake.presses,1);assert.ok(Math.abs(call({op:'snapshot'}).brake.effectiveSec-1)<1e-8);assert.equal(advance(7000).brake.presses,2);
 for(const [k,[lo,hi]]of Object.entries(enemyPaceRanges))for(const value of [lo-1,hi+1,NaN,'6'])assert.throws(()=>applyChanges(defaultsSnapshot,[{path:'enemyPace.'+k,value}]),k);
 for(const [k,v]of Object.entries(enemyPaceDefaults))assert.equal(getValue({},'enemyPace.'+k),v);
});
function completed(seed,helmet=false,jump=false,pace){const config=structuredClone(base);config.game.startInvulnSec=10;if(pace)config.enemyPace=pace;call({op:'create',proofVersion:2,config,requestId:seed,hadHelmet:helmet,hadJump:jump});let s=call({op:'start'});while(s.playing){if(jump&&s.timeMs%850===0)s=call({op:'jump'});s=call({op:'tick',ms:Math.min(50,1000/60)});if(s.timeMs>60000&&s.playing){s=call({op:'move',dx:90,dy:90});}}return {s,config,proof:call({op:'proof'}).proof,requestId:seed,hadHelmet:helmet,hadJump:jump};}
test('64 actual v2 runs replay with identical metrics; tampering, live proofs and wrong protocol fail',()=>{
 let brakes=0;
 for(let i=0;i<64;i++){const r=completed(hash('brake-'+i),!!(i%2),!!(i%3));brakes+=r.s.brake.presses;const input={...r.s,proof:r.proof};const round={proofVersion:2,policy:{config:r.config},requestId:r.requestId,hadHelmet:r.hadHelmet,hadJump:r.hadJump};assert.doesNotThrow(()=>androidRoundProof.finish(input,round));assert.throws(()=>androidRoundProof.finish({...input,timeMs:input.timeMs+1},round),e=>e.code==='result_proof_invalid');assert.throws(()=>androidRoundProof.finish({...input,proof:{...r.proof,version:1}},round),e=>e.code==='result_proof_required');}
 assert.ok(brakes>0);create();const live=call({op:'proof'}).proof;assert.equal(JSON.parse(globalThis.untouchTelegramReplay(JSON.stringify({op:'verify',config:base,requestId:'brake-clock',proof:live}))).ok,false);
});
test('server pins v2 to saved round; rejects downgrade/forgery; accepts once and preserves idempotency',async()=>{
 const local=await testDatabase();try{
  const db=new PostgresStore(local.pool);let stamp=Date.now();const policy={ok:true,config:structuredClone(base),revision:hash(base)};const engine=createEngine({db,getPolicy:async()=>policy,now:()=>stamp});const requestId=hash('proof2-server');const r=completed(requestId);policy.config=r.config;policy.revision=hash(r.config);const callServer=body=>engine.execute('proof2-owner',body);
  await callServer({action:'guest'});const start={action:'round_start',requestId,proofVersion:2,helmet:false,jump:false,rulesRevision:policy.revision,revision:base.economy.androidEnergyV2.revision};const begun=await callServer(start);assert.equal((await db.collection('rounds').doc(begun.roundId).get()).data().proofVersion,2);
  await assert.rejects(callServer({...start,proofVersion:1}),e=>e.code==='operation_conflict');await callServer({action:'round_activate',requestId});stamp+=r.s.timeMs;
  const finish={action:'round_finish',roundId:begun.roundId,timeMs:r.s.timeMs,runDistance:r.s.runDistance,riskCount:r.s.riskCount,hadHelmet:false,hadJump:false,proof:r.proof};
  await assert.rejects(callServer({...finish,riskCount:finish.riskCount+1}),e=>e.code==='result_proof_invalid');const result=await callServer(finish);assert.equal(result.scoreId,begun.roundId);assert.equal((await callServer(finish)).scoreId,begun.roundId);
 }finally{await local.close();}
});
test('generated v2 server model equals browser model and manifest hashes are current',()=>{
 const manifest=JSON.parse(fs.readFileSync(new URL('../public/kernel/manifest.json',import.meta.url)));const digest=p=>crypto.createHash('sha256').update(fs.readFileSync(new URL(p,import.meta.url))).digest('hex');assert.equal(digest('../public/kernel/android-world.js'),manifest.generatedSha256);assert.equal(digest('../../supabase/functions/_shared/telegram-replay.generated.mjs'),manifest.serverGeneratedSha256);assert.equal(digest('../../lib/domain/enemy_pace.dart'),manifest.paceModelSha256);assert.equal(digest('../tools/kernel/enemy-pace-v2.json'),manifest.paceOverrideSha256);
});

test('airborne hero does not press a ready floor plate; landing triggers it once',()=>{
 const {config}=create({hadJump:true});advance(5900);assert.equal(call({op:'jump'}).jumpCount,1);const airborne=advance(100);assert.equal(airborne.brake.ready,true);assert.equal(airborne.brake.presses,0);const landed=advance(Math.ceil(config.game.jumpDurationSec*1000));assert.equal(landed.brake.presses,1);
});

test('independent brake and speed-bar switches preserve curve, automatic press and default compatibility',()=>{
 for(const brakeEnabled of [false,true])for(const speedBarEnabled of [false,true]){
  const {start}=create({enemyPace:{brakeEnabled,speedBarEnabled}});assert.equal(start.brake.enabled,brakeEnabled);assert.equal(start.brake.speedBarEnabled,speedBarEnabled);
  let previous=start.brake.speed,s;
  for(let i=0;i<240;i++){s=advance(50);if(!brakeEnabled)assert.ok(s.brake.speed>=previous);previous=s.brake.speed;}
  assert.equal(s.brake.presses,brakeEnabled?2:0);assert.ok(Math.abs(s.brake.effectiveSec-(brakeEnabled?0:12))<1e-7);
  if(!brakeEnabled){assert.equal(s.brake.ready,false);assert.equal(s.brake.charge,0);assert.ok(Math.abs(s.brake.speed-speed(12))<1e-7);}
 }
 const {start}=create();assert.equal(start.brake.enabled,true);assert.equal(start.brake.speedBarEnabled,true);
});
test('admin toggles are strict booleans and disabled-brake proof replays with monotonic speed',()=>{
 for(const key of ['brakeEnabled','speedBarEnabled']){
  const path='enemyPace.'+key,field=fields.find(f=>f.path===path);assert.equal(field.type,'boolean');assert.equal(field.hidden,false);
  for(const value of [true,false])assert.equal(applyChanges(defaultsSnapshot,[{path,value}]).enemyPace[key],value);
  for(const value of [0,1,'false',null,{},[]]){assert.throws(()=>applyChanges(defaultsSnapshot,[{path,value}]));const c=structuredClone(base);c.enemyPace={[key]:value};assert.throws(()=>validatePolicy({ok:true,config:c,revision:hash(c)}));assert.equal(JSON.parse(globalThis.untouchKernel(JSON.stringify({op:'create',proofVersion:2,config:c,requestId:'invalid-switch'}))).ok,false);}
 }
 const r=completed(hash('disabled-brake-proof'),false,false,{brakeEnabled:false,speedBarEnabled:true});assert.equal(r.s.brake.presses,0);assert.ok(Math.abs(r.s.brake.effectiveSec-r.s.timeMs/1000)<.0011);assert.doesNotThrow(()=>androidRoundProof.finish({...r.s,proof:r.proof},{proofVersion:2,policy:{config:r.config},requestId:r.requestId,hadHelmet:false,hadJump:false}));
});
