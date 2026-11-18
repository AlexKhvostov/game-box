<script setup lang="ts">
import {ref,useId,onMounted,onBeforeUnmount} from 'vue';
import {registerOverlayBack} from '../services/ui-overlays';
import './achievement-port.css';
const props=withDefaults(defineProps<{title:string;locale?:string;name?:string;wide?:boolean;closable?:boolean;inactive?:boolean;variant?:'award'|'level'|'settings';dismissOnBackdrop?:boolean}>(),{locale:'ru',closable:true,dismissOnBackdrop:true});
const emit=defineEmits<{closing:[];close:[]}>();
const panel=ref<HTMLElement>(),titleId=useId(),closing=ref(false);let prior:HTMLElement|null=null,release:(()=>void)|undefined,closeTimer:ReturnType<typeof setTimeout>|undefined;
function close(){if(!props.closable||props.inactive||closing.value)return;closing.value=true;emit('closing');closeTimer=setTimeout(()=>emit('close'),matchMedia('(prefers-reduced-motion: reduce)').matches?0:100);}
defineExpose({requestClose:close});
function key(event:KeyboardEvent){
  const current=panel.value;if(!current||current!==Array.from(document.querySelectorAll('.port-dialog')).at(-1))return;
  if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();close();return;}
  if(event.key!=='Tab')return;
  const nodes=Array.from(current.querySelectorAll<HTMLElement>('button:not([disabled]),a[href],input:not([disabled]),select:not([disabled]),textarea,[tabindex="0"]')).filter(el=>el.getClientRects().length>0);
  const first=nodes[0],last=nodes.at(-1);if(!first){event.preventDefault();return;}
  if(!current.contains(document.activeElement)){event.preventDefault();first.focus({preventScroll:true});}
  else if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus({preventScroll:true});}
  else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus({preventScroll:true});}
}
onMounted(()=>{prior=document.activeElement as HTMLElement;panel.value?.focus({preventScroll:true});release=registerOverlayBack(close,props.name??'achievement');window.addEventListener('keydown',key,true);});
onBeforeUnmount(()=>{clearTimeout(closeTimer);release?.();window.removeEventListener('keydown',key,true);if(prior?.isConnected)prior.focus({preventScroll:true});});
</script>
<template><Teleport to="body"><div class="port-backdrop" :class="[variant?`port-${variant}-backdrop`:undefined,{'port-window-closing':closing}]" @pointerdown.self="dismissOnBackdrop&&close()"><section ref="panel" class="port-dialog" :class="{'port-dialog-wide':wide}" :inert="inactive||closing?true:undefined" :aria-hidden="inactive?true:undefined" role="dialog" aria-modal="true" :aria-labelledby="titleId" tabindex="-1"><header class="port-dialog-header"><slot name="leading"/><div class="port-dialog-heading"><slot name="eyebrow"/><h1 :id="titleId"><slot name="title">{{title}}</slot></h1></div><slot name="header"/><button v-if="closable" class="port-close" :aria-label="locale==='ru'?'Закрыть':'Close'" @click="close">×</button></header><slot/><footer v-if="$slots.footer" class="port-dialog-footer"><slot name="footer"/></footer></section></div></Teleport></template>
