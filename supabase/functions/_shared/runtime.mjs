import pg from 'pg';
import {createClient} from '@supabase/supabase-js';
import {ApiError,requireThat} from './core/policy.mjs';
import databaseCa from './database-ca.mjs';
export const env=name=>Deno.env.get(name)??'';
let pool,auth;
export function database(){
  if(pool)return pool;
  const connectionString=env('UNTOUCH_DATABASE_URL');requireThat(connectionString,'database_not_configured',503);
  const parsed=new URL(connectionString);
  requireThat(parsed.username.startsWith('untouch_runtime'),'database_role_invalid',503);
  pool=new pg.Pool({connectionString,ssl:{rejectUnauthorized:true,ca:databaseCa},max:2,connectionTimeoutMillis:8000,idleTimeoutMillis:10000});
  pool.on('error',()=>console.error('database_connection_error'));
  return pool;
}
export function authAdmin(){
  requireThat(env('SUPABASE_URL')&&env('SUPABASE_SERVICE_ROLE_KEY'),'auth_not_configured',503);
  return auth??=createClient(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
}
export async function authenticated(request){
  const token=request.headers.get('authorization')?.match(/^Bearer ([A-Za-z0-9_.-]+)$/)?.[1];
  requireThat(token&&token.length<12000,'unauthorized',401);
  const {data,error}=await authAdmin().auth.getUser(token);
  requireThat(!error&&data.user,'unauthorized',401);return data.user;
}
export function identity(user){
  // identities come from the Auth service. user_metadata can be edited by
  // users and must never establish Google linkage or administrator rights.
  const google=user.identities?.find(item=>item.provider==='google');
  const trusted=google?.identity_data??{};
  return{googleLinked:!!google,name:typeof trusted.full_name==='string'?trusted.full_name.slice(0,200):null,
    email:typeof trusted.email==='string'?trusted.email.slice(0,320):null};
}
export async function input(request){
  requireThat(request.headers.get('content-type')?.startsWith('application/json'),'content_type_invalid',415);
  const reader=request.body?.getReader();requireThat(reader,'body_invalid',400);let length=0;const chunks=[];
  while(true){const {value,done}=await reader.read();if(done)break;length+=value.length;if(length>20000){await reader.cancel();throw new ApiError('body_too_large',413);}chunks.push(value);}
  const bytes=new Uint8Array(length);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  try{const value=JSON.parse(new TextDecoder().decode(bytes));requireThat(value&&typeof value==='object'&&!Array.isArray(value),'body_invalid',400);return value;}catch(error){if(error instanceof ApiError)throw error;throw new ApiError('body_invalid',400);}
}
export function credentials(name){try{return JSON.parse(env(name)||'null');}catch{throw new ApiError('credentials_invalid',503);}}
export function cors(request,admin=false){
  const origin=request.headers.get('origin');
  const allowed=env('ADMIN_ALLOWED_ORIGINS').split(',').map(v=>v.trim()).filter(Boolean);
  if(admin&&origin)requireThat(allowed.includes(origin),'origin_denied',403);
  return{'Content-Type':'application/json;charset=utf-8','Cache-Control':'no-store',Vary:'Origin',
    ...(origin&&allowed.includes(origin)?{'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'}:{})};
}
export function handler(callback,{admin=false}={}){return async request=>{
  let headers={'Content-Type':'application/json;charset=utf-8','Cache-Control':'no-store'};
  try{
    headers=cors(request,admin);if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
    requireThat(request.method==='POST','method_invalid',405);
    const user=await authenticated(request),body=await input(request);
    return new Response(JSON.stringify(await callback({user,body,request})),{headers});
  }catch(error){const known=typeof error.code==='string'&&Number.isInteger(error.status);
    if(!known)console.error(JSON.stringify({event:'unhandled_request_error',name:error.name,
      code:typeof error.code==='string'&&/^[A-Za-z0-9_]{1,40}$/.test(error.code)?error.code:undefined,
      frames:typeof error.stack==='string'?error.stack.split('\n').slice(1,4):undefined}));
    return new Response(JSON.stringify({ok:false,error:known?error.code:'service_unavailable',...(known&&Array.isArray(error.details)?{details:error.details}:{})}),{status:known?error.status:503,headers});
  }
};}
