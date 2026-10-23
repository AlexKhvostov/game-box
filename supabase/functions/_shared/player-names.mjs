import {hash,requireThat} from './core/policy.mjs';
import {publicNickname} from './public-content.mjs';

export function accountNickname(identity) {
  const raw=identity.platform==='telegram'&&identity.telegramVerified===true?identity.username:
    identity.googleLinked===true&&typeof identity.email==='string'?identity.email.split('@')[0]:null;
  if(typeof raw!=='string')return null;
  try{return publicNickname([...raw.replace(/^@/,'').replace(/[\p{C}<>]/gu,'').trim()].slice(0,24).join(''));}catch{return null;}
}
export function fallbackNickname(uid,attempt=0) {
  const suffix=parseInt(hash(`player:${uid}:${attempt}`).slice(0,8),16).toString(36).padStart(7,'0');
  return `player-${suffix.slice(-3)}`;
}
// Called inside the existing serializable player transaction; reservations are
// written with the player and never overwrite another player's public name.
export async function reservePlayerName({db,tx,p,identity,put,newPlayer=false}) {
  const account=accountNickname(identity);
  if(!newPlayer&&!(p.nicknameSource==='fallback'&&!p.hasEverStarted&&
    (p.wallet.gamesStarted??0)===0&&(p.completedGames??0)===0&&account))return;
  for(let attempt=0;attempt<96;attempt++){
    const suffix=fallbackNickname(p.uid,attempt).split('-')[1];
    const candidate=account?(attempt===0?account:`${[...account].slice(0,23-suffix.length).join('')}-${suffix}`):fallbackNickname(p.uid,attempt);
    let name;try{name=publicNickname(candidate);}catch{continue;}
    const ref=db.collection('names').doc(hash(name.toLocaleLowerCase('ru'))),old=await tx.get(ref);
    if(old.exists&&old.data().uid!==p.uid)continue;
    if(p.nameKey&&p.nameKey!==ref.id)put(db.collection('names').doc(p.nameKey),null);
    p.nickname=name;p.nameKey=ref.id;p.nicknameSource=account?'account':'fallback';put(ref,{uid:p.uid});return;
  }
  // Existing names remain usable if a linked account's candidates are crowded.
  requireThat(!newPlayer,'nickname_unavailable',503);
}
