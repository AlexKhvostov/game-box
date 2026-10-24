import {handler,database,credentials,env} from '../_shared/runtime.mjs';
import {createRemoteConfig} from '../_shared/remote-config.mjs';
import {createConfigAdmin} from '../_shared/config-admin.mjs';
let execute;
Deno.serve(handler(async ({user,body})=>{
  const telegramStarsAccepted=env('TELEGRAM_STARS_ACCEPTED')==='true';
  execute??=createConfigAdmin({db:database(),remote:createRemoteConfig({credentials:credentials('FIREBASE_SERVICE_ACCOUNT_JSON'),telegramStarsAccepted}),telegramStarsAccepted});
  return execute(user.id,body);
},{admin:true}));
