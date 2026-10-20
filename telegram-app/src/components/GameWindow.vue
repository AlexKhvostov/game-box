<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { back, state } from '../services/game-store';
import StatusOverlay from './StatusOverlay.vue';
const props = withDefaults(defineProps<{ title: string; tall?: boolean; icon?: string; closable?: boolean }>(), { closable: true });
const panel = ref<HTMLElement>();
let previous: HTMLElement | null = null;
function key(event: KeyboardEvent) {
  if (event.key === 'Escape') { event.preventDefault(); if (props.closable !== false) back(); }
  if (event.key !== 'Tab') return;
  const items = Array.from(panel.value?.querySelectorAll<HTMLElement>('button:not([disabled]),a[href],input:not([disabled]),textarea,select,[tabindex="0"]') ?? []);
  const first = items[0], last = items.at(-1); if (!first) return;
  if (!panel.value?.contains(document.activeElement)) { event.preventDefault(); first.focus(); }
  else if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last!.focus(); }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
}
onMounted(() => { previous = document.activeElement as HTMLElement; panel.value?.focus(); window.addEventListener('keydown', key); });
onBeforeUnmount(() => { window.removeEventListener('keydown', key); previous?.focus(); });
</script>
<template>
  <div class="modal-backdrop" @pointerdown.self="closable === false ? undefined : back()">
    <section ref="panel" class="game-window" :class="{ tall }" role="dialog" aria-modal="true" aria-labelledby="window-title" tabindex="-1">
      <slot name="background"/>
      <header class="window-header"><button v-if="$slots.back" class="icon-button" :aria-label="state.locale==='ru'?'Назад':'Back'" :disabled="closable === false" @click="back">‹</button><h1 id="window-title"><slot name="title"><span v-if="icon" aria-hidden="true">{{ icon }}</span>{{ title }}</slot></h1><slot name="header-extra"/><button class="icon-button close-window" :aria-label="state.locale==='ru'?'Закрыть':'Close'" :disabled="closable === false" @click="back">×</button></header>
      <div class="window-body"><slot /></div>
      <footer v-if="$slots.footer" class="window-footer"><slot name="footer"/></footer>
      <StatusOverlay/>
    </section>
  </div>
</template>
