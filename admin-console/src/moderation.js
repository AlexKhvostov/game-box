const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const reasons={offensive_name:'Оскорбления или неприемлемое имя',personal_data:'Личные данные или контакты',impersonation:'Выдаёт себя за другого',other:'Другое нарушение'};
export function moderationCard(item){
  return `<article class="feedback-card"><header><div class="feedback-author"><strong>${escape(item.content?.nickname)}</strong><small>${escape(item.content?.googleName)}</small><small>ID: ${escape(item.targetUid)}</small></div><span>${escape(item.status==='pending'?'Новая жалоба':item.status==='resolved'?'Имя скрыто':'Рассмотрено')}</span></header><p>${escape(reasons[item.reason]??item.reason)}</p><small>Текущий ник: ${escape(item.currentNickname??'Профиль удалён')}</small><footer><button class="secondary" data-user="${escape(item.targetUid)}">Карточка игрока</button>${item.status==='pending'?`${item.currentNickname?`<button class="primary" data-report="${escape(item.id)}" data-decision="hide">Скрыть имя для всех</button>`:''}<button class="secondary" data-report="${escape(item.id)}" data-decision="dismiss">Отклонить жалобу</button>`:''}${item.restricted&&item.restrictionId===item.id?`<button class="secondary" data-report="${escape(item.id)}" data-decision="restore">Вернуть имя</button>`:''}</footer></article>`;
}
export function mountModeration({container,request,preview,toast,openUser}){
  const root=document.createElement('section');root.className='feedback-view';container.replaceChildren(root);
  root.innerHTML=`<div class="page-heading"><div><div class="eyebrow">ПУБЛИЧНЫЕ ИМЕНА</div><h1>Жалобы на имена</h1><p>Проверяйте сообщение и текущий ник перед действием. Скрытие имени сохраняет игру, места и баланс.</p></div></div><form class="feedback-toolbar"><select aria-label="Статус жалобы"><option value="pending">Новые</option><option value="all">Все</option><option value="resolved">Имя скрыто</option><option value="dismissed">Рассмотренные</option></select><button class="secondary" ${preview?'disabled':''}>Обновить</button></form><div class="empty" role="status"></div><div class="feedback-list"></div><div class="pagination"><button id="moderation-prev" class="secondary">← Назад</button><button id="moderation-next" class="secondary">Далее →</button></div><div class="notice">Жалобы хранятся 90 дней с ежедневной очисткой. Временное скрытие имени можно отменить; игрок также может сохранить новый допустимый ник.</div>`;
  const $=s=>root.querySelector(s);let offset=0,next=null,status='pending',busy=false,items=new Map();
  function controls(){root.querySelectorAll('button,select').forEach(b=>b.disabled=busy||preview);$('#moderation-prev').disabled=busy||preview||offset===0;$('#moderation-next').disabled=busy||preview||next===null;root.setAttribute('aria-busy',String(busy));}
  async function load(){
    if(busy||preview||!root.isConnected)return;busy=true;controls();
    try{
      const result=await request('moderation_list',{status,offset});if(!root.isConnected)return;
      next=result.nextOffset;items=new Map(result.reports.map(r=>[r.id,r]));$('.empty').textContent=result.reports.length?'':'Жалоб с этим статусом пока нет.';
      $('.feedback-list').innerHTML=result.reports.map(moderationCard).join('');
      root.querySelectorAll('[data-user]').forEach(b=>b.onclick=()=>openUser(b.dataset.user));
      root.querySelectorAll('[data-report]').forEach(b=>b.onclick=()=>void resolve(b.dataset.report,b.dataset.decision));
    }catch{if(root.isConnected)$('.empty').textContent='Не удалось загрузить жалобы. Повторите обновление.';}
    finally{busy=false;controls();}
  }
  async function resolve(id,decision){
    const report=items.get(id);if(busy||!report)return;busy=true;controls();
    try{await request('moderation_resolve',{reportId:id,decision,expectedFingerprint:report.fingerprint,requestId:crypto.randomUUID()});toast(decision==='hide'?'Публичное имя скрыто. Игра и баланс сохранены.':decision==='restore'?'Отображение имени восстановлено.':'Жалоба рассмотрена.');}
    catch(error){toast(error.message==='public_name_changed'?'Игрок уже изменил имя. Проверьте обновлённую жалобу.':'Не удалось сохранить решение. Повторите после обновления.');}
    finally{busy=false;await load();}
  }
  root.querySelector('form').onsubmit=e=>{e.preventDefault();offset=0;status=$('select').value;void load();};
  $('#moderation-prev').onclick=()=>{offset=Math.max(0,offset-25);void load();};$('#moderation-next').onclick=()=>{offset=next??offset;void load();};
  if(preview)$('.empty').textContent='Войдите в админку, чтобы увидеть жалобы.';
  controls();void load();
}
