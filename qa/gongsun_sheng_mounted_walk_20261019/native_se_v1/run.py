from pathlib import Path
import datetime,hashlib,json,shutil,sys,uuid
Q=Path(__file__).resolve().parent;R=Q.parents[2]
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019')
sys.path.insert(0,str(R/'tools'));import run_character_art_qa as common
shared,running=common.load_helpers(R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
assert not (E/'native_se_v1').exists(),'Never rerun an attempted frozen native candidate'
assert not running() and not shared.LOCK.exists(),'shared engine lane occupied'
binding=json.loads((Q/'prepared_binding.json').read_text());P=Path(binding['project']);assert all(sha(P/x['path'])==x['sha256'] for x in binding['files'])
assert all(sha(R/x['canonical_source'])==x['sha256'] for x in binding['inputs']['textures'].values())
O=E/'native_se_v1'/(datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);O.mkdir(parents=True)
receipt={'complete':False,'steps':[],'project':str(O),'scope':binding['inputs']['scope'],'runner_sha256':sha(Path(__file__)),'actual_unit_tested':False,'production_adopted':False};locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(O))
    locked=True;assert not running()
    for row in binding['files']:
        src=P/row['path'];dest=O/row['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest);assert sha(dest)==row['sha256']
    profile=shared.create_private_profile(O,Path('D:/CodexQA/gongsun_walk_se'));env=common.private_environment(profile);engine=shared.resolve_godot(None);receipt.update(profile=str(profile),engine_sha256=sha(engine))
    common.process_step(engine,O,env,O,'import',['--headless','--editor','--import','--quit'],180,'gl_compatibility',running,receipt['steps'])
    receipt['frozen']=[{'path':p.relative_to(O).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(O.rglob('*')) if p.is_file() and '.godot' not in p.relative_to(O).parts and p.suffix!='.log']
    common.process_step(engine,O,env,O,'native',['--resolution','2560x1440','--position','30000,30000','--script','res://preview.gd'],120,'gl_compatibility',running,receipt['steps'])
    report=json.loads((O/'report.json').read_text());assert report['passed'] and not report['failures'] and len(report['screenshots'])==4
    receipt.update(complete=True,native_checks=len(report['checks']),screenshots=report['screenshots'],observed_phase_transitions=len(report['phase_transitions']))
except BaseException as error:receipt['error']=repr(error)
finally:
    receipt['source_changes']=common.source_changes(O,receipt.get('frozen',[]));receipt['preservation']=[]
    for rel in ['qa/wu_yong_layered_full_pack_20261019/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
        rows=json.loads((R/rel).read_text());changed=common.source_changes(R,rows);receipt['preservation'].append({'manifest':rel,'files':len(rows),'changed':changed})
        if changed:receipt.update(complete=False,preservation_error=rel)
    if receipt['source_changes']:receipt['complete']=False
    if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(O):shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists();save(O/'receipt.json',receipt)
save(E/'latest_native_se_v1.json',{'receipt':str(O/'receipt.json')});print(json.dumps({k:receipt.get(k) for k in ['complete','native_checks','error','lock_released']}));assert receipt['complete']
