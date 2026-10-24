import {env} from './runtime.mjs';
import {gameRuntime} from './game-runtime.mjs';
import {createTelegramStars} from './telegram-stars.mjs';
import {createTelegramBot} from './telegram-bot.mjs';
let service;
export function telegramStarsRuntime(){
  const token=env('TELEGRAM_MAIN_BOT_TOKEN');
  return service??=createTelegramStars({db:gameRuntime().db,botId:token.split(':')[0],botApi:createTelegramBot({token}),
    getSettings:()=>gameRuntime().platformSettings('telegram'),integrationAccepted:env('TELEGRAM_STARS_ACCEPTED')==='true'});
}
