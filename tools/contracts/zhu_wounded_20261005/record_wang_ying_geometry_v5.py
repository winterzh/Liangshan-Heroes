"""Preserve native Godot geometry and reproducible generator inputs as reference."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst)
    else:dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
base=ROOT.parent/'qa-zhu-wounded-20261005'
run=Path(read(base/'wang_ying_pose_geometry_v5_run.json')['run'])
r=read(run/'receipt.json')
assert r['complete'] and r['lock_released'] and r['result']['support_on_image_left']
assert r['result']['support_screen'][0]+60<r['result']['swing_screen'][0]
assert abs(r['result']['planted_boot_bottom_y'])<1e-6
for artifact in r['generator_artifacts']:
    p=ROOT/artifact['path']
    assert sha(p)==artifact['sha256']
    copied=run/'project'/p.name if p.suffix=='.gd' else run/p.name
    assert sha(copied)==artifact['sha256']
src=run/'project/wang_ying_walk_b_se_geometry_v5.png'
assert sha(src)==r['output_sha256']
dest=HERE/'guides/wang_ying_walk_b_se_geometry_v5.png'
preserve(src,dest)
preserve(run/'receipt.json',QA/'wang_ying_pose_geometry_v5.json')
job={'schema':1,'character':'wang_ying','state':'walk_b_se_geometry_v5',
    'method':'godot_3d_pose_reference','generation_id':None,
    'repository_path':dest.relative_to(ROOT).as_posix(),'output':dest.relative_to(ROOT).as_posix(),
    'sha256':sha(dest),'output_sha256':sha(dest),'native_size':[768,768],
    'prompt':'New deterministic short broad adult primitive geometry reference; red image-left flat support boot, blue image-right raised boot. No character bitmap read or edited; no costume/face/production sprite.',
    'references':[],'generator_artifacts':r['generator_artifacts'],'selected':False,'native_pixel_edits':False,
    'production_qualified':False}
jp=HERE/'jobs/wang_ying_walk_b_se_geometry_v5.json'
if jp.exists():assert read(jp)==job
else:jp.write_text(json.dumps(job,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
old=Path(read(base/'wang_ying_pose_geometry_v4_run.json')['run'])
review={'schema':1,'method':'godot_3d_pose_reference','scope':'Code-native new geometry only',
    'selected':job['repository_path'],'selected_sha256':job['sha256'],'receipt_sha256':sha(run/'receipt.json'),
    'generator_inputs':2,'input_drift':0,'directly_viewed':True,
    'support_image_side':'left','support_screen':r['result']['support_screen'],'swing_screen':r['result']['swing_screen'],
    'support_contact_bottom_y':r['result']['planted_boot_bottom_y'],
    'previous_geometry_rejected':{'run':str(old),'receipt_sha256':sha(old/'receipt.json'),
        'reason':'Initial camera projection placed the red support boot on image-right, matching the rejected A pattern; not an opposing-support guide'},
    'limits':['Abstract geometry only; actual native character pose/anatomy and gait still require visual review',
        'Robot box torso and leg colors do not belong to the character or game'],
    'production_qualified':False}
p=QA/'wang_ying_pose_geometry_review_v5.json';assert not p.exists()
p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'reference':job['repository_path'],'support_image_side':'left','generator_inputs':2,'input_drift':0,'production_qualified':False}))
