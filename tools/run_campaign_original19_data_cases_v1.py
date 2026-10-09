"""Eight original persistence case mechanisms; other eleven remain required.

Only exact independent source admission plus a closed successful fresh V9
predecessor permits this four-process cold/data/QA/QA batch.
"""
import argparse
import datetime as dt
import json
from pathlib import Path
import sys
import uuid

from run_campaign_pending_terminal_ui_v5 import source_spec as ui_spec, Suite as FixedEvidenceSuite, require, hex_string, load_fixed_document
from run_campaign_admission_regressions_v4 import verify_closed_prior
from campaign_original19_data_runtime_v1 import FrozenProject, OwnedSerialBatch, inventory, no_links, read, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
from run_durable_campaign_chain_v9 import canonical, identity_module, verify_pin
import run_steam_integration_qa as native

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
DATA = QA / 'original19_data_layers_candidate_v2'
COMPAT = QA / 'original19_QA_compatibility_candidate_v1'
DATA_GD = DATA / 'campaign_original19_data_layers_v2.gd'
COMPAT_GD = COMPAT / 'campaign_original19_QA_compatibility_v1.gd'
DATA_IDS = ['true_new_missing_cfg', 'best_single_run_no_union', 'invalid_no_unlock',
            'legal_unknown_variant_preservation', 'unsupported_object_or_script_container', 'cycle_or_overdepth']
QA_IDS = ['QA_memory_only', 'QA_cloud_bool_compatibility']
SCOPE = 'original19_six_data_CFG_and_two_QA_compatibility_cases'
CASE_CHECKS = dict(zip(DATA_IDS, [7, 20, 10, 14, 30, 16]))


def source_spec(args):
    spec = ui_spec(args)
    inputs = json.loads(json.dumps(spec['inputs']))
    helpers = [Path(__file__), ROOT / 'tools/campaign_original19_data_runtime_v1.py',
               ROOT / 'tools/run_campaign_pending_terminal_ui_v5.py', QA / 'PENDING_TERMINAL_UI_SOURCE_SPEC_V5.json',
               QA / 'PENDING_TERMINAL_UI_INDEPENDENT_REVIEW_V5.json', DATA_GD, COMPAT_GD,
               DATA / 'SOURCE.json', COMPAT / 'SOURCE.json',
               DATA / 'ORIGINAL19_DATA_LAYERS_PRELIMINARY_REVIEW_V2.json',
               COMPAT / 'ORIGINAL19_QA_COMPATIBILITY_PRELIMINARY_REVIEW_V1.json',
               QA / 'ORIGINAL19_R12_ADAPTATION_REQUIREMENTS_V1.json']
    for folder, gd, review_name in [(DATA, DATA_GD, 'ORIGINAL19_DATA_LAYERS_PRELIMINARY_REVIEW_V2.json'),
                                    (COMPAT, COMPAT_GD, 'ORIGINAL19_QA_COMPATIBILITY_PRELIMINARY_REVIEW_V1.json')]:
        review = read(folder / review_name)
        require(review['independent'] is True and review['static_api_closure_passed'] is True
                and review['approved_stages'] == [] and review['candidate_sha256'] == sha(gd), 'Exact preliminary script review')
        manifest = read(folder / 'SOURCE.json')
        require(manifest['candidate'] == file_pin(gd), 'Exact preliminary source manifest')
        for row in manifest['runtime_sources']: verify_pin(row)
        relative = 'tools/' + gd.name
        require(relative not in {row['runtime_path'] for row in inputs['runtime_and_harness_overlays']}, 'Unique data/QA overlay')
        inputs['runtime_and_harness_overlays'].append({**file_pin(gd), 'runtime_path': relative})
    inputs['schema'] = 'original19_data_cases_inputs_v1'
    inputs['execution_contract'] = {'native_processes': 4, 'scope': SCOPE, 'data_case_ids': DATA_IDS,
                                   'separate_QA1_case_ids': QA_IDS, 'Steam_disabled': True,
                                   'all_original19_qualified': False}
    pins = {row['path']: row for row in spec['pins']}
    for path in helpers:
        row = file_pin(path)
        require(row['path'] not in pins or pins[row['path']] == row, 'Conflicting helper pin')
        pins[row['path']] = row
    spec.update(schema='original19_data_cases_source_spec_v1', inputs=inputs, pins=list(pins.values()),
                execution_scope=SCOPE, native_processes=4, data_case_ids=DATA_IDS, QA_case_ids=QA_IDS,
                original19_case_mechanisms_included=8, full_original19_included=False,
                data_expected_checks=109, data_case_checks=CASE_CHECKS, overall_goal_qualified=False)
    spec.pop('mandatory_check_labels', None)
    for row in spec['pins']: verify_pin(row)
    return spec


class Suite(FixedEvidenceSuite):
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        self.prior = verify_closed_prior(args.prior_durable, spec)
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private work root outside checkout')
        self.run = args.work_root / ('original19_data_' + uuid.uuid4().hex[:8])
        no_links(self.run); self.run.mkdir(parents=True, exist_ok=False)
        self.frozen = FrozenProject(self.run / 'project', spec['inputs'])
        self.batch = OwnedSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist)
        self.evidence, self.evidence_by_path = [], {}
        prior = self.read_fixed(args.prior_durable, self.prior['sha256'])
        for row in prior['all_evidence_pins']: self.remember(row)
        for step in prior['steps']: self.freeze_bytes(Path(step['output']) / 'native.log', step['log_sha256'])
        self.installed_identity = None
        self.receipt = {'schema': 'original19_data_cases_batch_v1', 'run': str(self.run),
                        'started_utc': dt.datetime.now(dt.timezone.utc).isoformat(), 'source_spec': spec,
                        'source_spec_sha256': canonical(spec), 'source_spec_file': args.fixed_source_spec_pin,
                        'independent_review': args.fixed_independent_review_pin, 'prior_durable_receipt': self.prior,
                        'steps': [], 'reports': {}, 'complete': False, 'eight_original_case_mechanisms_qualified': False,
                        'original19_qualified': False, 'normal_live_terminal_qualified': False,
                        'SDK_reward_once_qualified': False, 'UI_qualified': False, 'overall_goal_qualified': False}
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity

    def values(self, kind, profile, case=''):
        prefix = 'CAMPAIGN_DATA19_' if kind == 'data' else 'CAMPAIGN_COMPAT19_'
        def build(output, nonce):
            values = {prefix + 'OUTPUT': str(output), prefix + 'NONCE': nonce, prefix + 'PROFILE': str(profile),
                      prefix + 'IDENTITY_FILE': str(self.identity_path), prefix + 'IDENTITY_SHA256': sha(self.identity_path)}
            if kind != 'data': values[prefix + 'CASE'] = case
            return values
        return build

    def validate(self, kind, case=''):
        def validate_report(step, output, nonce):
            path = output / 'report.json'; report = self.read_fixed(path)
            log = self.freeze_bytes(output / 'native.log', step['log_sha256']).decode('utf-8', errors='replace')
            require(type(report['pid']) is int and report['pid'] == step['pid'] and report['nonce'] == nonce
                    and report['passed'] is True and report['failures'] == [] and report['overall_goal_qualified'] is False
                    and report['original19_qualified'] is False and report['UI_qualified'] is False
                    and report['SDK_reward_once_qualified'] is False, 'Actual limited report identity and scope')
            checks = report['checks']
            require(type(checks) is list and checks and all(type(row) is dict and row['ok'] is True and type(row['label']) is str for row in checks), 'All native checks true')
            require(report['time_scale'] == 1 and report['physics_ticks'] == 60, 'Normal engine clock')
            for field, value in self.runtime_fields.items():
                require(type(report['identity'].get(field)) is type(value) and report['identity'][field] == value, 'Exact current installed identity')
            user = Path(report['actual_user_directory']); no_links(user)
            require(user.resolve().is_relative_to(Path(step['profile']).resolve()), 'Actual owned userdata')
            if kind == 'data':
                require(report['schema'] == 'campaign_original19_data_layers_v2' and step['CAMPAIGN_QA_enabled'] is False
                        and len(checks) == self.spec['data_expected_checks'] and report['natural_battle_qualified'] is False, 'Exact normal data case report')
                cases = report['cases']
                require(type(cases) is list and [row['id'] for row in cases] == DATA_IDS and all(row['passed'] is True for row in cases), 'All six original data case IDs')
                flattened = []
                for row in cases:
                    require(len(row['checks']) == CASE_CHECKS[row['id']] and all(check['case'] == row['id'] for check in row['checks']), 'Exact per-case coverage')
                    flattened.extend(row['checks'])
                require(checks[11:-1] == flattened and checks[-1]['label'] == 'all six original data case IDs executed', 'Complete ordered native check coverage')
                refusals = report['invalid_refusals']
                require(type(refusals) is list and len(refusals) == 4, 'All physical invalid requests')
                for index, row in enumerate(refusals):
                    require(type(row['index']) is int and row['index'] == index and row['refusal']['ok'] is False
                            and row['refusal']['code'] == ['CAMPAIGN_INTENT_CONTEXT', 'CAMPAIGN_INTENT_CONTEXT', 'CAMPAIGN_INTENT_OUTCOME_MISMATCH', 'CAMPAIGN_INTENT_IDS'][index]
                            and hex_string(row['before_CFG_sha256'], 64) and row['before_CFG_sha256'] == row['after_CFG_sha256'], 'Exact invalid code and unchanged original CFG')
                marker = f'CAMPAIGN_ORIGINAL19_DATA_LAYERS true 6 {len(checks)}'
                self.freeze_bytes(user / 'campaign.cfg')
                directory = user / 'campaign_cfg_transactions/v1/5088120/1'
                require(directory.is_dir(), 'Actual CFG transaction journal exists')
                for item in directory.iterdir():
                    no_links(item)
                    if item.is_file(): self.freeze_bytes(item)
            else:
                require(report['schema'] == 'campaign_original19_QA_compatibility_v1' and report['case'] == case
                        and report['CAMPAIGN_QA_enabled'] is True and step['CAMPAIGN_QA_enabled'] is True
                        and report['normal_persistence_qualified'] is False, 'Separate QA1 compatibility scope')
                required = {'actual production Campaign and Cloud nodes retained', 'SDK disabled with no active credited run',
                            'actual campaign CFG sentinel bytes unchanged', 'actual Cloud dirty callback state unchanged',
                            'real sentinel readback contains no QA campaign progress'}
                require(required <= {row['label'] for row in checks}, 'Mandatory genuine QA compatibility observations')
                self.freeze_bytes(user / 'campaign.cfg', report['sentinel_sha256'])
                marker = f'CAMPAIGN_ORIGINAL19_QA_COMPATIBILITY {case} true {len(checks)}'
            require(log.count(marker) == 1, 'Exact closed native terminal marker')
            for row in self.evidence: verify_pin(row)
            self.receipt['reports'][case or kind] = {'report': self.evidence_by_path[str(path.resolve()).casefold()], 'checks': len(checks), 'actual_user_directory': str(user)}
        return validate_report

    def execute(self):
        self.frozen.prepare()
        require(native.install_native(self.frozen.project) == self.spec['native_dependencies'], 'Exact current native installation')
        self.frozen.before = inventory(self.frozen.project)
        self.batch.phase('cold_import', self.batch.profile('cold'), ['--headless', '--editor', '--import'], {}, lambda *args: None, 600)
        self.frozen.freeze_cold()
        self.installed_identity = identity_module().installed_identity(self.frozen.project)
        self.runtime_fields = {key: self.installed_identity[key] for key in ['content_version', 'rules_sha256', 'file_count', 'total_bytes']}
        self.runtime_fields.update(engine_binary_sha256=self.spec['engine']['sha256'], provider_sha256=sha(self.frozen.project / 'scripts/run_content_identity.gd'))
        self.identity_path = self.run / 'post_cold_identity.json'
        write_new(self.identity_path, {'runtime_fields': self.runtime_fields, 'complete_identity': self.installed_identity})
        self.freeze_bytes(self.identity_path)
        profile = self.batch.profile('data')
        self.batch.phase('original19_data', profile, ['--headless', '--script', 'res://tools/' + DATA_GD.name], self.values('data', profile), self.validate('data'), 900)
        for case in QA_IDS:
            profile = self.batch.profile(case.lower())
            self.batch.phase(case.lower(), profile, ['--headless', '--script', 'res://tools/' + COMPAT_GD.name], self.values('compat', profile, case), self.validate('compat', case), 300)
        self.integrity()
        self.receipt.update(complete=True, eight_original_case_mechanisms_qualified=True)


def main():
    require(__debug__, 'Assertions must remain enabled'); sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True); parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--work-root', type=Path, default=Path('D:/CodexTemp/lsh-original19-data-20261009'))
    parser.add_argument('--write-spec', type=Path); parser.add_argument('--source-spec', type=Path)
    parser.add_argument('--independent-review', type=Path); parser.add_argument('--prior-durable', type=Path); parser.add_argument('--run', action='store_true')
    args = parser.parse_args(); spec = source_spec(args); digest = canonical(spec)
    if not args.run:
        if args.write_spec: write_new(args.write_spec, {'spec': spec, 'source_spec_sha256': digest})
        print(json.dumps({'preflight': True, 'source_spec_sha256': digest, 'native_started': False, 'all_original19_qualified': False})); return 0
    require(args.write_spec is None and args.source_spec and args.independent_review and args.prior_durable, 'Exact seal/review/closed prior required')
    saved, args.fixed_source_spec_pin = load_fixed_document(args.source_spec)
    review, args.fixed_independent_review_pin = load_fixed_document(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == digest and review['independent'] is True
            and review['schema'] == 'original19_data_cases_independent_review_v1' and review['static_api_closure_passed'] is True
            and review['approved_stages'] == [SCOPE] and review['producer_sha256'] == sha(Path(__file__))
            and review['source_spec_sha256'] == digest and review['source_spec_file_sha256'] == args.fixed_source_spec_pin['sha256'], 'Exact limited independent source review')
    suite = Suite(args, spec); code = 0
    try: suite.execute()
    except BaseException as error:
        code = 1; suite.receipt.update(complete=False, eight_original_case_mechanisms_qualified=False, failure=repr(error))
    finally:
        try: suite.batch.release()
        except BaseException as error:
            code = 1; suite.receipt.update(complete=False, eight_original_case_mechanisms_qualified=False, release_failure=repr(error))
        suite.receipt['lock_released'] = not suite.batch.locked; suite.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist(); write_new(suite.run / 'receipt.json', suite.receipt)
    print(json.dumps({'run': str(suite.run), 'complete': suite.receipt['complete'], 'failure': suite.receipt.get('failure'), 'all_original19_qualified': False})); return code


if __name__ == '__main__':
    raise SystemExit(main())
