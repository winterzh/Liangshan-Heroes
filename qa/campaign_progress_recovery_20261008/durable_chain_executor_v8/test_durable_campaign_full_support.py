"""Fault injection for support code only. Never starts Godot or qualifies gameplay."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import durable_campaign_full_runtime as runtime
import durable_campaign_full_evidence as evidence
import durable_campaign_full_matrices as matrices
from prepare_durable_matrix_validators import generate


class SupportFaults(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='lsh_support_')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.profile = self.root / 'profiles/a'
        self.user = self.profile / 'appdata/Godot/app_userdata/test'
        self.user.mkdir(parents=True)
        self.out = self.root / 'steps/a/A_single_save'
        self.out.mkdir(parents=True)
        self.identity = {'content_version': 'c' * 64, 'engine_binary_sha256': 'e' * 64,
                         'rules_sha256': 'r' * 64, 'file_count': 1, 'total_bytes': 3,
                         'provider_sha256': 'p' * 64}
        self.token = 'a' * 32
        scope = self.user / 'continue/v1'
        active = {'schema': 'local_campaign_continue_lifecycle_v2', 'generation': 1, 'token': self.token,
                  'context': evidence.CONTEXT, 'scope': {'owner': '', 'content_version': 'c' * 64,
                  'engine_sha256': 'e' * 64}, 'state': 'active', 'victory': False,
                  'progress_state': 'none', 'intent': {}, 'progress_receipt': {}}
        self.journal = scope / ('local_runs/' + self.token + '/5088120/1/record_0000000001.json')
        self.write_envelope(self.journal, active, 'LH_LOCAL_CONTINUE_LIFECYCLE')
        self.packet = {'generation': 1, 'context': evidence.CONTEXT, 'resume_paused': True,
                       'binding': {'kind': 'uncredited', 'token': self.token,
                                   'receipt_sha256': evidence.sha(self.journal)}, 'world': {'test': 'typed'}}
        self.slot = scope / '5088120/1/record_0000000001.json'
        self.write_envelope(self.slot, self.packet, 'LH_CLASSIC_CONTINUE_SLOT')
        handoff = {'schema': 'daming_safe_retreat_cross_process_handoff_v25', 'mode': 'A_single_save',
                   'pid': 1234, 'nonce': 'b' * 32, 'first_role': 'lu', 'generation': 1,
                   'file_sha256': evidence.sha(self.slot), 'packet': self.packet,
                   'content_version': 'c' * 64, 'engine_sha256': 'e' * 64,
                   'ancestor_pids': [], 'ancestor_nonces': []}
        self.handoff = self.user / 'daming_safe_retreat_v25/handoff_A.json'
        self.write(self.handoff, handoff)
        self.write(self.out / 'saved_packet.json', self.packet)
        self.write(self.out / 'saved_world.json', self.packet['world'])
        self.report_path = self.out / 'report.json'
        self.report = {'schema': 'daming_campaign_durable_cross_process_report_v1', 'case': 'A_single_save',
                       'pid': 1234, 'nonce': 'b' * 32, 'first_role': 'lu', 'passed': True,
                       'checks': [{'label': 'support fixture only', 'passed': True}], 'trusted': self.identity,
                       'teleports': 0, 'fixture_ticks': 0, 'progress_injections': 0, 'clock_acceleration': False,
                       'steam_reward_once_qualified': False, 'single_safe_disk_case_qualified': True,
                       'natural_victory_qualified': False, 'local_terminal_readback_qualified': False,
                       'campaign_persistence_qualified': False, 'actual_user_data_dir': str(self.user),
                       'private_profile': str(self.profile), 'evidence': [evidence.file_pin(self.handoff),
                       evidence.file_pin(self.out / 'saved_packet.json'), evidence.file_pin(self.out / 'saved_world.json')]}
        self.write(self.report_path, self.report)
        self.step = {'process_terminal': True, 'exit_code': 0, 'engine_errors': 0, 'pid': 1234,
                     'nonce': 'b' * 32, 'profile': str(self.profile), 'output': str(self.out.parent)}

    def write(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding='utf-8')

    def write_envelope(self, path, document, magic):
        payload = json.dumps(document)
        self.write(path, {'magic': magic, 'version': '1', 'app': '5088120', 'owner': '1',
                         'revision': '1', 'previous_sha256': '0' * 64, 'payload': payload,
                         'payload_bytes': str(len(payload.encode())),
                         'payload_sha256': hashlib.sha256(payload.encode()).hexdigest()})

    def freeze(self):
        return evidence.freeze_closed_a(self.step, self.report_path, self.identity, 'lu', self.root / 'frozen')

    def test_closed_fixture_copy_has_exact_custody(self):
        frozen = self.freeze()
        dest = self.root / 'other_user'
        dest.mkdir()
        evidence.copy_frozen_a_to_profile(frozen, dest)
        self.assertEqual({v['relative']: v['sha256'] for v in evidence.data_tree(dest / 'continue/v1')},
                         {v['relative']: v['sha256'] for v in frozen['profile_files']})
        self.assertEqual(evidence.sha(dest / 'daming_safe_retreat_v25/handoff_A.json'), evidence.sha(self.handoff))

    def test_malformed_native_claims_refused(self):
        cases = [('pid', True), ('nonce', 'different'), ('passed', 1), ('teleports', False),
                 ('evidence', []), ('private_profile', str(self.root)), ('actual_user_data_dir', str(self.root))]
        for key, value in cases:
            with self.subTest(key=key):
                altered = copy.deepcopy(self.report)
                altered[key] = value
                self.write(self.report_path, altered)
                with self.assertRaises((AssertionError, TypeError)):
                    self.freeze()

    def test_identity_nullable_type_and_check_failure_refused(self):
        for change in ['type', 'check', 'duplicate']:
            with self.subTest(change=change):
                altered = copy.deepcopy(self.report)
                if change == 'type': altered['trusted']['file_count'] = True
                if change == 'check': altered['checks'][0]['passed'] = False
                if change == 'duplicate': altered['evidence'].append(altered['evidence'][0])
                self.write(self.report_path, altered)
                with self.assertRaises(AssertionError): self.freeze()

    def test_pending_or_foreign_scope_refused(self):
        for name in ['5088120/1/receipt.pending', '5088120/1/writing/owner.json',
                     '5088120/1/record_0000000002.json', 'foreign/token.json']:
            with self.subTest(name=name):
                path = self.user / 'continue/v1' / name
                self.write(path, {})
                with self.assertRaises(AssertionError): self.freeze()
                path.unlink()

    def test_empty_pending_or_foreign_directories_refused(self):
        for name in ['5088120/1/writing', '5088120/1/recovering', 'foreign']:
            with self.subTest(name=name):
                path = self.user / 'continue/v1' / name
                path.mkdir()
                with self.assertRaises(AssertionError): self.freeze()
                path.rmdir()

    def test_evidence_drift_during_copy_refused(self):
        original = evidence.shutil.copyfile
        def changing(source, target):
            result = original(source, target)
            self.report_path.write_text('{}', encoding='utf-8')
            return result
        with patch.object(evidence.shutil, 'copyfile', changing):
            with self.assertRaises(AssertionError): self.freeze()

    def test_corrupt_envelope_refused(self):
        value = evidence.read(self.slot)
        value['payload_sha256'] = '0' * 64
        self.write(self.slot, value)
        with self.assertRaises(AssertionError): self.freeze()

    def test_unclosed_process_refused(self):
        self.step['process_terminal'] = False
        with self.assertRaises(AssertionError): self.freeze()

    def test_changed_handoff_source_refused_before_copy(self):
        frozen = self.freeze()
        Path(frozen['a_handoff']['path']).write_text('{}', encoding='utf-8')
        dest = self.root / 'other_user'
        dest.mkdir()
        with self.assertRaises(AssertionError): evidence.copy_frozen_a_to_profile(frozen, dest)

    def test_duplicate_and_escape_rows_refused(self):
        frozen = self.freeze()
        for change in ['duplicate', 'escape']:
            with self.subTest(change=change):
                altered = copy.deepcopy(frozen)
                if change == 'duplicate': altered['profile_files'][1] = altered['profile_files'][0]
                else: altered['profile_files'][0]['relative'] = '../outside.json'
                dest = self.root / change
                dest.mkdir()
                with self.assertRaises(AssertionError): evidence.copy_frozen_a_to_profile(altered, dest)

    def test_stage_factory_exception_releases_only_owned_lease(self):
        batch = runtime.OwnedSerialBatch(self.root, SimpleNamespace(project=self.root), self.root / 'unused.exe', '0' * 64, lambda: None)
        lock = self.root / 'lease'
        def idle():
            lock.write_text(str(self.root), encoding='utf-8')
            batch.locked = True
        def fail(output, nonce):
            raise RuntimeError('injected manifest preparation fault')
        with patch.object(runtime, 'LOCK', lock), patch.object(batch, 'idle', idle), patch.object(runtime.subprocess, 'Popen') as popen:
            with self.assertRaises(RuntimeError): batch.phase('fault', self.profile, [], fail, lambda *args: None)
            popen.assert_not_called()
            self.assertFalse(lock.exists())
            self.assertFalse(batch.locked)

    def test_persist_failure_still_releases_lease(self):
        def fail(): raise OSError('injected receipt write failure')
        batch = runtime.OwnedSerialBatch(self.root, SimpleNamespace(project=self.root), self.root / 'unused.exe', '0' * 64, fail)
        lock = self.root / 'lease'
        def idle():
            lock.write_text(str(self.root), encoding='utf-8')
            batch.locked = True
        with patch.object(runtime, 'LOCK', lock), patch.object(batch, 'idle', idle), patch.object(runtime.subprocess, 'Popen') as popen:
            with self.assertRaises(OSError): batch.phase('fault', self.profile, [], {}, lambda *args: None)
            popen.assert_not_called()
            self.assertFalse(lock.exists())

    def test_actual_pid_set_poll_and_foreign_detection(self):
        class Child:
            pid = 8123
            returncode = 0
            def __init__(self): self.polls = 0
            def poll(self):
                self.polls += 1
                return None if self.polls == 1 else 0
            def wait(self, timeout): return 0
            def kill(self): pass
        batch = runtime.OwnedSerialBatch(self.root, SimpleNamespace(project=self.root), self.root / 'unused.exe', '0' * 64, lambda: None)
        lock = self.root / 'lease'
        def idle():
            lock.write_text(str(self.root), encoding='utf-8')
            batch.locked = True
        def pids(): return {8123} if batch.child else set()
        with patch.object(runtime, 'LOCK', lock), patch.object(batch, 'idle', idle), patch.object(batch, 'integrity', lambda: None), \
             patch.object(runtime, 'engines', pids), patch.object(runtime.subprocess, 'Popen', return_value=Child()), patch.object(runtime.time, 'sleep'):
            result = batch.phase('pid_set', self.profile, [], {}, lambda *args: None)
            self.assertTrue(result['complete'])
            self.assertFalse(lock.exists())

    def test_child_cleanup_wait_fault_keeps_original_failure_and_releases(self):
        class Child:
            pid = 8123
            returncode = None
            killed = False
            def poll(self): return -9 if self.killed else None
            def wait(self, timeout): raise OSError('injected child wait failure')
            def kill(self): self.killed = True
        child = Child()
        batch = runtime.OwnedSerialBatch(self.root, SimpleNamespace(project=self.root), self.root / 'unused.exe', '0' * 64, lambda: None)
        lock = self.root / 'lease'
        def idle():
            lock.write_text(str(self.root), encoding='utf-8')
            batch.locked = True
        def pids(): return {8123, 9000} if batch.child else set()
        with patch.object(runtime, 'LOCK', lock), patch.object(batch, 'idle', idle), patch.object(runtime, 'engines', pids), \
             patch.object(runtime.subprocess, 'Popen', return_value=child):
            with self.assertRaisesRegex(AssertionError, 'Foreign engine'): batch.phase('foreign', self.profile, [], {}, lambda *args: None)
            self.assertTrue(child.killed)
            self.assertFalse(lock.exists())
            self.assertFalse(batch.steps[0]['complete'])
            self.assertIn('Foreign engine', batch.steps[0]['failure'])
            self.assertTrue(batch.steps[0]['cleanup_failures'])

    def test_still_live_child_retains_handle_and_lease(self):
        class Child:
            pid = 8123
            returncode = None
            def poll(self): return None
            def wait(self, timeout): raise OSError('injected unknown child status')
            def kill(self): raise OSError('injected terminate failure')
        child = Child()
        batch = runtime.OwnedSerialBatch(self.root, SimpleNamespace(project=self.root), self.root / 'unused.exe', '0' * 64, lambda: None)
        lock = self.root / 'lease'
        def idle():
            lock.write_text(str(self.root), encoding='utf-8')
            batch.locked = True
        def pids(): return {8123, 9000} if batch.child else set()
        with patch.object(runtime, 'LOCK', lock), patch.object(batch, 'idle', idle), patch.object(runtime, 'engines', pids), \
             patch.object(runtime.subprocess, 'Popen', return_value=child):
            with self.assertRaisesRegex(AssertionError, 'Foreign engine'): batch.phase('foreign', self.profile, [], {}, lambda *args: None)
            self.assertIs(batch.child, child)
            self.assertTrue(lock.exists())
            self.assertFalse(batch.steps[0]['process_terminal'])
            with self.assertRaisesRegex(AssertionError, 'still live'): batch.release()

    def test_acquisition_fsync_fault_releases_created_lease(self):
        batch = runtime.OwnedSerialBatch(self.root, SimpleNamespace(project=self.root), self.root / 'unused.exe', '0' * 64, lambda: None)
        lock = self.root / 'lease'
        tick = [0]
        def clock():
            tick[0] += 31
            return tick[0]
        batch.deadline = 10000
        with patch.object(runtime, 'LOCK', lock), patch.object(runtime, 'engines', return_value=set()), patch.object(batch, 'integrity', lambda: None), \
             patch.object(runtime.time, 'monotonic', clock), patch.object(runtime.time, 'sleep'), patch.object(runtime.os, 'fsync', side_effect=OSError('injected fsync failure')):
            with self.assertRaisesRegex(OSError, 'fsync'): batch.phase('fsync', self.profile, [], {}, lambda *args: None)
            self.assertFalse(lock.exists())

    def test_ansi_engine_error_count(self):
        path = self.root / 'ansi.log'
        path.write_text('\x1b[31mERROR: failure\x1b[0m\n\x1b[33mSCRIPT ERROR: failure\x1b[0m\n', encoding='utf-8')
        self.assertEqual(runtime.error_count(path), 2)


class MatrixPredicateFaults(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[1]
        old = root / 'qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25'
        self.interface = evidence.read(old / 'NEGATIVE_WORLD_INTERFACE_V25B2.json')
        self.interface['report_schema'] = 'daming_campaign_world_negative_report_v1'
        self.report = {'schema': self.interface['report_schema'], 'pure_matrix_passed': True, 'fixture_ready': True,
                       'matrix_complete': True, 'whole_world_dto_negative_only': True}
        for key in ['overall_v25_qualified', 'live_object_capture_negative_implemented', 'live_object_capture_negative_qualified',
                    'separate_component_harness_implemented', 'future_producer_integration_qualified']: self.report[key] = False
        for key in ['disk_slot_writes', 'direct_gameplay_calls', 'cached_grids_cleared']: self.report[key] = 0
        self.report['executed_rows'] = [{**v, 'passed': True, 'actual_code': v['expected_code'],
                                        'source_input_type_ieee_exact': True, 'cached_grids_preserved': True,
                                        'mutated_packet_sha256': 'a' * 64, 'typed_document_sha256': 'b' * 64}
                                       for v in self.interface['route_expectations']]
        self.report['positives'] = [{'route': route, 'actual_A_unmodified': True, 'prepared': True,
                                    'detached_inert': True, 'input_exact': True} for route in ['source', 'json']]

    def test_generated_predicates_reproduce_immutable_source(self):
        path = Path(__file__).with_name('durable_campaign_full_matrices.py')
        self.assertEqual(path.read_text(encoding='utf-8-sig'), generate())

    def test_exact_matrix_count_and_duplicate_refused(self):
        matrices.validate_world(self.report, self.interface)
        altered = copy.deepcopy(self.report)
        altered['executed_rows'][-1] = altered['executed_rows'][0]
        with self.assertRaises(RuntimeError): matrices.validate_world(altered, self.interface)
        altered = copy.deepcopy(self.report)
        altered['executed_rows'].pop()
        with self.assertRaises(RuntimeError): matrices.validate_world(altered, self.interface)

    def test_nullable_key_omission_and_bool_integer_alias_refused(self):
        row = next(v for v in self.interface['route_expectations'] if any(value is None for value in v.values()))
        field = next(k for k, v in row.items() if v is None)
        altered = copy.deepcopy(self.report)
        target = next(v for v in altered['executed_rows'] if (v['case'], v['route']) == (row['case'], row['route']))
        del target[field]
        with self.assertRaises(RuntimeError): matrices.validate_world(altered, self.interface)
        altered = copy.deepcopy(self.report)
        altered['disk_slot_writes'] = False
        with self.assertRaises(RuntimeError): matrices.validate_world(altered, self.interface)


if __name__ == '__main__':
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    unittest.main(verbosity=2)
