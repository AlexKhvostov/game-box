const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const time=value=>value?new Date(value).toLocaleString('ru-RU'):'Дата не указана';

export function feedbackCard(item){
  return `<article class="feedback-card"><header><div class="feedback-author"><strong>${escape(item.nickname)}</strong>${item.email?`<small>${escape(item.email)}</small>`:''}<small class="feedback-user-id">ID: ${escape(item.userId)}</small></div><div class="feedback-meta"><span class="feedback-rating ${item.rating==null?'unrated':''}" aria-label="${item.rating==null?'Без оценки':`Оценка ${escape(item.rating)} из 5`}">${item.rating==null?'Без оценки':`<span aria-hidden="true">★</span> ${escape(item.rating)} <small>/ 5</small>`}</span><time>${escape(time(item.createdAt))}</time></div></header><p class="feedback-comment">${escape(item.comment)}</p><footer>${item.userAvailable?`<button class="secondary" data-feedback-user="${escape(item.userId)}">Карточка игрока →</button>`:'<span>Профиль игрока недоступен</span>'}</footer></article>`;
}

export function mountFeedback({container,request,preview,toast,openUser}){
  const root=document.createElement('section');root.className='feedback-view';container.replaceChildren(root);
  let search='',rating=null,offset=0,next=null,busy=false;
  root.innerHTML=`<div class="page-heading"><div><div class="eyebrow">ОБРАТНАЯ СВЯЗЬ ИГРОКОВ</div><h1>Отзывы</h1><p>Опыт игры, пожелания и оценки, отправленные из Untouch.</p></div><span id="feedback-total" class="service-tag">Supabase</span></div><form class="feedback-toolbar"><input type="search" id="feedback-search" maxlength="160" aria-label="Поиск отзывов" placeholder="Текст отзыва, ник или ID игрока"><select id="feedback-rating" aria-label="Оценка отзыва"><option value="">Все оценки</option>${[5,4,3,2,1].map(n=>`<option value="${n}">${n} из 5</option>`).join('')}<option value="unrated">Без оценки</option></select><button class="primary" ${preview?'disabled':''}>Найти</button><button type="button" id="feedback-refresh" class="secondary" ${preview?'disabled':''}>Обновить</button></form><div id="feedback-status" class="empty" role="status">${preview?'Войдите в админку, чтобы увидеть отзывы':'Загружаем отзывы…'}</div><div id="feedback-list" class="feedback-list"></div><div class="pagination"><button id="feedback-prev" class="secondary" disabled>← Назад</button><span id="feedback-page">Страница 1</span><button id="feedback-next" class="secondary" disabled>Далее →</button></div><div class="notice"><strong>Отзывы внутри игры</strong><span>Сообщения видны администраторам. Это не публичные отзывы Google Play. Оценка необязательна и не влияет на награду игроку.</span></div>`;
  const $=selector=>root.querySelector(selector);
  function controls(){
    root.querySelectorAll('form button,form select').forEach(button=>button.disabled=busy||preview);
    $('#feedback-prev').disabled=busy||offset===0;$('#feedback-next').disabled=busy||next===null;
    root.setAttribute('aria-busy',String(busy));
  }
  async function load(){
    if(busy||preview)return;busy=true;controls();
    try{
      const result=await request('feedback_list',{search,rating,offset});if(!root.isConnected)return;
      next=result.nextOffset;$('#feedback-total').textContent=`Найдено: ${result.total}`;
      $('#feedback-page').textContent=`Страница ${Math.floor(offset/25)+1}`;
      $('#feedback-status').hidden=!!result.feedback.length;
      $('#feedback-status').innerHTML=result.total?'По этому запросу отзывов нет<small>Измените поиск или оценку.</small>':search||rating!==null?'По этому запросу отзывов нет<small>Измените поиск или оценку.</small>':'Отзывов пока нет<small>Здесь появятся сообщения игроков из раздела «Ваш опыт игры».</small>';
      $('#feedback-list').innerHTML=result.feedback.map(feedbackCard).join('');
      root.querySelectorAll('[data-feedback-user]').forEach(button=>button.onclick=()=>openUser(button.dataset.feedbackUser));
    }catch(error){
      if(!root.isConnected)return;
      $('#feedback-status').hidden=false;$('#feedback-status').textContent='Не удалось загрузить отзывы. Нажмите «Обновить», чтобы повторить.';
      toast(error.message==='admin_required'?'У этого аккаунта нет прав администратора.':'Не удалось загрузить отзывы. Проверьте соединение.');
    }finally{busy=false;controls();}
  }
  root.querySelector('form').onsubmit=event=>{event.preventDefault();if(busy)return;search=$('#feedback-search').value.trim();const selected=$('#feedback-rating').value;rating=selected==='unrated'?'unrated':selected?Number(selected):null;offset=0;void load();};
  $('#feedback-refresh').onclick=()=>{offset=0;void load();};
  $('#feedback-prev').onclick=()=>{offset=Math.max(0,offset-25);void load();};
  $('#feedback-next').onclick=()=>{offset=next??offset;void load();};
  void load();
}
