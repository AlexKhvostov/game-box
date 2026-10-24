"""Create a bounded, parentless frontend delivery commit without changing HEAD/index.

No push, credentials, backend, project memory or old repository history is included.
"""
from pathlib import Path
import hashlib,json,os,re,subprocess,uuid,sys

ROOT=Path(__file__).resolve().parents[1]
BRANCH='refs/heads/codex/telegram-render'
private=ROOT/'.private/telegram-port/render-delivery'
private.mkdir(parents=True,exist_ok=True)
identifier=uuid.uuid4().hex
env={**os.environ,'GIT_INDEX_FILE':str(private/f'index-{identifier}')}
def git(*args,input=None):
    return subprocess.check_output(['git','-c','core.autocrlf=false',*args],cwd=ROOT,env=env,input=input)

exists=subprocess.run(['git','show-ref','--verify','--quiet',BRANCH],cwd=ROOT).returncode==0
assert not exists or '--update' in sys.argv,'Delivery branch already exists; review before updating'
previous=git('rev-parse',BRANCH).decode().strip() if exists else None
files=[]
for directory in ['src','public']:
    files.extend(p for p in (ROOT/'telegram-app'/directory).rglob('*') if p.is_file())
files.extend(ROOT/'telegram-app'/p for p in ['.gitignore','index.html','package.json','package-lock.json','tsconfig.json','vite.config.ts','RENDER.md','tools/build_render.mjs'])
files=sorted(set(files))
for p in files:
    assert not p.is_symlink() and '.private' not in p.parts and p.suffix not in {'.env','.dpapi','.map','.php'}
    if p.suffix in {'.json','.ts','.vue','.mjs','.js','.html','.md','.css'}:
        text=p.read_text(encoding='utf-8-sig')
        assert not re.search(r'\d{5,15}:[A-Za-z0-9_-]{30,}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----|sb_secret_|ghp_[A-Za-z0-9]{30,}',text),f'Secret-shaped content: {p.name}'
names=[p.relative_to(ROOT).as_posix() for p in files]
git('read-tree','--empty')
git('--literal-pathspecs','add','--pathspec-from-file=-','--pathspec-file-nul',input=('\0'.join(names)+'\0').encode())
tree=git('write-tree').decode().strip()
for p,name in zip(files,names):
    blob=git('show',f'{tree}:{name}')
    assert blob==p.read_bytes(),f'Unexpected source transformation: {name}'
version=json.loads((ROOT/'telegram-app/package.json').read_text())['version']
commit=git('commit-tree',tree,*(['-p',previous] if previous else []),'-m',f'Deploy verified Telegram frontend {version} on Render').decode().strip()
git('update-ref',BRANCH,commit,previous or '0'*40)
receipt={'branch':BRANCH.removeprefix('refs/heads/'),'commit':commit,'parentless':not exists,'parent':previous,'pushed':False,
         'files':len(files),'bytes':sum(p.stat().st_size for p in files),'version':version,
         'entries':[{'path':n,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p,n in zip(files,names)]}
target=private/f'{commit}.json'
target.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in receipt.items() if k!='entries'}))
