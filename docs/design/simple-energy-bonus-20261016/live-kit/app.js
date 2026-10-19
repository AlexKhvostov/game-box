import {averageChartPage,averageChartCard,selectAverageChart,addAverageChartButtons} from './average-chart.js?v=rms-live-1';
import {connectRankingKit,openRankingDestination,rankingPage,rankingSheet,rankingMineSheet,rankingDetail,rankingResultPage,handleRankingAction} from "./ranking-kit.js?v=account-stat-navigation-12";
import {hudHeaderPage,paintHudBonus} from "./hud-header.js?v=1";
import {HOURS,PACKS,PLANS,initialState,clock,claim,completeVideo,formatTime} from "./model.js";
import {balance,hud,home,homeControls,abilityStateCatalog,abilityDemoPanel,energySheet,subscriptionSheet,videoSheet,friendsSheet,packsSheet,paymentSheet,adSheet,abilitySheet,componentMap,icon} from "./components.js?v=soft-arrows-3";
import {referencePage,referenceViewer,referenceCatalog,referenceById} from "./reference-page.js?v=rewarded-guide-2";
import {accountPage,accountDialog,accountDialogTitle,connectAccountKit,handleAccountAction,accountClosing} from "./account-kit.js?v=account-stat-navigation-12";
import {bonusMotionPage,playEnergyReward,cancelReceipt,receiptPlaying} from "./bonus-receipt.js?v=rewarded-guide-4";

let state=initialState(),view="library",stack=[],help=false,adSession=null,toastTimer,returnFocus=null,selectedPlan=5;
let receiptSlow=false,receiptReduce=false;
const workspace=document.querySelector("#workspace"),overlayRoot=document.querySelector("#overlay-root");
const introDefaults={title:document.querySelector(".intro h1").innerHTML,copy:document.querySelector(".intro-copy").innerHTML,note:document.querySelector(".demo-note").innerHTML};
connectAccountKit({open,close,refresh,toast,openRanking:openRankingDestination});
connectRankingKit({open,close,refresh,toast});
const section=(n,title,note)=>'<div class="section-head"><h2><span class="index">'+n+'</span>'+title+'</h2><p>'+note+'</p></div>';
const specimen=(id,title,html,note="",short=false,system=false)=>'<article class="specimen"><div class="spec-label">'+id+' / '+title+'<span>LIVE COMPONENT</span></div><div class="spec-stage '+(short?"short ":"")+(system?"system":"")+'">'+html+'</div><p class="spec-note">'+note+'</p></article>';
function library() {
  return section("01","Окно энергии","E01 / по согласованному неоновому референсу")+
    '<div class="component-grid">'+
    specimen("E01.A","Бонус готов",energySheet(state,{frozen:false,plan:1}),"Закреплённый образец. Нажмите на круг, чтобы открыть живой бонус; получение запустит откат 8 часов.")+
    specimen("E01.B","Игровая перезарядка",energySheet(state,{frozen:true,plan:1}),"Кнопка отключена. Сектор открывается по часовой стрелке; награда остаётся видна.")+
    specimen("E01.D","Подписка ×5",energySheet(state,{frozen:true,plan:5}),"150 энергии за получение. Видео за +40 доступно и подписчикам.")+'</div>'+
    section("02","Главный экран и подписка","H01 · E01 · E02 / тот же бонус, больше энергии")+
    '<div class="component-grid">'+
    specimen("H01","Энергия на главном экране",home(state),"Баланс слева вверху; маленькие кнопки с иллюстрациями и статусами возле таймера. Стоимость — внутри окна.")+
    specimen("E01.C","Подписка ×2",energySheet(state,{frozen:true,plan:2}),"60 энергии за получение. Справа — статус подключения и управление.")+
    specimen("E02","Выбор подписки",subscriptionSheet(state),"×2 — $1 в неделю. ×5 — $3 в неделю. Оплата в наборе только имитируется.")+'</div>'+
    section("03","Бесплатные способы пополнения","E03 · S01 · E04 / прямые и короткие переходы")+
    '<div class="component-grid">'+
    specimen("E03","Перед просмотром",videoSheet(state),"Награда +40. Пауза 2 минуты начинается только после успешного просмотра.")+
    specimen("S01","Рекламный экран",adSheet(state),"Схема внешнего рекламного SDK. Можно пройти деморолик или закрыть без награды.",false,true)+
    specimen("E04","Пригласить друга",friendsSheet(state),"Код, ссылка и итог закреплены. Прокручивается только список людей. Кнопка i открывает подсказку.")+'</div>'+
    section("04","Покупка энергии","E05 · S02 / наглядные пакеты и шаг подтверждения")+
    '<div class="component-grid">'+
    specimen("E05","Пакеты энергии",packsSheet(state),"Иллюстрация объёма возрастает с пакетом. Старые цены читаются так же легко, как новые.")+
    specimen("S02","Оплата Google Play",paymentSheet(state),"Схематичный системный экран. Реальные цены, способы оплаты и внешний вид определяет Google Play.",false,true)+
    specimen("H01.V","Длинные значения",'<div><div class="hud-variants">'+[50,1500,99999].map(n=>'<div class="hud-sample">'+hud(n)+'<small>'+n+' энергии</small></div>').join("")+'</div><p class="small muted center" style="margin-top:22px">Плюс всегда круглый.<br>Ширина подстраивается под число.</p></div>',"Без надписи «Ваш баланс», без второго ресурса. Всё содержимое — DOM и SVG.",true)+'</div>'+
    section("05","Усиления перед попыткой","A01 · A02 / отдельные компактные окна")+
    '<div class="component-grid">'+
    specimen("A01","Шлем",abilitySheet(state,"helmet"),"Один поглощённый удар за попытку. Включённый шлем добавляет 1 к стоимости попытки.")+
    specimen("A02","Прыжок",abilitySheet(state,"jump"),"Второе одновременное касание запускает прыжок. Включение добавляет 1 к стоимости попытки.")+
    specimen("H02","Маленькие кнопки · все состояния",'<div class="game-ui ability-control-samples">'+abilityStateCatalog()+'<p class="small muted center">Шлем: выключен, включён, защита потрачена.<br>Прыжок: выключен, готов, откат.</p>'+actionDemoLink()+'</div>',"Небольшая высота и +20% ширины относительно эскиза. Живой откат — во вкладке «Усиления».",true)+
    specimen("UI","Базовые элементы",'<div class="game-ui"><p class="eyebrow">ENERGY / INTERACTION</p><div style="display:flex;align-items:center;gap:17px;margin:23px 0">'+balance(state.balance)+'</div><button class="neon-btn primary" data-action="open-energy">Открыть энергию</button><p class="small muted" style="margin:20px 0">Информация — открытая типографика.<br>Действие — контур, заливка и отклик.</p><button class="neon-btn" disabled>Недоступное действие</button></div>',"Синий неон отмечает действия; жёлтый — только энергию и готовый бонус.",true)+'</div>';
}
function actionDemoLink(){return '<button class="neon-btn ability-demo-link" data-view="abilities">Посмотреть откат · 2 с ↗</button>';}
function abilitiesPage(){
  return section("H02","Шлем и прыжок","Компактные кнопки по последнему эскизу · ширина +20%, высота 36 px")+'<div class="ability-showcase-layout"><div class="phone">'+home(state)+'</div><div class="ability-showcase-side">'+abilityDemoPanel(state)+'<section class="ability-reference-panel"><h3>Все состояния</h3>'+abilityStateCatalog()+'<p class="caption">Шлем: выкл. / вкл. / защита потрачена.<br>Прыжок: выкл. / готов / откат с таймером.<br>Все кнопки занимают одинаковое место.</p></section></div></div>';
}
let jumpAnimation=0;
let hudAnimation=0;
function stopHudPreview(){cancelAnimationFrame(hudAnimation);hudAnimation=0;document.querySelectorAll('[data-action="hud-run"]').forEach(el=>el.disabled=false);}
function startHudPreview(){
  stopHudPreview();const started=performance.now(),baseOffset=state.offset;
  state.bonusAt=clock(state)+HOURS;refresh();
  function frame(now){
    const elapsed=Math.min(8000,Math.max(0,now-started));
    state.offset=baseOffset+elapsed*(HOURS/8000-1);paintHudBonus(state);
    if(elapsed<8000){document.querySelectorAll('[data-action="hud-run"]').forEach(el=>el.disabled=true);hudAnimation=requestAnimationFrame(frame);}
    else{hudAnimation=0;state.bonusAt=0;refresh();toast("Демо: 8 часов прошли — бонус готов");}
  }
  hudAnimation=requestAnimationFrame(frame);
}
function paintJumpPreview(){
  const remaining=Math.max(0,(state.jumpReadyAt||0)-Date.now());
  const mode=state.jump?(remaining?"cooling":"ready"):"off";
  const text=mode==="cooling"?(Math.ceil(remaining/100)/10).toFixed(1).replace(".",",")+" с":mode==="ready"?"Готов":"Выкл.";
  document.querySelectorAll('[data-live-jump="true"]').forEach(el=>{el.dataset.state=mode;el.setAttribute("aria-label","Прыжок: "+text.replace(/\.$/,"")+". Открыть настройки");el.querySelector(".ability-state").textContent=text;el.querySelector(".ability-recharge-arc").setAttribute("stroke-dashoffset",String(100*(1-remaining/2000)));});
  document.querySelectorAll('[data-demo-jump="true"]').forEach(el=>{el.disabled=remaining>0;});
  if(remaining>0){jumpAnimation=requestAnimationFrame(paintJumpPreview);}else{
    state.jumpReadyAt=0;jumpAnimation=0;
    document.querySelectorAll('[data-jump-announcement]').forEach(el=>el.textContent=state.jump?"Готов. Откат завершён за 2 секунды — можно повторить.":"Прыжок выключен. Запустите показ отката, чтобы включить демо.");
  }
}
function startJumpPreview(){
  if((state.jumpReadyAt||0)>Date.now())return;
  cancelAnimationFrame(jumpAnimation);state.jump=true;state.jumpReadyAt=Date.now()+2000;refresh();
  document.querySelectorAll('[data-jump-announcement]').forEach(el=>el.textContent="Идёт двухсекундный откат. Повторный запуск доступен после завершения.");
  paintJumpPreview();
}
function scenario() {
  return '<div class="scenario-layout"><div class="phone">'+home(state)+'</div><aside class="scenario-guide"><p class="eyebrow">INTERACTIVE WALKTHROUGH</p><h2>Пройдите путь игрока</h2><p>Нажмите на баланс слева вверху. Заберите бонус, включите шлем или прыжок, откройте подписку. После подтверждения демопокупки обновится только баланс этого прототипа.</p><div class="flow-list">'+[
    ["energy","Окно энергии"],["subscription","Увеличить размер бонуса"],["video","Посмотреть рекламу"],["friends","Пригласить друга"],["packs","Купить энергию"],["helmet","Шлем"],["jump","Прыжок"]
  ].map(([id,label])=>'<button data-action="open-'+id+'">'+label+'<span>↗</span></button>').join("")+'</div><p style="margin-top:22px">Кнопки старта нет: в игре попытка начинается касанием поля. Здесь поле — иллюстрация, игровая физика не запускается.</p><p class="caption">Сверху находятся инструменты проверки: подписка, готовность бонуса, баланс и ускорение времени. Они не входят в интерфейс игры.</p></aside></div>';
}
function foundations() {
  return section("UI","Неоновый стиль Untouch","Токены и правила, из которых собраны компоненты")+
    '<div class="foundation-grid"><section class="foundation-card"><h2>Цвет имеет смысл</h2>'+
      [["#28d9ff","Интерактивный голубой","Кнопки, контуры, управление"],["#f9f45e","Энергия","Баланс, награда, цена в энергии"],["#061b2d","Тёмное стекло","Панели и модальные окна"],["#91a9bf","Вторичный текст","Условия и пояснения"]].map(([hex,title,note])=>'<div class="swatch"><i style="--swatch:'+hex+'"></i><span>'+title+'<small>'+hex+' · '+note+'</small></span></div>').join("")+'</section><section class="foundation-card"><h2>Свет и иерархия</h2><p>Тонкий светящийся контур, глубокая синяя заливка, мягкий внутренний свет. Свечение локальное: оно не заливает весь экран.<br><br>Баланс — цифра и молния без рамки внутри окна. Золотой круг обозначает готовую награду. Обычная информация не получает кнопку и объёмную подложку.</p><div style="margin-top:24px">'+balance(1500)+'</div><button class="neon-btn primary" data-action="open-energy" style="margin-top:25px">Действие</button></section><section class="foundation-card"><h2>Состояния и доступность</h2><p>Готово: тёплое свечение и «Забрать».<br><br>Откат: холодный приглушённый круг, крупный таймер, недоступное нажатие. Радиальный сектор отступает по часовой стрелке от 12 часов.<br><br>Фокус с клавиатуры виден; Escape закрывает окно; переключатели работают с клавиатуры. При сниженной анимации в системе пульсация отключена.</p></section></div>';
}
function render() {
  const scroll=window.scrollY;
  const rankPositions=new Map([...workspace.querySelectorAll(".rank-list")].map(el=>[el.dataset.rankingKey,el.scrollTop]));
  const listPositions=[...workspace.querySelectorAll(".friend-list")].map(el=>el.scrollTop);
  workspace.innerHTML=view==="average-chart"?averageChartPage():view==="rewarded-guide"?section("E03","Энергия за рекламу","Согласованный эскиз · два шага ожидания и бонус после закрытия")+'<div class="rewarded-guide-showcase"><div class="phone">'+videoSheet(state)+'</div></div>':view==="bonus-motion"?bonusMotionPage(state,{slow:receiptSlow,reduce:receiptReduce}):view==="library"?library():view==="scenario"?scenario():view==="references"?referencePage():view==="account"?accountPage():view==="abilities"?abilitiesPage():view==="ranking"?rankingPage():view==="result"?rankingResultPage():view==="hud"?hudHeaderPage(state,home(state)):foundations();
  addAverageChartButtons(workspace);
  document.querySelector(".lab").hidden=["references","account","ranking","result","average-chart"].includes(view);
  document.querySelector(".intro h1").innerHTML=view==="account"?'Аккаунт. <span>Компактный неон.</span>':view==="hud"?'Главный экран. <span>Неоновая шапка.</span>':view==="result"?'Результат игрока. <span>Компактные подробности.</span>':introDefaults.title;
  document.querySelector(".intro-copy").innerHTML=view==="account"?'Все текущие функции аккаунта — в компактных игровых окнах.<br>Нажимайте на элементы и проверяйте переходы.':view==="hud"?'Баланс, рейтинг и аккаунт — живые компоненты по последнему эскизу.<br>Кольцо плюса повторяет готовность бонуса из окна энергии.':view==="result"?'Подробности выбранной попытки в едином стиле с рейтингом.<br>Проверьте показатели, усиления и пояснения по нажатию.':introDefaults.copy;
  if(view==='average-chart'){
    document.querySelector('.intro h1').innerHTML='Два графика. <span>Сравнение средних.</span>';
    document.querySelector('.intro-copy').innerHTML='Утверждённое квадратичное и прежнее среднее на тех же 100 попытках.<br>В обоих расчётах — окно 50 и одинаковые веса по давности.';
  }
  if(view==="bonus-motion"){
    document.querySelector(".intro h1").innerHTML='Награда. <span>Энергия в движении.</span>';
    document.querySelector(".intro-copy").innerHTML='Заберите бонус или завершите демонстрационный просмотр рекламы.<br>Один игровой эффект для каждого успешного получения энергии.';
  }
  document.querySelector(".demo-note").innerHTML=view==="account"?'Демонстрационный профиль.<br><strong>Google и рекламный SDK не вызываются.</strong><br>Сохранение, отключение и сброс имитируются только здесь.':introDefaults.note;
  workspace.querySelectorAll(".rank-list").forEach(el=>el.scrollTop=rankPositions.get(el.dataset.rankingKey)||0);
  workspace.querySelectorAll(".friend-list").forEach((el,i)=>el.scrollTop=listPositions[i]||0);
  document.querySelectorAll("[data-view]").forEach(b=>{b.classList.toggle("active",b.dataset.view===view);b.setAttribute("aria-current",b.dataset.view===view?"page":"false");});
  document.querySelector("#lab-balance").value=state.balance;
  document.querySelector("#lab-plan").value=state.plan;
  document.querySelector("#lab-status").textContent="Демо · "+(state.plan===1?"без подписки":"×"+state.plan)+" · "+(state.bonusAt>clock(state)?"бонус на откате":"бонус готов");
  paintHudBonus(state);
  if(hudAnimation)document.querySelectorAll('[data-action="hud-run"]').forEach(el=>el.disabled=true);
  window.scrollTo(0,scroll);
}
function overlayContent() {
  const top=stack.at(-1);if(!top)return"";
  if(top.id==='average-chart')return averageChartCard({modal:true,calculation:top.purchase?.calculation??'rms'});
  if(top.id==="ranking")return rankingSheet("modal");
  if(top.id==="ranking-mine")return rankingMineSheet();
  if(top.id==="ranking-detail")return rankingDetail(top.purchase.id,top.purchase.resultOptions);
  if(top.id.startsWith("acct-"))return accountDialog(top.id.slice(5));
  if(top.id==="reference")return referenceViewer(top.purchase.referenceId);
  if(top.id==="friends")return friendsSheet(state,{help});
  if(top.id==="subscription")return subscriptionSheet(state,{selectedPlan});
  if(top.id==="payment")return paymentSheet(state,top.purchase);
  if(top.id==="ad")return adSheet(state,{running:!!adSession,remaining:adSession?Math.max(0,Math.ceil((adSession.ends-Date.now())/1000)):6});
  return componentMap[top.id]?.(state)||"";
}
function renderOverlay(focus=false) {
  if(!stack.length){overlayRoot.innerHTML="";document.body.style.overflow="";document.querySelector("main").inert=false;document.querySelector(".kit-header").inert=false;document.querySelector(".kit-footer").inert=false;return;}
  const list=overlayRoot.querySelector(".friend-list"),scroll=list?.scrollTop||0;
  const id=stack.at(-1).id;
  const oldRank=overlayRoot.querySelector(".rank-list");
  if(oldRank&&id==="ranking"){stack.at(-1).rankScroll=oldRank.scrollTop;stack.at(-1).rankKey=oldRank.dataset.rankingKey;}
  const dialogTitle=id.startsWith("acct-")?accountDialogTitle(id.slice(5)):({"average-chart":"График среднего",ranking:"Рейтинг","ranking-mine":"Мои попытки","ranking-detail":"Результат игрока",reference:"Референс",energy:"Энергия",subscription:"Увеличить размер бонуса",video:"Энергия за видео",friends:"Пригласить друга",packs:"Купить энергию",payment:"Демонстрация оплаты",ad:"Демонстрация рекламы",helmet:"Шлем",jump:"Прыжок"}[id]);
  overlayRoot.innerHTML='<div class="overlay"><div class="overlay-frame'+(id==="reference"?" reference-viewer":id==="average-chart"?" average-chart-frame":"")+'" role="dialog" aria-modal="true" aria-label="'+dialogTitle+'">'+(stack.length>1?'<button class="overlay-back" data-action="close">← Назад</button>':"")+overlayContent()+'</div></div>';
  addAverageChartButtons(overlayRoot);
  overlayRoot.querySelector(".friend-list")?.scrollTo(0,scroll);
  const nextRank=overlayRoot.querySelector(".rank-list");if(nextRank&&nextRank.dataset.rankingKey===stack.at(-1).rankKey)nextRank.scrollTop=stack.at(-1).rankScroll||0;
  document.body.style.overflow="hidden";document.querySelector("main").inert=true;document.querySelector(".kit-header").inert=true;document.querySelector(".kit-footer").inert=true;
  if(focus)overlayRoot.querySelector("button:not(:disabled)")?.focus();
}
function refresh(focus=false){cancelReceipt();render();renderOverlay(focus);if(jumpAnimation)document.querySelectorAll('[data-demo-jump="true"]').forEach(el=>el.disabled=(state.jumpReadyAt||0)>Date.now());}
function open(id,purchase) {
  const rank=overlayRoot.querySelector(".rank-list");if(rank&&stack.at(-1)?.id==="ranking"){stack.at(-1).rankScroll=rank.scrollTop;stack.at(-1).rankKey=rank.dataset.rankingKey;}
  if(!stack.length)returnFocus=document.activeElement;
  if(id==="subscription")selectedPlan=state.plan>1?state.plan:5;
  stack.push({id,purchase});help=false;renderOverlay(true);
}
function close() {
  cancelReceipt();
  if(stack.at(-1)?.id.startsWith("acct-"))accountClosing(stack.at(-1).id.slice(5));
  if(stack.at(-1)?.id==="ad")adSession=null;
  stack.pop();help=false;renderOverlay(true);
  if(!stack.length){render();if(returnFocus?.isConnected)returnFocus.focus();else workspace.querySelector("button")?.focus();}
}
function toast(message) {
  const el=document.querySelector("#toast");el.textContent=message;el.classList.add("show");
  clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove("show"),3200);
}
function purchase(p) {open("payment",p);}
async function presentEnergyReward({before,amount,source}){
  clearTimeout(toastTimer);document.querySelector('#toast').classList.remove('show');
  // Commit the cooldown presentation before the effect, retaining the same
  // specimen (library, motion demo or overlay) across the refresh.
  const sources=[...document.querySelectorAll('.energy-sheet .bonus-orb')];
  const sourceIndex=sources.indexOf(source);
  refresh();
  source=document.querySelectorAll('.energy-sheet .bonus-orb')[sourceIndex];
  const fx=await playEnergyReward({source,from:before,to:state.balance,amount,duration:receiptSlow?6400:1600,reduce:receiptReduce});
  refresh();
  if(!fx.cancelled)document.querySelector('#receipt-announcement').textContent="Получено "+amount+" энергии. Баланс "+state.balance;
}
async function finishVideoReward(){
  adSession=null;
  const before=state.balance,result=completeVideo(state,clock(state));state=result.state;
  if(stack.at(-1)?.id==="ad")stack.pop();
  if(stack.at(-1)?.id==="video")stack.pop();
  if(stack.at(-1)?.id!=="energy")stack.push({id:"energy"});
  refresh(true);
  if(result.amount)await presentEnergyReward({before,amount:result.amount,source:overlayRoot.querySelector('.bonus-orb')});
  else toast("Награда уже получена");
}
async function handle(action,target) {
  if(action==='average-chart-open-weighted'){selectAverageChart(null);open('average-chart',{calculation:'weighted'});return;}
  if(action==='average-chart-open-rms'){selectAverageChart(null);open('average-chart',{calculation:'rms'});return;}
  if(action==='average-chart-open'){selectAverageChart(null);open('average-chart');return;}
  if(action.startsWith('average-chart-select-')){selectAverageChart(Number(action.slice('average-chart-select-'.length)));const parent=target.closest('.ac-canvas'),scroll=parent?.scrollLeft??0;refresh();document.querySelectorAll('.ac-canvas').forEach(el=>el.scrollLeft=scroll);return;}
  if(receiptPlaying()){
    if(action==="claim"||action==="receipt-replay")return;
    cancelReceipt();refresh();
  }
  if(action.startsWith("receipt-plan-")){state.plan=Number(action.slice(13));state.bonusAt=0;refresh();return;}
  if(action==="receipt-video"){open("video");return;}
  if(action==="receipt-replay"){
    stopHudPreview();state.bonusAt=0;refresh();
    const stage=workspace.querySelector('.receipt-stage');
    if(stage){
      const rect=stage.getBoundingClientRect();
      if(rect.top<0||rect.bottom>innerHeight){
        stage.scrollIntoView({behavior:'instant',block:'center'});
        await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
      }
    }
    const replaySource=workspace.querySelector('[data-action="claim"]');
    if(view==="bonus-motion"&&replaySource)await handle("claim",replaySource);return;
  }
  if(["ready","cooldown","advance","reset","claim"].includes(action))stopHudPreview();
  if(action==="hud-run"){startHudPreview();return;}
  if(action.startsWith("hud-wait-")){stopHudPreview();const minutes=Number(action.slice(9));state.bonusAt=minutes?clock(state)+minutes*60000:0;refresh();return;}
  if(action.startsWith("rank-")){handleRankingAction(action);return;}
  if(action.startsWith("acct-")){await handleAccountAction(action,target);return;}
  if(action==="reference-prev"||action==="reference-next"){
    const top=stack.at(-1);if(top?.id!=="reference")return;
    const index=referenceCatalog.findIndex(x=>x.id===top.purchase.referenceId)+(action==="reference-next"?1:-1);
    if(referenceCatalog[index]){top.purchase.referenceId=referenceCatalog[index].id;renderOverlay(true);}
    return;
  }
  if(action.startsWith("reference-")){const id=action.slice(10);if(referenceById(id))open("reference",{referenceId:id});return;}
  if(action.startsWith("select-plan-")){if(stack.at(-1)?.id!=="subscription")open("subscription");selectedPlan=Number(action.slice(12));renderOverlay();overlayRoot.querySelector('[data-action="'+action+'"]')?.focus();return;}
  if(action.startsWith("preview-ready-")){state.plan=Number(action.slice(14));state.bonusAt=0;render();open("energy");return;}
  if(action==="open-video"){open("video");return;}
  if(action.startsWith("open-")) {open(action.slice(5));return;}
  if(action.startsWith("buy-pack-")){const pack=PACKS.find(p=>p.energy===Number(action.slice(9)));if(pack)purchase({type:"pack",...pack});return;}
  if(action.startsWith("buy-sub-")){const plan=Number(action.slice(8));if(PLANS[plan])purchase({type:"sub",plan});return;}
  switch(action) {
    case "buy-selected":purchase({type:"sub",plan:selectedPlan});break;
    case "restore-demo":toast("Демо: в приложении покупки восстанавливаются через Google Play");break;
    case "manage-demo":toast("Демо: в приложении откроется управление подпиской Google Play");break;
    case "close": if(stack.length)close();else toast("Это образец компонента. Откройте его в режиме «Сценарий».");break;
    case "claim": {
      const before=state.balance,result=claim(state,clock(state));state=result.state;
      if(!result.amount){toast("Бонус ещё перезаряжается");break;}
      await presentEnergyReward({before,amount:result.amount,source:target});
      break;
    }
    case "ready":state.bonusAt=0;refresh();toast("Демо: бонус готов");break;
    case "cooldown":state.bonusAt=clock(state)+HOURS/2;refresh();break;
    case "advance":state.offset+=HOURS;refresh();toast("Демо: прошло 8 часов");break;
    case "reset":cancelAnimationFrame(jumpAnimation);jumpAnimation=0;state=initialState();stack=[];adSession=null;help=false;refresh();toast("Демо сброшено · 50 энергии");break;
    case "toggle-helmet":case "toggle-jump": {
      const kind=action.slice(7);state[kind]=!state[kind];if(kind==="helmet")state.helmetSpent=false;if(kind==="jump"&&!state.jump){state.jumpReadyAt=0;cancelAnimationFrame(jumpAnimation);jumpAnimation=0;}refresh();
      (stack.length?overlayRoot:workspace).querySelector('[data-action="toggle-'+kind+'"]')?.focus();break;
    }
    case "friend-help":
      if(stack.at(-1)?.id!=="friends")open("friends");
      help=!help;renderOverlay(true);break;
    case "copy-code":case "copy-link":case "share-link": {
      const value=action==="copy-code"?"AB7K2":"https://untouch.example/r/AB7K2";
      try{await navigator.clipboard.writeText(value);toast(action==="share-link"?"Демоссылка скопирована для отправки":"Скопировано: "+value);}
      catch{toast("Демонстрационный "+(action==="copy-code"?"код: AB7K2":"адрес: "+value));}
      break;
    }
    case "start-video":
      if(state.adAt>clock(state)){toast("Следующее видео через "+formatTime(state.adAt-clock(state)).slice(3));return;}
      adSession={ends:Date.now()+6000};
      if(stack.at(-1)?.id!=="ad")open("ad");else renderOverlay(true);
      break;
    case "cancel-video":
      adSession=null;if(stack.at(-1)?.id==="ad")close();toast("Видео закрыто · награда не начислена");break;
    case "confirm-payment": {
      const top=stack.at(-1);
      if(!top||top.id!=="payment"){toast("Сначала выберите пакет или подписку");return;}
      const p=top.purchase;
      if(p.type==="sub"){state.plan=p.plan;toast("Демо: подключён бонус ×"+p.plan+" · таймер сохранён");}
      else {state.balance+=p.energy;toast("Демо: +"+p.energy+" энергии");}
      close();refresh(true);break;
    }
    case "demo-jump":startJumpPreview();break;
    case "demo-helmet":state.helmet=!state.helmet;state.helmetSpent=false;refresh();break;
    case "demo-spent":state.helmet=true;state.helmetSpent=true;refresh();break;
    case "demo-jump-off":state.jump=false;state.jumpReadyAt=0;cancelAnimationFrame(jumpAnimation);jumpAnimation=0;refresh();break;
    case "touch-field":toast("Это UI-прототип. В игре касание поля сразу начинает попытку.");break;
  }
}
document.addEventListener("click",e=>{
  const viewButton=e.target.closest("[data-view]");
  if(viewButton){cancelReceipt();view=viewButton.dataset.view;location.hash=view;refresh();return;}
  const button=e.target.closest("[data-action]");
  if(button&&!button.disabled)handle(button.dataset.action,button);
  else if(e.target.classList.contains("overlay"))close();
});
document.querySelector("#lab-balance").addEventListener("input",e=>{state.balance=Math.max(0,Math.min(999999,Math.trunc(Number(e.target.value)||0)));refresh();});
document.querySelector("#lab-plan").addEventListener("change",e=>{state.plan=Number(e.target.value);refresh();});
document.addEventListener("change",e=>{
  if(e.target.id==="receipt-slow")receiptSlow=e.target.checked;
  if(e.target.id==="receipt-reduced")receiptReduce=e.target.checked;
});
document.addEventListener("keydown",e=>{
  if(!stack.length)return;
  if(e.key==="Escape"){e.preventDefault();if(help){help=false;renderOverlay(true);}else close();}
  if(e.key==="Tab") {
    const focusable=[...overlayRoot.querySelectorAll('button:not(:disabled),[tabindex="0"],a[href]')];
    if(!focusable.length)return;
    const first=focusable[0],last=focusable.at(-1);
    if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}
    else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}
  }
});
window.addEventListener("hashchange",()=>{const requested=location.hash.slice(1);if(["bonus-motion","library","scenario","foundations","references","account","abilities","ranking","hud","result","rewarded-guide","average-chart"].includes(requested)){cancelReceipt();view=requested;refresh();}});
if(["bonus-motion","library","scenario","foundations","references","account","abilities","ranking","hud","result","rewarded-guide","average-chart"].includes(location.hash.slice(1)))view=location.hash.slice(1);
setInterval(()=>{
  if(adSession){
    const remaining=Math.max(0,Math.ceil((adSession.ends-Date.now())/1000));
    const timer=overlayRoot.querySelector(".ad-timer");if(timer)timer.textContent="Деморолик · "+remaining+" с";
    if(remaining===0){
      finishVideoReward();
    }
  }
  const remaining=Math.max(0,state.bonusAt-clock(state));
  paintHudBonus(state);
  if(state.bonusAt&&remaining===0){state.bonusAt=0;refresh();}
  document.querySelectorAll('[data-countdown="bonus"]').forEach(el=>el.textContent=formatTime(remaining));
  document.querySelectorAll("[data-ad-wait]").forEach(el=>el.textContent=(el.dataset.adWait==="prompt"?"Доступно через ":"")+formatTime(state.adAt-clock(state)).slice(3));
  document.querySelectorAll('[data-orb-mode="live"].cooling').forEach(el=>{
    const progress=Math.max(0,Math.min(1,1-remaining/HOURS));
    el.style.setProperty("--angle",progress*360+"deg");
    el.querySelectorAll(".progress,.progress-edge").forEach(arc=>arc.setAttribute("stroke-dasharray",progress*100+" 100"));
    el.querySelector(".endpoint")?.setAttribute("cx",50+47*Math.cos(progress*2*Math.PI));
    el.querySelector(".endpoint")?.setAttribute("cy",50+47*Math.sin(progress*2*Math.PI));
  });
  if(state.adAt&&state.adAt<=clock(state)){state.adAt=0;refresh();}
},500);
render();
