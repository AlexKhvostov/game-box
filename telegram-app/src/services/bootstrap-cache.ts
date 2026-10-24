import type {Profile,GameConfig,PlatformConfig} from './contracts';
import type {JsonStorage} from './storage';
export interface OfflineIdentity {botId:string;subject:string;environment:'production'}
export interface Bootstrap {version:1;namespace:string;profile:Profile;config:GameConfig;platform:PlatformConfig|null;identity:OfflineIdentity|null;sessionHash:string;receivedAt:number}
const maxAge=86400000,encoder=new TextEncoder();
// Telegram production Ed25519 public key, not a bot credential.
// https://core.telegram.org/bots/webapps#validating-data-for-third-party-use
const publicKey='e7bf03a2fa4602af4580703d88dda5bb59f32ed8b02a56c187fe7d34caed242d';
export async function sessionHash(raw:string){return [...new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(raw)))].map(b=>b.toString(16).padStart(2,'0')).join('');}
export async function validTelegramSession(raw:string,identity:OfflineIdentity,serverTime:number):Promise<boolean>{
  try{
    if(raw.length>16000||!/^\d{5,15}$/.test(identity.botId)||identity.environment!=='production')return false;
    const params=new URLSearchParams(raw),seen=new Set();
    for(const[key]of params){if(seen.has(key)||!/^[a-z_]+$/.test(key))return false;seen.add(key);}
    const at=Number(params.get('auth_date'))*1000,user=JSON.parse(params.get('user')??'null');
    if(!Number.isSafeInteger(at)||at<serverTime-maxAge||at>serverTime+30000||!Number.isSafeInteger(user?.id)||user.id<=0||user.is_bot===true||String(user.id)!==identity.subject)return false;
    const text=params.get('signature')??'';if(!/^[A-Za-z0-9_-]{86}={0,2}$/.test(text))return false;
    const signature=Uint8Array.from(atob(text.replace(/-/g,'+').replace(/_/g,'/').padEnd(88,'=')),c=>c.charCodeAt(0));
    params.delete('hash');params.delete('signature');
    const check=`${identity.botId}:WebAppData\n`+[...params.entries()].sort(([a],[b])=>a<b?-1:a>b?1:0).map(([k,v])=>`${k}=${v}`).join('\n');
    const key=await crypto.subtle.importKey('raw',Uint8Array.from(publicKey.match(/../g)!,b=>parseInt(b,16)),{name:'Ed25519'},false,['verify']);
    return await crypto.subtle.verify('Ed25519',key,signature,encoder.encode(check));
  }catch{return false;}
}
export async function readBootstrap(storage:JsonStorage,raw:string,namespace:string,wallTime=Date.now()):Promise<Bootstrap|null>{
  let cached:Bootstrap|null;
  try{cached=storage.get<Bootstrap|null>('bootstrap:v1',null);if(storage.get<string|null>('bootstrap-revoked:v1',null)===namespace)return null;}catch{return null;}
  if(!cached||cached.version!==1||cached.namespace!==namespace||!raw||!Number.isFinite(cached.receivedAt)||!Number.isFinite(cached.profile?.serverNow)||wallTime<cached.receivedAt-30000||wallTime-cached.receivedAt>maxAge)return null;
  if(!/^supabase:[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(cached.profile.id)||cached.profile.platform!=='telegram'||!cached.profile.telegramVerified||!Number.isSafeInteger(cached.profile.walletVersion)||!Number.isSafeInteger(cached.profile.wallet?.energy)||!cached.config?.ok||!/^[a-f0-9]{64}$/.test(cached.config.revision)||!cached.config.config?.economy?.androidEnergyV2)return null;
  const c=cached.config.config,w=cached.profile.wallet,e=w.energyConfig;
  if(cached.profile.walletVersion<0||w.energy<0||!e||![e.baseAttemptCost,e.helmetExtraCost,e.jumpExtraCost].every(n=>Number.isSafeInteger(n)&&n>=0)||e.baseAttemptCost<1||!w.simpleBonus?.policy||!w.adQuota||!Array.isArray(w.claimed))return null;
  if(!['player','field','enemies','game','mobileEnemies','economy'].every(k=>c[k]&&typeof c[k]==='object')||!Number.isFinite(c.player.size)||c.player.size<=0||!Number.isFinite(c.field.borderWidth)||!Number.isFinite(c.economy.runRewardEvery)||c.economy.runRewardEvery<=0||!Number.isFinite(c.economy.riskRewardEvery)||c.economy.riskRewardEvery<=0||!Array.isArray(c.enemies.aspects))return null;
  const serverTime=cached.profile.serverNow+Math.max(0,wallTime-cached.receivedAt);
  if(await sessionHash(raw)===cached.sessionHash){const at=Number(new URLSearchParams(raw).get('auth_date'))*1000;if(Number.isSafeInteger(at)&&at>=serverTime-maxAge&&at<=serverTime+30000)return cached;return null;}
  return cached.identity&&await validTelegramSession(raw,cached.identity,serverTime)?cached:null;
}
