import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {androidRoundProof} from '../functions/_shared/android-replay.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {defaults,hash} from '../functions/_shared/core/policy.mjs';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
const fixtures=JSON.parse(fs.readFileSync(new URL('./fixtures/android-replay.json',import.meta.url)));
const local=await testDatabase();after(()=>local.close());
const db=new PostgresStore(local.pool);let stamp=Date.UTC(2026,9,18,12);
const engine=createEngine({db,now:()=>stamp});
test('frozen v1 verifier retains its original physics/config/PRNG sources',()=>{
 const manifest=JSON.parse(fs.readFileSync(new URL('../functions/_shared/android-replay.generated.json',import.meta.url)));
 for(const [file,expected]of Object.entries(manifest)){
  const path=file==='generatedSha256'?'supabase/functions/_shared/android-replay.generated.mjs':file;
  // v3 extends GameConfig; v1 continues to use its original frozen policy model.
  const sourcePath=path==='lib/domain/gameplay_config.dart'?'tools/replay/legacy_gameplay_config.dart':path;
  const source=fs.readFileSync(new URL('../../'+sourcePath,import.meta.url),'utf8');
  const digest=value=>crypto.createHash('sha256').update(value.replaceAll('\r\n','\n')).digest('hex');
  assert.equal(digest(source),expected,path);
  assert.equal(digest(source.replaceAll('\r\n','\n').replaceAll('\n','\r\n')),expected,`${path}/CRLF checkout`);
 }
});
test('256 completed real Flutter/Dart runs match compiled server physics across frame rates/loadouts',()=>{
 for(const f of fixtures){
  const r=JSON.parse(globalThis.untouchReplay(JSON.stringify(f)));
  assert.equal(r.ok,true,f.requestId);
  for(const k of ['timeMs','runDistance','riskCount'])assert.equal(r[k],f[k],`${f.requestId}/${k}`);
 }
});
test('tampered duration/distance/risk/seed/jump/continued life cannot pass production verifier',()=>{
 const f=fixtures.find(f=>!f.hadHelmet&&!f.hadJump);
 const round={proofVersion:1,requestId:f.requestId,policy:{config:f.config},hadJump:false,hadHelmet:false};
 androidRoundProof.finish(f,round);
 for(const key of ['timeMs','runDistance','riskCount'])assert.throws(()=>androidRoundProof.finish({...f,[key]:f[key]+1},round),e=>e.code==='result_proof_invalid');
 for(const events of [[],[...f.proof.events,[0,20]],[[2],...f.proof.events],[[0,51]],[[1,Infinity,0]],[[9]],[[0,-1]]]){
  assert.throws(()=>androidRoundProof.finish({...f,proof:{version:1,events}},round),e=>e.code==='result_proof_invalid');
 }
 assert.throws(()=>androidRoundProof.finish({...f,proof:undefined},round),e=>e.code==='result_proof_required');
 assert.throws(()=>androidRoundProof.finish(f,{...round,requestId:hash('another-seed')}),e=>e.code==='result_proof_invalid');
});
test('new server attempts require proof before debit; accepted result is idempotent and cannot be forged',async()=>{
 const uid='actual-proof-owner';const call=body=>engine.execute(uid,body);
 await call({action:'guest'});
 const f=fixtures.find(f=>!f.hadHelmet&&!f.hadJump);
 await assert.rejects(call({action:'round_start',requestId:f.requestId,rulesRevision:defaults.revision}),e=>e.code==='update_required');
 assert.equal((await call({action:'profile'})).profile.wallet.energy,50);
 const r=await call({action:'round_start',requestId:f.requestId,rulesRevision:defaults.revision,proofVersion:1});
 await call({action:'round_activate',requestId:f.requestId});stamp+=f.timeMs+2000;
 const input={action:'round_finish',roundId:r.roundId,timeMs:f.timeMs,runDistance:f.runDistance,riskCount:f.riskCount,proof:f.proof};
 await assert.rejects(call({...input,riskCount:input.riskCount+1}),e=>e.code==='result_proof_invalid');
 assert.equal((await db.collection('scores').get()).size,0);
 const a=await call(input),b=await call(input);assert.equal(a.energyReward,b.energyReward);
 assert.equal((await db.collection('scores').get()).size,1);
 assert.equal((await db.collection('players').doc(uid).get()).data().completedGames,1);
 await assert.rejects(engine.execute('wrong-owner',input),e=>e.code==='round_not_found');
});

test('visible start poses replay while malformed, off-field or altered-speed headers are refused',()=>{
 const f=fixtures.find(f=>f.proof.startPose);
 assert.ok(f);
 const round={proofVersion:1,requestId:f.requestId,policy:{config:f.config},hadJump:f.hadJump,hadHelmet:f.hadHelmet};
 androidRoundProof.finish(f,round);
 for(const mutate of [p=>p.pop(),p=>p[0].push(7),p=>p[0][0]=-1000,
  p=>p[0][0]=null,p=>p[0][2]=1e6,p=>p[0][4]=1e12]) {
  const changed=structuredClone(f);mutate(changed.proof.startPose);
  assert.throws(()=>androidRoundProof.finish(changed,round),e=>e.code==='result_proof_invalid');
 }
 assert.equal(fixtures.filter(f=>f.proof.startPose).length,128);
 assert.equal(fixtures.filter(f=>!f.proof.startPose).length,128);
});
