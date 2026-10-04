from pathlib import Path
import json,hashlib,sys,copy,os
base=Path(__file__).parent;repo=Path('E:/ChatGPT/水浒');sys.path.insert(0,str(repo/'tools'))
import run_character_art_qa as driver
shared,running_engine=driver.load_helpers(repo)
run=base/'20261004_212322_72f6594f';project=run/'project';evidence=run/'evidence'
original=evidence/'receipt.json';out=evidence/'full_continuation_receipt.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not out.exists()
if running_engine():raise RuntimeError('Shared engine still occupied; wait without controlling other tasks')
assert shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run)
r=json.loads(original.read_text(encoding='utf-8'))
assert [(s['case'],s['passed']) for s in r['steps']]==[('import',True),('gou_lian',True),('routing',True)]
assert not r['source_changes'] and not r['private_source_changes']
for row in r['artifacts']:assert sha(evidence/row['path'])==row['sha256']
assert not driver.source_changes(repo,r['source_files']) and not driver.source_changes(project,r['source_files'])
assert sha(repo/driver.QA_DEST)==sha(project/driver.QA_DEST)==r['qa_sha256']
assert sha(Path(driver.__file__))==r['driver_sha256']
engine=shared.resolve_godot(None);assert sha(engine)==r['godot_sha256']
frozen={row['path']:row['sha256'] for row in r['source_files']}
runtime=shared.sources();assert all(p in frozen and sha(repo/p)==frozen[p] for p in runtime)
result=copy.deepcopy(r);result.pop('failure',None)
result['continued_from']={'receipt_path':str(original),'receipt_sha256':sha(original),'reason':'Only inventory pending because another project started its engine after routing. Same frozen project, sources, harness, profile and previous three passed steps authenticated.'}
env=os.environ.copy()
prefixes=("LSH_","RTS_","KH_","HNS_","HNA_","DAMING_","MENGZHOU_","SIEGE_","ART_","LC_","SJ_","SL_","DIRECTION4_","ZHU_","DEF_","STEAM_QA_","CAMPAIGN_QA_","PLAYTEST_")
for key in list(env):
 if key.startswith(prefixes) or key in ("CAMPAIGN_QA","STEAM_DISABLED"):env.pop(key,None)
for key,path in r['private_environment'].items():
 assert Path(path).is_dir() and Path(path).resolve().is_relative_to(Path(r['private_profile']).resolve())
 env[key]=path
env.update(STEAM_DISABLED="1",CAMPAIGN_QA="1",ART_QA_PROFILE=r['private_profile'])
try:
 directory=evidence/'inventory';directory.mkdir(exist_ok=True)
 driver.process_step(engine,project,env|{'DIRECTION4_INVENTORY_OUT':str(directory)},evidence,'inventory',['--headless','--script','res://tools/character_direction4_inventory.gd'],1000,'gl_compatibility',running_engine,result['steps'])
 assert isinstance(json.loads((directory/'inventory.json').read_text(encoding='utf-8'))['units'],list)
 result['source_changes']=driver.source_changes(repo,r['source_files'])
 result['private_source_changes']=driver.source_changes(project,r['source_files'])
 result['runtime_inventory_unchanged']=shared.sources()==runtime
 result['qa_unchanged']=sha(repo/driver.QA_DEST)==sha(project/driver.QA_DEST)==r['qa_sha256']
 result['driver_unchanged']=sha(Path(driver.__file__))==r['driver_sha256']
 result['godot_unchanged']=sha(engine)==r['godot_sha256']
 assert not result['source_changes'] and not result['private_source_changes'] and all(result[k] for k in ['runtime_inventory_unchanged','qa_unchanged','driver_unchanged','godot_unchanged'])
 result['complete']=True
except BaseException as exc:
 result['complete']=False;result['failure']={'type':type(exc).__name__,'message':str(exc)}
 raise
finally:
 result['engines_remaining']=running_engine()
 if shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run) and not result['engines_remaining']:shared.LOCK.unlink()
 result['lock_released']=not shared.LOCK.exists();result['complete']=bool(result.get('complete')) and result['lock_released']
 result['artifacts']=[{'path':p.relative_to(evidence).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(evidence.rglob('*')) if p.is_file() and p!=out]
 out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':result['complete'],'frozen_files':len(r['source_files']),'steps':[(s['case'],s['passed']) for s in result['steps']]}))
