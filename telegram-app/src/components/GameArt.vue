<script setup lang="ts">
import { ref, watch, onMounted, onBeforeUnmount, nextTick, getCurrentInstance } from 'vue';
import { state } from '../services/game-store';
import LoadingClock from './LoadingClock.vue';
defineOptions({inheritAttrs:false});
const props = withDefaults(defineProps<{ src: string; alt?: string }>(), { alt: '' });
const emit=defineEmits<{unavailable:[value:boolean]}>();
// A fragment does not automatically inherit the caller's scoped CSS marker.
// Preserve the old single-img-root styling contract. Current callers have no
// :slotted selectors; scopeId is the public VNode parent-scoped-style marker.
const instance=getCurrentInstance();
const inheritedScope=instance?.vnode.scopeId?{[instance.vnode.scopeId]:''}:{};
const image=ref<HTMLImageElement|null>(null), failed=ref(false), pending=ref(true), retry=ref(0), generation=ref(0);
const overlay=ref<{left:number;top:number;width:number;height:number;size:number;z:number;clip:string;opacity:number}|null>(null);
const placeholder = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="10" y="10" width="44" height="44" rx="12" fill="#062b40" stroke="#468ca4"/><path d="M23 32a9 9 0 1 1 3 7m-3-7v8h8" fill="none" stroke="#9cdeec" stroke-width="3" stroke-linecap="round"/></svg>');
const mounted=ref(false);
let deadline:ReturnType<typeof setTimeout>|undefined,resizeObserver:ResizeObserver|undefined,mutationObserver:MutationObserver|undefined;
const motionEvents=['animationstart','animationend','animationcancel','transitionrun','transitionstart','transitionend','transitioncancel'] as const;
const motionProperties=new Set(['opacity','transform','translate','scale','rotate','width','height','top','left','right','bottom','inset','clipPath']);
let motionFrame:number|undefined,motionUntil=0,motionCapped=false,motionListening=false;
// Follow only finite relevant ancestor motion while an image is pending. Current
// window entry/exit lasts160/100ms;2s is a hard safety budget, never a15s loop.
function finiteMotionActive(){
 const img=image.value;if(!mounted.value||!pending.value||!img||document.hidden)return false;
 let active=false;
 for(let element:Element|null=img;element;element=element.parentElement){
  const css=getComputedStyle(element);
  if(css.display==='none'||css.visibility!=='visible'||(element instanceof HTMLElement&&(element.hidden||element.inert)))return false;
  for(const animation of element.getAnimations?.()??[]){
   if(animation.playState!=='running'&&!animation.pending)continue;
   const effect=animation.effect as KeyframeEffect|null,end=effect?.getComputedTiming().endTime;
   if(typeof end!=='number'||!Number.isFinite(end)||end<=0||typeof effect?.getKeyframes!=='function')continue;
   if(effect.getKeyframes().some(frame=>Object.keys(frame).some(key=>motionProperties.has(key))))active=true;
  }
 }
 return active;
}
function cancelMotionFrame(){if(motionFrame!==undefined){cancelAnimationFrame(motionFrame);motionFrame=undefined;}}
function updateMotion(){
 motionFrame=undefined;placeClock();
 if(!finiteMotionActive())return;
 if(performance.now()>=motionUntil){motionCapped=true;overlay.value=null;return;}
 motionFrame=requestAnimationFrame(updateMotion);
}
function refreshClock(){
 placeClock();
 if(!finiteMotionActive()){cancelMotionFrame();return;}
 if(motionFrame===undefined&&!motionCapped){motionUntil=performance.now()+2000;motionFrame=requestAnimationFrame(updateMotion);}
}
function motionEvent(event:Event){
 const target=event.target,img=image.value;
 if(!pending.value||!img||!(target instanceof Element)||!target.contains(img))return;
 motionCapped=false;refreshClock();
}
function listenMotion(){if(!motionListening){motionListening=true;for(const name of motionEvents)document.addEventListener(name,motionEvent,true);}}
function stopMotion(){cancelMotionFrame();motionUntil=0;motionCapped=false;if(motionListening){motionListening=false;for(const name of motionEvents)document.removeEventListener(name,motionEvent,true);}}
function clearDeadline(){if(deadline!==undefined){clearTimeout(deadline);deadline=undefined;}}
// The img stays the parent's direct child. A pending-only portal avoids changing
// img selectors, inline baselines, object-fit, full-bleed positioning or hit targets.
function placeClock(){
 const img=image.value;
 if(!mounted.value||!pending.value||!img||document.hidden){overlay.value=null;return;}
 let box=img.getBoundingClientRect();
 const ownCss=getComputedStyle(img);
 if(!img.getClientRects().length||ownCss.visibility!=='visible'||Number(ownCss.opacity)===0){overlay.value=null;return;}
 // Auto-sized backgrounds/tube crops have no intrinsic bitmap size while held.
 // Use their existing allocated parent only for the clock, never resize the img.
 if((!box.width||!box.height)&&img.parentElement)box=img.parentElement.getBoundingClientRect();
 if(!box.width||!box.height){overlay.value=null;return;}
 let opacity=Number(ownCss.opacity);
 let left=Math.max(0,box.left),top=Math.max(0,box.top),right=Math.min(innerWidth,box.right),bottom=Math.min(innerHeight,box.bottom),z=0;
 // Do not let a body portal escape an overflow-clipped/hidden image ancestor.
 for(let parent=img.parentElement;parent;parent=parent.parentElement){
  const css=getComputedStyle(parent);
  if(css.display==='none'||css.visibility==='hidden'||css.visibility==='collapse'||Number(css.opacity)===0||parent.hidden||parent.inert){overlay.value=null;return;}
  opacity*=Number(css.opacity);
  const zi=Number(css.zIndex);if(Number.isFinite(zi))z=Math.max(z,zi);
  if(/hidden|clip|scroll|auto/.test(css.overflowX)||/hidden|clip|scroll|auto/.test(css.overflowY)){
   const bounds=parent.getBoundingClientRect();
   if(/hidden|clip|scroll|auto/.test(css.overflowX)){left=Math.max(left,bounds.left);right=Math.min(right,bounds.right);}
   if(/hidden|clip|scroll|auto/.test(css.overflowY)){top=Math.max(top,bounds.top);bottom=Math.min(bottom,bounds.bottom);}
  }
 }
 if(right<=left||bottom<=top){overlay.value=null;return;}
 overlay.value={left:box.left,top:box.top,width:box.width,height:box.height,size:Math.min(36,box.width,box.height),z:z+1,opacity,clip:`inset(${Math.max(0,top-box.top)}px ${Math.max(0,box.right-right)}px ${Math.max(0,box.bottom-bottom)}px ${Math.max(0,left-box.left)}px)`};
}
function observeImage(){
 resizeObserver?.disconnect();mutationObserver?.disconnect();
 if(!mounted.value||!pending.value||!image.value)return;
 resizeObserver?.observe(image.value);
 for(let parent=image.value.parentElement;parent;parent=parent.parentElement){
  resizeObserver?.observe(parent);
  mutationObserver?.observe(parent,{attributes:true,attributeFilter:['class','style','hidden','inert']});
 }
 listenMotion();refreshClock();
}
function stopPending(){clearDeadline();stopMotion();pending.value=false;overlay.value=null;resizeObserver?.disconnect();mutationObserver?.disconnect();}
function fail(){if(!pending.value)return;stopPending();failed.value=true;emit('unavailable',true);}
function arm(){clearDeadline();if(!mounted.value||!pending.value)return;deadline=setTimeout(fail,15000);void nextTick(observeImage);}
function reset(){stopPending();failed.value=false;pending.value=true;generation.value++;emit('unavailable',false);arm();}
function retryLoad(){if(failed.value){retry.value++;reset();}}
function loaded(event:Event){if(event.currentTarget!==image.value||failed.value)return;stopPending();emit('unavailable',false);}
function errored(event:Event){if(event.currentTarget===image.value)fail();}
watch(()=>props.src,()=>{retry.value=0;reset();});
onMounted(()=>{
 mounted.value=true;
 if(typeof ResizeObserver!=='undefined')resizeObserver=new ResizeObserver(refreshClock);
 mutationObserver=new MutationObserver(refreshClock);
 window.addEventListener('online',retryLoad);window.addEventListener('resize',refreshClock);window.addEventListener('scroll',refreshClock,true);
 document.addEventListener('visibilitychange',refreshClock);window.visualViewport?.addEventListener('resize',refreshClock);window.visualViewport?.addEventListener('scroll',refreshClock);
 arm();
});
onBeforeUnmount(()=>{
 mounted.value=false;clearDeadline();stopMotion();resizeObserver?.disconnect();mutationObserver?.disconnect();
 window.removeEventListener('online',retryLoad);window.removeEventListener('resize',refreshClock);window.removeEventListener('scroll',refreshClock,true);
 document.removeEventListener('visibilitychange',refreshClock);window.visualViewport?.removeEventListener('resize',refreshClock);window.visualViewport?.removeEventListener('scroll',refreshClock);
});
</script>
<template>
 <img :key="generation" ref="image" :src="failed ? placeholder : props.src + (retry ? `${props.src.includes('?')?'&':'?'}artRetry=${retry}` : '')" :alt="failed ? (state.locale==='ru'?'Картинка не загрузилась. Нажмите, чтобы повторить.':'Image unavailable. Tap to retry.') : alt" :data-art-state="failed?'failed':pending?'pending':'image'" :role="failed?'button':undefined" :tabindex="failed?0:undefined" :title="failed ? (state.locale==='ru'?'Повторить загрузку':'Retry image') : undefined" @error="errored" @load="loaded" @click="retryLoad" @keydown.enter="retryLoad" @keydown.space.prevent="retryLoad" v-bind="{...inheritedScope,...$attrs}">
 <Teleport v-if="mounted&&pending&&overlay" to="body">
  <span class="game-art-pending-clock" role="status" :aria-label="state.locale==='ru'?'Загружаем картинку':'Loading image'" :style="{left:`${overlay.left}px`,top:`${overlay.top}px`,width:`${overlay.width}px`,height:`${overlay.height}px`,zIndex:overlay.z,opacity:overlay.opacity,clipPath:overlay.clip}"><LoadingClock :size="overlay.size"/></span>
 </Teleport>
</template>
<style scoped>
img[data-art-state=pending]{filter:opacity(0)}.game-art-pending-clock{position:fixed;display:grid;place-items:center;pointer-events:none;contain:layout style paint}
</style>
