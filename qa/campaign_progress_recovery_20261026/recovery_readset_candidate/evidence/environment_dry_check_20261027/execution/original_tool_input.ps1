@'
from pathlib import Path
import ast, hashlib, importlib.util, json, subprocess, sys, uuid
sys.dont_write_bytecode=True
root=Path.cwd()
host=root/'qa/campaign_progress_recovery_20261026/recovery_readset_candidate/tests/readset/run_readset.py'
spec=importlib.util.spec_from_file_location('readset_environment_dry_check',host)
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
nonce=uuid.uuid4().hex
probe=Path(root.anchor)/'CodexQA/readset_env_probe'/nonce[:12]
m.h.identity.no_links(probe); m.io.fs_path(probe).mkdir(parents=True,exist_ok=False)
checks=[]
def check(condition,label):
    checks.append({'name':label,'passed':bool(condition)})
    if not condition: raise RuntimeError(label)
receipt={'schema':'readset_environment_host_dry_check_v1','complete':False,'engine_started':False,'original_profile_accessed':False,'synthetic_payload_only':True,'profile_root':str(probe),'checks':checks,'host_sha256':m.h.sha(m.io.fs_path(host)),'helper_sha256':m.h.sha(m.io.fs_path(Path(m.h.common.__file__))),'private_environment_calls':0}
try:
    ast.parse(host.read_text(encoding='utf-8'))
    check(True,'Python AST parses')
    help_result=subprocess.run([sys.executable,str(host),'--help'],capture_output=True,text=True,encoding='utf-8',errors='replace')
    receipt['help_exit_code']=help_result.returncode
    check(help_result.returncode==0 and '--execute' in help_result.stdout,'Actual Python --help exits zero without executing engine')
    profile=probe/'shared_profile'; profile.mkdir(exist_ok=False)
    base=m.h.common.private_environment(profile); receipt['private_environment_calls']+=1
    base_original=dict(base)
    src=probe/'synthetic_seed.json'; src.write_bytes(b'{"host_dry_check":true}\n')
    seed=profile/'inputs/seed.json'
    digest=hashlib.sha256(src.read_bytes()).hexdigest()
    m.p.copy(src,seed,digest)
    state={'private_seed':seed,'seed':src,'content_version':'host-environment-dry-check-only','engine_sha256':'0'*64,'original_inventory':{'files':{'5088120/1/record_0000000001.json':{'sha256':digest}}}}
    workers=host.parent
    producer=m.environment(state,workers,profile,nonce,'producer',base)
    producer['RS_OUTPUT']=str(probe/'producer')
    reader=m.environment(state,workers,profile,nonce,'attack_reader',base)
    check(base==base_original,'Stage creation leaves original base_env unchanged')
    check(producer is not base and reader is not base and producer is not reader,'Each stage has an independent copied environment')
    check('RS_OUTPUT' not in reader and 'RS_OUTPUT' not in base,'One stage mutation does not leak to another')
    check(producer['RS_PROFILE']==reader['RS_PROFILE']==str(profile),'Producer and reader share exact fresh profile')
    check(producer['RS_NONCE']==reader['RS_NONCE']==nonce,'Producer and reader retain exact batch nonce')
    check(producer['RS_PROCESS_NONCE']!=reader['RS_PROCESS_NONCE'],'Same profile receives distinct process nonce per stage')
    for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
        expected=profile/key.lower()
        m.io.owned(expected,profile)
        check(producer[key]==reader[key]==str(expected) and expected.is_dir(),'Shared profile exact owned directory '+key)
    check(producer['TEMP']!=producer['TMP'],'TEMP and TMP remain distinct private directories')
    check(producer['RS_SEED_PATH']==str(seed) and producer['RS_SEED_SHA']==digest and seed.is_relative_to(profile),'Producer receives only host-copied private seed')
    check(reader['RS_SEED_PATH']==reader['RS_SEED_SHA']=='','Reader receives no seed path or seed digest')
    check(str(src) not in producer.values() and str(src) not in reader.values(),'Host source seed is not exposed in worker environment')
    clone_nonce=uuid.uuid4().hex
    clone_profile=probe/'clone_profile'; clone_profile.mkdir(exist_ok=False)
    clone_base=m.h.common.private_environment(clone_profile); receipt['private_environment_calls']+=1
    check(all((clone_profile/k.lower()).is_dir() for k in ('APPDATA','LOCALAPPDATA','TEMP','TMP')),'Clone private environment exists before copying business tree')
    source=probe/'synthetic_business'
    for rel,payload in {'5088120/1/record_0000000001.json':b'{"synthetic":"record"}\n','5088120/1/writing/owner.json':b'{"synthetic":"owner"}\n','local_runs/synthetic/5088120/1/record_0000000001.json':b'{"synthetic":"lifecycle"}\n'}.items():
        file=source/rel; file.parent.mkdir(parents=True,exist_ok=True); file.write_bytes(payload)
    clone=clone_profile/'appdata/Godot/app_userdata/Host Environment Dry Check/continue/v1'
    m.io.fs_path(clone.parent).mkdir(parents=True,exist_ok=False)
    check(not clone.exists(),'Clone final continue/v1 destination is absent before copy')
    m.io.copy_account_tree(source,clone)
    check(m.io.snapshot(source)==m.io.snapshot(clone),'Real no-overwrite business-tree copy succeeds after environment creation')
    clone_env=m.environment(state,workers,clone_profile,clone_nonce,'clone_record',clone_base)
    for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
        check(clone_env[key]==str(clone_profile/key.lower()),'Clone profile exact directory '+key)
    check(clone_env['RS_SEED_PATH']==clone_env['RS_SEED_SHA']=='','Clone receives no original or private seed path')
    check(len({producer['RS_PROCESS_NONCE'],reader['RS_PROCESS_NONCE'],clone_env['RS_PROCESS_NONCE']})==3,'All three staged process nonces are independent')
    check(clone_env['RS_NONCE']==clone_nonce and clone_nonce!=nonce,'Clone uses independent batch nonce')
    check(all(e['STEAM_DISABLED']=='1' and e['CAMPAIGN_QA']=='' for e in (producer,reader,clone_env)),'All stage environments keep Steam disabled and CAMPAIGN_QA empty')
    rejected=False
    try: m.environment(state,workers,clone_profile,clone_nonce,'clone_record',base)
    except RuntimeError: rejected=True
    check(rejected,'Base environment from another profile is rejected')
    broken=dict(base); broken['TMP']=base['TEMP']; rejected=False
    try: m.environment(state,workers,profile,nonce,'attack_reader',broken)
    except RuntimeError: rejected=True
    check(rejected,'TMP incorrectly aliased to TEMP is rejected')
    check(base==base_original and receipt['private_environment_calls']==2,'Exactly one actual private_environment call per new profile')
    receipt['nonces']={'batch':nonce,'clone_batch':clone_nonce,'producer_process':producer['RS_PROCESS_NONCE'],'reader_process':reader['RS_PROCESS_NONCE'],'clone_process':clone_env['RS_PROCESS_NONCE']}
    receipt['profile_environment']={name:{k:env[k] for k in ('APPDATA','LOCALAPPDATA','TEMP','TMP','RS_SEED_PATH','RS_SEED_SHA')} for name,env in [('producer',producer),('reader',reader),('clone',clone_env)]}
    receipt['synthetic_clone_inventory']=m.io.snapshot(clone)
    receipt['complete']=True
except BaseException as error:
    import traceback
    receipt['error']=repr(error); receipt['traceback']=traceback.format_exc()
finally:
    receipt['check_count']=len(checks)
    target=probe/'receipt.json'
    with target.open('x',encoding='utf-8',newline='\n') as stream: json.dump(receipt,stream,ensure_ascii=False,indent=2); stream.write('\n')
    print(json.dumps({'complete':receipt['complete'],'checks':len(checks),'receipt':str(target),'receipt_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'host_sha256':receipt['host_sha256'],'engine_started':False,'error':receipt.get('error')},ensure_ascii=True))
if not receipt['complete']: raise SystemExit(1)
'@ | python -