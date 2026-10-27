import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {hash} from '../functions/_shared/core/policy.mjs';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
const local=await testDatabase(),db=new PostgresStore(local.pool);
after(()=>local.close());
const engine=createEngine({db}), kind='energy_ad_unavailable_bonus';
const op=(uid,nonce,args={})=>engine.execute(uid,{action:'wallet_operation',kind,args,operationId:hash(nonce)});

test('distinct concurrent requests and retries grant only 20 to the account',async()=>{
  const uid='ad-alternative';await engine.execute(uid,{action:'guest'});
  const results=await Promise.all(Array.from({length:5},(_,i)=>op(uid,`bonus-${i}`)));
  assert.ok(results.every(r=>r.profile.wallet.energy===70));
  assert.equal(results.at(-1).profile.wallet.energy,70);
  assert.deepEqual(results.at(-1).profile.wallet.claimed,[kind]);
  const first=await op(uid,'bonus-0');
  assert.deepEqual(first.profile.wallet.claimed,results[0].profile.wallet.claimed);
  assert.equal(first.profile.wallet.energy,70);
  const restarted=createEngine({db});
  const afterRestart=await restarted.execute(uid,{action:'wallet_operation',kind,operationId:hash('after-restart')});
  assert.equal(afterRestart.profile.wallet.energy,70);
});

test('the client cannot choose amount, age, or recipient; another account has its own single grant',async()=>{
  const uid='ad-alternative-invalid';await engine.execute(uid,{action:'guest'});
  for(const args of [{amount:999},{age:'under18'},{owner:'someone-else'}]) {
    await assert.rejects(op(uid,JSON.stringify(args),args),e=>e.code==='operation_invalid');
  }
  assert.equal((await engine.execute(uid,{action:'profile'})).profile.wallet.energy,50);
  assert.equal((await op(uid,'second-player')).profile.wallet.energy,70);
});

test('the shared engine does not enable this Android bonus for Telegram',async()=>{
  const uid='telegram-no-ad-alternative',identity={platform:'telegram',telegramVerified:true,username:'TelegramQA'};
  const before=await engine.execute(uid,{action:'guest'},identity);
  await assert.rejects(engine.execute(uid,{action:'wallet_operation',kind,operationId:hash('telegram-bonus')},identity),e=>e.code==='platform_action_invalid');
  const after=await engine.execute(uid,{action:'profile'},identity);
  assert.equal(after.profile.wallet.energy,before.profile.wallet.energy);
  assert.deepEqual(after.profile.wallet.claimed,before.profile.wallet.claimed);
});
