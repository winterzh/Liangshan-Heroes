import copy,hashlib,json,pathlib,shutil,sys
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path(__file__).parent
sys.path.insert(0,str(R/'tools'))
import build_ruan_xiaoqi_layered_20261018 as builder
from build_ruan_xiaoqi_pushcart_20261018 import import_descriptor

def load(p):return json.loads(pathlib.Path(p).read_text('utf-8'))
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def save(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())

assert not (E/'applied_low_steps.json').exists()
P=pathlib.Path(load(E/'prepared_pointer.json')['receipt']).parent
receipt=load(P/'receipt.json');assert receipt['state']=='complete' and receipt['checks']==138 and receipt['lock_released']
assert not load(P/'report.json')['failures']
raw_path=R/'assets/characters/ruan_xiaoqi_layer_fixes_20261018/prompt_set.json'
manifest_path=R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json'
before=load(manifest_path);old_raw=load(raw_path);raw=copy.deepcopy(old_raw)
candidate=load(E/'candidate_manifest.json');new_sources=load(R/'assets/characters/ruan_xiaoqi_nw_walk_20261018/prompt_set.json')
by_key={r['key']:r for r in new_sources['sources']}
changed=['push_contact_b_nw','push_passing_b_nw']
backup=E/'before_adoption'
for p in [raw_path,manifest_path,R/'assets/anim/ruan_xiaoqi_layered_20261018_push_walk_nw.tres']:
    dest=backup/p.relative_to(R);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
for pose_key,source_key in [('push_contact_b_nw','contact_b_feet'),('push_passing_b_nw','passing_b')]:
    row=by_key[source_key];assert sha(R/row['path'])==row['sha256']
    pose=candidate['poses'][pose_key];state=pose_key[:-3]
    raw['view_bindings'][state]['nw']={'path':row['path'],'sha256':row['sha256'],'region':pose['region'],'root_x':pose['pivot_native'][0]}
    old=old_raw['hand_registration'][pose_key]
    raw['hand_registration'][pose_key]={
        'manual_source_grip_centres':[pose['hand_registration']['manual_source_near_grip']],
        'manual_cart_grip_targets':[old['manual_cart_grip_targets'][0]],
        'translation_per_body_size':[v/pose['virtual_canvas_reference'] for v in pose['draw_offset_px']],
        'method':'Translation-only alignment to the prior approximate near-grip anchor. Far grip and natural gait/grounding not accepted; no claim of zero geometric residual or exact source-pixel preservation by generation.'}
raw['registration_revision']=3
raw['nw_low_walk_revision']={'sources':'assets/characters/ruan_xiaoqi_nw_walk_20261018/prompt_set.json','sha256':sha(R/'assets/characters/ruan_xiaoqi_nw_walk_20261018/prompt_set.json'),'selected':['contact_b_feet','passing_b'],'rejected':['contact_b_initial'],'native_resource_receipt':str(P/'receipt.json'),'native_resource_receipt_sha256':sha(P/'receipt.json')}
assert raw['sources']==old_raw['sources']
save(raw_path,raw)
m=builder.intended()
for k,v in before['poses'].items():
    if k not in changed:assert m['poses'][k]==v,k
assert m['canonical_cart_geometry']==before['canonical_cart_geometry']
new_files=[]
for key,row in m['sources'].items():
    target=R/row['path']
    if not target.exists():
        assert key.startswith(('contact_b_nw_low_','passing_b_nw_low_'))
        shutil.copyfile(R/row['candidate_origin'],target);import_descriptor(target)
        assert sha(target)==row['sha256'];new_files.extend([row['path'],row['path']+'.import'])
assert len(new_files)==4
outputs=builder.render(m);changed_resources=[]
for n,content in outputs.items():
    p=R/n
    if p.read_bytes()!=content.encode():
        assert n=='assets/anim/ruan_xiaoqi_layered_20261018_push_walk_nw.tres',n
        p.write_bytes(content.encode());changed_resources.append(n)
save(manifest_path,m)
assert len(changed_resources)==1
assert builder.intended()==m
save(E/'applied_low_steps.json',{'changed_poses':changed,'other_poses_unchanged':22,'new_files':new_files,'changed_resources':changed_resources,'cart_changed':False,'source_bitmaps_modified':False,'production_scripts_modified':False,'native_game_passed':False,'files':[{'path':p.relative_to(R).as_posix(),'sha256':sha(p)} for p in [raw_path,manifest_path,R/changed_resources[0],*[R/n for n in new_files]]]})
print(json.dumps({'changed_poses':changed,'unchanged_poses':22,'new_files':new_files,'changed_resources':changed_resources,'cart_changed':False}))
