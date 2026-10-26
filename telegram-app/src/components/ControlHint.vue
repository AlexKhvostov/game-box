<script setup lang="ts">
import {onMounted,onBeforeUnmount,ref,watch} from 'vue';
import {hintPathD,hintPose,hintPresentation,HINT_LOOP_MS} from '../game/control-hint';
import type {WorldState} from '../domain/kernel';
import {telegram} from '../platform/telegram';
const props=defineProps<{field?:HTMLCanvasElement;player?:WorldState['player'];active:boolean}>();
const root=ref<HTMLElement>(),overlay=ref<HTMLCanvasElement>(),hand=ref<HTMLElement>();
const phase=ref('appearing');
let ctx:CanvasRenderingContext2D|null=null,route:Path2D,resize:ResizeObserver|undefined;
let raf=0,previous=0,elapsed=0,alive=true,foreground=true;
let media:MediaQueryList;
function stop(){if(raf)cancelAnimationFrame(raf);raf=0;previous=0;}
function permitted(){return alive&&props.active&&foreground&&!document.hidden&&telegram()?.isActive!==false;}
function ensure(){if(!raf&&permitted()&&!media.matches)raf=requestAnimationFrame(tick);}
function draw(){
  const el=root.value,cv=overlay.value,field=props.field,p=props.player;if(!el||!cv||!field||!p||!ctx)return;
  const rr=el.getBoundingClientRect(),fr=field.getBoundingClientRect(),logicalWidth=el.clientWidth;
  if(!rr.width||!fr.width||!logicalWidth)return;
  const outerScale=rr.width/logicalWidth,width=logicalWidth,height=el.clientHeight;
  const left=(fr.left-rr.left)/outerScale,top=(fr.top-rr.top)/outerScale,side=fr.width/outerScale,bottom=top+side;
  const pixelRatio=Math.min(devicePixelRatio||1,3)*outerScale;
  const pw=Math.max(1,Math.round(width*pixelRatio)),ph=Math.max(1,Math.round(height*pixelRatio));
  if(cv.width!==pw||cv.height!==ph){cv.width=pw;cv.height=ph;}
  ctx.setTransform(pw/width,0,0,ph/height,0,0);ctx.clearRect(0,0,width,height);
  const presentation=hintPresentation(elapsed,media.matches),pose=hintPose(presentation.motionMs);
  el.parentElement?.style.setProperty('--control-hint-copy-opacity',String(media.matches?1:1-presentation.opacity));
  if(phase.value!==presentation.phase)phase.value=presentation.phase;
  const scale=Math.min(side/348,Math.max(.2,(height-bottom-16)/210));
  const finger={x:left+side/2+pose.x*scale,y:bottom+56*scale+pose.y*scale};
  if(hand.value){hand.value.style.transform=`translate(${finger.x}px,${finger.y}px) scale(${scale})`;hand.value.style.opacity=String(presentation.opacity);}
  el.dataset.offsetX=String(pose.x*scale);el.dataset.offsetY=String(pose.y*scale);
  if(presentation.opacity<=0)return;
  ctx.save();ctx.translate(left+side/2,bottom+56*scale);ctx.scale(scale,scale);
  ctx.globalAlpha=presentation.opacity*.34;ctx.strokeStyle='#d7f7ff';ctx.lineWidth=1.4;ctx.lineCap='round';ctx.setLineDash([2,6]);ctx.stroke(route);ctx.restore();
  // Copy just the actual hero's body; no second world/physics and no top path.
  const bodySize=p.size*p.visualScale,sx=p.x+(p.size-bodySize)/2,sy=p.y+(p.size-bodySize)/2;
  const size=bodySize*side/380,x=left+(p.x+p.size/2)*side/380+pose.x*scale-size/2,
    y=top+(p.y+p.size/2)*side/380+pose.y*scale-size/2;
  ctx.save();ctx.globalAlpha=.52*presentation.opacity*Math.min(1,Math.hypot(pose.x,pose.y)/16);
  ctx.beginPath();ctx.roundRect(x,y,size,size,size*.1);ctx.clip();
  ctx.filter='grayscale(1) brightness(2.7)';
  ctx.drawImage(field,sx/380*field.width,sy/380*field.height,bodySize/380*field.width,bodySize/380*field.height,x,y,size,size);
  ctx.restore();
}
function tick(now:number){raf=0;if(!permitted()||media.matches){previous=0;return;}
  if(previous)elapsed=(elapsed+Math.max(0,now-previous))%HINT_LOOP_MS;previous=now;draw();ensure();}
function sync(){stop();draw();ensure();}
function deactivate(){foreground=false;sync();}
function activate(){foreground=true;sync();}
function visibility(){document.hidden?deactivate():activate();}
watch(()=>props.active,()=>sync());
onMounted(()=>{
  ctx=overlay.value!.getContext('2d');route=new Path2D(hintPathD);media=matchMedia('(prefers-reduced-motion: reduce)');
  foreground=telegram()?.isActive!==false;
  resize=new ResizeObserver(()=>draw());resize.observe(root.value!);if(props.field)resize.observe(props.field);
  media.addEventListener('change',sync);document.addEventListener('visibilitychange',visibility);
  telegram()?.onEvent('deactivated',deactivate);telegram()?.onEvent('activated',activate);sync();
});
onBeforeUnmount(()=>{alive=false;stop();resize?.disconnect();media.removeEventListener('change',sync);
  root.value?.parentElement?.style.removeProperty('--control-hint-copy-opacity');
  document.removeEventListener('visibilitychange',visibility);telegram()?.offEvent('deactivated',deactivate);telegram()?.offEvent('activated',activate);});
</script>
<template>
  <div ref="root" class="control-hint" aria-hidden="true" :data-hint-phase="phase">
    <canvas ref="overlay" class="control-hint-canvas"></canvas>
    <div ref="hand" class="control-hint-hand-anchor"><i></i><img src="/assets/branding/ui/control-hint-hand-v1.png" alt="" :draggable="false"></div>
  </div>
</template>
<style scoped>
.control-hint{position:absolute;inset:0;z-index:2;pointer-events:none;overflow:hidden;user-select:none}
.control-hint-canvas{position:absolute;inset:0;width:100%;height:100%;pointer-events:none}
.control-hint-hand-anchor{position:absolute;left:0;top:0;pointer-events:none;transform-origin:0 0;will-change:transform}
.control-hint-hand-anchor i{position:absolute;left:-9.5px;top:-9.5px;width:19px;height:19px;border:1px solid #c0f5ffa6;border-radius:50%;pointer-events:none}
.control-hint-hand-anchor img{position:absolute;width:210px;height:210px;max-width:none;left:-55.44px;top:-31.08px;opacity:.82;pointer-events:none;mask-image:linear-gradient(135deg,#000 0%,#000 25%,#000d 34%,#0005 45%,#0001 55%,transparent 65%);-webkit-mask-image:linear-gradient(135deg,#000 0%,#000 25%,#000d 34%,#0005 45%,#0001 55%,transparent 65%)}
</style>
