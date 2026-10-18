import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
import {patchInviteShortCodes} from './supabase_invite_short_patch.mjs';
const root=process.cwd(),out=fs.mkdtempSync(path.join(os.tmpdir(),'untouch-invite-generation-'));
const checks=[];
try{
  let source=fs.readFileSync('tools/prepare_supabase_core.mjs','utf8');
  for(const module of ['supabase_current_game_patch','supabase_invite_short_patch'])source=source.replace(`from './${module}.mjs'`,`from '${pathToFileURL(path.join(root,`tools/${module}.mjs`)).href}'`);
  source=source.replace('const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));',`const root=${JSON.stringify(root)};`)
    .replace("const out=path.join(root,'supabase/functions/_shared/core');",`const out=${JSON.stringify(out)};`);
  await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
  for(const name of ['engine.mjs','policy.mjs','play.mjs','defaults.json']){
    const generated=fs.readFileSync(path.join(out,name)),current=fs.readFileSync(path.join(root,'supabase/functions/_shared/core',name));
    assert.ok(generated.equals(current),`generator byte-exact ${name}`);
    checks.push({name,byteExact:true,sha256:crypto.createHash('sha256').update(current).digest('hex')});
  }
  const baseline=fs.readFileSync('docs/release-evidence/invite-short-domain-20261018/baseline/supabase/functions/_shared/core/engine.mjs','utf8');
  assert.equal(patchInviteShortCodes(baseline),fs.readFileSync('supabase/functions/_shared/core/engine.mjs','utf8'),'only narrow invite patch changed generated engine');
  assert.throws(()=>patchInviteShortCodes('missing anchors'),/not unique/);
  assert.throws(()=>patchInviteShortCodes(baseline.replace('function seed(uid, policy, now) {','function seed(uid, policy, now) {\nfunction seed(uid, policy, now) {')),/not unique/);
  console.log(JSON.stringify({pass:7,fail:0,baselinePlusNarrowPatchOnly:true,anchorGuards:true,checks},null,2));
}finally{fs.rmSync(out,{recursive:true,force:true});}
