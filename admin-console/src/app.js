import {createClient} from '@supabase/supabase-js';
import {fields,sections,defaultsSnapshot,getValue,setValue,validateField,applyChanges,changesBetween} from '../../supabase/functions/_shared/config-schema.mjs';
import {projectUrl,publishableKey} from './public-config.js';
import './style.css';
import './readability.css';
import './users.css';
import {mountUsers} from './users.js';
import {mountFeedback} from './feedback.js';
import './feedback.css';

const $=selector=>document.querySelector(selector);
const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const icons={feedback:'<path d="M4 4h16v12H9l-5 4V4Z"/><path d="M8 8h8M8 12h5"/>',settings:'<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3"/><circle cx="15" cy="17" r="3"/>',history:'<path d="M3 10a9 9 0 1 1 2 8M3 4v6h6M12 7v5l3 2"/>',search:'<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4 4"/>',arrow:'<path d="m9 5 7 7-7 7"/>',check:'<path d="m5 12 4 4L19 6"/>',lock:'<rect x="5" y="10" width="14" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',logout:'<path d="M9 4H4v16h5m6-13 5 5-5 5m-7-5h12"/>',refresh:'<path d="M20 7v5h-5M4 17v-5h5M6 7a7 7 0 0 1 12-1l2 6M4 12l2 6a7 7 0 0 0 12-1"/>'};
const icon=name=>`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name]??icons.settings}</svg>`;
const localPreview=['localhost','127.0.0.1'].includes(location.hostname)&&new URLSearchParams(location.search).get('preview')==='1';
const supabase=createClient(import.meta.env.VITE_SUPABASE_URL||projectUrl,import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY||publishableKey,
  {auth:{flowType:'pkce',storage:sessionStorage,persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const state={mode:localPreview?'preview':'signedout',section:'energy',tab:'config',query:'',changedOnly:false,base:structuredClone(defaultsSnapshot),config:structuredClone(defaultsSnapshot.config),etag:null,version:null,initialized:false,remoteLoaded:false,busy:false,history:[],error:null};
const draftKey='untouch-admin-local-preview-v1';
const display=value=>typeof value==='boolean'?value?'Включено':'Выключено':typeof value==='object'?JSON.stringify(value):String(value);
const fieldDisplay=(path,value)=>{if(value==null)return 'Не задано';const field=fields.find(item=>item.path===path);return field?.displayScale?`${value/field.displayScale} ${field.displayUnit}`:display(value);};
const delta=()=>changesBetween(state.base.config,state.config);
const patches=()=>delta().map(change=>({path:change.path,value:change.after}));
function toast(text){$('#toast').textContent=text;$('#toast').classList.add('show');clearTimeout(toast.timer);toast.timer=setTimeout(()=>$('#toast').classList.remove('show'),4500);}
const errors={admin_required:'У этого аккаунта нет доступа к админке. Войдите под аккаунтом владельца.',unauthorized:'Сессия закончилась. Войдите снова.',remote_config_conflict:'Настройки уже изменены в другом окне. Сначала обновите текущую версию. Ваши изменения сохранены в форме.',firebase_credentials_missing:'Сервер ещё не подключён к Firebase Remote Config.',firebase_permission_denied:'Серверу ещё не выдан доступ к Remote Config.',database_not_configured:'Подключение серверной функции к базе ещё настраивается.',service_unavailable:'Сервер временно недоступен. Изменения остаются в форме.',android_conditional_policy_unsupported:'У Android уже есть условия или эксперимент. Публикация этой формой остановлена, чтобы сохранить варианты.'};
async function api(action,extra={},functionName='remote-config-admin'){
  const {data:{session}}=await supabase.auth.getSession();if(!session)throw Error('unauthorized');
  const response=await fetch(`${projectUrl}/functions/v1/${functionName}`,{method:'POST',headers:{Authorization:`Bearer ${session.access_token}`,apikey:publishableKey,'Content-Type':'application/json'},body:JSON.stringify({action,...extra}),signal:AbortSignal.timeout(25000)});
  const result=await response.json().catch(()=>({error:'service_unavailable'}));
  if(!response.ok||!result.ok){const error=Error(result.error??'service_unavailable');error.details=result.details;throw error;}return result;
}
function errorText(error){return errors[error.message]??(error.details?.map(item=>item.error).join('; '))??'Не удалось выполнить действие. Проверьте соединение и повторите.';}
async function task(callback){if(state.busy)return;if(document.querySelector('[aria-invalid="true"]')){toast('Исправьте выделенное значение перед продолжением');return;}state.busy=true;renderActions();try{await callback();}catch(error){toast(errorText(error));}finally{state.busy=false;renderActions();}}
function shell(){
  $('#app').innerHTML=`<aside class="sidebar"><a class="brand" href="/" aria-label="Untouch — главная"><span class="brand-mark"><i></i><i></i></span><span>UNTOUCH<small>ПАНЕЛЬ УПРАВЛЕНИЯ</small></span></a>
    <div class="workspace"><span class="platform">A</span><span>Untouch Android<small>Рабочее пространство</small></span><span class="online-dot"></span></div>
    <p class="nav-caption">УПРАВЛЕНИЕ ИГРОЙ</p><nav aria-label="Главное меню"><button class="nav-item active" data-tab="config">${icon('settings')}<span>Параметры <br>Remote Config</span></button><button class="nav-item" data-tab="users">${icon('lock')}<span>Пользователи</span></button><button class="nav-item" data-tab="feedback">${icon('feedback')}<span>Отзывы</span></button><button class="nav-item" data-tab="history">${icon('history')}<span>История публикаций</span></button></nav>
    <div class="sidebar-note">${icon('lock')}<div>Настройки под контролем<small>Сначала черновик.<br>Потом — публикация.</small></div></div>
    <div id="account" class="account"></div></aside><div class="main"><header class="topbar"><div class="breadcrumb">Untouch <span>/</span> Android <span>/</span> <strong id="crumb">Remote Config</strong></div><div id="connection" class="connection"></div></header><main id="content"></main></div>`;
  document.querySelectorAll('[data-tab]').forEach(button=>button.onclick=()=>switchTab(button.dataset.tab));
  renderAccount();render();
}
function renderAccount(){
  const signed=state.mode==='live';$('#account').innerHTML=`<span class="avatar">${localPreview?'П':'А'}</span><span>${localPreview?'Просмотр интерфейса':signed?'Администратор':'Доступ владельца'}<small>${localPreview?'Локально на компьютере':signed?'Вход выполнен':'Требуется вход'}</small></span>${signed?`<button id="logout" class="icon-button" aria-label="Выйти">${icon('logout')}</button>`:''}`;
  if($('#logout'))$('#logout').onclick=async()=>{if(delta().length&&!confirm('Выйти? Несохранённые изменения в форме будут потеряны.'))return;await supabase.auth.signOut({scope:'local'});state.mode='signedout';state.config=structuredClone(state.base.config);state.history=[];shell();};
  $('#connection').innerHTML=`<span class="status-dot ${signed?'green':''}"></span>${localPreview?'Локальный просмотр':signed?'Защищённое подключение':'Вход администратора'}`;
}
function render(){
  renderAccount();document.querySelectorAll('[data-tab]').forEach(button=>button.classList.toggle('active',button.dataset.tab===state.tab));$('#crumb').textContent=state.tab==='config'?'Remote Config':state.tab==='users'?'Пользователи':state.tab==='feedback'?'Отзывы':'История';
  if(!['live','preview'].includes(state.mode)){renderLogin();return;}
  if(state.tab==='users'){const initialUserId=state.selectedUser;state.selectedUser=null;mountUsers({container:$('#content'),request:(action,args)=>api(action,args,'support-admin'),preview:localPreview,toast,initialUserId});return;}
  if(state.tab==='feedback'){mountFeedback({container:$('#content'),request:(action,args)=>api(action,args,'support-admin'),preview:localPreview,toast,openUser:userId=>{state.selectedUser=userId;state.tab='users';render();}});return;}
  if(state.tab==='history'){renderHistory();return;}
  if(!localPreview&&!state.remoteLoaded){$('#content').innerHTML=`<div class="page-heading"><div><div class="eyebrow">НАСТРОЙКИ ANDROID</div><h1>Параметры Remote Config</h1></div></div><div class="notice error">${escape(state.error??'Подключение настроек ещё выполняется.')}</div><button id="retry-config" class="secondary">Повторить подключение</button>`;$('#retry-config').onclick=()=>task(loadLive);return;}
  const changes=delta();
  $('#content').innerHTML=`<div class="page-heading"><div><div class="eyebrow">НАСТРОЙКИ ANDROID</div><h1>Параметры Remote Config</h1><p>Меняйте баланс и поведение игры в понятной форме.</p></div><span class="service-tag"><span>◆</span> Firebase Remote Config</span></div>
    ${localPreview?'<div class="notice preview"><strong>Локальный просмотр интерфейса</strong><span>Показаны настройки из сборки. Можно проверить форму и сохранить локальный черновик. Публикация в Firebase недоступна.</span></div>':!state.initialized?'<div class="notice"><strong>Первая публикация Android</strong><span>Параметр Android ещё не создан. Показаны настройки из сборки; публикация добавит отдельный параметр игры.</span></div>':''}
    <section class="config-summary" aria-label="Состояние настроек"><div><span class="summary-label">ИСТОЧНИК</span><strong>Remote Config <span class="small-badge">Android</span></strong><small>Настройки игрового клиента</small></div><div><span class="summary-label">ОПУБЛИКОВАННАЯ ВЕРСИЯ</span><strong>${localPreview?'—':escape(state.version??'Ещё нет')}</strong><small>${localPreview?'Облако не подключено к просмотру':state.initialized?'Текущая версия Firebase':'Ожидает первой публикации'}</small></div><div><span class="summary-label">ИЗМЕНЕНИЯ В ФОРМЕ</span><strong id="change-count">${changes.length}</strong><small>Применятся после публикации</small></div></section>
    <div class="editor-toolbar"><label class="search">${icon('search')}<input id="search" type="search" placeholder="Найти параметр: бонус, скорость, звук…" aria-label="Поиск параметров" value="${escape(state.query)}"><kbd>/</kbd></label><label class="changed-filter"><input id="changed-only" type="checkbox" ${state.changedOnly?'checked':''}> Только изменения</label><button id="refresh" class="secondary refresh">${icon('refresh')} Обновить</button></div>
    <div class="editor"><nav id="sections" class="sections" aria-label="Разделы параметров"></nav><div id="fields" class="field-panel"></div></div><div class="bottom-bar"><div><span class="draft-dot"></span><strong id="draft-status">${changes.length?'Есть изменения':'Нет изменений'}</strong><small>Игра проверяет настройки при запуске, не чаще раза в минуту. Начатая попытка сохраняет свои правила.</small></div><div id="actions" class="actions"></div></div>`;
  $('#search').oninput=event=>{state.query=event.target.value;renderFields();};$('#changed-only').onchange=event=>{state.changedOnly=event.target.checked;renderFields();};
  $('#refresh').onclick=()=>task(async()=>{if(delta().length&&!confirm('Обновить настройки из облака? Несохранённые изменения в форме будут заменены.'))return;if(localPreview){state.base=structuredClone(defaultsSnapshot);state.config=structuredClone(state.base.config);render();return;}await loadLive();toast('Текущие настройки загружены');});
  renderSections();renderFields();renderActions();
}
function renderSections(){
  $('#sections').innerHTML=sections.filter(([id])=>fields.some(field=>field.section===id&&!field.hidden)).map(([id,label])=>`<button data-section="${id}" class="${state.section===id?'selected':''}"><span>${escape(label)}</span><small>${fields.filter(f=>f.section===id&&!f.hidden).length}</small></button>`).join('');
  document.querySelectorAll('[data-section]').forEach(button=>button.onclick=()=>{state.section=button.dataset.section;renderSections();renderFields();});
}
function renderFields(){
  if(!$('#fields'))return;const query=state.query.trim().toLowerCase();
  const matches=fields.filter(field=>!field.hidden&&(query?`${field.label} ${field.path} ${field.help}`.toLowerCase().includes(query):field.section===state.section)&&(!state.changedOnly||getValue(state.base.config,field.path)!==getValue(state.config,field.path)));
  const section=sections.find(item=>item[0]===state.section);
  $('#fields').innerHTML=`<div class="section-heading"><div><h2>${query?'Результаты поиска':escape(section[1])}</h2><p>${query?`Найдено параметров: ${matches.length}`:escape(section[2])}</p></div><span class="section-number">${String(sections.findIndex(item=>item[0]===state.section)+1).padStart(2,'0')}</span></div>${matches.length?matches.map(fieldRow).join(''):'<div class="empty">Подходящих параметров нет.<small>Измените поисковый запрос или выключите фильтр изменений.</small></div>'}`;
  document.querySelectorAll('[data-field]').forEach(input=>input.addEventListener('input',()=>onChange(input)));
}
function fieldRow(field){
  const value=getValue(state.config,field.path),before=getValue(state.base.config,field.path),changed=value!==before;
  let control;
  if(field.readOnly)control=`<output class="readonly">${escape(display(value))}</output>`;
  else if(field.type==='boolean')control=`<label class="toggle"><input data-field="${field.path}" type="checkbox" ${value?'checked':''} aria-label="${escape(field.label)}"><span></span></label>`;
  else if(field.options)control=`<select data-field="${field.path}" aria-label="${escape(field.label)}">${field.options.map(option=>`<option ${option===value?'selected':''}>${option}</option>`).join('')}</select>`;
  else control=`<div class="value-control"><input data-field="${field.path}" aria-label="${escape(field.label)}" type="${field.type==='number'?'number':'text'}" value="${escape(field.displayScale?value/field.displayScale:value)}" ${field.type==='number'?`min="${field.displayMin??field.min}" max="${field.displayMax??field.max}" step="${field.displayStep??field.step}"`:''}>${field.displayUnit||field.unit?`<span>${escape(field.displayUnit??field.unit)}</span>`:''}</div>`;
  return`<div class="field-row ${changed?'modified':''}" id="row-${field.path.replaceAll('.','-')}"><div class="field-copy"><label>${escape(field.label)}${changed?'<span class="modified-mark" title="Изменено"></span>':''}</label><p>${escape(field.help)}</p><span class="field-error" aria-live="polite"></span></div><div class="field-value">${control}${changed?`<small>Было: ${escape(fieldDisplay(field.path,before))}</small>`:''}</div></div>`;
}
function onChange(input){
  const field=fields.find(item=>item.path===input.dataset.field);let value=field.type==='boolean'?input.checked:field.type==='number'?input.value===''?NaN:Number(input.value)*(field.displayScale??1):input.value;
  if(field.displayScale&&field.step===1&&Number.isFinite(value))value=Math.round(value);
  const error=field.displayScale&&!input.validity.valid?`Укажите число от ${field.displayMin} до ${field.displayMax} ${field.displayUnit} с шагом ${field.displayStep}.`:validateField(field,value),row=input.closest('.field-row');row.querySelector('.field-error').textContent=error??'';input.setAttribute('aria-invalid',error?'true':'false');
  if(error)return;setValue(state.config,field.path,value);
  const before=getValue(state.base.config,field.path),changed=value!==before;
  row.classList.toggle('modified',changed);
  row.querySelector('.modified-mark')?.remove();row.querySelector('.field-value>small')?.remove();
  if(changed){row.querySelector('.field-copy label').insertAdjacentHTML('beforeend','<span class="modified-mark" title="Изменено"></span>');row.querySelector('.field-value').insertAdjacentHTML('beforeend',`<small>Было: ${escape(fieldDisplay(field.path,before))}</small>`);}
  renderActions();
}
function renderActions(){
  if(!$('#actions'))return;const changes=delta();$('#change-count').textContent=changes.length;$('#draft-status').textContent=changes.length?'Есть изменения':'Нет изменений';
  $('#actions').innerHTML=`<button id="discard" class="text-button" ${!changes.length||state.busy?'disabled':''}>Отменить изменения</button><button id="save" class="secondary" ${state.busy?'disabled':''}>Сохранить черновик</button><button id="preview" class="primary" ${state.busy||(!changes.length&&state.initialized)?'disabled':''}>Проверить изменения ${icon('arrow')}</button>`;
  $('#discard').onclick=()=>{if(!confirm('Отменить все изменения в форме?'))return;state.config=structuredClone(state.base.config);renderFields();renderActions();};
  $('#save').onclick=()=>task(async()=>{applyChanges(state.base,patches());if(localPreview){localStorage.setItem(draftKey,JSON.stringify(patches()));toast('Локальный черновик сохранён на этом компьютере');}else{await api('save_draft',{baseEtag:state.etag,patches:patches()});toast('Черновик сохранён. Настройки игры ещё не изменены');}});
  $('#preview').onclick=()=>task(async()=>{const config=applyChanges(state.base,patches());const result=localPreview?{changes:changesBetween(state.base.config,config)}:await api('preview',{baseEtag:state.etag,patches:patches()});showReview(result);});
}
function showReview(result){
  const dialog=$('#review');dialog.innerHTML=`<div class="dialog-top"><div class="eyebrow">ПЕРЕД ПУБЛИКАЦИЕЙ</div><button id="close-review" class="icon-button" aria-label="Закрыть">×</button></div><h2>Проверьте изменения</h2><p>Изменятся только перечисленные параметры Android.</p><div class="change-list">${result.changes.length?result.changes.map(change=>`<div><strong>${escape(change.label)}</strong><span><del>${escape(fieldDisplay(change.path,change.before))}</del> → <b>${escape(fieldDisplay(change.path,change.after))}</b></span></div>`).join(''):'<p>Первая публикация настроек из сборки. Значения не меняются.</p>'}</div><div class="notice"><span>${localPreview?'Это локальный просмотр. Для публикации потребуется вход и подключение серверной функции.':'Сервер применит публикацию сразу. Игра получает настройки при полном запуске, не чаще раза в минуту; без сети использует сохранённые. Условия начатой попытки сохранятся.'}</span></div><div class="dialog-actions"><button id="cancel-review" class="secondary">Вернуться к форме</button><button id="publish" class="primary" ${localPreview?'disabled':''}>Опубликовать в Remote Config</button></div>`;
  $('#close-review').onclick=$('#cancel-review').onclick=()=>dialog.close();
    $('#publish').onclick=()=>task(async()=>{const button=$('#publish');button.disabled=true;try{const published=await api('publish',{baseEtag:state.etag,patches:patches(),confirmRevision:result.snapshot.revision});dialog.close();await loadLive();toast(`Опубликована версия ${published.version??''}`);}finally{button.disabled=false;}});
  dialog.showModal();
}
function renderHistory(){
  $('#content').innerHTML=`<div class="page-heading"><div><div class="eyebrow">КОНТРОЛЬ ИЗМЕНЕНИЙ</div><h1>История публикаций</h1><p>Изменения настроек, сделанные через эту админку.</p></div></div><div class="history-panel">${localPreview?'<div class="empty">История появится после подключения<small>Локальные черновики не являются публикациями и не попадают в историю Firebase.</small></div>':state.history.length?state.history.map(item=>`<article><span class="history-status ${item.status}">${item.status==='published'?'Опубликовано':item.status==='pending'?'Требует сверки':'Ошибка'}</span><h2>${item.published_version?'Версия '+escape(item.published_version):'Публикация'}</h2><time>${escape(new Date(item.created_at).toLocaleString('ru-RU'))}</time><p>${item.changes.map(change=>escape(change.label)).join(', ')||'Подтверждение текущих настроек'}</p>${item.error_code?`<small>${escape(errors[item.error_code]??'Результат внешней публикации требует проверки')}</small>`:''}</article>`).join(''):'<div class="empty">Публикаций пока нет<small>После первой публикации здесь появится запись с изменёнными параметрами.</small></div>'}</div>`;
}
async function switchTab(tab){state.tab=tab;if(tab==='history'&&!localPreview&&state.mode==='live')await task(async()=>{state.history=(await api('history')).history;});render();}
function renderLogin(){
  $('#content').innerHTML=`<div class="login-layout"><div><div class="eyebrow">ПАНЕЛЬ УПРАВЛЕНИЯ ANDROID</div><h1>Настройки игры.<br>Всё на своих местах.</h1><p>Баланс, бонусы, движение врагов и звук —<br>в одной понятной форме.</p><div class="login-feature">${icon('settings')} Отдельная вкладка Remote Config</div><div class="login-feature">${icon('check')} Проверка значений перед публикацией</div><div class="login-feature">${icon('history')} Черновики и история изменений</div></div><section class="login-card"><span class="login-lock">${icon('lock')}</span><h2>Вход администратора</h2><p>Войдите в Google-аккаунт, которому выдан доступ к настройкам игры.</p>${state.error?`<div class="notice error">${escape(state.error)}</div>`:''}<button id="login" class="primary full">Войти через Google ${icon('arrow')}</button><small>Сам вход в аккаунт не предоставляет права администратора.</small></section></div>`;
  $('#login').onclick=()=>task(async()=>{const {error}=await supabase.auth.signInWithOAuth({provider:'google',options:{redirectTo:location.origin+'/'}});if(error){state.error='Вход через Google ещё не настроен для этого проекта. Подключение выполняется.';renderLogin();}});
}
async function loadLive(){
  const result=await api('get');state.base=result.snapshot;state.config=structuredClone(result.snapshot.config);state.etag=result.etag;state.version=result.version;state.initialized=result.initialized;state.remoteLoaded=true;state.mode='live';state.error=null;
  if(result.draft){if(result.draft.base_etag===result.etag){state.config=applyChanges(state.base,result.draft.patches);toast('Загружен ваш сохранённый черновик');}else toast('Есть черновик от старой версии. Он не применён: настройки в облаке уже менялись.');}
  render();
}
window.addEventListener('beforeunload',event=>{if(delta().length){event.preventDefault();event.returnValue='';}});
window.addEventListener('keydown',event=>{if(event.key==='/'&&!['INPUT','TEXTAREA'].includes(document.activeElement.tagName)&&$('#search')){event.preventDefault();$('#search').focus();}});
async function boot(){
  shell();
  if(localPreview){try{const draft=JSON.parse(localStorage.getItem(draftKey)||'null');if(draft)state.config=applyChanges(state.base,draft);}catch{toast('Сохранённый локальный черновик не подходит к текущей форме');}render();}
  else{const {data:{session}}=await supabase.auth.getSession();if(session){state.mode='live';try{await loadLive();}catch(error){if(error.message==='unauthorized')state.mode='signedout';state.error=errorText(error);render();}}}
}
boot().catch(()=>{state.error='Не удалось инициализировать подключение. Обновите страницу.';shell();});
