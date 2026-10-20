import { kernel, proof, type WorldState } from '../domain/kernel';
import { ImpactBurst } from './impact';
import { FieldPainter } from './painter';
import { operationId } from '../services/storage';
import { state, world, prepareAttempt, finishAttempt, errorText, openScreen, energy, failedFinish, applyPendingConfig } from '../services/game-store';
import { sound, enableAudio, syncMusic, stopAudio } from '../platform/audio';
import { telegram } from '../platform/telegram';
import type { GameConfig } from '../services/contracts';
import { motionProbe } from './motion-probe';
export class GameController {
  private painter: FieldPainter;
  private snapshot!: WorldState;
  private boundConfig: GameConfig | null = null;
  private requestId = '';
  private lastTime = 0;
  private debt = 0;
  private lastHud = 0;
  private frame = 0;
  private impacts:ImpactBurst[]=[];
  private raf = 0;
  private pointers = new Map<number, { x: number; y: number }>();
  private primary: number | null = null;
  private stopped = false;
  private resultTimer: ReturnType<typeof setTimeout> | undefined;
  private events: (() => void)[] = [];
  constructor(private canvas: HTMLCanvasElement, private touchpad: HTMLElement) {
    this.painter = new FieldPainter(canvas); this.reset();
    const bind = (name: string, callback: EventListener) => { touchpad.addEventListener(name, callback); this.events.push(() => touchpad.removeEventListener(name, callback)); };
    bind('pointerdown', this.down as EventListener); bind('pointermove', this.move as EventListener); bind('pointerup', this.up as EventListener); bind('pointercancel', this.up as EventListener);
    window.addEventListener('keydown', this.key); document.addEventListener('visibilitychange', this.visibility);
    telegram()?.onEvent('deactivated', this.deactivate); telegram()?.onEvent('activated', this.activate);
    this.raf = requestAnimationFrame(this.tick);
  }
  reset() {
    if (failedFinish.value) return;
    applyPendingConfig();
    if (!state.config) return;
    this.boundConfig = state.config;
    this.requestId = operationId(); this.snapshot = kernel({ op: 'create', config: this.boundConfig.config, requestId: this.requestId, hadHelmet: state.helmet, hadJump: state.jump });
    this.impacts=[];this.painter.configure(this.boundConfig.config); world.value = this.snapshot; this.reanchor();
    this.draw();
  }
  private draw() { if (this.snapshot && this.boundConfig) this.painter.draw(this.snapshot, this.boundConfig.config, this.frame, this.impacts); }
  reanchor() { this.lastTime = 0; this.debt = 0; this.pointers.clear(); this.primary = null; }
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
    if (this.stopped) return;
    this.raf = requestAnimationFrame(this.tick);
    if (!this.snapshot || state.screen || state.externalBusy || document.hidden || telegram()?.isActive === false) { this.lastTime = 0; this.debt = 0; return; }
    const dt = this.lastTime ? time - this.lastTime : 0; this.lastTime = time;
    if (dt <= 0) {this.draw();return;}
    this.impacts=this.impacts.filter(impact=>impact.update(Math.min(50,dt)/1000));
    if(this.snapshot.dead){this.frame++;this.draw();return;}
    if (this.snapshot.playing) {
      const before = this.snapshot.timeMs, started = motionProbe.clock();
      this.debt += dt; let budget = Math.min(250, this.debt);
      while (budget > 1e-9 && this.snapshot.playing) { const step = Math.min(50, budget); this.debt -= step; budget -= step; this.advance(step); }
      const afterKernel=motionProbe.clock();this.frame++;this.draw();
      motionProbe.frame(dt,this.snapshot.timeMs-before,afterKernel-started,motionProbe.clock()-afterKernel,this.snapshot.dead);
    } else { this.snapshot = kernel({ op: 'idle', ms: Math.min(50, dt) });if(this.snapshot.wallBounces)sound('wall');if(this.snapshot.enemyBounces)sound('collide');this.frame++;this.draw(); }
    if (time - this.lastHud >= 33) { world.value = this.snapshot; this.lastHud = time; }
  };
  private advance(ms: number) {
    const previous = this.snapshot; this.snapshot = kernel({ op: 'tick', ms });
    if (this.snapshot.wallBounces) sound('wall'); if (this.snapshot.enemyBounces) sound('collide');
    this.transitions(previous);
  }
  private transitions(previous: WorldState) {
    if (this.snapshot.riskCount > previous.riskCount) sound('risk');
    if (previous.helmet && !this.snapshot.helmet) { this.impacts.push(new ImpactBurst(this.snapshot,true));sound('helmet'); if (state.preferences.vibration) telegram()?.HapticFeedback?.impactOccurred('medium'); }
    if (this.snapshot.dead && !previous.dead) {
      this.impacts=[new ImpactBurst(this.snapshot)];sound(this.snapshot.againstWall ? 'heroWall' : 'hit'); if (state.preferences.vibration) telegram()?.HapticFeedback?.notificationOccurred('error');
      this.pointers.clear(); this.primary = null; this.debt = 0; world.value = this.snapshot;
      try { finishAttempt(this.requestId, this.snapshot, proof()); } catch (error) { state.error = errorText(error); }
      state.resultId = this.requestId; this.resultTimer = setTimeout(() => openScreen('result'), 420);
      motionProbe.finish();
    }
  }
  private down = (event: PointerEvent) => {
    if (!state.initialized || state.screen || state.externalBusy || this.snapshot.dead || event.button > 0) return;
    event.preventDefault(); this.touchpad.setPointerCapture(event.pointerId); enableAudio();
    if (!this.snapshot.playing) {
      if (this.geometryIssue()) { this.reanchor(); state.notice = state.locale === 'en' ? 'The field is not fully visible. Close the keyboard or reopen the game. Your run has not started.' : 'Поле отображается не полностью. Закройте клавиатуру или откройте игру заново. Попытка не началась.'; return; }
      if (energy.value < state.profile!.wallet.energyConfig.baseAttemptCost + (state.helmet ? state.profile!.wallet.energyConfig.helmetExtraCost : 0) + (state.jump ? state.profile!.wallet.energyConfig.jumpExtraCost : 0)) { openScreen('energy'); return; }
      try {
        // Loadout was chosen while idle. Recreate with the same seed, restore
        // the continuously displayed start pose, then start without a frame jump.
        prepareAttempt(this.requestId); this.snapshot = kernel({ op: 'start' }); this.lastTime = 0; this.debt = 0; world.value = this.snapshot; sound('start');motionProbe.start();
      } catch (error) { state.error = errorText(error); state.notice = state.error; return; }
    }
    if (this.primary === null) { this.primary = event.pointerId; this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY }); }
    else { this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY }); this.jump(); }
  };
  private move = (event: PointerEvent) => {
    if (!this.snapshot.playing || state.screen || event.pointerId !== this.primary) return;
    const last = this.pointers.get(event.pointerId); this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY }); if (!last) return;
    const factor = 380 / this.canvas.getBoundingClientRect().width;
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
    const previous = this.snapshot.jumpCooldownMs; this.snapshot = kernel({ op: 'jump' });
    if (this.snapshot.jumpCooldownMs > previous) sound('jump'); if(motionProbe.paintOnInput())this.draw(); world.value = this.snapshot;
  }
  private key = (event: KeyboardEvent) => {
    if (['INPUT', 'TEXTAREA', 'SELECT'].includes((event.target as HTMLElement)?.tagName) || state.screen) return;
    if (event.code === 'Space') { event.preventDefault(); this.jump(); }
  };
  private deactivate = () => { this.lastTime = 0; this.debt = 0; this.pointers.clear(); this.primary = null; stopAudio(); };
  private activate = () => { this.lastTime = 0; syncMusic(); };
  private visibility = () => document.hidden ? this.deactivate() : this.activate();
  dispose() { motionProbe.cancel();this.stopped = true; cancelAnimationFrame(this.raf); if (this.resultTimer) clearTimeout(this.resultTimer); for (const fn of this.events) fn(); window.removeEventListener('keydown', this.key); document.removeEventListener('visibilitychange', this.visibility); telegram()?.offEvent('deactivated', this.deactivate); telegram()?.offEvent('activated', this.activate); stopAudio(); }
}
