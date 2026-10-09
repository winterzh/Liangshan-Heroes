"""Retained JSON533/OwnedSlot76/admission ABC checks after a closed V12 prior.

V4 sources and predicates remain unchanged. Recipe-only never launches native;
execution needs a successful all61 prior, exact successor seal and admission.
"""
import argparse
import ast
import datetime as dt
import json
from pathlib import Path
import subprocess
import sys
import uuid

from campaign_admission_regression_runtime_v1 import OwnedSerialBatch
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from durable_campaign_full_runtime import FrozenProject, no_links, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
from durable_campaign_full_matrices import require
from run_campaign_file_faults_v3 import prior_receipt_path, pinned_document
from run_durable_campaign_chain_v12 import canonical, source_spec as durable_spec, identity_module, verify_pin
import run_campaign_admission_regressions_v4 as predecessor

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT/'qa/campaign_progress_recovery_20261008'
SCOPE = 'original_JSON_OwnedSlot_and_campaign_admission_after_V12'


def source_recipe(args):
    current = durable_spec(args)
    basis, basis_pin = pinned_document(QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json')
    current_review, current_review_pin = pinned_document(QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json')
    require(current == basis['spec'] and canonical(current) == basis['source_spec_sha256']
            and current_review['independent'] is True and current_review['static_api_closure_passed'] is True
            and current_review['approved_stages'] == ['durable_chain_and_matrices']
            and current_review['source_spec_sha256'] == basis['source_spec_sha256']
            and current_review['source_spec_file_sha256'] == basis_pin['sha256'], 'Exact approved current V12 basis')
    original, original_pin = pinned_document(QA/'ADMISSION_REGRESSION_SOURCE_SPEC_V4.json')
    original_review, original_review_pin = pinned_document(QA/'ADMISSION_REGRESSION_INDEPENDENT_REVIEW_V4.json')
    old = original['spec']
    require(canonical(old) == original['source_spec_sha256'] and original_review['independent'] is True
            and original_review['static_api_closure_passed'] is True
            and original_review['approved_stages'] == [predecessor.SCOPE]
            and original_review['source_spec_sha256'] == original['source_spec_sha256']
            and original_review['source_spec_file_sha256'] == original_pin['sha256']
            and original_review['producer_sha256'] == sha(Path(predecessor.__file__)),
            'Retained exact V4 source and scoped review, never transferred V9 authority')
    inputs = json.loads(json.dumps(current['inputs']))
    aliases = {row['runtime_path']:row for row in inputs['runtime_and_harness_overlays']}
    old_aliases = {row['runtime_path']:row for row in old['inputs']['runtime_and_harness_overlays']}
    admission_alias = 'tools/'+predecessor.GD
    require(admission_alias in aliases and admission_alias in old_aliases, 'Known admission driver alias in current complete inputs')
    extra_aliases = {'tools/native_ownership_json_boundary_v24q1.gd','tools/native_ownership_json_boundary_v24q1.tscn',
                     'tools/owned_slot_retry_qa.gd','tools/owned_slot_retry_qa.tscn'}
    require(set(old_aliases)-set(aliases) == extra_aliases, 'Exactly four retained pure regression native dependencies')
    inputs['runtime_and_harness_overlays'] = [old_aliases[admission_alias] if row['runtime_path'] == admission_alias else row
                                             for row in inputs['runtime_and_harness_overlays']]
    inputs['runtime_and_harness_overlays'].extend(old_aliases[name] for name in sorted(extra_aliases))
    require(len({row['runtime_path'].casefold() for row in inputs['runtime_and_harness_overlays']})
            == len(inputs['runtime_and_harness_overlays']), 'All complete installed aliases unique')
    manifest, manifest_pin = pinned_document(predecessor.CONSUMER/'SOURCE.json')
    for row in manifest['runtime_sources']+manifest['actual_semantic_Core_Contract']:
        require(any(all(candidate[key] == row[key] for key in ['path','bytes','sha256'])
                    for candidate in inputs['runtime_and_harness_overlays']), 'Retained admission production sources match current V12 runtime inputs')
    require(old['JSON_checks'] == 533 and old['OwnedSlot_checks'] == 76
            and old['admission_cases'] == list(predecessor.CASES)
            and old['pure_QA_labels'] == ['json_boundary','owned_slot_retry'], 'All original six-process cases retained')
    pins = {}

    def adopt(row):
        verify_pin(row)
        require(row['path'] not in pins or pins[row['path']] == row, 'Immutable predecessor source pin conflict')
        pins[row['path']] = row

    for row in [*current['pins'], *old['pins'], basis_pin, current_review_pin, original_pin, original_review_pin,
                manifest_pin, file_pin(Path(__file__))]:
        adopt(row)
    checked, edges = set(), []
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
    inputs['schema'] = 'campaign_admission_regression_inputs_v5'
    inputs['execution_contract'] = {'native_processes':6, 'JSON_checks':533, 'OwnedSlot_checks':76,
                                   'admission_cases':list(predecessor.CASES), 'normal_CAMPAIGN_QA_empty':True,
                                   'pure_QA_labels':['json_boundary','owned_slot_retry'],
                                   'default_slot_root':'user://continue/v1', 'overall_goal_qualified':False}
    return {'schema':'campaign_admission_regression_source_recipe_v5', 'producer':file_pin(Path(__file__)),
            'inputs':inputs, 'pins':sorted(pins.values(),key=lambda row:row['path']), 'Python_import_edges':edges,
            'engine':current['engine'], 'native_dependencies':current['native_dependencies'],
            'durable_basis_source_spec_file':basis_pin, 'durable_basis_independent_review':current_review_pin,
            'durable_basis_logical_sha256':basis['source_spec_sha256'], 'retained_V4_source_spec':original_pin,
            'retained_V4_review':original_review_pin, 'fixtures':old['fixtures'], 'fixture_pins':old['fixture_pins'],
            'execution_scope':SCOPE, 'native_processes':6, 'JSON_checks':533, 'OwnedSlot_checks':76,
            'admission_cases':list(predecessor.CASES), 'pure_QA_labels':old['pure_QA_labels'],
            'V9_prior_authority_transferred':False, 'native_started':False, 'original19_faults_qualified':False,
            'SDK_reward_once_qualified':False, 'overall_goal_qualified':False}


def source_spec(args):
    spec = source_recipe(args)
    spec['schema'] = 'campaign_admission_regression_source_spec_v5'
    spec['prior_durable_run'] = str(prior_receipt_path(args).parent)
    _, pin = verify_closed_prior_v12(prior_receipt_path(args), spec)
    spec['prior_durable_receipt'] = pin
    return spec


class Admission(predecessor.Admission):
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        require(prior_receipt_path(args) == Path(spec['prior_durable_run'])/'receipt.json', 'Exact sealed V12 prior path')
        prior, self.prior_pin = verify_closed_prior_v12(args.prior_durable, spec)
        require(self.prior_pin == spec['prior_durable_receipt'], 'Same original successful prior before run directory')
        self.prior_pins = prior['all_evidence_pins']+[file_pin(Path(step['output'])/'native.log') for step in prior['steps']]
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private evidence outside source checkout')
        self.run = args.work_root/('admission_regressions_v5_'+uuid.uuid4().hex[:8])
        no_links(self.run)
        self.run.mkdir(parents=True,exist_ok=False)
        self.project = self.run/'project'
        self.frozen = FrozenProject(self.project,spec['inputs'])
        self.receipt = {'schema':'campaign_admission_regression_batch_v5','run':str(self.run),'complete':False,
                        'started_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
                        'original_JSON_OwnedSlot_and_campaign_admission_qualified':False,'overall_goal_qualified':False,
                        'original19_faults_qualified':False,'SDK_reward_once_qualified':False,
                        'source_spec_sha256':canonical(spec),'source_spec':spec,
                        'source_spec_file':args.fixed_source_spec_pin,'independent_review':args.fixed_review_pin,
                        'prior_durable_receipt':self.prior_pin,'reports':{}}
        self.batch = OwnedSerialBatch(self.run,self.frozen,args.godot,spec['engine']['sha256'],self.persist)
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity
        self.reports, self.held_pins = {}, []
        self.identity = identity_module()
        self.persist()

    def actual_terminal(self, step, label, arguments, index):
        child = self.batch.child
        command = [str(self.batch.engine),'--path',str(self.project),*arguments]
        require(type(child) is subprocess.Popen and child._child_created is True and child.pid == step['pid']
                and subprocess.Popen.poll(child) == 0 and step['process_terminal'] is True
                and step['complete'] is False and child.args == step['command'] == command,
                'Exact original held terminal process before inherited complete consumer')
        require(step is self.batch.steps[-1] and len(self.batch.steps) == index+1 and step['label'] == label
                and all(row['complete'] for row in self.batch.steps[:-1])
                and self.batch.steps[0]['label'] == 'cold_import' and step['profile'] == str(self.profile),
                'Exact actual cold/JSON/OwnedSlot/ABC phase order and original private profile')
        profile = Path(step['profile'])
        no_links(profile)
        require(profile.resolve().is_relative_to((self.run/'profiles').resolve())
                and step['CAMPAIGN_QA_enabled'] is (label in self.spec['pure_QA_labels']), 'Only two fixed pure QA labels')
        env = step['environment_overrides']
        require(env['STEAM_DISABLED'] == '1' and all(env[key] == str(profile/key.lower())
                for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']), 'Original private normal/QA native environment')
        if index <= 3:
            require(all(step['profile'] != row['profile'] for row in self.batch.steps[:-1]), 'Distinct cold/JSON/OwnedSlot/admission profiles')
        else:
            require(step['profile'] == self.batch.steps[3]['profile'], 'Original successful admission same-profile ABC chain')
        self.integrity()

    def boundary_passed(self, step, log, report_path, nonce):
        self.actual_terminal(step,'json_boundary',['--headless','res://tools/native_ownership_json_boundary_v24q1.tscn'],1)
        super().boundary_passed(step,log,report_path,nonce)
        self.integrity()

    def owned_passed(self, step, log):
        self.actual_terminal(step,'owned_slot_retry',['--headless','res://tools/owned_slot_retry_qa.tscn'],2)
        super().owned_passed(step,log)
        self.integrity()

    def validate_case(self, case, step, text):
        index = predecessor.CASES.index(case)+3
        arguments = ['--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x720',
                     '--position','30000,30000',predecessor.SCENE]
        self.actual_terminal(step,case.lower(),arguments,index)
        super().validate_case(case,step,text)
        self.integrity()


def main():
    require(__debug__, 'Assertions must stay enabled')
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--work-root',type=Path,default=Path('D:/CodexTemp/lsh-admission-v5'))
    parser.add_argument('--write-recipe',type=Path)
    parser.add_argument('--write-spec',type=Path)
    parser.add_argument('--prior-durable',type=Path)
    parser.add_argument('--source-spec',type=Path)
    parser.add_argument('--independent-review',type=Path)
    parser.add_argument('--run',action='store_true')
    args = parser.parse_args()
    require(args.write_recipe is None or not args.run and args.write_spec is None, 'Recipe preparation never launches')
    if args.write_recipe:
        recipe = source_recipe(args)
        write_new(args.write_recipe,{'recipe_sha256':canonical(recipe),'recipe':recipe})
        print(json.dumps({'recipe_preflight':True,'recipe_sha256':canonical(recipe),'native_started':False}))
        return 0
    spec = source_spec(args)
    logical = canonical(spec)
    if not args.run:
        if args.write_spec:
            write_new(args.write_spec,{'source_spec_sha256':logical,'spec':spec})
        print(json.dumps({'preflight':True,'source_spec_sha256':logical,'prior_closed_checked':True,'native_started':False}))
        return 0
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None, 'Exact new seal and full direct chain admission required')
    saved,args.fixed_source_spec_pin = pinned_document(args.source_spec)
    review,args.fixed_review_pin = pinned_document(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == logical
            and review['schema'] == 'campaign_admission_regression_independent_review_v5'
            and review['independent'] is True and review['static_api_closure_passed'] is True
            and review['complete_consumer_and_phase_reviewed'] is True and review['approved_stages'] == [SCOPE]
            and review['producer_sha256'] == sha(Path(__file__)) and review['source_spec_sha256'] == logical
            and review['source_spec_file_sha256'] == args.fixed_source_spec_pin['sha256'],
            'Exact new V12-based native admission; old V4 and preliminary reviews cannot substitute')
    runner = Admission(args,spec)
    code = 0
    try:
        runner.execute()
    except BaseException as error:
        code = 1
        runner.receipt.update(complete=False,original_JSON_OwnedSlot_and_campaign_admission_qualified=False,failure=repr(error))
    finally:
        try:
            runner.batch.release()
        except BaseException as error:
            code = 1
            runner.receipt.update(complete=False,original_JSON_OwnedSlot_and_campaign_admission_qualified=False)
            runner.receipt.setdefault('finalization_failures',[]).append(repr(error))
        runner.receipt.update(lock_released=not runner.batch.locked,finished_utc=dt.datetime.now(dt.timezone.utc).isoformat())
        runner.persist()
        write_new(runner.run/'receipt.json',runner.receipt)
    print(json.dumps({'run':str(runner.run),'complete':runner.receipt['complete'],'failure':runner.receipt.get('failure'),
                      'overall_goal_qualified':False}))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
