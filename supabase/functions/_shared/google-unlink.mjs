import {requireThat} from './core/policy.mjs';
export async function prepareGoogleUnlink(user,auth){
  const identities=user.identities??[],google=identities.find(item=>item.provider==='google');
  if(!google||identities.length>=2)return{ok:true,ready:true};
  const trusted=google.identity_data??{};
  // Auth Admin's standard update endpoint creates an email identity even for
  // the same email. Use only the primary email already verified by Google;
  // never accept an email, provider flag or target UID from the request body.
  requireThat(trusted.email_verified===true&&typeof trusted.email==='string'&&
    user.email?.toLowerCase()===trusted.email.toLowerCase()&&!user.is_anonymous,'google_unlink_requires_verified_email',409);
  const {data,error}=await auth.updateUserById(user.id,{email:user.email,email_confirm:true});
  requireThat(!error&&data.user?.id===user.id&&data.user.identities?.some(item=>item.provider==='email'),
    'google_unlink_preparation_failed',503);
  return{ok:true,ready:true};
}
