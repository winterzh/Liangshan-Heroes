"""Prepare the first/repeat source recipe or run exact reviewed five processes.

--write-recipe does not verify a successful prior and grants no native scope.
--write-spec and --run require an actual successful closed V12 61-stage prior.
"""
import argparse,ast,datetime as dt,hashlib,json,sys,uuid
from pathlib import Path
from campaign_first_repeat_evidence_v3 import FirstRepeatEvidence
from campaign_natural_terminal_runtime_v1 import NaturalSerialBatch,MODES,CASES,actual_handoff
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from run_campaign_file_faults_v3 import Suite as EvidenceSuite,prior_receipt_path,pinned_document
from run_durable_campaign_chain_v12 import source_spec as durable_spec,canonical,verify_pin,identity_module
from durable_campaign_full_runtime import FrozenProject,inventory,no_links,sha,write_new
from durable_campaign_full_evidence_v2 import file_pin
from durable_campaign_full_matrices import require
import run_steam_integration_qa as native

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'qa/campaign_progress_recovery_20261008'
GD=QA/'original19_first_repeat_candidate_v1/campaign_original19_first_repeat_v1.gd'
SCOPE='two_original19_natural_full_seal_cases_and_same_profile_restarts'

def source_recipe(args):
    basis,basis_pin=pinned_document(QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json');current=durable_spec(args)
    require(current==basis['spec'] and canonical(current)==basis['source_spec_sha256'], 'Exact current approved durable V12 recipe')
    full_review,full_review_pin=pinned_document(QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json')
    require(full_review['independent'] is True and full_review['static_api_closure_passed'] is True
            and full_review['approved_stages']==['durable_chain_and_matrices'] and full_review['source_spec_sha256']==basis['source_spec_sha256']
            and full_review['source_spec_file_sha256']==basis_pin['sha256'], 'Exact limited V12 admission')
    pins={r['path']:r for r in current['pins']};extra=[]
    for spec_name,review_name,checks in [
        ('NATURAL_FIRST_REPEAT_RUNTIME_SOURCE_SPEC_V1.json','NATURAL_FIRST_REPEAT_RUNTIME_PRELIMINARY_REVIEW_V1.json',{'runtime_sha256':ROOT/'tools/campaign_natural_terminal_runtime_v1.py','publisher_sha256':ROOT/'tools/campaign_natural_terminal_exports_v1.py'}),
        ('FIRST_REPEAT_EVIDENCE_SOURCE_SPEC_V3.json','FIRST_REPEAT_EVIDENCE_PRELIMINARY_REVIEW_V3.json',{'consumer_sha256':ROOT/'tools/campaign_first_repeat_evidence_v3.py','binary_publisher_sha256':ROOT/'tools/campaign_original19_binary_files_v1.py'})]:
        component,component_pin=pinned_document(QA/spec_name);review,review_pin=pinned_document(QA/review_name)
        require(review['independent'] is True and review['static_api_closure_passed'] is True and review['approved_stages']==[]
                and review['source_spec_file_sha256']==component_pin['sha256'] and all(review[k]==sha(p) for k,p in checks.items()), 'Exact preliminary component source review')
        for row in component['pins']:
            verify_pin(row);require(row['path'] not in pins or pins[row['path']]==row, 'Conflicting immutable source pin');pins[row['path']]=row
        extra += [QA/spec_name,QA/review_name]
    manifest,manifest_pin=pinned_document(GD.parent/'SOURCE.json');contract,contract_pin=pinned_document(QA/'ORIGINAL19_FIRST_REPEAT_COMPLETE_LABEL_CONTRACT_V1.json')
    review,review_pin=pinned_document(GD.parent/'ORIGINAL19_FIRST_REPEAT_PRELIMINARY_REVIEW_V1.json')
    require(manifest['candidate']==file_pin(GD)==contract['GD'] and manifest['case_ids']==list(CASES)
            and review['independent'] is True and review['static_api_closure_passed'] is True and review['approved_stages']==[]
            and review['candidate_sha256']==sha(GD), 'Exact native candidate and preliminary review')
    require({k:len(v) for k,v in contract['complete_labels_by_mode'].items()}=={'first':74,'repeat':80,'restart_first':21,'restart_repeat':21}, 'Complete four-mode native labels')
    for field in ['builder','parser','full_source_inputs','level']:verify_pin(contract[field]);extra.append(Path(contract[field]['path']))
    inputs=json.loads(json.dumps(current['inputs']));relative='tools/'+GD.name
    require(relative not in {r['runtime_path'] for r in inputs['runtime_and_harness_overlays']}, 'Unique natural first/repeat overlay')
    inputs['runtime_and_harness_overlays'].append({**file_pin(GD),'runtime_path':relative})
    inputs['schema']='campaign_first_repeat_inputs_v1';inputs['execution_contract']={'native_processes':5,'scope':SCOPE,'modes':list(MODES),'case_ids':list(CASES),'same_real_private_profile':True,'Steam_disabled':True,'QA_mode_enabled':False}
    extra += [Path(__file__),QA/'DURABLE_CHAIN_SOURCE_SPEC_V12.json',QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V12.json',GD,GD.parent/'SOURCE.json',GD.parent/'ORIGINAL19_FIRST_REPEAT_PRELIMINARY_REVIEW_V1.json',QA/'ORIGINAL19_FIRST_REPEAT_COMPLETE_LABEL_CONTRACT_V1.json']
    pending=extra[:];checked=set();edges=[]
    while pending:
        p=pending.pop();row=file_pin(p);require(row['path'] not in pins or pins[row['path']]==row, 'Source pin rebaseline refused');pins[row['path']]=row
        if p.suffix!='.py' or str(p) in checked:continue
        checked.add(str(p))
        for n in ast.walk(ast.parse(p.read_bytes())):
            modules=[n.module] if isinstance(n,ast.ImportFrom) else [x.name for x in n.names] if isinstance(n,ast.Import) else []
            for module in modules:
                if module:
                    dep=ROOT/'tools'/(module.split('.')[0]+'.py')
                    if dep.is_file():edges.append([p.name,dep.name]);pending.append(dep)
    for row in pins.values():verify_pin(row)
    return {'schema':'campaign_first_repeat_source_recipe_v1','producer':file_pin(Path(__file__)),'inputs':inputs,'pins':sorted(pins.values(),key=lambda r:r['path']),
            'engine':current['engine'],'native_dependencies':current['native_dependencies'],'durable_basis_source_spec_file':basis_pin,'durable_basis_independent_review':full_review_pin,
            'durable_basis_logical_sha256':basis['source_spec_sha256'],'execution_scope':SCOPE,'native_processes':5,'full_labels':contract,'manifest':manifest,'Python_import_edges':sorted(edges),
            'original19_case_mechanisms_included':2,'original19_qualified':False,'SDK_reward_once_qualified':False,'UI_qualified':False,'overall_goal_qualified':False}

def source_spec(args):
    recipe=source_recipe(args);recipe['schema']='campaign_first_repeat_source_spec_v1'
    recipe['prior_durable_run']=str(prior_receipt_path(args).parent)
    _,pin=verify_closed_prior_v12(prior_receipt_path(args),recipe)
    recipe['prior_durable_receipt']=pin;return recipe

class Suite(EvidenceSuite):
    def __init__(self,args,spec):
        self.args,self.spec=args,spec
        require(prior_receipt_path(args)==Path(spec['prior_durable_run'])/'receipt.json', 'Exact sealed successful prior path')
        prior,self.prior_receipt_pin=verify_closed_prior_v12(args.prior_durable,spec)
        require(self.prior_receipt_pin==spec['prior_durable_receipt'], 'First original successful prior bytes unchanged')
        self.prior=self.prior_receipt_pin;no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Private evidence outside source checkout')
        self.run=args.work_root/('first_repeat_'+uuid.uuid4().hex[:8]);no_links(self.run);self.run.mkdir(parents=True,exist_ok=False)
        self.frozen=FrozenProject(self.run/'project',spec['inputs']);self.batch=NaturalSerialBatch(self.run,self.frozen,args.godot,spec['engine']['sha256'],self.persist)
        self.evidence=[];self.evidence_by_path={};self.installed_identity=None
        for row in [self.prior_receipt_pin,*prior['all_evidence_pins']]:self.remember(row)
        for step in prior['steps']:self.freeze_bytes(Path(step['output'])/'native.log',step['log_sha256'])
        self.receipt={'schema':'campaign_first_repeat_batch_v1','run':str(self.run),'started_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'source_spec':spec,'source_spec_sha256':canonical(spec),
                      'source_spec_file':args.fixed_source_spec_pin,'independent_review':args.fixed_review_pin,'prior_durable_receipt':self.prior_receipt_pin,'steps':[],'reports':{},'complete':False,
                      'normal_first_repeat_cases_and_restarts_qualified':False,'original19_qualified':False,'SDK_reward_once_qualified':False,'UI_qualified':False,'overall_goal_qualified':False}
        self.original_integrity=self.batch.integrity;self.batch.integrity=self.integrity;self.persist()

    def values(self,mode,profile):
        def build(output,nonce):
            pin=self.evidence_by_path[str(self.identity_path.resolve()).casefold()];token=prior_path=prior_sha=prior_token=''
            if mode.startswith('restart_'):_,_,handoff=actual_handoff(self,mode.removeprefix('restart_'));token=handoff['token']
            if mode=='repeat':path,first,handoff=actual_handoff(self,'first');prior_path=str(path);prior_sha=first['sha256'];prior_token=handoff['token']
            return {'CAMPAIGN_TERMINAL_OUTPUT':str(output),'CAMPAIGN_TERMINAL_NONCE':nonce,'CAMPAIGN_TERMINAL_MODE':mode,'CAMPAIGN_TERMINAL_PROFILE':str(profile),
                    'CAMPAIGN_TERMINAL_TOKEN':token,'CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0','CAMPAIGN_TERMINAL_IDENTITY_FILE':str(self.identity_path),'CAMPAIGN_TERMINAL_IDENTITY_SHA256':pin['sha256'],
                    'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE':prior_path,'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256':prior_sha,'CAMPAIGN_TERMINAL_PRIOR_TOKEN':prior_token}
        return build

    def validate(self,mode):
        def validator(step,output,nonce):
            self.receipt['reports'][mode]=self.consumer.validate(step,mode);self.persist()
        return validator

    def execute(self):
        self.frozen.prepare();require(native.install_native(self.frozen.project)==self.spec['native_dependencies'], 'Exact isolated native installation')
        self.frozen.before=inventory(self.frozen.project)
        self.batch.phase('cold_import',self.batch.profile('import'),['--headless','--editor','--import'],{},lambda *args:None,1200)
        self.frozen.freeze_cold();identity=identity_module().installed_identity(self.frozen.project);self.installed_identity=identity
        self.runtime_fields={k:identity[k] for k in ['content_version','rules_sha256','file_count','total_bytes']}
        self.runtime_fields.update(engine_binary_sha256=sha(self.args.godot),provider_sha256=sha(self.frozen.project/'scripts/run_content_identity.gd'))
        self.identity_path=self.run/'post_cold_identity.json';write_new(self.identity_path,{'runtime_fields':self.runtime_fields,'complete_identity':identity});self.freeze_bytes(self.identity_path)
        self.consumer=FirstRepeatEvidence(self,self.spec['full_labels'],self.spec['manifest']);self.persist()
        profile=self.batch.profile('natural_pair');arguments=['--headless','--script','res://tools/'+GD.name]
        for mode in MODES:
            self.batch.phase_with_exports(self,mode,self.spec['manifest'],mode,profile,arguments,self.values(mode,profile),self.validate(mode),180 if mode.startswith('restart_') else 1800)
        self.consumer.require_all()
        require(len(self.batch.steps)==len(self.batch.pids)==len(self.batch.nonces)==5 and all(s['complete'] for s in self.batch.steps) and set(self.receipt['reports'])==set(MODES), 'Five distinct closed successful native processes and four reports')
        self.integrity();self.receipt.update(complete=True,normal_first_repeat_cases_and_restarts_qualified=True);self.persist()

def main():
    require(__debug__, 'Assertions must stay enabled');sys.dont_write_bytecode=True
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',type=Path,required=True);p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--work-root',type=Path,default=Path('D:/CodexTemp/lsh-first-repeat'));p.add_argument('--write-recipe',type=Path);p.add_argument('--write-spec',type=Path)
    p.add_argument('--prior-durable',type=Path);p.add_argument('--source-spec',type=Path);p.add_argument('--independent-review',type=Path);p.add_argument('--run',action='store_true');args=p.parse_args()
    require(args.write_recipe is None or not args.run and args.write_spec is None, 'Recipe is source-only and cannot launch')
    if args.write_recipe:
        recipe=source_recipe(args);write_new(args.write_recipe,{'recipe_sha256':canonical(recipe),'recipe':recipe})
        print(json.dumps({'recipe_preflight':True,'recipe_sha256':canonical(recipe),'prior_closed_checked':False,'native_started':False}));return 0
    spec=source_spec(args);logical=canonical(spec)
    if not args.run:
        if args.write_spec:write_new(args.write_spec,{'source_spec_sha256':logical,'spec':spec})
        print(json.dumps({'preflight':True,'source_spec_sha256':logical,'prior_closed_checked':True,'native_started':False}));return 0
    require(args.write_spec is None and args.source_spec is not None and args.independent_review is not None, 'Exact seal and independent review required')
    saved,args.fixed_source_spec_pin=pinned_document(args.source_spec);review,args.fixed_review_pin=pinned_document(args.independent_review)
    require(saved['spec']==spec and saved['source_spec_sha256']==logical and review['schema']=='campaign_first_repeat_independent_review_v1' and review['independent'] is True
            and review['static_api_closure_passed'] is True and review['approved_stages']==[SCOPE] and review['producer_sha256']==sha(Path(__file__))
            and review['source_spec_sha256']==logical and review['source_spec_file_sha256']==args.fixed_source_spec_pin['sha256'], 'Exact limited independent native admission')
    suite=Suite(args,spec);code=0
    try:suite.execute()
    except BaseException as e:code=1;suite.receipt.update(complete=False,normal_first_repeat_cases_and_restarts_qualified=False,failure=repr(e))
    finally:
        try:suite.batch.release()
        except BaseException as e:code=1;suite.receipt.update(complete=False,normal_first_repeat_cases_and_restarts_qualified=False);suite.receipt.setdefault('finalization_failures',[]).append(repr(e))
        suite.receipt['lock_released']=not suite.batch.locked;suite.receipt['finished_utc']=dt.datetime.now(dt.timezone.utc).isoformat();suite.persist();write_new(suite.run/'receipt.json',suite.receipt)
        print(json.dumps({'run':str(suite.run),'complete':suite.receipt['complete'],'failure':suite.receipt.get('failure'),'overall_goal_qualified':False}))
    return code

if __name__=='__main__':raise SystemExit(main())
