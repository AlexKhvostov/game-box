import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs/promises';
export async function testDatabase(){
  const pg=await PGlite.create();
  await pg.exec("create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key,email text,created_at timestamptz not null default now());");
  const migration=await fs.readFile(new URL('../migrations/20261016180000_android_backend.sql',import.meta.url),'utf8');
  await pg.exec(migration);
  await pg.exec(await fs.readFile(new URL('../migrations/20261016183000_support_console.sql',import.meta.url),'utf8'));
  await pg.exec(await fs.readFile(new URL('../migrations/20261016190000_support_directory.sql',import.meta.url),'utf8'));
  await pg.exec(await fs.readFile(new URL('../migrations/20261016193000_platform_identities.sql',import.meta.url),'utf8'));
  await pg.exec(await fs.readFile(new URL('../migrations/20261018071436_android_ranking_indexes.sql',import.meta.url),'utf8'));
  let tail=Promise.resolve();
  async function connect(){let release;const next=new Promise(resolve=>release=resolve),before=tail;tail=next;await before;return{query:(text,values=[])=>pg.query(text,values),release};}
  const pool={connect,query:async(text,values=[])=>{const client=await connect();try{return await client.query(text,values);}finally{client.release();}}};
  return{pg,pool,close:()=>pg.close()};
}
