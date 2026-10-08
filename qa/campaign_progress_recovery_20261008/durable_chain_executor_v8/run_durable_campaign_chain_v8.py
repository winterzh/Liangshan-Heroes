"""Fresh normal durable ABCD and exact 52 refusal stages. Other acceptance remains separate."""
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import uuid

from durable_campaign_full_runtime import FrozenProject, OwnedSerialBatch, inventory, no_links, read, sha, write_new
from durable_campaign_full_evidence_v2 import copy_frozen_a_to_profile, data_tree, envelope, file_pin, freeze_closed_a, native_report, resolve_evidence_path
from durable_campaign_full_matrices import CASES, require, validate_capture, validate_component, validate_hold, validate_world, validate_case_labels
import run_steam_integration_qa as native

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
OLD = ROOT / 'qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25'
IDENTITY_HELPER = ROOT / 'qa/zhu_wounded_20261005/harness/run_daming_admit_v24s.py'
IDENTITY_SHA = '049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626'
SCHEMAS = {'world': 'daming_campaign_world_negative', 'component': 'daming_campaign_component', 'capture': 'daming_campaign_capture'}
SCENES = {k: 'res://tools/daming_campaign_' + k + '_negative_v1.tscn' for k in SCHEMAS}
SCENES['component'] = 'res://tools/daming_campaign_component_negative_v1.tscn'
SCENES['capture'] = 'res://tools/daming_campaign_capture_negative_v1.tscn'
INTERFACES = {'world': OLD / 'NEGATIVE_WORLD_INTERFACE_V25B2.json',
              'component': OLD / 'COMPONENT_NEGATIVE_INTERFACE_V25.json',
              'capture': OLD / 'CAPTURE_NEGATIVE_INTERFACE_V25D1.json'}
FULL_GD = 'tools/daming_campaign_durable_cross_process_v1.gd'
FULL_SCENE = 'res://tools/daming_campaign_durable_cross_process_v1.tscn'
WORLD_SOURCES = ['res://scripts/' + v for v in ['run_battle_world_core.gd', 'run_level8_unit_contract.gd', 'run_slot_store.gd',
    'run_snapshot_store.gd', 'run_unit_graph.gd', 'run_unit_state.gd', 'run_graph_identity.gd', 'run_battle_root_state.gd',
    'run_campaign_level_state.gd', 'run_campaign_mission_state.gd', 'run_campaign_presentation_state.gd',
    'run_cast_flow_state.gd', 'run_item_cast_flow_state.gd', 'run_state_value_codec.gd']]


def canonical(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def verify_pin(row):
    require(type(row) is dict and type(row['bytes']) is int and row['bytes'] >= 0, 'Typed file pin required')
    path = Path(row['path'])
    no_links(path)
    require(path.is_file() and path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], 'Pinned source drift: ' + str(path))


def component_sources(project):
    text = (project / 'tools/daming_campaign_component_negative_v1.gd').read_text(encoding='utf-8-sig')
    names = json.loads(re.search(r'const SOURCE_PATHS := (\[.*?\])', text).group(1))
    require(len(names) == len(set(names)) == 32 and all(v.startswith('res://scripts/') and '..' not in v for v in names), 'Exact32 component source paths')
    return names


def source_spec(args):
    source_path = QA / 'DURABLE_FULL_SOURCE_INPUTS_V6.json'
    source = read(source_path)
    require(canonical(source['spec']) == source['source_inputs_sha256'], 'Input seal logical SHA drift')
    inputs = source['spec']
    route_review_path = ROOT / 'qa/office_campaign_route_20261008/v34/ROUTE_V34_GROUND_INDEPENDENT_REVIEW.json'
    route_review = read(route_review_path)
    route_row = next(v for v in inputs['runtime_and_harness_overlays'] if v['runtime_path'] == 'tools/daming_safe_retreat_route_v26.gd')
    require(inputs['schema'] == 'daming_durable_full_source_inputs_v6' and route_review['independent'] is True
            and route_review['static_api_closure_passed'] is True and route_review['approved_stages'] == []
            and route_review['route_sha256'] == route_row['sha256'], 'New exact v34 ground-route source review')
    consumer_review_path = QA / 'final_durable_retreat_consumer_v1_r3/CONSUMER_HANDOFF_DIRECTORY_INDEPENDENT_REVIEW_V3.json'
    consumer_review = read(consumer_review_path)
    consumer_row = next(v for v in inputs['runtime_and_harness_overlays'] if v['runtime_path'] == FULL_GD)
    require(consumer_review['independent'] is True and consumer_review['static_api_closure_passed'] is True
            and consumer_review['negative_adapters_compatibility_passed'] is True and consumer_review['approved_stages'] == []
            and consumer_review['consumer_sha256'] == consumer_row['sha256'], 'Exact fixed-directory consumer and inherited negative source review')
    component_root = QA / 'final_durable_component_transport_v1_r5'
    component_review_path = component_root / 'COMPONENT_MEMBERSHIP_TRANSPORT_PRELIMINARY_REVIEW_R5.json'
    component_review = read(component_review_path)
    component_row = next(v for v in inputs['runtime_and_harness_overlays'] if v['runtime_path'] == 'tools/daming_campaign_component_negative_v1.gd')
    require(component_review['independent'] is True and component_review['static_api_closure_passed'] is True
            and component_review['approved_stages'] == [] and component_review['component_sha256'] == component_row['sha256'],
            'Exact per-record membership transport static review')
    require(inputs['execution_contract']['roles'] == ['lu', 'shi'] and inputs['execution_contract']['negative_process_stages'] == 52,
            'Exact retained role/matrix contract required')
    bridge = read(inputs['base_bridge']['path'])
    verify_pin(inputs['base_bridge'])
    require(bridge['complete'] is True and bridge['candidate_identity'] == inputs['base_identity'], 'Complete base bridge')
    for row in inputs['base_identity']['files']:
        verify_pin({**row, 'path': str(Path(bridge['candidate_root']) / row['path'])})
    for row in inputs['runtime_and_harness_overlays'] + inputs['metadata_and_predecessor_reviews'] + inputs['actual_semantic_Core_Contract']:
        verify_pin(row)
    review_paths = [QA / 'DURABLE_FULL_INPUTS_PREPARATION_REVIEW_V3.json',
                   QA / 'final_durable_negative_adapters_v1_r4/DURABLE_NEGATIVE_ADAPTERS_PRELIMINARY_REVIEW_V4.json']
    input_review, adapter_review = [read(p) for p in review_paths]
    require(input_review['independent'] is True and input_review['static_input_closure_passed'] is True
            and adapter_review['independent'] is True and adapter_review['static_api_closure_passed'] is True, 'Current static input/adapter reviews')
    helpers = [Path(__file__), ROOT / 'tools/durable_campaign_full_runtime.py', ROOT / 'tools/durable_campaign_full_evidence_v2.py',
               ROOT / 'tools/durable_campaign_full_matrices.py', ROOT / 'tools/prepare_durable_matrix_validators.py',
               ROOT / 'tools/test_durable_campaign_full_support.py', ROOT / 'tools/run_steam_integration_qa.py',
               ROOT / 'tools/run_workstation_baseline.py', IDENTITY_HELPER, *INTERFACES.values(), *review_paths, source_path, args.baseline]
    helpers += [OLD / 'run_daming_safe_retreat_v25s_r2b2_full.py', OLD / 'run_daming_safe_retreat_v25s.py', ROOT / 'tools/test_durable_campaign_chain_v2.py']
    helpers += [ROOT / 'tools/prepare_durable_campaign_full_inputs_v5.py', route_review_path,
                ROOT / 'qa/office_campaign_route_20261008/v34/SOURCE.json']
    helpers += [consumer_review_path, QA / 'final_durable_retreat_consumer_v1_r3/SOURCE.json']
    helpers += [ROOT / 'tools/test_durable_campaign_evidence_v2.py']
    # Legacy helper is imported only by host tests and source preparation.
    helpers += [ROOT / 'tools/durable_campaign_full_evidence.py']
    # Legacy producer supplies only the fixed CFG acknowledgement host test API.
    helpers += [ROOT / 'tools/run_durable_campaign_chain_v2.py']
    helpers += [ROOT / 'tools/prepare_durable_campaign_full_inputs_v6.py', component_review_path, component_root / 'SOURCE.json']
    require(sha(IDENTITY_HELPER) == IDENTITY_SHA, 'Fixed complete identity helper')
    baseline = read(args.baseline)
    require(baseline['complete'] is True and baseline['source_drift'] == [] and baseline['engine_sha256'] == sha(args.godot), 'Actual workstation baseline and engine required')
    require(native.native_dependencies() == baseline['native_dependencies'], 'Native vendor closure differs from actual baseline')
    for row in baseline['source_files']: verify_pin({**row, 'path': str(ROOT / row['path'])})
    version = baseline['startup_report']['engine']
    require([version[k] for k in ['major', 'minor', 'patch']] == [4, 6, 3] and version['status'] == 'stable', 'Actual stable4.6.3 baseline')
    interfaces = {kind: read(path) for kind, path in INTERFACES.items()}
    require(len(interfaces['world']['route_expectations']) == 264 and len(interfaces['component']['required_route_rows']) == 362
            and len(interfaces['capture']['required_cases']) == 24, 'Exact264/362/24 old predicates required')
    pins = [file_pin(p) for p in helpers]
    for name, manifest in baseline['native_dependencies'].items():
        pins += [file_pin(ROOT / 'vendor' / name / row['path']) for row in manifest['files']]
        pins.append(file_pin(ROOT / 'vendor' / name / 'provenance.json'))
    return {'schema': 'daming_durable_chain_source_spec_v8', 'inputs': inputs, 'input_file': file_pin(source_path), 'pins': pins,
            'engine': file_pin(args.godot), 'native_dependencies': baseline['native_dependencies'],
            'execution_scope': 'durable_chain_and_matrices', 'ABCD_processes': 8, 'negative_process_stages': 52,
            'original19_faults_included': False, 'admission_JSON_OwnedSlot_included': False,
            'public_continue_SDK_devices_performance_qualified': False, 'overall_goal_qualified': False}


def validate_cfg_ack(user, row, ack):
    require(type(row) is dict and set(row) == {'relative_user_path', 'bytes', 'sha256'}
            and type(row['relative_user_path']) is str and row['relative_user_path'] == 'campaign.cfg'
            and type(row['bytes']) is int and row['bytes'] >= 0 and type(row['sha256']) is str
            and re.fullmatch('[0-9a-f]{64}', row['sha256']), 'Exact fixed owned Campaign CFG row')
    user = Path(user)
    no_links(user)
    cfg = user / 'campaign.cfg'
    no_links(cfg)
    require(cfg.resolve().parent == user.resolve(), 'Fixed owned Campaign CFG boundary')
    verify_pin({'path': str(cfg), 'bytes': row['bytes'], 'sha256': row['sha256']})
    require(type(ack) is dict and set(ack) == {'schema', 'code', 'persisted', 'suppressed', 'file_sha256'}
            and type(ack['schema']) is str and ack['schema'] == 'campaign_progress_ack_v1'
            and type(ack['code']) is str and ack['code'] == 'CAMPAIGN_CFG_READBACK_VERIFIED'
            and ack['persisted'] is True and ack['suppressed'] is False
            and type(ack['file_sha256']) is str and ack['file_sha256'] == sha(cfg), 'Exact typed actual CFG generation3 acknowledgement')
    return cfg


def identity_module():
    require(sha(IDENTITY_HELPER) == IDENTITY_SHA, 'Identity helper drift before import')
    spec = importlib.util.spec_from_file_location('durable_chain_fixed_identity', IDENTITY_HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Chain:
    def __init__(self, args, spec, review):
        self.args, self.spec = args, spec
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private work directory outside checkout')
        args.work_root.mkdir(parents=True, exist_ok=True)
        self.run = args.work_root / ('durable_chain_' + uuid.uuid4().hex[:8])
        self.run.mkdir(exist_ok=False)
        self.receipt = {'schema': 'daming_durable_chain_batch_v8', 'run': str(self.run), 'source_spec': spec,
                        'source_spec_file': file_pin(args.source_spec),
                        'source_spec_sha256': canonical(spec), 'independent_review': file_pin(review), 'complete': False,
                        'durable_chain_and_matrices_qualified': False, 'overall_goal_qualified': False,
                        'original19_faults_qualified': False, 'admission_JSON_OwnedSlot_qualified': False,
                        'SDK_reward_once_qualified': False, 'public_continue_qualified': False, 'roles': {}, 'negative_reports': {}}
        self.frozen = FrozenProject(self.run / 'project', spec['inputs'])
        self.batch = OwnedSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist)
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity
        self.fields = None
        self.evidence_pins = {}
        self.persist()

    def persist(self):
        self.receipt['steps'] = self.batch.steps if hasattr(self, 'batch') else []
        path = self.run / 'checkpoint.json'
        no_links(path)
        path.write_text(json.dumps(self.receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    def integrity(self):
        for row in self.spec['pins'] + [self.spec['engine'], self.receipt['independent_review'], self.receipt['source_spec_file']]: verify_pin(row)
        require(native.native_dependencies() == self.spec['native_dependencies'], 'Native vendor drift')
        self.original_integrity()
        if self.fields is not None:
            verify_pin(self.post_cold_pin)
            actual = self.identity.installed_identity(self.frozen.project)
            require(actual == self.receipt['post_cold_runtime_identity'], 'Complete canonical runtime identity drift')

    def prepare(self):
        self.frozen.prepare()
        require(native.install_native(self.frozen.project) == self.spec['native_dependencies'], 'Native installation closure')
        self.frozen.before = inventory(self.frozen.project)
        self.identity = identity_module()
        profile = self.batch.profile('cold_import')
        self.batch.phase('cold_import', profile, ['--headless', '--editor', '--import'], {}, lambda *args: None, 1200)
        self.frozen.freeze_cold()
        installed = self.identity.installed_identity(self.frozen.project)
        self.fields = {k: installed[k] for k in ['content_version', 'rules_sha256', 'file_count', 'total_bytes']}
        self.fields.update(engine_binary_sha256=self.spec['engine']['sha256'], provider_sha256=sha(self.frozen.project / 'scripts/run_content_identity.gd'))
        self.receipt['post_cold_runtime_identity'] = installed
        self.receipt['post_cold_installed_files'] = self.frozen.cold
        write_new(self.run / 'post_cold_identity.json', self.fields)
        self.post_cold_pin = file_pin(self.run / 'post_cold_identity.json')
        self.component_paths = component_sources(self.frozen.project)
        self.interfaces = {kind: read(path) for kind, path in INTERFACES.items()}
        for kind, interface in self.interfaces.items():
            interface['report_schema'] = SCHEMAS[kind] + '_report_v1'
            interface['manifest_schema'] = SCHEMAS[kind] + '_inputs_v1'
        self.persist()

    def evidence(self, report, step):
        for row in report.get('evidence', []):
            resolved = resolve_evidence_path(row['path'], report['actual_user_data_dir'])
            pin = {'path': str(resolved), 'sha256': row['sha256'], 'bytes': resolved.stat().st_size}
            verify_pin(pin)
            path = resolved.resolve()
            require(path.is_relative_to(Path(step['output']).resolve()) or path.is_relative_to(Path(report['actual_user_data_dir']).resolve()), 'Evidence custody outside current output/user')
            self.remember(pin)

    def remember(self, row):
        key = row['path']
        require(key not in self.evidence_pins or self.evidence_pins[key] == row, 'Evidence pin rebaseline refused')
        verify_pin(row)
        self.evidence_pins[key] = row

    def validate_chain(self, role, case, step, output, nonce):
        path = output / case / 'report.json'
        report = native_report(step, path, 'daming_campaign_durable_cross_process_report_v1', case, self.fields, role)
        require('DAMING_RETREAT_V25_COMPLETE ' + case in (output / 'native.log').read_text(encoding='utf-8', errors='replace'), 'Actual chain terminal log marker')
        validate_hold(report, case)
        validate_case_labels(report, case)
        self.evidence(report, step)
        index = CASES.index(case)
        prior = self.receipt['roles'][role].get(CASES[index - 1]) if index else None
        require(report['previous_pid'] == (prior['pid'] if prior else 0) and report['previous_nonce'] == (prior['nonce'] if prior else ''), 'Exact preceding actual process chain')
        require(report['campaign_persistence_qualified'] is (index >= 2) and report['natural_victory_qualified'] is (index == 2)
                and report['local_terminal_readback_qualified'] is (index == 3) and report['single_safe_disk_case_qualified'] is (index < 2), 'Durable case eligibility')
        require(report['public_campaign_continue_qualified'] is False and report['callback_invocation_count_qualified'] is False, 'No unrelated qualification')
        if index in [1, 3]: require(type(report['orders']) is int and report['orders'] == 0, 'Data/settle stage issued route commands')
        user = Path(report['actual_user_data_dir'])
        scope = user / 'continue/v1/5088120/1'
        first = envelope(scope / 'record_0000000001.json', 'LH_CLASSIC_CONTINUE_SLOT', 1, '0' * 64)
        slot = first if index == 0 else envelope(scope / 'record_0000000002.json', 'LH_CLASSIC_CONTINUE_SLOT', 2, first['sha256'])
        require(slot['document']['context'] == {'mode': 'campaign', 'level_id': 'level8', 'waves': 0} and slot['document']['resume_paused'] is True, 'Actual full campaign packet context')
        if index < 2:
            hand = read(user / ('daming_safe_retreat_v25/handoff_' + ('A' if index == 0 else 'B') + '.json'))
            require(hand['pid'] == step['pid'] and hand['nonce'] == nonce and hand['mode'] == case and hand['first_role'] == role
                    and hand['file_sha256'] == slot['sha256'] and hand['packet'] == slot['document'], 'Actual complete save handoff')
        else:
            hand = read(user / 'daming_safe_retreat_v25/terminal_C.json')
            require(hand['schema'] == 'daming_campaign_durable_terminal_handoff_v1' and hand['campaign_persistence_qualified'] is True,
                    'Actual new durable terminal handoff')
            require(hand['pid'] == (step['pid'] if index == 2 else prior['pid']) and hand['nonce'] == (nonce if index == 2 else prior['nonce']), 'C/D actual handoff custody')
            require(hand['slot_file_sha256'] == slot['sha256'] and hand['slot_generation'] == 2 and hand['slot_binding'] == slot['document']['binding'], 'Terminal retains actual generation2 slot')
            token = slot['document']['binding']['token']
            journal = user / ('continue/v1/local_runs/' + token + '/5088120/1')
            records = []
            previous = '0' * 64
            for generation in [1, 2, 3]:
                row = envelope(journal / ('record_%010d.json' % generation), 'LH_LOCAL_CONTINUE_LIFECYCLE', generation, previous)
                require(row['document']['schema'] == 'local_campaign_continue_lifecycle_v2' and row['document']['token'] == token, 'Exact v2 token/generation chain')
                document = row['document']
                require(set(document) == {'schema', 'generation', 'token', 'context', 'scope', 'state', 'victory', 'progress_state', 'intent', 'progress_receipt'}
                        and document['context'] == {'mode': 'campaign', 'level_id': 'level8', 'waves': 0}
                        and document['scope'] == {'owner': '', 'content_version': self.fields['content_version'], 'engine_sha256': self.fields['engine_binary_sha256']}, 'Complete journal context/owner/source')
                if generation == 1:
                    require(document['state'] == 'active' and document['progress_state'] == 'none' and document['victory'] is False
                            and document['intent'] == {} and document['progress_receipt'] == {}, 'Exact original active receipt')
                if generation == 2: require(document['progress_receipt'] == {}, 'Pending generation must not carry ack')
                if generation > 1:
                    intent = document['intent']
                    require(set(intent) == {'schema', 'token', 'context', 'profile_id', 'owner', 'content_version', 'engine_sha256', 'victory', 'result'}
                            and intent['schema'] == 'campaign_progress_intent_v1' and intent['token'] == token and intent['context'] == document['context']
                            and intent['profile_id'] == 'campaign_level8_v1' and intent['owner'] == '' and intent['victory'] is True
                            and intent['content_version'] == self.fields['content_version'] and intent['engine_sha256'] == self.fields['engine_binary_sha256'], 'Complete fixed terminal intent')
                    result = intent['result']
                    require(set(result) == {'core_cleared', 'story_complete', 'story_done', 'story_total', 'done_ids', 'contract_version'}
                            and result['core_cleared'] is True and type(result['story_complete']) is bool
                            and type(result['story_done']) is int and 0 <= result['story_done'] <= 3 and type(result['story_total']) is int and result['story_total'] == 3
                            and type(result['contract_version']) is int and result['contract_version'] == 2 and type(result['done_ids']) is list
                            and len(result['done_ids']) == len(set(result['done_ids'])) == result['story_done']
                            and all(type(v) is str and v in ['daming_infiltration', 'daming_signal', 'daming_response'] for v in result['done_ids'])
                            and result['story_complete'] is (result['story_done'] == 3), 'Actual fixed Daming mission result')
                self.remember({k: row[k] for k in ['path', 'bytes', 'sha256']})
                records.append(row)
                previous = row['sha256']
            second, third = records[1]['document'], records[2]['document']
            require(second['state'] == third['state'] == 'terminal' and second['progress_state'] == 'pending' and third['progress_state'] == 'applied'
                    and second['victory'] is third['victory'] is True and second['intent'] == third['intent'], 'Same frozen victory intent2→3')
            cfgrow = hand['campaign_file']['file']
            cfg = validate_cfg_ack(user, cfgrow, third['progress_receipt'])
            terminal = hand['terminal']
            require(terminal['token'] == token and type(terminal['revision']) is int and terminal['revision'] == 3
                    and terminal['file_sha256'] == records[2]['sha256'] and terminal['document'] == third, 'Actual terminal third-generation full handoff')
            expected_files = [{'relative_user_path': Path(r['path']).relative_to(user).as_posix(), 'bytes': r['bytes'], 'sha256': r['sha256']} for r in records]
            require(terminal['files'] == expected_files, 'Actual raw journal file chain handoff')
            self.remember(file_pin(cfg))
            labels = {r['label'] for r in report['checks']}
            required = {'actual fresh CFG confirms same frozen campaign intent', 'consumed completion capability refuses repeat',
                        'safe and victory reports each exactly once'} if index == 2 else {
                        'new process reloads confirmed Campaign records', 'restart startup has no replay or completion capability',
                        'actual Session refuses obsolete active slot after durable terminal', 'terminal rejected before any new Battle Unit or graph allocation'}
            require(required <= labels, 'Missing actual CFG/capability/restart coverage')
            self.receipt['roles'][role][case + '_journal'] = [{k: v for k, v in row.items() if k not in ['raw_envelope']} for row in records]
        if index in [0, 2]:
            commands = read(output / case / 'route_commands.json')
            require(type(commands) is list and commands and len(commands) == report['orders'] and all(type(row['attack_move']) is bool and row['ids'] for row in commands), 'Actual normal route commands missing')
        row = {**file_pin(path), 'pid': step['pid'], 'nonce': nonce, 'checks': len(report['checks']), 'slot_sha256': slot['sha256']}
        self.remember(file_pin(path))
        self.remember({k: first[k] for k in ['path', 'bytes', 'sha256']})
        self.remember({k: slot[k] for k in ['path', 'bytes', 'sha256']})
        self.receipt['roles'][role][case] = row
        step['report'] = row
        if index == 0:
            self.actual_a = freeze_closed_a(step, path, self.fields, role, self.run / ('frozen_a_' + role))
            for key in ['a_report', 'a_handoff', 'a_packet', 'a_world', 'a_slot']: self.remember(self.actual_a[key])
            for value in self.actual_a['profile_files']: self.remember({k: value[k] for k in ['path', 'bytes', 'sha256']})

    def matrix(self, role, kind, fixture, case=None):
        label = role + '_' + kind + ('_' + case.lower() if case else '')
        profile = self.batch.profile(label)
        user = profile / 'appdata' / fixture['user_relative_to_appdata']
        if kind != 'world':
            user.mkdir(parents=True, exist_ok=False)
            copy_frozen_a_to_profile(fixture, user)
        manifest = None
        manifest_path = None
        def environment(output, nonce):
            nonlocal manifest, manifest_path
            manifest = {'schema': self.interfaces[kind]['manifest_schema'], 'first_role': role,
                        'content_version': self.fields['content_version'], 'engine_sha256': self.fields['engine_binary_sha256']}
            for field in ['a_report', 'a_handoff', 'a_packet', 'a_world', 'a_slot']: manifest[field] = fixture[field]
            if kind != 'world': manifest['profile_files'] = fixture['profile_files']
            if kind == 'component': manifest['source_pins'] = {p: sha(self.frozen.project / p.removeprefix('res://')) for p in self.component_paths}
            manifest_path = output / 'actual_A_manifest.json'
            write_new(manifest_path, manifest)
            prefix = 'DAMING_' + ('NEGATIVE' if kind == 'world' else kind.upper())
            values = {prefix + '_PROFILE': str(profile), prefix + '_NONCE': nonce,
                      prefix + '_MANIFEST': str(manifest_path), prefix + '_MANIFEST_SHA256': sha(manifest_path),
                      prefix + '_EXPECT_CONTENT': self.fields['content_version'], prefix + '_EXPECT_ENGINE': self.fields['engine_binary_sha256']}
            values[prefix + ('_REPORT' if kind == 'world' else '_OUT')] = str(output / 'report.json' if kind == 'world' else output / kind)
            if case: values[prefix + '_CASE'] = case
            return values
        def validate(step, output, nonce):
            path = output / 'report.json' if kind == 'world' else output / kind / 'report.json'
            report = read(path)
            require(type(report['pid']) is int and report['pid'] == step['pid'] and report['nonce'] == nonce and report['first_role'] == role, 'Actual independent matrix PID/nonce/role')
            require(report['passed'] is True and type(report['checks']) is list and report['checks'] and all(v['passed'] is True for v in report['checks']), 'Actual matrix checks')
            marker = {'world': 'DAMING_SAFE_NEGATIVE_WORLD_V25_COMPLETE ', 'component': 'DAMING_SAFE_COMPONENT_V25_COMPLETE ', 'capture': 'DAMING_SAFE_CAPTURE_V25_COMPLETE ' + (case or '')}[kind]
            require(marker in (output / 'native.log').read_text(encoding='utf-8', errors='replace'), 'Actual matrix terminal log marker')
            require(report['content_version'] == self.fields['content_version'] and report['engine_sha256'] == self.fields['engine_binary_sha256'], 'Actual matrix source/engine')
            actual_user = Path(report['actual_user_data_dir'])
            no_links(actual_user)
            require(actual_user.resolve() == user.resolve(), 'Actual matrix profile data root')
            require(sha(manifest_path) == canonical_raw_manifest[0], 'Matrix manifest drift')
            provenance = {(v['label'], v['sha256']) for v in report['provenance']}
            for field in ['a_report', 'a_handoff', 'a_packet', 'a_world', 'a_slot']:
                verify_pin(manifest[field])
                require((field, manifest[field]['sha256']) in provenance, 'Actual A evidence provenance')
            harness = self.frozen.project / SCENES[kind].removeprefix('res://').replace('.tscn', '.gd')
            require(report['harness_sha256'] == sha(harness), 'Exact installed matrix harness')
            if kind == 'world':
                validate_world(report, self.interfaces[kind])
                expected = {p: sha(self.frozen.project / p.removeprefix('res://')) for p in WORLD_SOURCES}
                require(len(report['source_files']) == 14 and {v['path']: v['sha256'] for v in report['source_files']} == expected, 'Complete world module pins')
            elif kind == 'component':
                validate_component(report, self.interfaces[kind])
                require(report['source_pins'] == manifest['source_pins'], 'Exact32 component source keyset/bytes')
            else:
                validate_capture(report, self.interfaces[kind], fixture, case, self.interfaces[kind]['required_cases'][case])
                require(report['base_harness_sha256'] == sha(self.frozen.project / FULL_GD), 'Exact fixed inherited durable base')
            self.evidence(report, step)
            if kind != 'world':
                require({v['relative']: v['sha256'] for v in data_tree(user / 'continue/v1')} == {v['relative']: v['sha256'] for v in fixture['profile_files']}
                        and sha(user / 'daming_safe_retreat_v25/handoff_A.json') == fixture['a_handoff']['sha256'], 'Original owned A tree changed')
            self.receipt['negative_reports'][label] = {**file_pin(path), 'pid': step['pid'], 'nonce': nonce, 'checks': len(report['checks'])}
            self.remember(file_pin(path))
            self.remember(file_pin(manifest_path))
        canonical_raw_manifest = []
        def sealed_environment(output, nonce):
            values = environment(output, nonce)
            canonical_raw_manifest.append(sha(manifest_path))
            return values
        self.batch.phase(label, profile, ['--headless', SCENES[kind]], sealed_environment, validate, 1200)

    def execute(self):
        self.prepare()
        for role in ['lu', 'shi']:
            self.receipt['roles'][role] = {}
            profile = self.batch.profile(role + '_chain')
            for case in CASES:
                def values(output, nonce, case=case):
                    return {'DAMING_RETREAT_PROFILE': str(profile), 'DAMING_RETREAT_OUT': str(output), 'DAMING_RETREAT_CASE': case,
                            'DAMING_RETREAT_FIRST_ROLE': role, 'DAMING_RETREAT_NONCE': nonce, 'DAMING_RETREAT_QA': '1',
                            'DAMING_RETREAT_EXPECT_CONTENT': self.fields['content_version'], 'DAMING_RETREAT_EXPECT_ENGINE': self.fields['engine_binary_sha256']}
                self.batch.phase(role + '_' + case.lower(), profile, ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
                                 '--resolution', '1280x720', '--position', '30000,30000', FULL_SCENE], values,
                                 lambda step, output, nonce, case=case: self.validate_chain(role, case, step, output, nonce), 1800)
                if case == CASES[0]:
                    fixture = self.actual_a
                    for kind in ['world', 'component']: self.matrix(role, kind, fixture)
                    for capture_case in self.interfaces['capture']['required_cases']: self.matrix(role, 'capture', fixture, capture_case)
        require(len(self.receipt['negative_reports']) == 52 and all(all(c in self.receipt['roles'][role] for c in CASES) for role in ['lu', 'shi']), 'Exact8+52 terminal set')
        self.integrity()
        for row in self.evidence_pins.values(): verify_pin(row)
        for step in self.batch.steps:
            require(sha(Path(step['output']) / 'native.log') == step['log_sha256'], 'Earlier native log drift')
        self.receipt['all_evidence_pins'] = list(self.evidence_pins.values())
        require(len(self.batch.steps) == len(self.batch.pids) == len(self.batch.nonces) == 61 and all(s['complete'] for s in self.batch.steps), '61 distinct completed native processes including cold import')
        self.receipt.update(complete=True, durable_chain_and_matrices_qualified=True)


def main():
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--work-root', type=Path, default=Path('D:/CodexTemp/lsh-durable-chain-20261008'))
    parser.add_argument('--write-spec', type=Path)
    parser.add_argument('--source-spec', type=Path)
    parser.add_argument('--independent-review', type=Path)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    spec = source_spec(args)
    digest = canonical(spec)
    if not args.run:
        if args.write_spec: write_new(args.write_spec, {'source_spec_sha256': digest, 'spec': spec})
        print(json.dumps({'preflight': True, 'source_spec_sha256': digest, 'native_started': False, 'overall_goal_qualified': False}))
        return 0
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None, 'Exact immutable seal and new independent review required')
    saved = read(args.source_spec)
    review = read(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == digest, 'Exact new producer source seal required')
    require(review['schema'] == 'daming_durable_chain_independent_review_v1' and review['independent'] is True
            and review['static_api_closure_passed'] is True and review['approved_stages'] == ['durable_chain_and_matrices']
            and review['producer_sha256'] == sha(Path(__file__)) and review['source_spec_sha256'] == digest
            and review['source_spec_file_sha256'] == sha(args.source_spec), 'Exact limited independent native admission required')
    chain = Chain(args, spec, args.independent_review)
    code = 0
    try:
        chain.execute()
    except BaseException as error:
        code = 1
        chain.receipt.update(complete=False, durable_chain_and_matrices_qualified=False, failure=repr(error))
    finally:
        try:
            chain.batch.release()
        except BaseException as error:
            code = 1
            chain.receipt.update(complete=False, durable_chain_and_matrices_qualified=False)
            chain.receipt.setdefault('finalization_failures', []).append(repr(error))
        chain.receipt['lock_released'] = not chain.batch.locked
        chain.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        chain.persist()
        write_new(chain.run / 'receipt.json', chain.receipt)
        print(json.dumps({'run': str(chain.run), 'complete': chain.receipt['complete'], 'failure': chain.receipt.get('failure'), 'overall_goal_qualified': False}, ensure_ascii=False))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
