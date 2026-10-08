# SYNTHETIC / PURE HOST / NO GODOT / NO POPEN. Never a native fixture.
import sys, pathlib, json, hashlib, uuid, copy, importlib, datetime
from types import SimpleNamespace
sys.dont_write_bytecode = True
ROOT=pathlib.Path(r'D:\AI项目\水浒\开发工程')
QA=ROOT/'qa/campaign_progress_recovery_20261008'
sys.path.insert(0,str(ROOT/'tools'))
M={v:importlib.import_module('campaign_original19_debug_faults_v'+str(v)) for v in [1,2]}
EXPECTED={1:'0e9c1f37eb1c1bf24a74a5e2007c3e27bd864f0e391b2dfd483c1295ec0e42a8',2:'10aa7439c209eec1956d2d52ad2512097cf2e843f0c9444d41aaa7a77ee02558'}
def sha(raw):return hashlib.sha256(raw).hexdigest()
def canonical(value):return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
def put(path,raw):path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
class FixedBytesStub:
    # Only first-byte read/registry behavior; no real serial runtime or process.
    def __init__(self,run,fields):self.run=run;self.runtime_fields=fields;self.evidence_by_path={}
    def freeze_bytes(self,path,expected=None):
        path=pathlib.Path(path);raw=path.read_bytes();key=str(path.resolve()).casefold()
        row={'path':str(path.resolve()),'bytes':len(raw),'sha256':sha(raw)}
        if expected is not None and row['sha256']!=expected:raise RuntimeError('synthetic original expected SHA drift')
        if key in self.evidence_by_path and self.evidence_by_path[key]!=row:raise RuntimeError('synthetic first pin drift')
        self.evidence_by_path[key]=row;return raw
    def read_fixed(self,path):return json.loads(self.freeze_bytes(path))
    def persist(self):pass
BASE=pathlib.Path('D:/CodexTemp/lsh-original19-synthetic-host-review-20261009')/uuid.uuid4().hex
BASE.mkdir(parents=True,exist_ok=False)
fields={'content_version':'SYNTHETIC_ONLY','rules_sha256':'a'*64,'file_count':1,'total_bytes':1,'engine_binary_sha256':'e'*64,'provider_sha256':'b'*64}
def fixture(version,scenario):
    mod=M[version];run=BASE/f'v{version}_{scenario}';out=run/'steps/synthetic_fault';profile=run/'profiles/synthetic';user=profile/'appdata/Godot/app_userdata/SYNTHETIC_ONLY'
    out.mkdir(parents=True);user.mkdir(parents=True)
    suite=FixedBytesStub(run,fields);nonce=uuid.uuid4().hex;token=uuid.uuid4().hex;pid=123456789
    context={'mode':'campaign','level_id':'level1','waves':0};scope={'owner':'','content_version':fields['content_version'],'engine_sha256':fields['engine_binary_sha256']}
    intent={'schema':'campaign_progress_intent_v1','token':token,'context':context,'profile_id':'campaign_level1_v1','owner':'','content_version':scope['content_version'],'engine_sha256':scope['engine_sha256'],'victory':True,'result':{'core_cleared':True,'story_complete':True,'story_done':4,'story_total':4,'done_ids':['merchant_cover','wine_scheme','no_bloodshed','all_safe'],'contract_version':2}}
    directory=user/'continue/v1/local_runs'/token/'5088120/1';previous='0'*64
    for g in [1,2]:
        doc={'schema':'local_campaign_continue_lifecycle_v2','generation':g,'token':token,'context':context,'scope':scope,'state':'active' if g==1 else 'terminal','victory':g==2,'progress_state':'none' if g==1 else 'pending','intent':{} if g==1 else intent,'progress_receipt':{}}
        payload=canonical(doc);env={'magic':'LH_LOCAL_CONTINUE_LIFECYCLE','version':'1','app':'5088120','owner':'1','revision':str(g),'previous_sha256':previous,'payload_bytes':str(len(payload)),'payload_sha256':sha(payload),'payload':payload.decode()};raw=canonical(env);put(directory/f'record_{g:010d}.json',raw);previous=sha(raw)
    public_raw=b'[progress]\nowner=""\nrecords={}\n';put(user/'campaign.cfg',public_raw)
    memory={'records':{},'unlocked':1,'owner':''};cloud={'dirty':True,'pending':False,'revision':7}
    ready={'schema':'campaign_natural_file_fault_ready_v1','pid':pid,'nonce':nonce,'case':'readback_semantic_mismatch','user_directory':str(user),'identity':fields,'context':context,'orders':27,'prior_CFG_sha256':sha(public_raw),'original_progress':memory,'original_cloud':cloud}
    put(out/'file_fault_ready.json',canonical(ready));suite.read_fixed(out/'file_fault_ready.json')
    injection={'schema':'SYNTHETIC_NO_NATIVE','notice':'Artificial source-only regression data; Popen and debugger were not exercised.'};put(out/'fault_injection.json',canonical(injection));injection_sha=sha(suite.freeze_bytes(out/'fault_injection.json'))
    target=user/'campaign_cfg_candidates/v1'/('c'*32)/'candidate.cfg';original=b'SYNTHETIC_ORIGINAL_CANDIDATE\n';changed=original+b'SYNTHETIC_CHANGED_CANDIDATE\n';put(target,changed)
    c=mod.FaultController.__new__(mod.FaultController);c.suite=suite;c.child=SimpleNamespace(pid=pid);c.step={'pid':pid,'nonce':nonce,'output':str(out),'profile':str(profile)};c.case='readback_semantic_mismatch';c.output=out;c.profile=profile;c.window={'code':'CFG_READBACK_SHA'};c.injection=injection_sha;c.target=target;c.original=original;c.changed=changed;c.backup=original;c.directory_identity=None;c.repaired=False;c.live=lambda:None
    c.ready_original=copy.deepcopy(ready);c.user=user;c.life_original=c.lifecycle(user)
    pending={'case':c.case,'code':c.window['code'],'coordinator_id':-101,'writer_id':-102,'lifecycle_id':-103,'proposal_id':-104,'proposal_semantics':{'ok':True,'sections':{'progress':{'owner':{'variant_type':4,'canonical':'[value]\nvalue=""\n'}}}},'intent':copy.deepcopy(intent),'gen1_sha256':c.life_original['records'][0]['sha256'],'gen2_sha256':c.life_original['records'][1]['sha256'],'actual_memory':copy.deepcopy(memory),'actual_cloud':copy.deepcopy(cloud),'writer_stage':'staging','prior_CFG_sha256':sha(public_raw),'injection_sha256':injection_sha}
    if scenario=='pending_gen1_SHA':pending['gen1_sha256']='d'*64
    elif scenario=='pending_gen2_SHA':pending['gen2_sha256']='d'*64
    elif scenario=='pending_intent':pending['intent']['result']['story_done']=3
    elif scenario=='pending_memory':pending['actual_memory']['unlocked']=2
    elif scenario=='pending_cloud':pending['actual_cloud']['revision']=8
    elif scenario=='disk_gen2_replace':
        # Replace with another canonical nine-string envelope, after initial pin.
        path=directory/'record_0000000002.json';env=json.loads(path.read_bytes());doc=json.loads(env['payload']);doc['intent']['result']['story_done']=3;payload=canonical(doc);env.update(payload=payload.decode(),payload_bytes=str(len(payload)),payload_sha256=sha(payload));put(path,canonical(env))
    elif scenario=='disk_extra_gen3':put(directory/'record_0000000003.json',b'SYNTHETIC_EXTRA_GEN3')
    elif scenario!='valid_negative_refcounted_IDs':raise RuntimeError('unknown synthetic scenario')
    put(out/'file_fault_pending.json',canonical(pending));before=target.read_bytes();error=None;returned=None
    try:returned=c.repair_if_pending()
    except Exception as e:error=f'{type(e).__name__}: {e}'
    after=target.read_bytes()
    return {'version':version,'scenario':scenario,'fixture':str(run),'before_target_sha256':sha(before),'after_target_sha256':sha(after),'target_modified':before!=after,'restored_original':after==original,'repair_returned':returned,'failure':error,'repair_artifact_written':(out/'fault_repaired.json').exists(),'synthetic':True,'pure_host':True,'noNative':True,'real_Popen_and_live_debugger_and_constructor_skipped':True}
for v in [1,2]:assert sha((ROOT/f'tools/campaign_original19_debug_faults_v{v}.py').read_bytes())==EXPECTED[v]
scenarios=['pending_gen1_SHA','pending_gen2_SHA','pending_intent','pending_memory','pending_cloud','disk_gen2_replace','disk_extra_gen3']
rows=[fixture(v,s) for v in [1,2] for s in scenarios]
positive=fixture(2,'valid_negative_refcounted_IDs')
assert all(x['target_modified'] and x['repair_returned'] is True for x in rows if x['version']==1)
assert all(not x['target_modified'] and x['failure'] is not None and not x['repair_artifact_written'] for x in rows if x['version']==2)
assert positive['repair_returned'] is True and positive['restored_original']
result={'schema':'original19_debug_faults_synthetic_pure_host_repro_v1_v2','recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_sha256':EXPECTED,'synthetic':True,'pure_host':True,'noNative':True,'real_Popen_debugger_Godot_process_ownership_not_tested':True,'temporary_fixture_root':str(BASE),'source_mutated':False,'production_or_real_player_profile_modified':False,'V1_all7_drift_cases_wrongly_modified_target':True,'V2_all7_drift_cases_refused_before_target_modification':True,'V2_negative_nonzero_RefCounted_ID_positive':positive,'rows':rows,'approved_stages':[],'native_qualified':False,'full_original19_qualified':False}
output=QA/'ORIGINAL19_DEBUG_FAULTS_SYNTHETIC_HOST_REPRO_V1_V2.json'
with output.open('x',encoding='utf-8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
print('SYNTHETIC_NO_NATIVE rows',len(rows),'V1 wrongly repaired7 V2 refused7, negativeIDs positive pass')
print('RESULT_SHA',sha(output.read_bytes()));print('FIXTURE_ROOT',BASE)
