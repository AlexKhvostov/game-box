import {handler,database,authAdmin} from '../_shared/runtime.mjs';
import {createSupportAdmin} from '../_shared/support-admin.mjs';
let execute;
Deno.serve(handler(async ({user,body})=>{
  execute??=createSupportAdmin({db:database(),auth:authAdmin().auth.admin});
  return execute(user.id,body);
},{admin:true}));
