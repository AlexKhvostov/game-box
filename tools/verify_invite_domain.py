"""Read-only HTTPS acceptance of invitation routing; never follows Play redirects."""
import argparse
import hashlib
import json
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None

def verify(home_sha, output):
    checks=[]
    completed=False
    opener=urllib.request.build_opener(NoRedirect)
    def request(path, limit=200000):
        try:
            response=opener.open('https://untouch.fun/'+path,timeout=20)
        except urllib.error.HTTPError as error:
            response=error
        with response:
            return response.code,response.headers,response.read(limit)
    def check(name, condition):
        checks.append({'name':name,'pass':bool(condition)})
        if not condition:
            raise AssertionError(name)
    try:
        status,headers,body=request('')
        check('landing unchanged',status==200 and hashlib.sha256(body).hexdigest()==home_sha)
        expected=json.loads((Path(__file__).resolve().parents[1]/'telegram-web/landing/.well-known/assetlinks.json').read_text())
        status,headers,body=request('.well-known/assetlinks.json')
        check('association HTTPS200 no redirect',status==200 and not headers.get('Location'))
        check('association JSON MIME',headers.get_content_type()=='application/json')
        check('association production package and existing certificates',json.loads(body)==expected)
        for code in ['ABC234','abc234','ABCDEFGH2345','abcdefgh2345']:
            status,headers,_=request('a/'+code)
            target=urllib.parse.urlsplit(headers.get('Location',''))
            query=urllib.parse.parse_qs(target.query)
            check('fixed Play destination '+code,status==302 and target.scheme=='https' and target.netloc=='play.google.com' and target.path=='/store/apps/details')
            check('exact referrer '+code,query=={'id':['com.best4u.untouch'],'referrer':['invite='+code.upper()]})
        for path in ['a/ABCDE','a/ABCDEFG','a/ABCDEFGH234','a/ABCDEFGH23456','a/ABC012','a/ABC234/more']:
            status,headers,_=request(path)
            check('invalid route '+path,status==404 and not headers.get('Location'))
        status,headers,_=request('a/ABC234?url=https%3A%2F%2Fevil.example&referrer=other')
        query=urllib.parse.parse_qs(urllib.parse.urlsplit(headers.get('Location','')).query)
        check('query cannot change target or code',status==302 and headers['Location'].startswith('https://play.google.com/store/apps/details?') and query=={'id':['com.best4u.untouch'],'referrer':['invite=ABC234']})
        status,_,body=request('invite-route-release.json')
        check('route version available',status==200 and json.loads(body)['artifact']=='invitation-route')
        for path in ['privacy/','delete-account/']:
            status,_,_=request(path,512)
            check('legal preserved '+path,status==200)
        completed=True
        return checks
    finally:
        output.parent.mkdir(parents=True,exist_ok=True)
        output.write_text(json.dumps({'ok':completed and all(c['pass'] for c in checks),'passed':sum(c['pass'] for c in checks),'checks':checks,'realPlayInstall':False},ensure_ascii=False,indent=2),encoding='utf8')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home-sha',required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    result=verify(args.home_sha,args.out)
    print(json.dumps({'ok':True,'passed':len(result)}))
