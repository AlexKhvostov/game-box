"""Release artifact verification; reads APKs without installing or running them."""
import argparse,hashlib,json,os,re,struct,subprocess,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--apk',type=Path,required=True);p.add_argument('--baseline',type=Path,required=True)
p.add_argument('--version-code',type=int,required=True)
p.add_argument('--sdk',type=Path,default=Path(os.environ['LOCALAPPDATA'])/'Android/Sdk')
p.add_argument('--java',type=Path,default=Path('C:/Program Files/Android/Android Studio/jbr/bin/java.exe'))
args=p.parse_args();build=args.sdk/'build-tools/36.0.0'
def command(*a):return subprocess.check_output(list(map(str,a)),stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace')
def certificate(apk):
    output=command(args.java,'-jar',build/'lib/apksigner.jar','verify','--verbose','--print-certs',apk)
    assert 'Verified using v2 scheme (APK Signature Scheme v2): true'in output
    return re.search(r'Signer #1 certificate SHA-256 digest: ([a-f0-9]+)',output).group(1)
badging=command(build/'aapt2.exe','dump','badging',args.apk)
assert "package: name='com.best4u.untouch'"in badging
assert int(re.search(r"versionCode='(\d+)'",badging).group(1))==args.version_code
assert int(re.search(r"(?:minS|s)dkVersion:'(\d+)'",badging).group(1))==24
assert int(re.search(r"targetSdkVersion:'(\d+)'",badging).group(1))>=36
assert not any(permission in badging for permission in ['com.google.android.gms.permission.AD_ID','android.permission.RECORD_AUDIO','android.permission.CAMERA','android.permission.ACCESS_FINE_LOCATION'])
digest=certificate(args.apk);assert digest==certificate(args.baseline),'Signing certificate changed'
command(build/'zipalign.exe','-c','-P','16','4',args.apk)
with zipfile.ZipFile(args.apk)as z,zipfile.ZipFile(args.baseline)as old:
    assert z.testzip()is None
    native64=0
    for name in z.namelist():
        if not name.startswith('lib/')or not name.endswith('.so'):continue
        data=z.read(name);assert data[:4]==b'\x7fELF'
        if data[4]!=2:continue
        endian='<'if data[5]==1 else '>';offset=struct.unpack_from(endian+'Q',data,32)[0]
        size,count=struct.unpack_from(endian+'HH',data,54)
        loads=[struct.unpack_from(endian+'Q',data,offset+i*size+48)[0]for i in range(count)if struct.unpack_from(endian+'I',data,offset+i*size)[0]==1]
        assert loads and min(loads)>=16384,(name,loads);native64+=1
    def oauth(archive):return set(re.findall(rb'[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com',archive.read('lib/arm64-v8a/libapp.so')))
    assert len(oauth(z))==1 and oauth(z)==oauth(old),'OAuth configuration changed'
print(json.dumps({'apk':str(args.apk),'versionCode':args.version_code,'sha256':hashlib.sha256(args.apk.read_bytes()).hexdigest(),'bytes':args.apk.stat().st_size,'signatureV2':True,'sameReleaseCertificateAs172':True,'zipCrc':True,'zipAlignment16KiB':True,'native64LibrariesVerified':native64,'oauthPreserved':True,'installed':False}))
