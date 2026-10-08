"""Prepare or run original JSON533/OwnedSlot76 and normal campaign admission ABC.

Execution requires a new exact independent review and the closed successful
durable batch bound by the current launch receipt. No concurrent native suite.
"""
import argparse
import datetime as dt
import json
from pathlib import Path
import re
import uuid

from run_durable_campaign_chain_v7 import source_spec as durable_spec, canonical, verify_pin, identity_module
from campaign_admission_regression_runtime_v1 import FrozenProject, OwnedSerialBatch, inventory, no_links, read, sha, write_new
from campaign_admission_regression_validators_v1 import LegacyPredicates, CASES
from durable_campaign_full_evidence_v2 import data_tree, data_directories, envelope, file_pin
from durable_campaign_full_matrices import require
import run_steam_integration_qa as native

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
OLD = ROOT / 'qa/zhu_wounded_20261005'
CONSUMER = QA / 'final_executor_candidate_v1_r3'
GD = 'daming_admit_campaign_v2_candidate_v1.gd'
SCENE = 'res://tools/daming_admit_campaign_v2_candidate_v1.tscn'
BOUNDARY_GD = OLD / 'harness/native_ownership_json_boundary_v24q1.gd'
PREPARATION = ROOT / 'qa/office_baseline_20261008/candidate/preparation.json'
LAUNCH = QA / 'ACTUAL_DURABLE_CHAIN_LAUNCH_V7.json'
SCOPE = 'original_JSON_OwnedSlot_and_campaign_admission'


def source_spec(args):
    spec = durable_spec(args)
    inputs = json.loads(json.dumps(spec['inputs']))
    review_path = CONSUMER / 'FINAL_ADMISSION_PRELIMINARY_REVIEW_V3.json'
    review = read(review_path)
    require(review['independent'] is True and review['static_api_closure_passed'] is True
            and review['approved_stages'] == [] and review['consumer_sha256'] == sha(CONSUMER / GD),
            'Exact preliminary admission source review required')
    manifest_path = CONSUMER / 'SOURCE.json'
    manifest = read(manifest_path)
    for row in manifest['files'] + manifest['runtime_sources'] + manifest['actual_semantic_Core_Contract']:
        verify_pin(row)
    require({(r['runtime_path'], r['sha256']) for r in manifest['runtime_sources']} ==
            {(r['runtime_path'], r['sha256']) for r in inputs['runtime_and_harness_overlays'] if r['runtime_path'].startswith('scripts/')},
            'Exact current R12 and Bai runtime combination')
    replacements = {'tools/' + name: CONSUMER / name for name in [GD, Path(SCENE).name]}
    require(set(replacements) <= {r['runtime_path'] for r in inputs['runtime_and_harness_overlays']}, 'Known two predecessor admission paths')
    inputs['runtime_and_harness_overlays'] = [{**file_pin(replacements[r['runtime_path']]), 'runtime_path': r['runtime_path']}
                                             if r['runtime_path'] in replacements else r for r in inputs['runtime_and_harness_overlays']]
    prep = read(PREPARATION)
    require(prep['complete'] is True and len(prep['json_fixture_paths']) == 11, 'Original eleven Windows fixture bridges')
    original_manifest = OLD / 'native_ownership_json_fixtures_v24q.json'
    fixtures = read(original_manifest)
    for key in ['original_payload', 'normalized_payload']:
        fixtures[key]['path'] = prep['json_fixture_paths'][key]
    for row in fixtures['maps']:
        row['path'] = prep['json_fixture_paths'][row['case']]
    fixture_pins = []
    for row in [fixtures['original_payload'], fixtures['normalized_payload'], *fixtures['maps']]:
        actual = file_pin(Path(row['path']))
        require(actual['sha256'] == row['sha256'], 'Exact original fixture SHA')
        fixture_pins.append(actual)
    scene = Path(prep['json_scene']['current_path'])
    require(sha(scene) == prep['json_scene']['sha256'], 'Exact explicit boundary scene')
    for path in [BOUNDARY_GD, scene]:
        runtime_path = 'tools/' + path.name
        require(runtime_path not in {r['runtime_path'] for r in inputs['runtime_and_harness_overlays']}, 'Unique boundary overlay')
        inputs['runtime_and_harness_overlays'].append({**file_pin(path), 'runtime_path': runtime_path})
    owned_scene = ROOT / 'qa/owned_slot_retry_20260909/20260909_034724_209b6af2/source_snapshot/owned_slot_retry_qa.tscn'
    require('res://tools/owned_slot_retry_qa.gd' in owned_scene.read_text(encoding='utf-8-sig'), 'Fixed original OwnedSlot scene binding')
    inputs['runtime_and_harness_overlays'].append({**file_pin(owned_scene), 'runtime_path': 'tools/owned_slot_retry_qa.tscn'})
    owned_tool = ROOT / 'tools/owned_slot_retry_qa.gd'
    require(sha(owned_tool) == '424987ebca5d8204c1b410c5ef12ecc5d460f6ca6bbb5c479ac0de59bf988a5c', 'Byte-exact original OwnedSlot76 tool')
    require('tools/owned_slot_retry_qa.gd' not in {r['runtime_path'] for r in inputs['runtime_and_harness_overlays']}, 'Unique original OwnedSlot overlay')
    inputs['runtime_and_harness_overlays'].append({**file_pin(owned_tool), 'runtime_path': 'tools/owned_slot_retry_qa.gd'})
    inputs['schema'] = 'campaign_admission_regression_inputs_v1'
    inputs['predecessor_execution_contract_reference'] = inputs['execution_contract']
    inputs['execution_contract'] = {'native_processes':6, 'JSON_checks':533, 'OwnedSlot_checks':76,
                                   'admission_cases':list(CASES), 'normal_CAMPAIGN_QA_empty':True,
                                   'pure_QA_labels':['json_boundary','owned_slot_retry'],
                                   'default_slot_root':'user://continue/v1', 'overall_goal_qualified':False}
    launch = read(LAUNCH)
    require(launch['source_spec_sha256'] == '96eaca0f946601e66aa44d171b627b6a9f3355e40c7d4ccba41c7402085e65cc'
            and launch['old_profiles_reused'] is False, 'Fixed preceding durable batch launch')
    helpers = [Path(__file__), ROOT / 'tools/campaign_admission_regression_runtime_v1.py',
               ROOT / 'tools/campaign_admission_regression_validators_v1.py',
               ROOT / 'tools/run_durable_campaign_chain_v7.py', CONSUMER / GD, CONSUMER / Path(SCENE).name,
               manifest_path, review_path, PREPARATION, original_manifest, BOUNDARY_GD, scene, owned_scene, owned_tool, LAUNCH,
               QA / 'DURABLE_CHAIN_SOURCE_SPEC_V7.json', QA / 'DURABLE_CHAIN_INDEPENDENT_REVIEW_V7.json',
               ROOT / 'tools/run_campaign_admission_regressions_v1.py', QA / 'ADMISSION_REGRESSION_SOURCE_SPEC_V1.json',
               QA / 'ADMISSION_REGRESSION_INDEPENDENT_REVIEW_V1.json']
    spec.update(schema='campaign_admission_regression_source_spec_v2', inputs=inputs,
                pins=spec['pins'] + [file_pin(p) for p in helpers] + fixture_pins,
                fixtures=fixtures, fixture_pins=fixture_pins, prior_durable_run=launch['run'],
                execution_scope=SCOPE, ABCD_processes=0, negative_process_stages=0,
                native_processes=6, JSON_checks=533, OwnedSlot_checks=76, admission_cases=list(CASES),
                pure_QA_labels=['json_boundary', 'owned_slot_retry'], admission_CAMPAIGN_QA_enabled=False,
                original19_faults_included=False, admission_JSON_OwnedSlot_included=True,
                durable_basis_source_spec_file=file_pin(QA / 'DURABLE_CHAIN_SOURCE_SPEC_V7.json'), overall_goal_qualified=False)
    unique_pins = {}
    for row in spec['pins']:
        require(row['path'] not in unique_pins or unique_pins[row['path']] == row, 'Conflicting duplicate source pin')
        unique_pins[row['path']] = row
    spec['pins'] = list(unique_pins.values())
    for row in spec['pins']: verify_pin(row)
    return spec


def verify_closed_prior(path, spec):
    original = file_pin(path)
    prior = read(path)
    require(prior['schema'] == 'daming_durable_chain_batch_v7' and Path(prior['run']) == Path(spec['prior_durable_run'])
            and Path(path) == Path(prior['run']) / 'receipt.json', 'Exact prior schema/run/path')
    basis = read(spec['durable_basis_source_spec_file']['path'])
    require(prior['complete'] is True and prior['lock_released'] is True
            and prior['durable_chain_and_matrices_qualified'] is True and prior['overall_goal_qualified'] is False
            and prior['source_spec'] == basis['spec'] and prior['source_spec_sha256'] == basis['source_spec_sha256']
            == canonical(prior['source_spec']), 'Exact successful limited prior source seal')
    full_cases = ['A_single_save','B_install_settle_resave','C_install_finish','D_read_terminal']
    capture_path = next(Path(row['path']) for row in basis['spec']['pins'] if Path(row['path']).name == 'CAPTURE_NEGATIVE_INTERFACE_V25D1.json')
    capture_cases = read(capture_path)['required_cases']
    require(len(capture_cases) == len(set(capture_cases)) == 24, 'Exact prior capture cases')
    labels = {'cold_import'} | {role + '_' + case.lower() for role in ['lu','shi'] for case in full_cases}
    labels |= {role + '_' + kind for role in ['lu','shi'] for kind in ['world','component']}
    labels |= {role + '_capture_' + case.lower() for role in ['lu','shi'] for case in capture_cases}
    steps = prior['steps']
    require(type(steps) is list and len(steps) == len(labels) == 61
            and {row['label'] for row in steps} == labels, 'Exact61 prior native labels')
    require(len({row['pid'] for row in steps}) == len({row['nonce'] for row in steps}) == 61, 'Distinct prior actual PID/nonces')
    for row in steps:
        require(type(row['pid']) is int and row['pid'] > 0 and type(row['nonce']) is str
                and re.fullmatch('[0-9a-f]{32}',row['nonce']) and row['complete'] is True and row['process_terminal'] is True
                and type(row['exit_code']) is int and row['exit_code'] == 0
                and type(row['engine_errors']) is int and row['engine_errors'] == 0, 'Actual prior process terminal/errors')
        output = Path(row['output']); no_links(output)
        require(output.resolve().is_relative_to(Path(prior['run']).resolve()), 'Prior output custody')
        require(sha(output / 'native.log') == row['log_sha256'], 'Prior native log drift')
    require(set(prior['roles']) == {'lu','shi'} and all(set(prior['roles'][role]) == set(full_cases) for role in ['lu','shi'])
            and set(prior['negative_reports']) == labels - {'cold_import'} - {role + '_' + case.lower() for role in ['lu','shi'] for case in full_cases}, 'Prior exact8+52 report coverage')
    require(type(prior['all_evidence_pins']) is list and prior['all_evidence_pins'], 'Prior complete evidence pin inventory')
    for row in prior['all_evidence_pins']: verify_pin(row)
    for role in ['lu','shi']:
        for row in prior['roles'][role].values(): verify_pin({k:row[k] for k in ['path','bytes','sha256']})
    for row in prior['negative_reports'].values(): verify_pin({k:row[k] for k in ['path','bytes','sha256']})
    require(file_pin(path) == original, 'Prior receipt changed during closed evidence verification')
    return original


class Admission(LegacyPredicates):
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        expected_prior = Path(spec['prior_durable_run']) / 'receipt.json'
        require(args.prior_durable == expected_prior, 'Only the exact preceding durable run may be used')
        prior = read(expected_prior)
        require(prior['complete'] is True and prior['lock_released'] is True
                and prior['durable_chain_and_matrices_qualified'] is True
                and len(prior['steps']) == 61 and all(s['complete'] is True and s['process_terminal'] is True for s in prior['steps'])
                and prior['source_spec_sha256'] == read(LAUNCH)['source_spec_sha256'] == canonical(prior['source_spec'])
                and prior['source_spec'] == read(spec['durable_basis_source_spec_file']['path'])['spec'],
                'Preceding whole suite must actually be closed and qualified')
        self.prior_pin = verify_closed_prior(expected_prior, spec)
        self.prior_pins = read(expected_prior)['all_evidence_pins'] + [file_pin(Path(s['output']) / 'native.log') for s in prior['steps']]
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private work root outside checkout')
        args.work_root.mkdir(parents=True, exist_ok=True)
        self.run = args.work_root / ('admission_regressions_' + uuid.uuid4().hex[:8])
        self.run.mkdir(exist_ok=False)
        self.project = self.run / 'project'
        self.frozen = FrozenProject(self.project, spec['inputs'])
        self.receipt = {'schema': 'campaign_admission_regression_batch_v2', 'run': str(self.run), 'complete': False,
                        'original_JSON_OwnedSlot_and_campaign_admission_qualified': False, 'overall_goal_qualified': False,
                        'original19_faults_qualified': False, 'SDK_reward_once_qualified': False,
                        'source_spec_sha256': canonical(spec), 'source_spec': spec,
                        'source_spec_file': file_pin(args.source_spec), 'independent_review': file_pin(args.independent_review),
                        'prior_durable_receipt': self.prior_pin, 'reports': {}}
        self.batch = OwnedSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist)
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity
        self.reports = {}
        self.held_pins = []
        self.identity = identity_module()

    def persist(self):
        self.receipt['steps'] = self.batch.steps
        path = self.run / 'checkpoint.json'
        pending = path.with_suffix('.writing')
        pending.write_text(json.dumps(self.receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        pending.replace(path)

    def integrity(self):
        self.original_integrity()
        for row in self.spec['pins'] + [self.spec['engine'], self.prior_pin,
                                       self.receipt['source_spec_file'], self.receipt['independent_review']] + self.held_pins + self.prior_pins:
            verify_pin(row)
        if hasattr(self, 'installed'):
            require(self.identity.installed_identity(self.project) == self.installed, 'Current installed identity drift')

    def copy_checked(self, source, target, digest):
        source, target = Path(source), Path(target)
        no_links(source); no_links(target)
        require(sha(source) == digest and not target.exists(), 'Immutable exact source copy')
        target.parent.mkdir(parents=True, exist_ok=True)
        data = source.read_bytes()
        with target.open('xb') as stream: stream.write(data)
        require(sha(source) == digest == sha(target), 'Source or copy drift')
        self.held_pins.append(file_pin(target))

    def evidence_path(self, data, value):
        require(type(value) is str, 'Typed evidence path')
        if value.startswith('user://'):
            relative = value.removeprefix('user://')
            require(relative in {'daming_admit_v24o/handoff_A.json', 'daming_admit_v24o/handoff_B.json'}, 'Only two fixed admission handoffs')
            target = Path(data['actual_user_data_dir']) / relative
        else:
            target = Path(value)
            require(target.is_absolute(), 'Absolute evidence path required')
        no_links(target)
        require(target.resolve().is_relative_to(self.output.resolve()) or
                target.resolve().is_relative_to(Path(data['actual_user_data_dir']).resolve()), 'Current output/user evidence custody')
        return target

    def verify_slot(self, data, handoff, generation):
        user = Path(data['actual_user_data_dir']); no_links(user)
        scope = user / 'continue/v1'
        prior = '0' * 64 if generation == 1 else self.reports[CASES[0]]['slot_sha256']
        path = scope / f'5088120/1/record_{generation:010d}.json'
        slot = envelope(path, 'LH_CLASSIC_CONTINUE_SLOT', generation, prior)
        self.held_pins.append({k:slot[k] for k in ['path','bytes','sha256']})
        require(slot['sha256'] == handoff['file_sha256'] and slot['document'] == handoff['packet'], 'Actual default-root packet and handoff exact')
        packet = slot['document']; token = packet['binding']['token']
        require(type(token) is str and re.fullmatch('[0-9a-f]{32}', token), 'Typed current run token')
        journal_path = scope / ('local_runs/' + token + '/5088120/1/record_0000000001.json')
        journal = envelope(journal_path, 'LH_LOCAL_CONTINUE_LIFECYCLE', 1, '0' * 64)
        self.held_pins.append({k:journal[k] for k in ['path','bytes','sha256']})
        active = journal['document']
        require(set(active) == {'schema','generation','token','context','scope','state','victory','progress_state','intent','progress_receipt'}
                and active['schema'] == 'local_campaign_continue_lifecycle_v2' and active['generation'] == 1
                and active['token'] == token and active['context'] == packet['context'] == {'mode':'campaign','level_id':'level8','waves':0}
                and active['state'] == 'active' and active['progress_state'] == 'none' and active['victory'] is False
                and active['intent'] == {} and active['progress_receipt'] == {}
                and active['scope'] == {'owner':'','content_version':self.installed['content_version'],'engine_sha256':self.receipt['godot_sha256']}
                and packet['binding'] == {'kind':'uncredited','token':token,'receipt_sha256':journal['sha256']}, 'Actual active v2 journal and packet scope exact')
        expected = {f'5088120/1/record_{i:010d}.json' for i in range(1, generation + 1)} | {'local_runs/' + token + '/5088120/1/record_0000000001.json'}
        require({r['relative'] for r in data_tree(scope)} == expected, 'Exact closed slot/journal file set')
        require(data_directories(scope) == {'5088120','5088120/1','local_runs','local_runs/' + token,'local_runs/' + token + '/5088120','local_runs/' + token + '/5088120/1'}, 'No pending or foreign directories')
        target = self.run / 'retained_slots' / f'generation_{generation}.json'
        if not target.exists(): self.copy_checked(path, target, sha(path))
        else: require(sha(target) == sha(path), 'Retained generation drift')
        return {'path':str(path),'sha256':sha(path),'bytes':path.stat().st_size,'retained_path':str(target),'generation':generation,'previous_sha256':prior}

    def prepare(self):
        self.frozen.prepare()
        require(native.install_native(self.project) == self.spec['native_dependencies'], 'Exact native installation closure')
        self.frozen.before = inventory(self.project)
        self.batch.phase('cold_import', self.batch.profile('cold_import'), ['--headless','--editor','--import'], {}, lambda *args: None, 1200)
        self.frozen.freeze_cold()
        self.installed = self.identity.installed_identity(self.project)
        self.receipt['godot_sha256'] = self.spec['engine']['sha256']
        self.receipt['post_cold_installed_identity'] = self.installed
        manifest = json.loads(json.dumps(self.spec['fixtures']))
        files = []
        for i, row in enumerate([manifest['original_payload'], manifest['normalized_payload'], *manifest['maps']]):
            source = Path(row['path']); target = self.run / 'boundary_inputs' / (str(i).zfill(2) + '_' + source.name)
            self.copy_checked(source, target, row['sha256'])
            files.append({'original_path':str(source),'path':str(target),'sha256':row['sha256'],'bytes':target.stat().st_size})
            row['path'] = str(target)
        manifest_path = self.run / 'boundary_inputs/fixtures_frozen.json'
        write_new(manifest_path, manifest); self.held_pins.append(file_pin(manifest_path))
        self.boundary = {'manifest':manifest,'files':files,'frozen_manifest':manifest_path}
        self.persist()

    def execute(self):
        self.prepare()
        self.profile = self.batch.profile('json_boundary')
        def json_values(output, nonce):
            return {'OWNERSHIP_JSON_PROFILE':str(self.profile),'OWNERSHIP_JSON_REPORT':str(output / 'report.json'),
                    'OWNERSHIP_JSON_FIXTURES':str(self.boundary['frozen_manifest']), 'OWNERSHIP_JSON_ENGINE_SHA256':self.receipt['godot_sha256'],
                    'OWNERSHIP_JSON_EXPECT_CONTENT':self.installed['content_version'],'OWNERSHIP_JSON_NONCE':nonce,'DAMING_ADMIT_NONCE':nonce}
        def json_check(step, output, nonce):
            report = output / 'report.json'; no_links(report)
            data = read(report); require(type(data['pid']) is int and len(data['checks']) == 533, 'Exact original JSON533 native report')
            for row in data.get('provenance', []): no_links(Path(row['path']))
            self.boundary_passed(step, (output / 'native.log').read_text(encoding='utf-8',errors='replace'), report, nonce)
            self.held_pins.append(file_pin(report))
        self.batch.phase('json_boundary', self.profile, ['--headless','res://tools/native_ownership_json_boundary_v24q1.tscn'], json_values, json_check, 1200)
        self.profile = self.batch.profile('owned_slot_retry')
        def owned_check(step, output, nonce):
            step['step_dir'] = str(output)
            text = (output / 'native.log').read_text(encoding='utf-8',errors='replace')
            match = re.search(r'OWNED_SLOT_RETRY_QA ([0-9]+) true (.+)', text); require(match is not None and int(match[1]) == 76, 'Exact original OwnedSlot76 native count')
            no_links(Path(match[2].strip())); self.owned_passed(step, text)
            self.held_pins.append(file_pin(Path(step['report'])))
        self.batch.phase('owned_slot_retry', self.profile, ['--headless','res://tools/owned_slot_retry_qa.tscn'],
                         {'LSH_OWNED_SLOT_RETRY_QA':'1','LSH_OWNED_SLOT_RETRY_PROFILE':str(self.profile)}, owned_check, 1200)
        self.profile = self.batch.profile('admission_chain')
        for index, case in enumerate(CASES):
            def values(output, nonce, case=case):
                return {'DAMING_ADMIT_PROFILE':str(self.profile),'DAMING_ADMIT_OUT':str(output),'DAMING_ADMIT_CASE':case,'DAMING_ADMIT_NONCE':nonce,
                        'DAMING_ADMIT_EXPECT_CONTENT':self.installed['content_version'],'DAMING_ADMIT_EXPECT_ENGINE':self.receipt['godot_sha256']}
            def check(step, output, nonce, case=case, index=index):
                self.output = output; step.update(case=case, process_nonce=nonce)
                data = read(output / case / 'report.json'); user = Path(data['actual_user_data_dir']); no_links(user)
                no_links(Path(data['private_profile']))
                require(type(data['pid']) is int and type(data['orders']) is int and user.resolve().is_relative_to((self.profile / 'appdata').resolve())
                        and Path(data['private_profile']).resolve() == self.profile.resolve() and len(data['checks']) >= [39,351,342][index], 'Actual admission profile, process and retained minimum coverage')
                require(data['trusted']['rules_sha256'] == self.installed['rules_sha256'] and data['trusted']['file_count'] == self.installed['file_count']
                        and data['trusted']['total_bytes'] == self.installed['total_bytes'], 'Complete current identity fields')
                self.validate_case(case, step, (output / 'native.log').read_text(encoding='utf-8',errors='replace'))
                for row in data['evidence']: self.held_pins.append(file_pin(self.evidence_path(data, row['path'])))
                self.held_pins.append(file_pin(output / case / 'report.json'))
            self.batch.phase(case.lower(), self.profile, ['--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x720','--position','30000,30000',SCENE], values, check, 1200)
        self.integrity()
        for step in self.batch.steps:
            log = Path(step['output']) / 'native.log'
            no_links(log)
            require(sha(log) == step['log_sha256'], 'Earlier actual native log drift')
        require(len(self.batch.steps) == len(self.batch.pids) == len(self.batch.nonces) == 6 and all(s['complete'] is True for s in self.batch.steps)
                and set(self.reports) == set(CASES), 'Six distinct closed native processes and three reports')
        self.receipt.update(complete=True, original_JSON_OwnedSlot_and_campaign_admission_qualified=True, evidence_pins=self.held_pins)


def main():
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True); parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--work-root',type=Path,default=Path('D:/CodexTemp/lsh-admission-regressions-20261008'))
    parser.add_argument('--write-spec',type=Path); parser.add_argument('--source-spec',type=Path)
    parser.add_argument('--independent-review',type=Path); parser.add_argument('--prior-durable',type=Path)
    parser.add_argument('--run',action='store_true'); args = parser.parse_args()
    spec = source_spec(args); digest = canonical(spec)
    if not args.run:
        if args.write_spec: write_new(args.write_spec, {'spec':spec,'source_spec_sha256':digest})
        print(json.dumps({'preflight':True,'source_spec_sha256':digest,'native_started':False,'overall_goal_qualified':False})); return 0
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None and args.prior_durable is not None, 'Exact seal/review/closed prior required')
    saved = read(args.source_spec); review = read(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == digest and review['schema'] == 'campaign_admission_regression_independent_review_v1'
            and review['independent'] is True and review['static_api_closure_passed'] is True and review['approved_stages'] == [SCOPE]
            and review['producer_sha256'] == sha(Path(__file__)) and review['source_spec_sha256'] == digest
            and review['source_spec_file_sha256'] == sha(args.source_spec), 'Exact limited independent native admission')
    runner = Admission(args, spec); code = 0
    try: runner.execute()
    except BaseException as error:
        code = 1; runner.receipt.update(complete=False,original_JSON_OwnedSlot_and_campaign_admission_qualified=False,failure=repr(error))
    finally:
        try: runner.batch.release()
        except BaseException as error:
            code = 1; runner.receipt.update(complete=False,original_JSON_OwnedSlot_and_campaign_admission_qualified=False)
            runner.receipt.setdefault('finalization_failures',[]).append(repr(error))
        runner.receipt.update(lock_released=not runner.batch.locked,finished_utc=dt.datetime.now(dt.timezone.utc).isoformat())
        runner.persist(); write_new(runner.run / 'receipt.json',runner.receipt)
        print(json.dumps({'run':str(runner.run),'complete':runner.receipt['complete'],'failure':runner.receipt.get('failure'),'overall_goal_qualified':False},ensure_ascii=False))
    return code


if __name__ == '__main__': raise SystemExit(main())
