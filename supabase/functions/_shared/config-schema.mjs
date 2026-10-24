import defaults from './core/defaults.json' with {type:'json'};
import {averageDefaults,averageRules} from './average-config.mjs';
import {enemyPaceDefaults,enemyPaceRanges,enemyPaceValid} from './enemy-pace-config.mjs';
import {androidGeometryIssues} from './android-constraints.mjs';
export const RC_KEY='android_config_v1';
export const sections=[
  ['enemyPace','Скорость и торможение','Android и Telegram: v(x)=начальная + множитель × ((x + сглаживание)^степень − компенсация). x — расчётное время активной партии. Параметры общие для обеих платформ; начатая партия сохраняет свои правила.'],
  ['ranking','Рейтинг «Среднее»','История попыток, веса и допуск в рейтинг'],
  ['energy','Энергия','Стоимость попыток и усилений'],['bonus','Бонус','Размер бонуса, интервал получения и другие награды'],
  ['enemies','Враги','Движение, форма и столкновения'],['player','Игрок','Размер и внешний вид'],
  ['field','Игровое поле','Границы, размеры и освещение'],['game','Управление и игра','Прыжок, защита и вибрация'],
  ['audio','Звук','Музыка и звуковые эффекты'],['ads','Реклама','Интервалы показа. Действуют только в сборках с включённой рекламой'],
  ['technical','Служебные параметры','Справочные и фиксированные значения']
];
const labels={
  'enemyPace.brakeEnabled':'Кнопка торможения',
  'enemyPace.speedBarEnabled':'Шкала скорости врагов',
"enemyPace.initialSpeed":"Начальная скорость","enemyPace.growthMultiplier":"Множитель роста","enemyPace.growthExponent":"Степень роста","enemyPace.startSmoothingSec":"Сглаживание начала","enemyPace.initialCompensation":"Компенсация начального значения","enemyPace.brakeCooldownSec":"Перезарядка кнопки","enemyPace.brakeFirstReadySec":"Первая готовность кнопки","enemyPace.brakeRewindSec":"Отброс расчётного времени",
  'ranking.average.windowSize':'Попыток в расчёте среднего',
  'ranking.average.previousWeightPercent':'Вес предыдущей попытки',
  'ranking.average.minAttempts':'Минимум попыток для допуска',
  'ranking.average.minDurationMs':'Минимальная длительность попытки',
  'mobileEnemies.startSpeedSteps':'Начальная скорость врагов','mobileEnemies.accelerationSteps':'Ускорение врагов',
  'mobileEnemies.speedVariation':'Разброс начальной скорости','mobileEnemies.accelerationVariation':'Разброс ускорения',
  'enemies.areaMultiplier':'Размер врагов','enemies.angleMinDeg':'Минимальный угол движения','enemies.angleMaxDeg':'Максимальный угол движения',
  'enemies.collideWithEachOther':'Столкновения между врагами','enemies.spinDegPerSec':'Вращение врагов',
  'player.size':'Размер игрока','player.showFace':'Показывать лицо игрока',
  'field.borderWidth':'Толщина границы','field.brightness':'Яркость поля','field.shadowBrightness':'Яркость теней',
  'field.colorHex':'Цвет поля','field.cornerRadius':'Скругление углов','field.maxSide':'Максимальный размер поля',
  'game.startHintEnabled':'Подсказка перед стартом','game.idleSpeedMultiplier':'Скорость в ожидании','game.idleEnemiesMove':'Движение врагов в ожидании',
  'game.jumpEnabled':'Разрешить прыжок','game.jumpDurationSec':'Длительность прыжка','game.jumpScale':'Размер игрока в прыжке',
  'game.helmetEnabled':'Разрешить защиту','game.helmetInvulnSec':'Время защиты после удара','game.startInvulnSec':'Защита после старта',
  'game.heartbeatHaptic':'Вибрация сердцебиения','game.timerHaptic':'Вибрация таймера','game.timerHapticStyle':'Вибрация таймера: основной сигнал',
  'game.timerHapticStyle5':'Вибрация таймера: 5 секунд','game.timerHapticStyle10':'Вибрация таймера: 10 секунд',
  'game.hudSpeedScaleMax':'Верхняя граница индикатора скорости','game.wallsKillPlayer':'Проигрыш при касании стены','game.jumpCooldownSec':'Перезарядка прыжка',
  'audio.music':'Музыка','audio.musicVolume':'Громкость музыки','audio.sfxVolume':'Громкость эффектов',
  'audio.sfxMobWall':'Удар врага о стену','audio.sfxMobCollide':'Столкновение врагов','audio.sfxHeroMob':'Удар игрока о врага',
  'audio.sfxHeroWall':'Удар игрока о стену','audio.sfxNearMiss':'Опасное сближение','audio.sfxHelmet':'Звук защиты','audio.sfxJump':'Звук прыжка','audio.sfxStart':'Звук старта',
  'economy.androidEnergyV2.batteryCapacity':'Ёмкость батарейки','economy.androidEnergyV2.chargeHours':'Период зарядки батарейки',
  'economy.androidEnergyV2.baseAttemptCost':'Стоимость попытки','economy.androidEnergyV2.helmetExtraCost':'Доплата за защиту','economy.androidEnergyV2.jumpExtraCost':'Доплата за прыжок',
  'economy.androidEnergyV2.rewards.achievement':'Награда за достижение','economy.androidEnergyV2.rewards.google':'Награда за привязку Google',
  'economy.androidEnergyV2.rewards.age':'Награда за указание возраста','economy.androidEnergyV2.rewards.feedback':'Награда за отзыв',
  'economy.androidEnergyV2.rewards.invite':'Другу за вход по приглашению',
  'economy.androidEnergyV2.simpleBonus.initialEnergy':'Энергия нового игрока','economy.androidEnergyV2.simpleBonus.reward':'Обычный бонус',
  'economy.androidEnergyV2.simpleBonus.periodSec':'Интервал получения бонуса','economy.androidEnergyV2.simpleBonus.tier2Reward':'Бонус с подпиской ×2',
  'economy.androidEnergyV2.simpleBonus.tier5Reward':'Бонус с подпиской ×5','economy.androidEnergyV2.simpleBonus.videoReward':'Награда за просмотр рекламы',
  'economy.androidEnergyV2.simpleBonus.videoCooldownSec':'Откат рекламы за вознаграждение',
  'economy.androidEnergyV2.simpleBonus.videoDailyLimit':'Рекламных наград за сутки','economy.androidEnergyV2.simpleBonus.inviterReward':'Вам за приглашение друга',
  'economy.runRewardEvery':'Пройденное расстояние для награды','economy.riskRewardEvery':'Опасных сближений для награды',
  'economy.earnSurviveSeconds':'Время для достижения «Выжить»','economy.earnRecordSeconds':'Время для достижения «Рекорд»',
  'economy.earnRisksInRun':'Сближений для достижения','economy.interstitialSessionGraceSec':'Пауза рекламы после запуска',
  'economy.interstitialSessionFreeRounds':'Попыток без рекламы после запуска','economy.interstitialGraceSec':'Начальная пауза полноэкранной рекламы',
  'economy.interstitialCooldownSec':'Пауза между полноэкранными показами','economy.interstitialMinLives':'Порог для полноэкранной рекламы'
};
const rules={
  ...Object.fromEntries(Object.entries(enemyPaceRanges).map(([k,v])=>['enemyPace.'+k,v])),
  'ranking.average.windowSize':[1,500,1,'попыток'],
  'ranking.average.previousWeightPercent':[50,100,0.1,'%'],
  'ranking.average.minAttempts':[1,10000,1,'попыток'],
  'ranking.average.minDurationMs':[0,60000,1,'мс'],
  'mobileEnemies.startSpeedSteps':[0.01,250,0.01,'шаг/с'],'mobileEnemies.accelerationSteps':[0,50,0.01,'шаг/с²'],
  'mobileEnemies.speedVariation':[0,0.5,0.01],'mobileEnemies.accelerationVariation':[0,0.5,0.01],
  'enemies.areaMultiplier':[0.2,20,0.1],'enemies.angleMinDeg':[0,180,1,'°'],'enemies.angleMaxDeg':[0,180,1,'°'],
  'enemies.spinDegPerSec':[-720,720,1,'°/с'],'player.size':[10,79,1,'px'],
  'field.borderWidth':[0,24,0.5,'px'],'field.brightness':[0.4,1.8,0.05],'field.shadowBrightness':[0.4,2.5,0.05],
  'field.cornerRadius':[0,200,1,'px'],'field.maxSide':[100,2000,1,'px'],
  'game.idleSpeedMultiplier':[0.05,1,0.05],'game.jumpDurationSec':[0.12,5,0.01,'с'],'game.jumpScale':[1.05,1.8,0.01],
  'game.helmetInvulnSec':[0,30,0.1,'с'],'game.startInvulnSec':[0,30,0.1,'с'],'game.jumpCooldownSec':[0,20,0.1,'с'],
  'game.hudSpeedScaleMax':[1,4000,1],'audio.musicVolume':[0,1,0.05],'audio.sfxVolume':[0,1,0.05],
  'economy.androidEnergyV2.chargeHours':[1,12,1,'ч'],'economy.androidEnergyV2.baseAttemptCost':[1,1000,1,'энергии'],
  'economy.androidEnergyV2.helmetExtraCost':[0,1000,1,'энергии'],'economy.androidEnergyV2.jumpExtraCost':[0,1000,1,'энергии'],
  'economy.androidEnergyV2.simpleBonus.periodSec':[1,2592000,1,'с'],'economy.androidEnergyV2.simpleBonus.videoCooldownSec':[1,86400,1,'с'],'economy.androidEnergyV2.simpleBonus.videoDailyLimit':[1,1000,1,'раз'],
  'economy.interstitialSessionFreeRounds':[10,1000,1],'economy.interstitialSessionGraceSec':[180,86400,1,'с'],
  'economy.interstitialGraceSec':[0,86400,1,'с'],'economy.interstitialCooldownSec':[0,86400,1,'с'],'economy.interstitialMinLives':[0,99,1]
};
const haptics=['lightImpact','mediumImpact','heavyImpact','selectionClick','vibrate','warning','success','error','none'];
const derived=new Set(['economy.androidEnergyV2.initialEnergy','economy.androidEnergyV2.rewards.ad','economy.androidEnergyV2.watchAdCooldownSec']);
function meta(path,value){
  const section=path.includes('.simpleBonus.')||path.includes('.rewards.')?'bonus':path.startsWith('economy.interstitial')?'ads':path.startsWith('economy.androidEnergyV2')?'energy':path.startsWith('economy.')?'bonus':path.startsWith('mobileEnemies.')||path.startsWith('enemies.')?'enemies':path.split('.')[0];
  const retired=[
    'economy.androidEnergyV2.batteryCapacity','economy.androidEnergyV2.chargeHours',
    'economy.androidEnergyV2.rewards.achievement','economy.androidEnergyV2.rewards.google','economy.androidEnergyV2.rewards.age',
    'economy.earnSurviveSeconds','economy.earnRecordSeconds','economy.earnRisksInRun',
    'game.heartbeatHaptic','game.timerHaptic','game.timerHapticStyle','game.timerHapticStyle5','game.timerHapticStyle10',
    'game.hudSpeedScaleMax','field.cornerRadius','field.maxSide'
  ].includes(path);
  const readOnly=!labels[path]||retired;const type=typeof value;
  let range=rules[path];if(!range&&type==='number')range=[path.startsWith('economy.')&&!path.includes('rewards')&&!path.includes('simpleBonus')?1:0,path.startsWith('economy.')?100000:1000000,1];
  let help=type==='boolean'?'Включите или выключите эту возможность.':range?`Допустимо от ${range[0]} до ${range[1]}${range[3]?' '+range[3]:''}.`:'Изменение применяется после публикации.';
  if(path==='enemyPace.brakeEnabled')help='Включает центральную педаль и замедление врагов. Если выключено, педали и её эффектов нет, расчётное время и скорость продолжают расти по формуле. Шкала включается отдельно.';
  if(path==='enemyPace.speedBarEnabled')help='Показывает шкалу скорости над полем. Не меняет скорость и работу педали торможения. При выключении место под шкалу не резервируется.';
  if(path.startsWith('mobileEnemies.'))help+=' Эти параметры используются прежней моделью Android. Новая модель Telegram настраивается в разделе «Скорость и торможение».';
  if(path==='enemyPace.initialSpeed')help+=' Это добавка к формуле; при 0 фактическая стартовая скорость может быть положительной.';
  if(path==='enemyPace.brakeRewindSec')help+=' Откатывает только расчётное время роста скорости, минимум до 0. Секундомер партии продолжает идти.';
  if(path==='ranking.average.windowSize')help='Число последних подходящих попыток. При изменении сервер пересчитывает рейтинг по сохранённой истории.';
  if(path==='ranking.average.previousWeightPercent')help='Вес предыдущей относительно следующей: 92% означает веса 1, 0,92, 0,8464… Новые попытки влияют сильнее; 100% — обычное среднее.';
  if(path==='ranking.average.minAttempts')help='Допуск после этого числа подтверждённых попыток дольше порога. До допуска игрок видит предварительное среднее и прогресс.';
  if(path==='ranking.average.minDurationMs')help='Строго больше указанного времени. 1000 мс = 1 секунда: ровно 1 секунда не учитывается. Пропущенные попытки не вытесняют историю и не меняют веса.';
  if(path==='game.jumpCooldownSec')help='От 0 до 20 секунд. 0 — следующий прыжок доступен сразу после приземления. Длительность самого прыжка не меняется. Значения меньше 2 секунд требуют обновлённой версии Google-приложения; прежние версии ограничивают откат двумя секундами.';
  if(path==='economy.androidEnergyV2.simpleBonus.periodSec')help='Через сколько часов после получения бонус станет доступен снова. Уже начавшийся период сохраняет свои условия.';
  if(path==='economy.androidEnergyV2.simpleBonus.initialEnergy')help='Начисляется один раз новым аккаунтам. Балансы существующих игроков не меняются.';
  if(path==='economy.androidEnergyV2.rewards.feedback')help='Однократная награда за внутреннее сообщение об опыте игры после траты 100 энергии. Оценка необязательна; от её значения награда не зависит. Не является отзывом Google Play.';
  if(path==='economy.androidEnergyV2.rewards.invite')help='Эту энергию получает новый игрок, пришедший по приглашению: после 5 завершённых игр и подключения Google у обоих. Сумма в игре «Пригласить друга» — другая награда, пригласившему.';
  if(path==='economy.androidEnergyV2.simpleBonus.videoCooldownSec')help='Минимальная пауза после успешного начисления рекламной награды. Проверяется по серверному времени.';
  if(path==='economy.androidEnergyV2.simpleBonus.videoDailyLimit')help='Максимум успешных рекламных наград на аккаунт за календарные сутки. Сброс в 00:00 по Минску (UTC+3). Ошибка и раннее закрытие не расходуют лимит.';
  if(path==='economy.androidEnergyV2.simpleBonus.inviterReward')help='Эту энергию получает тот, кто пригласил друга: после 5 завершённых игр друга и подключения Google у обоих. Именно эта сумма показана в игре в пункте «Пригласить друга».';
  if(path==='economy.androidEnergyV2.chargeHours')help='Серверная политика зарядки, часы. Содержимое купленных товаров не переопределяется.';
  if(readOnly)help=derived.has(path)?'Вычисляется из основного поля выше.':'Справочное значение: в текущей Android-версии не редактируется этой формой.';
  return{path,label:labels[path]??path,section:readOnly?'technical':section,type,readOnly,hidden:readOnly,default:value,
    ...(path==='economy.androidEnergyV2.simpleBonus.periodSec'?{displayScale:3600,displayUnit:'ч',displayStep:0.25,displayMin:0.25,displayMax:720}:{}),
    ...(path==='ranking.average.minDurationMs'?{displayScale:1000,displayUnit:'с',displayStep:0.001,displayMin:0,displayMax:60}:{}),
    ...(range?{min:range[0],max:range[1],step:range[2],unit:range[3]??''}:{}),
    ...(path.includes('HapticStyle')?{options:haptics}:{}),help};
}
const leaves=[];
function walk(value,path=''){if(value&&typeof value==='object')for(const [key,item]of Object.entries(value))walk(item,path?`${path}.${key}`:key);else leaves.push(meta(path,value));}
walk(defaults.config);
if(!defaults.config.enemyPace)walk({enemyPace:enemyPaceDefaults});
if(!defaults.config.ranking?.average)walk({ranking:{average:averageDefaults}});
export const fields=Object.freeze(leaves);
export const defaultsSnapshot=defaults;
export const getValue=(object,path)=>path.split('.').reduce((value,key)=>value?.[key],object)??(path.startsWith('ranking.average.')?averageDefaults[path.split('.').at(-1)]:path.startsWith('enemyPace.')?enemyPaceDefaults[path.split('.').at(-1)]:undefined);
export function setValue(object,path,value){const parts=path.split('.');let target=object;for(const part of parts.slice(0,-1))target=target[part]??={};target[parts.at(-1)]=value;}
export class ConfigInputError extends Error{constructor(code,details=[]){super(code);this.code=code;this.status=400;this.details=details;}}
export function validateField(field,value){
  if(field.readOnly)return 'Это поле доступно только для просмотра';
  if(typeof value!==field.type)return 'Неверный тип значения';
  if(field.type==='number'&&(!Number.isFinite(value)||value<field.min||value>field.max||(field.step===1&&!Number.isInteger(value))))return `Укажите ${field.step===1?'целое ':''}число от ${field.min} до ${field.max}`;
  if(field.displayScale){const displayed=value/field.displayScale;if(displayed<field.displayMin||displayed>field.displayMax||Math.abs(displayed/field.displayStep-Math.round(displayed/field.displayStep))>1e-9)return `Укажите число от ${field.displayMin} до ${field.displayMax} ${field.displayUnit} с шагом ${field.displayStep}.`;}
  if(field.options&&!field.options.includes(value))return 'Выберите значение из списка';
  if(field.path==='field.colorHex'&&!/^#[a-fA-F0-9]{6}$/.test(value))return 'Цвет должен содержать # и шесть цифр/букв';
  return null;
}
export function applyChanges(snapshot,patches){
  if(!Array.isArray(patches)||patches.length>fields.length)throw new ConfigInputError('changes_invalid');
  const config=structuredClone(snapshot.config),seen=new Set(),errors=[];
  for(const patch of patches){const field=fields.find(f=>f.path===patch?.path);if(!field||seen.has(patch.path)){errors.push({path:patch?.path,error:'Неизвестное или повторяющееся поле'});continue;}seen.add(patch.path);
    const error=validateField(field,patch.value);if(error)errors.push({path:patch.path,error});else setValue(config,patch.path,patch.value);
  }
  if(config.enemyPace||patches.some(p=>p.path.startsWith('enemyPace.')))config.enemyPace={...enemyPaceDefaults,...config.enemyPace};
  if(!enemyPaceValid(config))errors.push({path:'enemyPace',error:'Недопустимые параметры скорости и торможения'});
  if(config.enemies.angleMaxDeg<config.enemies.angleMinDeg)errors.push({path:'enemies.angleMaxDeg',error:'Максимальный угол должен быть не меньше минимального'});
  try{averageRules(config);}catch{errors.push({path:'ranking.average',error:'Недопустимые параметры среднего'});}
  errors.push(...androidGeometryIssues(config));
  if(errors.length)throw new ConfigInputError('config_invalid',errors);
  const energy=config.economy.androidEnergyV2,bonus=energy.simpleBonus;
  energy.initialEnergy=bonus.initialEnergy;energy.rewards.ad=bonus.videoReward;energy.watchAdCooldownSec=bonus.videoCooldownSec;
  for(const offer of energy.subscriptions)offer.chargeHours=Math.min(12,energy.chargeHours);
  return config;
}
export function changesBetween(before,after){
  const raw=(object,path)=>path.split('.').reduce((value,key)=>value?.[key],object);
  return fields.filter(f=>!f.readOnly&&JSON.stringify(raw(before,f.path))!==JSON.stringify(raw(after,f.path)))
    .map(f=>({path:f.path,label:f.label,before:raw(before,f.path)??null,after:raw(after,f.path)??null}));
}
