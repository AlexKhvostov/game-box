// Supabase-only current gameplay. Legacy Firebase/Telegram source is preserved.
export function patchCurrentGame(source) {
  const replace=(before,after)=>{
    if(!source.includes(before))throw Error('Current game patch source changed: '+before.slice(0,65));
    source=source.replace(before,after);
  };
  replace('const clone =', "import {averageRanking} from '../average-ranking.mjs';\nimport {recordRankings} from '../record-ranking.mjs';\nconst clone =");
  const oldScores=/      if\(input.period === 'allPeriods'\) \{[\s\S]*?const result=await scores\(input,stamp\);result.scores=await publicRows\(result.scores\);return result;/;
  if(!oldScores.test(source))throw Error('Ranking handler source changed');
  source=source.replace(oldScores,`      if(input.period === 'average') return averageRanking({db,config:policy.config,uid,stamp});
      const records=await recordRankings({db,uid,stamp,period:input.period});
      if(input.period === 'allPeriods') records.average=await averageRanking({db,config:policy.config,uid,stamp});
      return records;`);
  replace('playerName:p.nickname,createdAt:stamp}', 'playerName:p.nickname,createdAt:stamp,attemptAt:r.startedAt}');
  replace('energy:policy.config.economy.androidEnergyV2.simpleBonus.initialEnergy,batteries:[]',
    'feedbackSpentEnergy:0,energy:policy.config.economy.androidEnergyV2.simpleBonus.initialEnergy,batteries:[]');
  replace('wallet.nickname=p.nickname;',
    'wallet.nickname=p.nickname;wallet.feedbackMinimumSpend=100;wallet.feedbackSpentEnergy=Math.max(0,wallet.feedbackSpentEnergy ?? 0);');
  replace("if (kind === 'energy_reward') {",
    "if (kind === 'energy_reward') {requireThat(['google','age'].includes(args.id),'legacy_operation_disabled');");
  replace("if (w.claimed.includes('energy_feedback')) return {};",
    "if (w.claimed.includes('energy_feedback')) return {};requireThat((w.feedbackSpentEnergy ?? 0) >= 100,'feedback_locked');");
  replace('if (!r.activatedAt) {r.activatedAt=stamp;put(rr,r);}',
    'if (!r.activatedAt) {r.activatedAt=stamp;p.wallet.feedbackSpentEnergy=(p.wallet.feedbackSpentEnergy ?? 0)+r.cost;put(rr,r);}');
  const achievement=/    for \(const \[id,condition\] of Object\.entries\(\{survive_10s:[^\n]+\n/;
  if(!achievement.test(source))throw Error('Achievement unlock source changed');
  source=source.replace(achievement,'');
  return source;
}
