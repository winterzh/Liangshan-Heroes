import copy,hashlib,json,pathlib,shutil,sys
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path(__file__).parent
sys.path.insert(0,str(R/'tools'))
import build_ruan_xiaoqi_layered_20261018 as builder
from build_ruan_xiaoqi_pushcart_20261018 import import_descriptor
def load(p):return json.loads(pathlib.Path(p).read_text('utf-8'))
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def save(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
assert not (E/'applied_grips.json').exists()
P=pathlib.Path(load(E/'prepared_pointer.json')['receipt']).parent
receipt=load(P/'receipt.json');assert receipt['state']=='complete' and receipt['checks']==138 and receipt['lock_released']
assert not load(P/'report.json')['failures']
raw_path=R/'assets/characters/ruan_xiaoqi_layer_fixes_20261018/prompt_set.json';manifest_path=R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json'
old_raw=load(raw_path);raw=copy.deepcopy(old_raw);before=load(manifest_path);candidate=load(E/'candidate_manifest.json')
changed={x['pose'] for x in load(E/'candidate_changes.json')};assert len(changed)==6
resource_names={'assets/anim/ruan_xiaoqi_layered_20261018_push_idle_'+d+'.tres' for d in ['se','sw','ne','nw']}|{'assets/anim/ruan_xiaoqi_layered_20261018_push_walk_'+d+'.tres' for d in ['ne','nw']}
for p in [raw_path,manifest_path,*[R/n for n in sorted(resource_names)]]:
    dest=E/'before_adoption'/p.relative_to(R);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
for pose_key in changed:
    pose=candidate['poses'][pose_key];d=pose_key[-2:];state=pose_key[:-3];row=candidate['sources'][pose['source']]
    raw['view_bindings'][state][d]={'path':row['candidate_origin'],'sha256':row['sha256'],'region':pose['region'],'root_x':pose['pivot_native'][0]}
    raw['hand_registration'][pose_key]=copy.deepcopy(pose['hand_registration'])
raw['registration_revision']=4
source_doc=R/'assets/characters/ruan_xiaoqi_grip_sources_20261018/prompt_set.json'
raw['grip_revision']={'source_document':source_doc.relative_to(R).as_posix(),'sha256':sha(source_doc),'selected':{'idle_padding':['se','sw','ne','nw'],'contact_a_rear':['ne','nw']},'resource_receipt':str(P/'receipt.json'),'resource_receipt_sha256':sha(P/'receipt.json'),'scope':'Six selected poses; all other18 and fixed cart retained. Other walk grip/gait/continuity remain open. All old generation requests retained.'}
assert raw['sources']==old_raw['sources'];save(raw_path,raw)
m=builder.intended()
for k,v in before['poses'].items():
    if k not in changed:assert m['poses'][k]==v,k
assert before['canonical_cart_geometry']==m['canonical_cart_geometry']
new_files=[]
for k,row in m['sources'].items():
    p=R/row['path']
    if not p.exists():
        assert k.startswith(('idle_grips_padded_','contact_a_rear_reach_'))
        shutil.copyfile(R/row['candidate_origin'],p);import_descriptor(p);assert sha(p)==row['sha256'];new_files += [row['path'],row['path']+'.import']
assert len(new_files)==4
actual_resources=[]
for n,content in builder.render(m).items():
    p=R/n
    if p.read_bytes()!=content.encode():
        assert n in resource_names,n;p.write_bytes(content.encode());actual_resources.append(n)
assert set(actual_resources)==resource_names
save(manifest_path,m);assert builder.intended()==m
save(E/'applied_grips.json',{'changed_poses':sorted(changed),'unchanged_poses':18,'new_files':new_files,'changed_resources':sorted(actual_resources),'cart_changed':False,'production_scripts_modified':False,'native_game_passed':False,'files':[{'path':p.relative_to(R).as_posix(),'sha256':sha(p)} for p in [raw_path,manifest_path,*[R/n for n in sorted(resource_names)],*[R/n for n in new_files]]]})
print(json.dumps({'changed_poses':sorted(changed),'new_files':new_files,'resources':len(actual_resources),'cart_or_production_scripts_changed':False}))
