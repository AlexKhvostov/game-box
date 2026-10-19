import {rewardedGuideBody} from "./rewarded-guide.js?v=soft-arrows-3";
import {HOURS,PACKS,PLANS,clock,rewardFor,attemptCost,formatTime,energyText} from "./model.js";
import {energyHud,hudHeader} from "./hud-header.js?v=1";
const paths={
 bolt:'<path d="M14 1 3 14h7L8 25l13-15h-8l1-9Z" fill="currentColor"/>',
 close:'<path d="m5 5 14 14M19 5 5 19"/>',
 plus:'<path d="M12 4v16M4 12h16"/>',
 play:'<rect x="2.5" y="4" width="19" height="16" rx="3"/><path d="m10 8 6 4-6 4Z" fill="currentColor" stroke="none"/>',
 triangle:'<path d="M6 3.5c0-1 1-1.5 2-.9l13 9c1 .6 1 1.6 0 2.2l-13 9c-1 .6-2 .1-2-.9Z" fill="currentColor" stroke="none"/>',
 friend:'<circle cx="9" cy="7" r="4"/><path d="M2 21v-3a7 7 0 0 1 11-5M18 13v9M13.5 17.5h9"/>',
 user:'<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>',
 copy:'<rect x="8" y="7" width="12" height="14" rx="2"/><path d="M15 7V3H4v13h4"/>',
 share:'<path d="M12 15V2m-5 5 5-5 5 5M5 12H3v10h18V12h-2"/>',
 clock:'<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',
 shield:'<path d="m12 2 9 4v6c0 5-9 10-9 10S3 17 3 12V6Z"/><path d="m8 12 3 3 5-6"/>',
 helmet:'<path d="M4 15V11a8 8 0 0 1 16 0v8H8l-4-4ZM4 12h16M8 12v4h12M12 3v5"/>',
 jump:'<path d="M4 19c0-10 16-10 16 0M16 15l4 4 2-5"/><rect x="8" y="3" width="7" height="7" rx="1"/>',
 chevrons:'<path d="m4 12 8-8 8 8M4 21l8-8 8 8"/>',
 fire:'<path d="M14 1c1 7-6 7-5 13 1-2 3-3 5-5 0 5 5 5 5 10a7 7 0 0 1-14 0C3 11 10 10 14 1Z" fill="currentColor" stroke="none"/>',
 check:'<path d="m5 12 5 5L20 6"/>',
};
export function icon(name,cls="") {
  return '<svg class="'+cls+'" viewBox="0 0 24 26" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'+(paths[name]||paths.bolt)+'</svg>';
}
const action=(name,label,cls="neon-btn",extra="")=>'<button class="'+cls+'" data-action="'+name+'" '+extra+'>'+label+'</button>';
export function balance(value,cls="balance-text") {return '<span class="'+cls+'">'+energyText(value)+icon("bolt")+'</span>';}
function sparks() {
  return '<span class="spell-sparks" aria-hidden="true">'+Array.from({length:24},(_,i)=>{
    const angle=i*2.399963, r=43+(i%3)*3;
    return '<i style="--x:'+(50+Math.cos(angle)*r)+'%;--y:'+(50+Math.sin(angle)*r)+'%"></i>';
  }).join("")+'</span>';
}
export function hud(value=50) {
  return energyHud(value);
}
function header(title,s,extra="") {
  return '<header class="sheet-head"><h2>'+title+'</h2>'+extra+(s?balance(s.balance):"")+action("close",icon("close"),"icon-btn close",'aria-label="Закрыть окно"')+'</header>';
}
function wrap(content) {return '<div class="game-ui">'+content+'</div>';}
export function bonus(s,{frozen=null,plan=null}={}) {
  const actual={...s,plan:plan??s.plan};
  const remaining=frozen===true?HOURS/2:frozen===false?0:Math.max(0,s.bonusAt-clock(s));
  const ready=remaining<=0,progress=ready?1:Math.max(0,1-remaining/HOURS);
  const amount=rewardFor(actual);
  return '<div class="bonus-wrap"><button class="bonus-orb '+(ready?"ready":"cooling")+'" data-action="'+(frozen===null?"claim":"preview-ready-"+actual.plan)+'" '+(!ready?"disabled":"")+' aria-label="'+(ready?"Забрать "+amount+" энергии":"Бонус "+amount+" энергии, перезарядка")+'" style="--angle:'+(progress*360)+'deg" data-orb-mode="'+(frozen===null?"live":"fixed")+'">'+
    '<svg class="orb-ring" viewBox="0 0 100 100" aria-hidden="true"><circle class="track" cx="50" cy="50" r="43"/>'+(ready?'<circle cx="50" cy="50" r="43" fill="none" stroke="#ffec7d" stroke-width="2"/>':'<circle class="progress" cx="50" cy="50" r="43" pathLength="100" stroke-dasharray="'+(progress*100)+' 100"/><circle class="progress-edge" cx="50" cy="50" r="43" pathLength="100" stroke-dasharray="'+(progress*100)+' 100"/><circle class="endpoint" cx="'+(50+43*Math.cos(progress*2*Math.PI))+'" cy="'+(50+43*Math.sin(progress*2*Math.PI))+'" r="3.2"/>')+'</svg>'+
    '<span class="orb-main">'+icon("bolt","orb-bolt").replace('viewBox="0 0 24 26"','viewBox="3 1 18 24"')+'<span class="orb-amount"><span class="orb-value">'+amount+'</span>'+icon("bolt","orb-currency").replace('viewBox="0 0 24 26"','viewBox="3 1 18 24"')+'</span>'+(ready?'<span class="orb-claim">Забрать</span>':"")+'</span>'+
    (!ready?'<span class="cooldown-shade"></span><span class="cooldown-time">'+icon("clock")+'<span data-countdown="'+(frozen===true?"fixed":"bonus")+'">'+formatTime(remaining)+'</span></span>':"")+
    (ready?sparks():"")+'</button><span class="bonus-caption">'+(ready?"Бонус готов":"Перезарядка")+'</span></div>';
}
function boost(plan) {
  const art='<span class="boost-art" aria-hidden="true">'+icon("chevrons","boost-chevron")+icon("bolt","boost-lightning")+icon("chevrons","boost-chevron")+'</span>';
  return '<div class="boost-box">'+action("open-subscription",art+'<strong class="boost-label">Увеличить<br>размер<br>бонуса</strong>',"boost-btn"+(plan>1?" owned":""),'aria-label="Увеличить размер бонуса. Подписка"')+'<small>'+(plan===1?'Подписка':'Управлять')+'</small></div>';
}
export function actionRow({symbol,title,amount,label,event,disabled=false}) {
  return '<div class="action-row">'+icon(symbol,"action-icon")+'<span class="action-title">'+title+'</span><span class="reward">+'+amount+icon("bolt")+'</span>'+action(event,label,"neon-btn",(disabled?"disabled ":"")+(event==="open-video"&&disabled?'data-ad-wait="row"':""))+'</div>';
}
export function energySheet(s,variant={}) {
  const plan=variant.plan??s.plan,adWait=Math.max(0,s.adAt-clock(s));
  return wrap('<section class="sheet energy-sheet">'+header("Энергия",s)+'<div class="energy-body"><p class="bonus-title">Бонус каждые 8 часов</p><div class="bonus-row">'+bonus(s,variant)+boost(plan)+'</div>'+
    actionRow({symbol:"play",title:"Смотреть<br>рекламу",amount:40,label:adWait?formatTime(adWait).slice(3):"Смотреть",event:"open-video",disabled:!!adWait})+
    actionRow({symbol:"friend",title:"Пригласить<br>друга",amount:60,label:"Пригласить",event:"open-friends"})+
    action("open-packs",icon("plus")+'Купить энергию',"neon-btn wide")+'</div></section>');
}
export function subscriptionSheet(s,{selectedPlan=s.plan>1?s.plan:5}={}) {
  const offer=n=>{
    const p=PLANS[n],selected=selectedPlan===n;
    return action("select-plan-"+n,'<span class="radio-dot" aria-hidden="true"></span><span class="multiplier-medallion" aria-hidden="true">×'+n+'</span><span class="subscription-yield">'+balance(p.energy)+'<small>за один бонус</small></span><span class="subscription-price">$'+p.price+'<small>/ неделю</small></span>',"subscription-option"+(selected?" selected":""),'role="radio" aria-checked="'+selected+'" aria-label="Бонус ×'+n+', '+p.energy+' энергии, '+p.price+' долларов в неделю"');
  };
  const owned=selectedPlan===s.plan;
  return wrap('<section class="sheet subscription-sheet">'+header("Увеличить размер бонуса",null)+'<div class="sheet-body"><p class="lead">Бонус с одной кнопки каждые 8 часов</p><div role="radiogroup" aria-label="Множитель бонуса">'+offer(2)+offer(5)+'</div><p class="benefit">'+icon("check")+'<span><strong>Без автоматической рекламы</strong><br>Видео за энергию остаётся доступным.</span></p><div class="subscription-footer">'+action("buy-selected",owned?icon("check")+'Подключено ×'+s.plan:'Подключить ×'+selectedPlan+'<small>$'+PLANS[selectedPlan].price+' / неделю</small>',"neon-btn primary",owned?"disabled":"")+'<p class="terms">Подписка на 7 дней. Автопродление.<br>Отмена в Google Play.</p>'+action("restore-demo","Восстановить","text-button")+'<span class="muted"> · </span>'+action("manage-demo","Управлять","text-button")+'</div></div></section>');
}
export function videoSheet(s) {
  const wait=Math.max(0,s.adAt-clock(s));
  return wrap('<section class="sheet video-sheet">'+header("Энергия за рекламу",null)+rewardedGuideBody({reward:40,waitLabel:wait?"Доступно через "+formatTime(wait).slice(3):""})+'</section>');
}
export const FRIENDS = ["Лиса","Кирилл","Mira","Александр","NightFox","Виктор","Дарья","Nika","Денис","Sasha","Артём","Max"];
export function friendsSheet(s,{help=false}={}) {
  return wrap('<section class="sheet friends-sheet">'+header("Пригласить друга",null,action("friend-help","i","info-button",'aria-label="Как работает приглашение" aria-expanded="'+help+'"'))+
    '<div class="invite-top"><div class="copy-line"><span class="copy-label">Код</span><strong class="copy-value">AB7K2</strong>'+action("copy-code",icon("copy"),"icon-btn",'aria-label="Копировать код"')+'</div>'+
    '<div class="copy-line"><span class="copy-label">Ссылка</span><span class="copy-value">untouch.example/r/AB7K2</span>'+action("copy-link",icon("copy"),"icon-btn",'aria-label="Копировать ссылку"')+action("share-link","Поделиться","neon-btn share-button")+'</div>'+
    '<div class="friend-summary"><span>За приглашённого друга</span><strong>+60 ϟ</strong></div><div class="friend-summary"><span>Получено в примере</span><strong>660 ϟ</strong></div></div>'+
    '<div class="list-title"><span>Приглашённые · 12</span><span>Награда</span></div><div class="friend-list" tabindex="0" aria-label="Список приглашённых">'+FRIENDS.map((name,i)=>'<div class="friend-row"><span class="friend-avatar">'+name[0]+'</span><span class="person">'+name+'<small>'+(i===0?"3 из 5 игр":"Условия выполнены")+'</small></span>'+(i===0?'<span class="caption">Ожидается</span>':'<span class="reward">+60'+icon("bolt")+'</span>')+'</div>').join("")+'</div>'+
    (help?'<aside class="popover" role="note">'+action("friend-help",icon("close"),"icon-btn",'aria-label="Закрыть подсказку"')+'<h3>Как получить +60 энергии</h3>Поделитесь кодом или ссылкой. Друг укажет ваш код в своём аккаунте. После 5 игр друга, если у вас обоих подключён Google, вы получите 60 энергии.<br><span class="caption">Код и люди в UI kit — примеры.</span></aside>':"")+'</section>');
}
export function packsSheet(s) {
  const base=PACKS[0];
  const tiles=PACKS.map(p=>{
    const percent=Math.round((1-(p.price/p.energy)/(base.price/base.energy))*100);
    const best=percent===Math.max(...PACKS.map(x=>Math.round((1-(x.price/x.energy)/(base.price/base.energy))*100)));
    const badge=percent>0?'<span class="savings-badge'+(best?' best':'')+'" aria-label="Выгода '+percent+' процентов к базовому пакету">'+icon('fire')+'−'+percent+'%'+(best?'<b aria-hidden="true">★</b>':'')+'</span>':'';
    return '<button class="pack" data-action="buy-pack-'+p.energy+'" aria-label="'+p.energy+' энергии за '+p.price+' долларов"><span class="pack-amount">'+p.energy+icon("bolt")+'</span><span class="energy-pile" aria-hidden="true">'+Array.from({length:p.bars},(_,i)=>'<i style="--h:'+(12+i*2)+'px"></i>').join("")+'</span><span class="pack-price">'+(p.old?'<del class="price-was">$'+p.old+'</del>':'')+'<span class="price-now">$'+p.price+'</span>'+badge+'</span></button>';
  }).join('');
  return wrap('<section class="sheet packs-sheet">'+header("Купить энергию",s)+'<div class="sheet-body"><div class="pack-grid">'+tiles+'</div><p class="pack-comparison">Выгода к цене '+base.energy+' энергии</p><p class="terms">Цены макета. В приложении итоговая цена и валюта — из Google Play.</p></div></section>');
}
export function paymentSheet(s,purchase={type:"pack",energy:250,price:4}) {
  const sub=purchase.type==="sub",p=sub?PLANS[purchase.plan]:purchase;
  return wrap('<section class="system-sheet"><div class="system-label">S02 / Схема Google Play · ДЕМО</div><div class="system-body"><div class="google-mark">Google Play · Untouch</div><h2>Подтверждение '+(sub?"подписки":"покупки")+'</h2><div class="product"><span><strong>'+(sub?"Бонус ×"+purchase.plan:p.energy+" энергии")+'</strong><small>'+(sub?p.energy+" энергии каждые 8 часов":"Разовое пополнение")+'</small></span><strong>$'+p.price+(sub?'<small>за неделю</small>':"")+'</strong></div><p class="small">'+(sub?'7 дней, автопродление. Отмена в Google Play.':"После подтверждения энергия будет зачислена на баланс.")+'</p><p class="terms">Это компонент для проверки сценария. Реальных списаний нет. Настоящее окно и способы оплаты показывает Google Play.</p>'+action("confirm-payment","Подтвердить в демо","neon-btn primary")+action("close","Отмена","text-button")+'</div></section>');
}
export function adSheet(s,{running=false,remaining=6}={}) {
  return wrap('<section class="system-sheet"><div class="system-label">S01 / Демонстрация рекламного SDK</div><div class="system-body"><div class="ad-scene"><span class="cube"></span><strong>NEON RUN</strong><span class="ad-timer">'+(running?"Деморолик · "+remaining+" с":"Пример рекламного видео")+'</span></div><p class="small center">'+(running?"Дождитесь окончания. Награда: +40 энергии.":"В настоящем приложении здесь появляется реклама из SDK.")+'</p>'+action(running?"wait-video":"start-video",running?"Видео идёт…":"Запустить деморолик","neon-btn primary",running?"disabled":"")+action("cancel-video","Закрыть без награды","text-button")+'</div></section>');
}
export function abilityArt(kind) {
  const helmet=kind==="helmet";
  if(helmet)return '<div class="ability-art reference-helmet-art"><img src="references/details/helmet-illustration.png" alt="Кубик в шлеме и защитном барьере: цельная иллюстрация из референса"></div>';
  const finger='<svg viewBox="0 0 32 53" aria-hidden="true" fill="#073b61" stroke="#80eaff" stroke-width="1.7"><circle cx="12" cy="10" r="8" fill="#007ab4" stroke="#16dfff"/><path d="M9 26V11c0-4 6-4 6 0v15l4-5c3-3 7 0 5 4l3 5-2 17H11L3 32c-2-4 2-7 5-3l4 5"/></svg>';
  return '<div class="ability-art"><div class="mascot-scene jump-scene"><span class="mascot-floor"></span><img class="mascot-image" src="art/jump-v1.png" alt="Кубик подпрыгивает"><span class="gesture" aria-hidden="true"><span><b>1</b>'+finger+'</span><span><b>2</b>'+finger+'</span></span></div></div>';
}
// Kept as an alternate vector-only illustration, separate from the reference skin.
export function abilityArtVector(kind) {
  const helmet=kind==="helmet";
  return '<div class="ability-art"><svg viewBox="0 0 220 155" aria-hidden="true"><ellipse cx="110" cy="137" rx="44" ry="6" fill="#00c9ff" opacity=".12"/>'+
    (helmet?'<path d="M110 8 175 32v43c0 44-65 65-65 65S45 119 45 75V32Z" fill="#0d516c" fill-opacity=".15" stroke="#53e4ff" stroke-opacity=".65" stroke-width="1.5"/><path d="M110 14 168 36" fill="none" stroke="#b7f8ff" stroke-width="2"/>':'<path d="M58 112c-16-47 24-84 58-75" fill="none" stroke="#67dfff" stroke-width="2" stroke-dasharray="4 5"/><path d="m105 28 14 9-16 6" fill="none" stroke="#9beaff" stroke-width="2"/><path d="M61 122h34M48 132h38" stroke="#4ddfff" stroke-width="2"/>')+
    '<g transform="translate('+(helmet?"78 62":"94 39")+') rotate('+(helmet?"0":"-14")+' 32 32)"><rect width="64" height="64" rx="12" fill="#174a43" stroke="#86ffcb" stroke-width="2"/><rect x="5" y="5" width="54" height="54" rx="8" fill="#337767"/><path d="M18 27h6m16 0h6" stroke="#a6ffe0" stroke-width="5" stroke-linecap="round"/><path d="M24 43c5 5 13 5 18 0" fill="none" stroke="#8effd3" stroke-width="3" stroke-linecap="round"/>'+
    (helmet?'<path d="M-5 23C-5-12 69-12 69 23L59 31H5Z" fill="#15475d" stroke="#8be8ff" stroke-width="2"/><path d="M32-3v29M-3 23h68" stroke="#6ee3ff" stroke-width="2"/><rect x="24" y="-8" width="16" height="8" rx="3" fill="#0d334e" stroke="#a2f0ff"/>':"")+'</g>'+
    (!helmet?'<g transform="translate(164 97)" fill="#11344a" stroke="#8cd4eb" stroke-width="1.3"><path d="M5 35V8a4 4 0 0 1 8 0v15l4-5a4 4 0 0 1 6 5l-1 21H9Z"/><path d="M-17 30V3a4 4 0 0 1 8 0v19l4-2" opacity=".5"/></g>':"")+'</svg></div>';
}
export function abilitySheet(s,kind="helmet") {
  const helmet=kind==="helmet",name=helmet?"Шлем":"Прыжок",on=s[kind];
  return wrap('<section class="sheet ability-sheet">'+header(name,null)+abilityArt(kind)+'<div class="sheet-body"><h3>'+(helmet?"Защита от одного удара":"Перепрыгивайте врагов")+'</h3><p class="lead">'+(helmet?"Барьер принимает первый удар за попытку. Вы продолжите игру.":"Управляйте одним пальцем. Коснитесь экрана вторым, не убирая первый, — кубик подпрыгнет.<br>В прыжке — защита от врагов.")+'</p><div class="ability-toggle"><strong>'+name+(on?" включён":" выключен")+'</strong>'+action("toggle-"+kind,"","switch",'role="switch" aria-label="'+name+'" aria-checked="'+on+'"')+'</div><p class="ability-cost"><strong>+1'+icon("bolt")+'</strong><span>к стоимости попытки</span></p><p class="attempt">Попытка с вашими настройками: <strong>'+attemptCost(s)+' ϟ</strong></p>'+(!helmet?'<p class="caption center" style="margin-top:8px">Второе одновременное касание, не двойной тап.<br>Опасность стен зависит от правил игры.</p>':"")+'</div></section>');
}
const abilityLabels={off:"Выкл.",on:"Вкл.",spent:"Разбит",ready:"Готов"};
export function abilityShortcut(s,kind,{status=null,remaining=1400,live=true,interactive=true}={}) {
  const helmet=kind==="helmet",name=helmet?"Шлем":"Прыжок";
  const left=Math.max(0,(s.jumpReadyAt||0)-Date.now());
  const mode=status||(helmet?(s.helmet?(s.helmetSpent?"spent":"on"):"off"):(s.jump?(left?"cooling":"ready"):"off"));
  const ms=status?remaining:left,label=mode==="cooling"?(Math.ceil(ms/100)/10).toFixed(1).replace(".",",")+" с":abilityLabels[mode];
  const art=helmet?"references/details/helmet-illustration.png":"art/jump-v1.png";
  const ring='<svg class="ability-recharge" viewBox="0 0 40 40" aria-hidden="true"><circle class="ability-recharge-track" cx="20" cy="20" r="17"/><circle class="ability-recharge-arc" cx="20" cy="20" r="17" pathLength="100" stroke-dasharray="100" stroke-dashoffset="'+(100*(1-ms/2000))+'" transform="rotate(-90 20 20)"/></svg>';
  const crack='<svg class="ability-crack" viewBox="0 0 40 40" aria-hidden="true"><path d="m21 3-5 9 7 7-8 7 4 11M16 12l-7 1m14 6 9-3"/></svg>';
  const body='<span class="ability-face"><span class="ability-mini-art '+(helmet?"helmet-mini":"jump-mini")+'"><img src="'+art+'" alt="">'+(helmet?crack:ring)+'</span><span class="ability-state" '+(!helmet&&live?'data-jump-left="true"':"")+'>'+label+'</span><span class="ability-status-light" aria-hidden="true"></span><span class="ability-open-cue" aria-hidden="true">›</span></span>';
  const attrs='data-state="'+mode+'" data-kind="'+kind+'" '+(!helmet&&live?'data-live-jump="true"':"")+' aria-label="'+name+': '+label.replace(/\.$/,"")+(interactive?'. Открыть настройки':'')+'"';
  return interactive?action("open-"+kind,body,"ability-command",attrs+' aria-haspopup="dialog"'):'<div class="ability-command static-ability" role="img" '+attrs+'>'+body+'</div>';
}
export function abilityStateCatalog() {
  return '<div class="ability-catalog"><div class="ability-column-label">Шлем</div><div class="ability-column-label">Прыжок</div>'+[["off","off"],["on","ready"],["spent","cooling"]].map(([helmet,jump])=>'<div class="ability-state-cell">'+abilityShortcut({},"helmet",{status:helmet,live:false,interactive:false})+'</div><div class="ability-state-cell">'+abilityShortcut({},"jump",{status:jump,live:false,interactive:false})+'</div>').join("")+'</div>';
}
export function abilityDemoPanel(s) {
  return '<section class="ability-demo-panel"><p class="eyebrow">ЖИВАЯ ПРОВЕРКА · ТОЛЬКО UI KIT</p><h3>Откат прыжка — 2 секунды</h3><div class="ability-demo-live">'+abilityShortcut(s,"helmet")+abilityShortcut(s,"jump")+'</div><div class="ability-demo-actions">'+action("demo-jump","Показать откат · 2 с","neon-btn primary",'data-demo-jump="true"')+action("demo-helmet",s.helmet?"Выключить шлем":"Включить шлем","neon-btn")+action("demo-spent","Защита потрачена","neon-btn")+action("demo-jump-off","Выключить прыжок","text-button")+'</div><p class="ability-demo-explanation" role="status" data-jump-announcement>Нажмите «Показать откат»: 2,0 с → 0 → «Готов».</p><p class="caption">В игре прыжок запускается вторым одновременным касанием поля. Эта кнопка — инструмент показа анимации.</p></section>';
}
export function homeControls(s,time="00:00.00") {
  return '<div class="home-controls">'+abilityShortcut(s,"helmet")+'<p class="game-time" aria-label="Время попытки">'+time+'</p>'+abilityShortcut(s,"jump")+'</div>';
}
export function home(s) {
  return wrap('<section class="home-stage">'+hudHeader(s)+'<div class="home-title">UNTOUCH</div>'+homeControls(s)+'<button class="field-preview" data-action="touch-field" aria-label="Коснуться игрового поля"><svg viewBox="0 0 320 220" aria-hidden="true"><path d="M35 190 95 35h145l55 155Z" fill="#061f3150" stroke="#14678a" stroke-width="1"/><path d="M57 155h215M70 120h188M82 85h163" stroke="#0c405d" stroke-width="1"/><rect x="142" y="99" width="35" height="35" rx="6" fill="#1a5f50" stroke="#9affcf" stroke-width="1.5" transform="rotate(12 160 116)"/><path d="m105 49 8 14-17 1Z" fill="#922e5c" stroke="#ed6d98"/><path d="m235 132 9 18-20-1Z" fill="#922e5c" stroke="#ed6d98"/></svg></button><div class="home-bottom"><span class="attempt">Коснитесь поля · попытка <strong>'+attemptCost(s)+' ϟ</strong></span></div></section>');
}
export const componentMap={energy:energySheet,subscription:subscriptionSheet,video:videoSheet,friends:friendsSheet,packs:packsSheet,payment:paymentSheet,ad:adSheet,helmet:s=>abilitySheet(s,"helmet"),jump:s=>abilitySheet(s,"jump")};
