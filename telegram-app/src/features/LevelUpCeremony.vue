<script setup lang="ts">
import {computed,ref,onMounted,onBeforeUnmount,watch} from 'vue';
import {LevelUpAnimation,type LevelNumber} from '../../../packages/untouch_level_up_web/index.js';
import '../../../packages/untouch_level_up_web/level-up.css';
import ParityDialog from '../components/ParityDialog.vue';
import {safeLevel} from '../domain/achievement-presentation';
import {telegram} from '../platform/telegram';
import {observeQaLevelMedia} from '../services/qa-level-media-proof';
const props=withDefaults(defineProps<{level:number;locale:string;muted:boolean;volume?:number}>(),{volume:.1});
const emit=defineEmits<{close:[number,'accept'|'dismiss'];presented:[number]}>();
const scene=ref<HTMLElement>(),dialog=ref<InstanceType<typeof ParityDialog>>(),value=computed(()=>safeLevel(props.level)),ru=computed(()=>props.locale==='ru');
let closeReason:'accept'|'dismiss'='dismiss';
let stopMediaProof:(()=>void)|undefined;
const names=['Первый','Второй','Третий','Четвёртый','Пятый','Шестой'];let animation:LevelUpAnimation|undefined,timer:ReturnType<typeof setTimeout>|undefined,suspended=false;
function stopPlayback(){clearTimeout(timer);animation?.pause();}
function close(reason:'accept'|'dismiss'){closeReason=reason;dialog.value?.requestClose();}
function closed(){stopPlayback();emit('close',value.value,closeReason);}
function background(){if(document.hidden||telegram()?.isActive===false){suspended=true;clearTimeout(timer);animation?.finish({animate:false});}}
function localize(){if(!scene.value)return;const video=scene.value.querySelector('video'),badge=scene.value.querySelector('[data-levelup-badge]'),status=scene.value.querySelector('[data-levelup-status]');if(video){video.volume=Math.max(0,Math.min(.1,Number.isFinite(props.volume)?props.volume:0));video.setAttribute('aria-label',ru.value?'Праздничная анимация повышения уровня':'Level up celebration');}badge?.setAttribute('alt',`${ru.value?'Уровень':'Level'} ${value.value}`);if(status)status.textContent=`${ru.value?'Новый уровень':'New level'}: ${value.value}`;}
onMounted(()=>{if(!scene.value)return;animation=new LevelUpAnimation(scene.value,{level:value.value as LevelNumber,autoplay:false,muted:props.muted,locale:ru.value?'ru':'en'});const video=scene.value.querySelector('video');if(video)stopMediaProof=observeQaLevelMedia(video,value.value);localize();timer=setTimeout(()=>{if(suspended||document.hidden||telegram()?.isActive===false){background();return;}emit('presented',value.value);animation?.play();},matchMedia('(prefers-reduced-motion: reduce)').matches?0:160);document.addEventListener('visibilitychange',background);telegram()?.onEvent('deactivated',background);background();});
watch(()=>props.muted,muted=>animation?.setMuted(muted));watch(()=>props.volume,localize);watch(()=>props.locale,()=>{animation?.setLocale(ru.value?'ru':'en');localize();});
onBeforeUnmount(()=>{clearTimeout(timer);stopMediaProof?.();animation?.destroy();document.removeEventListener('visibilitychange',background);telegram()?.offEvent('deactivated',background);});
</script>
<template><ParityDialog ref="dialog" :dismiss-on-backdrop="false" :title="ru?'Поздравляем!':'Congratulations!'" :locale="locale" name="level-up" variant="level" @closing="stopPlayback" @close="closed"><div class="lu-window-content port-level-content"><header class="lu-dialog-head"><div><small>{{ru?'НОВЫЙ УРОВЕНЬ':'NEW LEVEL'}}</small><h2>{{ru?'Поздравляем!':'Congratulations!'}}</h2></div></header><div ref="scene" class="port-level-scene"></div><footer class="lu-dialog-footer"><div class="lu-rank-announcement"><span class="lu-rank-kicker">{{ru?'УРОВЕНЬ ПОВЫШЕН':'LEVEL UP'}}</span><div class="lu-rank-banner"><i class="lu-rank-wing lu-rank-wing--left" aria-hidden="true"></i><strong>{{ru?`${names[value-1]} уровень`:`Level ${value}`}}</strong><i class="lu-rank-wing lu-rank-wing--right" aria-hidden="true"></i></div></div><button class="lu-accept" @click="close('accept')"><span>{{ru?'Продолжить':'Continue'}}</span><i aria-hidden="true"></i></button></footer></div></ParityDialog></template>
