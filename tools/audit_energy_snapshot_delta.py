"""Offline-only two-DPAPI-snapshot energy delta. No host/Google/DB operations."""
import argparse,base64,json
from pathlib import Path
from datetime import datetime,timezone
import android_host_tools as host

def snapshot(folder):
    receipt=host.read_json(folder/'database-backup-receipt.json');encrypted=(folder/'database-before.dpapi').read_bytes()
    host.check(host.sha(encrypted)==receipt['encryptedSha256'] and receipt['dpapiRoundtripVerified'],'Encrypted snapshot mismatch')
    plain=host.crypt(encrypted,True);host.check(host.sha(plain)==receipt['sha256'],'Snapshot plaintext hash mismatch')
    return json.loads(plain)
def rows(snap,name):
    table=next(t for t in snap['tables'] if t['name']==name)
    return [dict(zip(table['columns'],[None if v is None else base64.b64decode(v).decode() for v in row])) for row in table['rowsBase64']]
def obj(value):return json.loads(value or '{}')
def utc(value):return datetime.fromtimestamp(int(value)/1000,timezone.utc).isoformat()
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--before',type=Path,required=True);parser.add_argument('--after',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    host.check(not args.output.exists(),'Do not replace delta evidence');before=snapshot(args.before);after=snapshot(args.after)
    owners={r['player_id'] for r in rows(before,'mobile_purchases') if r['product_id']=='energy_100_v1'};host.check(len(owners)==1,'Ambiguous anchor purchase owner');owner=next(iter(owners))
    bp=next(p for p in rows(before,'mobile_players') if p['id']==owner);ap=next(p for p in rows(after,'mobile_players') if p['id']==owner);bw=obj(bp['wallet_json']);aw=obj(ap['wallet_json'])
    br={r['id']:r for r in rows(before,'mobile_rounds') if r['player_id']==owner};ar={r['id']:r for r in rows(after,'mobile_rounds') if r['player_id']==owner}
    charged=refund=reward=0;changes=[]
    for ident,r in sorted(ar.items(),key=lambda pair:int(pair[1]['started_at'])):
        old=br.get(ident);ctx=obj(r['context_json']);old_result=obj(None if old is None else old['result_json']);new_result=obj(r['result_json'])
        is_new=old is None;cost=int(ctx.get('attemptCost',0)) if ctx.get('energyVersion')==2 else 0
        credit=int(new_result.get('energyReward',0))-int(old_result.get('energyReward',0));cancel=bool(new_result.get('canceled')) and not bool(old_result.get('canceled'))
        charged+=cost if is_new else 0;refund+=cost if cancel else 0;reward+=credit
        if is_new or credit or cancel:
            changes.append(dict(startedAtUtc=utc(r['started_at']),newRound=is_new,cost=cost if is_new else 0,activated=bool(ctx.get('activatedAt')),finished=r['finished_at'] is not None,canceled=bool(new_result.get('canceled')),refund=cost if cancel else 0,energyRewardDelta=credit,helmet=bool(ctx.get('hadHelmet')),jump=bool(ctx.get('hadJump'))))
    bo={r['id']:r for r in rows(before,'mobile_operations') if r['player_id']==owner};ao={r['id']:r for r in rows(after,'mobile_operations') if r['player_id']==owner};new_ops=[r for key,r in ao.items() if key not in bo]
    bbuy={r['token_hash']:r for r in rows(before,'mobile_purchases') if r['player_id']==owner};abuy={r['token_hash']:r for r in rows(after,'mobile_purchases') if r['player_id']==owner};refund_units=0;new_energy_grants=0
    for key,r in abuy.items():
        m=obj(r['token_sealed']);old=bbuy.get(key);om=obj(None if old is None else old['token_sealed'])
        if r['kind']=='energy':
            amount=int(m.get('grantAmount',0));quantity=int(m.get('grantQuantity',0));refunded=int(m.get('refundedQuantity',0))
            if old is None:new_energy_grants+=amount*max(0,quantity-refunded)
            else:refund_units+=amount*max(0,refunded-int(om.get('refundedQuantity',0)))
    known=-charged+refund+reward+new_energy_grants-refund_units;actual=int(aw['energy'])-int(bw['energy'])
    proof=dict(ok=True,readOnly=True,beforeCapturedAtUtc=before['capturedAtUtc'],afterCapturedAtUtc=after['capturedAtUtc'],energyBefore=bw['energy'],energyAfter=aw['energy'],actualEnergyDelta=actual,roundStartCount=sum(1 for r in changes if r['newRound']),roundStartEnergyCharged=charged,roundCancelEnergyRefund=refund,roundEnergyRewards=reward,newPurchaseEnergyGrants=new_energy_grants,purchaseRefundEnergy=refund_units,newWalletOperationCount=len(new_ops),claimedRewardCountBefore=len(bw.get('claimed',[])),claimedRewardCountAfter=len(aw.get('claimed',[])),gamesStartedDelta=int(aw.get('gamesStarted',0))-int(bw.get('gamesStarted',0)),walletVersionDelta=int(ap['wallet_version'])-int(bp['wallet_version']),knownExplainedDelta=known,unexplainedDelta=actual-known,batteryCountBefore=len(bw['batteries']),batteryCountAfter=len(aw['batteries']),purchaseRowsBefore=len(bbuy),purchaseRowsAfter=len(abuy),rounds=changes,deviceCauseNotProven=True)
    args.output.parent.mkdir(parents=True,exist_ok=True);host.save(args.output,proof);print(json.dumps(proof))
if __name__=='__main__':
    try:main()
    except Exception as error:print(json.dumps({'ok':False,'error':'Offline delta audit failed; no private data printed','errorType':type(error).__name__}));raise SystemExit(1)
