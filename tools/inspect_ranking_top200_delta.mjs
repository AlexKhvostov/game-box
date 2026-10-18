// Read-only investigation. Never logs identity, purchase tokens or credentials.
import fs from 'node:fs';
import path from 'node:path';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
let o;
try {
 const file=path.join(privateDirectory,'ranking-top200-20261018/before.dpapi');
 const before=JSON.parse(dpapi(fs.readFileSync(file,'utf8'),true));
 const at=fs.statSync(file).mtimeMs;
 o=await operator();
 const players=(await o.pool.query("select key,body->'wallet' as wallet,body->'completedGames' as completed from untouch.documents where parent='players' order by key")).rows;
 const changes=[];
 for(let i=0;i<before.players.length;i++){
  const old=before.players[i],current=players.find(p=>p.key===old.key);
  for(const field of ['energy','bestTimeMs','gamesStarted','feedbackSpentEnergy','claimed','unlocked'])
    if(JSON.stringify(old.wallet[field])!==JSON.stringify(current.wallet[field]))changes.push({profile:i+1,field,before:old.wallet[field],after:current.wallet[field]});
  if(old.completed!==current.completed)changes.push({profile:i+1,field:'completedGames',before:old.completed,after:current.completed});
 }
 const rounds=(await o.pool.query("select body->'startedAt' as started,body->'finishedAt' as finished,body->'cost' as cost,body->'canceled' as canceled from untouch.documents where parent='rounds' and (body->>'startedAt')::numeric >= $1",[at])).rows;
 const operations=(await o.pool.query("select body->'kind' as kind,body->'createdAt' as created,body->'appliedAt' as applied,body->'result' as result,jsonb_object_keys(body) as field from untouch.documents where parent like 'players/%/operations' and coalesce((body->>'createdAt')::numeric,(body->>'appliedAt')::numeric,0)>=$1",[at])).rows;
 console.log(JSON.stringify({baselineAt:new Date(at).toISOString(),changes,rounds,operations:operations.map(({result,...r})=>r)}));
} finally {await o?.close();}
