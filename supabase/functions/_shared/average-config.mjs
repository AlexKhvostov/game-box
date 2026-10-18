// Pure configuration contract shared by server and browser admin (no SDK/SQL).
export const averageDefaults=Object.freeze({windowSize:50,previousWeightPercent:92,minAttempts:20,minDurationMs:1000});
export function averageRules(config){
  const rules={...averageDefaults,...config.ranking?.average};
  const valid=Number.isInteger(rules.windowSize)&&rules.windowSize>=1&&rules.windowSize<=500
    &&Number.isFinite(rules.previousWeightPercent)&&rules.previousWeightPercent>=50&&rules.previousWeightPercent<=100
    &&Number.isInteger(rules.minAttempts)&&rules.minAttempts>=1&&rules.minAttempts<=10000
    &&Number.isInteger(rules.minDurationMs)&&rules.minDurationMs>=0&&rules.minDurationMs<=60000;
  if(!valid){const error=new Error('average_rules_invalid');error.code=error.message;error.status=503;throw error;}
  return rules;
}
