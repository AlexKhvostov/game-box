<script setup lang="ts">
defineProps<{ name:'video'|'invite'|'feedback'|'add'|'risk'|'run'|'copy'|'share'|'gamepad'|'chat-check' }>();
</script>
<template><svg class="game-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
  <template v-if="name==='video'"><path d="M3 3h18a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2h-7v2h-4v-2H3a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2m0 3v11h18V6z"/><path d="m9 7 7 4.5L9 16z"/></template>
  <template v-else-if="name==='gamepad'"><path d="M7 5h10c5 0 7 13 4 14-2 1-4-3-5-3H8c-1 0-3 4-5 3C0 18 2 5 7 5z" fill="none" stroke="currentColor" stroke-width="2"/><path d="M7 8v6m-3-3h6m6-2h2m0 4h2" fill="none" stroke="currentColor" stroke-width="2"/></template>
  <template v-else-if="name==='chat-check'"><path d="M3 3h18v14H8l-5 4z"/><path d="m7 10 3 3 7-7" fill="none" stroke="#062336" stroke-width="2"/></template>
  <path v-else-if="name==='invite'" d="M9 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8m0 2c-4.4 0-8 2-8 4.5V21h16v-2.5C17 16 13.4 14 9 14m10-7V4h2v3h3v2h-3v3h-2V9h-3V7z"/>
  <path v-else-if="name==='feedback'" d="M3 2h18a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H7l-6 4V4a2 2 0 0 1 2-2m2 4v2h14V6zm0 4v2h14v-2zm0 4v2h9v-2z"/>
  <path v-else-if="name==='add'" fill-rule="evenodd" d="M12 23a11 11 0 1 0 0-22 11 11 0 0 0 0 22M11 6h2v5h5v2h-5v5h-2v-5H6v-2h5z"/>
  <path v-else-if="name==='risk'" d="m12 2 11 20H1zm-1 7v6h2V9zm0 8v2h2v-2z" fill-rule="evenodd"/>
  <path v-else-if="name==='run'" d="M13 5a2 2 0 1 0 0-4 2 2 0 0 0 0 4m-3 1L5 10l1 2 3-2-1 5-5 5 2 2 6-6 2 2v5h3v-6l-4-4 1-4 2 3h5V9h-4l-3-3z"/>
  <path v-else-if="name==='copy'" d="M8 1h13v17H8zm2 2v13h9V3zM3 5h3v2H5v14h10v-1h2v3H3z" fill-rule="evenodd"/>
  <path v-else-if="name==='share'" d="M18 1a3 3 0 1 1-2.7 4.3l-7 4a3 3 0 0 1 0 2.4l7 4A3 3 0 1 1 14 18l-7-4a3 3 0 1 1 0-6l7-4a3 3 0 0 1 4-3"/>
</svg></template>
