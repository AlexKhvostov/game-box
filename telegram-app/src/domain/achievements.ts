/** Permanent tier identities match Android385 and the server ledger. Labels are
 * requirements, never identifiers: changing 60s to45s cannot repay a medal. */
export type MedalSeriesId = 'time'|'average'|'clean'|'risk'|'distance'|'attempts'|'ranking'|'invites';
export interface AchievementSeries {id:MedalSeriesId;ru:string;en:string;values:readonly (number|string)[];stableIds:readonly string[];helpRu:string;helpEn:string;seconds:boolean}
const series=(id:MedalSeriesId,ru:string,en:string,values:readonly(number|string)[],ids:readonly(number|string)[],helpRu:string,helpEn:string,seconds=false):AchievementSeries=>({id,ru,en,values,stableIds:ids.map(v=>`${id}-${v}`),helpRu,helpEn,seconds});
export const achievementSeries:readonly AchievementSeries[]=[
  series('time','Время выживания','Survival time',[30,60,90,120,180],[30,60,90,120,180],'Продержитесь указанное время в одной подтверждённой попытке.','Survive for the required time in one confirmed attempt.',true),
  series('average','Среднее время','Average time',[10,20,30,45,60],[10,20,30,60,90],'Достигните указанного среднего времени в рейтинге «Средние». Учитываются подтверждённые попытки по действующим правилам рейтинга.','Reach the required average survival time in the Average leaderboard. Confirmed attempts use the current leaderboard rules.',true),
  series('clean','Без усилений','No boosts',[20,30,60,90,120],[20,30,60,90,120],'Продержитесь указанное время в одной попытке. Шлем и прыжок должны быть выключены на всю попытку.','Survive for the required time in one attempt with both helmet and jump disabled throughout.',true),
  series('risk','Риск','Close calls',[2,5,10,20,50],[2,5,10,20,50],'Наберите указанное число близких уклонений от врагов за одну подтверждённую попытку. Смотрите счётчик риска во время игры.','Reach the required number of close calls in one confirmed attempt. Watch the risk counter while playing.'),
  series('distance','Шаги','Steps',[1000,2000,3000,5000,8000],[1000,2000,5000,10000,20000],'Пройдите указанное число игровых шагов за одну подтверждённую попытку. Это путь героя на поле, а не физические шаги с телефоном.','Travel the required number of game steps in one confirmed attempt. This measures the hero’s path, not physical walking.'),
  series('attempts','Количество попыток','Attempts',[100,500,1000,2500,5000],[50,200,500,1000,10000],'Завершите указанное количество подтверждённых попыток. Нажмите «Попытки» вверху, чтобы открыть свою историю.','Complete the required number of confirmed attempts. Tap Attempts above to open your history.'),
  series('ranking','Победы в рейтинге','Leaderboard wins',['day','week','month','year','first'],['day','week','month','year','first'],'Подтверждённые рекорды автоматически участвуют в рейтинге. DAY, WEEK, MONTH и YEAR даются за первое место при закрытии периода. Периоды закрываются в 00:00 UTC; неделя — с понедельника по воскресенье. TOP 1 — если хотя бы раз стали первыми в общем рейтинге. Каждая медаль и её энергия выдаются только один раз.','Confirmed records automatically enter the leaderboard. DAY, WEEK, MONTH and YEAR reward first place when the period closes. Periods close at 00:00 UTC; weeks run Monday–Sunday. TOP 1 rewards reaching first place overall. Each medal and its energy are awarded only once.'),
  series('invites','Приглашения','Invitations',[1,3,5,7,10],[1,5,10,50,100],'Поделитесь кодом из аккаунта. Друг вводит его в «Кто вас пригласил?» и выполняет условия программы приглашений. Считаются уникальные друзья с подтверждённой наградой, а не просто установки. Бонус медали выдаётся отдельно.','Share your account’s invitation code. Friends enter it under “Who invited you?” and complete the invitation program requirements. Only unique qualified friends count, not just installs. The medal bonus is separate.'),
];
export interface AchievementDefinition {id:string;series:MedalSeriesId;tier:number;value:number|string;titleRu:string;titleEn:string;helpRu:string;helpEn:string;seconds:boolean}
export const achievements:readonly AchievementDefinition[]=achievementSeries.flatMap(s=>s.values.map((value,tier)=>({id:s.stableIds[tier]!,series:s.id,tier,value,titleRu:s.ru,titleEn:s.en,helpRu:s.helpRu,helpEn:s.helpEn,seconds:s.seconds})));
export const achievementCatalog=achievements;
export const achievementEnergy:readonly number[]=[5,10,25,50,100];
const byId=new Map(achievements.map(a=>[a.id,a]));
export const medalById=(id:string)=>byId.get(id);
export const cupRanks:readonly number[]=[1000,500,100,10,1];
export function cupTier(place:number|null|undefined):number|null {if(place==null||place<1||place>1000)return null;for(let i=4;i>=0;i--)if(place<=cupRanks[i]!)return i;return null;}
export function levelCounts(earned:Iterable<string>):number[]{const ids=new Set(earned);return Array.from({length:5},(_,tier)=>achievementSeries.filter(s=>s.id!=='ranking'&&ids.has(s.stableIds[tier]!)).length);}
export function achievementLevel(earned:Iterable<string>):number {let level=1;for(const count of levelCounts(earned)){if(count!==7)break;level++;}return level;}
export interface AchievementReceipt {id:string;awardId:string;energy:number;runId?:string|null;at?:number}
export interface BackfillMarker {version:number;id:string;earned:string[];presented?:string[];levelBaseline?:number;cutoffAt?:number|string;localQuietLevel?:number}
export interface AchievementSnapshot {version:number;owner:string;confirmed:boolean;earned:string[];earnedRewards:Record<string,number>;metrics:Record<string,number>;rewards:number[];recordPlace:number|null;averagePlace:number|null;pending:AchievementReceipt[];silentBackfill?:BackfillMarker;invitationBackfill?:BackfillMarker;personalBackfill?:BackfillMarker;averageBackfill?:BackfillMarker}
export function emptyAchievementSnapshot(owner:string):AchievementSnapshot{return {version:2,owner,confirmed:false,earned:[],earnedRewards:{},metrics:{},rewards:[...achievementEnergy],recordPlace:null,averagePlace:null,pending:[]};}
const object=(v:unknown):v is Record<string,unknown>=>!!v&&typeof v==='object'&&!Array.isArray(v);
const stableId=(v:unknown):v is string=>typeof v==='string'&&/^[a-z0-9][a-z0-9-]{0,100}$/.test(v);
const integer=(v:unknown):v is number=>Number.isSafeInteger(v)&&Number(v)>=0;
export function parseBackfillMarker(raw:unknown,version:number):BackfillMarker|undefined {
  if(!object(raw)||raw.version!==version||typeof raw.id!=='string'||!raw.id||!Array.isArray(raw.earned)||!raw.earned.every(stableId))return undefined;
  return {version,id:raw.id,earned:[...new Set(raw.earned)],...(Array.isArray(raw.presented)&&raw.presented.every(v=>typeof v==='string')?{presented:[...new Set(raw.presented as string[])]}:{}),...(integer(raw.levelBaseline)&&raw.levelBaseline>=1&&raw.levelBaseline<=7?{levelBaseline:raw.levelBaseline}:{}),...(typeof raw.cutoffAt==='number'||typeof raw.cutoffAt==='string'?{cutoffAt:raw.cutoffAt}:{})};
}
export function parseAchievementSnapshot(raw:unknown,owner:string):AchievementSnapshot {
  if(!object(raw)||raw.owner!=null&&raw.owner!==owner||raw.version!==undefined&&![1,2].includes(Number(raw.version)))throw Error('achievement_snapshot_invalid');
  const result=emptyAchievementSnapshot(owner);result.confirmed=true;
  if(raw.earned!==undefined){if(!Array.isArray(raw.earned)||!raw.earned.every(stableId))throw Error('achievement_snapshot_invalid');result.earned=[...new Set(raw.earned)];}
  if(raw.rewards!==undefined){if(!Array.isArray(raw.rewards)||raw.rewards.length!==5||!raw.rewards.every(v=>integer(v)&&v<=100000))throw Error('achievement_snapshot_invalid');result.rewards=[...raw.rewards] as number[];}
  for(const field of ['metrics','earnedRewards'] as const)if(raw[field]!==undefined){if(!object(raw[field]))throw Error('achievement_snapshot_invalid');for(const [key,v]of Object.entries(raw[field])){if(!stableId(key)||typeof v!=='number'||!Number.isFinite(v)||v<0||field==='earnedRewards'&&!integer(v))throw Error('achievement_snapshot_invalid');result[field][key]=v;}}
  for(const field of ['recordPlace','averagePlace']as const){const p=raw[field];if(p!=null&&(!integer(p)||p<1))throw Error('achievement_snapshot_invalid');result[field]=p==null?null:p as number;}
  if(raw.pending!==undefined){if(!Array.isArray(raw.pending))throw Error('achievement_snapshot_invalid');const ids=new Set<string>();for(const r of raw.pending){if(!object(r)||typeof r.id!=='string'||!r.id||!stableId(r.awardId)||!integer(r.energy)||r.energy>100000||r.runId!=null&&typeof r.runId!=='string')throw Error('achievement_snapshot_invalid');if(ids.has(r.id))continue;ids.add(r.id);result.pending.push({id:r.id,awardId:r.awardId,energy:r.energy,...(r.runId!=null?{runId:r.runId as string}:{}),...(typeof r.at==='number'?{at:r.at}:{})});}}
  for(const [field,version]of [['silentBackfill',1],['invitationBackfill',2],['personalBackfill',2],['averageBackfill',3]] as const){const marker=parseBackfillMarker(raw[field],version);if(marker)result[field]=marker;}
  return result;
}
const order=new Map<string,number>([...achievements.filter(a=>a.series!=='ranking'),...achievements.filter(a=>a.series==='ranking')].map((a,i)=>[a.id,i]));
for(const [i,rank]of cupRanks.entries()){order.set(`record-cups-${rank}`,100+i);order.set(`average-cups-${rank}`,110+i);}
export function orderAchievementReceipts(receipts:Iterable<AchievementReceipt>):AchievementReceipt[]{return [...receipts].sort((a,b)=>(order.get(a.awardId)??90)-(order.get(b.awardId)??90)||(a.at??0)-(b.at??0)||a.id.localeCompare(b.id));}
export function medalRequirement(a:AchievementDefinition,personalVersion=3,invitationVersion=2):number|string {
  if(a.series==='invites'&&invitationVersion!==2)return [1,5,10,50,100][a.tier]!;
  if(a.series==='average'&&personalVersion!==3)return [10,20,30,60,90][a.tier]!;
  if(a.series==='distance'&&personalVersion===1)return [1000,2000,5000,10000,20000][a.tier]!;
  if(a.series==='attempts'&&personalVersion===1)return [50,200,500,1000,10000][a.tier]!;
  return a.value;
}
