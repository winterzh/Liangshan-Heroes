"""Six real CFG data cases and two separate QA1 compatibility cases after V12.

V1 was rejected for missing assertion and physical evidence coverage. This
successor consumes the complete reviewed V5 GD/V3 evidence, not V1 outcomes.
It needs a real closed all61 prior and new exact independent native admission.
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
from campaign_callback_packets_v2 import json_value, same
from campaign_original19_data_evidence_v3 import DataEvidence, labels, hex_value
from campaign_original19_data_runtime_v1 import OwnedSerialBatch
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from durable_campaign_full_runtime import FrozenProject, inventory, no_links, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
from durable_campaign_full_matrices import require
from run_campaign_file_faults_v3 import Suite as EvidenceSuite, prior_receipt_path, pinned_document
from run_durable_campaign_chain_v12 import canonical, source_spec as durable_spec, identity_module, verify_pin
import run_steam_integration_qa as native

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT/'qa/campaign_progress_recovery_20261008'
DATA = QA/'original19_data_layers_candidate_v5'
COMPAT = QA/'original19_QA_compatibility_candidate_v1'
DATA_GD = DATA/'campaign_original19_data_layers_v5.gd'
COMPAT_GD = COMPAT/'campaign_original19_QA_compatibility_v1.gd'
QA_IDS = ['QA_memory_only', 'QA_cloud_bool_compatibility']
SCOPE = 'original19_six_complete_CFG_data_and_two_QA_cases_after_V12'
COMMON_REPORT = {'schema','passed','checks','failures','pid','nonce','identity','actual_user_directory',
                 'time_scale','physics_ticks','scope','original19_qualified','UI_qualified',
                 'SDK_reward_once_qualified','overall_goal_qualified'}
DATA_REPORT = COMMON_REPORT | {'cases','invalid_refusals','trusted_scope','commits',
                               'original_unknown_expectation','final_CFG','natural_battle_qualified'}
QA_REPORT = COMMON_REPORT | {'case','sentinel_sha256','CAMPAIGN_QA_enabled','normal_persistence_qualified'}


def source_recipe(args):
    current = durable_spec(args)
    basis, basis_pin = pinned_document(QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json')
    review, review_pin = pinned_document(QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json')
    require(current == basis['spec'] and canonical(current) == basis['source_spec_sha256']
            and review['independent'] is True and review['static_api_closure_passed'] is True
            and review['approved_stages'] == ['durable_chain_and_matrices']
            and review['source_spec_sha256'] == basis['source_spec_sha256']
            and review['source_spec_file_sha256'] == basis_pin['sha256'], 'Exact approved V12 source basis')
    component, component_pin = pinned_document(QA/'ORIGINAL19_DATA_EVIDENCE_SOURCE_SPEC_V3.json')
    helper_review, helper_review_pin = pinned_document(QA/'ORIGINAL19_DATA_EVIDENCE_PRELIMINARY_REVIEW_V3.json')
    helper = ROOT/'tools/campaign_original19_data_evidence_v3.py'
    require(helper_review['independent'] is True and helper_review['static_api_closure_passed'] is True
            and helper_review['approved_stages'] == [] and helper_review['helper_sha256'] == sha(helper)
            and helper_review['source_spec_file_sha256'] == component_pin['sha256'], 'Exact complete V3 data evidence source review')
    contract, contract_pin = pinned_document(QA/'ORIGINAL19_COMPLETE_LABEL_CONTRACT_V3.json')
    require(contract['data_source'] == file_pin(DATA_GD) and contract['QA_source'] == file_pin(COMPAT_GD)
            and contract['data_total'] == 109 and contract['QA_totals'] == {case:20 for case in QA_IDS}
            and set(contract['QA_case_labels']) == set(QA_IDS), 'Exact whole109/20/20 source assertion contracts')
    inputs = json.loads(json.dumps(current['inputs']))
    pins = {}

    def adopt(row):
        verify_pin(row)
        require(row['path'] not in pins or pins[row['path']] == row, 'Immutable source pin conflict')
        pins[row['path']] = row

    for row in [*current['pins'], *component['pins'], basis_pin, review_pin, component_pin,
                helper_review_pin, contract_pin, file_pin(Path(__file__))]:
        adopt(row)
    for folder, gd, review_name in [(DATA, DATA_GD, 'ORIGINAL19_DATA_LAYERS_PRELIMINARY_REVIEW_V5.json'),
                                    (COMPAT, COMPAT_GD, 'ORIGINAL19_QA_COMPATIBILITY_PRELIMINARY_REVIEW_V1.json')]:
        manifest, manifest_pin = pinned_document(folder/'SOURCE.json')
        preliminary, preliminary_pin = pinned_document(folder/review_name)
        require(manifest['candidate'] == file_pin(gd) and preliminary['independent'] is True
                and preliminary['static_api_closure_passed'] is True and preliminary['approved_stages'] == []
                and preliminary['candidate_sha256'] == sha(gd), 'Exact retained native data/compatibility source review')
        for row in manifest['runtime_sources']:
            adopt(row)
            require(any(all(overlay[k] == row[k] for k in ['path','bytes','sha256'])
                        for overlay in inputs['runtime_and_harness_overlays']), 'Native probe production dependencies match current V12 inputs')
        alias = 'tools/'+gd.name
        require(alias not in {row['runtime_path'] for row in inputs['runtime_and_harness_overlays']}, 'Unique fixed native probe alias')
        inputs['runtime_and_harness_overlays'].append({**file_pin(gd), 'runtime_path': alias})
        for row in [manifest_pin, preliminary_pin, file_pin(gd)]:
            adopt(row)
    for path in [QA/'ORIGINAL19_DATA_CASES_INDEPENDENT_REVIEW_V1.json',
                 QA/'ORIGINAL19_DATA_CASES_SOURCE_SPEC_V1.json', ROOT/'tools/run_campaign_original19_data_cases_v1.py',
                 QA/'ORIGINAL19_R12_ADAPTATION_REQUIREMENTS_V1.json']:
        adopt(file_pin(path))
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
                        edges.append({'source':str(path), 'module':module, 'target':str(dependency)})
                        adopt(file_pin(dependency))
    for row in pins.values():
        verify_pin(row)
    inputs['schema'] = 'original19_data_cases_inputs_v2'
    inputs['execution_contract'] = {'native_processes':4, 'scope':SCOPE,
                                   'data_case_ids':contract['data_case_order'], 'separate_QA1_case_ids':QA_IDS,
                                   'Steam_disabled':True, 'all_original19_qualified':False}
    return {'schema':'original19_data_cases_source_recipe_v2', 'producer':file_pin(Path(__file__)),
            'inputs':inputs, 'pins':sorted(pins.values(), key=lambda row:row['path']), 'Python_import_edges':edges,
            'engine':current['engine'], 'native_dependencies':current['native_dependencies'],
            'durable_basis_source_spec_file':basis_pin, 'durable_basis_independent_review':review_pin,
            'durable_basis_logical_sha256':basis['source_spec_sha256'], 'data_evidence_basis':component_pin,
            'data_evidence_review':helper_review_pin, 'contract':contract, 'contract_file':contract_pin,
            'execution_scope':SCOPE, 'native_processes':4, 'original19_case_mechanisms_included':8,
            'full_original19_included':False, 'native_started':False, 'original19_qualified':False,
            'normal_live_terminal_qualified':False, 'SDK_reward_once_qualified':False, 'UI_qualified':False,
            'overall_goal_qualified':False}


def source_spec(args):
    spec = source_recipe(args)
    spec['schema'] = 'original19_data_cases_source_spec_v2'
    spec['prior_durable_run'] = str(prior_receipt_path(args).parent)
    _, pin = verify_closed_prior_v12(prior_receipt_path(args), spec)
    spec['prior_durable_receipt'] = pin
    return spec


class Suite(EvidenceSuite):
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        require(prior_receipt_path(args) == Path(spec['prior_durable_run'])/'receipt.json', 'Exact closed prior path')
        prior, self.prior_receipt_pin = verify_closed_prior_v12(args.prior_durable, spec)
        require(self.prior_receipt_pin == spec['prior_durable_receipt'], 'Same successful prior bytes before run directory')
        self.prior = self.prior_receipt_pin
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private evidence outside source checkout')
        self.run = args.work_root/('original19_data_v2_'+uuid.uuid4().hex[:8])
        no_links(self.run)
        self.run.mkdir(parents=True, exist_ok=False)
        self.frozen = FrozenProject(self.run/'project', spec['inputs'])
        self.batch = OwnedSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist)
        self.evidence, self.evidence_by_path, self.installed_identity = [], {}, None
        for row in [self.prior_receipt_pin, *prior['all_evidence_pins']]:
            self.remember(row)
        for step in prior['steps']:
            self.freeze_bytes(Path(step['output'])/'native.log', step['log_sha256'])
        self.receipt = {'schema':'original19_data_cases_batch_v2', 'run':str(self.run),
                        'started_utc':dt.datetime.now(dt.timezone.utc).isoformat(), 'source_spec':spec,
                        'source_spec_sha256':canonical(spec), 'source_spec_file':args.fixed_source_spec_pin,
                        'independent_review':args.fixed_review_pin, 'prior_durable_receipt':self.prior_receipt_pin,
                        'steps':[], 'reports':{}, 'complete':False, 'eight_original_case_mechanisms_qualified':False,
                        'original19_qualified':False, 'normal_live_terminal_qualified':False,
                        'SDK_reward_once_qualified':False, 'UI_qualified':False, 'overall_goal_qualified':False}
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity
        self.persist()

    def values(self, kind, profile, case=''):
        def build(output, nonce):
            prefix = 'CAMPAIGN_DATA19_' if kind == 'data' else 'CAMPAIGN_COMPAT19_'
            pin = self.evidence_by_path[str(self.identity_path.resolve()).casefold()]
            values = {prefix+'OUTPUT':str(output), prefix+'NONCE':nonce, prefix+'PROFILE':str(profile),
                      prefix+'IDENTITY_FILE':str(self.identity_path), prefix+'IDENTITY_SHA256':pin['sha256']}
            if kind == 'compat':
                values[prefix+'CASE'] = case
            return values
        return build

    def validate(self, kind, case=''):
        def actual_terminal(step, output, nonce):
            require(kind == 'data' and case == '' or kind == 'compat' and case in QA_IDS, 'Only fixed normal/QA modes')
            child = self.batch.child
            gd = DATA_GD if kind == 'data' else COMPAT_GD
            command = [str(self.batch.engine), '--path', str(self.frozen.project), '--headless', '--script', 'res://tools/'+gd.name]
            require(type(child) is subprocess.Popen and child._child_created is True and child.pid == step['pid']
                    and subprocess.Popen.poll(child) == 0 and step['process_terminal'] is True
                    and step['complete'] is False and child.args == step['command'] == command
                    and step['output'] == str(output) and step['nonce'] == nonce,
                    'Exact original held terminal process and native command')
            index = 1 if kind == 'data' else QA_IDS.index(case)+2
            require(len(self.batch.steps) == index+1 and step is self.batch.steps[-1]
                    and all(row['complete'] for row in self.batch.steps[:-1])
                    and step['label'] == ('original19_data' if kind == 'data' else case.lower())
                    and self.batch.steps[0]['label'] == 'cold_import', 'Only exact cold/data/QA1/QA1 successful serial order')
            profile = Path(step['profile'])
            no_links(profile)
            require(profile.resolve().is_relative_to((self.run/'profiles').resolve())
                    and all(step['profile'] != row['profile'] for row in self.batch.steps[:-1]), 'Four distinct original private profiles')
            env = step['environment_overrides']
            require(env['STEAM_DISABLED'] == '1'
                    and all(env[key] == str(profile/key.lower()) for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP'])
                    and step['CAMPAIGN_QA_enabled'] is (kind == 'compat'), 'Exact private isolation and QA-only allowlist')
            require({key:value for key,value in env.items() if key not in ['APPDATA','LOCALAPPDATA','TEMP','TMP','STEAM_DISABLED']}
                    == self.values(kind, profile, case)(output, nonce), 'Exact current original probe environment')
            path = output/'report.json'
            raw = self.freeze_bytes(path)
            require(0 < len(raw) <= 2097152, 'Bounded original closed native report')
            report = json_value(raw.decode('utf-8'))
            require(type(report) is dict and set(report) == (DATA_REPORT if kind == 'data' else QA_REPORT)
                    and type(report['pid']) is int and report['pid'] == step['pid'] and report['nonce'] == nonce
                    and report['passed'] is True and same(report['failures'],[])
                    and same(report['identity'], expected_native_identity(self.runtime_fields,self.installed_identity))
                    and type(report['time_scale']) in [int,float] and report['time_scale'] == 1
                    and type(report['physics_ticks']) is int and report['physics_ticks'] == 60
                    and all(report[key] is False for key in ['original19_qualified','UI_qualified','SDK_reward_once_qualified','overall_goal_qualified']),
                    'Whole actual normal-clock limited report and complete installed identity')
            require(type(report['actual_user_directory']) is str and report['actual_user_directory'], 'Original native userdata string')
            user = Path(report['actual_user_directory'])
            no_links(user)
            require(user.is_absolute() and user.resolve().is_relative_to((profile/'appdata').resolve()), 'Actual isolated physical userdata')
            log = self.freeze_bytes(output/'native.log',step['log_sha256']).decode('utf-8').splitlines()
            if kind == 'data':
                require(report['schema'] == 'campaign_original19_data_layers_v5' and report['natural_battle_qualified'] is False
                        and report['scope'] == 'six pure current projection/CFG/Variant data layers only; fixtures are not a live Battle result', 'Exact normal six-data scope')
                require(log.count('CAMPAIGN_ORIGINAL19_DATA_LAYERS true 6 109') == 1, 'Original whole data completion marker')
                result = DataEvidence(self, report, output, self.spec['contract']).run()
            else:
                require(report['schema'] == 'campaign_original19_QA_compatibility_v1' and report['case'] == case
                        and report['CAMPAIGN_QA_enabled'] is True and report['normal_persistence_qualified'] is False
                        and report['scope'] == 'retained QA1-only Campaign compatibility; Cloud may retain its private settings/language apply behavior; Campaign CFG must not change', 'Exact separate QA1 scope')
                labels(report['checks'], self.spec['contract']['QA_case_labels'][case])
                require(log.count('CAMPAIGN_ORIGINAL19_QA_COMPATIBILITY '+case+' true 20') == 1
                        and hex_value(report['sentinel_sha256']), 'Whole original QA branch completion and original sentinel hash')
                self.freeze_bytes(user/'campaign.cfg',report['sentinel_sha256'])
                result = {'complete_original_QA_checks':20, 'sentinel_sha256':report['sentinel_sha256'], 'normal_persistence_qualified':False}
            self.integrity()
            self.receipt['reports'][case or kind] = {'report':self.evidence_by_path[str(path.resolve()).casefold()],
                                                    'actual_user_directory':report['actual_user_directory'], 'evidence':result}
            self.persist()
        return actual_terminal

    def execute(self):
        self.frozen.prepare()
        require(native.install_native(self.frozen.project) == self.spec['native_dependencies'], 'Exact isolated native installation')
        self.frozen.before = inventory(self.frozen.project)
        self.batch.phase('cold_import',self.batch.profile('cold'),['--headless','--editor','--import'],{},lambda *args:None,1200)
        self.frozen.freeze_cold()
        identity = identity_module().installed_identity(self.frozen.project)
        self.installed_identity = identity
        self.runtime_fields = {key:identity[key] for key in ['content_version','rules_sha256','file_count','total_bytes']}
        self.runtime_fields.update(engine_binary_sha256=sha(self.args.godot), provider_sha256=sha(self.frozen.project/'scripts/run_content_identity.gd'))
        self.identity_path = self.run/'post_cold_identity.json'
        write_new(self.identity_path,{'runtime_fields':self.runtime_fields,'complete_identity':identity})
        self.freeze_bytes(self.identity_path)
        profile = self.batch.profile('data')
        self.batch.phase('original19_data',profile,['--headless','--script','res://tools/'+DATA_GD.name],self.values('data',profile),self.validate('data'),900)
        for case in QA_IDS:
            profile = self.batch.profile(case.lower())
            self.batch.phase(case.lower(),profile,['--headless','--script','res://tools/'+COMPAT_GD.name],self.values('compat',profile,case),self.validate('compat',case),300)
        require(len(self.batch.steps) == len(self.batch.pids) == len(self.batch.nonces) == 4
                and all(step['complete'] and step['process_terminal'] and step['exit_code'] == 0 for step in self.batch.steps)
                and set(self.receipt['reports']) == {'data',*QA_IDS}, 'Four actual distinct closed successful processes and all eight case evidence')
        self.integrity()
        self.receipt.update(complete=True,eight_original_case_mechanisms_qualified=True)
        self.persist()


def main():
    require(__debug__, 'Assertions must stay enabled')
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--work-root',type=Path,default=Path('D:/CodexTemp/lsh-original19-data-v2'))
    parser.add_argument('--write-recipe',type=Path)
    parser.add_argument('--write-spec',type=Path)
    parser.add_argument('--prior-durable',type=Path)
    parser.add_argument('--source-spec',type=Path)
    parser.add_argument('--independent-review',type=Path)
    parser.add_argument('--run',action='store_true')
    args = parser.parse_args()
    require(args.write_recipe is None or not args.run and args.write_spec is None, 'Recipe mode never launches')
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
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None, 'Exact seal and full chain admission required')
    saved,args.fixed_source_spec_pin = pinned_document(args.source_spec)
    review,args.fixed_review_pin = pinned_document(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == logical
            and review['schema'] == 'original19_data_cases_independent_review_v2' and review['independent'] is True
            and review['static_api_closure_passed'] is True and review['complete_consumer_and_phase_reviewed'] is True
            and review['approved_stages'] == [SCOPE] and review['producer_sha256'] == sha(Path(__file__))
            and review['source_spec_sha256'] == logical and review['source_spec_file_sha256'] == args.fixed_source_spec_pin['sha256'],
            'Exact new source-bound native admission, no preliminary or rejected V1 substitution')
    suite = Suite(args,spec)
    code = 0
    try:
        suite.execute()
    except BaseException as error:
        code = 1
        suite.receipt.update(complete=False,eight_original_case_mechanisms_qualified=False,failure=repr(error))
    finally:
        try:
            suite.batch.release()
        except BaseException as error:
            code = 1
            suite.receipt.update(complete=False,eight_original_case_mechanisms_qualified=False,release_failure=repr(error))
        suite.receipt['lock_released'] = not suite.batch.locked
        suite.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist()
        write_new(suite.run/'receipt.json',suite.receipt)
    print(json.dumps({'run':str(suite.run),'complete':suite.receipt['complete'],'failure':suite.receipt.get('failure'),'overall_goal_qualified':False}))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
