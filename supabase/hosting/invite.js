'use strict';
(() => {
  const match=/^\/a\/((?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12}))\/?$/i.exec(location.pathname);
  if(!match || location.search || location.hash) {
    document.getElementById('message').textContent='Ссылка приглашения не найдена.';
    return;
  }
  const target=new URL('https://play.google.com/store/apps/details');
  target.searchParams.set('id','com.best4u.untouch');
  target.searchParams.set('referrer',`invite=${match[1].toUpperCase()}`);
  const link=document.getElementById('play');link.href=target.toString();link.hidden=false;
  location.replace(target.toString());
})();
