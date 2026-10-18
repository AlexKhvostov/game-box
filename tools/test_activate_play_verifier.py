"""Offline activation guards and actual PHP token-helper checks; no keys/network/DB."""
import json
import io
import re
from pathlib import Path
import subprocess
import tempfile
import unittest
import urllib.error
from unittest.mock import patch
import activate_play_verifier as activation


class ActivationTests(unittest.TestCase):
    def test_explicit_gate_before_any_access(self):
        with patch.object(activation.host, 'connect') as connect:
            with self.assertRaises(RuntimeError): activation.apply(Path('unused'), False)
            connect.assert_not_called()

    def test_only_three_private_keys_assigned(self):
        source = (activation.host.ROOT/'tools/play_verifier_activation_operator.php').read_text()
        self.assertEqual(set(re.findall(r"\$candidate\['([^']+)'\]\s*=(?!=)",source)), {'play_service_account_path','play_package','play_token_key'})
        for name in ('play_service_account_path','play_package','play_token_key'):
            self.assertIn("$candidate['"+name+"']", source)
        self.assertIn('$unchangedBefore===$unchangedAfter',source)

    def test_oauth_before_first_config_write(self):
        source = (activation.host.ROOT/'tools/play_verifier_activation_operator.php').read_text()
        self.assertLess(source.index('$access=mobile_play_access($service)'), source.index('pa_write($staging'))
        self.assertIn('[$actual,$actualService,$actualKey]=mobile_play_context()',source)
        self.assertNotIn('mobile_play_verify(',source)

    def test_no_rollback_and_private_staging_protected(self):
        source = (activation.host.ROOT/'tools/play_verifier_activation_operator.php').read_text()
        self.assertIn("$temporary=__DIR__.'/config-data/",source)
        self.assertNotIn('pa_write($paPrivatePath',source)
        self.assertIn("'automaticRollback'=>false",source)
        self.assertIn('pa_backup_candidate($backupPath,$bytes)',source)
        self.assertIn("$staging=__DIR__.'/config-data/",source)
        self.assertIn('opcache_invalidate($paPrivatePath,true)',source)
        self.assertNotIn('dirname($path)',source)

    def test_catalog_proof_strict_booleans_and_status(self):
        skus=['energy_100_v1','energy_250_v1','energy_500_v1','energy_1000_v1','energy_batteries_2_v1','energy_batteries_5_v1']
        catalog={'oauthReady':True,'catalog':[{'productId':sku,'found':True,'httpStatus':200,'weeklyBasePlanFound':True,'weeklyBasePlanActive':True} for sku in skus]}
        self.assertTrue(activation.valid_catalog(catalog))
        for field,values in [('weeklyBasePlanFound',[None,False,0,1,'true']),('weeklyBasePlanActive',[None,False,0,1,'true']),('found',[None,False,0,1,'true']),('httpStatus',[None,201,'200',200.0])]:
            for value in values:
                malformed=json.loads(json.dumps(catalog));malformed['catalog'][-1][field]=value
                self.assertFalse(activation.valid_catalog(malformed),(field,value))
        missing=json.loads(json.dumps(catalog));del missing['catalog'][-1]['weeklyBasePlanActive']
        self.assertFalse(activation.valid_catalog(missing))

    def test_candidate_dpapi_before_expose_and_error_receipt(self):
        source=(activation.host.ROOT/'tools/activate_play_verifier.py').read_text()
        self.assertLess(source.index("host.backup_bytes(folder/'candidate-before-expose.dpapi'"),source.index("result = post({'action':'activate'"))
        self.assertIn("except urllib.error.HTTPError",source)
        self.assertIn("folder/'activation-recovery.json'",source)
        self.assertNotIn('print(raw)',source)

    def test_actual_php_catalog_requires_buy_active_and_p1w(self):
        script=r'''$source=file_get_contents($argv[1]);$start=strpos($source,'function pa_check');$end=strpos($source,'$paWritten=false;');eval(substr($source,$start,$end-$start));
$checks=[];$checks[]=pa_catalog_ready(['purchaseOptions'=>[['state'=>'ACTIVE','buyOption'=>[]]]],false);
$checks[]=!pa_catalog_ready(['purchaseOptions'=>[['state'=>'DRAFT','buyOption'=>[]]]],false);
$checks[]=!pa_catalog_ready(['purchaseOptions'=>[['state'=>'ACTIVE','rentOption'=>[]]]],false);
$plan=['basePlanId'=>'weekly','state'=>'ACTIVE','autoRenewingBasePlanType'=>['billingPeriodDuration'=>'P1W']];$checks[]=pa_catalog_ready(['basePlans'=>[$plan]],true);
$plan['autoRenewingBasePlanType']['billingPeriodDuration']='P1M';$checks[]=!pa_catalog_ready(['basePlans'=>[$plan]],true);
$plan['autoRenewingBasePlanType']['billingPeriodDuration']='P1W';$plan['state']='DRAFT';$checks[]=!pa_catalog_ready(['basePlans'=>[$plan]],true);
echo json_encode($checks);'''
        result=subprocess.run(['C:/xampp/php/php.exe','-r',script,str(activation.host.ROOT/'tools/play_verifier_activation_operator.php')],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr);self.assertTrue(all(json.loads(result.stdout)))

    def test_actual_php_token_preservation_and_generation(self):
        script = r'''$source=file_get_contents($argv[1]);$start=strpos($source,'function pa_check');$end=strpos($source,'$paWritten=false;');eval(substr($source,$start,$end-$start));
$checks=[];$old=base64_encode(str_repeat('A',32));[$same,$created]=pa_token_key($old,null);$checks[]=$same===$old&&!$created;
[$new,$created]=pa_token_key('',0);$checks[]=$created&&strlen(base64_decode($new,true))===32&&$new!==$old;
[$new2]=pa_token_key('',0);$checks[]=$new2!==$new;
foreach([['bad',0],['',1],[null,0],[base64_encode(str_repeat('B',31)),0]] as $case){try{pa_token_key($case[0],$case[1]);$checks[]=false;}catch(Throwable $error){$checks[]=true;}}
$checks[]=pa_outside('/home/private/play/key','/home/site');$root='home'.DIRECTORY_SEPARATOR.'site';$checks[]=!pa_outside($root.DIRECTORY_SEPARATOR.'key',$root);
echo json_encode($checks);'''
        result=subprocess.run(['C:/xampp/php/php.exe','-r',script,str(activation.host.ROOT/'tools/play_verifier_activation_operator.php')],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        checks=json.loads(result.stdout)
        self.assertEqual(len(checks),9)
        self.assertTrue(all(checks),checks)

    def test_prepare_rejects_missing_catalog_before_ftps(self):
        with tempfile.TemporaryDirectory(prefix='play-activation-offline-') as path:
            root=Path(path);out=root/'out';out.mkdir();installed=root/'installed';installed.mkdir()
            (installed/'prepared.json').write_text('{}')
            (installed/'verify_key-1.json').write_text('{"ok":true}')
            with patch.object(activation.host,'remote') as remote:
                with self.assertRaises(RuntimeError):activation.prepare(out,installed)
                remote.assert_not_called()

    def _failure_flow(self,mode='http503'):
        with tempfile.TemporaryDirectory(prefix='activation-503-offline-') as path:
            folder=Path(path);template=(activation.host.ROOT/'tools/play_verifier_activation_operator.php').read_bytes()
            baseline={'files':{name.removeprefix('api/'):activation.host.sha(b'baseline') for name in activation.FILES}}
            (folder/'prepared.json').write_text(json.dumps({'baseline':baseline,'operatorSha256':activation.host.sha(template)}))
            for name in activation.FILES:
                target=folder/'before'/(name+'.dpapi');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b'encrypted')
            state={};events=[]
            class FTP:
                def storbinary(self,command,stream):state[command[5:]]=stream.read()
                def delete(self,name):events.append('cleanup');del state[name]
                def close(self):pass
            def remote(name):return state[name] if name in state else b'baseline'
            def request(req,timeout):
                payload=json.loads(req.data)
                if payload['action']=='stage':
                    events.append('stage')
                    if mode=='lost-stage':raise urllib.error.URLError('lost stage ACK')
                    data={'ok':True,'privateConfigUnchanged':True,'durableCandidateSaved':True,'candidateBase64':'ZmFrZS1jYW5kaWRhdGU=','candidateSha256':activation.host.sha(b'fake-candidate')}
                    return io.BytesIO(json.dumps(data).encode())
                events.append('activate')
                body={'ok':False,'error':'play_activation_guard_failed','configWritten':True,'candidateRetained':True,'automaticRollback':False,'manualReconciliationRequired':True,'candidateBase64':'NEVER-PERSIST-THIS'}
                raise urllib.error.HTTPError('https://invalid.local',503,'safe',{},io.BytesIO(json.dumps(body).encode()))
            def backup(path,data):
                events.append('dpapi-roundtrip')
                if mode=='dpapi-failed':raise RuntimeError('synthetic DPAPI failure')
                return {'dpapiRoundtripVerified':True}
            with patch.object(activation.host,'remote',side_effect=remote),patch.object(activation.host,'crypt',return_value=b'baseline'), \
                 patch.object(activation.host,'connect',return_value=FTP()),patch.object(activation.host,'inventory',side_effect=lambda folder:{name.rsplit('/',1)[1]:{} for name in state}), \
                 patch.object(activation.urllib.request,'urlopen',side_effect=request),patch.object(activation.host,'backup_bytes',side_effect=backup):
                with self.assertRaises((RuntimeError,urllib.error.URLError)):activation.apply(folder,True)
            expected={'http503':['stage','dpapi-roundtrip','activate','cleanup'],'dpapi-failed':['stage','dpapi-roundtrip','cleanup'],'lost-stage':['stage','cleanup']}
            self.assertEqual(events,expected[mode])
            with patch.object(activation.host,'connect') as connect:
                with self.assertRaises(RuntimeError):activation.apply(folder,True)
                connect.assert_not_called()
            self.assertTrue((folder/'activation-attempt.json').exists())
            if mode!='dpapi-failed':
                recovery=json.loads((folder/'activation-recovery.json').read_text())
                if mode=='http503':self.assertTrue(recovery['configWritten']);self.assertFalse(recovery['automaticRollback']);self.assertEqual(recovery['phase'],'activate')
                else:self.assertTrue(recovery['responseLost']);self.assertEqual(recovery['phase'],'stage')
                self.assertNotIn('candidateBase64',recovery);self.assertNotIn('NEVER-PERSIST-THIS',(folder/'activation-recovery.json').read_text())

    def test_http503_retains_recovery_without_secrets_and_cleans_endpoint(self):self._failure_flow()
    def test_dpapi_failure_never_posts_activation(self):self._failure_flow('dpapi-failed')
    def test_lost_stage_ack_blocks_blind_retry_before_network(self):self._failure_flow('lost-stage')


if __name__=='__main__':unittest.main()
