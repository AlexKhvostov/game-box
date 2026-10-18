// Local QA only: built admin in a real 390px iframe viewport. Not deployed.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../admin-console/dist');
http.createServer((req,res)=>{
  const url=new URL(req.url,'http://127.0.0.1:4173');
  if(url.pathname==='/__qa'){
    res.setHeader('Content-Type','text/html;charset=utf-8');
    res.end('<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>Untouch — проверка 390px</title><body style="margin:0;background:#dce6df;display:flex;justify-content:center"><iframe id="mobile" title="Админка 390px" src="/?preview=1" width="390" height="844" style="display:block;border:0;flex-shrink:0"></iframe>');return;
  }
  const relative=decodeURIComponent(url.pathname==='/'?'/index.html':url.pathname),file=path.resolve(root,'.'+relative);
  if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',({'.html':'text/html;charset=utf-8','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml'})[path.extname(file)]??'application/octet-stream');
  fs.createReadStream(file).pipe(res);
}).listen(4173,'127.0.0.1',()=>console.log('Responsive QA: http://127.0.0.1:4173/__qa'));
