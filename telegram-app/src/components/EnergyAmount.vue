<script setup lang="ts">
import {state} from '../services/game-store';
import EnergyBolt from './EnergyBolt.vue';
defineProps<{amount:number;prefix?:string}>();
</script>
<template><span class="energy-amount" role="img" :aria-label="`${prefix??''}${amount} ${state.locale==='ru'?'энергии':'energy'}`"><span aria-hidden="true">{{prefix}}{{amount}}</span><EnergyBolt/></span></template>
