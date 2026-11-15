import {watch} from 'vue';
import { kernel, proof, type WorldState, type RoundProof } from '../domain/kernel';
import {HelmetShatter} from './helmet';
import { ImpactBurst, type ImpactEffect } from './impact';
import { FieldPainter } from './painter';
import { operationId } from '../services/storage';
import { state, world, prepareAttempt, finishAttempt, errorText, openScreen, energy, failedFinish, applyPendingConfig } from '../services/game-store';
import { sound, enableAudio, syncMusic, stopAudio } from '../platform/audio';
import { telegram } from '../platform/telegram';
import type { GameConfig } from '../services/contracts';
import { motionProbe } from './motion-probe';
import {JumpReadySignal} from './jump-ready-signal';
import {dismissControlHint,resetControlHint,recordControlHintStart} from '../services/control-hint-store';
import {EnemyReactions,ENEMY_PRESENTATION_MS} from './enemy-reactions';
import {controlSensitivity,enemyReactionsAllowed,type GamePresentationPolicy,type GamePresentationPreferences} from './presentation-policy';
export interface GameControllerCallbacks {
  /** Local persistence has begun. Prepare the first award while enemies react. */
  onDefeat?:(requestId:string,snapshot:WorldState,roundProof:RoundProof)=>void;
  /** Show prepared awards or the result immediately; never await HTTP here. */
  onPresentationReady?:(requestId:string)=>void;
}
export class GameController {
  private painter: FieldPainter;
  private jumpReady = new JumpReadySignal();
  private snapshot!: WorldState;
  private boundConfig: GameConfig | null = null;
  private requestId = '';
  private lastTime = 0;
  private debt = 0;
  private lastHud = 0;
  private frame = 0;
  private impacts:ImpactEffect[]=[];
  private raf = 0;
  private pointers = new Map<number, { x: number; y: number }>();
  private primary: number | null = null;
  private stopped = false;
  private enemyReactions:EnemyReactions|null=null;
  private impactAgeMs=0;
  private presentationDelivered=false;
  private events: (() => void)[] = [];
  constructor(private canvas: HTMLCanvasElement, private touchpad: HTMLElement,private callbacks:GameControllerCallbacks={},playingInput?:HTMLElement) {
    this.painter = new FieldPainter(canvas); this.reset();
    for(const surface of new Set([touchpad,...(playingInput?[playingInput]:[])])){
      const bind = (name: string, callback: EventListener) => { surface.addEventListener(name, callback,{passive:false}); this.events.push(() => surface.removeEventListener(name, callback)); };
      bind('pointerdown', this.down as EventListener); bind('pointermove', this.move as EventListener); bind('pointerup', this.up as EventListener); bind('pointercancel', this.up as EventListener);
    }
    window.addEventListener('keydown', this.key); document.addEventListener('visibilitychange', this.visibility);
    telegram()?.onEvent('deactivated', this.deactivate); telegram()?.onEvent('activated', this.activate);
    this.events.push(watch(()=>[state.screen,state.inviteNoticeOpen,state.externalBusy],this.syncActivity,{flush:'sync'}));
    this.events.push(watch(()=>JSON.stringify([this.presentationPolicy(),state.preferences]),()=>{if(!this.snapshot?.playing){this.configureReactions();this.draw();}this.syncActivity();}));
    this.syncActivity();
  }
  private presentationPolicy(){return (state as typeof state & {presentation?:GamePresentationPolicy}).presentation;}
  private preferences(){return state.preferences as typeof state.preferences & GamePresentationPreferences;}
  private configureReactions(){
    const enabled=enemyReactionsAllowed(this.presentationPolicy(),this.preferences());
    if(!enabled)this.enemyReactions=null;
    else this.enemyReactions??=new EnemyReactions();
  }
  reset() {
    if (failedFinish.value) return;

    applyPendingConfig();
    if (!state.config) return;
    resetControlHint();
    this.boundConfig = state.config;
    this.jumpReady.reset();
    this.requestId = operationId(); this.snapshot = kernel({ op: 'create', proofVersion: 6, config: this.boundConfig.config, requestId: this.requestId, hadHelmet: state.helmet, hadJump: state.jump });
    this.configureReactions();this.enemyReactions?.reset();this.impactAgeMs=0;this.presentationDelivered=false;
    this.impacts=[];this.painter.configure(this.boundConfig.config); world.value = this.snapshot; this.reanchor();
    this.draw();
    this.syncActivity();
  }
  private observeJumpReady() {
    const s = this.snapshot;
    this.jumpReady.observe(s.jumpEnabled === true && this.boundConfig?.config.game.jumpEnabled === true,
      Math.max(s.jumpCooldownMs, s.jumpRemainingMs ?? NaN), s.timeMs);
  }
  private draw() {
    if (this.snapshot && this.boundConfig) {
      this.observeJumpReady();
      this.painter.draw(this.snapshot, this.boundConfig.config, this.frame, this.impacts, this.jumpReady.ageMs,{showPlayerFace:this.preferences().showPlayerFace,enemyReactions:this.enemyReactions,locale:state.locale});
    }
  }
  reanchor() { this.lastTime = 0; this.debt = 0; this.pointers.clear(); this.primary = null; }
  private active(){return !this.stopped&&!!this.snapshot&&!state.screen&&!state.inviteNoticeOpen&&!state.externalBusy&&!document.hidden&&telegram()?.isActive!==false;}
  private syncActivity=()=>{
    if(!this.active()||(this.snapshot.dead&&this.presentationDelivered)){
      if(this.raf)cancelAnimationFrame(this.raf);this.raf=0;this.reanchor();return;
    }
    if(!this.raf)this.raf=requestAnimationFrame(this.tick);
  };
  private geometryIssue() {
    const rect = this.canvas.getBoundingClientRect(), vp = window.visualViewport;
    const visible = { left: vp?.offsetLeft ?? 0, top: vp?.offsetTop ?? 0, right: (vp?.offsetLeft ?? 0) + (vp?.width ?? window.innerWidth), bottom: (vp?.offsetTop ?? 0) + (vp?.height ?? window.innerHeight) };
    for (let node: HTMLElement | null = this.canvas; node; node = node.parentElement) {
      const style = getComputedStyle(node);
      if (style.visibility !== 'visible' || style.display === 'none' || +style.opacity === 0) return 'field_invisible';
      if (style.transform !== 'none') {
        const m = new DOMMatrixReadOnly(style.transform);
        if (!m.is2D || m.a <= 0 || m.d <= 0 || Math.abs(m.b) > 1e-6 || Math.abs(m.c) > 1e-6 || Math.abs(m.a / m.d - 1) > .03) return 'field_distorted';
      }
      if (style.overflowX !== 'visible' || style.overflowY !== 'visible') {
        const clip = node.getBoundingClientRect();
        if (style.overflowX !== 'visible') { visible.left = Math.max(visible.left, clip.left); visible.right = Math.min(visible.right, clip.right); }
        if (style.overflowY !== 'visible') { visible.top = Math.max(visible.top, clip.top); visible.bottom = Math.min(visible.bottom, clip.bottom); }
      }
    }
    return kernel({ op: 'guard', field: [rect.x,rect.y,rect.width,rect.height], visible: [visible.left,visible.top,visible.right-visible.left,visible.bottom-visible.top], dpr: window.devicePixelRatio }).issue;
  }
  private tick = (time: number) => {
    this.raf=0;
    if(!this.active()){this.reanchor();return;}
    const dt = this.lastTime ? time - this.lastTime : 0; this.lastTime = time;
    if (dt <= 0) {this.draw();this.syncActivity();return;}
    this.impacts=this.impacts.filter(impact=>impact.update(Math.min(50,dt)/1000));
    if(this.snapshot.dead){
      // Only active presentation time counts; a background/modal pause cannot
      // open a result or leave an animation timer working in the hidden app.
      const step=Math.min(50,dt);this.impactAgeMs+=step;this.enemyReactions?.advance(step);
      this.frame++;this.draw();
      const hold=this.enemyReactions?.caught?ENEMY_PRESENTATION_MS:420;
      if(this.impactAgeMs>=hold&&!this.presentationDelivered){
        this.presentationDelivered=true;this.impacts=[];
        if(this.callbacks.onPresentationReady)this.callbacks.onPresentationReady(this.requestId);else openScreen('result');
      }
      this.syncActivity();return;
    }
    if (this.snapshot.playing) {
      const before = this.snapshot.timeMs, started = motionProbe.clock();
      this.debt += dt; let budget = Math.min(250, this.debt);
      while (budget > 1e-9 && this.snapshot.playing) { const step = Math.min(50, budget); this.debt -= step; budget -= step; this.advance(step); }
      const afterKernel=motionProbe.clock();this.frame++;this.draw();
      motionProbe.frame(dt,this.snapshot.timeMs-before,afterKernel-started,motionProbe.clock()-afterKernel,this.snapshot.dead);
    } else { const step=Math.min(50,dt);this.enemyReactions?.advance(step);this.snapshot = kernel({ op: 'idle', ms: step });if(this.snapshot.wallBounces)sound('wall');if(this.snapshot.enemyBounces)sound('collide');this.frame++;this.draw(); }
    if (time - this.lastHud >= 33) { world.value = this.snapshot; this.lastHud = time; }
    this.syncActivity();
  };
  private advance(ms: number) {
    this.enemyReactions?.advance(ms);
    const previous = this.snapshot; this.snapshot = kernel({ op: 'tick', ms });
    this.observeJumpReady();
    if (this.snapshot.wallBounces) sound('wall'); if (this.snapshot.enemyBounces) sound('collide');
    this.transitions(previous);
  }
  private transitions(previous: WorldState) {
    if (!this.snapshot.dead && (this.snapshot.brake?.presses??0) > (previous.brake?.presses??0)) {sound('brake');if(this.enemyReactions){this.enemyReactions.brake();sound('enemySurprise');}}
    if (this.snapshot.riskCount > previous.riskCount) sound('risk');
    if ((this.snapshot.helmetCharge?.breaks??0) > (previous.helmetCharge?.breaks??0)) { this.impacts.push(new HelmetShatter(this.snapshot));sound('helmet'); if (state.preferences.vibration) telegram()?.HapticFeedback?.impactOccurred('medium'); }
    if (this.snapshot.dead && !previous.dead) {

      this.enemyReactions?.finish(!this.snapshot.againstWall);
      this.impacts=[new ImpactBurst(this.snapshot)];sound(this.snapshot.againstWall ? 'heroWall' : 'hit');if(this.enemyReactions?.caught)sound('enemyCatch'); if (state.preferences.vibration) telegram()?.HapticFeedback?.notificationOccurred('error');
      this.pointers.clear(); this.primary = null; this.debt = 0; world.value = this.snapshot;
      state.resultId = this.requestId;this.impactAgeMs=0;this.presentationDelivered=false;
      try {
        const roundProof=proof();
        try { finishAttempt(this.requestId,this.snapshot,roundProof); }
        catch(error){state.error=errorText(error);}
        // The presentation context must exist even when a full device cannot
        // persist the result. Its result-first fallback exposes Retry saving;
        // it cannot wait forever for an award run that was never prepared.
        this.callbacks.onDefeat?.(this.requestId,this.snapshot,roundProof);
      } catch (error) { state.error = errorText(error); }
      motionProbe.finish();
    }
  }
  private down = (event: PointerEvent) => {
    if (!state.initialized || state.screen || state.inviteNoticeOpen || state.externalBusy || this.snapshot.dead || event.button > 0) return;
    event.preventDefault();
    const surface=event.currentTarget instanceof HTMLElement?event.currentTarget:this.touchpad;
    surface.setPointerCapture(event.pointerId); enableAudio();
    if (!this.snapshot.playing) {
      const fromLower=event.clientY>=this.canvas.getBoundingClientRect().bottom;
      if (this.geometryIssue()) { this.reanchor(); state.notice = state.locale === 'en' ? 'The field is not fully visible. Close the keyboard or reopen the game. Your run has not started.' : 'Поле отображается не полностью. Закройте клавиатуру или откройте игру заново. Попытка не началась.'; return; }
      if (energy.value < state.profile!.wallet.energyConfig.baseAttemptCost + (state.helmet ? state.profile!.wallet.energyConfig.helmetExtraCost : 0) + (state.jump ? state.profile!.wallet.energyConfig.jumpExtraCost : 0)) { openScreen('energy'); return; }
      try {
        // Loadout was chosen while idle. Recreate with the same seed, restore
        // the continuously displayed start pose, then start without a frame jump.
        prepareAttempt(this.requestId); this.snapshot = kernel({ op: 'start' }); this.lastTime = 0; this.debt = 0; world.value = this.snapshot; sound('start');motionProbe.start();
        if(this.snapshot.playing){dismissControlHint();recordControlHintStart(fromLower,this.requestId);}
      } catch (error) { if(error instanceof Error && error.message==='insufficient_energy'){openScreen('energy');return;} state.error = errorText(error); state.notice = state.error; return; }
    }
    if (this.primary === null) { this.primary = event.pointerId; this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY }); }
    else { this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY }); this.jump(); }
  };
  private move = (event: PointerEvent) => {
    if (!this.snapshot.playing || state.screen || state.inviteNoticeOpen || event.pointerId !== this.primary) return;
    const last = this.pointers.get(event.pointerId); this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY }); if (!last) return;
    const factor = 380 / this.canvas.getBoundingClientRect().width * controlSensitivity(this.preferences());
    const dx = (event.clientX - last.x) * factor, dy = (event.clientY - last.y) * factor;
    if (!dx && !dy) return;
    const previous = this.snapshot; this.snapshot = kernel({ op: 'move', dx, dy }); this.transitions(previous);
    // Consume every input in physics immediately, but present once per display frame.
    // The old duplicate paints remain available only for an explicit QA comparison.
    const paintOnInput=motionProbe.paintOnInput(),started=motionProbe.clock();
    if(paintOnInput){this.draw();world.value=this.snapshot;}
    motionProbe.input(motionProbe.clock()-started,paintOnInput);
  };
  private up = (event: PointerEvent) => {
    this.pointers.delete(event.pointerId);
    if (this.primary === event.pointerId) { this.primary = this.pointers.keys().next().value ?? null; if (this.primary !== null) this.pointers.delete(this.primary); }
  };
  jump() {
    if (!this.snapshot.playing || !state.jump) return;
    const before=this.snapshot;this.snapshot=kernel({op:'jump'});
    this.observeJumpReady();
    const accepted=this.snapshot.jumpCount!==undefined&&before.jumpCount!==undefined
      ? this.snapshot.jumpCount>before.jumpCount
      : this.snapshot.jumpCooldownMs>before.jumpCooldownMs;
    if(accepted){sound('jump');}if(motionProbe.paintOnInput())this.draw();world.value=this.snapshot;
  }
  private key = (event: KeyboardEvent) => {
    if (['INPUT', 'TEXTAREA', 'SELECT'].includes((event.target as HTMLElement)?.tagName) || state.screen || state.inviteNoticeOpen) return;
    if (event.code === 'Space') { event.preventDefault(); this.jump(); }
  };
  private deactivate = () => { this.reanchor();if(this.raf)cancelAnimationFrame(this.raf);this.raf=0;stopAudio(); };
  private activate = () => { this.lastTime = 0; syncMusic();this.syncActivity(); };
  private visibility = () => document.hidden ? this.deactivate() : this.activate();
  dispose() { motionProbe.cancel();this.stopped = true; cancelAnimationFrame(this.raf);this.raf=0;this.enemyReactions=null; for (const fn of this.events) fn(); window.removeEventListener('keydown', this.key); document.removeEventListener('visibilitychange', this.visibility); telegram()?.offEvent('deactivated', this.deactivate); telegram()?.offEvent('activated', this.activate); stopAudio(); }
}
