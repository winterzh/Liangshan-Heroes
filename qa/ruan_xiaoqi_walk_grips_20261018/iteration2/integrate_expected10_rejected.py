"""Prepare reviewable integration files; apply only after this exact resource batch passes.

This is a local, recorded staging helper, not a game startup tool. --prepare
never writes production assets. --apply-after-native is separately guarded by
the real completed resource receipt, every frozen byte and the retained before
inventory. It does not claim the later Battle/PCK acceptance has happened.
"""
import argparse,copy,hashlib,json,pathlib,shutil,sys
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path(__file__).parent
sys.path.insert(0,str(R/'tools'))
import build_ruan_xiaoqi_layered_20261018 as builder
from build_ruan_xiaoqi_pushcart_20261018 import import_descriptor
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(pathlib.Path(p).read_text('utf-8'))
def save(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
parser=argparse.ArgumentParser(description=__doc__);mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument('--prepare',action='store_true');mode.add_argument('--apply-after-native',action='store_true');args=parser.parse_args()
if args.prepare:assert not (E/'integration_plan.json').exists(),'Already prepared; inspect/resume the retained batch rather than overwrite it'
baseline=load(R/'qa/ruan_xiaoqi_grip_20261018/runtime_inventory.json')
for row in baseline:assert sha(R/row['path'])==row['sha256'],row['path']
resource_path=pathlib.Path(load(E/'prepared_pointer.json')['receipt']);receipt=load(resource_path);P=pathlib.Path(receipt['project'])
for row in receipt['frozen']:assert sha(P/row['path'])==row['sha256'],row['path']
if args.apply_after_native:
    assert receipt['state']=='complete' and receipt['art_resource_preview_complete'] and receipt['lock_released']
    report=load(P/'report.json');assert report['art_resource_preview_complete'] and not report['failures'] and all(x['passed'] for x in report['checks'])
    assert not (E/'applied_walk_grips.json').exists()
raw_path=R/'assets/characters/ruan_xiaoqi_layer_fixes_20261018/prompt_set.json';manifest_path=R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json'
before=load(manifest_path);old_raw=load(raw_path);selection=copy.deepcopy(old_raw);candidate=load(E/'candidate_manifest.json');changes=load(E/'candidate_changes.json');changed={x['pose'] for x in changes};assert len(changed)==14
for name in changed:
    p=candidate['poses'][name];row=candidate['sources'][p['source']];state=name[:-3];d=name[-2:]
    selection['view_bindings'][state][d]={'path':row['candidate_origin'],'sha256':row['sha256'],'region':p['region'],'root_x':p['pivot_native'][0]}
    selection['hand_registration'][name]=copy.deepcopy(p['hand_registration'])
selection['registration_revision']=5
source_doc=R/'assets/characters/ruan_xiaoqi_walk_grips_20261018/prompt_set.json'
selection['walk_grip_revision']={'source_document':source_doc.relative_to(R).as_posix(),'sha256':sha(source_doc),'changed_poses':sorted(changed),'resource_receipt':str(resource_path),'resource_qualification':'complete' if args.apply_after_native else 'pending','scope':'Remaining fourteen walk poses; prior six body and four fixed-cart poses retained. Exact finger contact, anatomical gait/foot-root continuity and whole art remain unaccepted.'}
if args.apply_after_native:selection['walk_grip_revision']['resource_receipt_sha256']=sha(resource_path)
assert selection['sources']==old_raw['sources']
selection_path=E/'future_integration/source_selection.json'
if args.apply_after_native:
    saved=E/'prepared_integration_archive';assert not saved.exists();saved.mkdir()
    plan_before=load(E/'integration_plan.json');assert sha(selection_path)==plan_before['source_selection_sha256']
    for path in [selection_path,E/'integration_plan.json',E/'future_integration/project/assets/direction4/level1_ruan_xiaoqi_layered_20261018.json',*[E/'future_integration/project'/n for n in plan_before['changed_resources']]]:
        dest=saved/path.relative_to(E);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,dest)
save(selection_path,selection)
original_raw=builder.RAW;builder.RAW=selection_path
try:m=builder.intended()
finally:builder.RAW=original_raw
for name,v in before['poses'].items():
    if name not in changed:assert m['poses'][name]==v,name
assert before['canonical_cart_geometry']==m['canonical_cart_geometry']
for name in changed:
    for k in ['region','margin','pivot_native','virtual_canvas_reference','draw_scale','draw_offset_px','visible_top','source','body_height_target']:
        assert m['poses'][name][k]==candidate['poses'][name][k],(name,k)
art=E/'future_integration/project';art.mkdir(parents=True,exist_ok=True);new_files=[]
for key,row in m['sources'].items():
    source=R/row['candidate_origin'];dest=art/row['path'];dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.exists():assert sha(dest)==row['sha256']
    else:shutil.copyfile(source,dest)
    assert sha(source)==sha(dest)==row['sha256']
    if not (R/row['path']).exists():new_files += [row['path'],row['path']+'.import']
assert len(new_files)==10
renderer_root=builder.renderer.ROOT;builder.renderer.ROOT=art
try:outputs=builder.render(m)
finally:builder.renderer.ROOT=renderer_root
expected={'assets/anim/ruan_xiaoqi_layered_20261018_push_walk_'+d+'.tres' for d in ['se','sw','ne','nw']};changed_resources=[]
for name,content in outputs.items():
    if (R/name).read_bytes()!=content.encode():
        assert name in expected,name;changed_resources.append(name)
        target=art/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(content.encode())
assert set(changed_resources)==expected
save(art/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json',m)
plan={'resource_receipt':str(resource_path),'resource_state':receipt['state'],'resource_before_sha256':sha(resource_path),'before_inventory':baseline,'changed_poses':sorted(changed),'unchanged_poses':10,'prior_body_poses_retained':6,'fixed_cart_poses_retained':4,'new_runtime_files':new_files,'changed_resources':sorted(changed_resources),'future_active_sources':len(m['sources']),'future_native_references_expected':176,'production_applied':args.apply_after_native,'native_game_passed':False,'future_manifest_sha256':sha(art/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json'),'source_selection_sha256':sha(selection_path)}
if args.apply_after_native:
    for path in [raw_path,manifest_path,*[R/n for n in sorted(changed_resources)]]:
        backup=E/'before_adoption'/path.relative_to(R);backup.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,backup)
    for key,row in m['sources'].items():
        target=R/row['path']
        if not target.exists():shutil.copyfile(R/row['candidate_origin'],target);import_descriptor(target)
        assert sha(target)==row['sha256']
    raw_path.write_bytes(selection_path.read_bytes());manifest_path.write_bytes((art/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json').read_bytes())
    for name in changed_resources:(R/name).write_bytes((art/name).read_bytes())
    save(E/'applied_walk_grips.json',plan)
else:
    save(E/'integration_plan.json',plan)
    for row in baseline:assert sha(R/row['path'])==row['sha256'],row['path']
print(json.dumps({'mode':'applied_for_new_native_game' if args.apply_after_native else 'prepared_only','changed_poses':14,'unchanged_poses':10,'new_runtime_files':len(new_files),'changed_resources':len(changed_resources),'resource_state':receipt['state'],'native_game_passed':False}))
