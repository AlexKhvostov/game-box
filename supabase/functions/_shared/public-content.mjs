import {hash,requireThat} from './core/policy.mjs';

export const communityRulesVersion=1;
export const reportReasons=['offensive_name','personal_data','impersonation','other'];
const uuid=/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/;
export function requirePublicWords(value){
  const words=(typeof value==='string'?value:'').normalize('NFC').toLocaleLowerCase('ru').split(/[^\p{L}\p{N}]+/u);
  requireThat(!words.some(w=>['fuck','bitch','nigger','хуй','пизда','блядь','ебать'].includes(w)),'nickname_prohibited',400);
}
export function publicNickname(value){
  const name=typeof value==='string'?value.trim().normalize('NFC'):'';
  requireThat([...name].length>=2&&[...name].length<=24&&!/[\p{C}<>]/u.test(name),'nickname_invalid',400);
  requirePublicWords(name);
  return name;
}
export function requireCommunityRules(p){
  requireThat(p.communityRulesVersion===communityRulesVersion,'community_rules_required',409);
}

// These actions only affect public names. They never change a score, a place,
// a wallet or the target player's ability to play, sign in or rename themselves.
export async function publicContentAction({db,tx,p,input,stamp,put}){
  if(input.action==='public_names_reset'){p.hiddenPlayers=[];return{};}
  if(input.action==='public_rules_accept'){
    requireThat(input.version===communityRulesVersion,'community_rules_invalid',400);
    p.communityRulesVersion=communityRulesVersion;p.communityRulesAcceptedAt=stamp;return{};
  }
  const target=typeof input.target==='string'?input.target.replace(/^supabase:/,''):'';
  requireThat(uuid.test(target)&&target!==p.uid,'public_target_invalid',400);
  if(input.action==='public_name_hide'){
    requireThat(typeof input.hide==='boolean','operation_invalid',400);
    const hidden=new Set(p.hiddenPlayers??[]);
    if(input.hide){requireThat(hidden.size<200||hidden.has(target),'hidden_names_limit',409);hidden.add(target);}
    else hidden.delete(target);
    p.hiddenPlayers=[...hidden];return{};
  }
  requireThat(input.action==='public_name_report'&&reportReasons.includes(input.reason),'report_reason_invalid',400);
  const targetRef=db.collection('players').doc(target),snapshot=await tx.get(targetRef),profile=snapshot.data();
  requireThat(profile&&!profile.supportDisabled,'player_not_found',404);
  const content={nickname:profile.nickname,googleName:profile.hideGoogleAccount?null:profile.publicGoogleName??null};
  const fingerprint=hash(content),key=hash({reporter:p.uid,target,fingerprint});
  const ref=db.collection('publicReports').doc(key),previous=await tx.get(ref);
  if(previous.exists)return{reportReceived:true,replayed:true};
  const day=new Date(stamp).toISOString().slice(0,10);
  const count=p.publicReportsDay?.day===day?p.publicReportsDay.count:0;
  requireThat(count<20,'reports_daily_limit',429);
  p.publicReportsDay={day,count:count+1};
  put(ref,{reporterUid:p.uid,targetUid:target,content,fingerprint,reason:input.reason,status:'pending',createdAt:stamp});
  return{reportReceived:true,replayed:false};
}

export function maskViewerNames(value,hiddenPlayers=[]){
  const hidden=new Set(hiddenPlayers.map(uid=>`supabase:${uid}`));
  function visit(v){
    if(Array.isArray(v))return v.map(visit);
    if(!v||typeof v!=='object')return v;
    const result=Object.fromEntries(Object.entries(v).map(([k,item])=>[k,visit(item)]));
    if(hidden.has(v.userId)){
      if(Object.hasOwn(v,'playerName'))result.playerName='Скрытое имя';
      if(Object.hasOwn(v,'nickname'))result.nickname='Скрытое имя';
      if(Object.hasOwn(v,'googleName'))result.googleName=null;
    }
    return result;
  }
  return visit(value);
}
