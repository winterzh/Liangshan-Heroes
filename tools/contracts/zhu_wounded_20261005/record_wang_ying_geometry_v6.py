"""Preserve two direction-specific native geometry references and source inputs."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
QA=ROOT/'qa/zhu_wounded_20261005';base=ROOT.parent/'qa-zhu-wounded-20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst)
    else:dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
rows=[]
for d in ('sw','nw'):
    run=Path(read(base/f'wang_ying_pose_geometry_{d}_v6_run.json')['run']);r=read(run/'receipt.json')
    assert r['complete'] and r['lock_released'] and not r['result']['support_on_image_left']
    assert r['result']['swing_screen'][0]+60<r['result']['support_screen'][0]
    assert abs(r['result']['planted_boot_bottom_y'])<1e-6
    for artifact in r['generator_artifacts']:
        p=ROOT/artifact['path'];assert sha(p)==artifact['sha256']
        copied=run/'project'/p.name if p.suffix=='.gd' else run/p.name
        if p.suffix=='.json':copied=run/'project/geometry_config.json'
        assert sha(copied)==artifact['sha256']
    src=run/f'project/wang_ying_walk_b_{d}_geometry_v6.png';assert sha(src)==r['output_sha256']
    dest=HERE/f'guides/wang_ying_walk_b_{d}_geometry_v6.png';preserve(src,dest)
    preserve(run/'receipt.json',QA/f'wang_ying_pose_geometry_{d}_v6.json')
    job={'schema':1,'character':'wang_ying','state':f'walk_b_{d}_geometry_v6',
        'method':'godot_3d_pose_reference','generation_id':None,'references':[],
        'repository_path':dest.relative_to(ROOT).as_posix(),'output':dest.relative_to(ROOT).as_posix(),
        'sha256':sha(dest),'output_sha256':sha(dest),'native_size':[768,768],
        'prompt':f'New deterministic short broad adult {d.upper()} primitive geometry; red image-right flat support, blue image-left raised boot. No source bitmap read or edited. No costume, face or production artwork.',
        'generator_artifacts':r['generator_artifacts'],'selected':False,'native_pixel_edits':False,'production_qualified':False}
    jp=HERE/f'jobs/wang_ying_walk_b_{d}_geometry_v6.json'
    if jp.exists():assert read(jp)==job
    else:jp.write_text(json.dumps(job,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    rows.append({'direction':d,'reference':job['repository_path'],'sha256':job['sha256'],
        'generator_inputs':3,'input_drift':0,'support_image_side':'right',
        'support_screen':r['result']['support_screen'],'swing_screen':r['result']['swing_screen'],
        'receipt_sha256':sha(run/'receipt.json'),'directly_viewed':True})
p=QA/'wang_ying_pose_geometry_review_v6.json';assert not p.exists()
p.write_text(json.dumps({'schema':1,'method':'godot_3d_pose_reference','rows':rows,
    'scope':'New primitive geometry only; no character bitmap inputs or edits. Imagegen character poses still require review.',
    'production_qualified':False},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'geometry_references':2,'generator_inputs_each':3,'input_drift':0,'production_qualified':False}))
