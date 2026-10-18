import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';

test('historical feedback spend backfill counts activated costs, excludes refunds, preserves existing counters',async()=>{
  const local=await testDatabase();
  try{
    const db=new PostgresStore(local.pool);
    await db.collection('players').doc('old').set({wallet:{energy:50}});
    for(const [id,body] of Object.entries({
      started:{uid:'old',cost:9,activatedAt:null,canceled:false},
      active:{uid:'old',cost:3,activatedAt:100,canceled:false},
      completed:{uid:'old',cost:1,activatedAt:100,finishedAt:200,canceled:false},
      canceled:{uid:'old',cost:8,activatedAt:null,canceled:true}
    }))await db.collection('rounds').doc(id).set(body);
    const sql=await fs.readFile(new URL('../migrations/20261016200359_feedback_spent_energy.sql',import.meta.url),'utf8');
    await local.pg.exec(sql);
    assert.deepEqual((await db.collection('players').doc('old').get()).data().wallet,{energy:50,feedbackSpentEnergy:4});
    await db.collection('players').doc('old').update({'wallet.feedbackSpentEnergy':88});
    await local.pg.exec(sql);
    assert.equal((await db.collection('players').doc('old').get()).data().wallet.feedbackSpentEnergy,88);
  }finally{await local.close();}
});
