// The PKCE verifier and session use the same storage across the Google redirect.
export function createAuthStorage(local,session){
  const preference='untouch-admin-remember-v1';
  const remembered=()=>local.getItem(preference)==='1';
  return{
    remembered,
    setRemember(value){local.setItem(preference,value?'1':'0');},
    getItem(key){return (remembered()?local:session).getItem(key);},
    setItem(key,value){const target=remembered()?local:session,other=remembered()?session:local;target.setItem(key,value);other.removeItem(key);},
    removeItem(key){local.removeItem(key);session.removeItem(key);}
  };
}
