import {hudHeader} from './hud-header.js?v=1';
import {initialState} from './model.js';

// Presentation components only. No account, gameplay-config or server requests.
export const BRAKE_UI = Object.freeze({cooldown:8, maximumSpeed:150, pressMs:120, lossHoldMs:110, lossFadeMs:220, waveMs:680});
const states=new Set(['uncharged','charging','ready','pressed']);
const clamp=(v,min=0,max=1)=>Math.max(min,Math.min(max,v));
const finite=(v,name)=>{if(!Number.isFinite(v))throw new TypeError(`${name} must be finite`);return v;};
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let sequence=0;
const buttonRim='M50 5H82Q95 5 95 18V82Q95 95 82 95H18Q5 95 5 82V18Q5 5 18 5H50Z';

export function chargeSector(progress,r=44) {
  const p=clamp(finite(progress,'progress')),cx=50,cy=50;
  if(p===0)return '';
  if(p===1)return `M50 ${cy-r} A${r} ${r} 0 1 1 50 ${cy+r} A${r} ${r} 0 1 1 50 ${cy-r} Z`;
  const a=p*Math.PI*2,x=cx+r*Math.sin(a),y=cy-r*Math.cos(a);
  return `M50 50 L50 ${cy-r} A${r} ${r} 0 ${p>.5?1:0} 1 ${x.toFixed(5)} ${y.toFixed(5)} Z`;
}
export function enemySpeedAt(seconds) {return 70*(Math.pow(Math.max(0,finite(seconds,'seconds'))+3,.2)-1);}

export function createBrakeDemo({cooldown=8,rewind=8,firstReady=8}={}) {
  for(const [name,n] of Object.entries({cooldown,rewind,firstReady}))if(!Number.isFinite(n)||n<=0)throw new RangeError(`${name} must be positive`);
  let elapsed=0,effective=0,readyAt=firstReady,cycleStart=0,cycleLength=firstReady,presses=0;
  const snapshot=()=>({elapsed,effective,speed:enemySpeedAt(effective),ready:elapsed>=readyAt,progress:clamp((elapsed-cycleStart)/cycleLength),remaining:Math.max(0,readyAt-elapsed),presses});
  return {
    snapshot,
    advance(dt){finite(dt,'dt');if(dt<0)throw new RangeError('dt must not be negative');elapsed+=dt;effective+=dt;return snapshot();},
    press(){if(elapsed<readyAt)return null;const before=enemySpeedAt(effective);effective=Math.max(0,effective-rewind);cycleStart=elapsed;cycleLength=cooldown;readyAt=elapsed+cooldown;presses++;return {before,after:enemySpeedAt(effective),...snapshot()};},
    reset(){elapsed=effective=presses=cycleStart=0;readyAt=cycleLength=firstReady;return snapshot();}
  };
}

function normalizedButton({state='uncharged',progress=0}={}) {
  if(!states.has(state))throw new RangeError('Unknown brake button state');
  const p=state==='ready'||state==='pressed'?1:state==='uncharged'?0:clamp(finite(progress,'progress'));
  return {state,progress:p};
}
function buttonLabel(s,p){return s==='ready'?'Замедлить врагов':s==='pressed'?'Торможение':'Тормоз перезаряжается, '+Math.round(p*100)+' процентов';}

export function brakeButton(options={}) {
  const {state,progress}=normalizedButton(options),id=`brk-${++sequence}`,size=options.size??44;
  if(!Number.isFinite(size)||size<=0)throw new RangeError('size must be positive');
  return `<button type="button" class="brk-button" data-state="${state}" data-progress="${progress}" style="--brk-size:${size}px" ${state==='ready'?'':'disabled'} aria-label="${escape(buttonLabel(state,progress))}">
    <svg viewBox="0 0 100 100" aria-hidden="true" focusable="false">
      <defs><linearGradient id="${id}-empty" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#c1c8c8"/><stop offset="1" stop-color="#8e9b9d"/></linearGradient>
      <linearGradient id="${id}-charged" x1="0" y1="0" x2=".8" y2="1"><stop class="brk-stop-1" stop-color="#f2ffac"/><stop class="brk-stop-2" offset=".48" stop-color="#d4fa65"/><stop class="brk-stop-3" offset="1" stop-color="#a6e641"/></linearGradient>
      <clipPath id="${id}-face"><rect x="8" y="8" width="84" height="84" rx="12"/></clipPath></defs>
      <rect class="brk-floor-shadow" x="8" y="16" width="84" height="80" rx="12"/>
      <rect class="brk-base" x="8" y="12" width="84" height="82" rx="12"/>
      <g class="brk-face"><rect x="8" y="8" width="84" height="84" rx="12" fill="url(#${id}-empty)"/>
        <path class="brk-charge-face" d="${chargeSector(progress,64)}" fill="url(#${id}-charged)" clip-path="url(#${id}-face)"/>
        <path class="brk-gloss" d="M18 26V22Q18 16 24 16H79" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round"/>
        <g class="brk-snail" fill="#f9fffa" stroke="#163544" stroke-width="3.1" stroke-linecap="round" stroke-linejoin="round">
          <path d="M23 63h21c10 0 17-4 18-14l1-10c.4-6 9-7 11-1 4 13-4 29-17 32H23c-8 0-8-7 0-7Z"/>
          <circle cx="39" cy="47" r="18"/><path d="M39 60c-15 0-19-17-9-24 9-7 21 1 18 10-2 7-12 8-14 2-1-4 4-7 7-4" fill="none"/>
          <path d="m65 34-3-9m9 9 5-10" fill="none"/><circle cx="62" cy="23" r="1.5" fill="#163544"/><circle cx="77" cy="22" r="1.5" fill="#163544"/>
        </g><rect class="brk-rim" x="8" y="8" width="84" height="84" rx="12"/>
        <path class="brk-charge-track" d="${buttonRim}"/>
        <path class="brk-charge-ring" d="${buttonRim}" pathLength="100" stroke-dasharray="${progress*100} 100"/>
      </g><rect class="brk-press-ring" x="3" y="3" width="94" height="94" rx="15"/>
    </svg></button>`;
}

export function mountBrakeButton(host,options={}) {
  let current=normalizedButton(options),disposed=false;
  host.innerHTML=brakeButton(options);
  const element=host.querySelector('.brk-button');
  function setState(update){
    if(disposed)return;
    const previous=current.state;
    current=normalizedButton({...current,...update});
    element.dataset.state=current.state;element.dataset.progress=String(current.progress);
    element.disabled=current.state!=='ready';
    element.setAttribute('aria-label',buttonLabel(current.state,current.progress));
    element.querySelector('.brk-charge-face').setAttribute('d',chargeSector(current.progress,64));
    element.querySelector('.brk-charge-ring').setAttribute('stroke-dasharray',`${current.progress*100} 100`);
    if(current.state==='ready'&&previous!=='ready')element.classList.add('brk-ready-flash');
    else if(current.state!=='ready')element.classList.remove('brk-ready-flash');
  }
  const onAnimationEnd=event=>{if(event.animationName==='brk-ready-cue')element.classList.remove('brk-ready-flash');};
  const onClick=()=>{if(!disposed&&current.state==='ready')options.onPress?.();};
  element.addEventListener('click',onClick);
  element.addEventListener('animationend',onAnimationEnd);
  return {element,setState,getState:()=>({...current}),destroy(){disposed=true;element.removeEventListener('click',onClick);element.removeEventListener('animationend',onAnimationEnd);host.replaceChildren();}};
}

// Floor effect: expands beneath bodies; per-enemy hits are visual, not a second speed model.
export function mountBrakeWave(host,{duration=BRAKE_UI.waveMs,reducedMotion,onHit=()=>{}}={}) {
  if(!Number.isFinite(duration)||duration<=160)throw new RangeError('Wave duration must exceed 160 ms');
  host.innerHTML='<svg class="brk-wave-svg" viewBox="0 0 380 380" aria-hidden="true"><circle cx="190" cy="190" r="18"/><circle cx="190" cy="190" r="18"/><circle cx="190" cy="190" r="18"/></svg>';
  const svg=host.querySelector('svg'),rings=[...svg.children],reduced=reducedMotion??window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let raf=0,disposed=false,active=false,targets=[],hit=new Set();
  const reach=Math.hypot(190,190)+12;
  function stop(){cancelAnimationFrame(raf);raf=0;active=false;svg.dataset.active='false';rings.forEach(el=>el.setAttribute('opacity','0'));}
  function play(nextTargets=[]){
    if(disposed)return;stop();targets=nextTargets;hit=new Set();active=true;svg.dataset.active='true';
    const start=performance.now();
    function frame(now){
      const elapsed=now-start;
      rings.forEach((ring,i)=>{const t=clamp((elapsed-i*80)/(duration-160));const radius=reduced?30:18+(reach-18)*(1-(1-t)**1.4);ring.setAttribute('r',String(radius));ring.setAttribute('stroke-width',String(2.4-1.3*t));ring.setAttribute('opacity',elapsed<i*80?'0':String((reduced ? .18 : .58)*(1-t)));});
      const t=clamp(elapsed/(duration-160)),radius=18+(reach-18)*(1-(1-t)**1.4);
      targets.forEach((target,i)=>{if(!hit.has(i)&&(reduced||Math.hypot(target.x-190,target.y-190)<=radius)){hit.add(i);onHit(target,i);}});
      if(elapsed<duration)raf=requestAnimationFrame(frame);else stop();
    }
    frame(start);
  }
  stop();
  return {play,stop,getState:()=>({active,hits:hit.size}),destroy(){disposed=true;stop();host.replaceChildren();}};
}

export function speedBar({value=0,max=BRAKE_UI.maximumSpeed}={}) {
  finite(value,'value');if(!Number.isFinite(max)||max<=0)throw new RangeError('max must be positive');
  const v=clamp(value,0,max);
  return `<div class="brk-speed" role="progressbar" aria-label="Скорость врагов" aria-valuemin="0" aria-valuemax="${max}" aria-valuenow="${v}"><span class="brk-speed-fill" style="width:${v/max*100}%"></span><span class="brk-speed-loss"></span><span class="brk-speed-caption">скорость врагов</span></div>`;
}

export function mountSpeedBar(host,options={}) {
  const max=options.max??150;
  host.innerHTML=speedBar(options);
  const element=host.querySelector('.brk-speed'),fill=element.querySelector('.brk-speed-fill'),loss=element.querySelector('.brk-speed-loss');
  let value=clamp(options.value??0,0,max),visual=value,base=value,tail=0,raf=0,disposed=false,braking=false;
  const reduced=options.reducedMotion??window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function cancel(){cancelAnimationFrame(raf);raf=0;braking=false;}
  function paint(){fill.style.width=`${base/max*100}%`;loss.style.left=`${base/max*100}%`;loss.style.width=`${tail/max*100}%`;loss.hidden=tail<=0;element.dataset.braking=String(braking);element.setAttribute('aria-valuenow',String(value));}
  function setValue(next,{duration=0}={}){
    finite(next,'value');if(disposed)return;const from=visual;
    cancel();value=clamp(next,0,max);tail=0;
    if(reduced||duration<=0){base=visual=value;paint();return;}
    const start=performance.now(),target=value;
    function frame(now){const t=clamp((now-start)/duration);base=visual=from+(target-from)*(1-(1-t)**2);paint();if(t<1)raf=requestAnimationFrame(frame);else raf=0;}
    raf=requestAnimationFrame(frame);
  }
  function brakeTo(next,{holdMs=BRAKE_UI.lossHoldMs,fadeMs=BRAKE_UI.lossFadeMs}={}) {
    finite(next,'value');if(disposed)return;
    const before=visual,target=clamp(next,0,max);cancel();
    if(target>=before){setValue(target,{duration:220});return;}
    value=base=target;tail=before-target;visual=before;braking=true;paint();
    const start=performance.now(),initialTail=tail,hold=Math.max(0,holdMs),fade=reduced?0:Math.max(0,fadeMs);
    function frame(now){const t=now-start<hold?0:fade===0?1:clamp((now-start-hold)/fade);tail=initialTail*(1-t)**2;visual=base+tail;if(t===1){tail=0;braking=false;raf=0;}paint();if(t<1)raf=requestAnimationFrame(frame);}
    raf=requestAnimationFrame(frame);
  }
  paint();
  return {element,setValue,brakeTo,getState:()=>({value,visual,tail,braking}),destroy(){disposed=true;cancel();host.replaceChildren();}};
}

const hero='<img class="brk-hero" src="art/my-attempts/hero-ready.png" alt="Герой Untouch">';
const enemies='<i class="brk-enemy brk-enemy-a"></i><i class="brk-enemy brk-enemy-b"></i><i class="brk-enemy brk-enemy-c"></i><i class="brk-enemy brk-enemy-d"></i>';

export function brakeKitPage() {
  const s=initialState();
  return `<section class="section-head"><h2><span class="index">B01 / B02</span>Торможение</h2><p>Улитка, зарядка фона и шкала скорости</p></section>
    <div class="brk-lab-layout"><section class="brk-live-card"><div class="brk-live-phone">
      <div class="brk-hud" inert>${hudHeader(s,{remaining:0,live:false})}</div><div class="brk-clock" data-brk-clock>00:00.000</div><p class="brk-round-note">Риск 0 · Шаги 0</p>
      <div class="brk-live-arena"><div class="brk-live-pedal" data-brk-live-button></div><div class="brk-wave" data-brk-wave></div>${enemies}${hero}</div>
      <div data-brk-live-speed></div><p class="brk-scene-status" data-brk-status aria-live="polite">До готовности 8 с</p>
    </div></section><aside class="brk-tools"><h3>Попробуйте в движении</h3><p>Заряженная улитка приподнимается, коротко вспыхивает и становится зеленее. Нажмите: кнопка утопится и пустит волну торможения по полю.</p>
      <div class="brk-tool-actions"><button class="neon-btn primary" data-brk-action="toggle">Запустить</button><button class="neon-btn" data-brk-action="reset">Сначала</button><button class="neon-btn" data-brk-action="ready">Показать готовую</button><button class="neon-btn" data-brk-action="wave">Показать волну</button></div>
      <p>Через 8 секунд кнопка снова поднимется. Фон и обводка заряжаются по часовой стрелке. Враги и герой проходят поверх кнопки.</p>
      <label class="brk-size-control">Ширина образца<select data-brk-width><option>320</option><option>360</option><option selected>390</option><option>430</option></select></label>
      <small>Это демонстрация компонентов. Герой отодвинут для обзора. Данные, баланс и основная игра не меняются.</small></aside></div>
    <section class="brk-section"><h3>B01 · Четыре состояния кнопки</h3><div class="brk-state-grid">${[['uncharged',0,'Не заряжена','Утоплена, почти серый фон'],['charging',.5,'Заряжается','Окрашена правая половина'],['ready',1,'Заряжена','Зелёная, поднята над основанием'],['pressed',1,'Нажатие','Утоплена, короткая вспышка']].map(([state,progress,title,note])=>`<article class="brk-state-card"><h4>${title}</h4><div class="brk-state-floor"><div data-brk-specimen="${state}" data-progress="${progress}"></div>${hero}</div><p>${note}</p>${state==='pressed'?'<button class="brk-small-action" data-brk-action="flash">Повторить вспышку</button>':''}</article>`).join('')}</div>
      <div class="brk-charge-scrub"><label>Посмотреть зарядку фона<input type="range" min="0" max="100" value="50" data-brk-charge aria-label="Заряд кнопки"></label><span>От серого к салатовому, по часовой стрелке</span></div></section>
    <section class="brk-section"><h3>B01 · Кнопка под игровыми объектами</h3><div class="brk-layer-grid">${['enemy','hero'].map(kind=>`<article class="brk-state-card"><h4>${kind==='enemy'?'Враг выше кнопки':'Герой выше кнопки'}</h4><div class="brk-state-floor brk-layer-floor"><div class="brk-layer-pedal" data-brk-layer-button></div>${kind==='enemy'?'<i class="brk-enemy brk-layer-enemy"></i>':'<img class="brk-hero brk-layer-hero" src="art/my-attempts/hero-ready.png" alt="Герой поверх кнопки">'}</div></article>`).join('')}</div></section>
    <section class="brk-section"><h3>B02 · Скорость врагов</h3><div class="brk-meter-demo"><div data-brk-meter-demo></div><div class="brk-tool-actions"><button class="neon-btn" data-brk-action="grow">Показать рост</button><button class="neon-btn" data-brk-action="brake">Показать торможение</button></div><p>Светло-красное заполнение — скорость. Зелёный участок — та часть, которая сейчас исчезнет. Подпись внутри, чисел на шкале нет.</p></div></section>`;
}

export function mountBrakeKitPage(root) {
  let model=createBrakeDemo(),running=false,raf=0,last=0,pressedAt=-Infinity,disposed=false;
  const arena=root.querySelector('.brk-live-arena'),clock=root.querySelector('[data-brk-clock]'),status=root.querySelector('[data-brk-status]'),toggle=root.querySelector('[data-brk-action="toggle"]');
  const liveMeter=mountSpeedBar(root.querySelector('[data-brk-live-speed]'),{value:model.snapshot().speed});
  const isolatedMeter=mountSpeedBar(root.querySelector('[data-brk-meter-demo]'),{value:90});
  const liveButton=mountBrakeButton(root.querySelector('[data-brk-live-button]'),{onPress:press});
  const specimens=[...root.querySelectorAll('[data-brk-specimen]')].map(host=>mountBrakeButton(host,{state:host.dataset.brkSpecimen,progress:Number(host.dataset.progress),size:44}));
  const initialBodies=[[52,40,30,110,.8,.6],[235,63,60,60,-.6,.8],[13,235,42,85,.7,-.714],[202,236,103,35,-.8,-.6]];
  let bodies=initialBodies.map(b=>b.slice()),enemySpeed=model.snapshot().speed;
  const enemyEls=[...arena.querySelectorAll('.brk-enemy')],motionReduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const layerButtons=[...root.querySelectorAll('[data-brk-layer-button]')].map(host=>mountBrakeButton(host,{state:'ready'}));
  const hitTimers=new Set();
  const wave=mountBrakeWave(root.querySelector('[data-brk-wave]'),{onHit(target){target.element.classList.add('brk-wave-hit');const timer=setTimeout(()=>{target.element.classList.remove('brk-wave-hit');hitTimers.delete(timer);},160);hitTimers.add(timer);}});
  function clearWave(){wave.stop();hitTimers.forEach(clearTimeout);hitTimers.clear();enemyEls.forEach(el=>el.classList.remove('brk-wave-hit'));}
  function drawBodies(){bodies.forEach(([x,y,w,h],i)=>Object.assign(enemyEls[i].style,{left:`${x/380*100}%`,top:`${y/380*100}%`,width:`${w/380*100}%`,height:`${h/380*100}%`}));}
  function paint(now=performance.now()) {
    const s=model.snapshot(),pressed=now-pressedAt<BRAKE_UI.pressMs;
    liveButton.setState({state:pressed?'pressed':s.ready?'ready':s.progress>0?'charging':'uncharged',progress:s.progress});
    arena.classList.toggle('is-braking',pressed);
    if(!liveMeter.getState().braking)liveMeter.setValue(s.speed);
    const ms=Math.floor(s.elapsed*1000),seconds=Math.floor(ms/1000);
    clock.textContent=`${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}.${String(ms%1000).padStart(3,'0')}`;
    const text=pressed?'Торможение':s.ready?'Улитка готова':`До готовности ${Math.ceil(s.remaining)} с`;
    if(status.textContent!==text)status.textContent=text;
    drawBodies();
  }
  function frame(now) {
    if(disposed||!running)return;
    const dt=Math.max(0,(now-last)/1000);last=now;model.advance(dt);
    const target=model.snapshot().speed;
    enemySpeed+= (target-enemySpeed)*(1-Math.exp(-dt/0.075));
    if(!motionReduced)bodies.forEach(b=>{b[0]+=b[4]*enemySpeed*dt;b[1]+=b[5]*enemySpeed*dt;for(const [pos,dim,vel] of [[0,2,4],[1,3,5]]){const high=380-b[dim]-4;if(b[pos]<4){b[pos]=4;b[vel]=Math.abs(b[vel]);}else if(b[pos]>high){b[pos]=high;b[vel]=-Math.abs(b[vel]);}}});
    paint(now);raf=requestAnimationFrame(frame);
  }
  function start(){if(running||disposed)return;running=true;last=performance.now();toggle.textContent='Пауза';raf=requestAnimationFrame(frame);}
  function stop(){running=false;cancelAnimationFrame(raf);raf=0;clearWave();toggle.textContent='Продолжить';pressedAt=-Infinity;paint();}
  function press(){const result=model.press();if(!result)return;pressedAt=performance.now();liveMeter.brakeTo(result.after);wave.play(bodies.map(([x,y,w,h],i)=>({x:x+w/2,y:y+h/2,element:enemyEls[i]})));paint(pressedAt);start();}
  function reset(ready=false){stop();model.reset();if(ready)model.advance(8);pressedAt=-Infinity;bodies=initialBodies.map(b=>b.slice());enemySpeed=model.snapshot().speed;liveMeter.setValue(enemySpeed);paint();toggle.textContent='Запустить';}
  let flashTimer=0;
  function onClick(event){const action=event.target.closest('[data-brk-action]')?.dataset.brkAction;
    if(action==='toggle'){if(running)stop();else start();}
    if(action==='reset')reset();
    if(action==='ready')reset(true);
    if(action==='wave'){reset(true);press();}
    if(action==='grow')isolatedMeter.setValue(135,{duration:1200});
    if(action==='brake')isolatedMeter.brakeTo(45);
    if(action==='flash'){clearTimeout(flashTimer);specimens[3].element.classList.remove('brk-replay');void specimens[3].element.offsetWidth;specimens[3].element.classList.add('brk-replay');flashTimer=setTimeout(()=>specimens[3].element.classList.remove('brk-replay'),350);}
  }
  const scrub=root.querySelector('[data-brk-charge]'),width=root.querySelector('[data-brk-width]');
  const onScrub=()=>{const p=Number(scrub.value)/100;specimens[1].setState({state:p===0?'uncharged':p===1?'ready':'charging',progress:p});};
  const onWidth=()=>root.querySelector('.brk-live-phone').style.setProperty('--brk-preview-width',`${width.value}px`);
  const onVisibility=()=>{if(document.hidden)stop();};
  root.addEventListener('click',onClick);scrub.addEventListener('input',onScrub);width.addEventListener('change',onWidth);document.addEventListener('visibilitychange',onVisibility);paint();
  return ()=>{disposed=true;running=false;cancelAnimationFrame(raf);clearTimeout(flashTimer);clearWave();wave.destroy();root.removeEventListener('click',onClick);scrub.removeEventListener('input',onScrub);width.removeEventListener('change',onWidth);document.removeEventListener('visibilitychange',onVisibility);liveButton.destroy();liveMeter.destroy();isolatedMeter.destroy();specimens.forEach(c=>c.destroy());layerButtons.forEach(c=>c.destroy());};
}
