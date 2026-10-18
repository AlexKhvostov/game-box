// Supabase-only short invite aliases. The reviewed Firebase source stays unchanged.
export function patchInviteShortCodes(source) {
  const replace = (before, after) => {
    if (!source.includes(before)) before = before.replaceAll('\n', '\r\n');
    if (source.split(before).length !== 2) throw Error(`Invite alias patch anchor is not unique: ${before.slice(0, 90)}`);
    source = source.replace(before, after);
  };
  replace("function seed(uid, policy, now) {", `// invite-short-alias: retain legacy aliases; reserve short aliases inside SERIALIZABLE tx.
const shortCodeFor = (uid, attempt) => [...Buffer.from(hash(\`invite:v2:\${uid}:\${attempt}\`), 'hex').subarray(0, 6)].map(b => alphabet[b & 31]).join('');
function seed(uid, policy, now) {`);
  replace("      } else if (['invites_state','invites_bind','invites_list'].includes(action)) {", `      } else if (['invites_state','invites_bind','invites_list'].includes(action)) {
        if (!p.ownShortCode) {
          for (let attempt=0; attempt<32; attempt++) {
            const candidate=shortCodeFor(uid,attempt), alias=db.collection('inviteCodes').doc(candidate);
            const occupied=await tx.get(alias);
            if (!occupied.exists || occupied.data().uid === uid) {
              p.ownShortCode=candidate;put(alias,{uid,createdAt:stamp});break;
            }
          }
          requireThat(p.ownShortCode,'invite_code_collision',503);
        }`);
  replace("          requireThat(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12}$/.test(code),'invite_code_invalid',400);\n          requireThat(!p.inviterUid || p.inviterCode === code,'invite_already_bound');", "          requireThat(/^(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})$/.test(code),'invite_code_invalid',400);");
  replace("          const code=typeof input.code === 'string' ? input.code.trim().toUpperCase() : '';", "          const rawCode=typeof input.code === 'string' ? input.code.trim() : '';\n          const code=/^(?:[A-Za-z2-9]{6}|[A-Za-z2-9]{12})$/.test(rawCode) ? rawCode.toUpperCase() : '';");
  replace("          requireThat(target.exists,'invite_not_found'); const targetUid=target.data().uid;", "          requireThat(!p.inviterUid || target.exists && target.data().uid === p.inviterUid,'invite_already_bound');\n          requireThat(target.exists,'invite_not_found'); const targetUid=target.data().uid;");
  replace("    return {profileId:owner(p.uid),ownCode:p.ownCode,inviteUrl:`https://untouch-android-game-box-b30d4.web.app/a/${p.ownCode}`,inviterAssigned:!!p.inviterUid,", "    return {profileId:owner(p.uid),ownCode:p.ownShortCode,inviteUrl:`https://untouch.fun/a/${p.ownShortCode}`,inviterAssigned:!!p.inviterUid,");
  replace('export {createEngine,seed,publicProfile,owner,codeFor};','export {createEngine,seed,publicProfile,owner,codeFor,shortCodeFor};');
  return source;
}
