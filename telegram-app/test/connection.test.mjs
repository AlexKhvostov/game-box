import {test} from 'node:test';
import assert from 'node:assert/strict';
import {ApiTransport,ConnectionTracker,TransportError,transportErrorText} from '../src/services/connection.ts';
const turn=()=>new Promise(resolve=>setImmediate(resolve));
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};}
function fixture(options={}){
  const calls=[],states=[];let clock=0;
  const transport=new ApiTransport('https://api.example/telegram-api',{cooldownMs:0,...options,now:()=>clock,changed:s=>states.push(s),fetcher:async(url,init)=>{
    const d=deferred();calls.push({url,init,...d});init.signal.addEventListener('abort',()=>d.reject(new DOMException('aborted','AbortError')),{once:true});return d.promise;
  }});
  return{transport,calls,states,advance:n=>clock+=n,request:()=>transport.request({method:'POST'},r=>r.json())};
}
const reply=(status=200)=>new Response(JSON.stringify({ok:status===200}),{status,headers:{'Content-Type':'application/json'}});

test('the default browser fetch retains its global receiver for both requests and probes',async()=>{
  const original=globalThis.fetch,calls=[];
  globalThis.fetch=function(_url,init){assert.equal(this,globalThis,'Window.fetch requires the Window receiver');calls.push(init.method);return Promise.resolve(init.method==='OPTIONS'?new Response(null,{status:204}):reply());};
  const transport=new ApiTransport('https://api.example/telegram-api');
  try{await transport.request({method:'POST'},r=>r.json());await transport.check();assert.deepEqual(calls,['POST','OPTIONS']);assert.equal(transport.connection.status,'online');}
  finally{transport.dispose();globalThis.fetch=original;}
});

test('a delayed request failure cannot overwrite a newer ranking response or start a probe',async()=>{
  const f=fixture();try{
    const old=f.request().catch(e=>e),ranking=f.request();f.calls[1].resolve(reply());await ranking;
    f.calls[0].reject(new TypeError('network'));assert.ok(await old instanceof TransportError);await turn();
    assert.equal(f.transport.connection.status,'online');assert.equal(f.calls.length,2);assert.deepEqual(f.states,['online']);
  }finally{f.transport.dispose();}
});
test('browser offline hint is only a check; a visible 204 keeps the working connection online',async()=>{
  const f=fixture();try{
    const p=f.request();f.calls[0].resolve(reply());await p;
    const check=f.transport.check();await turn();assert.equal(f.calls[1].init.method,'OPTIONS');assert.equal(f.calls[1].init.cache,'no-store');assert.equal(f.calls[1].init.mode,'cors');
    assert.equal(f.transport.connection.status,'online');f.calls[1].resolve(new Response(null,{status:204}));await check;
    assert.equal(f.transport.connection.status,'online');assert.deepEqual(f.states,['online']);
  }finally{f.transport.dispose();}
});
test('HTTP auth/server/domain errors prove reachability and never create a network probe',async()=>{
  for(const status of [401,403,409,429,500,503]){
    const f=fixture();try{
      const p=f.transport.request({method:'POST'},async()=>{throw Error('network_unavailable');}).catch(e=>e);
      f.calls[0].resolve(reply(status));assert.equal((await p).message,'network_unavailable');
      assert.equal(f.transport.connection.status,'online');assert.equal(f.calls.length,1);
    }finally{f.transport.dispose();}
  }
});
test('reachability is reported at headers before JSON, stale wallet or local storage failure',async()=>{
  const f=fixture(),body=deferred();try{
    const p=f.transport.request({method:'POST'},()=>body.promise).catch(e=>e);f.calls[0].resolve(reply());await turn();
    assert.equal(f.transport.connection.status,'online');body.reject(Error('storage_unavailable'));assert.equal((await p).message,'storage_unavailable');
    assert.equal(f.transport.connection.status,'online');assert.equal(f.calls.length,1);
  }finally{f.transport.dispose();}
});
test('several failing requests share one confirmation probe; only its failure means offline',async()=>{
  const f=fixture();try{
    const pending=[f.request().catch(e=>e),f.request().catch(e=>e),f.request().catch(e=>e)];
    f.calls.slice().forEach(c=>c.reject(new TypeError('network')));await Promise.all(pending);await turn();
    assert.equal(f.calls.length,4);assert.equal(f.transport.connection.status,'checking');
    f.calls[3].reject(new TypeError('network'));await turn();assert.equal(f.transport.connection.status,'offline');
  }finally{f.transport.dispose();}
});
test('a failing probe cannot override a real API response received while it was running',async()=>{
  const f=fixture();try{
    const broken=f.request().catch(e=>e);f.calls[0].reject(new TypeError('network'));await broken;await turn();
    const healthy=f.request();f.calls[2].resolve(reply());await healthy;
    f.calls[1].reject(new TypeError('late probe'));await turn();assert.equal(f.transport.connection.status,'online');
    assert.ok(!f.states.includes('offline'));
  }finally{f.transport.dispose();}
});
test('an actual later outage can still be detected after a previous response',async()=>{
  const f=fixture();try{
    const good=f.request();f.calls[0].resolve(reply());await good;
    const lost=f.request().catch(e=>e);f.calls[1].reject(new TypeError('network'));await lost;await turn();
    assert.equal(f.transport.connection.status,'checking');f.calls[2].reject(new TypeError('network'));await turn();
    assert.equal(f.transport.connection.status,'offline');
    const restored=f.transport.check();await turn();f.calls[3].resolve(new Response(null,{status:204}));await restored;
    assert.equal(f.transport.connection.status,'online');
  }finally{f.transport.dispose();}
});
test('hide cancels probes without declaring offline; immediate resume gets a fresh generation',async()=>{
  const f=fixture();try{
    const first=f.transport.check();await turn();f.transport.setActive(false);f.transport.setActive(true);await first;await turn();
    assert.equal(f.calls.length,2);assert.ok(!f.states.includes('offline'));f.calls[1].resolve(new Response(null,{status:204}));await turn();
    assert.equal(f.transport.connection.status,'online');
  }finally{f.transport.dispose();}
});
test('requests from before suspension cannot set a false offline state after resume',async()=>{
  const f=fixture();try{
    const old=f.request().catch(e=>e);f.transport.setActive(false);f.transport.setActive(true);await turn();
    f.calls[1].resolve(new Response(null,{status:204}));await turn();f.calls[0].reject(new TypeError('old timeout'));await old;
    assert.equal(f.transport.connection.status,'online');assert.equal(f.calls.length,2);
  }finally{f.transport.dispose();}
});

test('HTTP received after resume is fresh evidence even when the request began before suspension',async()=>{
  const f=fixture();try{
    const old=f.request();f.transport.setActive(false);f.transport.setActive(true);await turn();
    f.calls[0].resolve(reply());await old;f.calls[1].reject(new TypeError('late probe failure'));await turn();
    assert.equal(f.transport.connection.status,'online');assert.ok(!f.states.includes('offline'));
  }finally{f.transport.dispose();}
});

test('a response after disposal cannot notify the previous store',async()=>{
  const f=fixture();const old=f.request();f.transport.dispose();f.calls[0].resolve(reply());await old;
  assert.deepEqual(f.states,[]);
});
test('timeouts before headers are operation timeouts; a separate failed probe confirms the outage',async()=>{
  const f=fixture({timeoutMs:10});try{
    const error=await f.request().catch(e=>e);assert.equal(error.code,'request_timeout');await turn();
    assert.equal(f.transport.connection.status,'checking');f.calls[1].reject(new TypeError('probe'));await turn();assert.equal(f.transport.connection.status,'offline');
  }finally{f.transport.dispose();}
});
test('a body timeout cannot undo the HTTP response already received',async()=>{
  const f=fixture({timeoutMs:10});try{
    const pending=f.transport.request({method:'POST'},()=>new Promise((_,reject)=>f.calls[0].init.signal.addEventListener('abort',()=>reject(new DOMException('aborted','AbortError'))))).catch(e=>e);
    f.calls[0].resolve(reply());assert.equal((await pending).code,'request_timeout');assert.equal(f.transport.connection.status,'online');assert.equal(f.calls.length,1);
  }finally{f.transport.dispose();}
});
test('repeated hints obey cooldown; recovery does not require a browser online event',async()=>{
  const f=fixture({cooldownMs:3000});try{
    const first=f.transport.check();await turn();f.calls[0].reject(new TypeError('offline'));await first;
    for(let n=0;n<20;n++)await f.transport.check();assert.equal(f.calls.length,1);
    f.advance(6000);const restored=f.transport.check();await turn();f.calls[1].resolve(new Response(null,{status:204}));await restored;
    assert.equal(f.transport.connection.status,'online');
  }finally{f.transport.dispose();}
});
test('disposal/hidden app do not start probes or emit an offline cancellation',async()=>{
  const f=fixture();f.transport.setActive(false);await f.transport.check();assert.equal(f.calls.length,0);
  f.transport.setActive(true);await turn();f.transport.dispose();await turn();assert.ok(!f.states.includes('offline'));
});
test('an opaque probe response is not evidence that the API can be reached',async()=>{
  const f=fixture();try{const p=f.transport.check();await turn();f.calls[0].resolve({type:'opaque'});await p;assert.equal(f.transport.connection.status,'offline');}finally{f.transport.dispose();}
});
test('a response invalidates earlier failure evidence, independent of request order',()=>{
  const c=new ConnectionTracker(),a=c.ticket(),b=c.ticket();c.response(a);assert.equal(c.failure(b,true),false);assert.equal(c.status,'online');
  const later=c.ticket();assert.equal(c.failure(later,true),true);assert.equal(c.status,'offline');
});
test('transport messages describe the failed request and never promise a saved game or no internet',()=>{
  for(const locale of ['ru','en'])for(const code of ['network_unavailable','request_timeout','service_unavailable']){
    const text=transportErrorText(code,locale);assert.ok(text);assert.doesNotMatch(text,/сохран|результат|нет связи|offline|saved|result|internet/i);
  }
  assert.equal(transportErrorText('storage_unavailable','ru'),null);assert.equal(transportErrorText('telegram_unauthorized','en'),null);
});
