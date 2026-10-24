import crypto from 'node:crypto';
import {Buffer} from 'node:buffer';
import {requireThat} from './core/policy.mjs';

// Telegram's HMAC validation: https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
// The trusted UID is resolved server-side, never accepted from a request body.
export function verifyTelegramInitData(raw,botToken,{now=Date.now,maxAgeSec=86400}={}){
  requireThat(typeof botToken==='string'&&/^\d{5,15}:[A-Za-z0-9_-]{20,}$/.test(botToken),'telegram_not_configured',503);
  requireThat(typeof raw==='string'&&raw.length>0&&raw.length<=16000,'telegram_unauthorized',401);
  const params=new URLSearchParams(raw),seen=new Set();
  for(const [key]of params){requireThat(!seen.has(key)&&/^[a-z_]+$/.test(key),'telegram_unauthorized',401);seen.add(key);}
  const supplied=params.get('hash');requireThat(/^[a-f0-9]{64}$/.test(supplied??''),'telegram_unauthorized',401);
  params.delete('hash');
  const check=[...params.entries()].sort(([a],[b])=>a<b?-1:a>b?1:0).map(([k,v])=>`${k}=${v}`).join('\n');
  const secret=crypto.createHmac('sha256','WebAppData').update(botToken).digest();
  const expected=crypto.createHmac('sha256',secret).update(check).digest();
  requireThat(crypto.timingSafeEqual(expected,Buffer.from(supplied,'hex')),'telegram_unauthorized',401);
  const at=Number(params.get('auth_date')),stamp=Math.floor(now()/1000);
  requireThat(/^\d{1,12}$/.test(params.get('auth_date')??'')&&Number.isSafeInteger(at)&&at<=stamp+30&&at>=stamp-maxAgeSec,'telegram_session_expired',401);
  let user;try{user=JSON.parse(params.get('user')??'null');}catch{}
  requireThat(user&&Number.isSafeInteger(user.id)&&user.id>0&&user.is_bot!==true,'telegram_unauthorized',401);
  return {subject:String(user.id),botId:botToken.split(':')[0],username:typeof user.username==='string'?user.username.slice(0,64):null,
    displayName:[user.first_name,user.last_name].filter(v=>typeof v==='string').join(' ').slice(0,200),
    language:typeof user.language_code==='string'?user.language_code.slice(0,20):null,
    startParam:params.get('start_param')??null,authenticatedAt:at*1000};
}

export function createTelegramIdentityResolver({pool,botToken,additionalBotTokens=[],now=Date.now}){
  const tokens=[...new Set([botToken,...additionalBotTokens].filter(Boolean))];
  return async raw=>{
    let data,lastError;
    for(const token of tokens){
      try{data=verifyTelegramInitData(raw,token,{now});break;}
      catch(error){if(error.code==='telegram_session_expired')throw error;lastError=error;}
    }
    if(!data){if(lastError)throw lastError;requireThat(false,'telegram_not_configured',503);}
    // Private provider mapping has no password/email and is independent of Google Auth.
    // Each bot owns a separate mapping. A matching Telegram user ID alone must
    // never reuse the wallet, score history or name of another bot's account.
    const result=await pool.query(`insert into untouch.external_identities(provider,subject,uid,username,display_name,bot_id)
      values('telegram',$1,$2,$3,$4,$5) on conflict(provider,subject,bot_id) do update
      set username=excluded.username,display_name=excluded.display_name,updated_at=now()
      where untouch.external_identities.bot_id=excluded.bot_id returning uid`,
      [data.subject,crypto.randomUUID(),data.username,data.displayName,data.botId]);
    requireThat(result.rows[0],'telegram_bot_namespace_invalid',403);
    return {uid:result.rows[0].uid,platform:'telegram',telegramVerified:true,googleLinked:false,
      subject:data.subject,botId:data.botId,username:data.username,name:data.displayName,language:data.language,startParam:data.startParam};
  };
}

// Separate bot accounts must not earn referral rewards by inviting the same
// verified Telegram person through another bot. No username-based matching.
export function createTelegramInviteGuard({pool}){
  return async (identity,rawCode)=>{
    const code=typeof rawCode==='string'?rawCode.trim().toUpperCase():'';
    if(!/^(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})$/.test(code))return;
    const found=await pool.query(`select exists(select 1 from untouch.documents c
      join untouch.external_identities e on e.uid::text=c.body->>'uid'
      where c.parent='inviteCodes' and c.key=$1 and e.provider='telegram' and e.subject=$2) as same_user`,[code,identity.subject]);
    requireThat(!found.rows[0]?.same_user,'invite_self');
  };
}
