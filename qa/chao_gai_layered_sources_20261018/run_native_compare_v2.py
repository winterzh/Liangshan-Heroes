"""Run only after mounted comparison actually completed and shared lane is idle."""
from pathlib import Path
import datetime, hashlib, json, shutil, sys, uuid

R = Path(__file__).resolve().parents[2]
Q = Path(__file__).resolve().parent
E = Path(r'D:/CodexEvidence/shuihu/chao_gai_layered_recheck_20261018')
M = Path(r'D:/CodexEvidence/shuihu/gongsun_mounted_idle_mass_20261018')
sys.path.insert(0, str(R/'tools'))
import run_character_art_qa as common
shared, running = common.load_helpers(R)

def sha(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()

def save(path, value):
    with path.open('x', encoding='utf-8') as handle:
        handle.write(json.dumps(value, ensure_ascii=False, indent=2)+'\n')

assert not (E/'success.json').exists(), 'Completed immutable comparison must not be rerun'
assert (M/'latest.json').is_file(), 'Finish the existing mounted comparison first'
mounted_path = Path(json.loads((M/'latest.json').read_text(encoding='utf-8'))['receipt'])
assert mounted_path.resolve().is_relative_to((M/'native_resources').resolve())
mounted = json.loads(mounted_path.read_text(encoding='utf-8')); assert mounted['complete']
assert not running() and not shared.LOCK.exists(), 'Shared engine lane occupied'
prepared = json.loads((E/'prepared_binding.json').read_text(encoding='utf-8'))
assert prepared['prepared'] and not prepared['native_executed']
prepared_project = Path(prepared['project']); assert prepared_project == E/'prepared'
assert all(sha(prepared_project/x['path']) == x['sha256'] for x in prepared['frozen'])
inputs = json.loads((prepared_project/'inputs.json').read_text(encoding='utf-8'))
assert all(sha(R/x['canonical_source']) == x['sha256'] for x in inputs['textures'].values())
stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
P = E/'native_resources'/stamp; P.mkdir(parents=True, exist_ok=False)
pins = []
for rel in ['qa/tribute_cart_wheel_unit_20261018/runtime_inventory.json',
            'qa/tribute_cart_wheel_unit_20261018/protected_next.json',
            'qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    value = json.loads((R/rel).read_text(encoding='utf-8'))
    rows = value if isinstance(value,list) else value.get('files',value.get('source_files',value.get('entries',[])))
    assert rows and not common.source_changes(R, rows)
    pins.append((rel,rows))
receipt = {'complete':False,'scope':'original/actor/actor+fixed-cart resource comparison only',
    'project':str(P),'prepared_binding':str(E/'prepared_binding.json'),
    'mounted_receipt':str(mounted_path),'steps':[],'production_adopted':False,
    'actual_game_unit_tested':False,'wheel_rotation_tested':False,
    'rendered_art_accepted':False,'runner_sha256':sha(Path(__file__))}
locked = False
try:
    with shared.LOCK.open('x',encoding='utf-8') as handle: handle.write(str(P))
    locked = True; assert not running()
    for row in prepared['frozen']:
        source = prepared_project/row['path']; target = P/row['path']
        assert not source.is_symlink() and sha(source) == row['sha256']
        target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(source,target)
        assert sha(target) == row['sha256']
    profile = shared.create_private_profile(P,Path('D:/CodexQA/chgl_profiles'))
    env = common.private_environment(profile); receipt['private_profile']=str(profile)
    engine = shared.resolve_godot(None); receipt['engine_sha256']=sha(engine)
    common.process_step(engine,P,env,P,'import',['--headless','--editor','--import','--quit'],180,'gl_compatibility',running,receipt['steps'])
    frozen = [{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size}
              for p in sorted(P.rglob('*')) if p.is_file() and '.godot' not in p.relative_to(P).parts and p.suffix != '.log']
    receipt['frozen']=frozen
    common.process_step(engine,P,env,P,'native',['--resolution','1920x960','--position','30000,30000','--script','res://preview.gd'],120,'gl_compatibility',running,receipt['steps'])
    report=json.loads((P/'report.json').read_text(encoding='utf-8'))
    assert report['resource_preview_complete'] and not report['failures']
    assert len(report['screenshots'])==4
    receipt['native_checks']=len(report['checks']); receipt['screenshots']=report['screenshots']
    receipt['comparison_source_changes']=common.source_changes(P,frozen)
    receipt['root_preservation']=[{'manifest':rel,'count':len(rows),'changed':common.source_changes(R,rows)} for rel,rows in pins]
    assert not receipt['comparison_source_changes'] and all(not x['changed'] for x in receipt['root_preservation'])
    assert all(sha(R/x['canonical_source'])==x['sha256'] for x in inputs['textures'].values())
    receipt['complete']=True
except BaseException as error:
    receipt['error']=repr(error)
finally:
    if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(P): shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists()
    save(P/'receipt.json',receipt)
save(E/('success.json' if receipt['complete'] else 'failure_'+stamp+'.json'),{'receipt':str(P/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['complete','native_checks','error','lock_released']},ensure_ascii=False))
assert receipt['complete']
