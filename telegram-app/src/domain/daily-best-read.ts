// Compact public read only: never accepts a profile, wallet or award checkpoint.
export const DAILY_BEST_TTL_MS=60000;
export const utcDay=(stamp:number)=>new Date(stamp).toISOString().slice(0,10);
export interface DailyBestState {owner:string;day:string;timeMs:number|null;loading:boolean;attempted:boolean;error:string;updatedAt:number|null}
export const emptyDailyBest=(owner='',day=utcDay(Date.now())):DailyBestState=>({owner,day,timeMs:null,loading:false,attempted:false,error:'',updatedAt:null});
export class DailyBestRead {
 private value:DailyBestState;
 private serial=0;
 private disposed=false;
 private flight?:Promise<void>;
 private read:()=>Promise<unknown>;private publish:(state:DailyBestState)=>void;private allowed:()=>boolean;private clock:()=>number;
 constructor(read:()=>Promise<unknown>,publish:(state:DailyBestState)=>void,allowed:()=>boolean,clock=()=>Date.now()) {this.read=read;this.publish=publish;this.allowed=allowed;this.clock=clock;this.value=emptyDailyBest('',utcDay(clock()));}
 get revision(){return this.serial;}
 setOwner(owner:string){if(this.disposed||this.value.owner===owner)return;this.serial++;this.flight=undefined;this.set(emptyDailyBest(owner,utcDay(this.clock())));}
 private set(value:DailyBestState){this.value=value;this.publish({...value});}
 observeDay(){if(this.disposed)return false;const day=utcDay(this.clock());if(day===this.value.day)return false;this.serial++;this.flight=undefined;this.set(emptyDailyBest(this.value.owner,day));return true;}
 refresh(force=false):Promise<void>{
  if(this.disposed)return Promise.resolve();this.observeDay();
  if(!this.value.owner||!this.allowed())return Promise.resolve();
  if(this.flight)return this.flight;
  const stamp=this.clock(),last=this.value.updatedAt;
  if(!force&&!this.value.error&&last!==null&&stamp>=last&&stamp-last<DAILY_BEST_TTL_MS)return Promise.resolve();
  const owner=this.value.owner,day=this.value.day,serial=++this.serial;
  const current=()=>!this.disposed&&serial===this.serial&&owner===this.value.owner&&day===utcDay(this.clock());
  this.set({...this.value,loading:true,error:''});
  let operation:Promise<void>,started=false;
  operation=Promise.resolve().then(()=>{if(current()&&this.allowed()){started=true;return this.read();}return undefined;}).then(raw=>{
   if(!started||!current())return;
   const reply=raw as {ok?:unknown;timeMs?:unknown;day?:unknown;serverNow?:unknown};
   if(!reply||reply.ok!==true||typeof reply.day!=='string'||reply.day!==day||!Number.isSafeInteger(reply.serverNow)||Number(reply.serverNow)<0||utcDay(Number(reply.serverNow))!==reply.day||(reply.timeMs!==null&&(!Number.isSafeInteger(reply.timeMs)||Number(reply.timeMs)<=0)))throw Error('daily_best_invalid');
   this.set({...this.value,timeMs:reply.timeMs as number|null,attempted:true,error:'',updatedAt:stamp});
  }).catch(error=>{if(current())this.set({...this.value,attempted:true,error:error instanceof Error?error.message:String(error),updatedAt:null});}).finally(()=>{
   if(this.flight!==operation)return;this.flight=undefined;
   if(current())this.set({...this.value,loading:false});
   // A request crossing midnight cannot leave yesterday's result/loading behind.
   else if(!this.disposed&&owner===this.value.owner&&this.observeDay()&&this.allowed())void this.refresh();
  });
  this.flight=operation;return operation;
 }
 reuseRanking(timeMs:number|null,day:string,revision:number,startedAt=this.clock()){
  if(this.disposed||revision!==this.serial||!this.value.owner||day!==utcDay(this.clock())||(timeMs!==null&&(!Number.isSafeInteger(timeMs)||timeMs<=0)))return false;
  this.serial++;this.flight=undefined;this.set({owner:this.value.owner,day,timeMs,loading:false,attempted:true,error:'',updatedAt:startedAt});return true;
 }
 dispose(){this.disposed=true;this.serial++;this.flight=undefined;this.set({...this.value,loading:false});}
}
