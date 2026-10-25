import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {hash} from '../functions/_shared/core/policy.mjs';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
const local=await testDatabase(),db=new PostgresStore(local.pool);after(()=>local.close());
const engine=createEngine({db});
test('operation grant identifies only its own bonus and lost-reply replay preserves that grant',async()=>{
 const uid='grant-bonus',before=await engine.execute(uid,{action:'guest'});
 const command={action:'wallet_operation',kind:'energy_bonus_claim',operationId:hash('grant-bonus-operation')};
 const first=await engine.execute(uid,command);
 assert.equal(first.profile.wallet.energy,before.profile.wallet.energy+30);
 assert.deepEqual(first.energyGrant,{kind:command.kind,operationId:command.operationId,amount:30});
 await engine.execute(uid,{action:'wallet_operation',kind:'energy_hidden_tap',operationId:hash('other-grant')});
 const replay=await engine.execute(uid,command);
 assert.equal(replay.profile.wallet.energy,first.profile.wallet.energy+20);
 assert.deepEqual(replay.energyGrant,first.energyGrant);
});
test('a zero-credit operation and a repeated one-time reward never advertise another grant',async()=>{
 const uid='grant-age';await engine.execute(uid,{action:'guest'});
 const mark=await engine.execute(uid,{action:'wallet_operation',kind:'energy_age_completed',operationId:hash('age-mark')});
 assert.equal(mark.energyGrant,undefined);
 const credit=await engine.execute(uid,{action:'wallet_operation',kind:'energy_reward',args:{id:'age'},operationId:hash('age-first')});
 assert.ok(credit.energyGrant.amount>0);
 const repeat=await engine.execute(uid,{action:'wallet_operation',kind:'energy_reward',args:{id:'age'},operationId:hash('age-second')});
 assert.equal(repeat.profile.wallet.energy,credit.profile.wallet.energy);
 assert.equal(repeat.energyGrant,undefined);
});
