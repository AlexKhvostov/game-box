"""Synthetic local-only purchase audit fixtures; no keys, PDO or network."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
PHP=ROOT/'tools/audit_play_purchase_snapshot.php'


class PurchaseAuditTests(unittest.TestCase):
    def test_offline_snapshot_amount_unique_and_no_pii(self):
        def table(name,columns,rows,ddl=''):
            return dict(name=name,columns=columns,rowsBase64=[[base64.b64encode(str(cell).encode()).decode() for cell in row] for row in rows],createSql=ddl)
        metadata=json.dumps(dict(grantAmount=100,grantQuantity=1,refundedQuantity=0,energyProductTerms=dict(amount=100)))
        snapshot={'format':'android-energy-db-v1','capturedAtUtc':'fixture','tables':[
            table('mobile_players',['id','nickname','google_sub'],[['42','DO-NOT-PRINT-NAME','DO-NOT-PRINT-SUB']]),
            table('mobile_purchases',['token_hash','player_id','product_id','kind','token_sealed','expires_at'],[['DO-NOT-PRINT-HASH','42','energy_100_v1','energy',metadata,'0']], 'PRIMARY KEY (`token_hash`)')]}
        result=subprocess.run(['C:/xampp/php/php.exe',str(PHP)],input=json.dumps({'snapshot':snapshot,'productId':'energy_100_v1','googleGet':False}).encode(),capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr.decode());proof=json.loads(result.stdout)
        self.assertEqual(proof['reports'][0]['recordedNetGrant'],100);self.assertEqual(proof['reports'][0]['ledgerRowsForToken'],1)
        self.assertTrue(proof['tokenPrimaryKeyPresent']);self.assertTrue(proof['reports'][0]['ledgerOwnerExists'])
        self.assertNotIn('DO-NOT-PRINT',result.stdout.decode());self.assertEqual(proof['googleGetRequests'],0)

    def test_actual_owner_consume_ack_fact_and_mismatched_owner(self):
        script=r'''define('PPA_HELPERS_ONLY',true);require $argv[1];$row=['kind'=>'energy','player_id'=>'42','product_id'=>'energy_100_v1'];$meta=['grantQuantity'=>1];
$data=['obfuscatedExternalAccountId'=>hash('sha256','android:42'),'testPurchaseContext'=>['fopType'=>'TEST'],'acknowledgementState'=>'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED','purchaseStateContext'=>['purchaseState'=>'PURCHASED'],'productLineItem'=>[['productId'=>'energy_100_v1','productOfferDetails'=>['quantity'=>1,'consumptionState'=>'CONSUMPTION_STATE_CONSUMED']]],'orderId'=>'DO-NOT-PRINT-ORDER'];
$good=ppa_google_fact($row,$meta,$data);$data['obfuscatedExternalAccountId']='wrong';$bad=ppa_google_fact($row,$meta,$data);echo json_encode([$good,$bad]);'''
        result=subprocess.run(['C:/xampp/php/php.exe','-r',script,str(PHP)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr);good,bad=json.loads(result.stdout)
        self.assertTrue(good['ownerMatchesLedger']);self.assertFalse(bad['ownerMatchesLedger']);self.assertTrue(good['googleTestPurchase'])
        self.assertEqual(good['consumptionState'],'CONSUMPTION_STATE_CONSUMED');self.assertEqual(good['acknowledgementState'],'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED')
        self.assertNotIn('DO-NOT-PRINT',result.stdout);self.assertNotIn('obfuscatedExternalAccountId',result.stdout)

    def test_source_has_no_payment_or_sql_write_calls(self):
        source=PHP.read_text()
        self.assertIn("mobile_play_http($url,'GET',null,$access)",source)
        for forbidden in ['mobile_play_verify(',':consume',':acknowledge','tg_connect_pdo(','->exec(','->prepare(']:self.assertNotIn(forbidden,source)

    def test_subscription_owner_weekly_ack_and_actual_expiry_fact(self):
        script=r'''define('PPA_HELPERS_ONLY',true);require $argv[1];$row=['kind'=>'energy_subscription','player_id'=>'42','product_id'=>'energy_batteries_5_v1','expires_at'=>'1792076700000'];
$data=['testPurchase'=>[],'externalAccountIdentifiers'=>['obfuscatedExternalAccountId'=>hash('sha256','android:42')],'acknowledgementState'=>'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED','subscriptionState'=>'SUBSCRIPTION_STATE_ACTIVE','lineItems'=>[['productId'=>'energy_batteries_5_v1','expiryTime'=>'2026-10-15T15:05:00Z','offerDetails'=>['basePlanId'=>'weekly']]]];
echo json_encode(ppa_google_fact($row,[],$data));'''
        result=subprocess.run(['C:/xampp/php/php.exe','-r',script,str(PHP)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr);proof=json.loads(result.stdout)
        for name in ['ownerMatchesLedger','weeklyBasePlanMatches','productMatchesLedger','googleTestPurchase']:self.assertTrue(proof[name])
        self.assertEqual(proof['googleExpiresAt'],1792076700000);self.assertTrue(proof['ledgerExpiryMatches'])

    def test_deferred_two_line_pending_and_renewed_are_sanitized(self):
        script=r'''define('PPA_HELPERS_ONLY',true);require $argv[1];$f=json_decode(file_get_contents($argv[2]),true);$results=[];
foreach(['pending','active']as$phase){$d=$f[$phase];$d['externalAccountIdentifiers']['obfuscatedExternalAccountId']=hash('sha256','android:42');$d['linkedPurchaseToken']='DO-NOT-PRINT-RAW-TOKEN';
$d['startTime']=gmdate('c',time()-500);$d['lineItems'][0]['expiryTime']=gmdate('c',time()+($phase==='pending'?100:-10));if($phase==='active')$d['lineItems'][1]['expiryTime']=gmdate('c',time()+300);
$row=['kind'=>'energy_subscription','player_id'=>'42','product_id'=>'energy_batteries_2_v1','expires_at'=>0];$results[]=ppa_google_fact($row,[],$d,['linkedProductId'=>'energy_batteries_5_v1']);}echo json_encode($results);'''
        fixture=ROOT/'test/fixtures/google_play_deferred_replacement.json'
        result=subprocess.run(['C:/xampp/php/php.exe','-r',script,str(PHP),str(fixture)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        pending,active=json.loads(result.stdout)
        for fact,count,phase in [(pending,5,'pending'),(active,2,'active')]:
            self.assertTrue(fact['normalizationAccepted']);self.assertEqual(fact['normalizedBatteryCount'],count)
            self.assertEqual(fact['normalizedLedgerProductId'],'energy_batteries_2_v1');self.assertEqual(fact['normalizedDeferredPhase'],phase)
            self.assertEqual(len(fact['googleLineItems']),2)
        self.assertNotIn('DO-NOT-PRINT',result.stdout)
        self.assertNotIn('linkedPurchaseToken',result.stdout)
        self.assertNotIn('latestSuccessfulOrderId',result.stdout)

    def test_current_only_uses_token_match_without_disclosing_it(self):
        def table(name,columns,rows):
            return dict(name=name,columns=columns,rowsBase64=[[base64.b64encode(str(cell).encode()).decode() for cell in row] for row in rows],createSql='')
        wallet=json.dumps({'energy':1974,'energySubscription':{'tokenHash':'DO-NOT-PRINT-CURRENT','productId':'energy_batteries_5_v1','batteryCount':5,'durationMs':28800000}})
        meta=json.dumps({'energyProductTerms':{'chargeHours':12},'energyPromisedTerms':{'chargeHours':8}})
        rows=[[hash_value,'42','energy_batteries_2_v1','energy_subscription',meta,'0'] for hash_value in ['DO-NOT-PRINT-OLD','DO-NOT-PRINT-CURRENT']]
        snapshot={'format':'android-energy-db-v1','capturedAtUtc':'fixture','tables':[
            table('mobile_players',['id','wallet_json'],[['42',wallet]]),
            table('mobile_purchases',['token_hash','player_id','product_id','kind','token_sealed','expires_at'],rows)]}
        result=subprocess.run(['C:/xampp/php/php.exe',str(PHP)],input=json.dumps({'snapshot':snapshot,'productId':'energy_batteries_2_v1','currentSubscriptionOnly':True}).encode(),capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr.decode());proof=json.loads(result.stdout)
        self.assertEqual(proof['purchaseRows'],1);self.assertTrue(proof['currentSubscriptionOnly'])
        self.assertTrue(proof['reports'][0]['walletSubscriptionTokenMatchesLedger']);self.assertEqual(proof['reports'][0]['baseChargeHours'],12);self.assertEqual(proof['reports'][0]['promisedChargeHours'],8)
        self.assertNotIn('DO-NOT-PRINT',result.stdout.decode())


if __name__=='__main__':unittest.main()
