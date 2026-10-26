// Prepared PCM is shared; only lightweight, one-shot Web Audio voices are made at an event.
export const effects = {
  start: {file:'game_start', flag:'sfxStart', gain:.5, gap:0, voices:1},
  wall: {file:'mob_wall', flag:'sfxMobWall', gain:.7, gap:28, voices:3},
  collide: {file:'mob_collide', flag:'sfxMobCollide', gain:.55, gap:45, voices:1},
  hit: {file:'hero_mob', flag:'sfxHeroMob', gain:.72, gap:0, voices:1},
  heroWall: {file:'hero_wall', flag:'sfxHeroWall', gain:.7, gap:0, voices:1},
  helmet: {file:'helmet_break', flag:'sfxHelmet', gain:.58, gap:0, voices:1},
  jump: {file:'jump', flag:'sfxJump', gain:.45, gap:0, voices:1},
  brake: {file:'brake', flag:'sfxBrake', gain:.48, gap:0, voices:1},
  risk: {file:'near_miss', flag:'sfxNearMiss', gain:.42, gap:90, voices:1},
} as const;
export type SoundName = keyof typeof effects;
export interface AudioPolicy {active:boolean; sound:boolean; music:boolean; config:Record<string,unknown>}
interface Voice {source:AudioBufferSourceNode; name:SoundName}
const volume=(value:unknown,fallback:number)=>typeof value==='number'&&Number.isFinite(value)?Math.max(0,Math.min(1,value)):fallback;
export class GameAudio {
  private context:AudioContext|undefined;
  private buffers=new Map<string,AudioBuffer>();
  private gains=new Map<string,GainNode>();
  private voices=new Set<Voice>();
  private last=new Map<string,number>();
  private preparing:Promise<void>|undefined;
  private resuming:Promise<void>|undefined;
  private music:AudioBufferSourceNode|undefined;
  private musicAt=0;
  private musicOffset=0;
  private epoch=0;
  private disposed=false;
  private unlocked=false;
  private starts=0;
  private dropped=0;
  private peakVoices=0;
  constructor(private policy:()=>AudioPolicy,
    private createContext:()=>AudioContext=()=>new AudioContext({latencyHint:'interactive'}),
    private fetcher:typeof fetch=(...args)=>globalThis.fetch(...args),
    private clock:()=>number=()=>performance.now()){}
  prepare(timeoutMs=6000):Promise<void> {
    return this.preparing??=this.load(timeoutMs);
  }
  private async load(timeoutMs:number) {
    if(this.disposed)return;
    try{this.context??=this.createContext();}catch{return;}
    const context=this.context,abort=new AbortController();let expired=false;
    let timer:ReturnType<typeof setTimeout>;
    const deadline=new Promise<void>(resolve=>{timer=setTimeout(()=>{expired=true;abort.abort();resolve();},timeoutMs);});
    const tasks=[...Object.values(effects).map(x=>x.file),'bgm_loop'].map(async name=>{
      try{
        const response=await this.fetcher(`/assets/sfx/${name}.wav`,{signal:abort.signal});
        if(!response.ok)throw Error('audio_asset_unavailable');
        const encoded=await response.arrayBuffer();
        if(expired||this.disposed)return;
        const buffer=await context.decodeAudioData(encoded);
        if(!expired&&!this.disposed)this.buffers.set(name,buffer);
      }catch{/* An unavailable sound is skipped, never fetched or replayed at a collision. */}
    });
    try{await Promise.race([Promise.allSettled(tasks),deadline]);}finally{clearTimeout(timer!);}
    // Make all persistent gains outside the gameplay event path.
    if(!this.disposed)try{for(const name of [...Object.keys(effects),'music'])this.gain(name);}catch{}
  }
  unlock():Promise<void> {
    this.unlocked=true;
    const context=this.context;
    if(!context||this.disposed||!this.policy().active)return Promise.resolve();
    if(context.state==='running'){this.sync();return Promise.resolve();}
    if(!this.resuming){
      try{this.resuming=context.resume().then(()=>{if(!this.disposed)this.sync();}).catch(()=>{}).finally(()=>{this.resuming=undefined;});}catch{return Promise.resolve();}
    }
    return this.resuming;
  }
  resumeIfUnlocked(){if(this.unlocked)void this.unlock();}
  private gain(name:string):GainNode {
    let gain=this.gains.get(name);
    if(!gain){gain=this.context!.createGain();gain.connect(this.context!.destination);this.gains.set(name,gain);}
    return gain;
  }
  private allowed(name:SoundName) {
    const p=this.policy();return !this.disposed&&this.unlocked&&p.active&&p.sound&&p.config[effects[name].flag]!==false;
  }
  play(name:SoundName):boolean {
    if(!Object.hasOwn(effects,name)||!this.allowed(name)||this.context?.state!=='running')return false;
    const spec=effects[name],buffer=this.buffers.get(spec.file),now=this.clock();
    if(!buffer){this.dropped++;return false;}
    if(now-(this.last.get(name)??-Infinity)<spec.gap)return false;
    this.last.set(name,now);
    const same=[...this.voices].filter(v=>v.name===name);
    if(same.length>=spec.voices)this.end(same[0]!);
    const gain=this.gains.get(name);if(!gain){this.dropped++;return false;}
    let source:AudioBufferSourceNode|undefined,voice:Voice|undefined;
    try{
      gain.gain.value=volume(this.policy().config.sfxVolume,1)*spec.gain;
      source=this.context.createBufferSource();voice={source,name};
      source.buffer=buffer;source.connect(gain);
      const ended=voice;source.onended=()=>{this.voices.delete(ended);try{ended.source.disconnect();}catch{}};
      this.voices.add(voice);source.start();this.starts++;this.peakVoices=Math.max(this.peakVoices,this.voices.size);return true;
    }catch{if(voice)this.end(voice);else try{source?.disconnect();}catch{}this.dropped++;return false;}
  }

  // Only the start tap may wait briefly for the first user-gesture unlock.
  // No collision, risk, jump or missing asset is queued for later playback.
  startFromGesture() {
    if(this.play('start')||!this.allowed('start')||!this.buffers.has(effects.start.file))return;
    const stamp=this.clock(),epoch=this.epoch;
    void this.unlock().then(()=>{if(epoch===this.epoch&&this.clock()-stamp<=25)this.play('start');});
  }
  sync() {
    const p=this.policy();
    if(!p.active){this.stop();return;}
    for(const voice of [...this.voices])if(!p.sound||p.config[effects[voice.name].flag]===false)this.end(voice);
    const buffer=this.buffers.get('bgm_loop');
    if(!this.unlocked||!p.music||p.config.music===false||!buffer||this.context?.state!=='running'){
      this.pauseMusic(!p.music||p.config.music===false);return;
    }
    const gain=this.gains.get('music');if(!gain)return;
    try{
      gain.gain.value=volume(p.config.musicVolume,.08);if(this.music)return;
      const source=this.context.createBufferSource();this.music=source;source.buffer=buffer;source.loop=true;source.connect(gain);
      this.musicAt=this.context.currentTime;source.start(0,this.musicOffset%buffer.duration);
    }catch{this.pauseMusic(true);}
  }
  private end(voice:Voice) {
    this.voices.delete(voice);voice.source.onended=null;
    try{voice.source.stop();}catch{}try{voice.source.disconnect();}catch{}
  }
  private pauseMusic(reset=false) {
    if(this.music){if(!reset)this.musicOffset+=Math.max(0,(this.context?.currentTime??0)-this.musicAt);try{this.music.stop();}catch{}try{this.music.disconnect();}catch{}this.music=undefined;}
    if(reset)this.musicOffset=0;
  }
  stop() {this.epoch++;this.last.clear();for(const voice of [...this.voices])this.end(voice);this.pauseMusic();}
  dispose() {this.stop();this.disposed=true;this.buffers.clear();for(const gain of this.gains.values())try{gain.disconnect();}catch{}this.gains.clear();try{void this.context?.close().catch(()=>{});}catch{}}
  diagnostics() {
    let estimatedOutputLagMs:number|null=null;
    try{const stamp=this.context?.getOutputTimestamp?.();if(stamp?.contextTime&&this.context?.state==='running')estimatedOutputLagMs=Math.max(0,(this.context.currentTime-stamp.contextTime)*1000);}catch{}
    return {ready:this.buffers.size,total:Object.keys(effects).length+1,context:this.context?.state??'unavailable',sampleRate:this.context?.sampleRate??0,
      baseLatencyMs:this.context?.baseLatency==null?null:this.context.baseLatency*1000,outputLatencyMs:this.context?.outputLatency==null?null:this.context.outputLatency*1000,estimatedOutputLagMs,
      activeVoices:this.voices.size,peakVoices:this.peakVoices,starts:this.starts,dropped:this.dropped,music:!!this.music};
  }
}
