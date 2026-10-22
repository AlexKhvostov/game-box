import type {AttemptHistorySnapshot, ServerAttempt} from '../services/contracts.ts';

export type HistoryState = {snapshot: AttemptHistorySnapshot | null; loading: boolean; error: string};
type Storage = {get<T>(key:string,fallback:T):T;set(key:string,value:unknown):void};
const validNumber=(v:unknown)=>typeof v==='number'&&Number.isFinite(v)&&v>=0;
function validRow(r:ServerAttempt){return r&&typeof r.id==='string'&&r.id.length>0&&Number.isSafeInteger(r.number)&&r.number>0&&validNumber(r.timeMs)&&validNumber(r.createdAt)&&validNumber(r.runDistance)&&validNumber(r.riskCount)&&typeof r.hadJump==='boolean'&&typeof r.hadHelmet==='boolean'&&(r.averageMs===null||validNumber(r.averageMs))&&typeof r.included==='boolean'&&Number.isSafeInteger(r.windowCount)&&r.windowCount>=0;}
const averageKey=(snapshot:AttemptHistorySnapshot)=>{const a=snapshot.average;return JSON.stringify({rules:a.rules,averageMs:a.mine.averageMs,usedCount:a.mine.usedCount,eligibleCount:a.mine.eligibleCount,totalAttempts:a.mine.totalAttempts});};
export function validateHistory(value:unknown,owner:string):AttemptHistorySnapshot {
  const v=value as AttemptHistorySnapshot,h=v?.history,a=v?.average;
  if(!h||h.userId!==owner||!h.snapshot||typeof h.snapshot!=='string'||!Number.isSafeInteger(h.totalCount)||h.totalCount<0||!Array.isArray(h.rows)||h.rows.length>h.totalCount||!(h.nextCursor===null||typeof h.nextCursor==='string'&&h.nextCursor.length>0)||!a?.rules||a.mine?.userId!==owner||!(a.mine.averageMs===null||validNumber(a.mine.averageMs))||a.mine.totalAttempts!==h.totalCount||h.rows.some(r=>!validRow(r))||h.best!==null&&!validRow(h.best))throw new Error('attempt_history_invalid');
  const rules=a.rules;
  if(typeof rules.algorithm!=='string'||!rules.algorithm||!Number.isSafeInteger(rules.windowSize)||rules.windowSize<1||!validNumber(rules.previousWeightPercent)||rules.previousWeightPercent>100||!Number.isSafeInteger(rules.minAttempts)||rules.minAttempts<0||!validNumber(rules.minDurationMs)||!Number.isSafeInteger(a.mine.usedCount)||a.mine.usedCount<0||a.mine.usedCount>h.totalCount||h.best&&h.best.number>h.totalCount)throw new Error('attempt_history_invalid');
  const ids=new Set<string>(),numbers=new Set<number>();
  for(let i=0;i<h.rows.length;i++){
    const row=h.rows[i],previous=h.rows[i-1];
    if(ids.has(row.id)||numbers.has(row.number)||row.number>h.totalCount||previous&&(previous.number!==row.number+1||previous.createdAt<row.createdAt))throw new Error('attempt_history_invalid');
    ids.add(row.id);numbers.add(row.number);
  }
  if(h.totalCount>0&&!h.rows.length||h.nextCursor===null&&h.rows.length&&h.rows.at(-1)!.number!==1)throw new Error('attempt_history_invalid');
  return structuredClone({average:a,history:h});
}

/** Separate, owner-bound read cache: it never modifies the durable result outbox. */
export class ServerHistoryLoader {
  value:HistoryState={snapshot:null,loading:false,error:''};
  private owner='';private epoch=0;private flight:Promise<void>|null=null;private retryMore=false;
  private fetchPage:(body:Record<string,unknown>)=>Promise<unknown>;private changed:(value:HistoryState)=>void;private storage?:Storage;
  constructor(fetchPage:(body:Record<string,unknown>)=>Promise<unknown>,changed:(value:HistoryState)=>void,storage?:Storage){this.fetchPage=fetchPage;this.changed=changed;this.storage=storage;}
  private emit(){this.changed({...this.value});}
  setOwner(owner:string){if(owner===this.owner)return;this.owner=owner;this.epoch++;this.flight=null;this.value={snapshot:null,loading:false,error:''};
    if(owner)try{const cached=this.storage?.get<unknown>(`attempt-history:v1:${owner}`,null);if(cached)this.value.snapshot=validateHistory(cached,owner);}catch{/* Cache errors never block a fresh read. */}this.emit();}
  refresh(){return this.load(false);}
  more(){return this.load(true);}
  retry(){return this.load(this.retryMore);}
  invalidate(preserve=false){this.epoch++;this.flight=null;this.value={snapshot:preserve?this.value.snapshot:null,loading:false,error:''};this.emit();}
  private load(more:boolean):Promise<void>{
    if(!this.owner)return Promise.resolve();if(this.flight)return this.flight;
    const current=this.value.snapshot,cursor=more?current?.history.nextCursor:null;
    if(more&&!cursor)return Promise.resolve();
    const owner=this.owner,epoch=this.epoch,active=()=>owner===this.owner&&epoch===this.epoch;
    this.retryMore=more;
    this.value={...this.value,loading:true,error:''};this.emit();
    const work=(async()=>{try{
      let response:unknown,restarted=false;
      try{response=await this.fetchPage({action:'attempts_history',limit:cursor?200:100,...(cursor?{cursor}:{})});}
      catch(error){if(!active())return;if(cursor&&error instanceof Error&&['attempt_history_changed','attempt_history_cursor_invalid'].includes(error.message)){restarted=true;response=await this.fetchPage({action:'attempts_history',limit:100});}else throw error;}
      if(!active())return;
      const page=validateHistory(response,owner);
      if((!cursor||restarted)&&page.history.rows.length&&page.history.rows[0]!.number!==page.history.totalCount)throw new Error('attempt_history_invalid');
      if(cursor&&!restarted&&page.history.snapshot===current!.history.snapshot){
        if(averageKey(page)!==averageKey(current!)||page.history.totalCount!==current!.history.totalCount)throw new Error('attempt_history_invalid');
        if(page.history.rows.length&&page.history.rows[0]!.number!==current!.history.rows.at(-1)!.number-1)throw new Error('attempt_history_invalid');
        const merged=new Map([...current!.history.rows,...page.history.rows].map(r=>[r.id,r]));
        page.history.rows=[...merged.values()].sort((a,b)=>b.number-a.number);
        validateHistory(page,owner);
      }else if(cursor&&page.history.rows[0]?.number!==page.history.totalCount&&page.history.totalCount)throw new Error('attempt_history_changed');
      this.value={snapshot:page,loading:false,error:''};
      // Keep disk cache bounded to the fresh first page. Large histories stay
      // in memory so they cannot consume the journal's localStorage quota.
      if(!cursor||restarted)try{this.storage?.set(`attempt-history:v1:${owner}`,page);}catch{/* Optional cache does not affect gameplay storage. */}
    }catch(error){if(active())this.value={...this.value,loading:false,error:error instanceof Error?error.message:'attempt_history_failed'};}
    finally{if(active()){this.flight=null;this.emit();}}})();this.flight=work;return work;
  }
}
