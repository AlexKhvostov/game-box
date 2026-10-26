// Presentation-only port of the approved UI Kit and Android ControlHintMotion.
export const HINT_MOTION_MS=5400, HINT_FADE_MS=350, HINT_REST_MS=5000;
export const HINT_LOOP_MS=HINT_MOTION_MS+HINT_FADE_MS+HINT_REST_MS;
export const HINT_PROGRESS_KEY='untouch_tg_v2:control_hint_lower_starts_v1';
type Point={x:number;y:number};
const points=[[0,0],[55,-35],[-40,-80],[42,-125],[76,-58],[-48,24],[50,80],[-52,54]]
  .map(p=>p.map(v=>v*.8));
const at=(i:number)=>points[(i+points.length)%points.length];
const curves=points.map((p,i)=>{const next=at(i+1),before=at(i-1),after=at(i+2);return[p,
  [p[0]+(next[0]-before[0])*.1,p[1]+(next[1]-before[1])*.1],
  [next[0]-(after[0]-p[0])*.1,next[1]-(after[1]-p[1])*.1],next];});
function onCurve([a,b,c,d]:number[][],t:number):Point{const u=1-t;return{
  x:u*u*u*a[0]+3*u*u*t*b[0]+3*u*t*t*c[0]+t*t*t*d[0],
  y:u*u*u*a[1]+3*u*u*t*b[1]+3*u*t*t*c[1]+t*t*t*d[1]};}
const lengths=curves.map(c=>{let length=0,last=onCurve(c,0);for(let i=1;i<=24;i++){
  const p=onCurve(c,i/24);length+=Math.hypot(p.x-last.x,p.y-last.y);last=p;}return length;});
const length=lengths.reduce((a,b)=>a+b,0);
export const hintPathD='M0 0 '+curves.map(c=>'C'+c.slice(1).map(p=>p.join(' ')).join(' ')).join(' ');
export function hintPose(timeMs:number):Point{
  let distance=(((Number.isFinite(timeMs)?timeMs:0)%HINT_MOTION_MS+HINT_MOTION_MS)%HINT_MOTION_MS)/HINT_MOTION_MS*length;
  for(let i=0;i<curves.length;i++){
    if(distance<=lengths[i]||i===curves.length-1)return onCurve(curves[i],distance/lengths[i]);distance-=lengths[i];
  }return{x:0,y:0};
}
export function hintPresentation(timeMs:number,reduced=false){
  if(reduced)return{phase:'reduced',opacity:1,motionMs:1400};
  const t=((Number.isFinite(timeMs)?timeMs:0)%HINT_LOOP_MS+HINT_LOOP_MS)%HINT_LOOP_MS;
  const smooth=(v:number)=>v*v*(3-2*v);
  if(t<HINT_FADE_MS)return{phase:'appearing',opacity:smooth(t/HINT_FADE_MS),motionMs:t};
  if(t<HINT_MOTION_MS)return{phase:'showing',opacity:1,motionMs:t};
  if(t<HINT_MOTION_MS+HINT_FADE_MS)return{phase:'fading',opacity:1-smooth((t-HINT_MOTION_MS)/HINT_FADE_MS),motionMs:HINT_MOTION_MS};
  return{phase:'waiting',opacity:0,motionMs:0};
}

export class ControlHintProgress{
  lowerStarts=0;
  private lastAttempt='';
  private storage:Pick<Storage,'getItem'|'setItem'>;
  constructor(storage:Pick<Storage,'getItem'|'setItem'>){
    this.storage=storage;
    try{const value=Number(storage.getItem(HINT_PROGRESS_KEY));
      if(Number.isInteger(value)&&value>=0)this.lowerStarts=Math.min(3,value);
    }catch{/* A tutorial preference cannot block a run. */}
  }
  recordSuccessfulStart(fromLower:boolean,attemptId:string){
    if(!fromLower||!attemptId||attemptId===this.lastAttempt||this.lowerStarts>=3)return false;
    this.lastAttempt=attemptId;this.lowerStarts++;
    try{this.storage.setItem(HINT_PROGRESS_KEY,String(this.lowerStarts));}catch{/* Keep session progress. */}
    return true;
  }
}
