import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createServer} from '../node_modules/vite/dist/node/index.js';
const tick=()=>new Promise(resolve=>setImmediate(resolve));
const sample=JSON.parse(fs.readFileSync(new URL('../qa/fixture-profile.json',import.meta.url),'utf8'));
test('actual API and reactive store keep connection evidence separate from wallet acceptance and delivery ACK',async t=>{
  const keys=['window','document','location','localStorage','navigator','fetch'],before=new Map(keys.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)]));
  const values=new Map(),events=new Map(),calls=[];let failStorage=false,store,server;
  const listen=(name,fn)=>{if(!events.has(name))events.set(name,new Set());events.get(name).add(fn);};
  const unlisten=(name,fn)=>events.get(name)?.delete(fn);
  function install(name,value){Object.defineProperty(globalThis,name,{value,writable:true,configurable:true});}
  install('location',{hostname:'127.0.0.1'});
  install('window',{addEventListener:listen,removeEventListener:unlisten});
  install('document',{hidden:false,addEventListener:listen,removeEventListener:unlisten,createElement:()=>({content:{}})});
  install('navigator',{locks:{request:async(_name,_options,callback)=>callback({})}});
  install('localStorage',{getItem:k=>values.get(k)??null,setItem:(k,v)=>{if(failStorage)throw Error('quota');values.set(k,v);}});
  install('fetch',async(url,init={})=>{
    if(url==='/qa-session')return Response.json({initData:'isolated-SSR-fixture'});
    const body=init.body?JSON.parse(init.body):null;
    if(body?.action==='guest')return Response.json(structuredClone(sample));
    return new Promise((resolve,reject)=>{calls.push({url,init,body,resolve,reject});init.signal?.addEventListener('abort',()=>reject(new DOMException('aborted','AbortError')),{once:true});});
  });
  try{
    server=await createServer({configFile:false,root:path.resolve(import.meta.dirname,'..'),server:{middlewareMode:true},appType:'custom'});
    store=await server.ssrLoadModule('/src/services/game-store.ts');await store.initialize();assert.equal(store.state.initialized,true);
    await t.test('old failed profile request cannot override a newer scores response',async()=>{
      const start=calls.length,old=store.request({action:'profile'}).catch(e=>e),fresh=store.refreshBoards();
      calls[start+1].resolve(Response.json({ok:true,periods:{all:[],day:[]},average:null}));await fresh;
      calls[start].reject(new TypeError('network'));assert.equal((await old).code,'network_unavailable');assert.equal((await old).source,'transport');await tick();
      assert.equal(store.state.connection,'online');assert.equal(store.state.online,true);assert.equal(calls.length,start+2);
    });
    await t.test('browser offline is just a hint, not an offline assignment',async()=>{
      for(const fn of events.get('offline'))fn();await tick();const c=calls.at(-1);assert.equal(c.init.method,'OPTIONS');
      c.resolve(new Response(null,{status:204}));await tick();assert.equal(store.state.connection,'online');
    });
    await t.test('HTTP error named network_unavailable is still reachable and is not a transport failure',async()=>{
      const start=calls.length,p=store.request({action:'scores'}).catch(e=>e);calls.at(-1).resolve(Response.json({ok:false,error:'network_unavailable'},{status:503}));
      assert.equal((await p).code,'network_unavailable');assert.equal((await p).source,'api');assert.equal(store.state.connection,'online');assert.equal(calls.length,start+1);
      assert.doesNotMatch(store.errorText(await p),/сохран|нет связи/i);
    });
    await t.test('stale wallet response cannot undo the independent HTTP evidence',async()=>{
      const prior=store.state.profile.walletVersion,old=structuredClone(sample);old.profile.walletVersion=prior-1;
      const p=store.request({action:'profile'});calls.at(-1).resolve(Response.json(old));await p;
      assert.equal(store.state.profile.walletVersion,prior);assert.equal(store.state.connection,'online');
    });
    await t.test('malformed server JSON and local persistence failure do not mean loss of the network',async()=>{
      const malformed=store.request({action:'profile'}).catch(e=>e);calls.at(-1).resolve(new Response('<html>error</html>',{status:502}));
      assert.equal((await malformed).code,'service_unavailable');assert.equal(store.state.connection,'online');
      failStorage=true;const save=store.request({action:'profile'}).catch(e=>e),next=structuredClone(sample);next.profile.walletVersion++;
      calls.at(-1).resolve(Response.json(next));assert.equal((await save).message,'storage_unavailable');failStorage=false;
      assert.equal(store.state.connection,'online');
    });
    await t.test('probe success neither acknowledges a prepared game nor claims a finished result was saved',async()=>{
      await new Promise(resolve=>setTimeout(resolve,3100));
      const id='a'.repeat(64),beforeEnergy=store.state.profile.wallet.energy;
      store.prepareAttempt(id);const start=calls.at(-1);assert.equal(start.body.action,'round_start');start.reject(new TypeError('network'));await tick();await tick();
      const probe=calls.at(-1);assert.equal(probe.init.method,'OPTIONS');probe.resolve(new Response(null,{status:204}));await tick();
      const entry=store.state.history.find(a=>a.requestId===id);assert.equal(entry.phase,'prepared');assert.equal(entry.result,undefined);
      assert.equal(store.state.profile.wallet.energy,beforeEnergy);assert.equal(store.state.connection,'online');assert.equal(store.state.notice,'');
      const saved=JSON.parse(values.get(`untouch_tg_v2:rounds:${store.state.profile.id}`));assert.equal(saved.attempts.find(a=>a.requestId===id).phase,'prepared');
    });
  }finally{
    failStorage=false;store?.disposeStore();window.__untouchWriter?.release();await server?.close();
    for(const k of keys){const descriptor=before.get(k);if(descriptor)Object.defineProperty(globalThis,k,descriptor);else delete globalThis[k];}
  }
});
