import {achievementLevel, medalById, personalSeriesCount} from './achievements.ts';

export const levelRankingLimit = 200;
export const personalMedalTotal = personalSeriesCount * 5;

export interface LevelRankEntry {
  userId: string;
  playerName: string;
  level: number;
  medalCount: number;
  place: number;
}

export interface PublicPlayerMedals {
  userId: string;
  playerName: string;
  level: number;
  earned: string[];
  recordPlace: number | null;
}

const identity = /^supabase:[A-Za-z0-9_-]{1,128}$/;
const integerBetween = (value:unknown,min:number,max:number):value is number =>
  typeof value === 'number' && Number.isSafeInteger(value) && value >= min && value <= max;

export function parseLevelRanking(value:unknown,owner:string):LevelRankEntry[] {
  const result=value as {personalMedalTotal?:unknown;rows?:unknown}|null;
  if(result?.personalMedalTotal!==personalMedalTotal||!Array.isArray(result.rows)||result.rows.length>levelRankingLimit+1)
    throw new Error('level_ranking_invalid');

  const ids=new Set<string>();
  let previousPlace=0;
  return result.rows.map((entry:Partial<LevelRankEntry>|null)=>{
    if(!entry||typeof entry.userId!=='string'||!identity.test(entry.userId)||ids.has(entry.userId)||
      typeof entry.playerName!=='string'||!integerBetween(entry.level,1,6)||!integerBetween(entry.medalCount,0,personalMedalTotal)||
      !integerBetween(entry.place,previousPlace+1,Number.MAX_SAFE_INTEGER)||entry.place>levelRankingLimit&&entry.userId!==owner)
      throw new Error('level_ranking_invalid');
    const {userId,playerName,level,medalCount,place}=entry;
    ids.add(userId);
    previousPlace=place;
    return {userId,playerName,level,medalCount,place};
  });
}

export function parsePublicPlayerMedals(value:unknown,target:string):PublicPlayerMedals {
  const result=value as {player?:Partial<PublicPlayerMedals>}|null;
  const player=result?.player;
  if(!player||!identity.test(target)||player.userId!==target||typeof player.playerName!=='string'||
    !Array.isArray(player.earned)||!player.earned.every(id=>typeof id==='string')||
    !(player.recordPlace===null||integerBetween(player.recordPlace,1,Number.MAX_SAFE_INTEGER)))
    throw new Error('player_medals_invalid');

  const earned=[...new Set(player.earned.filter(id=>medalById(id)))];
  if(player.level!==achievementLevel(earned)) throw new Error('player_medals_invalid');
  return {userId:target,playerName:player.playerName,level:player.level,earned,recordPlace:player.recordPlace};
}
