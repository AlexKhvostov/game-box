import {requireThat} from './core/policy.mjs';
// Direct Bot API. Token never enters a browser, log, exception text or proxy.
export function createTelegramBot({token,fetchImpl=fetch}){
  const methods=new Set(['createInvoiceLink','answerPreCheckoutQuery','editUserStarSubscription','sendMessage']);
  return async(method,body,{timeoutMs=8000}={})=>{
    requireThat(methods.has(method)&&/^\d+:[A-Za-z0-9_-]+$/.test(token),'telegram_service_unavailable',503);
    let response,data;try{response=await fetchImpl(`https://api.telegram.org/bot${token}/${method}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(Math.min(8000,timeoutMs))});data=await response.json();}catch{requireThat(false,'telegram_service_unavailable',503);}
    requireThat(response.ok&&data?.ok===true,'telegram_service_unavailable',503);return data.result;
  };
}
