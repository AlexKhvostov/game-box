<script setup lang="ts">
const props=defineProps<{ modelValue: boolean; disabled?: boolean }>();
const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>();
function change(event:Event) {
  const input=event.target as HTMLInputElement,value=input.checked;
  // Async settings retain the confirmed position until their owner accepts the
  // change. A failed privacy request must not leave a falsely unchecked switch.
  input.checked=props.modelValue;
  emit('update:modelValue',value);
}
</script>
<template>
  <input class="game-switch" type="checkbox" role="switch" :checked="modelValue" :disabled="disabled" @change="change">
</template>
