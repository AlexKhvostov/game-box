<script setup lang="ts">
import {onBeforeUnmount, onMounted, ref, watch} from 'vue';
import {drawJumpGlow} from '../game/jump-glow';

const props = withDefaults(defineProps<{progress: number; enabled?: boolean; opacity?: number}>(), {enabled: true, opacity: 1});
const canvas = ref<HTMLCanvasElement>();
let observer: ResizeObserver | undefined;
function paint() {
  const el = canvas.value;
  if (!el) return;
  const side = el.getBoundingClientRect().width;
  if (!side) return;
  const pixels = Math.max(1, Math.round(side * Math.min(devicePixelRatio || 1, 3)));
  if (el.width !== pixels || el.height !== pixels) el.width = el.height = pixels;
  const c = el.getContext('2d');
  if (!c) return;
  c.setTransform(1, 0, 0, 1, 0, 0);
  c.clearRect(0, 0, pixels, pixels);
  drawJumpGlow(c, {x: 0, y: 0, size: pixels, progress: props.progress, enabled: props.enabled, opacity: props.opacity});
}
onMounted(() => {observer = new ResizeObserver(paint); observer.observe(canvas.value!); paint();});
watch(() => [props.progress, props.enabled, props.opacity], paint, {flush: 'post'});
onBeforeUnmount(() => observer?.disconnect());
</script>

<template><canvas ref="canvas" class="jump-glow-layer" aria-hidden="true" /></template>

<style scoped>
.jump-glow-layer {display: block; width: 100%; aspect-ratio: 1; pointer-events: none;}
</style>
