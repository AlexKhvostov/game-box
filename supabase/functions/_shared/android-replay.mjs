import './android-replay.generated.mjs';
import {requireThat} from './core/policy.mjs';
export const androidRoundProof={
 start(input){requireThat(input.proofVersion===1,'update_required');},
 finish(input,round){
  // Grandfather only rounds already accepted by the previous server version.
  // Every newly created round requires proof; clients cannot select this flag.
  if(round.proofVersion!==1)return;
  requireThat(input.proof?.version===1&&Array.isArray(input.proof.events),'result_proof_required');
  requireThat(input.proof.events.length<=600000,'result_proof_invalid');
  const result=JSON.parse(globalThis.untouchReplay(JSON.stringify({config:round.policy.config,requestId:round.requestId,
    hadJump:round.hadJump,hadHelmet:round.hadHelmet,proof:input.proof})));
  requireThat(result.ok&&['timeMs','runDistance','riskCount'].every(key=>result[key]===input[key]),'result_proof_invalid');
 }
};
