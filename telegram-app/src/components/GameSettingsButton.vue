<script setup lang="ts">
withDefaults(defineProps<{locale:string;disabled?:boolean}>(),{disabled:false});
defineEmits<{click:[]}>();
</script>
<template>
  <button type="button" class="port-settings-entry" :disabled="disabled" :aria-label="locale==='ru'?'Настройки игры':'Game settings'"
    @pointerdown.stop @pointerup.stop @pointermove.stop @pointercancel.stop @touchstart.stop @touchend.stop @keydown.stop @keyup.stop @click.stop="$emit('click')">
    <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9.5 3-.6 2.3-1.6.9-2.3-.6-2.5 4.3 1.7 1.7v1.8l-1.7 1.7L5 19.4l2.3-.6 1.6.9.6 2.3h5l.6-2.3 1.6-.9 2.3.6 2.5-4.3-1.7-1.7v-1.8l1.7-1.7L19 5.6l-2.3.6-1.6-.9-.6-2.3z"/><circle cx="12" cy="12.5" r="3.3"/></svg>
  </button>
</template>
<style scoped>
.port-settings-entry{display:grid;place-items:center;flex:none;width:39px;min-height:62px;padding:5px;border:1px solid #5dafc0;border-radius:0 0 11px 11px;background:linear-gradient(#1d536d,#12394e);color:#a3eae8;cursor:pointer;touch-action:manipulation}
.port-settings-entry svg{width:24px;height:24px;fill:none;stroke:currentColor;stroke-width:1.6}
.port-settings-entry:focus-visible{outline:2px solid #d1fff5;outline-offset:2px}
</style>
