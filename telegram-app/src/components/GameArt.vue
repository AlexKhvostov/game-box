<script setup lang="ts">
import { ref, watch, onMounted, onBeforeUnmount } from 'vue';
import { state } from '../services/game-store';
const props = withDefaults(defineProps<{ src: string; alt?: string }>(), { alt: '' });
const emit=defineEmits<{unavailable:[value:boolean]}>();
const failed = ref(false), retry = ref(0);
// Preserve the illustration's allotted box after a failed download; the browser
// broken-image glyph must never become the layout of a game window.
const placeholder = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="10" y="10" width="44" height="44" rx="12" fill="#062b40" stroke="#468ca4"/><path d="M23 32a9 9 0 1 1 3 7m-3-7v8h8" fill="none" stroke="#9cdeec" stroke-width="3" stroke-linecap="round"/></svg>');
function retryLoad() { if (failed.value) { failed.value = false; retry.value++;emit('unavailable',false); } }
watch(() => props.src, () => { failed.value = false; retry.value = 0;emit('unavailable',false); });
onMounted(() => window.addEventListener('online', retryLoad));
onBeforeUnmount(() => window.removeEventListener('online', retryLoad));
</script>
<template>
  <img :src="failed ? placeholder : props.src + (retry ? `${props.src.includes('?')?'&':'?'}artRetry=${retry}` : '')" :alt="failed ? (state.locale==='ru'?'Картинка не загрузилась. Нажмите, чтобы повторить.':'Image unavailable. Tap to retry.') : alt" :data-art-state="failed?'failed':'image'" :role="failed?'button':undefined" :tabindex="failed?0:undefined" :title="failed ? (state.locale==='ru'?'Повторить загрузку':'Retry image') : undefined" @error="failed=true;emit('unavailable',true)" @load="!failed&&emit('unavailable',false)" @click="retryLoad" @keydown.enter="retryLoad" @keydown.space.prevent="retryLoad">
</template>
