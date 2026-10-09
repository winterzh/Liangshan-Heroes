"""Run the retained real terminal UI retry/restart checks after a closed V12 prior.

Recipe-only preparation never starts native work. V5 sources and checks remain
unchanged; this successor requires a new exact source seal and admission.
"""
import argparse
import ast
import datetime as dt
import json
from pathlib import Path
import subprocess
import sys
import uuid

from campaign_callback_controller_v3 import expected_native_identity
from campaign_callback_packets_v2 import same
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from durable_campaign_full_runtime import FrozenProject, OwnedSerialBatch, no_links, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
from durable_campaign_full_matrices import require
from run_campaign_file_faults_v3 import prior_receipt_path, pinned_document
from run_durable_campaign_chain_v12 import canonical, source_spec as durable_spec, verify_pin
import run_campaign_pending_terminal_ui_v5 as predecessor

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT/'qa/campaign_progress_recovery_20261008'
SCOPE = 'actual_pending_terminal_UI_same_object_retry_and_restart_after_V12'


def source_recipe(args):
    current = durable_spec(args)
    basis, basis_pin = pinned_document(QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json')
    review, review_pin = pinned_document(QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json')
    require(current == basis['spec'] and canonical(current) == basis['source_spec_sha256']
            and review['independent'] is True and review['static_api_closure_passed'] is True
            and review['approved_stages'] == ['durable_chain_and_matrices']
            and review['source_spec_sha256'] == basis['source_spec_sha256']
            and review['source_spec_file_sha256'] == basis_pin['sha256'], 'Exact approved current V12 basis')
    original, original_pin = pinned_document(QA/'PENDING_TERMINAL_UI_SOURCE_SPEC_V5.json')
    original_review, original_review_pin = pinned_document(QA/'PENDING_TERMINAL_UI_INDEPENDENT_REVIEW_V5.json')
    require(canonical(original['spec']) == original['source_spec_sha256']
            and original_review['independent'] is True and original_review['static_api_closure_passed'] is True
            and original_review['approved_stages'] == [predecessor.SCOPE]
            and original_review['source_spec_sha256'] == original['source_spec_sha256']
            and original_review['source_spec_file_sha256'] == original_pin['sha256']
            and original_review['producer_sha256'] == sha(Path(predecessor.__file__))
            and original_review['probe_sha256'] == sha(predecessor.PROBE),
            'Retained V5 consumer/probe bytes and review, never transferred execution authority')
    labels_path = predecessor.PROBE.parent/'MANDATORY_CHECK_LABELS_V3.json'
    labels, labels_pin = pinned_document(labels_path)
    require(same(labels['expected_counts'], original['spec']['mandatory_check_labels']), 'All original label multiplicities retained')
    inputs = json.loads(json.dumps(current['inputs']))
    probe = file_pin(predecessor.PROBE)
    alias = 'tools/'+predecessor.PROBE.name
    require(alias not in {row['runtime_path'] for row in inputs['runtime_and_harness_overlays']}, 'Unique retained native UI probe alias')
    inputs['runtime_and_harness_overlays'].append({**probe, 'runtime_path': alias})
    inputs['schema'] = 'campaign_pending_terminal_ui_inputs_v6'
    inputs['execution_contract'] = {'native_processes': 3, 'scope': SCOPE, 'normal_CAMPAIGN_QA_empty': True,
                                    'Steam_disabled': True, 'same_original_Coordinator_CFG_writer_intent': True,
                                    'same_profile_ordinary_restart': True}
    pins = {}

    def adopt(row):
        verify_pin(row)
        require(row['path'] not in pins or pins[row['path']] == row, 'No source conflict between immutable predecessors')
        pins[row['path']] = row

    for row in [*current['pins'], *original['spec']['pins'], basis_pin, review_pin, original_pin,
                original_review_pin, labels_pin, probe, file_pin(Path(__file__))]:
        adopt(row)
    checked, edges = set(), []
    while True:
        pending = [Path(row['path']) for row in pins.values() if row['path'].endswith('.py') and row['path'] not in checked]
        if not pending:
            break
        for path in pending:
            checked.add(str(path))
            for node in ast.walk(ast.parse(path.read_bytes(), filename=str(path))):
                modules = [node.module] if isinstance(node, ast.ImportFrom) and node.level == 0 else [v.name for v in node.names] if isinstance(node, ast.Import) else []
                for module in modules:
                    if not module:
                        continue
                    dependency = ROOT/'tools'/(module.split('.')[0]+'.py')
                    if dependency.is_file():
                        edges.append({'source': str(path), 'module': module, 'target': str(dependency)})
                        adopt(file_pin(dependency))
    for row in pins.values():
        verify_pin(row)
    return {'schema': 'campaign_pending_terminal_ui_source_recipe_v6', 'producer': file_pin(Path(__file__)),
            'inputs': inputs, 'pins': sorted(pins.values(), key=lambda row: row['path']), 'Python_import_edges': edges,
            'engine': current['engine'], 'native_dependencies': current['native_dependencies'],
            'durable_basis_source_spec_file': basis_pin, 'durable_basis_independent_review': review_pin,
            'durable_basis_logical_sha256': basis['source_spec_sha256'], 'retained_V5_source_spec': original_pin,
            'retained_V5_review': original_review_pin, 'retained_probe': probe, 'label_contract': labels_pin,
            'mandatory_check_labels': labels['expected_counts'], 'png_decoder': original['spec']['png_decoder'],
            'execution_scope': SCOPE, 'native_processes': 3, 'original_consumer_checks_retained': True,
            'V5_closed_V9_prior_authority_transferred': False, 'native_started': False,
            'pending_UI_qualified': False, 'original19_faults_qualified': False, 'SDK_reward_once_qualified': False,
            'overall_goal_qualified': False}


def source_spec(args):
    spec = source_recipe(args)
    spec['schema'] = 'campaign_pending_terminal_ui_source_spec_v6'
    spec['prior_durable_run'] = str(prior_receipt_path(args).parent)
    _, pin = verify_closed_prior_v12(prior_receipt_path(args), spec)
    spec['prior_durable_receipt'] = pin
    return spec


class Suite(predecessor.Suite):
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        require(prior_receipt_path(args) == Path(spec['prior_durable_run'])/'receipt.json', 'Exact sealed successful V12 prior path')
        prior, self.prior = verify_closed_prior_v12(args.prior_durable, spec)
        require(self.prior == spec['prior_durable_receipt'], 'Same original successful prior before directory creation')
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private UI evidence outside source checkout')
        self.run = args.work_root/('pending_terminal_ui_v6_'+uuid.uuid4().hex[:8])
        no_links(self.run)
        self.run.mkdir(parents=True, exist_ok=False)
        self.frozen = FrozenProject(self.run/'project', spec['inputs'])
        self.batch = OwnedSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist)
        self.evidence, self.evidence_by_path, self.installed_identity = [], {}, None
        self.remember(self.prior)
        for row in prior['all_evidence_pins']:
            self.remember(row)
        for step in prior['steps']:
            self.freeze_bytes(Path(step['output'])/'native.log', step['log_sha256'])
        self.receipt = {'schema': 'campaign_pending_terminal_ui_batch_v6', 'run': str(self.run),
                        'started_utc': dt.datetime.now(dt.timezone.utc).isoformat(), 'source_spec': spec,
                        'source_spec_sha256': canonical(spec), 'source_spec_file': args.fixed_source_spec_pin,
                        'independent_review': args.fixed_independent_review_pin, 'prior_durable_receipt': self.prior,
                        'steps': [], 'reports': {}, 'complete': False,
                        'actual_pending_terminal_UI_same_object_retry_qualified': False,
                        'original19_faults_qualified': False, 'SDK_reward_once_qualified': False,
                        'overall_goal_qualified': False}
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity
        self.persist()

    def validate(self, mode):
        inherited = super().validate(mode)

        def actual_terminal(step, output, nonce):
            child = self.batch.child
            require(type(child) is subprocess.Popen and child._child_created is True
                    and child.pid == step['pid'] and subprocess.Popen.poll(child) == 0
                    and step['process_terminal'] is True and step['complete'] is False
                    and step['nonce'] == nonce and step['output'] == str(output), 'Retained original terminal Popen during full UI consumer')
            require(mode in ['fresh', 'restart'] and len(self.batch.steps) == (2 if mode == 'fresh' else 3)
                    and self.batch.steps[0]['complete'] is True
                    and self.batch.steps[0]['label'] == 'cold_import'
                    and step is self.batch.steps[-1]
                    and step['label'] == ('actual_pending_terminal_ui' if mode == 'fresh' else 'actual_pending_terminal_restart'),
                    'Only original successful cold then actual fresh and same-profile restart')
            command = [str(self.batch.engine), '--path', str(self.frozen.project), '--script',
                       'res://tools/'+predecessor.PROBE.name]
            require(child.args == step['command'] == command, 'Exact retained GUI probe command')
            profile = Path(step['profile'])
            require(profile != Path(self.batch.steps[0]['profile'])
                    and profile.resolve().is_relative_to((self.run/'profiles').resolve()), 'Distinct owned UI profile')
            if mode == 'restart':
                require(self.batch.steps[1]['complete'] is True and step['profile'] == self.batch.steps[1]['profile'],
                        'Actual successful fresh UI phase before original same-profile restart')
            report = self.read_fixed(output/'report.json')
            require(same(report['identity'], expected_native_identity(self.runtime_fields, self.installed_identity)),
                    'Complete fifteen-field native identity before retained detailed UI checks')
            inherited(step, output, nonce)
            self.integrity()
        return actual_terminal

    def execute(self):
        super().execute()
        require(len(self.batch.steps) == len(self.batch.pids) == len(self.batch.nonces) == 3
                and all(step['complete'] and step['process_terminal'] and step['exit_code'] == 0 for step in self.batch.steps),
                'Three actual distinct successful closed native processes')
        self.integrity()
        self.persist()


def main():
    require(__debug__, 'Assertions must stay enabled')
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--work-root', type=Path, default=Path('D:/CodexTemp/lsh-pending-ui-v6'))
    parser.add_argument('--write-recipe', type=Path)
    parser.add_argument('--write-spec', type=Path)
    parser.add_argument('--prior-durable', type=Path)
    parser.add_argument('--source-spec', type=Path)
    parser.add_argument('--independent-review', type=Path)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    require(args.write_recipe is None or not args.run and args.write_spec is None, 'Recipe preparation never launches')
    if args.write_recipe:
        recipe = source_recipe(args)
        write_new(args.write_recipe, {'recipe_sha256': canonical(recipe), 'recipe': recipe})
        print(json.dumps({'recipe_preflight': True, 'recipe_sha256': canonical(recipe), 'native_started': False}))
        return 0
    spec = source_spec(args)
    logical = canonical(spec)
    if not args.run:
        if args.write_spec:
            write_new(args.write_spec, {'source_spec_sha256': logical, 'spec': spec})
        print(json.dumps({'preflight': True, 'source_spec_sha256': logical, 'prior_closed_checked': True, 'native_started': False}))
        return 0
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None, 'Exact new source seal and independent admission required')
    saved, args.fixed_source_spec_pin = pinned_document(args.source_spec)
    review, args.fixed_independent_review_pin = pinned_document(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == logical
            and review['schema'] == 'campaign_pending_terminal_ui_independent_review_v6'
            and review['independent'] is True and review['static_api_closure_passed'] is True
            and review['complete_consumer_and_phase_reviewed'] is True and review['approved_stages'] == [SCOPE]
            and review['producer_sha256'] == sha(Path(__file__)) and review['probe_sha256'] == sha(predecessor.PROBE)
            and review['source_spec_sha256'] == logical and review['source_spec_file_sha256'] == args.fixed_source_spec_pin['sha256'],
            'Exact new V12 UI native admission; prior V5 and preliminary reviews cannot substitute')
    suite = Suite(args, spec)
    code = 0
    try:
        suite.execute()
    except BaseException as error:
        code = 1
        suite.receipt.update(complete=False, actual_pending_terminal_UI_same_object_retry_qualified=False, failure=repr(error))
    finally:
        try:
            suite.batch.release()
        except BaseException as error:
            code = 1
            suite.receipt.update(complete=False, actual_pending_terminal_UI_same_object_retry_qualified=False, release_failure=repr(error))
        suite.receipt['lock_released'] = not suite.batch.locked
        suite.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist()
        write_new(suite.run/'receipt.json', suite.receipt)
    print(json.dumps({'run': str(suite.run), 'complete': suite.receipt['complete'], 'failure': suite.receipt.get('failure'),
                      'overall_goal_qualified': False}))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
