import type {InviteState} from '../services/contracts';
/** One public, owner-bound snapshot used by preview, exported PNG and caption. */
export interface ShareInvitation {
  owner:string;code:string;url:string;codeLabel:string;title:string;conditions:string;
}
export function shareInvitationBadge(code:string,locale:'ru'|'en'):Pick<ShareInvitation,'code'|'codeLabel'|'title'>{
  return{code,codeLabel:locale==='ru'?'Пригласительный код':'Invitation code',title:locale==='ru'?'Введи код — получи бонус':'Enter the code — get a bonus'};
}
export function resultInvitation(owner:string|undefined,invites:Pick<InviteState,'ownCode'|'requiredGames'|'minimumEnergy'|'telegramInviteUrl'>|null|undefined,locale:string,contract:1|2|3=3,miniAppTarget=''):ShareInvitation|null{
  const code=invites?.ownCode;
  if(!owner||typeof code!=='string'||!/^(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})$/.test(code))return null;
  const main=['https://t.me/UntouchGameBot','https://t.me/UntouchGameBot/untouch'],test=['https://t.me/TestUntouch_bot'];
  const targets=main.includes(miniAppTarget)?main:test.includes(miniAppTarget)?test:[];
  const url=invites?.telegramInviteUrl;if(typeof url!=='string'||!targets.some(target=>url===`${target}?startapp=invite_${code}`))return null;
  // This caller requests inviteContract3: a retained legacy field cannot override its games rule.
  const energy=invites?.minimumEnergy,energyRule=contract!==3&&Number.isSafeInteger(energy)&&energy!>0;
  const games=invites?.requiredGames;if(!energyRule&&(!Number.isSafeInteger(games)||games!<1))return null;
  const ru=locale==='ru';
  const condition=energyRule?(ru?`Завершите игру, потратив суммарно от ${energy} энергии на завершённые игры.`:`Finish a game and spend at least ${energy} energy on completed games.`):(ru?`Завершите игр: ${games}.`:`Finish ${games} games.`);
  return{owner,url,...shareInvitationBadge(code,ru?'ru':'en'),conditions:ru?`Введите код в аккаунте. ${condition} Google для участия не требуется.`:`Enter the code in your account. ${condition} Google is not required.`};
}
export function sameShareInvitation(a:ShareInvitation|null,b:ShareInvitation|null){return!!a&&!!b&&a.owner===b.owner&&a.code===b.code&&a.url===b.url&&a.title===b.title&&a.conditions===b.conditions&&a.codeLabel===b.codeLabel;}
export function shareCaption(result:string,invitation:ShareInvitation){return`${result}\n${invitation.title}\n${invitation.codeLabel}: ${invitation.code}\n${invitation.conditions}\n${invitation.url}`;}
