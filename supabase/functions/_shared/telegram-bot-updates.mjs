import {hash,requireThat} from './core/policy.mjs';
// The webhook already verified Telegram's private secret header. Only replies
// to explicit private-chat commands are sent, never broadcasts or test messages.
export function createTelegramBotUpdates({stars,botApi,db,botId,appUrl,now=Date.now}){
  return async update=>{
    requireThat(Number.isSafeInteger(update?.update_id)&&update.update_id>=0,'telegram_update_invalid',400);
    if(update.pre_checkout_query||update.message?.successful_payment||update.message?.refunded_payment||update.subscription)return stars.update(update);
    const m=update.message;
    if(m?.chat?.type!=='private'||!Number.isSafeInteger(m.from?.id)||m.from.id!==m.chat.id||m.from.is_bot)return {ok:true,ignored:true};
    const command=typeof m.text==='string'?m.text.trim().match(/^\/(start|help|support|paysupport|terms)(?:@[A-Za-z0-9_]+)?(?:\s|$)/)?.[1]:null;
    if(!command)return {ok:true,ignored:true};
    const ref=db.collection('telegramBotUpdates').doc(hash(`${botId}:${update.update_id}`));
    const send=await db.runTransaction(async tx=>{
      const old=(await tx.get(ref)).data();if(old?.done||old?.until>now())return false;
      tx.set(ref,{botId,updateId:update.update_id,until:now()+15000,done:false});return true;
    });
    if(!send)return {ok:true,duplicate:true};
    const support=command==='paysupport'||command==='support';
    const text=support?'Поддержка Untouch: support@untouch.fun. По вопросам оплаты укажите User ID из аккаунта игры, дату и товар из квитанции Telegram. Токены и пароли не присылайте.':command==='terms'?'Условия и политика конфиденциальности доступны в игре: Аккаунт → Справка. По вопросам оплаты: /paysupport.':'Untouch — уворачивайтесь от красных кубиков и побейте свой рекорд! Нажмите «Играть». По вопросам оплаты: /paysupport.';
    try{
      requireThat(/^https:\/\/untouch-telegram-app\.onrender\.com\/?$/.test(appUrl),'telegram_app_not_configured',503);
      await botApi('sendMessage',{chat_id:m.chat.id,text,reply_markup:{inline_keyboard:[[{text:'🎮 Играть',web_app:{url:appUrl}}]]}});
      await ref.set({botId,updateId:update.update_id,done:true,at:now()});return {ok:true,replied:true};
    }catch(error){await ref.set({botId,updateId:update.update_id,done:false,until:0});throw error;}
  };
}
