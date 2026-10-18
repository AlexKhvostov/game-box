// Private PostgreSQL JSONB repository. All game writes run in real SERIALIZABLE
// transactions; no client document API, permissive RPC, or browser SQL access.
const copy=value=>value === undefined ? undefined : structuredClone(value);
const validPath=path=>{
  if(typeof path!=='string'||path.length>768||!/^([A-Za-z0-9_-]+\/)+[A-Za-z0-9_-]+$/.test(path)) throw Error('Invalid document path');
  return path;
};
class Snapshot {
  constructor(ref,body){this.ref=ref;this.id=ref.id;this.exists=body!==undefined;this.body=copy(body);}
  data(){return copy(this.body);}
}
class Reference {
  constructor(db,path){this.db=db;this.path=validPath(path);this.id=path.split('/').at(-1);}
  collection(name){return new Query(this.db,`${this.path}/${name}`);}
  async get(){return this.db.read(this);}
  async set(body){await this.db.runTransaction(async tx=>{tx.set(this,body);});}
  async update(patch){await this.db.runTransaction(async tx=>{
    const old=await tx.get(this);if(!old.exists)throw Error('Document missing');const body=old.data();
    for(const [key,value]of Object.entries(patch)){
      const pieces=key.split('.');let target=body;
      for(const part of pieces.slice(0,-1)){if(['__proto__','prototype','constructor'].includes(part))throw Error('Invalid field');target=target[part]??={};}
      const end=pieces.at(-1);if(['__proto__','prototype','constructor'].includes(end))throw Error('Invalid field');target[end]=copy(value);
    }tx.set(this,body);
  });}
}
class Query {
  constructor(db,parent,filters=[],orders=[],max=200,cursor=null){Object.assign(this,{db,parent,filters,orders,max,cursor});}
  doc(id){return new Reference(this.db,`${this.parent}/${id}`);}
  where(field,op,value){if(!['==','>=','>','<=','<'].includes(op))throw Error('Unsupported comparison');return new Query(this.db,this.parent,[...this.filters,[field,op,value]],this.orders,this.max,this.cursor);}
  orderBy(field,direction='asc'){if(!['asc','desc'].includes(direction))throw Error('Invalid order');return new Query(this.db,this.parent,this.filters,[...this.orders,[field,direction]],this.max,this.cursor);}
  limit(max){if(!Number.isSafeInteger(max)||max<1||max>500)throw Error('Invalid page limit');return new Query(this.db,this.parent,this.filters,this.orders,max,this.cursor);}
  startAfter(...cursor){return new Query(this.db,this.parent,this.filters,this.orders,this.max,cursor);}
  async get(){return this.db.query(this);}
  count(){return{get:async()=>{const count=await this.db.count(this);return{data:()=>({count})};}};}
}
function buildQuery(query,count=false){
  const args=[query.parent],predicates=['parent=$1'];
  const arg=value=>{args.push(value);return `$${args.length}`;};
  const field=name=>{
    if(name==='__name__')return 'key';
    if(!/^[A-Za-z][A-Za-z0-9_.]*$/.test(name))throw Error('Invalid field');
    return `(body #> ${arg(name.split('.'))}::text[])`;
  };
  for(const [name,op,value]of query.filters)predicates.push(`${field(name)} ${op==='=='?'=':op} ${arg(JSON.stringify(value))}::jsonb`);
  const orders=[...query.orders];if(!orders.some(([name])=>name==='__name__'))orders.push(['__name__',orders.at(-1)?.[1]??'asc']);
  const sorted=orders.map(([name,direction])=>({name,direction,sql:field(name)}));
  for(const item of sorted)if(item.name!=='__name__')predicates.push(`${item.sql} is not null`);
  if(query.cursor){
    let values=query.cursor;
    if(values[0] instanceof Snapshot){const snap=values[0];values=sorted.map(item=>item.name==='__name__'?snap.id:item.name.split('.').reduce((v,k)=>v?.[k],snap.data()));}
    if(values.length!==sorted.length)throw Error('Cursor does not match order');
    const right=values.map((value,i)=>sorted[i].name==='__name__'?arg(value):`${arg(JSON.stringify(value))}::jsonb`);
    predicates.push(`(${sorted.map((item,i)=>`(${sorted.slice(0,i).map((p,j)=>`${p.sql}=${right[j]}`).concat(`${item.sql}${item.direction==='desc'?'<':'>'}${right[i]}`).join(' and ')})`).join(' or ')})`);
  }
  const order=count?'':` order by ${sorted.map(item=>`${item.sql} ${item.direction}`).join(',')} limit ${arg(query.max)}`;
  return {text:`select ${count?'count(*)::integer as count':'path,body'} from untouch.documents where ${predicates.join(' and ')}${order}`,values:args};
}
export class PostgresStore {
  constructor(pool){this.pool=pool;}
  collection(name){if(!/^[A-Za-z_][A-Za-z0-9_-]*$/.test(name))throw Error('Invalid collection');return new Query(this,name);}
  async read(ref,connection=this.pool){const result=await connection.query('select body from untouch.documents where path=$1',[ref.path]);return new Snapshot(ref,result.rows[0]?.body);}
  async getAll(...refs){if(!refs.length)return[];const result=await this.pool.query('select path,body from untouch.documents where path=any($1::text[])',[refs.map(r=>r.path)]);const rows=new Map(result.rows.map(r=>[r.path,r.body]));return refs.map(r=>new Snapshot(r,rows.get(r.path)));}
  async query(query){const sql=buildQuery(query);const result=await this.pool.query(sql.text,sql.values);const docs=result.rows.map(r=>new Snapshot(new Reference(this,r.path),r.body));return{docs,size:docs.length};}
  async count(query){const sql=buildQuery(query,true);const result=await this.pool.query(sql.text,sql.values);return result.rows[0].count;}
  async runTransaction(callback){
    for(let attempt=0;attempt<7;attempt++){
      const connection=await this.pool.connect();let begun=false;
      try{
        await connection.query('begin isolation level serializable');begun=true;
        await connection.query("set local statement_timeout='5000ms'");
        const writes=[];
        const tx={get:ref=>this.read(ref,connection),set:(ref,body)=>writes.push([ref,copy(body)]),delete:ref=>writes.push([ref,null])};
        const result=await callback(tx);
        for(const [ref,body]of writes){
          if(body===null)await connection.query('delete from untouch.documents where path=$1',[ref.path]);
          else await connection.query('insert into untouch.documents(path,parent,key,body) values($1,$2,$3,$4::jsonb) on conflict(path) do update set body=excluded.body,updated_at=now()',
            [ref.path,ref.path.slice(0,ref.path.lastIndexOf('/')),ref.id,JSON.stringify(body)]);
        }
        await connection.query('commit');return result;
      }catch(error){
        if(begun)await connection.query('rollback').catch(()=>{});
        if(!['40001','40P01','23505'].includes(error.code)||attempt===6)throw error;
      }finally{connection.release();}
      await new Promise(resolve=>setTimeout(resolve,10*(attempt+1)));
    }
  }
}
