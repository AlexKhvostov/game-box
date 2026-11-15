import {shareInvitationBadge} from './share-invitation.ts';
import type {ShareCardData} from '../services/share-card';
export interface PublicShareDownload {v:1;time:number;risk:number;steps:number;locale:'ru'|'en';code:string;textScale:number}
const keys=['v','time','risk','steps','locale','code','textScale'];
function valid(value:unknown):PublicShareDownload {
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('share_download_invalid');
 const o=value as Record<string,unknown>;
 if(Object.keys(o).length!==keys.length||Object.keys(o).some(k=>!keys.includes(k))||o.v!==1||!['ru','en'].includes(o.locale as string)||typeof o.code!=='string'||!/^(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})$/.test(o.code))throw Error('share_download_invalid');
 for(const [key,max] of [['time',359999999],['risk',1000000000],['steps',1000000000]] as const)if(!Number.isSafeInteger(o[key])||(o[key] as number)<0||(o[key] as number)>max)throw Error('share_download_invalid');
 if(typeof o.textScale!=='number'||!Number.isFinite(o.textScale)||o.textScale<.5||o.textScale>2.5)throw Error('share_download_invalid');
 return o as unknown as PublicShareDownload;
}
/** Explicit projection: identity, referral targets and session fields never enter the URL. */
export function publicShareDownload(data:ShareCardData):PublicShareDownload {
 return valid({v:1,time:data.timeMs,risk:data.riskCount,steps:data.steps,locale:data.locale,code:data.invitation?.code,textScale:data.textScale??1});
}
export function shareDownloadUrl(data:ShareCardData,pageUrl:string){
 const url=new URL('/share-download.html',pageUrl);
 if(!['http:','https:'].includes(url.protocol)||url.username||url.password)throw Error('share_download_invalid');
 url.search='';url.hash=encodeURIComponent(JSON.stringify(publicShareDownload(data)));return url.href;
}
export function decodeShareDownload(fragment:string):PublicShareDownload {
 if(fragment.length>2048||!fragment.startsWith('#'))throw Error('share_download_invalid');
 const raw=decodeURIComponent(fragment.slice(1));if(raw.length>1024)throw Error('share_download_invalid');
 return valid(JSON.parse(raw));
}
export function downloadCardData(data:PublicShareDownload):ShareCardData {
 const d=valid(data);return{timeMs:d.time,riskCount:d.risk,steps:d.steps,locale:d.locale,textScale:d.textScale,invitation:shareInvitationBadge(d.code,d.locale)};
}
export function sharePngName(timeMs:number){return `untouch-${(timeMs/1000).toFixed(3)}.png`;}
