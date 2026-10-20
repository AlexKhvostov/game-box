// QA-only, bounded local timings. No identity, input coordinates or game proof.
export class MotionProbe {
  private last: {frames:number[][];moves:number;inputDraws:number;inputDrawMs:number;storage:number[][];droppedFrames:number;inputPaintMode:string}|null = null;
  private legacyInputPaint = false;
  private active = false;
  private frames: number[][] = [];
  private moves = 0;
  private inputDraws = 0;
  private inputDrawMs = 0;
  private storage: number[][] = [];
  private droppedFrames = 0;
  private startedAt = 0;
  private generation = 0;
  private logTimer: ReturnType<typeof setTimeout>|null = null;
  private enabled: boolean;
  constructor(enabled: boolean) {this.enabled=enabled;}
  start() { if (!this.enabled) return; this.clearLog();this.generation++;this.startedAt=performance.now();this.active = true; this.frames = []; this.moves = this.inputDraws = this.inputDrawMs = this.droppedFrames = 0; this.storage = []; }
  clock() { return this.enabled && this.active ? performance.now() : 0; }
  frame(dt: number, advanced: number, updateMs: number, paintMs: number, fatal=false) {
    if(!this.active)return;
    if(this.frames.length>=1800){this.droppedFrames++;return;}
    // advanced is a delta of the floored display clock, not exact physics time.
    this.frames.push([dt,advanced,updateMs,paintMs,fatal?1:0,performance.now()-this.startedAt].map(n=>Math.round(n*1000)/1000));
  }
  input(drawMs = 0, drew = false) { if (this.active) { this.moves++; if(drew){this.inputDraws++;this.inputDrawMs += drawMs;} } }
  persisted(ms: number, codeUnits: number) { if(this.active && this.storage.length < 64)this.storage.push([Math.round(ms*1000)/1000,codeUnits,Math.round((performance.now()-this.startedAt)*1000)/1000]); }
  finish() {
    if (!this.active) return;
    // Defer capture until the fatal frame has also been measured.
    const generation=this.generation;
    queueMicrotask(() => {
      if(!this.active||generation!==this.generation)return;this.active=false;
      const report={frames:this.frames,moves:this.moves,inputDraws:this.inputDraws,inputDrawMs:this.inputDrawMs,storage:this.storage,droppedFrames:this.droppedFrames,inputPaintMode:this.paintOnInput()?'legacy':'raf'};
      this.last=report;
      this.logTimer=setTimeout(()=>{
        this.logTimer=null;if(this.active||generation!==this.generation)return;
        console.info('UNTOUCH_MOTION '+JSON.stringify({kind:'summary',frames:report.frames.length,moves:report.moves,inputDraws:report.inputDraws,inputDrawMs:report.inputDrawMs,storage:report.storage,droppedFrames:report.droppedFrames,inputPaintMode:report.inputPaintMode}));
        for(let i=0;i<report.frames.length;i+=20)console.info('UNTOUCH_MOTION '+JSON.stringify({kind:'frames',offset:i,rows:report.frames.slice(i,i+20)}));
      },700);
    });
  }
  private clearLog(){if(this.logTimer)clearTimeout(this.logTimer);this.logTimer=null;}
  cancel() { this.clearLog();this.generation++;this.active=false;this.frames=[];this.storage=[]; }
  report() {return this.last;}
  paintOnInput(){return this.enabled&&this.legacyInputPaint;}
  setLegacyInputPaint(value:boolean){if(this.enabled&&!this.active)this.legacyInputPaint=value;}
}
export const motionProbe = new MotionProbe(import.meta.env?.VITE_QA_MODE === 'true');
