"""Offline guards: no FTP/HTTP/Google/real database calls."""
from datetime import datetime, timezone, timedelta
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import deploy_energy_charge_policy as op


class PolicyOperatorTests(unittest.TestCase):
    def test_write_requires_go_before_network_or_credentials(self):
        for mode in ('apply', 'activate'):
            with self.subTest(mode=mode), patch.object(sys, 'argv', ['operator', mode]), \
                 patch.object(op.common, 'connect', side_effect=AssertionError('No network')):
                with self.assertRaisesRegex(RuntimeError, 'Explicit root GO'):
                    op.main()

    def test_expired_baseline_rejected(self):
        for date in (datetime.now(timezone.utc) - timedelta(minutes=31), datetime.now(timezone.utc) + timedelta(minutes=2)):
            with self.assertRaisesRegex(RuntimeError, 'Baseline expired'):
                op.fresh({'createdAtUtc': date.isoformat()})

    def test_exact_seven_file_scope(self):
        with tempfile.TemporaryDirectory(dir=op.ROOT / '.private') as folder:
            path = Path(folder)
            op.common.save(path / 'manifest.json', {'files': []})
            with self.assertRaisesRegex(RuntimeError, 'Exact seven-file'):
                op.package_check(path)

    def test_staging_source_change_rejected_before_stor(self):
        with tempfile.TemporaryDirectory(dir=op.ROOT / '.private') as folder:
            directory = Path(folder)
            source = directory / 'site' / op.ORDER[0]
            source.parent.mkdir(parents=True)
            source.write_bytes(b'changed after accepted package validation')
            class NoWrite:
                def storbinary(self, *args):
                    raise AssertionError('Must reject before STOR')
                def close(self):
                    pass
            with patch.object(op, 'current_guards'), patch.object(op.common, 'connect', return_value=NoWrite()), \
                 patch.object(op.common, 'inventory', return_value={}):
                with self.assertRaisesRegex(RuntimeError, 'immediately before STOR'):
                    op.stage_apply(directory, directory, {'expectedBeforeHashes': {}}, {op.ORDER[0]: op.common.sha(b'approved')})

    def test_partial_stor_cleanup_registered_before_upload(self):
        staged = {}
        class Partial:
            def storbinary(self, command, source):
                staged[command.removeprefix('STOR ')] = source.read(3)
                raise OSError('Fixture partial write')
            def delete(self, name):
                del staged[name]
            def close(self):
                pass
        def inventory(folder):
            return {name.rsplit('/', 1)[1]: {} for name in staged if name.startswith(folder + '/')}
        with tempfile.TemporaryDirectory(dir=op.ROOT / '.private') as folder:
            directory = Path(folder)
            source = directory / 'site' / op.ORDER[0]
            source.parent.mkdir(parents=True)
            source.write_bytes(b'approved')
            with patch.object(op, 'current_guards'), patch.object(op.common, 'connect', return_value=Partial()), \
                 patch.object(op.common, 'inventory', side_effect=inventory):
                with self.assertRaises(OSError):
                    op.stage_apply(directory, directory, {'expectedBeforeHashes': {}}, {op.ORDER[0]: op.common.sha(b'approved')})
            self.assertEqual(staged, {})

    def test_full_baseline_once_before_seven_stages_server_cas_and_source_hash_remain(self):
        staged = {}
        class Ftp:
            def storbinary(self, command, source):
                staged[command.removeprefix('STOR ')] = source.read()
            def delete(self, name):
                del staged[name]
            def close(self):
                pass
        def inventory(folder):
            return {name.rsplit('/', 1)[1]: {} for name in staged if name.startswith(folder + '/')}
        with tempfile.TemporaryDirectory(dir=op.ROOT / '.private') as folder:
            directory = Path(folder)
            expected = {}
            for name in op.ORDER:
                target = directory / 'site' / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(name.encode())
                expected[name] = op.common.sha(name.encode())
            audit = {'createdAtUtc': op.now(), 'expectedBeforeHashes': {}, 'inspection': {'publicationRevision': 'fixture', 'unchangedConfigSha256': 'fixture'}, 'protectedHashes': {}}
            with patch.object(op, 'current_guards') as guards, \
                 patch.object(op.common, 'connect', return_value=Ftp()), \
                 patch.object(op.common, 'inventory', side_effect=inventory), \
                 patch.object(op.common, 'remote', side_effect=lambda name: staged[name]), \
                 patch.object(op, 'protected_call', return_value={'published': expected}) as post:
                op.stage_apply(directory, directory, audit, expected)
                guards.assert_called_once_with(audit, {})
                sent = post.call_args.args[1]
                self.assertEqual(len(sent['staged']), 7)
                self.assertEqual(sent['expectedFiles'], audit['expectedBeforeHashes'])
            self.assertEqual(staged, {})
            source = (op.ROOT / 'tools/energy_charge_policy_live_operator.php').read_text(encoding='utf-8-sig')
            self.assertIn("cp_files($input['expectedFiles']??null)", source)
            self.assertIn('cp_guards($input);cp_require(cp_regular($path)', source)

    def test_operator_partial_stor_also_cleans(self):
        staged = {}
        class Partial:
            def storbinary(self, command, source):
                staged[command.removeprefix('STOR ')] = source.read(7)
                raise OSError('Partial operator')
            def delete(self, name):
                del staged[name]
            def close(self):
                pass
        def inventory(folder):
            return {name.rsplit('/', 1)[1]: {} for name in staged}
        with tempfile.TemporaryDirectory(dir=op.ROOT / '.private') as folder, \
             patch.object(op.common, 'connect', return_value=Partial()), \
             patch.object(op.common, 'inventory', side_effect=inventory):
            with self.assertRaises(OSError):
                op.protected_call(Path(folder), {'action': 'inspect'})
            self.assertEqual(staged, {})

    def test_lost_activation_ack_has_durable_no_retry_receipt_and_cleanup(self):
        staged = {}
        class Ftp:
            def storbinary(self, command, source):
                staged[command.removeprefix('STOR ')] = source.read()
            def delete(self, name):
                del staged[name]
            def close(self):
                pass
        def inventory(folder):
            return {name.rsplit('/', 1)[1]: {} for name in staged}
        with tempfile.TemporaryDirectory(dir=op.ROOT / '.private') as folder:
            directory = Path(folder)
            with patch.object(op.common, 'connect', return_value=Ftp()), \
                 patch.object(op.common, 'remote', side_effect=lambda name: staged[name]), \
                 patch.object(op.common, 'inventory', side_effect=inventory), \
                 patch.object(op.urllib.request, 'urlopen', side_effect=urllib.error.URLError('Fixture lost ACK')):
                with self.assertRaises(urllib.error.URLError):
                    op.protected_call(directory, {'action': 'activate'})
            self.assertTrue((directory / 'request-attempted-activate.json').is_file())
            receipt = op.common.read_json(directory / 'partial-recovery.json')
            self.assertEqual(receipt['configWritten'], 'unknown')
            self.assertEqual(staged, {})

    def test_corrupt_or_missing_file_backup_stops_even_with_valid_db_backup(self):
        with tempfile.TemporaryDirectory(dir=op.ROOT / '.private') as folder:
            directory = Path(folder)
            db = op.common.backup_bytes(directory / 'database-before.dpapi', b'synthetic snapshot')
            op.common.save(directory / 'database-backup-receipt.json', db)
            files = []
            for name in op.ORDER + op.PROTECTED + (op.PUBLISHED,):
                path = directory / 'files' / (name + '.dpapi')
                path.parent.mkdir(parents=True, exist_ok=True)
                files.append({'path': name, **op.common.backup_bytes(path, b'fixture '+name.encode())})
            op.common.save(directory / 'audit.json', {'files': files})
            op.db_validate(directory)
            path.write_bytes(b'corrupt encrypted backup')
            with self.assertRaisesRegex(RuntimeError, 'File backup receipt invalid'):
                op.db_validate(directory)

    def test_php_scope_and_config_exclusion_execute_without_http(self):
        source = (op.ROOT / 'tools/energy_charge_policy_live_operator.php').read_text(encoding='utf-8-sig')
        functions = '\n'.join(re.findall(r'^function cp_(?:paths|without_policy)\([^\n]+', source, re.M))
        runner = functions + ";$c=['economy'=>['androidEnergyV2'=>['chargePolicy'=>['version'=>1],'revision'=>'new','rewards'=>['ad'=>20]]],'game'=>['wallsKillPlayer'=>false]];echo json_encode(['paths'=>array_keys(cp_paths()),'config'=>cp_without_policy($c)]);"
        result = subprocess.run(['C:/xampp/php/php.exe', '-r', runner], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        out = json.loads(result.stdout)
        self.assertEqual(out['paths'], list(op.ORDER))
        self.assertEqual(out['config'], {'economy': {'androidEnergyV2': {'rewards': {'ad': 20}}}, 'game': {'wallsKillPlayer': False}})
        self.assertNotIn('ALTER TABLE', source)
        self.assertNotIn('mobile_play_verify(', source)
        self.assertNotIn('file_put_contents', source)
        self.assertIn('gameplay_publish($candidate,$snapshot[\'revision\'])', source)
        self.assertIn('keep_forward_no_automatic_rollback', source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
