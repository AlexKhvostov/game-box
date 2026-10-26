import type {JsonStorage} from '../services/storage';
export interface InviteRewardNotice {id:string;role:'inviter'|'invitee';amount:number;friendId?:string|null;friendName?:string|null}
const validId=(id:unknown):id is string=>typeof id==='string'&&/^[a-f0-9]{64}$/.test(id);
export function parseInviteRewards(raw:unknown):InviteRewardNotice[]{
  if(!Array.isArray(raw))return[];
  const ids=new Set<string>();
  return raw.filter((n):n is InviteRewardNotice=>!!n&&validId(n.id)&&['inviter','invitee'].includes(n.role)&&Number.isSafeInteger(n.amount)&&n.amount>=0&&n.amount<=100000&&!ids.has(n.id)&&!!ids.add(n.id));
}
/** Seen/presented/pending ACK are independent of money and scoped by bot+owner. */
export class InviteRewardJournal {
  private value:{seen:string[];presented:string[];pending:string[]};
  private key:string;
  private storage:JsonStorage;
  constructor(storage:JsonStorage,namespace:string,owner:string){
    this.storage=storage;
    this.key=`invite-rewards:v1:${namespace}:${owner}`;
    const raw=storage.get<any>(this.key,{});
    const list=(name:string):string[]=>Array.isArray(raw?.[name])?[...new Set<string>(raw[name].filter(validId))]:[];
    this.value={seen:list('seen'),presented:list('presented'),pending:list('pending')};
  }
  get pending(){return [...this.value.pending];}
  seen(id:string){return this.value.seen.includes(id);}
  presented(id:string){return this.value.presented.includes(id);}
  private change(id:string,kind:'seen'|'presented'|'confirmed'){
    if(!validId(id))throw Error('invite_reward_invalid');
    const next=structuredClone(this.value);
    const add=(key:'seen'|'presented'|'pending')=>{if(!next[key].includes(id))next[key].push(id);};
    if(kind==='seen'){add('seen');add('presented');add('pending');}
    else if(kind==='presented')add('presented');else next.pending=next.pending.filter(v=>v!==id);
    this.storage.set(this.key,next);this.value=next;
  }
  acknowledge(id:string){this.change(id,'seen');}
  markPresented(id:string){this.change(id,'presented');}
  confirm(id:string){this.change(id,'confirmed');}
}
