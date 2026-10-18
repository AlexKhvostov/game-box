"""Local DPAPI snapshot audit, optionally fixed Google purchase GETs; never mutation."""
import argparse
import base64
import json
from pathlib import Path
import re
import subprocess
import sys
import android_host_tools as host
import setup_play_verifier as setup


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot-directory',type=Path,required=True)
    parser.add_argument('--product-id',required=True)
    parser.add_argument('--google-get',action='store_true')
    parser.add_argument('--current-subscription-only',action='store_true')
    parser.add_argument('--private-config-backup',type=Path,default=host.ROOT/'.private/play-server-activation-20261015-prepare1/private-after.dpapi')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();folder=args.snapshot_directory.resolve()
    host.check(folder.is_relative_to((host.ROOT/'.private').resolve()),'Encrypted snapshot must be private')
    host.check(not args.output.exists(),'Do not overwrite audit proof')
    receipt=host.read_json(folder/'database-backup-receipt.json');encrypted=(folder/'database-before.dpapi').read_bytes()
    host.check(host.sha(encrypted)==receipt['encryptedSha256'] and receipt['dpapiRoundtripVerified'],'Snapshot receipt mismatch')
    plain=host.crypt(encrypted,True);host.check(host.sha(plain)==receipt['sha256'] and len(plain)==receipt['bytes'],'Snapshot plaintext hash mismatch')
    payload={'snapshot':json.loads(plain),'productId':args.product_id,'googleGet':args.google_get,'currentSubscriptionOnly':args.current_subscription_only}
    if args.google_get:
        config=host.crypt(args.private_config_backup.read_bytes(),True)
        matches=re.findall(rb"'play_token_key'\s*=>\s*'([A-Za-z0-9+/=]+)'",config)
        host.check(len(matches)==1 and len(base64.b64decode(matches[0],validate=True))==32,'Private token key unavailable')
        key=setup.DEFAULT_KEY.read_bytes();setup.validate_key(key)
        payload.update(tokenKeyBase64=matches[0].decode(),serviceAccount=json.loads(key))
    result=subprocess.run(['C:/xampp/php/php.exe',str(host.ROOT/'tools/audit_play_purchase_snapshot.php')],input=json.dumps(payload).encode(),capture_output=True)
    host.check(result.returncode==0,'Audit failed; no raw process output disclosed')
    proof=json.loads(result.stdout);host.check(proof.get('ok') and proof.get('readOnly'),'Audit proof rejected')
    args.output.parent.mkdir(parents=True,exist_ok=True);host.save(args.output,proof);print(json.dumps(proof))


if __name__=='__main__':
    try:main()
    except Exception as error:
        print(json.dumps({'ok':False,'error':'Read-only purchase audit stopped; no secrets disclosed','errorType':type(error).__name__}));sys.exit(1)
