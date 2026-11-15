<script setup lang="ts">
import { ref, useId, onMounted, onBeforeUnmount } from 'vue';
import { back, state } from '../services/game-store';
import StatusOverlay from './StatusOverlay.vue';
const props = withDefaults(defineProps<{ title: string; tall?: boolean; icon?: string; closable?: boolean; inactive?:boolean;statusBusy?:boolean;statusMessage?:string;closing?:boolean }>(), { closable: true, statusBusy: undefined });
const titleId=useId();
const panel = ref<HTMLElement>();
let previous: HTMLElement | null = null;
function key(event: KeyboardEvent) {
  if(props.inactive)return;
  if(panel.value!==Array.from(document.querySelectorAll('.modal-backdrop .game-window')).at(-1))return;
  if (event.key === 'Escape') { event.preventDefault(); if (props.closable !== false) back(); }
  if (event.key !== 'Tab') return;
  const items = Array.from(panel.value?.querySelectorAll<HTMLElement>('button:not([disabled]),a[href],input:not([disabled]),textarea,select,[tabindex="0"]') ?? []);
  const first = items[0], last = items.at(-1); if (!first) return;
  if (!panel.value?.contains(document.activeElement)) { event.preventDefault(); first.focus({preventScroll:true}); }
  else if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last!.focus({preventScroll:true}); }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus({preventScroll:true}); }
}
onMounted(() => { previous = document.activeElement as HTMLElement; panel.value?.focus({preventScroll:true}); window.addEventListener('keydown', key); });
onBeforeUnmount(() => { window.removeEventListener('keydown', key); previous?.focus({preventScroll:true}); });
</script>
<template>
  <div class="modal-backdrop" :class="{'window-exiting':closing||state.windowClosing}" @pointerdown.self="closable === false ? undefined : back()">
    <section ref="panel" class="game-window" :class="{ tall }" :inert="inactive||closing||state.windowClosing?true:undefined" :aria-hidden="inactive?true:undefined" role="dialog" aria-modal="true" :aria-labelledby="titleId" tabindex="-1">
      <slot name="background"/>
      <header class="window-header"><button v-analytics="{feature: 'back', placement: 'window'}" v-if="$slots.back" class="icon-button" :aria-label="state.locale==='ru'?'Назад':'Back'" :disabled="closable === false" @click="back">‹</button><h1 :id="titleId"><slot name="title"><span v-if="icon" aria-hidden="true">{{ icon }}</span>{{ title }}</slot></h1><slot name="header-extra"/><button v-analytics="{feature: 'close', placement: 'window'}" class="icon-button close-window" :aria-label="state.locale==='ru'?'Закрыть':'Close'" :disabled="closable === false" @click="back">×</button></header>
      <div class="window-body"><slot /></div>
      <footer v-if="$slots.footer" class="window-footer"><slot name="footer"/></footer>
      <StatusOverlay v-if="!inactive" :busy="statusBusy" :message="statusMessage"/>
    </section>
  </div>
</template>

<style scoped>
.modal-backdrop{animation:window-barrier-enter 160ms ease both}.modal-backdrop.window-exiting{animation:window-barrier-exit 100ms cubic-bezier(.75,0,.75,.9) both}@keyframes window-barrier-enter{from{background-color:transparent}to{background-color:#061b2db8}}@keyframes window-barrier-exit{from{background-color:#061b2db8}to{background-color:transparent}}
.modal-backdrop:not(.window-exiting)>.game-window{animation:port-window-enter 160ms cubic-bezier(.22,.8,.25,1) both}.modal-backdrop.window-exiting>.game-window{animation:port-window-exit 100ms ease-out both;pointer-events:none}@keyframes port-window-enter{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}@keyframes port-window-exit{to{opacity:0;transform:translateY(8px)}}@media(prefers-reduced-motion:reduce){.modal-backdrop,.modal-backdrop>.game-window{animation:none!important}}
</style>
