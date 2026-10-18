// Calendar days use the game's existing server timezone: Europe/Minsk, UTC+3.
const DAY=86400000,OFFSET=10800000;
export function rewardedQuota(player,bonus,stamp){
  const day=Math.floor((stamp+OFFSET)/DAY);
  const saved=player.adRewardsDaily;
  const used=saved?.day===day ? Math.max(0,Math.trunc(saved.count)) : 0;
  const limit=bonus.videoDailyLimit??20;
  return {day,used,limit,remaining:Math.max(0,limit-used),resetAt:(day+1)*DAY-OFFSET};
}
