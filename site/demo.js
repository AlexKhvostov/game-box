import { loadGameModule } from './media.js';
import { config } from './demo-engine/config.js';
import { visualWallInset } from './demo-engine/util.js';
const { GameWorld } = await loadGameModule(new URL('./demo-engine/game-world.js', import.meta.url));
const { FieldRenderer, GameFieldColors } = await loadGameModule(new URL('./demo-engine/renderer.js', import.meta.url));

const KEY = 'untouch_landing_demo_v4_android_pace';
const ATTEMPTS = 3;
const SIZE = 380;
const formatTime = ms => { const t=Math.max(0,Math.floor(ms));return `${String(Math.floor(t/60000)).padStart(2,'0')}:${String(Math.floor(t/1000)%60).padStart(2,'0')}.${String(t%1000).padStart(3,'0')}`; };
export class LandingDemo {
  constructor(root) {
    this.root = root;
    this.canvas = root.querySelector('canvas');
    this.ctx = this.canvas.getContext('2d');
    this.time = root.querySelector('[data-time]');
    this.hearts = root.querySelector('[data-lives]');
    this.message = root.querySelector('[data-message]');
    this.continueLink = root.querySelector('[data-continue]');
    this.retryButton = root.querySelector('[data-retry]');
    this.resultOverlay = root.querySelector('[data-result]');
    this.resultScore = root.querySelector('[data-result-score]');
    this.finger = root.querySelector('[data-finger]');
    this.status = 'idle'; this.elapsed = 0; this.best = 0; this.lives = ATTEMPTS;
    this.analyticsAttempts = 0;
    this.pointer = null; this.keys = new Set(); this.frame = 0;
    try {
      const saved = JSON.parse(localStorage.getItem(KEY) || 'null');
      if (saved && Number.isInteger(saved.lives) && saved.lives >= 0 && saved.lives <= ATTEMPTS) {
        this.lives = Math.max(0, saved.lives - (saved.active === true ? 1 : 0));
        this.best = Number.isFinite(saved.best) && saved.best >= 0 ? saved.best : 0;
      }
    } catch { /* Storage may be disabled; the current visit still has three lives. */ }
    if(!this.lives)this.status='exhausted';
    this.world = new GameWorld({config, fieldW:SIZE, fieldH:SIZE, wallInset:visualWallInset(config.field.borderWidth)});
    this.world.resetLayout(); this.preparePreview(); this.renderer = new FieldRenderer(config.theme);
    const dpr = Math.min(devicePixelRatio || 1, 2);
    this.canvas.width = this.canvas.height = SIZE * dpr;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.retryButton.addEventListener('click', () => this.arm());
    document.querySelector('[data-demo-reset]').addEventListener('click', () => this.reset());
    const zone = root.querySelector('[data-controls]');
    zone.addEventListener('pointerdown', e => {
      if(e.target.closest('button,a'))return;
      if (this.pointer || !this.lives || (e.pointerType === 'mouse' && e.button !== 0)) return;
      const point=this.fieldPoint(e);
      if(!['idle','ready','paused','playing'].includes(this.status))return;
      e.preventDefault(); zone.setPointerCapture(e.pointerId);
      this.pointer = {id:e.pointerId, ...point};
      this.canvas.focus({preventScroll:true});
      if(this.status!=='playing')this.start();
    });
    zone.addEventListener('pointermove', e => {
      if (this.pointer?.id !== e.pointerId) return;
      const point=this.fieldPoint(e);
      if(this.status!=='playing') {
        if(Math.hypot(point.x-this.pointer.x,point.y-this.pointer.y)<1)return;
        this.start();
      }
      this.world.movePlayerBy({dx:point.x-this.pointer.x, dy:point.y-this.pointer.y});
      this.pointer.x=point.x; this.pointer.y=point.y; this.checkCollision(); this.draw();
    });
    zone.addEventListener('pointerup', e => { if (this.pointer?.id === e.pointerId) this.pointer=null; });
    zone.addEventListener('pointercancel', () => this.pause());
    this.canvas.addEventListener('keydown', e => {
      if((e.key==='Enter'||e.key===' ') && this.status!=='playing'){e.preventDefault();this.arm();}
      if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.key)) {e.preventDefault(); if(['idle','ready','paused'].includes(this.status))this.start();if(this.status==='playing')this.keys.add(e.key);}
      if(e.key==='Escape')this.pause();
    });
    this.canvas.addEventListener('keyup', e => this.keys.delete(e.key));
    this.canvas.addEventListener('blur', () => {this.keys.clear();});
    window.addEventListener('blur', () => this.pause());
    window.addEventListener('untouch:pause-demo', () => this.pause());
    document.addEventListener('visibilitychange', () => {if(document.hidden)this.pause();});
    this.visible=true;
    this.observer = new IntersectionObserver(entries => {this.visible=entries[0].isIntersecting;if(!this.visible)this.pause();});
    this.observer.observe(this.canvas);
    this.save(false); this.updateUI(); this.draw();
    this.animatePreview();
  }
  fieldPoint(e) {
    const rect=this.canvas.getBoundingClientRect();
    const matrix=new DOMMatrix(getComputedStyle(this.canvas.parentElement).transform);
    const point=new DOMPoint(e.clientX-(rect.left+rect.width/2),e.clientY-(rect.top+rect.height/2)).matrixTransform(matrix.inverse());
    const scale=SIZE/this.canvas.clientWidth;
    return {x:SIZE/2+point.x*scale,y:SIZE/2+point.y*scale};
  }
  animatePreview() {
    const now=performance.now(), dt=Math.min((now-(this.previewLast||now))/1000,0.04);this.previewLast=now;
    if(['idle','ready'].includes(this.status) && this.visible && !document.hidden && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
      const center=(SIZE-this.world.playerSize)/2;
      this.previewTime+=dt;
      this.world.enemies.forEach((enemy,i)=>{
        const home=this.previewHomes[i],phase=i*.8;
        const inset=this.world.wallInset;
        enemy.pos={dx:Math.max(inset,Math.min(SIZE-inset-enemy.w,home.dx+(Math.sin(this.previewTime*1.4+phase)-Math.sin(phase))*4)),dy:Math.max(inset,Math.min(SIZE-inset-enemy.h,home.dy+(Math.sin(this.previewTime*1.1+phase)-Math.sin(phase))*3))};
      });
      this.world.player={dx:center,dy:center};this.draw();
    }
    this.previewRaf=requestAnimationFrame(()=>this.animatePreview());
  }
  preparePreview() {
    this.previewTime=0;this.previewHomes=this.world.enemies.map(e=>({...e.pos}));
  }
  arm() {
    if(!this.lives || this.status==='playing')return;
    if(this.status==='paused'){this.start();return;}
    if(this.status==='result'){this.world.resetLayout();this.preparePreview();this.elapsed=0;}
    this.status='ready';this.updateUI();this.draw();this.canvas.focus({preventScroll:true});
  }
  reset() {
    cancelAnimationFrame(this.raf);this.pointer=null;this.keys.clear();
    this.lives=ATTEMPTS;this.elapsed=0;this.best=0;this.frame=0;this.status='idle';
    this.world.resetLayout();this.preparePreview();this.save(false);this.updateUI();this.draw();
  }
  save(active) {try {localStorage.setItem(KEY, JSON.stringify({lives:this.lives,best:this.best,active}));} catch {}}
  updateUI() {
    this.hearts.textContent = '♥'.repeat(this.lives) + '♡'.repeat(ATTEMPTS-this.lives);
    this.hearts.setAttribute('aria-label', `Осталось жизней: ${this.lives}`);
    this.time.textContent = formatTime(this.elapsed);
    this.resultOverlay.hidden = !['result','exhausted'].includes(this.status);
    this.resultScore.textContent = ((this.status==='exhausted' ? this.best : this.elapsed)/1000).toFixed(3)+' с';
    this.retryButton.hidden = this.lives===0;
    this.finger.toggleAttribute('hidden',!['idle','ready'].includes(this.status));
    this.continueLink.hidden = this.lives>0;
    this.message.textContent = this.lives===0 ? `Три попытки позади. Лучший результат: ${(this.best/1000).toFixed(3)} с.` : this.status==='paused' ? 'Пауза. Коснись поля, чтобы продолжить.' : this.status==='result' ? `Твой результат: ${(this.elapsed/1000).toFixed(3)} с. Ещё попытку?` : this.status==='playing' ? 'Веди кубик. Уворачивайся от коралловых фигур.' : 'Коснись поля и веди пальцем. На компьютере — стрелки.';
    this.root.dataset.state = this.status;
  }
  start() {
    if(!this.lives || this.status==='playing')return;
    if(this.status!=='paused'){
      this.elapsed=0;
      this.analyticsAttempts++;
      window.dispatchEvent(new CustomEvent('untouch:demo-start', {detail:{attempt_number:this.analyticsAttempts}}));
    }
    this.status='playing';this.save(true);this.updateUI();this.canvas.focus({preventScroll:true});
    this.last=performance.now();this.raf=requestAnimationFrame(t=>this.tick(t));
  }
  pause() {
    this.pointer=null;this.keys.clear();
    if(this.status!=='playing')return;
    cancelAnimationFrame(this.raf);this.status='paused';this.updateUI();
  }
  checkCollision() {
    if(this.status!=='playing' || this.elapsed < config.game.startInvulnSec*1000)return;
    if((this.world.wallsKillPlayer() && this.world.playerHitsBorder()) || this.world.playerHitsEnemy())this.finish();
  }
  finish() {
    if(this.status!=='playing')return;
    this.elapsed=Math.floor(this.elapsed);
    window.dispatchEvent(new CustomEvent('untouch:demo-end', {detail:{attempt_number:this.analyticsAttempts,duration_ms:this.elapsed}}));
    cancelAnimationFrame(this.raf);this.pointer=null;this.keys.clear();
    this.lives=Math.max(0,this.lives-1);this.best=Math.max(this.best,this.elapsed);
    this.status=this.lives ? 'result' : 'exhausted';this.save(false);this.updateUI();this.draw();
  }
  tick(now) {
    if(this.status!=='playing')return;
    const dt=Math.max(0,Math.min((now-this.last)/1000,0.04));this.last=now;this.elapsed+=dt*1000;
    const dx=Number(this.keys.has('ArrowRight'))-Number(this.keys.has('ArrowLeft'));
    const dy=Number(this.keys.has('ArrowDown'))-Number(this.keys.has('ArrowUp'));
    if(dx||dy){const norm=Math.hypot(dx,dy);this.world.movePlayerBy({dx:dx/norm*240*dt,dy:dy/norm*240*dt});}
    this.world.tickPlay(dt,this.elapsed/1000,1);this.checkCollision();
    this.time.textContent=formatTime(this.elapsed);this.frame++;this.draw();
    if(this.status==='playing')this.raf=requestAnimationFrame(t=>this.tick(t));
  }
  draw() {
    this.ctx.clearRect(0,0,SIZE,SIZE);
    this.renderer.paint(this.ctx,this.world,{fieldSize:{width:SIZE,height:SIZE},fieldColor:GameFieldColors.floor,accent:GameFieldColors.hero,danger:GameFieldColors.enemy,borderColor:GameFieldColors.wall,drawBorder:true,borderWidth:config.field.borderWidth,cornerRadius:18,showFace:true,frame:this.frame,invulnerable:false,shadowBrightness:config.field.shadowBrightness});
    this.finger.style.left=((this.world.player.dx+this.world.playerSize*.8)/SIZE*100)+'%';
    this.finger.style.top=((this.world.player.dy+this.world.playerSize*.8)/SIZE*100)+'%';
  }
}
export const demo = new LandingDemo(document.querySelector('#demo-widget'));
