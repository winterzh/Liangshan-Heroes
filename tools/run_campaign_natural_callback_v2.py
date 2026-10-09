"""Prepare exact callback sources or run cold/callback/same-profile restart.

Recipe preparation grants no execution scope. A native run additionally needs
a successful closed all61 V12 prior and a new independent complete admission.
Earlier ORDER-001 delta review never supplies that admission.
"""
import argparse
import ast
import datetime as dt
import json
from pathlib import Path
import sys
import uuid

from campaign_callback_runtime_v1 import CallbackSerialBatch, CASE
from campaign_natural_callback_evidence_v3 import NaturalCallbackEvidence, MODES
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from run_campaign_file_faults_v3 import Suite as EvidenceSuite, prior_receipt_path, pinned_document
from run_campaign_first_repeat_v1 import Suite as FirstRepeatSuite
from run_durable_campaign_chain_v12 import source_spec as durable_spec, canonical, verify_pin, identity_module
from durable_campaign_full_runtime import FrozenProject, inventory, no_links, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
from durable_campaign_full_matrices import require
import run_steam_integration_qa as native

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
GD = QA / 'callback_natural_driver_candidate_v1/campaign_original19_natural_callback_v1.gd'
SOURCE_MAP = QA / 'callback_observer_candidate_v1/ACTUAL_CALLBACK_SOURCE_MAP_V1.json'
SCOPE = 'one_original19_actual_natural_callback_and_same_profile_restart'


def reviewed_file(row, path):
    verify_pin(row)
    actual = file_pin(path)
    return (Path(row['path']).resolve() == Path(actual['path']).resolve()
            and row['bytes'] == actual['bytes'] and row['sha256'] == actual['sha256'])


def source_recipe(args):
    basis, basis_pin = pinned_document(QA / 'DURABLE_CHAIN_SOURCE_SPEC_V12.json')
    current = durable_spec(args)
    require(current == basis['spec'] and canonical(current) == basis['source_spec_sha256'], 'Exact current approved durable V12 sources')
    full_review, full_review_pin = pinned_document(QA / 'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json')
    require(full_review['independent'] is True and full_review['static_api_closure_passed'] is True
            and full_review['approved_stages'] == ['durable_chain_and_matrices']
            and full_review['source_spec_sha256'] == basis['source_spec_sha256']
            and full_review['source_spec_file_sha256'] == basis_pin['sha256'], 'Exact existing V12 admission only')
    pins = {}
    def adopt(row):
        verify_pin(row)
        require(row['path'] not in pins or pins[row['path']] == row, 'Immutable source pin conflict')
        pins[row['path']] = row
    for row in current['pins']:
        adopt(row)
    component, component_pin = pinned_document(QA / 'NATURAL_CALLBACK_USER_TEXT_SOURCE_SPEC_V1.json')
    delta, delta_pin = pinned_document(QA / 'NATURAL_CALLBACK_USER_TEXT_PRELIMINARY_REVIEW_V1.json')
    require(delta['independent'] is True and delta['limited_delta_only'] is True and delta['static_api_closure_passed'] is True
            and delta['approved_stages'] == [] and delta['source_spec_file_sha256'] == component_pin['sha256']
            and reviewed_file(delta['packet_helper_pin'], ROOT / 'tools/campaign_callback_packet_evidence_v3.py')
            and reviewed_file(delta['natural_consumer_pin'], ROOT / 'tools/campaign_natural_callback_evidence_v3.py'), 'Exact natural USER-TEXT delta review; not complete admission')
    for row in component['pins']:
        adopt(row)
    manifest, manifest_pin = pinned_document(GD.parent / 'SOURCE.json')
    contract, contract_pin = pinned_document(QA / 'CALLBACK_COMPLETE_LABEL_CONTRACT_V1.json')
    parent_manifest, parent_manifest_pin = pinned_document(QA / 'original19_first_repeat_candidate_v1/SOURCE.json')
    require(manifest['pins'][0] == file_pin(GD) == contract['GD'] and manifest['pins'][1] == contract['parent_GD']
            and parent_manifest['candidate'] == contract['parent_GD'] and manifest['case'] == CASE and manifest['required_mode'] == 'first'
            and {k:len(v) for k,v in contract['complete_labels_by_mode'].items()} == {'first':80,'restart_first':21}
            and len(contract['preterminal_ready_labels_by_mode']['first']) == 56, 'Exact callback/parent native sources and complete labels')
    inputs = json.loads(json.dumps(current['inputs']))
    overlays = inputs['runtime_and_harness_overlays']
    # Actual child extends the parent script and loads the read-only observer.
    for row in manifest['pins'][:3]:
        relative = 'tools/' + Path(row['path']).name
        require(relative not in {v['runtime_path'] for v in overlays}, 'Unique native callback dependency overlay')
        overlays.append({**row, 'runtime_path':relative})
    inputs['schema'] = 'campaign_natural_callback_inputs_v1'
    inputs['execution_contract'] = {'native_processes':3,'scope':SCOPE,'modes':list(MODES),'case':CASE,
                                    'same_real_private_profile':True,'Steam_disabled':True,'QA_mode_enabled':False}
    extra = [Path(__file__), QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json', QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json',
             QA/'NATURAL_CALLBACK_USER_TEXT_SOURCE_SPEC_V1.json', QA/'NATURAL_CALLBACK_USER_TEXT_PRELIMINARY_REVIEW_V1.json',
             QA/'CALLBACK_COMPLETE_LABEL_CONTRACT_V1.json', GD.parent/'SOURCE.json',
             QA/'original19_first_repeat_candidate_v1/SOURCE.json', SOURCE_MAP]
    for path in extra:
        adopt(file_pin(path))
    # Close every pinned Python source, including historical source snapshots.
    checked = set()
    edges = []
    while True:
        pending = [Path(row['path']) for row in pins.values() if row['path'].endswith('.py') and row['path'] not in checked]
        if not pending:
            break
        for path in pending:
            checked.add(str(path))
            for node in ast.walk(ast.parse(path.read_bytes(), filename=str(path))):
                modules = [node.module] if isinstance(node,ast.ImportFrom) and node.level == 0 else [v.name for v in node.names] if isinstance(node,ast.Import) else []
                for module in modules:
                    if not module:
                        continue
                    dependency = ROOT/'tools'/(module.split('.')[0]+'.py')
                    if dependency.is_file():
                        edges.append({'source':str(path),'module':module,'target':str(dependency)})
                        adopt(file_pin(dependency))
    for row in pins.values():
        verify_pin(row)
    return {'schema':'campaign_natural_callback_source_recipe_v2','producer':file_pin(Path(__file__)),
            'inputs':inputs,'pins':sorted(pins.values(),key=lambda v:v['path']), 'engine':current['engine'],
            'native_dependencies':current['native_dependencies'],'durable_basis_source_spec_file':basis_pin,
            'durable_basis_independent_review':full_review_pin,'durable_basis_logical_sha256':basis['source_spec_sha256'],
            'callback_delta_review':delta_pin,'full_consumer_independent_admission_obtained':False,
            'execution_scope':SCOPE,'native_processes':3,'full_labels':contract,'manifest':manifest,
            'parent_manifest':parent_manifest,'manifest_file':manifest_pin,'source_map_file':file_pin(SOURCE_MAP),
            'Python_import_edges':edges,'original19_case_mechanisms_included':1,'original19_qualified':False,
            'SDK_reward_once_qualified':False,'UI_qualified':False,'overall_goal_qualified':False}


def source_spec(args):
    recipe = source_recipe(args)
    recipe['schema'] = 'campaign_natural_callback_source_spec_v2'
    recipe['prior_durable_run'] = str(prior_receipt_path(args).parent)
    _, pin = verify_closed_prior_v12(prior_receipt_path(args), recipe)
    recipe['prior_durable_receipt'] = pin
    return recipe


class Suite(EvidenceSuite):
    # Environment and complete report validator retain the reviewed parent API.
    validate = FirstRepeatSuite.validate

    def __init__(self,args,spec):
        self.args,self.spec = args,spec
        require(prior_receipt_path(args) == Path(spec['prior_durable_run'])/'receipt.json', 'Exact sealed successful prior path')
        prior,self.prior_receipt_pin = verify_closed_prior_v12(args.prior_durable,spec)
        require(self.prior_receipt_pin == spec['prior_durable_receipt'], 'First original successful prior bytes unchanged')
        self.prior = self.prior_receipt_pin
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private evidence outside source checkout')
        self.run = args.work_root/('natural_callback_'+uuid.uuid4().hex[:8])
        no_links(self.run)
        self.run.mkdir(parents=True,exist_ok=False)
        self.frozen = FrozenProject(self.run/'project',spec['inputs'])
        self.batch = CallbackSerialBatch(self.run,self.frozen,args.godot,spec['engine']['sha256'],self.persist)
        self.evidence,self.evidence_by_path,self.installed_identity = [],{},None
        for row in [self.prior_receipt_pin,*prior['all_evidence_pins']]:
            self.remember(row)
        for step in prior['steps']:
            self.freeze_bytes(Path(step['output'])/'native.log',step['log_sha256'])
        self.receipt = {'schema':'campaign_natural_callback_batch_v2','run':str(self.run),'started_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
                        'source_spec':spec,'source_spec_sha256':canonical(spec),'source_spec_file':args.fixed_source_spec_pin,
                        'independent_review':args.fixed_review_pin,'prior_durable_receipt':self.prior_receipt_pin,
                        'steps':[],'reports':{},'complete':False,'natural_callback_and_restart_qualified':False,
                        'original19_qualified':False,'SDK_reward_once_qualified':False,'UI_qualified':False,'overall_goal_qualified':False}
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity
        self.persist()

    def values(self,mode,profile):
        parent = FirstRepeatSuite.values(self,mode,profile)
        def build(output,nonce):
            values = parent(output,nonce)
            if mode == 'first':
                values['CAMPAIGN_CALLBACK_CASE'] = CASE
            return values
        return build

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
        self.consumer = NaturalCallbackEvidence(self,self.spec['full_labels'],self.spec['manifest'])
        self.persist()
        profile = self.batch.profile('natural_callback_pair')
        manifest = self.spec['manifest_file']
        source_map = self.spec['source_map_file']
        self.batch.callback_phase(self,manifest['path'],manifest['sha256'],source_map['path'],source_map['sha256'],
                                  profile,self.values('first',profile),self.validate('first'),1800)
        parent = self.spec['parent_manifest']
        self.batch.phase_with_exports(self,'restart_first',parent,'restart_first',profile,
            ['--headless','--script','res://tools/'+Path(parent['candidate']['path']).name],
            self.values('restart_first',profile),self.validate('restart_first'),180)
        self.consumer.require_all()
        require(len(self.batch.steps) == len(self.batch.pids) == len(self.batch.nonces) == 3
                and all(s['complete'] for s in self.batch.steps) and set(self.receipt['reports']) == set(MODES), 'Three distinct closed processes and both complete reports')
        self.integrity()
        self.receipt.update(complete=True,natural_callback_and_restart_qualified=True)
        self.persist()


def main():
    require(__debug__, 'Assertions must stay enabled')
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--work-root',type=Path,default=Path('D:/CodexTemp/lsh-natural-callback'))
    parser.add_argument('--write-recipe',type=Path)
    parser.add_argument('--write-spec',type=Path)
    parser.add_argument('--prior-durable',type=Path)
    parser.add_argument('--source-spec',type=Path)
    parser.add_argument('--independent-review',type=Path)
    parser.add_argument('--run',action='store_true')
    args = parser.parse_args()
    require(args.write_recipe is None or not args.run and args.write_spec is None, 'Source recipe cannot launch or claim prior success')
    if args.write_recipe:
        recipe = source_recipe(args)
        write_new(args.write_recipe,{'recipe_sha256':canonical(recipe),'recipe':recipe})
        print(json.dumps({'recipe_preflight':True,'recipe_sha256':canonical(recipe),'prior_closed_checked':False,'native_started':False}))
        return 0
    spec = source_spec(args)
    logical = canonical(spec)
    if not args.run:
        if args.write_spec:
            write_new(args.write_spec,{'source_spec_sha256':logical,'spec':spec})
        print(json.dumps({'preflight':True,'source_spec_sha256':logical,'prior_closed_checked':True,'native_started':False}))
        return 0
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None, 'Exact seal and new complete independent admission required')
    saved,args.fixed_source_spec_pin = pinned_document(args.source_spec)
    review,args.fixed_review_pin = pinned_document(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == logical
            and review['schema'] == 'campaign_natural_callback_independent_review_v2' and review['independent'] is True
            and review['static_api_closure_passed'] is True and review['complete_consumer_and_phase_reviewed'] is True
            and review['approved_stages'] == [SCOPE] and review['producer_sha256'] == sha(Path(__file__))
            and review['source_spec_sha256'] == logical and review['source_spec_file_sha256'] == args.fixed_source_spec_pin['sha256'], 'Exact complete source admission; delta receipt refused')
    suite = Suite(args,spec)
    code = 0
    try:
        suite.execute()
    except BaseException as error:
        code = 1
        suite.receipt.update(complete=False,natural_callback_and_restart_qualified=False,failure=repr(error))
    finally:
        try:
            suite.batch.release()
        except BaseException as error:
            code = 1
            suite.receipt.update(complete=False,natural_callback_and_restart_qualified=False)
            suite.receipt.setdefault('finalization_failures',[]).append(repr(error))
        suite.receipt['lock_released'] = not suite.batch.locked
        suite.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist()
        write_new(suite.run/'receipt.json',suite.receipt)
        print(json.dumps({'run':str(suite.run),'complete':suite.receipt['complete'],'failure':suite.receipt.get('failure'),'overall_goal_qualified':False}))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
