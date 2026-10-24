import {env,input,database} from '../_shared/runtime.mjs';
import {gameRuntime} from '../_shared/game-runtime.mjs';
import {createTelegramIdentityResolver,createTelegramInviteGuard} from '../_shared/telegram-auth.mjs';
import {createTelegramApi} from '../_shared/telegram-api.mjs';
import {requireThat} from '../_shared/core/policy.mjs';
import {telegramStarsRuntime} from '../_shared/telegram-stars-runtime.mjs';
let execute;
Deno.serve(async request=>{
  let headers={'Content-Type':'application/json;charset=utf-8','Cache-Control':'no-store',Vary:'Origin'};
  try{
    const origin=request.headers.get('origin'),allowed=env('TELEGRAM_ALLOWED_ORIGINS').split(',').map(v=>v.trim()).filter(Boolean);
    requireThat(!origin||allowed.includes(origin),'origin_denied',403);
    if(origin)headers={...headers,'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'content-type,authorization,apikey','Access-Control-Allow-Methods':'POST,OPTIONS'};
    if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
    requireThat(request.method==='POST','method_invalid',405);
    execute??=createTelegramApi({engine:gameRuntime().engine,platformConfig:()=>gameRuntime().platformSettings('telegram'),stars:telegramStarsRuntime(),miniAppLink:env('TELEGRAM_MAIN_MINIAPP_LINK')||env('TELEGRAM_MINIAPP_LINK'),monetizationBotId:env('TELEGRAM_MAIN_BOT_TOKEN').split(':')[0],
      resolveIdentity:createTelegramIdentityResolver({pool:database(),botToken:env('TELEGRAM_MAIN_BOT_TOKEN')||env('TELEGRAM_BOT_TOKEN'),additionalBotTokens:[env('TELEGRAM_BOT_TOKEN')]}),checkInvite:createTelegramInviteGuard({pool:database()})});
    const raw=request.headers.get('authorization')?.match(/^tma (.+)$/)?.[1];
    const body=await input(request,12*1024*1024);
    const result=await execute(raw,body);
    return new Response(JSON.stringify(result),{headers});
  }catch(error){
    const known=typeof error.code==='string'&&Number.isInteger(error.status);
    if(!known)console.error(JSON.stringify({event:'telegram_request_failed',name:error.name,
      code:typeof error.code==='string'&&/^[A-Za-z0-9_]{1,40}$/.test(error.code)?error.code:undefined,
      frames:typeof error.stack==='string'?error.stack.split('\n').slice(1,3):undefined}));
    return new Response(JSON.stringify({ok:false,error:known?error.code:'service_unavailable',
      ...(known&&error.code==='result_time_invalid'&&Number.isSafeInteger(error.retryAfterMs)?{retryAfterMs:error.retryAfterMs}:{})}),{status:known?error.status:503,headers});
  }
});
