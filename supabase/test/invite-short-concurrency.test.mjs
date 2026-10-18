// Forced interleaving model of SERIALIZABLE retry, not a multi-connection PostgreSQL test.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createEngine,seed,shortCodeFor} from '../functions/_shared/core/engine.mjs';
import {defaults,validatePolicy} from '../functions/_shared/core/policy.mjs';

class InterleavedStore {
  constructor(collision){this.rows=new Map();this.version=new Map();this.collision=`inviteCodes/${collision}`;this.arrivals=0;this.retries=0;this.barrier=new Promise(resolve=>this.release=resolve);}
  ref(path){return{path,id:path.split('/').at(-1),get:async()=>this.snap(path,this.rows.get(path))};}
  snap(path,value){return{exists:value!==undefined,id:path.split('/').at(-1),data:()=>structuredClone(value)};}
  collection(name){
    const query={doc:id=>this.ref(`${name}/${id}`),where:()=>query,orderBy:()=>query,limit:()=>query,get:async()=>({docs:[],size:0}),count:()=>({get:async()=>({data:()=>({count:0})})})};return query;
  }
  async runTransaction(callback){
    for(let attempt=0;attempt<7;attempt++){
      const observed=new Map(),writes=[];
      const tx={get:async ref=>{
        const version=this.version.get(ref.path)||0,body=structuredClone(this.rows.get(ref.path));observed.set(ref.path,version);
        if(attempt===0&&ref.path===this.collision&&this.arrivals<2){if(++this.arrivals===2)this.release();await this.barrier;}
        return this.snap(ref.path,body);
      },set:(ref,body)=>writes.push([ref.path,structuredClone(body)]),delete:ref=>writes.push([ref.path,undefined])};
      const result=await callback(tx);
      if([...observed].some(([path,version])=>(this.version.get(path)||0)!==version)){this.retries++;continue;}
      for(const [path,body]of writes){if(body===undefined)this.rows.delete(path);else this.rows.set(path,body);this.version.set(path,(this.version.get(path)||0)+1);}
      return result;
    }
    throw Error('Fixture retry exhausted');
  }
}
test('different UIDs race on the same deterministic candidate; losing transaction retries another alias',async()=>{
  const seen=new Map();let pair;
  for(let i=0;i<200000;i++){const uid=`collision_uid_${i}`,code=shortCodeFor(uid,0);if(seen.has(code)){pair=[seen.get(code),uid,code];break;}seen.set(code,uid);}
  assert.ok(pair,'deterministic birthday collision fixture');
  const [a,b,collision]=pair,db=new InterleavedStore(collision),stamp=Date.UTC(2026,9,18),policy=validatePolicy(defaults);
  for(const uid of [a,b])db.rows.set(`players/${uid}`,seed(uid,policy,stamp));
  const engine=createEngine({db,now:()=>stamp});
  const results=await Promise.all([a,b].map(uid=>engine.execute(uid,{action:'invites_state'})));
  const codes=results.map(r=>r.invites.ownCode);assert.notEqual(codes[0],codes[1]);assert.ok(codes.includes(collision));assert.ok(db.retries>=1);
  for(let i=0;i<2;i++){const uid=[a,b][i];assert.equal(db.rows.get(`inviteCodes/${codes[i]}`).uid,uid);assert.equal(db.rows.get(`players/${uid}`).ownShortCode,codes[i]);}
});
test('same UID concurrent first calls converge on one alias after retry',async()=>{
  const uid='same_uid_race',code=shortCodeFor(uid,0),db=new InterleavedStore(code),stamp=Date.UTC(2026,9,18);
  db.rows.set(`players/${uid}`,seed(uid,validatePolicy(defaults),stamp));
  const engine=createEngine({db,now:()=>stamp});
  const results=await Promise.all([1,2].map(()=>engine.execute(uid,{action:'invites_state'})));
  assert.deepEqual(results.map(r=>r.invites.ownCode),[code,code]);assert.equal(db.rows.get(`inviteCodes/${code}`).uid,uid);assert.ok(db.retries>=1);
  assert.equal([...db.rows.keys()].filter(path=>path.startsWith('inviteCodes/')).length,1);
});
