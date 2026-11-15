// Runs before the app bundle. No network reporting, auth data, or raw errors.
(function () {
  'use strict';
  var done=false, pendingCode='';
  function show(code) {
    if(done)return;
    if(pendingCode&&(code==='START-TIMEOUT'||code==='START-INTERFACE'||code==='START-RUNTIME'))return;
    pendingCode=code;
    var message=document.getElementById('boot-message');
    var retry=document.getElementById('boot-retry');
    if(message)message.textContent='Не удалось загрузить игру. Код: '+code+'. Попробуйте ещё раз.';
    if(retry)retry.hidden=false;
  }
  function resourceError(event) {
    if(done)return;
    var element=event.target;
    if(element&&element.tagName==='SCRIPT')show((element.getAttribute('src')||'').indexOf('/vendor/telegram-web-app-')!==-1?'START-SDK':'START-SCRIPT');
    else if(element&&element.tagName==='LINK'&&element.hasAttribute('data-boot-style'))show('START-STYLE');
    else if(event.target===window)show('START-RUNTIME');
  }
  function loaded(event) {
    var element=event.target;
    if(element&&element.tagName==='LINK'&&element.hasAttribute('data-boot-style'))element.media='all';
  }
  var timer=setTimeout(function(){show('START-TIMEOUT');},15000);
  window.addEventListener('error',resourceError,true);
  document.addEventListener('load',loaded,true);
  document.addEventListener('DOMContentLoaded',function(){
    var retry=document.getElementById('boot-retry');
    if(retry)retry.addEventListener('click',function(){location.reload();});
    if(pendingCode)show(pendingCode);
  },{once:true});
  window.__untouchBoot={
    fail:show,
    stylesReady:function(){
      return Promise.all(Array.prototype.map.call(document.querySelectorAll('link[data-boot-style]'),function(link){
        if(link.sheet){link.media='all';return Promise.resolve();}
        return new Promise(function(resolve,reject){
          link.addEventListener('load',function(){link.media='all';resolve();},{once:true});
          link.addEventListener('error',function(){show('START-STYLE');reject(new Error('startup_styles_unavailable'));},{once:true});
        });
      }));
    },
    ready:function(){
      done=true;clearTimeout(timer);
      window.removeEventListener('error',resourceError,true);
      document.removeEventListener('load',loaded,true);
      var screen=document.getElementById('boot-screen');if(screen)screen.remove();
    }
  };
})();
