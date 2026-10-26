<script setup lang="ts">
import {computed} from 'vue';
import {floorBrandAsset,floorBrandOpacity,floorBrandSize} from '../domain/floor-brand';
const props=defineProps<{height:number}>();
const size=computed(()=>floorBrandSize(372,props.height-28));
</script>
<template><div class="game-floor-brand" aria-hidden="true" :style="{opacity:floorBrandOpacity}"><img :src="floorBrandAsset" :width="size.width" :height="size.height" alt="" :draggable="false" decoding="async"></div></template>
<style scoped>
.game-floor-brand{position:absolute;left:0;right:0;bottom:16px;display:flex;justify-content:center;line-height:0;pointer-events:none;user-select:none}
.game-floor-brand img{display:block;object-fit:contain;pointer-events:none;user-select:none;-webkit-user-drag:none}
</style>
