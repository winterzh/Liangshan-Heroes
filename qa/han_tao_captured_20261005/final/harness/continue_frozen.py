"""Continue unchanged imported production with a repaired QA entry and fresh profile."""
from pathlib import Path
import sys,json,hashlib,shutil,time,uuid
sys.dont_write_bytecode=True
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.path.insert(0,str(repo/'tools'))
import run_character_art_qa as driver
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
import run_han_tao_capture_qa as case_driver
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
prior=base/'20261005_065428_d44621d5';project=prior/'project'
prior_receipt_path=prior/'evidence/receipt.json'
old=json.loads(prior_receipt_path.read_text(encoding='utf-8'))
assert old['source_root']==str(repo) and old['godot_sha256']==sha(shared.resolve_godot(None))
assert any(s['case']=='import' and s['passed'] for s in old['steps'])
assert old['lock_released'] and not old['source_changes'] and not old['private_source_changes']
assert not driver.source_changes(repo,old['source_files']) and not driver.source_changes(project,old['source_files'])
if running_engine() or shared.LOCK.exists():raise RuntimeError('ENGINE_SLOT_OCCUPIED')
run=base/('continuation_'+time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])
evidence=run/'evidence';evidence.mkdir(parents=True)
qa=repo/'tools/han_tao_capture_direction4_qa.gd';dest=project/'tools/han_tao_capture_direction4_qa.gd'
receipt={'complete':False,'run':str(run),'project':str(project),'source_root':str(repo),'source_files':old['source_files'],'steps':[],'continued_from':{'receipt_sha256':sha(prior_receipt_path),'path':str(prior_receipt_path),'unchanged_imported_project':str(project)},'qa_sha256':sha(qa),'driver_sha256':sha(repo/'tools/run_character_art_qa.py'),'continuation_driver_sha256':sha(Path(__file__)),'godot_sha256':old['godot_sha256'],'source_head':old.get('source_head'),'fresh_import':False,'visual':True,'scope':'Unchanged frozen/imported production. Only repaired QA entry replaced; new private profile and new evidence. No packaging/publish/other process control.'}
locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
    locked=True
    shutil.copyfile(qa,dest)
    harness=evidence/'harness';harness.mkdir()
    for p in [qa,Path(__file__),repo/'tools/run_han_tao_capture_qa.py',repo/'tools/run_character_art_qa.py',repo/'tools/han_tao_capture_body_fixture.gd']:shutil.copyfile(p,harness/p.name)
    profile=shared.create_private_profile(run,base/'profiles')
    env=driver.private_environment(profile)
    receipt['private_profile']=str(profile)
    directory=evidence/'han_tao';directory.mkdir()
    case=case_driver.parse_cases(repo,['han_tao=assets/direction4/han_tao_captured_20261005.json'])[0]
    receipt['selected_cases']=[case]
    case_env=env|{'ART_CHARACTER':'han_tao','ART_MANIFEST':'res://'+case['manifest'],'ART_QA_OUT':str(directory),'ART_VISUAL':'1'}
    driver.process_step(shared.resolve_godot(None),project,case_env,evidence,'han_tao',['--position','20000,20000','--script','res://tools/han_tao_capture_direction4_qa.gd'],600,'gl_compatibility',running_engine,receipt['steps'])
    receipt['character_results']=[case_driver.verify_report(case,directory,True)]
    for label,script,out_key in [('routing','skirmish_direction4_contract_test.gd','DIRECTION4_CONTRACT_OUT'),('inventory','character_direction4_inventory.gd','DIRECTION4_INVENTORY_OUT')]:
        folder=evidence/label;folder.mkdir()
        driver.process_step(shared.resolve_godot(None),project,env|{out_key:str(folder)},evidence,label,['--headless','--script','res://tools/'+script],600,'gl_compatibility',running_engine,receipt['steps'])
        data=json.loads((folder/('report.json' if label=='routing' else 'inventory.json')).read_text(encoding='utf-8'))
        assert data.get('passed') is True if label=='routing' else isinstance(data.get('units'),list)
    receipt['qa_unchanged']=sha(qa)==sha(dest)==receipt['qa_sha256']
    receipt['driver_unchanged']=sha(repo/'tools/run_character_art_qa.py')==receipt['driver_sha256']
    receipt['continuation_driver_unchanged']=sha(Path(__file__))==receipt['continuation_driver_sha256']
    receipt['complete']=all(receipt[k] for k in ['qa_unchanged','driver_unchanged','continuation_driver_unchanged'])
except BaseException as exc:
    receipt['failure']={'type':type(exc).__name__,'message':str(exc)}
finally:
    receipt['source_changes']=driver.source_changes(repo,receipt['source_files'])
    receipt['private_source_changes']=driver.source_changes(project,receipt['source_files'])
    receipt['godot_unchanged']=sha(shared.resolve_godot(None))==receipt['godot_sha256']
    receipt['engines_remaining']=running_engine()
    if locked:receipt['owned_lock_removed']=driver.release_owned_lock(shared.LOCK,run,receipt,receipt['engines_remaining'])
    receipt['lock_released']=not shared.LOCK.exists()
    receipt['complete']=receipt['complete'] and receipt['lock_released'] and not receipt['source_changes'] and not receipt['private_source_changes'] and receipt['godot_unchanged']
    receipt['artifacts']=[{'path':p.relative_to(evidence).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(evidence.rglob('*')) if p.is_file() and p.name!='receipt.json']
    (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if receipt['complete']:(base/'final_run.json').write_text(json.dumps({'run':str(run),'project':str(project)}),encoding='utf-8')
    print(json.dumps({'complete':receipt['complete'],'run':str(run),'checks':sum(r['checks'] for r in receipt.get('character_results',[])),'failure':receipt.get('failure')},ensure_ascii=False),flush=True)
if not receipt['complete']:sys.exit(1)
