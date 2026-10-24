// Isolated loopback QA. Uses the real engine, PostgreSQL migrations and auth
// verifier with a synthetic Telegram fixture. Never reads the real bot token.
import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import {testDatabase} from '../../supabase/test/database.mjs';
import {PostgresStore} from '../../supabase/functions/_shared/postgres-store.mjs';
import {createEngine} from '../../supabase/functions/_shared/core/engine.mjs';
import {createTelegramIdentityResolver} from '../../supabase/functions/_shared/telegram-auth.mjs';
import {createTelegramApi} from '../../supabase/functions/_shared/telegram-api.mjs';
import {initialPlatformSettings} from '../../supabase/functions/_shared/platform-config-schema.mjs';
import {validatePolicy} from '../../supabase/functions/_shared/core/policy.mjs';
const local=await testDatabase();
for(const name of ['20261019205914_android_average_ranking_cache.sql','20261019223954_telegram_platform_core.sql','20261022085951_telegram_bot_namespaces.sql'])await local.pg.exec(await fs.readFile(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8'));
const snapshot=validatePolicy(JSON.parse(await fs.readFile(new URL('../src/generated/android-config.json',import.meta.url),'utf8')));
const fixtureToken='123456789:loopback-qa-fixture-no-real-bot-123456';
const db=new PostgresStore(local.pool),engine=createEngine({db,getPolicy:async()=>snapshot});
const api=createTelegramApi({engine,resolveIdentity:createTelegramIdentityResolver({pool:local.pool,botToken:fixtureToken}),platformConfig:async()=>initialPlatformSettings(snapshot.config).telegram});
const signed=()=>{
  const params=new URLSearchParams({auth_date:String(Math.floor(Date.now()/1000)),user:JSON.stringify({id:990001,first_name:'QA',username:'isolated_qa'})});
  const check=[...params].sort(([a],[b])=>a<b?-1:1).map(([k,v])=>`${k}=${v}`).join('\n');
  const key=crypto.createHmac('sha256','WebAppData').update(fixtureToken).digest();params.set('hash',crypto.createHmac('sha256',key).update(check).digest('hex'));return params.toString();
};
const allowed=new Set(['http://127.0.0.1:5175','http://localhost:5175']);
const server=http.createServer(async(req,res)=>{
  res.setHeader('Content-Type','application/json;charset=utf-8');res.setHeader('Cache-Control','no-store');
  try{
    if(req.headers.origin&&!allowed.has(req.headers.origin))throw Object.assign(Error(),{code:'origin_denied',status:403});
    if(req.method==='GET'&&req.url==='/qa-session'){res.end(JSON.stringify({initData:signed(),fixture:true}));return;}
    if(req.method==='GET'&&req.url==='/qa-health'){res.end(JSON.stringify({ok:true,kind:'isolated-fixture',database:'in-memory-pglite',realBot:false}));return;}
    if(req.method!=='POST'||req.url!=='/qa-api')throw Object.assign(Error(),{code:'not_found',status:404});
    const chunks=[];let size=0;for await(const c of req){size+=c.length;if(size>12*1024*1024)throw Object.assign(Error(),{code:'body_too_large',status:413});chunks.push(c);}
    const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
    const raw=req.headers.authorization?.match(/^tma (.+)$/)?.[1];res.end(JSON.stringify(await api(raw,body)));
  }catch(e){res.statusCode=Number.isInteger(e.status)?e.status:503;res.end(JSON.stringify({ok:false,error:e.code??'service_unavailable',...(e.retryAfterMs?{retryAfterMs:e.retryAfterMs}:{})}));}
});
server.listen(4181,'127.0.0.1',()=>console.log('Isolated QA API ready on loopback :4181. No real bot/payments/production data.'));
async function close(){server.close();await local.close();process.exit(0);}
process.on('SIGINT',close);process.on('SIGTERM',close);
