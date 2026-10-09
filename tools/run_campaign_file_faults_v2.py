"""Fresh six natural file faults plus same-profile ordinary restarts.

Source preparation may precede the actual V12 result. --run requires exact
independent native admission and the successful closed current V12 61 stages.
Other original19 cases, SDK, broad UI, content, performance and devices remain.
"""
import argparse
import ast
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys
import uuid

from campaign_file_fault_evidence_v2 import FileFaultEvidence
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from campaign_original19_fault_runtime_v3 import FaultSerialBatch, CASES
from campaign_original19_native_exports_v1 import NativeExports
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import FrozenProject, inventory, no_links, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
from run_durable_campaign_chain_v12 import canonical, identity_module, source_spec as durable_spec, verify_pin
import run_steam_integration_qa as native

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'qa/campaign_progress_recovery_20261008'
GD=QA/'original19_natural_file_faults_candidate_v6/campaign_original19_natural_file_faults_v6.gd'
SCOPE='six_original19_natural_file_faults_and_same_profile_restarts'
PRIOR_RUN=Path('D:/CodexTemp/lsh-durable-chain-20261009/durable_chain_6409dde9')


def pinned_document(path):
    path=Path(path);no_links(path);raw=path.read_bytes();pin={'path':str(path.resolve()),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    value=json.loads(raw.decode('utf-8-sig'));verify_pin(pin);return value,pin


def source_spec(args):
    basis,basis_pin=pinned_document(QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json')
    current=durable_spec(args)
    require(current==basis['spec'] and canonical(current)==basis['source_spec_sha256'], 'Exact current approved V12 source recipe')
    full_review,full_review_pin=pinned_document(QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json')
    require(full_review['independent'] is True and full_review['static_api_closure_passed'] is True
            and full_review['approved_stages']==['durable_chain_and_matrices']
            and full_review['source_spec_sha256']==basis['source_spec_sha256'] and full_review['source_spec_file_sha256']==basis_pin['sha256'], 'Exact existing limited V12 admission')
    component,component_pin=pinned_document(QA/'ORIGINAL19_FILE_FAULT_EVIDENCE_SOURCE_SPEC_V2.json')
    review,review_pin=pinned_document(QA/'ORIGINAL19_FILE_FAULT_EVIDENCE_PRELIMINARY_REVIEW_V2.json')
    require(review['independent'] is True and review['static_api_closure_passed'] is True and review['approved_stages']==[]
            and review['source_spec_file_sha256']==component_pin['sha256'], 'Exact limited component preliminary review')
    for row in component['pins']:verify_pin(row)
    manifest,manifest_pin=pinned_document(GD.parent/'SOURCE.json')
    contract,contract_pin=pinned_document(QA/'ORIGINAL19_FILE_FAULT_FULL_LABEL_CONTRACT_V3.json')
    require(manifest['candidate']==file_pin(GD) and contract['GD']==file_pin(GD)
            and manifest['case_ids']==contract['case_ids']==list(CASES), 'Exact latest GD/source/full labels')
    inputs=json.loads(json.dumps(current['inputs']));relative='tools/'+GD.name
    require(relative not in {r['runtime_path'] for r in inputs['runtime_and_harness_overlays']}, 'Unique natural fault runtime overlay')
    inputs['runtime_and_harness_overlays'].append({**file_pin(GD),'runtime_path':relative})
    inputs['schema']='campaign_six_file_fault_inputs_v1'
    inputs['execution_contract']={'native_processes':13,'scope':SCOPE,'case_ids':list(CASES),'Steam_disabled':True,'QA_mode_enabled':False}
    pins={r['path']:r for r in current['pins']+component['pins']}
    extra=[Path(__file__),ROOT/'tools/campaign_original19_fault_runtime_v3.py',ROOT/'tools/campaign_file_fault_prior_v2.py',
           QA/'ORIGINAL19_FILE_FAULT_EVIDENCE_SOURCE_SPEC_V2.json',QA/'ORIGINAL19_FILE_FAULT_EVIDENCE_PRELIMINARY_REVIEW_V2.json',
           QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json',QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json',GD.parent/'SOURCE.json',
           QA/'ORIGINAL19_FILE_FAULT_FULL_LABEL_CONTRACT_V3.json']
    pending=extra[:];checked=set();edges=[]
    while pending:
        p=pending.pop();row=file_pin(p);require(row['path'] not in pins or pins[row['path']]==row, 'Conflicting original source pin');pins[row['path']]=row
        if p.suffix!='.py' or str(p) in checked:continue
        checked.add(str(p));tree=ast.parse(p.read_bytes(),filename=str(p))
        for node in ast.walk(tree):
            modules=[node.module] if isinstance(node,ast.ImportFrom) else [item.name for item in node.names] if isinstance(node,ast.Import) else []
            for module in modules:
                if module:
                    dependency=ROOT/'tools'/(module.split('.')[0]+'.py')
                    if dependency.is_file():edges.append([p.name,dependency.name]);pending.append(dependency)
    for row in pins.values():verify_pin(row)
    return {'schema':'campaign_six_file_fault_source_spec_v2','producer':file_pin(Path(__file__)),'inputs':inputs,'pins':sorted(pins.values(),key=lambda r:r['path']),
            'engine':current['engine'],'native_dependencies':current['native_dependencies'],'execution_scope':SCOPE,'native_processes':13,
            'durable_basis_source_spec_file':basis_pin,'durable_basis_independent_review':full_review_pin,'durable_basis_logical_sha256':basis['source_spec_sha256'],
            'prior_durable_run':str(PRIOR_RUN),'prior_closed_evidence_required_before_any_native':True,
            'full_labels':contract,'manifest':manifest,'Python_import_edges':sorted(edges),'original19_case_mechanisms_included':6,
            'original19_qualified':False,'SDK_reward_once_qualified':False,'UI_qualified':False,'overall_goal_qualified':False}


class Suite:
    def __init__(self,args,spec):
        self.args,self.spec=args,spec
        require(args.prior_durable==PRIOR_RUN/'receipt.json', 'Only exact preceding fresh V12 run accepted')
        prior,self.prior_receipt_pin=verify_closed_prior_v12(args.prior_durable,spec)
        self.prior=self.prior_receipt_pin
        no_links(args.work_root);require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private QA root outside source checkout')
        self.run=args.work_root/('file_faults_'+uuid.uuid4().hex[:8]);no_links(self.run);self.run.mkdir(parents=True,exist_ok=False)
        self.frozen=FrozenProject(self.run/'project',spec['inputs'])
        self.batch=FaultSerialBatch(self.run,self.frozen,args.godot,spec['engine']['sha256'],self.persist)
        self.evidence=[];self.evidence_by_path={};self.installed_identity=None
        for row in [self.prior_receipt_pin,*prior['all_evidence_pins']]:self.remember(row)
        for step in prior['steps']:self.freeze_bytes(Path(step['output'])/'native.log',step['log_sha256'])
        self.receipt={'schema':'campaign_six_file_fault_batch_v1','run':str(self.run),'started_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
                      'source_spec':spec,'source_spec_sha256':canonical(spec),'source_spec_file':args.fixed_source_spec_pin,
                      'independent_review':args.fixed_review_pin,'prior_durable_receipt':self.prior_receipt_pin,'steps':[],'reports':{},'complete':False,
                      'six_file_faults_and_restarts_qualified':False,'original19_qualified':False,'SDK_reward_once_qualified':False,
                      'UI_qualified':False,'overall_goal_qualified':False}
        self.original_integrity=self.batch.integrity;self.batch.integrity=self.integrity;self.persist()

    def remember(self,row):
        path=Path(row['path']);no_links(path);fixed={'path':str(path.resolve()),'bytes':row['bytes'],'sha256':row['sha256']};verify_pin(fixed)
        key=fixed['path'].casefold();require(key not in self.evidence_by_path or self.evidence_by_path[key]==fixed, 'First original pin cannot be rebased')
        if key not in self.evidence_by_path:self.evidence_by_path[key]=fixed;self.evidence.append(fixed)
        return fixed

    def freeze_bytes(self,path,expected=None):
        path=Path(path);no_links(path);raw=path.read_bytes();digest=hashlib.sha256(raw).hexdigest()
        require(expected is None or digest==expected, 'Exact previously declared original bytes')
        self.remember({'path':str(path.resolve()),'bytes':len(raw),'sha256':digest});return raw

    def read_fixed(self,path,expected=None):return json.loads(self.freeze_bytes(path,expected).decode('utf-8-sig'))

    def persist(self):
        if not hasattr(self,'receipt'):return
        self.receipt['steps']=self.batch.steps;self.receipt['evidence_pins']=self.evidence
        (self.run/'checkpoint.json').write_text(json.dumps(self.receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

    def integrity(self):
        for row in [*self.spec['pins'],*self.evidence,self.receipt['source_spec_file'],self.receipt['independent_review']]:verify_pin(row)
        for step in self.batch.steps:
            if step.get('process_terminal') and step.get('log_sha256'):self.freeze_bytes(Path(step['output'])/'native.log',step['log_sha256'])
        require(native.native_dependencies()==self.spec['native_dependencies'], 'Native dependency original identity')
        self.original_integrity()
        if self.installed_identity is not None:
            require(identity_module().installed_identity(self.frozen.project)==self.installed_identity, 'Complete post-cold installed source identity')

    def values(self,mode,case,profile,token=''):
        def build(output,nonce):
            pin=self.evidence_by_path[str(self.identity_path.resolve()).casefold()]
            return {'CAMPAIGN_TERMINAL_OUTPUT':str(output),'CAMPAIGN_TERMINAL_NONCE':nonce,'CAMPAIGN_TERMINAL_MODE':mode,
                    'CAMPAIGN_TERMINAL_PROFILE':str(profile),'CAMPAIGN_FILE19_CASE':case,'CAMPAIGN_TERMINAL_TOKEN':token,
                    'CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0','CAMPAIGN_TERMINAL_IDENTITY_FILE':str(self.identity_path),
                    'CAMPAIGN_TERMINAL_IDENTITY_SHA256':pin['sha256']}
        return build

    def validate(self,mode,case):
        def validator(step,output,nonce):
            if mode=='restart':NativeExports(self,step).require_complete('restart')
            result=self.consumer.validate(step,mode,case);self.receipt['reports'][case+'_'+mode]=result;self.persist()
        return validator

    def execute(self):
        self.frozen.prepare();require(native.install_native(self.frozen.project)==self.spec['native_dependencies'], 'Exact isolated native installation')
        self.frozen.before=inventory(self.frozen.project)
        self.batch.phase('cold_import',self.batch.profile('import'),['--headless','--editor','--import'],{},lambda *args:None,600)
        self.frozen.freeze_cold();identity=identity_module().installed_identity(self.frozen.project);self.installed_identity=identity
        self.runtime_fields={k:identity[k] for k in ['content_version','rules_sha256','file_count','total_bytes']}
        self.runtime_fields.update(engine_binary_sha256=sha(self.args.godot),provider_sha256=sha(self.frozen.project/'scripts/run_content_identity.gd'))
        self.identity_path=self.run/'post_cold_identity.json';write_new(self.identity_path,{'runtime_fields':self.runtime_fields,'complete_identity':identity})
        self.freeze_bytes(self.identity_path);self.consumer=FileFaultEvidence(self,self.spec['full_labels'],self.spec['manifest']);self.persist()
        arguments=['--headless','--script','res://tools/'+GD.name]
        for case in CASES:
            profile=self.batch.profile(case.lower())
            self.batch.fault_phase(self,case,self.spec['manifest'],profile,arguments,self.values('fresh',case,profile),self.validate('fresh',case))
            token=self.consumer.fresh[case]['journals'][1]['document']['token']
            self.batch.phase('restart_'+case.lower(),profile,arguments,self.values('restart',case,profile,token),self.validate('restart',case),180)
        self.consumer.require_all();require(len(self.batch.steps)==13 and len(self.receipt['reports'])==12, 'All13 terminal processes and six paired cases')
        self.integrity();self.receipt.update(complete=True,six_file_faults_and_restarts_qualified=True);self.persist()


def main():
    require(__debug__, 'Assertions must stay enabled');sys.dont_write_bytecode=True
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True);parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--work-root',type=Path,default=Path('D:/CodexTemp/lsh-f19'))
    parser.add_argument('--write-spec',type=Path);parser.add_argument('--source-spec',type=Path);parser.add_argument('--independent-review',type=Path)
    parser.add_argument('--prior-durable',type=Path);parser.add_argument('--run',action='store_true');args=parser.parse_args()
    spec=source_spec(args);logical=canonical(spec)
    if not args.run:
        if args.write_spec:write_new(args.write_spec,{'source_spec_sha256':logical,'spec':spec})
        print(json.dumps({'preflight':True,'source_spec_sha256':logical,'native_started':False,'prior_closed_checked':False,'overall_goal_qualified':False}));return 0
    require(args.write_spec is None and all(p is not None for p in [args.source_spec,args.independent_review,args.prior_durable]), 'Exact seal/review/closed prior required')
    saved,args.fixed_source_spec_pin=pinned_document(args.source_spec);review,args.fixed_review_pin=pinned_document(args.independent_review)
    require(saved['spec']==spec and saved['source_spec_sha256']==logical, 'Exact current source seal')
    require(review['schema']=='campaign_six_file_fault_independent_review_v1' and review['independent'] is True
            and review['static_api_closure_passed'] is True and review['approved_stages']==[SCOPE]
            and review['producer_sha256']==sha(Path(__file__)) and review['source_spec_sha256']==logical
            and review['source_spec_file_sha256']==args.fixed_source_spec_pin['sha256'], 'Exact limited independent native admission')
    suite=Suite(args,spec);code=0
    try:suite.execute()
    except BaseException as error:code=1;suite.receipt.update(complete=False,six_file_faults_and_restarts_qualified=False,failure=repr(error))
    finally:
        try:suite.batch.release()
        except BaseException as error:code=1;suite.receipt.update(complete=False,six_file_faults_and_restarts_qualified=False);suite.receipt.setdefault('finalization_failures',[]).append(repr(error))
        suite.receipt['lock_released']=not suite.batch.locked;suite.receipt['finished_utc']=dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist();write_new(suite.run/'receipt.json',suite.receipt)
        print(json.dumps({'run':str(suite.run),'complete':suite.receipt['complete'],'failure':suite.receipt.get('failure'),'overall_goal_qualified':False}))
    return code


if __name__=='__main__':raise SystemExit(main())
