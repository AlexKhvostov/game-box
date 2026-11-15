export interface DailyThought {id:string;ru:string;en:string}
export function parseDailyThought(value:unknown):DailyThought|null {
  const q=value as DailyThought;
  return q&&/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}$/.test(q.id)&&[q.ru,q.en].every(t=>typeof t==='string'&&t.trim().length>0&&Array.from(t).length<=240&&!/[<>\x00-\x1f]/.test(t))?{id:q.id,ru:q.ru.trim(),en:q.en.trim()}:null;
}
// Monotonic visible time; background/error time cannot consume reading time.
export class StartupReadingClock {
  private elapsed=0;private since:number|null=null;
  private clock:()=>number;
  constructor(clock:()=>number=()=>performance.now()){this.clock=clock;}
  setActive(active:boolean){this.elapsed=this.visibleMs;this.since=active?this.clock():null;}
  get visibleMs(){return this.elapsed+(this.since===null?0:Math.max(0,this.clock()-this.since));}
  remaining(minimumMs:number){return Math.max(0,Math.max(2000,Math.min(10000,Number.isFinite(minimumMs)?minimumMs:2000))-this.visibleMs);}
}
