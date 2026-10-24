import { computed, reactive } from 'vue';
import { energy } from './game-store';
export const rewardMotion = reactive({ held: 0, revealed: 0, active: false });
// Presentation only. Starting a run always checks the authoritative wallet.
export const displayEnergy = computed(() => Math.max(0,energy.value-rewardMotion.held+rewardMotion.revealed));
