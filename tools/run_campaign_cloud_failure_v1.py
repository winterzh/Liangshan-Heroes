"""Prepare or execute one real SDK-disabled cloud write-failure boundary.

Execution requires the closed successful all61 durable prior, an exact new
source seal and independent admission. This is not the complete original19 case.
"""
import argparse
import ast
import datetime as dt
import json
from pathlib import Path
import sys
import uuid

from campaign_cloud_failure_evidence_v2 import CASE, CloudFailureEvidence
from campaign_cloud_failure_runtime_v1 import CloudFailureSerialBatch
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from run_campaign_file_faults_v3 import Suite as EvidenceSuite, prior_receipt_path, pinned_document
from run_durable_campaign_chain_v12 import source_spec as durable_spec, canonical, verify_pin, identity_module
from durable_campaign_full_runtime import FrozenProject, inventory, no_links, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
from durable_campaign_full_matrices import require
import run_steam_integration_qa as native

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT/'qa/campaign_progress_recovery_20261008'
SCOPE = 'one_actual_SDK_disabled_cloud_write_failure_boundary'


def source_recipe(args):
    basis, basis_pin = pinned_document(QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json')
    current = durable_spec(args)
    require(current == basis['spec'] and canonical(current) == basis['source_spec_sha256'],
            'Exact approved durable V12 source basis')
    durable_review, durable_review_pin = pinned_document(QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json')
    require(durable_review['independent'] is True and durable_review['static_api_closure_passed'] is True
            and durable_review['approved_stages'] == ['durable_chain_and_matrices']
            and durable_review['source_spec_sha256'] == basis['source_spec_sha256']
            and durable_review['source_spec_file_sha256'] == basis_pin['sha256'],
            'Original prior admission remains limited to V12')
    component, component_pin = pinned_document(QA/'CLOUD_FAILURE_RUNTIME_SOURCE_SPEC_V2.json')
    require(component['source_spec_sha256'] == canonical(component['spec']), 'Exact immutable linked consumer/runtime basis')
    pins = {}

    def adopt(row):
        verify_pin(row)
        require(row['path'] not in pins or pins[row['path']] == row, 'No conflicting original source pin')
        pins[row['path']] = row

    for row in [*current['pins'], *component['spec']['pins'], component_pin, basis_pin, durable_review_pin]:
        adopt(row)
    manifest, manifest_pin = pinned_document(component['spec']['candidate_manifest']['path'])
    labels, labels_pin = pinned_document(component['spec']['label_contract']['path'])
    require(manifest_pin == component['spec']['candidate_manifest'] and labels_pin == component['spec']['label_contract']
            and manifest['candidate'] == labels['GD'] and manifest['parent_GD'] == labels['parent_GD']
            and manifest['case'] == CASE and manifest['required_mode'] == 'first'
            and labels['source_label_count'] == len(labels['complete_local_boundary_labels']) == 40,
            'Whole fixed native driver and failure-boundary contract')
    recipe, recipe_pin = pinned_document(manifest['source_recipe_basis']['path'])
    require(recipe_pin == manifest['source_recipe_basis']
            and recipe['recipe_sha256'] == manifest['source_recipe_basis_logical_sha256'] == canonical(recipe['recipe'])
            and recipe['recipe']['engine'] == current['engine']
            and recipe['recipe']['native_dependencies'] == current['native_dependencies'],
            'Actual original engine and native dependency source basis')
    inputs = json.loads(json.dumps(manifest['inputs']))
    inputs['schema'] = 'campaign_cloud_failure_inputs_v1'
    inputs['execution_contract'] = {'native_processes': 2, 'case': CASE, 'scope': SCOPE,
                                    'fresh_private_profile': True, 'Steam_disabled': True,
                                    'QA_mode_enabled': False, 'synthetic_local_owner': '1'}
    for key in ['candidate', 'parent_GD']:
        row = manifest[key]
        alias = 'tools/'+Path(row['path']).name
        matches = [v for v in inputs['runtime_and_harness_overlays'] if v['runtime_path'] == alias]
        require(len(matches) == 1 and all(matches[0][k] == row[k] for k in ['path', 'bytes', 'sha256']),
                'Exact installed native aliases in the preserved full input set')
    for row in [manifest_pin, labels_pin, recipe_pin, file_pin(Path(__file__))]:
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
    return {'schema': 'campaign_cloud_failure_source_recipe_v1', 'producer': file_pin(Path(__file__)),
            'inputs': inputs, 'pins': sorted(pins.values(), key=lambda row: row['path']), 'Python_import_edges': edges,
            'engine': current['engine'], 'native_dependencies': current['native_dependencies'],
            'durable_basis_source_spec_file': basis_pin, 'durable_basis_independent_review': durable_review_pin,
            'durable_basis_logical_sha256': basis['source_spec_sha256'], 'consumer_runtime_basis': component_pin,
            'manifest': manifest, 'manifest_file': manifest_pin, 'labels': labels, 'labels_file': labels_pin,
            'execution_scope': SCOPE, 'native_processes': 2, 'boundary_producer_implemented': True,
            'full_original19_case_producer_implemented': False, 'full_chain_independent_admission_obtained': False,
            'successful_authorized_retry_qualified': False, 'same_profile_restart_qualified': False,
            'original19_qualified': False, 'SDK_reward_once_qualified': False, 'Steam_account_qualified': False,
            'upload_qualified': False, 'UI_qualified': False, 'overall_goal_qualified': False}


def source_spec(args):
    spec = source_recipe(args)
    spec['schema'] = 'campaign_cloud_failure_source_spec_v1'
    spec['prior_durable_run'] = str(prior_receipt_path(args).parent)
    _, pin = verify_closed_prior_v12(prior_receipt_path(args), spec)
    spec['prior_durable_receipt'] = pin
    return spec


class Suite(EvidenceSuite):
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        require(prior_receipt_path(args) == Path(spec['prior_durable_run'])/'receipt.json', 'Exact sealed successful prior path')
        prior, self.prior_receipt_pin = verify_closed_prior_v12(args.prior_durable, spec)
        require(self.prior_receipt_pin == spec['prior_durable_receipt'], 'Successful original prior remains unchanged before any run directory')
        self.prior = self.prior_receipt_pin
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private evidence outside source checkout')
        self.run = args.work_root/('cloud_failure_'+uuid.uuid4().hex[:8])
        no_links(self.run)
        self.run.mkdir(parents=True, exist_ok=False)
        self.frozen = FrozenProject(self.run/'project', spec['inputs'])
        self.batch = CloudFailureSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist)
        self.evidence, self.evidence_by_path, self.installed_identity = [], {}, None
        for row in [self.prior_receipt_pin, *prior['all_evidence_pins']]:
            self.remember(row)
        for step in prior['steps']:
            self.freeze_bytes(Path(step['output'])/'native.log', step['log_sha256'])
        self.receipt = {'schema': 'campaign_cloud_failure_batch_v1', 'run': str(self.run),
                        'started_utc': dt.datetime.now(dt.timezone.utc).isoformat(), 'source_spec': spec,
                        'source_spec_sha256': canonical(spec), 'source_spec_file': args.fixed_source_spec_pin,
                        'independent_review': args.fixed_review_pin, 'prior_durable_receipt': self.prior_receipt_pin,
                        'steps': [], 'reports': {}, 'complete': False, 'local_failure_boundary_qualified': False,
                        'successful_authorized_retry_qualified': False, 'same_profile_restart_qualified': False,
                        'original19_qualified': False, 'SDK_reward_once_qualified': False,
                        'Steam_account_qualified': False, 'upload_qualified': False, 'UI_qualified': False,
                        'overall_goal_qualified': False}
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity
        self.persist()

    def values(self, profile):
        def build(output, nonce):
            pin = self.evidence_by_path[str(self.identity_path.resolve()).casefold()]
            return {'CAMPAIGN_CALLBACK_CASE': CASE, 'CAMPAIGN_TERMINAL_OUTPUT': str(output),
                    'CAMPAIGN_TERMINAL_NONCE': nonce, 'CAMPAIGN_TERMINAL_MODE': 'first',
                    'CAMPAIGN_TERMINAL_PROFILE': str(profile), 'CAMPAIGN_TERMINAL_TOKEN': '',
                    'CAMPAIGN_TERMINAL_EXPECT_RECOVERY': '0', 'CAMPAIGN_TERMINAL_IDENTITY_FILE': str(self.identity_path),
                    'CAMPAIGN_TERMINAL_IDENTITY_SHA256': pin['sha256'], 'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE': '',
                    'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256': '', 'CAMPAIGN_TERMINAL_PRIOR_TOKEN': ''}
        return build

    def validate(self, step, output, nonce):
        self.receipt['reports']['cloud_write_failure'] = self.consumer.validate(step)
        self.persist()

    def execute(self):
        self.frozen.prepare()
        require(native.install_native(self.frozen.project) == self.spec['native_dependencies'], 'Exact isolated native installation')
        self.frozen.before = inventory(self.frozen.project)
        self.batch.phase('cold_import', self.batch.profile('import'), ['--headless', '--editor', '--import'], {}, lambda *args: None, 1200)
        self.frozen.freeze_cold()
        identity = identity_module().installed_identity(self.frozen.project)
        self.installed_identity = identity
        self.runtime_fields = {k: identity[k] for k in ['content_version', 'rules_sha256', 'file_count', 'total_bytes']}
        self.runtime_fields.update(engine_binary_sha256=sha(self.args.godot), provider_sha256=sha(self.frozen.project/'scripts/run_content_identity.gd'))
        self.identity_path = self.run/'post_cold_identity.json'
        write_new(self.identity_path, {'runtime_fields': self.runtime_fields, 'complete_identity': identity})
        self.freeze_bytes(self.identity_path)
        self.consumer = CloudFailureEvidence(self, self.spec['labels'], self.spec['manifest'])
        profile = self.batch.profile('cloud_write_failure')
        self.batch.cloud_failure_phase(self, profile, self.values(profile), self.validate, 180)
        require(self.consumer.completed and len(self.batch.steps) == len(self.batch.pids) == len(self.batch.nonces) == 2
                and all(step['complete'] for step in self.batch.steps)
                and set(self.receipt['reports']) == {'cloud_write_failure'}, 'Two actual distinct terminal processes and whole failure evidence')
        self.integrity()
        self.receipt.update(complete=True, local_failure_boundary_qualified=True)
        self.persist()


def main():
    require(__debug__, 'Assertions must stay enabled')
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--work-root', type=Path, default=Path('D:/CodexTemp/lsh-cloud-failure'))
    parser.add_argument('--write-recipe', type=Path)
    parser.add_argument('--write-spec', type=Path)
    parser.add_argument('--prior-durable', type=Path)
    parser.add_argument('--source-spec', type=Path)
    parser.add_argument('--independent-review', type=Path)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    require(args.write_recipe is None or not args.run and args.write_spec is None, 'Recipe-only mode never launches')
    if args.write_recipe:
        recipe = source_recipe(args)
        write_new(args.write_recipe, {'recipe_sha256': canonical(recipe), 'recipe': recipe})
        print(json.dumps({'recipe_preflight': True, 'recipe_sha256': canonical(recipe), 'prior_closed_checked': False, 'native_started': False}))
        return 0
    spec = source_spec(args)
    logical = canonical(spec)
    if not args.run:
        if args.write_spec:
            write_new(args.write_spec, {'source_spec_sha256': logical, 'spec': spec})
        print(json.dumps({'preflight': True, 'source_spec_sha256': logical, 'prior_closed_checked': True, 'native_started': False}))
        return 0
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None, 'Exact seal and complete boundary-chain admission required')
    saved, args.fixed_source_spec_pin = pinned_document(args.source_spec)
    review, args.fixed_review_pin = pinned_document(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == logical
            and review['schema'] == 'campaign_cloud_failure_independent_review_v1' and review['independent'] is True
            and review['static_api_closure_passed'] is True and review['complete_consumer_and_phase_reviewed'] is True
            and review['approved_stages'] == [SCOPE] and review['producer_sha256'] == sha(Path(__file__))
            and review['source_spec_sha256'] == logical and review['source_spec_file_sha256'] == args.fixed_source_spec_pin['sha256'],
            'New exact native admission, no preliminary receipt substitution')
    suite = Suite(args, spec)
    code = 0
    try:
        suite.execute()
    except BaseException as error:
        code = 1
        suite.receipt.update(complete=False, local_failure_boundary_qualified=False, failure=repr(error))
    finally:
        try:
            suite.batch.release()
        except BaseException as error:
            code = 1
            suite.receipt.update(complete=False, local_failure_boundary_qualified=False)
            suite.receipt.setdefault('finalization_failures', []).append(repr(error))
        suite.receipt['lock_released'] = not suite.batch.locked
        suite.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist()
        write_new(suite.run/'receipt.json', suite.receipt)
        print(json.dumps({'run': str(suite.run), 'complete': suite.receipt['complete'],
                          'failure': suite.receipt.get('failure'), 'overall_goal_qualified': False}))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
