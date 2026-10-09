"""Real isolated stage-parent fault, production RetryTerminal and normal restart.

This source is a QA candidate. Execution requires its own exact independent
review and a successful closed fresh V9 predecessor; it has no SDK authority.
"""
import argparse
import datetime as dt
import json
from pathlib import Path
import uuid

from run_campaign_admission_regressions_v4 import source_spec as admission_spec, verify_closed_prior
from durable_campaign_full_runtime import FrozenProject, OwnedSerialBatch, read, sha, write_new, no_links
from durable_campaign_full_evidence_v2 import envelope, file_pin
from run_durable_campaign_chain_v9 import canonical, identity_module, verify_pin

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
PROBE = QA / 'pending_terminal_ui_candidate_v1/campaign_pending_terminal_ui_probe_v1.gd'
SCOPE = 'actual_pending_terminal_UI_same_object_retry_and_restart'


def require(value, message):
    if not value:
        raise AssertionError(message)


def source_spec(args):
    spec = admission_spec(args)
    inputs = json.loads(json.dumps(spec['inputs']))
    inputs['runtime_and_harness_overlays'].append({**file_pin(PROBE), 'runtime_path': 'tools/' + PROBE.name})
    inputs['execution_contract'] = {'native_processes': 3, 'scope': SCOPE,
                                   'normal_CAMPAIGN_QA_empty': True, 'Steam_disabled': True}
    spec.update(schema='campaign_pending_terminal_ui_source_spec_v2', inputs=inputs,
                execution_scope=SCOPE, native_processes=3,
                admission_JSON_OwnedSlot_included=False, original19_faults_included=False,
                SDK_reward_once_included=False, overall_goal_qualified=False)
    helpers = [Path(__file__), PROBE, ROOT / 'tools/campaign_natural_terminal_probe.gd',
               ROOT / 'tools/run_campaign_admission_regressions_v4.py',
               QA / 'ADMISSION_REGRESSION_SOURCE_SPEC_V4.json',
               QA / 'ADMISSION_REGRESSION_INDEPENDENT_REVIEW_V4.json',
               ROOT / 'tools/run_campaign_pending_terminal_ui_v1.py', QA / 'PENDING_TERMINAL_UI_SOURCE_SPEC_V1.json']
    pins = {row['path']: row for row in spec['pins']}
    for path in helpers:
        row = file_pin(path)
        require(row['path'] not in pins or row == pins[row['path']], 'Conflicting source pin')
        pins[row['path']] = row
    spec['pins'] = list(pins.values())
    for row in spec['pins']:
        verify_pin(row)
    return spec


class Suite:
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        self.prior = verify_closed_prior(args.prior_durable, spec)
        self.run = args.work_root / ('pending_terminal_ui_' + uuid.uuid4().hex[:8])
        no_links(self.run)
        self.run.mkdir(parents=True, exist_ok=False)
        self.frozen = FrozenProject(self.run / 'project', spec['inputs'])
        self.batch = OwnedSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist)
        self.evidence = [self.prior]
        self.receipt = {'schema': 'campaign_pending_terminal_ui_batch_v2', 'run': str(self.run),
                        'started_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
                        'source_spec': spec, 'source_spec_sha256': canonical(spec),
                        'source_spec_file': file_pin(args.source_spec),
                        'independent_review': file_pin(args.independent_review),
                        'prior_durable_receipt': self.prior, 'steps': [], 'reports': {},
                        'complete': False, 'actual_pending_terminal_UI_same_object_retry_qualified': False,
                        'original19_faults_qualified': False, 'SDK_reward_once_qualified': False,
                        'overall_goal_qualified': False}

    def persist(self):
        if not hasattr(self, 'receipt'):
            return
        self.receipt['steps'] = self.batch.steps
        self.receipt['evidence_pins'] = self.evidence
        (self.run / 'checkpoint.json').write_text(json.dumps(self.receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    def integrity(self):
        for row in self.spec['pins'] + self.evidence + [self.receipt['source_spec_file'], self.receipt['independent_review']]:
            verify_pin(row)
        self.batch.integrity()

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
            require(report['schema'] == 'campaign_pending_terminal_ui_probe_v1'
                    and report['pid'] == step['pid'] and report['nonce'] == nonce and report['mode'] == mode,
                    'Actual report identity')
            checks = report['checks']
            require(type(report['passed']) is bool and report['passed'] and report['failures'] == []
                    and type(checks) is list and checks and all(type(row['ok']) is bool and row['ok'] for row in checks)
                    and len({row['label'] for row in checks}) == len(checks), 'All distinct native checks')
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
                    self.evidence.append(file_pin(image))
            require(len(self.token) == 32 and all(c in '0123456789abcdef' for c in self.token), 'Actual run token')
            directory = user / 'continue/v1/local_runs' / self.token / '5088120/1'
            no_links(directory)
            require({p.name for p in directory.iterdir()} == {f'record_{n:010}.json' for n in range(1, 4)}, 'Exact three lifecycle files')
            previous = '0' * 64
            journals = []
            for revision in range(1, 4):
                row = envelope(directory / f'record_{revision:010}.json', 'LH_LOCAL_CONTINUE_LIFECYCLE', revision, previous)
                document = row['document']
                require(document['token'] == self.token and document['schema'] == 'local_campaign_continue_lifecycle_v2'
                        and document['context'] == {'mode': 'campaign', 'level_id': 'level1', 'waves': 0}, 'Same actual lifecycle scope')
                if revision > 1:
                    require(document['intent']['result']['story_complete'] is True
                            and document['progress_state'] == ('pending' if revision == 2 else 'applied'), 'Natural frozen intent and acknowledgement')
                previous = row['sha256']; journals.append({k: row[k] for k in ['path', 'bytes', 'sha256']})
            require(row['document']['progress_receipt']['persisted'] is True
                    and row['document']['progress_receipt']['suppressed'] is False, 'Real acknowledged CFG')
            cfg = file_pin(user / 'campaign.cfg')
            if mode == 'fresh':
                self.journals, self.cfg_sha = journals, cfg['sha256']
                self.evidence.extend(journals + [cfg])
            else:
                require(journals == self.journals and cfg['sha256'] == self.cfg_sha, 'Restart preserves all original bytes')
            self.evidence.extend([file_pin(report_path), file_pin(output / 'native.log')])
            self.receipt['reports'][mode] = {'report': file_pin(report_path), 'checks': len(checks), 'journal': journals, 'cfg_sha256': cfg['sha256']}
        return validate_report

    def execute(self):
        self.frozen.prepare()
        self.batch.phase('cold_import', self.batch.profile('import'), ['--headless', '--editor', '--import'], {},
                         lambda step, output, nonce: None, 600)
        self.frozen.freeze_cold()
        identity = identity_module().installed_identity(self.frozen.project)
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
