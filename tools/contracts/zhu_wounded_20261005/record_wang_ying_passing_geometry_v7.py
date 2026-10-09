"""Publish directly viewed low-passing geometry with immutable generator inputs."""
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
for phase in ('passing_a','passing_b'):
    for d in ('se','sw','ne','nw'):
        run=Path(read(base/f'wang_ying_passing_geometry_{phase}_{d}_v7_run.json')['run']);r=read(run/'receipt.json')
        config=read(HERE/f'guides/geometry_{phase}_{d}_v7.json')
        assert r['complete'] and r['lock_released'] and r['result']['passed']
        assert r['result']['support_on_image_left']==(config['expected_support_image_side']=='left')
        assert abs(r['result']['support_screen'][0]-r['result']['swing_screen'][0])>60
        assert abs(r['result']['planted_boot_bottom_y'])<1e-6
        assert 0.08<r['result']['raised_boot_center'][1]-0.055<0.14
        for artifact in r['generator_artifacts']:
            p=ROOT/artifact['path'];assert sha(p)==artifact['sha256']
            copy=run/'project'/p.name if p.suffix=='.gd' else run/p.name
            if p.suffix=='.json':copy=run/'project/geometry_config.json'
            assert sha(copy)==artifact['sha256']
        src=run/f'project/wang_ying_{phase}_{d}_geometry_v7.png';assert sha(src)==r['output_sha256']
        dest=HERE/f'guides/wang_ying_{phase}_{d}_geometry_v7.png';preserve(src,dest)
        preserve(run/'receipt.json',QA/f'wang_ying_passing_geometry_{phase}_{d}_v7.json')
        key=f'wang_ying_{phase}_{d}_geometry_v7'
        job={'schema':1,'character':'wang_ying','state':f'{phase}_{d}_geometry_v7','method':'godot_3d_pose_reference',
            'generation_id':None,'references':[],'repository_path':dest.relative_to(ROOT).as_posix(),
            'output':dest.relative_to(ROOT).as_posix(),'sha256':sha(dest),'output_sha256':sha(dest),'native_size':[768,768],
            'prompt':f'New {d.upper()} {phase} short broad adult geometry: red flat support, blue low passing boot under pelvis. No source bitmap read/edit or production artwork.',
            'generator_artifacts':r['generator_artifacts'],'selected':False,'native_pixel_edits':False,'production_qualified':False}
        jp=HERE/f'jobs/{key}.json'
        if jp.exists():assert read(jp)==job
        else:jp.write_text(json.dumps(job,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        rows.append({'phase':phase,'direction':d,'path':job['repository_path'],'sha256':job['sha256'],
            'generator_inputs':3,'input_drift':0,'support_image_side':config['expected_support_image_side'],
            'support_screen':r['result']['support_screen'],'swing_screen':r['result']['swing_screen'],
            'boot_bottom_clearance':r['result']['raised_boot_center'][1]-0.055,
            'receipt_sha256':sha(run/'receipt.json'),'directly_viewed_native':True})
p=QA/'wang_ying_passing_geometry_review_v7.json';assert not p.exists()
p.write_text(json.dumps({'schema':1,'method':'godot_3d_pose_reference','rows':rows,
    'scope':'Eight new geometry references only. Configs retain pre-render expectation text; actual completion is proved by independent receipts.',
    'limits':['Robot torso, leg colors and contact markers are not character artwork','Native Wang Ying passing sprites still to be authored and reviewed'],
    'production_qualified':False},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'geometry_references':8,'generator_inputs_each':3,'input_drift':0,'production_qualified':False}))
