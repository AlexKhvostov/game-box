<script setup lang="ts">
import {onMounted,onBeforeUnmount,ref,computed,nextTick,useId} from 'vue';
import {state,walletOperation,errorText} from '../services/game-store';
import EnergyAmount from './EnergyAmount.vue';
import LoadingClock from './LoadingClock.vue';
import {ageBand,ensureResourceAge} from '../platform/audience';
import {telegram} from '../platform/telegram';
import {registerOverlayBack} from '../services/ui-overlays';
const emit=defineEmits<{close:[]}>();
const panel=ref<HTMLElement>(),titleId=useId();let prior:HTMLElement|null=null;
const closing=ref(false);let closeTimer:ReturnType<typeof setTimeout>|undefined,closePromise:Promise<void>|undefined,resolveClose:(()=>void)|undefined;
function close():Promise<void>{if(closePromise)return closePromise;closing.value=true;closePromise=new Promise(resolve=>{resolveClose=resolve;closeTimer=setTimeout(()=>{emit('close');resolve();resolveClose=undefined;},matchMedia('(prefers-reduced-motion: reduce)').matches?0:100);});return closePromise;}
function key(event:KeyboardEvent){if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();close();return;}if(event.key!=='Tab')return;const current=panel.value;if(!current)return;const nodes=Array.from(current.querySelectorAll<HTMLElement>('button:not([disabled]),a[href],input,[tabindex="0"]')).filter(el=>el.getClientRects().length>0),first=nodes[0],last=nodes.at(-1);if(!first){event.preventDefault();return;}if(!current.contains(document.activeElement)){event.preventDefault();first.focus();}else if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}}
const media=ref(''),controller=new AbortController();let objectUrl='',closed=false,mediaTimer:ReturnType<typeof setTimeout>|undefined;
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
const gift=computed(()=>state.profile?.wallet.easterGift),claiming=ref(false),claimError=ref('');
async function claim(){
 if(claiming.value||!gift.value?.enabled||gift.value.claimed)return;
 const owner=state.profile?.id;claiming.value=true;claimError.value='';
 try{
  // The age screen belongs to the main host, below this teleported overlay.
  // Release the overlay before opening it; the durable wallet operation keeps
  // its existing retry ID and always uses the owner who requested the gift.
  if(!ageBand()){await close();await nextTick();}
  if(await ensureResourceAge()&&owner&&state.profile?.id===owner)await walletOperation('energy_easter_gift');
 }catch(e){if(closed)state.error=errorText(e);else claimError.value=errorText(e);}
 finally{claiming.value=false;}
}
const maxBytes=2*1024*1024;
const motionQuery=window.matchMedia('(prefers-reduced-motion: reduce)'),reducedMotion=ref(motionQuery.matches),foreground=ref(!document.hidden&&telegram()?.isActive!==false);
const localArt=ref('/assets/branding/ui/easter-cube-gift-v3.png');
const mascotStyle=computed(()=>{if(!reducedMotion.value)return undefined;const t=.28*Math.PI*2;return{transform:`translateY(${Math.sin(t)*4}px) rotate(${Math.sin(t)*.018}rad) scale(${1+Math.sin(t*2)*.025})`};});
const activity=()=>foreground.value=!document.hidden&&telegram()?.isActive!==false;
const motionChange=()=>reducedMotion.value=motionQuery.matches;
const removeBack=registerOverlayBack(close,'easter_egg');
onMounted(async()=>{
  prior=document.activeElement as HTMLElement;panel.value?.focus?.({preventScroll:true});window.addEventListener('keydown',key,true);
  document.addEventListener('visibilitychange',activity);telegram()?.onEvent('activated',activity);telegram()?.onEvent('deactivated',activity);motionQuery.addEventListener?.('change',motionChange);
  const settings=state.config?.config.easterEgg,url=settings?.assetUrl;
  if(!url)return;
  mediaTimer=setTimeout(()=>controller.abort(),6000);
  try{
    const u=new URL(url);
    if(url.length>2048||u.protocol!=='https:'||u.username||u.password||u.hash||!u.hostname.includes('.')||/^([\d.]+|localhost|\[)/.test(u.hostname)||u.hostname.endsWith('.localhost'))return;
    const key=encodeURIComponent(`${settings.contentId??''}:${url}`);
    let cache:Cache|undefined;try{cache=await caches.open('untouch-easter-v1');}catch{}
    const cacheUrl=new URL('/__untouch_easter_media__',location.origin).href;
    let response=await cache?.match(cacheUrl);
    if(response?.headers.get('x-easter-key')!==key)response=undefined;
    if(!response){
      const remote=await fetch(url,{signal:controller.signal,credentials:'omit',redirect:'error',referrerPolicy:'no-referrer'});
      if(!remote.ok||!['image/png','image/jpeg','image/gif','image/webp'].includes(remote.headers.get('content-type')?.split(';')[0]??'')||Number(remote.headers.get('content-length'))>maxBytes)return;
      const reader=remote.body?.getReader();if(!reader)return;
      const chunks:Uint8Array<ArrayBuffer>[]= [];let count=0;
      for(;;){const {done,value}=await reader.read();if(done)break;count+=value.length;if(count>maxBytes){await reader.cancel();return;}chunks.push(new Uint8Array(value));}
      response=new Response(new Blob(chunks,{type:remote.headers.get('content-type')!}),{headers:{'content-type':remote.headers.get('content-type')!,'x-easter-key':key}});
      try{await cache?.put(cacheUrl,response.clone());}catch{}
    }
    const blob=await response.blob();if(blob.size>maxBytes||closed)return;
    objectUrl=URL.createObjectURL(blob);
    const image=new Image();image.src=objectUrl;await image.decode();
    if(!closed&&image.naturalWidth<=4096&&image.naturalHeight<=4096&&image.naturalWidth*image.naturalHeight<=8000000)media.value=objectUrl;
  }catch{/* Decorative content always falls back to the bundled scene. */}
  finally{clearTimeout(mediaTimer);mediaTimer=undefined;}
});
onBeforeUnmount(()=>{clearTimeout(closeTimer);resolveClose?.();removeBack();window.removeEventListener('keydown',key,true);if(prior?.isConnected)prior.focus({preventScroll:true});document.removeEventListener('visibilitychange',activity);telegram()?.offEvent('activated',activity);telegram()?.offEvent('deactivated',activity);motionQuery.removeEventListener?.('change',motionChange);closed=true;clearTimeout(mediaTimer);mediaTimer=undefined;controller.abort();if(objectUrl)URL.revokeObjectURL(objectUrl);});
</script>
<template>
  <div class="easter-backdrop" :class="{'easter-closing':closing}" @pointerdown.self="close">
    <section ref="panel" role="dialog" aria-modal="true" :aria-labelledby="titleId" tabindex="-1" class="easter-card" :inert="closing?true:undefined">
      <header class="easter-header"><h1 :id="titleId">{{t('Вы меня нашли!','You found me!')}}</h1><button class="easter-close" :aria-label="t('Закрыть','Close')" @click="close">×</button></header>
      <div class="easter-art">
        <img v-if="media" :src="media" alt="" @error="media=''"/>
        <img v-else class="easter-mascot" :class="{paused:!foreground,reduced:reducedMotion}" :style="mascotStyle" :src="localArt" alt="Untouch" @error="localArt='/assets/branding/ui/hero-ready-v1.png'"/>
      </div>
      <h2>{{t('Вот это любопытство!','Now that is curiosity!')}}</h2><p class="easter-caption">{{gift?.enabled?t('Подарок от разработчиков — спасибо, что играете в Untouch.','A developer gift — thank you for playing Untouch.'):t('Спасибо, что играете в Untouch!','Thank you for playing Untouch!')}}</p>
      <template v-if="gift?.contract===1&&gift.enabled">
        <div class="easter-amount"><EnergyAmount :amount="gift.amount"/></div>
        <button class="easter-claim" :class="{claimed:gift.claimed}" :disabled="claiming||gift.claimed" @click="claim">
          <LoadingClock v-if="claiming" :size="18" :active="foreground"/>
          <svg v-else-if="gift.claimed" viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 4 4L20 5"/></svg>
          <svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="M3 8h18v4H3zM5 12v9h14v-9M12 8v13M12 8H7a3 3 0 1 1 3-3zm0 0h5a3 3 0 1 0-3-3z"/></svg>
          {{gift.claimed?t('Подарок получен','Gift received'):claiming?t('Получаем…','Claiming…'):t('Забрать подарок','Claim gift')}}
        </button>
        <p v-if="claimError||gift.claimed" class="easter-feedback" :class="{error:claimError}" :role="claimError?'alert':'status'" aria-live="polite">{{claimError?t('Не удалось подтвердить. Проверьте соединение и повторите.','Not confirmed. Check your connection and try again.'):t('Энергия уже на вашем балансе','Energy is already on your balance')}}</p>
      </template>
      <button class="easter-return" @click="close">{{t('Вернуться в игру','Back to the game')}}</button>
    </section>
  </div>
</template>
<style scoped>
.easter-backdrop,.easter-backdrop *{box-sizing:border-box}.easter-backdrop{position:fixed;inset:0;z-index:1500;background:#000817e6;display:grid;place-items:center;padding:24px 16px;color:#edf8ff;font-family:Roboto,Arial,sans-serif;touch-action:manipulation}
.easter-card{position:relative;isolation:isolate;width:min(360px,100%);max-height:calc(100dvh - 48px);overflow:auto;padding:12px;border:1.2px solid #5deaff;border-radius:20px;background:linear-gradient(135deg,#063957,#00172c 64%,#012039);box-shadow:0 0 13px 1px #54e9ff33,0 5px 8px #000b19dd,inset 0 0 0 2px #001d36,inset 0 0 0 3.5px #13d7ff,inset 0 0 0 5px #012039,inset 0 0 0 6px #a0fbff,inset 0 0 0 7.7px #00d7ff70;text-align:center;outline:0}
.easter-card:before,.easter-card:after{content:'';position:absolute;top:3px;width:28px;height:1.5px;background:linear-gradient(90deg,transparent,#ddffff,transparent);pointer-events:none}.easter-card:before{left:7%}.easter-card:after{right:7%}
.easter-header{display:flex;align-items:center;min-height:44px;margin-bottom:8px;border-bottom:1px solid #54e9ff80;text-align:left}.easter-header h1{flex:1;min-width:0;margin:0;font-size:calc(23px * var(--text-scale,1));line-height:1.15;font-weight:900;color:#fff;text-shadow:0 0 7px #198aff66}.easter-close{flex:none;display:grid;place-items:center;width:44px;height:44px;min-height:44px;padding:0;border:0;background:none;color:#54e9ff;font-size:28px;line-height:1}
.easter-art{height:150px;display:grid;place-items:center}.easter-art img{display:block;width:100%;height:150px;object-fit:contain}.easter-card h2{font-size:calc(18px * var(--text-scale,1));line-height:1.3;font-weight:900;margin:0;color:#edf8ff}.easter-caption{color:#a1c5dc;font-size:calc(12px * var(--text-scale,1));line-height:1.45;margin:10px 6px}
.easter-amount{display:flex;justify-content:center;margin-bottom:10px}.easter-amount>.energy-amount{padding:2px 24px;background:#574b2466;border:1px solid #ffe47a;border-radius:28px;box-shadow:0 0 12px #ffd64233;color:#ffe47a;font-size:calc(24px * var(--text-scale,1));font-weight:900;line-height:1.3}.easter-amount :deep(.energy-bolt){width:30px;height:30px;margin-left:4px}
.easter-claim{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;min-height:48px;padding:10px 12px;border:1.5px solid #b6ffff;border-radius:13px;background:linear-gradient(#24e9ef,#039ab7 23%,#00698d 80%,#0cc8d8);box-shadow:0 0 12px #00d7e955;color:#fff;font-size:calc(17px * var(--text-scale,1));font-weight:800;line-height:1.2}.easter-claim:active{background:linear-gradient(#02a9c1,#00577b)}.easter-claim:disabled{opacity:1;color:#72bed0;border-color:#398a9a;background:linear-gradient(#19566a,#07354b);box-shadow:none}.easter-claim.claimed:disabled{background:#00615d66;border:1px solid #55eade;border-radius:12px;color:#edf8ff}.easter-claim>svg{width:22px;height:22px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;flex:none}.easter-claim.claimed>svg{color:#54e9ff}
.easter-feedback{margin:8px 0 0;color:#a1c5dc;font-size:calc(12px * var(--text-scale,1));line-height:1.45}.easter-feedback.error{color:#ffd18a}.easter-return{display:block;width:100%;min-height:44px;padding:8px;border:0;background:none;color:#a1c5dc;font-size:calc(14px * var(--text-scale,1));font-weight:700}.easter-card button:focus-visible{outline:2px solid #d1fff5;outline-offset:2px}
.easter-mascot{animation:easter-mascot385 8s linear infinite}.easter-mascot.paused{animation-play-state:paused}.easter-mascot.reduced{animation:none}@keyframes easter-mascot385{0.000%{transform:translateY(0.000000px) rotate(0.000000rad) scale(1.000000)}3.125%{transform:translateY(0.780361px) rotate(0.003512rad) scale(1.009567)}6.250%{transform:translateY(1.530734px) rotate(0.006888rad) scale(1.017678)}9.375%{transform:translateY(2.222281px) rotate(0.010000rad) scale(1.023097)}12.500%{transform:translateY(2.828427px) rotate(0.012728rad) scale(1.025000)}15.625%{transform:translateY(3.325878px) rotate(0.014966rad) scale(1.023097)}18.750%{transform:translateY(3.695518px) rotate(0.016630rad) scale(1.017678)}21.875%{transform:translateY(3.923141px) rotate(0.017654rad) scale(1.009567)}25.000%{transform:translateY(4.000000px) rotate(0.018000rad) scale(1.000000)}28.125%{transform:translateY(3.923141px) rotate(0.017654rad) scale(0.990433)}31.250%{transform:translateY(3.695518px) rotate(0.016630rad) scale(0.982322)}34.375%{transform:translateY(3.325878px) rotate(0.014966rad) scale(0.976903)}37.500%{transform:translateY(2.828427px) rotate(0.012728rad) scale(0.975000)}40.625%{transform:translateY(2.222281px) rotate(0.010000rad) scale(0.976903)}43.750%{transform:translateY(1.530734px) rotate(0.006888rad) scale(0.982322)}46.875%{transform:translateY(0.780361px) rotate(0.003512rad) scale(0.990433)}50.000%{transform:translateY(0.000000px) rotate(0.000000rad) scale(1.000000)}53.125%{transform:translateY(-0.780361px) rotate(-0.003512rad) scale(1.009567)}56.250%{transform:translateY(-1.530734px) rotate(-0.006888rad) scale(1.017678)}59.375%{transform:translateY(-2.222281px) rotate(-0.010000rad) scale(1.023097)}62.500%{transform:translateY(-2.828427px) rotate(-0.012728rad) scale(1.025000)}65.625%{transform:translateY(-3.325878px) rotate(-0.014966rad) scale(1.023097)}68.750%{transform:translateY(-3.695518px) rotate(-0.016630rad) scale(1.017678)}71.875%{transform:translateY(-3.923141px) rotate(-0.017654rad) scale(1.009567)}75.000%{transform:translateY(-4.000000px) rotate(-0.018000rad) scale(1.000000)}78.125%{transform:translateY(-3.923141px) rotate(-0.017654rad) scale(0.990433)}81.250%{transform:translateY(-3.695518px) rotate(-0.016630rad) scale(0.982322)}84.375%{transform:translateY(-3.325878px) rotate(-0.014966rad) scale(0.976903)}87.500%{transform:translateY(-2.828427px) rotate(-0.012728rad) scale(0.975000)}90.625%{transform:translateY(-2.222281px) rotate(-0.010000rad) scale(0.976903)}93.750%{transform:translateY(-1.530734px) rotate(-0.006888rad) scale(0.982322)}96.875%{transform:translateY(-0.780361px) rotate(-0.003512rad) scale(0.990433)}100.000%{transform:translateY(-0.000000px) rotate(-0.000000rad) scale(1.000000)}}@media(prefers-reduced-motion:reduce){.easter-mascot{animation:none}}
</style>

<style scoped>
.easter-backdrop{animation:easter-barrier-enter 160ms ease both}.easter-card{animation:easter-window-enter 160ms cubic-bezier(.22,.8,.25,1) both}.easter-closing{animation:easter-barrier-exit 100ms cubic-bezier(.75,0,.75,.9) both}.easter-closing .easter-card{animation:easter-window-exit 100ms ease-out both;pointer-events:none}
@keyframes easter-window-enter{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}@keyframes easter-window-exit{to{opacity:0;transform:translateY(8px)}}@keyframes easter-barrier-enter{from{background-color:transparent}to{background-color:#000817e6}}@keyframes easter-barrier-exit{from{background-color:#000817e6}to{background-color:transparent}}@media(prefers-reduced-motion:reduce){.easter-backdrop,.easter-card{animation:none!important}}
</style>
