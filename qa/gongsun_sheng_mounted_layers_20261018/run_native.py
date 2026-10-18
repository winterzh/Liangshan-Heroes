"""One native source-render comparison after the existing Wu queue is terminal."""
from pathlib import Path
import datetime,hashlib,json,shutil,sys,uuid
R=Path(__file__).resolve().parents[2];Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_layers_20261018')
sys.path.insert(0,str(R/'tools'));import run_character_art_qa as common
shared,running=common.load_helpers(R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
state=json.loads(Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit/queue/state.json').read_text())
assert state['state']=='terminal','Existing Wu queue must finish first; never start another watcher'
assert not running() and not shared.LOCK.exists(),'shared Godot lane occupied'
assert not (E/'native_resources').exists(),'Never rerun a native attempted candidate'
binding=json.loads((E/'prepared_binding.json').read_text());P=Path(binding['project'])
assert all(sha(P/x['path'])==x['sha256'] for x in binding['frozen'])
data=json.loads((P/'inputs.json').read_text());assert all(sha(R/x['canonical_source'])==x['sha256'] for x in data['textures'].values())
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];O=E/'native_resources'/stamp;O.mkdir(parents=True)
receipt={'complete':False,'project':str(O),'scope':data['scope'],'steps':[],'actual_unit_tested':False,'production_adopted':False,'runner_sha256':sha(Path(__file__))};locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(O))
    locked=True;assert not running()
    for row in binding['frozen']:
        src=P/row['path'];dst=O/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(dst)==row['sha256']
    profile=shared.create_private_profile(O,Path('D:/CodexQA/gongsun_layer_profiles'));env=common.private_environment(profile);engine=shared.resolve_godot(None);receipt.update(profile=str(profile),engine_sha256=sha(engine))
    common.process_step(engine,O,env,O,'import',['--headless','--editor','--import','--quit'],180,'gl_compatibility',running,receipt['steps'])
    receipt['frozen']=[{'path':p.relative_to(O).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(O.rglob('*')) if p.is_file() and '.godot' not in p.relative_to(O).parts and p.suffix!='.log']
    common.process_step(engine,O,env,O,'native',['--resolution','1920x1280','--position','30000,30000','--script','res://preview.gd'],120,'gl_compatibility',running,receipt['steps'])
    report=json.loads((O/'report.json').read_text());assert report['resource_preview_complete'] and not report['failures'] and len(report['screenshots'])==4 and len(report['texture_references'])==11
    receipt.update(complete=True,native_checks=len(report['checks']),screenshots=report['screenshots'])
except BaseException as error:receipt['error']=repr(error)
finally:
    receipt['source_changes']=common.source_changes(O,receipt.get('frozen',[]));receipt['root_preservation']=[]
    for rel in ['qa/chao_gai_layered_full_pack_20261018/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
        rows=json.loads((R/rel).read_text());changed=common.source_changes(R,rows);receipt['root_preservation'].append({'manifest':rel,'files':len(rows),'changed':changed})
        if changed:receipt.update(complete=False,preservation_error=rel)
    if receipt['source_changes']:receipt['complete']=False
    if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(O):shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists();save(O/'receipt.json',receipt)
save(E/'latest_native.json',{'receipt':str(O/'receipt.json')});print(json.dumps({k:receipt.get(k) for k in ['complete','native_checks','error','lock_released']}));assert receipt['complete']
