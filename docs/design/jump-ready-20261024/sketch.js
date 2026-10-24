import {createJumpGlowPixels,createJumpGlowDrawer} from './current-jump-glow.js';
// Isolated visual proposal. Never imported by Android, Telegram, or UI Kit.
const clamp=v=>Math.max(0,Math.min(1,v)),DURATION=2,SIGNAL=.42;
const media=matchMedia('(prefers-reduced-motion: reduce)'),el=id=>document.getElementById(id);
const base=createJumpGlowDrawer({radius:.1});
function texture(color,gain=1){
  const cv=document.createElement('canvas');cv.width=cv.height=256;const c=cv.getContext('2d');const im=c.createImageData(256,256);im.data.set(createJumpGlowPixels(256,{radius:.1}));
  for(let i=0;i<im.data.length;i+=4){im.data[i]=color[0];im.data[i+1]=color[1];im.data[i+2]=color[2];im.data[i+3]=Math.round(Math.min(255,im.data[i+3]*gain));}c.putImageData(im,0,0);return cv;
}
const readyTextures={gold:texture([255,247,170],1.2),lime:texture([232,255,105],1.3),sweep:texture([255,241,142],1.1)},flashTexture=texture([255,255,236],1.65);
const state={progress:1,readyAge:10,paused:true,helmet:true,reduced:media.matches,signals:0,frozen:false};
function face(c,x,y,s){
  c.save();c.translate(x,y);c.scale(s,s);const ink='#122c38';
  for(const side of [-1,1]){const ex=.5+side*.21,ey=.39;
    for(const [cx,cy,rx,ry,color]of [[ex,ey,.115,.16,'#f4ffff'],[ex,ey,.075,.12,ink],[ex,ey+.06,.0625,.05,'#179cb0'],[ex-.035,ey-.065,.038,.038,'#f4ffff'],[ex+.035,ey+.04,.018,.018,'#f4ffff'],[.5+side*.29,.62,.065,.0325,'#ff89ada6']]){c.fillStyle=color;c.beginPath();c.ellipse(cx,cy,rx,ry,0,0,Math.PI*2);c.fill();}}
  c.strokeStyle=ink;c.lineWidth=.035;c.lineCap='round';c.beginPath();c.moveTo(.4,.69);c.quadraticCurveTo(.5,.82,.6,.69);c.stroke();c.restore();
}
function bodyPath(c,x,y,s){c.beginPath();c.roundRect(x,y,s,s,s*.1);}
export function signalStrength(age,reduced=false){return reduced||age<0||age>=SIGNAL?0:Math.sin(Math.PI*age/SIGNAL);}
function hero(c,x,y,s,style,progress,age,{helmet=state.helmet,reduced=state.reduced}={}){
  c.save();c.fillStyle='#0006';bodyPath(c,x+s*.12,y+s*.15,s);c.fill();
  const g=c.createLinearGradient(x,y,x+s,y+s);g.addColorStop(0,'#b2fbe9');g.addColorStop(.35,'#35f5c6');g.addColorStop(1,'#13bda5');bodyPath(c,x,y,s);c.fillStyle=g;c.fill();c.strokeStyle='#8affcd';c.lineWidth=s/44*1.4;c.stroke();
  c.save();bodyPath(c,x,y,s);c.clip();
  const ready=progress>=1,flash=signalStrength(age,reduced);
  if(!ready)base(c,{x,y,size:s,progress});
  else{
    c.drawImage(readyTextures[style],x,y,s,s);
    if(flash>0&&style!=='sweep'){c.globalAlpha=flash;c.drawImage(flashTexture,x,y,s,s);c.globalAlpha=1;}
    if(style==='sweep'){
      if(!reduced&&age>=0&&age<SIGNAL){
        const t=age/SIGNAL,cy=y+s*(1-t),h=s*.24;c.save();c.beginPath();c.rect(x,cy-h/2,s,h);c.clip();c.globalAlpha=Math.sin(Math.PI*t);c.drawImage(flashTexture,x,y,s,s);c.restore();
      }
      c.strokeStyle='#fff9c8';c.lineWidth=s*.023;c.lineCap='round';c.beginPath();c.moveTo(x+s*.04,y+s*.13);c.lineTo(x+s*.13,y+s*.055);c.moveTo(x+s*.87,y+s*.055);c.lineTo(x+s*.96,y+s*.13);c.stroke();
    }
  }c.restore();
  // Face remains exactly as before: the light never flashes over the eyes.
  face(c,x,y,s);
  if(helmet){c.strokeStyle='#a4efff';c.lineWidth=s/44*2.6;c.beginPath();c.roundRect(x-s*2.5/44,y-s*2.5/44,s+s*5/44,s+s*5/44,s*6.5/44);c.stroke();c.strokeStyle='#a4efff77';c.lineWidth=s/44*1.2;c.beginPath();c.roundRect(x-s*5/44,y-s*5/44,s+s*10/44,s+s*10/44,s*9/44);c.stroke();}
  c.restore();
}
function ground(c,w,h){c.fillStyle='#082b40';c.fillRect(0,0,w,h);c.strokeStyle='#22536a66';c.lineWidth=.7;for(let n=20;n<w;n+=24){c.beginPath();c.moveTo(n,0);c.lineTo(n,h);c.stroke();}for(let n=20;n<h;n+=24){c.beginPath();c.moveTo(0,n);c.lineTo(w,n);c.stroke();}}
function live(cv,style){const w=cv.clientWidth,h=172;if(cv.width!==Math.round(w*2)){cv.width=Math.round(w*2);cv.height=h*2;}const c=cv.getContext('2d');c.setTransform(2,0,0,2,0,0);ground(c,w,h);hero(c,26,70,44,style,state.progress,state.readyAge);hero(c,w-130,22,116,style,state.progress,state.readyAge);cv.dataset.bodyCssSize='44';}
const styles=['gold','lime','sweep'];
for(const style of styles){const row=document.createElement('div');row.className='story-row';row.innerHTML=`<strong>${({gold:'A · Золото',lime:'B · Лимон',sweep:'C · Блик'})[style]}</strong>`;for(const [p,age]of [[.9,-1],[1,SIGNAL/2],[1,1]]){const cv=document.createElement('canvas');cv.width=380;cv.height=230;cv.dataset.storyStyle=style;cv.dataset.progress=String(p);cv.dataset.age=String(age);row.append(cv);}el('story').append(row);}
function render(){
  for(const cv of document.querySelectorAll('.live'))live(cv,cv.dataset.style);
  for(const cv of document.querySelectorAll('[data-story-style]')){const c=cv.getContext('2d');c.setTransform(2,0,0,2,0,0);ground(c,190,115);hero(c,59,20,70,cv.dataset.storyStyle,Number(cv.dataset.progress),Number(cv.dataset.age));}
  const p=state.progress>=1?100:Math.min(99,Math.floor(state.progress*100));el('charge').value=String(p);el('percent').textContent=`${p}%`;el('pause').textContent=state.paused?'Продолжить':'Пауза';el('helmet').checked=state.helmet;el('reduced').checked=state.reduced;
  el('status').textContent=state.progress>=1?'Готов · 100%':`Зарядка · ${p}%`;el('status').dataset.phase=state.progress>=1?(state.readyAge<SIGNAL?'signal':'ready'):'charging';
}
function setProgress(p){const was=state.progress>=1;state.progress=clamp(p);if(state.progress>=1&&!was){state.readyAge=0;state.signals++;}else if(state.progress<1)state.readyAge=-1;}
function advance(dt){if(state.paused||!Number.isFinite(dt)||dt<=0)return;const was=state.progress>=1;if(!was)setProgress(state.progress+dt/DURATION);if(was)state.readyAge+=dt;}
function start(p){Object.assign(state,{progress:p,readyAge:-1,paused:false,frozen:false});previous=performance.now();render();}
el('jump').onclick=()=>start(0);el('last').onclick=()=>start(.75);el('signal').onclick=()=>{state.frozen=false;setProgress(.99);setProgress(1);state.paused=false;previous=performance.now();render();};
el('pause').onclick=()=>{state.paused=!state.paused;previous=performance.now();render();};el('charge').oninput=()=>{state.paused=true;setProgress(Number(el('charge').value)/100);render();};el('helmet').onchange=()=>{state.helmet=el('helmet').checked;render();};el('reduced').onchange=()=>{state.reduced=el('reduced').checked;render();};media.onchange=e=>{state.reduced=e.matches;render();};
let previous=performance.now();function loop(now){const dt=Math.min(.05,(now-previous)/1000);previous=now;if(!document.hidden&&!state.frozen){if(state.paused&&state.readyAge>=0&&state.readyAge<SIGNAL){state.readyAge+=dt;render();}else if(!state.paused&&(state.progress<1||state.readyAge<SIGNAL)){advance(dt);render();}}requestAnimationFrame(loop);}render();requestAnimationFrame(loop);
// Only the standalone sketch exposes this deterministic acceptance hook.
window.jumpReadySketch={state,setProgress,advance,render,signalStrength,setFrame:(p,age)=>{Object.assign(state,{progress:p,readyAge:age,paused:true,frozen:true});render();}};
new ResizeObserver(()=>render()).observe(el('motion-board'));
