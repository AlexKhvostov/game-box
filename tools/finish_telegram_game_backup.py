"""Finish only metadata upload/readback after the full ZIP has already matched."""
from datetime import datetime, timezone
import hashlib,json,pathlib,re,subprocess,urllib.parse,urllib.error,urllib.request

def finish(credentials,root,target):
    target=pathlib.Path(target).resolve();workspace=pathlib.Path(__file__).resolve().parent.parent
    if root!='/' or not target.is_relative_to(workspace/'releases'): raise ValueError('Unexpected backup location')
    manifest=json.loads((target/'manifest.json').read_text(encoding='utf8'))
    if manifest.get('state')!='local-and-FTP-complete' or manifest.get('ftpArchiveVerified') is not True or manifest.get('httpAccessDenied') is not True:
        raise ValueError('Full FTP ZIP SHA proof is required before metadata finalization')
    directory=manifest['remoteDirectory']
    if not re.fullmatch(r'/\.backups/telegram-before-neon-\d{4}-\d{2}-\d{2}_\d{8}_\d{6}_\d{6}',directory): raise ValueError('Unexpected private FTP directory')
    archive_name=manifest['archive']
    if pathlib.PurePosixPath(archive_name).name!=archive_name or manifest['ftpArchive']!=directory+'/'+archive_name: raise ValueError('Unsafe archive path')
    if hashlib.sha256((target/archive_name).read_bytes()).hexdigest()!=manifest['archiveSha256']: raise ValueError('Previously verified ZIP changed')
    def transfer(name,local=None,byte_range=None):
        url='ftp://'+credentials['host']+':'+str(credentials.get('port',21))+urllib.parse.quote(directory+'/'+name)
        config='url = '+json.dumps(url)+'\nuser = '+json.dumps(credentials['user']+':'+credentials['password'])+'\n'
        command=['curl.exe','--config','-','--ssl-reqd','--tls-max','1.2','--disable-epsv','--silent','--show-error','--connect-timeout','20','--max-time','90','--retry','2','--retry-all-errors']
        if local is not None: command+=['--upload-file',str(local)]
        if byte_range: command+=['--range',byte_range]
        result=subprocess.run(command,input=config.encode(),capture_output=True)
        if result.returncode:
            error=result.stderr.decode(errors='replace')
            for value in [credentials['user'],credentials['password']]: error=error.replace(value,'[redacted]') if value else error
            raise RuntimeError('Backup metadata FTPS failed: '+name+': '+error)
        return result.stdout
    for name in ['manifest.json','RESTORE.md']:
        local=target/name;expected=local.read_bytes();size=len(expected)
        transfer(name,local=local)
        actual=b''.join(transfer(name,byte_range=f'{start}-{min(size-1,start+16383)}') for start in range(0,size,16384)) if size>16384 else transfer(name)
        if hashlib.sha256(actual).digest()!=hashlib.sha256(expected).digest(): raise ValueError('Remote backup metadata SHA differs')
    try: urllib.request.urlopen('https://untouch.ballaball.xyz'+manifest['ftpArchive']+'?verify=metadata',timeout=25)
    except urllib.error.HTTPError as error:
        if error.code!=403: raise
    else: raise ValueError('Previously private ZIP became publicly accessible')
    terminal={'updated':datetime.now(timezone.utc).isoformat(),'state':'backup-and-metadata-verified','ftpArchive':manifest['ftpArchive'],'archiveSha256':manifest['archiveSha256'],'fullZipProofFromCompletedTransfer':True,'metadataFTPSVerified':True,'HTTPAccessDenied':True}
    (target/'terminal-verification.json').write_text(json.dumps(terminal,indent=2),encoding='utf8')
    print('Dated game backup and metadata verified:',manifest['ftpArchive'],flush=True)
