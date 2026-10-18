"""Exclusive shared-lane native topology comparison, immutable after first attempt."""
from pathlib import Path
import datetime,hashlib,json,shutil,sys,uuid
R=Path(__file__).resolve().parents[2]
Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/chao_gai_semantic_hand_registration_v2_20261018')
sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
shared,running=common.load_helpers(R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')

assert not (E/'native_resources').exists(),'Do not rerun an attempted immutable candidate'
assert not running() and not shared.LOCK.exists(),'Shared Godot lane occupied'
binding=json.loads((E/'prepared_binding.json').read_text())
assert binding['prepared'] and not binding['native_executed']
prepared=Path(binding['project']);assert prepared==E/'prepared'
assert all(sha(prepared/x['path'])==x['sha256'] for x in binding['frozen'])
inputs=json.loads((prepared/'inputs.json').read_text())
assert all(sha(R/x['canonical_source'])==x['sha256'] for x in inputs['textures'].values())
previous=json.loads(Path(binding['previous_receipt']).read_text());assert previous['five_row_comparisons_rendered'] and previous['native_checks']==49
old_project=Path(previous['project']);assert not common.source_changes(old_project,previous['frozen'])
pins=[]
for rel in ['qa/tribute_cart_wheel_unit_20261018/runtime_inventory.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
    rows=json.loads((R/rel).read_text());assert not common.source_changes(R,rows);pins.append((rel,rows))
hud=sha(R/'scripts/hud.gd')
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
P=E/'native_resources'/stamp;P.mkdir(parents=True)
receipt={'complete':False,'project':str(P),'prepared_binding':str(E/'prepared_binding.json'),'steps':[],
    'scope':inputs['scope'],'production_adopted':False,'actual_game_unit_tested':False,'complete_attack_animation_accepted':False,
    'runner_sha256':sha(Path(__file__)),'previous_receipt':binding['previous_receipt']}
locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(P))
    locked=True;assert not running()
    for row in binding['frozen']:
        src=prepared/row['path'];dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(src,dst);assert sha(dst)==row['sha256']
    profile=shared.create_private_profile(P,Path('D:/CodexQA/chhand2_profiles'));env=common.private_environment(profile)
    engine=shared.resolve_godot(None);receipt.update(private_profile=str(profile),engine_sha256=sha(engine))
    common.process_step(engine,P,env,P,'import',['--headless','--editor','--import','--quit'],180,'gl_compatibility',running,receipt['steps'])
    receipt['frozen']=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size}
        for p in sorted(P.rglob('*')) if p.is_file() and '.godot' not in p.relative_to(P).parts and p.suffix!='.log']
    common.process_step(engine,P,env,P,'native',['--resolution','1920x1200','--position','30000,30000','--script','res://preview.gd'],120,'gl_compatibility',running,receipt['steps'])
    report=json.loads((P/'report.json').read_text());assert report['resource_preview_complete'] and not report['failures']
    assert len(report['screenshots'])==8 and len(report['texture_references'])==8
    receipt['complete']=True
except BaseException as error:
    receipt['error']=repr(error)
finally:
    if (P/'report.json').exists():
        report=json.loads((P/'report.json').read_text());receipt.update(native_checks=len(report['checks']),native_failures=report['failures'],screenshots=report['screenshots'])
    try:
        receipt['source_changes']=common.source_changes(P,receipt.get('frozen',[]))
        receipt['previous_frozen_changes']=common.source_changes(old_project,previous['frozen'])
        receipt['root_preservation']=[{'manifest':rel,'count':len(rows),'changed':common.source_changes(R,rows)} for rel,rows in pins]
        receipt['root_hud_unchanged']=sha(R/'scripts/hud.gd')==hud
        assert not receipt['source_changes'] and not receipt['previous_frozen_changes'] and receipt['root_hud_unchanged']
        assert all(not row['changed'] for row in receipt['root_preservation'])
        assert all(sha(R/x['canonical_source'])==x['sha256'] for x in inputs['textures'].values())
    except BaseException as error:receipt.update(complete=False,preservation_error=repr(error))
    if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(P):shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists();save(P/'receipt.json',receipt)
save(E/'latest.json',{'receipt':str(P/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['complete','native_checks','error','preservation_error','lock_released']},ensure_ascii=False))
assert receipt['complete']
