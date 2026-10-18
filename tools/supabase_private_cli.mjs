// No credentials in argv, plaintext files, source, or logs. Windows named
// pipes carry one short-lived payload to the official, authorized CLI.
import net from 'node:net';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {randomUUID} from 'node:crypto';
const root=path.dirname(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')));
const binary=path.join(root,'supabase/node_modules/@supabase/cli-windows-x64/bin/supabase.exe');
export function privateCli(command,payload){return new Promise((resolve,reject)=>{
  const pipe=`\\\\.\\pipe\\untouch-${randomUUID()}`;
  const server=net.createServer(connection=>{connection.end(payload);});
  const timeout=setTimeout(()=>{server.close();reject(Error('private_cli_timeout'));},30000);
  server.once('error',()=>{clearTimeout(timeout);reject(Error('private_pipe_unavailable'));});
  server.listen(pipe,()=>{
    const child=spawn(binary,[...command,pipe,...(command[0]==='db'?['--linked']:[]),'--project-ref','exinizzxqtjnysgibide','--output-format','json'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let stdout='',stderr='';
    child.stdout.on('data',data=>stdout+=data);child.stderr.on('data',data=>stderr+=data);
    child.once('error',()=>{clearTimeout(timeout);server.close();reject(Error('private_cli_spawn_failed'));});
    child.once('close',code=>{clearTimeout(timeout);server.close();if(code!==0){
      // Callers may keep this sanitized diagnostic, never the original output.
      let diagnostic='command_failed';try{const parsed=JSON.parse((stderr||stdout).trim());diagnostic=parsed.error?.code??diagnostic;}catch{}
      reject(Object.assign(Error('private_cli_failed'),{diagnostic}));return;
    }resolve(stdout);});
  });
});}
if(process.argv.includes('--self-check')){
  try{const result=await privateCli(['db','query','--file'],'select current_user as role;');console.log(JSON.stringify({ok:result.includes('postgres'),transport:'named-pipe'}));}
  catch(error){console.error(JSON.stringify({ok:false,error:error.message,diagnostic:error.diagnostic}));process.exitCode=1;}
}
