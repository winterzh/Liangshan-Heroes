"""Prepare or execute actual cold/cloud-apply/ordinary same-profile restart.

Recipe-only mode never starts native work. Execution requires a successful
closed all61 V12 prior, exact source seal and independent full-chain admission.
"""
import argparse
import ast
import datetime as dt
import json
from pathlib import Path
import sys
import uuid

from campaign_cloud_case_runtime_v1 import CloudCaseSerialBatch, CASE
from campaign_cloud_restart_evidence_v1 import CloudCaseEvidence
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from run_campaign_file_faults_v3 import Suite as EvidenceSuite, prior_receipt_path, pinned_document
from run_durable_campaign_chain_v12 import source_spec as durable_spec, canonical, verify_pin, identity_module
from durable_campaign_full_runtime import FrozenProject, inventory, no_links, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
from durable_campaign_full_matrices import require
import run_steam_integration_qa as native

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT/'qa/campaign_progress_recovery_20261008'
SCOPE = 'one_original19_actual_cloud_applying_callback_and_same_profile_restart'
SOURCE_MAP = QA/'callback_observer_candidate_v1/ACTUAL_CALLBACK_SOURCE_MAP_V1.json'


def source_recipe(args):
    basis,basis_pin = pinned_document(QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json')
    current = durable_spec(args)
    require(current == basis['spec'] and canonical(current) == basis['source_spec_sha256'], 'Exact approved durable V12 source basis')
    full_review,full_review_pin = pinned_document(QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json')
    require(full_review['independent'] is True and full_review['static_api_closure_passed'] is True
            and full_review['approved_stages'] == ['durable_chain_and_matrices']
            and full_review['source_spec_sha256'] == basis['source_spec_sha256']
            and full_review['source_spec_file_sha256'] == basis_pin['sha256'], 'Original V12 admission remains limited to V12')
    component,component_pin = pinned_document(QA/'CLOUD_NATIVE_USER_TEXT_SOURCE_SPEC_V1.json')
    delta,delta_pin = pinned_document(QA/'CLOUD_NATIVE_USER_TEXT_PRELIMINARY_REVIEW_V1.json')
    require(delta['independent'] is True and delta['static_api_closure_passed'] is True and delta['approved_stages'] == []
            and delta['source_spec_file_sha256'] == component_pin['sha256']
            and all(sha(ROOT/'tools'/name) == digest for name,digest in delta['reviewed_helpers'].items()),
            'Exact cloud raw-user-text component review, never execution admission')
    pins = {}
    def adopt(row):
        verify_pin(row)
        require(row['path'] not in pins or pins[row['path']] == row, 'Original source pin conflict or drift')
        pins[row['path']] = row
    for row in [*current['pins'],*component['pins']]:adopt(row)
    first_dir = QA/'cloud_applying_driver_candidate_v3'
    restart_dir = QA/'cloud_restart_driver_candidate_v1'
    first,first_pin = pinned_document(first_dir/'SOURCE.json')
    first_labels,first_labels_pin = pinned_document(first_dir/'COMPLETE_LABEL_CONTRACT_V3.json')
    restart,restart_pin = pinned_document(restart_dir/'SOURCE.json')
    restart_labels,restart_labels_pin = pinned_document(restart_dir/'COMPLETE_LABEL_CONTRACT_V1.json')
    require(first['candidate'] == first_labels['GD'] and first['parent_GD'] == first_labels['parent_GD']
            and first['case'] == CASE and first['required_mode'] == 'first' and len(first_labels['complete_labels']) == 40
            and restart['candidate'] == restart_labels['GD'] and restart['parent_GD'] == first['parent_GD'] == restart_labels['parent_GD']
            and restart['first_driver'] == first['candidate'] and restart['case'] == CASE
            and restart['required_mode'] == 'restart_first' and len(restart_labels['complete_labels']) == 33,
            'Exact full first-cloud and ordinary-restart native source/label contracts')
    inputs = json.loads(json.dumps(current['inputs']))
    overlays = inputs['runtime_and_harness_overlays']
    for row in [first[k] for k in ['candidate','parent_GD','observer_GD','observer_parent_GD']]+[restart['candidate']]:
        adopt(row)
        alias = 'tools/'+Path(row['path']).name
        require(alias not in {v['runtime_path'] for v in overlays}, 'Unique cloud native dependency runtime alias')
        overlays.append({**row,'runtime_path':alias})
    for row in first['production_runtime_sources']+restart['startup_dependencies']:
        adopt({k:row[k] for k in ['path','bytes','sha256']})
    preliminary = []
    for path in [restart_dir/'INDEPENDENT_SOURCE_REVIEW_V1.json',QA/'CLOUD_RESTART_CONSUMER_PRELIMINARY_REVIEW_V1.json']:
        review,pin = pinned_document(path)
        detail = review['review']
        require(detail['review_kind'] == 'finite_readonly_source_review'
                and detail['status'] == 'SOURCE_REVIEW_COMPLETE_NATIVE_CHAIN_INCOMPLETE'
                and detail['approved_stages'] == [] and detail['native_qualification'] is False,
                'Original finite restart review retained, not promoted to admission')
        for row in detail['source_pins']:
            actual = file_pin(ROOT/row['path'])
            require(all(actual[k] == row[k] for k in ['bytes','sha256']), 'Exact independently reviewed restart source bytes')
            adopt(actual)
        adopt(pin)
        preliminary.append(pin)
    inputs['schema'] = 'campaign_cloud_case_inputs_v1'
    inputs['execution_contract'] = {'native_processes':3,'case':CASE,'scope':SCOPE,'same_real_private_profile':True,
                                    'Steam_disabled':True,'QA_mode_enabled':False,'synthetic_local_owner':'1'}
    for path in [Path(__file__),QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json',QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json',
                 QA/'CLOUD_NATIVE_USER_TEXT_SOURCE_SPEC_V1.json',QA/'CLOUD_NATIVE_USER_TEXT_PRELIMINARY_REVIEW_V1.json',
                 first_dir/'SOURCE.json',first_dir/'COMPLETE_LABEL_CONTRACT_V3.json',restart_dir/'SOURCE.json',
                 restart_dir/'COMPLETE_LABEL_CONTRACT_V1.json',restart_dir/'HOST_SOURCE.json',restart_dir/'REVIEW_SCOPE_V1.md',
                 SOURCE_MAP,ROOT/'tools/campaign_cloud_case_runtime_v1.py',ROOT/'tools/campaign_cloud_restart_exports_v1.py',
                 ROOT/'tools/campaign_cloud_restart_evidence_v1.py']:
        adopt(file_pin(path))
    checked,edges = set(),[]
    while True:
        pending = [Path(row['path']) for row in pins.values() if row['path'].endswith('.py') and row['path'] not in checked]
        if not pending:break
        for path in pending:
            checked.add(str(path))
            for node in ast.walk(ast.parse(path.read_bytes(),filename=str(path))):
                modules = [node.module] if isinstance(node,ast.ImportFrom) and node.level == 0 else [v.name for v in node.names] if isinstance(node,ast.Import) else []
                for module in modules:
                    if not module:continue
                    dependency = ROOT/'tools'/(module.split('.')[0]+'.py')
                    if dependency.is_file():
                        edges.append({'source':str(path),'module':module,'target':str(dependency)})
                        adopt(file_pin(dependency))
    for row in pins.values():verify_pin(row)
    return {'schema':'campaign_cloud_case_source_recipe_v1','producer':file_pin(Path(__file__)),
            'inputs':inputs,'pins':sorted(pins.values(),key=lambda row:row['path']),'Python_import_edges':edges,
            'engine':current['engine'],'native_dependencies':current['native_dependencies'],
            'durable_basis_source_spec_file':basis_pin,'durable_basis_independent_review':full_review_pin,
            'durable_basis_logical_sha256':basis['source_spec_sha256'],'cloud_delta_review':delta_pin,
            'restart_preliminary_reviews':preliminary,'first_manifest':first,'first_manifest_file':first_pin,
            'first_labels':first_labels,'first_labels_file':first_labels_pin,'restart_manifest':restart,
            'restart_manifest_file':restart_pin,'restart_labels':restart_labels,'restart_labels_file':restart_labels_pin,
            'source_map_file':file_pin(SOURCE_MAP),'execution_scope':SCOPE,'native_processes':3,
            'full_chain_independent_admission_obtained':False,'original19_case_mechanisms_included':1,
            'original19_qualified':False,'SDK_reward_once_qualified':False,'Steam_account_qualified':False,
            'upload_qualified':False,'UI_qualified':False,'overall_goal_qualified':False}


def source_spec(args):
    spec = source_recipe(args)
    spec['schema'] = 'campaign_cloud_case_source_spec_v1'
    spec['prior_durable_run'] = str(prior_receipt_path(args).parent)
    _,pin = verify_closed_prior_v12(prior_receipt_path(args),spec)
    spec['prior_durable_receipt'] = pin
    return spec


class Suite(EvidenceSuite):
    def __init__(self,args,spec):
        self.args,self.spec = args,spec
        require(prior_receipt_path(args) == Path(spec['prior_durable_run'])/'receipt.json', 'Exact sealed successful prior path')
        prior,self.prior_receipt_pin = verify_closed_prior_v12(args.prior_durable,spec)
        require(self.prior_receipt_pin == spec['prior_durable_receipt'], 'First successful prior bytes unchanged before any run directory')
        self.prior = self.prior_receipt_pin
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private evidence outside source checkout')
        self.run = args.work_root/('cloud_case_'+uuid.uuid4().hex[:8])
        no_links(self.run)
        self.run.mkdir(parents=True,exist_ok=False)
        self.frozen = FrozenProject(self.run/'project',spec['inputs'])
        self.batch = CloudCaseSerialBatch(self.run,self.frozen,args.godot,spec['engine']['sha256'],self.persist)
        self.evidence,self.evidence_by_path,self.installed_identity = [],{},None
        for row in [self.prior_receipt_pin,*prior['all_evidence_pins']]:self.remember(row)
        for step in prior['steps']:self.freeze_bytes(Path(step['output'])/'native.log',step['log_sha256'])
        self.receipt = {'schema':'campaign_cloud_case_batch_v1','run':str(self.run),'started_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
                        'source_spec':spec,'source_spec_sha256':canonical(spec),'source_spec_file':args.fixed_source_spec_pin,
                        'independent_review':args.fixed_review_pin,'prior_durable_receipt':self.prior_receipt_pin,
                        'steps':[],'reports':{},'complete':False,'local_cloud_callback_and_restart_qualified':False,
                        'original19_qualified':False,'Steam_account_qualified':False,'upload_qualified':False,
                        'SDK_reward_once_qualified':False,'UI_qualified':False,'overall_goal_qualified':False}
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity
        self.persist()

    def values(self,mode,profile):
        require(mode in ['first','restart_first'], 'Only the two actual cloud case modes')
        def build(output,nonce):
            pin = self.evidence_by_path[str(self.identity_path.resolve()).casefold()]
            values = {'CAMPAIGN_CALLBACK_CASE':CASE,'CAMPAIGN_TERMINAL_OUTPUT':str(output),'CAMPAIGN_TERMINAL_NONCE':nonce,
                      'CAMPAIGN_TERMINAL_MODE':mode,'CAMPAIGN_TERMINAL_PROFILE':str(profile),'CAMPAIGN_TERMINAL_TOKEN':'',
                      'CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0','CAMPAIGN_TERMINAL_IDENTITY_FILE':str(self.identity_path),
                      'CAMPAIGN_TERMINAL_IDENTITY_SHA256':pin['sha256'],'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE':'',
                      'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256':'','CAMPAIGN_TERMINAL_PRIOR_TOKEN':''}
            if mode == 'restart_first':
                first = self.consumer.first_step
                require(first is not None and first['complete'] is True, 'Only original actually completed first cloud report')
                values.update(CAMPAIGN_CLOUD_PRIOR_REPORT_FILE=str(Path(first['output'])/'report.json'),
                              CAMPAIGN_CLOUD_PRIOR_REPORT_SHA256=first['actual_native_exports']['report.json']['sha256'])
            return values
        return build

    def validate(self,mode):
        def validator(step,output,nonce):
            self.receipt['reports'][mode] = self.consumer.validate_first(step) if mode == 'first' else self.consumer.validate_restart(step)
            self.persist()
        return validator

    def execute(self):
        self.frozen.prepare()
        require(native.install_native(self.frozen.project) == self.spec['native_dependencies'], 'Exact isolated native installation')
        self.frozen.before = inventory(self.frozen.project)
        self.batch.phase('cold_import',self.batch.profile('import'),['--headless','--editor','--import'],{},lambda *args:None,1200)
        self.frozen.freeze_cold()
        identity = identity_module().installed_identity(self.frozen.project)
        self.installed_identity = identity
        self.runtime_fields = {k:identity[k] for k in ['content_version','rules_sha256','file_count','total_bytes']}
        self.runtime_fields.update(engine_binary_sha256=sha(self.args.godot),provider_sha256=sha(self.frozen.project/'scripts/run_content_identity.gd'))
        self.identity_path = self.run/'post_cold_identity.json'
        write_new(self.identity_path,{'runtime_fields':self.runtime_fields,'complete_identity':identity})
        self.freeze_bytes(self.identity_path)
        self.consumer = CloudCaseEvidence(self,self.spec['first_labels'],self.spec['first_manifest'],self.spec['restart_labels'],self.spec['restart_manifest'])
        self.persist()
        profile = self.batch.profile('cloud_case_pair')
        first,source_map = self.spec['first_manifest_file'],self.spec['source_map_file']
        self.batch.cloud_apply_phase(self,first['path'],first['sha256'],source_map['path'],source_map['sha256'],
                                     profile,self.values('first',profile),self.validate('first'),1800)
        restart = self.spec['restart_manifest_file']
        self.batch.cloud_restart_phase(self,restart['path'],restart['sha256'],profile,self.values('restart_first',profile),self.validate('restart_first'),180)
        self.consumer.require_all()
        require(len(self.batch.steps) == len(self.batch.pids) == len(self.batch.nonces) == 3
                and all(step['complete'] for step in self.batch.steps) and set(self.receipt['reports']) == {'first','restart_first'},
                'Three actual distinct closed successful processes and two full reports')
        self.integrity()
        self.receipt.update(complete=True,local_cloud_callback_and_restart_qualified=True)
        self.persist()


def main():
    require(__debug__, 'Assertions must stay enabled')
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--work-root',type=Path,default=Path('D:/CodexTemp/lsh-cloud-case'))
    parser.add_argument('--write-recipe',type=Path)
    parser.add_argument('--write-spec',type=Path)
    parser.add_argument('--prior-durable',type=Path)
    parser.add_argument('--source-spec',type=Path)
    parser.add_argument('--independent-review',type=Path)
    parser.add_argument('--run',action='store_true')
    args = parser.parse_args()
    require(args.write_recipe is None or not args.run and args.write_spec is None, 'Recipe mode never launches or claims successful prior')
    if args.write_recipe:
        recipe = source_recipe(args)
        write_new(args.write_recipe,{'recipe_sha256':canonical(recipe),'recipe':recipe})
        print(json.dumps({'recipe_preflight':True,'recipe_sha256':canonical(recipe),'prior_closed_checked':False,'native_started':False}))
        return 0
    spec = source_spec(args)
    logical = canonical(spec)
    if not args.run:
        if args.write_spec:write_new(args.write_spec,{'source_spec_sha256':logical,'spec':spec})
        print(json.dumps({'preflight':True,'source_spec_sha256':logical,'prior_closed_checked':True,'native_started':False}))
        return 0
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None, 'Exact seal and full-chain independent admission required')
    saved,args.fixed_source_spec_pin = pinned_document(args.source_spec)
    review,args.fixed_review_pin = pinned_document(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == logical
            and review['schema'] == 'campaign_cloud_case_independent_review_v1' and review['independent'] is True
            and review['static_api_closure_passed'] is True and review['complete_consumer_and_phase_reviewed'] is True
            and review['approved_stages'] == [SCOPE] and review['producer_sha256'] == sha(Path(__file__))
            and review['source_spec_sha256'] == logical and review['source_spec_file_sha256'] == args.fixed_source_spec_pin['sha256'],
            'Exact new complete-chain native admission, no preliminary receipt substitution')
    suite = Suite(args,spec)
    code = 0
    try:suite.execute()
    except BaseException as error:
        code = 1
        suite.receipt.update(complete=False,local_cloud_callback_and_restart_qualified=False,failure=repr(error))
    finally:
        try:suite.batch.release()
        except BaseException as error:
            code = 1
            suite.receipt.update(complete=False,local_cloud_callback_and_restart_qualified=False)
            suite.receipt.setdefault('finalization_failures',[]).append(repr(error))
        suite.receipt['lock_released'] = not suite.batch.locked
        suite.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist()
        write_new(suite.run/'receipt.json',suite.receipt)
        print(json.dumps({'run':str(suite.run),'complete':suite.receipt['complete'],'failure':suite.receipt.get('failure'),'overall_goal_qualified':False}))
    return code


if __name__ == '__main__':raise SystemExit(main())
