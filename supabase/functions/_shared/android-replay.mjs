import './android-replay.generated.mjs';
import './telegram-replay.generated.mjs';
import './android-helmet-replay.generated.mjs';
import {requireThat} from './core/policy.mjs';
export const androidRoundProof={
 start(input){requireThat([1,2,3].includes(input.proofVersion),'update_required');},
 finish(input,round){
  // Grandfather only rounds already accepted by the previous server version.
  // Every newly created round requires proof; clients cannot select this flag.
  if(![1,2,3].includes(round.proofVersion))return;
  requireThat(input.proof?.version===round.proofVersion&&Array.isArray(input.proof.events),'result_proof_required');
  requireThat(input.proof.events.length<=600000,'result_proof_invalid');
  const result=JSON.parse((round.proofVersion===3?globalThis.untouchHelmetReplay:round.proofVersion===2?globalThis.untouchTelegramReplay:globalThis.untouchReplay)(JSON.stringify({
   op: 'verify',config:round.policy.config,requestId:round.requestId,
    hadJump:round.hadJump,hadHelmet:round.hadHelmet,proof:input.proof})));
  requireThat(result.ok&&['timeMs','runDistance','riskCount'].every(key=>result[key]===input[key]),'result_proof_invalid');
 }
};
