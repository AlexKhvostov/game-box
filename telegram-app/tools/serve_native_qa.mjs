// Actual Telegram auth against an isolated in-memory database. No fixture
// session endpoint, production database, ads, purchases or incoming webhook.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {testDatabase} from '../../supabase/test/database.mjs';
import {PostgresStore} from '../../supabase/functions/_shared/postgres-store.mjs';
import {createEngine} from '../../supabase/functions/_shared/core/engine.mjs';
import {createTelegramIdentityResolver} from '../../supabase/functions/_shared/telegram-auth.mjs';
import {createTelegramApi} from '../../supabase/functions/_shared/telegram-api.mjs';
import {initialPlatformSettings} from '../../supabase/functions/_shared/platform-config-schema.mjs';
import {validatePolicy,requireThat} from '../../supabase/functions/_shared/core/policy.mjs';
const root=path.resolve(import.meta.dirname,'../..'),site=path.resolve(process.env.UNTOUCH_QA_SITE??''),origin=process.env.UNTOUCH_QA_ORIGIN??'',token=process.env.UNTOUCH_QA_BOT_TOKEN??'';
requireThat(site.startsWith(path.join(root,'releases')+path.sep)&&/^https:\/\/(?:[A-Za-z0-9-]+\.trycloudflare\.com|[a-f0-9]+\.lhr\.life)$/.test(origin)&&/^\d+:[A-Za-z0-9_-]+$/.test(token),'qa_configuration_invalid',503);
const local=await testDatabase();
for(const name of ['20261019205914_android_average_ranking_cache.sql','20261019223954_telegram_platform_core.sql'])await local.pg.exec(await fs.readFile(path.join(root,'supabase/migrations',name),'utf8'));
const policy=validatePolicy(JSON.parse(await fs.readFile(path.join(root,'telegram-app/src/generated/android-config.json'),'utf8'))),db=new PostgresStore(local.pool),engine=createEngine({db,getPolicy:async()=>policy});
const resolve=createTelegramIdentityResolver({pool:local.pool,botToken:token});let allowedUid=null;
const api=createTelegramApi({engine,platformConfig:async()=>initialPlatformSettings(policy.config).telegram,resolveIdentity:async raw=>{
  const identity=await resolve(raw);allowedUid??=identity.uid;requireThat(allowedUid===identity.uid,'qa_account_locked',403);return identity;
}});
const types={'.html':'text/html;charset=utf-8','.js':'application/javascript','.css':'text/css','.json':'application/json','.svg':'image/svg+xml','.png':'image/png','.wav':'audio/wav','.woff2':'font/woff2'};
let requests=0,windowStarted=Date.now();
const server=http.createServer(async(req,res)=>{
  res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');
  try{
    if(Date.now()-windowStarted>60000){requests=0;windowStarted=Date.now();}requireThat(++requests<=240,'qa_rate_limit',429);
    if(req.url==='/healthz'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({ok:true,qa:true,actualTelegramAuth:true,fixture:false,payments:false,ads:false,isolatedDatabase:true}));return;}
    if(req.url==='/telegram-api'){
      requireThat(req.method==='POST'&&req.headers.origin===origin,'origin_denied',403);
      let size=0;const chunks=[];for await(const c of req){size+=c.length;requireThat(size<=12*1024*1024,'body_too_large',413);chunks.push(c);}
      let body;try{body=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{requireThat(false,'input_invalid',400);}
      const raw=req.headers.authorization?.match(/^tma (.+)$/)?.[1];
      const result=await api(raw,body);res.setHeader('Content-Type','application/json');res.end(JSON.stringify(result));return;
    }
    requireThat(req.method==='GET'||req.method==='HEAD','method_invalid',405);
    const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname),file=path.resolve(site,pathname==='/'?'index.html':'.'+pathname);
    requireThat(file.startsWith(site+path.sep)&&types[path.extname(file)]&&!pathname.split('/').some(p=>p.startsWith('.')),'not_found',404);
    const data=await fs.readFile(file);res.setHeader('Content-Type',types[path.extname(file)]);res.end(req.method==='HEAD'?undefined:data);
  }catch(error){res.statusCode=Number.isInteger(error.status)?error.status:error.code==='ENOENT'?404:503;res.setHeader('Content-Type','application/json');res.end(JSON.stringify({ok:false,error:Number.isInteger(error.status)?error.code:res.statusCode===404?'not_found':'service_unavailable',...(error.retryAfterMs?{retryAfterMs:error.retryAfterMs}:{})}));}
});
server.listen(4182,'127.0.0.1',()=>console.log('Native QA ready :4182; real Telegram auth, isolated DB, one QA account, no payments/ads/fixture sessions.'));
async function close(){server.close();await local.close();process.exit(0);}process.on('SIGINT',close);process.on('SIGTERM',close);
