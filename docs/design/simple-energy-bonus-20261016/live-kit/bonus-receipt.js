import {energySheet,home,icon} from './components.js?v=soft-arrows-3';
import {rewardFor} from './model.js';

let active=null;
const ease=t=>1-Math.pow(1-Math.max(0,Math.min(1,t)),3);
export const receiptPlaying=()=>!!active;
export function cancelReceipt(){active?.finish(true);}

// Presentation only: the caller commits the confirmed reward ONCE before this.
// Cancel/resize/close end the visuals, never reverse or repeat the transaction.
export function playEnergyReward({source,from,to,amount,duration=1600,reduce=false}){
  cancelReceipt();
  const sheet=source?.closest('.energy-sheet');
  // The visible game's top-left wallet is the only destination. Isolated
  // library specimens retain a predictable top-left endpoint, never a modal balance.
  const stage=source?.closest('.receipt-stage,.phone-screen,.spec-preview');
  const visible=el=>el.getBoundingClientRect().width>0&&el.getBoundingClientRect().height>0;
  const target=[...(stage||document).querySelectorAll('.home-stage .hud-energy-number')].find(visible)
    ||[...document.querySelectorAll('.home-stage .hud-energy-number')].find(visible);
  const counters=[target?.firstChild,sheet?.querySelector('.sheet-head .balance-text')?.firstChild].filter(n=>n?.nodeType===3);
  if(!source||!sheet)return Promise.resolve({cancelled:false});
  const reduced=reduce||matchMedia('(prefers-reduced-motion: reduce)').matches;
  duration=reduced?180:duration;
  const start=source.getBoundingClientRect(),end=target?.getBoundingClientRect(),panel=sheet.getBoundingClientRect();
  // Keep the Telegram reward -> balance choreography; one visual focal point.
  const width=Math.min(230,panel.width*.86,innerWidth-40);
  const sx=Math.max(width/2+16,Math.min(innerWidth-width/2-16,panel.x+panel.width/2));
  const sy=Math.max(104,Math.min(innerHeight-104,start.y+start.height*.47));
  const tx=end?end.x+end.width/2:innerWidth/4,ty=end?end.y+end.height/2:52;
  const layer=document.createElement('div');
  layer.className='receipt-fx';layer.setAttribute('aria-hidden','true');
  layer.classList.toggle('receipt-fx-reduced',reduced);
  const core='<svg viewBox="0 0 96 108" aria-hidden="true"><defs><linearGradient id="reward-core-gold" x1=".2" y1="0" x2=".8" y2="1"><stop stop-color="#fffbd0"/><stop offset=".38" stop-color="#fff168"/><stop offset="1" stop-color="#ffb719"/></linearGradient></defs><path d="m55 5 7 5-1 31 28 5-48 61-7-4 8-46H15l7 5Z" fill="#bd740d"/><path d="M55 5 15 57h27l-8 46 48-61H54Z" fill="url(#reward-core-gold)" stroke="#fffac2" stroke-width="1.5" stroke-linejoin="round"/><path d="m53 13-26 36h16Z" fill="#ffffe0" opacity=".8"/><path d="m43 62-5 30 32-43" fill="none" stroke="#ffd64c" stroke-width="2"/></svg>';
  layer.innerHTML='<i class="receipt-aura"></i><i class="receipt-reveal-flare"></i><i class="receipt-reveal-rays"></i><i class="receipt-shockwave"></i>'+
    '<div class="receipt-reward-card"><span class="receipt-title">Энергия получена!</span><span class="receipt-energy-core">'+core+'</span><span class="receipt-payout"><strong>+'+amount+'</strong><small>энергии</small></span></div>'+
    (reduced?'':Array.from({length:6},(_,i)=>'<span class="receipt-mote '+(i%3?'tiny':'bolt')+'">'+(i%3?'':icon('bolt'))+'</span>').join('')+Array.from({length:28},(_,i)=>'<i class="receipt-firework '+(i%3===0?'star':'')+'"></i>').join(''));
  document.body.append(layer);
  const gain=layer.querySelector('.receipt-reward-card'),aura=layer.querySelector('.receipt-aura');
  const flare=layer.querySelector('.receipt-reveal-flare'),rays=layer.querySelector('.receipt-reveal-rays'),shock=layer.querySelector('.receipt-shockwave');
  Object.assign(aura.style,{left:sx+'px',top:sy+'px',width:(width*1.45)+'px',height:(width*1.35)+'px'});
  [flare,rays,shock].forEach(el=>Object.assign(el.style,{left:sx+'px',top:(sy-18)+'px'}));
  const payoutSize=Math.min(56,width*.25,(width-72)/(String(amount).length+1)/.75);
  gain.style.width=width+'px';
  gain.style.setProperty('--payout-size',payoutSize+'px');
  const motes=[...layer.querySelectorAll('.receipt-mote')];
  const fireworks=[...layer.querySelectorAll('.receipt-firework')];
  source.classList.add('receipt-source');source.disabled=true;source.setAttribute('aria-busy','true');
  sheet.classList.add('receipt-on');
  source.classList.toggle('receipt-reduced',reduced);
  target?.classList.add('receipt-target');
  const format=n=>Math.round(n).toLocaleString('ru-RU');
  const clamp=n=>Math.max(0,Math.min(1,n));
  const pop=n=>1+2.70158*Math.pow(n-1,3)+1.70158*Math.pow(n-1,2);
  counters.forEach(count=>count.textContent=format(from));
  return new Promise(resolve=>{
    let frame=0,done=false;const started=performance.now();
    const run={finish(cancelled=false){
      if(done)return;done=true;cancelAnimationFrame(frame);layer.remove();
      source.classList.remove('receipt-source','receipt-reduced');source.removeAttribute('aria-busy');
      sheet.classList.remove('receipt-on');
      target?.classList.remove('receipt-target');target?.style.removeProperty('--receipt-hit');
      counters.forEach(count=>count.textContent=format(to));
      window.removeEventListener('resize',stop);window.removeEventListener('scroll',stop,true);
      document.removeEventListener('visibilitychange',hidden);
      if(active===run)active=null;
      resolve({cancelled});
    }};
    const stop=()=>run.finish(true),hidden=()=>{if(document.hidden)stop();};
    active=run;
    window.addEventListener('resize',stop);window.addEventListener('scroll',stop,true);
    document.addEventListener('visibilitychange',hidden);
    function paint(now){
      if(!source.isConnected){stop();return;}
      const p=clamp((now-started)/duration);
      const appearance=clamp(p/.1125),flight=reduced?0:clamp((p-.4)/.4);
      const fly=flight<.5?4*flight*flight*flight:1-Math.pow(-2*flight+2,3)/2;
      const scale=reduced?1:(.82+.18*pop(appearance))*(1-.78*fly);
      const cardX=sx+(tx-sx)*fly,cardY=sy+(ty-sy)*fly-(reduced?0:Math.sin(Math.PI*flight)*30);
      gain.style.transform='translate('+cardX+'px,'+cardY+'px) translate(-50%,-50%) scale('+Math.max(.05,scale)+')';
      gain.style.opacity=String(appearance*(1-clamp((flight-.76)/.24)));
      const celebration=clamp(p/.6),shine=Math.sin(Math.PI*celebration);
      aura.style.transform='translate(-50%,-50%) scale('+(0.7+ease(celebration)*.5)+')';
      aura.style.opacity=reduced?'0':String(clamp(p/.1)*(1-clamp((p-.4)/.22)));
      const flash=clamp((p-.04)/.27),wave=clamp((p-.08)/.32);
      flare.style.opacity=reduced?'0':String(Math.sin(Math.PI*flash)*.75);
      flare.style.transform='translate(-50%,-50%) scale('+(0.35+ease(flash)*1.15)+')';
      rays.style.opacity=reduced?'0':String(shine*.3);
      rays.style.transform='translate(-50%,-50%) rotate('+(p*18)+'deg)';
      shock.style.opacity=reduced?'0':String(Math.sin(Math.PI*wave)*.55);
      shock.style.transform='translate(-50%,-50%) scale('+(0.3+ease(wave)*1.5)+')';
      fireworks.forEach((el,i)=>{
        const t=clamp((p-.055-(i%4)*.012)/.46),a=i*2.399963;
        const radius=45+(25+i%5*12)*ease(t);
        const x=sx+Math.cos(a)*radius;
        const y=sy-18+Math.sin(a)*radius+t*t*18;
        el.style.transform='translate('+x+'px,'+y+'px) translate(-50%,-50%) rotate('+(i*25+t*45)+'deg) scale('+(1-t*.5)+')';
        el.style.opacity=t>0&&t<1?String(Math.min(1,t*12,(1-t)*4)):'0';
      });
      motes.forEach((el,i)=>{
        const t=clamp((p-.4-i*.012)/.34),v=t*t*(3-2*t),side=(i%2?1:-1);
        const cx=sx+side*(20+i*4),cy=sy-60-i*4;
        const x=(1-v)*(1-v)*sx+2*(1-v)*v*cx+v*v*tx;
        const y=(1-v)*(1-v)*sy+2*(1-v)*v*cy+v*v*ty;
        el.style.transform='translate('+x+'px,'+y+'px) translate(-50%,-50%) scale('+(0.55+Math.sin(Math.PI*t)*.65)+')';
        el.style.opacity=t>0&&t<1?String(Math.min(1,t*12,(1-t)*10)):'0';
      });
      const roll=reduced?p:clamp((p-.8)/.2);
      counters.forEach(count=>count.textContent=format(from+(to-from)*roll));
      target?.style.setProperty('--receipt-hit',String(reduced?0:Math.sin(Math.PI*clamp((p-.83)/.17))));
      layer.dataset.phase=p<.1125?'burst':p<.4?'celebrate':p<.8?'flight':p<.96?'credit':'settle';
      if(p<1)frame=requestAnimationFrame(paint);else run.finish();
    }
    frame=requestAnimationFrame(paint);
  });
}

export function bonusMotionPage(state,{slow=false,reduce=false}={}){
  return '<section class="receipt-layout"><article class="receipt-preview"><div class="spec-label">E01.M / Энергия в награду<span>LIVE MOTION</span></div><div class="receipt-stage"><div class="receipt-home">'+home(state)+'</div>'+energySheet(state)+'</div><p class="receipt-live-note">'+(state.bonusAt>Date.now()+state.offset?'Энергия на балансе · бонус на перезарядке':'Нажмите «Забрать» — энергия перелетит в баланс')+'</p></article>'+
    '<aside class="receipt-guide"><p class="eyebrow">ENERGY / REWARD MOTION</p><h2>Одна награда.<br>Бонус и реклама.</h2><p class="receipt-description">Energy Burst: раскрытие светящегося заряда, звёздный салют и перелёт в баланс. Одна анимация для бонуса и успешного видео, около1,6 секунды.</p><div class="receipt-demo-controls"><button class="neon-btn primary" data-action="receipt-replay">'+icon('bolt')+'Повторить награду · '+rewardFor(state)+'</button><button class="neon-btn receipt-video-preview" data-action="receipt-video">'+icon('play')+'Проверить после рекламы · +40</button><div class="receipt-plan-row">'+[1,2,5].map(n=>'<button class="neon-btn '+(state.plan===n?'selected':'')+'" data-action="receipt-plan-'+n+'" aria-pressed="'+(state.plan===n)+'">'+(n===1?'Обычный':'Подписка ×'+n)+'<small>+'+(30*n)+' '+icon('bolt')+'</small></button>').join('')+'</div><label class="receipt-option"><input type="checkbox" id="receipt-slow" '+(slow?'checked':'')+'> Замедлить ×4 · рассмотреть движение</label><label class="receipt-option"><input type="checkbox" id="receipt-reduced" '+(reduce?'checked':'')+'> Спокойный вариант · без перелёта</label></div><ol class="receipt-steps"><li><span>01</span><div><strong>Отклик на нажатие</strong><p>Объёмная молния раскрывается во вспышке, вокруг расходится звёздный салют.</p><small>0–180 мс</small></div></li><li><span>02</span><div><strong>Награда сама летит в баланс</strong><p>Награда читается до640 мс, затем превращается в заряд и улетает к счётчику.</p><small>180–1280 мс</small></div></li><li><span>03</span><div><strong>Баланс принимает заряд</strong><p>Сначала заряд долетает до основного счётчика слева вверху. Затем оба числа быстро прокручиваются к новому балансу.</p><small>1200–1600 мс</small></div></li></ol><p class="receipt-footnote">Это демонстрация компонентов. Суммы взяты из текущего UI kit. Награда учитывается один раз; анимация только показывает получение.</p><a href="bonus-receipt-spec.md" target="_blank">Спецификация анимации для разработчика ↗</a></aside></section>';
}
