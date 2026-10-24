import {requireThat} from './core/policy.mjs';

export const telegramActions=new Set(['guest','profile','rename','wallet_operation','round_start','round_activate','round_cancel','round_finish',
  'scores','attempts_history','invites_state','invites_bind','invites_list','public_rules_accept','public_name_report','public_name_hide','public_names_reset']);
export function createTelegramApi({engine,resolveIdentity,platformConfig=async()=>null,stars,miniAppLink='',checkInvite=async()=>{},monetizationBotId=''}){
  const commercial=identity=>/^\d{5,15}$/.test(monetizationBotId)&&identity.botId===monetizationBotId;
  return async (raw,body)=>{
    const identity=await resolveIdentity(raw);
    if(['stars_invoice','stars_cancel'].includes(body?.action)){
      requireThat(stars,'stars_unavailable',409);
      return body.action==='stars_invoice'?stars.invoice(identity,body):stars.cancel(identity,body);
    }
    requireThat(telegramActions.has(body?.action),'platform_action_invalid',400);
    if(body.action==='wallet_operation'&&body.kind==='rewarded_ad_start'){
      requireThat(commercial(identity),'ad_unavailable',409);
      const settings=await platformConfig();
      requireThat(settings?.ads?.enabled===true&&/^\d+$/.test(settings.ads.rewardedBlockId),'ad_unavailable',409);
    }
    if(body.action==='invites_bind')await checkInvite(identity,body.code);
    const result=await engine.execute(identity.uid,body,identity);
    if(body.action==='guest'&&/^invite_(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})$/.test(identity.startParam??'')){
      try{await checkInvite(identity,identity.startParam.slice(7));const bound=await engine.execute(identity.uid,{action:'invites_bind',code:identity.startParam.slice(7)},identity);result.profile=bound.profile;}
      catch(error){if(!['invite_self','invite_not_found','invite_already_bound'].includes(error.code))throw error;result.inviteError=error.code;}
    }
    if(result.invites&&/^https:\/\/t\.me\/[A-Za-z0-9_]+(?:\/[A-Za-z0-9_]+)?$/.test(miniAppLink))result.invites.telegramInviteUrl=`${miniAppLink}?startapp=invite_${result.invites.ownCode}`;
    if(body.action==='guest'||body.action==='profile'){
      result.platformConfig=await platformConfig();
      if(result.platformConfig&&!commercial(identity)){
        result.platformConfig=structuredClone(result.platformConfig);
        result.platformConfig.ads.enabled=false;result.platformConfig.stars.salesEnabled=false;
      }
      result.offlineIdentity={botId:identity.botId,subject:identity.subject,environment:'production'};
    }
    return result;
  };
}
