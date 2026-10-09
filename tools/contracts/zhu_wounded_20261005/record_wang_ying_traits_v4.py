"""Preserve retained short-adult idle evidence and native directional templates."""
from pathlib import Path
import hashlib,json,shutil,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005'
CONTRACT=Path(__file__).parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst)
    else:shutil.copyfile(src,dst)
imp_run,preview_run=map(Path,sys.argv[1:3])
imp=read(imp_run/'receipt.json');r=read(preview_run/'receipt.json')
assert imp['complete'] and imp['lock_released'] and imp['dimensions']['passed']
assert len(imp['dimensions']['checks'])==1
for v in imp['source_files']:
    if v['path'].endswith('.png'):assert sha(ROOT/v['path'])==v['before_sha256']==v['after_sha256']
assert r['complete'] and r['lock_released'] and r['native_input_drift']==0
assert len(r['inputs'])==7 and len(r['preview']['checks'])==4
assert all(v['passed'] for v in r['visible_render_checks'])
for v in r['inputs']:assert sha(ROOT/v['path'])==v['sha256']==sha(preview_run/'project'/v['path'])
sources=read(QA/'wang_ying_traits_sources_v4.json')
assert len(sources['checks'])==52 and all(v['passed'] for v in sources['checks'])
matrix=preview_run/'project/idle_matrix_v3.png';assert sha(matrix)==r['matrix_sha256']
preserve(imp_run/'receipt.json',QA/'wang_ying_traits_texture_v4.json')
preserve(preview_run/'receipt.json',QA/'wang_ying_traits_idle_preview_v4.json')
preserve(matrix,QA/'wang_ying_traits_idle_matrix_v4.png')
templates=[]
for direction in ('se','sw','ne','nw'):
    job_path=CONTRACT/f'jobs/wang_ying_idle_single_{direction}_v4.json'
    job=read(job_path);p=ROOT/job['output']
    assert sha(p)==job['output_sha256']
    assert sha(ROOT/job['request'])==job['request_sha256']
    for parent in job['references']:assert sha(ROOT/parent['path'])==parent['sha256']
    with Image.open(p) as im:
        assert im.size==(1254,1254) and im.mode=='RGBA'
        alpha=im.getchannel('A')
        all_alpha_box=alpha.getbbox()
        # Match the existing read-only bounds audit; do not alter source pixels.
        box=alpha.point(lambda value:255 if value>16 else 0).getbbox();assert box
        margins=[box[0],box[1],im.width-box[2],im.height-box[3]]
        assert min(margins)>=4, (direction,margins)
    templates.append({'direction':direction,'path':job['output'],'sha256':sha(p),
        'job':job_path.relative_to(ROOT).as_posix(),'job_sha256':sha(job_path),
        'nonzero_alpha_bounds':all_alpha_box,'visible_alpha_threshold':16,
        'visible_alpha_bounds':box,'visible_alpha_margins':margins,
        'requested_padding_80_met':min(margins)>=80,'actual_engine_import_verified':False})
review={'schema':1,'character':'wang_ying','result':'retained_short_sturdy_adult_static_candidate',
    'review':'Native retained four-view source and actual SpriteFrames matrix directly viewed; four newly generated full-canvas native views also viewed',
    'posture':'Mature bearded short sturdy adult, stable natural stance; not stretched to a tall military silhouette',
    'source_checks':52,'frozen_inputs':7,'input_drift':0,'matrix_sha256':sha(matrix),
    'retained_quad_render_body_fraction':0.70,'ordinary_height_reference_fraction':0.78,
    'height_ratio_is_project_art_inference':True,'templates':templates,
    'method':'built-in image_gen for full-canvas native templates; retained quad PNG unchanged; no local pixel edits',
    'limits':['Matrix header says ordinary idle; retained manifest remains rescued candidate and no state route is qualified',
              'Full-canvas template armor studs and belt detailing vary from retained quad; action and directional continuity remain open',
              'Read-only visible bounds use established alpha greater than 16; faint edge alpha remains unchanged. Requested 80px padding is recorded separately from 4px no-clipping gate',
              'New full-canvas templates have not been engine-imported or used in SpriteFrames',
              'No walk/Unit/campaign/UI or production acceptance'],
    'static_posture_candidate':True,'runtime_qualified':False,'production_qualified':False}
dest=QA/'wang_ying_traits_idle_review_v4.json'
assert not dest.exists(),'Preserve existing observations; create a new review revision'
dest.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'source_checks':52,'retained_idle_views':4,'native_templates':4,'input_drift':0,'production_qualified':False}))
