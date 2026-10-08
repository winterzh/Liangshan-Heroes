"""Real isolated stage-parent fault, production RetryTerminal and normal restart.

This source is a QA candidate. Execution requires its own exact independent
review and a successful closed fresh V9 predecessor; it has no SDK authority.
"""
import argparse
from collections import Counter
import hashlib
import sys
from PIL import Image
import run_steam_integration_qa as native
import datetime as dt
import json
from pathlib import Path
import uuid

from run_campaign_admission_regressions_v4 import source_spec as admission_spec, verify_closed_prior
from durable_campaign_full_runtime import FrozenProject, OwnedSerialBatch, read, sha, write_new, no_links, inventory
from durable_campaign_full_evidence_v2 import envelope, file_pin
from run_durable_campaign_chain_v9 import canonical, identity_module, verify_pin

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
PROBE = QA / 'pending_terminal_ui_candidate_v2/campaign_pending_terminal_ui_probe_v2.gd'
SCOPE = 'actual_pending_terminal_UI_same_object_retry_and_restart'


def require(value, message):
    if not value:
        raise AssertionError(message)


def hex_string(value, size):
    return type(value) is str and len(value) == size and all(c in '0123456789abcdef' for c in value)


def exact_context(value):
    return type(value) is dict and set(value) == {'mode', 'level_id', 'waves'} and type(value['waves']) is int and value == {'mode': 'campaign', 'level_id': 'level1', 'waves': 0}


def validate_intent(value, token, scope):
    require(type(value) is dict and set(value) == {'schema', 'token', 'context', 'profile_id', 'owner', 'content_version', 'engine_sha256', 'victory', 'result'}, 'Exact intent fields')
    require(value['schema'] == 'campaign_progress_intent_v1' and type(value['schema']) is str
            and value['token'] == token and hex_string(value['token'], 32)
            and exact_context(value['context']) and value['profile_id'] == 'campaign_level1_v1'
            and type(value['profile_id']) is str and value['victory'] is True, 'Exact live full intent identity')
    for key, expected in scope.items():
        require(type(value[key]) is str and value[key] == expected, 'Exact intent scope')
    result = value['result']
    require(type(result) is dict and set(result) == {'core_cleared', 'story_complete', 'story_done', 'story_total', 'done_ids', 'contract_version'}, 'Full natural result fields')
    require(result['core_cleared'] is True and result['story_complete'] is True
            and type(result['story_done']) is int and result['story_done'] == 4
            and type(result['story_total']) is int and result['story_total'] == 4
            and type(result['contract_version']) is int and result['contract_version'] == 2
            and type(result['done_ids']) is list and len(result['done_ids']) == 4
            and all(type(x) is str for x in result['done_ids'])
            and set(result['done_ids']) == {'merchant_cover', 'wine_scheme', 'no_bloodshed', 'all_safe'}, 'All four genuine story goals')


def source_spec(args):
    spec = admission_spec(args)
    inputs = json.loads(json.dumps(spec['inputs']))
    inputs['runtime_and_harness_overlays'].append({**file_pin(PROBE), 'runtime_path': 'tools/' + PROBE.name})
    inputs['execution_contract'] = {'native_processes': 3, 'scope': SCOPE,
                                   'normal_CAMPAIGN_QA_empty': True, 'Steam_disabled': True}
    for key in ['JSON_checks', 'OwnedSlot_checks', 'admission_cases', 'pure_QA_labels']:
        spec.pop(key, None)
    spec.update(schema='campaign_pending_terminal_ui_source_spec_v3', inputs=inputs,
                execution_scope=SCOPE, native_processes=3,
                admission_JSON_OwnedSlot_included=False, original19_faults_included=False,
                SDK_reward_once_included=False, overall_goal_qualified=False)
    helpers = [Path(__file__), PROBE, ROOT / 'tools/campaign_natural_terminal_probe.gd',
               ROOT / 'tools/run_campaign_admission_regressions_v4.py',
               QA / 'ADMISSION_REGRESSION_SOURCE_SPEC_V4.json',
               QA / 'ADMISSION_REGRESSION_INDEPENDENT_REVIEW_V4.json',
               ROOT / 'tools/run_campaign_pending_terminal_ui_v1.py', QA / 'PENDING_TERMINAL_UI_SOURCE_SPEC_V1.json',
               ROOT / 'tools/run_campaign_pending_terminal_ui_v2.py', QA / 'PENDING_TERMINAL_UI_SOURCE_SPEC_V2.json',
               QA / 'pending_terminal_ui_candidate_v1/campaign_pending_terminal_ui_probe_v1.gd',
               QA / 'PENDING_TERMINAL_UI_INDEPENDENT_REVIEW_V2.json',
               QA / 'pending_terminal_ui_candidate_v2/MANDATORY_CHECK_LABELS_V3.json']
    pins = {row['path']: row for row in spec['pins']}
    for path in helpers:
        row = file_pin(path)
        require(row['path'] not in pins or row == pins[row['path']], 'Conflicting source pin')
        pins[row['path']] = row
    label_basis = read(QA / 'pending_terminal_ui_candidate_v2/MANDATORY_CHECK_LABELS_V3.json')
    for row in label_basis['original_label_basis']:
        actual = file_pin(Path(row['path']))
        require(all(actual[key] == row[key] for key in ['path', 'bytes', 'sha256']), 'Original label inventory custody')
        pins[actual['path']] = actual
    spec['pins'] = list(pins.values())
    spec['mandatory_check_labels'] = label_basis['expected_counts']
    spec['png_decoder'] = {'package': 'Pillow', 'version': Image.__version__}
    for row in spec['pins']:
        verify_pin(row)
    return spec


class Suite:
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        self.prior = verify_closed_prior(args.prior_durable, spec)
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private work root outside checkout')
        self.run = args.work_root / ('pending_terminal_ui_' + uuid.uuid4().hex[:8])
        no_links(self.run)
        self.run.mkdir(parents=True, exist_ok=False)
        self.frozen = FrozenProject(self.run / 'project', spec['inputs'])
        self.batch = OwnedSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist)
        prior = read(args.prior_durable)
        self.evidence = [self.prior] + prior['all_evidence_pins'] + [file_pin(Path(step['output']) / 'native.log') for step in prior['steps']]
        self.installed_identity = None
        self.receipt = {'schema': 'campaign_pending_terminal_ui_batch_v3', 'run': str(self.run),
                        'started_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
                        'source_spec': spec, 'source_spec_sha256': canonical(spec),
                        'source_spec_file': file_pin(args.source_spec),
                        'independent_review': file_pin(args.independent_review),
                        'prior_durable_receipt': self.prior, 'steps': [], 'reports': {},
                        'complete': False, 'actual_pending_terminal_UI_same_object_retry_qualified': False,
                        'original19_faults_qualified': False, 'SDK_reward_once_qualified': False,
                        'overall_goal_qualified': False}
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity

    def persist(self):
        if not hasattr(self, 'receipt'):
            return
        self.receipt['steps'] = self.batch.steps
        self.receipt['evidence_pins'] = self.evidence
        (self.run / 'checkpoint.json').write_text(json.dumps(self.receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    def integrity(self):
        for row in self.spec['pins'] + self.evidence + [self.receipt['source_spec_file'], self.receipt['independent_review']]:
            verify_pin(row)
        self.original_integrity()
        require(native.native_dependencies() == self.spec['native_dependencies'], 'Native dependency drift')
        require(Image.__version__ == self.spec['png_decoder']['version'], 'PNG decoder version drift')
        if self.installed_identity is not None:
            require(identity_module().installed_identity(self.frozen.project) == self.installed_identity, 'Exact complete installed identity drift')

    def values(self, mode, profile, token=''):
        def build(output, nonce):
            return {'CAMPAIGN_TERMINAL_OUTPUT': str(output), 'CAMPAIGN_TERMINAL_NONCE': nonce,
                    'CAMPAIGN_TERMINAL_MODE': mode, 'CAMPAIGN_TERMINAL_PROFILE': str(profile),
                    'CAMPAIGN_TERMINAL_IDENTITY_FILE': str(self.identity_path),
                    'CAMPAIGN_TERMINAL_IDENTITY_SHA256': sha(self.identity_path),
                    'CAMPAIGN_TERMINAL_TOKEN': token, 'CAMPAIGN_TERMINAL_EXPECT_RECOVERY': '0'}
        return build

    def validate(self, mode):
        def validate_report(step, output, nonce):
            report_path = output / 'report.json'
            report = read(report_path)
            require(report['schema'] == 'campaign_pending_terminal_ui_probe_v2'
                    and type(report['pid']) is int and report['pid'] == step['pid'] and report['nonce'] == nonce and report['mode'] == mode,
                    'Actual report identity')
            checks = report['checks']
            require(type(report['passed']) is bool and report['passed'] and report['failures'] == []
                    and type(checks) is list and checks and all(type(row['ok']) is bool and row['ok'] for row in checks)
                    , 'All native checks')
            require(Counter(row['label'] for row in checks) == Counter(self.spec['mandatory_check_labels'][mode]), 'Exact mandatory check label multiplicities')
            require(sha(output / 'native.log') == step['log_sha256'], 'Original native log hash')
            marker = f'CAMPAIGN_PENDING_TERMINAL_UI_PROBE {mode} true {len(checks)}'
            require((output / 'native.log').read_text(encoding='utf-8', errors='replace').count(marker) == 1, 'Exact native terminal marker')
            require(report['time_scale'] == 1 and report['physics_ticks'] == 60
                    and report['original19_faults_qualified'] is False and report['Steam_rewards_qualified'] is False,
                    'Normal clock and limited scope')
            for field, value in self.runtime_fields.items():
                require(type(report['identity'].get(field)) is type(value) and report['identity'][field] == value, 'Exact installed identity')
            user = Path(report['user_directory']); no_links(user)
            require(user.resolve().is_relative_to(Path(step['profile']).resolve()), 'Owned actual userdata')
            if mode == 'fresh':
                require(report['pending_failure_UI_checks_passed'] is True, 'Actual pending UI checks required')
                handoff_path = output / 'terminal_handoff.json'; handoff = read(handoff_path)
                require(handoff['pid'] == step['pid'] and handoff['nonce'] == nonce, 'Actual terminal handoff')
                self.token = handoff['token']
                self.evidence.append(file_pin(handoff_path))
                for name in ['actual_pending_ui.png', 'actual_confirmed_ui.png']:
                    image = output / name; no_links(image)
                    require(image.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n' and image.stat().st_size > 1000, 'Actual rendered PNG evidence')
                    require(type(report['actual_images']) is dict and set(report['actual_images']) == {'actual_pending_ui.png', 'actual_confirmed_ui.png'}, 'Exactly two native screenshots')
                    metadata = report['actual_images'][name]
                    require(type(metadata) is dict and set(metadata) == {'width', 'height', 'sha256'}
                            and type(metadata['width']) is int and type(metadata['height']) is int
                            and metadata['width'] >= 640 and metadata['height'] >= 360
                            and hex_string(metadata['sha256'], 64) and metadata['sha256'] == sha(image), 'Native captured image custody')
                    with Image.open(image) as decoded:
                        require(decoded.format == 'PNG' and decoded.size == (metadata['width'], metadata['height']), 'Actual PNG dimensions and format')
                        decoded.verify()
                    with Image.open(image) as decoded:
                        decoded.load()
                        require(decoded.getbbox() is not None, 'Decoded rendered pixels')
                    self.evidence.append(file_pin(image))
            else:
                require(report['pending_failure_UI_checks_passed'] is False and report['actual_images'] == {}
                        and report['pending_object_observations'] == [], 'Restart has no injected terminal UI fault')
            require(len(self.token) == 32 and all(c in '0123456789abcdef' for c in self.token), 'Actual run token')
            directory = user / 'continue/v1/local_runs' / self.token / '5088120/1'
            no_links(directory)
            require({p.name for p in directory.iterdir()} == {f'record_{n:010}.json' for n in range(1, 4)}, 'Exact three lifecycle files')
            previous = '0' * 64
            journals = []
            intent = None
            scope = {'owner': '', 'content_version': self.runtime_fields['content_version'], 'engine_sha256': self.spec['engine']['sha256']}
            for revision in range(1, 4):
                row = envelope(directory / f'record_{revision:010}.json', 'LH_LOCAL_CONTINUE_LIFECYCLE', revision, previous)
                document = row['document']
                require(type(document) is dict and set(document) == {'schema', 'generation', 'token', 'context', 'scope', 'state', 'victory', 'progress_state', 'intent', 'progress_receipt'}, 'Exact lifecycle document fields')
                require(document['token'] == self.token and type(document['token']) is str
                        and document['schema'] == 'local_campaign_continue_lifecycle_v2' and type(document['schema']) is str
                        and type(document['generation']) is int and document['generation'] == revision
                        and exact_context(document['context']) and type(document['scope']) is dict
                        and set(document['scope']) == set(scope) and all(type(v) is str for v in document['scope'].values())
                        and document['scope'] == scope, 'Same typed actual lifecycle scope')
                if revision > 1:
                    validate_intent(document['intent'], self.token, scope)
                    if revision == 2:
                        intent = document['intent']
                        require(type(document['progress_receipt']) is dict and not document['progress_receipt'], 'Gen2 has no ACK')
                    else:
                        require(document['intent'] == intent, 'Gen2 and gen3 retain the same full frozen intent')
                    require(document['state'] == 'terminal' and type(document['state']) is str and document['victory'] is True
                            and type(document['progress_state']) is str and document['progress_state'] == ('pending' if revision == 2 else 'applied'), 'Natural terminal transitions')
                else:
                    require(document['state'] == 'active' and type(document['state']) is str and document['progress_state'] == 'none'
                            and type(document['progress_state']) is str and document['victory'] is False
                            and type(document['intent']) is dict and not document['intent']
                            and type(document['progress_receipt']) is dict and not document['progress_receipt'], 'Original active generation1')
                previous = row['sha256']; journals.append({k: row[k] for k in ['path', 'bytes', 'sha256']})
            require(row['document']['progress_receipt']['persisted'] is True
                    and row['document']['progress_receipt']['suppressed'] is False, 'Real acknowledged CFG')
            cfg = file_pin(user / 'campaign.cfg')
            ack = row['document']['progress_receipt']
            require(type(ack) is dict and set(ack) == {'schema', 'code', 'persisted', 'suppressed', 'file_sha256'}
                    and type(ack['schema']) is str and ack['schema'] == 'campaign_progress_ack_v1'
                    and type(ack['code']) is str and ack['code'] == 'CAMPAIGN_CFG_READBACK_VERIFIED'
                    and ack['persisted'] is True and ack['suppressed'] is False
                    and hex_string(ack['file_sha256'], 64) and ack['file_sha256'] == cfg['sha256'], 'Exact CFG-bound five-field ACK')
            handoff_path = output / ('terminal_handoff.json' if mode == 'fresh' else 'restart_handoff.json')
            handoff = read(handoff_path)
            require(type(handoff['pid']) is int and handoff['pid'] == step['pid'] and handoff['nonce'] == nonce
                    and handoff['token'] == self.token and handoff['cfg_sha256'] == cfg['sha256']
                    and handoff['intent'] == intent and handoff['files'] == {Path(r['path']).name: r['sha256'] for r in journals}, 'Full raw handoff closes CFG journal and intent')
            if mode == 'fresh':
                require(handoff['schema'] == 'campaign_natural_terminal_handoff_v1' and exact_context(handoff['context'])
                        and handoff['identity'] == report['identity'], 'Fresh handoff scope')
                self.validate_pending_objects(report['pending_object_observations'], journals, intent, nonce)
            else:
                require(handoff['schema'] == 'campaign_natural_terminal_restart_v1'
                        and type(handoff['startup_result']) is dict and type(handoff['startup_result'].get('progress_recovered')) is int
                        and handoff['startup_result']['progress_recovered'] == 0
                        and handoff['startup_result'].get('settlement_authorized') is False, 'Ordinary restart no recovery or settlement')
            self.evidence.append(file_pin(handoff_path))
            if mode == 'fresh':
                self.journals, self.cfg_sha = journals, cfg['sha256']
                self.evidence.extend(journals + [cfg])
            else:
                require(journals == self.journals and cfg['sha256'] == self.cfg_sha, 'Restart preserves all original bytes')
            self.evidence.extend([file_pin(report_path), file_pin(output / 'native.log')])
            self.receipt['reports'][mode] = {'report': file_pin(report_path), 'checks': len(checks), 'journal': journals, 'cfg_sha256': cfg['sha256']}
        return validate_report

    def validate_pending_objects(self, observations, journals, intent, nonce):
        require(type(observations) is list and len(observations) == 2, 'Both actual blocked attempts observed')
        fields = {'attempt', 'coordinator_id', 'writer_id', 'proposal_id', 'lifecycle_id', 'intent', 'memory', 'code', 'writer_stage', 'proposal_text_sha256', 'semantics_sha256', 'writer_semantics_sha256', 'fault_sha256', 'gen1_sha256', 'gen2_sha256'}
        expected_fault = hashlib.sha256(('campaign_pending_terminal_ui_fault:' + nonce + '\n').encode()).hexdigest()
        for attempt, observation in enumerate(observations):
            require(type(observation) is dict and set(observation) == fields and type(observation['attempt']) is int and observation['attempt'] == attempt, 'Typed exact blocked diagnostic')
            for key in ['coordinator_id', 'writer_id', 'proposal_id', 'lifecycle_id']:
                require(type(observation[key]) is int and observation[key] != 0 and observation[key] == observations[0][key], 'Exact same native transaction object IDs')
            require(observation['intent'] == intent and observation['memory'] == {'records': {}, 'unlocked': 1, 'owner': ''}
                    and type(observation['memory']['unlocked']) is int and observation['code'] == 'CFG_STAGE_PARENT'
                    and observation['writer_stage'] == 'staging' and observation['fault_sha256'] == expected_fault
                    and observation['gen1_sha256'] == journals[0]['sha256'] and observation['gen2_sha256'] == journals[1]['sha256'], 'Actual held bytes intent and memory')
            for key in ['proposal_text_sha256', 'semantics_sha256', 'writer_semantics_sha256']:
                require(hex_string(observation[key], 64) and observation[key] == observations[0][key], 'Complete retained frozen proposal hashes')
            require(observation['semantics_sha256'] == observation['writer_semantics_sha256'], 'Writer freezes the exact full value semantics')

    def execute(self):
        self.frozen.prepare()
        require(native.install_native(self.frozen.project) == self.spec['native_dependencies'], 'Exact native installation')
        self.frozen.before = inventory(self.frozen.project)
        self.batch.phase('cold_import', self.batch.profile('import'), ['--headless', '--editor', '--import'], {},
                         lambda step, output, nonce: None, 600)
        self.frozen.freeze_cold()
        identity = identity_module().installed_identity(self.frozen.project)
        self.installed_identity = identity
        self.receipt['post_cold_runtime_identity'] = identity
        self.receipt['post_cold_installed_files'] = self.frozen.cold
        self.runtime_fields = {key: identity[key] for key in ['content_version', 'rules_sha256', 'file_count', 'total_bytes']}
        self.runtime_fields.update(engine_binary_sha256=sha(self.args.godot), provider_sha256=sha(self.frozen.project / 'scripts/run_content_identity.gd'))
        self.identity_path = self.run / 'post_cold_identity.json'
        write_new(self.identity_path, {'runtime_fields': self.runtime_fields, 'complete_identity': identity})
        self.evidence.append(file_pin(self.identity_path)); self.persist()
        profile = self.batch.profile('pending_ui')
        arguments = ['--script', 'res://tools/' + PROBE.name]
        self.batch.phase('actual_pending_terminal_ui', profile, arguments, self.values('fresh', profile), self.validate('fresh'), 1800)
        self.batch.phase('actual_pending_terminal_restart', profile, arguments, self.values('restart', profile, self.token), self.validate('restart'), 180)
        self.integrity()
        self.receipt.update(complete=True, actual_pending_terminal_UI_same_object_retry_qualified=True)


def main():
    require(__debug__, 'Assertions must remain enabled')
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True); parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--work-root', type=Path, default=Path('D:/CodexTemp/lsh-pending-terminal-ui-20261009'))
    parser.add_argument('--write-spec', type=Path); parser.add_argument('--source-spec', type=Path)
    parser.add_argument('--independent-review', type=Path); parser.add_argument('--prior-durable', type=Path)
    parser.add_argument('--run', action='store_true'); args = parser.parse_args()
    spec = source_spec(args); digest = canonical(spec)
    if not args.run:
        if args.write_spec: write_new(args.write_spec, {'spec': spec, 'source_spec_sha256': digest})
        print(json.dumps({'preflight': True, 'source_spec_sha256': digest, 'native_started': False})); return 0
    require(args.write_spec is None and args.source_spec and args.independent_review and args.prior_durable, 'Exact seal/review/closed prior required')
    saved = read(args.source_spec); review = read(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == digest
            and review['schema'] == 'campaign_pending_terminal_ui_independent_review_v1' and review['independent'] is True
            and review['static_api_closure_passed'] is True and review['approved_stages'] == [SCOPE]
            and review['producer_sha256'] == sha(Path(__file__)) and review['probe_sha256'] == sha(PROBE)
            and review['source_spec_sha256'] == digest and review['source_spec_file_sha256'] == sha(args.source_spec), 'Exact limited source review required')
    suite = Suite(args, spec); code = 0
    try: suite.execute()
    except BaseException as error:
        code = 1; suite.receipt.update(complete=False, actual_pending_terminal_UI_same_object_retry_qualified=False, failure=repr(error))
    finally:
        try: suite.batch.release()
        except BaseException as error:
            code = 1; suite.receipt.update(complete=False, actual_pending_terminal_UI_same_object_retry_qualified=False, release_failure=repr(error))
        suite.receipt['lock_released'] = not suite.batch.locked
        suite.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist(); write_new(suite.run / 'receipt.json', suite.receipt)
    print(json.dumps({'run': str(suite.run), 'complete': suite.receipt['complete'], 'failure': suite.receipt.get('failure'), 'overall_goal_qualified': False})); return code


if __name__ == '__main__':
    raise SystemExit(main())
